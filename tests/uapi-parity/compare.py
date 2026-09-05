#!/usr/bin/env python3
"""Compare the island and librga multi_rga UAPI tables and fail on any drift.

The two emitters know nothing about each other: each includes exactly one side's
headers and prints a flat ``kind<TAB>name<TAB>value`` table. This script is the
only place the two vocabularies meet, and it is deliberately paranoid --- an
entry that is present on one side only, or whose value moved, is a failure
unless it appears in one of the three explicit tables below WITH the exact
values recorded here. Those tables are pinned expectations, not mute buttons: a
declared divergence that changes shape still fails.

Running the emitters
--------------------
Layout parity has to be measured at the TARGET ABI, so the emitters are normally
aarch64 binaries. This script works out how to execute them:

  1. same architecture as the host                -> run directly
  2. ``LIBRGA_PARITY_RUNNER`` set                 -> use it as the command prefix
  3. ``MESON_EXE_WRAPPER`` set                    -> use the cross file's wrapper
  4. ``qemu-<arch>`` on PATH                      -> use it
  5. ``LIBRGA_PARITY_BOARD`` set (user@host)      -> scp to /tmp/librga-parity/
                                                     on the board and ssh there
  6. otherwise                                    -> fail with instructions

An x86_64 build is allowed as a smoke test and is reported as such, but it does
not prove aarch64 layout parity and the generated doc says so.
"""

from __future__ import annotations

import argparse
import os
import platform
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Pinned expectations. Every entry needs a reason; a bare exemption is a bug.
# --------------------------------------------------------------------------

#: Members the two sides genuinely spell differently. Key is the librga name,
#: value is the island name. Layout must still agree exactly after renaming ---
#: only the identifier differs, never the offset or the width.
MEMBER_ALIASES = {
    "rga_external_buffer.memory_info": "rga_external_buffer.memory_parm",
    "rga_buffer_pool.buffers": "rga_buffer_pool.buffers_ptr",
    "rga_img_info_t.is_10b_compact": "rga_img_info_t.compact_mode",
}

#: Type names that differ cosmetically. Not ABI --- recorded for the doc and to
#: keep a reader from thinking the emitters compare unrelated things.
TYPE_ALIASES = {
    "rga_rect_t": "RECT",
    "rga_point_t": "POINT",
    "rga_mmu_t": "MMU",
    "rga_color_fill_t": "COLOR_FILL",
    "rga_fading_t": "FADING",
    "rga_line_draw_t": "line_draw_t",
    "rga_csc_coe": "csc_coe_t",
    "rga_full_csc": "full_csc_t",
    "rga_mosaic_info": "rga_mosaic_info_t",
    "rga_gauss_config": "rga_gauss_config_t",
    "rga_osd_invert_factor": "rga_osd_invert_factor_t",
    "rga_color": "rga_color_t",
    "rga_osd_bpp2": "rga_osd_bpp2_t",
    "rga_osd_mode_ctrl": "rga_osd_mode_ctrl_t",
    "rga_osd_info": "rga_osd_info_t",
    "rga_pre_intr_info": "rga_pre_intr_info_t",
}

#: Symbols the island declares and librga does not, with their pinned values.
#: librga never issues these, so its headers legitimately omit them --- but an
#: island renumber is still ABI drift, so the numbers are asserted here.
ISLAND_ONLY_EXPECTED = {
    ("ioctl", "RGA_CACHE_FLUSH"): (
        0x501C,
        "legacy RGA1 cache-flush command; librga has no caller",
    ),
    ("ioctl", "RGA_IMPORT_DMA"): (
        0x601D,
        "legacy RGA2 dma import; librga uses RGA_IOC_IMPORT_BUFFER instead",
    ),
    ("ioctl", "RGA_RELEASE_DMA"): (
        0x601E,
        "legacy RGA2 dma release; librga uses RGA_IOC_RELEASE_BUFFER instead",
    ),
    ("ioctl", "RGA_BUFFER_POOL_SIZE_MAX"): (
        40,
        "driver-side cap on one import batch; librga does not expose it",
    ),
}

#: Symbols librga declares and the island header does not, with pinned values.
LIBRGA_ONLY_EXPECTED = {
    ("ioctl", "RGA2_BLIT_SYNC"): (
        0x6017,
        "legacy RGA2 blit command retained for pre-multi_rga drivers",
    ),
    ("ioctl", "RGA2_BLIT_ASYNC"): (
        0x6018,
        "legacy RGA2 blit command retained for pre-multi_rga drivers",
    ),
    ("ioctl", "RGA2_FLUSH"): (
        0x6019,
        "legacy RGA2 flush command retained for pre-multi_rga drivers",
    ),
}

