-- Era 5-6: VLSI, the datacenter cooling loop, chiplets, GPUs and multi-core
-- CPUs.
--
-- The chain is deliberately split across the existing fab tier:
--   Wafer Fab      masks (the old process is still the basis of the new one)
--   Chemistry      slurry, low-k dielectric, coolant, cooling units
--   Cooling Tower  water + steam -> coolant
--   VLSI Fab       exposure, planarisation, dicing, GPU assembly
--   Assembly Fab   SoC packaging, chiplets, HBM stacks, multi-core CPUs
--
-- Coolant is not a GUI switch. It is manufactured, piped into the VLSI Fab and
-- consumed by every wafer/die/GPU step, so the cooling loop is part of the
-- production line.

local M = require("scripts.util")

-- A phase-shift mask is a tighter pattern etched into the previous generation
-- of mask. It is consumed by the VLSI exposure step.
M.recipe({
  name = "phase-shift-mask",
  enabled = false,
  category = "chiptorio-fab",
  energy_required = 12,
  ingredients = {
    M.item("litho-mask", 1),
    M.item("glass", 2),
    M.item("copper-plate", 1),
  },
  results = { M.item("phase-shift-mask", 1) },
})

-- Chemical-mechanical planarisation: abrasive silica in an acidic carrier.
M.recipe({
  name = "cmp-slurry",
  enabled = false,
  category = "chemistry",
  energy_required = 5,
  ingredients = {
    M.item("silica", 4),
    M.fluid("water", 20),
    M.fluid("sulfuric-acid", 10),
  },
  results = { M.fluid("cmp-slurry", 20) },
})

-- The insulator between copper interconnect layers.
M.recipe({
  name = "low-k-dielectric",
  enabled = false,
  category = "chemistry",
  energy_required = 8,
  ingredients = {
    M.item("plastic-bar", 2),
    M.fluid("sulfuric-acid", 10),
  },
  results = { M.item("low-k-dielectric", 2) },
})

-- Absorption chiller: water plus process steam becomes chilled coolant.
M.recipe({
  name = "coolant",
  enabled = false,
  category = "chiptorio-cooling",
  energy_required = 5,
  ingredients = {
    M.fluid("water", 100),
    M.fluid("steam", 100),
  },
  results = { M.fluid("coolant", 100) },
})

-- A packaged heat exchanger for the Datacenter itself.
M.recipe({
  name = "cooling-unit",
  enabled = false,
  category = "chemistry",
  energy_required = 6,
  ingredients = {
    M.item("steel-plate", 4),
    M.item("pipe", 8),
    M.item("copper-plate", 4),
    M.fluid("coolant", 10),
  },
  results = { M.item("cooling-unit", 2) },
})

-- Deep-UV exposure with a phase-shift mask, on a chilled stage.
M.recipe({
  name = "vlsi-wafer",
  enabled = false,
  category = "chiptorio-vlsi",
  energy_required = 16,
  ingredients = {
    M.item("silicon-wafer", 10),
    M.item("phase-shift-mask", 1),
    M.fluid("photoresist", 20),
    M.fluid("coolant", 10),
  },
  results = { M.item("vlsi-wafer", 10) },
})

-- CMP, copper fill and dicing in one fab step.
M.recipe({
  name = "vlsi-die",
  enabled = false,
  category = "chiptorio-vlsi",
  energy_required = 14,
  ingredients = {
    M.item("vlsi-wafer", 10),
    M.fluid("cmp-slurry", 20),
    M.item("copper-plate", 2),
  },
  results = { M.item("vlsi-die", 40) },
})

-- System on a chip: the CPU, cache and I/O are one package.
M.recipe({
  name = "system-on-chip",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 20,
  ingredients = {
    M.item("vlsi-die", 4),
    M.item("low-k-dielectric", 2),
    M.item("copper-plate", 2),
  },
  results = { M.item("system-on-chip", 1) },
})

-- Advanced packaging: two or more dies on one interposer.
M.recipe({
  name = "chiplet",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 24,
  ingredients = {
    M.item("system-on-chip", 2),
    M.item("low-k-dielectric", 2),
    M.item("copper-plate", 4),
  },
  results = { M.item("chiplet", 1) },
})

-- Stacked memory: several VLSI dies bonded into one HBM stack.
M.recipe({
  name = "hbm-stack",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 18,
  ingredients = {
    M.item("vlsi-die", 2),
    M.item("copper-plate", 2),
    M.item("plastic-bar", 1),
  },
  results = { M.item("hbm-stack", 1) },
})

-- A GPU is a chiplet plus stacked memory, assembled and cooled in the VLSI Fab.
M.recipe({
  name = "gpu",
  enabled = false,
  category = "chiptorio-vlsi",
  energy_required = 30,
  ingredients = {
    M.item("chiplet", 2),
    M.item("hbm-stack", 2),
    M.fluid("coolant", 20),
  },
  results = { M.item("gpu", 1) },
})

-- Multi-core CPU: several chiplets and a memory stack in one package.
M.recipe({
  name = "multi-core-cpu",
  enabled = false,
  category = "chiptorio-compute",
  energy_required = 30,
  ingredients = {
    M.item("chiplet", 2),
    M.item("hbm-stack", 1),
    M.item("system-on-chip", 1),
  },
  results = { M.item("multi-core-cpu", 1) },
})
