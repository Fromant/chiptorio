-- Network wiring: physical-layer cables, switches and routers.
--
-- DESIGN §5.2 (rewritten). Networking is a physical layer problem:
--   * Cables collide with everything and route around machines.
--   * A machine connects only if physically adjacent to a cable/switch tile,
--     or within a router's wireless reach.
--   * Switches merge segments into one subnet; routers bridge subnets and
--     act as WiFi access points.
--   * Five cable tiers exist; a segment runs at the bandwidth of its weakest
--     link (weakest-link rule).
--
-- Nothing here knows about the graph. scripts/runtime/network_graph.lua turns
-- these entities into segments, subnets and networks; this file only defines
-- what they are.

local M = require("scripts.util")

data:extend({
  {
    type = "collision-layer",
    order = "50",
    name = "chiptorio-cable",
  },
})

local function rgba(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 1 }
end

--- Borrow a real world sprite from a base prototype.
local function donor(type_name, name)
  local prototypes = data.raw[type_name]
  local proto = prototypes and prototypes[name]
  if not proto then
    error("chiptorio: missing donor prototype " .. tostring(type_name) .. "/" .. tostring(name))
  end
  return proto
end

-- Cable tier definitions.
--   bandwidth: abstract units per tile of segment
--   latency:   abstract latency units per tile
--   tier:      numeric tier for weakest-link rule (lower = slower)
local CABLE_TIERS = {
  {
    name = "network-cable",
    label = "twisted-pair",
    tier = 1,
    bandwidth = 50,
    latency = 2,
    tint = rgba(0.85, 0.55, 0.30),
    donor_type = "pipe",
    donor = "pipe",
    size_w = 80,
    size_h = 80,
    scale = 0.6,
    craft_time = 0.5,
    stack_size = 200,
    amount = 4,
    ingredients = {
      M.item("copper-cable", 2),
      M.item("plastic-bar", 1),
    },
  },
  {
    name = "network-coaxial-cable",
    label = "coaxial",
    tier = 2,
    bandwidth = 200,
    latency = 2,
    tint = rgba(0.20, 0.60, 0.95),
    donor_type = "pipe",
    donor = "pipe",
    size_w = 80,
    size_h = 80,
    scale = 0.6,
    craft_time = 1,
    stack_size = 100,
    amount = 4,
    ingredients = {
      M.item("copper-cable", 4),
      M.item("plastic-bar", 2),
      M.item("steel-plate", 1),
    },
  },
  {
    name = "network-fiber-mm-cable",
    label = "multi-mode-fiber",
    tier = 3,
    bandwidth = 1000,
    latency = 1,
    tint = rgba(0.40, 0.95, 0.40),
    donor_type = "pipe",
    donor = "pipe",
    size_w = 80,
    size_h = 80,
    scale = 0.6,
    craft_time = 2,
    stack_size = 50,
    amount = 2,
    ingredients = {
      M.item("glass", 2),
      M.item("copper-cable", 2),
      M.item("advanced-circuit", 1),
    },
  },
  {
    name = "network-fiber-sm-cable",
    label = "single-mode-fiber",
    tier = 4,
    bandwidth = 5000,
    latency = 1,
    tint = rgba(0.70, 0.40, 0.95),
    donor_type = "pipe",
    donor = "pipe",
    size_w = 80,
    size_h = 80,
    scale = 0.6,
    craft_time = 4,
    stack_size = 25,
    amount = 1,
    ingredients = {
      M.item("glass", 4),
      M.item("hbm-stack", 1),
      M.item("superconductor", 1),
    },
  },
}

--- Make a 1×1 cable entity. Cables collide with everything (object layer)
--- so they cannot be placed on machines, belts or other cables, and nothing
--- can be placed on them. Routing around the factory is a real logistics
--- problem.
local function make_cable(spec)
  local base = data.raw.container["wooden-chest"]
  if not base then
    error("chiptorio: base container prototype not found")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = { "entity-name." .. spec.name }
  entity.localised_description = { "entity-description." .. spec.name }
  entity.minable = { mining_time = 0.05, result = spec.name }
  entity.corpse = nil
  entity.dying_explosion = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.inventory_size = 0
  entity.default_empty_slots_signal = nil
  -- Cables collide with everything on the object layer: they cannot be placed
  -- on machines, belts, or other cables, and nothing can be placed on them.
  -- Routing around the factory is a real logistics problem.
  entity.collision_layer = { layers = { ["object"] = true } }
  entity.collision_mask = { layers = { ["object"] = true } }
  M.set_world_picture(entity, donor(spec.donor_type, spec.donor), spec.tint)
  entity.icon_draw_specification = { scale = 0.5 }
  entity.max_health = 50
  entity.collision_box = { { -0.35, -0.35 }, { 0.35, 0.35 } }
  entity.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
  M.set_entity_icon(entity, spec.name)
  data:extend({ entity })

  local item = M.item_from("wooden-chest", spec.name, "chiptorio-network", spec.order or ("z[" .. spec.name .. "]"))
  item.place_result = spec.name
  item.stack_size = spec.stack_size
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, spec.amount) },
  })
