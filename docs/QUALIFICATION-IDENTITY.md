# Qualification must name the shipped bytes [EXISTS]

R1 `1.10.5+ceralive.1` was measured with a local candidate ELF whose SHA-256 was
`361ab931ebe49f3c77256003a36849dc5703de26f3863ada0acdbe84a6f7c884`.
The released runtime instead contains
`07b6b6c466c6bddbcf7006e5b678d68de372b44686e6eb8ea3fcf00ce1cb6b74`.
Source commit and version agreed; bytes did not. Item 47's row 19 identified the
gap. This infrastructure closes that identity boundary, not the missing hardware
qualification. It does not alter that release or invent receipts for it.

## Why this gate, rather than another build check

The recovered `r1-isolated-drill.sh` already required expected ELF hashes and
checked local and staged files. Merely requiring those hashes again would not
catch an accurately identified candidate followed by a different release build.
The existing two-build reproducibility check proves repeatability within its
controlled build environment, not equality with the board's candidate.

The enforcing boundary is therefore **publication**. After the artifact download
and existing asset-set/checksum validation, before creating any tag/release,
`ci/check-release-qualification.sh` compares the actual runtime archive, development
archive and packaged ELF against **both** reviewed board receipts. It returns 1
on missing, empty, malformed or mismatched receipts. The workflow runs it as an
unconditional step in the live publish job, without error suppression. A failed
step prevents release creation and the subsequent APT reindex dispatch.

The public asset set stays exactly two `.deb`/`.sha256` pairs. Those checksums
already publish archive identity; an extra release-manifest asset is unnecessary.
The ELF hash is derived directly from the runtime archive, not a staging tree.
All 17 existing CI jobs, ABI/dynsym rules and disabled LTO remain unchanged.

## Receipt lifecycle

1. Obtain a candidate package pair from CI or an authorized publication **dry run**.
   Dry runs intentionally need no qualification receipts: they produce candidates
   to measure, create no release, and do not claim board qualification.
2. Extract the runtime ELF and supply the existing expected `CANDIDATE_SHA256`
   and `BASELINE_SHA256` to the recovered drill. Also supply `RUNTIME_DEB`,
   `DEV_DEB`, `RELEASE_VERSION` and `BOARD_MODEL`. See the [board runbook](../tests/board/README.md).
   `ci/artifact-identity.sh` checks package names, versions, arm64 metadata and
   extracts/hashes the packaged ELF. A candidate/package mismatch fails before
   transport, including when the caller updates its expected hash to match the
   wrong local candidate. Missing required inputs also fail before measurement.
3. The fresh result directory retains `artifact-inputs.sha256`, existing input
   hashes and per-row logs. Remote provider hashes are checked before and after
   measurements; local archives are rechecked at the end. No successful receipt
   is emitted for failed rows, interrupted runs, failed staging, or failed cleanup.
4. After all rows and ownership cleanup succeed, the EXIT handler writes
   `rock-5b-plus.sha256` or `orange-pi-5-plus.sha256`. These are exact three-line
   checksum records: runtime archive, development archive, packaged ELF.
5. Review the run's full evidence and commit each unchanged successful receipt to
   `tests/board/qualification/<version>/<board>.sha256`, with its evidence locator
   in the accompanying review/acceptance record. This is an ordinary reviewed PR,
   **not** an automatic acceptance or a plan-checkbox update. Never generate or
   edit a receipt using a later release build. No historical receipts are supplied
   by this change, so publication from this line fails closed until they exist.
6. Dispatch only after all other release prerequisites are satisfied. The publish
   job checks out the exact dispatched commit for the approved receipts and
   compares the downloaded upload payload to both. A rebuilt mismatch requires
   measuring that new candidate and reviewing new receipts, not overriding a hash.

For an offline comparison, from a checkout containing the reviewed receipts and
the two actual archives in `dist/`:

```sh
RELEASE_VERSION=1.10.5+ceralive.1 DEB_ARCH=arm64 \
  bash ci/check-release-qualification.sh
```

## Proof boundary

The R1 record preflight now runs through this same entry before archive comparison;
`--records-only` checks the committed matrix, both identity receipts and the actual
GitHub rehearsal runs without a local payload. It runs on documentation-only PRs
as well as live publication. See [the remediation contract](R1-RECORD-DEVIATIONS.md#recurrence-gate-and-discharge-basis)
for required table keys, read-only API access, fail-closed log expiry and the
pre-fix/current-snapshot proof. It does not turn an installation receipt into
`ldconfig` or normal-loader evidence, nor approve every matrix disposition.

This is an artifact-identity gate, not cryptographic board attestation or a new
acceptance framework. Operators/reviewers remain responsible for board identity,
trustworthy receipts and any loader/proc-maps evidence in the acceptance record.
The development archive is **identified**, not installed or transaction-tested by
the isolated drill. H1 package transactions, D24, H7 and other obligations still
need their own matching-artifact evidence; this checksum comparison does not
declare them passed. Raw bench/reproducer invocations do not generate publishable
receipts. Release lines not carrying this change are not silently updated.

It would have caught the motivating R1 release: a measured candidate receipt
would disagree with the later runtime/dev archives and ELF and stop publication.
Supplying the released package with the old candidate ELF would instead fail the
drill before measurement. Manually falsifying a reviewed receipt or bypassing the
publication workflow is outside this gate's authority.

## Offline mutation proof

Run `bash tests/board/test-isolated-drill.sh`. The existing `board-isolated-drill`
Meson test executes this coverage in both required build jobs; there is no new job
or duplicate reproducibility/ABI check. All transport is replaced by the existing
strict mock. No board connection, hardware operation or package installation occurs.
The package fixture contains a real host-compiled ELF; its arm64 control metadata
exists solely to exercise identity checks, not to claim target execution.

| Mutation | Required process result |
|---|---|
| Append a byte to the candidate ELF, retain expected hash | Drill exits 1 before transport/receipt |
| Update that expected hash but retain the original runtime package | Drill exits 1 before transport/receipt |
| Restore the ELF | Drill exits 0; receipt appears after cleanup |
| Existing scorer/transport failures | Drill exits 1; no successful receipt |
| Existing cleanup failure | Drill exits 13; no successful receipt |
| Remove expected hash, archive, version or board-model input | Drill exits 1 before transport/receipt |
| Repack the runtime with a changed ELF; keep qualification receipts | Actual publish-step command's job shell exits 1 |
| Change only the development archive | Job shell exits 1 |
| Missing, empty or malformed receipt on either board | Job shell exits 1 |
| Restore the exact qualified archives/receipts | Job shell exits 0 |
| Wrong version/package/architecture or absent packaged ELF | Identity generation exits nonzero |

`tests/board/test-release-qualification.sh` extracts and executes the real workflow
step's command under `bash --noprofile --norc -e -o pipefail`, checks its environment
bindings and rejects step-level skipping/error suppression. Tests assert the outer
process status, not just the diagnostic text. A gate changed to always succeed
therefore fails the mutation test rather than reporting a decorative green.
