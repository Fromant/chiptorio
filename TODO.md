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
| P0.1 | Power and cooling do not throttle research | `[ ]` |
| P0.2 | Infinite research is only The Question | `[ ]` |
| P0.3 | Monitor lacks tabs, alerts, locate, utilisation and power/heat | `[ ]` |
| P0.4 | FOUP contamination gate is not active | `[~]` |
| P0.5 | Vanilla circuits overlap the Chiptorio chip line | `[~]` decision needed |

### P0.1 Power and cooling throttle (DESIGN §5.4)

**Design.** Research is gated not only by compute, memory and bandwidth but also
by delivered power and cooling; a shortfall pauses or slows the network.

**Reality.** The data exists and is summed, but nothing consumes it:

- `scripts/research_meta.lua:30-31` says power and heat are summed but "do not
  throttle research yet (DESIGN §5.4 is a later phase)".
- `scripts/runtime/network_runtime.lua:164,181-183,203-206,241-243` gives every
  device `power`, `heat` and `cooling` and sums them into the network totals.
- `scripts/runtime/network_graph.lua:44-46` carries the same three fields.
- `scripts/runtime/research_alloc.lua` and `scripts/runtime/research_runtime.lua`
  never read them.
- The `cooling-tower` is a crafting machine for cryogen/coolant (`scripts/era7.lua`),
  not a network cooling device. No entity supplies `cooling` to a network.
- The monitor does not display power, heat or cooling (see P0.3).

**Why it matters.** Without this, the power and heat numbers on every chip,
memory module and provider are decorative, and datacenters have no operating
cost beyond their ordinary electric drain. The design's "build cooling, not just
compute" loop is missing.

**Done when:**

- [ ] A network exposes `power_demand`, `power_supply`, `heat`, `cooling` and a
      shortfall reason.
- [ ] Power/cooling shortfalls have defined consequences. Recommended: a hard
      pause for cooling (like memory/bandwidth) and a proportional decay for
      power, matching the existing compute-shortfall rule.
- [ ] A real entity or module supplies cooling and is unlocked in the tech tree;
      the existing `cooling-tower` either becomes that entity or a new cooling
      entity is added. Do not leave cooling as a value only the datacenter has.
- [ ] `chip efficiency` (P0.2) and half-node power bonuses feed the same
      multiplier table.
- [ ] `research_alloc` unit tests cover power-only, cooling-only and combined
      shortfalls.
- [ ] The runtime probe builds a network that fails on cooling, asserts the
      pause/decay reason, then adds cooling and asserts recovery.
- [ ] The monitor shows demand/supply and the shortfall (P0.3).

**Open question.** Should power be an actual electric-network draw (the entities
already have `energy_usage`), or an abstract network statistic? The current
provider `drain` values suggest ordinary electric drain, while chip `power` is an
abstract load. Decide before implementing; mixing both will confuse players.

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

**Reality.** `scripts/technology.lua:320-363` makes only `the-question` infinite.
`scripts/research_meta.lua:236,321-323` has a single `infinite_scale` used by The
Question; there is no force-level multiplier table for chip performance,
efficiency, yield, memory density/bandwidth, network bandwidth or cooling.
`DESIGN.md:1017` already admits "still to add: infinite multipliers".

**Why it matters.** The endgame currently has one repeatable technology. There is
no long-term sink for the chip/memory/base you spent the game building, and the
late-game "make the fab better" loop is absent.

**Done when:**

- [ ] The eight scripted researches exist as infinite technologies with sensible
      prerequisites, costs and icons.
- [ ] Each has a documented cap or diminishing return where the design asks for
      one (Chip Efficiency 90%; Process Yield 300%).
- [ ] The runtime reads force-level multipliers from one table and applies them
      consistently:
      - compute multiplier: chip performance + quantum correction for QPUs
      - power multiplier: chip efficiency
      - memory capacity and bandwidth multipliers: separate
      - network bandwidth multiplier
      - cooling capacity multiplier
- [ ] The multipliers are saved and survive `on_configuration_changed`.
- [ ] A unit test proves level scaling and caps; a data contract proves the
      technologies and their effects exist; a runtime probe researches a level
      and observes the multiplier.
- [ ] The monitor exposes the current multipliers (P0.3).

**Note.** Do not use `productivity_bonus` for memory or bandwidth. It is a recipe
effect and would either do nothing or double-apply. Memory and bandwidth are
hardware and must be scripted (the same rule already applies to qualification).

### P0.3 Network Monitor diagnostics (DESIGN §5.3, §5.5)

**Design.** Monitor tabs: Overview, Topology, Devices, Alerts, Routing. Locate
buttons ping entities. Alerts for no route, loop, memory full, compute starved,
cooling insufficient, power low. Link utilisation shown by line thickness/colour.
Power and heat displayed.

**Reality.** `scripts/runtime/network_runtime.lua:741-831` renders one scroll
panel: cable/subnet/network counts, per-network compute by profile, memory,
bandwidth, latency, provider/lab counts, and subnet swatches. The overlay
(`:460-529`) draws fixed-width lines. There are no tabs, alerts, locate buttons,
utilisation or power/heat display. The locale has no keys for them.

**Why it matters.** Once P0.1 and P0.2 land, the player needs to see *why* a
network is short and where the bottleneck is. A monitor that only reports totals
turns diagnosis into guesswork.

**Done when:**

