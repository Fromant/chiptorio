-- Device assembly: glass, vacuum tubes and discrete transistors. The process
-- nodes package integrated circuits and later architectures in
-- scripts/node_recipes.lua.

local M = require("scripts.util")

M.recipe({
  name = "glass",
  enabled = false,
  category = "smelting",
  energy_required = 4,
  ingredients = { M.item("silica", 4) },
  results = { M.item("glass", 1) },
})

-- The first "logic device": a thermionic valve.
M.recipe({
  name = "vacuum-tube",
  enabled = false,
  category = "crafting",
  energy_required = 4,
  ingredients = {
    M.item("glass", 2),
    M.item("copper-cable", 1),
    M.item("iron-plate", 1),
  },
  results = { M.item("vacuum-tube", 1) },
})

-- Through-hole discrete transistor, packaged by hand.
M.recipe({
  name = "discrete-transistor",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 6,
  ingredients = {
    M.item("bare-die", 2),
    M.item("plastic-bar", 1),
    M.item("copper-cable", 2),
  },
  results = { M.item("discrete-transistor", 4) },
})
