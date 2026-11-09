# Batch 5 — initial implementation (historical)

**Current implementation:** [Batch 5 redo, revision 04](batch-5-redo.md). The four
criticized machines are being replaced under the subsequent user request; QLN
Terminal is explicitly excluded and preserved. The dimensions and verification
notes below document the initial implementation, not the new installed sizes.
Use the revision-04 page for current rebuild instructions and behavior.

**Post-review status (2026-11-06):** this page records the installed implementation,
not approval of its visuals for the next design pass. The user found the assembler's
tape reels fan-like/overlapping and its animation insufficient, and the two AI
machines too similar. A square-footprint industrial-scale redesign, robotic arms,
distinct GPU/model-serving architectures and shared Ethernet-like network lighting
are discussed in [Machine scale and art direction](machine-scale-and-art-direction.md).
Those changes are **not implemented or authorized for immediate rebuilding**.
Previous batches remain untouched; the optional component-prop idea is small polish,
not a new production requirement.

Installed entities, in render order:

| Entity | Actual footprint | Functional art | Working condition |
|---|---|---|---|
| QLN Terminal | 1×1 | Horizontal storage map, four reader sockets and access pads | Terminal GUI open |
| Training Cluster | 3×3 | Four exposed accelerator trays, tensor packages/HBM, copper coldplates, crossed coolant manifolds, optical links, cooling fans | AI runtime actually advances training after compute/data checks |
| Inference Lab | 3×3 | Removable model cartridge, ceramic arithmetic tiles, stage indicators, cooling cassettes | Installed model has sufficient network support to grant insight |
| Circuit Assembler | 3×3 | PCB workholder, indexed tape feeders/reels, moving XY bridge and placement head | Native crafting; separate native unlit idle animation |
| Network Monitor | 3×2 | Flat topology-map instrument, subnet diagram and bilateral probe sockets | Connected to a network |

All are fixed-view and non-rotatable. No preferred operator front, hero renders,
or redundant direction sets. Low-poly primitives use the shared textured metal,
enamel, PCB and ceramic materials. Terminal and Monitor animate lights only;
compute cooling fans and the assembly mechanism have real geometry motion.

## Rebuild

```sh
cd tools/asset-studio
npm ci
npm run render:batch5
```

This **Node + Sharp** pipeline detects Blender, rebuilds the editable models,
verifies loop closure/footprints/motion and zero idle emission, renders 24 working
frames and a separate idle/shadow, validates alpha bounds and frozen animation,
packs sheets, and installs generated PNG/Lua definitions. No PowerShell wrapper.
One model unit remains one tile; export scale is 0.5, not adjusted to hide clipping.

- Source geometry: `tools/graphics/blender/batch5_models.py`.
- Editable models/build entrypoints: `tools/graphics/blender/<entity>/`.
- Review frames/manifests: `tools/graphics/blender/renders/game-batch5/<entity>/`.
- Installed sheets: `graphics/entity/<entity>/`.
- Optional single-asset rebuild: `npm run render:batch5 -- --asset=circuit-assembler`.
- Repack existing frames: add `--pack-only`.
- Inspect animations in Asset Studio under **Batch 5 / completed**.

## Integration

The QLN Terminal keeps its 1×1 node inventory and behavior. AI machines keep their
original 3×3 selection and collision boxes. Training is a scripted assembler;
Inference is a scripted lab. Both display idle prototype art and register one
working body overlay, with activity leases reported by the AI tick. No native
research/crafting clock is mistaken for AI work. Unsupported inference and removed
models return to idle. No gameplay gates, recipes or AI rates were changed.

The Circuit Assembler uses native `graphics_set.animation` and `idle_animation`;
the single-frame idle layers repeat to match the working animation's effective
frame count. Its inherited collision boxes and fluid connections are untouched.
It needs no runtime scan or polling overlay.

The Monitor's existing prototype was **3×2**, despite the old comment calling it
1×1. Its art preserves that rectangle and the original collision bounds. Network
status supplies its light-only lease without adding routing or bandwidth.

The previous rejected facing models are not reused. Historical flat PNGs remain
available as references and are labeled accordingly by the asset catalog.

## Verification

- Blender validator: 48-frame seamless driver period, 24 exported frames, idle
  lights off, correct 1×1 / 3×3 / 3×2 metadata, mechanical/light-only distinctions.
- Packer: matching origins/footprints, nonempty unclipped alpha bounds, model body
  within tile width, screen-right shadow centroid, distinct working frames,
  identical idle/work canvas and shift.
- Data contract: fixed view, preserved bounds, registered AI/container overlays,
  native assembler idle/working definitions and no unused assembler overlay.
- Runtime contract: connected Monitor activity, actual training/inference activity,
  no inference activity without a model, and idle after model removal.
- Asset Studio: filesystem coverage, all five in completed batch 5, actual
  prototype dimensions, animated previews and offline export.
