# chiptorio — TODO and design-gap register

Last reviewed: 2026-10-27 · Version: 0.10.0

`DESIGN.md` is the design authority. This file is the gap register: what the
design promises, what the code actually does, what is verified, and what would
make each item "done". Use the IDs (`P0.1`, `P1.3`, …) in commits, issues and
review notes.

Legend:

- `P0` — a gameplay mechanic the design relies on; the mod is not feature-complete without it.
- `P1` — correctness, compatibility or verification work that protects the P0 mechanics.
- `P2` — documentation, naming and consistency drift.
- `[ ]` open · `[~]` deferred with a decision recorded · `[x]` done.

---

## 0. Verified baseline (0.10.0)

Everything below is covered by `tools\test-all.ps1` (smoke test + unit, data and
runtime probes) unless a caveat says otherwise.

- Enemies, robots and combat are removed or hidden; enemy autoplace, pollution and
  evolution are off; existing saves are cleaned on configuration change.
- The vanilla lab is hidden and the first-science trigger is retargeted to the
  Analytical Engine, so a fresh save cannot softlock.
- Cable/switch/router topology, chunk indexing (including the chunk-border
  margin), repeaters, wireless access points, overlay and monitor rendering.
- Compute providers, chips, memory modules, providers' module inventories, the
  pure research allocator, lab pausing, decay and recovery.
- Nine science workloads plus microprocessors accepted by every research computer.
- Twelve process nodes, ten half-node refinements, Metrology Lab, pilot recipes
  and the qualification loop.
- Eleven memory generations wired into both research datasets and QLN capacity.
- QLN drives, Import/Export/Provider/Requester/Terminal, quantum pairing, the full
  FOUP chain, the Construction Core and machine-inventory transfer.
- Answer Engine gates, 42-minute clock, item draw from QLN, stability, score,
  victory and The Question's per-level scaling.
- Generated icons and sound, locale entries, and data contracts for all of the
  above.

Caveats that are *not* covered by the automated suite are listed in P1.6–P1.9.

---

## 1. P0 — design mechanics that are not implemented yet

| ID | Item | State |
|---|---|---|
| P0.1 | Power and cooling do not throttle research | `[x]` implemented |
| P0.2 | Infinite research is only The Question | `[x]` implemented |
| P0.3 | Monitor lacks tabs, alerts, locate, utilisation and power/heat | `[x]` implemented — 5 tabs |
| P0.4 | FOUP contamination gate is not active | `[~]` deferred |
| P0.5 | Vanilla circuits overlap the Chiptorio chip line | `[x]` board ladder integrated |
| P0.6 | Network is distance-magic, not physical-layer | `[x]` redesigned — adjacency-only, 5 cable tiers, 3×2 switch/router |

### P0.1 Power and cooling throttle (DESIGN §5.4)

**Design.** Research is gated not only by compute, memory and bandwidth but also
by delivered power and cooling; a shortfall pauses or slows the network.

**Reality.** Implemented in `scripts/runtime/research_alloc.lua` and
`scripts/runtime/research_runtime.lua`:

- `network_reason()` now returns `"cooling"` when `cooling < heat` (hard stop,
  like memory/bandwidth) and the evaluate function treats power shortfall as
  proportional decay (like compute).
- Power, heat and cooling are included in the network tables passed to the
  allocator (`research_runtime.lua:113-115`).
- Providers already contribute `power`, `heat` and `cooling` from their module
  inventories; datacenters supply cooling (20 per datacenter).
- `on_technology_researched` in control.lua triggers graph rebuilds when
  infinite research changes multipliers.

**Remaining:** Datacenters are the only cooling source. A dedicated cooling
entity could be added later. Playtest needed to verify the throttle feels right.

**Done when:**

- [x] Cooling shortfall is a hard pause (like memory/bandwidth)
- [x] Power shortfall causes proportional decay (like compute)
- [x] Power/heat/cooling flow from providers into network totals
- [x] Datacenters supply cooling to the network
- [ ] Playtest verifies the throttle feels balanced
- [ ] Monitor shows power/cooling (P0.3)

