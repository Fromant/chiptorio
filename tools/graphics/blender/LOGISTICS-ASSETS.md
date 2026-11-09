# Logistics utility nodes — third batch

Five more installed game assets, all retaining their actual **1×1** collision
footprints and existing adjacency rules. The old art TODO's 2×2 suggestions were
not the implemented machine sizes. These are low-segment native meshes with one
fixed game view, 24-frame working sheets, unlit idle pictures and static shadows.

| Asset | Triangles | Working art |
| --- | --- | --- |
| FOUP Dock | 2,324 | Carrier load port, guide rails, moving lid-lock cams and violet cycle indicators |
| Wireless Access Point | 2,072 | Fixed mast, four ceramic RF patches and link-status lamps; no rotating antenna |
| QLN Import Node | 2,284 | Recessed blue ingress aperture, inward arrows and inward-phased packet lights |
| QLN Export Node | 2,112 | Raised ochre egress manifold, outward arrows and outward-phased packet lights |
| QLN Provider Node | 2,592 | Eight cargo compartments, protective rim and green supply indicators |

Physical hardware and colours distinguish the three transfer nodes even while
idle. Provider cargo remains stackable in its eight ordinary inventory slots;
it is not a compute-provider hardware inventory. FOUP buffers and recipes are
unchanged. Nothing renders four duplicate directions or a separate hero camera.

## Rebuild/install/review

```powershell
.\tools\graphics\blender\render-game-logistics.ps1 -Build -Install `
  -BlenderPath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' `
  -Device hip -GpuName 9070
```

Omit the explicit GPU arguments for automatic CPU fallback. `-PackOnly` reuses
rendered frames. The wrapper uses the shared game-view renderer/packer, with
64 source pixels per tile and native sprite scale 0.5.

Outputs under `tools/graphics/blender/renders/game-logistics/`:

- `preview.html`: plays the exact game sheets, with idle/working and game-size/4× zoom.
- `contact-sheet.png` and `working-idle.gif`: actual exported sprite comparisons.
- Each entity's `game-sprite.json`, raw frames, and packed PNG/Lua definitions.

## Activity hooks

`device_visuals` reuses the previous batch's render lifecycle and saved activity
leases. Transfers now report the number of items actually moved, without changing
their budgets, ordering, refunds or storage mechanics:

- Import lights activate only after real insertion into the storage group.
- Export lights activate only after real delivery, not a failed removal/refund.
- Provider lights activate only when its cargo is accepted by the storage group.
- FOUP cams/indicators run on successful seal **or** unseal operations, not while
  waiting for a complete batch.
- The access point is tracked as a zero-capacity status endpoint and indicates
  whether it is attached to a network.

**Existing wireless limitation:** actual wireless reach is implemented by network
routers. The standalone access point did not have routing logic before this
batch and is not silently turned into a bridge here. Its new graph role only
supports link-status reporting; it grants no extra range or capacity. The separate
standalone access-point behaviour remains a gap in `TODO.md`.

Runtime contracts cover successful and blocked/empty transfers, FOUP seal/unseal,
access-point connection/disconnection, and correct delivery despite art hooks.
Data contracts check matching work/idle frames and unchanged 1×1 footprints.
