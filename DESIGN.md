# chiptorio — Design Specification

Status: authoritative design; Phase 0 in progress  
Date: 2026-10-26  
Mod ID: `chiptorio`  
Target: Factorio 2.1, no Space Age, Nauvis only  
Authority: this file is the design and architecture reference for the 1.0 redesign. Read §15 before changing prototypes and §16 before changing behaviour.

---

## 0. Decision log

Confirmed decisions:

1. The mod is named **chiptorio**, not `chipotrio`.
2. The sustained-production throughput gate is removed.
3. Research is gated by a computer network: compute/s, memory, and bandwidth.
4. The internet unlocks after the first microprocessors.
5. Labs connect to the network and see all compute on it.
6. Datacenters are built to supply compute.
7. Memory stores research datasets and QLN item storage.
8. QLN is an AE2-like logistics network with a strong gameplay goal and a quantum late game.
9. All robots are removed.
10. Biters are removed; pollution gameplay is disabled.
11. Semiconductor progression is granular: process nodes, lithography methods, transistor architectures, packaging, memory generations, CPU architecture, and infinite research.
12. The Answer Engine remains the endgame and keeps the 42 motif.
13. Every mechanic is tested: pure logic, data contracts, runtime integration, save/load, and performance.
14. **Node scope:** 12 major process nodes + 10 half-node refinements.
15. **Half-node refinements require a qualification step**, not just research.
16. **Tech tree:** Option A — a new chiptorio progression tree with a Foundation chapter that reorganizes/clones the vanilla tech spine; military, bot, and enemy technologies are removed.
17. v0.5 saves break; no migration.
18. Versioning: `0.6.0` is the first internet-enabled build; `1.0.0` is the complete redesign.

Open decisions are listed in §19.

---

## 1. Vision and pillars

**Pitch:** Build the semiconductor industry from relays to quantum processors, then connect every machine into a network that turns raw compute into answers.

Pillars:

1. **Computers are infrastructure.** Labs are clients. Datacenters, memory, switches, and routers are the factory.
2. **Research is a network workload.** It needs compute/s, memory, and bandwidth, not a stockpile.
3. **Progress is granular.** Real process nodes, lithography, transistor, packaging, memory, and architecture branches.
4. **No biters, no bots.** The map is a pure industrial/engineering puzzle.
5. **Nothing is a menu button.** Internet, memory, logistics, and the ending are built as entities and supply chains.
6. **Everything is testable.** Pure modules, data contracts, runtime scenarios, persistence, performance.
7. **The name is chiptorio.** Every ID, path, locale key, and remote interface follows it.

---

## 2. Naming and compatibility

Rename scope:

- `info.json` `name` → `chiptorio`
- asset paths → `__chiptorio__/...`
- locale prefix → `chiptorio.`
- remote interfaces → `chiptorio`, `chiptorio-network`, `chiptorio-answer`, `chiptorio-tests`
- prototype prefixes → `chiptorio-`
- script module paths, test directories, docs, tooling
- repository references and generated asset scripts

Compatibility:

- Old `chipotrio` saves will not load. This is accepted.
- No migration layer for v0.5.
- The repository folder and mod folder become `chiptorio`.
- Version `0.6.0` is the first playable redesign build; `1.0.0` is the complete content release.

---

## 3. Scope and non-goals

In scope:

- complete tech-tree rebuild (Option A)
- network/compute/memory/bandwidth economy
- 12 major nodes + 10 half-node refinements
- lithography, transistor, packaging, memory, architecture branches
- QLN pre-quantum and quantum logistics
- Construction Core
- Answer Engine rework
- infinite research
- test harness and full test suite
- generated icons, cable sprites, tech icons, locale

Out of scope for 1.0:

- Space Age planets or interplanetary logistics
- true multiprocessor simulation on the GPU
- full AE2 autocrafting (stretch goal after core QLN)
- random hardware failures
- competitive multiplayer balance
- hand-authored entity art (continue cloned/tinted prototypes for 1.0)

---

## 4. Progression structure

### 4.1 Chapters

Six chapters, deeper than the current eight thin eras:

