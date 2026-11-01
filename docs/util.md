# Chiptorio — scripts/util.lua reference

`scripts/util.lua` provides shared helpers used by the data stage and runtime. It is not a prototype module itself; every consumer requires it explicitly from its load-stage entrypoint.

## Helpers

### `M.copy(prototype)`
Deep-copies a Factorio prototype table. Used to clone base entities (labs, labs, accumulators, pipes) before mutating them into Chiptorio machines. Never mutates the source.

### `M.set_icon(item_or_entity, name)`
Sets the icon path to `__chiptorio__/graphics/icons/<name>.png` for an item or entity prototype.

### `M.set_entity_icon(entity, name)`
Sets an entity prototype's icon using the standard icon path convention.

### `M.set_custom_animation(entity, name, size_w, size_h, scale, shift)`
Applies a hand-drawn or rendered sprite sheet as an entity's `on_animation`/`off_animation`. Used by providers that do not use the Blender pipeline.

### `M.tint_animation(animation, tint)`
Tints an animation's layers by a color table. Used for cable tier variants and provider color-coding.

### `M.item_exists(name)`
Checks `data.raw.item[name]` safely; returns nil if absent. Used instead of direct `data.raw.item` access for chips and memory modules.

### `M.recipe({name, enabled, energy_required, ingredients, results})`
Registers a recipe with positional ingredient handling consistent with Factorio 2.1. Wraps `data:extend({ { type = "recipe", ... } })`.

## Usage rules

- Require `scripts.util` once per module that needs it; do not create module-level globals for it.
- Clone base prototypes with `M.copy` before editing; never mutate `data.raw` base prototypes directly.
- Recipes must use `M.recipe`, not raw `data:extend` recipe tables, to keep ingredient positioning and category validation consistent.
- Chips and memory modules are `module` prototypes; check existence with `M.item_exists`, never `data.raw.item`.
