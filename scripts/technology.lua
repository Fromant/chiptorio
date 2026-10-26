-- New technologies. Costs are expressed in the re-flavoured workloads:
--   automation-science-pack = punched cards
--   logistic-science-pack   = punched tape
--   military-science-pack   = magnetic tape
--   chemical-science-pack   = disk packs
--   quantum-science-pack    = qubit arrays

local M = require("scripts.util")
local meta = require("scripts.tech_meta")

local function ingredients(list)
  local out = {}
  -- Technology science ingredients are the legacy positional form
  -- {"item-name", amount} - not the typed recipe-ingredient struct.
  for name, amount in pairs(list) do
    table.insert(out, { name, amount })
  end
  return out
end

local techs = {
  {
    name = "electromechanics",
    order = "a[chipotrio]-a",
    count = 20,
    time = 10,
    cost = { ["automation-science-pack"] = 1 },
    prerequisites = {},
    effects = {},
  },
  {
    name = "thermionics",
    order = "a[chipotrio]-b",
    count = 40,
    time = 15,
    cost = {
      ["automation-science-pack"] = 1,
      ["logistic-science-pack"] = 1,
    },
    prerequisites = { "electromechanics" },
    effects = {
      "silica",
      "glass",
      "vacuum-tube",
      "tube-mainframe",
    },
  },
  {
    name = "semiconductor-physics",
    order = "a[chipotrio]-c",
    count = 75,
    time = 20,
    cost = {
      ["automation-science-pack"] = 1,
      ["logistic-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
    },
    prerequisites = { "thermionics", "chemical-science-pack" },
    effects = {
      "crystal-puller",
      "metallurgical-silicon",
      "polysilicon",
    },
  },
  {
    name = "crystal-growth",
    order = "a[chipotrio]-d",
    count = 100,
    time = 25,
    cost = {
      ["logistic-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
    },
    prerequisites = { "semiconductor-physics" },
    effects = {
      "monocrystalline-ingot",
      "silicon-wafer",
    },
  },
  {
    name = "photolithography",
    order = "a[chipotrio]-e",
    count = 150,
    time = 30,
    cost = {
      ["logistic-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
    },
    prerequisites = { "crystal-growth" },
    effects = {
      "wafer-fab",
      "photoresist",
      "etchant",
      "litho-mask",
      "exposed-wafer",
      "etched-wafer",
      "processed-wafer",
      "bare-die",
      "discrete-transistor",
    },
  },
  {
    name = "planar-process",
    order = "a[chipotrio]-f",
    count = 200,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["military-science-pack"] = 1,
    },
    prerequisites = { "photolithography" },
    effects = {
      "server-rack",
      "integrated-circuit",
      "mainframe-cluster",
    },
  },
  {
    name = "microarchitecture",
    order = "a[chipotrio]-g",
    count = 300,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
    },
    prerequisites = { "planar-process" },
    effects = {
      "microprocessor",
    },
  },
  {
    name = "vlsi-process",
    order = "a[chipotrio]-h",
    count = 250,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "microarchitecture" },
    effects = {
      "vlsi-fab",
      "cooling-tower",
      "coolant",
      "cooling-unit",
      "phase-shift-mask",
      "cmp-slurry",
      "low-k-dielectric",
      "vlsi-wafer",
      "vlsi-die",
      "system-on-chip",
    },
  },
  {
    name = "datacenter",
    order = "a[chipotrio]-i",
    count = 300,
    time = 30,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "vlsi-process" },
    effects = {
      "datacenter",
    },
  },
  {
    name = "advanced-packaging",
    order = "a[chipotrio]-j",
    count = 400,
    time = 40,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "datacenter" },
    effects = {
      "chiplet",
      "hbm-stack",
      "gpu",
    },
  },
  {
    name = "heterogeneous-compute",
    order = "a[chipotrio]-k",
    count = 500,
    time = 40,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "advanced-packaging" },
    effects = {
      "multi-core-cpu",
    },
  },
  {
    name = "quantum-computing",
    order = "a[chipotrio]-l",
    count = 600,
    time = 45,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "heterogeneous-compute" },
    effects = {
      "cryostat",
      "quantum-fab",
      "cryogen",
      "superconductor",
      "qubit",
      "quantum-science-pack",
    },
  },
  {
    name = "quantum-error-correction",
    order = "a[chipotrio]-m",
    count = 400,
    time = 60,
    cost = {
      ["quantum-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "quantum-computing" },
    effects = {
      "error-corrected-qubit",
    },
  },
  {
    name = "quantum-advantage",
    order = "a[chipotrio]-n",
    count = 500,
    time = 60,
    cost = {
      ["quantum-science-pack"] = 2,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "quantum-error-correction" },
    effects = {
      "quantum-processor",
    },
  },
  {
    -- The final technology is infinite: level 1 unlocks the Answer Engine,
    -- and every further level raises the engine's demand and score.
    name = "the-question",
    order = "a[chipotrio]-z",
    count_formula = "500 * L",
    time = 60,
    cost = {
      ["automation-science-pack"] = 1,
      ["logistic-science-pack"] = 1,
      ["military-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
      ["quantum-science-pack"] = 1,
      ["microprocessor"] = 1,
    },
    prerequisites = {
      "electromechanics",
      "thermionics",
      "semiconductor-physics",
      "crystal-growth",
      "photolithography",
      "planar-process",
      "microarchitecture",
      "vlsi-process",
      "datacenter",
      "advanced-packaging",
      "heterogeneous-compute",
      "quantum-computing",
      "quantum-error-correction",
      "quantum-advantage",
    },
    effects = {
      "answer-engine",
    },
    infinite = true,
  },
}

for _, spec in ipairs(techs) do
  local effects = {}
  for _, recipe in ipairs(spec.effects) do
    table.insert(effects, { type = "unlock-recipe", recipe = recipe })
  end

  local unit = {
    time = spec.time,
    ingredients = ingredients(spec.cost),
  }
  if spec.count_formula then
    unit.count_formula = spec.count_formula
  else
    unit.count = spec.count
  end

  local proto = {
    type = "technology",
    name = spec.name,
    icons = {
      { icon = "__chipotrio__/graphics/technology/" .. spec.name .. ".png", icon_size = 256 },
    },
    order = spec.order,
    prerequisites = spec.prerequisites,
    effects = effects,
    unit = unit,
  }
  if spec.infinite then
    proto.max_level = "infinite"
  end

  local gate = meta[spec.name]
  if gate then
    proto.localised_description = {
      "technology-description.chipotrio-gated",
      tostring(gate.rate),
      { "item-name." .. gate.item },
    }
  end

  data:extend({ proto })
end
