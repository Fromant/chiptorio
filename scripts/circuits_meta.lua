-- Board ladder definitions.
--
-- Pure: no `data`, `game` or `storage` access. `scripts/circuits.lua` turns
-- these entries into prototypes.
--
-- Each board tier:
--   name      internal item/prototype name. The first three reuse the vanilla
--             internal names (electronic-circuit, advanced-circuit,
--             processing-unit) so every existing recipe reference keeps working.
--   label     visible name key prefix (item-name.<label>, item-description.<label>)
--   order     prototype sort order
--   gate      technology that unlocks the base recipe
--   tint      icon tint for new board items (first three are re-themed vanilla)
--   energy    base recipe energy_required (seconds)
--   results   base recipe result count (default 1)
--   base      base recipe ingredients (array of M.item()-style ingredient tables)
--   alts      alternative recipes: later chips make older boards cheaper. Each
--             entry has gate, energy, results, ingredients. Recipe name is
--             "<board>-from-<source>".
--
-- Only the Integrated Circuit chip is still called a "circuit". Everything else
-- is a board — the passive carrier; the chip is the compute.

local M = {}

M.BOARDS = {
  {
    name = "electronic-circuit",
    label = "control-board",
    order = "a[control-board]",
    gate = "thermionics",
    tint = { r = 0.70, g = 0.55, b = 0.40 },
    energy = 4,
    results = 1,
    base = {
      { type = "item", name = "iron-plate", amount = 1 },
      { type = "item", name = "copper-cable", amount = 3 },
      { type = "item", name = "vacuum-tube", amount = 2 },
    },
    alts = {
      {
        gate = "process-10um",
        energy = 3,
        results = 1,
        ingredients = {
          { type = "item", name = "iron-plate", amount = 1 },
          { type = "item", name = "copper-cable", amount = 2 },
          { type = "item", name = "discrete-transistor", amount = 2 },
        },
      },
      {
        gate = "process-350nm",
        energy = 2,
        results = 4,
        ingredients = {
          { type = "item", name = "iron-plate", amount = 1 },
          { type = "item", name = "system-on-chip", amount = 1 },
        },
      },
    },
  },
  {
    name = "advanced-circuit",
    label = "advanced-control-board",
    order = "b[advanced-control-board]",
    gate = "process-10um",
    tint = { r = 0.85, g = 0.45, b = 0.35 },
    energy = 6,
    results = 1,
    base = {
      { type = "item", name = "electronic-circuit", amount = 1 },
      { type = "item", name = "discrete-transistor", amount = 2 },
      { type = "item", name = "integrated-circuit", amount = 1 },
      { type = "item", name = "plastic-bar", amount = 2 },
    },
    alts = {
      {
        gate = "process-180nm",
        energy = 5,
        results = 1,
        ingredients = {
          { type = "item", name = "electronic-circuit", amount = 1 },
          { type = "item", name = "microprocessor", amount = 1 },
          { type = "item", name = "plastic-bar", amount = 1 },
        },
      },
      {
        gate = "process-350nm",
        energy = 4,
        results = 2,
        ingredients = {
          { type = "item", name = "electronic-circuit", amount = 1 },
          { type = "item", name = "system-on-chip", amount = 1 },
        },
      },
    },
  },
  {
    name = "processing-unit",
    label = "compute-board",
    order = "c[compute-board]",
    gate = "process-3um",
    tint = { r = 0.45, g = 0.65, b = 0.85 },
    energy = 8,
    results = 1,
    base = {
      { type = "item", name = "advanced-circuit", amount = 1 },
      { type = "item", name = "microprocessor", amount = 1 },
      { type = "item", name = "copper-plate", amount = 2 },
      { type = "fluid", name = "sulfuric-acid", amount = 10 },
    },
    alts = {
      {
        gate = "process-90nm",
        energy = 7,
        results = 1,
        ingredients = {
          { type = "item", name = "advanced-circuit", amount = 1 },
          { type = "item", name = "system-on-chip", amount = 1 },
          { type = "item", name = "copper-plate", amount = 1 },
          { type = "fluid", name = "sulfuric-acid", amount = 5 },
        },
      },
      {
        gate = "process-22nm",
        energy = 6,
        results = 2,
        ingredients = {
          { type = "item", name = "advanced-circuit", amount = 1 },
          { type = "item", name = "multi-core-cpu", amount = 1 },
          { type = "fluid", name = "sulfuric-acid", amount = 5 },
        },
      },
    },
  },
  {
    name = "accelerator-board",
    label = "accelerator-board",
    order = "d[accelerator-board]",
    gate = "process-90nm",
    tint = { r = 0.20, g = 0.70, b = 0.40 },
    energy = 10,
    results = 1,
    base = {
      { type = "item", name = "processing-unit", amount = 1 },
      { type = "item", name = "gpu", amount = 1 },
      { type = "item", name = "hbm-stack", amount = 1 },
      { type = "item", name = "cooling-unit", amount = 10 },
    },
    alts = {
      {
        gate = "heterogeneous-compute",
        energy = 8,
        results = 1,
        ingredients = {
          { type = "item", name = "processing-unit", amount = 1 },
          { type = "item", name = "neural-processor", amount = 1 },
          { type = "item", name = "hbm-stack", amount = 1 },
          { type = "item", name = "cooling-unit", amount = 5 },
        },
      },
    },
  },
  {
    name = "neural-board",
    label = "neural-board",
    order = "e[neural-board]",
    gate = "heterogeneous-compute",
    tint = { r = 0.70, g = 0.30, b = 0.90 },
    energy = 12,
    results = 1,
    base = {
      { type = "item", name = "accelerator-board", amount = 1 },
      { type = "item", name = "neural-processor", amount = 1 },
      { type = "item", name = "superconductor", amount = 4 },
    },
    alts = {
      {
        gate = "quantum-error-correction",
        energy = 10,
        results = 1,
        ingredients = {
          { type = "item", name = "accelerator-board", amount = 1 },
          { type = "item", name = "quantum-processor", amount = 1 },
          { type = "item", name = "superconductor", amount = 2 },
        },
      },
    },
  },
  {
    name = "quantum-board",
    label = "quantum-board",
    order = "f[quantum-board]",
    gate = "quantum-error-correction",
    tint = { r = 0.30, g = 0.20, b = 0.80 },
    energy = 15,
    results = 1,
    base = {
      { type = "item", name = "neural-board", amount = 1 },
      { type = "item", name = "quantum-processor", amount = 1 },
      { type = "fluid", name = "cryogen", amount = 20 },
    },
    alts = {},
  },
}

-- Circuit Assembler machine definition.
M.ASSEMBLER = {
  name = "circuit-assembler",
  base_type = "assembling-machine",
  base = "assembling-machine-2",
  category = "chiptorio-circuit",
  speed = 1.0,
  power = "180kW",
  modules = 2,
  craft_time = 10,
  order = "a[circuit-assembler]",
  tint = { r = 0.60, g = 0.50, b = 0.40 },
  ingredients = {
    { type = "item", name = "iron-plate", amount = 10 },
    { type = "item", name = "copper-plate", amount = 10 },
    { type = "item", name = "iron-gear-wheel", amount = 5 },
    { type = "item", name = "vacuum-tube", amount = 5 },
  },
  gate = "thermionics",
}

return M
