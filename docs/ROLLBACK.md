# Rollback — putting Radxa's `librga2` back

## The command

```bash
apt-get install --yes --allow-downgrades ./librga2_2.2.0-1_arm64.deb
```

That is the whole procedure, and it is the **only** rollback command a board
drill may use. It is written here because it was executed and observed to work,
not because it is the obvious thing to type — see *What was actually run* below
for the transcript this line came from.

The `.deb` is the one the device image pins:

```text
https://radxa-repo.github.io/rk3588s2-bookworm/pool/main/libr/librga/librga2_2.2.0-1_arm64.deb
sha256  ca4f18666f6c5d5290c7e41e5901350ecf76530f24364e37b81fa6be4ab5f344
```

The leading `./` is not decoration. `apt-get install` treats an argument as a
local file only when it starts with `/` or `./`; drop the prefix and apt parses
`librga2_2.2.0-1_arm64.deb` as `package/release` syntax and fails with a
misleading "Release … was not found".

`--allow-downgrades` is needed because `librga2-ceralive` provides
`librga2 (= 2.2.0)`, and apt treats installing the real `librga2 2.2.0-1` over
that provider as a version regression.

## What rollback does to everything else

Nothing has to be removed by hand. `apt` resolves the whole transition in one
step:

- `librga2-ceralive` is removed, because Radxa's `librga2` is the package our
  `Conflicts: librga2` names.
- Packages that depend on `librga2` — on a device that is
  `gstreamer1.0-rockchip-ceralive` — **stay installed**. They were satisfied by
  our `Provides: librga2 (= 2.2.0)` before, and are satisfied by the real package
  after.
- `librga-ceralive-dev` is not part of this. It is not installed on a device.

`dpkg` prints a "dependency problems, but removing anyway" line while it takes
`librga2-ceralive` out. That is expected: it is describing the intermediate state
between removing the old provider and configuring the new one, and the
transaction ends with every dependency satisfied. It is not a failure and it is
not something to work around.

## The forward direction, for completeness

```bash
apt-get install --yes ./librga2-ceralive_<version>_arm64.deb
```

No `--allow-downgrades`. Radxa's `librga2` comes out, `librga2-ceralive` goes in,
and dependents stay installed.

## What was actually run

`ci/transition-test.sh` performs both directions and writes the rollback command
that passed into the file named by `ROLLBACK_RECORD`. This document quotes that
file rather than a command someone believed would work.

The run behind the text above:

```text
=== forward: Radxa librga2 + dependent  ->  librga2-ceralive ===
The following packages will be REMOVED:  librga2
The following NEW packages will be installed:  librga2-ceralive
forward: PASS (librga2 removed, dependent retained)

=== rollback: librga2-ceralive  ->  Radxa librga2 ===
The following packages will be REMOVED:  librga2-ceralive
The following NEW packages will be installed:  librga2
rollback: PASS (librga2-ceralive removed, dependent retained)

the rollback command that passed:
  apt-get install --yes --allow-downgrades ./librga2_2.2.0-1_arm64.deb
transition-test: OK
```

Conditions: a clean `debian:trixie-slim` arm64 root — the target suite from
`ci/target-suite.env` — with the pinned Radxa `.deb` above (sha256 verified
before use) and a stub package declaring `Depends: librga2`, standing in for
`gstreamer1.0-rockchip-ceralive`.

**The documented `dpkg --remove --force-depends` fallback was not needed.** apt
solved the rollback directly. If a future suite or a future dependency graph
makes apt refuse, `ci/transition-test.sh` falls back to

```bash
dpkg --remove --force-depends librga2-ceralive
dpkg -i ./librga2_2.2.0-1_arm64.deb
apt-get -f install
```

and records *that* as the passing command instead. If it ever does, this file is
updated from the recorded output — the rule is that the command here is the one
the test observed, never the one that seemed reasonable.

## What this does NOT prove

Stated plainly, because a passing transition test reads like more than it is:

- **It has not run on an RK3588 board.** The drill above ran in a container on
  the target suite and architecture. It proves the package relationships resolve
  the way they are supposed to; it says nothing about the RGA hardware, `/dev/rga`,
  or anything the library does once loaded. The board gate is a separate step.
- **It does not cover a device with a running stream.** Replacing a shared object
  under a live process leaves the old mapping in place until restart. Rollback on
  a streaming device is a stop-then-roll-back operation.
- **It was executed under `qemu-aarch64`**, not on native arm64 silicon. That
  affects nothing here — every assertion is about dpkg and apt state, not code
  generation — but it is recorded so nobody has to guess later.
