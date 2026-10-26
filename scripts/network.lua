-- Network wiring: cable, switch, router and monitor.
--
-- All four are 1x1 containers cloned from the wooden chest. The cable uses a
-- dedicated collision layer so cables collide with each other (no stacking)
-- but with nothing else: a cable can run under a machine or a belt, which is
-- what makes wiring a factory reasonable.
--
-- Nothing here knows about the graph. scripts/runtime/network_graph.lua turns
-- these entities into subnets; this file only defines what they are.

local M = require("scripts.util")

data:extend({
  {
    type = "collision-layer",
    order = "50",
    name = "chiptorio-cable",
  },
})

local function icon_picture(name)
  return {
    layers = {
      {
        filename = "__chiptorio__/graphics/icons/" .. name .. ".png",
        width = 64,
        height = 64,
        scale = 0.5,
        priority = "extra-high",
      },
    },
  }
end

local function make_network_entity(spec)
  local base = data.raw.container["wooden-chest"]
  if not base then
    error("chiptorio: base container prototype not found")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = spec.mining_time or 0.05, result = spec.name }
  entity.corpse = nil
  entity.dying_explosion = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.inventory_size = 0
  entity.default_empty_slots_signal = nil
  entity.picture = icon_picture(spec.name)
  entity.icon_draw_specification = { scale = 0.5 }
  entity.max_health = spec.health or 100
  entity.collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } }
  entity.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
  if spec.collision_layer then
    -- Dedicated layer on both sides: cables collide only with cables. Keeping
    -- the default "object" layer would make every belt and machine collide
    -- with the cable, because their masks include it.
    entity.collision_layer = { layers = { [spec.collision_layer] = true } }
    entity.collision_mask = { layers = { [spec.collision_layer] = true } }
  else
    entity.collision_box = spec.collision_box or { { -0.35, -0.35 }, { 0.35, 0.35 } }
  end
  M.set_entity_icon(entity, spec.name)
  data:extend({ entity })

  local item = M.item_from("wooden-chest", spec.name, "chiptorio-machines", spec.order)
  item.place_result = spec.name
  item.stack_size = spec.stack_size or 50
  M.set_icon(item, spec.name)

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, spec.amount or 1) },
  })
end

-- The cable is the only walkable, stack-proof, freely routed piece.
make_network_entity({
  name = "network-cable",
  order = "a[network-cable]",
  stack_size = 200,
  amount = 4,
  craft_time = 0.5,
  collision_layer = "chiptorio-cable",
  ingredients = {
    M.item("copper-cable", 2),
    M.item("plastic-bar", 1),
  },
})

-- A switch is a powered backplane: it merges the cable runs it touches and
-- adds bandwidth to the subnet.
make_network_entity({
  name = "network-switch",
  order = "b[network-switch]",
  health = 150,
  craft_time = 2,
  ingredients = {
    M.item("network-cable", 5),
    M.item("electronic-circuit", 2),
    M.item("steel-plate", 2),
  },
})

-- A router deliberately does not conduct: it keeps the two sides on separate
-- subnets and forwards between them.
make_network_entity({
  name = "network-router",
  order = "c[network-router]",
  health = 200,
  craft_time = 4,
  ingredients = {
    M.item("network-cable", 5),
    M.item("advanced-circuit", 4),
    M.item("steel-plate", 5),
  },
})

-- The monitor is the topology and statistics window.
make_network_entity({
  name = "network-monitor",
  order = "d[network-monitor]",
  health = 150,
  craft_time = 3,
  ingredients = {
    M.item("network-cable", 5),
    M.item("electronic-circuit", 5),
    M.item("steel-plate", 5),
    M.item("glass", 2),
  },
})

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
