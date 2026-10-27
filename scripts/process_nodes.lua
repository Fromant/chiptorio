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

-- Ten half-node refinements. They add no wafer/die family: they qualify the
-- previous major node and give it a global yield/compute improvement. Phase 4
-- implements the Metrology Lab; the table is defined now so the data is one
-- source of truth and the contract can check it.
M.HALF_NODES = {
  {
    key = "6um",
    label = "6 µm",
    between = { "10um", "3um" },
    samples = 50,
    yield = 1.10,
    compute = 1.05,
    power = 0.95,
    requires_network = false,
  },
  {
    key = "1.5um",
    label = "1.5 µm",
    between = { "3um", "1um" },
    samples = 60,
    yield = 1.10,
    compute = 1.05,
    power = 0.95,
    requires_network = false,
  },
  {
    key = "800nm",
    label = "800 nm",
    between = { "1um", "350nm" },
    samples = 70,
    yield = 1.15,
    compute = 1.05,
    power = 0.90,
    requires_network = true,
  },
  {
    key = "250nm",
    label = "250 nm",
    between = { "350nm", "180nm" },
    samples = 80,
    yield = 1.15,
    compute = 1.05,
    power = 0.90,
    requires_network = true,
  },
  {
    key = "130nm",
    label = "130 nm",
    between = { "180nm", "90nm" },
    samples = 90,
    yield = 1.15,
    compute = 1.10,
    power = 0.90,
    requires_network = true,
  },
  {
    key = "65nm",
    label = "65 nm",
    between = { "90nm", "45nm" },
    samples = 100,
    yield = 1.20,
    compute = 1.10,
    power = 0.85,
    requires_network = true,
  },
  {
    key = "32nm",
    label = "32 nm",
    between = { "45nm", "22nm" },
    samples = 105,
    yield = 1.20,
    compute = 1.10,
    power = 0.85,
    requires_network = true,
  },
  {
    key = "10nm",
    label = "10 nm",
    between = { "14nm", "7nm" },
    samples = 110,
    yield = 1.20,
    compute = 1.15,
    power = 0.85,
    requires_network = true,
  },
  {
    key = "5nm",
    label = "5 nm",
    between = { "7nm", "3nm" },
    samples = 120,
    yield = 1.25,
    compute = 1.15,
    power = 0.80,
    requires_network = true,
  },
  {
    key = "2nm",
    label = "2 nm",
    between = { "3nm", "1-4nm" },
    samples = 150,
    yield = 1.25,
    compute = 1.20,
    power = 0.80,
    requires_network = true,
  },
}

--- Look up a major node by key.
function M.node(key)
  for _, node in ipairs(M.NODES) do
    if node.key == key then
      return node
    end
  end
  return nil
end

--- Look up a half-node by key.
function M.half_node(key)
  for _, half in ipairs(M.HALF_NODES) do
    if half.key == key then
      return half
    end
  end
  return nil
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

--- Die yield multiplier of every completed half-node before this node.
function M.half_bonus(node_key)
  local order = {}
  local target
  for index, node in ipairs(M.NODES) do
    order[node.key] = index
    if node.key == node_key then
      target = index
    end
  end
  if not target then
    return 1
  end
  local bonus = 1
  for _, half in ipairs(M.HALF_NODES) do
    local reached = order[half.between[2]]
    if reached and reached <= target then
      bonus = bonus * half.yield
    end
  end
  return bonus
end

return M
