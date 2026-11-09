# Machine scale and art direction — industrial hypercomputing

Discussion record: **2026-11-06**. This document records the direction after the
Batch 5 review. It supersedes earlier rectangular *target* footprints and cabinet/
flat-board concepts, **not the installed prototypes or historical batch records**.

**Subsequent authorization — 2026-11-07:** the user requested a Batch 5 redo but
explicitly protected QLN Terminal. Circuit Assembler **5×5**, Training Cluster
**9×9**, Inference Lab **7×7**, and Network Monitor **3×3** are selected for the
[revision-04 implementation](batch-5-redo.md). Terminal remains **1×1**, superseding
the earlier tentative 2×2 idea. All other factory-wide size/balance proposals remain
unimplemented. The original discussion and its baseline sizes are retained below
as a decision record; its original "not yet authorized" statements do not override
this later, limited four-machine request.

## 1. Status and boundaries

**Later Batch 6 authorization:** Crystal Puller, Wafer Fab, Assembly Fab,
Computer Assembler and VLSI Fab are all **5×5** in their new review candidates.
This overrides any different tentative sizes below for those five only. Installed
art/prototypes remain unchanged pending review and publication; see
[Batch 6 candidates](batch-6-assets.md).

**Agreed direction / user requirements**

- Chiptorio should feel like an industrial silicon factory with enormous computing
  potential: substantial, valuable facilities, GPU hardware, heavy services and
  visible work. Not a collection of small decorated PCBs.
- Use **square occupied footprints for planned machine redesigns**. Do not make
  9×7, 7×5, or similar rectangles the normal solution for large, fixed-view machines.
  Players would reasonably want to rotate those rectangles to fit factory layouts;
  most Chiptorio machines should remain non-rotatable.
- Keep recognizable function visible from the one game camera. No preferred front
  face, cabinet kiosk composition, hero camera, or redundant directional renders.
- Circuit Assembler needs a much stronger, robotic Factorio-like manufacturing
  animation, **without fans**. Realism may yield to readable, satisfying motion.
- Training Cluster and Inference Lab must have fundamentally different silhouettes
  and internal layouts, not color variants of the same four-corner arrangement.
- Network equipment should share Ethernet-like port lights and irregular activity
  bursts. **Do not redo previous batches** to retrofit that style.
- Small reusable component props inside assembly animations are a welcome optional
  detail, but should receive only a small amount of effort.

**Original discussion boundaries, before the later limited authorization above**

- No model rebuilding, sprite replacement, prototype resizing, recipe changes,
  gameplay rebalance, or rerendering yet. This update is documentation only.
- No changes to the live Asset Studio batch assignments or its prototype-derived
  sizes. It must continue to distinguish what exists from what is proposed.
- Exact target dimensions, capacity/power changes, migration policy, and execution
  order still need approval. The square table below is a revised **proposal**, not
  a finalized balance specification.

Batch 5 remains installed and technically tested, but its Circuit Assembler and AI
visual designs are **pending artistic revision**. Tests passing did not mean those
designs met the desired visual direction. The earlier rejected facing drafts are
also not a source to restore.

## 2. Reference review — bounded, read-only sample

Correct local reference root:

```text
C:\Users\user\Downloads\factorio-sprites-20261106T194010Z-1-001\factorio-sprites
```

The earlier `C:\Users\user\Downloads\factorio-sprites` location contained an empty
`photometric-lab/base` directory at review time; it was the wrong reference copy.

The supplied collection is roughly 468 MB. Only these samples were inspected:

| Reference | Material inspected | Useful observation |
|---|---|---|
| `gravity-assembler` | Static preview and four phases of its GIF | Large articulated arms surround an open, recessed working area. The central workpiece and arm poses visibly change while the enclosing structure remains stable. |
| `manufacturer` | Static preview and four phases of its GIF | Lids, linear mechanisms, glowing working zones and localized sparks create several kinds of activity rather than one decorative rotor. |
| `cybernetics-facility` | Static preview only | Strong central mass, recessed cavities and layered service hardware give depth and weight. No animation behavior was inferred from this still. |
| `photometric-lab` | Static preview only | A clear central process chamber remains legible among secondary pipes and instruments. No animation behavior was inferred from this still. |

The two sampled GIFs total about **14.7 MB**. Four phases each were extracted to a
temporary review directory outside the repository. The GIF previews have 100 and
128 frames at 50 ms/frame respectively; those are **preview-file properties**, not
evidence of their in-game frame counts or a requirement to copy those counts.
The manufacturer's sprite directory also visibly separates animation, color,
emission, frozen, and shadow files. Large production sheets were not loaded.

