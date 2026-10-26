-- All new intermediate items and the mod's own item groups.

local M = require("scripts.util")

do
  -- 2.1 requires an icon on item groups. Clone an existing one so we inherit
  -- a valid icon path/size instead of guessing.
  local base_group = data.raw["item-group"]["intermediate-products"]
  local group = M.copy(base_group)
  group.name = "chipotrio"
  group.localised_name = { "item-group-name.chipotrio" }
  group.order = "zzz[chipotrio]"
  group.icon = "__chipotrio__/graphics/icons/quantum-processor.png"
  group.icon_size = 64
  data:extend({ group })
end

data:extend({
  {
    type = "item-subgroup",
    name = "chipotrio-materials",
    group = "chipotrio",
    order = "a[materials]",
  },
  {
    type = "item-subgroup",
    name = "chipotrio-chips",
    group = "chipotrio",
    order = "b[chips]",
  },
  {
    type = "item-subgroup",
    name = "chipotrio-computers",
    group = "chipotrio",
    order = "c[computers]",
  },
  {
    type = "item-subgroup",
    name = "chipotrio-machines",
    group = "chipotrio",
    order = "d[machines]",
  },
})

local function make_material(name, order)
  local proto = M.item_from("iron-plate", name, "chipotrio-materials", order)
  M.set_icon(proto, name)
  return proto
end

local function make_chip(name, base, order)
  local proto = M.item_from(base, name, "chipotrio-chips", order)
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

-- Devices ---------------------------------------------------------------

make_chip("vacuum-tube", "electronic-circuit", "a[tube]")
make_chip("discrete-transistor", "electronic-circuit", "b[transistor]")
make_chip("integrated-circuit", "processing-unit", "c[ic]")
make_chip("microprocessor", "processing-unit", "d[cpu]")
make_chip("system-on-chip", "processing-unit", "e[soc]")
make_chip("chiplet", "processing-unit", "f[chiplet]")
make_chip("hbm-stack", "processing-unit", "g[hbm]")
make_chip("gpu", "processing-unit", "h[gpu]")
make_chip("multi-core-cpu", "processing-unit", "i[multi-core]")
make_chip("qubit", "processing-unit", "j[qubit]")
make_chip("error-corrected-qubit", "processing-unit", "k[logical-qubit]")
make_chip("quantum-processor", "processing-unit", "l[quantum-cpu]")

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
