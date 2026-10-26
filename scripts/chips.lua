-- Device assembly: glass, vacuum tubes, transistors, ICs, CPUs.

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
  category = "chipotrio-fab",
  energy_required = 6,
  ingredients = {
    M.item("bare-die", 2),
    M.item("plastic-bar", 1),
    M.item("copper-cable", 2),
  },
  results = { M.item("discrete-transistor", 4) },
})

-- Planar process: many devices on one die.
M.recipe({
  name = "integrated-circuit",
  enabled = false,
  category = "chipotrio-fab",
  energy_required = 12,
  ingredients = {
    M.item("bare-die", 4),
    M.item("plastic-bar", 2),
    M.fluid("sulfuric-acid", 10),
  },
  results = { M.item("integrated-circuit", 2) },
})

-- Microarchitecture: the chip that makes everything else smart.
M.recipe({
  name = "microprocessor",
  enabled = false,
  category = "chipotrio-fab",
  energy_required = 20,
  ingredients = {
    M.item("integrated-circuit", 2),
    M.item("bare-die", 4),
    M.item("copper-plate", 2),
  },
  results = { M.item("microprocessor", 1) },
})
