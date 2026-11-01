-- Metrology Lab: a network qualification station, not a research lab.
--
-- It accepts qualification wafers as inputs and reports to the network graph,
-- but never researches ordinary technologies. It is a standalone assembling
-- machine clone with no crafting categories, giving us full control over
-- graphics, animation, and GUI without lab-clone quirks.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

-- Standalone assembling-machine base for a non-researching machine.
local am_base = data.raw["assembling-machine"]["assembling-machine-1"]
if not am_base then
  error("chiptorio: base assembling-machine not found")
end

local entity = M.copy(am_base)
entity.name = "metrology-lab"
entity.localised_name = nil
entity.localised_description = nil
entity.minable = { mining_time = 0.5, result = "metrology-lab" }
entity.placeable_by = { item = "metrology-lab", count = 1 }
entity.next_upgrade = nil
entity.fast_replaceable_group = nil
entity.hidden = false
entity.hidden_in_factoriopedia = false
entity.corpse = nil

-- No crafting: this is a network qualification station, not a factory.
-- crafting_categories is inherited from the base assembling-machine
-- ({"crafting"}), but crafting_speed = 0.001 makes crafting impractically
-- slow. The metrology-lab is a network device, not a factory.
entity.crafting_speed = 0.001
entity.module_slots = 0
entity.allowed_module_categories = {}

entity.energy_usage = "250kW"
entity.energy_source = entity.energy_source or { type = "electric" }
entity.energy_source.drain = "5kW"

M.set_entity_icon(entity, "metrology-lab")
M.set_custom_graphics(entity, "metrology-lab", 160, 160, 0.5)

-- Freeze the base animation; the runtime can drive it via rendering overlay
-- if directional animation is needed later.
entity.collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } }
entity.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
entity.drawing_box_vertical_extension = 2.5
entity.tile_width = 3
entity.tile_height = 3

data:extend({ entity })

local item = M.copy(data.raw.item["assembling-machine-1"])
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

-- Metrology Test Structure: a dummy item consumed by pilot recipes. It has no
-- other use; pilot lines consume it to produce Process Qualification Wafers.
local mts_item = M.item_from("iron-plate", "metrology-test-structure", "chiptorio-materials", "zzz[metrology-test-structure]")
M.set_icon(mts_item, "metrology-test-structure")
mts_item.stack_size = 100
data:extend({ mts_item })

M.recipe({
  name = "metrology-test-structure",
  enabled = false,
  category = "crafting",
  energy_required = 2,
  ingredients = { M.item("iron-plate", 1) },
  results = { M.item("metrology-test-structure", 1) },
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
