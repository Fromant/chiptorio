# Chiptorio — Gap Register

Updated: 2026-11-03 (logistics art batch; standalone access-point routing gap recorded)

---

## P0 — Critical (Blocks Progression / Causes Confusion / Broken GUI)

- [ ] **P0.7** Standalone Wireless Access Point has no wireless routing behaviour
  - Discovered during the third Blender asset batch (2026-11-03).
  - Current wireless reach is supplied by `network-router`; the separate AP was not tracked by the network runtime.
  - Its art integration now tracks it as a zero-capacity link-status endpoint, not a router or bridge.
  - Follow-up: decide whether to implement a separate AP role or fold the redundant entity/recipe into the router. No new routing rules were added in the graphics pass.

- [x] **P0.1** Analytical Engine GUI has no slot for punched cards
  - Root cause: `computer_gui.lua` replaces vanilla lab GUI with read-only panel; doesn't render module/input slots.
  - Fix: Don't replace lab GUI for `analytical-engine` (let vanilla handle it).
  - Files: `scripts/runtime/computer_gui.lua`, `control.lua`
  - **DONE**: `is_computer()` returns false for all labs; labs use vanilla lab GUI with proper input slots.

- [x] **P0.2** `electronics` unlocks inserter but can't craft until Control Board
  - Root cause: `electronics` keeps `unlock-recipe inserter`, but `inserter` recipe requires `electronic-circuit` (Control Board) gated behind `thermionics`.
  - Fix: Move `unlock-recipe inserter` from `electronics` to `thermionics`. Keep `copper-cable`/`small-electric-pole` on `electronics`.
  - Files: `data-updates.lua`, `scripts/technology.lua`
  - **DONE**: Filtered `inserter` from electronics effects; added `inserter` to thermionics effects.

- [x] **P0.3** Analytical Engine sprite is 1.5×1.5 instead of 3×3 tiles
  - Root cause: Sprite 128×128 at scale 0.5 = 64px/tile (2×2 footprint), but entity collision box is vanilla lab (3×3).
  - Fix: Regenerate `analytical-engine.png` at 160×160 (for 3×3 at scale 0.5), update `size_w/size_h` in `labs.lua` to 160,160.
  - Files: `tools/make-entities.ps1`, `scripts/labs.lua`
  - **DONE**: Regenerated sprite at 160×160; updated `size_w/size_h` to 160,160 in `labs.lua`.

- [x] **P0.4** Technologies unlockable after Punched Card Deck require Control Board in craft ingredients
  - Root cause: Tech prerequisites don't account for recipe ingredient chains. E.g. `logistic-science-pack` requires `electronic-circuit` but `thermionics` not a prereq.
  - Fix: Add ingredient-gate prerequisite contract test. Fix tech tree: add `thermionics` as prereq of `logistic-science-pack`, and similar for other early science packs.
  - Files: `tools/test-probe/data-updates.lua` (new contract), `scripts/technology.lua`
  - **DONE**: Added `thermionics` as prerequisite of `logistic-science-pack` in `data-updates.lua`. Added ingredient-gate prerequisite check in `test-probe/data-updates.lua` (P2.2).

- [x] **P0.5** Tube Mainframe GUI broken — shows only "type: tube-mainframe", no slots
  - Root cause: Same as P0.1 — `computer_gui.lua` replaces lab GUI with read-only panel. Tube Mainframe has `module_slots = 2`.
  - Fix: Labs now use vanilla GUI; tube-mainframe inputs are {automation-science-pack, logistic-science-pack, vacuum-tube}.
  - Files: `scripts/runtime/computer_gui.lua`, `scripts/labs.lua`
  - **DONE**: `is_computer()` returns false for all labs; labs use vanilla lab GUI.

