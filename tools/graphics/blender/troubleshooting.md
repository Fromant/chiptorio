# Chiptorio — Blender pipeline troubleshooting

Common failures when running `tools/graphics/blender/render-entity.ps1` and how to fix them.

## Blender not found

```
Get-Command : The term 'blender' is not recognized
```

Blender 5.2 is not on `PATH`. Supply `-BlenderPath`:

```powershell
-BlenderPath 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
```

Or run from the repository root with the full path to `render-entity.ps1`.

## HIP GPU not available / explicit hip fails

```
No matching HIP GPU found
```

`-Device hip` requires a matching HIP device and fails instead of silently falling back to CPU. Use `-Device auto` (default) to fall back to CPU, or verify the GPU name with `-GpuName` (e.g. `9070` for RX 9070 XT).

The render manifest records the actual selected device. Check `renders/final/render-manifest.json` for `"device"`.

## Frozen animation

```
Animation is frozen: north
```

`pack.ps1` throws when all frames in a direction are byte-identical. This usually means the fan rotors or lamp materials were not animated in `build.py` or `render.py`, or `pose(frame)` did not change object/material state between frames. Fix the model or the renderer, not the check.

## Silhouette exceeds 3x3

```
Animated silhouette exceeds 3x3: north
```

`pack.ps1` throws when the union of all frame alpha bounds exceeds `96 x 96` game pixels (scale × 32 per tile). Reduce model proportions, camera distance, or sprite scale so the full cabinet silhouette fits within the footprint. Shadows may extend beyond 96×96.

## Shadow direction regression

```
Shadow direction regression: north must cast screen-right
```

`pack.ps1` verifies shadows fall screen-right by sampling shadow alpha mass relative to the body. Ensure the shadow catcher is enabled and the model rotates only on the turntable (camera and lights fixed).

## Missing blend file

```
Model missing. Run with -Build.
```

`server-rack.blend` does not exist. Run with `-Build` first to generate it from `build.py`.

## Intermediate frames deleted before pack

Frames in `renders/final/frames/` are required for packing. Either keep them (`-KeepFrames`) or re-render before repacking. `pack.ps1` cleans up frames after packing unless `-KeepFrames` is set.

## Install requires all four directions

```
Install requires all four cardinal directions.
```

`-Install` needs `north`, `east`, `south`, and `west` all present in the manifest. Render all four (or omit `-Install` for a static/subset export).

## Review in-game

Use `tools/preview-rack.ps1 -Reload` to open the disposable comparison scene. `-CollectScreenshot` copies captures into `renders/final/`. Existing player saves are not loaded. Headless verification remains `tools/test-all.ps1`.
