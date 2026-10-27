-- QLN prototypes: the pre-quantum Data Bus and the phase-six quantum layer.
--
-- DESIGN §9. All entities are cloned from base prototypes and tinted; no
-- custom entity art. Storage Drives and the Quantum Entanglement Core are lab
-- clones because a lab is the only 2.1 prototype that exposes a module
-- inventory. The Construction Core is an accumulator clone, because it reads
-- and spends `entity.energy` while idle. Every other node is a 1x1 container.
--
-- The runtime never learns any of these numbers from this file: the tuning
-- lives in scripts/qln_meta.lua and the topology lives in network_runtime.lua.

local Mutil = require("scripts.util")
local qmeta = require("scripts.qln_meta")
local nodes = require("scripts.process_nodes")

local function rgba(r, g, b, a)
  return { r = r, g = g, b = b, a = a or 1 }
end

--- Look up a base prototype we borrow a world sprite from. All QLN nodes are
--- clones, so every one needs a real donor: an item icon scaled onto the map
--- looks like a floating sticker and hides the collision box.
local function donor(type_name, name)
  local prototypes = data.raw[type_name]
  local proto = prototypes and prototypes[name]
  if not proto then
    error("chiptorio: missing donor prototype " .. tostring(type_name) .. "/" .. tostring(name))
  end
  return proto
end

local function make_node(spec)
  local base = data.raw.container["wooden-chest"]
  if not base then
    error("chiptorio: base container missing; cannot build QLN nodes")
  end

  local entity = Mutil.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = spec.mining_time or 0.2, result = spec.name }
  entity.corpse = nil
  entity.dying_explosion = nil
  entity.fast_replaceable_group = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.inventory_size = spec.inventory_size or 0
  Mutil.set_world_picture(entity, donor(spec.donor_type or "container", spec.donor or "wooden-chest"), spec.tint)
  entity.icon_draw_specification = { scale = 0.5 }
  entity.max_health = spec.health or 150
  entity.collision_box = spec.collision_box or { { -0.35, -0.35 }, { 0.35, 0.35 } }
  entity.selection_box = spec.selection_box or { { -0.5, -0.5 }, { 0.5, 0.5 } }
  Mutil.set_entity_icon(entity, spec.icon)
  data:extend({ entity })

  local item = Mutil.item_from("wooden-chest", spec.name, "chiptorio-qln", spec.order)
  item.place_result = spec.name
  item.stack_size = spec.stack_size or 50
  Mutil.set_icon(item, spec.icon)

  Mutil.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time or 4,
    ingredients = spec.ingredients or {},
    results = { Mutil.item(spec.name, 1) },
  })
end

-- The QLN is a lab-based storage machine: it needs module slots for memory
-- cells but must never be usable as a research lab.
local function make_lab_node(spec)
  local base = data.raw.lab["lab"]
  if not base then
    error("chiptorio: base lab missing; cannot build " .. spec.name)
  end

  local entity = Mutil.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = spec.mining_time or 0.5, result = spec.name }
  entity.placeable_by = { item = spec.name, count = 1 }
  entity.next_upgrade = nil
  entity.fast_replaceable_group = nil
  entity.corpse = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.inputs = {}
  entity.researching_speed = 0.001
  entity.module_slots = spec.module_slots or 0
  entity.allowed_module_categories = spec.allowed_module_categories
  entity.allowed_effects = nil
  entity.energy_usage = spec.energy_usage or "25kW"
  entity.energy_source = entity.energy_source or { type = "electric" }
  entity.energy_source.drain = spec.drain or "5kW"
  -- The lab sprite is 3x3. Its collision box must match the sprite, or a
  -- Storage Drive looks like it occupies a 3x3 footprint while only blocking a
  -- 1.6x1.6 square - belts and players walk into the art.
  entity.collision_box = spec.collision_box or { { -1.2, -1.2 }, { 1.2, 1.2 } }
  entity.selection_box = spec.selection_box or { { -1.5, -1.5 }, { 1.5, 1.5 } }
  Mutil.set_entity_icon(entity, spec.icon)
  if spec.tint then
    Mutil.tint_animation(entity.on_animation, spec.tint)
    Mutil.tint_animation(entity.off_animation, spec.tint)
  end
  data:extend({ entity })

  local item = Mutil.copy(data.raw.item["lab"])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-qln"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  Mutil.set_icon(item, spec.icon)
  data:extend({ item })

  Mutil.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time or 6,
    ingredients = spec.ingredients or {},
    results = { Mutil.item(spec.name, 1) },
  })
