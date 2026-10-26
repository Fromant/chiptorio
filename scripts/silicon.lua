-- The silicon chain: sand -> wafer.
--
-- Bulk chemistry (silica, polysilicon, photoresist, etchant) stays in base
-- chemical plants and furnaces. Crystal growth moves to the crystal puller and
-- every lithography/metrology step moves to the wafer fab.

local M = require("scripts.util")

-- Crush stone into usable silica sand.
M.recipe({
  name = "silica",
  enabled = false,
  category = "crafting",
  energy_required = 1,
  ingredients = { M.item("stone", 5) },
  results = { M.item("silica", 4) },
})

-- Carbothermic reduction. Ugly, hot, and good enough for 98% silicon.
M.recipe({
  name = "metallurgical-silicon",
  enabled = false,
  category = "chiptorio-crystal",
  energy_required = 8,
  ingredients = { M.item("silica", 4), M.item("coal", 1) },
  results = { M.item("metallurgical-silicon", 1) },
})

-- Stand-in for the Siemens process: acid + steam purification to 9N.
M.recipe({
  name = "polysilicon",
  enabled = false,
  category = "chemistry",
  energy_required = 10,
  ingredients = {
    M.item("metallurgical-silicon", 2),
    M.fluid("sulfuric-acid", 20),
    M.fluid("steam", 20),
  },
  results = { M.item("polysilicon", 1) },
})

-- Czochralski crystal pulling, compressed into one furnace step.
M.recipe({
  name = "monocrystalline-ingot",
  enabled = false,
  category = "chiptorio-crystal",
  energy_required = 30,
  ingredients = { M.item("polysilicon", 4) },
  results = { M.item("monocrystalline-ingot", 1) },
})

-- Wire saw + lapping + polishing.
M.recipe({
  name = "silicon-wafer",
  enabled = false,
  category = "crafting",
  energy_required = 10,
  ingredients = { M.item("monocrystalline-ingot", 1), M.item("silica", 2) },
  results = { M.item("silicon-wafer", 8) },
})

-- Photoresist: coal tar / novolak stand-in.
M.recipe({
  name = "photoresist",
  enabled = false,
  category = "chemistry",
  energy_required = 5,
  ingredients = {
    M.item("plastic-bar", 1),
    M.fluid("light-oil", 20),
    M.fluid("steam", 20),
  },
  results = { M.fluid("photoresist", 20) },
})

-- Wet etchant, bottled as its own fluid so it can be piped or barrelled.
M.recipe({
  name = "etchant",
  enabled = false,
  category = "chemistry",
  energy_required = 4,
  ingredients = {
    M.fluid("sulfuric-acid", 20),
    M.fluid("water", 20),
  },
  results = { M.fluid("etchant", 20) },
})

-- Quartz/chrome mask. Consumed slowly: masks wear out.
M.recipe({
  name = "litho-mask",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 8,
  ingredients = { M.item("glass", 2), M.item("steel-plate", 1) },
  results = { M.item("litho-mask", 1) },
})

-- Contact/projection exposure.
M.recipe({
  name = "exposed-wafer",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 12,
  ingredients = {
    M.item("silicon-wafer", 10),
    M.fluid("photoresist", 20),
    M.item("litho-mask", 1),
  },
  results = { M.item("exposed-wafer", 10) },
})

M.recipe({
  name = "etched-wafer",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 8,
  ingredients = {
    M.item("exposed-wafer", 10),
    M.fluid("etchant", 20),
  },
  results = { M.item("etched-wafer", 10) },
})

-- Sputtering / damascene metallisation.
M.recipe({
  name = "processed-wafer",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 10,
  ingredients = {
    M.item("etched-wafer", 10),
    M.item("copper-plate", 2),
    M.fluid("sulfuric-acid", 10),
  },
  results = { M.item("processed-wafer", 10) },
})

-- Dicing.
M.recipe({
  name = "bare-die",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 5,
  ingredients = { M.item("processed-wafer", 10) },
  results = { M.item("bare-die", 40) },
})
