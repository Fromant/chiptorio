-- The fab tier.
--
-- Three machines split the chip process across purpose-built shells:
--   wafer-fab      fluid-capable cleanroom (cloned from chemical plant)
--   crystal-puller high-temperature furnace (cloned from electric furnace)
--   server-rack    packaging / compute assembly (cloned from AM3)
--
-- Every machine is a deep copy of a base prototype with only identity, stats,
-- category and a tint changed. That keeps all 2.1 sprite/fluid-box plumbing
-- valid without shipping entity art.

local M = require("scripts.util")

-- Custom recipe categories. The names are deliberately namespaced so other
-- mods cannot accidentally put recipes in our fabs.
data:extend({
  { type = "recipe-category", name = "chipotrio-fab" },
  { type = "recipe-category", name = "chipotrio-crystal" },
  { type = "recipe-category", name = "chipotrio-compute" },
  { type = "recipe-category", name = "chipotrio-vlsi" },
  { type = "recipe-category", name = "chipotrio-cooling" },
  { type = "recipe-category", name = "chipotrio-quantum" },
})

local function make_machine(spec)
  local entity = M.copy(data.raw[spec.base_type][spec.base])
  if not entity then
    error("chipotrio: base machine '" .. spec.base .. "' not found")
  end

  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = spec.mining_time or 0.2, result = spec.name }
  entity.corpse = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.fast_replaceable_group = "chipotrio-machines"
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
  item.subgroup = "chipotrio-machines"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  -- This recipe builds the machine, so it stays in the normal crafting
  -- category and is unlocked by a technology effect.
  M.recipe({
    name = spec.name,
    enabled = false,
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_machine({
  name = "wafer-fab",
  base_type = "assembling-machine",
  base = "chemical-plant",
  category = "chipotrio-fab",
  speed = 1.5,
  power = "300kW",
  modules = 3,
  craft_time = 10,
  order = "a[wafer-fab]",
  tint = { r = 0.55, g = 0.85, b = 1.0 },
  ingredients = {
    M.item("steel-plate", 20),
    M.item("glass", 10),
    M.item("electronic-circuit", 10),
    M.item("copper-plate", 20),
    M.item("pipe", 10),
  },
})

make_machine({
  name = "crystal-puller",
  base_type = "furnace",
  base = "electric-furnace",
  category = "chipotrio-crystal",
  speed = 2,
  power = "240kW",
  modules = 2,
  craft_time = 8,
  order = "b[crystal-puller]",
  tint = { r = 1.0, g = 0.82, b = 0.45 },
  ingredients = {
    M.item("steel-plate", 20),
    M.item("stone-brick", 10),
    M.item("electronic-circuit", 10),
    M.item("copper-plate", 20),
  },
})

make_machine({
  name = "server-rack",
  base_type = "assembling-machine",
  base = "assembling-machine-3",
  category = "chipotrio-compute",
  speed = 1.25,
  power = "420kW",
  modules = 4,
  craft_time = 12,
  order = "c[server-rack]",
  tint = { r = 0.55, g = 0.70, b = 0.95 },
  ingredients = {
    M.item("steel-plate", 30),
    M.item("advanced-circuit", 20),
    M.item("integrated-circuit", 10),
    M.item("electronic-circuit", 10),
  },
})

make_machine({
  name = "vlsi-fab",
  base_type = "assembling-machine",
  base = "chemical-plant",
  category = "chipotrio-vlsi",
  speed = 2,
  power = "800kW",
  modules = 4,
  craft_time = 20,
  order = "d[vlsi-fab]",
  tint = { r = 0.70, g = 0.55, b = 1.0 },
  ingredients = {
    M.item("wafer-fab", 2),
    M.item("steel-plate", 20),
    M.item("advanced-circuit", 20),
    M.item("integrated-circuit", 10),
    M.item("pipe", 20),
    M.item("cooling-unit", 2),
  },
})

make_machine({
  name = "cooling-tower",
  base_type = "assembling-machine",
  base = "chemical-plant",
  category = "chipotrio-cooling",
  speed = 1.5,
  power = "300kW",
  modules = 2,
  craft_time = 10,
  order = "e[cooling-tower]",
  tint = { r = 0.45, g = 0.80, b = 1.0 },
  ingredients = {
    M.item("steel-plate", 10),
    M.item("pipe", 20),
    M.item("copper-plate", 10),
    M.item("electronic-circuit", 5),
  },
})

make_machine({
  name = "quantum-fab",
  base_type = "assembling-machine",
  base = "chemical-plant",
  category = "chipotrio-quantum",
  speed = 1.5,
  power = "1.2MW",
  modules = 4,
  craft_time = 30,
  order = "f[quantum-fab]",
  tint = { r = 0.45, g = 0.35, b = 0.95 },
  ingredients = {
    M.item("vlsi-fab", 1),
    M.item("steel-plate", 30),
    M.item("advanced-circuit", 30),
    M.item("superconductor", 4),
    M.item("cooling-unit", 4),
  },
})
