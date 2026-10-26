# Chip'torio - design document

> A Factorio total conversion where **computation is the economy**.
> Target: Factorio **2.1.23**, **no DLC**, **Nauvis only**.

---

## 1. Pitch

Vanilla Factorio asks: *can you build a factory?*
Chip'torio asks: *can you build a computer industry?*

The factory is still there. Belts, furnaces, oil, power, biters. But the thing
that actually advances you is **compute**: the ability to manufacture
increasingly dense logic, at increasing scale, and keep it fed.

The arc is the real arc of computing:

```
relays -> valves -> discrete transistors -> integrated circuits
      -> microprocessors -> VLSI -> wafer-scale -> quantum
```

Each step is a *manufacturing* problem, not a research-point problem. You do
not unlock the microprocessor by delivering 200 flasks. You unlock it by
building a fab that can actually produce wafers, and by sustaining enough
compute to design the next chip.

## 2. Design pillars

1. **The early game stays recognizable.** Burner drills, stone furnaces, red
   science. A new player should not feel lost for the first hour.
2. **Every jump in capability is a physical process.** No hand-waved "CPU
   research". If you want a chip, you need sand, crystal, masks, resist, etch,
   metal, packaging.
3. **Scale is the wall, not recipes.** Late technologies require *sustained
   throughput*, not stockpiles. A big factory that stops producing is worthless.
4. **Chips are infrastructure.** Late-game machines physically contain chips.
   Losing your chip line cripples everything downstream.
5. **No DLC assumptions.** All mechanics work on Nauvis with the base game.

## 3. Two currencies

Vanilla research has one input: science packs. Chip'torio splits it into two
independent axes, which is what makes the progression feel like computing
rather than alchemy.

### 3.1 Workloads (what to compute)

The six vanilla science packs are re-flavoured as storage media and kept under
their internal prototype names, so the entire vanilla tech tree keeps working:

| Vanilla prototype | New name | Era |
|---|---|---|
| `automation-science-pack` | Punched Card Deck | mechanical |
| `logistic-science-pack` | Punched Tape Reel | relay |
| `military-science-pack` | Magnetic Tape Reel | valve |
| `chemical-science-pack` | Disk Pack | transistor |
| `production-science-pack` | Solid-State Drive | IC |
| `utility-science-pack` | Mainframe Module | VLSI |

Each tier consumes a little of the previous tier, so research has a vertical
dependency without a 5x cost explosion.

### 3.2 Compute throughput (how fast you can compute)

Selected technologies declare a **sustained production rate** requirement
(items/second of a workload), measured over a rolling one-minute window.

- Stockpiling does not help: the gate reads *production*, not consumption.
- Below the floor, research speed scales with the fraction of the rate you are
  actually producing: at half the rate you research at half speed, and at zero
  the bar freezes and then decays by 2% per minute. A stockpile can keep labs
  running, but it cannot outrun the factory.
- A chat notice fires when the requirement is first seen and periodically
  while it is unmet. A runtime setting can disable enforcement for players who
  dislike the mechanic.

This is the mod's signature mechanic: a datacenter is a *rate*, not a pile.

## 4. Progression

### 4.0 Opening progression (fresh save)

Vanilla unlocks the first science pack with a *trigger* technology: craft a
lab. Chip'torio hides the vanilla lab, so that trigger is retargeted to the
Analytical Engine. A new save therefore starts like this:

1. Hand-mine and smelt. Crafting 50 iron plates triggers **Steam Power**;
   crafting 10 copper plates triggers **Electronics** (circuits, inserters,
   small poles).
2. Craft the **Analytical Engine** (gears, copper, iron, four circuits).
   Crafting it triggers the **Punched Cards** technology and unlocks the first
   science pack recipe.
3. Power the engine and start researching. Nothing before this point needs a
   lab, a chip, or research of any kind.

The loading stage asserts that the Analytical Engine recipe is enabled at game
start, so a future rebalance cannot silently reintroduce this softlock.

### 4.1 Era ladder

