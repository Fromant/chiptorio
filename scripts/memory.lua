-- Memory modules.
--
-- Capacity and bandwidth are read by the research runtime from
-- scripts/research_meta.lua. The items themselves are module prototypes (see
-- scripts/items.lua), because a provider stores them in its module inventory.
--
-- The recipes are the only place the two generations differ in cost: SRAM is
-- cheap, fast to build and small; DRAM is a later, denser package.

local M = require("scripts.util")

M.recipe({
  name = "sram-module",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 8,
  ingredients = {
    M.item("integrated-circuit", 2),
    M.item("silicon-wafer", 1),
    M.item("copper-plate", 2),
  },
  results = { M.item("sram-module", 2) },
})

M.recipe({
  name = "dram-module",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 12,
  ingredients = {
    M.item("vlsi-die", 2),
    M.item("integrated-circuit", 2),
    M.item("copper-plate", 2),
  },
  results = { M.item("dram-module", 1) },
})
