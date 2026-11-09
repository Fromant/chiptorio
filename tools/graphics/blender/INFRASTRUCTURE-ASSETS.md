# Infrastructure assets — second batch

The next five P0 entries follow the same single-view, native game-scale pipeline
as the labs. Their working states are tied to actual gameplay, not decorative
always-on turntables. Each `.blend` is rebuildable, uses low-segment primitives
and rigid mesh batching, and has a closed 48-frame/two-second working cycle.

| Asset | Size | Geometry | Activity |
| --- | --- | --- | --- |
| Metrology Lab | 3×3 | 3,392 triangles / 48 mesh objects | Real XY wafer stage below a fixed optical head; inspection lamps |
| Answer Engine | 5×5 | 14,396 triangles / 92 mesh objects | Four compute banks, real cooling fans, roof `42` and data/status lights |
| QLN Storage Drive | 2×2 | 3,996 triangles / 55 mesh objects | Four accessible memory bays, static hardware, online heartbeat lights |
| Quantum Entanglement Core | 2×2 | 5,112 triangles / 36 mesh objects | Two cryogenic sample wells and pulsing optical link; no spinning levitating props |
| Construction Core | 2×2 | 4,970 triangles / 54 mesh objects | Eight ceramic power cells, copper buses, segmented charge indicators; no decorative robot arms |

Construction retains the actual existing 2×2 battery footprint and energy
behaviour, rather than adopting the old TODO's speculative 3×3 size. Storage
Drive bays still accept only one memory module each. Consumable wafer stacks
and all recipes, research gates, inventories and energy budgets are unchanged.

## Rebuild/install/review

```powershell
.\tools\graphics\blender\render-game-infrastructure.ps1 -Build -Install `
  -BlenderPath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' `
  -Device hip -GpuName 9070
```

The optional explicit GPU selection fails rather than silently switching devices.
Omit it for automatic CPU fallback. FFmpeg is optional for the generated GIF;
the exact-sheet HTML player works without it.

The wrapper reuses `render-game-labs.ps1`, `render.py --game-view`,
`pack-game-lab.ps1` and `preview-game-labs.ps1`. Its larger 512px canvas leaves
room for the 5×5 Answer Engine and its shadow; the rendered density remains
64 source pixels per tile, with sprite scale 0.5. **It does not enlarge the
models, change the camera pitch, or render extra directions.**

Installed files are `graphics/entity/<name>/{working.png,idle.png,shadow.png,sprite-def.lua}`.
Review files are under `tools/graphics/blender/renders/game-infrastructure/`:

- `preview.html`: exact exported sheet player, work/idle and game-size/4× controls.
- `contact-sheet.png` and `working-idle.gif`: comparisons at 2× game size.
- Per-entity `game-sprite.json`: crop, projected origin, footprint and timing.

## Runtime integration

Containers cannot natively select a working animation, so their registered idle
picture remains the base/shadow and `device_visuals` attaches the working body
only while the owning simulation reports activity. Moving inspection geometry
stays inside the opaque instrument bed; the base cannot leave a floating
rest-pose silhouette. There is no second animated shadow.

- Metrology reports supported, powered wafer analysis, including fractional
  samples between whole-wafer consumption boundaries (so the scanner does not stutter).
- The Answer Engine reports successful computation/item consumption, and returns
  immediately to idle when paused or starved.
- QLN drives report an online state only when connected and populated.
- Quantum cores animate only when paired by the actual QLN grouping algorithm.
- Construction uses native accumulator `chargable_graphics`, with work loops
  for charge/discharge and unlit idle. Its battery implementation is unchanged.

`control.lua` owns initialization and the sole 60-tick dispatcher. The visual
module stores render/entity references and one-second activity leases in
`storage`, scans no surfaces, reuses loops rather than restarting them each
second, expires disconnected/inactive reports, and prunes invalid targets.
Save/load retains render references; configuration changes reset them safely.
`remote.call("chiptorio-art", "status")` returns active scripted device art.

Run `tools/test-all.ps1`. The contracts check native and registered art, footprints,
shared work/idle origins, qualification activity, Answer starvation transitions,
drive online/empty transitions, and quantum pair/unpair transitions.
