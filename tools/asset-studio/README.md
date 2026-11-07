# Chiptorio Asset Studio

React + Vite + Express. Inventory and an approval-gated production pipeline for
every batch: cached staging, exact-artifact review, isolated validation and
transactional publication. No new PowerShell wrappers.

```sh
npm ci
npm run dev
```

**http://127.0.0.1:4173**

```sh
npm run export   # ../../asset-overview.html, fully offline
npm test
npm run build
npm run test:ui
```

[Production workflow](../../docs/asset-pipeline.md) · [Inventory documentation](../../docs/asset-studio.md).