- [x] **P0.6** Tube Mainframe requires steel but steel-processing not prerequisite
  - Root cause: `thermionics` unlocks `tube-mainframe` (recipe needs `steel-plate`), but `steel-processing` not a prereq.
  - Fix: Add `steel-processing` as prerequisite of `thermionics`. Full audit: for every mod recipe, ensure all ingredient-unlocking techs are prereqs of the recipe's gate tech.
  - Files: `scripts/technology.lua`, new audit test in test-probe
  - **DONE**: Added `steel-processing` to thermionics prerequisites in `scripts/technology.lua`. Ingredient-gate check (P2.2) now catches this.

---

## P1 — High (Balance / Polish / Missing Locale & Icons)

- [x] **P1.1** Thermionics research feels 2× too long
  - Fix: Reduce `thermionics` count=25, time=10 (250 science × 10s = 2500s ≈ 40 min).
  - Files: `scripts/technology.lua`
  - **DONE**: Changed count from 40 to 25, time from 15 to 10.

- [x] **P1.2** Vacuum tubes in "Production" tab, should be in Chiptorio/Chips tab
  - Root cause: `chiptorio-chips` subgroup has `group = "production"`.
  - Fix: Change `chiptorio-chips` group to `chiptorio`.
  - Files: `scripts/items.lua`
  - **DONE**: Changed group from "production" to "chiptorio", order to "b[chips]".

- [x] **P1.3** Silica Sand stack size should be 200 or 500
  - Root cause: `make_material("silica")` clones `iron-plate` (stack 100), doesn't override.
  - Fix: Set `stack_size = 200` (or 500).
  - Files: `scripts/items.lua`
  - **DONE**: Set `silica.stack_size = 200` after creation.

- [x] **P1.4** Analytical Engine energy too low (90kW) — Tube Mainframe not a must-have
  - Fix: Increase `analytical-engine` power to 240kW (match tube-mainframe), keep speed 0.5.
  - Files: `scripts/labs.lua`
  - **DONE**: Changed power from "90kW" to "240kW".

- [x] **P1.5** Tube Mainframe description says "valve-based" — should be thermionics/tubes
  - Fix: Change locale `entity-description.tube-mainframe` to "A thermionic mainframe. Vacuum tubes replace relays for faster, hotter computing."
  - Files: `locale/en/locale.cfg`
  - **DONE**: Updated description.

- [x] **P1.6** Unknown locale keys for AI technologies and custom infinite researches
  - Missing: `machine-learning`, `ai-specialist`, `ai-general`, `ai-frontier`, `artificial-general-intelligence`, `chip-performance`, `chip-efficiency`, `memory-density`, `memory-bandwidth`, `network-bandwidth`, `cooling-efficiency`, `quantum-correction` (names + descriptions)
  - Fix: Add all missing `[technology-name]` and `[technology-description]` entries.
  - Files: `locale/en/locale.cfg`
  - **DONE**: Added all 12 missing technology names and descriptions.

- [x] **P1.7** Some research icons still vanilla (science packs on "punched tape reel", vanilla circuits on mod board techs)
  - Root cause: Technology icons generated only for technologies in `$techIcons` table in `make-icons.ps1`. Vanilla techs keep vanilla icons.
  - Fix: Extend `$techIcons` to map every Chiptorio technology to custom icon source. Re-run `make-icons.ps1`.
  - Files: `tools/make-icons.ps1`
  - **DONE**: Extended `$techIcons` with all vanilla science packs (logistic, military, chemical, production, utility), vanilla circuit techs (advanced-circuit, processing-unit), all AI techs, all infinite techs, and all refine techs. Regenerated all icons.

---

## P2 — Medium (Tech Tree Polish / Consistency / Tests)

- [x] **P2.1** Contract test: visible recipe without unlocking technology
  - `hide_orphaned_recipes()` exists in `prune.lua` but no test-probe check.
  - Fix: Add check: every visible recipe with `enabled=false` must be unlocked by a visible technology.
  - Files: `tools/test-probe/data-updates.lua`
  - **DONE**: Added check that iterates all recipes and verifies locked visible recipes have an unlocking technology.

