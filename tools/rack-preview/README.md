# Server enclosure review scenario

Run `powershell -NoProfile -ExecutionPolicy Bypass -File tools/preview-rack.ps1 -Reload`
from the repository root. The isolated dev mod shows four orientations, a
vanilla lab for scale, and a close-packed row of 3x3 server enclosures. It
provides electricity so fan and lamp animations can be reviewed without
power warnings. Existing player saves are not loaded.

Use R / Shift+R while holding or pointing at a rack. Every direction has the
same 3x3 footprint, with the full silhouette inside it and no stretching.
Rotation preserves installed modules, health, energy and position.

`-CollectScreenshot` copies the static scene and paired animation captures
to `tools/graphics/blender/renders/final/`. The exported sprite-sheet player
is `renders/final/preview.html` in that same Blender workspace.
