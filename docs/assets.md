# Chiptorio — Generated Assets, Locale, Release

## Planned scale and art direction

The post-Batch-5 discussion is recorded in
**[Machine scale and art direction](machine-scale-and-art-direction.md)**:
square non-rotatable floor plans, industrial hypercomputing scale, a robotic
Circuit Assembler, distinct GPU-training/model-serving facilities, Ethernet-style
network lights, optional small component props, and a limited external reference
review. The subsequent [Batch 5 redo](batch-5-redo.md) selects only assembler 5×5,
training 9×9, inference 7×7 and monitor 3×3; Terminal is protected and unchanged.
All other sizes remain proposals. No earlier batch is authorized for redesign by
the discussion document alone.

## Live graphics inventory

**[Asset Studio](asset-studio.md)** is the React/Vite/Node application for browsing
every shipped graphic, installed/inherited machine sprites, Blender models, and
the proposed render batches. Run `npm ci` then `npm run dev` in
`tools/asset-studio`; open `http://127.0.0.1:4173`. Its Blender buttons open models
or render isolated previews, never install sprites. `npm run export` writes the
offline, self-contained root `asset-overview.html`.

## Icon generation

`tools/make-icons.ps1` regenerates all item icons, technology icons, the
sixteen connection-aware cable world sprites in `graphics/entity/cable/`,
`thumbnail.png`, and `graphics/answer-ending.png`. Do not hand-edit generated
PNGs.

- A new icon needs a `Save-Icon` call and an entry in the contact-sheet
  `$order`.
- A new cable shape needs an entry in `$cableShapes` and in `CABLE_SHAPES` in
  `scripts/network.lua` and `tools/test-probe/data-updates.lua`.
- A new technology also needs an entry in `$techIcons`.

## Sound generation

`tools/make-sound.ps1` rebuilds `sound/answer-fanfare.ogg` and requires
`ffmpeg` on `PATH`.

## Locale

Add `locale/en/locale.cfg` entries for new items, entities, and technologies;
placeholders are `__1__`, not `%s`.

Locale keys are auto-resolved by Factorio (`item-name.<name>`,
`entity-name.<name>`, `technology-name.<name>`, `recipe-name.<name>`,
`fluid-name.<name>`), so explicit `localised_name` is not required. The data
contract in `tools/test-probe/data-updates.lua` verifies every Chiptorio-created
prototype has a locale entry.

## Release

Bump `info.json` `version` and add a dated `changelog.txt` entry under
Features/Balance/Bugfixes, newest first.

## Blender entity sprites

The first five labs use `tools/graphics/blender/render-game-labs.ps1 -Build -Install`.
It builds editable models and exports one fixed game view with native working and
unlit idle states. The Analytical Engine is 4×2; the other four labs are 2×2.
The exact-sheet viewer compares the exported game sprites, not hero renders.
See `tools/graphics/blender/LAB-PREVIEWS.md` for materials, geometry budgets and
packing/alignment checks. `preview-labs.ps1` delegates to the same game pipeline.

The next five infrastructure machines use
`tools/graphics/blender/render-game-infrastructure.ps1 -Build -Install`.
See `tools/graphics/blender/INFRASTRUCTURE-ASSETS.md` for their models, gameplay
activity hooks, native accumulator charge animation and exact-sheet viewer.

The third five assets use `tools/graphics/blender/render-game-logistics.ps1 -Build -Install`.
They retain their existing 1×1 utility-node footprints. See
`tools/graphics/blender/LOGISTICS-ASSETS.md` for actual transfer/FOUP activity,
access-point link-status scope, geometry counts and the exact-sheet viewer.

The server enclosure uses the standalone pipeline in
[`tools/graphics/blender/README.md`](../tools/graphics/blender/README.md).
`render-entity.ps1 -Build -Animate -Install` rebuilds the model, renders and
packs its optional animation, and installs the generated sprite definition.
Omit `-Animate` for a static export. `-Angles` chooses directions independently;
`-Device hip -GpuName 9070` selects the AMD Radeon RX 9070 XT. The legacy
PowerShell entity generator skips the server rack so it cannot overwrite it.