1. **Foundation** — basic automation, power, belts, inserters, oil, trains, construction.
2. **Electromechanical** — relays, vacuum tubes, punched cards, first computers.
3. **Discrete Semiconductors** — transistors, diodes, early logic, magnetic storage.
4. **Microelectronics** — 10 µm → 1 µm, first ICs, CPUs, internet.
5. **VLSI/ULSI** — 350 nm → 90 nm, fabs, packaging, datacenters.
6. **Nanoscale** — 45 nm → 3 nm, FinFET/GAA, EUV, chiplets, QLN.
7. **Quantum/Endgame** — QPUs, cryogenics, Answer Engine.

(Seven labels including Foundation; “six semiconductor chapters” plus Foundation is also acceptable wording.)

### 4.2 Tech tree — Option A

- The vanilla progression tree is hidden or removed.
- A new chiptorio tree is built from scratch.
- The **Foundation** chapter is a reorganized, curated vanilla spine: automation, electronics, oil, trains, construction. It may clone/rewrite vanilla technologies rather than re-inventing every base recipe.
- Military, bot, and enemy technologies are removed.
- Chip, internet, memory, QLN, packaging, and process branches are entirely new.
- Every recipe must be unlocked by exactly one technology or explicitly enabled from the start.
- Every technology must be reachable from the start.
- Technology chapters are implemented as technology groups if the 2.1 prototype supports them; otherwise as prerequisite clusters and explicit ordering.

Data-contract tests enforce:

- no orphan recipes
- no unreachable technologies
- no technology cycle
- every lab accepts every science pack
- every technology’s ingredients are valid
- no military/bot/enemy prototype references remain

### 4.3 Science packs

Nine packs. The six vanilla internal names remain; three are custom.

| Display name | Internal name | Role |
|---|---|---|
| Punched Card | `automation-science-pack` | early logic |
| Punched Tape | `logistic-science-pack` | automation/control |
| Magnetic Tape | `military-science-pack` | storage/network/control (no military use) |
| Disk Pack | `chemical-science-pack` | process/chemistry |
| Solid-State Drive | `production-science-pack` | VLSI/packaging |
| Mainframe Module | `utility-science-pack` | advanced compute |
| Optical Disc | `chiptorio-optical-science-pack` | photonics/networking |
| HBM Stack | `chiptorio-hbm-science-pack` | memory/advanced packaging |
| Qubit Array | `chiptorio-quantum-science-pack` | quantum |

Every lab accepts all nine. Technologies use subsets, not all packs. The first internet technology uses pre-internet packs and requires no compute.

### 4.4 Major process nodes

Twelve major nodes create full item families and new production chains.

| # | Node | Year | Lithography | Transistor | Wafer | Packaging |
|---|---|---|---|---|---|---|
| 1 | 10 µm | 1971 | contact | PMOS | 50 mm | wire bond / DIP |
| 2 | 3 µm | 1977 | projection | CMOS | 100 mm | DIP / QFP |
| 3 | 1 µm | 1985 | i-line | CMOS | 150 mm | QFP / PGA |
| 4 | 350 nm | 1994 | KrF DUV | CMOS | 200 mm | BGA |
| 5 | 180 nm | 1999 | KrF DUV | CMOS | 200 mm | flip-chip |
| 6 | 90 nm | 2003 | ArF DUV | strained Si | 300 mm | flip-chip |
| 7 | 45 nm | 2007 | immersion | high-k/metal gate | 300 mm | flip-chip |
| 8 | 22 nm | 2011 | multi-patterning | FinFET | 300 mm | 2.5D |
| 9 | 14 nm | 2014 | multi-patterning | FinFET | 300 mm | 2.5D |
| 10 | 7 nm | 2018 | EUV | FinFET | 300 mm | chiplet |
| 11 | 3 nm | 2022 | EUV | GAA | 300 mm | 3D |
| 12 | 1.4 nm | 2028 | high-NA EUV | CFET | 300 mm | hybrid bonding |

Each major node adds:

- node wafer item
- node die item
- node CPU item
- node GPU item (where appropriate)
- node process kit or mask set
- node fab machine or fab upgrade
- node recipes and technologies
- node science-pack costs
- node chip profile

### 4.5 Half-node refinements and qualification

Ten half-nodes improve the previous major node. They do **not** add a new wafer/die/chip family.