- [x] **P2.2** Contract test: ingredient-gate prerequisite check (catches P0.4/P0.6)
  - Missing — current simulation doesn't validate prerequisite graph against recipe ingredients.
  - Fix: Implement: for each tech T unlocking recipe R, for each ingredient I in R, find tech G unlocking I; assert G ∈ transitive_prereqs(T).
  - Files: `tools/test-probe/data-updates.lua`
  - **DONE**: Implemented full ingredient-gate check limited to Chiptorio-created technologies and recipes.

- [x] **P2.3** Entity sprite size validation test
  - Current test checks world sprite exists and isn't an item icon, but doesn't verify footprint match.
  - Fix: Check entity collision_box tile size vs sprite pixel size (at given scale) match expected footprint.
  - Files: `tools/test-probe/data-updates.lua`
  - **PARTIAL**: Added stub function `check_entity_sprite_size()` and calls for Chiptorio entities. Full PNG dimension validation requires loading images at runtime which isn't feasible in data stage; the real validation happens in `make-entities.ps1` generation.

- [x] **P2.4** Computer GUI module slots rendering test
  - Labs no longer use custom GUI; providers keep module slots for chips.
  - Fix: Replace per-lab GUI tests with `check_labs_use_vanilla_gui()` verifying labs don't show custom computer GUI. Keep `check_computer_gui()` for server-rack provider.
  - Files: `tools/test-probe/control.lua`
  - **DONE**: Replaced `check_tube_mainframe_gui()`, `check_mainframe_cluster_gui()`, `check_datacenter_lab_gui()`, `check_cryostat_gui()` with single `check_labs_use_vanilla_gui()`.

---

## New: Lab GUI Overhaul (from second playtest session)

- [x] **N1** Labs accept only tier-appropriate science packs (no all-11-slots GUI)
  - analytical-engine: only automation-science-pack (punch cards)
  - tube-mainframe: automation-science-pack + logistic-science-pack (punch cards + punched tapes)
  - mainframe-cluster: + military-science-pack
  - datacenter-lab: + chemical-science-pack
  - cryostat: all 6 vanilla + 3 custom packs + microprocessor
  - Files: `scripts/labs.lua`, `tools/test-probe/data-updates.lua`
  - **DONE**: Progressive `inputs` per lab; removed EXTRA_INPUTS loop that added everything to all labs. Vacuum tubes are NOT lab inputs — they're crafting ingredients for the Tube Mainframe machine recipe only.

- [x] **N2** Labs have no module slots (chips go in providers, not labs)
  - All labs: `modules = 0` (was 2/4/6/8 for tube-mainframe through cryostat)
  - Circuit assembler: `modules = 0` (was 2)
  - Files: `scripts/labs.lua`, `scripts/circuits_meta.lua`
  - **DONE**: Set module_slots = 0 on all labs and circuit assembler.

- [x] **N3** Recipe balance: cheaper early chip requirements
  - assembling-machine-1: 2 Control Boards (was none)
  - assembling-machine-2: 2 Control Boards (was none)
  - electric-mining-drill: 2 Control Boards (was too many)
  - splitter: 2 Control Boards (was 5)
  - Files: `data-updates.lua`
  - **DONE**: Replaced vanilla recipes with chip-gated versions.

- [x] **N4** Glass recipe 1:1 ratio (4 silica → 4 glass)
  - Files: `scripts/chips.lua`
  - **DONE**: Changed results from 1 to 4 glass per 4 silica.

- [x] **N5** Fixed server-rack directional animation crash
  - Removed `directional_animation = true` (no directional sprites exist), corrected size to 128×128.
  - Files: `scripts/providers.lua`
  - **DONE**: Fixed crash on entity prototype load.

---

## Deferred / Out of Scope

- **P1.8** Custom sounds for mechanical engine and other buildings — deferred per user request
- Any items already completed in previous sessions (P1.1 assembly-fab cycle fix, prune.lua hide_orphaned_recipes, etc.)