#: Real, known layout divergences. Each records BOTH sides' current values, so
#: the entry stops matching --- and the gate fails --- the moment either side
#: moves again. Adding to this table is a deliberate act that must come with a
#: filed finding, never a convenience.
DECLARED_DIVERGENCES = {
    ("off", "rga_osd_info.last_flags0"): (
        40,
        44,
        "island declares last_flags0 before last_flags1 inside the u64 union; "
        "librga declares them the other way round, so on little-endian the two "
        "sides disagree about which half of last_flags each name addresses",
    ),
    ("off", "rga_osd_info.last_flags1"): (
        44,
        40,
        "mirror of rga_osd_info.last_flags0",
    ),
    ("off", "rga_osd_info.cur_flags0"): (
        48,
        52,
        "island declares cur_flags0 before cur_flags1 inside the u64 union; "
        "librga declares them the other way round",
    ),
    ("off", "rga_osd_info.cur_flags1"): (
        52,
        48,
        "mirror of rga_osd_info.cur_flags0",
    ),
}

#: Floors from the parity contract. The gate may grow, never silently shrink.
MIN_IOCTLS = 12
MIN_STRUCT_SIZES = 6

#: ELF e_machine -> (uname-style name, qemu-user suffix)
ELF_MACHINES = {
    0x03: ("i386", "i386"),
    0x28: ("arm", "arm"),
    0x3E: ("x86_64", "x86_64"),
    0xB7: ("aarch64", "aarch64"),
    0xF3: ("riscv64", "riscv64"),
}


# --------------------------------------------------------------------------
# Execution
# --------------------------------------------------------------------------


def elf_arch(path: Path) -> str:
    """Return the uname-style architecture an ELF executable targets."""
    with path.open("rb") as fh:
        head = fh.read(20)
    if len(head) < 20 or head[:4] != b"\x7fELF":
        raise SystemExit(f"compare: {path} is not an ELF executable")
    little = head[5] == 1
    machine = int.from_bytes(head[18:20], "little" if little else "big")
    if machine not in ELF_MACHINES:
        raise SystemExit(f"compare: {path} targets unknown ELF machine 0x{machine:x}")
    return ELF_MACHINES[machine][0]


def host_arch() -> str:
    mach = platform.machine()
    return {"amd64": "x86_64", "arm64": "aarch64"}.get(mach, mach)


class Runner:
    """Knows how to execute a possibly-foreign-architecture emitter."""

    def __init__(self, target: str) -> None:
        self.target = target
        self.kind = "native"
        self.prefix: list[str] = []
        self.board = ""

        if target == host_arch():
            return

        override = os.environ.get("LIBRGA_PARITY_RUNNER", "").strip()
        if override:
            self.kind, self.prefix = "runner-override", shlex.split(override)
            return

        # Meson exports whatever exe_wrapper the cross file declared. Honouring
        # it means a board-runner wrapper in the cross file works here for free.
        meson_wrapper = os.environ.get("MESON_EXE_WRAPPER", "").strip()
        if meson_wrapper:
            self.kind, self.prefix = "meson-exe-wrapper", shlex.split(meson_wrapper)
            return

        qemu_suffix = next(s for m, (n, s) in ELF_MACHINES.items() if n == target)
        for candidate in (f"qemu-{qemu_suffix}", f"qemu-{qemu_suffix}-static"):
            found = shutil.which(candidate)
            if found:
                self.kind, self.prefix = "qemu-user", [found]
                return

        board = os.environ.get("LIBRGA_PARITY_BOARD", "").strip()
        if board:
            self.kind, self.board = "board-ssh", board
            return

        raise SystemExit(
            f"compare: emitters target {target} but this host is {host_arch()}, and no way "
            "to run them was found.\n"
            f"  install qemu-user (qemu-{qemu_suffix}), or set LIBRGA_PARITY_RUNNER to a "
            "command prefix,\n"
            "  or set LIBRGA_PARITY_BOARD=user@host to stage them in /tmp/librga-parity/ "
            "on a real board."
        )

    def describe(self) -> str:
        if self.kind == "native":
            return f"native ({self.target})"
        if self.kind == "board-ssh":
            return f"board ssh {self.board} (/tmp/librga-parity/)"
        return f"{self.kind}: {' '.join(self.prefix)}"

    def run(self, exe: Path) -> str:
        if self.kind == "board-ssh":
            remote_dir = "/tmp/librga-parity"
            subprocess.run(
                ["ssh", self.board, f"mkdir -p {remote_dir}"],
                check=True,
            )
            subprocess.run(
                ["scp", "-q", str(exe), f"{self.board}:{remote_dir}/{exe.name}"],
                check=True,
            )
            proc = subprocess.run(
                ["ssh", self.board, f"chmod +x {remote_dir}/{exe.name} && {remote_dir}/{exe.name}"],
                check=True,
                capture_output=True,
                text=True,
            )
            return proc.stdout
        proc = subprocess.run(
            [*self.prefix, str(exe)], check=True, capture_output=True, text=True
        )
        return proc.stdout


