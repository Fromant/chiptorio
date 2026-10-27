-- Board ladder: Circuit Assembler, board items, board recipes, vanilla re-theme.
--
-- Runs after items/chips/technologies exist so it can:
--   * re-theme the three vanilla circuit items in place (same internal names)
--   * create new board items (accelerator-board, neural-board, quantum-board)
--   * create/modify board recipes in the chiptorio-circuit category
--   * wire board recipes into gate technology effects

local M = require("scripts.util")
local meta = require("scripts.circuits_meta")

-- ---------------------------------------------------------------------------
-- Recipe category for board assembly.
-- ---------------------------------------------------------------------------

data:extend({
  { type = "recipe-category", name = "chiptorio-circuit" },
})

-- ---------------------------------------------------------------------------
-- Item subgroup for boards.
-- ---------------------------------------------------------------------------

data:extend({
  {
    type = "item-subgroup",
    name = "chiptorio-circuits",
    group = "chiptorio",
    order = "c[circuits]",
  },
})

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function set_item_flavour(proto, board)
  proto.localised_name = { "item-name." .. board.label }
  proto.localised_description = { "item-description." .. board.label }
  if board.tint then
    proto.icons = {
      {
        icon = "__chiptorio__/graphics/icons/" .. board.name .. ".png",
        icon_size = 64,
        tint = board.tint,
      },
    }
  else
    M.set_icon(proto, board.name)
  end
end

--- Ensure a board item exists. Existing vanilla items are re-themed in place;
--- new boards are cloned from processing-unit.
local function ensure_board_item(board)
  local existing = data.raw.item[board.name]
  if existing then
    existing.subgroup = "chiptorio-circuits"
    existing.order = board.order
    existing.hidden = false
    existing.hidden_in_factoriopedia = false
    set_item_flavour(existing, board)
    return existing
  end

  local proto = M.item_proto("processing-unit", board.name, "chiptorio-circuits", board.order)
  proto.stack_size = 100
  set_item_flavour(proto, board)
  data:extend({ proto })
  return proto
end

--- Ensure a board recipe exists. Existing vanilla recipes (first three boards)
--- are overwritten in place; new recipes are created via M.recipe.
local function ensure_board_recipe(board, alt)
  local recipe_name
  if alt then
    recipe_name = board.name .. "-from-" .. alt.gate
  else
    recipe_name = board.name
  end

  local ingredients = alt and alt.ingredients or board.base
  local energy = alt and alt.energy or board.energy
  local results = alt and alt.results or board.results

  local spec = {
    name = recipe_name,
    enabled = false,
    category = "chiptorio-circuit",
    energy_required = energy,
    ingredients = ingredients,
    results = { { type = "item", name = board.name, amount = results } },
  }

  local existing = data.raw.recipe[recipe_name]
  if existing then
    existing.category = nil
    existing.additional_categories = nil
    existing.categories = { "chiptorio-circuit" }
    existing.energy_required = energy
    existing.ingredients = ingredients
    existing.results = spec.results
    existing.enabled = false
    existing.hidden = false
    return existing
  end

  M.recipe(spec)
  return spec
end

-- ---------------------------------------------------------------------------
-- Board items and recipes
-- ---------------------------------------------------------------------------

for _, board in ipairs(meta.BOARDS) do
  ensure_board_item(board)
  ensure_board_recipe(board)
  for _, alt in ipairs(board.alts or {}) do
    ensure_board_recipe(board, alt)
  end
end

-- ---------------------------------------------------------------------------
-- Circuit Assembler machine
-- ---------------------------------------------------------------------------

local function make_circuit_assembler(spec)
  local entity = M.copy(data.raw[spec.base_type][spec.base])
  if not entity then
    error("chiptorio: base machine '" .. spec.base .. "' not found")
  end

  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.2, result = spec.name }
  entity.corpse = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.fast_replaceable_group = "chiptorio-machines"
  entity.crafting_categories = { spec.category }
  entity.crafting_speed = spec.speed
  entity.energy_usage = spec.power
  entity.module_slots = spec.modules
  M.set_entity_icon(entity, spec.name)
  if spec.custom_graphics then
    M.set_custom_graphics(entity, spec.custom_graphics or spec.name, spec.size_w or 160, spec.size_h or 160, spec.scale or 0.5, spec.shift)
  elseif spec.tint then
    M.tint_entity(entity, spec.tint)
  end
  data:extend({ entity })

  local item = M.copy(data.raw.item[spec.base])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-machines"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_circuit_assembler(meta.ASSEMBLER)

-- ---------------------------------------------------------------------------
-- Wire board recipes into gate technology effects.
-- ---------------------------------------------------------------------------

local function add_tech_effect(tech_name, effect_name)
  local tech = data.raw.technology[tech_name]
  if not tech then
    error("chiptorio: technology '" .. tostring(tech_name)
      .. "' not found; cannot unlock board recipe '" .. tostring(effect_name) .. "'")
  end
  tech.effects = tech.effects or {}
  for _, existing in ipairs(tech.effects) do
    if type(existing) == "table" and existing.recipe == effect_name then
      return
    end
    if type(existing) == "string" and existing == effect_name then
      return
    end
  end
  table.insert(tech.effects, { type = "unlock-recipe", recipe = effect_name })
end

for _, board in ipairs(meta.BOARDS) do
  add_tech_effect(board.gate, board.name)
  for _, alt in ipairs(board.alts or {}) do
    local recipe_name = board.name .. "-from-" .. alt.gate
    add_tech_effect(alt.gate, recipe_name)
  end
end

-- Circuit Assembler recipe unlocked by thermionics.
local assembler = meta.ASSEMBLER
add_tech_effect(assembler.gate, assembler.name)

return true