| Half-node | Between | Main improvement |
|---|---|---|
| 6 µm | 10 µm → 3 µm | yield, density |
| 1.5 µm | 3 µm → 1 µm | yield, mask quality |
| 800 nm | 1 µm → 350 nm | density, 8-inch wafers |
| 250 nm | 350 → 180 nm | yield, copper readiness |
| 130 nm | 180 → 90 nm | density, 300 mm readiness |
| 65 nm | 90 → 45 nm | compute, power, yield |
| 32 nm | 45 → 22 nm | density, high-k refinement |
| 10 nm | 14 → 7 nm | density, multi-patterning |
| 5 nm | 7 → 3 nm | compute, GAA refinement |
| 2 nm | 3 → 1.4 nm | density, high-NA readiness |

#### 4.5.1 Two-stage refinement

A half-node is not finished when its technology is researched. It has two stages:

**Stage 1 — Research.** The technology is researched normally. It unlocks:

- a **Pilot Process** recipe in the previous node’s fab
- a **Metrology Lab** (if not already built)
- a **Qualification** objective in the tech/network GUI

**Stage 2 — Process qualification.** The player must run a pilot line and qualify the process:

1. Craft **Process Qualification Wafers** (PQWs) in the previous node’s fab.
   - Recipe consumes: previous-node wafer, a mask/process kit, photoresist, and a metrology test structure.
   - Output: 1 PQW.
2. Deliver PQWs to a **Metrology Lab** by inserter, belt, or QLN.
3. The Metrology Lab analyzes them over time:
   - consumes PQWs
   - fills a qualification bar
   - requires power
   - for post-internet half-nodes, also requires compute and memory
4. When the required number is analyzed, the half-node upgrade activates force-wide.

The upgrade applies to the previous major node:

- yield multiplier for wafer/die recipes
- compute multiplier for chips
- power/heat multiplier
- optional unlock of a process module for flavor

The technology remains “researched”, but its effects are gated until qualification is complete. The GUI must show this clearly:

> 65 nm Process — researched  
> Qualification: 37/100 test wafers analyzed  
> Requires: 20 CU/s vector, 16 GB memory, Metrology Lab online  
> Upgrade inactive until qualification completes.

#### 4.5.2 Qualification data

Data-driven in the technology table:

```lua
qualification = {
  samples = 100,
  sample_item = "chiptorio-65nm-qualification-wafer",
  sample_recipe = "chiptorio-65nm-qualification-wafer",
  lab = "metrology-lab",
  analysis_time = 2.0,          -- seconds per sample
  compute = { scalar = 10, vector = 10 },
  memory = 16,                  -- GB
  requires_network = true,
  effects = {
    yield = 1.20,
    compute = 1.10,
    power = 0.85,
  },
}
```

Early half-nodes before the internet (6 µm, 1.5 µm) use `requires_network = false`. From 800 nm onward the Metrology Lab requires network compute/memory. This avoids a pre-internet deadlock while making later refinements a network task.

#### 4.5.3 Anti-grind rules

- Sample batch is modest: 50–150 depending on node.
- Analysis time is 1–3 seconds per sample.
- One Metrology Lab can handle a half-node; no need to build a second factory.
- No random failures.
- Qualification is per-force and persists across save/load.
- The pilot recipe is cheap enough to run from existing node production.
- The upgrade is global once qualified, so fabs do not need individual modules.

#### 4.5.4 Why this step exists

Research alone would make half-nodes just another bar to fill. The qualification step makes them **process engineering**:

- you must build a pilot line
- you must produce test wafers from the previous node
- you must analyze them in a metrology lab
- late half-nodes also consume network compute/memory

This is the real-life rhythm of a process shrink, and it prevents “research 65 nm, instantly better chips” from feeling free.

---

## 5. Internet and network

### 5.1 Entities

| Entity | Role |
|---|---|
| Network Cable | 1×1, no collision, blueprintable, connects adjacent cables |
| Switch | joins cable segments into one subnet; adds backplane bandwidth |
| Router | separates subnets; forwards traffic with throughput and latency |
| Repeater | extends cable range |
| Wireless AP | connects devices in range on a channel |
| Quantum Link | paired global link; endgame |
| Network Monitor | GUI for topology, stats, alerts, router config |
| Server Rack | small compute provider |
| Datacenter | large compute + memory provider |
| Memory Bank | memory modules |
| Cooling Tower | cooling capacity |
| Construction Core | builds/deconstructs ghosts from QLN |
| QLN Import Node | items into network storage |
| QLN Export Node | items out of network storage |
| QLN Terminal | player storage GUI |
| QLN Requester | pulls items from network |
| QLN Provider | supplies items to network |
| FOUP Dock | fills/empties sealed wafer carriers |
| Metrology Lab | half-node qualification analysis |

