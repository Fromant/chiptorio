-- New technologies. Costs are expressed in the re-flavoured workloads:
--   automation-science-pack        = punched cards
--   logistic-science-pack          = punched tape
--   military-science-pack          = magnetic tape
--   chemical-science-pack          = disk packs
--   production-science-pack        = solid-state drives
--   utility-science-pack           = mainframe modules
--   chiptorio-optical-science-pack = optical discs
--   chiptorio-hbm-science-pack     = HBM stacks
--   chiptorio-quantum-science-pack = qubit arrays
--
-- The twelve process-node technologies are generated from
-- scripts/process_nodes.lua at the bottom of this file: the node table owns the
-- manufacturing content and the science cost, this file owns the tech-tree
-- position.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

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
    order = "a[chiptorio]-a",
    count = 20,
    time = 10,
    cost = { ["automation-science-pack"] = 1 },
    prerequisites = {},
    effects = {},
  },
  {
    name = "thermionics",
    order = "a[chiptorio]-b",
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
    order = "a[chiptorio]-c",
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
    order = "a[chiptorio]-d",
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
    order = "a[chiptorio]-e",
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
    order = "a[chiptorio]-f",
    count = 200,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["military-science-pack"] = 1,
    },
    prerequisites = { "photolithography" },
    effects = {
      "mainframe-cluster",
    },
  },
  {
    name = "microarchitecture",
    order = "a[chiptorio]-g",
    count = 300,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
    },
    prerequisites = { "process-3um" },
    effects = {},
  },
  {
    -- The internet is the first network technology. It costs no compute: it is
    -- the thing that creates compute. DESIGN §7.4.
    name = "internet",
    order = "a[chiptorio]-g2",
    count = 200,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
    },
    prerequisites = { "microarchitecture" },
    effects = {
      -- The internet is also the first compute tier: the packaging machine,
      -- the first provider and the first memory module all arrive together.
      "assembly-fab",
      "server-rack",
      "memory-bank",
      "sram-module",
      "network-cable",
      "network-switch",
      "network-router",
      "network-monitor",
    },
  },
  {
    name = "vlsi-process",
    order = "a[chiptorio]-h",
    count = 250,
    time = 30,
    cost = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    -- The first compute-gated technology, so the network must exist first.
    prerequisites = { "internet", "process-1um" },
    effects = {
      "vlsi-fab",
      "cooling-tower",
      "coolant",
      "cooling-unit",
      "phase-shift-mask",
      "cmp-slurry",
      "low-k-dielectric",
    },
  },
  {
    name = "datacenter",
    order = "a[chiptorio]-i",
    count = 300,
    time = 30,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "vlsi-process", "process-350nm" },
    effects = {
      "datacenter",
      "datacenter-lab",
      "dram-module",
    },
  },
  {
    name = "advanced-packaging",
    order = "a[chiptorio]-j",
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
    },
  },
  {
    name = "heterogeneous-compute",
    order = "a[chiptorio]-k",
    count = 500,
    time = 40,
    cost = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "advanced-packaging" },
    effects = {},
  },
  {
    name = "quantum-computing",
    order = "a[chiptorio]-l",
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
      "chiptorio-quantum-science-pack",
    },
  },
  {
    name = "quantum-error-correction",
    order = "a[chiptorio]-m",
    count = 400,
    time = 60,
    cost = {
      ["chiptorio-quantum-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "quantum-computing" },
    effects = {
      "error-corrected-qubit",
    },
  },
  {
    name = "quantum-advantage",
    order = "a[chiptorio]-n",
    count = 500,
    time = 60,
    cost = {
      ["chiptorio-quantum-science-pack"] = 2,
      ["utility-science-pack"] = 1,
    },
    prerequisites = { "quantum-error-correction" },
    -- A pure gate: the quantum processor itself is packaged by the 7 nm,
    -- 3 nm and 1.4 nm node recipes.
    effects = {},
  },
  {
    -- The final technology is infinite: level 1 unlocks the Answer Engine,
    -- and every further level raises the engine's demand and score.
    name = "the-question",
    order = "a[chiptorio]-z",
    count_formula = "500 * L",
    time = 60,
    cost = {
      ["automation-science-pack"] = 1,
      ["logistic-science-pack"] = 1,
      ["military-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
      ["chiptorio-quantum-science-pack"] = 1,
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
      "internet",
      "vlsi-process",
      "datacenter",
      "advanced-packaging",
      "heterogeneous-compute",
      "quantum-computing",
      "quantum-error-correction",
      "quantum-advantage",
      "process-1-4nm",
    },
    effects = {
      "answer-engine",
    },
    infinite = true,
  },
}

-- Tech-tree position of each major process node. The manufacturing content
-- (mask/wafer/die recipes and chip packaging) is generated from the pure node
-- table in scripts/process_nodes.lua; this table only says when it unlocks.
-- The two custom science packs ride on the node that introduces their
-- feedstock: optical discs at 350 nm, HBM stacks at 90 nm.
local NODE_TECHS = {
  ["10um"] = {
    order = "a[chiptorio]-f1",
    count = 150,
    time = 30,
    prerequisites = { "photolithography" },
  },
  ["3um"] = {
    order = "a[chiptorio]-g1",
    count = 200,
    time = 30,
    prerequisites = { "process-10um" },
  },
  ["1um"] = {
    order = "a[chiptorio]-g3",
    count = 250,
    time = 30,
    prerequisites = { "process-3um", "microarchitecture" },
  },
  ["350nm"] = {
    order = "a[chiptorio]-h1",
    count = 300,
    time = 35,
    prerequisites = { "process-1um", "vlsi-process" },
    extra_effects = { "chiptorio-optical-science-pack" },
  },
  ["180nm"] = {
    order = "a[chiptorio]-i1",
    count = 350,
    time = 35,
    prerequisites = { "process-350nm" },
  },
  ["90nm"] = {
    order = "a[chiptorio]-j1",
    count = 450,
    time = 40,
    prerequisites = { "process-180nm", "advanced-packaging" },
    extra_effects = { "chiptorio-hbm-science-pack" },
  },
  ["45nm"] = {
    order = "a[chiptorio]-j2",
    count = 550,
    time = 45,
    prerequisites = { "process-90nm" },
  },
  ["22nm"] = {
    order = "a[chiptorio]-k1",
    count = 650,
    time = 45,
    prerequisites = { "process-45nm", "heterogeneous-compute" },
  },
  ["14nm"] = {
    order = "a[chiptorio]-k2",
    count = 800,
    time = 50,
    prerequisites = { "process-22nm" },
  },
  ["7nm"] = {
    order = "a[chiptorio]-l1",
    count = 1000,
    time = 55,
    prerequisites = { "process-14nm", "quantum-computing" },
  },
  ["3nm"] = {
    order = "a[chiptorio]-m1",
    count = 1200,
    time = 60,
    prerequisites = { "process-7nm", "quantum-error-correction" },
  },
  ["1-4nm"] = {
    order = "a[chiptorio]-n1",
    count = 1500,
    time = 60,
    prerequisites = { "process-3nm" },
  },
}

for _, node in ipairs(nodes.NODES) do
  local position = NODE_TECHS[node.key]
  if not position then
    error("chiptorio: process node '" .. node.key .. "' has no technology position")
  end

  local names = nodes.items(node.key)
  local effects = { names.mask, names.wafer, names.die }
  for _, chip in ipairs(node.chips) do
    effects[#effects + 1] = chip .. "-from-" .. node.key
  end
  for _, extra in ipairs(position.extra_effects or {}) do
    effects[#effects + 1] = extra
  end

  techs[#techs + 1] = {
    name = nodes.tech_name(node.key),
    order = position.order,
    count = position.count,
    time = position.time,
    cost = node.science,
    prerequisites = position.prerequisites,
    effects = effects,
  }
end

-- Half-node refinement technologies. Researching one unlocks the Metrology Lab,
-- the test structure and that half-node's pilot recipe. The bonus stays inactive
-- until the Process Qualification Wafers have been analysed, which the runtime
-- tracks per force (scripts/runtime/qualification_runtime.lua, DESIGN §4.5).
--
-- The tech costs half of the node it refines and sits directly behind that
-- node, so a refinement is always a detour, never a prerequisite for the next
-- major node. From 800 nm it also requires the internet, because the Metrology
-- Lab needs a network to analyse against.
for _, half in ipairs(nodes.HALF_NODES) do
  local previous = nodes.node(half.between[1])
  local position = previous and NODE_TECHS[previous.key]
  if not position then
    error("chiptorio: half-node '" .. half.key .. "' has no previous node technology")
  end

  local prerequisites = { nodes.tech_name(previous.key) }
  if half.requires_network then
    prerequisites[#prerequisites + 1] = "internet"
  end

  techs[#techs + 1] = {
    name = nodes.half_tech_name(half.key),
    -- "f1b" sorts directly after the node it refines and before the next node.
    order = position.order .. "b",
    count = math.floor(position.count / 2),
    time = position.time,
    cost = previous.science,
    prerequisites = prerequisites,
    effects = {
      "metrology-lab",
      "metrology-test-structure",
      nodes.qualification_recipe(half.key),
    },
  }
end

-- The final technology wants every refinement researched. Qualification is a
-- runtime state, not a technology, so it cannot be a prerequisite.
for _, spec in ipairs(techs) do
  if spec.name == "the-question" then
    for _, half in ipairs(nodes.HALF_NODES) do
      spec.prerequisites[#spec.prerequisites + 1] = nodes.half_tech_name(half.key)
    end
  end
end

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
      { icon = "__chiptorio__/graphics/technology/" .. spec.name .. ".png", icon_size = 256 },
    },
    order = spec.order,
    prerequisites = spec.prerequisites,
    effects = effects,
    unit = unit,
  }
  if spec.infinite then
    proto.max_level = "infinite"
  end

  data:extend({ proto })
end
