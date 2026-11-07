# Semiconductor machine sources

These are **staged candidates**, not installed or approved art. All five Batch 6
machines use 5×5 foundations and native crafting activity. See
`docs/batch-6-assets.md` and `docs/asset-pipeline.md` from the repository root.

- The per-asset module is the registry's authoring entrypoint (`build(w)`).
- `semiconductor_geometry.py` contains the initial process designs and shared
  prop/motion helpers. Every dependency is explicit in `assets.json`.
- For an individual artistic revision, put the revised `build(w)` implementation
  in **that asset's entrypoint**, importing the unchanged helpers. Do not edit a
  shared factory just to change one asset: that would deliberately invalidate
  every dependent candidate. Existing approved sources must remain reproducible.
- Interlock checks belong with the mechanism. Keep the complete 96-frame loop
  closed; zero idle emission and the 5×5 floor envelope are pipeline requirements.
- Never invoke these modules as canonical-model/direct-install scripts. Use the
  shared pipeline, review exact packed sheets, and wait for user approval.
