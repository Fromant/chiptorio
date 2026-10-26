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
function M.item_from(base_name, name, subgroup, order)
  local base = data.raw.item[base_name]
  if not base then
    error("chipotrio: base item '" .. tostring(base_name) .. "' not found")
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

  data:extend({ proto })
  return proto
end

--- Point an item prototype at one of the generated 64x64 icons.
function M.set_icon(proto, icon_name, size)
  proto.icon = nil
  proto.icon_size = nil
  proto.icons = {
    {
      icon = "__chipotrio__/graphics/icons/" .. icon_name .. ".png",
      icon_size = size or 64,
    },
  }
end

--- Entities and fluids use the single `icon` field, not `icons`.
function M.set_entity_icon(proto, icon_name)
  proto.icons = nil
  proto.icon = "__chipotrio__/graphics/icons/" .. icon_name .. ".png"
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
    error("chipotrio: no technology available to clone icons from")
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
