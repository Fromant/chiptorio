# Chiptorio — Blender entity pipeline

This directory holds the standalone Blender pipeline that produces the **3 x 3 twin-bay server enclosure** entity art (rotating fans, blinking lamps, four cardinal directions, ground shadows). The pipeline is 100% working: build → render → pack → install, with no image-generation service and no hand-edited PNGs.

User-facing docs: [`docs/assets.md`](../../docs/assets.md). The canonical model is `server-rack.blend`; `build.py` rebuilds it from native geometry.

## File map

| File | Purpose |
|------|---------|
| `server-rack.blend` | Editable native model (materials, geometry, rig, named animation channels). |
| `build.py` | Rebuilds `server-rack.blend` from scratch: collections, materials, geometry, camera, lights, shadow catcher, fan/rotor rigs, lamp materials. |
| `render.py` | Renders the saved model for requested directions; rotates geometry on a turntable (camera/light fixed), exports frame-zero stills, animation frames and one static shadow per direction. Writes `render-manifest.json`. |
| `render-entity.ps1` | PowerShell entrypoint: runs `build.py` (`-Build`), then `render.py`, then `pack.ps1`. Controls angles, frames, samples, resolution, device, shadows, output dir, install. |
| `pack.ps1` | Packs frames left-to-right/top-to-bottom into sprite sheets, validates dimensions, frozen-animation and silhouette bounds, checks shadow direction, emits `sprite-def.lua`, optionally installs sheets/shadows/definition into `graphics/entity/server-rack/`, writes `preview.html`. |
| `make-preview.ps1` | Optional static contact sheet (`preview.png`) from exported frames. |
| `renders/final/` | Render output (gitignored): frames, sheets, shadows, manifest, sprite-def, preview files. |
| `renders/final/in-game-preview.png`, `in-game-*.png` | Factorio review captures from `preview-rack.ps1 -CollectScreenshot`. |

## Prerequisites

- Blender 5.2 on `PATH`, or supply `-BlenderPath`.
- HIP/AMD GPU optional (`-Device hip -GpuName 9070`); CPU fallback is automatic unless `-Device hip` is explicitly requested.

## One command (from repository root)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/graphics/blender/render-entity.ps1 `
  -Build -Animate -Device hip -GpuName 9070 -Install `
  -BlenderPath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
```

That rebuilds the model, animates all four directions, packs sheets, emits `sprite-def.lua` and installs into `graphics/entity/server-rack/`.

Static export (default, no `-Animate`): one frame per direction, no animation prototype changes needed.
```powershell
.\render-entity.ps1 -Angles north,east,south,west -Install
```
Review a single direction:
```powershell
.\render-entity.ps1 -Angles east -Animate
```

`render-entity.ps1` examples after the first are run from this directory; otherwise pass `-BlenderPath`. Install requires all four cardinal directions. `-Angles` also accepts `hero`. `-NoShadows` omits shadows. `-Samples`, `-Resolution`, `-OutputDirectory`, `-KeepFrames` are independent. Re-render before repacking when intermediate frames were removed.

## Pipeline stages

1. **`build.py`** — standalone materials, geometry, rig and named animation channels. Empty factory settings; `CYCLES`, AgX transform, 384 px, film transparent. One Blender unit = one Factorio tile; front = `-Y`. Collections: `Base`, `Details`, `Emission`, `Cables`, `Rig`, `Reference`. Materials are named (Graphite enamel, Cast iron, Brushed aluminium, Online LED, Activity LED, Terminal phosphor, …). Named animation channels: fan rotors carry `animation_channel='fan'` plus `phase`; lamp materials carry `animation_channel='lamp'` plus `phase`, `activity`, `base_color`, `emission_strength`.

2. **`render.py`** — renders the saved model. Camera and lighting stay fixed at a 45-degree orthographic view; only the enclosure rotates on a turntable so every direction casts shadows to screen-right. Frame-zero stills and one static shadow per direction are exported. Fans rotate about individual hubs; seven blades repeat seamlessly after one-seventh of a revolution; lamps use staggered deterministic patterns. Default: 16 frames, four columns, 30 fps (`animation_speed=0.5`), sprite scale 0.475 at 384 px. Writes `render-manifest.json` (entity, footprint, frames, line_length, directions, device, shadows, shadow_direction).

3. **`pack.ps1`** — packs frames into sheets, validates dimensions, confirms animation changes (throws if frozen), checks every silhouette fits the 3x3 area (96 x 96 game pixels; shadows may extend beyond), verifies shadows cast screen-right, emits `sprite-def.lua`, copies sheets/shadows/definition into `graphics/entity/server-rack/` under `-Install`, and generates `preview.html` (plays the exact exported sheets with a pause button). `-KeepFrames` retains intermediate `frames/*.png`; otherwise they are cleaned up after packing.

4. **Install** — only sheets, shadows and the generated `sprite-def.lua` are copied into `graphics/entity/server-rack/`. Blender renders never mutate prototypes; installation is an explicit option.

## Projection and alignment