### 5.2 Topology

- **Subnet:** connected component of cables, switches, and device ports.
- **Network:** subnets joined by routers.
- Devices connect if a cable is within 2 tiles.
- Cable graph rebuilds only when entities/tiles change, not every tick.
- Rebuild is coalesced: mark dirty, rebuild on the next 10-tick or 60-tick job.
- Blueprints trigger the same rebuild path.

### 5.3 Stats and allocation

Per subnet:

- compute capacity
- memory capacity
- switch backplane bandwidth
- cable bandwidth
- power draw
- heat and cooling
- device list
- latency

Per network:

- reachable subnets
- router throughput
- total compute, memory, bandwidth
- research demand
- QLN storage and item throughput

Allocation:

```
usable_compute = min(total_compute, total_bandwidth)
lab_demand     = tech.compute_per_lab * lab.compute_multiplier
active_labs    = min(labs_with_packs, floor(usable_compute / lab_demand))
```

- Each active lab consumes its compute demand and researches normally.
- Inactive labs are switched off so they do not consume packs.
- If `active_labs == 0`, research freezes and decays.
- If memory is below `tech.memory`, research freezes and decays.
- If usable compute is below `tech.compute_floor`, progress decays proportionally.
- Above the floor, speed is determined by how many labs the network supports.

### 5.4 Power and cooling

- Servers draw power continuously.
- Servers produce heat.
- Datacenters have built-in cooling.
- Cooling Towers provide cooling capacity and consume power/water.
- If heat > cooling, compute throttles proportionally.
- If power satisfaction is below 100%, compute throttles proportionally.

### 5.5 GUI and overlay

- Hotkey toggles network overlay.
- Cables/devices colored by subnet.
- Link utilization shown by line thickness/color.
- Network Monitor tabs: Overview, Topology, Devices, Alerts, Routing.
- “Locate” buttons ping entities.
- Alerts: no route, loop, memory full, compute starved, cooling insufficient, power low.
- GUI updates every 30–60 ticks, not every tick.

---

## 6. Compute and datacenters

### 6.1 Profiles

| Profile | Source | Used by |
|---|---|---|
| Scalar | CPU | general research |
| Vector | GPU | physics, simulation, metrology |
| Tensor | NPU | AI, design, optimization |
| Quantum | QPU | quantum chemistry, cryptography, endgame |

Early techs need scalar only. Later techs require mixed profiles. A network must supply every required profile; surplus of one cannot cover another.

### 6.2 Server Rack

- 4 chip slots.
- Base power draw and heat.
- Base network port.
- Compute is the sum of installed chips × power × cooling × infinite multipliers.

### 6.3 Datacenter

- 8 chip slots.
- 4 memory slots.
- Built-in cooling.
- Higher bandwidth port.
- Much higher power draw.
- Mid/late-game concentration of compute.

### 6.4 Chips

Chips are custom module items with zero vanilla module effect. The script reads the module inventory.

Example profiles (first-pass):

| Chip | Scalar | Vector | Tensor | Quantum | Power | Heat |
|---|---:|---:|---:|---:|---:|---:|
| 10 µm CPU | 1 | 0 | 0 | 0 | 10 kW | 1 |
| 1 µm CPU | 4 | 0 | 0 | 0 | 25 kW | 2 |
| 90 nm CPU | 16 | 0 | 0 | 0 | 60 kW | 4 |
| GPU | 0 | 4× CPU | 0 | 0 | 100 kW | 6 |
| NPU | 0 | 0 | 8× CPU | 0 | 120 kW | 7 |
| QPU | 0 | 0 | 0 | 64× CPU | 500 kW | 20 |

### 6.5 Memory Bank

- 4 memory module slots.
- Each module adds capacity and bandwidth.
- Memory generations differ in capacity, bandwidth, and power.
- ECC is optional later.

---

## 7. Research

### 7.1 Lab tiers

| Lab | Speed | Compute demand | Role |
|---|---:|---:|---|
| Analytical Engine | 0.5 | 0.5 CU/s | pre-internet |
| Tube Mainframe | 1.0 | 2 CU/s | early network |
| Mainframe Cluster | 1.75 | 8 CU/s | mid |
| Datacenter Lab | 2.5 | 32 CU/s | late |
| Cryostat | 4.0 | 128 CU/s | quantum |