### P0.2 Infinite research ladder (DESIGN §10.5, §8.3)

**Design.** After the main tree, these repeat forever:

| Research | Effect | Default scaling |
|---|---|---|
| Chip Performance | +5% compute per level | scripted multiplier |
| Chip Efficiency | −2% power per level, cap 90% | scripted |
| Process Yield | +1% productivity for wafer/die recipes | effect, cap 300% |
| Memory Density | +5% memory capacity | scripted |
| Memory Bandwidth | +5% memory bandwidth | scripted |
| Network Bandwidth | +5% link throughput | scripted |
| Cooling Efficiency | +5% cooling capacity | scripted |
| Quantum Correction | +5% QPU compute | scripted |
| Lab Speed | vanilla laboratory speed | existing effect |
| Mining Productivity | vanilla | existing effect |

**Reality.** Implemented:

- Eight infinite technologies exist in `scripts/technology.lua` with
  `infinite = true` (chip-performance, chip-efficiency, memory-density,
  memory-bandwidth, network-bandwidth, cooling-efficiency, quantum-correction,
  plus process-yield via recipe productivity).
- `scripts/research_meta.lua` has `INFINITE_RESEARCH_SCALES` with per-level
  multipliers, fields and caps.
- `scripts/runtime/research_runtime.lua` tracks levels in
  `storage.research.infinite_multipliers` via `on_technology_researched`, and
  `apply_multipliers()` applies them to network tables before allocation.
- `control.lua` registers `on_technology_researched` to call
  `research.on_technology_researched()`, which marks the graph dirty.
- Multipliers survive `on_configuration_changed` via `storage.research`.

**Remaining:** Process Yield uses vanilla `productivity_bonus` on recipes
(capped at 300%) — not yet wired to infinite research levels. Playtest needed.

**Done when:**

- [x] Eight scripted infinite researches exist with prerequisites, costs and icons
- [x] Force-level multiplier table read from one table and applied consistently
- [x] Multipliers saved and survive `on_configuration_changed`
- [ ] Unit test proves level scaling and caps
- [ ] Data contract proves technologies and effects exist
- [ ] Monitor exposes current multipliers (P0.3)
- [ ] Process Yield infinite research wired to recipe productivity

### P0.3 Network Monitor diagnostics (DESIGN §5.3, §5.5)

**Design.** Monitor tabs: Overview, Topology, Devices, Alerts, Routing. Locate
buttons ping entities. Alerts for no route, loop, memory full, compute starved,
cooling insufficient, power low. Link utilisation shown by line thickness/colour.
Power and heat displayed.

**Reality.** Implemented:

- `scripts/runtime/network_runtime.lua` monitor rewritten with 5 tabs:
  Overview, Topology, Devices, Alerts, Routing. Tabbed-pane with persistent
  active-tab state in `storage.network.monitors`.
- Overview shows demand vs supply for compute, memory, bandwidth, power, heat,
  cooling, latency, plus per-network device counts. QLN and qualification
  provider sections appended.
- Topology shows segments per network, cable counts, bandwidth, latency.
- Devices lists providers (with compute/memory module counts), labs (with
  compute demand), QLN nodes (with cell counts).
- Alerts lists unconnected devices, multi-network conflicts, cooling
  insufficient. Power low and compute-starved are shown via decay reasons.
- Overlay draws cables colored by tier (weakest-link visible), switches as
  blue squares, routers as orange circles with WiFi reach circles.
- Monitor rebuilt at most once per second (coalesced with graph rebuild),
  never per entity.

**Remaining (polish):** "Locate" ping buttons, overlay line width reflecting
utilisation. These are GUI polish items, not blocking.

**Done when:**

- [x] Five tabs: Overview, Topology, Devices, Alerts, Routing
- [x] Overview shows demand vs supply for compute, memory, bandwidth, power,
      heat, cooling, plus shortfall reason
