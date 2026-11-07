# Asset Studio

**Production:** use the [shared approval-gated pipeline](asset-pipeline.md) for all
batches. Drafts/candidates never install; review, approval, isolated validation and
explicit publication are separate stages. Old direct-install commands are obsolete.

A local **React + Vite + Express** application for all Chiptorio graphics.
Node.js 22+ and npm are the only web-app prerequisites. No PowerShell wrapper.

```sh
cd tools/asset-studio
npm ci
npm run dev
```

Open **http://127.0.0.1:4173**. The app listens only on loopback.
`npm run build` followed by `npm start` runs the production build instead.

## Library

- Automatic filesystem rescan every 15 seconds; searchable names, paths and batches.
- Completed render batches, explicitly proposed future batches, and legacy references.
- All PNGs under `graphics/`, plus `thumbnail.png`; all sixteen cable shapes and
  four tinted cable tiers; item/fluid/interface icons; technology and ending art.
- Machine previews use actual prototype layers, scale, shifts, tints and animation
  sheets, including inherited Factorio art. Working/idle, pause, footprint overlay,
  enlarged inspector, and every source sheet are available.
- Previews demonstrate artwork, not a running gameplay simulation. Selection bounds
  are taken from prototypes, not old modeling estimates.
- Unchanged vanilla terrain and native GUI styles are game-provided, not separate
  Chiptorio graphic files. Shared item icons cover custom GUI sprite buttons.

On first launch, Factorio is detected and run headlessly with a disposable mod
snapshot to read `data.raw`. **No player save is opened.** Subsequent launches reuse
`tools/asset-studio/.cache/prototypes.json`. Use **Refresh prototypes** after Lua
prototype changes; ordinary image/model changes appear on automatic rescan.

Factorio detection: `FACTORIO_EXE` environment variable → root `.env` → Steam
libraries/common installation paths → `PATH`. Blender detection uses `BLENDER_EXE`,
installed Blender Foundation directories, and `PATH`. Detected paths are visible
on hover in the sidebar. Node is detected from the running process.

## Blender actions

Production builds use the [shared pipeline](asset-pipeline.md), e.g.
`npm run pipeline -- build --batch=batch-6`. It stages candidates and never
installs. Completed art, including Batch 5 and QLN Terminal, remains locked.
`render:batch5` is disabled. The inventory UI's **Render** button is a separate
preview-only action and never installs or rebuilds an asset.

- **Blender** opens the detected editable `.blend` file in Blender.
- **Render** explicitly starts a low-sample, single fixed game-view preview in a
  disposable cache directory. It does **not** rebuild the model, pack sheets,
  install graphics, or modify gameplay. One tool job runs at a time.
- **Tool activity** shows bounded process logs, failures, and completed preview images.
- Assets without models have no Blender actions. No speculative model generation
  or render is started by scanning or exporting the library.

The server accepts only same-origin JSON actions on loopback and only opens models
found by the asset scanner. It never accepts arbitrary executables or shell commands.
Do not expose this development tool through a public reverse proxy.

## Single-file export

**Export single HTML** downloads a fully offline catalog with embedded images,
animated sheet previews, filters, and batch order. It intentionally has no local
Blender controls: a standalone HTML file cannot launch local tools safely.

```sh
npm run export
```

This writes root **`asset-overview.html`**, with no external scripts, fonts or images.
The app and export share the same catalog builder and batch definitions. The export
includes raw source sheets under expandable details, not only thumbnail images.

## Tests

```sh
npm test
npm run build
npm run test:ui
```

Browser tests use installed Microsoft Edge on Windows when available, otherwise
Playwright Chromium (`npx playwright install chromium`). `PLAYWRIGHT_BROWSER` can
override the browser executable. The web tests do not launch Blender. Test renders
can be requested separately through the explicit local API or UI.

`tools/test-all.ps1` remains the mod's existing headless gameplay verification;
the Node app does not replace or invoke that test harness.
