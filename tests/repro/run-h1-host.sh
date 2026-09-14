#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# H1 host driver: run tests/repro/h1_init_race.cpp in a FRESH PROCESS per
# iteration, under ThreadSanitizer, against the fake-/dev/rga shim.
#
#   bash tests/repro/run-h1-host.sh [iterations]     # default 200
#
# Fresh process per iteration is not a stylistic choice. `rgaCtx`, `refCount`
# and the singleton's `sInstance` are all process globals with no reset path,
# so a second iteration inside one process would start from an already-warm
# context and measure nothing. Every number this script prints therefore comes
# from a first-ever init in a brand new address space.
#
# HOST ONLY. This is the shim's model of the driver, never silicon. TSan does
# not run on a board and no row derived from this script may imply it did.
# See docs/SANITIZERS.md.
#
# WHAT IT CHECKS, PER ITERATION
#
#   (a) sanitizer text  — did TSan name the library's context object (`rgaCtx`)
#                         or its reference counter (`refCount`)? Prints "clean"
#                         or the matching report text.
#   (b) device fd count — how many /proc/self/fd entries point at the shim's
#                         memfd after init, and whether any survives teardown.
#
# Exit status is 1 if any iteration produced a sanitizer hit on those names, a
# post-init count above 1, or a surviving fd after teardown. A clean sweep
# exits 0. Neither outcome is a fix; both are characterisation.
set -euo pipefail

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../..")
cd "$root"

iterations=${1:-200}
case "$iterations" in
	'' | *[!0-9]*) printf 'usage: %s [iterations]\n' "$0" >&2; exit 2 ;;
esac
((iterations > 0)) || { printf 'iterations must be positive\n' >&2; exit 2; }

build="build-tsan"
library=$build/librga.so.2.1.0
shim=$build/libfake_rga.so

for artifact in "$library" "$shim"; do
	[[ -f $artifact ]] || {
		printf 'run-h1-host: missing %s — run: bash scripts/build-sanitized.sh tsan\n' \
			"$artifact" >&2
		exit 2
	}
done

# The same assertion build-sanitized.sh makes, repeated here because this script
# is runnable on its own and a TSan tree with no runtime linked reports clean
# forever.
ldd "$library" | grep -q libtsan || {
	printf 'run-h1-host: %s links no tsan runtime\n' "$library" >&2
	exit 2
}

client=$build/h1_init_race
# -fpermissive for the same reason scripts/build-sanitized.sh needs it: the
# non-aarch64 arm of im2d's pointer casts is compiled on an x86_64 host, and its
# headers come along for the ride.
g++ -std=c++20 -O1 -g -fno-omit-frame-pointer -fsanitize=thread -fpermissive \
	-Wall -Wextra \
	-Iinclude -Iim2d_api -Icore -Icore/hardware -Icore/utils \
	-Icore/3rdparty/libdrm/include/drm -Icore/3rdparty/android_hal \
	tests/repro/h1_init_race.cpp -o "$client" \
	"$library" -Wl,-rpath,"$(realpath "$build")" -pthread -ldl
ldd "$client" | grep -q libtsan || {
	printf 'run-h1-host: client links no tsan runtime\n' >&2
	exit 2
}

work=$(mktemp -d "${TMPDIR:-/tmp}/h1-host.XXXXXX")
results=test-results/h1
mkdir -p "$results"
trap 'rm -rf "$work"' EXIT HUP INT TERM

# The names the task asks about: the internal context object and the reference
# counter, plus the mutex that guards only the counter. A report naming any of
# them is the finding; a report naming none of them is still printed in full to
# the per-iteration log, it just does not decide the verdict.
names='rgaCtx|refCount|mMutex'

# halt_on_error=0 so one report does not truncate an iteration's own output;
# exitcode=0 so a report is data rather than a crashed child. Symbolization is
# ON — without it TSan prints offsets and the global's NAME, which is the whole
# question in (a), never appears.
export TSAN_OPTIONS="halt_on_error=0 exitcode=0 symbolize=1 second_deadlock_stack=1"

overall=0

