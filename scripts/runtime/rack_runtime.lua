-- Runtime: animation control for compute providers.
--
-- Providers are standalone assembling-machine prototypes with directional
-- graphics_set (frozen single-frame stills). rack_runtime plays the full
-- working animation via rendering.draw_animation only when computer modules
-- are installed. Rotation replaces the entity with a new direction (direction
-- is tracked in storage since LuaEntity.direction is not reliable on
-- assembling-machine prototypes in 2.1).

local meta = require("scripts.research_meta")
local M = {}

local COMPUTER_GUI_NAME = "chiptorio-computer-gui"

local PROVIDER_NAMES = { "server-rack", "memory-bank", "datacenter" }

local DIRECTIONS = { defines.direction.north, defines.direction.east,
                     defines.direction.south, defines.direction.west }
local DIRECTION_NAMES = {
  [defines.direction.north] = "north",
  [defines.direction.east] = "east",
  [defines.direction.south] = "south",
  [defines.direction.west] = "west",
}

local function is_provider(entity)
  if not (entity and entity.valid) then return false end
  for _, name in ipairs(PROVIDER_NAMES) do
    if entity.name == name then return true end
  end
  return false
end

--- Check if a provider has any computer modules installed.
local function has_compute_modules(entity)
  local inventory = entity.get_module_inventory()
  if not inventory then return false end
  for _, item in pairs(inventory.get_contents()) do
    if meta.COMPUTER_PROFILES[item.name] then
      return true
    end
  end
  return false
end

-- Per-entity rendering records for the working animation overlay.
local function visuals()
  storage.chiptorio_rack_visuals = storage.chiptorio_rack_visuals or {}
  return storage.chiptorio_rack_visuals
end

-- Track direction per entity (unit_number -> direction index 1-4).
local function dirs_table()
  storage.chiptorio_rack_dirs = storage.chiptorio_rack_dirs or {}
  return storage.chiptorio_rack_dirs
end

local function entity_dir_index(entity)
  local t = dirs_table()
  return t[entity.unit_number] or 1
end

local function set_entity_dir_index(entity, index)
  local t = dirs_table()
  t[entity.unit_number] = index
end

local function entity_direction(entity)
  return DIRECTIONS[entity_dir_index(entity)]
end

--- Create or update the rendering overlay for a provider based on whether it
-- has computer modules installed.
local function update_visuals(entity)
  if not (entity and entity.valid and is_provider(entity)) then return end
  local unit = entity.unit_number
  local active = has_compute_modules(entity)

  local old = visuals()[unit]
  if old and old.render and old.render.valid then
    old.render.destroy()
  end

  if not active then
    visuals()[unit] = nil
    return
  end

  local dir = DIRECTION_NAMES[entity_direction(entity)] or "north"
  local name = "chiptorio-rack-" .. dir
  visuals()[unit] = {
    entity = entity,
    render = rendering.draw_animation{
      animation = name, target = entity, surface = entity.surface,
      animation_speed = 0.5, animation_offset = 0, render_layer = "object",
    },
  }
end

function M.on_built(event)
  local entity = event and (event.entity or event.destination)
  if not (entity and entity.valid and is_provider(entity)) then return end
  -- Store initial direction (default to north index 1)
  set_entity_dir_index(entity, 1)
  update_visuals(entity)
end

function M.on_removed(event)
  local entity = event and event.entity
  if not (entity and entity.valid and entity.unit_number) then return end
  local record = visuals()[entity.unit_number]
  if record then
    if record.render and record.render.valid then record.render.destroy() end
    visuals()[entity.unit_number] = nil
  end
  local t = dirs_table()
  t[entity.unit_number] = nil
end

function M.tick()
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = PROVIDER_NAMES}) do
      if entity.valid then
        update_visuals(entity)
      end
    end
  end
end

function M.init()
  for _, record in pairs(visuals()) do
    if record.render and record.render.valid then record.render.destroy() end
  end
  storage.chiptorio_rack_visuals = {}
  storage.chiptorio_rack_dirs = {}
  M.tick()
end

function M.animation_status(entity)
  if not (entity and entity.valid) then return nil end
  local active = has_compute_modules(entity)
  return { speed = active and 0.5 or 0 }
end

function M.rotate(entity, reverse)
  if not (entity and entity.valid and is_provider(entity)) then return end
  local idx = entity_dir_index(entity)
  local step = reverse and -1 or 1
  local new_idx = ((idx - 1 + step) % 4) + 1
  local new_dir = DIRECTIONS[new_idx]

  -- Preserve state through entity replacement.
  local health, energy = entity.health, entity.energy
  local modules = entity.get_module_inventory()
  local held = game.create_inventory(#modules)
  for slot = 1, #modules do held[slot].swap_stack(modules[slot]) end

  local replacement = entity.surface.create_entity{
    name = entity.name, position = entity.position, force = entity.force,
    quality = entity.quality, direction = new_dir,
    fast_replace = true, spill = false,
    raise_built = true, create_build_effect_smoke = false, snap_to_grid = false,
  }
  if not replacement then
    for slot = 1, #modules do modules[slot].swap_stack(held[slot]) end
    held.destroy()
    return
  end

  local target = replacement.get_module_inventory()
  for slot = 1, #target do target[slot].swap_stack(held[slot]) end
  held.destroy()

  if entity.valid then entity.destroy{ raise_destroy = true } end
  replacement.health, replacement.energy = health, energy

  -- Track the new direction for the replacement entity
  set_entity_dir_index(replacement, new_idx)

  update_visuals(replacement)
  return replacement
end

function M.on_input(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local selected = player.selected
  if selected and selected.valid and selected.force == player.force and is_provider(selected) then
    local replacement = M.rotate(selected, event.input_name == "chiptorio-rack-rotate-reverse")
    if replacement and player.opened and player.opened.valid then
      -- Re-open the custom GUI on the replacement entity if it was open.
      local gui = player.gui.screen[COMPUTER_GUI_NAME]
      if gui and gui.valid then
        player.opened = replacement
      end
    end
  end
end

return M