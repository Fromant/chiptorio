# Chiptorio — Blender Asset TODO

This document tracks every sprite/icon/asset in the mod that would benefit
from being created in Blender. Currently:

- **`server-rack`** is the only entity with Blender-rendered directional art
  (`graphics/entity/server-rack/`), produced by `tools/graphics/blender/`.
- The first nineteen P0 entries below now have installed, single-view Blender game
  sprites with working/unlit-idle states. Remaining entities still use legacy
  `tools/make-entities.ps1` PNGs.
- All icons and technology icons are hand-drawn 64x64 / 256x256 PNGs.

Priority: P0 = blocks gameplay clarity, P1 = improves polish, P2 = nice-to-have.

**Batch 6 in staged review:** Crystal Puller, Wafer Fab, Assembly Fab, Computer
Assembler and VLSI Fab now have **5×5 candidate designs**. See
[batch-6-assets.md](batch-6-assets.md). These are not installed or visually approved.
Use the [shared approval-gated pipeline](asset-pipeline.md), not the historical
direct-install PowerShell commands recorded below. Earlier batches stay protected.

**Direction (revision 04):** see
[Machine scale and art direction](machine-scale-and-art-direction.md). Planned
redesigns use **square occupied footprints**, not the earlier 9×7/7×5 proposals.
Industrial-scale computing, a robotic assembler without fans, distinct AI
silhouettes, irregular Ethernet-like port lights and limited optional component
props are recorded there. The later request authorizes only the four-machine
[Batch 5 redo](batch-5-redo.md): assembler 5×5, training 9×9, inference 7×7, monitor
3×3. Terminal stays exactly 1×1 and untouched. The later Batch 6 request separately
authorizes five 5×5 candidates, not installation. Other proposed resizes/balancing
still need approval; do not retrofit earlier batches.

**Installed art direction (revision 03):** prefer symmetric, non-rotatable factory machines
over front-facing cabinets/consoles. Put recognizable function and working motion
on top, distribute detail around all sides, and avoid a single preferred viewing
face. Detail should explain the mechanism, not merely add trim. Working loops
must include actual mechanical motion where appropriate, not only blinking lamps.

**Game asset batch, revision 03:** the first five P0 entries have native model
builders in `tools/graphics/blender/<entity>/`. `render-game-labs.ps1 -Build -Install`
exports one actual game view, native working loops, unlit idle stills and shadows.
`scripts/labs.lua` consumes the generated definitions directly. The exact-sheet
viewer is not a separate hero render. See `tools/graphics/blender/LAB-PREVIEWS.md`.

**Second installed batch:** P0.6–P0.10 use `render-game-infrastructure.ps1` and the
same packing/alignment pipeline. See `tools/graphics/blender/INFRASTRUCTURE-ASSETS.md`
for actual processing/online/link activity hooks and native battery animations.

**Third installed batch:** P0.11–P0.15 use `render-game-logistics.ps1`; the five
utility nodes retain their actual 1×1 footprints. See
`tools/graphics/blender/LOGISTICS-ASSETS.md` for transfer and seal/unseal activity,
link-status scope, and previews. Standalone AP routing remains a separate gap.

---

## Live inventory and render batches

The complete graphic inventory is now in **Asset Studio**:
`cd tools/asset-studio`, `npm ci`, `npm run dev`. Open
`http://127.0.0.1:4173`. It detects every shipped PNG, inherited machine sprites,
editable Blender models, and installed tools. `npm run export` regenerates the
standalone root `asset-overview.html`. See [asset-studio.md](asset-studio.md).

Batch 4 retains only `qln-requester-node`. The rejected facing drafts were removed.
**Batch 5 is installed:** fresh non-facing `qln-terminal`, `training-cluster`,
`inference-lab`, `circuit-assembler`, and `network-monitor`. It uses the Node-only
`npm run render:batch5` build/render/validated-pack pipeline; see
[batch-5-redo.md](batch-5-redo.md). The initial implementation is recorded separately
in [batch-5-assets.md](batch-5-assets.md). Further batches are defined in
`tools/asset-studio/catalog.mjs`, with five graphics per icon/technology batch.
The app's prototype-derived selection sizes supersede historical size ideas below.
The initial assembler/AI designs were rejected after technical testing. The four
revision-04 replacements remain in batch 5 rather than being counted as a new batch.

