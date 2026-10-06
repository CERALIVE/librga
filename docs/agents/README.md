# Agent contracts

Read the contract for the subsystem you touch before editing. Original sections are preserved verbatim; only link targets relocate.

| Original heading | Contract | Governed paths / task |
|---|---|---|
| Overview | [overview.md](overview.md) | `docs/PROVENANCE.md` |
| Role | [role.md](role.md) | `/dev/rga` |
| Repository map | [repository-map.md](repository-map.md) | `im2d_api/`; `core/`; `include/rga/`; `include/`; `samples/`; `docs/Rockchip_*`; `docs/PROVENANCE.md`; `docs/API-TRAPS.md`; `docs/fix-audit.md`; `docs/DONORS.md` |
| Commit strategy | [commit-strategy.md](commit-strategy.md) | `integration/1.10.5-ceralive.1`; `tests/shim/contract.c`; `tests/shim/fake_rga.c`; `CERALIVE/librga` |
| PR-TARGETING | [pr-targeting.md](pr-targeting.md) | `CERALIVE/librga`; `--base release/1.10.1`; `https://github.com/CERALIVE/librga/`; `docs/fix-audit.md` |
| Frozen contracts | [frozen-contracts.md](frozen-contracts.md) | `/`; `include/rga/`; `packaging/baseline-symbols-upstream-delta.txt` |
| The additive-only principle | [the-additive-only-principle.md](the-additive-only-principle.md) | `/` |
| Test and board-drill contract | [test-and-board-drill-contract.md](test-and-board-drill-contract.md) | `docs/HANDLE-PLANES.md`; `ci/check-release-qualification.sh`; `tests/board/qualification/<version>/`; `docs/R0-INFRASTRUCTURE-RECOVERY.md`; `r1-isolated-drill.sh`; `/usr`; `docs/TOOLCHAIN-GATE-PROOFS.md`; `tests/test-build-check-gating.sh`; `ci/package-lto.env`; `docs/BUILD-FLAGS.md` |
| Licensing | [licensing.md](licensing.md) | `docs/PROVENANCE.md`; `core/3rdparty/libdrm/include/drm/`; `samples/utils/3rdparty/libdrm/include/`; `core/3rdparty/libdrm/include/drm`; `samples/utils/3rdparty/libdrm/lib/`; `packaging/copyright`; `core/rga_sync.cpp`; `core/rga_sync.h`; `debian/`; `packaging/build-deb.sh` |
| Anti-patterns | [anti-patterns.md](anti-patterns.md) | ` / `; `debian/` |
