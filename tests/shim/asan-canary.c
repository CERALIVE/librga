// SPDX-License-Identifier: Apache-2.0
// Deliberate faults. Not a test of librga — a test of the sanitizer build
// recipe. If this binary exits 0 in silence, the runtimes are linked but not
// intercepting, and every clean report from the same tree is meaningless.
// scripts/build-sanitized.sh builds it; ci/sanitizers-steps.sh runs it and
// REQUIRES both reports.
//
// One fault per runtime, because `asan` here means `-fsanitize=address,undefined`
// and a canary that exercised only ASan would leave half the recipe unproven.
// The UBSan fault comes first and is not fatal, so a single run shows both.
#include <stdlib.h>
#include <stdio.h>

int main(void) {
	volatile int big = 2147483647;
	big = big + 1;         /* signed overflow, on purpose -> UBSan */

	char *p = malloc(8);
	if (!p) return 2;
	p[8] = 'x';            /* one past the end, on purpose -> ASan */

	printf("NO SANITIZER REPORT: overflowed to %d and wrote %c past an 8-byte allocation\n", big, p[8]);
	free(p);
	return 0;
}
