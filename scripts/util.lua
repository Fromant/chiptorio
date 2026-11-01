-- Shared helpers for the data stage.
--
-- Everything here is deliberately built on top of *existing* base prototypes:
-- we deep-copy a known-good prototype and only replace the identity fields.
-- That way we never have to guess at icon_path / icon_size / sprite layout,
-- which is the usual source of "missing sprite" crashes in overhaul mods.

local M = {}

local deepcopy = (util and util.table and util.table.deepcopy) or table.deepcopy

function M.copy(value)
  return deepcopy(value)
end

--- Copy a base item prototype into a new item.
--- base_name: existing item to inherit from (picks up stack_size, flags, ...)
--- name:      new prototype name
--- subgroup:  item subgroup to place it in
--- order:     optional sort order inside the subgroup
function M.item_proto(base_name, name, subgroup, order)
  local base = data.raw.item[base_name]
  if not base then
    error("chiptorio: base item '" .. tostring(base_name) .. "' not found")
  end

  local proto = deepcopy(base)
  proto.name = name
  proto.localised_name = nil
  proto.localised_description = nil
  proto.factoriopedia_description = nil
  proto.subgroup = subgroup
  proto.order = order or ("z[" .. name .. "]")
  proto.hidden = false
  proto.hidden_in_factoriopedia = false

  -- never leak placement behaviour from the base item
  proto.place_result = nil
  proto.place_as_equipment_result = nil
  proto.place_as_tile = nil

  proto.icons = deepcopy(base.icons or { { icon = base.icon, icon_size = base.icon_size } })
  proto.icon = nil
  proto.icon_size = nil

  return proto
end

function M.item_from(base_name, name, subgroup, order)
  local proto = M.item_proto(base_name, name, subgroup, order)
  data:extend({ proto })
  return proto
end

--- Copy a base item into a module prototype. Modules live in `data.raw.module`,
--- so the type has to be set *before* `data:extend`, unlike an item tweak.
--- The effect is deliberately empty: a chip's gameplay value is read by the
--- research runtime, not by the vanilla module effect maths.
function M.module_from(base_name, name, category, tier, subgroup, order)
  local proto = M.item_proto(base_name, name, subgroup, order)
  proto.type = "module"
  proto.category = category
  proto.tier = tier
  proto.effect = {}
  proto.effect_description = nil
  data:extend({ proto })
  return proto
end

--- True for anything a recipe, lab input or technology can name as an item.
--- Modules are items in the ingredient sense but live under `data.raw.module`,
--- so a plain `data.raw.item[name]` check is wrong for chips.
function M.item_exists(name)
  if not name then
    return false
  end
  if data.raw.item and data.raw.item[name] then
    return true
  end
  if data.raw.module and data.raw.module[name] then
    return true
  end
  if data.raw.tool and data.raw.tool[name] then
    return true
  end
  return false
end

--- Point an item prototype at one of the generated 64x64 icons.
function M.set_icon(proto, icon_name, size)
  proto.icon = nil
  proto.icon_size = nil
  proto.icons = {
    {
      icon = "__chiptorio__/graphics/icons/" .. icon_name .. ".png",
      icon_size = size or 64,
    },
  }
end

--- The same icon with a colour tint. Used to give a dozen process nodes a
--- distinct look without a dozen hand-drawn PNGs.
function M.set_tinted_icon(proto, icon_name, tint, size)
  proto.icon = nil
  proto.icon_size = nil
  proto.icons = {
    {
      icon = "__chiptorio__/graphics/icons/" .. icon_name .. ".png",
      icon_size = size or 64,
      tint = tint,
    },
  }
end

--- Entities and fluids use the single `icon` field, not `icons`.
function M.set_entity_icon(proto, icon_name)
  proto.icons = nil
  proto.icon = "__chiptorio__/graphics/icons/" .. icon_name .. ".png"
  proto.icon_size = nil
end

local TINT_SKIP = {
  "shadow",
  "light",
  "smoke",
  "reflection",
  "corpse",
  "remnant",
  "explosion",
  "fire",
  "glow",
}

local function tint_sprite(sprite, color)
  if type(sprite) ~= "table" then
    return
  end
  if sprite.layers then
    for _, layer in ipairs(sprite.layers) do
      tint_sprite(layer, color)
    end
    return
  end
  if type(sprite.filename) ~= "string" then
    return
  end
  local filename = string.lower(sprite.filename)
  for _, skip in ipairs(TINT_SKIP) do
    if string.find(filename, skip, 1, true) then
      return
    end
  end
  if not sprite.tint then
    sprite.tint = color
  end
end

--- Recolour a machine's main animation. Working visuals (smoke, flames,
--- fluid overlays) are deliberately left alone so machines still read as
--- themselves.
function M.tint_entity(entity, color)
  local animation = entity.graphics_set and entity.graphics_set.animation
  if not animation then
    return
  end
  tint_sprite(animation, color)
  for _, direction in ipairs({ "north", "south", "east", "west" }) do
    if animation[direction] then
      tint_sprite(animation[direction], color)
    end
  end
end

