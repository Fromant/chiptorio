-- Keep Factorio's inventory/lab UI and attach a read-only network inspector.
-- No copied stacks, cursor buttons, or per-player module-local state.
local meta = require("scripts.research_meta")
local qmeta = require("scripts.qln_meta")
local network = require("scripts.runtime.network_runtime")
local M = {}
local NAME = "chiptorio-computer-gui"

local function hardware_profile(entity)
  if entity.name == "qln-storage-drive" then
    return { computer_slots = 0, memory_slots = qmeta.DRIVE_SLOTS }
  end
  return meta.PROVIDERS[entity.name]
end

local function supported(entity)
  return entity and entity.valid and (hardware_profile(entity)
    or meta.LAB_DEMAND[entity.name] or entity.name == "metrology-lab")
end

local function destroy(player)
  for _, root in pairs({ player.gui.relative, player.gui.screen }) do
    local frame = root[NAME]
    if frame then frame.destroy() end
  end
end

local function number(value)
  value = value or 0
  return value >= 1000 and string.format("%.1fk", value / 1000) or string.format("%g", value)
end

local function find_device(entity)
  for _, graph in pairs(network.graphs() or {}) do
    for _, device in pairs(graph.devices or {}) do
      if device.entity == entity then
        local id = (graph.device_network or {})[device.id]
        return device, id and graph.networks[id]
      end
    end
  end
end

local function label(parent, name, caption)
  return parent.add({ type = "label", name = name, caption = caption })
end

local function update(player, entity)
  local frame = player.gui.relative[NAME]
  if not frame then return end
  local body = frame[NAME .. "-body"]
  local device, net = find_device(entity)
  local status = body["status"]
  status.caption = net and { "chiptorio.computer-network", net.id }
    or { "chiptorio.computer-connect-cable" }
  status.style.font_color = net and { 0.6, 1, 0.6 } or { 1, 0.8, 0.4 }
  local drive = entity.name == "qln-storage-drive"
  local profile = hardware_profile(entity)
  body["capacity-title"].caption = drive and { "chiptorio.computer-storage-title" }
    or profile and { "chiptorio.computer-capacity-title" }
    or { "chiptorio.computer-demand-title" }
  if profile then
    local inv = entity.get_inventory(defines.inventory.chest)
    local computers, memory, ignored = 0, 0, 0
    for i = 1, #inv do
      local stack = inv[i]
      if stack.valid_for_read then
        if meta.COMPUTER_PROFILES[stack.name] then
          local count = math.min(stack.count, math.max(0, profile.computer_slots - computers))
          computers = computers + count
          ignored = ignored + stack.count - count
        elseif meta.MEMORY_PROFILES[stack.name] then
          local count = math.min(stack.count, math.max(0, profile.memory_slots - memory))
          memory = memory + count
          ignored = ignored + stack.count - count
        else
          ignored = ignored + stack.count
        end
      end
    end
    body["hardware"].caption = drive and { "chiptorio.computer-drive-installed", memory, profile.memory_slots }
      or { "chiptorio.computer-installed", computers, profile.computer_slots, memory, profile.memory_slots }
    body["warning"].caption = ignored > 0 and { "chiptorio.computer-ignored", ignored }
      or ((computers + memory == 0) and { "chiptorio.computer-install-hardware" } or "")
    body["warning"].visible = ignored > 0 or computers + memory == 0
  end
  for _, key in ipairs({ "compute", "memory", "bandwidth" }) do
    local value = device and device[key]
    if not profile then
      value = device and device["demand_" .. key]
    end
    body[key].caption = { "chiptorio.computer-" .. (key == "compute" and "total-compute" or key),
      device and number(value) or { "chiptorio.computer-unavailable" } }
    body[key].visible = not drive
  end
  body["qln-cells"].visible = drive
  body["qln-cells"].caption = { "chiptorio.computer-storage-cells",
    device and number(device.qln_cells) or { "chiptorio.computer-unavailable" } }
  for _, key in ipairs(meta.COMPUTE_PROFILES) do
    local field = body["profile-" .. key]
    local value = device and device[key] or 0
    field.caption = { "chiptorio.computer-" .. key, number(value) }
    field.visible = profile ~= nil and value > 0
  end
  body["lab-hint"].visible = profile == nil
  if not profile then
    body["lab-hint"].caption = entity.name == "metrology-lab"
      and { "chiptorio.computer-qualification-hint" } or { "chiptorio.computer-research-hint" }
  end
  body["capacity-note"].visible = profile ~= nil
  body["capacity-note"].caption = drive and { "chiptorio.computer-drive-note" }
    or { "chiptorio.computer-capacity-note" }
end

function M.on_gui_opened(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  destroy(player)
  local entity = event.entity
  if not supported(entity) then return end
  local frame = player.gui.relative.add({
    type = "frame", name = NAME, direction = "vertical",
    caption = { "chiptorio.computer-panel-title" },
    anchor = { gui = entity.type == "container" and defines.relative_gui_type.container_gui
      or defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right },
  })
  frame.style.width = 300
  local body = frame.add({ type = "flow", name = NAME .. "-body", direction = "vertical" })
  body.style.vertical_spacing = 8
  local status = label(body, "status", "")
  status.style.font = "default-bold"
  status.style.single_line = false
  status.style.maximal_width = 270
  if hardware_profile(entity) then
    body.add({ type = "line" })
    label(body, "hardware-title", { "chiptorio.computer-hardware-title" }).style.font = "default-bold"
    label(body, "hardware", "")
    local hint = label(body, "hint", entity.name == "qln-storage-drive"
      and { "chiptorio.computer-drive-transfer-hint" } or { "chiptorio.computer-transfer-hint" })
    hint.style.single_line = false
    hint.style.maximal_width = 270
    local warning = label(body, "warning", "")
    warning.style.single_line = false
    warning.style.maximal_width = 270
    warning.style.font_color = { 1, 0.8, 0.4 }
  end
  body.add({ type = "line" })
  label(body, "capacity-title", { "chiptorio.computer-capacity-title" }).style.font = "default-bold"
  for _, key in ipairs({ "compute", "memory", "bandwidth" }) do label(body, key, "") end
  label(body, "qln-cells", "")
  for _, key in ipairs(meta.COMPUTE_PROFILES) do label(body, "profile-" .. key, "") end
  local lab_hint = label(body, "lab-hint", "")
  lab_hint.style.single_line = false
  lab_hint.style.maximal_width = 270
  local note = label(body, "capacity-note", { "chiptorio.computer-capacity-note" })
  note.style.single_line = false
  note.style.maximal_width = 270
  update(player, entity)
end

function M.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player then destroy(player) end
end

function M.tick()
  for _, player in pairs(game.players) do
    local entity = player.opened
    if player.opened_gui_type == defines.gui_type.entity and supported(entity) then
      if not player.gui.relative[NAME] then
        M.on_gui_opened({ player_index = player.index, entity = entity })
      else
        update(player, entity)
      end
    elseif player.gui.relative[NAME] then
      destroy(player)
    end
  end
end

return M
