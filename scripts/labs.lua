-- Computer generations.
--
-- The base lab is hidden (see data-updates.lua). Every generation accepts ALL
-- workloads, because gating packs by machine silently deadlocks the vanilla
-- tech tree. What improves per generation is speed, power cost and module
-- slots - i.e. how much compute you get per chip.
--
-- Only the Analytical Engine is craftable without research. Later generations
-- are unlocked by their technology, and the loading stage asserts that the
-- starter engine remains enabled.

local M = require("scripts.util")

local function make_lab(spec)
  local base = data.raw.lab["lab"]
  if not base then
    error("chiptorio: base lab prototype not found")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.5, result = spec.name }
  entity.placeable_by = { item = spec.name, count = 1 }
  entity.next_upgrade = nil
  entity.researching_speed = spec.speed
  entity.energy_usage = spec.power
  entity.module_slots = spec.modules
  entity.fast_replaceable_group = "chiptorio-computers"
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.corpse = nil
  M.set_entity_icon(entity, spec.name)
  if spec.tint then
    M.tint_animation(entity.on_animation, spec.tint)
    M.tint_animation(entity.off_animation, spec.tint)
  end
  data:extend({ entity })

  local item = M.copy(data.raw.item["lab"])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-computers"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = spec.enabled ~= false,
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_lab({
  name = "analytical-engine",
  order = "a[analytical-engine]",
  speed = 0.5,
  power = "90kW",
  modules = 0,
  craft_time = 5,
  tint = { r = 0.75, g = 0.62, b = 0.45 },
  ingredients = {
    M.item("iron-gear-wheel", 8),
    M.item("copper-plate", 20),
    M.item("iron-plate", 20),
  },
})

make_lab({
  name = "tube-mainframe",
  order = "b[tube-mainframe]",
  speed = 1.0,
  power = "240kW",
  modules = 2,
  craft_time = 10,
  enabled = false,
  tint = { r = 0.65, g = 0.72, b = 0.85 },
  ingredients = {
    M.item("steel-plate", 20),
    M.item("vacuum-tube", 30),
    M.item("electronic-circuit", 20),
  },
})

make_lab({
  name = "mainframe-cluster",
  order = "c[mainframe-cluster]",
  speed = 1.75,
  power = "600kW",
  modules = 4,
  craft_time = 15,
  enabled = false,
  tint = { r = 0.35, g = 0.45, b = 0.55 },
  ingredients = {
    M.item("steel-plate", 40),
    M.item("discrete-transistor", 20),
    M.item("integrated-circuit", 20),
    M.item("advanced-circuit", 10),
  },
})

make_lab({
  name = "datacenter-lab",
  order = "d[datacenter-lab]",
  speed = 2.5,
  power = "1.5MW",
  modules = 6,
  craft_time = 30,
  enabled = false,
  tint = { r = 0.20, g = 0.55, b = 0.75 },
  ingredients = {
    M.item("server-rack", 4),
    M.item("system-on-chip", 8),
    M.item("cooling-unit", 4),
    M.item("steel-plate", 20),
    M.item("advanced-circuit", 20),
  },
})

make_lab({
  name = "cryostat",
  order = "e[cryostat]",
  speed = 4.0,
  power = "3MW",
  modules = 8,
  craft_time = 45,
  enabled = false,
  tint = { r = 0.55, g = 0.80, b = 1.0 },
  ingredients = {
    M.item("datacenter-lab", 1),
    M.item("cooling-unit", 8),
    M.item("superconductor", 8),
    M.item("steel-plate", 40),
    M.item("advanced-circuit", 40),
  },
})

-- Extra lab inputs. The three custom workloads are ordinary item prototypes,
-- so every generation can read them. `microprocessor` is only used by The
-- Question, but it must be in every lab's input list or that technology can
-- load and never be researched. This is the same anti-deadlock rule as for the
-- vanilla packs: the Cryostat is faster and more module-hungry, not the only
-- machine that accepts a given input.
--
-- `microprocessor` is a module prototype, so the existence check must look in
-- `data.raw.module` too; a plain `data.raw.item` lookup would reject it.
local EXTRA_INPUTS = {
  "chiptorio-optical-science-pack",
  "chiptorio-hbm-science-pack",
  "chiptorio-quantum-science-pack",
  "microprocessor",
}
for _, extra in ipairs(EXTRA_INPUTS) do
  if not M.item_exists(extra) then
    error("chiptorio: lab input item '" .. extra .. "' is missing")
  end
end

for _, name in ipairs({
  "analytical-engine",
  "tube-mainframe",
  "mainframe-cluster",
  "datacenter-lab",
  "cryostat",
}) do
  local lab = data.raw.lab[name]
  if not lab then
    error("chiptorio: research computer '" .. name .. "' missing")
  end
  lab.inputs = lab.inputs or {}
  for _, extra in ipairs(EXTRA_INPUTS) do
    local present = false
    for _, input in ipairs(lab.inputs) do
      if input == extra then
        present = true
      end
    end
    if not present then
      table.insert(lab.inputs, extra)
    end
  end
end
