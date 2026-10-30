# Chiptorio — Agent Instructions

This file contains conventions for coding agents working in this repository.
User-facing documentation is in [`README.md`](README.md) and
[`docs/`](docs/). The authoritative design is in [`DESIGN.md`](DESIGN.md).
The gap register is in [`TODO.md`](TODO.md).

## Verify

Verification is headless Factorio. There is no build, lint, typecheck, or
test-runner step.

- `tools\test-all.ps1` — smoke test → contract → registration audit →
  save/load → power-grid → performance. Any failure exits non-zero.
- `tools\test-contract.ps1` — probe-only iteration; `-Ticks` must be a
  multiple of 60 (default 300).
- `tools\test-power-grid.ps1` — power-grid-only iteration.
- `tools\test-perf.ps1` — performance-only iteration.
- `tools\test-registration.ps1` — registration audit-only iteration.
- `tools\test-save-load.ps1` — save/load-only iteration.
- `tools\run-mod.ps1` — links the working tree into `%TEMP%\chiptorio-dev\mods`,
  enables it, and launches a playable Factorio. `-Copy` snapshots the tree;
  `-NoWait` returns immediately.

All scripts resolve Factorio from `-Factorio`, `FACTORIO_EXE`, a repository
root `.env`, then auto-detected Steam/common install paths. Keep path logic in
`tools/common.ps1`; do not hardcode a local install. `.env` is gitignored and
`.env.example` is the tracked template. Use `-Keep` to inspect the temporary
save and log.

## Test log markers

`CHIPTORIO-TEST PASS <suite>` and `CHIPTORIO-TEST FAIL <suite>`. The wrapper
requires `PASS unit`, `PASS data`, `PASS runtime`, `PASS force-isolation`,
`PASS power-grid` and `PASS playthrough`. A new suite must add a marker and a
matching assertion in the PowerShell wrapper. Keep
`unit_harness.finish` after all unit specs: calling it inside one spec hides
later failures.

`--benchmark` raises all `on_nth_tick`/`on_tick` handlers only at tick 0 and
does not dispatch script events for later ticks. Multi-tick checks (power
grid) must run on a real headless server, not a benchmark.

## Where to find things

| Topic | Location |
|-------|----------|
| Overview, features, installation | `README.md`, `docs/overview.md`, `docs/installation.md` |
| Test scripts, markers, procedures | `docs/testing.md` |
| Runtime architecture, module map | `docs/architecture.md` |
| Load-stage rules, prototype conventions | `docs/prototypes.md` |
| Generated assets, locale, release | `docs/assets.md` |
| Debug hooks, remote interfaces | `docs/debug.md` |
| P1 verification status | `docs/p1-verification.md` |
| Authoritative design | `DESIGN.md` (§15 before prototypes, §16 before behaviour) |
| Gap register | `TODO.md` |

## Key rules (summary; full details in docs/)

- `data.lua` is order-sensitive: items and fluids, then machines and labs,
  then recipes and technologies. `data-updates.lua` is only for vanilla
  mutations after all mods load.
- `data.lua` must keep `require("scripts.network")`.
- `scripts/process_nodes.lua` is pure and is the single source of truth for
  the twelve process nodes, ten half-nodes, node item names, die yields and
  the half-node bonus.
- Chips and memory modules are `module` prototypes; check items with
  `M.item_exists`, not `data.raw.item`.
- Compute providers are lab clones with `inputs = {}` and
  `researching_speed = 0.001`. Never set `allowed_effects` on a lab clone.
- Every `scripts/*.lua` module must be explicitly required from a
  load-stage entrypoint; require each module once, from the stage that owns it.
- `control.lua` owns the single `script.on_nth_tick(60)` dispatcher. Modules
  expose plain functions; they must not register events themselves.
- Persist runtime state in `storage`, initialized from `on_init` and
  `on_configuration_changed`, never in module globals.
- Labs are paused with `disabled_by_script`, never deleted.
- `scripts/research_meta.lua` is the single source of truth for lab demand,
  chip and memory profiles, provider slots and every technology gate.
- `scripts/runtime/research_alloc.lua` is the pure allocator;
  `scripts/runtime/research_runtime.lua` is the only research module that
  touches entities and `storage`.
- `scripts/runtime/network_graph.lua` is pure: no `game`, no `storage`, no
  prototypes.
- `network_runtime` must not require `qualification_runtime` or `qln_runtime`.
  Both monitor sections and the multiplier setter are registered through
  `network.set_qualification_provider`, `network.set_qln_provider` and plain
  calls.
- `scripts/prune.lua` removes enemies, robots, and combat. It hides prototypes
  and disables recipes instead of deleting them. Add new removals to the
  tables in that module, not ad-hoc loops in `data-updates.lua`.
- Enemies are disabled by clearing `autoplace` on the base spawner and worm
  prototypes. Do not delete the `enemy-base` autoplace control.
- Prototypes are cloned and tinted from base entities via `scripts/util.lua`;
  do not add custom entity art.
- Keep the six vanilla science-pack internal names; change only localised
  names and recipes.
- DESIGN §15 lists 2.1 API traps: recipe `categories` vs `category`, no fluid
  ingredients in `crafting`, positional technology ingredients, `icon` vs
  `icons`, and `__1__` locale placeholders.

## Generated assets, locale, release

- `tools\make-icons.ps1` regenerates all item icons, technology icons, the
  sixteen cable world sprites, `thumbnail.png`, and
  `graphics/answer-ending.png`. Do not hand-edit generated PNGs.
- `tools\make-sound.ps1` rebuilds `sound/answer-fanfare.ogg` and requires
  `ffmpeg` on `PATH`.
- Add `locale/en/locale.cfg` entries for new items, entities, and
  technologies; placeholders are `__1__`, not `%s`.
- Release: bump `info.json` `version` and add a dated `changelog.txt` entry
  under Features/Balance/Bugfixes, newest first.

## Debug hooks

- `/c remote.call("chiptorio-answer", "status")` — logs engine state
- `/c remote.call("chiptorio-network", "status")` — logs cable/segment/network
  counts
- `/c remote.call("chiptorio-research", "status")` — logs gate, decay, labs
- `/c remote.call("chiptorio-qualification", "status")` — logs half-node state
- `/c remote.call("chiptorio-qln", "status")` — logs drives, items, capacity