## P0 — Entity World Sprites (blocking / used in-game)

P0.1–P0.19 are converted; Circuit Assembler and Network Monitor below are also converted. Future conversions should
follow the fixed-view art direction above, not the old four-direction suggestions.

| # | Entity | Current Art | Visual Idea | Blender Params |
|---|--------|-------------|-------------|----------------|
| P0.1 | `analytical-engine` | `graphics/entity/analytical-engine/` | Open mechanical computer hall: two long decimal-store banks, twelve spindles, 48 numbered drums, a geared mill aisle and carry mechanisms. | Footprint 4x2, fixed game view; register rotation, eccentric drive, carry motion, card advance |
| P0.2 | `tube-mainframe` | `graphics/entity/tube-mainframe/` | Four open valve banks, static relay/meter hardware, corner transformers without decorative rings. | Footprint 2x2, fixed game view; light-only working loop, all bulbs off when idle |
| P0.3 | `mainframe-cluster` | `graphics/entity/mainframe-cluster/` | Four radial exposed logic banks, IC leads, gold contacts, backplane harnesses, central exhaust; no opaque lid hiding the hardware. | Footprint 2x2, fixed game view; fan rotation and bank activity |
| P0.4 | `datacenter-lab` | `graphics/entity/datacenter-lab/` | Server-blade seams/latches, a detailed top compute plane with activity lights and corner radiators. No exposed copper pistons or moving scan heads. | Footprint 2x2, fixed game view; radiator fans and optical activity |
| P0.5 | `cryostat` | `graphics/entity/cryostat/` | Radial thermal shields and quantum sample stage, sealed helium compressors, coaxial insulation sleeves on straight risers and separate pipe elbows. | Footprint 2x2, fixed game view; light-only sample pulse, idle lights off |
| P0.6 | `metrology-lab` | `graphics/entity/metrology-lab/` | Real XY wafer stage below a fixed objective, vibration bed and service quadrants. | 3x3, fixed game view; scanning during supported wafer analysis |
| P0.7 | `answer-engine` | `graphics/entity/answer-engine/` | Four compute banks, corner power towers, cooling fans and an illuminated roof "42". | 5x5, fixed game view; lights/fans follow successful computation |
| P0.8 | `qln-storage-drive` | `graphics/entity/qln-storage-drive/` | Four accessible single-module memory bays, backplane controller and status segments. | 2x2, fixed game view; online heartbeat when connected/populated |
| P0.9 | `quantum-entanglement-core` | `graphics/entity/quantum-entanglement-core/` | Twin cryogenic sample wells with optical link guides and phase lights; no rotating floating cores. | 2x2, fixed game view; link pulse only when paired |
| P0.10 | `construction-core` | `graphics/entity/construction-core/` | Eight ceramic power cells, copper buses and segmented charge indicators. | Existing 2x2 footprint retained; native charge/discharge animation |
| P0.11 | `foup-dock` | `graphics/entity/foup-dock/` | Guided wafer carrier load port with locking cams and cycle indicators. | Existing 1x1 retained; fixed game view; successful seal/unseal activity |
| P0.12 | `wireless-access-point` | `graphics/entity/wireless-access-point/` | Fixed mast, four ceramic RF patches, link-status lamps. | Existing 1x1 retained; fixed game view; connected-status pulse, no new routing |
| P0.13 | `qln-import-node` | `graphics/entity/qln-import-node/` | Blue recessed ingress aperture with inward flow arrows and packet indicators. | Existing 1x1 retained; fixed game view; lights on actual import |
| P0.14 | `qln-export-node` | `graphics/entity/qln-export-node/` | Ochre raised egress manifold with outward flow arrows and packet indicators. | Existing 1x1 retained; fixed game view; lights on actual delivery |
| P0.15 | `qln-provider-node` | `graphics/entity/qln-provider-node/` | Eight cargo compartments, protective rim and green supply indicators. | Existing 1x1 retained; fixed game view; lights on actual accepted cargo |
| P0.16 | `qln-requester-node` | `graphics/entity/qln-requester-node/` | Filter slot chassis with request pulse indicators. | Existing 1x1 retained; fixed game view; lights on actual item requests |
| P0.17 | `qln-terminal` | `graphics/entity/qln-terminal/` | Low four-sided terminal with horizontal storage-map display and recessed readers. | 1x1; lights while its GUI is in use |
| P0.18 | `training-cluster` | `graphics/entity/training-cluster/` | GPU cabinet hall, exposed accelerator blades, fabric bridges, service aisles and coolant plant. | Revision 04: actual 9x9; working only on successful scripted training |
| P0.19 | `inference-lab` | `graphics/entity/inference-lab/` | Tall model-cartridge library with selector carriages and separate lower serving banks. | Revision 04: actual 7x7; working only on supported inference |

