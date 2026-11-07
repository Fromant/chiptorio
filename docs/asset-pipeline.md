# Shared asset production pipeline

One workflow for **every batch**: entities, icons, technology images, shared cable
shapes and presentation art. Planning is `tools/asset-studio/assets.json` (223
editable assets, 46 stable batch identities at migration). References are read-only;
tinted cable tiers share their underlying shape assets.

## Model-first iteration

For geometry or motion revisions, stop before rendering the animation:

1. Use **Build model only (no animation render)** in Production tools, or run
   `npm run pipeline -- build --asset=entity:wafer-fab --model-only`.
   This builds a staged `.blend` and checks geometry, loop closure, idle emission
   and the complete footprint envelope. It creates no shipping sprites.
2. Review one model at a time under **Model and motion**. Download the `.blend`
   or open it in Blender, play/scrub the timeline and inspect contacts and handoffs.
   Camera view is Numpad 0. Open uses a disposable inspection copy; edits there
   do not update the authoring source or mutate the cached model.
3. **Quick camera still** renders one low-sample game-camera image. The result
   appears in Tool activity; it does not render an animation or install anything.
4. **Request model changes** records feedback. **Model looks good** accepts only
   that model/source revision; it does not approve sprites or start rendering.
5. **Render final animation** is a separate action after model acceptance.
   It reuses the checked model cache. Review final sprites separately, then use
   the existing isolated validation and publication gates.

Do not run full animation renders during model iteration before the user accepts
the model. Existing renders retain their Blender downloads and feedback under
**Previously reviewed assets - Blender files and feedback**. Source, descriptor
or model changes invalidate model acceptance. Model approval is independent of
shipping-art approval and cannot publish files. Image-only assets use PNG review.

## Final-art workflow

From `tools/asset-studio`, run `npm run dev`, open **http://127.0.0.1:4173** and
review the **Review finished assets** queue. It shows one current full-quality,
unreviewed individual asset at a time. Approving or requesting changes saves the
decision and advances to the next; **Skip to next asset** defers a decision.
Drafts, bundles, superseded versions, stale sources and reviewed assets stay out
of this queue. No review history or artifacts are deleted.

Build/source controls and candidate history are under **Production tools**.
Installed graphics and references are behind **Browse installed assets and
references**. Select a batch or asset for production; there is no rebuild-all.

1. **Configure/edit.** `Scaffold model.py` creates source under
   `tools/graphics/assets/`, never installed art. Replace its placeholder and clear
   `source.placeholder`. Source descriptors are editable in the UI. Protected art
   requires an explicit unlock with a reason; previous batches never auto-unlock.
2. **Optional draft.** Reduced samples/frames at the actual camera and physical
   scale. Drafts cannot be approved or published.
3. **Build review candidate.** Immutable full-quality PNGs and Lua definitions.
   Compare installed/candidate working and idle states at the same world scale;
   pause, scrub frames, inspect footprints and individual publication files.
4. **Request changes / approve exact revision.** Approval binds to the complete
   manifest hash and installs nothing. Source, descriptor and artifact changes
   cannot inherit approval.
5. **Validate in isolated Factorio.** Copy the mod/test tools, overlay the exact
   approved bytes and run all six suites. No player save is loaded. Subsequent
   repository/source/target changes invalidate validation.
6. **Explicit publish.** Confirm the exact revision. Copy those same artifacts,
   without Blender/render/repack; lock published assets, refresh installed
   prototypes and offline inventory.

Multi-asset builds also create a **batch candidate** with per-member comparisons:
approve once, validate once, publish the entire set transactionally. Individual
candidates remain available for selective review. Only one revision per asset
can belong to a batch candidate.

## Authoring contract

`source.format` adapters:

| Format | Fields | Input |
|---|---|---|
| `python` | `builder`, optional `dependencies` | Module exporting `build(w)` using shared `Workshop` |
| `legacy-builder` | `builder`, `model` | Existing builder, executed only in a private source snapshot |
| `blend` | `model`, optional `dependencies` | Copied native model; never saved over its source |
| `image` | `image` | Authored PNG; exact declared dimensions/bytes |
| `unconfigured` | — | Planning only; never silently treats installed art as a new design |

