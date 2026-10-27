# chiptorio — Design Specification

Status: authoritative design; 1.0.0 implemented. The board ladder, Circuit Assembler,
computer modules, power/cooling throttle, infinite research, AI training/inference, and
the full gameplay spec in §20 are implemented. `TODO.md` is the gap register; `IMPLEMENTATION_TODO.md`
tracks the build order. `README.md` Status and `changelog.txt` are current.
Date: 2026-10-27  
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
19. **Circuits are integrated, not deleted.** The three vanilla circuit items keep their internal names and become boards: `electronic-circuit` → Control Board, `advanced-circuit` → Advanced Control Board, `processing-unit` → Compute Board. Boards are crafted in a Circuit Assembler from chips, memory, and passives. Only the Integrated Circuit chip is still called a "circuit".
20. **Computers are modules.** Racks and datacenters hold computer modules (`category = chiptorio-computer`), not raw chips. Each computer bundles board + chip + memory (+ storage where applicable). Compute is produced and consumed in the same building.
21. **Memory is unified.** One memory family (SRAM → DRAM → SDRAM → DDR → DDR2 → DDR3 → DDR4 → DDR5 → HBM → HBM3 → 3D NAND). Memory modules go into computers, memory banks, and QLN Storage Drives alike — capacity comes from installed modules everywhere. There is no RAM vs SSD split and no separate SSD item line.
22. **Pre/post-internet lab split.** Pre-internet labs are self-contained: a computer module installed in the lab provides that lab's compute. Post-internet labs are network clients: they draw compute from the network behind them (racks and datacenters full of computers). The Internet tech requires no compute.
23. **AI: GPU trains, NPU infers, tiered side by side.** From the GPU era (90 nm) onward, both GPU and NPU tiers exist. GPUs train models; NPUs run inference. Five AI tiers (Narrow → Specialist → General → Frontier → AGI) matched to compute eras. A scripted Training Cluster reserves compute and draws data from QLN to produce Models; an Inference Lab consumes Models for insight. Models are research ingredients.
24. **The Question fails at stability 0.** Pre-flight gate check at ~90% of every target; stability drains while any gate is unmet; stability 0 resets the run and loses part of the corpus.
25. **No crusher for 1.0.0.** `stone → silica` is crafted directly. A crusher may be added later from open-source reference mechanics, with no mod dependency.
26. **No backward-compatible save migration.** 0.10.0 saves break; clean break for 1.0.0.
27. **Vanilla modules disabled for now.** Computers, racks, and datacenters accept only `chiptorio-computer` modules; vanilla module categories are not accepted. Reconsider after 1.0.
28. **Vanilla `electronics` technology is replaced.** The `electronics` tech and its `electronic-circuit` recipe are superseded by the Thermionics chain: vacuum tubes → Control Board → board ladder.

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

There is deliberately no per-fab process module: the upgrade is force-wide, so a fab
does not need to be rebuilt or refitted to benefit.

The technology remains "researched", but its effects are gated until qualification is complete. The network monitor shows this clearly:

> 65 nm Process — researched  
> Qualification: 37/100 wafers analyzed  
> Needs 32 compute (scalar 0.5, vector 0.5), 64 memory and 32 bandwidth.

If the lab is unpowered or the network is short, the bar simply stops and the monitor
names the reason: `no-labs`, `no-network`, `no-power`, `compute`, `memory` or
`bandwidth`. Nothing decays and nothing is destroyed; the pilot line can be fixed and
the batch resumes.

#### 4.5.2 Qualification data

The half-node table lives in `scripts/process_nodes.lua` (pure) and the network gates in
`scripts/research_meta.lua` (pure). The technology table only supplies position and
cost:

```lua
-- process_nodes.HALF_NODES entry
{
  key = "65nm",                       -- prototype-safe
  label = "65 nm",                    -- locale only
  between = { "90nm", "45nm" },       -- the major node it refines
  samples = 100,
  analysis_time = 2.0,                -- seconds per sample
  requires_network = true,
  tint = { r = 0.35, g = 0.75, b = 0.95 },
  bonus = { yield = 1.20, compute = 1.10, power = 0.85 },
}

-- research_meta.QUALIFICATION_GATES["65nm"]
{
  floor = 32,
  memory = 64,
  bandwidth = 32,
  profiles = { scalar = 0.5, vector = 0.5 },
}
```

Generated names are `refine-<key>` for the technology and
`refine-<key>-qualification-wafer` for both the PQW item and its pilot recipe.
The pilot recipe runs in the refined node's fab category (`chiptorio-fab` for the first
three nodes, `chiptorio-vlsi` after that) and consumes 2 previous-node wafers, 1 of that
node's base mask, 20 photoresist and 1 metrology test structure per PQW.

The bonus is applied by three different mechanisms, because they are three different
game systems:

- `bonus.yield` becomes `LuaRecipe.productivity_bonus` on the refined node's wafer and
  die recipes. Those recipes set `allow_productivity = true`; the bonus is set, not
  added, so re-qualifying cannot multiply the same recipe twice.
- `bonus.compute` becomes a per-force multiplier read by
  `network_runtime.provider_descriptor` for every provider, so a rebuilt graph sees it.
- `bonus.power` scales provider `power` and `heat`, not `cooling`. Memory capacity and
  backplane bandwidth are hardware and are never scaled.

Early half-nodes before the internet (6 µm, 1.5 µm) have no gate at all, so the
Metrology Lab works offline. From 800 nm onward the lab needs a network that meets its
gate. Profile shares stay scalar-only up to 130 nm: a vector requirement before the GPU
exists would deadlock the ladder.

#### 4.5.3 Anti-grind rules

- Sample batch is modest: 50–150 depending on node.
- Analysis time is 1.5–3 seconds per sample, and the total batch is a few minutes of
  lab time, not an evening.
