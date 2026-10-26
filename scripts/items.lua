-- All new intermediate items and the mod's own item groups.
--
-- Two kinds of prototype live here:
--   * ordinary items - feedstock, packaged devices and packaging components
--   * modules        - the compute and memory modules a provider can hold
--
-- Chips are modules rather than items because a provider's module inventory is
-- the only machine-readable "what is installed" surface in 2.1. The module
-- effect is empty; scripts/runtime/research_runtime.lua reads the prototype
-- names and turns them into compute with scripts/research_meta.lua.

local M = require("scripts.util")

-- Module categories. These are the Ctrl+click upgrade families and the
-- categories a provider accepts. Keep them separate: a memory module must
-- never silently replace a chip in a module slot.
data:extend({
  { type = "module-category", name = "chiptorio-chip" },
  { type = "module-category", name = "chiptorio-memory" },
})

do
  -- 2.1 requires an icon on item groups. Clone an existing one so we inherit
  -- a valid icon path/size instead of guessing.
  local base_group = data.raw["item-group"]["intermediate-products"]
  local group = M.copy(base_group)
  group.name = "chiptorio"
  group.localised_name = { "item-group-name.chiptorio" }
  group.order = "zzz[chiptorio]"
  group.icon = "__chiptorio__/graphics/icons/quantum-processor.png"
  group.icon_size = 64
  data:extend({ group })
end

data:extend({
  {
    type = "item-subgroup",
    name = "chiptorio-materials",
    group = "chiptorio",
    order = "a[materials]",
  },
  {
    type = "item-subgroup",
    name = "chiptorio-chips",
    group = "chiptorio",
    order = "b[chips]",
  },
  {
    type = "item-subgroup",
    name = "chiptorio-memory",
    group = "chiptorio",
    order = "c[memory]",
  },
  {
    type = "item-subgroup",
    name = "chiptorio-computers",
    group = "chiptorio",
    order = "d[computers]",
  },
  {
    type = "item-subgroup",
    name = "chiptorio-machines",
    group = "chiptorio",
    order = "e[machines]",
  },
  {
    type = "item-subgroup",
    name = "chiptorio-providers",
    group = "chiptorio",
    order = "f[providers]",
  },
})

local function make_material(name, order)
  local proto = M.item_from("iron-plate", name, "chiptorio-materials", order)
  M.set_icon(proto, name)
  return proto
end

local function make_chip(name, base, order)
  local proto = M.item_from(base, name, "chiptorio-chips", order)
  M.set_icon(proto, name)
  return proto
end

local function make_chip_module(name, base, order, tier)
  local proto = M.module_from(base, name, "chiptorio-chip", tier, "chiptorio-chips", order)
  M.set_icon(proto, name)
  return proto
end

local function make_memory_module(name, base, order, tier)
  local proto = M.module_from(base, name, "chiptorio-memory", tier, "chiptorio-memory", order)
  M.set_icon(proto, name)
  return proto
end

-- Feedstock -------------------------------------------------------------

make_material("silica", "a[silica]")
make_material("glass", "b[glass]")
make_material("metallurgical-silicon", "c[mg-si]")
make_material("polysilicon", "d[poly-si]")
make_material("monocrystalline-ingot", "e[ingot]")
make_material("silicon-wafer", "f[wafer]")
make_material("litho-mask", "g[mask]")
make_material("exposed-wafer", "h[exposed]")
make_material("etched-wafer", "i[etched]")
make_material("processed-wafer", "j[processed]")
make_material("bare-die", "k[die]")

-- Era 5-6 feedstock and packages ----------------------------------------

make_material("phase-shift-mask", "l[phase-mask]")
make_material("low-k-dielectric", "m[low-k]")
make_material("cooling-unit", "n[cooling-unit]")
make_material("vlsi-wafer", "o[vlsi-wafer]")
make_material("vlsi-die", "p[vlsi-die]")

-- Era 7 feedstock --------------------------------------------------------

make_material("superconductor", "q[superconductor]")

-- Components and packages ------------------------------------------------

make_chip("vacuum-tube", "electronic-circuit", "a[tube]")
make_chip("discrete-transistor", "electronic-circuit", "b[transistor]")
make_chip("chiplet", "processing-unit", "f[chiplet]")
make_chip("hbm-stack", "processing-unit", "g[hbm]")
make_chip("qubit", "processing-unit", "j[qubit]")
make_chip("error-corrected-qubit", "processing-unit", "k[logical-qubit]")

-- Compute modules --------------------------------------------------------
--
-- One module = one chip. The provider's slot count is the physical limit; the
-- profiles in scripts/research_meta.lua decide what each name contributes.

make_chip_module("integrated-circuit", "processing-unit", "c[ic]", 1)
make_chip_module("microprocessor", "processing-unit", "d[cpu]", 2)
make_chip_module("system-on-chip", "processing-unit", "e[soc]", 3)
make_chip_module("multi-core-cpu", "processing-unit", "i[multi-core]", 4)
make_chip_module("gpu", "processing-unit", "h[gpu]", 5)
make_chip_module("quantum-processor", "processing-unit", "l[quantum-cpu]", 6)

-- Memory modules ---------------------------------------------------------

make_memory_module("sram-module", "processing-unit", "a[sram]", 1)
make_memory_module("dram-module", "processing-unit", "b[dram]", 2)

-- The seventh workload. It is a tool item because labs consume it exactly
-- like a science pack; only the name and recipe are ours.
do
  local proto = M.item_from(
    "utility-science-pack",
    "quantum-science-pack",
    "science-pack",
    "g[quantum-science-pack]"
  )
  M.set_icon(proto, "qubit-array")
  proto.localised_name = { "item-name.qubit-array" }
  proto.localised_description = { "item-description.qubit-array" }
  proto.color_hint = { text = "Q" }
end
