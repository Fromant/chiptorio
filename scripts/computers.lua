-- Computer modules: Computer Assembler, computer items, computer recipes.
--
-- Runs after boards/chips/technologies exist so it can create computer items
-- (modules) and wire computer recipes into gate technology effects.

local M = require("scripts.util")
local meta = require("scripts.computers_meta")

-- ---------------------------------------------------------------------------
-- Recipe category and module category for computer assembly.
-- ---------------------------------------------------------------------------

data:extend({
  { type = "recipe-category", name = "chiptorio-computer" },
  { type = "module-category", name = "chiptorio-computer" },
})

-- ---------------------------------------------------------------------------
-- Item subgroup for computers.
-- ---------------------------------------------------------------------------

data:extend({
  {
    type = "item-subgroup",
    name = "chiptorio-computers",
    group = "chiptorio",
    order = "d[computers]",
  },
})

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function set_item_flavour(proto, computer)
  proto.localised_name = { "item-name." .. computer.label }
  proto.localised_description = { "item-description." .. computer.label }
  if computer.tint then
    proto.icons = {
      {
        icon = "__chiptorio__/graphics/icons/" .. computer.name .. ".png",
        icon_size = 64,
        tint = computer.tint,
      },
    }
  else
    M.set_icon(proto, computer.name)
  end
end

--- Ensure a computer item exists. All computers are new (clone from processing-unit).
--- Computers are module prototypes so providers can read them from their
--- module inventory.
local function ensure_computer_item(computer)
  local proto = M.item_proto("processing-unit", computer.name, "chiptorio-computers", computer.order)
  proto.type = "module"
  proto.category = "chiptorio-computer"
  proto.tier = 1
  proto.effect = {}
  proto.effect_description = nil
  proto.stack_size = 50
  set_item_flavour(proto, computer)
  data:extend({ proto })
  return proto
end

--- Ensure a computer recipe exists.
local function ensure_computer_recipe(computer)
  local spec = {
    name = computer.name,
    enabled = false,
    category = "chiptorio-computer",
    energy_required = computer.energy,
    ingredients = computer.base,
    results = { { type = "item", name = computer.name, amount = computer.results } },
  }
  M.recipe(spec)
  return spec
end

-- ---------------------------------------------------------------------------
-- Computer items and recipes
-- ---------------------------------------------------------------------------

for _, computer in ipairs(meta.COMPUTERS) do
  ensure_computer_item(computer)
  ensure_computer_recipe(computer)
end

-- ---------------------------------------------------------------------------
-- Computer Assembler machine
-- ---------------------------------------------------------------------------

local function make_computer_assembler(spec)
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
  if spec.tint then
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

make_computer_assembler(meta.ASSEMBLER)

-- ---------------------------------------------------------------------------
-- Wire computer recipes into gate technology effects.
-- ---------------------------------------------------------------------------

local function add_tech_effect(tech_name, effect_name)
  local tech = data.raw.technology[tech_name]
  if not tech then
    error("chiptorio: technology '" .. tostring(tech_name)
      .. "' not found; cannot unlock computer recipe '" .. tostring(effect_name) .. "'")
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

for _, computer in ipairs(meta.COMPUTERS) do
  add_tech_effect(computer.gate, computer.name)
end

-- Computer Assembler recipe unlocked by internet.
local assembler = meta.ASSEMBLER
add_tech_effect(assembler.gate, assembler.name)

return true