- One lab is enough; extra labs on the same network speed the batch up rather than
  being required.
- No random failures. A powered, supported lab always makes progress.
- Qualification is per-force and persists across save/load.
- The pilot recipe is cheap enough to run from existing node production.
- The upgrade is global once qualified, so fabs do not need individual modules.
- Progress is only granted for whole samples, and only if the matching PQW is actually
  in a lab inventory. Time alone cannot qualify a process.

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

- **Segment:** connected component of cable tiles (4-way adjacency). Segment bandwidth is the weakest cable tier present (weakest-link rule).
- **Network:** segments joined by switches and routers.
- Devices connect only if physically adjacent to a cable/switch tile or within a router's 16-tile wireless reach. Cables collide with everything — they cannot be placed on machines or belts, and nothing can be placed on them.
- Cable graph rebuilds only when entities/tiles change, not every tick.
- Rebuild is coalesced: mark dirty, rebuild on the next 60-tick job.
- Blueprints trigger the same rebuild path.
- Repeater entity removed; switches are 3×2 junction boxes and routers are 3×2 gateways with WiFi.

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

- Storage cells run from 1k for SRAM to 256k for 3D NAND; the 1k / 4k / 16k /
  64k / 256k sizes are the even rungs of the ladder.
- DDR3 cells are cheap and slow.
- HBM cells are fast and expensive.
- 3D NAND cells are dense and slow.

### 8.3 Generations

| Generation | Era | Capacity | Bandwidth | QLN cells | Notes |
|---|---|---:|---:|---:|---|
| SRAM | Internet | 16 | 8 | 1k | cache, first network |
| DRAM | 3 µm | 128 | 16 | 4k | first main memory |
| SDRAM | 1 µm | 256 | 24 | 8k | synchronous |
| DDR | 350 nm | 384 | 32 | 12k | double data rate |
| DDR2 | 180 nm | 512 | 40 | 16k | |
| DDR3 | 90 nm | 768 | 48 | 24k | QLN storage workhorse |
| DDR4 | 45 nm | 1024 | 56 | 32k | |
| DDR5 | 22 nm | 1536 | 64 | 48k | |
| HBM | 14 nm | 2048 | 96 | 64k | 2.5D packaging |
| HBM3 | 7 nm | 3072 | 128 | 96k | 3D packaging |
| 3D NAND | 7 nm | 4096 | 16 | 256k | QLN bulk storage |

Each generation's recipe is unlocked by the process-node technology of its era,
so the memory ladder advances with the process ladder. SRAM is the exception:
it arrives with the Internet, which is also the first compute tier (DESIGN
§7.4).

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
- **FOUP Dock** — a ten-slot container that seals 25 wafers of one process node into a single carrier item, or unseals one. The mode switch is a relative panel beside the container window, so the slots stay usable. Import and Export Nodes respect the mode: a sealing dock accepts FOUPs and wafers and exports sealed carriers, an unsealing dock does the reverse.
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

**Implementation status (0.10.0).** The FOUP chain works end to end: a dock seals
a batch, and QLN Import/Export Nodes move empty carriers, wafers and sealed
carriers in the correct direction for the dock's mode, so a batch can travel
through storage and unseal at another fab. The contamination gate on 45 nm and
below die recipes is **not** active yet; until playtesting decides whether to
require it, a carrier is an optional transport-compression tool rather than a
mandatory step.

### 9.4 Construction Core

- 2×2 powered entity (an accumulator clone, so its battery is real and refills while idle), range 32.
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
Phase 4 kept that decision: the qualification loop unlocks a pilot line, not a
standalone lithography method, so there is still one process kit per major node.

### 10.2 Transistor architectures

PMOS → NMOS → CMOS → HMOS → FinFET → GAA nanosheet → CFET.

Each is a technology that unlocks the next node family and improves density/efficiency.

Phase 3 records the transistor architecture on its node and expresses it through
the node's die recipe and yield. Phase 4 did not add a separate transistor
technology per architecture: the half-node refinements carry the process
improvements, and a second tech layer would have duplicated them.

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
- **Network monitor:** overview, topology, devices, alerts, routing tabs.
- **Entity tooltips:** ports, power, heat, compute profile, memory capacity.
- **Item tooltips:** chip profile, memory generation, QLN capacity.
- **Alerts:** compute starved, memory full, no route, router bottleneck, cooling insufficient, power low, qualification stalled, unconnected devices, multi-network conflicts.
- **Overlay:** cable tier visualization (weakest-link), switches as blue squares, routers as orange circles with WiFi reach circles.
- **Locale:** all new items/entities/techs; `__1__` placeholders.
- **Icons:** generated 64×64 items, 256×256 tech icons, cable sprites, network icons.
- **Sound:** keep the generated fanfare; add terminal/network sounds later.
- **Remote interface:** `chiptorio-network`, `chiptorio-research`, `chiptorio-qualification`, `chiptorio-qln`, `chiptorio-answer`, `chiptorio-ai`.

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
  metrology.lua           -- Metrology Lab, test structure, pilot recipes
  memory.lua              -- the eleven memory-generation recipes
  network.lua             -- cable tiers, switch, router, monitor, wireless AP
  qln.lua                 -- QLN nodes, drives, FOUP, construction core, quantum labs
  qln_meta.lua            -- PURE: QLN rates, capacity per module, tech names
  process_nodes.lua       -- PURE: 12-node ladder, half-node table, naming
  node_items.lua          -- tinted node mask/wafer/die items and PQWs
  node_recipes.lua        -- node mask/wafer/die and chip-packaging recipes
  chips.lua, silicon.lua, era5.lua, era7.lua, workloads.lua, endgame.lua
  circuits_meta.lua, circuits.lua         -- board ladder, Circuit Assembler, vanilla re-theme
  computers_meta.lua, computers.lua       -- computer modules, Computer Assembler
  ai_meta.lua, ai.lua                     -- AI models, Training Cluster, Inference Lab
  research_meta.lua       -- PURE: labs, chips, memory, providers, tech/qual gates
  answer_meta.lua         -- PURE: Answer requirements and per-level scaling
  technology.lua          -- the chiptorio tech tree, including refine-* techs
  prune.lua               -- enemies, robots, combat removal
  enemy_cleanup.lua
  answer_engine.lua       -- The Answer runtime, GUI, scoring and victory
  runtime/
    network_graph.lua     -- PURE: topology builder
    research_alloc.lua    -- PURE: allocation and decay
    qualification_alloc.lua -- PURE: gate checks and qualification progress
    qln_transport.lua     -- PURE: storage groups, capacity, insert/remove
    network_runtime.lua   -- chunk cache, capacities, overlay, monitor
    research_runtime.lua  -- lab pausing, decay, debug interface
    qualification_runtime.lua -- Metrology Lab analysis, per-force bonuses
    qln_runtime.lua       -- QLN drives, transfer nodes, FOUP, construction
    ai_runtime.lua        -- Training Cluster, Inference Lab, AI tick logic