A lab must be connected to a cable within 2 tiles. Pre-internet techs work offline. Post-internet techs require network compute.

### 7.2 Technology schema

```lua
{
  name = "process-7nm",
  chapter = "nanoscale",
  node = "7nm",
  prerequisites = { ... },
  unit = {
    ingredients = { ... },
    time = 60,
    count = 500,
  },
  compute = {
    floor = 400,
    per_lab = 100,
    profiles = { scalar = 0.4, vector = 0.4, tensor = 0.2 },
  },
  memory = 512,
  bandwidth = 400,
  effects = { ... },
  qualification = nil, -- or the half-node table
}
```

The data stage generates tooltips from this table. Runtime uses the same table. One source of truth.

### 7.3 Decay

- At zero usable compute or insufficient memory: 2%/min progress decay.
- Below the compute floor: proportional decay, max 2%/min.
- Above the floor: no decay.
- If labs are active but below full speed: slower progress, no decay unless below the floor.
- Setting `chiptorio-strict-network`; default on.

### 7.4 Internet unlock

- Unlocks after the first microprocessor.
- The internet technology requires no compute.
- It unlocks Cable, Switch, Network Monitor, and the first Server Rack.
- First Server Rack uses microprocessors, circuits, steel, and cooling.
- First memory module is SRAM; first memory-gated tech is small.
- No deadlock: the player can always build the first network with pre-internet tech.

### 7.5 Anti-deadlock

- Every lab accepts every science pack.
- Every technology’s packs are accepted by every lab tier.
- No technology requires a compute profile that no available chip provides.
- No technology requires more memory than the tier can build.
- Every prerequisite is researchable without the technology it unlocks.
- Data-contract tests enforce these rules.

---

## 8. Memory

Memory has two uses.

### 8.1 Research datasets

Each technology has a dataset size. When research starts, that much memory is reserved. If memory is insufficient, research cannot start. If memory is lost, research decays.

### 8.2 QLN item storage

Memory modules also provide item storage for QLN.

- Storage cells: 1k / 4k / 16k / 64k / 256k items.
- DDR3 cells are cheap and slow.
- HBM cells are fast and expensive.
- 3D NAND cells are dense and slow.

### 8.3 Generations

| Generation | Era | Capacity | Bandwidth | Notes |
|---|---|---:|---:|---|
| SRAM | early | tiny | high | cache, first network |
| DRAM | 3 µm | small | medium | first main memory |
| SDRAM | 1 µm | medium | medium | synchronous |
| DDR | 350 nm | medium | high | double data rate |
| DDR2 | 180 nm | large | high | |
| DDR3 | 90 nm | larger | higher | QLN storage cells |
| DDR4 | 45 nm | very large | higher | |
| DDR5 | 22 nm | huge | very high | |
| HBM | 14 nm | huge | extreme | 2.5D packaging |
| HBM3 | 7 nm | massive | extreme | 3D packaging |
| 3D NAND | 7 nm | massive | low | QLN bulk storage |

Infinite research: memory density and memory bandwidth.

---

## 9. QLN — AE2-like logistics

Name: **Quantum Logistics Network**, with a pre-quantum stage called the **Data Bus**.

### 9.1 Pre-quantum QLN

- **Import Node** — pulls items from an adjacent chest/belt/machine into network storage.
- **Export Node** — pushes items from network storage into an adjacent inventory/belt.
- **Storage Drive** — holds storage cells; provides capacity.
- **Terminal** — player GUI: search, deposit, withdraw, see counts.
- **Requester Node** — requests items from network storage.
- **Provider Node** — supplies items to the network.
- **Network links** — the same cables/subnets/routers; throughput in items/s.
- **Channels** — optional; each node consumes a channel, switches provide channels. Default: bandwidth only, channels later if needed.

No bots. This is how items move across the base at scale.

### 9.2 Quantum QLN

- **Quantum Entanglement Core** — paired endpoints.
- Connects two networks globally, regardless of distance.
- Very high power, limited bandwidth, expensive.
- Unlocks remote outposts, orbital-style separation, and endgame logistics.

### 9.3 The goal

Three reinforcing reasons:

