# Chiptorio

Factorio 2.1 total-conversion mod (Lua, no Space Age, Nauvis only). `DESIGN.md` is the authoritative design and architecture document; read §15 before changing prototypes and §16 before changing behaviour. `changelog.txt` and `info.json` are the release record.

## Verify

- There is no build, lint, typecheck, or test-runner step. Verification is headless Factorio:
  - `powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1` copies the mod to `%TEMP%\chiptorio-test`, loads the data stage, creates a map, runs 600 ticks, and scans `%APPDATA%\Factorio\factorio-current.log`.
  - `powershell -ExecutionPolicy Bypass -File tools\test-all.ps1` runs the smoke test and the contract probe. The probe is a separate test mod in `tools/test-probe/`; it asserts the data contract after all mods load and checks the runtime on a fresh map.
- Every script resolves Factorio from `-Factorio`, `FACTORIO_EXE`, a repository-root `.env`, then auto-detected Steam/common install paths. Keep path logic in `tools/common.ps1`; do not hardcode a local install. `.env` is gitignored and `.env.example` is the tracked template. Use `-Keep` to inspect the temporary save and log.
- The test log markers are `CHIPTORIO-TEST PASS <suite>` and `CHIPTORIO-TEST FAIL <suite>`. New tests must add a marker and a matching assertion in the PowerShell wrapper.

## Load-stage rules

- `data.lua` is order-sensitive: items and fluids, then machines and labs, then recipes and technologies. `data-updates.lua` is only for vanilla mutations after all mods load.
- Every `scripts/*.lua` module must be explicitly required from a load-stage entrypoint; the directory is not auto-loaded.
- `data-updates.lua` hides the vanilla lab and retargets the first-science trigger to `analytical-engine`. Its load-time assertions prevent a fresh-save softlock; do not remove them.
- `scripts/prune.lua` removes enemies, robots, and combat. It hides prototypes and disables recipes instead of deleting them, because deleting an item means scrubbing every prototype that references it. It then removes empty technologies and rewires prerequisites. Add new removals to the tables in that module, not ad-hoc loops in `data-updates.lua`.
- Enemies are disabled by clearing `autoplace` on the base spawner and worm prototypes. Do not delete the `enemy-base` autoplace control: the base planet map-generation tables still reference it.
- Prototypes are cloned and tinted from base entities via `scripts/util.lua`; do not add custom entity art. Keep the six vanilla science-pack internal names and change only their localised names and recipes, or the vanilla tech tree breaks. See DESIGN §3.1 for the mapping.
- Every research computer must accept every workload plus `microprocessor`; `scripts/labs.lua` appends and asserts these inputs. Never gate packs by lab generation, which can deadlock the vanilla tech tree.
- Adding a workload means creating the item, appending it to every lab's `inputs`, using it in technology ingredients, and updating `scripts/answer_meta.lua`.
- DESIGN §15 also lists 2.1 API traps: recipe `categories` versus `category`, no fluid ingredients in the `crafting` category, positional technology ingredients, `icon` versus `icons`, and `__1__` locale placeholders.

## Runtime rules

- `control.lua` owns the single `script.on_nth_tick(60)` dispatcher and the `on_init` / `on_configuration_changed` handlers. Modules expose plain functions; they must not register those events themselves, or one module will silently replace another.
- Persist runtime state in `storage`, initialized from `on_init` and `on_configuration_changed`, never in module globals.
- The throughput gate is gone. Do not reintroduce production-rate gates; the redesign gates research on network compute, memory, and bandwidth (DESIGN §7).
- `scripts/rates.lua` still backs the old Answer Engine until the Phase 7 rework. `get_flow_count` reports production only when `category = "input"`.
- The Answer Engine is a lab clone with no inputs; its 42-minute clock, GUI, scoring, and victory screen live in `scripts/answer_engine.lua`, not in ordinary research.

## Generated assets, locale, release

- `tools/make-icons.ps1` regenerates all item icons, technology icons, `thumbnail.png`, and `graphics/answer-ending.png`. Do not hand-edit generated PNGs. A new icon needs a `Save-Icon` call and an entry in the contact-sheet `$order`; a new technology also needs an entry in `$techIcons`.
- `tools/make-sound.ps1` rebuilds `sound/answer-fanfare.ogg` and requires `ffmpeg` on `PATH`.
- Add `locale/en/locale.cfg` entries for new items, entities, and technologies; placeholders are `__1__`, not `%s`.
- Release: bump `info.json` `version` and add a dated `changelog.txt` entry under Features/Balance/Bugfixes, newest first.

## Debug hooks

- `/c remote.call("chiptorio-answer", "status")` logs engine state; `debug_complete` exercises the victory and score path.