| Era | Real-world analogue | Logic device | Feature size | Research machine | Workload |
|---|---|---|---|---|---|
| 0 | 1830s-1890s | gears, relays | mechanical | Analytical Engine | punched cards |
| 1 | 1900s-1940s | vacuum tube | millimetres | Tube Mainframe | punched tape |
| 2 | 1950s-1960s | discrete transistor | 10 mm | Tube Mainframe | magnetic tape |
| 3 | 1970s | SSI/MSI IC | 10 um | Mainframe Cluster | disk pack |
| 4 | 1980s | microprocessor | 1 um | Mainframe Cluster | SSD |
| 5 | 1990s-2000s | VLSI / SoC | 100 nm | Datacenter | mainframe module |
| 6 | 2010s+ | multi-core / GPU | 10 nm | Datacenter | mainframe module |
| 7 | speculative | quantum | - | Cryostat | qubit arrays |

Eras 0-7 are implemented as of v0.4.

### 4.2 The first chip (implemented)

This is the chain the player actually builds:

```
stone
  -> silica sand
      -> glass ---------------------------> lithography mask
      -> metallurgical silicon (coal)
          -> polysilicon (acid + steam)
              -> monocrystalline ingot (Crystal Puller)
                  -> silicon wafer (wire saw)
                      -> exposed wafer (photoresist + mask)
                          -> etched wafer (etchant)
                              -> processed wafer (copper + acid)
                                  -> bare die (dicing)
                                      -> discrete transistor (package)
                                      -> integrated circuit (planar process)
                                          -> microprocessor
```

Supporting chemistry:

```
plastic + light oil + steam -> photoresist
sulfuric acid + water       -> etchant
```

Nothing in the chain is hand-waved, but not every step needs a bespoke
building either. Bulk chemistry (silica, polysilicon, photoresist, etchant)
stays in chemical plants; crystal growth moves to the **Crystal Puller**, and
every lithography / etch / metallisation / dicing step moves to the
**Wafer Fab**.

### 4.3 Fab machines (v0.2)

| Machine | Base | Category | Speed | Power | Modules | Unlock |
|---|---|---|---|---|---|---|
| Crystal Puller | electric furnace | `chipotrio-crystal` | 2.0 | 240 kW | 2 | Semiconductor Physics |
| Wafer Fab | chemical plant | `chipotrio-fab` | 1.5 | 300 kW | 3 | Photolithography |
| Server Rack | AM3 | `chipotrio-compute` | 1.25 | 420 kW | 4 | Planar Process |

The Wafer Fab is cloned from the chemical plant specifically because it needs
working fluid boxes: exposure, etch and metallisation all consume fluids. The
Crystal Puller is a furnace clone (no fluids). The Server Rack is the high-tier
packaging machine: solid-state drives and mainframe modules are built there,
which makes the top two workloads depend on the fab tier.

Machine recipes build in ordinary assembling machines; only the *process*
recipes use the new categories. All three machines are tinted base reskins, so
there is still no custom entity art to go missing.

### 4.4 Research machines

| Machine | Speed | Power | Modules | Unlock |
|---|---|---|---|---|
| Analytical Engine | 0.5 | 90 kW | 0 | available at start |
| Tube Mainframe | 1.0 | 240 kW | 2 | Thermionics |
| Mainframe Cluster | 1.75 | 600 kW | 4 | Planar Process |
| Datacenter | 2.5 | 1.5 MW | 6 | Datacenter |
| Cryostat | 4.0 | 3 MW | 8 | Quantum Computing |

All generations accept all workloads. This is a compatibility decision, not a
thematic one: gating packs per machine silently deadlocks the vanilla tech
tree (a tech can require a pack whose machine is locked behind that same tech).
The generational upgrade is speed, modules and power efficiency.

### 4.5 New technologies (v0.2)

| Tech | Cost | Gate | Unlocks |
|---|---|---|---|
| Electromechanics | 20 cards | - | circuit network becomes available |
| Thermionics | 40 cards + tape | - | silica, glass, vacuum tube, tube mainframe |
| Semiconductor Physics | 75+ | - | crystal puller, Si, polysilicon |
| Crystal Growth | 100+ | - | ingot, wafer |
| Photolithography | 150+ | 3 tape/s | wafer fab, resist, etch, mask, wafers, die, transistor |
| Planar Process | 200+ | 6 magnetic tape/s | server rack, IC, mainframe cluster |
| Microarchitecture | 300+ | 10 disk packs/s | microprocessor |

### 4.6 Era 5-6: VLSI, chiplets and the datacenter (v0.3)

Era 5 moves from a single-chip CPU to a system on a chip, and from a mainframe
cluster to a datacenter. It introduces a process that is too demanding for the
original Wafer Fab: deep-UV exposure, chemical-mechanical planarisation, low-k
interconnect, stacked memory, and a chilled stage.

