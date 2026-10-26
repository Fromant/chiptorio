# Chip'torio

Factorio 2.1 total-conversion mod (Lua, no Space Age, Nauvis only). `DESIGN.md` is the authoritative design and architecture document; read §8 before changing prototypes. `changelog.txt` and `info.json` are the release record.

## Verify

- There is no build, lint, typecheck, or test-runner step. Verification is headless Factorio:
  - `powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1` copies the mod to `%TEMP%\chipotrio-test`, loads the data stage, creates a map, runs 600 ticks, and scans `%APPDATA%\Factorio\factorio-current.log`.
  - `powershell -ExecutionPolicy Bypass -File tools\test-gate.ps1` runs the throughput-gate regression. Its `-Ticks` value must be a multiple of 60.
- Both scripts default to the Windows Steam Factorio path; pass `-Factorio <path>` when installed elsewhere. Use `-Keep` to inspect the temporary save and log.
- `test-gate.ps1` hard-codes the technologies needed to start `photolithography`; update that seed list when changing its prerequisites. If you intentionally change gate-decay behavior, update both the assertion and the docs.

## Load-stage rules

- `data.lua` is order-sensitive: items and fluids, then machines and labs, then recipes and technologies. `data-updates.lua` is only for vanilla mutations after all mods load.
- Every `scripts/*.lua` module must be explicitly required from a load-stage entrypoint; the directory is not auto-loaded.
- `data-updates.lua` hides the vanilla lab and retargets the first-science trigger to `analytical-engine`. Its load-time assertions prevent a fresh-save softlock; do not remove them.
- Prototypes are cloned and tinted from base entities via `scripts/util.lua`; do not add custom entity art. Keep the six vanilla science-pack internal names and change only their localised names and recipes, or the vanilla tech tree breaks. See DESIGN §3.1 for the mapping.
- Every research computer must accept every workload plus `microprocessor`; `scripts/labs.lua` appends and asserts these inputs. Never gate packs by lab generation, which can deadlock the vanilla tech tree.
- Adding a workload means creating the item, appending it to every lab's `inputs`, using it in technology ingredients, and updating `scripts/answer_meta.lua`.
- `scripts/tech_meta.lua` is pure data read by both the data stage (tooltips) and runtime (enforcement); keep gate numbers there.
- DESIGN §8 also lists 2.1 API traps: recipe `categories` versus `category`, no fluid ingredients in the `crafting` category, positional technology ingredients, `icon` versus `icons`, and `__1__` locale placeholders.

## Runtime rules

- `control.lua` owns the single `script.on_nth_tick(60)` dispatcher. Add new tick work to that callback instead of registering another handler; other events are registered inside their modules.
- Persist runtime state in `storage`, initialized from `on_init` and `on_configuration_changed`, never in module globals.
- Throughput is production on Nauvis over a rolling one minute via `scripts/rates.lua`. In `get_flow_count`, `category = "input"` is production; stockpiles and consumption must not satisfy a gate.
- The Answer Engine is a lab clone with no inputs; its 42-minute clock, GUI, scoring, and victory screen live in `scripts/answer_engine.lua`, not in ordinary research.

## Generated assets, locale, release

- `tools/make-icons.ps1` regenerates all item icons, technology icons, `thumbnail.png`, and `graphics/answer-ending.png`. Do not hand-edit generated PNGs. A new icon needs a `Save-Icon` call and an entry in the contact-sheet `$order`; a new technology also needs an entry in `$techIcons`.
- `tools/make-sound.ps1` rebuilds `sound/answer-fanfare.ogg` and requires `ffmpeg` on `PATH`.
- Add `locale/en/locale.cfg` entries for new items, entities, and technologies; placeholders are `__1__`, not `%s`.
- Release: bump `info.json` `version` and add a dated `changelog.txt` entry under Features/Balance/Bugfixes, newest first.

## Debug hooks

- `/c remote.call("chipotrio", "rates")` prints per-force gate rates.
- `/c remote.call("chipotrio-answer", "status")` logs engine state; `debug_complete` exercises the victory and score path.
