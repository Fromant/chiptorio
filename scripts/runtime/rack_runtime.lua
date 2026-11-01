-- Rotation adapter for the four render variants of the lab-based rack.
local meta = require("scripts.research_meta")
local M = {}
local function index(name)
  for i, variant in ipairs(meta.RACK_VARIANTS) do if name == variant then return i end end
end
local directions = { "north", "east", "south", "west" }
local function visuals()
  storage.chiptorio_rack_visuals = storage.chiptorio_rack_visuals or {}
  return storage.chiptorio_rack_visuals
end
function M.on_built(event)
  local entity = event and (event.entity or event.destination)
  if not (entity and entity.valid and index(entity.name)) then return end
  local records = visuals()
  local old = records[entity.unit_number]
  if old and old.render.valid then return end
  local name = "chiptorio-rack-" .. directions[index(entity.name)]
  records[entity.unit_number] = {
    entity = entity,
    render = rendering.draw_animation{
      animation=name, target=entity, surface=entity.surface,
      animation_speed=0.5, animation_offset=0, render_layer="object",
    },
  }
end
function M.on_removed(event)
  local entity = event and event.entity
  if not (entity and entity.valid and entity.unit_number) then return end
  local records = visuals()
  local record = records[entity.unit_number]
  if record then
    if record.render.valid then record.render.destroy() end
    records[entity.unit_number] = nil
  end
end
function M.tick()
  local records = visuals()
  for unit, record in pairs(records) do
    if not record.entity.valid then
      if record.render.valid then record.render.destroy() end
      records[unit] = nil
    end
  end
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered{name=meta.RACK_VARIANTS}) do
      M.on_built{entity=entity}
    end
  end
end
function M.init()
  for _, record in pairs(visuals()) do
    if record.render.valid then record.render.destroy() end
  end
  storage.chiptorio_rack_visuals = {}
  M.tick()
end
function M.animation_status(entity)
  local record = entity and entity.valid and visuals()[entity.unit_number]
  return record and record.render.valid and {
    animation=record.render.animation, speed=record.render.animation_speed,
  } or nil
end
function M.rotate(entity, reverse)
  if not (entity and entity.valid) then return end
  local i = index(entity.name)
  if not i then return end
  local name = meta.RACK_VARIANTS[(i - 1 + (reverse and -1 or 1)) % 4 + 1]
  local proto = prototypes.entity[name]
  local box, pos = proto.collision_box, entity.position
  local area = {{pos.x+box.left_top.x,pos.y+box.left_top.y},
                {pos.x+box.right_bottom.x,pos.y+box.right_bottom.y}}
  local layers = proto.collision_mask.layers
  -- Ignore this rack, but refuse to rotate through neighbours or water.
  for _, other in ipairs(entity.surface.find_entities_filtered{area=area,collision_mask=layers}) do
    if other ~= entity and other.type ~= "entity-ghost" then return end
  end
  if entity.surface.count_tiles_filtered{area=area,collision_mask=layers,limit=1} > 0 then return end
  local health, energy, last_user = entity.health, entity.energy, entity.last_user
  local modules = entity.get_module_inventory()
  local held = game.create_inventory(#modules)
  for slot=1,#modules do held[slot].swap_stack(modules[slot]) end
  local replacement = entity.surface.create_entity{
    name=name, position=entity.position, force=entity.force, quality=entity.quality,
    fast_replace=true, spill=false, raise_built=true, create_build_effect_smoke=false,
    snap_to_grid=false,
  }
  if not replacement then
    for slot=1,#modules do modules[slot].swap_stack(held[slot]) end
    held.destroy()
    return
  end
  local target = replacement.get_module_inventory()
  for slot=1,#target do target[slot].swap_stack(held[slot]) end
  held.destroy()
  -- Different footprint sizes aren't always treated as a native fast replace.
  -- Remove the original explicitly after the replacement and modules are safe.
  if entity.valid then entity.destroy{raise_destroy=true} end
  replacement.health, replacement.energy = health, energy
  replacement.last_user = last_user
  return replacement
end
function M.on_input(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local stack = player.cursor_stack
  if stack and stack.valid_for_read and index(stack.name) then
    local i = index(stack.name)
    stack.set_stack{name=meta.RACK_VARIANTS[(i-1+(event.input_name=="chiptorio-rack-rotate-reverse" and -1 or 1))%4+1],count=stack.count,quality=stack.quality}
    return
  end
  local selected = player.selected
  if selected and selected.valid and selected.force == player.force and index(selected.name) then
    local opened = player.opened == selected
    local replacement = M.rotate(selected,event.input_name=="chiptorio-rack-rotate-reverse")
    if opened and replacement then player.opened = replacement end
  end
end
return M