| Step | Machine | Inputs | Output |
|---|---|---|---|
| Phase-shift mask | Wafer Fab | litho mask, glass, copper | phase-shift mask |
| CMP slurry | Chemical plant | silica, water, acid | CMP slurry (fluid) |
| Low-k dielectric | Chemical plant | plastic, acid | low-k dielectric |
| Coolant | Cooling Tower | water, steam | coolant (fluid) |
| Cooling unit | Chemical plant | steel, pipe, copper, coolant | cooling unit |
| VLSI exposure | VLSI Fab | wafer, phase mask, resist, coolant | VLSI wafer |
| CMP + dicing | VLSI Fab | VLSI wafer, slurry, copper | VLSI die |
| SoC packaging | Server Rack | VLSI die, low-k, copper | system on a chip |
| Chiplet | Server Rack | SoC, low-k, copper | chiplet |
| HBM stack | Server Rack | VLSI die, copper, plastic | HBM stack |
| GPU | VLSI Fab | chiplet, HBM, coolant | GPU |
| Multi-core CPU | Server Rack | chiplet, HBM, SoC | multi-core CPU |

The cooling loop is deliberately a production chain, not a GUI toggle: the
Cooling Tower turns water and steam into coolant, the VLSI Fab and GPU line
consume it, and the Datacenter itself is built from cooling units. A player who
ignores cooling cannot produce the chips that the Era 6 gates measure.

**New machines**

| Machine | Base | Category | Speed | Power | Modules | Unlock |
|---|---|---|---|---|---|---|
| VLSI Fab | chemical plant | `chipotrio-vlsi` | 2.0 | 800 kW | 4 | VLSI Process |
| Cooling Tower | chemical plant | `chipotrio-cooling` | 1.5 | 300 kW | 2 | VLSI Process |
| Datacenter | lab | - | 2.5 | 1.5 MW | 6 | Datacenter |

The VLSI Fab and Cooling Tower are chemical-plant clones because both need
working fluid boxes. The Datacenter is the fourth research generation: it
accepts all workloads like its predecessors, and it is faster and more
module-hungry rather than being a hard gate.

**New technologies**

| Tech | Cost | Gate | Unlocks |
|---|---|---|---|
| VLSI Process | 250 + disk/prod/utility | 2 utility/s | VLSI Fab, Cooling Tower, coolant, cooling unit, phase-shift mask, CMP slurry, low-k dielectric, VLSI wafer/die, SoC |
| Datacenter | 300 + prod/utility | 3 utility/s | Datacenter |
| Advanced Packaging | 400 + prod/utility | 0.5 SoC/s | chiplet, HBM stack, GPU |
| Heterogeneous Compute | 500 + prod/utility | 0.2 GPU/s | multi-core CPU |

The last two gates measure **chip production**, not science packs. That is the
point of the era: you cannot research advanced packaging without a running
packaging line, and you cannot research heterogeneous compute without a GPU
line that is actually producing. The GPU line in turn needs coolant, so the
datacenter cooling loop is on the critical path without any extra scripting.

### 4.7 Era 7: quantum (v0.4)

Era 7 does not pretend that a Factorio base can build a fault-tolerant quantum
computer. It abstracts the parts that matter for gameplay: a cryogenic supply
chain, physical qubits, error correction, and a logical processor built from
many physical qubits.

| Step | Machine | Inputs | Output |
|---|---|---|---|
| Superconductor | Chemical plant | copper, steel, acid | superconductor |
| Cryogen | Cooling Tower | coolant, water | cryogen (fluid) |
| Qubit | Quantum Fab | superconductor, VLSI die, cryogen | qubit |
| Error-corrected qubit | Quantum Fab | 9 qubits, superconductor, cryogen | error-corrected qubit |
| Quantum processor | Quantum Fab | error-corrected qubits, superconductor, low-k, cryogen | quantum processor |
| Qubit array | Quantum Fab | qubits, cryogen | qubit array (workload) |

The **Qubit Array** is a seventh workload: a rack of physical qubits that the
Cryostat consumes while researching. It is deliberately made only from physical
qubits, not logical ones, so error correction can be researched without already
having error correction. Error-corrected qubits are what the quantum processor
is built from, and they are what the final gate measures.

**New machines**

