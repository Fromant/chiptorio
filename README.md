# Chiptorio

A Factorio total conversion where **computation is the economy**.

Start with a mechanical Analytical Engine and punched cards. End with a cryogenic quantum line, a datacenter full of GPUs, and a machine that has been computing for 42 minutes just to answer one question.

![Chiptorio](thumbnail.png)

- **Factorio:** 2.1 (tested with 2.1.23)
- **DLC:** none required; Nauvis only
- **Status:** 0.8.0 — redesign in progress: enemies and robots removed, network research and the twelve-node process ladder in, QLN next

## What makes it different

- **Research runs on compute, not flasks.** The six vanilla science packs are repurposed as storage media: punched cards, punched tape, magnetic tape, disk packs, SSDs, and mainframe modules. Three more workloads join them: optical discs, HBM stacks, and Qubit Arrays.
- **No biters, no bots.** Enemy generation is disabled and existing enemies are cleaned up. Robots, roboports, and the spidertron are gone. The map is an industrial and engineering puzzle, and item logistics will move to the Quantum Logistics Network.
- **Chips are infrastructure.** Twelve process nodes take you from 10 µm to 1.4 nm. Each node adds mask sets, wafers and dies, and packages the architecture chips of its era: integrated circuits, microprocessors, systems on a chip, GPUs, multi-core CPUs and quantum processors.
- **The factory is the network.** The **Internet** technology unlocks cables, switches, routers, and a monitor. Cables run under machines, switches merge a subnet, routers join subnets, and the monitor shows compute, memory, bandwidth, and latency per network. `ALT + N` draws the topology in-world.
- **Five research computers.** The Analytical Engine, Tube Mainframe, Mainframe Cluster, Datacenter, and Cryostat get faster and accept more modules. They all accept every workload, so the vanilla tech tree cannot deadlock.
- **A real ending.** Build the 5x5 Answer Engine, keep every production line running for 42 minutes, and find out what the factory was for.
- **The redesign** replaces the old sustained-production gate with network compute, memory, and bandwidth. Labs become network clients; datacenters supply compute; twelve process nodes gate the chip ladder. The full plan is in [`DESIGN.md`](DESIGN.md).

## Progression at a glance

| Era | Logic device | Research machine |
|---|---|---|
| 0 | gears and relays | Analytical Engine |
| 1–2 | vacuum tubes and discrete transistors | Tube Mainframe |
| 3–4 | integrated circuits and microprocessors | Mainframe Cluster |
| 5–6 | VLSI, chiplets, GPUs, multi-core CPUs | Datacenter |
| 7 | superconducting qubits | Cryostat |

The full design, balance targets, and per-era production chains are in [`DESIGN.md`](DESIGN.md).

## Installation

1. Install Factorio 2.1. Space Age is not required.
2. Copy this repository into your Factorio `mods` directory:
   - Windows: `%APPDATA%\Factorio\mods`
   - Linux: `~/.factorio/mods`
   - macOS: `~/Library/Application Support/factorio/mods`
3. Enable **Chiptorio** in the mod list and start a new game.

Alternatively, zip the repository root (so `info.json` is at the top of the archive) as `chiptorio_0.8.0.zip` and place it in the `mods` directory.

## Getting started

The vanilla lab is hidden, so the opening works a little differently:

1. Hand-mine and smelt. Crafting 50 iron plates unlocks **Steam Power**; crafting 10 copper plates unlocks **Electronics**.
2. Craft an **Analytical Engine** from gears, copper, iron, and four circuits.
3. Crafting the engine unlocks **Punched Cards** and the first science-pack recipe.
4. Power the engine and start researching.

Nothing before the Analytical Engine needs a lab, a chip, or research. See DESIGN §4.0 for the full opening sequence.

## The Answer

The endgame is a machine, not a menu button. The **Answer Engine** is a 5x5 lab clone assembled in an Assembly Fab from every era of the factory. Booting it requires sustained production of all nine workloads plus microprocessors.

- The computation takes **42 minutes** of real time.
- Dropping below any target pauses the clock; recovering resumes it.
- Completing it prints `42`, plays a generated chiptune fanfare, and sets a custom victory screen.
- **The Question** is an infinite post-game technology. Each level raises the engine's demand by 25% and awards 42 more points per completion.

## Development

This is a Lua mod with no build step. All verification runs through headless Factorio.

### Tests

```powershell
# Data-stage load, map creation, and a 600-tick benchmark
powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1

# Smoke test plus data-contract and runtime assertions
powershell -ExecutionPolicy Bypass -File tools\test-all.ps1
```

Both scripts resolve the Factorio executable automatically:

1. `-Factorio <path>` if provided
2. the `FACTORIO_EXE` environment variable
3. `FACTORIO_EXE` in a repository-root `.env` file
4. common Steam library and install locations

If automatic detection fails, copy `.env.example` to `.env` and set its `FACTORIO_EXE` value. The `.env` file is gitignored, so it can stay machine-specific.

The contract probe lives in `tools/test-probe/`. It loads as a second mod, unit-tests the pure graph, research allocator and process-node table in the data stage, asserts the data contract after every mod has loaded, and then checks the fresh map at runtime. The wrappers look for `CHIPTORIO-TEST PASS` and fail on `CHIPTORIO-TEST FAIL`. Both scripts support `-Keep` to retain the temporary save for inspection.

### Generated assets

Icons, the mod thumbnail, and the victory image are generated, not hand-authored:

```powershell
powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
powershell -ExecutionPolicy Bypass -File tools\make-sound.ps1
```

`make-sound.ps1` requires `ffmpeg` on `PATH` and rebuilds `sound/answer-fanfare.ogg`.

### Project layout

```text
data.lua / data-updates.lua   prototype stages
control.lua                   runtime entry point and tick dispatcher
scripts/                      data-stage and runtime modules
graphics/, sound/             generated assets
tools/                        headless tests, path resolution, asset generators
.env.example                  template for local Factorio path overrides
```

More detail, including the 2.1 API pitfalls and module map, is in DESIGN §15. [`AGENTS.md`](AGENTS.md) contains the conventions for coding agents working in this repository, and [`changelog.txt`](changelog.txt) tracks releases.

## Status

Version 0.8.0 completes the compute economy and the semiconductor ladder. Enemies and robots are gone, the throughput gate is removed, labs run on network compute, memory and bandwidth, and twelve process nodes carry the chip line from 10 µm to 1.4 nm. QLN logistics, the half-node qualification loop and the Answer Engine rework are next milestones; `1.0.0` is the complete redesign.