--- Recolour a lab-style animation (on_animation / off_animation), which uses
--- `layers` directly instead of a graphics_set.
function M.tint_animation(animation, color)
  if type(animation) ~= "table" then
    return
  end
  if type(animation.layers) == "table" then
    for _, layer in pairs(animation.layers) do
      layer.tint = color
    end
  end
end

--- Recolour every sprite in a connection-aware picture table (PipePictures and
--- similar structs). Auto-tiling entities keep one sprite per connection shape,
--- so tinting a single `picture` is not enough.
function M.tint_pictures(pictures, color)
  if type(pictures) ~= "table" or not color then
    return pictures
  end
  for _, sprite in pairs(pictures) do
    tint_sprite(sprite, color)
  end
  return pictures
end

--- Return a deep copy of a base entity's static world sprite, ready to be used
--- as a container clone's `picture`. Different prototype types keep their
--- visual in different fields, so the helper looks in every place the base game
--- actually uses:
---   * `picture` / `picture_off` / `picture_on` - chests and lamps
---   * `sprites.north` - combinators and display panels
---   * `pictures.straight_vertical_single` / `pictures.north` - connection-aware
---     donors, of which only the single-tile sprite is taken
---   * `animation` / `graphics_set.animation` - machines
--- The copy is tinted unless `tint` is nil, so callers never mutate a donor.
function M.world_sprite(proto, tint)
  if type(proto) ~= "table" then
    return nil
  end

  local sprite
  for _, key in ipairs({ "picture", "picture_off", "picture_on" }) do
    if proto[key] then
      sprite = proto[key]
      break
    end
  end
  if not sprite and type(proto.sprites) == "table" then
    sprite = proto.sprites.north or proto.sprites.east
  end
  if not sprite and type(proto.pictures) == "table" then
    sprite = proto.pictures.straight_vertical_single or proto.pictures.north
  end
  if not sprite and type(proto.animation) == "table" then
    sprite = proto.animation.north or proto.animation
  end
  if not sprite and type(proto.graphics_set) == "table" then
    local animation = proto.graphics_set.animation
    if type(animation) == "table" then
      sprite = animation.north or animation
    end
  end
  if not sprite then
    return nil
  end

  local copy = deepcopy(sprite)
  if tint then
    tint_sprite(copy, tint)
  end
  return copy
end

--- Set a container clone's picture from a donor prototype, failing loudly at
--- the data stage instead of shipping an invisible entity.
function M.set_world_picture(entity, donor, tint)
  local picture = M.world_sprite(donor, tint)
  if not picture then
    error("chiptorio: donor prototype '" .. tostring(donor and donor.name) .. "' has no world sprite")
  end
  entity.picture = picture
end

--- Set a container's world picture to a generated entity sprite in
--- graphics/entity/<name>.png. The width/height must match the PNG; scale
--- shrinks the sprite onto the tile footprint.
function M.set_custom_picture(entity, name, width, height, scale, shift)
  entity.picture = {
    filename = "__chiptorio__/graphics/entity/" .. name .. ".png",
    width = width,
    height = height,
    scale = scale or 0.5,
    shift = shift or { 0, 0 },
  }
end

--- Set an assembling-machine / furnace graphics_set animation to a generated
--- entity sprite, replacing the cloned base sprite entirely.
function M.set_custom_graphics(entity, name, width, height, scale, shift)
  local gs = entity.graphics_set or {}
  gs.animation = {
    filename = "__chiptorio__/graphics/entity/" .. name .. ".png",
    width = width,
    height = height,
    scale = scale or 0.5,
    shift = shift or { 0, 0 },
  }
  entity.graphics_set = gs
end

--- Set a lab clone's on_animation and off_animation to a generated entity
--- sprite, replacing the cloned base animation entirely.
function M.set_custom_animation(entity, name, width, height, scale, shift)
  local sprite = {
    filename = "__chiptorio__/graphics/entity/" .. name .. ".png",
    width = width,
    height = height,
    scale = scale or 0.5,
    shift = shift or { 0, 0 },
  }
  entity.on_animation = sprite
  entity.off_animation = sprite
end

--- Set an accumulator clone's chargable_graphics (picture / charge /
--- discharge) to a generated entity sprite.
function M.set_custom_accumulator(entity, name, width, height, scale, shift)
  local sprite = {
    filename = "__chiptorio__/graphics/entity/" .. name .. ".png",
    width = width,
    height = height,
    scale = scale or 0.5,
    shift = shift or { 0, 0 },
  }
  local cg = entity.chargable_graphics or {}
  cg.picture = sprite
  cg.charge_animation = sprite
  cg.discharge_animation = sprite
  entity.chargable_graphics = cg
end