| Machine | Base | Category | Speed | Power | Modules | Unlock |
|---|---|---|---|---|---|---|
| Quantum Fab | chemical plant | `chipotrio-quantum` | 1.5 | 1.2 MW | 4 | Quantum Computing |
| Cryostat | lab | - | 4.0 | 3 MW | 8 | Quantum Computing |

The Quantum Fab is another chemical-plant clone because every quantum step
consumes cryogen. The Cryostat is the fifth research generation. Like its
predecessors it accepts **all** workloads, including Qubit Arrays, so the
vanilla tech tree cannot deadlock. Its speed and eight module slots are the
reward for the Era 7 supply chain, not a gate.

**New technologies**

| Tech | Cost | Gate | Unlocks |
|---|---|---|---|
| Quantum Computing | 600 + prod/utility | 0.2 multi-core CPU/s | Cryostat, Quantum Fab, cryogen, superconductor, qubit, Qubit Array |
| Quantum Error Correction | 400 + qubit array/utility | 0.25 qubit/s | error-corrected qubit |
| Quantum Advantage | 500 + 2 qubit arrays/utility | 0.1 error-corrected qubit/s | quantum processor |

All three gates measure **production**. A stockpile of multi-core CPUs, qubits
or logical qubits cannot carry the research: the line has to be running. The
error-correction gate is the first one that requires a product whose own recipe
is unlocked by the technology being researched, which is why the Qubit Array
recipe intentionally depends only on physical qubits.

The quantum processor is used in late-game vanilla equipment (spidertron) and
will be a required ingredient for *The Question* in 0.5. That keeps the final
era connected to the rest of the factory instead of being a self-contained
curiosity.

## 5. "No controllable parts before microprocessors"

The early game deliberately has no programmable automation:

- The **circuit network** (wires, combinators, speakers) requires
  `Electromechanics`, which is an early but real research step.
- Inserters, belts, trains and boilers are electromechanical and remain
  available - they do not need software.
- Late-game entities are re-costed to contain chips:
  assembling machine 3, beacon, roboport, programmable speaker, spidertron.

The intent: the first time you place a combinator should feel like the first
time you place a *computer*, not like a tutorial step.

## 6. Balance framework

Current numbers are first-pass and explicitly tunable. The framework:

**Time targets (experienced player, default settings)**

| Milestone | Target |
|---|---|
| Analytical Engine running | 10-20 min |
| Thermionics | 45-60 min |
| Chemical science (disk packs) | 2.5-3.5 h |
| First wafer | 3.5-4 h |
| First IC | 4.5-5 h |
| First microprocessor | 6-7 h |
| Era 5 (VLSI) | 9-10 h |
| Era 6 (GPU) | 12-14 h |
| Era 7 (quantum) | 18-22 h |

**Cost multipliers**

- One ingot of crystal = 32 silica = 40 stone. One ingot yields 8 wafers.
  One IC consumes roughly 0.2 ingot-equivalents. This is intentionally
  stone-hungry: silica mining must become a real outpost.
- Workload chain adds ~50% cumulative cost per tier, not a multiplier.
- Throughput gates are set at roughly 1/3 of what a player can build with the
  previous era's technology, so clearing the gate requires deliberate scaling,
  not luck.

**What to tune first when playtesting**

1. `photolithography` gate (3 tape/s) - the first real "build a factory" wall.
2. Silica-to-stone ratio - controls how much the map opens up.
3. Analytical Engine cost - controls the first 10 minutes.
4. Lab power draw - controls how fast the player must scale power.
5. Coolant-to-VLSI ratio - controls whether Era 5 is a supply chain or a
   formality. The Cooling Tower is intentionally cheap; the cost is plumbing.
6. Cryogen-to-qubit ratio - controls how much of Era 7 is cooling infrastructure.
   The Quantum Fab should never be the only thing starving for cryogen.

## 7. Endgame: The Answer (decided)

**Decision:** the mod ends with **The Answer**, the comedy ending. It is the
only candidate that fits the tone of a game about building increasingly
absurd computers to answer questions nobody asked.

**Implemented in 0.5:**

1. **The Answer Engine.** A 5x5 lab clone with no science-pack inputs and no
   research speed. It is assembled in a Server Rack from every prior era:
   monocrystalline ingots, phase-shift masks, server racks, datacenters,
   cryostats, multi-core CPUs, quantum processors, advanced circuits and steel.
   It is a building, not a menu button.