# --------------------------------------------------------------------------
# Comparison
# --------------------------------------------------------------------------


def parse_table(text: str, origin: str) -> dict[tuple[str, str], int]:
    table: dict[tuple[str, str], int] = {}
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            raise SystemExit(f"compare: {origin}:{lineno}: malformed table row {raw!r}")
        kind, name, value = parts
        key = (kind, name)
        if key in table:
            raise SystemExit(f"compare: {origin}:{lineno}: duplicate entry {key}")
        table[key] = int(value)
    if not table:
        raise SystemExit(f"compare: {origin} produced an empty table")
    return table


def canonicalise(table: dict[tuple[str, str], int]) -> dict[tuple[str, str], int]:
    """Rewrite librga member names to their island spelling."""
    out: dict[tuple[str, str], int] = {}
    for (kind, name), value in table.items():
        out[(kind, MEMBER_ALIASES.get(name, name))] = value
    return out


def read_pin(pin_env: Path) -> dict[str, str]:
    pin: dict[str, str] = {}
    for raw in pin_env.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        pin[key.strip()] = value.strip()
    return pin


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--island-exe", required=True, type=Path)
    ap.add_argument("--librga-exe", required=True, type=Path)
    ap.add_argument("--pin-env", type=Path)
    ap.add_argument("--emit-doc", type=Path)
    ap.add_argument("--island-header", type=Path, help="fetched header, for the doc header note")
    args = ap.parse_args()

    # Meson hands us build-dir-relative paths like './uapi-parity-island-side'.
    # Path() normalises the leading './' away, and exec does not search the
    # working directory for a bare name, so resolve before anything runs them.
    args.island_exe = args.island_exe.resolve()
    args.librga_exe = args.librga_exe.resolve()

    island_arch = elf_arch(args.island_exe)
    librga_arch = elf_arch(args.librga_exe)
    if island_arch != librga_arch:
        raise SystemExit(
            f"compare: emitters disagree on target architecture "
            f"(island={island_arch}, librga={librga_arch}); comparing them would be meaningless"
        )

    runner = Runner(island_arch)
    print(f"uapi-parity: target ABI {island_arch}, execution via {runner.describe()}")
    if island_arch != "aarch64":
        print(
            "uapi-parity: WARNING this is a "
            f"{island_arch} SMOKE run --- it does not prove aarch64 layout parity"
        )

    island = parse_table(runner.run(args.island_exe), "island_side")
    librga = canonicalise(parse_table(runner.run(args.librga_exe), "librga_side"))

    failures: list[str] = []
    compared_ioctls: list[tuple[str, int]] = []
    compared_sizes: list[tuple[str, int]] = []
    compared_members = 0

    for key in sorted(island.keys() & librga.keys()):
        kind, name = key
        a, b = island[key], librga[key]
        declared = DECLARED_DIVERGENCES.get(key)
        if a == b:
            if declared:
                failures.append(
                    f"{kind} {name}: declared divergence no longer diverges "
                    f"(both sides now {a}); remove it from DECLARED_DIVERGENCES"
                )
        elif declared and (declared[0], declared[1]) == (a, b):
            pass  # known, pinned, unchanged
        elif declared:
            failures.append(
                f"{kind} {name}: DECLARED divergence changed shape "
                f"(recorded island={declared[0]} librga={declared[1]}, "
                f"now island={a} librga={b})"
            )
        else:
            failures.append(f"{kind} {name}: island={a} librga={b}")

        if kind == "ioctl":
            compared_ioctls.append((name, a))
        elif kind == "size":
            compared_sizes.append((name, a))
        elif kind == "off":
            compared_members += 1

    for key in sorted(island.keys() - librga.keys()):
        expected = ISLAND_ONLY_EXPECTED.get(key)
        if expected is None:
            failures.append(
                f"{key[0]} {key[1]}: present on island (value {island[key]}) but absent from librga, "
                "and not declared in ISLAND_ONLY_EXPECTED"
            )
        elif expected[0] != island[key]:
            failures.append(
                f"{key[0]} {key[1]}: island-only value moved "
                f"(recorded {expected[0]}, now {island[key]})"
            )

    for key in sorted(librga.keys() - island.keys()):
        expected = LIBRGA_ONLY_EXPECTED.get(key)
        if expected is None:
            failures.append(
                f"{key[0]} {key[1]}: present in librga (value {librga[key]}) but absent from the "
                "island header, and not declared in LIBRGA_ONLY_EXPECTED"
            )
        elif expected[0] != librga[key]:
            failures.append(
                f"{key[0]} {key[1]}: librga-only value moved "
                f"(recorded {expected[0]}, now {librga[key]})"
            )

    if len(compared_ioctls) < MIN_IOCTLS:
        failures.append(
            f"only {len(compared_ioctls)} ioctl values compared, contract requires >= {MIN_IOCTLS}"
        )
    if len(compared_sizes) < MIN_STRUCT_SIZES:
        failures.append(
            f"only {len(compared_sizes)} struct sizes compared, contract requires "
            f">= {MIN_STRUCT_SIZES}"
        )

    print(
        f"uapi-parity: compared {len(compared_ioctls)} ioctl values, "
        f"{len(compared_sizes)} struct sizes, {compared_members} member offsets "
        f"({len(island.keys() & librga.keys())} entries in common)"
    )
    print(
        f"uapi-parity: {len(DECLARED_DIVERGENCES)} declared divergences, "
        f"{len(ISLAND_ONLY_EXPECTED)} island-only symbols, "
        f"{len(LIBRGA_ONLY_EXPECTED)} librga-only symbols"
    )

    if args.emit_doc:
        pin = read_pin(args.pin_env) if args.pin_env else {}
        write_doc(
            args.emit_doc,
            pin=pin,
            target_arch=island_arch,
            runner=runner.describe(),
            island=island,
            librga=librga,
            ioctls=compared_ioctls,
            sizes=compared_sizes,
            member_count=compared_members,
            failures=failures,
        )
        print(f"uapi-parity: wrote {args.emit_doc}")

    if failures:
        print(f"\nuapi-parity: FAIL --- {len(failures)} problem(s):", file=sys.stderr)
        for f in failures:
            print(f"  {f}", file=sys.stderr)
        return 1

    print("uapi-parity: PASS")
    return 0


