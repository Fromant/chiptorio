# Chiptorio — Sprite Prompts for Texel Studio

Generate every sprite below at **64×64 native resolution** with transparency. Use the project palette:

| Name | Hex | Role |
|------|-----|------|
| Ink | `#0C1116` | Outlines, deep shadows, vacuum tubes |
| Panel | `#1A2430` | Chassis, casings, dark metal |
| Line | `#33475A` | Traces, PCB lines, panel details |
| Cyan | `#45E0C0` | Cooling, liquid, HBM, quantum |
| Gold | `#E0B040` | Contacts, pins, gold plating |
| Red | `#E05555` | Heat, warnings, active power, errors |
| Green | `#4FBF6A` | Go, online, cold, success |
| Silver | `#B9C6D4` | Aluminum, bare metal, solder |
| Steel | `#7D8B99` | Structural metal, frames |
| Cream | `#E8DCC0` | Ceramic, old paper, light plastic |
| Brown | `#8A5A3A` | Wood, fiberboard, substrate |
| Purple | `#9A6EE0` | Magic/quantum, high voltage, exotic |
| Orange | `#E08A3A` | Heat sinks, warning amber, copper |

Style notes:
- **Entity world sprites: 64×64 native.** Drawn for a Factorio tile (32×32), but 64×64 gives detail at zoom. Slightly isometric, readable when zoomed out.
- **Item icons: 64×64.** Readable at inventory scale.
- **Technology icons: 256×256.** Detailed tech-screen icons.
- Save entity sprites to `graphics/entity/<filename>.png`.
- Save item icons to `graphics/icons/<filename>.png`.
- Save tech icons to `graphics/technology/<filename>.png`.

---

## Building Scale (important)

| Building | Tile Size | Notes |
|---|---|---|
| Network Cable | floor decal (no footprint) | Overlay draws connections |
| Network Switch | 2×2 | Box with ports on all 4 sides |
| Network Router | 2×2 | Box with antennas + ports |
| Network Monitor | 2×2 | Kiosk with tilted screen |
| Network Repeater | 1×1 | Inline box, cable left/right |
| Wireless Access Point | 2×2 | Panel + antenna |
| Circuit Assembler | 3×3 | Large bench, front panel |
| Computer Assembler | 3×3 | Large bench, blue screen |
| Server Rack | 2×2 | Rack with 4 bays |
| Memory Bank | 2×2 | Rack with memory slots |
| Datacenter | 3×3 | Large rack, cooling towers |
| Wafer Fab | 7×7 | MASSIVE cleanroom, fluid pipes |
| Crystal Puller | 5×5 | Tall furnace, crystal cylinder |
| Assembly Fab | 5×5 | Chip packaging line |
| VLSI Fab | 7×7 | VLSI plant, coolant pipes |
| Quantum Fab | 7×7 | Cryogenic, frost patterns |
| Cooling Tower | 5×5 | Fan on top, vapor plumes |
| Metrology Lab | 3×3 | Microscope + wafer stage |
| Construction Core | 3×3 | Accumulator shell + arm icon |
| FOUP Dock | 3×3 | Container + carrier on top |
| QLN Storage Drive | 2×2 | Rack-mount drive bays |
| QLN Terminal | 2×2 | Kiosk with screen |
| QLN Import/Export/Provider/Requester Node | 2×2 | Inline boxes with arrows |
| Answer Engine | 5×5 | The endgame machine |
| Labs (Analytical, Tube, Mainframe, Datacenter, Cryostat) | 2×2 | Computer mainframes |

---

## 1. Entity World Sprites (placeable buildings & nodes)

### Network (overlay connections, no physical port logic)