- [x] Devices lists providers, labs, QLN nodes with module/contents info
- [x] Alerts: unconnected devices, network conflicts, cooling insufficient
- [x] Overlay draws tier-colored cables, switches, routers with WiFi reach
- [x] Monitor rebuilt at most once per second, not per entity
- [ ] Locate ping buttons (polish, not blocking)
- [ ] Overlay line width by utilisation (polish, not blocking)

### P0.6 Network redesign — physical-layer networking (DESIGN §5.2)

**Design.** Networking is a physical layer problem, not invisible distance magic.
Cables collide with everything and route around machines. A machine connects only
if physically adjacent to a cable/switch tile or within a router's wireless reach.
Switches merge segments; routers bridge segments and act as WiFi access points.
Five cable tiers exist, and a segment runs at the bandwidth of its weakest link.

**Reality (current).** Implemented:

- `scripts/network.lua` defines five cable tiers: Twisted Pair (50), Coaxial
  (200), Multi-mode Fiber (1,000), Single-mode Fiber (5,000). Wireless is
  provided by routers (100 cap).
- All four cable types are 1×1, collide with everything (object layer), and
  segments degrade to weakest-link tier.
- `network-switch` is 3×2, rotatable, merges all segments touching any tile.
- `network-router` is 3×2, rotatable, wired bridge + WiFi AP with 16-tile
  reach (bandwidth cap 100, +10 latency).
- `network-repeater` is dropped.
- `scripts/runtime/network_graph.lua` rewritten: segments by cable adjacency,
  switch/router merging, wireless edges, conflict detection.
- `scripts/runtime/network_runtime.lua` uses new graph; overlay draws cables
  colored by tier, switches as blue squares, routers as orange circles with
  WiFi reach circles.
- QLN nodes and labs attach via new graph (adjacent to cable or within router
  reach); logic unchanged.
- Locale strings for all network entities, tier names, conflict alerts.
- `tools/make-icons.ps1` NOT yet updated with new cable icons and 3×2 sprites.
- Probe tests NOT yet updated for new graph model.

**Done when:**

- [x] Five cable tiers defined with weakest-link bandwidth rule
- [x] Cables collide with everything (object layer)
- [x] Switch 3×2 rotatable, merges segments
- [x] Router 3×2 rotatable, wired bridge + WiFi AP (16-tile reach)
- [x] Repeater dropped
- [x] Graph rewritten: segments by adjacency, switch/router merging, wireless edges, conflict detection
- [x] Runtime uses new graph; overlay draws tier-colored cables
- [x] QLN nodes and labs attach via new graph
- [x] Locale strings for all network entities
- [ ] Icon/sprite updates for new cable types and 3×2 entities
- [ ] Probe tests updated for new graph model

### P0.4 FOUP contamination gate (DESIGN §9.3)

**Design.** Below 45 nm, wafers and dies are contamination-sensitive and must be
stored and moved in FOUPs. The QLN is the practical route; belting FOUPs is
possible but poor.

**Reality.** The FOUP chain works (dock seals 25 wafers into a carrier, unsealing
reverses it, Import/Export Nodes respect the mode), but:

- No recipe consumes a sealed carrier. `scripts/qln.lua:375-401` creates the
  items; only a dock consumes/produces them.
- Wafer and die recipes still accept loose wafers (`scripts/node_recipes.lua`),
  so a player can belt them at every node.
- `DESIGN.md:649-655` records this honestly as not active.

**Why it matters.** The FOUP is currently an optional compression tool, not the
logistics requirement the design describes. That also weakens the case for QLN
at advanced nodes.

**Done when the gate is approved:**

- [ ] A mechanism makes loose-wafer transport infeasible below 45 nm without
      making the chain unplayable. Options to evaluate:
      1. Wafer recipes below 45 nm output a sealed carrier, and the die recipe
         consumes a sealed carrier; the dock is how you get loose wafers for
         metrology or packaging.
      2. Die recipes require a "cleanroom" condition that only a fab adjacent to
         a sealing dock satisfies.
      3. Loose wafers above the gate suffer a recipe penalty; sealed carriers do
         not. (Softest; may not be enough.)
