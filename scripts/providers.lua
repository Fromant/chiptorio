-- Compute providers: the machines that turn chips into network compute.
--
-- Built from scratch as container prototypes so they can hold module
-- inventory (computer modules) without any crafting/lab baggage.

local M = require("scripts.util")
local meta = require("scripts.research_meta")

local entities = {}
local items = {}
local recipes = {}
local animations = {}

local function make_provider(spec)
  local profile = meta.PROVIDERS[spec.name]
  if not profile then
    error("chiptorio: no provider profile for '" .. spec.name .. "'")
  end

  local inventory_size = profile.computer_slots + profile.memory_slots

  -- Build a directional picture for the container prototype.
  local picture = nil

  if spec.blender_sprite then
    local art = require("graphics.entity.server-rack.sprite-def")
    -- Use the north direction's sprite as the base picture.
    local north = art.north
    picture = {
      filename = north.layers[1].filename,
      width = north.layers[1].width,
      height = north.layers[1].height,
      scale = north.layers[1].scale,
      shift = north.layers[1].shift,
      tint = north.layers[1].tint,
    }

    -- Full animations registered as named prototypes for rack_runtime.
    for direction, graphic in pairs(art) do
      local anim = M.copy(graphic)
      anim.type = "animation"
      anim.name = "chiptorio-rack-" .. direction
      animations[#animations + 1] = anim
    end
  elseif spec.custom_animation then
    picture = {
      filename = "__chiptorio__/graphics/entity/" .. spec.custom_animation .. ".png",
      width = spec.size_w or 128,
      height = spec.size_h or 128,
      scale = spec.scale or 0.5,
      shift = spec.shift or { 0, 0 },
    }
  end

  local entity = M.make_provider_base({
    name = spec.name,
    localised_name = { "entity-name." .. spec.name },
    localised_description = { "entity-description." .. spec.name },
    minable = { mining_time = 0.5, result = spec.name },
    placeable_by = { item = spec.name, count = 1 },
    fast_replaceable_group = "chiptorio-providers",
    inventory_size = inventory_size,
    inventory_stack_size = 1,
    quality_affects_inventory_size = false,
    picture = picture,
    collision_box = spec.collision_box or { { -1.4, -1.4 }, { 1.4, 1.4 } },
    selection_box = spec.selection_box or { { -1.5, -1.5 }, { 1.5, 1.5 } },
    drawing_box_vertical_extension = spec.drawing_box_vertical_extension,
    max_health = spec.max_health,
  })

  entities[#entities + 1] = entity

  local item = M.item_proto("wooden-chest", spec.name, "chiptorio-providers", spec.order)
  item.place_result = spec.name
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
  { type = "custom-input", name = "chiptorio-rack-rotate", key_sequence = "R", consuming = "none" },
  { type = "custom-input", name = "chiptorio-rack-rotate-reverse", key_sequence = "Shift-R", consuming = "none" },
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

-- Register named animations together with entities so Factorio's prototype
-- validation sees both at once.
local all = {}
for _, e in ipairs(entities) do all[#all + 1] = e end
for _, i in ipairs(items) do all[#all + 1] = i end
for _, a in ipairs(animations) do all[#all + 1] = a end
for _, r in ipairs(recipes) do all[#all + 1] = r end
data:extend(all)