New Python modules need **no batch allowlist edits**:

```python
def build(w):
    w.base(2.8)
    # Add the real design, meaningful motion and state-gated emission here.
    return [3, 3], .65, 4  # occupied tiles, camera target height, legacy ortho hint
```

Declare custom imported modules/data in `source.dependencies`; shared Python
helpers and implicit legacy imports are snapshotted/hashed automatically. Builders
are trusted local authoring code, **not an OS sandbox**. Never use absolute
production write paths. Blender sources use the standard collections/camera rig
from `Workshop`; retain those when supplying an edited `.blend`.

Entity scene/descriptor footprints and periods must agree. One unit = one tile;
64 rendered pixels/tile, Factorio scale 0.5. Automatic canvas enlargement never
shrinks physical machinery. Checks cover loop closure, zero idle emission,
whole-cycle floor envelope, alpha/clipping, shadows, origin alignment, changed
frames and atlas limits; detailed legacy motion validators remain active.

Image/cable/presentation outputs require `render.width`/`height`. `fit: "canvas"`
preserves connector-sensitive framing; other Blender images can be trimmed and
uniformly fitted. PNG source intake preserves exact bytes and dimensions.

## Explicit gameplay ownership

Modes: `native-crafting`, `native-lab`, `accumulator`, `static`, `scripted`,
`existing-directional`. Static entities have one frame. Scripted art requires an
existing registered `device_visuals` owner; current owners run at 12 fps
(`frames = period / 2`, source rig 24 fps). Unknown activity owners fail closed:
implement gameplay signals deliberately, never infer activity from entity existence.
The directional adapter supports the established server-rack runtime and four views.

`graphics/published-assets.lua` starts empty: the data-stage adapter changes no
installed art until an approved entity binding is published. Binding metadata is
itself reviewed and validated. Recipes, power, compute output and balance are not
changed by the tooling. Enlarging footprints never relocates/deletes existing
entities; fluid connectors require deliberate design when resizing a fluid machine.

## Cache, logs and recovery

Build/render/pack have separate content hashes and completion records. Only
explicitly selected assets run. Repack reuses frames; sample/canvas changes reuse
models. Incomplete/corrupt stages rebuild; verified stages resume. Identical
candidate builds return the same revision. Full logs are files; CLI/UI summaries
and failure excerpts are bounded.

Ignored persistent state: `tools/asset-studio/workspace/` → `steps/`, `candidates/`,
`reviews/`, `validations/`, `published/`, `logs/`, `transactions/`, `validation-runs/`.

Publication checks target baselines, sources, descriptors, approval, artifact
integrity and the tested repository fingerprint. Atomic **per-file** replacements
use durable journals/backups and rollback; the whole operation is not a single
filesystem rename. After a crash use **Recover publication**. Recovery refuses
live publication processes and unrelated user edits. Never delete a lock to bypass
recovery. Separately staged entities may share an old binding-index baseline:
publish their batch candidate together, or rebuild/reapprove the next candidate
after publishing one (cached art is reused).

## CLI and tests

```sh
npm run pipeline -- status
npm run pipeline -- build --batch=batch-6 --draft
npm run pipeline -- build --asset=entity:wafer-fab
npm run pipeline -- build --batch=42
npm test
npm run test:ui
npm run build
npm run test:pipeline:blender
npm run test:pipeline:factorio
```

CLI output contains short stage summaries, revision IDs and review URLs. Visual
approval is recorded in the web app. CLI `validate` requires `--revision=<hash>`;
`publish` also requires `--confirm=<same hash>` and every normal approval gate.

Blender smoke uses a disposable design and proves stage-cache reuse. Factorio
smoke copies existing art into a disposable mod, validates/publishes **only there**,
and checks production art is unchanged. Neither approves production candidates.
Do not run separate Factorio suites concurrently: existing scripts share temp
suite directories. They are reused by Node; no new PowerShell wrappers exist.

`migrate-registry.mjs` is one-time and refuses overwriting the plan. `render:batch5`
and old direct-install instructions are obsolete; the compatibility command refuses
execution. Newly discovered unregistered assets remain explicitly unscheduled.