1. **The Answer Engine requires it.** The final machine needs thousands of items per minute of many types. Belts and trains cannot feed it cleanly. The engine’s item supply is QLN-native.
2. **Advanced nodes require FOUP logistics.** Below a certain node (45 nm and below), wafers/dies are contamination-sensitive. They are stored and moved in **FOUPs** (front-opening unified pods). FOUPs are filled/emptied only at **FOUP Docks**, and the QLN is the practical way to route them between fabs, packaging, and metrology. Belting FOUPs is possible but slow and space-hungry; the QLN is the intended path.
3. **No bots.** QLN replaces logistic bots entirely, and the Construction Core replaces construction bots. A large base is a network base.

Not a hard “you cannot belt this” rule. Strong incentive + endgame requirement, not a prohibition.

### 9.4 Construction Core

- 3×3 entity, power, range 32.
- Builds and deconstructs ghosts using QLN storage.
- Speed limited by construction power and item availability.
- No bot entities, no roboports, no personal roboport.
- Early game: manual building. Mid game: Construction Core.
- Required for the no-bots design to be playable.

### 9.5 Optional stretch: pattern crafting

AE2-style autocrafting is a large feature. Ship storage/transport/requester first; add Pattern Provider + Crafting Core later if the core loop feels good. Do not let autocrafting block the network/compute redesign.

---

## 10. Semiconductors

### 10.1 Lithography methods

Ten methods, each a technology and a machine/module unlock:

1. Contact lithography
2. Proximity lithography
3. Projection lithography
4. i-line stepper
5. KrF DUV (248 nm)
6. ArF DUV (193 nm)
7. ArF immersion
8. Double/multi-patterning
9. EUV (13.5 nm)
10. High-NA EUV

Each method has a mask/resist/etch recipe chain. The machine tier determines which nodes it can process.

### 10.2 Transistor architectures

PMOS → NMOS → CMOS → HMOS → FinFET → GAA nanosheet → CFET.

Each is a technology that unlocks the next node family and improves density/efficiency.

### 10.3 Packaging and assembly

Wire bond → DIP → QFP → BGA → flip-chip → TSV → 2.5D → 3D stacking → chiplet → hybrid bonding.

Packaging affects:

- chip compute (power delivery, interconnect)
- memory bandwidth (HBM needs 2.5D)
- heat
- QLN/FOUP requirements

### 10.4 Interconnect, wafer size, metrology

- **Interconnect:** aluminum → copper → low-k → air gap → optical.
- **Wafer size:** 50 → 100 → 150 → 200 → 300 mm; affects dies per wafer and machine tier.
- **Metrology/yield:** inspection, defect density, cleanroom class, ECC, redundancy; improves yield and memory reliability.
- **Cooling:** air → liquid → immersion → cryogenic.
- **Power delivery:** VRM → PMIC → voltage scaling; improves efficiency.
- **Software:** assembler → compiler → OS → parallel runtime → virtualization → AI framework.

### 10.5 Infinite research

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

Use existing Factorio effects where possible. Scripted force-level multipliers only for compute/memory/network/cooling.

### 10.6 Content estimate

- ~120–160 items
- ~180–240 recipes
- ~120–150 technologies
- ~20 machines/buildings
- ~18 network/logistics entities
- 9 science packs
- 12 major nodes + 10 half-node refinements
- 10 lithography methods
- 7 transistor architectures
- 10 packaging methods
- 11 memory generations

---

## 11. Removal of biters and bots

### 11.1 Biters

- Disable enemy autoplace for new maps.
- On configuration change, destroy enemy spawners/worms/units in existing maps.
- Remove military technologies, weapons, ammo, turrets, walls, gates, artillery, tanks, spidertron, land mines.
- Keep non-military vehicles/trains if useful for bulk transport.
- Repurpose `military-science-pack` as magnetic tape.
- Pollution gameplay disabled. Optional later: particulate contamination affecting cleanroom yield.

### 11.2 Bots

Remove:

- roboports
- logistic robots
- construction robots
- personal roboport
- spidertron
- robot-related technologies and equipment

Replace with:

- QLN for item logistics
- Construction Core for building/deconstruction
- manual early game

---

## 12. Endgame: The Answer

Keep the 42 motif, the victory screen, and the fanfare. Replace the production-rate check with a network/compute final exam.

The Answer Engine is a 5×5 network-connected machine that requires:

- a minimum compute rate of all four profiles
- a large memory dataset
- a minimum network bandwidth
- continuous QLN supply of science packs, microprocessors, and quantum processors
- a 42-minute computation

