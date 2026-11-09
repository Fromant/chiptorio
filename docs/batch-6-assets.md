# Batch 6 — semiconductor production, candidate revision 01

User-approved design footprint: **5×5 for all five machines**. This is candidate
metadata only: installed prototypes/art stay at their previous sizes until visual
approval, isolated validation and explicit publication through Asset Studio.
No costs, power, production rates, recipes or existing layouts are changed here.
The candidate bindings explicitly move the existing fluid connections onto the
new 5×5 perimeter without deleting boxes or changing their input/output directions.
Crystal Puller remains a dry furnace. Nothing in that plan is applied yet.

| Machine | Dominant construction | Working sequence |
|---|---|---|
| Crystal Puller | Open hot-zone vessel, tall extraction bridge, lower cooling well | Grow/rotate silicon boule, lift clear, transfer, lower into cooling well, return seed head |
| Wafer Fab | Low three-pod cluster with open central vacuum handler and wafer carriers | Dock pickup, extend/retract blade, visit the process pods, return |
| Assembly Fab | Open leadframe bed, two wire-bonding C-frames and a separate mould press | Bonding approaches/dwells, capillary movement, package press closes/releases, strip indexes |
| Computer Assembler | Open backplane/chassis cell, broad insertion gantry and feeder banks | Pick up module, traverse, insert/retract, move pallet to test station |
| VLSI Fab | Tall stepped optical column, precision XY stage, reticle tower and vacuum skid | Reticle exchange, stepped wafer positioning, localized exposure dwells, return |

All are fixed game-camera views on square occupied foundations, not scaled-up
copies of previous machines. Broad structure, exposed work, connected utilities,
industrial enamel/ceramic/steel and restrained process lighting take priority over
tiny props. The crystal tower and VLSI optics deliberately contrast with the lower
wafer cluster, wire-bonding line and computer gantry.

Sources: `tools/graphics/assets/semiconductor/`. Each small entry module exports
`build(w)`; shared geometry is an explicit registry dependency. Native crafting
owns all five working loops (including the furnace). Candidate loops are 48 frames
at 12 fps / four seconds; idle is a separate unlit rest state. Process cues are
stylized authored cycles, not a simulation of individual recipe products.
Builder interlocks additionally check crystal transfer clearance, retraction
before wafer-handler rotation, bonding/mould release before leadframe indexing,
insertion-head clearance during pallet movement and stationary in-bounds exposure.

```sh
cd tools/asset-studio
npm run pipeline -- build --asset=entity:crystal-puller --draft
npm run pipeline -- build --batch=batch-6 --draft
npm run pipeline -- build --batch=batch-6
```

Drafts cannot be approved. The full batch candidate reviews each machine at the
same world scale as its current installation and shows the real 3×3 → 5×5
footprint change. Do not run Factorio candidate validation or publish until the
user has reviewed and explicitly approved the exact revision.

After an eventual publication, old dense 3×3 layouts may need manual rebuilding:
neighbours and existing pipes are not relocated or deleted automatically. Reserve
5×5 for the machines and reconnect fluids at the new perimeter.
