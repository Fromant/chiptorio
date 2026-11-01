-- The Answer Engine: the final 5x5 machine.
--
-- Built from scratch (not cloned from lab or assembling-machine) so there is
-- no inherited baggage: no crafting, no modules, no researching_speed, no
-- base-prototype animation clock. Its only job is to run the scripted
-- 42-minute computation in scripts/answer_engine.lua.

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

local entity = M.make_provider_base({
  name = "answer-engine",
  localised_name = { "entity-name.answer-engine" },
  localised_description = { "entity-description.answer-engine" },
  minable = { mining_time = 2, result = "answer-engine" },
  placeable_by = { item = "answer-engine", count = 1 },
  inventory_size = 0,
  picture = {
    filename = "__chiptorio__/graphics/entity/answer-engine.png",
    width = 240,
    height = 240,
    scale = 0.5,
    shift = { 0, 0 },
  },
  collision_box = { { -2.3, -2.3 }, { 2.3, 2.3 } },
  selection_box = { { -2.5, -2.5 }, { 2.5, 2.5 } },
  max_health = 5000,
})

data:extend({ entity })

local item = M.item_proto("wooden-chest", "answer-engine", "chiptorio-computers", "f[answer-engine]")
item.place_result = "answer-engine"
item.stack_size = 1
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
