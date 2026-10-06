# librga — agent routing

Parent: [CeraLive workspace rules](https://github.com/CERALIVE/ceralive/blob/master/AGENTS.md).

<!-- workspace-hard-rules:begin -->
## Workspace hard rules (identical in every CeraLive AGENTS.md)
- Commits and PRs carry the human author only: no Co-authored-by, no AI attribution.
- Start from the updated canonical branch; rebase to update; never `reset --hard` or discard others' work.
- One focused PR per repo, opened against CERALIVE/<repo>; the root policy PR merges first.
- A repo is self-contained: no path above its root; consume @ceralive packages from the registry, never link:/file:.
- Never delete, skip or weaken a test; every behavior change ships with a test.
- A user-visible change updates docs.ceralive.tv in English and Spanish (es-419), and any ceralive.tv claim it touches, in the same release.
- AGENTS.md holds rules and routing only, within budget; contracts and history live in docs/agents/.
- Full canon: https://github.com/CERALIVE/ceralive/blob/master/AGENTS.md
<!-- workspace-hard-rules:end -->

## ROLE
CeraLive's additive-only Rockchip RGA userspace fork bridges GStreamer to the RK3588 island's `/dev/rga`.
Canonical branch: `main`; releases retain upstream-style versioning.

## STRUCTURE
- `core/`, `im2d_api/`, `include/`: driver bridge and public API.
- `tests/`: host shim, goldens, unit tests and board drills.
- `ci/`, `scripts/`, `.github/`: gates and workflow tooling.
- `packaging/`: first-party runtime/development packages.
- `docs/`: contracts, provenance and evidence.
- `samples/`, `debian/`, `cmake/`: retained upstream trees.

## COMMANDS
Run in Debian arm64 containers matching `ci/target-suite.env`; build checks run on both trixie and bookworm.
```bash
bash ci/build-check-steps.sh
bash tests/test-analyzer-gate.sh
ANALYZER_STRICT=1 bash scripts/run-analyzer.sh
bash scripts/analyzer-summary.sh
bash ci/werror-steps.sh
bash ci/sanitizers-steps.sh
bash tests/test-sanitizer-failures.sh
bash ci/abi-steps.sh
SOURCE_DATE_EPOCH="$(git show -s --format=%ct HEAD)" bash packaging/package-contract.sh --repro
```
Release-record preflight also runs on documentation-only PRs; see the test contract for exact workflow context and evidence boundaries.

## WHERE TO LOOK
| Code path or task | Contract |
|---|---|
| Before changing anything else here, open docs/agents/README.md and read the contract for the subsystem you touch | [Contract index](docs/agents/README.md) |
| Import coordinate and provenance | [Overview](docs/agents/overview.md) |
| Role, releases and installed truth | [Role](docs/agents/role.md) |
| Repository areas and subsystem paths | [Repository map](docs/agents/repository-map.md) |
| Commit provenance, history and remotes | [Commit strategy](docs/agents/commit-strategy.md) |
| PR targets and independent review | [PR-TARGETING](docs/agents/pr-targeting.md) |
| Public headers, ABI, packages and defaults | [Frozen contracts](docs/agents/frozen-contracts.md) |
| Retained platforms, validation and strict-driver truth | [The additive-only principle](docs/agents/the-additive-only-principle.md) |
| tests/, ci/, scripts/, fix ledger and board qualification | [Test and board-drill contract](docs/agents/test-and-board-drill-contract.md) |
| Licensing, notices and packaging exclusions | [Licensing](docs/agents/licensing.md) |
| Prohibited changes and scope boundaries | [Anti-patterns](docs/agents/anti-patterns.md) |

## HARD RULES
- ADDITIVE-ONLY: strip no platform tree or legacy API; preserve every exported symbol except the recorded 18 inherited R1 removals.
- No SONAME (`librga.so.2`), public-struct layout, visibility or version-script changes; retain LP64 sizes 696/304.
- Validation changes only accept MORE valid input; defaults for colour, interpolation and logging remain frozen.
- `LIBRGA_STRICT_DRIVER=1` stays a default-off opt-in policy, not implemented functionality; setting it currently has no effect.
- No new public API or runtime knob; preserve `librga.pc`, its variables and `include/rga/` installation.
- The package pair uses an image platform-layer URL+SHA pin swap, NEVER a REPOS entry or FIRST_PARTY_APT_PKGS layer move.
- Version as `1.10.x+ceralive.N`, not CalVer; `packaging/version` is the release source of truth.
- PRs here merge-commit merge under fork history rules; never squash fix-series/upstream-sync history or self-merge a fix.
- Integrate `integration/1.10.5-ceralive.1` by merge, never rebase; read the historical branch exception before syncing.
- A fix needs a RED reproducer on its actual base and an independent APPROVE receipt with reviewer session identity.
- Never widen the accepted removal list; packaged LTO must pass exact exported name/type/binding/visibility equality.
- Required gates reject missing execution, failed tools, untriaged findings and unauthorized skips; no clean-zero substitutes.
- Host-shim sanitizer results never qualify silicon; unreachable boards are SKIPPED-unreachable, never PASS.
- Publication requires both-board reviewed receipts binding the exact runtime/dev archives; never recreate them from a rebuild.
- Sysext drills use extracted process-local providers: never APT-manage librga or remount `/usr` on that qualification path.
- Board access needs explicit enable and environment identity; stage rollback first, use apt across Conflicts, write only under `/tmp`.
- Generate the D21 ledger from fragments; never hand-edit it or substitute historical review for current receipts.
- Preserve legacy log macro emission and deprecated setter no-ops with layouts intact; do not claim the setters were repaired.
- Preserve notices; exclude root `Android.mk` and sample prebuilt libdrm from artifacts; never build or edit `debian/`.
- Driver changes are STOP-and-surface to the island track; no opportunistic cleanup, 10-bit implementation or consumer stopgap here.