end

for _, spec in ipairs(CABLE_TIERS) do
  spec.order = "a[cable-" .. spec.label .. "]"
  make_cable(spec)
end

--- Make a 3×2 rotatable network device (switch or router).
--   collision_box rotates with direction. Ports are on the long sides.
local function make_network_device(spec)
  local base = data.raw.container["wooden-chest"]
  if not base then
    error("chiptorio: base container prototype not found")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = { "entity-name." .. spec.name }
  entity.localised_description = { "entity-description." .. spec.name }
  entity.minable = { mining_time = spec.mining_time or 0.2, result = spec.name }
  entity.corpse = nil
  entity.dying_explosion = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.inventory_size = 0
  entity.default_empty_slots_signal = nil
  -- 3×2 footprint, rotatable. Ports are on the long sides.
  entity.collision_box = { { -1.5, -1 }, { 1.5, 1 } }
  entity.selection_box = { { -1.5, -1 }, { 1.5, 1 } }
  entity.direction_count = 4
  -- Switches and routers don't need circuit network connectors.
  entity.circuit_connector = nil
  M.set_world_picture(entity, donor(spec.donor_type or "container", spec.donor or "wooden-chest"), spec.tint)
  entity.icon_draw_specification = { scale = 0.5 }
  entity.max_health = spec.health or 150
  M.set_entity_icon(entity, spec.name)
  data:extend({ entity })

  local item = M.item_from("wooden-chest", spec.name, "chiptorio-network", spec.order)
  item.place_result = spec.name
  item.stack_size = spec.stack_size or 20
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_network_device({
  name = "network-switch",
  order = "b[network-switch]",
  health = 200,
  mining_time = 0.5,
  craft_time = 4,
  donor_type = "constant-combinator",
  donor = "constant-combinator",
  tint = rgba(0.55, 0.85, 1.0),
  ingredients = {
    M.item("network-cable", 10),
    M.item("electronic-circuit", 4),
    M.item("steel-plate", 4),
  },
})

make_network_device({
  name = "network-router",
  order = "c[network-router]",
  health = 250,
  mining_time = 0.5,
  craft_time = 8,
  donor_type = "constant-combinator",
  donor = "constant-combinator",
  tint = rgba(1.0, 0.80, 0.45),
  stack_size = 10,
  radius_visualisation_spec = {
    sprite = "__chiptorio__/graphics/icons/network-router.png",
    distance = 16,
    use_active_high_priority = false,
  },
  ingredients = {
    M.item("network-cable", 10),
    M.item("advanced-circuit", 8),
    M.item("steel-plate", 8),
  },
})

-- Monitor: 1×1 display panel. Reads the network graph and shows topology.
make_network_device({
  name = "network-monitor",
  order = "d[network-monitor]",
  health = 150,
  mining_time = 0.2,
  craft_time = 3,
  donor_type = "display-panel",
  donor = "display-panel",
  tint = rgba(0.50, 1.0, 0.85),
  ingredients = {
    M.item("network-cable", 5),
    M.item("electronic-circuit", 5),
    M.item("steel-plate", 5),
    M.item("glass", 2),
  },
})

-- Custom input for overlay toggle.
data:extend({
  {
    type = "custom-input",
    name = "chiptorio-network-overlay",
    key_sequence = "ALT + N",
    consuming = "game-only",
  },
  {
    type = "shortcut",
    name = "chiptorio-network-monitor",
    order = "z[chiptorio]-a[network-monitor]",
    action = "lua",
    localised_name = { "shortcut.chiptorio-network-monitor" },
    technology_to_unlock = "internet",
    icon = "__chiptorio__/graphics/icons/network-monitor.png",
    icon_size = 64,
    small_icon = "__chiptorio__/graphics/icons/network-monitor.png",
    small_icon_size = 64,
  },
})

return M
