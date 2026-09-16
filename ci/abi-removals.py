#!/usr/bin/env python3
# Modified by CeraLive 2026-09-14: reconcile exact removed ELF names before suppression.
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Used by check-abi.sh: REPORT EXPECTED_TSV OUTPUT_SUPPRESSIONS."""

import re
import sys
from pathlib import Path


def main() -> None:
    """Fail closed on stale lists or incomplete reports; emit deletion-only rules."""
    report_path, expected_path, output_path = map(Path, sys.argv[1:])
    expected: set[str] = set()
    for number, line in enumerate(expected_path.read_text().splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        symbol, separator, reason = line.partition("\t")
        if not separator or not reason.strip() or not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", symbol):
            sys.exit(f"ABI: invalid allowlist entry at {expected_path}:{number}")
        if symbol in expected:
            sys.exit(f"ABI: duplicate allowlist entry: {symbol}")
        expected.add(symbol)

    report = report_path.read_text()
    summaries = re.findall(
        r"^(?:Functions|Variables|Function symbols|Variable symbols) changes summary: (\d+) Removed[, ]",
        report, re.MULTILINE,
    )
    if report.strip() and len(summaries) < 2:
        sys.exit("ABI: unrecognized abidiff summary")
    removed: dict[str, str] = {}
    kind = ""
    entries = 0
    for line in report.splitlines():
        heading = re.fullmatch(r"\d+ Removed (function|variable)s?(?: symbols? not referenced by debug info)?:", line)
        if heading:
            kind = heading[1]
        if not line.lstrip().startswith("[D]"):
            continue
        if not kind:
            sys.exit(f"ABI: removal outside a recognized section: {line}")
        entries += 1
        linkage = re.search(r"\{([^{}]+)\}\s*$", line)
        names = linkage[1] if linkage else line.split("[D]", 1)[1].strip()
        for symbol in re.split(r", (?:aliases )?", names):
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_.$@]*", symbol) or symbol in removed:
                sys.exit(f"ABI: unrecognized or duplicate removed symbol: {line}")
            removed[symbol] = kind
    if entries != sum(map(int, summaries)):
        sys.exit("ABI: removal details disagree with abidiff summary")

    actual = set(removed)
    if actual != expected:
        sys.exit(
            f"ABI: unexpected removals: {sorted(actual - expected)}\n"
            f"ABI: expected removals absent: {sorted(expected - actual)}"
        )
    # Literal ELF names plus deletion kind: never hide a surviving symbol's type change.
    output_path.write_text("".join(
        f"[suppress_{removed[symbol]}]\n"
        f"  symbol_name = {symbol}\n"
        f"  change_kind = deleted-{removed[symbol]}\n\n"
        for symbol in sorted(expected)
    ))
    print(f"ABI: exact removal set accepted ({len(expected)} symbols)")


if __name__ == "__main__":
    main()
