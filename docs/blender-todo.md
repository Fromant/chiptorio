# Chiptorio — Blender Asset TODO

This document tracks every sprite/icon/asset in the mod that would benefit
from being created in Blender. Currently:

- **`server-rack`** is the only entity with Blender-rendered directional art
  (`graphics/entity/server-rack/`), produced by `tools/graphics/blender/`.
- All other entity sprites are hand-drawn rosy-42 style PNGs from
  `tools/make-entities.ps1`.
- All icons and technology icons are hand-drawn 64x64 / 256x256 PNGs.

Priority: P0 = blocks gameplay clarity, P1 = improves polish, P2 = nice-to-have.

---

## P0 — Entity World Sprites (blocking / used in-game)

These entities currently use hand-drawn `make-entities.ps1` sprites. Converting
them to Blender gives consistent lighting, directional animation, and proper
3D presence.

| # | Entity | Current Art | Visual Idea | Blender Params |
|---|--------|-------------|-------------|----------------|
| P0.1 | `analytical-engine` | `graphics/entity/analytical-frame.png` | Victorian brass computer with gears, crank, card reader slot, punch card output tray. Copper/brass materials, steam puffs optional. | Footprint 3x3, size 160px, 4 directions, idle + working animation (gears turning, crank rotating), shadow cast screen-right |
| P0.2 | `tube-mainframe` | `graphics/entity/tube-mainframe.png` | Rack of vacuum tubes with orange glowing filaments, heat haze at top, metal chassis. Glass tubes, orange emission, metal panels. | Footprint 2x2, size 128px, 4 directions, subtle flicker animation on tubes |
| P0.3 | `mainframe-cluster` | `graphics/entity/mainframe-cluster.png` | Rack with module cards, green PCBs with gold contacts, status lights row. Rack unit style, blinking LEDs. | Footprint 2x2, size 128px, 4 directions, blinking status light animation |
| P0.4 | `datacenter-lab` | `graphics/entity/datacenter-lab.png` | White/silver chassis, cooling pipes front and back, dual screens. Clean lab aesthetic, cool blue accents. | Footprint 2x2, size 128px, 4 directions |
| P0.5 | `cryostat` | `graphics/entity/cryostat.png` | Cryogenic lab, dewar flask, quantum core glow, frost patterns on corners. Silver/white, blue core emission, frost texture. | Footprint 2x2, size 128px, 4 directions, subtle core pulse animation |
| P0.6 | `metrology-lab` | `graphics/entity/metrology-lab.png` | Bench with microscope (left), wafer stage (center), status bar (right). Clean workshop aesthetic. | Footprint 3x3, size 160px, 4 directions |
| P0.7 | `answer-engine` | `graphics/entity/answer-engine.png` | Large 5x5 block, quantum accents, "42" screen, corner towers, top quantum core glow. Imposing endgame machine. | Footprint 5x5, size 240px, 4 directions, screen animation showing "42" and computation text |
| P0.8 | `qln-storage-drive` | `graphics/entity/qln-storage-drive.png` | Rack-mount drive with 4 slots, capacity bar, side rails. Server rack style, drive activity LEDs. | Footprint 2x2, size 128px, 4 directions, drive activity light animation |
| P0.9 | `quantum-entanglement-core` | `graphics/entity/quantum-entanglement-core.png` | Two purple cores linked by magenta arc. Hovering cores, energy arc between them. | Footprint 2x2, size 128px, 4 directions, arc pulse animation, core rotation |
| P0.10 | `construction-core` | `graphics/entity/construction-core.png` | Accumulator shell with arm icon, charge bars on right. Industrial battery aesthetic. | Footprint 3x3, size 160px, 4 directions, charge bar fill animation |
| P0.11 | `foup-dock` | `graphics/entity/foup-dock.png` | Container body with top carrier, mode indicator (red/green). FOUP carrier on top, seal/unseal mode. | Footprint 2x2, size 128px, 4 directions, carrier lift animation |
| P0.12 | `wireless-access-point` | `graphics/entity/wireless-access-point.png` | Flat panel with center antenna, broadcast arcs. Wi-Fi router aesthetic. | Footprint 2x2, size 128px, 4 directions, broadcast arc animation |
| P0.13 | `qln-import-node` | `graphics/entity/qln-import-node.png` | Box with IN arrow, cyan flow inside. Data ingress node. | Footprint 2x2, size 128px, 4 directions, flow animation |
| P0.14 | `qln-export-node` | `graphics/entity/qln-export-node.png` | Box with OUT arrow, cyan flow inside. Data egress node. | Footprint 2x2, size 128px, 4 directions, flow animation |
| P0.15 | `qln-provider-node` | `graphics/entity/qln-provider-node.png` | Disk with supply icon, outgoing arcs. QLN storage provider. | Footprint 2x2, size 128px, 4 directions, arc pulse |
| P0.16 | `qln-requester-node` | `graphics/entity/qln-requester-node.png` | Disk with request icon, incoming arcs. QLN storage requester. | Footprint 2x2, size 128px, 4 directions, arc pulse |
| P0.17 | `qln-terminal` | `graphics/entity/qln-terminal.png` | Kiosk with tilted screen, keyboard tray, card reader. Terminal aesthetic. | Footprint 2x2, size 128px, 4 directions, screen text animation |
| P0.18 | `training-cluster` | (uses hand-drawn sprite from make-entities?) | AI training rack, server blades, blinking lights. | Footprint 2x2, size 128px, 4 directions |
| P0.19 | `inference-lab` | (uses hand-drawn sprite) | AI inference lab, neural network visualisation, processing units. | Footprint 3x3, size 160px, 4 directions |

