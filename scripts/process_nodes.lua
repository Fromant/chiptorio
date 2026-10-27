-- Process-node ladder and half-node refinements.
--
-- This module is pure data. Both the data stage (to generate items, recipes and
-- technologies) and the runtime (for qualification, later) read the same table.
-- It must never touch `data`, `game` or `storage`.
--
-- DESIGN §4.4 and §4.5. Twelve major nodes, each a full manufacturing family:
--   node-<key>-mask    the lithography mask set / process kit
--   node-<key>-wafer   exposed and metallised wafers
--   node-<key>-die     the diced transistor family of that node
-- The architecture chips (integrated circuit, microprocessor, SoC, GPU,
-- multi-core, QPU) are packaged from these dies; a node does not invent a new
-- chip name, it makes the existing names cheaper and available.

local M = {}

-- tint is applied to the shared wafer/die/mask icons so twelve nodes are
-- visually distinguishable without twelve hand-drawn icons.
M.NODES = {
  {
    key = "10um",
    label = "10 µm",
    year = 1971,
    lithography = "Contact",
    transistor = "PMOS",
    wafer_mm = 50,
    packaging = "Wire bond / DIP",
    dies = 40,
    order = "a[10um]",
    tint = { r = 0.95, g = 0.55, b = 0.45 },
    mask = { "litho-mask", 1 },
    extra = nil,
    chips = { "integrated-circuit" },
    science = {
      ["automation-science-pack"] = 1,
      ["logistic-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
    },
  },
  {
    key = "3um",
    label = "3 µm",
    year = 1977,
    lithography = "Projection",
    transistor = "CMOS",
    wafer_mm = 100,
    packaging = "DIP / QFP",
    dies = 60,
    order = "b[3um]",
    tint = { r = 0.95, g = 0.72, b = 0.35 },
    mask = { "litho-mask", 2 },
    extra = nil,
    chips = { "integrated-circuit", "microprocessor" },
    science = {
      ["logistic-science-pack"] = 1,
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
    },
  },
  {
    key = "1um",
    label = "1 µm",
    year = 1985,
    lithography = "i-line",
    transistor = "CMOS",
    wafer_mm = 150,
    packaging = "QFP / PGA",
    dies = 80,
    order = "c[1um]",
    tint = { r = 0.85, g = 0.85, b = 0.35 },
    mask = { "litho-mask", 3 },
    extra = nil,
    chips = { "integrated-circuit", "microprocessor" },
    science = {
      ["chemical-science-pack"] = 1,
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
  },
  {
    key = "350nm",
    label = "350 nm",
    year = 1994,
    lithography = "KrF DUV",
    transistor = "CMOS",
    wafer_mm = 200,
    packaging = "BGA",
    dies = 100,
    order = "d[350nm]",
    tint = { r = 0.55, g = 0.95, b = 0.55 },
    mask = { "phase-shift-mask", 1 },
    extra = { type = "fluid", name = "coolant", amount = 10 },
    chips = { "system-on-chip" },
    science = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
    },
  },
  {
    key = "180nm",
    label = "180 nm",
    year = 1999,
    lithography = "KrF DUV",
    transistor = "CMOS",
    wafer_mm = 200,
    packaging = "Flip-chip",
    dies = 120,
    order = "e[180nm]",
    tint = { r = 0.40, g = 0.90, b = 0.85 },
    mask = { "phase-shift-mask", 1 },
    extra = { type = "fluid", name = "coolant", amount = 10 },
    chips = { "system-on-chip" },
    science = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
    },
  },
  {
    key = "90nm",
    label = "90 nm",
    year = 2003,
    lithography = "ArF DUV",
    transistor = "Strained silicon",
    wafer_mm = 300,
    packaging = "Flip-chip",
    dies = 160,
    order = "f[90nm]",
    tint = { r = 0.35, g = 0.75, b = 0.95 },
    mask = { "phase-shift-mask", 2 },
    extra = { type = "fluid", name = "coolant", amount = 20 },
    chips = { "system-on-chip", "gpu" },
    science = {
      ["production-science-pack"] = 1,
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
    },
  },
  {
    key = "45nm",
    label = "45 nm",
    year = 2007,
    lithography = "Immersion",
    transistor = "High-k metal gate",
    wafer_mm = 300,
    packaging = "Flip-chip",
    dies = 200,
    order = "g[45nm]",
    tint = { r = 0.45, g = 0.55, b = 0.95 },
    mask = { "phase-shift-mask", 2 },
    extra = { type = "fluid", name = "coolant", amount = 20 },
    chips = { "gpu" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
    },
  },
  {
    key = "22nm",
    label = "22 nm",
    year = 2011,
    lithography = "Multi-patterning",
    transistor = "FinFET",
    wafer_mm = 300,
    packaging = "2.5D",
    dies = 240,
    order = "h[22nm]",
    tint = { r = 0.65, g = 0.45, b = 0.95 },
    mask = { "phase-shift-mask", 3 },
    extra = { type = "fluid", name = "coolant", amount = 30 },
    chips = { "gpu", "multi-core-cpu" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
    },
  },
  {
    key = "14nm",
    label = "14 nm",
    year = 2014,
    lithography = "Multi-patterning",
    transistor = "FinFET",
    wafer_mm = 300,
    packaging = "2.5D",
    dies = 280,
    order = "i[14nm]",
    tint = { r = 0.90, g = 0.45, b = 0.85 },
    mask = { "phase-shift-mask", 3 },
    extra = { type = "fluid", name = "coolant", amount = 30 },
    chips = { "gpu", "multi-core-cpu" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
    },
  },
  {
    key = "7nm",
    label = "7 nm",
    year = 2018,
    lithography = "EUV",
    transistor = "FinFET",
    wafer_mm = 300,
    packaging = "Chiplet",
    dies = 320,
    order = "j[7nm]",
    tint = { r = 0.95, g = 0.35, b = 0.65 },
    mask = { "phase-shift-mask", 4 },
    extra = { type = "fluid", name = "coolant", amount = 40 },
    chips = { "multi-core-cpu", "quantum-processor" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-optical-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
      ["chiptorio-quantum-science-pack"] = 1,
    },
  },
  {
    key = "3nm",
    label = "3 nm",
    year = 2022,
    lithography = "EUV",
    transistor = "Gate-all-around",
    wafer_mm = 300,
    packaging = "3D",
    dies = 360,
    order = "k[3nm]",
    tint = { r = 0.95, g = 0.30, b = 0.45 },
    mask = { "phase-shift-mask", 4 },
    extra = { type = "fluid", name = "coolant", amount = 40 },
    chips = { "multi-core-cpu", "quantum-processor" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
      ["chiptorio-quantum-science-pack"] = 1,
    },
  },
  {
    key = "1-4nm",
    label = "1.4 nm",
    year = 2028,
    lithography = "High-NA EUV",
    transistor = "CFET",
    wafer_mm = 300,
    packaging = "Hybrid bonding",
    dies = 400,
    order = "l[1-4nm]",
    tint = { r = 0.80, g = 0.25, b = 0.95 },
    mask = { "phase-shift-mask", 5 },
    extra = { type = "fluid", name = "coolant", amount = 50 },
    chips = { "multi-core-cpu", "quantum-processor" },
    science = {
      ["utility-science-pack"] = 1,
      ["chiptorio-hbm-science-pack"] = 1,
      ["chiptorio-quantum-science-pack"] = 1,
    },
  },
}