---

## P1 — Entity World Sprites (polish)

| # | Entity | Current Art | Visual Idea | Blender Params |
|---|--------|-------------|-------------|----------------|
| P1.1 | `wafer-fab` | `graphics/entity/wafer-fab.png` | 7x7 cleanroom with fluid pipes, load port, status screen, wafer cassette. | Footprint 7x7, size 320px, 4 directions, fluid pipe animation |
| P1.2 | `crystal-puller` | `graphics/entity/crystal-puller.png` | 5x5 furnace with crystal cylinder, melt pool, top heater ring. | Footprint 5x5, size 240px, 4 directions, crystal rotation, heat glow |
| P1.3 | `assembly-fab` | `graphics/entity/assembly-fab.png` | 5x5 packaging line with chip pattern, I/O ports, top spool. | Footprint 5x5, size 240px, 4 directions, spool rotation |
| P1.4 | `circuit-assembler` | `graphics/entity/circuit-assembler/` | Two articulated robots, chip pickup/placement, work clamps and timed PCB shuttle; no fans or reels. | Revision 04: actual 5x5; native crafting and unlit idle |
| P1.5 | `computer-assembler` | `graphics/entity/computer-assembler.png` | 3x3 bench with blue screen, circuit lid. | Footprint 3x3, size 160px, 4 directions |
| P1.6 | `vlsi-fab` | `graphics/entity/vlsi-fab.png` | 7x7 massive plant with coolant pipes, mask-loader port. | Footprint 7x7, size 320px, 4 directions |
| P1.7 | `cooling-tower` | `graphics/entity/cooling-tower.png` | 5x5 tower with top fan, vapor plumes, pipe inlets. | Footprint 5x5, size 240px, 4 directions, fan rotation, vapor animation |
| P1.8 | `quantum-fab` | `graphics/entity/quantum-fab.png` | 7x7 cryogenic plant with frost patterns, dilution refrigerator. | Footprint 7x7, size 320px, 4 directions, frost animation |
| P1.9 | `network-switch` | `graphics/entity/network-switch.png` | 2x2 box chassis with 4-sided ports, green LEDs, top status display. | Footprint 2x2, size 128px, 4 directions, port LED blink |
| P1.10 | `network-router` | `graphics/entity/network-router.png` | 2x2 box with two antennas, signal arcs. | Footprint 2x2, size 128px, 4 directions, signal arc pulse |
| P1.11 | `network-monitor` | `graphics/entity/network-monitor/` | Square topology instrument, four Ethernet-like port banks, steady link lights and independent bursts. | Revision 04: actual 3x3; online decorative activity, not packet telemetry |

---

## P2 — Item Icons (64x64)

These are currently hand-drawn. Blender versions would give consistent
materials, lighting, and isometric presentation.

### Compute Modules (chip modules)
| Item | Visual Idea |
|------|-------------|
| `microcomputer` | Small PCB with microprocessor + SRAM, isometric |
| `server` | Server blade with SoC + DDR3, isometric |
| `supercomputer` | GPU card with HBM3, isometric |
| `neural-computer` | Neural processor board with HBM3, isometric |
| `quantum-computer` | Quantum processor board with 3D NAND, isometric |

### Memory Modules
| Item | Visual Idea |
|------|-------------|
| `sram-module` through `hbm3-module` | RAM sticks of increasing sophistication, isometric |

### Chips & Components
| Item | Visual Idea |
|------|-------------|
| `vacuum-tube` | Glass vacuum tube with orange filament |
| `discrete-transistor` | Through-hole transistor |
| `chiplet` | Small bare die |
| `hbm-stack` | Stacked memory dies |
| `qubit` | Superconducting qubit chip |
| `error-corrected-qubit` | Qubit with error correction surface |