---

## P1 — Entity World Sprites (polish)

| # | Entity | Current Art | Visual Idea | Blender Params |
|---|--------|-------------|-------------|----------------|
| P1.1 | `wafer-fab` | `graphics/entity/wafer-fab.png` | 7x7 cleanroom with fluid pipes, load port, status screen, wafer cassette. | Footprint 7x7, size 320px, 4 directions, fluid pipe animation |
| P1.2 | `crystal-puller` | `graphics/entity/crystal-puller.png` | 5x5 furnace with crystal cylinder, melt pool, top heater ring. | Footprint 5x5, size 240px, 4 directions, crystal rotation, heat glow |
| P1.3 | `assembly-fab` | `graphics/entity/assembly-fab.png` | 5x5 packaging line with chip pattern, I/O ports, top spool. | Footprint 5x5, size 240px, 4 directions, spool rotation |
| P1.4 | `circuit-assembler` | `graphics/entity/circuit-assembler.png` | 3x3 bench with screen, component tray. | Footprint 3x3, size 160px, 4 directions |
| P1.5 | `computer-assembler` | `graphics/entity/computer-assembler.png` | 3x3 bench with blue screen, circuit lid. | Footprint 3x3, size 160px, 4 directions |
| P1.6 | `vlsi-fab` | `graphics/entity/vlsi-fab.png` | 7x7 massive plant with coolant pipes, mask-loader port. | Footprint 7x7, size 320px, 4 directions |
| P1.7 | `cooling-tower` | `graphics/entity/cooling-tower.png` | 5x5 tower with top fan, vapor plumes, pipe inlets. | Footprint 5x5, size 240px, 4 directions, fan rotation, vapor animation |
| P1.8 | `quantum-fab` | `graphics/entity/quantum-fab.png` | 7x7 cryogenic plant with frost patterns, dilution refrigerator. | Footprint 7x7, size 320px, 4 directions, frost animation |
| P1.9 | `network-switch` | `graphics/entity/network-switch.png` | 2x2 box chassis with 4-sided ports, green LEDs, top status display. | Footprint 2x2, size 128px, 4 directions, port LED blink |
| P1.10 | `network-router` | `graphics/entity/network-router.png` | 2x2 box with two antennas, signal arcs. | Footprint 2x2, size 128px, 4 directions, signal arc pulse |
| P1.11 | `network-monitor` | `graphics/entity/network-monitor.png` | 2x2 kiosk with tilted screen, status LEDs. | Footprint 2x2, size 128px, 4 directions, screen content change |

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