tools/
  common.ps1, test-all.ps1, test-mod.ps1, test-contract.ps1
  run-mod.ps1, make-icons.ps1, make-sound.ps1
  test-probe/             -- separate test mod: unit, data and runtime probes
```

Rules:

- `data.lua` order: items/fluids → machines/labs/providers/memory → network/memory/chips → node recipes → technologies.
- `data-updates.lua` only touches vanilla after all mods load.
- `control.lua` owns one `on_nth_tick(60)` dispatcher.
- Runtime state lives in `storage`, versioned and initialized in `on_init` and `on_configuration_changed`.
- Pure modules (`research_meta`, `answer_meta`, `qln_meta`, `network_graph`, `research_alloc`, `qualification_alloc`, `qln_transport`, `process_nodes`) never touch `data`, `game` or `storage`.
- Prototypes are cloned from base entities; icons are generated. Node items share the wafer/die/mask art with a per-node tint.
- `scripts/technology.lua` generates the twelve `process-*` technologies from `process_nodes.NODES` and the ten `refine-*` technologies from `process_nodes.HALF_NODES`; the technology table only supplies tech-tree position and cost.
- `network_runtime` never requires `qualification_runtime` or `qln_runtime`. Both register a monitor section (and the multiplier setter) through calls, which keeps the dependency one-way.
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
- A lab clone whose `inputs` are the ten PQWs is a valid Metrology Lab: those items sit in `defines.inventory.lab_input`, which is the only item inventory a lab exposes to script. Set `module_slots = 0` so it cannot also be used as a provider.
- `LuaRecipe.productivity_bonus` is a per-force `Read|Write` `EffectValue` (0.10 = 10%), reached through `force.recipes[name].productivity_bonus`. The recipe must have `allow_productivity = true`, and the value is absolute: setting it again does not stack.
- `LuaInventory.remove{}` returns the number actually removed, which is what the qualification runtime uses to decide whether a sample was really paid for.
- Qualification completion changes chip compute, so it must call `network.mark_dirty()`; otherwise the cached graph keeps serving the pre-bonus provider capacities for up to a second.
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
  bridging, device reach, contested/unconnected devices, bandwidth and latency, repeater
  reach, wireless access point union, and a 10,000-cable scale case.
- `research_spec.lua`: profile shares, compute floor, memory and bandwidth hard stops,
  proportional decay, greedy lab enablement, bandwidth cap, `decay_amount`, lab demand.
- `node_spec.lua`: twelve major nodes in roadmap order, unique and prototype-safe
  naming, monotonic die yield, first-three/VLSI split, ten half-nodes between adjacent
  majors, prototype-safe refinement and PQW names, the offline/network split,
  multiplying the qualified set exactly once, unknown-node lookups.
- `qualification_spec.lua`: gates exist for exactly the network half-nodes, missing
  network/compute/memory/bandwidth are separate hard stops, profile shares are honoured,
  only powered and supported labs gain samples, clamping, wafer consumption and bar
  fractions.
- `qln_spec.lua`: memory-module cell counts, drive capacity, group insert/remove,
  atomic withdraw, capacity clamping and deterministic item ordering.

All five specs run before a single `PASS unit` marker; calling `H.finish` inside one
spec would hide the failures of the specs that run after it.

Still to add: infinite multipliers, property tests, save/load.

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
unprefixed `quantum-science-pack` no longer exists. The qualification contract checks
the Metrology Lab (visible, lab clone, near-zero research speed, all ten PQWs as inputs),
the test structure, one locked pilot recipe per half-node that produces its PQW, one
`refine-*` technology per half-node with the right prerequisite and internet split, node
wafer/die recipes that allow productivity, and that `the-question` requires every
refinement.

The QLN contract checks every node is a visible, minable entity with a matching item and
a locked recipe, that the Storage Drive is a lab clone with four module slots and accepts
the memory categories, that the FOUP chain has an empty and a sealed carrier plus a dock,
that `qln` and `qln-quantum` unlock the expected nodes, that `quantum-advantage` unlocks
the neural processor, and that The Answer Engine recipe exists and is unlocked only by
`the-question`.

Still to add: optional QLN pattern crafting, multiplayer desync contracts.

### 16.3 Runtime integration tests

Implemented on a fresh map: enemy/bot/removal checks, cable+router topology via the remote
interface, provider capacity from module inventories (2 providers, 1 lab, 8 scalar, 64
memory), supported research with no decay, a memory-gated technology paused and decaying at
the maximum rate, a mixed scalar/vector technology refused on a scalar-only network, a pure
compute shortfall decaying at the maximum rate and recovering when chips are reinstalled.
Half-node qualification runs end to end: a Metrology Lab on a cable run qualifies 6 µm
offline and consumes its PQWs, the wafer/die yield bonus appears on the refined node, the
compute multiplier reaches the topology while memory capacity stays unscaled, 800 nm is
refused with reason `compute` on the boosted 4.2-scalar network, accepted at 8.4 scalar
with microprocessors, and the second qualification stacks compute to 8.82.

QLN runs end to end on the same map: an Import Node pulls into a Storage Drive and an
Export Node pushes back out, the same path moves items from a furnace output into an
assembling machine input, a FOUP chain sends wafers and an empty carrier from storage
into a sealing dock and pulls the sealed carrier back, the Terminal deposit and withdraw
hooks see the same pool, Provider and Requester Nodes stock adjacent inventories, a
Quantum Entanglement Core unions two networks into one storage group, a standalone FOUP
Dock seals and unseals a wafer batch, and the Construction Core mines a deconstruction
target, builds a ghost from QLN storage and gets its build indexed by the network
immediately. A device two tiles across a chunk border is still indexed, and repeater and
wireless links join networks without a cable between them. The Answer Engine boots,
advances ten seconds, pauses when an item line is withdrawn, completes through the debug
hook, records the score and victory, and scales every compute demand at Question level 2.
The QLN monitor section is rendered, but the Terminal and FOUP Dock windows are skipped on
benchmark maps, which have no player; they run when the probe mod is enabled in a normal
save.

Still to add: power/cooling throttle, save/load, force isolation, multiplayer desync
testing.

### 16.4 Performance tests

- 10,000 cables
- 1,000 providers
- 200 labs
- 100 routers/subnets
- tick time and graph rebuild time

The pure graph build runs in the data stage at 10,100 cables, 1,300 devices and 101
subnets, and logs `CHIPTORIO-TEST PERF graph` so a regression is visible in the log.
Factorio 2.1 removes `os`, so the spec asserts structure rather than wall-clock time.
Tick time, provider polling and the open monitor at scale still need a dedicated
`tools/test-perf.ps1` harness.

### 16.5 Harness

- `tools/test-mod.ps1` — data stage, map creation, 600-tick benchmark
- `tools/test-contract.ps1` — unit, data-contract and runtime probe
- `tools/test-all.ps1` — both of the above
- `tools/run-mod.ps1` — playable launch from an isolated dev mod directory
- all use `tools/common.ps1`
- isolated temp dirs, probe mod, log markers, non-zero exit on failure
- `-Keep` preserves save/log
- CI-ready

Save/load, force isolation and a dedicated tick-time benchmark do not have a wrapper yet.

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
| 9 | Board ladder, Circuit Assembler, computer modules, AI training/inference | full suite green |

Rough effort: 5–7 weeks focused work. All phases 0–9 are implemented in 1.0.0:
the board ladder and Circuit Assembler, computer modules as chiptorio-computer
modules in racks and datacenters, power/cooling throttle with Chip Efficiency
and Cooling Efficiency multipliers, eight infinite research technologies, the
AI layer (Training Cluster, Inference Lab, five model tiers), data contracts,
unit probes, runtime probes, generated icons, locale, and the full test suite.
Save/load, force isolation, multiplayer desync testing, monitor diagnostics,
and the deferred FOUP contamination gate remain post-1.0 work tracked in
IMPLEMENTATION_TODO.md and TODO.md.

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
4. **GUI and tick performance.** Partly resolved. A 10,100-cable / 1,300-device graph
   builds in the data-stage unit suite, so the topology maths is exercised at scale. The
   open monitor with 100+ devices, provider polling across 1,000 entities, and real tick
   time are still unmeasured; the fallback is a paginated or summary monitor view.

Fallbacks:

- cable → tile-based graph
- provider → assembling machine with hidden recipe
- throttling → scripted progress scaling/refund
- GUI → paginated/summary view

---

## 19. Open questions

1. ~~Exact sample counts and compute/memory requirements for half-node qualification.~~
   Resolved in `process_nodes.HALF_NODES` and `research_meta.QUALIFICATION_GATES`.
2. ~~Whether half-node upgrades are global or also require per-fab process modules.~~
   Resolved: global, applied through force recipe productivity and chip multipliers.
3. ~~Whether QLN pattern crafting ships in 1.0 or later.~~
   Resolved: not in 1.0; stretch goal after core QLN.
4. ~~Whether pollution becomes a cleanroom contamination mechanic later.~~
   Resolved: optional later; not in 1.0.
5. True multiplayer/desync test scope.
6. Final art direction and custom entity art for 1.0 vs 1.1.
7. Whether the Foundation chapter keeps vanilla technology names (safer for existing recipe unlocks) or clones them under new chiptorio names.
8. Exact balance numbers after playtesting.
9. ~~Exact AI tier sample counts, model recipes, and insight values.~~
   Resolved in `scripts/ai_meta.lua` AI_TIERS table; values are starting points for playtesting.
10. Whether post-game adds an ASI (superintelligence) tier as a score multiplier beyond AGI.
11. Whether the Crusher is ever added; if so, whether its code is adapted from open-source references with no dependency.

---

## 20. Gameplay: full playthrough specification

This section describes the complete player journey from first stone to The Question,
act by act. It is the authoritative gameplay reference for 1.0.0. Every recipe,
gate, building, and progression rule is described here as text; implementation
details live in the architecture sections above.

### 20.1 The four economies

Chiptorio runs four interlocking economies. They share one resource pool — the
network's compute, memory, bandwidth, power, and cooling — and the player's job
is to balance them across the game.

| Economy | What it produces | What it consumes |
|---|---|---|
| Materials & fabs | wafers, dies, chips, boards, computers, science media | ore, stone, oil, power |
| Computation | compute/s, memory, bandwidth (installed in racks and datacenters) | chips, boards, memory modules, power, cooling |
| Logistics | item movement at scale, no bots | QLN storage, FOUP carriers, Construction Core |
| Intelligence | models, insight, AGI | compute, data (SSDs/mainframe modules/HBM), science media |

The core loop is a spiral:

```
research → better nodes → cheaper chips → better boards → better computers
   ↑                                                            │
   └────────── more compute / memory / bandwidth / models ←─────┘