end

-- The Construction Core needs a battery the grid fills while the machine is
-- idle. A lab's energy field only tracks research work, so it is the wrong
-- donor; an accumulator exposes exactly one writable charge that keeps filling
-- from the electric network. It does not need module slots.
local function make_accumulator_node(spec)
  local base = data.raw.accumulator["accumulator"]
  if not base then
    error("chiptorio: base accumulator missing; cannot build " .. spec.name)
  end

  local entity = Mutil.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = spec.mining_time or 0.5, result = spec.name }
  entity.placeable_by = { item = spec.name, count = 1 }
  entity.next_upgrade = nil
  entity.fast_replaceable_group = nil
  entity.corpse = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.max_health = spec.health or 200
  entity.collision_box = { { -0.9, -0.9 }, { 0.9, 0.9 } }
  entity.selection_box = { { -1, -1 }, { 1, 1 } }
  entity.energy_source = entity.energy_source or { type = "electric" }
  entity.energy_source.buffer_capacity = spec.buffer_capacity or qmeta.CONSTRUCTION_BUFFER
  entity.energy_source.input_flow_limit = spec.input_flow_limit or qmeta.CONSTRUCTION_POWER
  Mutil.set_entity_icon(entity, spec.icon)
  if spec.tint then
    local graphics = entity.chargable_graphics
    if graphics then
      Mutil.tint_animation(graphics.picture, spec.tint)
      Mutil.tint_animation(graphics.charge_animation, spec.tint)
      Mutil.tint_animation(graphics.discharge_animation, spec.tint)
    end
  end
  data:extend({ entity })

  local item = Mutil.copy(data.raw.item["accumulator"])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-qln"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  Mutil.set_icon(item, spec.icon)
  data:extend({ item })

  Mutil.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time or 6,
    ingredients = spec.ingredients or {},
    results = { Mutil.item(spec.name, 1) },
  })
end

-- ---------------------------------------------------------------------------
-- Pre-quantum QLN (phase 5)
-- ---------------------------------------------------------------------------

make_node({
  name = "qln-import-node",
  icon = "qln-import-node",
  order = "a[qln-import]",
  donor = "wooden-chest",
  tint = rgba(0.45, 0.85, 1.0),
  craft_time = 5,
  ingredients = {
    Mutil.item("network-cable", 2),
    Mutil.item("electronic-circuit", 4),
    Mutil.item("steel-plate", 4),
  },
})

make_node({
  name = "qln-export-node",
  icon = "qln-export-node",
  order = "b[qln-export]",
  donor = "iron-chest",
  tint = rgba(1.0, 0.72, 0.42),
  craft_time = 5,
  ingredients = {
    Mutil.item("network-cable", 2),
    Mutil.item("electronic-circuit", 4),
    Mutil.item("steel-plate", 4),
  },
})

make_node({
  name = "qln-provider-node",
  icon = "qln-provider-node",
  order = "c[qln-provider]",
  donor = "steel-chest",
  tint = rgba(0.50, 1.0, 0.60),
  craft_time = 6,
  inventory_size = 8,
  ingredients = {
    Mutil.item("network-cable", 4),
    Mutil.item("advanced-circuit", 4),
    Mutil.item("steel-plate", 6),
  },
})

make_node({
  name = "qln-requester-node",
  icon = "qln-requester-node",
  order = "d[qln-requester]",
  donor = "steel-chest",
  tint = rgba(1.0, 0.55, 0.55),
  craft_time = 6,
  -- One slot holds the filter item. The requester never consumes it; it is the
  -- "request this" template, the same trick as a filtered inserter.
  inventory_size = 1,
  ingredients = {
    Mutil.item("network-cable", 4),
    Mutil.item("advanced-circuit", 4),
    Mutil.item("steel-plate", 6),
  },
})

make_node({
  name = "qln-terminal",
  icon = "qln-terminal",
  order = "e[qln-terminal]",
  donor_type = "display-panel",
  donor = "display-panel",
  tint = rgba(0.45, 1.0, 0.90),
  craft_time = 6,
  ingredients = {
    Mutil.item("network-monitor", 1),
    Mutil.item("advanced-circuit", 6),
    Mutil.item("glass", 4),
  },
})

