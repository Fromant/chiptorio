-- Metrology Lab, Metrology Test Structures and the pilot processes.
--
-- A half-node is not finished when its technology is researched. The technology
-- unlocks a pilot recipe in the previous node's fab and the Metrology Lab; the
-- player then produces Process Qualification Wafers and delivers them to the
-- lab. scripts/runtime/qualification_runtime.lua consumes the wafers and marks
-- the refinement qualified, which applies the force-wide bonus.
--
-- The lab is a vanilla lab clone for the same reason the compute providers are:
-- a lab prototype is the only 2.1 entity that exposes a readable item inventory
-- to script. Its `inputs` are the ten PQWs, not science packs, so it can hold
-- samples but cannot research anything. The near-zero research speed keeps the
-- animation honest.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

-- ---------------------------------------------------------------------------
-- Metrology Test Structure
-- ---------------------------------------------------------------------------

local test_structure = M.item_from(
  "bare-die",
  "metrology-test-structure",
  "chiptorio-materials",
  "z[metrology-test-structure]"
)
M.set_icon(test_structure, "metrology-test-structure")
test_structure.localised_description = nil

M.recipe({
  name = "metrology-test-structure",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 4,
  ingredients = {
    M.item("glass", 1),
    M.item("copper-plate", 1),
    M.item("silica", 1),
  },
  results = { M.item("metrology-test-structure", 1) },
})

-- ---------------------------------------------------------------------------
-- Metrology Lab
-- ---------------------------------------------------------------------------

local BASE_LAB = "lab"
local base = data.raw.lab[BASE_LAB]
if not base then
  error("chiptorio: base lab prototype not found")
end

local entity = M.copy(base)
entity.name = "metrology-lab"
entity.localised_name = nil
entity.localised_description = nil
entity.minable = { mining_time = 0.5, result = "metrology-lab" }
entity.placeable_by = { item = "metrology-lab", count = 1 }
entity.next_upgrade = nil
entity.energy_usage = "250kW"
entity.researching_speed = 0.001
entity.module_slots = 0
entity.fast_replaceable_group = nil
entity.hidden = false
entity.hidden_in_factoriopedia = false
entity.corpse = nil
entity.inputs = {}
for _, half in ipairs(nodes.HALF_NODES) do
  entity.inputs[#entity.inputs + 1] = nodes.qualification_item(half.key)
end
M.set_entity_icon(entity, "metrology-lab")
M.tint_animation(entity.on_animation, { r = 0.45, g = 0.85, b = 0.95 })
M.tint_animation(entity.off_animation, { r = 0.45, g = 0.85, b = 0.95 })
data:extend({ entity })

local item = M.copy(data.raw.item[BASE_LAB])
item.name = "metrology-lab"
item.localised_name = nil
item.localised_description = nil
item.place_result = "metrology-lab"
item.subgroup = "chiptorio-computers"
item.order = "f[metrology-lab]"
item.hidden = false
item.hidden_in_factoriopedia = false
M.set_icon(item, "metrology-lab")
data:extend({ item })

M.recipe({
  name = "metrology-lab",
  enabled = false,
  energy_required = 20,
  ingredients = {
    M.item("steel-plate", 10),
    M.item("copper-plate", 20),
    M.item("glass", 10),
    M.item("iron-gear-wheel", 10),
    M.item("electronic-circuit", 10),
  },
  results = { M.item("metrology-lab", 1) },
})

-- ---------------------------------------------------------------------------
-- Pilot processes
-- ---------------------------------------------------------------------------

-- One Process Qualification Wafer per half-node, made in the fab of the node it
-- refines. The recipe deliberately uses the base mask that node consumes, not
-- that node's process-kit item: a pilot line must be cheap enough to run from
-- existing node production (DESIGN §4.5.3).
for _, half in ipairs(nodes.HALF_NODES) do
  local previous = nodes.node(half.between[1])
  if not previous then
    error("chiptorio: half-node '" .. half.key .. "' refines an unknown node")
  end
  local names = nodes.items(previous.key)
  if not M.item_exists(names.wafer) then
    error("chiptorio: pilot recipe for '" .. half.key .. "' needs " .. names.wafer)
  end

  local index = nodes.major_index(previous.key)
  local category = index <= 3 and "chiptorio-fab" or "chiptorio-vlsi"
  local wafer = nodes.qualification_item(half.key)

  M.recipe({
    name = nodes.qualification_recipe(half.key),
    enabled = false,
    category = category,
    energy_required = 10,
    ingredients = {
      M.item(names.wafer, 2),
      M.item(previous.mask[1], 1),
      M.fluid("photoresist", 20),
      M.item("metrology-test-structure", 1),
    },
    results = { M.item(wafer, 1) },
    localised_name = { "recipe-name." .. wafer },
  })
end