2. **The question.** *The Question* is an infinite final technology. Level 1
   costs all seven workloads plus microprocessors, requires every Chip'torio
   technology, and unlocks the Answer Engine. Because it is infinite, it also
   remains the post-game sink.
3. **The computation.** Booting requires a sustained production rate of all
   seven workloads **and** microprocessors, read from the same rolling
   one-minute production statistics as the mid-game gates. Unlike the mid-game
   gates, this one is multi-input: overbuilding one pack cannot carry it.
4. **The wait.** The engine runs for **42 minutes** of real time. The clock
   advances one second only while every required line is at or above target.
   Dropping below any target pauses the clock; recovering resumes it
   automatically. The custom engine panel shows every current rate, the
   remaining time, the question level and the answer score.
5. **The answer.** At the end, a scripted event prints `42` above the machine,
   plays a generated chiptune fanfare, sets a custom victory screen with a
   generated portrait image, and leaves the save playable.
6. **Post-game.** Every level of *The Question* raises the engine's demand by
   25% and awards 42 more points per completion. The engine can be run again
   from its panel, so the infinite technology is a real megabase sink rather
   than a dead end.

Base targets: 10/s punched cards, 10/s punched tape, 10/s magnetic tape, 6/s
disk packs, 4/s solid-state drives, 2/s mainframe modules, 0.5/s qubit arrays
and 1/s microprocessors. These live in `scripts/answer_meta.lua` and are shared
by the panel and the runtime.

Why this over the alternatives: a wafer-scale hypercomputer (A) is the more
"serious" ending, but it is fundamentally the same factory test with a
straighter face. The Answer lets the final machine be deliberately ridiculous
while the *requirement* stays serious. Seed AGI (B) risks a magic tech;
endless Moore's law (D) has no closure. The Answer can absorb D as its
post-game.

### Considered and rejected

- **Wafer-Scale Hypercomputer.** Strong thematic endpoint, but tonally
  interchangeable with any other "build the biggest thing" victory.
- **Seed AGI.** Narrative-heavy; the win condition drifts away from the
  factory.
- **Endless Moore's Law.** Kept as the post-game, not the ending.

## 8. Implementation architecture

```
data.lua                  requires prototype modules in dependency order
data-updates.lua          touches vanilla after all mods have loaded
control.lua               requires runtime modules
settings.lua              runtime-global toggles
scripts/
  util.lua                deepcopy / prototype cloning / icon / tint helpers
  items.lua               item groups, subgroups, all new items
  fluids.lua              photoresist, etchant, CMP slurry, coolant, cryogen
  machines.lua            fab tier: wafer fab, crystal puller, server rack, VLSI fab, cooling tower, quantum fab
  labs.lua                five research-computer generations
  silicon.lua             sand -> wafer chain
  chips.lua               glass, tubes, transistors, ICs, CPUs
  era5.lua                VLSI, cooling loop, chiplets, GPUs, multi-core CPUs
  era7.lua                cryogen, superconductors, qubits, error correction, quantum processors
  workloads.lua           renames + re-recipes the six vanilla science packs (the seventh lives in era7.lua)
  endgame.lua             the 5x5 Answer Engine entity, item and recipe
  answer_meta.lua         shared final-exam rates, runtime and score constants
  technology.lua          new techs, including the infinite The Question
  tech_meta.lua           throughput requirements (shared data/runtime)
  rates.lua               shared production-rate reader
  research_gate.lua       runtime enforcement + debug remote interface
  answer_engine.lua       runtime clock, engine panel, victory screen and score
graphics/
  icons/                  generated 64x64 item, fluid and machine icons
  technology/             generated 256x256 technology icons
tools/
  make-icons.ps1          regenerates the entire icon set, thumbnail and victory image
  make-sound.ps1          synthesises the Answer Engine fanfare
  test-mod.ps1            headless data-stage validation
  test-gate.ps1           runtime regression test for the throughput gate
```

### Key engineering decisions

1. **Clone entities, generate icons.** Every machine is a deep copy of a base
   prototype with only identity, category, stats and a tint changed, so all
   2.1 sprite and fluid-box plumbing stays valid. Icons are generated
   procedurally by `tools/make-icons.ps1` as chunky 16x16 pixel art upscaled
   to 64x64 (and 256x256 for technologies). No hand-authored art is required,
   and nothing can reference a missing file.
2. **Keep vanilla prototype names.** Science packs keep their internal names;
   only `localised_name` and recipe change. This is why the vanilla tech tree
   works without touching ~200 technologies.