make_lab_node({
  name = "qln-storage-drive",
  icon = "qln-storage-drive",
  order = "f[qln-storage-drive]",
  craft_time = 8,
  module_slots = qmeta.DRIVE_SLOTS,
  allowed_module_categories = { "chiptorio-memory" },
  energy_usage = "25kW",
  drain = "5kW",
  tint = rgba(0.35, 0.85, 0.95),
  ingredients = {
    Mutil.item("datacenter", 1),
    Mutil.item("steel-plate", 20),
    Mutil.item("advanced-circuit", 10),
    Mutil.item("network-cable", 5),
  },
})

make_accumulator_node({
  name = "construction-core",
  icon = "construction-core",
  order = "g[construction-core]",
  craft_time = 30,
  tint = rgba(1.0, 0.75, 0.35),
  ingredients = {
    Mutil.item("assembly-fab", 1),
    Mutil.item("datacenter", 1),
    Mutil.item("advanced-circuit", 20),
    Mutil.item("low-k-dielectric", 10),
  },
})

-- ---------------------------------------------------------------------------
-- Phase 6: quantum QLN, FOUP and wireless
-- ---------------------------------------------------------------------------

make_lab_node({
  name = "quantum-entanglement-core",
  icon = "quantum-entanglement-core",
  order = "h[quantum-entanglement-core]",
  craft_time = 60,
  module_slots = 0,
  allowed_module_categories = {},
  energy_usage = "10MW",
  drain = "500kW",
  tint = rgba(0.75, 0.50, 1.0),
  ingredients = {
    Mutil.item("quantum-fab", 1),
    Mutil.item("cryostat", 1),
    Mutil.item("error-corrected-qubit", 10),
    Mutil.item("superconductor", 20),
  },
})

make_node({
  name = "foup-dock",
  icon = "foup-dock",
  order = "i[foup-dock]",
  donor_type = "constant-combinator",
  donor = "constant-combinator",
  tint = rgba(0.80, 0.60, 1.0),
  craft_time = 10,
  inventory_size = qmeta.FOUP_SLOTS,
  ingredients = {
    Mutil.item("vlsi-fab", 1),
    Mutil.item("steel-plate", 20),
    Mutil.item("advanced-circuit", 10),
  },
})

make_node({
  name = "network-repeater",
  icon = "network-repeater",
  order = "j[network-repeater]",
  donor_type = "constant-combinator",
  donor = "constant-combinator",
  tint = rgba(0.40, 0.90, 1.0),
  craft_time = 3,
  ingredients = {
    Mutil.item("network-cable", 4),
    Mutil.item("electronic-circuit", 2),
    Mutil.item("steel-plate", 2),
  },
})

make_node({
  name = "wireless-access-point",
  icon = "wireless-access-point",
  order = "k[wireless-access-point]",
  donor_type = "display-panel",
  donor = "display-panel",
  tint = rgba(0.65, 0.55, 1.0),
  craft_time = 8,
  health = 200,
  ingredients = {
    Mutil.item("network-router", 1),
    Mutil.item("advanced-circuit", 8),
    Mutil.item("steel-plate", 4),
    Mutil.item("glass", 4),
  },
})

-- FOUP items. The empty carrier is craftable; the sealed variants are produced
-- by a FOUP Dock and consumed by another Dock. One sealed carrier represents a
-- fixed batch of wafers of exactly one process node, so QLN storage can move it
-- as an ordinary item without losing its contents.
local foup = Mutil.item_from("iron-plate", "foup", "chiptorio-qln", "l[foup]")
foup.stack_size = 50
Mutil.set_icon(foup, "foup")

Mutil.recipe({
  name = "foup",
  enabled = false,
  category = "crafting",
  energy_required = 4,
  ingredients = {
    Mutil.item("plastic-bar", 10),
    Mutil.item("steel-plate", 4),
    Mutil.item("advanced-circuit", 1),
  },
  results = { Mutil.item("foup", 2) },
})

for _, node in ipairs(nodes.NODES) do
  local sealed = Mutil.item_from("iron-plate", "foup-sealed-" .. node.key, "chiptorio-qln", "m[foup-" .. node.order .. "]")
  sealed.stack_size = 10
  sealed.localised_name = { "item-name.foup-sealed", node.label }
  sealed.localised_description = { "item-description.foup-sealed", node.label }
  Mutil.set_tinted_icon(sealed, "foup", node.tint)
end
