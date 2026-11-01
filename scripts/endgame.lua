-- The Answer Engine: the final 5x5 machine.
--
-- It is a standalone assembling-machine prototype with no crafting categories,
-- so it cannot be used to research ordinary technologies. Its only job is to
-- run the scripted 42-minute computation in scripts/answer_engine.lua.
-- Cloning the assembling-machine gives us module-free, research-free behaviour
-- with full control over graphics and animation.

local M = require("scripts.util")

local BASE_SCALE = 0.5
local ENGINE_SCALE = 0.85
local SCALE_FACTOR = ENGINE_SCALE / BASE_SCALE

local function scale_shift(shift)
  if not shift then
    return nil
  end
  local x = shift.x or shift[1] or 0
  local y = shift.y or shift[2] or 0
  return { x * SCALE_FACTOR, y * SCALE_FACTOR }
end

local function scale_animation(animation)
  if not animation or not animation.layers then
    return
  end
  for _, layer in ipairs(animation.layers) do
    if layer.scale then
      layer.scale = layer.scale * SCALE_FACTOR
    end
    if layer.shift then
      layer.shift = scale_shift(layer.shift)
    end
  end
end

local ingredient_names = {
  "monocrystalline-ingot",
  "phase-shift-mask",
  "server-rack",
  "datacenter",
  "cryostat",
  "multi-core-cpu",
  "quantum-processor",
  "advanced-circuit",
  "steel-plate",
}
for _, name in ipairs(ingredient_names) do
  if not M.item_exists(name) then
    error("chiptorio: answer-engine ingredient '" .. name .. "' is missing")
  end
end

-- Standalone assembling-machine base.
local am_base = data.raw["assembling-machine"]["assembling-machine-1"]
if not am_base then
  error("chiptorio: base assembling-machine not found")
end

local entity = M.copy(am_base)
entity.name = "answer-engine"
entity.localised_name = nil
entity.localised_description = nil
entity.minable = { mining_time = 2, result = "answer-engine" }
entity.placeable_by = { item = "answer-engine", count = 1 }
entity.next_upgrade = nil
entity.fast_replaceable_group = nil
entity.corpse = nil
entity.dying_explosion = nil
entity.max_health = 5000
entity.collision_box = { { -2.3, -2.3 }, { 2.3, 2.3 } }
entity.selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } }
entity.hidden = false
entity.hidden_in_factoriopedia = false

-- No crafting, no modules, no ordinary research.
-- crafting_categories is inherited from the base assembling-machine
-- ({"crafting"}), but crafting_speed = 0.001 makes crafting impractically
-- slow. The answer-engine is a scripted computation device, not a factory.
entity.crafting_speed = 0.001
entity.module_slots = 0
entity.allowed_module_categories = {}

entity.energy_usage = "10MW"
entity.energy_source = entity.energy_source or { type = "electric" }
entity.energy_source.drain = "2MW"
entity.working_sound = nil
entity.water_reflection = nil
entity.icons_positioning = nil

M.set_custom_graphics(entity, "answer-engine", 240, 240, 0.5)
M.set_entity_icon(entity, "answer-engine")
data:extend({ entity })

local item = M.copy(data.raw.item["assembling-machine-1"])
item.name = "answer-engine"
item.localised_name = nil
item.localised_description = nil
item.place_result = "answer-engine"
item.subgroup = "chiptorio-computers"
item.order = "f[answer-engine]"
item.stack_size = 1
item.hidden = false
item.hidden_in_factoriopedia = false
M.set_icon(item, "answer-engine")
data:extend({ item })

-- Built in an Assembly Fab from every previous era. The ingredient list is
-- deliberately broad: one of every major tier of the factory.
M.recipe({
  name = "answer-engine",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 120,
  ingredients = {
    M.item("monocrystalline-ingot", 64),
    M.item("phase-shift-mask", 32),
    M.item("server-rack", 32),
    M.item("datacenter", 8),
    M.item("cryostat", 2),
    M.item("multi-core-cpu", 16),
    M.item("quantum-processor", 8),
    M.item("advanced-circuit", 40),
    M.item("steel-plate", 60),
  },
  results = { M.item("answer-engine", 1) },
})
