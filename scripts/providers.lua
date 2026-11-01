-- Compute providers: the machines that turn chips into network compute.
--
-- A provider is a standalone assembling-machine clone with a dummy crafting
-- category (no recipes) so it can never craft anything. That keeps the module
-- inventory, power connection, minimap behaviour and directional graphics valid
-- without cloning the lab prototype. The lab prototype carries research inputs,
-- researching_speed, and a research animation clock we never use;
-- assembling-machine gives us module slots + electric power + working/idle
-- animation without any of that.
--
-- The prototype numbers live in scripts/research_meta.lua so the data stage and
-- the runtime cannot drift apart.

local M = require("scripts.util")
local meta = require("scripts.research_meta")

local entities = {}
local items = {}
local recipes = {}

local function make_provider(spec)
  local base = data.raw["assembling-machine"]["assembling-machine-1"]
  if not base then
    error("chiptorio: base assembling-machine not found")
  end

  local profile = meta.PROVIDERS[spec.name]
  if not profile then
    error("chiptorio: no provider profile for '" .. spec.name .. "'")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.5, result = spec.name }
  entity.placeable_by = { item = spec.name, count = 1 }
  entity.next_upgrade = nil
  entity.fast_replaceable_group = "chiptorio-providers"
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.corpse = nil

  -- No crafting: this machine is a compute provider, not a factory.
  -- Inherits crafting_categories = {"crafting"} from the base assembling-machine,
  -- but crafting_speed = 0.001 makes crafting impractically slow (~1000x
  -- slower than a normal assembler). Providers are network devices, not
  -- factories; the custom GUI never shows crafting tabs.
  entity.crafting_speed = 0.001
  entity.module_slots = profile.computer_slots + profile.memory_slots
  local module_categories = { "chiptorio-computer" }
  if profile.memory_slots and profile.memory_slots > 0 then
    module_categories[#module_categories + 1] = "chiptorio-memory"
  end
  entity.allowed_module_categories = module_categories

  entity.energy_usage = profile.power .. "kW"
  entity.energy_source = entity.energy_source or { type = "electric" }
  entity.energy_source.drain = profile.drain

  M.set_entity_icon(entity, spec.name)

  if spec.blender_sprite then
    local art = require("graphics.entity.server-rack.sprite-def")
    local gs = { animation = {} }
    for direction, graphic in pairs(art) do
      -- Base animation is frozen to a single frame; rack_runtime.lua plays
      -- the full working loop via rendering.draw_animation with a named
      -- animation prototype registered below.
      local frozen = M.copy(graphic)
      for _, layer in ipairs(frozen.layers) do
        layer.frame_count = 1
        layer.animation_speed = 0.001
        layer.repeat_count = 1
      end
      gs.animation[direction] = frozen
      -- Register the full animation as a named prototype so rack_runtime can
      -- play it via rendering.draw_animation.
      local anim = M.copy(graphic)
      anim.type = "animation"
      anim.name = "chiptorio-rack-" .. direction
      data:extend({ anim })
    end
    entity.graphics_set = gs
    entity.collision_box = { { -1.4, -1.4 }, { 1.4, 1.4 } }
    entity.selection_box = { { -1.5, -1.5 }, { 1.5, 1.5 } }
    entity.drawing_box_vertical_extension = 2.5
    entity.tile_width = 3
    entity.tile_height = 3
  elseif spec.custom_animation then
    M.set_custom_graphics(entity, spec.custom_animation or spec.name, spec.size_w or 128, spec.size_h or 128, spec.scale or 0.5, spec.shift)
  elseif spec.tint then
    M.tint_entity(entity, spec.tint)
  end

  entities[#entities + 1] = entity

  local item = M.copy(data.raw.item["assembling-machine-1"])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-providers"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  items[#items + 1] = item

  recipes[#recipes + 1] = {
    type = "recipe",
    name = spec.name,
    enabled = false,
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  }
end

-- Custom inputs first.
data:extend({
  { type = "custom-input", name = "chiptorio-rack-rotate", key_sequence = "", linked_game_control = "rotate", consuming = "none" },
  { type = "custom-input", name = "chiptorio-rack-rotate-reverse", key_sequence = "", linked_game_control = "reverse-rotate", consuming = "none" },
})

make_provider({
  name = "server-rack",
  order = "a[server-rack]",
  craft_time = 12,
  blender_sprite = true,
  ingredients = {
    M.item("steel-plate", 20),
    M.item("electronic-circuit", 10),   -- Control Board
    M.item("copper-plate", 20),
  },
})

make_provider({
  name = "memory-bank",
  order = "b[memory-bank]",
  craft_time = 10,
  custom_animation = "memory-bank",
  size_w = 128,
  size_h = 128,
  scale = 0.5,
  ingredients = {
    M.item("steel-plate", 16),
    M.item("electronic-circuit", 8),    -- Control Board
    M.item("copper-plate", 20),
  },
})

make_provider({
  name = "datacenter",
  order = "c[datacenter]",
  craft_time = 30,
  custom_animation = "datacenter",
  size_w = 160,
  size_h = 160,
  scale = 0.5,
  ingredients = {
    M.item("server-rack", 4),
    M.item("cooling-unit", 8),
    M.item("steel-plate", 40),
    M.item("electronic-circuit", 30),   -- Control Board
  },
})

-- Register entities and items. crafting_categories is empty so providers can
-- never craft anything.
local all = {}
for _, e in ipairs(entities) do all[#all + 1] = e end
for _, i in ipairs(items) do all[#all + 1] = i end
for _, r in ipairs(recipes) do all[#all + 1] = r end
data:extend(all)
