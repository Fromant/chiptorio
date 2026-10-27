# chiptorio — Design Specification

Status: authoritative design; Phases 0-3 complete, Phase 4 next  
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

- node mask set / process kit
- node wafer item
- node die item
- packaging recipes for the architecture chips that node supports
- node recipes and a technology
- node science-pack costs
- higher die yield and a bigger wafer (the node's chip family)

### 4.4.1 Implementation: nodes feed architecture chips

Phase 3 implements the ladder as **manufacturing generations feeding the six
architecture modules** (integrated circuit, microprocessor, system-on-chip, GPU,
multi-core CPU, quantum processor). A node does not invent a seventh chip name
and the compute profiles in `scripts/research_meta.lua` never change; what
changes is the cost and availability of the existing chips:

- `node-<key>-mask` is the process kit. It consumes `litho-mask` for 10 µm to
  1 µm and `phase-shift-mask` from 350 nm onward.
- `node-<key>-wafer` exposes and metallises plain `silicon-wafer`.
- `node-<key>-die` dices the wafer. Die yield rises from 40 to 400 per ten
  wafers across the ladder.
- `<chip>-from-<key>` packages a node die into an architecture module. The
  technology unlocks every recipe it needs, which is asserted at the data
  stage.

The first three nodes run in the Wafer Fab. From 350 nm the wafer and die
recipes move to the VLSI Fab and consume coolant. Optical Discs are unlocked by
350 nm, HBM Stacks by 90 nm, and the Qubit Array by Quantum Computing.

Internal keys must be prototype-safe, so the last node's key is `1-4nm` while
its display label is "1.4 nm".

The node table lives in the pure module `scripts/process_nodes.lua`. It is the
single source of truth for item names, technology names, die counts, half-node
links and the half-node bonus. `scripts/node_items.lua` and
`scripts/node_recipes.lua` generate prototypes from it, and
`scripts/technology.lua` generates the twelve `process-*` technologies. The
table deliberately carries no `data` or `game` access so the probe can unit
test it across mods.

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

Allocation (implemented in `scripts/runtime/research_alloc.lua`):

```
profile_compute = min over required profiles of (available[profile] / share[profile])
effective       = min(profile_compute, total_bandwidth)
lab_demand      = max(lab.base_demand, tech.per_lab)
active_labs     = greedy by unit_number while used + lab_demand <= effective
```

- Profiles are relative shares. A technology with `{ scalar = 0.5, vector = 0.5 }` and a
  floor of 128 needs 64 scalar **and** 64 vector; surplus of one kind cannot cover a
  shortfall of the other.
- Every network is evaluated independently. The technology runs if at least one network
  satisfies the compute floor, the memory requirement and the bandwidth requirement.
- A network that qualifies enables labs greedily by `unit_number` (oldest first). A lab
  that does not fit is paused whole, never partially fed.
- Inactive labs are switched off with `disabled_by_script`, so they do not consume packs
  and are visibly idle.
- If no network qualifies, memory and bandwidth failures are hard stops (maximum decay);
  a pure compute shortfall decays in proportion to the gap.
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
- 25 bandwidth backplane, 150 kW draw.
- Base power draw and heat.
- Base network port.
- Compute is the sum of the installed chips.

### 6.3 Datacenter

- 8 chip slots.
- 4 memory slots.
- Built-in cooling.
- 100 bandwidth backplane, 1 MW draw.
- Much higher power draw.
- Mid/late-game concentration of compute.

### 6.4 Chips

Chips are custom module items with zero vanilla module effect. The script reads the module inventory.
They live in `data.raw.module` under the `chiptorio-chip` category, so a provider's module
inventory is the single machine-readable "what is installed" surface.

Implemented profiles:

| Chip | Scalar | Vector | Tensor | Quantum | Power | Heat |
|---|---:|---:|---:|---:|---:|---:|
| Integrated Circuit | 1 | 0 | 0 | 0 | 5 kW | 0.5 |
| Microprocessor | 2 | 0 | 0 | 0 | 10 kW | 1 |
| System on a Chip | 8 | 0 | 0 | 0 | 25 kW | 2 |
| Multi-Core CPU | 32 | 0 | 0 | 0 | 60 kW | 4 |
| GPU | 2 | 16 | 0 | 0 | 100 kW | 6 |
| Quantum Processor | 0 | 0 | 0 | 64 | 500 kW | 20 |

### 6.5 Memory Bank

- 4 memory module slots.
- 25 bandwidth backplane, 80 kW draw.
- Each module adds capacity and bandwidth.
- SRAM: 16 capacity, 8 bandwidth. DRAM: 128 capacity, 16 bandwidth.
- QLN item storage will reuse the same modules in a later phase.
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
-- scripts/research_meta.lua, the single source of truth
["vlsi-process"] = {
  floor = 8,             -- minimum profile compute for any network
  per_lab = 2,           -- minimum compute demand of one lab
  memory = 16,           -- dataset size
  bandwidth = 8,         -- bus bandwidth
  profiles = { scalar = 1 },          -- relative shares, not capacities
},
```

The data stage generates tooltips from this table. Runtime uses the same table. One source of truth.

### 7.3 Decay

- The research bar is `LuaForce.research_progress`, a fraction in `[0, 1]`.
- Maximum decay is 2% of the bar per minute (`research_meta.MAX_DECAY_PER_MINUTE`).
- Supported with at least one active lab: no decay.
- No network at all, memory shortfall, bandwidth shortfall, zero effective compute, or
  capacity but no connected lab: maximum decay.
- Pure compute shortfall: `2%/min * (1 - profile_compute / floor)`, so the player can see
  the gap closing as they add chips.
- Decay is applied by the 60-tick dispatcher; `remote.call("chiptorio-research", "step", n)`
  exists for tests.
- No `chiptorio-strict-network` setting: the network gate is always on.

### 7.4 Internet unlock

- The Internet technology requires only `microarchitecture` (the first microprocessor).
- It requires no compute: it is the technology that creates compute.
- It unlocks the Assembly Fab, the Server Rack, the Memory Bank, SRAM, and the wiring.
- `vlsi-process` is the first compute-gated technology and requires `internet`.
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

Phase 3 folds the method into the node: `process_nodes.NODES` records the
lithography method and the mask family (`litho-mask` or `phase-shift-mask`)
for each node, and the node technology unlocks the matching process kit.
Standalone lithography technologies are Phase 4 content if the qualification
loop needs to unlock methods separately.

### 10.2 Transistor architectures

PMOS → NMOS → CMOS → HMOS → FinFET → GAA nanosheet → CFET.

Each is a technology that unlocks the next node family and improves density/efficiency.

Phase 3 records the transistor architecture on its node and expresses it through
the node's die recipe and yield. A separate transistor technology per
architecture is deferred with the half-node qualification work.

### 10.3 Packaging and assembly

Wire bond → DIP → QFP → BGA → flip-chip → TSV → 2.5D → 3D stacking → chiplet → hybrid bonding.

Packaging affects:

- chip compute (power delivery, interconnect)
- memory bandwidth (HBM needs 2.5D)
- heat
- QLN/FOUP requirements

Phase 3 models packaging as the node's packaging field plus the chip-packaging
recipes it unlocks: wire-bond ICs at 10 µm, microprocessors at 3 µm, systems on
a chip at 350 nm, GPUs at 90 nm (HBM stack required), multi-core CPUs at 22 nm
(chiplet required), and quantum processors at 7 nm and below (qubits required).

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
control.lua
graphics/                 -- generated icons, technology icons, ending art
locale/en/locale.cfg
scripts/
  util.lua                -- prototype cloning, icons, recipes
  items.lua               -- items, module categories, chip and memory modules
  fluids.lua
  machines.lua            -- wafer fab, crystal puller, VLSI fab, assembly fab
  labs.lua                -- analytical engine .. cryostat
  providers.lua           -- server rack, memory bank, datacenter (lab clones)
  memory.lua              -- SRAM/DRAM recipes
  network.lua             -- cable, switch, router, monitor
  process_nodes.lua       -- PURE: 12-node ladder, half-node table, naming
  node_items.lua          -- tinted node mask/wafer/die items
  node_recipes.lua        -- node mask/wafer/die and chip-packaging recipes
  chips.lua, silicon.lua, era5.lua, era7.lua, workloads.lua, endgame.lua
  research_meta.lua       -- PURE: labs, chips, memory, providers, tech gates
  answer_meta.lua, rates.lua
  technology.lua          -- the chiptorio tech tree
  prune.lua               -- enemies, robots, combat removal
  enemy_cleanup.lua
  answer_engine.lua
  runtime/
    network_graph.lua     -- PURE: topology builder
    research_alloc.lua    -- PURE: allocation and decay
    network_runtime.lua   -- chunk cache, capacities, overlay, monitor
    research_runtime.lua  -- lab pausing, decay, debug interface
tools/
  common.ps1, test-all.ps1, test-mod.ps1, test-contract.ps1
  make-icons.ps1, make-sound.ps1
  test-probe/             -- separate test mod: unit, data and runtime probes
```

Rules:

- `data.lua` order: items/fluids → machines/labs/providers/memory → network/memory/chips → node recipes → technologies.
- `data-updates.lua` only touches vanilla after all mods load.
- `control.lua` owns one `on_nth_tick(60)` dispatcher.
- Runtime state lives in `storage`, versioned and initialized in `on_init` and `on_configuration_changed`.
- Pure modules (`research_meta`, `network_graph`, `research_alloc`, `process_nodes`) never touch `data`, `game` or `storage`.
- Prototypes are cloned from base entities; icons are generated. Node items share the wafer/die/mask art with a per-node tint.
- `scripts/technology.lua` generates the twelve `process-*` technologies from `process_nodes.NODES`; the technology table only supplies tech-tree position and cost.
- Test code lives in `tools/test-probe/`, never in the mod.

### 15.1 Factorio 2.1 API traps

These have all caused load-stage or runtime errors in this project:

- Recipe `category` is a string; `categories` is the list form. A recipe with fluid ingredients must not use the `crafting` category.
- Technology ingredients are the positional `{"item-name", amount}` form, not the typed recipe-ingredient table.
- Prototypes take `icon` or `icons`, not both, and `icon_size` must match the file.
- Prototype names may only contain `A-Z a-z 0-9 _-`. A dotted process key such as `1.4nm` fails at load ("Invalid prototype name"); use `1-4nm` internally and keep "1.4 nm" in the locale label.
- In 2.1 science packs are `item` prototypes, not `tool` prototypes (`data.raw.tool` only holds durability tools). Any item lookup that serves recipes, labs or technologies must not assume `data.raw.item` and `data.raw.tool` are the only homes; `M.item_exists` also checks `data.raw.module`.
- Locale placeholders are `__1__`, `__2__`, not `%s`.
- `defines.events.on_player_fast_replace` does not exist in 2.1. Referencing it yields `First argument must be a table or LuaEventType`.
- Custom-input events cannot be raised through `script.raise_event`. Test an input path through an exported function, e.g. `remote.call("chiptorio-network", "overlay", true)`.
- `rendering.destroy(id)` does not exist. Use `rendering.get_object_by_id(id).destroy()`, or `rendering.clear(mod_name)`.
- An entity at position `4.5` occupies tile `4`: use `math.floor`, not rounding.
- `storage` is shared by every mod in the save. Namespace it and never assume another mod's keys are absent.
- Factorio stores one handler per event. Register every handler in `control.lua`; a registration inside a module silently replaces another module's handler.
- A `nil` entry inside an `ipairs` registration list truncates the loop without error. Register each event explicitly.
- `ModulePrototype` lives in `data.raw.module`, not `data.raw.item`, so item checks must consult both (see `M.item_exists`). It requires `category`, `tier` and `effect`; `effect = {}` is valid and is how zero-effect chips are built.
- `LabPrototype.allowed_effects` is an `EffectTypeLimitation`, not a map of booleans. Assigning `{ speed = true }` fails with "Value must be a string"; omit it and inherit the base lab's limits instead.
- A lab clone with `inputs = {}` is a valid compute provider: it keeps module slots and `get_module_inventory()` without being usable for research. Setting `researching_speed = 0.001` keeps the animation honest.
- Provider module contents change without an inventory event (inserters, manual transfer). The runtime compares a signature derived from `get_module_inventory().get_contents()` once per second instead of listening to inventory events.
- `LuaForce.research_progress` is readable and writable; `current_research` is read-only and `force.add_research` queues a technology.
- At runtime `LuaTechnology.prerequisites` is a dictionary keyed by technology name, not an array. Use `pairs`, and `research_recursive()` to force-unlock a chain in tests; the data-stage prototype uses an array of names.
- `game.get_entity_by_unit_number` only works with the `get-by-unit-number` flag. Store entity references in graph device descriptors instead.

---

## 16. Testing

### 16.1 Unit tests

Implemented in `tools/test-probe/`, run from the probe's data stage against the pure
modules through a cross-mod `require("__chiptorio__/scripts/...")`:

- `graph_spec.lua`: connectivity, tile flooring, duplicate tiles, switch merging, router
  bridging, device reach, contested/unconnected devices, bandwidth and latency.
- `research_spec.lua`: profile shares, compute floor, memory and bandwidth hard stops,
  proportional decay, greedy lab enablement, bandwidth cap, `decay_amount`, lab demand.
- `node_spec.lua`: twelve major nodes in roadmap order, unique and prototype-safe
  naming, monotonic die yield, first-three/VLSI split, ten half-nodes between adjacent
  majors, monotonic and accumulating half-node bonuses, unknown-node lookups.

All three specs run before a single `PASS unit` marker; calling `H.finish` inside one
spec would hide the failures of the specs that run after it.

Still to add: memory generations for QLN, infinite multipliers, qualification tables,
property tests.

### 16.2 Data-contract tests

Implemented: icons and locale exist, chip and memory modules are modules with an empty
effect and the right category, providers are labs with no inputs and both module
categories, provider recipes start locked, `assembly-fab` exists, `internet` unlocks the
network and the first providers, `datacenter` unlocks the lab/provider/DRAM, `vlsi-process`
requires the internet, lab inputs include every workload, no military/bot/enemy remnants,
no throughput-gate references. The process-node contract checks every node's three items,
three locked recipes and technology, and that the technology unlocks each mask/wafer/die
plus one packaging recipe per supported architecture. It also asserts the nine-pack lab
inputs, that each custom pack is unlocked by its introducing technology, and that the
unprefixed `quantum-science-pack` no longer exists.

Still to add: qualification tables, QLN.

### 16.3 Runtime integration tests

Implemented on a fresh map: enemy/bot/removal checks, cable+router topology via the remote
interface, provider capacity from module inventories (2 providers, 1 lab, 8 scalar, 64
memory), supported research with no decay, a memory-gated technology paused and decaying at
the maximum rate, a mixed scalar/vector technology refused on a scalar-only network, a pure
compute shortfall decaying at the maximum rate and recovering when chips are reinstalled.

Still to add: power/cooling throttle, save/load, force isolation, QLN, half-node
qualification, Answer Engine victory/score, infinite scaling.

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

Rough effort: 5–7 weeks focused work. Phases 0–3 are complete. Phase 4 is next; the
highest remaining risk is the half-node qualification loop, not the network runtime.

---

## 18. Technical risks and spikes

1. **Lab throttling. Resolved.** `LuaEntity.disabled_by_script` pauses a lab safely: the
   force stops accumulating progress from it, the entity shows idle, and re-enabling
   resumes. The runtime sets it every second from the allocator result. No progress
   refund hack is needed.
2. **Cable entity. Resolved.** A 1×1 `container` clone with `collision_layer` and
   `collision_mask` both set to `chiptorio-cable` places, blueprints and mines cleanly, and
   the chunk-indexed rebuild handles the current test map.
3. **Compute provider shell. Resolved.** A lab clone with `inputs = {}`, a near-zero
   research speed and module slots exposes `get_module_inventory()` and accepts custom
   module categories. Chips are zero-effect modules, so vanilla module maths is inert.
4. **GUI performance.** Open. A network monitor with tabs and 100+ devices updating at
   30–60 ticks is still untested at scale, as are 10k cables and 1,000 providers.

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