### Boards & Process Items
| Item | Visual Idea |
|------|-------------|
| `processing-unit` | Green PCB with components |
| `silicon-wafer` | Silicon wafer, circular |
| `litho-mask` | Photomask plate, square |
| `metrology-test-structure` | Small test structure, square |

---

## P3 — Technology Icons (256x256 or 480x256)

Already exist as hand-drawn PNGs. Blender versions would be a major upgrade
but are lowest priority since they're small in-game.

All technologies in `graphics/technology/` could be blender-rendered:
- Process nodes: `process-10um`, `process-1um`, `process-350nm`, etc.
- Refinements: `refine-6um`, `refine-2nm`, etc.
- AI: `machine-learning`, `ai-specialist`, `ai-general`, `ai-frontier`, `artificial-general-intelligence`
- QLN: `qln`, `qln-quantum`
- Endgame: `the-question`, `quantum-advantage`

---

## P4 — Cable World Sprites

The 16 cable direction sprites (straight, corner, T, cross, ending) for each
of 4 cable tiers are currently generated by `make-icons.ps1`. Blender versions
would give proper 3D cable connectors.

Cable tiers: `network-cable`, `network-coaxial-cable`, `network-fiber-mm-cable`, `network-fiber-sm-cable`
Shapes per tier: `straight_vertical_single`, `straight_vertical`, `straight_horizontal`, `corner_up_right`, `corner_up_left`, `corner_down_right`, `corner_down_left`, `t_up`, `t_down`, `t_left`, `t_right`, `cross`, `ending_up`, `ending_down`, `ending_left`, `ending_right`

---

## P5 — GUI & Misc

| Asset | Description | Visual Idea |
|-------|-------------|-------------|
| `thumbnail.png` | Mod thumbnail for portal | Answer Engine with "42" |
| `answer-ending.png` | Endgame image | The Answer revealed |
| `sound/answer-fanfare.ogg` | Endgame sound | Orchestral fanfare |

---

## Pipeline Specifications (from `tools/graphics/blender/`)

### Entity Sprite Pipeline
```
build.py          → rebuilds <name>.blend from native geometry
render.py         → renders all 4 directions + shadows
render-entity.ps1 → PowerShell wrapper for render.py
pack.ps1          → packs frames into sheets, validates dimensions,
                    emits sprite-def.lua, installs to graphics/entity/<name>/
```

### Per-entity Blender Directory Structure
```
tools/graphics/blender/<entity-name>/
├── <entity-name>.blend      # Native Blender file
├── build.py                 # Geometry/materials builder
├── render.py                # Camera/render settings exporter
├── render-entity.ps1        # PowerShell render wrapper
└── pack.ps1                 # Sheet packer + installer
```

### Animation Specs
- **Idle**: animation_speed = 0.001 (frozen single frame)
- **Working**: animation_speed = 0.5, played via rendering overlay when active
- **Directions**: north, east, south, west (4-directional)
- **Shadow**: draw_as_shadow = true, offset appropriately
- **Scale**: 0.5 for most entities (160px canvas → 80 game pixels at 3x3 footprint)

### Size Map by Footprint
| Footprint | Canvas Size | Scale |
|-----------|-------------|-------|
| 1x1       | 80px        | 0.5   |
| 2x2       | 128px       | 0.5   |
| 3x3       | 160px       | 0.5   |
| 5x5       | 240px       | 0.5   |
| 7x7       | 320px       | 0.5   |

---

## Migration Notes

The `server-rack` is the model to follow:
1. `tools/graphics/blender/server-rack/` contains `server-rack.blend`, `build.py`, `render.py`, `render-entity.ps1`, `pack.ps1`
2. `pack.ps1 -Install` copies sheets/shadows/sprite-def.lua to `graphics/entity/server-rack/`
3. `scripts/providers.lua` reads `graphics.entity.server-rack.sprite-def` and builds `graphics_set.animation` per direction
4. `scripts/runtime/rack_runtime.lua` plays the working animation via `rendering.draw_animation` only when computer modules are installed

To convert another entity to Blender, clone the `server-rack/` directory and adapt `build.py`/`render.py` for the new geometry.
