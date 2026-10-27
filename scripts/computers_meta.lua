-- Computer definitions.
--
-- Pure: no `data`, `game` or `storage` access. `scripts/computers.lua` turns
-- these entries into prototypes.
--
-- Each computer:
--   name      internal item/prototype name
--   label     visible name key prefix
--   order     prototype sort order
--   gate      technology that unlocks the recipe
--   tint      icon tint
--   energy    recipe energy_required (seconds)
--   results   recipe result count (default 1)
--   base      base recipe ingredients (board + chip + memory)
--   profile   compute profile contributed when installed in a provider:
--             scalar, vector, tensor, quantum (compute/s), memory, bandwidth
--   power     power draw (kW) when installed
--   heat      heat produced when installed
--
-- Computers are modules (`category = chiptorio-computer`). Racks and
-- datacenters hold them in module slots. A computer bundles its own compute
-- and memory; there are no separate chip or memory slots in providers.

local M = {}

M.COMPUTERS = {
  {
    name = "microcomputer",
    label = "microcomputer",
    order = "a[microcomputer]",
    gate = "internet",
    tint = { r = 0.55, g = 0.70, b = 0.95 },
    energy = 8,
    results = 1,
    base = {
      { type = "item", name = "processing-unit", amount = 1 },   -- Compute Board
      { type = "item", name = "microprocessor", amount = 1 },
      { type = "item", name = "sram-module", amount = 1 },
    },
    profile = { scalar = 8, memory = 256, bandwidth = 32 },
    power = 25,
    heat = 2,
  },
  {
    name = "server",
    label = "server",
    order = "b[server]",
    gate = "process-350nm",
    tint = { r = 0.45, g = 0.65, b = 0.85 },
    energy = 10,
    results = 1,
    base = {
      { type = "item", name = "advanced-circuit", amount = 1 },  -- Advanced Control Board
      { type = "item", name = "system-on-chip", amount = 1 },
      { type = "item", name = "ddr3-module", amount = 1 },
    },
    profile = { scalar = 32, memory = 512, bandwidth = 64 },
    power = 60,
    heat = 4,
  },
  {
    name = "supercomputer",
    label = "supercomputer",
    order = "c[supercomputer]",
    gate = "process-90nm",
    tint = { r = 0.20, g = 0.70, b = 0.40 },
    energy = 12,
    results = 1,
    base = {
      { type = "item", name = "accelerator-board", amount = 1 },
      { type = "item", name = "gpu", amount = 1 },
      { type = "item", name = "hbm-module", amount = 1 },
    },
    profile = { scalar = 8, vector = 64, memory = 1024, bandwidth = 128 },
    power = 100,
    heat = 6,
  },
  {
    name = "neural-computer",
    label = "neural-computer",
    order = "d[neural-computer]",
    gate = "heterogeneous-compute",
    tint = { r = 0.70, g = 0.30, b = 0.90 },
    energy = 15,
    results = 1,
    base = {
      { type = "item", name = "neural-board", amount = 1 },
      { type = "item", name = "neural-processor", amount = 1 },
      { type = "item", name = "hbm3-module", amount = 1 },
    },
    profile = { scalar = 4, vector = 32, tensor = 128, memory = 2048, bandwidth = 256 },
    power = 150,
    heat = 8,
  },
  {
    name = "quantum-computer",
    label = "quantum-computer",
    order = "e[quantum-computer]",
    gate = "quantum-error-correction",
    tint = { r = 0.30, g = 0.20, b = 0.80 },
    energy = 20,
    results = 1,
    base = {
      { type = "item", name = "quantum-board", amount = 1 },
      { type = "item", name = "quantum-processor", amount = 1 },
      { type = "item", name = "3d-nand-module", amount = 1 },
    },
    profile = { scalar = 2, vector = 16, tensor = 64, quantum = 256, memory = 4096, bandwidth = 512 },
    power = 500,
    heat = 20,
  },
}

-- Computer Assembler machine definition.
M.ASSEMBLER = {
  name = "computer-assembler",
  base_type = "assembling-machine",
  base = "assembling-machine-2",
  category = "chiptorio-computer",
  speed = 1.0,
  power = "240kW",
  modules = 2,
  craft_time = 12,
  order = "b[computer-assembler]",
  custom_graphics = "computer-assembler",
  size_w = 160,
  size_h = 160,
  scale = 0.5,
  ingredients = {
    { type = "item", name = "iron-plate", amount = 15 },
    { type = "item", name = "steel-plate", amount = 10 },
    { type = "item", name = "electronic-circuit", amount = 5 },   -- Control Board
    { type = "item", name = "vacuum-tube", amount = 5 },
  },
  gate = "internet",
}

return M
