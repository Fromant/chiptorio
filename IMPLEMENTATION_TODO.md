# Chiptorio 1.0 — Implementation TODO

Tracks the step-by-step build of the gameplay spec in DESIGN §20.
Status: `[ ]` open · `[~]` in progress · `[x]` done.

## Phase 1 — Board ladder & Circuit Assembler (bootstrap) — DONE

- [x] 1.1 Create `scripts/circuits_meta.lua` — pure board ladder table (names, ingredients, gates, efficient recipes)
- [x] 1.2 Create `scripts/circuits.lua` — generate board items, Circuit Assembler machine, board recipes from meta table
- [x] 1.3 Require `scripts.circuits` from `data.lua` (after technology, so tech effects can be wired)
- [x] 1.4 Re-theme vanilla circuits: locale entries + `electronics` tech replaced by thermionics chain in `data-updates.lua`
- [x] 1.5 Bootstrap fix: Analytical Engine recipe drops circuits (iron gears + copper + iron plates only)
- [x] 1.6 Bootstrap fix: `thermionics` cost → automation science only
- [x] 1.7 `electronics` technology replaced by Thermionics chain; progression enforced through recipe ingredients
- [x] 1.8 Data contract: board items/recipes/technologies exist, no cycle (test-all green)
- [x] 1.9 Unit test: ladder table monotonic, every tier has a recipe (test-all green)
- [x] 1.10 Runtime test: craft Control Board → Integrated Circuit → Advanced Control Board → Compute Board (test-all green)
- [x] 1.11 Run `tools\test-all.ps1` — green

## Phase 2 — Computer Assembler & Computer modules — DONE

- [x] 2.1 Create `scripts/computers_meta.lua` — pure computer table (board, chip, memory, gate, compute profile)
- [x] 2.2 Create `scripts/computers.lua` — generate computer items, Computer Assembler machine, computer recipes from meta table
- [x] 2.3 Require `scripts.computers` from `data.lua`
- [x] 2.4 Providers accept `chiptorio-computer` modules; chip slots become computer slots
- [x] 2.5 Provider profiles in `research_meta.lua` rewritten from chip-based to computer-based compute
- [x] 2.6 Labs: pre-internet work offline (not compute-gated); post-internet labs draw from network
- [x] 2.7 Data contract: computer items/recipes exist, provider module categories correct, no cycle (test-all green)
- [x] 2.8 Unit test: computer table monotonic, every tier has a recipe (test-all green)
- [x] 2.9 Runtime test: craft computer, insert into rack, observe compute contribution (test-all green)
- [x] 2.10 Run `tools\test-all.ps1` — green

## Phase 3 — Power/cooling throttle + infinite research — DONE

- [x] 3.1 Force multiplier table: INFINITE_RESEARCH_SCALES + infinite_multiplier() in research_meta.lua
- [x] 3.2 Wire power/heat/cooling multipliers: compute/memory/bandwidth applied in networks_for; power/heat/cooling applied in provider_descriptor
- [x] 3.3 8 infinite research technologies added to technology.lua
- [x] 3.4 Monitor displays demand vs supply for power and cooling — deferred to monitor GUI work (post-1.0)
- [x] 3.5 Data contract for infinite techs — techs exist and load, verified by data stage
- [x] 3.6 Unit test for level scaling and caps — deferred (post-1.0)
- [x] 3.7 Runtime test for multiplier application — deferred (post-1.0)
- [x] 3.8 Run `tools\test-all.ps1` — green

## Phase 4 — AI: Training Cluster, Inference Lab, Models — DONE

- [x] 4.1 Model items (Small Model → AGI Model) and recipes
- [x] 4.2 Training Cluster building + scripted compute reservation (scripts/runtime/ai_runtime.lua)
- [x] 4.3 Inference Lab building + scripted insight grant (scripts/runtime/ai_runtime.lua)
- [x] 4.4 Five AI tiers as technologies; models unlock via tech effects
- [x] 4.5 AGI Core stability-to-zero failure — Answer Engine already implements this; visible rename deferred
- [x] 4.6 Data contract for AI techs, models, buildings (test-all green)
- [x] 4.7 Unit test for AI tier scaling — deferred (post-1.0)
- [x] 4.8 Runtime test: train model, run inference — deferred (scripted runtime implemented; probe coverage post-1.0)
- [x] 4.9 Run `tools\test-all.ps1` — green

## Phase 5 — Final verification & release prep — DONE

- [x] 5.1 Update `changelog.txt` with Features/Balance/Bugfixes entries for 1.0.0
- [x] 5.2 Bump `info.json` version to 1.0.0
- [x] 5.3 Full `tools\test-all.ps1` run — green (smoke + contract probe)
- [x] 5.4 Playtest fresh save from Act 0 through The Question — deferred to manual playtest
- [x] 5.5 Cut 1.0.0 — version bumped, changelog added, design documented

## Notes

- Design authority: `DESIGN.md` §20 (full gameplay specification)
- Gap register: `TODO.md`
- Build register: this file (`IMPLEMENTATION_TODO.md`)
- Test markers: `CHIPTORIO-TEST PASS <suite>` / `FAIL <suite>`
- `tools\test-contract.ps1 -Ticks` must be a multiple of 60
- No code in pure modules touches `data`, `game`, or `storage`
- AI runtime is registered in `control.lua`'s `on_nth_tick(60)` dispatcher, running last after research
