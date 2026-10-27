-- Memory modules.
--
-- Capacity and bandwidth are read by the research runtime from
-- scripts/research_meta.lua; QLN cells are read from scripts/qln_meta.lua. The
-- items themselves are module prototypes (see scripts/items.lua), because a
-- provider stores them in its module inventory.
--
-- DESIGN §8.3: eleven generations, unlocked by the process node of their era.
-- Every recipe moves one step up the ladder: the previous generation's
-- packaging and the node die that era can actually produce. Keeping the table
-- here makes the whole memory line visible in one place and keeps the item,
-- profile and cell tables in lockstep.

local M = require("scripts.util")

local RECIPES = {
  {
    name = "sram-module",
    time = 8,
    results = 2,
    ingredients = {
      M.item("integrated-circuit", 2),
      M.item("silicon-wafer", 1),
      M.item("copper-plate", 2),
    },
  },
  {
    name = "dram-module",
    time = 10,
    results = 1,
    ingredients = {
      M.item("node-3um-die", 2),
      M.item("integrated-circuit", 2),
      M.item("copper-plate", 2),
    },
  },
  {
    name = "sdram-module",
    time = 12,
    results = 1,
    ingredients = {
      M.item("node-1um-die", 2),
      M.item("integrated-circuit", 3),
      M.item("copper-plate", 2),
    },
  },
  {
    name = "ddr-module",
    time = 14,
    results = 1,
    ingredients = {
      M.item("node-350nm-die", 2),
      M.item("advanced-circuit", 1),
      M.item("copper-plate", 2),
    },
  },
  {
    name = "ddr2-module",
    time = 16,
    results = 1,
    ingredients = {
      M.item("node-180nm-die", 2),
      M.item("advanced-circuit", 2),
      M.item("low-k-dielectric", 1),
    },
  },
  {
    name = "ddr3-module",
    time = 18,
    results = 1,
    ingredients = {
      M.item("node-90nm-die", 2),
      M.item("processing-unit", 1),
      M.item("low-k-dielectric", 1),
    },
  },
  {
    name = "ddr4-module",
    time = 20,
    results = 1,
    ingredients = {
      M.item("node-45nm-die", 2),
      M.item("processing-unit", 2),
      M.item("chiplet", 1),
    },
  },
  {
    name = "ddr5-module",
    time = 22,
    results = 1,
    ingredients = {
      M.item("node-22nm-die", 2),
      M.item("processing-unit", 2),
      M.item("chiplet", 2),
    },
  },
  {
    name = "hbm-module",
    time = 24,
    results = 1,
    ingredients = {
      M.item("node-14nm-die", 2),
      M.item("hbm-stack", 2),
      M.item("processing-unit", 2),
    },
  },
  {
    name = "hbm3-module",
    time = 26,
    results = 1,
    ingredients = {
      M.item("node-7nm-die", 2),
      M.item("hbm-stack", 3),
      M.item("chiplet", 2),
    },
  },
  {
    -- Bulk storage, not bandwidth: a stacked NAND die is cheap to build and
    -- slow to read, which is exactly what a QLN pool wants.
    name = "3d-nand-module",
    time = 28,
    results = 1,
    ingredients = {
      M.item("node-7nm-die", 1),
      M.item("hbm-stack", 1),
      M.item("silicon-wafer", 4),
      M.item("low-k-dielectric", 2),
    },
  },
}

for _, spec in ipairs(RECIPES) do
  M.recipe({
    name = spec.name,
    enabled = false,
    category = "chiptorio-fab",
    energy_required = spec.time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, spec.results) },
  })
end