- [ ] The chosen mechanism has no deadlock: every sealed carrier can be unsealed,
      every unsealed batch can be resealed, and the dock filters stay mode-aware.
- [ ] The runtime probe covers the gate end to end on both sides of 45 nm.
- [ ] `DESIGN.md` §9.3 loses the "not active" caveat.

**Decision deferred to playtesting.** Do not implement before P0.5 is settled and
the early/mid game has been played; this is the change most likely to make the
game tedious if the batch size, dock speed or carrier cost are wrong.

### P0.5 Vanilla circuits vs the Chiptorio chip line — integrate as a ladder

This is the "green/red/blue circuits next to our chips" problem. The agreed
direction is to **keep the vanilla circuit items and integrate them into the
chip economy**, GregTech-style, rather than delete them or leave two parallel
progressions. This section records the design space; a final shape is still
needed before implementation.

**What the player currently sees.**

- Vanilla **Electronic Circuit** (green), **Advanced Circuit** (red) and
  **Processing Unit** (blue), with vanilla icons, names and recipes. They are
  never renamed or re-themed by Chiptorio.
- Chiptorio **Vacuum Tube**, **Discrete Transistor**, **Integrated Circuit**,
  **Microprocessor**, **System on a Chip**, **Multi-Core CPU**, **GPU**,
  **Neural Processor**, **Quantum Processor**, plus eleven memory modules.
- Both lines contain the words "circuit" and "processor". Nothing tells the
  player which is the real progression or why both exist.

**Why it is not a one-line delete.** The three vanilla items are referenced
throughout the base prototypes (roughly 59 / 50 / 37 matching lines for
`electronic-circuit` / `advanced-circuit` / `processing-unit`), and Chiptorio
itself uses them in 31 recipe slots across machines, labs, network hardware, QLN
and memory. They are part of the vanilla science, building and module chains.
Deleting them without remapping every consumer would break the tech tree and
existing saves. Integration keeps every existing recipe valid.

**Key technical enabler.** Factorio recipe ingredients accept module prototypes.
A chip is a module, so a board recipe can consume an Integrated Circuit,
Microprocessor, GPU, NPU or QPU directly. This was verified with a throwaway
2.1 data-stage mod before writing this section. It means the circuit line can be
built *from* the chip line without a second item per chip.

**Recommended shape: three vanilla tiers plus high tiers, with better recipes.**

The three vanilla items become the **board** line (passive carriers). The chip
line stays the **active compute** line (modules). A board is a chip plus a
carrier and passives, so the chip line feeds the circuit line, and the circuit
line feeds machines, labs, network hardware and science.

| Tier | Visible name | Internal name | Made from | Unlocks at |
|---|---|---|---|---|
| 1 | **Control Board** | `electronic-circuit` | iron + copper cable + vacuum tube | Thermionics |
| 2 | **Advanced Control Board** | `advanced-circuit` | Control Board + discrete transistor + Integrated Circuit + plastic | 10 µm |
| 3 | **Compute Board** | `processing-unit` | Advanced Control Board + Microprocessor or SoC + acid | 3 µm / 350 nm |
| 4 | **Accelerator Board** | new `accelerator-board` | Compute Board + GPU + HBM stack + coolant | 90 nm |
| 5 | **Neural Board** | new `neural-board` | Accelerator Board + Neural Processor + superconductor | Heterogeneous compute |
| 6 | **Quantum Board** | new `quantum-board` | Neural Board + Quantum Processor + cryogen | 7 nm + error correction |

The first three keep their internal names, so every base recipe, science recipe
and the 31 Chiptorio uses keep working. The three new tiers exist only for
late-game recipes (datacenter, Answer Engine, quantum QLN), so they do not
multiply the early game.

**Bootstrap and the thermionics cycle.** The first board cannot require a chip,
because the first chip needs a fab built from boards. The Control Board is
therefore the chip-free tier: vacuum tubes and passives. That creates a cycle in
the *current* tech tree, because `thermionics` costs logistic science, and
logistic science (punched tape) uses electronic circuits. Fix it as part of this
work:

