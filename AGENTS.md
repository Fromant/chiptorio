# Chiptorio — Agent Instructions

Chiptorio is a Factorio 2.1 Lua total conversion ("computation is the economy").
There is **no build step**: `data.lua`/`data-updates.lua` define prototypes and
`control.lua` runs at runtime. All verification is headless Factorio via
`tools/*.ps1`. Target: Factorio 2.1, no Space Age, Nauvis only.

## Verify

- `tools\test-all.ps1` — smoke → contract → registration audit → save/load →
  power-grid → performance. Any failure exits non-zero.
- `tools\test-contract.ps1` — probe-only iteration; `-Ticks` must be a multiple
  of 60 (default 300).
- `tools\test-power-grid.ps1` — power-grid-only iteration.
- `tools\test-perf.ps1` — performance-only iteration.
- `tools\test-registration.ps1` — registration audit-only iteration.
- `tools\test-save-load.ps1` — save/load-only iteration.
- `tools\run-mod.ps1` — links the tree into `%TEMP%\chiptorio-dev\mods`,
  enables it, and launches Factorio. `-Copy` snapshots the tree; `-NoWait`
  returns immediately. Use `-Keep` on test scripts to inspect the temp save/log.

Factorio resolution order: `-Factorio` → `FACTORIO_EXE` env → repository-root
`.env` → auto-detected Steam/common install. Path logic lives in
`tools/common.ps1`; do not hardcode a local install. `.env` is gitignored;
`.env.example` is the template.

## Test log markers

`CHIPTORIO-TEST PASS <suite>` / `CHIPTORIO-TEST FAIL <suite>` in
`factorio-current.log`. `test-contract.ps1` requires `PASS unit`, `PASS data`,
`PASS runtime`, `PASS force-isolation`, `PASS power-grid` and `PASS playthrough`.
A new suite needs a marker plus a matching assertion in the PowerShell wrapper.
Keep `unit_harness.finish` after all unit specs: calling it inside one spec
hides later failures.

`--benchmark` dispatches `on_nth_tick`/`on_tick` handlers only at tick 0 and no
script events after. Multi-tick checks (power grid) need a real headless
server, not a benchmark.

`tools/test-probe/` is a separate test mod that loads after chiptorio. Pure
modules are unit-tested through cross-mod `require("__chiptorio__/scripts/…")`,
so adding `game`, `storage`, or `data` access to a pure module breaks the unit
suite. Require new specs from `tools/test-probe/data.lua` before
`unit_harness.finish`; new runtime suites go in `tools/test-probe/control.lua`.

## Where to find things

`docs/testing.md` — test procedures and markers
`docs/installation.md` — play and test commands
`docs/architecture.md` — runtime architecture, module map
`docs/prototypes.md` — load-stage rules, prototype conventions
`docs/assets.md` — generated assets, locale, release
`docs/debug.md` — debug hooks, remote interfaces
`DESIGN.md` — authoritative design; read §15 before prototypes, §16 before behaviour
`TODO.md` — gap register

## Key rules

- `data.lua` is order-sensitive: items/fluids → machines/labs → recipes/technologies.
  `data-updates.lua` is only for vanilla mutations after all mods load.
- `data.lua` must keep `require("scripts.network")`.
- Every `scripts/*.lua` module is explicitly required once from the load-stage
  entrypoint that owns it; the directory is not auto-loaded.
- `control.lua` owns the single `script.on_nth_tick(60)` dispatcher. Modules
  expose plain functions; they never register events themselves.
- Persist runtime state in `storage`, initialized from `on_init` and
  `on_configuration_changed`, never in module globals.
- Labs are paused with `disabled_by_script`, never deleted.
- `scripts/process_nodes.lua` is pure: single source of truth for the twelve
  process nodes, ten half-nodes, die yields, half-node bonus.
- `scripts/research_meta.lua` is the single source of truth for lab demand,
  chip/memory profiles, provider slots, technology gates.
- `scripts/runtime/research_alloc.lua` is the pure allocator;
  `scripts/runtime/research_runtime.lua` is the only research module touching
  entities and `storage`.
- `scripts/runtime/network_graph.lua` is pure: no `game`, `storage`, prototypes.
- `network_runtime` must not require `qualification_runtime` or `qln_runtime`;
  qualification/QLN monitors and the multiplier setter are registered through
  `network.set_qualification_provider`, `network.set_qln_provider` and plain calls.
- `scripts/prune.lua` removes enemies/robots/combat: hides prototypes and
  disables recipes instead of deleting. Add removals to its tables, not ad-hoc
  loops in `data-updates.lua`.
- Enemies are disabled by clearing `autoplace` on the base spawner and worm
  prototypes. Do not delete the `enemy-base` autoplace control.
- Prototypes are cloned and tinted from base entities via `scripts/util.lua`;
  no custom entity art.
- Keep the six vanilla science-pack internal names; change only localised names
  and recipes.
- Chips/memory modules are `module` prototypes; check with `M.item_exists`, not
  `data.raw.item`. Compute providers are lab clones with `inputs = {}` and
  `researching_speed = 0.001`; never set `allowed_effects` on a lab clone.
- DESIGN §15 2.1 API traps: recipe `categories` vs `category`, no fluid
  ingredients in `crafting`, positional technology ingredients, `icon` vs
  `icons`, `__1__` locale placeholders (not `%s`).

## Generated assets, locale, release

- Entity/icon/cable/presentation production uses the shared approval-gated Node
  pipeline in `tools/asset-studio/`; read `docs/asset-pipeline.md`. No direct-install
  legacy render commands or new PowerShell wrappers. Drafts/candidates are staged;
  visual approval, isolated validation and explicit publication are separate gates.
  Earlier approved assets stay locked; never auto-unlock/rebuild them.

- `tools\make-icons.ps1` regenerates item/technology icons, cable sprites,
  `thumbnail.png`, `graphics/answer-ending.png`. Do not hand-edit generated PNGs.
- `tools\make-sound.ps1` rebuilds `sound/answer-fanfare.ogg`; needs `ffmpeg` on `PATH`.
- Add `locale/en/locale.cfg` entries for new items, entities, technologies;
  placeholders are `__1__`.
- Release: bump `info.json` `version`, add a dated `changelog.txt` entry under
  Features/Balance/Bugfixes (newest first), and update README Status, DESIGN
  header, and TODO.md version/date so the three cannot drift.

## Debug hooks

- `/c remote.call("chiptorio-answer", "status")` — engine state
- `/c remote.call("chiptorio-network", "status")` — cable/segment/network counts
- `/c remote.call("chiptorio-research", "status")` — gate, decay, labs
- `/c remote.call("chiptorio-qualification", "status")` — half-node state
- `/c remote.call("chiptorio-qln", "status")` — drives, items, capacity