If requirements are unmet:

- the clock pauses
- stability decays
- the panel shows exactly what is missing

At completion:

- prints `42`
- plays the fanfare
- sets the victory screen
- awards points
- unlocks/levels **The Question** infinite research

Each level of The Question raises compute, memory, bandwidth, and item demand by 25% and awards 42 more points. The engine is rerunnable and remains a megabase sink.

---

## 13. Balance framework

### 13.1 Time targets

| Milestone | Target |
|---|---|
| Analytical Engine | 10–20 min |
| First vacuum tube | 45–60 min |
| First IC | 3–4 h |
| First microprocessor | 5–6 h |
| Internet unlocked | 6–8 h |
| First server rack + network | 7–9 h |
| First datacenter | 10–12 h |
| 90 nm | 14–16 h |
| 7 nm | 22–26 h |
| Quantum | 30–35 h |
| Answer Engine | 40–50 h |

### 13.2 Cost shape

- Early: 10–50 packs, 1–10 CU/s, 0–16 MB memory.
- Mid: 100–500 packs, 50–200 CU/s, 1–16 GB memory.
- Late: 1,000–5,000 packs, 1,000–5,000 CU/s, 100 GB–1 TB memory.
- Endgame: 10,000+ packs, 10,000+ CU/s, 1+ PB memory.

Formula:

```
cost(n)    = base * growth^(node_index)
compute(n) = base_compute * 4^(node_index / 3)
memory(n)  = base_memory * 8^(node_index / 3)
```

Playtest and adjust the curve, not every entry.

### 13.3 Yield

| Node | Base yield |
|---|---:|
| 10 µm | 90% |
| 1 µm | 80% |
| 90 nm | 65% |
| 7 nm | 45% |
| 3 nm | 30% |

Yield multiplies dies per wafer. Metrology, cleanroom, half-node qualifications, and infinite research raise it.

### 13.4 Anti-frustration

- Internet tech requires no compute.
- First server rack is cheap.
- First memory module is small.
- Every lab accepts every pack.
- Every tech’s prerequisites are reachable.
- Decay is capped and documented.
- GUI shows exactly what is missing.
- No random failures.
- No hard “you cannot belt this” rules.

---

## 14. UX

- **Research panel:** compute required/available, labs active, memory, bandwidth, ETA, decay warning, qualification progress.
- **Network monitor:** overview, topology, devices, alerts, router config, subnet colors.
- **Entity tooltips:** ports, power, heat, compute profile, memory capacity.
- **Item tooltips:** chip profile, memory generation, QLN capacity.
- **Alerts:** compute starved, memory full, no route, router bottleneck, cooling insufficient, power low, qualification stalled.
- **Overlay:** cable/subnet visualization, link utilization.
- **Locale:** all new items/entities/techs; `__1__` placeholders.
- **Icons:** generated 64×64 items, 256×256 tech icons, cable sprites, network icons.
- **Sound:** keep the generated fanfare; add terminal/network sounds later.
- **Remote interface:** `chiptorio.network`, `chiptorio.research`, `chiptorio.logistics`, `chiptorio.tests`, `chiptorio.spawn`.

---

## 15. Architecture

```
info.json
data.lua
data-updates.lua
settings.lua
control.lua
scripts/
  core/
    util.lua
    events.lua
    storage.lua
  data/
    items.lua
    fluids.lua
    machines.lua
    labs.lua
    network.lua
    memory.lua
    chips.lua
    logistics.lua
    endgame.lua
    vanilla.lua
  tech/
    schema.lua
    foundation.lua
    process.lua
    lithography.lua
    compute.lua
    memory.lua
    network.lua
    packaging.lua
    software.lua
    infinite.lua
    endgame.lua
  runtime/
    network_graph.lua      -- pure logic
    network_alloc.lua      -- pure logic
    network_runtime.lua    -- events, storage, GUI
    research.lua
    memory.lua
    logistics.lua
    construction.lua
    answer.lua
    gui.lua
    migrations.lua
  tests/
    graph_spec.lua
    alloc_spec.lua
    research_spec.lua
    memory_spec.lua
    logistics_spec.lua
```

Rules:

- `data.lua` order: items/fluids → machines/labs → network/memory/chips → recipes → technologies.
- `data-updates.lua` only touches vanilla after all mods load.
- `control.lua` owns one `on_nth_tick(60)` dispatcher.
- Runtime state lives in `storage`, versioned and initialized in `on_init` and `on_configuration_changed`.
- Pure modules never touch `game` or `storage`.
- Prototypes are cloned from base entities; icons and cable sprites are generated.
- Tech data is pure tables; `tech/schema.lua` validates it at load time.

---

## 16. Testing

### 16.1 Unit tests

Graph, allocation, research, memory, QLN, infinite multipliers, property tests, golden tests.

### 16.2 Data-contract tests

Icons, locale, recipes, categories, tech DAG, reachability, lab inputs, science packs, chip profiles, memory modules, network entities, no military/bot/enemy remnants, no throughput-gate references, qualification tables.

### 16.3 Runtime integration tests

- internet unlock
- no compute → decay
- enough compute → progress
- memory gate
- bandwidth gate
- multiple subnets + router
- cable removal
- power/cooling throttle
- blueprint rebuild
- save/load
- force isolation
- QLN storage/transport
- Construction Core
- half-node qualification
- Answer Engine victory/score
- infinite scaling

### 16.4 Performance tests

- 10,000 cables
- 1,000 providers
- 200 labs
- 100 routers/subnets
- tick time and graph rebuild time

### 16.5 Harness

- `tools/test-all.ps1`
- `tools/test-unit.ps1`
- `tools/test-data.ps1`
- `tools/test-runtime.ps1`
- `tools/test-save.ps1`
- `tools/test-perf.ps1`
- all use `tools/common.ps1`
- isolated temp dirs, probe mod, log markers, non-zero exit on failure
- `-Keep` preserves save/log
- CI-ready

---

## 17. Implementation phases

| Phase | Scope | Acceptance |
|---|---|---|
| 0 | Rename; remove gate; remove biters/bots/military; test harness skeleton | loads; no enemies/bots; tests run |
| 1 | Cable/switch/router graph, monitor, overlay, subnet stats | graph tests pass |
| 2 | Server racks, datacenters, chips, memory banks, labs as clients, research compute/memory/bandwidth | internet unlock; decay tests pass |
| 3 | Process-node ladder, lithography, transistor, packaging, science packs | 10 µm → 1.4 nm chain researchable |
| 4 | Half-node qualification, Metrology Lab, pilot recipes | qualification tests pass |
| 5 | Pre-quantum QLN + Construction Core | storage/transport; no bots |
| 6 | Quantum QLN, wireless, FOUP, advanced networking | global links; FOUP chain |
| 7 | Answer Engine rework, infinite research, victory | 42-minute endgame |
| 8 | Balance, GUI polish, icons/sound, locale, performance, docs, release | full suite green |

Rough effort: 5–7 weeks focused work. Phases 1–2 are highest risk; spike entity shells and lab throttling first.

---

## 18. Technical risks and spikes

1. **Lab throttling.** Confirm `LuaEntity.active` can stop a lab without breaking research, or find a safe alternative.
2. **Cable entity.** Confirm 1×1 no-collision entity placement, blueprinting, mining, sprite variants, and graph rebuild at 10k cables.
3. **Compute provider shell.** Confirm a beacon/lab/EEI clone can accept module items, draw continuous power, and expose module inventory.
4. **GUI performance.** Confirm a network monitor with tabs and 100+ devices updates at 30–60 tick intervals without UPS spikes.

Fallbacks:

- cable → tile-based graph
- provider → assembling machine with hidden recipe
- throttling → scripted progress scaling/refund
- GUI → paginated/summary view

---

## 19. Open questions

1. Exact sample counts and compute/memory requirements for half-node qualification.
2. Whether half-node upgrades are global (current plan) or also require per-fab process modules.
3. Whether QLN pattern crafting ships in 1.0 or later.
4. Whether pollution becomes a cleanroom contamination mechanic later.
5. True multiplayer/desync test scope.
6. Final art direction and custom entity art for 1.0 vs 1.1.
7. Whether the Foundation chapter keeps vanilla technology names (safer for existing recipe unlocks) or clones them under new chiptorio names.
8. Exact balance numbers after playtesting.

---

## 20. Next step

When Plan mode is exited:

1. Copy this file to `DESIGN.md` in the repository, adjusted for repository style.
2. Start Phase 0: rename, prune, remove the old gate, add the test harness skeleton.
3. Build the network graph spike before content.
4. Keep this file as the design reference until `DESIGN.md` is authoritative.
