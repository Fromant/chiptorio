-- Metrology Lab: a network qualification station, not a research lab.
--
-- Built from scratch (not cloned from lab) so there is no inherited baggage:
-- no science inputs, no researching_speed, no crafting, no base-prototype
-- animation clock. Accepts qualification wafers as inputs and reports to the
-- network graph, but never researches ordinary technologies.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

local entity = M.make_provider_base({
  name = "metrology-lab",
  localised_name = { "entity-name.metrology-lab" },
  localised_description = { "entity-description.metrology-lab" },
  minable = { mining_time = 0.5, result = "metrology-lab" },
  placeable_by = { item = "metrology-lab", count = 1 },
  inventory_size = 100,
  picture = {
    filename = "__chiptorio__/graphics/entity/metrology-lab.png",
    width = 160,
    height = 160,
    scale = 0.5,
    shift = { 0, 0 },
  },
  collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } },
  selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } },
  drawing_box_vertical_extension = 2.5,
})

M.set_blender_device_graphics(entity, "metrology-lab")
data:extend({ entity })

local item = M.item_proto("wooden-chest", "metrology-lab", "chiptorio-computers", "f[metrology-lab]")
item.place_result = "metrology-lab"
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
