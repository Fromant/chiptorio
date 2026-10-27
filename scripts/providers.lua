-- Compute providers: the machines that turn chips into network compute.
--
-- A provider is a lab clone with no science inputs and a near-zero research
-- speed. That is deliberate: a lab prototype is the only 2.1 entity that
-- exposes a readable module inventory to script, and cloning it keeps the
-- module-slot GUI, power connection, minimap behaviour and animation plumbing
-- valid without shipping entity art.
--
-- The prototype numbers live in scripts/research_meta.lua so the data stage and
-- the runtime cannot drift apart.

local M = require("scripts.util")
local meta = require("scripts.research_meta")

local function make_provider(spec)
  local base = data.raw.lab["lab"]
  if not base then
    error("chiptorio: base lab prototype not found")
  end

  local profile = meta.PROVIDERS[spec.name]
  if not profile then
    error("chiptorio: no provider profile for '" .. spec.name .. "'")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.5, result = spec.name }
  entity.placeable_by = { item = spec.name, count = 1 }
  entity.next_upgrade = nil
  entity.fast_replaceable_group = "chiptorio-providers"
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.corpse = nil

  -- No science inputs and no meaningful research speed: this machine must
  -- never be usable as an ordinary lab.
  entity.inputs = {}
  entity.researching_speed = 0.001
  entity.energy_usage = profile.power .. "kW"
  entity.energy_source = entity.energy_source or { type = "electric" }
  entity.energy_source.drain = profile.drain
  local module_categories = { "chiptorio-computer" }
  if profile.memory_slots and profile.memory_slots > 0 then
    module_categories[#module_categories + 1] = "chiptorio-memory"
  end
  entity.module_slots = profile.computer_slots + profile.memory_slots
  entity.allowed_module_categories = module_categories
  -- Chips have an empty effect, so the inherited lab effect limits are fine.
  entity.allowed_effects = nil

  M.set_entity_icon(entity, spec.name)
  if spec.custom_animation then
    M.set_custom_animation(entity, spec.custom_animation or spec.name, spec.size_w or 128, spec.size_h or 128, spec.scale or 0.5, spec.shift)
  elseif spec.tint then
    M.tint_animation(entity.on_animation, spec.tint)
    M.tint_animation(entity.off_animation, spec.tint)
  end
  data:extend({ entity })

  local item = M.copy(data.raw.item["lab"])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-providers"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_provider({
  name = "server-rack",
  order = "a[server-rack]",
  craft_time = 12,
  custom_animation = "server-rack",
  size_w = 128,
  size_h = 128,
  scale = 0.5,
  ingredients = {
    M.item("steel-plate", 20),
    M.item("electronic-circuit", 10),   -- Control Board
    M.item("copper-plate", 20),
  },
})

make_provider({
  name = "memory-bank",
  order = "b[memory-bank]",
  craft_time = 10,
  custom_animation = "memory-bank",
  size_w = 128,
  size_h = 128,
  scale = 0.5,
  ingredients = {
    M.item("steel-plate", 16),
    M.item("electronic-circuit", 8),    -- Control Board
    M.item("copper-plate", 20),
  },
})

make_provider({
  name = "datacenter",
  order = "c[datacenter]",
  craft_time = 30,
  custom_animation = "datacenter",
  size_w = 160,
  size_h = 160,
  scale = 0.5,
  ingredients = {
    M.item("server-rack", 4),
    M.item("cooling-unit", 8),
    M.item("steel-plate", 40),
    M.item("electronic-circuit", 30),   -- Control Board
  },
})
