-- Runtime: custom GUI for Chiptorio computer buildings.
--
-- All Chiptorio computers are lab clones, so Factorio's default entity GUI
-- shows the vanilla "select research" button. Research is managed by the
-- network allocator, not by the player clicking in individual buildings, so
-- we replace the lab GUI with a custom read-only status panel that shows the
-- entity's network connection and the compute the network produces.

local meta = require("scripts.research_meta")
local network = require("scripts.runtime.network_runtime")

local M = {}

local COMPUTER_GUI = "chiptorio-computer-gui"

local COMPUTER_NAME_SET = nil
local function is_computer(entity)
  if not (entity and entity.valid) then
    return false
  end
  if not COMPUTER_NAME_SET then
    COMPUTER_NAME_SET = {}
    for name in pairs(meta.LAB_DEMAND) do
      COMPUTER_NAME_SET[name] = true
    end
    for _, name in ipairs({ "server-rack", "memory-bank", "datacenter" }) do
      COMPUTER_NAME_SET[name] = true
    end
    COMPUTER_NAME_SET["metrology-lab"] = true
  end
  return COMPUTER_NAME_SET[entity.name] == true
end

--- Find the cached device for an entity and the graph it lives in.
local function find_device(entity)
  for _, graph in pairs(network.graphs() or {}) do
    for _, device in pairs(graph.devices or {}) do
      if device.entity == entity then
        return device, graph
      end
    end
  end
  return nil, nil
end

--- Find the network that contains a given device id.
local function find_network_for_device(graph, device_id)
  for _, net in ipairs(graph.networks or {}) do
    for _, lab_id in ipairs(net.labs or {}) do
      if lab_id == device_id then
        return net
      end
    end
  end
  return nil
end

local function format_number(value)
  if value >= 1000 then
    return string.format("%.1fk", value / 1000)
  end
  return string.format("%g", value)
end

local function destroy_gui(player)
  local frame = player.gui.screen[COMPUTER_GUI]
  if frame and frame.valid then
    frame.destroy()
  end
end

local function rebuild_gui(player, entity)
  destroy_gui(player)

  local frame = player.gui.screen.add({
    type = "frame",
    name = COMPUTER_GUI,
    direction = "vertical",
    caption = entity.localised_name or entity.name,
  })
  frame.auto_center = true

  local body = frame.add({
    type = "scroll-pane",
    name = COMPUTER_GUI .. "-body",
    direction = "vertical",
  })
  body.style.maximal_height = 420
  body.style.minimal_width = 300

  local device, graph = find_device(entity)

  local kind_label = body.add({ type = "label", caption = { "chiptorio.computer-kind", entity.name } })
  kind_label.style.font = "default-bold"
  kind_label.style.top_margin = 4
  kind_label.style.bottom_margin = 4

  body.add({ type = "line" })

  if not device then
    body.add({ type = "label", caption = { "chiptorio.computer-not-on-network" } })
  else
    local net = find_network_for_device(graph, device.id)
    if net then
      body.add({ type = "label", caption = { "chiptorio.computer-network", net.id } })
      body.add({ type = "line" })
    end

    if device.compute > 0 then
      local header = body.add({ type = "label", caption = { "chiptorio.computer-compute" } })
      header.style.font = "default-bold"
      header.style.top_margin = 4

      if device.scalar > 0 then
        body.add({ type = "label", caption = { "chiptorio.computer-scalar", format_number(device.scalar) } })
      end
      if device.vector > 0 then
        body.add({ type = "label", caption = { "chiptorio.computer-vector", format_number(device.vector) } })
      end
      if device.tensor > 0 then
        body.add({ type = "label", caption = { "chiptorio.computer-tensor", format_number(device.tensor) } })
      end
      if device.quantum > 0 then
        body.add({ type = "label", caption = { "chiptorio.computer-quantum", format_number(device.quantum) } })
      end
      body.add({ type = "label", caption = { "chiptorio.computer-total-compute", format_number(device.compute) } })
      body.add({ type = "line" })
    end

    if device.memory > 0 then
      body.add({ type = "label", caption = { "chiptorio.computer-memory", format_number(device.memory) } })
    end
    if device.bandwidth > 0 then
      body.add({ type = "label", caption = { "chiptorio.computer-bandwidth", format_number(device.bandwidth) } })
    end
    if device.memory > 0 or device.bandwidth > 0 then
      body.add({ type = "line" })
    end

    if device.kind == "lab" and net then
      local header = body.add({ type = "label", caption = { "chiptorio.computer-network-labs" } })
      header.style.font = "default-bold"
      header.style.top_margin = 4

      body.add({ type = "label", caption = { "chiptorio.computer-labs-on-network", #(net.labs or {}) } })

      local active = 0
      for _, lab_id in ipairs(net.labs or {}) do
        local d = graph.devices[lab_id]
        if d and d.entity and d.entity.valid and not d.entity.disabled_by_script then
          active = active + 1
        end
      end
      body.add({ type = "label", caption = { "chiptorio.computer-labs-active", active } })
    end
  end

  local toolbar = frame.add({ type = "flow", direction = "horizontal" })
  toolbar.style.horizontally_stretchable = true
  toolbar.add({
    type = "button",
    name = COMPUTER_GUI .. "-close",
    caption = { "chiptorio.computer-close" },
  })

  player.opened = frame
  frame.bring_to_front()
end

function M.on_gui_opened(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  local entity = event.entity
  if entity and entity.valid and is_computer(entity) then
    destroy_gui(player)
    rebuild_gui(player, entity)
  end
end

function M.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  local element = event.element
  if element and element.valid and element.name == COMPUTER_GUI then
    destroy_gui(player)
  end
end

function M.on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not (player and element and element.valid) then
    return
  end
  if element.name == COMPUTER_GUI .. "-close" then
    destroy_gui(player)
    player.opened = nil
  end
end

return M