# --------------------------------------------------------------------------
# Generated documentation
# --------------------------------------------------------------------------


def write_doc(
    path: Path,
    *,
    pin: dict[str, str],
    target_arch: str,
    runner: str,
    island: dict[tuple[str, str], int],
    librga: dict[tuple[str, str], int],
    ioctls: list[tuple[str, int]],
    sizes: list[tuple[str, int]],
    member_count: int,
    failures: list[str],
) -> None:
    ref = pin.get("ISLAND_REF", "(unknown)")
    repo = pin.get("ISLAND_REPO", "CERALIVE/rk3588-media-island")
    hpath = pin.get("ISLAND_RGA_H_PATH", "(unknown)")
    hsha = pin.get("ISLAND_RGA_H_SHA256", "(unknown)")

    lines: list[str] = []
    add = lines.append

    add("# multi_rga UAPI parity")
    add("")
    add(
        "**Generated file. Do not edit by hand.** Produced by "
        "`tests/uapi-parity/compare.py --emit-doc` and refreshed by the `uapi-parity` "
        "Meson test."
    )
    add("")
    add(
        "This fork talks to the RK3588 `multi_rga` driver through a private ioctl ABI. "
        "Nothing in the compiler, the linker, or the packaging notices when the driver "
        "moves a field and librga does not: the mismatch shows up as a corrupt blit or a "
        "silently ignored parameter on a board. This gate makes that failure a build "
        "failure instead. It compiles the island's own driver header and librga's own "
        "headers as two independent translation units at the target ABI, then compares "
        "every ioctl number, struct size, and member offset the two have in common."
    )
    add("")
    add("## Pinned island coordinate")
    add("")
    add("| Field | Value |")
    add("| --- | --- |")
    add(f"| Repository | `{repo}` |")
    add(f"| Ref | `{ref}` |")
    add(f"| Header path | `{hpath}` |")
    add(f"| SHA-256 | `{hsha}` |")
    add("")
    add(
        "The ref is a published release tag, never a branch: a branch would move under "
        "the pin and silently change what this gate asserts. The header is fetched from "
        "`raw.githubusercontent.com` and rejected unless its bytes hash to the value "
        "above, so no local checkout of the island is read or required."
    )
    add("")
    add("## This run")
    add("")
    add(f"- Target ABI: **{target_arch}**")
    add(f"- Emitters executed via: {runner}")
    if target_arch != "aarch64":
        add(
            f"- **This was a {target_arch} smoke run.** Struct layout is ABI-specific, so a "
            "green result here does not prove aarch64 parity; the CI job and the board "
            "gate run the aarch64 build."
        )
    add(f"- ioctl values compared: **{len(ioctls)}**")
    add(f"- struct sizes compared: **{len(sizes)}**")
    add(f"- member offsets compared: **{member_count}**")
    add(f"- Result: **{'FAIL' if failures else 'PASS'}**")
    add("")

    add("## ioctl numbers")
    add("")
    add("| Symbol | Value | Hex |")
    add("| --- | --- | --- |")
    for name, value in sorted(ioctls):
        add(f"| `{name}` | {value} | `0x{value:x}` |")
    add("")

    add("## Struct sizes and member offsets")
    add("")
    add(
        "Sizes are bytes at the target ABI. `sizeof(struct rga_req)` is the load-bearing "
        "one: it is the request block handed to the driver on every blit."
    )
    add("")
    add("| Struct | sizeof | members compared |")
    add("| --- | --- | --- |")
    for name, value in sorted(sizes):
        n_members = sum(1 for (k, nm) in island if k == "off" and nm.startswith(name + "."))
        alias = TYPE_ALIASES.get(name)
        label = f"`{name}`" + (f" (librga `{alias}`)" if alias else "")
        add(f"| {label} | {value} | {n_members} |")
    add("")

    add("## Reconciled member renames")
    add("")
    add(
        "The same field, spelled differently on each side. Offsets and widths must still "
        "agree exactly; only the identifier differs."
    )
    add("")
    add("| island | librga |")
    add("| --- | --- |")
    for librga_name, island_name in sorted(MEMBER_ALIASES.items(), key=lambda kv: kv[1]):
        add(f"| `{island_name}` | `{librga_name}` |")
    add("")

    add("## Declared divergences")
    add("")
    if DECLARED_DIVERGENCES:
        add(
            "Real disagreements, recorded with both sides' current values. These are "
            "findings to fix, not exemptions: if either side moves again the recorded "
            "pair stops matching and the gate fails."
        )
        add("")
        add("| Entry | island | librga | Why it is recorded |")
        add("| --- | --- | --- | --- |")
        for (kind, name), (a, b, why) in sorted(DECLARED_DIVERGENCES.items()):
            add(f"| `{kind} {name}` | {a} | {b} | {why} |")
    else:
        add("None. The two sides agree on every entry they share.")
    add("")

    add("## Symbols present on one side only")
    add("")
    add("| Symbol | Side | Value | Why |")
    add("| --- | --- | --- | --- |")
    for (kind, name), (value, why) in sorted(ISLAND_ONLY_EXPECTED.items()):
        add(f"| `{name}` | island | `0x{value:x}` | {why} |")
    for (kind, name), (value, why) in sorted(LIBRGA_ONLY_EXPECTED.items()):
        add(f"| `{name}` | librga | `0x{value:x}` | {why} |")
    add("")
    add(
        "Their values are pinned here too, so a renumber on either side is caught even "
        "though there is nothing to compare it against."
    )
    add("")

    add("## Regenerating")
    add("")
    add("```sh")
    add("# QEMU_LD_PREFIX is for Meson's own configure-time sanity binary, which is")
    add("# dynamically linked. The parity emitters themselves are linked -static.")
    add("export QEMU_LD_PREFIX=/usr/aarch64-linux-gnu")
    add("meson setup build-parity --cross-file tests/uapi-parity/aarch64.cross")
    add("meson test -C build-parity uapi-parity uapi-parity-stubs")
    add("```")
    add("")
    add(
        "Moving the pin is a deliberate act: edit `tests/uapi-parity/island-pin.env`, "
        "re-run `tests/uapi-parity/fetch-island-header.sh`, and record the new SHA-256 in "
        "the same commit as the diff that justifies it."
    )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())
