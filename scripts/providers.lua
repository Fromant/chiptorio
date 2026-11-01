-- Compute providers: the machines that turn chips into network compute.
--
-- Built from scratch (not cloned from lab or assembling-machine) so there is
-- no inherited baggage: no research inputs, no researching_speed, no crafting
-- categories beyond a dummy "crafting" with near-zero speed, no base-prototype
-- animation clock, no module-effect limits. Every field is set explicitly.
--
-- The prototype numbers live in scripts/research_meta.lua so the data stage and
-- the runtime cannot drift apart.

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

  local module_categories = { "chiptorio-computer" }
  if profile.memory_slots and profile.memory_slots > 0 then
    module_categories[#module_categories + 1] = "chiptorio-memory"
  end

  local total_slots = profile.computer_slots + profile.memory_slots

  -- Build the graphics_set: either blender-rendered directional sprites or a
  -- single custom animation. Base graphics are frozen single-frame stills;
  -- rack_runtime.lua plays the working loop via rendering.draw_animation only
  -- when compute modules are installed.
  local graphics_set = { animation = {} }

  if spec.blender_sprite then
    local art = require("graphics.entity.server-rack.sprite-def")
    for direction, graphic in pairs(art) do
      -- Frozen still for the base graphics_set.
      local frozen = M.copy(graphic)
      for _, layer in ipairs(frozen.layers) do
        layer.frame_count = 1
        layer.animation_speed = 0.001
        layer.repeat_count = 1
      end
      graphics_set.animation[direction] = frozen

      -- Full animation registered as a named prototype for rack_runtime.
      local anim = M.copy(graphic)
      anim.type = "animation"
      anim.name = "chiptorio-rack-" .. direction
      animations[#animations + 1] = anim
    end
    -- Ensure all four directions exist in the graphics_set table.
    graphics_set.animation = {
      north = graphics_set.animation.north,
      east = graphics_set.animation.east,
      south = graphics_set.animation.south,
      west = graphics_set.animation.west,
    }
  elseif spec.custom_animation then
    -- Single still image for non-bladner providers (memory-bank, datacenter).
    graphics_set.animation = {
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
    module_slots = total_slots,
    allowed_module_categories = module_categories,
    energy_usage = profile.power .. "kW",
    drain = profile.drain,
    graphics_set = graphics_set,
    collision_box = spec.collision_box or { { -1.4, -1.4 }, { 1.4, 1.4 } },
    selection_box = spec.selection_box or { { -1.5, -1.5 }, { 1.5, 1.5 } },
    drawing_box_vertical_extension = spec.drawing_box_vertical_extension or 2.5,
    tile_width = spec.tile_width or 3,
    tile_height = spec.tile_height or 3,
    max_health = spec.max_health,
  })

  entities[#entities + 1] = entity

  local item = M.item_proto("assembling-machine-1", spec.name, "chiptorio-providers", spec.order)
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

-- Register named animations together with entities so Factorio's prototype
-- validation sees both at once.
local all = {}
for _, e in ipairs(entities) do all[#all + 1] = e end
for _, i in ipairs(items) do all[#all + 1] = i end
for _, a in ipairs(animations) do all[#all + 1] = a end
for _, r in ipairs(recipes) do all[#all + 1] = r end
data:extend(all)
