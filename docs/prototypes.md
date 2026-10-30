# Chiptorio — Prototypes and Load-Stage Rules

## Load-stage order

`data.lua` is order-sensitive:

1. Items and fluids
2. Machines and labs
3. Recipes and technologies

`data-updates.lua` is only for vanilla mutations after all mods load.

`data.lua` must keep `require("scripts.network")`. The `internet` technology
unlocks `network-cable`, `network-switch`, `network-router` and
`network-monitor` by recipe name, so omitting the module fails map creation
with `recipe with name 'network-cable' does not exist`.

## Prototype conventions

### Chips and memory modules

Chips and memory modules are `module` prototypes (category
`chiptorio-chip` / `chiptorio-memory`, `effect = {}`), because a provider's
module inventory is the only machine-readable "what is installed" surface.
They live in `data.raw.module`; check items with `M.item_exists`, not
`data.raw.item`.

### Compute providers

Compute providers (`server-rack`, `memory-bank`, `datacenter`) are lab clones
with `inputs = {}` and `researching_speed = 0.001`. Do not give them science
packs — that would turn them into ordinary labs. Never set `allowed_effects`
on a lab clone — it is an `EffectTypeLimitation`, and a boolean map fails to
load.

### Metrology Lab

The Metrology Lab is a lab clone: its inputs are the ten Process Qualification
Wafers, `module_slots = 0`, generated in `scripts/metrology.lua` from
`process_nodes.HALF_NODES`. A pilot recipe runs in the refined node's fab
category and must stay unlocked by its `refine-*` technology, never enabled at
start. The 6 µm and 1.5 µm refinements must stay offline; from 800 nm the lab
needs a network gate.

### FOUP Dock

The FOUP Dock is a container with a relative mode panel
(`defines.relative_gui_type.item_with_inventory_gui`, position right) rather
than a screen frame. It is deliberately absent from `QLN_NODE_NAMES` in
`qln_runtime.lua`; `dock_accepts` / `dock_outputs` give Import and Export
Nodes mode-aware direction. A sealing dock takes `foup` and
`node-*-wafer` and exports `foup-sealed-*`; an unsealing dock does the
reverse. Never remove those filters.

### Vanilla science packs

Keep the six vanilla science-pack internal names and change only their
localised names and recipes, or the vanilla tech tree breaks. See DESIGN §4.3
for the mapping.

### Network entities

`scripts/network.lua` defines cable tiers (twisted pair, coaxial, multi-mode
fiber, single-mode fiber), 3×2 rotatable switches and routers. Cables collide
with everything — they cannot be placed on machines or belts, and nothing can
be placed on them. Switches merge cable segments; routers bridge segments and
act as WiFi access points with 16-tile reach. Cables are `pipe` clones only
for connection-aware auto-tiling: sixteen one-tile sprites live in
`graphics/entity/cable/`, tinted per tier, and `fluid_box.pipe_covers` stays
nil so no vanilla pipe segment leaks in.

## Module requirements

Every `scripts/*.lua` module must be explicitly required from a load-stage
entrypoint; the directory is not auto-loaded. Require each module once, from
the stage that owns it.

## 2.1 API traps (DESIGN §15)

1. Recipe `categories` versus `category` (plural vs singular)
2. No fluid ingredients in the `crafting` category
3. Positional technology ingredients
4. `icon` versus `icons`
5. `__1__` locale placeholders (not `%s`)

## Process nodes

`scripts/process_nodes.lua` is pure and is the single source of truth for the
twelve process nodes, ten half-nodes, node item names, die yields and the
half-node bonus. `scripts/node_items.lua` and `scripts/node_recipes.lua`
generate prototypes from it, and `scripts/technology.lua` only supplies
tech-tree position and cost. Internal keys must be prototype-safe
(`1-4nm`, not `1.4nm`); keep the dotted label in the locale.

## Pruning

`scripts/prune.lua` removes enemies, robots, and combat. It hides prototypes
and disables recipes instead of deleting them, because deleting an item means
scrubbing every prototype that references it. It then removes empty
technologies and rewires prerequisites. Add new removals to the tables in that
module, not ad-hoc loops in `data-updates.lua`.

Enemies are disabled by clearing `autoplace` on the base spawner and worm
prototypes. Do not delete the `enemy-base` autoplace control — the base planet
map-generation tables still reference it.

## Art

Prototypes are cloned and tinted from base entities via `scripts/util.lua`;
do not add custom entity art.