The reference folder was not modified. No external images, models, contact sheets,
or materials were copied into the mod or committed as documentation assets.
Treat these as references for craft and animation readability, not as Chiptorio's
palette, fiction, exact geometry, or licensed source assets. No redistribution
rights have been established. The local path is not a build dependency.

### Lessons to adopt, without copying the reference style

1. **One dominant mechanism first.** Read the arm/process chamber at normal game
   scale before adding hoses, labels, bolts and tertiary detail.
2. **Expose the working volume.** Use a recessed assembly bed, cutaway service bays
   or open rack aisles; do not hide the interesting work behind a solid roof.
3. **Separate visual frequencies.** Broad masses establish the machine; medium
   mechanisms explain the process; small surface detail rewards close inspection.
4. **Animate a sequence, not perpetual wiggles.** Distinct poses and changes in the
   workpiece communicate feed, handling, assembly and release. Dwell and motion
   profiles are design goals; they were not measured from four sampled frames.
5. **Make effects local.** A placement light, tiny soldering flash or port burst
   should point at an operation, not wash the entire machine in neon.
6. **Keep the structure weighty.** Stationary foundations, braced arm mounts,
   anchored manifolds, panel thickness, gaskets and connected services make moving
   parts feel supported. Avoid floating hardware and disconnected props.
7. **Don't import indiscriminate grime.** Chiptorio can have worn industrial frames,
   fabricated metal, ceramic, enamel and controlled clean process areas without
   turning every semiconductor tool into a rusty furnace.

## 3. Footprint, height and rendering are separate decisions

A square **X/Y floor footprint** does not require a square silhouette or a square
PNG. Camera projection, elevated mechanisms and shadows can require a taller or
wider sprite canvas without occupying extra tiles.

- Retire the earlier proposed 9×7 and 7×5 footprints. Do not use rectangles merely
  to compensate for height, framing, clipping or occlusion.
- Design the facility within a square foundation. Populate that floor with bays,
  service alleys, manifolds and process equipment rather than stretching an old
  model uniformly or placing it on a huge empty plinth.
- A square foundation does **not** require four identical copies of every prop.
  Balanced silhouettes, accessible sides and a non-facing composition matter;
  machinery and animation may have different local roles and phases.
- Keep substantial height where it adds weight, but use stepped roofs, open aisles,
  lower peripheral services and selective cutaways to avoid hiding the process or
  blocking neighboring machines. Do not make every facility a tower.
- Increase export canvas bounds when height/shadows need it; preserve world scale,
  origin and alignment. Do not shrink the machine or distort the collision box to
  make a render fit. Rectangular **sprite bounds** are fine.
- Review at actual game scale, including neighboring machines, before committing
  to detailed modeling. Retain one fixed, game-applicable view.

Existing rectangles are current-state facts, not exceptions silently approved for
the new plan. Analytical Engine is currently 4×2 and network instruments 3×2; they
remain unchanged until a separately authorized resize. Cables keep their current
1×1 tiles and connectivity shapes.

## 4. Revised square-footprint proposal

Sizes below are **occupied tiles**, not canvas dimensions, and are not implemented.
Current sizes in this historical table are the pre-redo prototype baseline.
See the revision-04 page for the four newly selected sizes. All targets are square.
The previously discussed progression and selective monumentality are retained;
rectangular targets have been replaced by square candidates.

### Research, compute and AI

| Machine | Current | Proposed target | Role / distinction |
|---|---:|---:|---|
| Analytical Engine | 4×2 | **4×4** | Early mechanical workshop; a foothold, not an early megaproject |
| Tube Mainframe | 2×2 | **5×5** | Substantial valve/relay installation |
| Mainframe Cluster | 2×2 | **7×7** | Multiple logic banks with genuine service structure |
| Datacenter Lab | 2×2 | **9×9** | Research facility, distinct from the compute-provider hall |
| Cryostat | 2×2 | **7×7** | Cryogenic research equipment with believable service plant |
| Metrology Lab | 3×3 | **7×7** | Precision inspection/handling facility, readable optics and stages |
| Server Rack | 3×3 | **3×3** | Compact modular compute building block |
| Memory Bank | 3×3 | **5×5** | Storage/memory installation, not another GPU hall |
| Datacenter provider | 3×3 | **11×11** | Actual computing hall, worthwhile alternative to individual racks |
| Training Cluster | 3×3 | **9×9** | Dense GPU rack aisles, fabric and heavy power/cooling infrastructure |
| Inference Lab | 3×3 | **7×7** | Distinct model-serving architecture and processing banks |
| Answer Engine | 5×5 | **17×17** | Monumental endgame installation, visibly the culmination of the factory |

