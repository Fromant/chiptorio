-- Explicit activity ownership is checked by Asset Studio and again here.
-- Empty until the first visually approved publication; legacy art stays unchanged.
local M = require("scripts.util")
local bindings = require("graphics.published-assets")
local owners = {
  ["metrology-lab"]=true, ["answer-engine"]=true, ["qln-storage-drive"]=true,
  ["quantum-entanglement-core"]=true, ["foup-dock"]=true,
  ["wireless-access-point"]=true, ["qln-import-node"]=true,
  ["qln-export-node"]=true, ["qln-provider-node"]=true,
  ["qln-requester-node"]=true, ["qln-terminal"]=true,
  ["training-cluster"]=true, ["inference-lab"]=true, ["network-monitor"]=true,
  ["network-switch"]=true, ["network-router"]=true, ["memory-bank"]=true,
}
for name, binding in pairs(bindings) do
  local entity = assert(data.raw[binding.type] and data.raw[binding.type][name], "Published asset prototype missing: " .. name)
  local art = require("graphics.entity." .. name .. ".sprite-def")
  local mode = binding.mode
  -- Optional reviewed connection plan: retain fluid boxes/directions/flow, move
  -- only the explicitly pinned ports to the enlarged machine's tile perimeter.
  for _, port in ipairs(binding.fluid_ports or {}) do
    local box = assert(entity.fluid_boxes and entity.fluid_boxes[port.box], "Published fluid box missing: " .. name)
    local connection = assert(box.pipe_connections and box.pipe_connections[port.connection], "Published fluid connection missing: " .. name)
    local previous = connection.position
    assert(previous and (previous[1] or previous.x) == port.from[1] and (previous[2] or previous.y) == port.from[2]
      and connection.direction == port.direction, "Published fluid connection baseline changed: " .. name)
    connection.position = M.copy(port.position)
    if binding.base_pipe_sprites then
      local native = data.raw["assembling-machine"]["assembling-machine-2"].fluid_boxes[1]
      box.pipe_picture, box.pipe_covers = M.copy(native.pipe_picture), M.copy(native.pipe_covers)
    end
  end
  if mode == "scripted" then
    assert(owners[name], "Published art has no activity owner: " .. name)
    M.set_blender_device_graphics(entity, name)
  elseif mode == "accumulator" then
    assert(entity.type == "accumulator")
    M.set_blender_device_graphics(entity, name)
  elseif mode == "native-crafting" and binding.directional then
    assert(entity.type == "assembling-machine" or entity.type == "furnace")
    entity.graphics_set = { animation=M.copy(art.on_animation), idle_animation=M.copy(art.off_animation) }
    local flags = {}
    for _, flag in ipairs(entity.flags or {}) do if flag ~= "not-rotatable" then flags[#flags+1] = flag end end
    entity.flags = flags
    local width, height = art.footprint[1], art.footprint[2]
    entity.tile_width, entity.tile_height = width, height
    entity.selection_box = {{-width/2,-height/2},{width/2,height/2}}
    entity.collision_box = {{-width/2+0.15,-height/2+0.15},{width/2-0.15,height/2-0.15}}
  else
    local idle = M.copy(art.off_animation)
    local still = M.copy(idle)
    for _, layer in ipairs(still.layers) do
      layer.frame_count, layer.line_length, layer.repeat_count, layer.animation_speed = nil, nil, nil, nil
    end
    if mode == "native-crafting" then
      assert(entity.type == "assembling-machine" or entity.type == "furnace")
      for _, layer in ipairs(idle.layers) do layer.repeat_count = art.on_animation.layers[1].frame_count end
      entity.graphics_set = { animation=M.copy(art.on_animation), idle_animation=idle }
    elseif mode == "native-lab" then
      assert(entity.type == "lab")
      entity.on_animation, entity.off_animation = M.copy(art.on_animation), idle
      entity.light = nil
    elseif mode == "static" then
      if entity.type == "container" then entity.picture = still
      elseif entity.type == "lab" then entity.on_animation, entity.off_animation = idle, M.copy(idle)
      else entity.graphics_set = { animation=idle } end
    else error("Unsupported published graphics mode: " .. tostring(mode)) end
    local width, height = art.footprint[1], art.footprint[2]
    entity.tile_width, entity.tile_height = width, height
    entity.selection_box = {{-width/2,-height/2},{width/2,height/2}}
    entity.collision_box = {{-width/2+0.15,-height/2+0.15},{width/2-0.15,height/2-0.15}}
    entity.flags = M.copy(entity.flags or {})
    local fixed = false
    for _, flag in ipairs(entity.flags) do if flag == "not-rotatable" then fixed = true end end
    if not fixed then entity.flags[#entity.flags+1] = "not-rotatable" end
  end
end
