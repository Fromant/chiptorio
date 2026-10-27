-- Process-node items: one mask set, one wafer family and one die family per
-- major node (DESIGN §4.4).
--
-- The icons are the existing wafer/die/mask art with a per-node tint, so
-- twelve nodes stay distinguishable without twelve hand-drawn PNGs. Recipe
-- costs and yields live in scripts/node_recipes.lua; the node table itself is
-- pure and lives in scripts/process_nodes.lua.

local M = require("scripts.util")
local nodes = require("scripts.process_nodes")

local function make_node_item(base, name, icon, tint, order)
  local proto = M.item_from(base, name, "chiptorio-materials", order)
  M.set_tinted_icon(proto, icon, tint)
  proto.localised_name = { "item-name." .. name }
  proto.localised_description = nil
  return proto
end

for index, node in ipairs(nodes.NODES) do
  local names = nodes.items(node.key)
  local prefix = string.format("%02d", index)
  make_node_item("litho-mask", names.mask, "litho-mask", node.tint, prefix .. "-a[process-mask]")
  make_node_item("silicon-wafer", names.wafer, "silicon-wafer", node.tint, prefix .. "-b[node-wafer]")
  make_node_item("bare-die", names.die, "bare-die", node.tint, prefix .. "-c[node-die]")
end