- One model unit = one tile; footprint 3 x 3.
- Camera and lighting fixed at 45 degrees orthographic; only geometry rotates. All shadows fall screen-right. No nonuniform scaling.
- All directions share one uniform sprite scale (0.475 at 384 px). Packing computes a fixed shift from the union of all frame alpha bounds so fans and blinking lights never make the sprite jump.
- Static parts, emissive lamps, cable curves, rotors, rig and shadow catcher remain editable in the native file. Static export uses frame-zero pose.
- `footprint_tiles = [3,3]`, `pixels_per_tile = 64`, `camera_target_z = 0.65` live in the scene custom properties.

## Factorio integration

- `scripts/providers.lua` builds the server-rack provider (a lab clone: `inputs = {}`, `researching_speed = 0.001`, no `allowed_effects`). When `spec.blender_sprite` is true it requires `graphics.entity.server-rack.sprite-def`, creates one animation prototype per direction (`chiptorio-rack-<dir>`), and sets `on_animation`/`off_animation` to a single-frame still (the decorative loop is played independently by `rack_runtime.lua`).
- Variants `server-rack-east/south/west` are hidden clones sharing the same profile; R / Shift+R rotation is handled by `rack_runtime.lua` (preserves modules, health, energy, position).
- Runtime attaches an independent visual loop to each rack, so fans and lamps animate even when the lab is idle. Render references persist in `storage` and are recreated on configuration change, rotation and cloning. Ground shadows stay in the static entity graphics.
- `tools/make-entities.ps1` (the legacy hand-drawn entity generator) explicitly skips the server rack so it cannot overwrite the rendered art.
- The data stage consumes the generated `sprite-def.lua` for static entity graphics and animation prototypes.
- `scripts/research_meta.lua` defines `RACK_VARIANTS = {"server-rack","server-rack-east","server-rack-south","server-rack-west"}` and maps any variant back to `server-rack`.

## Adding a NEW 3D rendered asset

This pipeline is currently dedicated to `server-rack`. To create another rendered entity, clone the pattern:

1. **Copy the directory** to a new asset name, e.g. `tools/graphics/blender/<new-entity>/`, and copy `server-rack.blend` → `<new-entity>.blend`, `build.py`, `render.py`, `render-entity.ps1`, `pack.ps1`.
2. **Edit `build.py`**: change `HERE`, the output filepath, model geometry/materials, collections, camera/lights, and named animation channels. Keep `CYCLES` + AgX + film transparent + 384 px defaults unless the asset needs a different resolution.
3. **Edit `render.py`**: change the `entity` name in the manifest and the collection names (`Base`, `Details`, `Emission`, `Cables`) to match your model. Keep the turntable + fixed-camera + screen-right-shadow convention.
4. **Edit `render-entity.ps1`**: update `$blend` to `<new-entity>.blend`; defaults for angles/frames/samples/resolution/device as appropriate.
5. **Edit `pack.ps1`**: it reads `render-manifest.json` generically, but the install destination path and `sprite-def.lua` `__chiptorio__/graphics/entity/<new-entity>/` prefix must match the new asset. The silhouette bound check uses the asset's footprint tiles (scale × 32 per tile).
6. **Run**: `.\render-entity.ps1 -Build -Animate -Install` from the new directory, or from repo root with the full path.
7. **Wire into Factorio**: in `scripts/providers.lua`, add a `make_provider` spec with `blender_sprite = true` and point the sprite lookup at `graphics.entity.<new-entity>.sprite-def`. Add the item/recipe/technology in the normal `data.lua` order (items/fluids → machines/labs → recipes/technologies). Add locale entries in `locale/en/locale.cfg` (`item-name.<name>`, `entity-name.<name>`).
8. **Review**: `tools/preview-rack.ps1 -Reload` opens the disposable comparison scene; `-CollectScreenshot` copies captures into `renders/final/`. Headless verification remains `tools/test-all.ps1`.
9. **Commit**: ship the installed sheets/shadows/`sprite-def.lua` under `graphics/entity/<new-entity>/`. `renders/final/` intermediate frames are gitignored review output.

## Rules & traps

- Do **not** hand-edit generated PNGs. Re-run the pipeline instead.
- Do **not** delete intermediate `frames/*.png` before packing; `-KeepFrames` retains them, otherwise pack cleans them up. Re-render before repacking if frames were removed.
- `pack.ps1` throws on frozen animation (all frames identical) and on silhouettes exceeding the footprint; fix the model, not the check.
- Shadows must cast screen-right; pack verifies this and throws on regression.
- The manifest records the actual render device; explicit `-Device hip` fails instead of silently falling back to CPU.
- No image-generation service or downloaded preset dependencies are involved; `build.py` builds from native geometry with no legacy template steps.

## Verification

- `tools/preview-rack.ps1 -Reload` — isolated rack-art scenario for visual review.
- `tools/preview-rack.ps1 -CollectScreenshot` — copies in-game captures into `renders/final/`.
- `tools/test-all.ps1` — headless verification (smoke → contract → registration → save/load → power-grid → performance). Any failure exits non-zero.
- Existing player saves are not loaded by the preview scenario.