--- Build a from-scratch assembling-machine prototype for Chiptorio devices
--- that are not factories: compute providers, qualification stations, QLN
--- storage nodes, the Answer Engine, etc.
---
--- Unlike cloning `data.raw.lab["lab"]` or `data.raw["assembling-machine"][...]`,
--- this sets every field explicitly so there is no inherited baggage:
--- no research inputs, no researching_speed, no unwanted crafting categories,
--- no base-prototype animation clock, no module-effect limits.
---
--- Fields set explicitly:
---   * identity: type, name, localised_name, localised_description
---   * placement: minable, placeable_by, next_upgrade, fast_replaceable_group
---   * visuals: corpse, hidden, hidden_in_factoriopedia, graphics_set
---   * physics: collision_box, selection_box, drawing_box_vertical_extension,
---     tile_width, tile_height
---   * power: energy_usage, energy_source (electric with drain)
---   * crafting: crafting_categories = {"crafting"}, crafting_speed = 0.001
---     (Factorio requires a category and positive speed; 0.001 is effectively
---     no crafting)
---   * modules: module_slots, allowed_module_categories, allowed_effects = nil
---   * inputs: optional list of input item names (for metrology-lab wafers)
---   * misc: max_health, working_sound, water_reflection, icons_positioning
function M.make_provider_base(spec)
  local entity = {
    type = "assembling-machine",
    name = spec.name,
    localised_name = spec.localised_name,
    localised_description = spec.localised_description,
    minable = spec.minable or { mining_time = 0.5, result = spec.name },
    placeable_by = spec.placeable_by or { item = spec.name, count = 1 },
    next_upgrade = nil,
    fast_replaceable_group = spec.fast_replaceable_group,
    hidden = spec.hidden or false,
    hidden_in_factoriopedia = spec.hidden_in_factoriopedia or false,
    corpse = nil,
    dying_explosion = spec.dying_explosion,

    -- No crafting: this is a network/compute device, not a factory.
    -- Factorio requires a non-empty category and positive speed on
    -- assembling-machines. We use the vanilla "crafting" category with a
    -- near-zero speed so no recipe can ever complete in practical time.
    crafting_categories = { "crafting" },
    crafting_speed = 0.001,

    -- Module slots (0 for pure devices, >0 for providers/storage nodes).
    module_slots = spec.module_slots or 0,
    allowed_module_categories = spec.allowed_module_categories or {},
    -- Modules in Chiptorio have empty effect tables, but Factorio requires
    -- allowed_effects to be non-empty when module_slots > 0.
    allowed_effects = spec.allowed_effects or { "consumption" },

    -- Electric power.
    energy_usage = spec.energy_usage,
    energy_source = {
      type = "electric",
      usage_priority = spec.usage_priority or "secondary-input",
      drain = spec.drain or "0kW",
    },

    -- Graphics.
    graphics_set = spec.graphics_set,

    -- Entity icon (single-string form, used by entities).
    icon = spec.icon or ("__chiptorio__/graphics/icons/" .. spec.name .. ".png"),
    icon_size = spec.icon_size or 64,

    -- Physics.
    collision_box = spec.collision_box or { { -0.9, -0.9 }, { 0.9, 0.9 } },
    selection_box = spec.selection_box or { { -1, -1 }, { 1, 1 } },
    drawing_box_vertical_extension = spec.drawing_box_vertical_extension,
    tile_width = spec.tile_width,
    tile_height = spec.tile_height,

    -- Optional overrides.
    max_health = spec.max_health,
    working_sound = spec.working_sound,
    water_reflection = spec.water_reflection,
    icons_positioning = spec.icons_positioning,
    inputs = spec.inputs,
  }

  -- Remove nil fields so Factorio doesn't choke on them.
  for k, v in pairs(entity) do
    if v == nil then
      entity[k] = nil
    end
  end

  return entity
end

--- Shortcut for a crafting recipe.
--- 2.1 merged RecipePrototype.category into a `categories` list, so accept
--- the friendlier single-category form here.
function M.recipe(spec)
  spec.type = "recipe"
  spec.energy_required = spec.energy_required or 1
  if spec.category then
    spec.categories = { spec.category }
    spec.category = nil
  end
  data:extend({ spec })
  return spec
end

--- Icons for a new technology, cloned from an existing technology so the
--- 480x256 / 256x256 tech icon conventions are always correct.
function M.tech_icons(from)
  local source = data.raw.technology[from] or data.raw.technology["electronics"]
  if not source then
    error("chiptorio: no technology available to clone icons from")
  end
  return deepcopy(source.icons or { { icon = source.icon, icon_size = source.icon_size } })
end

--- Add one ingredient to an existing recipe, if the recipe exists.
function M.add_ingredient(recipe_name, ingredient)
  local recipe = data.raw.recipe[recipe_name]
  if not recipe or not recipe.ingredients then
    return false
  end
  table.insert(recipe.ingredients, ingredient)
  return true
end

--- Append a prerequisite to a technology, if it exists and is not already there.
function M.add_prerequisite(tech_name, prereq)
  local tech = data.raw.technology[tech_name]
  if not tech then
    return false
  end
  tech.prerequisites = tech.prerequisites or {}
  for _, existing in pairs(tech.prerequisites) do
    if existing == prereq then
      return false
    end
  end
  table.insert(tech.prerequisites, prereq)
  return true
end

M.item = function(name, amount)
  return { type = "item", name = name, amount = amount }
end

M.fluid = function(name, amount)
  return { type = "fluid", name = name, amount = amount }
end

return M