3. **Throughput from statistics, not per-tick bookkeeping.** The gate reads
   `LuaForce::get_item_production_statistics(...):get_flow_count`. No entity
   scanning, no UPS cost, no desync surface.
4. **Data-driven gate metadata.** `tech_meta.lua` is pure data, required by
   both stages, so the tooltip and the enforcement can never disagree.
5. **Custom categories, base machine shells.** Recipes use
   `chipotrio-fab`, `chipotrio-crystal`, `chipotrio-compute`,
   `chipotrio-vlsi`, `chipotrio-cooling` and `chipotrio-quantum`, so the
   economy can be re-housed later without touching a single recipe.

### Testing

- `tools/test-mod.ps1` loads the data stage, creates a map and runs a short
  benchmark; it fails on data-stage errors.
- `tools/test-gate.ps1` starts a gated technology in a probe save and asserts
  that the gate freezes progress and decays at exactly 2% per minute.
- `tools/make-icons.ps1` regenerates every icon and the thumbnail
  deterministically, so the art can be rebuilt from source at any time.

### Notable 2.1 API facts learned while building this

- Technology science ingredients are the **legacy positional form**
  `{"item-name", amount}` - not the typed recipe-ingredient struct.
- `RecipePrototype.category` was merged into `categories = {...}`.
- Recipes in the `"crafting"` category **cannot** have fluid ingredients;
  fluid steps need a machine with fluid boxes (here: the chemical-plant-based
  Wafer Fab with a custom `chipotrio-fab` category).
- `LabPrototype` (and other entities) use a single `icon` string, while items
  use `icons = {{icon=..., icon_size=...}}`. Mixing them up is a data error.
- Item groups use a single `icon` **and** inherit `icon_size` (128 on the
  vanilla groups). Replace both fields if the new icon is 64x64.
- The first science pack is unlocked by a **trigger technology** that fires
  when a lab is crafted. Hiding the lab therefore requires retargeting
  `automation-science-pack.research_trigger` or a fresh save cannot start.
- Localised strings use `__1__`, `__2__` placeholders, **not** C-style `%s` / `%d`.
- Prototype-localised parameters must be strings or nested LocalisedStrings;
  numbers are rejected at load. Runtime `player.print` is more forgiving, but
  the code converts numbers to strings everywhere to keep one rule.
- In `LuaFlowStatistics`, `input` is the **production** column and `output`
  is the **consumption** column.
- Adding a seventh workload means adding a real `item` prototype, appending it
  to **every** lab's `inputs` list, and using it in `technology.unit.ingredients`.
  Miss the lab input and the technology can load but never be researched.
  `scripts/labs.lua` and the data-stage probe both assert this.

## 9. Roadmap

| Version | Scope |
|---|---|
| 0.1 (done) | Era 0-4 slice, silicon chain, IC, CPU, throughput gate |
| 0.2 (done) | Fab entities (fluid boxes, categories, power draw), generated icon + tech art pass |
| 0.3 (done) | Era 5-6: VLSI, multi-core, GPU, datacenter cooling loop |
| 0.4 (done) | Era 7: cryostats, qubits, error correction, quantum processors |
| 0.5 | The Answer: multiblock engine, 42-minute compute, victory event, infinite post-game |
| 0.6 | Full rebalance, biters/pollution pass, multiplayer test |
| 1.0 | Art, sound, achievements, portal release |

## 10. Open questions

1. ~~**Endgame:** A, B, C or D?~~ Decided: **The Answer** (section 7).
2. **How vanilla should the first hour be?** Currently almost 1:1 except the
   lab replacement. Could add a "no electricity" mechanical start.
3. **Biters:** keep as pressure, remove for a pure puzzle, or repurpose as
   "thermal throttling" events?
4. ~~**How hard should the throughput gates bite?**~~ Decided: linear throttle
   below the required rate, plus a 2%/min decay at zero production (section 3.2).
5. **Do we keep vanilla military science**, or replace it with a "sensor /
   signal processing" workload? Computing and radar are thematically close.
6. **Multiplayer:** should throughput be per-force (current) or per-surface?
7. ~~**Art direction:** retro-terminal / chiptune palette, or clean industrial?~~
   Starting point: retro-terminal (dark slate, cyan, amber, magenta). Easy to
   repaint because every icon is generated from one palette block.
