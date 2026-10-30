# Chiptorio — Overview

A Factorio 2.1 total-conversion mod where **computation is the economy**.

Start with a mechanical Analytical Engine and punched cards. End with a cryogenic
quantum line, a datacenter full of GPUs, and a machine that has been computing
for 42 minutes just to answer one question.

## Facts

| Field | Value |
|-------|-------|
| Factorio version | 2.1 (tested with 2.1.23) |
| DLC | None required; Nauvis only |
| Mod ID | `chiptorio` |
| Status | 1.0.0 — feature-complete |
| Space Age | Not used |

## What makes it different

- **Research runs on compute, not flasks.** The six vanilla science packs are
  repurposed as storage media: punched cards, punched tape, magnetic tape, disk
  packs, SSDs, and mainframe modules. Three more workloads join them: optical
  discs, HBM stacks, and Qubit Arrays.
- **No biters, no bots.** Enemy generation is disabled and existing enemies are
  cleaned up. Robots, roboports, and the spidertron are gone. Item logistics
  runs on the Quantum Logistics Network (QLN), and a scripted Construction Core
  does the building that robots used to do.
- **Chips are infrastructure.** Twelve process nodes take you from 10 µm to
  1.4 nm. Each node adds mask sets, wafers and dies, and packages the
  architecture chips of its era: integrated circuits, microprocessors, systems
  on a chip, GPUs, multi-core CPUs and quantum processors.
- **Storage is memory.** A QLN Storage Drive is only as large as the modules
  installed in it. Eleven memory generations run from SRAM to 3D NAND, and each
  arrives with the process node of its era.
- **The factory is the network.** Internet unlocks cables, switches, routers,
  and a monitor. Four cable tiers run from twisted pair to single-mode fiber;
  a segment's bandwidth is its weakest link. Cables collide with everything —
  route them around machines, not under them. Switches (3×2 junction boxes)
  merge segments; routers (3×2 gateways with 16-tile WiFi reach) bridge them.
  The monitor shows compute, memory, bandwidth, power, heat, and cooling per
  network across five tabs. `ALT + N` draws the topology in-world.
- **Five research computers.** Analytical Engine, Tube Mainframe, Mainframe
  Cluster, Datacenter, and Cryostat. They all accept every workload, so the
  vanilla tech tree cannot deadlock.
- **A real ending.** Build the 5×5 Answer Engine, supply every compute profile,
  dataset, bandwidth and item line for 42 minutes, and find out what the
  factory was for.

## Progression at a glance

| Era | Logic device | Research machine |
|-----|-------------|------------------|
| 0 | gears and relays | Analytical Engine |
| 1–2 | vacuum tubes and discrete transistors | Tube Mainframe |
| 3–4 | integrated circuits and microprocessors | Mainframe Cluster |
| 5–6 | VLSI, chiplets, GPUs, multi-core CPUs | Datacenter |
| 7 | superconducting qubits | Cryostat |

The full design, balance targets, and per-era production chains are in
[`DESIGN.md`](DESIGN.md).

## Project layout

```
data.lua / data-updates.lua   prototype stages
control.lua                   runtime entry point and tick dispatcher
scripts/                      data-stage and runtime modules
graphics/, sound/             generated assets
tools/                        headless tests, path resolution, asset generators
docs/                         structured project documentation
.env.example                  template for local Factorio path overrides
```

More detail, including the 2.1 API pitfalls and module map, is in DESIGN §15.
[`AGENTS.md`](AGENTS.md) contains conventions for coding agents working in this
repository, and [`changelog.txt`](changelog.txt) tracks releases.
