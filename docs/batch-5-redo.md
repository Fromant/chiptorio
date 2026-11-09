# Batch 5 redo — industrial hypercomputing, revision 04

Scope authorized on **2026-11-07**: redo Circuit Assembler, Training Cluster,
Inference Lab and Network Monitor. **QLN Terminal is approved and protected**:
its 1×1 model, installed sheets, builder function and behavior are unchanged.
Earlier entity artwork is not rebuilt or replaced.

## Machines

| Entity | Occupied tiles | Art and motion | Exported loop |
|---|---:|---|---|
| Circuit Assembler | **5×5** | Two articulated robots, cast pedestals and hydraulic details; magazine pickup, carried chip props, placement, pneumatic clamps and an indexed PCB shuttle. No fans or reels. | **48 frames / 4 seconds** |
| Training Cluster | **9×9** | Sixteen open GPU cabinets with six blades each, broad service aisles, overhead fabric bridges, coolant headers and separate cooling/power services. | **24 frames / 2 seconds** |
| Inference Lab | **7×7** | A taller central model-cartridge library with moving selectors, four lower serving banks and separate memory/cooling services; not a recolored training hall. | **32 frames / 2⅔ seconds** |
| Network Monitor | **3×3** | Square topology instrument with four Ethernet-like patch bays, green link indicators and independent irregular amber bursts. | **48 frames / 4 seconds** |
| QLN Terminal — untouched | **1×1** | Approved horizontal storage map and four readers. | Original **24 frames / 2 seconds** |

All remain fixed-view and non-rotatable. Enlargements are real square selection,
collision and tile footprints, not only bigger sprites. Export scale stays 0.5
and the camera remains the same game projection. Larger canvases accommodate
height and shadows: 768 px for assembly, 1024 px for the AI halls, 512 px for the
monitor. There are no hero views or redundant direction exports.

## Animation and detail

- The robot cycle uses sampled two-link kinematics and distinct feed, lift, swing,
  placement, dwell and return poses. Arms are staggered rather than mirrored in
  lockstep. The PCB indexes only after placement and after the clamps release.
- Small shared packaged-chip geometry is reused in magazines, grippers and the
  board. These props are baked sprite detail, not a new item-rendering system,
  recipe-specific animation set, inventory, compute provider or runtime entity.
- Network port patterns are deterministic and varied per port; the revised
  scripted facilities also have reproducible per-entity phase offsets. They are
  online decorative activity, **not measured packet/throughput telemetry**.
- Working/idle art is separate, with zero idle emission. Circuit uses native
  crafting/idle animations. Training follows successful AI processing; inference
  follows supported model operation; monitor follows network connection.
- Earlier networking/logistics batches and the approved terminal retain their
  original appearance and phase behavior. No external reference assets are copied.

## Rebuild and inspect

```sh
cd tools/asset-studio
npm ci
npm run pipeline -- build --batch=done-5
```

**Superseded workflow:** the original direct-install renderer is disabled. The
[shared pipeline](asset-pipeline.md) now stages review candidates for any batch.
Completed Batch 5 assets are locked; explicitly unlock only an authorized asset
before staging a revision. Nothing installs before visual approval and validation.

- One asset: `npm run pipeline -- build --asset=entity:circuit-assembler`.
- Optional low-cost draft: add `--draft`.
- Repacking/resume uses verified content-addressed stage caches automatically.
- Source geometry: `tools/graphics/blender/batch5_redesign.py`.
- Terminal's unchanged function and the builder dispatch: `batch5_models.py`.
- Editable models: `tools/graphics/blender/<entity>/<entity>.blend`.
- Frames and manifests: `tools/graphics/blender/renders/game-batch5/<entity>/`.
- Installed PNGs/Lua: `graphics/entity/<entity>/`.
- Review in Asset Studio at `http://127.0.0.1:4173/?batch=done-5`.
- Refresh prototypes after installation; `npm run export` updates the offline HTML.

## Integration and balance boundaries

The graph already attaches to every occupied tile, not just the machine center.
The runtime test places cables at the far edges of the new 9×9 / 7×7 facilities
and verifies real AI progress/activity. Fixtures are spread out and placement is
checked, rather than force-building overlapping machines into the old test layout.

Unused inherited fluid boxes are cleared from the dry Circuit Assembler and the
scripted Training Cluster; obsolete internal pipe connectors are not retained in
their enlarged footprints. Native assembler idle layers repeat to match the new
working animation's effective frame count.

GPU hardware is available at the current AI technology gate. This pass does **not**
change recipes, compute output, power costs or AI work rates; further economic
balancing remains separate work. Other machine-size proposals in
[the direction document](machine-scale-and-art-direction.md) remain proposals.

### Existing saves

These occupied footprints grow. No existing entities or their neighbors are
automatically moved, deleted or discarded. Old dense layouts may need manual
relocation/rebuilding; reserve 5×5 / 9×9 / 7×7 for the resized facilities. Save/load
verification is not a promise of collision-free automatic expansion of every
existing factory.

## Verification

- Seamless 48/64/96-frame scene periods, expected exported frame counts and zero
  idle emission; mechanical and light-only animation checks.
- Every sampled robot pose is checked for its floor envelope and arm separation;
  clamp/shuttle timing is checked across the whole cycle, not just frame zero.
  Model selectors are checked to stay clear of cartridge fascias/latches.
- Ethernet sequences must differ between ports and contain repeated bursts.
- Packer checks nonempty/unclipped alpha, matching idle/work origins and footprints,
  physical body width, screen-right shadows, distinct frames and texture limits.
- Data/runtime contracts check real square occupation, dry fluid-box cleanup,
  native versus scripted graphics, perimeter attachment, supported AI activity and
  return to idle.
- A local SHA-256 baseline protects the approved terminal models/sprites and all
  earlier entity art byte-for-byte. It also compares the terminal builder function.
- Asset Studio tests cover new dimensions/frame counts, inspection, previews and
  the self-contained offline export.