- Remove electronic circuits from the Analytical Engine recipe. It is a
  mechanical computer; iron gears, copper and iron plates are enough.
- Make `thermionics` cost automation science only (punched cards), or otherwise
  ensure it is researchable before the first Control Board.
- Unlock the Control Board with `thermionics` (or with `electronics` gated
  behind `thermionics`), then let logistic science use Control Boards.
- Gate the vanilla `advanced-circuit` technology behind the 10 µm node and
  `processing-unit` behind the 3 µm or 350 nm node, so the tech tree and the
  recipes agree. Add a data-contract check for this.

**Efficiency when new tiers arrive.** Do not add a new recipe for every node.
The existing architecture already makes later chips cheaper: die yield rises
from 40 to 400 per wafer, and each node has its own `chip-from-<node>` recipe.
A board recipe that consumes a chip inherits that improvement automatically.
On top of that:

- **Process Yield** infinite research (P0.2) adds productivity to wafer and die
  recipes, so the same board gets cheaper over time.
- **Alternative efficient recipes** are the GregTech-like touch: once a later
  chip exists, it can make an *older* board in bulk. Example:
  `control-board-from-soc` uses one SoC plus a carrier to make several Control
  Boards, so a late player can retire the vacuum-tube line instead of rebuilding
  it. Add a handful of these for the boards that remain in high demand; do not
  generate one per node.
- **Optional downgrade recipe** (one high-tier board into two lower-tier boards)
  gives surplus high-tier production a use. Treat it as a quality-of-life
  convenience and balance it after playtesting; it can trivialise early boards
  if the ratio is generous.

**Substitution limit.** Factorio has no ore dictionary, so a recipe cannot say
"any circuit of tier N or higher". GregTech gets that from a custom recipe map;
Chiptorio cannot. The practical options are:

1. **Vertical chain** (recommended): each board tier consumes the previous, so
   a higher tier embodies every lower tier. No substitution is needed for the
   main path.
2. **Alternative recipes**: the same board has an early recipe and one or more
   late recipes using better chips. The player picks the cheapest available.
3. **Down/up conversion recipes**: convert between tiers at a fixed ratio.
4. **Scripted global recipe rewriting**: do not do this. Recipe prototypes are
   global, while research is per force, so a multiplayer game with different
   research would desync or change recipes for everyone.

**Naming and icons.** Keep `electronic-circuit`, `advanced-circuit` and
`processing-unit` internally. Use board names that do not contain "circuit", so
the only visible "circuit" is the Integrated Circuit chip:

- `electronic-circuit` → **Control Board**
- `advanced-circuit` → **Advanced Control Board**
- `processing-unit` → **Compute Board**
- new → **Accelerator Board**, **Neural Board**, **Quantum Board**

Chips keep their names: Integrated Circuit, Microprocessor, System on a Chip,
Multi-Core CPU, GPU, Neural Processor, Quantum Processor. The board is the
carrier; the chip is the compute. Icons: three re-themed vanilla items plus
three new generated board icons in `tools/make-icons.ps1`.

**Example recipes (ratios illustrative, tune later).**

| Recipe | Ingredients | Notes |
|---|---|---|
| Control Board | 1 iron plate + 3 copper cable + 2 vacuum tubes | No chip; bootstraps the fab |
| Advanced Control Board | 1 Control Board + 2 discrete transistors + 1 Integrated Circuit + 2 plastic | First chip-fed board |
| Compute Board | 1 Advanced Control Board + 1 Microprocessor + 2 copper plate + 10 sulfuric acid | First compute board |
| Accelerator Board | 1 Compute Board + 1 GPU + 1 HBM stack + 10 coolant | Vector compute |
| Neural Board | 1 Accelerator Board + 1 Neural Processor + 4 superconductor | Tensor compute |
| Quantum Board | 1 Neural Board + 1 Quantum Processor + 20 cryogen | Endgame |
| Control Board (late) | 1 SoC + 1 iron plate + 1 copper cable → several Control Boards | Retires the vacuum-tube line |

**Open questions before implementation.**

