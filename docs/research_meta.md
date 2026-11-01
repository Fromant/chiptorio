# Chiptorio — scripts/research_meta.md

`scripts/research_meta.lua` is the single source of truth for lab demand, chip and memory profiles, provider slots, and every technology gate. It is pure: it reads no `game`, `storage`, or prototypes, and is loaded by both the data stage and runtime.

## Contents

- **Lab demand** — per-technology compute, memory, and bandwidth requirements.
- **Chip profiles** — compute contribution of each chip/module type installed in a provider.
- **Memory profiles** — capacity contribution of each memory module generation.
- **Provider slots** — `computer_slots` and `memory_slots` per provider (`server-rack`, `memory-bank`, `datacenter`, etc.).
- **Technology gates** — which technologies unlock which providers, recipes, and QLN capabilities.
- **`RACK_VARIANTS`** — `{"server-rack", "server-rack-east", "server-rack-south", "server-rack-west"}`; every variant maps back to `server-rack` for profile lookup.

## Usage

- The data stage consumes profiles to build provider prototypes (`scripts/providers.lua`).
- `scripts/runtime/research_alloc.lua` (pure allocator) reads demand and profiles to compute per-force research feasibility.
- `scripts/runtime/research_runtime.lua` (the only research module that touches entities and `storage`) pauses labs with `disabled_by_script` and applies decay.
- Never duplicate profile data in `technology.lua` or runtime modules; `research_meta.lua` is authoritative.

## Purity requirement

`research_meta.lua` must remain pure: no `game`, no `storage`, no `data.raw` access. If it needs runtime state, that state lives in `storage` and is passed in by `research_runtime.lua`.
