-- Runtime: animation control for compute providers.
--
-- Providers are standalone assembling-machine prototypes with directional
-- graphics_set. The base animation is frozen (single frame) and a separate
-- rendering overlay plays the working loop only when computer modules are
-- installed. Rotation uses the entity's native direction (pressing R turns
-- the machine); no entity replacement is needed.

local meta = require("scripts.research_meta")
local M = {}

local PROVIDER_NAMES = { "server-rack", "memory-bank", "datacenter" }

local DIRECTION_NAMES = { [defines.direction.north] = "north",
                          [defines.direction.east] = "east",
                          [defines.direction.south] = "south",
                          [defines.direction.west] = "west" }

local function index(name)
  if name == "server-rack" then return 1 end
  return nil
end

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
local records = {}

local function visuals()
  storage.chiptorio_rack_visuals = storage.chiptorio_rack_visuals or {}
  return storage.chiptorio_rack_visuals
end

function M.on_built(event)
  local entity = event and (event.entity or event.destination)
  if not (entity and entity.valid and is_provider(entity)) then return end
  M.update_visuals(entity)
end

function M.on_removed(event)
  local entity = event and event.entity
  if not (entity and entity.valid and entity.unit_number) then return end
  local record = visuals()[entity.unit_number]
  if record then
    if record.render and record.render.valid then record.render.destroy() end
    visuals()[entity.unit_number] = nil
  end
end

--- Create or update the rendering overlay for a provider based on whether it
--- has computer modules installed.
function M.update_visuals(entity)
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

  local dir = DIRECTION_NAMES[entity.direction] or "north"
  local name = "chiptorio-rack-" .. dir
  visuals()[unit] = {
    entity = entity,
    render = rendering.draw_animation{
      animation = name, target = entity, surface = entity.surface,
      animation_speed = 0.5, animation_offset = 0, render_layer = "object",
    },
  }
end

function M.tick()
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name = PROVIDER_NAMES}) do
      if entity.valid then
        M.update_visuals(entity)
      end
    end
  end
end

function M.init()
  for _, record in pairs(visuals()) do
    if record.render and record.render.valid then record.render.destroy() end
  end
  storage.chiptorio_rack_visuals = {}
  M.tick()
end

function M.animation_status(entity)
  if not (entity and entity.valid) then return nil end
  local record = visuals()[entity.unit_number]
  if record and record.render and record.render.valid then
    return { animation_speed = record.render.animation_speed }
  end
  return { animation_speed = 0 }
end

function M.rotate(entity, reverse)
  if not (entity and entity.valid and is_provider(entity)) then return end
  local dir = entity.direction
  local step = reverse and -1 or 1
  local dirs = { defines.direction.north, defines.direction.east,
                 defines.direction.south, defines.direction.west }
  local idx = 1
  for i, d in ipairs(dirs) do
    if dir == d then idx = i break end
  end
  local new_dir = dirs[((idx - 1 + step) % 4) + 1]
  entity.direction = new_dir
  -- Refresh the rendering overlay to match the new direction
  M.update_visuals(entity)
  return entity
end

function M.on_input(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local selected = player.selected
  if selected and selected.valid and selected.force == player.force and is_provider(selected) then
    local opened = player.opened == selected
    local replacement = M.rotate(selected, event.input_name == "chiptorio-rack-rotate-reverse")
    if opened and replacement then player.opened = replacement end
  end
end

return M