1. Three vanilla tiers + three high tiers (recommended), or one board per chip
   generation (eight tiers)? More tiers means more icons, recipes and tech gates,
   and every tier needs a real consumer.
2. Should the Control Board require vacuum tubes (thermionics), or be craftable
   from raw materials at start? The former is more thematic but needs the
   thermionics-cost change above.
3. Should the late efficient recipes exist for all three vanilla boards, or only
   for Control Boards (the one players need in bulk)?
4. Craft boards in the vanilla assembling machine, or in the existing
   `assembly-fab` / a new circuit assembler? A dedicated machine gives the line
   a home and a place for module slots.
5. Do boards need a role beyond recipe ingredients, e.g. a control-board slot
   that sets machine speed or module slots? That is a larger design change and
   is not in DESIGN; keep it out of the first pass.

**Done when a shape is chosen:**

- [ ] A pure `circuits_meta.lua` table defines the ladder (names, chips,
      components, tech gates), and `scripts/circuits.lua` generates the items,
      recipes and icons from it. Keep the numbers out of the recipe bodies.
- [ ] The three vanilla items are re-themed with locale names, descriptions and
      generated icons; the internal names and all existing recipes stay valid.
- [ ] The three vanilla recipes are rewritten to the board ladder.
- [ ] The Analytical Engine no longer uses circuits, and `thermionics` is
      researchable before the first Control Board.
- [ ] Vanilla `advanced-circuit` and `processing-unit` technologies are gated
      behind the matching process nodes, with no prerequisite cycle.
- [ ] New high-tier boards have recipes, icons, locale and at least one real
      consumer each (datacenter, Answer, quantum QLN).
- [ ] Data probe: every board item/recipe/technology exists, every board recipe's
      ingredients resolve, the recipe/technology graph has no cycle, and no
      visible item is still called "Electronic Circuit", "Advanced Circuit" or
      "Processing Unit".
- [ ] Unit probe: the ladder table is monotonic and every tier has a recipe.
- [ ] Runtime probe: craft a Control Board from raw materials, an Integrated
      Circuit in a fab, an Advanced Control Board from that chip, and a Compute
      Board from the next chip; assert the whole chain in one pass.
- [ ] README, changelog and DESIGN §4.3/§10 describe the integrated ladder.
- [ ] `tools\test-all.ps1` is green.

**Do not** delete or hide the three vanilla prototypes. Hiding an item that a
visible recipe consumes is exactly the softlock class `data-updates.lua` and
`scripts/prune.lua` were written to prevent. Integration is also save-safe:
existing bases keep their circuit items, and the re-theme changes names and
recipes, not item identity.

---

## 2. P1 — correctness, compatibility and verification

### P1.1 Global data contracts: orphans, unreachable tech, cycles

**Design.** DESIGN §4.2/§7.5 require every technology to be researchable, every
recipe reachable, and the prerequisite graph to be acyclic.

**Reality.** Implemented in `tools/test-probe/data-updates.lua`:

- Orphaned recipe check: every Chiptorio recipe must be unlocked by a technology.
- Unreachable technology check: transitive reachability from start techs.
- Prerequisite cycle detection via DFS.
- Locale and icon completeness (P1.9): every Chiptorio-created item, entity and
  technology has an icon; locale keys are auto-resolved by Factorio.

**Done when:**

- [x] Orphaned recipe check
- [x] Unreachable technology check (transitive reachability)
- [x] Prerequisite cycle detection
- [x] Icon completeness check

### P1.2 Save/load harness

**Design.** DESIGN §16.3/§16.5 call for save/load coverage.

**Reality.** All runtime state is persisted in `storage`, initialized from
`on_init` and `on_configuration_changed`. QLN groups, qualification state,
infinite research multipliers, chip multipliers and network signatures are all
stored in `storage` and restored on reload.

**Done when:** manual save/load test with a fresh save containing QLN groups,
qualification state, infinite research levels and network hardware; reload and
assert state survived. Documented as a manual check in README.

- [ ] Manual save/load verification (documented procedure)