### Silicon production and assembly

| Machine | Current | Proposed target |
|---|---:|---:|
| Crystal Puller | 3×3 | **5×5** |
| Circuit Assembler | 3×3 | **5×5** |
| Computer Assembler | 3×3 | **7×7** |
| Assembly Fab | 3×3 | **9×9** |
| Wafer Fab | 3×3 | **9×9** |
| VLSI Fab | 3×3 | **13×13** |
| Quantum Fab | 3×3 | **11×11** |
| Cooling Tower | 3×3 | **7×7** |

### Connectivity and utilities

| Machine/group | Current | Proposed target |
|---|---:|---:|
| Four cable tiers | 1×1 each | **Keep 1×1** |
| QLN import/export/provider/requester nodes | 1×1 each | **Keep 1×1** |
| Wireless Access Point | 1×1 | **Keep 1×1** |
| Network Switch / Router / Monitor | 3×2 each | **3×3 each**, future proposal only |
| QLN Terminal | 1×1 | **Keep 1×1 — approved and protected by the later request** |
| FOUP Dock | 1×1 | **2×2** |
| QLN Storage Drive | 2×2 | **3×3** |
| Quantum Entanglement Core | 2×2 | **5×5** |
| Construction Core | 2×2 | **5×5** |

Small connectors should contrast with the large facilities. Making every logistics
node enormous would add routing friction rather than industrial scale. Proposed
future square network instruments do **not** authorize touching prior batches now.

## 5. Circuit Assembler redesign brief

### Feedback on the installed design

The circular objects are intended as tape reels, not cooling fans. They do not
read clearly, and the user reports apparent collisions/overlaps around them and
the working machinery. Treat this as a failed visual-readability/clearance result,
not as a claim that a particular prototype collision-box bug has been diagnosed.
Do not defend an unreadable mechanism merely because its modeled function has a
name. The current gantry loop is insufficiently compelling.

### Proposed replacement

- A square **5×5 robotic production cell**, no fans or fan-like decorative rotors.
- One or two substantial articulated arms over an open, central board fixture.
- Clearly separated arm sweep volumes, component magazines and loading/discharge
  pockets. Feeders should be visibly connected, not ambiguous circles at corners.
- A suggested loop: **feed → grab → swing → place → clamp/inspect → discharge and
  return**. Use anticipation, acceleration, brief working dwells and weighty returns.
- Stage the two arms rather than mirroring every movement simultaneously. Keep
  the useful operation visible and the idle pose deliberate.
- Stylistic exaggeration is welcome: an oversized gripper, pneumatic clamp or
  small soldering action may communicate more than a physically literal tiny tool.
- Check clearances over the **whole cycle**, including props, rails, arms, fixtures,
  hoses and product. Use a swept-envelope/contact-sheet review, not frame zero only.
- Effects and component motion stop in idle; idle remains unlit. Native crafting
  remains the activity source unless a separately justified design requires more.

### Optional miniature component library — small effort only

The user suggested having chip/chiplet/GPU/item models that can appear inside an
assembly animation. This is desirable polish, **not a prerequisite or a new major
asset project**.

- Begin with at most a few reusable low-poly props: a generic die/chiplet, a packaged
  chip, and a small PCB/board. A GPU/accelerator board is a later-use candidate.
- A visible part may be picked from a magazine, transferred to the workholder,
  seated under a clamp, and carried out as a populated board. Reuse meshes/materials
  already needed by machines wherever possible.
- Keep a tiny time box: one short modeling/detail pass, not a separately rendered
  icon overhaul or comprehensive model of every module generation.
- Do not show a GPU being made by an early assembler if its recipe/technology does
  not support that story. Generic components are enough for a shared animation.
- Use these as **Blender geometry baked into the machine sprite**. Do not create
  runtime item entities, inventories, logistics, physics or per-tick rendering for
  each decorative part.
- No promise of recipe-specific sprite variants, a new item-production animation
  system, or one export per craftable item. Skip the props if they do not remain
  legible at game scale or threaten the main mechanism's schedule.
- Existing work already contains simple package/board geometry; this idea does not
  mean a finished, shared item-model library exists yet.

## 6. Distinct AI architecture and GPU consistency

### Training Cluster — GPU computing hall

Replace the small board with four corner fans by a **9×9 square facility** containing
parallel rows of recognizable GPU/accelerator cabinets, rack-height structure,
interconnect bridges, power buses and coolant headers. Open aisles/cutaways expose
the expensive hardware. Its mass should come from several deep equipment banks,
not a stretched PCB or a closed, featureless roof. Cooling motion is appropriate
when the relevant mechanism is visible; rack activity should be distributed.

