-- Process fluids. Cloned from heavy oil so all fluid rendering fields are
-- valid for 2.1 without hand-writing a prototype.

local M = require("scripts.util")

local function make_fluid(name, color)
  local base = data.raw.fluid["heavy-oil"]
  local proto = M.copy(base)
  proto.name = name
  proto.localised_name = nil
  proto.default_temperature = 15
  proto.max_temperature = 100
  proto.base_color = color
  proto.flow_color = {
    r = math.min(1, color.r + 0.15),
    g = math.min(1, color.g + 0.15),
    b = math.min(1, color.b + 0.15),
  }
  proto.hidden = false
  M.set_entity_icon(proto, name)
  data:extend({ proto })
  return proto
end

make_fluid("photoresist", { r = 0.85, g = 0.35, b = 0.10 })
make_fluid("etchant", { r = 0.20, g = 0.70, b = 0.55 })
make_fluid("cmp-slurry", { r = 0.65, g = 0.68, b = 0.72 })
make_fluid("coolant", { r = 0.15, g = 0.55, b = 0.90 })
make_fluid("cryogen", { r = 0.35, g = 0.20, b = 0.95 })