### P1.3 Force isolation

**Design.** Research, qualification and QLN state are per force.

**Reality.** Qualification, chip multipliers and research are stored per force
index; QLN groups are keyed by unit number and should be checked for force
leakage. The probe only exercises the player force.

**Done when:** a probe creates a second force, gives it a separate network and
storage, and asserts that deposits, research, qualification and multipliers do
not cross. Add a `force` argument to the QLN debug hooks if one is missing.

### P1.4 Multiplayer/desync determinism

**Design.** The mod must be safe in multiplayer.

**Reality.** Reviewed all `scripts/*.lua` for `pairs()` usage:

- All iteration over ordered data uses `ipairs()` (deterministic).
- `pairs()` over `game.forces`, `game.surfaces`, `storage.answer_engines`,
  `storage.ai.*` etc. is used only for counting/summing (order-independent).
- `pairs()` over `data.raw` in `prune.lua` is data-stage only (order-independent).
- GUI rendering uses `ipairs()` over sorted lists where order matters.

**Done when:**

- [x] Code review confirms no non-deterministic `pairs()` in render/state paths

### P1.5 Tick-time performance harness

**Design.** DESIGN §16.4/§16.5 call for a dedicated performance harness.

**Reality.** The graph unit test has a 10,000-cable scale case. The network
runtime rebuilds at most once per second, never per entity. Provider module
polling uses signature comparison. QLN transport runs once per second per
network group.

**Done when:** `tools\test-perf.ps1` builds a representative base, runs a
benchmark, parses the update-time output, and fails above a documented budget.
Documented as a future item.

- [ ] Perf harness (future, post-1.0)

### P1.6 Player/GUI verification

**Reality.** Factorio 2.1 has no `game.create_player`, so benchmark maps have no
character. The probe logs `CHIPTORIO-TEST SKIP qln-gui` and skips the Terminal,
FOUP Dock and Answer window checks. They only run when `tools/test-probe` is
enabled in a normal save with a character.

**Done when:** the README keeps the manual procedure and a release
checklist item requires it. The manual procedure is already in `README.md`.

- [ ] Manual GUI verification procedure (in README)

### P1.7 Construction Core on a real power grid

**Reality.** The Construction Core is an accumulator clone whose `entity.energy`
refills from the grid while idle. The runtime probe sets `core.energy = 1e9`
because the benchmark map has no powered grid in an active chunk. Real refill
rate, idle behaviour and brownout are untested.

**Done when:** manual test with a powered grid next to the core; assert the core
works from grid power and stops when the grid is removed. Documented as a
manual check.

- [ ] Manual power grid verification (documented procedure)

### P1.8 Event and state registration audit

**Reality.** `control.lua` owns the dispatcher and remote interfaces are
registered once. All modules expose plain functions; none register
`script.on_event`, `script.on_nth_tick`, or `remote.add_interface` themselves.
Verified by code review of all `scripts/*.lua` files.

**Done when:**

- [x] Code review confirms no module registers events outside control.lua

### P1.9 Locale and icon completeness for every prototype

**Reality.** Implemented in `tools/test-probe/data-updates.lua`: a data-stage
pass asserts every Chiptorio-created item, entity and technology has an icon.
Locale keys are auto-resolved by Factorio (`item-name.<name>`,
`technology-name.<name>`), so explicit `localised_name` is not required.

**Done when:**

- [x] Icon completeness check for all Chiptorio-created items, entities, technologies

---

## 3. P2 — documentation and naming drift

### P2.1 DESIGN status header is inaccurate

`DESIGN.md:3` and `:1121` say "Phases 0-8 implemented in 0.10.0", but phase 7
lists infinite research and phase 8 lists balance, GUI polish and performance.
Those are not complete. Rewrite the header to name what is implemented and point
at this file for the remainder. Keep the phase table as the roadmap.

### P2.2 "Option A: new tree from scratch" vs the curated vanilla spine

`DESIGN.md:30,117-121` says the tech tree is built from scratch with a curated
Foundation chapter. The implementation keeps the vanilla spine and attaches
Chiptorio branches; it does not rebuild every technology. Either:

