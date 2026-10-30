# Chiptorio

A Factorio total conversion where **computation is the economy**.

Start with a mechanical Analytical Engine and punched cards. End with a cryogenic quantum line, a datacenter full of GPUs, and a machine that has been computing for 42 minutes just to answer one question.

![Chiptorio](thumbnail.png)

- **Factorio:** 2.1 (tested with 2.1.23)
- **DLC:** none required; Nauvis only
- **Status:** 1.0.0 — feature-complete: enemies and robots are gone, research runs on network compute with power/cooling throttle, the twelve-node process ladder and half-node qualification are in, QLN (with eleven memory generations), the reworked Answer Engine with infinite research, five-tab network monitor, and the vanilla-circuit board ladder all ship.

## What makes it different

- **Research runs on compute, not flasks.** The six vanilla science packs are repurposed as storage media: punched cards, punched tape, magnetic tape, disk packs, SSDs, and mainframe modules. Three more workloads join them: optical discs, HBM stacks, and Qubit Arrays.
- **No biters, no bots.** Enemy generation is disabled and existing enemies are cleaned up. Robots, roboports, and the spidertron are gone. Item logistics runs on the **Quantum Logistics Network** (QLN), and a scripted Construction Core does the building that robots used to do.
- **Chips are infrastructure.** Twelve process nodes take you from 10 µm to 1.4 nm. Each node adds mask sets, wafers and dies, and packages the architecture chips of its era: integrated circuits, microprocessors, systems on a chip, GPUs, multi-core CPUs and quantum processors.
- **Storage is memory.** A QLN Storage Drive is only as large as the modules installed in it. Eleven memory generations run from 1k SRAM to 256k 3D NAND, and each arrives with the process node of its era, so a finer fab really does mean a bigger pool.
- **The factory is the network.** The **Internet** technology unlocks cables, switches, routers, and a monitor. Four cable tiers run from twisted pair to single-mode fiber; a segment's bandwidth is its weakest link. Cables collide with everything — route them around machines, not under them. Cable runs auto-tile into straight, corner, junction and ending sprites. Switches (3×2 junction boxes) merge segments; routers (3×2 gateways with 16-tile WiFi reach) bridge them. The monitor shows compute, memory, bandwidth, power, heat, and cooling per network across five tabs. `ALT + N` draws the topology in-world.
- **Five research computers.** The Analytical Engine, Tube Mainframe, Mainframe Cluster, Datacenter, and Cryostat get faster and accept more modules. They all accept every workload, so the vanilla tech tree cannot deadlock.
- **A real ending.** Build the 5x5 Answer Engine, supply every compute profile, dataset, bandwidth and item line for 42 minutes, and find out what the factory was for.
- **The redesign** replaces the old sustained-production gate with network compute, memory, and bandwidth. Labs become network clients; datacenters supply compute; twelve process nodes gate the chip ladder, and ten half-node refinements are qualified by running a pilot line through a Metrology Lab. The full plan is in [`DESIGN.md`](DESIGN.md).

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

Alternatively, zip the repository root (so `info.json` is at the top of the archive) as `chiptorio_0.10.0.zip` and place it in the `mods` directory.

## Getting started

The vanilla lab is hidden, so the opening works a little differently:

1. Hand-mine and smelt. Crafting 50 iron plates unlocks **Steam Power**; crafting 10 copper plates unlocks **Electronics**.
2. Craft an **Analytical Engine** from gears, copper, iron, and four circuits.
3. Crafting the engine unlocks **Punched Cards** and the first science-pack recipe.
4. Power the engine and start researching.

Nothing before the Analytical Engine needs a lab, a chip, or research. See DESIGN §4.0 for the full opening sequence.

## The Answer

The endgame is a machine, not a menu button. The **Answer Engine** is a 5x5 lab clone assembled in an Assembly Fab from every era of the factory. Booting it requires the network behind it to supply all four compute profiles, a large memory dataset, backplane bandwidth, and a continuous QLN draw of science packs, microprocessors and quantum processors. It does not read production statistics or accept science packs directly.

- The computation takes **42 minutes** of real time.
- Dropping below any target pauses the clock; recovering resumes it.
- Completing it prints `42`, plays a generated chiptune fanfare, and sets a custom victory screen.
- **The Question** is an infinite post-game technology. Each level raises the engine's demand by 25% and awards 42 more points per completion.

## Development

This is a Lua mod with no build step. All verification runs through headless Factorio.

### Play

```powershell
# Launch Factorio with the current working tree as the active mod
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1

# Snapshot the tree instead of linking it
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -Copy

# Launch and return without waiting for the game to exit
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -NoWait
```

The run script creates an isolated dev mod directory at `%TEMP%\chiptorio-dev\mods`, links the repository into it, enables Chiptorio in `mod-list.json`, and launches Factorio with `--mod-directory`. A directory junction means every launch uses the latest working tree; `-Copy` takes a snapshot instead. Start a new Nauvis game and leave Space Age off.

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

The contract probe lives in `tools/test-probe/`. It loads as a second mod, unit-tests the pure graph, research allocator, process-node table, qualification allocator and QLN transport in the data stage, asserts the data contract after every mod has loaded, and then checks the fresh map at runtime. The wrappers look for `CHIPTORIO-TEST PASS` and fail on `CHIPTORIO-TEST FAIL`. Both scripts support `-Keep` to retain the temporary save for inspection.

A benchmark map has no player and Factorio 2.1 has no script API to create one, so the probe logs `CHIPTORIO-TEST SKIP qln-gui` and skips the QLN Terminal and FOUP Dock window checks. To exercise those paths, enable `tools/test-probe` as a second mod in a normal save that has a character and watch `factorio-current.log` for the runtime `PASS` markers. Do this in a disposable save: the probe clears and rebuilds a test area, drives the Answer Engine, and destroys the entities it created.

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

Version 1.0.0 is feature-complete. Enemies and robots are gone, the throughput gate is removed, labs run on network compute, memory and bandwidth with a power/cooling throttle, twelve process nodes carry the chip line from 10 µm to 1.4 nm, and ten refinements between them are unlocked by research but only take effect after a pilot line has been analysed in a Metrology Lab. QLN covers the Data Bus, quantum-linked storage, FOUP logistics, repeaters and wireless access points, and a Construction Core replaces construction robots. The Answer Engine draws its items from QLN and scales forever through The Question.

[`TODO.md`](TODO.md) is the gap register for what follows 1.0.0: manual save/load, GUI and tick-time performance verification, the deferred FOUP contamination gate, and post-1.0 balance tuning. Construction Core power-grid verification is automated via `tools/test-power-grid.ps1`.
