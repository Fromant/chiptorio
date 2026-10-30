# Chiptorio — Installation and Development

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

Nothing before the Analytical Engine needs a lab, a chip, or research. See
DESIGN §4.0 for the full opening sequence.

## Play (development)

```powershell
# Launch Factorio with the current working tree as the active mod
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1

# Snapshot the tree instead of linking it
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -Copy

# Launch and return without waiting for the game to exit
powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -NoWait
```

The run script creates an isolated dev mod directory at
`%TEMP%\chiptorio-dev\mods`, links the repository into it, enables Chiptorio in
`mod-list.json`, and launches Factorio with `--mod-directory`. A directory
junction means every launch uses the latest working tree; `-Copy` takes a
snapshot instead. Start a new Nauvis game and leave Space Age off.

## Factorio executable resolution

All scripts resolve Factorio in this order:

1. `-Factorio <path>` parameter
2. `FACTORIO_EXE` environment variable
3. `FACTORIO_EXE` in a repository-root `.env` file
4. Common Steam library and install locations (auto-detected)

Keep path logic in `tools/common.ps1`; do not hardcode a local install. `.env`
is gitignored and `.env.example` is the tracked template.

## Tests

```powershell
# Data-stage load, map creation, and a 600-tick benchmark
powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1

# Full verification: smoke, contract, registration audit, save/load, power-grid, perf
powershell -ExecutionPolicy Bypass -File tools\test-all.ps1
```

Both scripts support `-Keep` to retain the temporary save for inspection and
`-Ticks <n>` to set the benchmark tick count (must be a multiple of 60 for
test-contract).

Individual test scripts:

| Script | Purpose |
|--------|---------|
| `tools\test-mod.ps1` | Smoke test: load, create map, run benchmark |
| `tools\test-contract.ps1` | Data contract + runtime probe (benchmark) |
| `tools\test-save-load.ps1` | P1.2 save/load (hosted server + reload) |
| `tools\test-power-grid.ps1` | P1.7 Construction Core on a real grid (hosted server) |
| `tools\test-perf.ps1` | P1.5 tick-time performance harness |
| `tools\test-registration.ps1` | P1.8 static registration audit |
| `tools\test-all.ps1` | All of the above |

The probe is a separate test mod in `tools/test-probe/`. Its data stage
unit-tests the pure modules through a cross-mod
`require("__chiptorio__/scripts/...")`, so adding `game`, `storage`, or `data`
access to a pure module breaks the unit suite. A new spec must be required from
`tools/test-probe/data.lua` before `unit_harness.finish`; a new runtime suite
belongs in `tools/test-probe/control.lua`.

Data-contract assertions live in `tools/test-probe/data-updates.lua`. A
prototype change usually needs a matching check there, not just a passing smoke
test.

## Generated assets

Icons, the mod thumbnail, and the victory image are generated, not hand-authored:

```powershell
powershell -ExecutionPolicy Bypass -File tools\make-icons.ps1
powershell -ExecutionPolicy Bypass -File tools\make-sound.ps1
```

`make-sound.ps1` requires `ffmpeg` on `PATH` and rebuilds
`sound/answer-fanfare.ogg`.

## Release

Bump `info.json` `version` and add a dated `changelog.txt` entry under
Features/Balance/Bugfixes, newest first.