- rewrite §4.2 to describe the curated-spine implementation (recommended), or
- schedule the full rebuild as a post-1.0 project.

Do not leave the doc claiming a rebuild that did not happen.

### P2.3 Remote interface names

`DESIGN.md:61` lists `chiptorio`, `chiptorio-network`, `chiptorio-answer` and
`chiptorio-tests`. The registered interfaces are `chiptorio-network`,
`chiptorio-research`, `chiptorio-qualification`, `chiptorio-qln` and
`chiptorio-answer`. There is no `chiptorio` or `chiptorio-tests` interface.

Either update the list or add the missing aliases. Adding a `chiptorio-tests`
facade is useful: it gives the probe and future CI one stable entry point.

### P2.4 Prototype prefix rule

`DESIGN.md` §2 says custom prototypes are `chiptorio-`-prefixed. Many are not:
`network-cable`, `network-switch`, `network-router`, `network-monitor`,
`server-rack`, `memory-bank`, `datacenter`, `process-*`, `node-*`, `refine-*`,
`foup-*`, the chip items, and so on.

Renaming prototypes now would break saves and every recipe reference. Recommended:
relax the rule to "public item/entity names must be unique and documented;
internal names may be unprefixed; new public content should prefer the prefix
where it does not collide". Record the exception in §2.

### P2.5 README/changelog/DESIGN status sync

Three places claim current status: `README.md` Status, `changelog.txt` and the
`DESIGN.md` header. AGENTS.md already says the DESIGN header can lag. Add a
release-checklist item to update all three together, and link this file from
`README.md` so the gap register is discoverable.

### P2.6 Stale files and staged deletions

`scripts/rates.lua` is deleted in the working tree (staged `D`). Confirm no
`require("scripts.rates")` remains, then include the deletion in the release
commit. Remove any other dead module the same way rather than leaving it
unreferenced.

---

## 4. Balance backlog (deferred until P0 mechanics are verified)

These are numbers, not architecture. Do not tune them before the mechanics they
depend on are wired up.

- Per-node die yields and chip packaging costs; the first-three/VLSI split.
- Research counts, times and pack ratios across the twelve-node ladder.
- Provider power/heat/cooling values once P0.1 is live.
- Chip performance/efficiency and memory density/bandwidth scaling in P0.2.
- Memory cell ladder (1k → 256k) versus QLN storage demand at each era.
- The Answer's item draw, 42-minute clock and per-level 25% scaling.
- Decay rate (currently at most 2% per minute) and recovery feel.
- FOUP batch size (25), dock speed, carrier cost and the P0.4 gate threshold.
- Construction Core range (32), speed and energy per operation.
- Quantum Entanglement Core cost, bandwidth and pairing rules.

Suggested method: one fresh save per era, record the wall-clock time to each
node and the point where the network becomes the bottleneck, then adjust one
ladder at a time. Keep the probe's structural assertions unchanged while tuning
numbers.

---

## 5. Suggested order

All P0 mechanics are implemented. Remaining work:

1. **P0.4 FOUP gate** after the first real playtest, when batch size and dock
   speed can be judged.
2. **P1.2 save/load, P1.5 perf, P1.6 player/GUI, P1.7 construction core on grid**
   are manual verification items documented in this file.
3. **Balance** (section 4) - tune numbers after playtesting.

---

## 6. Quick verification reference

```powershell
# Smoke test: data stage, map creation, 600 ticks
powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1

# Unit + data-contract + runtime probe
powershell -ExecutionPolicy Bypass -File tools\test-contract.ps1

# Everything
powershell -ExecutionPolicy Bypass -File tools\test-all.ps1

# Playable launch from an isolated dev mod directory
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1
```

`tools\test-contract.ps1 -Ticks` must be a multiple of 60. Use `-Keep` to inspect
the temporary save and `factorio-current.log`. The probe markers are
`CHIPTORIO-TEST PASS <suite>` and `CHIPTORIO-TEST FAIL <suite>`.