-- Ten half-node refinements. A half-node adds no wafer/die family: it qualifies
-- the previous major node and then applies a force-wide bonus. The table is the
-- single source of truth for the data stage (pilot recipe and technology) and
-- the runtime (qualification progress and bonuses). DESIGN §4.5.
--
-- `bonus.yield` multiplies the previous node's wafer and die output,
-- `bonus.compute` multiplies the compute of every chip in the force, and
-- `bonus.power` scales provider power and heat. The runtime multiplies them
-- over the qualified set, so they accumulate without ever stacking twice on one
-- recipe.
--
-- Keys must be prototype-safe: "1.5um" would fail at load ("Invalid prototype
-- name"), so the key is "1-5um" and only the label contains the dot.
M.HALF_NODES = {
  {
    key = "6um",
    label = "6 µm",
    between = { "10um", "3um" },
    tint = { r = 0.95, g = 0.55, b = 0.45 },
    samples = 50,
    analysis_time = 1.5,
    requires_network = false,
    bonus = { yield = 1.10, compute = 1.05, power = 0.95 },
  },
  {
    key = "1-5um",
    label = "1.5 µm",
    between = { "3um", "1um" },
    tint = { r = 0.95, g = 0.72, b = 0.35 },
    samples = 60,
    analysis_time = 1.5,
    requires_network = false,
    bonus = { yield = 1.10, compute = 1.05, power = 0.95 },
  },
  {
    key = "800nm",
    label = "800 nm",
    between = { "1um", "350nm" },
    tint = { r = 0.85, g = 0.85, b = 0.35 },
    samples = 70,
    analysis_time = 1.75,
    requires_network = true,
    bonus = { yield = 1.15, compute = 1.05, power = 0.90 },
  },
  {
    key = "250nm",
    label = "250 nm",
    between = { "350nm", "180nm" },
    tint = { r = 0.55, g = 0.95, b = 0.55 },
    samples = 80,
    analysis_time = 1.75,
    requires_network = true,
    bonus = { yield = 1.15, compute = 1.05, power = 0.90 },
  },
  {
    key = "130nm",
    label = "130 nm",
    between = { "180nm", "90nm" },
    tint = { r = 0.40, g = 0.90, b = 0.85 },
    samples = 90,
    analysis_time = 2.0,
    requires_network = true,
    bonus = { yield = 1.15, compute = 1.10, power = 0.90 },
  },
  {
    key = "65nm",
    label = "65 nm",
    between = { "90nm", "45nm" },
    tint = { r = 0.35, g = 0.75, b = 0.95 },
    samples = 100,
    analysis_time = 2.0,
    requires_network = true,
    bonus = { yield = 1.20, compute = 1.10, power = 0.85 },
  },
  {
    key = "32nm",
    label = "32 nm",
    between = { "45nm", "22nm" },
    tint = { r = 0.45, g = 0.55, b = 0.95 },
    samples = 105,
    analysis_time = 2.25,
    requires_network = true,
    bonus = { yield = 1.20, compute = 1.10, power = 0.85 },
  },
  {
    key = "10nm",
    label = "10 nm",
    between = { "14nm", "7nm" },
    tint = { r = 0.90, g = 0.45, b = 0.85 },
    samples = 110,
    analysis_time = 2.25,
    requires_network = true,
    bonus = { yield = 1.20, compute = 1.15, power = 0.85 },
  },
  {
    key = "5nm",
    label = "5 nm",
    between = { "7nm", "3nm" },
    tint = { r = 0.95, g = 0.35, b = 0.65 },
    samples = 120,
    analysis_time = 2.5,
    requires_network = true,
    bonus = { yield = 1.25, compute = 1.15, power = 0.80 },
  },
  {
    key = "2nm",
    label = "2 nm",
    between = { "3nm", "1-4nm" },
    tint = { r = 0.95, g = 0.30, b = 0.45 },
    samples = 150,
    analysis_time = 3.0,
    requires_network = true,
    bonus = { yield = 1.25, compute = 1.20, power = 0.80 },
  },
}

--- Index of an entry with `key` in a list, or nil.
local function index_of(list, key)
  for index, entry in ipairs(list) do
    if entry.key == key then
      return index
    end
  end
  return nil
end

--- Look up a major node by key.
function M.node(key)
  local index = index_of(M.NODES, key)
  return index and M.NODES[index] or nil
end

--- Look up a half-node by key.
function M.half_node(key)
  local index = index_of(M.HALF_NODES, key)
  return index and M.HALF_NODES[index] or nil
end

--- Position of a major node in the roadmap, or nil.
function M.major_index(key)
  return index_of(M.NODES, key)
end

--- Position of a half-node in the roadmap, or nil.
function M.half_index(key)
  return index_of(M.HALF_NODES, key)
end

--- Item names for one node. One function so the data stage and tests cannot
--- disagree about the naming scheme.
function M.items(key)
  return {
    mask = "node-" .. key .. "-mask",
    wafer = "node-" .. key .. "-wafer",
    die = "node-" .. key .. "-die",
  }
end

--- Technology name for a major node.
function M.tech_name(key)
  return "process-" .. key
end

--- Technology name for a half-node refinement.
function M.half_tech_name(key)
  return "refine-" .. key
end

--- The Process Qualification Wafer item and its pilot recipe. A recipe may share
--- an item's name in Factorio, so both are the same prototype-safe string.
function M.qualification_item(key)
  return "refine-" .. key .. "-qualification-wafer"
end

function M.qualification_recipe(key)
  return M.qualification_item(key)
end

--- The major node a half-node refines.
function M.refined_node(key)
  local half = M.half_node(key)
  return half and half.between[1] or nil
end

local function is_qualified(qualified, key)
  if not qualified then
    return false
  end
  if qualified[key] then
    return true
  end
  -- Accept a list of keys as well as a set, so callers can pass either.
  for _, value in ipairs(qualified) do
    if value == key then
      return true
    end
  end
  return false
end

--- Product of every bonus over the qualified half-nodes. With nothing qualified
--- all three multipliers are 1; the result is a plain table the data stage and
--- the runtime can both use.
function M.total_bonus(qualified)
  local bonus = { yield = 1, compute = 1, power = 1 }
  for _, half in ipairs(M.HALF_NODES) do
    if is_qualified(qualified, half.key) then
      bonus.yield = bonus.yield * half.bonus.yield
      bonus.compute = bonus.compute * half.bonus.compute
      bonus.power = bonus.power * half.bonus.power
    end
  end
  return bonus
end

return M