- [ ] The monitor has the five tabs, or a documented smaller set with the same
      information.
- [ ] Overview shows demand vs supply for compute, memory, bandwidth, power and
      cooling, plus the current shortfall reason.
- [ ] Devices lists providers, labs, QLN nodes and their module contents.
- [ ] Alerts lists: no route, isolated device, memory full, compute starved,
      cooling insufficient, power low, and a crossed/looped link if detectable.
- [ ] "Locate" pings the entity (use `rendering.draw_circle` with a short-lived
      marker; do not leave permanent render objects).
- [ ] Overlay line width/colour reflects utilisation or shortfall.
- [ ] The monitor is rebuilt at most once per second, and the open monitor does
      not rebuild every tick.
- [ ] The runtime probe asserts the monitor sections exist and the alert list is
      correct for a deliberately starved network. GUI interaction still needs a
      player (P1.6).

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

**Reality.** `tools/test-probe/data-updates.lua` checks missing prerequisites,
hidden-content leakage, node/qualification/QLN contracts and memory generations.
It does not do a global pass for:

- a visible recipe that no technology unlocks and that starts disabled;
- a visible technology with no path from a start technology;
- a prerequisite cycle;
- a technology that unlocks a recipe which produces a hidden item;
- a recipe whose only ingredient is hidden or itself unreachable.

**Done when:** one data-stage pass builds the recipe/technology graph, reports the
offenders with names, and fails the probe. Exempt intentional islands (pilot
recipes, The Answer Engine, trigger-unlocked starter recipes) through an explicit
allow-list, not by weakening the check.

### P1.2 Save/load harness

**Design.** DESIGN §16.3/§16.5 call for save/load coverage.

**Reality.** No test saves, reloads and re-checks runtime state. The probe always
starts from a fresh map.

**Done when:** a wrapper creates a save with QLN groups, qualification state, an
active Answer clock, a researched technology and network hardware, loads it, and
asserts the state survived. This is the highest-value P1 item because every new
`storage` field is currently trusted on faith.

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

**Reality.** No multiplayer or desync test. Most iteration is ordered, but
`pairs()` over prototype tables and item pools can leak non-determinism into GUI
and graph order.

**Done when:** a review pass removes or sorts every `pairs()` that feeds a
rendered list or a state transition, and the probe runs the same scenario twice
with shuffled storage insertion order and compares the results byte-for-byte. A
real two-client test is out of scope headless; document the manual check.

### P1.5 Tick-time performance harness

**Design.** DESIGN §16.4/§16.5 call for a dedicated performance harness.

**Reality.** The graph unit test has a 10,000-cable scale case, but there is no
tick-time measurement with providers, labs, QLN nodes, FOUPs and an open monitor.

**Done when:** `tools\test-perf.ps1` builds a representative base, runs a
benchmark, parses the update-time output, and fails above a documented budget.
Keep the budget generous; the point is catching accidental per-tick scans, not
micro-optimising.

### P1.6 Player/GUI verification

**Reality.** Factorio 2.1 has no `game.create_player`, so benchmark maps have no
character. The probe logs `CHIPTORIO-TEST SKIP qln-gui` and skips the Terminal,
FOUP Dock and Answer window checks. They only run when `tools/test-probe` is
enabled in a normal save with a character.

**Done when:** either a fixture save with a character is checked in (and a
wrapper loads it), or the README keeps the manual procedure and a release
checklist item requires it. The manual procedure is already in `README.md`.

### P1.7 Construction Core on a real power grid

**Reality.** The runtime probe sets `core.energy = 1e9` because the benchmark map
has no powered grid in an active chunk. Real refill rate, idle behaviour and
brownout are untested.

**Done when:** a probe builds a powered network next to the core, forces the
chunk active (radar/`chart` or a scripted active surface), and asserts that the
core works from grid power and stops when the grid is removed. If Factorio
cannot keep the chunk active headless, document it as a manual check.

### P1.8 Event and state registration audit

**Reality.** `control.lua` owns the dispatcher and remote interfaces are
registered once. There is no automated guard against a module registering its
own `on_nth_tick` or remote interface, which is the exact failure mode AGENTS.md
warns about.

**Done when:** a load-stage assertion or a small probe scans the modules'
returned tables and forbids event registration outside `control.lua`, or a review
checklist covers it. Prefer the assertion if it can be done without touching
runtime modules.

### P1.9 Locale and icon completeness for every prototype

**Reality.** Data probes check the main custom content, but a new item can still
ship with a missing description or a fallback icon. The icon generator's
`$order` list is maintained by hand.

**Done when:** a data-stage pass asserts every visible Chiptorio item, entity and
technology has a locale name (description optional but reported) and an icon that
resolves to a Chiptorio-generated path. Allow-list vanilla re-themes.

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

1. **Decide P0.5 (circuits).** It changes item names, icons and locale, so doing
   it after the other P0 work would mean redoing tests and screenshots.
2. **P0.1 power/cooling + P0.2 infinite research.** They share the multiplier
   table and the monitor fields; implement them together.
3. **P0.3 monitor.** It is how the player sees P0.1/P0.2 working.
4. **P1.1 data contracts + P1.2 save/load.** Protect the new storage fields
   before adding more.
5. **P0.4 FOUP gate** after the first real playtest, when batch size and dock
   speed can be judged.
6. **P1.3–P1.5, P1.7–P1.9.**
7. **Balance.**

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
