# Chiptorio — P1 Verification Status

P1 items are correctness, compatibility, and verification work that protects
the P0 mechanics. `[x]` done · `[ ]` open.

| ID | Item | Status | Method |
|----|------|--------|--------|
| P1.2 | Save/load | `[x]` | `tools/test-save-load.ps1` — hosted server + reload benchmark |
| P1.4 | Determinism | `[x]` | Code review — no non-deterministic `pairs()` in render/state paths |
| P1.5 | Perf harness | `[x]` | `tools/test-perf.ps1` — benchmark with timing parse, budget 1000 us/tick avg |
| P1.6 | Player/GUI | `[ ]` | Not automatable — Factorio 2.1 has no `game.create_player` |
| P1.7 | Power grid | `[x]` | `tools/test-power-grid.ps1` — hosted server, Construction Core charge/isolate |
| P1.8 | Registration audit | `[x]` | `tools/test-registration.ps1` — static scan of `scripts/*.lua` |
| P1.9 | Locale translations | `[x]` | `tools/test-probe/data-updates.lua` — locale + icon check |

All automated P1 items are asserted by `tools/test-all.ps1`.

## P1.2 Save/load

Creates a map, hosts it from a headless server (`--start-server`) long enough
for the probe to build runtime state and write `chiptorio-reload.zip`, then
benchmarks that save and requires `PASS save-load`. Server auth is avoided via
`--server-settings` derived from the shipped example, overriding visibility
(public/lan false), empty credentials, `require_user_verification=false`,
`auto_pause=false`, `--bind 127.0.0.1 --port 34199`. Save path is redirected
via generated `config.ini` with `[path] read-data=<gameRoot>\data`,
`write-data=<temp>`. Save/load verification uses a dedicated force
`chiptorio-saveload` so player-force state stays untouched.

## P1.5 Perf harness

Creates a fresh map, runs a benchmark with `--benchmark-verbose timings`,
parses the Factorio per-tick update-time summary from stdout, and fails if
the average update time exceeds the budget (default 1000 us/tick) or the
maximum exceeds 50000 us/tick.

## P1.7 Power grid

The Construction Core is an accumulator clone: `entity.energy` is its work
budget and it refills from the grid while idle. A solar panel charges the
core across real ticks, then the panel is removed and the core must hold its
charge. Runs on a live headless server because `--benchmark` cannot dispatch
tick handlers after tick 0.

## P1.8 Registration audit

Statically scans all `scripts/*.lua` files (except `control.lua`) and fails
if any module registers `script.on_event`, `script.on_nth_tick`,
`script.on_init`, `script.on_configuration_changed`, or
`remote.add_interface`. `answer_engine.lua` and `qln_runtime.lua` are
permitted to register their own remote interfaces
(`chiptorio-answer`, `chiptorio-qln`); `control.lua` guards those with
`if not remote.interfaces[...]`.

## P1.9 Locale translations

Data-stage pass in `tools/test-probe/data-updates.lua` asserts every
Chiptorio-created item, entity, technology, recipe, and fluid has a locale
entry in `locale/en/locale.cfg` and an icon.
