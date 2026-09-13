# Verify the amended R0 contract [EXISTS]

This manual acceptance procedure accompanies the **owner-approved 2026-09-12
amendment** in [R0-NEUTRALITY.md](R0-NEUTRALITY.md). It changes no library,
packaging, fixture, CI script, or comparator. Its projected comparison inputs
are temporary copies, explicitly distinct from the preserved raw evidence.
It is a release-review requirement, **not an automatically registered CI job**.

## Evidence used for the decision

- Source: R0 base [`5a97e650`](https://github.com/CERALIVE/librga/blob/5a97e650a30b7c7036eb5aa26e39f2d09f18fcc9/core/NormalRgaApi.cpp#L883),
  with assignments and whole-object copy at lines 951–973; layout in
  [`core/hardware/rga_ioctl.h`](../core/hardware/rga_ioctl.h) at lines 223–236.
- Package: [Build Check 34708891767](https://github.com/CERALIVE/librga/actions/runs/34708891767),
  `dist` artifact **10302383893**, head `f09da93cc0ef6049997e7387cf832f60189ea0ef`.
  Runtime `.deb` and extracted `.so` hashes are checked by the recipe below.
- Reference: Radxa `librga2 2.2.0-1`, runtime `.deb` SHA-256
  `ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344`;
  extracted `.so` SHA-256
  `0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3`.
- Compiler identity: published
  [Radxa debug package](https://radxa-repo.github.io/rk3588s2-bookworm/pool/main/libr/librga/librga2-dbgsym_2.2.0-1_arm64.deb),
  SHA-256 `51eea331769b0b243e4346df869d7296bdbb7795d16eef142c297045579eaf8c`.
  Matching build id `2da72b58ecbe1601d24d31868d3a1e7e905f5887` and `.gnu_debuglink`
  lead to `usr/lib/debug/.build-id/2d/a72b58ecbe1601d24d31868d3a1e7e905f5887.debug`.
  `readelf --debug-dump=info` identifies `../im2d_api/src/im2d_impl.cpp` with
  `GNU C++14 12.2.0`, `-O2`, `-fstack-protector-strong`, `-fPIC`. See the full
  producer string in the amendment, not an inference from dependency floors.
- Follow-up export transcript `export-results.txt`, SHA-256
  `2c76718f0f19db0f8c723a7a89eecf92aeae092de33282b33e8c2b9e4ed19aa7`:
  baseline Radxa/CI R0/scratch R0 **274/274/274**, scratch-versus-CI symmetric
  difference empty; final `-O1` on the job-map translation unit alone:
  **281 definitions, 0 missing, 7 added**. This legal repair was demonstrated,
  not adopted. Its unstripped experimental ELF is not the board-tested artifact.
- Follow-up padding transcript `padding-results.txt`, SHA-256
  `3da4362aa446100cd6379738f886c5fffc930930834c273b8da973e490a15433`:
  **20/20** distinct requests in each Radxa environment group, **40/40** distinct
  across both; **20/20 poison pairs on each provider**, exactly the nine padding
  bytes `aa`→`55`, named members unchanged. The recipe rechecks the retained raw
  requests and poison logs, not just these transcript summaries. The experiments
  used arm64 GCC 14.2.0-19 under QEMU in Trixie, offline, with the original
  packaged libraries and fake-device shim; they were not board runs.
- [Both-board receipt, 2026-09-12](https://github.com/CERALIVE/librga/pull/2#issuecomment-5649766546):
  nine matching PSNR cells, one-hour soaks (Rock **139,031**, Orange Pi **140,572**
  iterations), fd 5→5 and restoration. No new hardware evidence is claimed here.
- Independent rejection: reviewer session `ses_f67b8eddfffe5fsQOkDKinJnY7`,
  reviewed head `f09da93`, recorded on [PR #2](https://github.com/CERALIVE/librga/pull/2).
  The literal failures remain rejected; this amendment is a different contract
  for fresh independent adjudication, not a replacement review verdict.

## Reconcile the executable gates

| Existing executable | Unchanged behavior | Role under this amendment |
|---|---|---|
| `tests/golden/cases.c --verify`, called by `tests/golden/run.sh` | Strict comparison of all 504 bytes against a hex fixture; rejects truncation/trailing bytes | Mandatory static construction goldens. The static client is instrumented with `-ftrivial-auto-var-init=zero`; it does not prove packaged-library byte equality. All eight CI goldens remain required. |
| `cmp` on dynamic G1–G8 captures | Literal binary equality | G1–G7 match. Raw G8 remains **FAIL**, a known-failing advisory because Radxa is non-deterministic. The manual procedure below compares explicit temporary G8 projections through the same unmodified `cmp`. |
| `tests/golden/csc-padding-probe.c` | Raw `memcmp`; returns 1 on padding inequality | Known-failing diagnostic/advisory on both libraries, never a green neutrality gate. |
| `packaging/package-contract.sh`, staged mode | `nm -D --defined-only` name list, then `LC_ALL=C comm -23` against the committed 254-name floor; nonempty difference fails R0 | Mandatory global-name floor. Candidate names include weak bindings, so this alone cannot detect global→weak demotion. The manual procedure additionally requires **GLOBAL binding** for every reference global. No baseline or script is edited. |
| Unfiltered defined-symbol set comparison; historical `abidiff` | Still reports the missing weak definitions; historical `abidiff` exit 12 and `ctype` finding remain recorded | Known-failing literal-containment advisories for R0 versus Radxa. No suppressions, altered exits, or type-ABI pass inferred from stripped ELF. The historical `ctype` observation is not substituted for the exact CI artifact's three map-helper differences. |
| `tests/uapi-parity/compare.py` | Layout/ioctl comparison with its existing pinned divergences | Mandatory layout check, **not** a semantic request comparator. The nine-offset exception applies only to the measured aarch64 layout. |
| `tests/board/g-a-neutrality.sh` | Existing per-board R1–R7 scoring, PSNR/fd/soak requirements | Mandatory both-board evidence for the exact artifact, untouched. |

`ci/build-check-steps.sh` and `.github/workflows/build-check.yml` still run the
existing mandatory checks. They do not run the manual dynamic A/B check or
`abidiff`. A green CI badge alone is not an amended-neutrality verdict. A new
missing weak symbol must be explained and reviewed; the recipe pins the three
known missing definitions instead of accepting arbitrary unexplained losses.

## Run the manual acceptance and negative controls

1. From the repository root, retain the reviewed files under the gitignored
   `test-results/r0-amendment/reference/`: both `.deb` files, extracted libraries
   under `r0/usr/lib/aarch64-linux-gnu/` and `radxa/usr/lib/aarch64-linux-gnu/`, and
   the unmodified dynamic captures `r0-G1.raw` … `r0-G8.raw` and
   `radxa-G1.raw` … `radxa-G8.raw`. Obtain CI artifacts through `gh run download`
   for the run above; never substitute a locally rebuilt library. The retained
   dynamic captures are from the independent review of those hash-verified
   binaries. A fresh capture must use the unchanged `golden-cases-dynamic` and
   `libfake_rga.so`, one process per case and provider, recording library hashes.
   Do not use the instrumented static client to claim packaged-byte equality.
2. Retain the follow-up's 80 raw G8 captures and 40 poison logs under
   `test-results/r0-amendment/repeat/`, named
   `<radxa|r0>-<fixed-env|varied-env>-<00..19>.raw` and
   `<radxa|r0>-poison-<00..19>.txt`. Those original input files remain untouched.
   Their producer is the unchanged dynamic runner / existing poison diagnostic,
   not the projection procedure below.
3. Run the following Python block from the repository root with Python 3 and
   GNU binutils/diffutils installed. It executes the same unmodified `cmp` and
   `comm` operations used by the literal checks. `comm` itself returns 0 even
   when names differ: the **nonempty-difference predicate** supplies gate exit 1.
   Captured stderr/stdout and scratch inputs go only under `test-results/`.
   Input errors, hash errors, unexpected deltas, or an accepted negative control
   fail this procedure; none is turned into an advisory success.

```python
from hashlib import sha256
from pathlib import Path
import os
import subprocess
from tempfile import TemporaryDirectory

root = Path.cwd()
work = root / "test-results/r0-amendment"
ref = work / "reference"
repeat = work / "repeat"
padding = frozenset((309, 310, 311, 318, 319, 330, 331, 342, 343))
env = os.environ | {"LC_ALL": "C"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def request(path: Path) -> bytes:
    data = path.read_bytes()
    require(len(data) == 504, f"invalid request size: {path}")
    return data


def projection(data: bytes) -> bytes:
    return bytes(0 if offset in padding else byte
                 for offset, byte in enumerate(data))


identities = {
    "librga2-ceralive_1.10.1+ceralive.1_arm64.deb":
        "7c59bade43e2f8bb4c31e0ae965bee480128aa128528fdc88e8bc082e98ec498",
    "librga2_2.2.0-1_arm64.deb":
        "ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344",
    "r0/usr/lib/aarch64-linux-gnu/librga.so.2.1.0":
        "adf9e34934497092c30ba2ec3cf45141e058c368991d77524d9c0e38f5e29fc6",
    "radxa/usr/lib/aarch64-linux-gnu/librga.so.2.1.0":
        "0b455344259c37fec821955e2de85bb5f76a34e69682217b514c407d8a35c6c3",
}
for name, expected in identities.items():
    require(sha256((ref / name).read_bytes()).hexdigest() == expected,
            f"artifact identity mismatch: {name}")
print("Artifact identity: all four SHA-256 values match")


def exports(provider: str, binding: str | None = None) -> set[str]:
    library = ref / provider / "usr/lib/aarch64-linux-gnu/librga.so.2.1.0"
    output = subprocess.run(
        ["readelf", "--dyn-syms", "--wide", str(library)],
        env=env, capture_output=True, text=True, check=True).stdout
    names = set()
    for line in output.splitlines():
        fields = line.split()
        if (len(fields) >= 8 and fields[0].removesuffix(":").isdigit()
                and fields[6] != "UND" and fields[4] != "LOCAL"
                and (binding is None or fields[4] == binding)):
            names.add(fields[7])
    return names


baseline = set((root / "packaging/baseline-symbols-radxa-2.2.0-1.txt")
               .read_text().splitlines())
require(len(baseline) == 254 and baseline == exports("radxa", "GLOBAL"),
        "committed floor is not the complete Radxa GLOBAL set")
actual = exports("r0", "GLOBAL")
prefix = "_ZNSt8_Rb_treeIjSt4pairIKjP10im_rga_jobESt10_Select1stIS4_ESt4lessIjESaIS4_EE"
known_missing = {
    prefix + "22_M_emplace_hint_uniqueIJRKSt21piecewise_construct_tSt5tupleIJRS1_EESF_IJEEEEESt17_Rb_tree_iteratorIS4_ESt23_Rb_tree_const_iteratorIS4_EDpOT_",
    prefix + "24_M_get_insert_unique_posERS1_",
    prefix + "29_M_get_insert_hint_unique_posESt23_Rb_tree_const_iteratorIS4_ERS1_",
}
require(len(exports("radxa")) == len(exports("r0")) == 274,
        "unexpected artifact export inventory")
require(exports("radxa") - exports("r0") == known_missing,
        "unexplained unfiltered export difference")
require(known_missing <= exports("radxa", "WEAK"),
        "excluded definition is not WEAK")
print("ADVISORY raw ELF containment: FAIL, three known weak map helpers missing")

with TemporaryDirectory(dir=work, prefix="controls-") as temporary:
    scratch = Path(temporary)
    left, right, missing = (scratch / name for name in ("left", "right", "missing"))

    def floor_status(names: set[str]) -> int:
        left.write_text("\n".join(sorted(baseline)) + "\n")
        right.write_text("\n".join(sorted(names)) + "\n")
        return subprocess.run(
            ["bash", "-c", 'comm -23 "$1" "$2" > "$3" && test ! -s "$3"',
             "floor", str(left), str(right), str(missing)],
            env=env, check=False).returncode

    require(floor_status(actual) == 0, "GLOBAL floor failed")
    for symbol in sorted(baseline):
        require(floor_status(actual - {symbol}) == 1,
                f"missing global accepted: {symbol}")
        require(missing.read_text().splitlines() == [symbol],
                "negative control did not detect the intended missing global")
    print("GLOBAL floor: 254/254; deletion controls: 254/254 gate exits 1")

    def byte_status(expected: bytes, candidate: bytes) -> int:
        left.write_bytes(expected)
        right.write_bytes(candidate)
        return subprocess.run(["cmp", "-s", str(left), str(right)],
                              env=env, check=False).returncode

    for number in range(1, 9):
        radxa = request(ref / f"radxa-G{number}.raw")
        r0 = request(ref / f"r0-G{number}.raw")
        raw = byte_status(radxa, r0)
        require(raw == (1 if number == 8 else 0), f"unexpected raw G{number} result")
        if number == 8:
            print("ADVISORY raw G8: FAIL, cmp exit 1 (unchanged)")
            require(byte_status(projection(radxa), projection(r0)) == 0,
                    "G8 meaningful request bytes differ")
        print(f"G{number} amended comparison: exit 0")

    radxa = request(ref / "radxa-G8.raw")
    r0 = request(ref / "r0-G8.raw")
    for offset in range(504):
        mutant = bytearray(r0)
        mutant[offset] ^= 1
        code = byte_status(projection(radxa), projection(bytes(mutant)))
        require(code == (0 if offset in padding else 1),
                f"wrong mutation result at zero-based offset {offset}: {code}")
        if offset in (308, 312, 320, 344):
            print(f"Named-byte negative control offset {offset}: cmp exit {code}")
    print("Request mutations: 495/495 non-padding bytes rejected (exit 1); "
          "9/9 padding-only changes accepted (exit 0)")
    for malformed in (r0[:-1], r0 + b"\0"):
        require(byte_status(projection(radxa), projection(malformed)) == 1,
                "malformed request accepted")
    print("Truncated/trailing-byte controls: both cmp exit 1")

    for provider in ("radxa", "r0"):
        samples = [request(repeat / f"{provider}-{group}-env-{run:02}.raw")
                   for group in ("fixed", "varied") for run in range(20)]
        require(len(set(samples)) == 40, "repeat evidence is not 40 distinct requests")
        for sample in samples:
            require(byte_status(projection(radxa), projection(sample)) == 0,
                    "repeat evidence has a meaningful-byte difference")
        require(byte_status(samples[0], samples[1]) == 1,
                "first two raw repeat requests unexpectedly equal")
        for run in range(20):
            log = (repeat / f"{provider}-poison-{run:02}.txt").read_text()
            changes = {line for line in log.splitlines() if line.startswith("offset=")}
            require(changes == {f"offset={offset} before=aa after=55" for offset in padding},
                    "unexpected poison changes")
            require("flag=1 Y=187,628,63,16368 U=-102,-346,449,130944 V=449,-407,-40,130944" in log,
                    "poison named values differ")
        print(f"{provider}: 40/40 raw requests distinct, semantic comparison exit 0; "
              "raw self-comparison exit 1; 20/20 nine-byte poison pairs")
print("Amended manual acceptance and all negative controls completed")
```

The mutation sweep tests **all 495 non-excluded bytes**, not just a convenient
coefficient. It includes `flag` at 308, the named coefficient at 312 and named
offset bytes at 320 and 344—the exact trap created by misreading `cmp` positions
as offsets. It rejects short and long requests too. The export controls remove
each of the **254** globals independently from a temporary candidate inventory;
the `.so` itself is never edited. Removing a GLOBAL binding is also how a
global→weak demotion appears to this binding-filtered comparison. The reference
floor is never mutated. These are failing controls of the *amended* predicates,
not merely demonstrations that the old raw predicates can fail.

## Verification receipt

Executed **2026-09-12**, locally on retained evidence, without board access.
The exact Python block above produced:

```text
Artifact identity: all four SHA-256 values match
ADVISORY raw ELF containment: FAIL, three known weak map helpers missing
GLOBAL floor: 254/254; deletion controls: 254/254 gate exits 1
G1 amended comparison: exit 0
G2 amended comparison: exit 0
G3 amended comparison: exit 0
G4 amended comparison: exit 0
G5 amended comparison: exit 0
G6 amended comparison: exit 0
G7 amended comparison: exit 0
ADVISORY raw G8: FAIL, cmp exit 1 (unchanged)
G8 amended comparison: exit 0
Named-byte negative control offset 308: cmp exit 1
Named-byte negative control offset 312: cmp exit 1
Named-byte negative control offset 320: cmp exit 1
Named-byte negative control offset 344: cmp exit 1
Request mutations: 495/495 non-padding bytes rejected (exit 1); 9/9 padding-only changes accepted (exit 0)
Truncated/trailing-byte controls: both cmp exit 1
radxa: 40/40 raw requests distinct, semantic comparison exit 0; raw self-comparison exit 1; 20/20 nine-byte poison pairs
r0: 40/40 raw requests distinct, semantic comparison exit 0; raw self-comparison exit 1; 20/20 nine-byte poison pairs
Amended manual acceptance and all negative controls completed
```

The first recipe trial failed its inventory guard because it counted two LOCAL
section entries in `.dynsym` as exports. The final recipe excludes LOCAL entries,
matching `nm -D --defined-only`'s 274 exported definitions; no library or existing
comparator was changed to address that recipe error.

`bash packaging/package-contract.sh` returned 0 with the static package contract
intact. The diff from `f09da93` is empty for **all** `core/`, `im2d_api/`,
`include/`, `meson.build`, `meson_options.txt`, `packaging/`, `ci/`, `tests/`, and
`scripts/` paths. In particular, every `PACKAGED_INPUTS` path used to derive
`SOURCE_DATE_EPOCH` is unchanged. The entire historical section of
`R0-NEUTRALITY.md`, from `## Bootstrap adaptations` onward, was checked against
`f09da93` and is byte-for-byte unchanged, including all FAIL entries.

The original `.deb` was rehashed and re-extracted locally; its payload hash also
matches. No rebuild or replacement of that artifact was performed. A full source
build/sanitizer/board gate is not rerun for this documentation-only amendment;
the existing build and board receipts remain tied to their original artifact.
Markdown LSP diagnostics were requested, but this environment has no Markdown
language server; no clean-LSP result is claimed. The executable documentation was
compiled and run by Python as shown above.

Publication must still reproduce the exact board-tested SHA-256 at the fixed
build path and packaged-input epoch. These checks establish the amended
predicates and artifact preservation, **not independent review approval**.
