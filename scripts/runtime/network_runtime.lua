-- Runtime: network topology cache, overlay and monitor GUI.
--
-- The topology maths live in scripts/runtime/network_graph.lua and are pure.
-- This module is the only network code that reads entities and writes
-- `storage`. It owns three things:
--   1. a chunk index, so a rebuild only scans chunks that can hold wiring;
--   2. the cached graph, rebuilt on the 60-tick dispatcher after a dirty mark;
--   3. the overlay rendering and the monitor window.
--
-- Event registration lives in control.lua. Modules must not call
-- script.on_event themselves or one module silently replaces another.

local graph_builder = require("scripts.runtime.network_graph")
local meta = require("scripts.research_meta")

local M = {}

local CHUNK = 32
local MAX_OVERLAY_LINES = 4000
local MAX_MONITOR_SUBNETS = 24

local CABLE = "network-cable"
local SWITCH = "network-switch"
local ROUTER = "network-router"
local MONITOR = "network-monitor"

local PROVIDER_NAMES = { "server-rack", "memory-bank", "datacenter" }

local LAB_NAMES = {}
for name in pairs(meta.LAB_DEMAND) do
  LAB_NAMES[#LAB_NAMES + 1] = name
end
table.sort(LAB_NAMES)

local NETWORK_NAMES = { CABLE, SWITCH, ROUTER, MONITOR }
for _, name in ipairs(PROVIDER_NAMES) do
  NETWORK_NAMES[#NETWORK_NAMES + 1] = name
end
for _, name in ipairs(LAB_NAMES) do
  NETWORK_NAMES[#NETWORK_NAMES + 1] = name
end

-- Which graph role an entity has. A provider contributes compute, memory and
-- bandwidth; a lab is a client that consumes compute. Everything else is
-- wiring.
local NETWORK_KINDS = {
  [CABLE] = "cable",
  [SWITCH] = "switch",
  [ROUTER] = "router",
  [MONITOR] = "monitor",
}
for _, name in ipairs(PROVIDER_NAMES) do
  NETWORK_KINDS[name] = "provider"
end
for _, name in ipairs(LAB_NAMES) do
  NETWORK_KINDS[name] = "lab"
end

-- Capacity a prototype contributes to its subnet. Providers are built from
-- their module inventory in provider_descriptor() instead of a static profile.
local PROFILES = {
  [SWITCH] = { bandwidth = 100 },
  [ROUTER] = { bandwidth = 250 },
  [MONITOR] = { power = 2 },
}

local SUBNET_COLORS = {
  { r = 0.27, g = 0.88, b = 0.75 },
  { r = 0.35, g = 0.65, b = 1.00 },
  { r = 0.95, g = 0.75, b = 0.30 },
  { r = 0.95, g = 0.45, b = 0.55 },
  { r = 0.65, g = 0.55, b = 0.95 },
  { r = 0.55, g = 0.90, b = 0.45 },
}

local ROUTER_COLOR = { r = 1.00, g = 0.70, b = 0.20 }
local ALERT_COLOR = { r = 0.95, g = 0.30, b = 0.30 }

local EMPTY_GRAPH = graph_builder.build({})

local function empty_graph()
  return EMPTY_GRAPH
end

local function is_network_entity(entity)
  return entity and entity.valid and NETWORK_KINDS[entity.name] ~= nil
end

local function init_storage()
  storage.network = storage.network or {}
  local network = storage.network
  network.version = 1
  network.dirty = network.dirty ~= false
  network.chunks = network.chunks or {}
  network.graphs = network.graphs or {}
  network.overlay = network.overlay or false
  network.render_ids = network.render_ids or {}
  network.monitors = network.monitors or {}
  network.module_signatures = network.module_signatures or {}
end

local function track(entity)
  local surface = entity.surface
  if not (surface and surface.valid) then
    return
  end
  local chunks = storage.network.chunks[surface.index]
  if not chunks then
    chunks = {}
    storage.network.chunks[surface.index] = chunks
  end
  local position = entity.position
  local cx = math.floor(position.x / CHUNK)
  local cy = math.floor(position.y / CHUNK)
  local key = cx .. ":" .. cy
  if not chunks[key] then
    chunks[key] = { cx = cx, cy = cy }
  end
end

local function scan_surface(surface)
  local graph = storage.network.graphs[surface.index]
  return graph or empty_graph()
end

local COMPUTE_KINDS = { "scalar", "vector", "tensor", "quantum" }
local POWER_FIELDS = { "power", "heat", "cooling" }

local function new_device(entity, kind)
  return {
    id = entity.unit_number,
    kind = kind,
    name = entity.name,
    force_index = entity.force and entity.force.index or nil,
    x = entity.position.x,
    y = entity.position.y,
    compute = 0,
    scalar = 0,
    vector = 0,
    tensor = 0,
    quantum = 0,
    memory = 0,
    bandwidth = 0,
    power = 0,
    heat = 0,
    cooling = 0,
    demand_compute = 0,
    demand_memory = 0,
    demand_bandwidth = 0,
    entity = entity,
  }
end

local function add_profile(device, profile, count)
  for _, field in ipairs(COMPUTE_KINDS) do
    local value = (profile[field] or 0) * count
    device[field] = device[field] + value
    device.compute = device.compute + value
  end
  device.memory = device.memory + (profile.capacity or 0) * count
  device.bandwidth = device.bandwidth + (profile.bandwidth or 0) * count
  for _, field in ipairs(POWER_FIELDS) do
    device[field] = device[field] + (profile[field] or 0) * count
  end
end

--- Read a provider's module inventory and turn it into capacities. Only the
--- first `chip_slots` chips and `memory_slots` memory modules count; extra
--- modules are stored but ignored, so the physical slot count is the limit.
local function provider_descriptor(entity)
  local profile = meta.PROVIDERS[entity.name]
  if not profile then
    return nil
  end

  local device = new_device(entity, "provider")
  device.bandwidth = profile.bandwidth or 0
  device.power = profile.power or 0
  device.heat = profile.heat or 0
  device.cooling = profile.cooling or 0
  device.chip_slots = profile.chip_slots or 0
  device.memory_slots = profile.memory_slots or 0
  device.chips = 0
  device.memory_modules = 0

  local inventory = entity.get_module_inventory()
  if not inventory then
    return device
  end

  for _, item in ipairs(inventory.get_contents()) do
    local chip = meta.CHIP_PROFILES[item.name]
    local memory = meta.MEMORY_PROFILES[item.name]
    if chip and device.chips < device.chip_slots then
      local count = item.count
      if count > device.chip_slots - device.chips then
        count = device.chip_slots - device.chips
      end
      device.chips = device.chips + count
      add_profile(device, chip, count)
    elseif memory and device.memory_modules < device.memory_slots then
      local count = item.count
      if count > device.memory_slots - device.memory_modules then
        count = device.memory_slots - device.memory_modules
      end
      device.memory_modules = device.memory_modules + count
      add_profile(device, memory, count)
    end
  end

  return device
end

local function lab_descriptor(entity)
  local base = meta.LAB_DEMAND[entity.name]
  if not base then
    return nil
  end
  local device = new_device(entity, "lab")
  device.demand_compute = base
  device.base_demand = base
  return device
end

local function rebuild_surface(surface)
  local chunks = storage.network.chunks[surface.index]
  local cables = {}
  local devices = {}
  local seen = {}

  if chunks then
    for _, chunk in pairs(chunks) do
      local area = {
        { chunk.cx * CHUNK, chunk.cy * CHUNK },
        { (chunk.cx + 1) * CHUNK, (chunk.cy + 1) * CHUNK },
      }
      for _, entity in ipairs(surface.find_entities_filtered({ area = area, name = NETWORK_NAMES })) do
        if entity.valid and NETWORK_KINDS[entity.name] and not seen[entity.unit_number] then
          seen[entity.unit_number] = true
          if entity.name == CABLE then
            cables[#cables + 1] = { x = entity.position.x, y = entity.position.y }
          else
            local kind = NETWORK_KINDS[entity.name]
            local device
            if kind == "provider" then
              device = provider_descriptor(entity)
            elseif kind == "lab" then
              device = lab_descriptor(entity)
            else
              local profile = PROFILES[entity.name] or {}
              device = new_device(entity, kind)
              device.bandwidth = profile.bandwidth or 0
              device.power = profile.power or 0
            end
            if device then
              devices[#devices + 1] = device
            end
          end
        end
      end
    end
  end

  return graph_builder.build({ cables = cables, devices = devices })
end

--- Stable signature of every provider's module contents. Modules can change
--- without an event (inserters, manual transfer), so the tick polls this instead
--- of listening to every inventory event. Only a change marks the graph dirty.
local function provider_signature(surface)
  local parts = {}
  for _, entity in ipairs(surface.find_entities_filtered({ name = PROVIDER_NAMES })) do
    if entity.valid then
      local inventory = entity.get_module_inventory()
      local contents = {}
      if inventory then
        for _, item in ipairs(inventory.get_contents()) do
          contents[#contents + 1] = item.name .. "=" .. item.count
        end
      end
      table.sort(contents)
      parts[#parts + 1] = tostring(entity.unit_number) .. ":" .. table.concat(contents, ",")
    end
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function clear_overlay()
  -- 2.1 has no rendering.destroy(id). Resolve the object and destroy it, so an
  -- id from an older save or a stale entry cannot throw.
  for _, render_id in ipairs(storage.network.render_ids) do
    local object = rendering.get_object_by_id(render_id)
    if object and object.valid then
      object.destroy()
    end
  end
  storage.network.render_ids = {}
end

local function draw_overlay()
  clear_overlay()
  if not storage.network.overlay then
    return
  end

  local drawn = 0
  for index, graph in pairs(storage.network.graphs) do
    local surface = game.get_surface(index)
    if surface and surface.valid then
      for _, subnet in ipairs(graph.subnets) do
        local color = SUBNET_COLORS[(subnet.id - 1) % #SUBNET_COLORS + 1]
        for _, cable in pairs(subnet.cables) do
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          -- Draw the forward half of each pair only, so every cable link is
          -- drawn exactly once.
          local neighbours = {
            { cable.x + 1, cable.y },
            { cable.x, cable.y + 1 },
            { cable.x + 1, cable.y + 1 },
            { cable.x - 1, cable.y + 1 },
          }
          for _, neighbour in ipairs(neighbours) do
            local neighbour_id = graph.subnet_by_tile[neighbour[1] .. ":" .. neighbour[2]]
            if neighbour_id == subnet.id and drawn < MAX_OVERLAY_LINES then
              local render = rendering.draw_line {
                surface = surface,
                color = color,
                width = 2,
                from = { cable.x + 0.5, cable.y + 0.5 },
                to = { neighbour[1] + 0.5, neighbour[2] + 0.5 },
              }
              storage.network.render_ids[#storage.network.render_ids + 1] = render.id
              drawn = drawn + 1
            end
          end
        end
      end

      -- Routers bridge subnets. Draw the router and a spoke to each subnet it
      -- reaches, so a joined network is visible as one shape.
      for router_id, subnet_ids in pairs(graph.router_subnets or {}) do
        local position = graph.positions and graph.positions[router_id]
        if position and #subnet_ids > 0 then
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          local marker = rendering.draw_circle {
            surface = surface,
            color = ROUTER_COLOR,
            radius = 0.3,
            width = 2,
            filled = true,
            target = position,
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = marker.id
          drawn = drawn + 1

          for _, subnet_id in ipairs(subnet_ids) do
            local subnet = graph.subnets[subnet_id]
            if subnet then
              if drawn >= MAX_OVERLAY_LINES then
                return
              end
              local spoke = rendering.draw_line {
                surface = surface,
                color = ROUTER_COLOR,
                width = 1,
                from = position,
                to = { subnet.x + 0.5, subnet.y + 0.5 },
              }
              storage.network.render_ids[#storage.network.render_ids + 1] = spoke.id
              drawn = drawn + 1
            end
          end
        end
      end

      -- Anything the graph could not attach is drawn red. It is the first
      -- thing to look for when a machine is not on the network.
      for _, device_id in ipairs(graph.unconnected or {}) do
        local position = graph.positions and graph.positions[device_id]
        if position then
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          local marker = rendering.draw_circle {
            surface = surface,
            color = ALERT_COLOR,
            radius = 0.35,
            width = 2,
            filled = false,
            target = position,
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = marker.id
          drawn = drawn + 1
        end
      end
    end
  end
end

local function rebuild_all()
  init_storage()
  local graphs = {}
  local signatures = {}
  for index, _ in pairs(storage.network.chunks) do
    local surface = game.get_surface(index)
    if surface and surface.valid then
      graphs[index] = rebuild_surface(surface)
      signatures[index] = provider_signature(surface)
    end
  end
  storage.network.graphs = graphs
  storage.network.module_signatures = signatures
  storage.network.dirty = false
end

--- Poll provider module contents. Returns true when anything changed.
function M.poll_modules()
  init_storage()
  local changed = false
  local signatures = {}
  for index in pairs(storage.network.chunks) do
    local surface = game.get_surface(index)
    if surface and surface.valid then
      local signature = provider_signature(surface)
      signatures[index] = signature
      if storage.network.module_signatures[index] ~= signature then
        changed = true
      end
    end
  end
  storage.network.module_signatures = signatures
  if changed then
    storage.network.dirty = true
  end
  return changed
end

--- Cached graphs, keyed by surface index. Read-only for other runtime modules.
--- Rebuilds first if the topology or a module inventory changed, so a remote
--- debug call sees the same graph the next tick would.
function M.graphs()
  init_storage()
  -- Module inventories change without an event; polling here means a remote
  -- debug call (and the research tick) sees the current chips, not last
  -- second's.
  M.poll_modules()
  if storage.network.dirty then
    rebuild_all()
    draw_overlay()
  end
  return storage.network.graphs
end

function M.init_storage()
  init_storage()
end

--- Seed the chunk index from every surface. Called once on init and on
--- configuration change; after that, build and mine events keep it current.
local function seed_chunks()
  init_storage()
  storage.network.chunks = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({ name = NETWORK_NAMES })) do
      if entity.valid then
        track(entity)
      end
    end
  end
  storage.network.dirty = true
end

function M.on_init()
  seed_chunks()
  rebuild_all()
end

function M.on_configuration_changed()
  seed_chunks()
  rebuild_all()
end

function M.mark_dirty()
  init_storage()
  storage.network.dirty = true
end

function M.is_dirty()
  init_storage()
  return storage.network.dirty
end

--- Cached graph for a surface, rebuilding first if anything changed.
function M.graph_for(surface)
  init_storage()
  if storage.network.dirty then
    rebuild_all()
    draw_overlay()
  end
  return scan_surface(surface)
end

--- The 60-tick job. Rebuilds at most once per second, never per entity.
function M.tick()
  init_storage()
  M.poll_modules()
  if storage.network.dirty then
    rebuild_all()
    draw_overlay()
    M.refresh_monitors()
  end
end

function M.on_built(event)
  local entity = event.entity or event.created_entity or event.destination
  if not is_network_entity(entity) then
    return
  end
  init_storage()
  track(entity)
  storage.network.dirty = true
end

function M.on_removed(event)
  -- The entity is already invalid for some of these events
  -- (script_raised_destroy), so there is nothing reliable to read. Marking
  -- dirty is cheap: rebuilds are coalesced to one per second.
  M.mark_dirty()
end

--- Turn the topology overlay on or off and redraw it. Returns the new state.
--- This exists separately from the keybind so tests and remote debugging can
--- exercise the rendering path without a player keypress.
function M.set_overlay(enabled)
  init_storage()
  storage.network.overlay = enabled and true or false
  draw_overlay()
  return storage.network.overlay
end

function M.on_toggle_overlay(event)
  local player = game.players[event.player_index]
  local enabled = M.set_overlay(not storage.network.overlay)
  if player then
    player.print({
      enabled and "chiptorio.network-overlay-on" or "chiptorio.network-overlay-off",
    })
  end
end

-- ---------------------------------------------------------------------------
-- Monitor window
-- ---------------------------------------------------------------------------

local MONITOR_GUI = "chiptorio-network-monitor"

local function monitor_players()
  local players = {}
  for index in pairs(storage.network.monitors) do
    local player = game.players[index]
    if player then
      players[#players + 1] = player
    end
  end
  return players
end

local function destroy_monitor(player)
  local frame = player.gui.screen[MONITOR_GUI]
  if frame and frame.valid then
    frame.destroy()
  end
  storage.network.monitors[player.index] = nil
end

local function add_stat(parent, caption, value)
  local row = parent.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  local label = row.add({ type = "label", caption = caption })
  label.style.minimal_width = 140
  row.add({ type = "label", caption = value })
end

local function format_number(value)
  if value >= 1000 then
    return string.format("%.1fk", value / 1000)
  end
  return string.format("%g", value)
end

local function rebuild_monitor(player)
  local frame = player.gui.screen[MONITOR_GUI]
  if not (frame and frame.valid) then
    return
  end
  local body = frame[MONITOR_GUI .. "-body"]
  if not (body and body.valid) then
    return
  end
  body.clear()

  local surface = player.surface
  local graph = M.graph_for(surface)
  if not graph or #graph.networks == 0 then
    body.add({ type = "label", caption = { "chiptorio.network-empty" } })
    return
  end

  add_stat(body, { "chiptorio.network-cables" }, tostring(graph.cable_count))
  add_stat(body, { "chiptorio.network-subnets" }, tostring(#graph.subnets))
  add_stat(body, { "chiptorio.network-networks" }, tostring(#graph.networks))
  if #graph.unconnected > 0 then
    add_stat(body, { "chiptorio.network-unconnected" }, tostring(#graph.unconnected))
  end

  for _, network in ipairs(graph.networks) do
    body.add({ type = "line" })
    local title = body.add({
      type = "label",
      caption = { "chiptorio.network-header", network.id, #network.subnets },
    })
    title.style.font = "default-bold"
    add_stat(body, { "chiptorio.network-compute" }, format_number(network.compute))
    if network.scalar > 0 then
      add_stat(body, { "chiptorio.network-scalar" }, format_number(network.scalar))
    end
    if network.vector > 0 then
      add_stat(body, { "chiptorio.network-vector" }, format_number(network.vector))
    end
    if network.tensor > 0 then
      add_stat(body, { "chiptorio.network-tensor" }, format_number(network.tensor))
    end
    if network.quantum > 0 then
      add_stat(body, { "chiptorio.network-quantum" }, format_number(network.quantum))
    end
    add_stat(body, { "chiptorio.network-memory" }, format_number(network.memory))
    add_stat(body, { "chiptorio.network-bandwidth" }, format_number(network.bandwidth))
    add_stat(body, { "chiptorio.network-latency" }, format_number(network.latency))
    add_stat(
      body,
      { "chiptorio.network-devices" },
      tostring(#(network.providers or {})) .. " / " .. tostring(#(network.labs or {}))
    )

    for index, subnet in ipairs(network.subnets) do
      if index > MAX_MONITOR_SUBNETS then
        body.add({ type = "label", caption = { "chiptorio.network-truncated", #network.subnets - index + 1 } })
        break
      end
      local subnet_stats = graph.subnets[subnet]
      if subnet_stats then
        local row = body.add({ type = "flow", direction = "horizontal" })
        row.style.vertical_align = "center"
        local swatch = row.add({ type = "label", caption = "  •  " })
        local color = SUBNET_COLORS[(subnet_stats.id - 1) % #SUBNET_COLORS + 1]
        swatch.style.font_color = color
        row.add({
          type = "label",
          caption = { "chiptorio.network-subnet", subnet_stats.id, subnet_stats.cable_count, #subnet_stats.devices },
        })
      end
    end
  end
end

function M.refresh_monitors()
  init_storage()
  for _, player in ipairs(monitor_players()) do
    rebuild_monitor(player)
  end
end

local function create_monitor(player)
  init_storage()
  destroy_monitor(player)

  local frame = player.gui.screen.add({
    type = "frame",
    name = MONITOR_GUI,
    direction = "vertical",
    caption = { "chiptorio.network-title" },
  })
  frame.auto_center = true

  local toolbar = frame.add({ type = "flow", direction = "horizontal" })
  toolbar.add({
    type = "button",
    name = MONITOR_GUI .. "-refresh",
    caption = { "chiptorio.network-refresh" },
  })
  toolbar.add({
    type = "button",
    name = MONITOR_GUI .. "-close",
    caption = { "chiptorio.network-close" },
  })

  local scroll = frame.add({
    type = "scroll-pane",
    name = MONITOR_GUI .. "-body",
    direction = "vertical",
  })
  scroll.style.maximal_height = 520
  scroll.style.minimal_width = 360

  storage.network.monitors[player.index] = true
  rebuild_monitor(player)
end

function M.open_monitor(player)
  if player then
    create_monitor(player)
  end
end

function M.on_gui_opened(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  local entity = event.entity
  if entity and entity.valid and entity.name == MONITOR then
    create_monitor(player)
  end
end

function M.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  init_storage()
  if storage.network.monitors[player.index] then
    destroy_monitor(player)
  end
end

function M.on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not (player and element and element.valid) then
    return
  end
  if element.name == MONITOR_GUI .. "-close" then
    destroy_monitor(player)
  elseif element.name == MONITOR_GUI .. "-refresh" then
    rebuild_monitor(player)
  end
end

function M.on_lua_shortcut(event)
  if event.prototype_name ~= "chiptorio-network-monitor" then
    return
  end
  local player = game.players[event.player_index]
  M.open_monitor(player)
end

-- ---------------------------------------------------------------------------
-- Debug interface
-- ---------------------------------------------------------------------------

--- Machine-readable topology summary for tests and remote debugging.
function M.summary(surface_index)
  init_storage()
  local surface = game.get_surface(surface_index or 1)
  if not surface then
    return nil
  end
  local graph = M.graph_for(surface)
  local summary = {
    cable_count = graph.cable_count,
    subnets = #graph.subnets,
    networks = #graph.networks,
    unconnected = #graph.unconnected,
    contested = #graph.contested,
    compute = 0,
    scalar = 0,
    vector = 0,
    quantum = 0,
    memory = 0,
    bandwidth = 0,
    labs = 0,
    providers = 0,
  }
  for _, network in ipairs(graph.networks) do
    summary.compute = summary.compute + network.compute
    summary.scalar = summary.scalar + network.scalar
    summary.vector = summary.vector + network.vector
    summary.quantum = summary.quantum + network.quantum
    summary.memory = summary.memory + network.memory
    summary.bandwidth = summary.bandwidth + network.bandwidth
    summary.labs = summary.labs + #(network.labs or {})
    summary.providers = summary.providers + #(network.providers or {})
  end
  return summary
end

--- /c remote.call("chiptorio-network", "status")
function M.status()
  init_storage()
  if storage.network.dirty then
    rebuild_all()
  end
  for index, graph in pairs(storage.network.graphs) do
    log(string.format(
      "CHIPTORIO NETWORK surface=%d cables=%d subnets=%d networks=%d unconnected=%d",
      index,
      graph.cable_count,
      #graph.subnets,
      #graph.networks,
      #graph.unconnected
    ))
  end
end

return M
