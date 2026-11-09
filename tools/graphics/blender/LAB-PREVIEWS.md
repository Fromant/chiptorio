# Native game lab assets — revision 03

These are game sprites, not hero renders. Each machine exports **one fixed game
view**, one working loop, one unlit idle still and one ground shadow. No four-way
rendering is needed. Labs use native `on_animation` / `off_animation`; Factorio
switches states for actual research activity, power and script disablement.

## Machines

- **Analytical Engine, 4×2:** a low open mechanical hall. Two long decimal-store
  banks, twelve register spindles, 48 numbered drums, a geared arithmetic aisle,
  carry pawls/combs, eccentrics, lubrication rails and program feeds at both ends.
  Bilateral, not a square front-facing display or a tower with decorative gears.
- **Tube Mainframe, 2×2:** four valve banks and corner transformers. Working
  animation changes only the cathode lights: no relay/meter motion or corner
  transformer rings. Idle has all bulbs disabled.
- **Mainframe Cluster, 2×2:** exposed logic banks, backplane wiring, central
  exhaust fan and bank lights. The fan is a real cooling mechanism, not a prop.
- **Datacenter Lab, 2×2:** server-blade seams/latches around a detailed top compute
  plane, optical activity lights and corner radiator fans. No exposed copper
  pistons or physically moving scan bars.
- **Cryostat, 2×2:** thermal shields, quantum sample stage and sealed compressor
  heads. The straight helium risers have correctly coaxial insulation sleeves;
  elbows are separate curved sections. Working animation is light-only, without
  exposed horizontal eccentric/piston mechanisms on top of radiators.

## Materials and geometry budgets

World sprites are not restricted to a flat rosy-42 swatch list. They use baked
PBR finishes: cast iron, worn enamel, machined steel, oiled brass, copper, ceramic,
quartz, PCB substrate, gold contacts, frost, rubber and state-driven emission.
Subtle procedural variation changes rough surface response without becoming
pixel noise. Detail comes from functional parts, not merely more saturated colors.

Small cylinders use 8 or 16 sides; large cylinders use 24. Toruses use 16/24 major
segments and four minor segments, curves use low bevel/path resolution, font
curves use low resolution and bevels use one segment. Rigid siblings are baked
and batched by parent/material/collection, preserving all animation pivots and
drivers. This avoids thousands of triangles on tiny round details and reduces
object/BVH overhead without blanket decimation of gear teeth and lettering.
The build prints real triangle and mesh-object counts and stores them on the
scene. The denser mechanical hall legitimately needs more geometry than a valve
or cooling assembly; a low triangle count is not an excuse to remove its mechanism.
Cycles persistent data is enabled during frame export to reuse static scene data
instead of re-preparing it for every animation frame.

## Build, render, pack, install

From the repository root, with Blender on PATH (or pass `-BlenderPath`):

```powershell
.\tools\graphics\blender\render-game-labs.ps1 -Build -Install -Frames 24 -Samples 24
```

Optional: `-Device hip -GpuName 9070`. `-Assets analytical-engine` selects one
machine. `-PackOnly` reuses existing frames. Explicit GPU requests do not silently
fall back to CPU. `preview-labs.ps1` now delegates to this pipeline rather than
rendering four unnecessary facings.

1. `<asset>/build.py` rebuilds its editable `.blend` from `lab_models.py`.
2. `verify-lab-motion.py` validates the closed 48-frame native cycle, moving
   geometry where required, light-only machines, and zero idle emission.
3. `render.py --game-view` uses the actual fixed 45° game camera at 64 rendered
   pixels per tile. No larger hero canvas or alternate yaw. The 24 output frames
   play at 12 fps for the two-second cycle. `--idle` disables all light materials.
4. `pack-game-lab.ps1` validates bounds/dimensions, preserves the projected world
   origin, crops idle/work/shadow identically, packs the exact pixels and emits
   `sprite-def.lua`. Scale is 0.5 (two source pixels per game pixel). Sprite shifts
   are calculated from the projected ground origin, not the silhouette center.
5. `-Install` copies `working.png`, `idle.png`, `shadow.png`, and `sprite-def.lua`
   into `graphics/entity/<asset>/`. `scripts/labs.lua` consumes them directly and
   sets non-rotatable flags and matching collision/selection footprints.

Review output is under `tools/graphics/blender/renders/game-labs/`:

- `preview.html` plays **the exported game sheets**, with working/idle and
  native-game-size/4× zoom toggles and physical footprint outlines.
- `contact-sheet.png` and `working-idle.gif` compare actual idle/work sprites at
  2× game size. These are not a different camera or a separate model render.
- Per-asset `game-sprite.json` records scale, origin, crop, footprint and timing.

Ground shadows are static, as in the rack pipeline. Working geometry and idle
lighting differ natively; there is no periodic Lua rendering overlay for labs.
After installation run `tools/test-all.ps1`. Data contracts verify native
working/idle sprites, matching canvases, non-rotatable flags and 4×2/2×2 sizes.

Old concept renders remain under `renders/labs/` and `renders/labs-v2/` only as
history. They are not the game pipeline.