### Inference Lab — model-serving engine

Use a **7×7 square facility** with a dominant model-storage/cartridge structure and
separate upright processing banks or serving islands. Distinct input/output paths,
stage indicators and a different roof/height hierarchy should distinguish it from
the training hall in grayscale. It must not be the same rack layout recolored
purple. The exact silhouette remains to be sketched; a featureless glowing sci-fi
orb is not the desired substitute for readable computing equipment.

### What the existing game actually provides

- `supercomputer` includes an `accelerator-board`, `gpu`, and `ddr3-module`.
- Inference Lab currently costs one `supercomputer`; GPU-related visual hardware
  therefore has a concrete ingredient connection.
- Training Cluster currently costs **two `server` items**, not GPUs or
  supercomputers. Revising that construction recipe is a **proposal** to evaluate,
  not a change already made.
- `machine-learning` currently requires `quantum-advantage`, so the AI buildings
  are already gated after GPU availability. Do not assume earlier GPU/HBM access
  when changing gates or introducing early tiers.
- Both AI facilities currently consume/use **network-provided compute**, rather
  than acting as additional compute providers. Artwork or recipe props must not
  silently grant extra compute or count the same hardware twice.
- Keep the Datacenter provider's actual compute-supply role distinct from the
  Datacenter Lab's research role and the AI facilities' workloads.

## 7. Ethernet-style lighting language

Apply the common language to the next authorized Monitor/network work. Leave
previous batches and installed network/logistics artwork untouched for now;
retrofits need their own approval. This is not an instruction to make every
factory machine blink like a switch.

- Recognizable recessed Ethernet-like port blocks, stable green link indicators,
  and short irregular amber/green activity bursts. Optional fiber accents should
  remain restrained and secondary.
- Different ports have different phases and burst lengths; avoid uniform breathing,
  synchronized rows or a neon wash over the whole object.
- Distinguish disconnected/idle, online/link, and activity states. Do not keep a
  disconnected machine advertising activity.
- "Random-looking" need not mean uncontrolled randomness: use deterministic
  per-port patterns/seeds so loops are reproducible and multiplayer behavior is
  not made nondeterministic.
- Gate the pattern with actual available state. Where the runtime only knows
  connectivity, an online decorative burst is **not packet-count/throughput
  telemetry** and must not be presented as such. Do not invent expensive traffic
  instrumentation just to animate lights.
- Working/idle states remain distinct. Preserve the intended unlit disconnected
  state; any persistent online link light is an explicit online state, not a
  forgotten emissive idle bulb.

## 8. Size balance before art production

Monumentality should create a satisfying computing campus, not a tedious area tax.

1. Preserve a manageable early-game workshop before demanding megaprojects.
2. Decide footprint, construction cost, throughput/capacity, power and cooling
   **separately**. Do not multiply every statistic by footprint area.
3. Give consolidated Datacenters a worthwhile density/service advantage over an
   equivalent rack installation, without selecting arbitrary multipliers yet.
4. Let scale imply usable subsystems: loading/handling space, rack aisles, cooling
   and power distribution, process chambers and maintenance clearances.
5. Plan perimeter network attachment and logistics access. Do not strand a machine
   behind decorative services or require a preferred rotated front to connect it.
6. Update real selection/collision bounds, grid placement, fluid connectors and
   network footprint logic together when a resize is eventually authorized. A big
   sprite over the old tiny collision box is not a size rebalance.
7. Make separate plans for fresh maps and existing saves. Enlarging placed entities
   in place can overlap neighboring infrastructure; no automatic destructive
   relocation/removal policy has been approved.
8. Validate three layout sketches before detailed models: an early electronics
   workshop, a midgame wafer block, and a late-game GPU/datacenter campus. Include
   actual transport/power/cooling access and one-camera occlusion checks.

## 9. Proposed next decisions, not a work order

- Approve or amend the square target table and the three representative layouts.
- Decide capacity/power/cooling/construction-cost targets for those footprints.
- Confirm the Circuit Assembler arm sequence and the two AI silhouette sketches.
- Agree on migration boundaries and exactly which assets may be revised next.
- Only then implement sizes, validate placement/connectivity, and produce new art.

The external references, installed Batch 5 implementation, candidate redesigns and
optional prop polish are deliberately kept separate. None of the proposed changes
in this document were executed merely by recording the original discussion. The
subsequent four-machine redo is separately scoped in the revision-04 page.
