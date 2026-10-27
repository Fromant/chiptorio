# Chiptorio — Sprite Prompts for Texel Studio

Generate every sprite below at the resolution noted. Use the project palette:

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
- Icons: 16×16 base, upscaled 4× to 64×64 nearest-neighbour. Chunky, readable at inventory scale.
- Entities: 64×64 world sprites, drawn for a 32×32 Factorio tile. Slightly isometric, readable when zoomed out.
- Technology icons: 256×256, detailed but still readable as a tech-screen icon.

Save all entity sprites to `graphics/entity/<filename>.png`.
Save all item icons to `graphics/icons/<filename>.png`.
Save all tech icons to `graphics/technology/<filename>.png`.

---

## 1. Entity World Sprites (placeable buildings & nodes)

graphics/entity/network-cable.png - A thin floor cable sprite for a 1x1 Factorio tile. Draw a single straight vertical line, 2 pixels wide, in Cyan (#45E0C0), running top to bottom center of a 64x64 canvas. Add small rounded connector caps at top and bottom edges in Silver (#B9C6D4). Transparent background. This tiles vertically and horizontally to form cable runs.

graphics/entity/network-switch.png - A 1x1 networking switch on a 64x64 canvas. Box chassis in Panel (#1A2430) with Steel (#7D8B99) frame. Front face has 5 circular port recesses in Ink (#0C1116), each with a tiny Green (#4FBF6A) LED dot above it. Top edge has a small status display rectangle in Cyan (#45E0C0). Cable enters from bottom center. No wooden-chest look — reads as a network device.

graphics/entity/network-router.png - A 1x1 router on a 64x64 canvas. Similar to switch but taller. Box chassis in Panel (#1A2430). Front has 4 ports in a row. Two antenna rods on top in Steel (#7D8B99), thin vertical lines extending above the box. Signal wave arcs on right side in Cyan (#45E0C0), thin concentric arcs. Cable enters from bottom center.

graphics/entity/network-monitor.png - A 1x1 monitor kiosk on a 64x64 canvas. Screen tilted up at ~45 degrees, screen face in Ink (#0C1116) with a Cyan (#45E0C0) grid pattern. Stand in Steel (#7D8B99). Small status LEDs below screen: Red (#E05555) left, Green (#4FBF6A) right. Reads as a display terminal.

graphics/entity/network-repeater.png - A 1x1 inline repeater on a 64x64 canvas. Small inline box in Panel (#1A2430), wider than tall. Cable enters left and right edges. Center has a single glowing Green (#4FBF6A) status light. Signal arc above in Cyan (#45E0C0), thin. Reads as a signal booster between cable runs.

graphics/entity/wireless-access-point.png - A 1x1 wireless AP on a 64x64 canvas. Flat square mounting panel in Panel (#1A2430). Single antenna rod in center top in Steel (#7D8B99). Signal broadcast arcs emanating from antenna in Cyan (#45E0C0), thin concentric semicircles. Cable enters bottom center. Wall-mountable look.

graphics/entity/circuit-assembler.png - A 1x1 board assembly bench on a 64x64 canvas. Beige/tan workbench surface in Cream (#E8DCC0). Back panel in Panel (#1A2430) with a small screen showing cyan scanlines (Cyan #45E0C0 lines on Ink #0C1116). Left side has a parts tray with Copper (#E08A3A) traces. Right side has a component picker arm in Steel (#7D8B99). Reads as a circuit-board assembly station, not a factory assembler.

graphics/entity/computer-assembler.png - A 1x1 computer assembly bench on a 64x64 canvas. Same chassis as circuit-assembler but screen is Blue (#45E0C0 tinted darker) instead of cyan. Lid has a circuit-board etched pattern in Line (#33475A). Extra antenna nub on top right. Reads as a computer-module assembly station.

graphics/entity/training-cluster.png - A rack-mount training cluster on a 64x64 canvas. Rack unit in Panel (#1A2430) with perforated metal front in Steel (#7D8B99). Three vertical bays, each with a small screen (Ink #0C1116) and indicator row (Red/Green/Yellow dots). Cable management arm at back right in Steel. Cable enters bottom center. Reads as a server-training rack.

graphics/entity/inference-lab.png - A 1x1 inference lab workstation on a 64x64 canvas. Lab bench in Cream (#E8DCC0). Monitor on left (dark screen with Cyan text lines). Glowing flask on right (Cyan #45E0C0 liquid in Glass shape). Chip under glass cloche in center (Silver #B9C6D4 with Gold #E0B040 pins). Keyboard tray below. Reads as an AI inference workstation.

graphics/entity/server-rack.png - A 1x1 server rack provider on a 64x64 canvas. Rack chassis in Panel (#1A2430). Four horizontal server bays, each with a dark screen and blinking LEDs (Red/Green). Right side has cable management. Top has vents. Cable enters bottom center. Reads as a compute provider rack.

graphics/entity/memory-bank.png - A 1x1 memory bank on a 64x64 canvas. Rack chassis in Panel (#1A2430). Four vertical memory module slots on front, each showing a stick in Silver (#B9C6D4) with Gold (#E0B040) contacts. Status LEDs above each slot. Cable enters bottom center. Reads as a memory provider.

graphics/entity/datacenter.png - A 1x1 datacenter on a 64x64 canvas. Large rack chassis in Panel (#1A2430), taller than server-rack. Eight horizontal bays with screens and LEDs. Built-in cooling: two fan grilles on top (Steel #7D8B99 circles). Right side has coolant pipe inlet in Cyan (#45E0C0). Cable enters bottom center. Reads as a large compute provider with cooling.

graphics/entity/wafer-fab.png - A 1x1 wafer fabrication cleanroom on a 64x64 canvas. Machine in Panel (#1A2430) with fluid input pipe on left (Cyan #45E0C0 fluid visible). Front has a load port (dark recess) and a status screen (Ink #0C1116 with Cyan text). Side has a wafer cassette graphic (stack of Silver circles). Reads as a cleanroom fab.

graphics/entity/crystal-puller.png - A 1x1 crystal puller furnace on a 64x64 canvas. Furnace body in Steel (#7D8B99) with heat glow (Orange #E08A3A) at bottom. Center vertical cylinder (crystal ingot) in Silver (#B9C6D4) pulling up from a melt pool (Ink #0C1116 with Orange rim). Top has a heater ring in Red (#E05555). Reads as a crystal growth furnace.

graphics/entity/assembly-fab.png - A 1x1 assembly fab on a 64x64 canvas. AM3-style assembler chassis but with chip-pattern side panel (Grid of Gold #E0B040 squares on Ink #0C1116). Front has input/output ports. Top has a spool of wire (Silver #B9C6D4). Cable enters bottom center. Reads as a chip-packaging assembler.

graphics/entity/vlsi-fab.png - A 1x1 VLSI fab on a 64x64 canvas. Chemical-plant style chassis in Panel (#1A2430). Coolant pipes in Cyan (#45E0C0) running along sides. Front has a mask-loader port (dark recess). Status screen shows process steps. Reads as a VLSI fabrication plant.

graphics/entity/quantum-fab.png - A 1x1 quantum fab on a 64x64 canvas. Cryogenic machine in White/Silver (#B9C6D4) with frost patterns (Light Cyan #45E0C0 pale). Front has a dilution-refrigerator cylinder stack. Top has quantum wiring (thin Gold #E0B040 lines). Reads as a cryogenic quantum fab.

graphics/entity/cooling-tower.png - A 1x1 cooling tower on a 64x64 canvas. Tower body in Steel (#7D8B99). Top has a fan grille (Steel circle with blades). Water vapor rising from top (Cyan #45E0C0 translucent plumes). Pipe inlets at bottom (Cyan fluid). Reads as a cooling tower.

graphics/entity/metrology-lab.png - A 1x1 metrology lab on a 64x64 canvas. Lab bench in Cream (#E8DCC0). Microscope on left (Steel #7D8B99). Wafer under analysis on center stage (Silver circle with test pattern in Ink #0C1116). Status bar on right (Green/Red segments). Cable enters bottom center. Reads as a metrology analysis lab.

graphics/entity/construction-core.png - A 1x1 construction core on a 64x64 canvas. Accumulator-style shell (cylindrical) in Steel (#7D8B99) with a construction-arm icon on front (Gold #E0B040 crane silhouette). Battery charge level shown as horizontal bars on right side (Green #4FBF6A fill). Cable enters bottom center. Reads as a construction accumulator.

graphics/entity/foup-dock.png - A 1x1 FOUP dock container on a 64x64 canvas. Container in Panel (#1A2430) with front access door (dark recess). Top has a sealed carrier graphic (Silver cylinder with Gold caps). Mode indicator: Red (#E05555) for seal, Green (#4FBF6A) for unseal. Cable enters bottom center. Reads as a FOUP sealing dock.

graphics/entity/qln-storage-drive.png - A 1x1 QLN storage drive on a 64x64 canvas. Rack-mount drive in Panel (#1A2430). Four front slots with module stick graphics (Silver #B9C6D4 + Gold #E0B040 contacts). Capacity bar at bottom (Cyan #45E0C0 fill). Cable enters bottom center.

graphics/entity/qln-terminal.png - A 1x1 QLN terminal kiosk on a 64x64 canvas. Kiosk stand in Steel (#7D8B99). Screen tilted up showing item list (Ink #0C1116 with Silver #B9C6D4 text lines). Keyboard tray below. Card reader slot on right. Cable enters bottom center.

graphics/entity/qln-import-node.png - A 1x1 QLN import node on a 64x64 canvas. Small inline box in Panel (#1A2430). Arrow pointing IN from left edge (Green #4FBF6A). Inserter-compatible chest front (small dark recess). Cable enters bottom center. Reads as an item import point.

graphics/entity/qln-export-node.png - A 1x1 QLN export node on a 64x64 canvas. Small inline box in Panel (#1A2430). Arrow pointing OUT to right edge (Red #E05555). Chest front. Cable enters bottom center. Reads as an item export point.

graphics/entity/qln-provider-node.png - A 1x1 QLN provider node on a 64x64 canvas. Small box in Panel (#1A2430). Outgoing signal arcs on right (Cyan #45E0C0). Supply icon (Gold #E0B040 box with plus) on front. Cable enters bottom center.

graphics/entity/qln-requester-node.png - A 1x1 QLN requester node on a 64x64 canvas. Small box in Panel (#1A2430). Incoming signal arcs on left (Cyan #45E0C0). Request icon (Ink #0C1116 box with minus) on front. Cable enters bottom center.

graphics/entity/answer-engine.png - A 5x5 Answer Engine on a 64x64 canvas. Large machine block in Panel (#1A2430) with Quantum accents (Purple #9A6EE0). Front has a large central screen (Ink #0C1116 with Gold #E0B040 "42" glyph). Four corner towers with cooling fins (Steel #7D8B99). Top has a quantum core glow (Cyan #45E0C0 pulsing center). Reads as the endgame machine.

graphics/entity/analytical-engine.png - A 1x1 analytical engine on a 64x64 canvas. Mechanical computer in Brass/Copper (#E08A3A) with gears. Front has a card reader slot (dark recess) and output tray. Side has a crank handle (Steel #7D8B99). Reads as a Victorian mechanical computer.

graphics/entity/tube-mainframe.png - A 1x1 tube mainframe on a 64x64 canvas. Rack in Panel (#1A2430) filled with vacuum tubes (vertical Glass cylinders with Orange #E08A3A filaments glowing). Heat haze at top. Cable enters bottom center. Reads as a tube-era computer.

graphics/entity/mainframe-cluster.png - A 1x1 mainframe cluster on a 64x64 canvas. Rack in Panel (#1A2430) with module cards (Green #4FBF6A PCBs with Gold #E0B040 contacts). Blinking status lights row. Cable enters bottom center. Reads as a transistor-era computer.

graphics/entity/datacenter-lab.png - A 1x1 datacenter lab on a 64x64 canvas. Lab version of datacenter: White/Silver (#B9C6D4) chassis with cooling pipes (Cyan #45E0C0). Front has research screens. Cable enters bottom center. Reads as a post-internet lab client.

graphics/entity/cryostat.png - A 1x1 cryostat on a 64x64 canvas. Cryogenic lab in White/Silver (#B9C6D4) with frost patterns. Front has a dewar flask (Silver cylinder with Cyan #45E0C0 liquid). Quantum core glow inside. Cable enters bottom center. Reads as a quantum lab client.

---

## 2. Item Icons (inventory, 64×64 generated from 16×16)

graphics/icons/vacuum-tube.png - Glass vacuum tube icon. Glass envelope in Cream (#E8DCC0 outline), filament inside in Orange (#E08A3A) glowing, base pins in Silver (#B9C6D4). 16x16 chunky.

graphics/icons/discrete-transistor.png - Discrete transistor icon. Black body in Ink (#0C1116), three leads in Silver (#B9C6D4), band in Red (#E05555). 16x16.

graphics/icons/integrated-circuit.png - IC chip icon. Black square chip in Ink (#0C1116), Gold (#E0B040) pins on all four sides, dot marking pin 1 in top-left. 16x16.

graphics/icons/microprocessor.png - Microprocessor icon. Larger square chip in Ink (#0C1116), Gold pins, heat spreader square in center Silver (#B9C6D4). 16x16.

graphics/icons/system-on-chip.png - SoC icon. Chip with multiple functional blocks shown as colored squares (Cyan/Green/Red small squares on chip surface). 16x16.

graphics/icons/multi-core-cpu.png - Multi-core CPU icon. Chip with four core squares visible in Silver (#B9C6D4) on black Ink (#0C1116) substrate. 16x16.

graphics/icons/gpu.png - GPU icon. Chip with memory stack beside it (tall Silver rectangles) and Gold pins. 16x16.

graphics/icons/neural-processor.png - NPU icon. Chip with tensor core grid pattern (3x3 small squares) in Purple (#9A6EE0) accents. 16x16.

graphics/icons/quantum-processor.png - QPU icon. Chip in Silver (#B9C6D4) with qubit circle pattern (5 dots in a ring) in Cyan (#45E0C0). 16x16.

graphics/icons/electronic-circuit.png - Control Board icon. Brown fiberglass board in Brown (#8A5A3A), Copper (#E08A3A) traces, vacuum tube cylinders (2 small Orange/Glass), through-hole components. 16x16.

graphics/icons/advanced-circuit.png - Advanced Control Board icon. Green PCB (#4FBF6A dark green), SMD chips (small black squares), discrete transistor rectangles. 16x16.

graphics/icons/processing-unit.png - Compute Board icon. Blue PCB (#45E0C0 dark), microprocessor square chip, capacitors (small cylinders). 16x16.

graphics/icons/accelerator-board.png - Accelerator Board icon. Black PCB, GPU chip square, HBM stack tall rectangles beside it, Cyan (#45E0C0) accents. 16x16.

graphics/icons/neural-board.png - Neural Board icon. Purple PCB (#9A6EE0 dark), NPU chip, tensor grid pattern, superconducting traces (Silver #B9C6D4). 16x16.

graphics/icons/quantum-board.png - Quantum Board icon. Silver/White PCB, QPU chip, cryogenic wiring thin lines, dilution plate pattern. 16x16.

graphics/icons/microcomputer.png - Microcomputer module icon. Green PCB card, single chip, two RAM sticks, Gold edge connector at bottom. 16x16.

graphics/icons/server.png - Server module icon. Black PCB, larger chip, four RAM sticks, heatsink rectangle on top. 16x16.

graphics/icons/supercomputer.png - Supercomputer module icon. Black PCB, GPU chip large, HBM stack tall, heatsink with heat pipes (lines). 16x16.

graphics/icons/neural-computer.png - Neural Computer module icon. Purple accents, NPU chip, tensor core grid, glowing traces (Cyan #45E0C0 lines). 16x16.

graphics/icons/quantum-computer.png - Quantum Computer module icon. Silver/White card, QPU chip, qubit array circle, dilution fridge wires (thin Silver lines). 16x16.

graphics/icons/small-model.png - Small Model icon. Small folded paper/disk in Silver (#B9C6D4) with AI circuit trace (Cyan #45E0C0 line). 16x16.

graphics/icons/specialist-model.png - Specialist Model icon. Disk with domain sector lines (3 slices in different colors), AI trace. 16x16.

graphics/icons/general-model.png - General Model icon. Disk with neural network nodes (3 dots connected by lines), AI trace. 16x16.

graphics/icons/frontier-model.png - Frontier Model icon. Disk with quantum nodes (Cyan dots) and AI trace. 16x16.

graphics/icons/agi-model.png - AGI Model icon. Disk with glowing core (Gold #E0B040 center) and AI trace radiating outward. 16x16.

graphics/icons/foup.png - FOUP carrier icon. Sealed wafer carrier cylinder in Silver (#B9C6D4), Gold (#E0B040) end caps, handle on top. 16x16.

graphics/icons/silica.png - Silica sand icon. Small pile of tan grains (Cream #E8DCC0 + Brown #8A5A3A specks). 16x16.

graphics/icons/metallurgical-silicon.png - Metallurgical silicon icon. Dark silicon chunk (Ink #0C1116) with Silver sparkles. 16x16.

graphics/icons/polysilicon.png - Polysilicon icon. Silicon rod (Silver #B9C6D4) with crystal grain lines. 16x16.

graphics/icons/monocrystalline-ingot.png - Crystal ingot icon. Cylindrical crystal in Silver (#B9C6D4) with flat end showing crystal lattice (Gold #E0B040 X pattern). 16x16.

graphics/icons/silicon-wafer.png - Silicon wafer icon. Round wafer (Silver #B9C6D4 circle) with flat edge notch, thin edge line. 16x16.

graphics/icons/litho-mask.png - Lithography mask icon. Quartz plate (Silver #B9C6D4 square) with Chrome pattern (Ink #0C1116 circuit lines). 16x16.

graphics/icons/bare-die.png - Bare die icon. Small square die (Silver #B9C6D4) with bond pads (Gold #E0B040 dots on corners). 16x16.

graphics/icons/sram-module.png - SRAM module icon. Small memory stick (Silver #B9C6D4) with Gold contacts, "SRAM" label implied by 1 chip square. 16x16.

graphics/icons/dram-module.png - DRAM module icon. Memory stick with 2 chip squares. 16x16.

graphics/icons/sdram-module.png - SDRAM module icon. Memory stick with 3 chip squares. 16x16.

graphics/icons/ddr-module.png - DDR module icon. Memory stick with 4 chip squares. 16x16.

graphics/icons/ddr2-module.png - DDR2 module icon. Memory stick with 5 chip squares. 16x16.

graphics/icons/ddr3-module.png - DDR3 module icon. Memory stick with 6 chip squares. 16x16.

graphics/icons/ddr4-module.png - DDR4 module icon. Memory stick with 7 chip squares. 16x16.

graphics/icons/ddr5-module.png - DDR5 module icon. Memory stick with 8 chip squares. 16x16.

graphics/icons/hbm-module.png - HBM module icon. Memory stick with stacked dies (tall rectangles) and Gold contacts. 16x16.

graphics/icons/hbm3-module.png - HBM3 module icon. HBM with taller stack, Cyan accents. 16x16.

graphics/icons/3d-nand-module.png - 3D NAND module icon. Memory stick with vertical 3D stack layers (horizontal lines on chips). 16x16.

graphics/icons/optical-disc.png - Optical disc icon. Disc (Silver #B9C6D4 circle) with data spiral (Ink #0C1116 spiral line). 16x16.

graphics/icons/hbm-science.png - HBM science icon. Bonded memory dies icon (stacked Silver rectangles) formatted as science pack (science pack border in Silver #B9C6D4). 16x16.

graphics/icons/qubit-array.png - Qubit array icon. Qubit chip (Silver circle) with control lines (Silver #B9C6D4 thin lines) in science pack border. 16x16.

graphics/icons/circuit-assembler.png - Circuit Assembler item icon. Mini version of entity sprite: workbench with screen and component tray. 16x16.

graphics/icons/computer-assembler.png - Computer Assembler item icon. Mini version: bench with blue screen and circuit pattern lid. 16x16.

graphics/icons/training-cluster.png - Training Cluster item icon. Mini rack with 3 bays and blinking LEDs. 16x16.

graphics/icons/inference-lab.png - Inference Lab item icon. Mini workstation with monitor and flask. 16x16.

---

## 3. Technology Icons (256×256)

graphics/technology/electromechanics.png - Relay and gears icon. Copper gears (Gold #E0B040) meshing, relay contacts (Silver #B9C6D4), Ink (#0C1116) background panel. Tech-screen icon style with border.

graphics/technology/thermionics.png - Vacuum tube icon. Large glass tube (Cream #E8DCC0) with glowing filament (Orange #E08A3A), pins at base. Dark background panel.

graphics/technology/semiconductor-physics.png - Crystal and silicon icon. Silicon crystal (Silver #B9C6D4) growing from melt (Orange #E08A3A pool), probe touching it. Dark panel background.

graphics/technology/crystal-growth.png - Crystal puller icon. Cylindrical crystal being pulled from furnace, heat glow around. Dark panel.

graphics/technology/photolithography.png - Mask and wafer icon. Lithography mask (Silver square with Ink pattern) over wafer (Silver circle), light beam (Cyan #45E0C0) projecting down. Dark panel.

graphics/technology/planar-process.png - Planar process icon. Cross-section of silicon layers (horizontal stripes Silver/Ink) with oxide layer (Cyan #45E0C0 thin). Dark panel.

graphics/technology/microarchitecture.png - CPU architecture icon. Chip die (Silver square) with block diagram (Gold #E0B040 rectangles connected by lines). Dark panel.

graphics/technology/internet.png - Network icon. Globe (Silver circle) with network nodes (dots) connected by lines (Cyan #45E0C0), cable plug at bottom. Dark panel.

graphics/technology/vlsi-process.png - VLSI icon. Wafer (Silver circle) with many small dies (grid of Gold squares), Cyan #45E0C0 process lines. Dark panel.

graphics/technology/datacenter.png - Datacenter icon. Rack (Panel #1A2430) with 8 servers, cooling fans on top, network cable plugged in. Dark panel.

graphics/technology/advanced-packaging.png - Packaging icon. Chip (Silver square) on interposer (Green #4FBF6A board) with solder bumps (Gold #E0B040 dots). Dark panel.

graphics/technology/heterogeneous-compute.png - Heterogeneous compute icon. CPU + GPU + NPU chips connected by bus lines (Cyan #45E0C0). Dark panel.

graphics/technology/quantum-computing.png - Quantum computing icon. Qubit (Silver circle) in dilution fridge (White #B9C6D4 cylinder), control lines radiating. Dark panel.

graphics/technology/quantum-error-correction.png - QEC icon. 9 physical qubits (9 Silver circles) arranged around 1 logical qubit (larger Cyan #45E0C0 circle in center). Dark panel.

graphics/technology/quantum-advantage.png - Quantum advantage icon. QPU chip (Silver square) outperforming classical chip (Ink square) with speed lines (Cyan #45E0C0). Dark panel.

graphics/technology/qln.png - QLN icon. Storage nodes connected by network lines (Cyan #45E0C0), storage drive (Silver cylinder) at center. Dark panel.

graphics/technology/qln-quantum.png - Quantum QLN icon. Two storage groups linked by entanglement arc (Purple #9A6EE0 wavy line), cores at ends. Dark panel.

graphics/technology/machine-learning.png - ML icon. Neural network nodes (Silver dots) connected (Silver lines), training arrow (Green #4FBF6A) pointing to model disk. Dark panel.

graphics/technology/ai-specialist.png - Specialist AI icon. Model disk with domain sector slices (3 colors) and NPU chip beside it. Dark panel.

graphics/technology/ai-general.png - General AI icon. Model disk with neural nodes, tensor core chip (Purple #9A6EE0) beside it. Dark panel.

graphics/technology/ai-frontier.png - Frontier AI icon. Model disk with quantum nodes (Cyan dots), QPU chip beside it. Dark panel.

graphics/technology/artificial-general-intelligence.png - AGI icon. AGI Model disk with glowing Gold core, surrounded by all 5 model tiers in a ring. Dark panel.

graphics/technology/the-question.png - The Question icon. Large "42" glyph (Gold #E0B040) on dark panel, compute bars below (Scalar/Vector/Tensor/Quantum in Cyan/Purple/Green/Red). Dark panel.

---

## 4. Node Item Icons (process nodes, 64×64 generated from 16×16)

For each of the 12 major nodes + 10 half-nodes, three items each (mask, wafer, die):

graphics/icons/node-10um-mask.png - 10µm mask: contact lithography reticle, thick Chrome pattern (Ink #0C1116) on Quartz (Silver #B9C6D4).
graphics/icons/node-10um-wafer.png - 10µm wafer: 50mm wafer (Silver circle), contact exposure marks.
graphics/icons/node-10um-die.png - 10µm die: large PMOS die (Silver square), few bond pads.

graphics/icons/node-3um-mask.png - 3µm mask: projection reticle, medium Chrome pattern.
graphics/icons/node-3um-wafer.png - 3µm wafer: 100mm wafer (larger Silver circle).
graphics/icons/node-3um-die.png - 3µm die: CMOS die (Silver square), more bond pads than 10µm.

graphics/icons/node-1um-mask.png - 1µm mask: i-line reticle, finer Chrome pattern.
graphics/icons/node-1um-wafer.png - 1µm wafer: 150mm wafer.
graphics/icons/node-1um-die.png - 1µm die: CMOS die, denser bond pads.

graphics/icons/node-350nm-mask.png - 350nm mask: KrF DUV phase-shift mask (Silver with Cyan #45E0C0 phase areas).
graphics/icons/node-350nm-wafer.png - 350nm wafer: 200mm wafer.
graphics/icons/node-350nm-die.png - 350nm die: BGA die (Silver square with corner bumps).

graphics/icons/node-180nm-mask.png - 180nm mask: KrF DUV mask with copper readiness marks.
graphics/icons/node-180nm-wafer.png - 180nm wafer: 200mm wafer.
graphics/icons/node-180nm-die.png - 180nm die: flip-chip die (bumps on face).

graphics/icons/node-90nm-mask.png - 90nm mask: ArF DUV immersion mask, finest Chrome pattern yet.
graphics/icons/node-90nm-wafer.png - 90nm wafer: 300mm wafer (large Silver circle).
graphics/icons/node-90nm-die.png - 90nm die: strained silicon die, strained pattern lines.

graphics/icons/node-45nm-mask.png - 45nm mask: high-k/metal gate mask, high-k layer (Purple #9A6EE0 tint).
graphics/icons/node-45nm-wafer.png - 45nm wafer: 300mm wafer.
graphics/icons/node-45nm-die.png - 45nm die: high-k die, metal gate pattern.

graphics/icons/node-22nm-mask.png - 22nm mask: multi-patterning mask, multiple exposure marks.
graphics/icons/node-22nm-wafer.png - 22nm wafer: 300mm wafer.
graphics/icons/node-22nm-die.png - 22nm die: FinFET die (3D fin lines on top).

graphics/icons/node-14nm-mask.png - 14nm mask: multi-patterning mask, refined.
graphics/icons/node-14nm-wafer.png - 14nm wafer: 300mm wafer.
graphics/icons/node-14nm-die.png - 14nm die: FinFET die, more fins.

graphics/icons/node-7nm-mask.png - 7nm mask: EUV mask, finest pattern (EUV wavelength mark).
graphics/icons/node-7nm-wafer.png - 7nm wafer: 300mm wafer.
graphics/icons/node-7nm-die.png - 7nm die: FinFET die, EUV pattern.

graphics/icons/node-3nm-mask.png - 3nm mask: EUV mask, GAA marks.
graphics/icons/node-3nm-wafer.png - 3nm wafer: 300mm wafer.
graphics/icons/node-3nm-die.png - 3nm die: GAA die (nanowire pattern).

graphics/icons/node-1-4nm-mask.png - 1.4nm mask: high-NA EUV mask, most refined.
graphics/icons/node-1-4nm-wafer.png - 1.4nm wafer: 300mm wafer.
graphics/icons/node-1-4nm-die.png - 1.4nm die: CFET die (stacked nanosheets).

Half-node refinement icons (6um, 1.5um, 800nm, 250nm, 130nm, 65nm, 32nm, 10nm, 5nm, 2nm):
- Same wafer/die style as parent node but with refinement badge (small Cyan #45E0C0 checkmark or "R" in corner).

---

## 5. Technology Icons Needing Regeneration

These already exist but should match new entity art style:
graphics/technology/process-10um.png through process-1-4nm.png
graphics/technology/refine-6um.png through refine-2nm.png
graphics/technology/automation-science-pack.png through chiptorio-quantum-science-pack.png

---

## Integration Notes

- Item icons are 64×64 PNGs with transparency, referenced by `M.set_icon()` in data stage.
- Entity world sprites are 64×64 PNGs with transparency, assigned via `entity.picture` or `M.set_custom_sprite()`.
- Technology icons are 256×256 PNGs, assigned via `M.tech_icons()` or direct `entity.icons`.
- All paths relative to `graphics/` in the mod root, referenced as `__chiptorio__/graphics/...`.

Generate them one at a time in Texel Studio, then push the `graphics/` folder back here for integration into `scripts/util.lua` and entity definitions.