graphics/entity/network-cable.png - Floor decal for cable path. Thin vertical line 2px wide in Cyan (#45E0C0), running top to bottom center of 64×64 canvas. Small rounded connector caps at top and bottom edges in Silver (#B9C6D4). Transparent background. Overlay draws connection lines between cables/devices.

graphics/entity/network-switch.png - 2×2 switch on 64×64 canvas (centered in the tile footprint). Box chassis in Panel (#1A2430) with Steel (#7D8B99) frame. Four sides each have 2 circular port recesses in Ink (#0C1116) with Green (#4FBF6A) LED dots above. Top edge has status display in Cyan (#45E0C0). Reads as a real switch with physical ports.

graphics/entity/network-router.png - 2×2 router. Similar to switch but taller. Box chassis in Panel (#1A2430). Four sides have ports. Two antenna rods on top in Steel (#7D8B99). Signal wave arcs in Cyan (#45E0C0), thin concentric arcs emanating from top.

graphics/entity/network-monitor.png - 2×2 monitor kiosk. Screen tilted up at ~45°, screen face in Ink (#0C1116) with Cyan (#45E0C0) grid pattern. Stand in Steel (#7D8B99). Status LEDs below: Red (#E05555) left, Green (#4FBF6A) right.

graphics/entity/network-repeater.png - 1×1 inline repeater. Small box in Panel (#1A2430), cable enters left and right edges. Center has glowing Green (#4FBF6A) status light. Signal arc above in Cyan (#45E0C0).

graphics/entity/wireless-access-point.png - 2×2 AP. Flat square mounting panel in Panel (#1A2430). Antenna rod in center top in Steel (#7D8B99). Signal broadcast arcs in Cyan (#45E0C0), thin concentric semicircles.

### Compute Providers & Labs

graphics/entity/server-rack.png - 2×2 rack. Chassis in Panel (#1A2430). Four horizontal server bays, each with dark screen and blinking LEDs (Red/Green). Right side cable management. Top vents. Cable enters bottom center.

graphics/entity/memory-bank.png - 2×2 memory bank. Chassis in Panel (#1A2430). Four vertical memory module slots on front, Silver (#B9C6D4) sticks with Gold (#E0B040) contacts. Status LEDs above each slot.

graphics/entity/datacenter.png - 3×3 datacenter. Large rack chassis in Panel (#1A2430), taller. Eight horizontal bays with screens and LEDs. Top has two fan grilles (Steel #7D8B99 circles). Right side coolant pipe inlet in Cyan (#45E0C0).

graphics/entity/analytical-engine.png - 2×2 mechanical computer. Brass/Copper (#E08A3A) chassis with gears. Front card reader slot (dark recess), output tray. Side crank handle in Steel (#7D8B99). Reads as Victorian computer.

graphics/entity/tube-mainframe.png - 2×2 tube mainframe. Rack in Panel (#1A2430) filled with vacuum tubes — vertical Glass cylinders with Orange (#E08A3A) filaments glowing. Heat haze at top.

graphics/entity/mainframe-cluster.png - 2×2 mainframe cluster. Rack in Panel (#1A2430) with module cards — Green (#4FBF6A) PCBs with Gold (#E0B040) contacts. Blinking status lights row.

graphics/entity/datacenter-lab.png - 2×2 datacenter lab. White/Silver (#B9C6D4) chassis with cooling pipes (Cyan #45E0C0). Front research screens.

graphics/entity/cryostat.png - 2×2 cryostat. Cryogenic lab in White/Silver (#B9C6D4) with frost patterns. Front dewar flask — Silver cylinder with Cyan (#45E0C0) liquid. Quantum core glow inside.

### Fabs (BIG)

graphics/entity/wafer-fab.png - 7×7 cleanroom fab. Large building in Panel (#1A2430). Fluid input pipes on left (Cyan #45E0C0 visible). Front load port (dark recess) and status screen (Ink #0C1116 with Cyan text). Side wafer cassette graphic (stack of Silver circles). Cleanroom curtains/strip doors at front. Reads as massive industrial cleanroom.

graphics/entity/crystal-puller.png - 5×5 crystal puller. Furnace body in Steel (#7D8B99) with heat glow (Orange #E08A3A) at bottom. Center vertical cylinder (crystal ingot) in Silver (#B9C6D4) pulling from melt pool (Ink #0C1116 with Orange rim). Top heater ring in Red (#E05555). Tall, furnace-like.

graphics/entity/assembly-fab.png - 5×5 assembly fab. AM3-style chassis but larger. Side panel chip-pattern (grid of Gold #E0B040 squares on Ink #0C1116). Front input/output ports. Top spool of wire (Silver #B9C6D4). Reads as chip packaging line.

graphics/entity/vlsi-fab.png - 7×7 VLSI fab. Chemical-plant style but massive. Coolant pipes in Cyan (#45E0C0) running along sides. Front mask-loader port (dark recess). Status screen showing process steps. Industrial scale.

graphics/entity/quantum-fab.png - 7×7 quantum fab. Cryogenic machine in White/Silver (#B9C6D4) with frost patterns (pale Cyan #45E0C0). Front dilution-refrigerator cylinder stack. Top quantum wiring (thin Gold #E0B040 lines). Reads as cryogenic quantum fab.

graphics/entity/cooling-tower.png - 5×5 cooling tower. Tower body in Steel (#7D8B99). Top fan grille (Steel circle with blades). Water vapor rising (Cyan #45E0C0 translucent plumes). Pipe inlets at bottom (Cyan fluid).

### QLN & Construction

graphics/entity/metrology-lab.png - 3×3 metrology lab. Bench in Cream (#E8DCC0). Microscope on left (Steel #7D8B99). Wafer under analysis on center stage (Silver circle with test pattern in Ink #0C1116). Status bar on right (Green/Red segments).

graphics/entity/construction-core.png - 3×3 construction core. Cylindrical accumulator shell in Steel (#7D8B99). Construction-arm icon on front (Gold #E0B040 crane silhouette). Battery charge bars on right (Green #4FBF6A fill).

graphics/entity/foup-dock.png - 3×3 FOUP dock. Container in Panel (#1A2430) with front access door (dark recess). Top sealed carrier graphic (Silver cylinder with Gold caps). Mode indicator: Red (#E05555) seal, Green (#4FBF6A) unseal.

graphics/entity/qln-storage-drive.png - 2×2 storage drive. Rack-mount drive in Panel (#1A2430). Four front slots with module stick graphics (Silver + Gold contacts). Capacity bar at bottom (Cyan #45E0C0 fill).

graphics/entity/qln-terminal.png - 2×2 terminal kiosk. Stand in Steel (#7D8B99). Screen tilted up showing item list (Ink #0C1116 with Silver #B9C6D4 text lines). Keyboard tray below. Card reader slot on right.

graphics/entity/qln-import-node.png - 2×2 import node. Box in Panel (#1A2430). Arrow pointing IN from left (Green #4FBF6A). Chest front small dark recess.

graphics/entity/qln-export-node.png - 2×2 export node. Box in Panel (#1A2430). Arrow pointing OUT to right (Red #E05555). Chest front.

graphics/entity/qln-provider-node.png - 2×2 provider node. Box in Panel (#1A2430). Outgoing signal arcs on right (Cyan #45E0C0). Supply icon (Gold #E0B040 box with plus).

graphics/entity/qln-requester-node.png - 2×2 requester node. Box in Panel (#1A2430). Incoming signal arcs on left (Cyan #45E0C0). Request icon (Ink #0C1116 box with minus).

graphics/entity/answer-engine.png - 5×5 Answer Engine. Large block in Panel (#1A2430) with Quantum accents (Purple #9A6EE0). Front central screen (Ink #0C1116 with Gold #E0B040 "42" glyph). Four corner towers with cooling fins (Steel #7D8B99). Top quantum core glow (Cyan #45E0C0 pulsing center).

---

## 2. Item Icons (inventory, 64×64)

Same as before — all chips, boards, computers, AI models, FOUP, silicon materials, memory modules, science packs, node items at 64×64 native (not upscaled from 16×16):

graphics/icons/vacuum-tube.png - Glass tube, filament glowing Orange, Silver base pins
graphics/icons/discrete-transistor.png - Black body, 3 Silver leads, Red band
graphics/icons/integrated-circuit.png - Black square chip, Gold pins all sides, dot at pin 1
graphics/icons/microprocessor.png - Larger chip, Silver heat spreader center, Gold pins
graphics/icons/system-on-chip.png - Chip with colored block squares (Cyan/Green/Red)
graphics/icons/multi-core-cpu.png - Chip with 4 core squares in Silver on Ink substrate
graphics/icons/gpu.png - Chip with memory stack (tall Silver rectangles) beside it
graphics/icons/neural-processor.png - Chip with 3x3 tensor grid in Purple accents
graphics/icons/quantum-processor.png - Silver chip with qubit ring (5 Cyan dots)

graphics/icons/electronic-circuit.png - Control Board: Brown fiberglass, Copper traces, 2 tube cylinders
graphics/icons/advanced-circuit.png - Advanced Control Board: dark green PCB, SMD chips
graphics/icons/processing-unit.png - Compute Board: dark blue PCB, microprocessor square
graphics/icons/accelerator-board.png - Accelerator Board: black PCB, GPU chip, HBM stack, Cyan accents
graphics/icons/neural-board.png - Neural Board: Purple PCB, NPU chip, tensor grid, Silver traces
graphics/icons/quantum-board.png - Quantum Board: Silver PCB, QPU chip, cryogenic wiring lines

graphics/icons/microcomputer.png - Green PCB card, chip, 2 RAM sticks, Gold edge connector
graphics/icons/server.png - Black PCB, chip, 4 RAM sticks, heatsink
graphics/icons/supercomputer.png - Black PCB, GPU chip, HBM stack, heat pipes
graphics/icons/neural-computer.png - Purple accents, NPU chip, tensor grid, Cyan traces
graphics/icons/quantum-computer.png - Silver card, QPU chip, qubit circle, dilution wires

graphics/icons/small-model.png - Silver disk with Cyan AI circuit trace
graphics/icons/specialist-model.png - Disk with 3 domain slices, AI trace
graphics/icons/general-model.png - Disk with neural nodes connected by lines
graphics/icons/frontier-model.png - Disk with Cyan quantum nodes, AI trace
graphics/icons/agi-model.png - Disk with Gold glowing center, AI trace radiating

graphics/icons/foup.png - Sealed carrier cylinder, Silver, Gold end caps, top handle

graphics/icons/silica.png - Tan grain pile (Cream + Brown specks)
graphics/icons/metallurgical-silicon.png - Dark silicon chunk with Silver sparkles
graphics/icons/polysilicon.png - Silicon rod with crystal grain lines
graphics/icons/monocrystalline-ingot.png - Crystal cylinder, flat end with Gold X lattice
graphics/icons/silicon-wafer.png - Round Silver wafer circle with flat notch
graphics/icons/litho-mask.png - Quartz square with Chrome circuit lines
graphics/icons/bare-die.png - Small Silver square die with Gold bond pad dots

graphics/icons/sram-module.png - Memory stick, 1 chip square, Silver + Gold
graphics/icons/dram-module.png - Memory stick, 2 chip squares
graphics/icons/sdram-module.png - Memory stick, 3 chip squares
graphics/icons/ddr-module.png - Memory stick, 4 chip squares
graphics/icons/ddr2-module.png - Memory stick, 5 chip squares
graphics/icons/ddr3-module.png - Memory stick, 6 chip squares
graphics/icons/ddr4-module.png - Memory stick, 7 chip squares
graphics/icons/ddr5-module.png - Memory stick, 8 chip squares
graphics/icons/hbm-module.png - Memory stick with tall stacked dies
graphics/icons/hbm3-module.png - HBM with taller stack, Cyan accents
graphics/icons/3d-nand-module.png - Memory stick with vertical stack layers (horizontal lines)

graphics/icons/optical-disc.png - Silver disc with Ink data spiral
graphics/icons/hbm-science.png - Bonded memory dies in science pack border
graphics/icons/qubit-array.png - Qubit chip circle with control lines in science pack border

graphics/icons/circuit-assembler.png - Mini workbench with screen and component tray
graphics/icons/computer-assembler.png - Mini bench with blue screen and circuit lid
graphics/icons/training-cluster.png - Mini rack with 3 bays and blinking LEDs
graphics/icons/inference-lab.png - Mini workstation with monitor and flask

---

## 3. Technology Icons (256×256)

graphics/technology/electromechanics.png - Copper gears meshing, relay contacts, Ink background panel with border
graphics/technology/thermionics.png - Large glass vacuum tube with glowing Orange filament
graphics/technology/semiconductor-physics.png - Silicon crystal growing from Orange melt pool
graphics/technology/crystal-growth.png - Crystal cylinder being pulled from furnace with heat glow
graphics/technology/photolithography.png - Mask over wafer with Cyan light beam projecting down
graphics/technology/planar-process.png - Silicon layer cross-section with Cyan oxide layer
graphics/technology/microarchitecture.png - Chip die with Gold block diagram rectangles
graphics/technology/internet.png - Globe with network nodes connected by Cyan lines
graphics/technology/vlsi-process.png - Wafer with grid of Gold dies, Cyan process lines
graphics/technology/datacenter.png - Rack with 8 servers, cooling fans, network cable
graphics/technology/advanced-packaging.png - Chip on interposer board with Gold solder bumps
graphics/technology/heterogeneous-compute.png - CPU + GPU + NPU connected by Cyan bus lines
graphics/technology/quantum-computing.png - Qubit circle in dilution fridge cylinder
graphics/technology/quantum-error-correction.png - 9 physical qubits around 1 logical Cyan qubit
graphics/technology/quantum-advantage.png - QPU chip outperforming classical chip with Cyan speed lines
graphics/technology/qln.png - Storage nodes connected by Cyan lines, storage drive at center
graphics/technology/qln-quantum.png - Two storage groups linked by Purple entanglement arc
graphics/technology/machine-learning.png - Neural network nodes, Green training arrow to model disk
graphics/technology/ai-specialist.png - Model disk with 3 domain slices, NPU chip beside
graphics/technology/ai-general.png - Model disk with neural nodes, Purple tensor chip beside
graphics/technology/ai-frontier.png - Model disk with Cyan quantum nodes, QPU chip beside
graphics/technology/artificial-general-intelligence.png - AGI disk with Gold core, all 5 model tiers in ring
graphics/technology/the-question.png - Large Gold "42" glyph, compute bars below in 4 colors

---

## 4. Node Items (mask/wafer/die for each node, 64×64)

Node icons follow the pattern: mask = reticle with Chrome pattern, wafer = Silver circle, die = Silver square with bond pads. Refinement badges: small Cyan checkmark in corner.

10 µm: contact lithography, thick pattern, 50mm wafer, large PMOS die
3 µm: projection reticle, 100mm wafer, CMOS die
1 µm: i-line reticle, 150mm wafer, CMOS die
350 nm: KrF DUV phase-shift mask (Cyan areas), 200mm wafer, BGA die
180 nm: KrF DUV mask, 200mm wafer, flip-chip die
90 nm: ArF DUV immersion mask, 300mm wafer, strained silicon die
45 nm: high-k/metal gate mask (Purple tint), 300mm wafer, high-k die
22 nm: multi-patterning mask, 300mm wafer, FinFET die
14 nm: multi-patterning mask refined, 300mm wafer, FinFET die
7 nm: EUV mask, 300mm wafer, FinFET die
3 nm: EUV mask with GAA marks, 300mm wafer, GAA nanowire die
1-4 nm: high-NA EUV mask, 300mm wafer, CFET stacked nanosheet die

Half-node refinement icons: same as parent node die/wafer but with small Cyan refinement badge.

---

## Integration Notes

- Entity sprites: 64×64 PNGs with transparency, assigned via `entity.picture` or a new `M.set_custom_sprite()` helper in `scripts/util.lua`
- Item icons: 64×64 PNGs with transparency, referenced by `M.set_icon()` in data stage
- Technology icons: 256×256 PNGs, assigned via technology `icons` field
- All paths relative to `graphics/` in mod root, referenced as `__chiptorio__/graphics/...`

Generate them one at a time in Texel Studio, then push the `graphics/` folder back here for integration into entity definitions.
