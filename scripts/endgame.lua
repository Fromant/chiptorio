-- The Answer Engine: the final 5x5 machine.
--
-- It is a lab clone with no inputs, so it cannot be used to research ordinary
-- technologies. Its only job is to run the scripted 42-minute computation in
-- scripts/answer_engine.lua. Cloning the lab keeps the GUI, power connection,
-- minimap behaviour and animation plumbing valid without shipping entity art.

local M = require("scripts.util")

local BASE_SCALE = 0.5
local ENGINE_SCALE = 0.85
local SCALE_FACTOR = ENGINE_SCALE / BASE_SCALE

local function scale_shift(shift)
  if not shift then
    return nil
  end
  -- Vector can be either {x = , y = } or the positional {x, y} form that
  -- util.by_pixel produces in the base prototypes.
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

local base_entity = data.raw.lab["lab"]
if not base_entity then
  error("chiptorio: base lab missing; cannot build the answer engine")
end

local entity = M.copy(base_entity)
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

-- No science packs, no module slots, no ordinary research. The runtime owns
-- the countdown; the lab GUI is only used as a place to anchor our controls.
entity.inputs = {}
entity.module_slots = 0
entity.researching_speed = 0.001
entity.energy_usage = "10MW"
entity.energy_source.drain = "2MW"
entity.working_sound = nil
entity.water_reflection = nil
entity.icons_positioning = nil

scale_animation(entity.on_animation)
scale_animation(entity.off_animation)
M.tint_animation(entity.on_animation, { r = 1.0, g = 0.78, b = 0.35 })
M.tint_animation(entity.off_animation, { r = 0.78, g = 0.55, b = 0.25 })
M.set_entity_icon(entity, "answer-engine")
data:extend({ entity })

local item = M.copy(data.raw.item["lab"])
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
    M.item("advanced-circuit", 100),
    M.item("steel-plate", 200),
  },
  results = { M.item("answer-engine", 1) },
})
