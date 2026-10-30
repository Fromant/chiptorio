# Chiptorio

A Factorio total conversion where **computation is the economy**.

Start with a mechanical Analytical Engine and punched cards. End with a
cryogenic quantum line, a datacenter full of GPUs, and a machine that has been
computing for 42 minutes just to answer one question.

![Chiptorio](thumbnail.png)

- **Factorio:** 2.1 (tested with 2.1.23)
- **DLC:** none required; Nauvis only
- **Status:** 1.0.0 — feature-complete

## What makes it different

- **Research runs on compute, not flasks.** The six vanilla science packs are
  repurposed as storage media. Three more workloads join them: optical discs,
  HBM stacks, and Qubit Arrays.
- **No biters, no bots.** Enemy generation is disabled and existing enemies are
  cleaned up. Robots are gone. Item logistics runs on the Quantum Logistics
  Network (QLN), and a scripted Construction Core does the building.
- **Chips are infrastructure.** Twelve process nodes take you from 10 µm to
  1.4 nm, packaging the architecture chips of each era.
- **Storage is memory.** A QLN Storage Drive is only as large as the modules
  installed in it. Eleven memory generations run from SRAM to 3D NAND.
- **The factory is the network.** Internet unlocks cables, switches, routers,
  and a monitor. Four cable tiers run from twisted pair to single-mode fiber;
  a segment's bandwidth is its weakest link.
- **Five research computers.** Analytical Engine, Tube Mainframe, Mainframe
  Cluster, Datacenter, and Cryostat. They all accept every workload.
- **A real ending.** Build the 5×5 Answer Engine, supply every compute profile,
  dataset, bandwidth and item line for 42 minutes.

## Progression at a glance

| Era | Logic device | Research machine |
|-----|-------------|------------------|
| 0 | gears and relays | Analytical Engine |
| 1–2 | vacuum tubes and discrete transistors | Tube Mainframe |
| 3–4 | integrated circuits and microprocessors | Mainframe Cluster |
| 5–6 | VLSI, chiplets, GPUs, multi-core CPUs | Datacenter |
| 7 | superconducting qubits | Cryostat |

## Installation

1. Install Factorio 2.1. Space Age is not required.
2. Copy this repository into your Factorio `mods` directory:
   - Windows: `%APPDATA%\Factorio\mods`
   - Linux: `~/.factorio/mods`
   - macOS: `~/Library/Application Support/factorio/mods`
3. Enable **Chiptorio** in the mod list and start a new game.

Alternatively, zip the repository root (so `info.json` is at the top of the
archive) as `chiptorio_0.10.0.zip` and place it in the `mods` directory.

## Getting started

The vanilla lab is hidden, so the opening works a little differently:

1. Hand-mine and smelt. Crafting 50 iron plates unlocks **Steam Power**;
   crafting 10 copper plates unlocks **Electronics**.
2. Craft an **Analytical Engine** from gears, copper, iron, and four circuits.
3. Crafting the engine unlocks **Punched Cards** and the first science-pack
   recipe.
4. Power the engine and start researching.

Nothing before the Analytical Engine needs a lab, a chip, or research.

## Development

This is a Lua mod with no build step. All verification runs through headless
Factorio. See [`docs/installation.md`](docs/installation.md) for play and test
commands, and [`docs/`](docs/) for structured project documentation.

## Status

Version 1.0.0 is feature-complete. Enemies and robots are gone, the throughput
gate is removed, labs run on network compute, memory and bandwidth with a
power/cooling throttle, twelve process nodes carry the chip line from 10 µm
to 1.4 nm, and ten refinements between them are unlocked by research but only
take effect after a pilot line has been analysed in a Metrology Lab. QLN
covers the Data Bus, quantum-linked storage, FOUP logistics, repeaters and
wireless access points, and a Construction Core replaces construction robots.
The Answer Engine draws its items from QLN and scales forever through The
Question.

See [`TODO.md`](TODO.md) for the gap register and
[`changelog.txt`](changelog.txt) for the release record.