```

### 20.2 Act 0 — The mechanical mind (0–20 minutes)

**The puzzle.** You have nothing and no lab. How do you start researching?

**Progression.**

1. Hand-mine stone, iron, copper, coal. Build steam power: boilers, steam
   engines, offshore pumps, drills, furnaces.
2. Craft **silica** from stone (`stone → silica`, crafting). This is the first
   semiconductor material and the reason stone matters beyond early furnaces.
3. Smelt **glass** from silica (`silica → glass`, furnace). Glass is the first
   vacuum-tube ingredient and is locked behind Thermionics.
4. Research **Electromechanics** (punched cards) to unlock basic control logic.
5. Craft the **Analytical Engine** from iron gears, copper plates, and iron
   plates. **No circuits.** This is the bootstrap computer: mechanical, slow
   (0.5 speed), no module slots, craftable from the start.
6. Crafting the engine retargets the first-science trigger to `analytical-engine`,
   unlocking **Punched Cards** (automation science).
7. Power the engine and research the first technologies.

**What gates you.** Materials only. No chip, no network, no lab is required
before the engine.

**What it feels like.** A Victorian computer in a Factorio base. The first
research bar is deliberately slow — you are about to industrialise computation.

### 20.3 Act 1 — The tube era (20 minutes–2 hours)

**The puzzle.** Build the first logic device and the first board line without a
chip industry.

**Progression.**

1. Research **Thermionics**. Its cost is automation science only (punched cards),
   so the punched-card line can pay for it — this breaks the cycle where logistic
   science (punched tape) would otherwise require circuits before circuits exist.
2. Thermionics unlocks: silica → glass, **vacuum tubes** (`glass + copper-cable +
   iron-plate → vacuum-tube`, crafting), the **Circuit Assembler**, and the
   **Control Board** (`electronic-circuit`).
3. Build the first board line: iron plates, copper cable, and vacuum tubes →
   Control Boards in the Circuit Assembler.
4. Build the **Tube Mainframe** from Control Boards and vacuum tubes. It is a
   self-contained computer: no network, no chips, just a faster lab (1.0 speed).
5. Build the science-media chain, each tier consuming the previous:
   - Punched Cards → Punched Tape (adds Control Boards where circuits were used)
   - Punched Tape → Magnetic Tape
   - Magnetic Tape → Disk Packs
6. Discrete transistors enter through the node ladder (see Act 2).

**What gates you.** Board supply and the science-media chain. The first board is
the first manufactured product your factory makes.

**What it feels like.** The transition from "craft a machine" to "design a
production line". Control Boards are suddenly in everything: labs, racks, science,
buildings.

### 20.4 Act 2 — Discrete semiconductors (2–6 hours)

**The puzzle.** Turn sand into a working transistor, then into the first
integrated circuit.

**Progression.**

1. Research **Semiconductor Physics** (needs chemical science, which needs the
   board chain) → Crystal Puller, metallurgical silicon, polysilicon.
   - `metallurgical-silicon = silica + coal` (crystal puller)
   - `polysilicon = metallurgical-silicon + sulfuric-acid + steam` (chemistry)
2. Research **Crystal Growth** → monocrystalline ingot → silicon wafer.
   - `monocrystalline-ingot = polysilicon` (crystal puller)
   - `silicon-wafer = monocrystalline-ingot + silica` (crafting)
3. Research **Photolithography** → Wafer Fab, photoresist, etchant, masks, bare
   die, discrete transistor.
   - `litho-mask = glass + steel-plate` (Wafer Fab)
   - `exposed-wafer = silicon-wafer + photoresist + litho-mask` (Wafer Fab)
   - `etched-wafer = exposed-wafer + etchant` (Wafer Fab)
   - `processed-wafer = etched-wafer + copper-plate + sulfuric-acid` (Wafer Fab)
   - `bare-die = processed-wafer` (Wafer Fab, yield 40 per 10 wafers)
4. Research **10 µm** → first process node: mask set, wafer, die, and **Integrated
   Circuits** (`bare-die + plastic-bar + sulfuric-acid → integrated-circuit`,
   Wafer Fab).
5. The Integrated Circuit unlocks the **Advanced Control Board**
   (`advanced-circuit`): Control Board + discrete transistors + Integrated
   Circuit + plastic (Circuit Assembler).
6. Research **3 µm** → **Microprocessors** (`bare-die + ... → microprocessor`,
   Wafer Fab) and the **Compute Board** (`processing-unit`):
   Advanced Control Board + Microprocessor + copper plate + sulfuric acid
   (Circuit Assembler).
7. Build the **Mainframe Cluster** from Advanced Control Boards and Integrated
   Circuits — the first chip-powered computer (1.75 speed).
8. Research **Microarchitecture**, then **Internet**.

**What gates you.** The first chip. You need a fab, mask line, wafer line, board
line, and computer line all at once. This is the first real industry moment.

**What it feels like.** The factory has a product. You are no longer making
science; you are making silicon.

### 20.5 Act 3 — The internet and the first network (6–9 hours)

**The puzzle.** Stop building one bigger computer and start building a network of
small ones.

**Progression.**

1. Research **Internet**. It is deliberately **not compute-gated** — it is the
   technology that creates compute. It requires only Microarchitecture.
2. Internet unlocks: Network Cable, Network Switch, Network Router, Network
   Monitor, **Server Rack**, **Memory Bank**, **SRAM module**, and the **Assembly
   Fab**.
3. The **pre/post-internet split** becomes explicit:
   - **Pre-internet:** the lab *is* the computer. Research = build a bigger
     mainframe (Analytical Engine → Tube Mainframe → Mainframe Cluster).
   - **Post-internet:** the lab is a *client*. Research = build a bigger network.
4. Build the first network: a Server Rack with chips, a Memory Bank with SRAM,
   and your Mainframe Cluster connected by cable within 2 tiles.
5. Read the **Network Monitor**: compute, memory, bandwidth, latency, subnet
   counts. `ALT + N` draws the topology in-world.
6. The first compute-gated tech is **VLSI Process**, which needs 8 scalar, 16
   memory, and 8 bandwidth. You learn the three gates (compute, memory,
   bandwidth) and that surplus of one cannot cover another.
7. Build the first **Microcomputer** module (Compute Board + Microprocessor +
   SRAM module) and insert it into the rack. Compute is produced and consumed in
   the same building.

**What gates you.** Topology and the three gates. A fast chip on an isolated
subnet does nothing.

**What it feels like.** The base becomes a computer. Cables are as important as
belts.

### 20.6 Act 4 — VLSI, boards, computers, and memory (9–16 hours)

**The puzzle.** Turn compute into a product line. Boards, computers, and memory
become the new intermediates.

**Progression.**

1. Research **VLSI Process** (first compute-gated tech, requires Internet +
   1 µm) → VLSI Fab, Cooling Tower, coolant, phase-shift masks, low-k dielectric.
2. Advance **1 µm → 350 nm** → Systems on a Chip, more dies per wafer, and the
   **Datacenter** + **Datacenter Lab**.
3. Build the **board ladder** (all crafted in the Circuit Assembler, each tier
   consuming the previous):

   | Board | Internal name | Ingredients | Gate |
   |---|---|---|---|
   | Control Board | `electronic-circuit` | iron plate + copper cable + vacuum tubes | Thermionics |
   | Advanced Control Board | `advanced-circuit` | Control Board + discrete transistors + Integrated Circuit + plastic | 10 µm |
   | Compute Board | `processing-unit` | Advanced Control Board + Microprocessor + copper plate + sulfuric acid | 3 µm / 350 nm |
   | Accelerator Board | `accelerator-board` | Compute Board + GPU + HBM stack + coolant | 90 nm |
   | Neural Board | `neural-board` | Accelerator Board + Neural Processor + superconductor | Heterogeneous Compute |
   | Quantum Board | `quantum-board` | Neural Board + Quantum Processor + cryogen | Quantum Error Correction |

   Only the Integrated Circuit chip is still called a "circuit". Everything else
   is a board — the passive carrier; the chip is the compute.

4. Build **computers** (module items, inserted into racks and datacenters,
   crafted in the **Computer Assembler** — a separate machine from the Circuit
   Assembler):

   | Computer | Board | Chip | Memory | Gate | Role |
   |---|---|---|---|---|---|
   | Microcomputer | Compute Board | Microprocessor | SRAM | Internet | first rack computer |
   | Server | Advanced Control Board or Compute Board | System on a Chip | DDR3/DDR4 | 350 nm | mid rack |
   | Supercomputer | Accelerator Board | GPU | HBM | 90 nm | vector compute |
   | Neural Computer | Neural Board | Neural Processor | HBM3 | Heterogeneous Compute | tensor compute |
   | Quantum Computer | Quantum Board | Quantum Processor | HBM3 / 3D NAND | Quantum Error Correction | quantum compute |

   Computers are modules (`category = chiptorio-computer`). Racks and
   datacenters hold them in module slots; a lab tier will not accept science
   until a matching computer is installed. Compute is produced and consumed in
   the same building.

5. Build **memory as a unified family**:

   SRAM → DRAM → SDRAM → DDR → DDR2 → DDR3 → DDR4 → DDR5 → HBM → HBM3 → 3D NAND.
   Each generation unlocks with its process-node technology. Memory modules go
   into computers, memory banks, and QLN Storage Drives alike — capacity comes
   from installed modules everywhere. There is no RAM vs SSD split and no
   separate SSD item line; 3D NAND is simply the densest generation.

   Storage Drive: holds memory modules; QLN cell capacity comes from installed
   modules (one cell per module slot per generation density).

6. **Half-node qualification** (6 µm, 1.5 µm, 800 nm, 250 nm, 130 nm, 65 nm).
   Each half-node is researched, then qualified by running a pilot line through
   the Metrology Lab: craft Process Qualification Wafers, deliver them to the
   lab, and earn a force-wide yield/compute/power bonus.

7. **90 nm** → GPUs, HBM, Accelerator Boards, Supercomputers. Vector compute
   becomes mandatory for physics/simulation/metrology technologies. From this
   era onward, **NPU tiers exist alongside GPU tiers**: GPUs train models, NPUs
   run inference, and both are needed as AI advances.

8. **Efficient recipes** (GregTech-style vertical substitution). Every board gets
   alternative recipes from later chips:

   | Board | Base recipe | Alt 1 | Alt 2 |
   |---|---|---|---|
   | Control Board | tubes | discrete transistors (10 µm) | 1 SoC → several boards (350 nm) |
   | Advanced Control Board | Integrated Circuit | Microprocessor | SoC |
   | Compute Board | Microprocessor | SoC | Multi-Core CPU |
   | Accelerator Board | GPU | NPU | — |
   | Neural Board | Neural Processor | QPU | — |
   | Quantum Board | QPU | — | — |

   Later chips make older boards cheaper, so the tube line retires instead of
   being rebuilt. Process Yield infinite research keeps making the whole line
   cheaper over time.

**What gates you.** Tier matching: each board wants a chip from its era, each
computer wants a board and memory from its era. Building the wrong tier is the
classic bottleneck.

**What it feels like.** You are running a product company. The factory has a
catalogue: boards, computers, memory, and the machines that build them.

### 20.7 Act 5 — Nanoscale, QLN, and logistics at scale (16–26 hours)

**The puzzle.** Move items at megabase scale without bots.

**Progression.**

1. Advance **45 nm → 22 nm → 14 nm** → FinFET, multi-core CPUs, DDR4/DDR5,
   HBM, chiplets, 2.5D packaging.
2. Build the **QLN** (pre-quantum Data Bus):
   - Import Node: pulls items from adjacent inventory into network storage.
   - Export Node: pushes items from network storage into adjacent inventory.
   - Storage Drive: holds memory modules; capacity comes from installed modules.
   - Terminal: player GUI — search, deposit, withdraw, see counts.
   - Requester Node / Provider Node: pull from or push to network storage.
   - Network links: same cables/subnets/routers; throughput in items/s.
3. Build **FOUP Docks**: a 10-slot container that seals 25 wafers of one process
   node into a sealed carrier (`foup-sealed-<node>`), or unseals one. Import and
   Export Nodes respect the dock's mode: a sealing dock accepts FOUPs and wafers
   and exports sealed carriers; an unsealing dock does the reverse.
4. Build the **Construction Core** (accumulator clone, range 32): builds and
   deconstructs ghosts from QLN storage, powered by the grid. No bots, no
   roboports, no personal roboport.
5. The base becomes a network base: trains bring ore and plates; QLN moves
   everything complex; the Construction Core builds.

**What gates you.** QLN capacity and item throughput. The network bandwidth
that runs research also limits item movement.

**What it feels like.** The factory is now a single organism. You stop belting
intermediates and start designing storage and channels.

### 20.8 Act 6 — Intelligence: training and inference (26–35 hours)

**The puzzle.** The network can compute. Can it learn?

**Design principle.** Some racks produce compute; some consume it to create
models; science consumes models plus compute to run inference. Compute is one
pool; research labs, training clusters, and inference labs all compete for it.

**The AI triangle.**

- **Compute producers** — racks and datacenters full of computers.
- **Training Cluster** (separate building, scripted): reserves vector/tensor
  compute from the network, consumes data from QLN (disk packs → SSDs → mainframe
  modules → HBM stacks as tiers advance), and produces a **Model** item over
  time. If compute or data falls short, training pauses; no progress is lost.
- **Inference Lab** (lab variant): installs or consumes a Model, draws compute
  and data, and grants insight — reduced dataset size for technologies, or a
  temporary tensor/vector compute bonus for a window.

**Five AI tiers**, matched to compute eras. From the GPU era (90 nm) onward,
GPU and NPU tiers exist side by side — GPUs train, NPUs infer:

| AI Tier | Era | Train on | Infer on | Model | Research cost |
|---|---|---|---|---|---|
| Narrow | 90 nm / GPU | GPU | CPU/GPU | Small Model | Small Model + scalar compute |
| Specialist | 22 nm / Multi-core + early NPU | GPU | NPU | Specialist Model | Specialist Model + vector compute |
| General | 14 nm / NPU | GPU + NPU | NPU | General Model | General Model + tensor compute |
| Frontier | 7 nm / QPU-adjacent | NPU | NPU | Frontier Model | Frontier Model + quantum compute |
| AGI | 3 nm / QPU | QPU | QPU | AGI Model | AGI Model + quantum science |

**Rules.**
- You cannot research an AI technology without first training its model — models
  are research ingredients (the same positional mechanism The Question already
  uses for microprocessors).
- You cannot run inference without a model installed.
- GPUs train; NPUs infer. Separate tiers of both are required from the GPU era
  onward — you must build both a training pipeline (GPU-based) and an inference
  pipeline (NPU-based) as AI advances.
- Training happens first on GPU-era hardware; inference moves to NPU-era
  hardware as NPUs become available.

**What gates you.** Tensor compute (NPUs) and data supply (memory modules).
The AI era is the first time the network must choose what to spend compute on:
research, training, or inference.

**What it feels like.** The factory starts making decisions. You are no longer
just building compute; you are allocating it.

### 20.9 Act 7 — Quantum, AGI, and The Question (35–50 hours)

**The puzzle.** Build a mind and keep it alive for 42 minutes.

**Progression.**

1. Advance **7 nm** → Quantum Processors, qubits, quantum science.
2. Research **Quantum Computing** → Cryostat, Quantum Fab, cryogen, superconductor.
3. Research **Quantum Error Correction** → error-corrected qubits, Quantum Board,
   Quantum Computer.
4. Build **Quantum QLN**: Quantum Entanglement Cores pair two networks globally,
   unioning their storage into one group. Wireless APs and repeaters complete
   the network.
5. Research **Artificial General Intelligence**. It costs an AGI Model plus
   quantum science. You must have a working training pipeline.
6. Build the **AGI Core** (visible name of the Answer Engine; internal name stays
   `answer-engine` for save compatibility). It is a 5×5 machine assembled from
   every era of the factory: Quantum Boards, QPUs, massive memory, cooling.
7. Install the AGI model. Ask **The Question**.

**The Question — failure rules.**
- **Pre-flight check:** the AGI refuses to boot below ~90% of every gate —
  compute (all four profiles), memory, bandwidth, power, cooling, and QLN item
  draw. No wasted runs on a hopeless network.
- **The run:** 42 minutes of real time. The AGI draws science media,
  microprocessors, and quantum processors continuously from QLN storage.
- **Starvation:** if any gate falls below target, stability drains. The panel
  shows exactly what is missing.
- **Failure:** at stability 0, the run fails. The clock resets and part of the
  corpus is lost. The AGI reports the shortfall.
- **Success:** victory screen, generated fanfare, `42` printed, and a score from
  compute headroom, stability, time, and model tier.

**What gates you.** Sustained throughput and stability under load. The question
is not "can you build the machine?" but "can your network sustain a mind?"

**What it feels like.** A megabase exam. After the first victory, The Question
becomes infinite: each level raises demand by 25% and awards 42 more points.

### 20.10 Power and cooling throttle (§5.4)

- Servers draw power continuously and produce heat.
- Datacenters have built-in cooling; Cooling Towers provide additional cooling
  capacity and consume power/water.
- If heat > cooling, compute throttles proportionally.
- If power satisfaction is below 100%, compute throttles proportionally.
- Memory and bandwidth shortfalls remain hard stops (maximum decay); a pure
  compute/power/cooling shortfall decays in proportion to the gap.
- Power and heat are summed by the network graph and consumed by the research
  allocator; the monitor displays demand vs supply for power and cooling.

### 20.11 Infinite research (§10.5)

After the main tree, these repeat forever:

| Research | Effect | Scaling | Cap |
|---|---|---|---|
| Chip Performance | +5% compute per level | scripted multiplier | none |
| Chip Efficiency | −2% power per level | scripted | 90% reduction |
| Process Yield | +1% productivity for wafer/die recipes | recipe effect | 300% |
| Memory Density | +5% memory capacity | scripted | none |
| Memory Bandwidth | +5% memory bandwidth | scripted | none |
| Network Bandwidth | +5% link throughput | scripted | none |
| Cooling Efficiency | +5% cooling capacity | scripted | none |
| Quantum Correction | +5% QPU compute | scripted | none |
| Lab Speed | vanilla laboratory speed | vanilla effect | none |
| Mining Productivity | vanilla mining productivity | vanilla effect | none |
| The Question | +25% Answer demand per level | scripted | none |

The Question is the only one already live (0.10.0). The other eight are added
with the power/cooling work.

### 20.12 What the player is doing minute-to-minute

| Act | The verb | The real puzzle |
|---|---|---|
| 0 | Mine, smelt, handcraft, watch the first bar | Patience and bootstrap |
| 1 | Build the tube line, the board line, the science-media chain | Vertical chains (each tier consumes the last) |
| 2 | Build the fab: masks, wafers, dies, chips | Process engineering (yields, nodes) |
| 3 | String cable, place racks and memory, read the monitor | Network topology and the three gates |
| 4 | Design the product line: boards, computers, memory, half-node qualification | Tier matching (board ↔ chip ↔ memory ↔ computer) |
| 5 | Design storage and channels: QLN, FOUP, Construction Core | Logistics at scale without bots |
| 6 | Allocate compute: research vs training vs inference | Compute allocation and model economics |
| 7 | Build the AGI, pass pre-flight, survive 42 minutes, retry | Sustained throughput and stability under load |

### 20.13 Vanilla gates and recipe changes

Every vanilla prototype that touches circuits is re-themed, not deleted. The
internal names `electronic-circuit`, `advanced-circuit`, and `processing-unit`
stay; their visible names become Control Board, Advanced Control Board, and
Compute Board.

| Vanilla recipe | Change | Gate |
|---|---|---|
| `analytical-engine` | circuits removed; iron gears + copper plates + iron plates only | start |
| `electronics` technology | replaced by the Thermionics chain | removed |
| `electronic-circuit` → Control Board | iron plate + copper cable + vacuum tubes | Thermionics |
| `advanced-circuit` → Advanced Control Board | Control Board + discrete transistors + Integrated Circuit + plastic | 10 µm |
| `processing-unit` → Compute Board | Advanced Control Board + Microprocessor + copper plate + sulfuric acid | 3 µm / 350 nm |
| `advanced-circuit` technology | moved behind 10 µm node | 10 µm |
| `processing-unit` technology | moved behind 3 µm / 350 nm | 3 µm / 350 nm |
| `assembling-machine-3` | + Integrated Circuit + Microprocessor | already wired |
| `beacon` | + Microprocessor + System on a Chip | already wired |
| `programmable-speaker` | + Microprocessor | already wired |
| science pack recipes | swap circuits for boards where they currently use them | matching era |

Boards are crafted in the **Circuit Assembler**; computers are crafted in the
separate **Computer Assembler**. Each machine has its own recipe category.
No crusher is added for 1.0.0; `stone → silica` is crafted directly.

### 20.14 What is intentionally NOT in 1.0

- No crusher entity (skip; `stone → silica` is crafted).
- No mod dependencies; Chiptorio is fully self-contained.
- No backward-compatible save migration; 0.10.0 saves break.
- No QLN pattern crafting (AE2-style autocrafting) — stretch goal after 1.0.
- No pollution-based cleanroom contamination — optional later.
- No hand-authored entity art; all prototypes are cloned and tinted from base.

## 21. Immediate next steps

The design is documented. Implementation order:

1. `scripts/circuits_meta.lua` + `scripts/circuits.lua` — the board ladder,
   Circuit Assembler, three vanilla re-themes, bootstrap fix
   (Analytical Engine drops circuits, `thermionics` becomes automation-science-only).
2. SSD line — Flash SSD, NVMe SSD, 3D NAND SSD; QLN cells switch from RAM to SSD.
3. Computers — computer modules (board + chip + RAM + SSD), inserted into
   racks/datacenters; provider profiles change from chip-based to computer-based.
4. Power/cooling throttle + infinite research — P0.1/P0.2.
5. AI — Training Cluster, Inference Lab, five AI tiers, Models as research
   ingredients, AGI Core with stability-to-zero failure.
6. Data contracts, unit probes, and runtime probes for every section above.
7. Playtest from a fresh save; tune `research_meta.lua`, `qln_meta.lua`,
   `answer_meta.lua`; cut 1.0.0.
