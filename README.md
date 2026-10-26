# Chip'torio

A Factorio total conversion where **computation is the economy**.

Start with a mechanical Analytical Engine and punched cards. End with a cryogenic quantum line, a datacenter full of GPUs, and a machine that has been computing for 42 minutes just to answer one question.

![Chip'torio](thumbnail.png)

- **Factorio:** 2.1 (tested with 2.1.23)
- **DLC:** none required; Nauvis only
- **Status:** 0.5.0 — Eras 0–7 and The Answer endgame implemented

## What makes it different

- **Research runs on compute, not flasks.** The six vanilla science packs are repurposed as storage media: punched cards, punched tape, magnetic tape, disk packs, SSDs, and mainframe modules. Qubit Arrays are a seventh workload.
- **Throughput is a factory test.** Selected technologies require a sustained production rate, measured over a rolling minute. A stockpile can keep the labs fed, but it cannot satisfy the gate; below the target, research is throttled and then decays.
- **Chips are infrastructure.** You mine silica, pull silicon crystals, expose wafers, etch, dice, package, and eventually build VLSI dies, chiplets, GPUs, and quantum processors. Late-game vanilla machines are re-costed to need them.
- **Five research computers.** The Analytical Engine, Tube Mainframe, Mainframe Cluster, Datacenter, and Cryostat get faster and accept more modules. They all accept every workload, so the vanilla tech tree cannot deadlock.
- **A real ending.** Build the 5x5 Answer Engine, keep every production line running for 42 minutes, and find out what the factory was for.

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
3. Enable **Chip'torio** in the mod list and start a new game.

Alternatively, zip the repository root (so `info.json` is at the top of the archive) as `chipotrio_0.5.0.zip` and place it in the `mods` directory.

## Getting started

The vanilla lab is hidden, so the opening works a little differently:

1. Hand-mine and smelt. Crafting 50 iron plates unlocks **Steam Power**; crafting 10 copper plates unlocks **Electronics**.
2. Craft an **Analytical Engine** from gears, copper, iron, and four circuits.
3. Crafting the engine unlocks **Punched Cards** and the first science-pack recipe.
4. Power the engine and start researching.

Nothing before the Analytical Engine needs a lab, a chip, or research. See DESIGN §4.0 for the full opening sequence.

## The Answer

The endgame is a machine, not a menu button. The **Answer Engine** is a 5x5 lab clone assembled in a Server Rack from every era of the factory. Booting it requires sustained production of all seven workloads plus microprocessors.

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

# Runtime regression for the throughput gate (2%/min decay)
powershell -ExecutionPolicy Bypass -File tools\test-gate.ps1
```

Both scripts resolve the Factorio executable automatically:

1. `-Factorio <path>` if provided
2. the `FACTORIO_EXE` environment variable
3. `FACTORIO_EXE` in a repository-root `.env` file
4. common Steam library and install locations

If automatic detection fails, copy `.env.example` to `.env` and set its `FACTORIO_EXE` value. The `.env` file is gitignored, so it can stay machine-specific.

`test-gate.ps1` requires `-Ticks` to be a multiple of 60. Both scripts support `-Keep` to retain the temporary save for inspection.

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

More detail, including the 2.1 API pitfalls and module map, is in DESIGN §8. [`AGENTS.md`](AGENTS.md) contains the conventions for coding agents working in this repository, and [`changelog.txt`](changelog.txt) tracks releases.

## Status

Version 0.5.0 completes the gameplay arc through Era 7 and The Answer. A full rebalance, biter/pollution pass, and multiplayer test are planned for 0.6; art, sound, achievements, and a mod-portal release are planned for 1.0.