run_scenario() {
	scenario=$1
	log=$results/$scenario.log
	csv=$results/$scenario.csv
	: > "$log"
	printf 'iteration,ok,ctx_agreed,refcount_after_init,fds_after_init,deinit_calls,refcount_after_teardown,fds_after_teardown,sanitizer\n' > "$csv"

	sanitizer_hits=0 multi_open=0 leaked=0 failed=0
	max_fds=0 max_refcount=0

	printf '\n=== scenario %s (%s iterations, fresh process each) ===\n' \
		"$scenario" "$iterations"

	for ((i = 1; i <= iterations; ++i)); do
		out=$work/out.$i err=$work/err.$i
		status=0
		env LD_PRELOAD="$(realpath "$shim")" \
			FAKE_RGA_LOG="$work/interposed.$i.log" \
			"$client" "$scenario" > "$out" 2> "$err" || status=$?

		if ((status != 0)); then
			failed=$((failed + 1))
			printf '[%s #%s] client exited %s\n' "$scenario" "$i" "$status" >> "$log"
			cat "$out" "$err" >> "$log"
			continue
		fi

		# The library prints a deprecation banner to stdout on every successful
		# init, so pick the result line out rather than assuming it is alone.
		line=$(grep '^scenario=' "$out" || true)
		if [[ -z $line ]]; then
			failed=$((failed + 1))
			printf '[%s #%s] no result line\n' "$scenario" "$i" >> "$log"
			cat "$out" "$err" >> "$log"
			continue
		fi
		field() { sed -n "s/.*[[:space:]]$1=\([^[:space:]]*\).*/\1/p" <<< "$line"; }
		ok=$(field ok)
		agreed=$(field ctx_agreed)
		refcount=$(field refcount_after_init)
		fds=$(field fds_after_init)
		calls=$(field deinit_calls)
		refcount_end=$(field refcount_after_teardown)
		fds_end=$(field fds_after_teardown)

		if grep -Eq "$names" "$err"; then
			verdict=hit
			sanitizer_hits=$((sanitizer_hits + 1))
			{
				printf '[%s #%s] sanitizer named %s:\n' "$scenario" "$i" "$names"
				grep -E -B4 -A12 "$names" "$err"
			} >> "$log"
		elif [[ -s $err ]]; then
			# Instrumented and reporting, just not about these names. Recorded
			# so an unrelated report is never silently rounded up to "clean".
			verdict=other
			{ printf '[%s #%s] sanitizer output, other names:\n' "$scenario" "$i"; cat "$err"; } >> "$log"
		else
			verdict=clean
		fi

		if ((fds > max_fds)); then max_fds=$fds; fi
		if ((refcount > max_refcount)); then max_refcount=$refcount; fi
		if ((fds > 1)); then multi_open=$((multi_open + 1)); fi
		if ((fds_end > 0)); then leaked=$((leaked + 1)); fi

		printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
			"$i" "$ok" "$agreed" "$refcount" "$fds" "$calls" \
			"$refcount_end" "$fds_end" "$verdict" >> "$csv"
		printf '[%s #%s] %s sanitizer=%s\n' "$scenario" "$i" "$line" "$verdict" >> "$log"
	done

	printf 'iterations              : %s\n' "$iterations"
	printf 'client failures         : %s\n' "$failed"
	printf '(a) sanitizer naming %s\n' "$names"
	if ((sanitizer_hits == 0)); then
		printf '    clean (%s/%s iterations produced no report naming those symbols)\n' \
			"$iterations" "$iterations"
	else
		printf '    HIT in %s/%s iterations; first report:\n' "$sanitizer_hits" "$iterations"
		sed -n '/sanitizer named/,/^$/p' "$log" | head -40
	fi
	printf '(b) device fds\n'
	printf '    max fds_after_init      : %s\n' "$max_fds"
	printf '    iterations with >1 fd   : %s\n' "$multi_open"
	printf '    max refcount_after_init : %s\n' "$max_refcount"
	printf '    iterations leaking an fd after teardown : %s\n' "$leaked"
	printf 'per-iteration log : %s\n' "$log"
	printf 'per-iteration csv : %s\n' "$csv"

	((sanitizer_hits == 0 && multi_open == 0 && leaked == 0 && failed == 0)) || overall=1
}

run_scenario c-init
run_scenario singleton-get

printf '\n=== H1 host verdict: %s ===\n' \
	"$( ((overall == 0)) && printf 'no host-side artifact observed' || printf 'artifact observed, see logs')"
exit "$overall"
