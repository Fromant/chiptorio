-- Recipes for the process-node ladder.
--
-- Each major node has three manufacturing steps and one or more chip-packaging
-- recipes:
--   mask set   the lithography reticle / process kit
--   wafer      exposure and metallisation of plain silicon wafers
--   die        dicing the wafer into that node's transistor family
--   chips      packaging dies into the architecture modules a provider accepts
--
-- A node does not invent a new chip name. It makes the existing architecture
-- chips available at that node's die cost, which is why later nodes are
-- cheaper per chip even though the profile table never changes (DESIGN §4.4).
--
-- The first three nodes run in the Wafer Fab. From 350 nm the recipes move to
-- the VLSI Fab, which also consumes coolant.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

--- Ingredient list for packaging one chip at one node.
local function chip_ingredients(chip, names, index)
  if chip == "integrated-circuit" then
    return {
      M.item(names.die, 2),
      M.item("plastic-bar", 2),
      M.fluid("sulfuric-acid", 10),
    }, 2
  elseif chip == "microprocessor" then
    return {
      M.item(names.die, 3),
      M.item("integrated-circuit", 1),
      M.item("copper-plate", 2),
    }, 1
  elseif chip == "system-on-chip" then
    return {
      M.item(names.die, 4),
      M.item("low-k-dielectric", 2),
      M.item("copper-plate", 2),
    }, 1
  elseif chip == "gpu" then
    return {
      M.item(names.die, 2),
      M.item("hbm-stack", 1),
      M.fluid("coolant", 10),
    }, 1
  elseif chip == "multi-core-cpu" then
    return {
      M.item(names.die, 2),
      M.item("chiplet", 1),
      M.item("hbm-stack", 1),
    }, 1
  elseif chip == "quantum-processor" then
    -- The first QPU is built from physical qubits; once error correction is
    -- researched the later nodes use logical qubits.
    if index >= 11 then
      return {
        M.item(names.die, 1),
        M.item("error-corrected-qubit", 4),
        M.item("superconductor", 4),
        M.fluid("cryogen", 20),
      }, 1
    end
    return {
      M.item(names.die, 1),
      M.item("qubit", 16),
      M.item("superconductor", 4),
      M.fluid("cryogen", 20),
    }, 1
  end
  error("chiptorio: unknown chip architecture '" .. tostring(chip) .. "'")
end

for index, node in ipairs(nodes.NODES) do
  local names = nodes.items(node.key)
  local fab = index <= 3 and "chiptorio-fab" or "chiptorio-vlsi"
  local extra_fluid = node.extra

  -- Lithography mask set / process kit.
  M.recipe({
    name = names.mask,
    enabled = false,
    category = "chiptorio-fab",
    energy_required = 8 + index * 2,
    ingredients = {
      M.item(node.mask[1], node.mask[2]),
      M.item("copper-plate", 2 + index),
      M.item("plastic-bar", 2),
    },
    results = { M.item(names.mask, 1) },
  })

  -- Exposure and metallisation.
  local wafer_ingredients = {
    M.item("silicon-wafer", 10),
    M.item(names.mask, 1),
    M.fluid("photoresist", 20),
  }
  if extra_fluid then
    wafer_ingredients[#wafer_ingredients + 1] = extra_fluid
  end
  M.recipe({
    name = names.wafer,
    enabled = false,
    category = fab,
    energy_required = 12 + index * 2,
    ingredients = wafer_ingredients,
    results = { M.item(names.wafer, 10) },
    -- Qualified half-nodes raise this recipe's force productivity; allow the
    -- bonus without requiring a productivity module in the fab.
    allow_productivity = true,
  })

  -- Dicing. The die count rises with the node: same wafer, more devices.
  M.recipe({
    name = names.die,
    enabled = false,
    category = fab,
    energy_required = 8 + index,
    ingredients = {
      M.item(names.wafer, 10),
      M.fluid("etchant", 10),
    },
    results = { M.item(names.die, node.dies) },
    allow_productivity = true,
  })

  -- Packaging recipes for the architectures this node supports.
  for _, chip in ipairs(node.chips) do
    local ingredients, amount = chip_ingredients(chip, names, index)
    local recipe = {
      type = "recipe",
      name = chip .. "-from-" .. node.key,
      enabled = false,
      categories = { "chiptorio-compute" },
      energy_required = 16 + index * 2,
      ingredients = ingredients,
      results = { M.item(chip, amount) },
      icons = {
        {
          icon = "__chiptorio__/graphics/icons/" .. chip .. ".png",
          icon_size = 64,
        },
      },
      localised_name = { "recipe-name." .. chip },
    }
    data:extend({ recipe })
  end
end

-- The two custom science packs that are not node-specific. The third, the
-- Qubit Array, is built in the Quantum Fab (scripts/era7.lua).
M.recipe({
  name = "chiptorio-optical-science-pack",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 10,
  ingredients = {
    M.item("glass", 2),
    M.item("copper-plate", 1),
    M.fluid("photoresist", 10),
  },
  results = { M.item("chiptorio-optical-science-pack", 2) },
  icons = {
    { icon = "__chiptorio__/graphics/icons/optical-disc.png", icon_size = 64 },
  },
  localised_name = { "item-name.optical-disc" },
})

M.recipe({
  name = "chiptorio-hbm-science-pack",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 12,
  ingredients = {
    M.item("hbm-stack", 1),
    M.item("low-k-dielectric", 2),
    M.item("plastic-bar", 1),
  },
  results = { M.item("chiptorio-hbm-science-pack", 4) },
  icons = {
    { icon = "__chiptorio__/graphics/icons/hbm-science.png", icon_size = 64 },
  },
  localised_name = { "item-name.hbm-science" },
})
