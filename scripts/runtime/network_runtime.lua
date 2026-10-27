-- Runtime: network topology cache, overlay and monitor GUI (physical layer).
--
-- DESIGN §5.2. The topology maths live in scripts/runtime/network_graph.lua
-- and are pure. This module is the only network code that reads entities and
-- writes `storage`. It owns three things:
--   1. a chunk index, so a rebuild only scans chunks that can hold wiring;
--   2. the cached graph, rebuilt on the 60-tick dispatcher after a dirty mark;
--   3. the overlay rendering and the monitor window.
--
-- Event registration lives in control.lua. Modules must not call
-- script.on_event themselves or one module silently replaces another.

local graph_builder = require("scripts.runtime.network_graph")
local meta = require("scripts.research_meta")
local qmeta = require("scripts.qln_meta")

local M = {}

local CHUNK = 32
-- A device can attach to wiring in a neighbouring chunk: a cable reaches one
-- tile (adjacency only), a router's WiFi reaches sixteen. Buffer every scan by
-- the longest reach.
local SCAN_MARGIN = qmeta.WIRELESS_RANGE or 16
local MAX_OVERLAY_LINES = 4000
local MAX_MONITOR_NETWORKS = 24

local CABLE = "network-cable"
local COAXIAL = "network-coaxial-cable"
local FIBER_MM = "network-fiber-mm-cable"
local FIBER_SM = "network-fiber-sm-cable"
local SWITCH = "network-switch"
local ROUTER = "network-router"
local MONITOR = "network-monitor"
local METROLOGY = "metrology-lab"
local ANSWER = "answer-engine"

local PROVIDER_NAMES = { "server-rack", "memory-bank", "datacenter" }

local LAB_NAMES = {}
for name in pairs(meta.LAB_DEMAND) do
  LAB_NAMES[#LAB_NAMES + 1] = name
end
table.sort(LAB_NAMES)

-- Every entity the network layer tracks. Repeater is dropped; it is folded
-- into the switch's junction-box role.
local NETWORK_NAMES = { CABLE, COAXIAL, FIBER_MM, FIBER_SM, SWITCH, ROUTER, MONITOR, METROLOGY, ANSWER }
for _, name in ipairs(PROVIDER_NAMES) do
  NETWORK_NAMES[#NETWORK_NAMES + 1] = name
end
for _, name in ipairs(LAB_NAMES) do
  NETWORK_NAMES[#NETWORK_NAMES + 1] = name
end

-- QLN node names are tracked by qln_runtime.lua but also scanned here so they
-- attach to the network graph. qln_runtime registers its own names separately.
local QLN_NODE_NAMES = {
  "qln-import-node",
  "qln-export-node",
  "qln-provider-node",
  "qln-requester-node",
  "qln-terminal",
  "qln-storage-drive",
  "construction-core",
  "foup-dock",
  "quantum-entanglement-core",
}
for _, name in ipairs(QLN_NODE_NAMES) do
  NETWORK_NAMES[#NETWORK_NAMES + 1] = name
end

-- Which graph role an entity has.
local NETWORK_KINDS = {
  [CABLE] = "cable",
  [COAXIAL] = "cable",
  [FIBER_MM] = "cable",
  [FIBER_SM] = "cable",
  [SWITCH] = "switch",
  [ROUTER] = "router",
  [MONITOR] = "monitor",
  [METROLOGY] = "metrology",
  [ANSWER] = "answer",
}
for _, name in ipairs(PROVIDER_NAMES) do
  NETWORK_KINDS[name] = "provider"
end
for _, name in ipairs(LAB_NAMES) do
  NETWORK_KINDS[name] = "lab"
end
for _, name in ipairs(QLN_NODE_NAMES) do
  NETWORK_KINDS[name] = name == "qln-storage-drive" and "qln-drive" or "qln"
end

-- Static capacity a prototype contributes. Providers are built from their
-- module inventory in provider_descriptor() instead of a static profile.
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
local SWITCH_COLOR = { r = 0.55, g = 0.85, b = 1.00 }
local ALERT_COLOR = { r = 0.95, g = 0.30, b = 0.30 }

-- Cable tier colors for the overlay. Each tier gets a distinct color so the
-- weakest-link rule is visible at a glance.
local CABLE_COLORS = {
  ["network-cable"] = { r = 0.85, g = 0.55, b = 0.30 },
  ["network-coaxial-cable"] = { r = 0.20, g = 0.60, b = 0.95 },
  ["network-fiber-mm-cable"] = { r = 0.40, g = 0.95, b = 0.40 },
  ["network-fiber-sm-cable"] = { r = 0.70, g = 0.40, b = 0.95 },
}

local EMPTY_GRAPH = graph_builder.build({})

local function empty_graph()
  return EMPTY_GRAPH
end

local function tile_key(x, y)
  return x .. ":" .. y
end

local function is_network_entity(entity)
  return entity and entity.valid and NETWORK_KINDS[entity.name] ~= nil
end

local function init_storage()
  storage.network = storage.network or {}
  local network = storage.network
  network.version = 2
  network.dirty = network.dirty ~= false
  network.chunks = network.chunks or {}
  network.graphs = network.graphs or {}
  network.overlay = network.overlay or false
  network.render_ids = network.render_ids or {}
  network.monitors = network.monitors or {}
  network.module_signatures = network.module_signatures or {}
  network.chip_multipliers = network.chip_multipliers or {}
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
    direction = entity.direction or 0,
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

local function add_profile(device, profile, count, multiplier)
  local compute_scale = multiplier and multiplier.compute or 1
  local power_scale = multiplier and multiplier.power or 1
  for _, field in ipairs(COMPUTE_KINDS) do
    local value = (profile[field] or 0) * count * compute_scale
    device[field] = device[field] + value
    device.compute = device.compute + value
  end
  -- Memory capacity and backplane bandwidth are hardware, not compute: a
  -- process refinement must never create memory or ports out of nothing.
  device.memory = device.memory + (profile.capacity or 0) * count
  device.bandwidth = device.bandwidth + (profile.bandwidth or 0) * count
  for _, field in ipairs(POWER_FIELDS) do
    local scale = (field == "power" or field == "heat") and power_scale or 1
    device[field] = device[field] + (profile[field] or 0) * count * scale
  end
end

-- Force-wide compute and power multipliers from completed half-nodes. The
-- qualification runtime is the only writer; this module reads the table while
-- describing providers so a rebuilt graph picks the new values up.
function M.set_chip_multipliers(force_index, bonus)
  init_storage()
  bonus = bonus or {}
  storage.network.chip_multipliers[force_index] = {
    compute = bonus.compute or 1,
    power = bonus.power or 1,
  }
  storage.network.dirty = true
end

function M.chip_multipliers(force_index)
  init_storage()
  return storage.network.chip_multipliers[force_index] or { compute = 1, power = 1 }
end

--- Read a provider's module inventory and turn it into capacities. Only the
-- first `computer_slots` computers and `memory_slots` memory modules count;
-- extra modules are stored but ignored, so the physical slot count is the limit.
local function provider_descriptor(entity)
  local profile = meta.PROVIDERS[entity.name]
  if not profile then
    return nil
  end

  local multiplier = M.chip_multipliers(entity.force and entity.force.index or 0)
  local power_scale = multiplier.power or 1

  local force_index = entity.force and entity.force.index or 0
  local infinite = storage.research and storage.research.infinite_multipliers
    and storage.research.infinite_multipliers[force_index] or {}
  local efficiency_mult = infinite["chip-efficiency"] or 1
  local cooling_mult = infinite["cooling-efficiency"] or 1

  local device = new_device(entity, "provider")
  device.bandwidth = profile.bandwidth or 0
  device.power = (profile.power or 0) * power_scale * efficiency_mult
  device.heat = (profile.heat or 0) * power_scale * efficiency_mult
  device.cooling = (profile.cooling or 0) * cooling_mult
  device.computer_slots = profile.computer_slots or 0
  device.memory_slots = profile.memory_slots or 0
  device.computers = 0
  device.memory_modules = 0

  local inventory = entity.get_module_inventory()
  if not inventory then
    return device
  end

  for _, item in ipairs(inventory.get_contents()) do
    local computer = meta.COMPUTER_PROFILES[item.name]
    local memory = meta.MEMORY_PROFILES[item.name]
    if computer and device.computers < device.computer_slots then
      local count = item.count
      if count > device.computer_slots - device.computers then
        count = device.computer_slots - device.computers
      end
      device.computers = device.computers + count
      add_profile(device, computer, count, multiplier)
    elseif memory and device.memory_modules < device.memory_slots then
      local count = item.count
      if count > device.memory_slots - device.memory_modules then
        count = device.memory_slots - device.memory_modules
      end
      device.memory_modules = device.memory_modules + count
      add_profile(device, memory, count, multiplier)
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

--- A Metrology Lab is a network client: it needs power and, for the later
-- half-nodes, a network that meets the qualification gate. It contributes no
-- capacity and consumes no research compute.
local function metrology_descriptor(entity)
  local device = new_device(entity, "metrology")
  device.demand_compute = 0
  device.base_demand = 0
  return device
end

--- A Storage Drive contributes QLN item cells, not research memory. It is a
-- lab clone with four memory slots; extra modules beyond the slot count are
-- stored but ignored, exactly like a provider.
local function qln_drive_descriptor(entity)
  local device = new_device(entity, "qln-drive")
  device.qln_cells = 0
  local inventory = entity.get_module_inventory()
  if not inventory then
    return device
  end
  local used = 0
  for _, item in ipairs(inventory.get_contents()) do
    local cells = qmeta.DRIVE_CELLS[item.name]
    if cells and used < qmeta.DRIVE_SLOTS then
      local count = item.count
      if count > qmeta.DRIVE_SLOTS - used then
        count = qmeta.DRIVE_SLOTS - used
      end
      used = used + count
      device.qln_cells = device.qln_cells + cells * count
    end
  end
  return device
end

local function qln_descriptor(entity)
  return new_device(entity, "qln")
end

local function answer_descriptor(entity)
  return new_device(entity, "answer")
end

local function generic_descriptor(entity, kind)
  local profile = PROFILES[entity.name] or {}
  local device = new_device(entity, kind)
  device.bandwidth = profile.bandwidth or 0
  device.power = profile.power or 0
  if entity.name == ROUTER then
    device.wireless_reach = qmeta.WIRELESS_RANGE or 16
  end
  return device
end

--- Collect entities from scanned chunks and turn them into graph descriptors.
-- Cables carry their tier. Switches and routers carry their direction for
-- 3×2 footprint computation.
local function rebuild_surface(surface)
  local chunks = storage.network.chunks[surface.index]
  local cables = {}
  local devices = {}
  local seen = {}

  if chunks then
    for _, chunk in pairs(chunks) do
      local area = {
        { chunk.cx * CHUNK - SCAN_MARGIN, chunk.cy * CHUNK - SCAN_MARGIN },
        { (chunk.cx + 1) * CHUNK + SCAN_MARGIN, (chunk.cy + 1) * CHUNK + SCAN_MARGIN },
      }
      for _, entity in ipairs(surface.find_entities_filtered({ area = area, name = NETWORK_NAMES })) do
        if entity.valid and NETWORK_KINDS[entity.name] and not seen[entity.unit_number] then
          seen[entity.unit_number] = true
          if entity.name == CABLE then
            cables[#cables + 1] = {
              x = entity.position.x,
              y = entity.position.y,
              tier = "network-cable",
            }
          elseif entity.name == COAXIAL then
            cables[#cables + 1] = {
              x = entity.position.x,
              y = entity.position.y,
              tier = "network-coaxial-cable",
            }
          elseif entity.name == FIBER_MM then
            cables[#cables + 1] = {
              x = entity.position.x,
              y = entity.position.y,
              tier = "network-fiber-mm-cable",
            }
          elseif entity.name == FIBER_SM then
            cables[#cables + 1] = {
              x = entity.position.x,
              y = entity.position.y,
              tier = "network-fiber-sm-cable",
            }
          else
            local kind = NETWORK_KINDS[entity.name]
            local device
            if kind == "provider" then
              device = provider_descriptor(entity)
            elseif kind == "lab" then
              device = lab_descriptor(entity)
            elseif kind == "metrology" then
              device = metrology_descriptor(entity)
            elseif kind == "qln-drive" then
              device = qln_drive_descriptor(entity)
            elseif kind == "qln" then
              device = qln_descriptor(entity)
            elseif kind == "answer" then
              device = answer_descriptor(entity)
            else
              device = generic_descriptor(entity, kind)
            end
            if device then
              devices[#devices + 1] = device
            end
          end
        end
      end
    end
  end

  -- Index the chunks the margin reached, so a device that sits just across a
  -- border is scanned directly next time instead of only through the buffer.
  -- Note: we don't have `found` here because we're iterating chunks; tracking
  -- happens on build/remove events instead.
  return graph_builder.build({ cables = cables, devices = devices })
end

--- Stable signature of every provider's module contents. Modules can change
-- without an event (inserters, manual transfer), so the tick polls this instead
-- of listening to every inventory event. Only a change marks the graph dirty.
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
      -- Draw every cable segment colored by tier. The weakest-link rule is
      -- visible: a single twisted-pair tile in a fiber run shows as copper
      -- among the glass.
      for _, segment in pairs(graph.raw_segments or {}) do
        if drawn >= MAX_OVERLAY_LINES then
          return
        end
        -- Determine color from first cable's tier (segment runs at weakest
        -- tier, but individual tiles may show their actual tier).
        local color = CABLE_COLORS["network-cable"]
        for _, cable in ipairs(segment.cables) do
          local tier_color = CABLE_COLORS[cable.tier]
          if tier_color then
            color = tier_color
            break
          end
        end
        -- Draw each cable as a point (small circle) since cables are 1×1.
        for _, cable in ipairs(segment.cables) do
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          local render = rendering.draw_circle {
            surface = surface,
            color = color,
            radius = 0.25,
            width = 1,
            filled = true,
            target = { cable.x + 0.5, cable.y + 0.5 },
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = render.id
          drawn = drawn + 1
        end
        -- Draw lines between adjacent cables in the segment.
        local cable_at = {}
        for _, cable in ipairs(segment.cables) do
          cable_at[tile_key(cable.x, cable.y)] = true
        end
        for _, cable in ipairs(segment.cables) do
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          local neighbours = {
            { cable.x + 1, cable.y },
            { cable.x, cable.y + 1 },
          }
          for _, neighbour in ipairs(neighbours) do
            if cable_at[tile_key(neighbour[1], neighbour[2])] then
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

      -- Draw switches as blue squares on their center tile.
      for _, switch in ipairs(graph.switches or {}) do
        if drawn >= MAX_OVERLAY_LINES then
          return
        end
        local position = graph.positions and graph.positions[switch.id]
        if position then
          local render = rendering.draw_rectangle {
            surface = surface,
            color = SWITCH_COLOR,
            filled = false,
            width = 2,
            left_top = { position.x - 1.5, position.y - 1 },
            right_bottom = { position.x + 1.5, position.y + 1 },
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = render.id
          drawn = drawn + 1
        end
      end

      -- Draw routers as orange circles with WiFi reach indicator.
      for _, router in ipairs(graph.routers or {}) do
        if drawn >= MAX_OVERLAY_LINES then
          return
        end
        local position = graph.positions and graph.positions[router.id]
        if position then
          local marker = rendering.draw_circle {
            surface = surface,
            color = ROUTER_COLOR,
            radius = 0.35,
            width = 2,
            filled = true,
            target = position,
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = marker.id
          drawn = drawn + 1

          -- WiFi reach circle (semi-transparent).
          local reach = rendering.draw_circle {
            surface = surface,
            color = { r = 1.0, g = 0.7, b = 0.2, a = 0.3 },
            radius = qmeta.WIRELESS_RANGE or 16,
            width = 1,
            filled = false,
            target = position,
          }
          storage.network.render_ids[#storage.network.render_ids + 1] = reach.id
          drawn = drawn + 1
        end
      end

      -- Anything the graph could not attach is drawn red. Conflicts (device
      -- touching multiple networks) are drawn as larger red circles.
      for _, device_id in ipairs(graph.unconnected or {}) do
        local position = graph.positions and graph.positions[device_id]
        if position then
          if drawn >= MAX_OVERLAY_LINES then
            return
          end
          local color = ALERT_COLOR
          local radius = 0.35
          if graph.conflicts and graph.conflicts[device_id] then
            color = { r = 1.0, g = 0.1, b = 0.1 }
            radius = 0.5
          end
          local marker = rendering.draw_circle {
            surface = surface,
            color = color,
            radius = radius,
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
-- Rebuilds first if the topology or a module inventory changed, so a remote
-- debug call (and the research tick) sees the current chips, not last
-- second's.
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

-- The qualification and QLN runtimes register extra monitor sections. A
-- callback keeps the dependency one-way: network_runtime never requires them.
local qualification_provider = nil
local qln_provider = nil

function M.set_qualification_provider(provider)
  qualification_provider = provider
end

function M.set_qln_provider(provider)
  qln_provider = provider
end

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

-- ---------------------------------------------------------------------------
-- Monitor tab: Overview
-- ---------------------------------------------------------------------------

local function render_overview(body, graph, player)
  body.add({ type = "label", caption = { "chiptorio.monitor-overview-title" } })
  body.add({ type = "line" })

  add_stat(body, { "chiptorio.network-cables" }, tostring(graph.cable_count))
  add_stat(body, { "chiptorio.network-networks" }, tostring(#graph.networks))
  if #graph.unconnected > 0 then
    add_stat(body, { "chiptorio.network-unconnected" }, tostring(#graph.unconnected))
  end

  for _, network in ipairs(graph.networks) do
    body.add({ type = "line" })
    local title = body.add({
      type = "label",
      caption = { "chiptorio.network-header", network.id },
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
    add_stat(body, { "chiptorio.network-power" }, format_number(network.power or 0))
    add_stat(body, { "chiptorio.network-heat" }, format_number(network.heat or 0))
    add_stat(body, { "chiptorio.network-cooling" }, format_number(network.cooling or 0))
    add_stat(body, { "chiptorio.network-latency" }, format_number(network.latency))
    add_stat(
      body,
      { "chiptorio.network-devices" },
      tostring(#(network.providers or {})) .. " / " .. tostring(#(network.labs or {}))
    )
    if #(network.qln_nodes or {}) > 0 then
      add_stat(body, { "chiptorio.network-qln-nodes" }, tostring(#network.qln_nodes))
    end
    if #(network.routers or {}) > 0 then
      add_stat(body, { "chiptorio.network-routers" }, tostring(#network.routers))
    end
  end

  -- QLN and qualification sections are rendered by their respective runtimes
  -- through the registered providers, appended to the Overview tab.
  if qln_provider then
    qln_provider(player, body)
  end
  if qualification_provider then
    qualification_provider(player, body)
  end
end

-- ---------------------------------------------------------------------------
-- Monitor tab: Topology
-- ---------------------------------------------------------------------------

local function render_topology(body, graph)
  body.add({ type = "label", caption = { "chiptorio.monitor-topology-title" } })
  body.add({ type = "line" })

  local shown = 0
  for _, network in ipairs(graph.networks) do
    if shown >= MAX_MONITOR_NETWORKS then
      body.add({ type = "label", caption = { "chiptorio.network-truncated", #graph.networks - shown } })
      break
    end
    shown = shown + 1

    body.add({ type = "line" })
    local title = body.add({
      type = "label",
      caption = { "chiptorio.network-header", network.id },
    })
    title.style.font = "default-bold"
    add_stat(body, { "chiptorio.network-segments" }, tostring(#network.merged_segments))
    add_stat(body, { "chiptorio.network-bandwidth" }, format_number(network.bandwidth))
    add_stat(body, { "chiptorio.network-latency" }, format_number(network.latency))

    for _, mroot in ipairs(network.merged_segments) do
      local mseg = graph.merged_segments[mroot]
      if mseg then
        local row = body.add({ type = "flow", direction = "horizontal" })
        row.style.vertical_align = "center"
        row.add({ type = "label", caption = { "chiptorio.network-segment", #mseg.raw_roots } })
        add_stat(row, { "chiptorio.network-segment-bw" }, format_number(mseg.bandwidth))
        add_stat(row, { "chiptorio.network-segment-lat" }, format_number(mseg.latency))
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Monitor tab: Devices
-- ---------------------------------------------------------------------------

local function render_devices(body, graph)
  body.add({ type = "label", caption = { "chiptorio.monitor-devices-title" } })
  body.add({ type = "line" })

  for _, network in ipairs(graph.networks) do
    body.add({ type = "line" })
    local title = body.add({
      type = "label",
      caption = { "chiptorio.network-header", network.id },
    })
    title.style.font = "default-bold"

    if #(network.providers or {}) > 0 then
      local label = body.add({ type = "label", caption = { "chiptorio.network-providers" } })
      label.style.font = "default-bold"
      for _, id in ipairs(network.providers) do
        local device = graph.devices[id]
        if device then
          local row = body.add({ type = "flow", direction = "horizontal" })
          row.style.vertical_align = "center"
          row.add({ type = "label", caption = device.name .. " (" .. device.id .. ")" })
          local mod_line = ""
          if device.computers and device.computers > 0 then
            mod_line = mod_line .. device.computers .. " compute"
          end
          if device.memory_modules and device.memory_modules > 0 then
            if #mod_line > 0 then mod_line = mod_line .. ", " end
            mod_line = mod_line .. device.memory_modules .. " memory"
          end
          row.add({ type = "label", caption = mod_line })
        end
      end
    end

    if #(network.labs or {}) > 0 then
      local label = body.add({ type = "label", caption = { "chiptorio.network-labs" } })
      label.style.font = "default-bold"
      for _, id in ipairs(network.labs) do
        local device = graph.devices[id]
        if device then
          local row = body.add({ type = "flow", direction = "horizontal" })
          row.style.vertical_align = "center"
          row.add({ type = "label", caption = device.name .. " (" .. device.id .. ")" })
          row.add({ type = "label", caption = format_number(device.demand_compute or 0) .. " compute demand" })
        end
      end
    end

    if #(network.qln_nodes or {}) > 0 then
      local label = body.add({ type = "label", caption = { "chiptorio.network-qln" } })
      label.style.font = "default-bold"
      for _, id in ipairs(network.qln_nodes) do
        local device = graph.devices[id]
        if device then
          local row = body.add({ type = "flow", direction = "horizontal" })
          row.style.vertical_align = "center"
          row.add({ type = "label", caption = device.name .. " (" .. device.id .. ")" })
          local cells = ""
          if device.qln_cells and device.qln_cells > 0 then
            cells = device.qln_cells .. " cells"
          else
            cells = "no QLN cells"
          end
          row.add({ type = "label", caption = cells })
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Monitor tab: Alerts
-- ---------------------------------------------------------------------------

local function render_alerts(body, graph)
  body.add({ type = "label", caption = { "chiptorio.monitor-alerts-title" } })
  body.add({ type = "line" })

  local alert_count = 0

  -- Unconnected devices
  for _, id in ipairs(graph.unconnected or {}) do
    local device = graph.devices[id]
    if device then
      alert_count = alert_count + 1
      local row = body.add({ type = "flow", direction = "horizontal" })
      row.style.vertical_align = "center"
      local label = row.add({ type = "label", caption = { "chiptorio.alert-unconnected", device.name } })
      label.style.font_color = ALERT_COLOR
      row.add({ type = "label", caption = "id=" .. device.id })
    end
  end

  -- Conflicted devices (touching multiple networks)
  if graph.conflicts then
    for id, nets in pairs(graph.conflicts) do
      local device = graph.devices[id]
      if device then
        alert_count = alert_count + 1
        local row = body.add({ type = "flow", direction = "horizontal" })
        row.style.vertical_align = "center"
        local label = row.add({ type = "label", caption = { "chiptorio.alert-conflict", device.name, #nets } })
        label.style.font_color = ALERT_COLOR
        row.add({ type = "label", caption = "networks: " .. #nets })
      end
    end
  end

  -- Network-level alerts: memory, bandwidth, cooling, power shortfalls
  for _, network in ipairs(graph.networks) do
    -- Check each lab on the network for its tech's gate
    -- (This is a simplified check; the full evaluation happens in research_runtime)
    local heat = network.heat or 0
    local cooling = network.cooling or 0
    if heat > 0 and cooling < heat then
      alert_count = alert_count + 1
      local row = body.add({ type = "flow", direction = "horizontal" })
      row.style.vertical_align = "center"
      local label = row.add({ type = "label", caption = { "chiptorio.alert-cooling", network.id } })
      label.style.font_color = ALERT_COLOR
      row.add({ type = "label", caption = "heat=" .. format_number(heat) .. " cooling=" .. format_number(cooling) })
    end
  end

  if alert_count == 0 then
    body.add({ type = "label", caption = { "chiptorio.alert-none" } })
  end
end

-- ---------------------------------------------------------------------------
-- Monitor tab: Routing
-- ---------------------------------------------------------------------------

local function render_routing(body, graph)
  body.add({ type = "label", caption = { "chiptorio.monitor-routing-title" } })
  body.add({ type = "line" })

  for _, network in ipairs(graph.networks) do
    if #(network.routers or {}) > 0 then
      body.add({ type = "line" })
      local title = body.add({
        type = "label",
        caption = { "chiptorio.network-header", network.id },
      })
      title.style.font = "default-bold"

      for _, router_id in ipairs(network.routers) do
        local router = graph.devices[router_id]
        if router then
          local row = body.add({ type = "flow", direction = "horizontal" })
          row.style.vertical_align = "center"
          row.add({ type = "label", caption = "Router (" .. router_id .. ")" })
          local seg_count = #(router.segments or {})
          row.add({ type = "label", caption = seg_count .. " segment(s)" })
          local reach = router.wireless_reach or 0
          row.add({ type = "label", caption = "WiFi reach: " .. reach .. " tiles" })
        end
      end
    end
  end

  if #graph.routers == 0 then
    body.add({ type = "label", caption = { "chiptorio.monitor-routing-none" } })
  end
end

-- ---------------------------------------------------------------------------
-- Monitor rebuild with tabs
-- ---------------------------------------------------------------------------

local TAB_OVERVIEW = 1
local TAB_TOPOLOGY = 2
local TAB_DEVICES = 3
local TAB_ALERTS = 4
local TAB_ROUTING = 5

local TAB_CAPTIONS = {
  { "chiptorio.tab-overview" },
  { "chiptorio.tab-topology" },
  { "chiptorio.tab-devices" },
  { "chiptorio.tab-alerts" },
  { "chiptorio.tab-routing" },
}

local TAB_RENDERERS = {
  render_overview,
  render_topology,
  render_devices,
  render_alerts,
  render_routing,
}

local function rebuild_monitor(player)
  local frame = player.gui.screen[MONITOR_GUI]
  if not (frame and frame.valid) then
    return
  end

  local surface = player.surface
  local graph = M.graph_for(surface)

  -- Find or create the tabbed pane
  local tabbed = frame[MONITOR_GUI .. "-tabs"]
  if not (tabbed and tabbed.valid) then
    return
  end

  -- Get active tab from the tabbed pane (Factorio manages this on clicks)
  local active_tab = tabbed.active_tab_index or 1
  active_tab = math.min(math.max(active_tab, 1), #TAB_CAPTIONS)

  -- Rebuild tabs if needed (network count changed)
  local current_count = #tabbed.tabs
  local needed_count = #graph.networks > 0 and #TAB_CAPTIONS or 0

  if current_count ~= needed_count then
    tabbed.clear()
    if needed_count > 0 then
      for _, caption in ipairs(TAB_CAPTIONS) do
        tabbed.add({ type = "tab", caption = caption })
      end
    end
    active_tab = 1
  end

  if needed_count == 0 then
    -- No networks: show empty state on the first tab
    local pane = tabbed[1]
    if pane and pane.valid then
      pane.clear()
      pane.add({ type = "label", caption = { "chiptorio.network-empty" } })
    end
    tabbed.active_tab_index = 1
    return
  end

  -- Set active tab
  tabbed.active_tab_index = active_tab

  -- Get the active tab's content pane
  local pane = tabbed[active_tab]
  if not (pane and pane.valid) then
    return
  end

  -- Clear and render the active tab
  pane.clear()
  local renderer = TAB_RENDERERS[active_tab]
  if renderer then
    if active_tab == TAB_OVERVIEW then
      renderer(pane, graph, player)
    else
      renderer(pane, graph)
    end
  end

  -- Store the active tab for persistence across saves
  local state = storage.network.monitors[player.index]
  if not state then
    state = {}
    storage.network.monitors[player.index] = state
  end
  state.tab = active_tab
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

  local tabbed = frame.add({
    type = "tabbed-pane",
    name = MONITOR_GUI .. "-tabs",
  })
  for _, caption in ipairs(TAB_CAPTIONS) do
    local tab = tabbed.add({ type = "tab", caption = caption })
    tab.add({ type = "scroll-pane", name = MONITOR_GUI .. "-pane", direction = "vertical" })
  end

  -- Store initial tab state
  storage.network.monitors[player.index] = { tab = 1 }

  -- Same suppression as the QLN windows: the monitor is a container clone, so
  -- the default chest GUI opens first. Claiming `player.opened` closes it and
  -- puts our monitor in front instead of below it.
  player.opened = frame
  frame.bring_to_front()

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
  if entity and entity.valid then
    if entity.name == MONITOR then
      create_monitor(player)
    else
      -- A screen frame survives the game closing the entity GUI, so opening
      -- another entity would leave the monitor floating over it.
      init_storage()
      destroy_monitor(player)
    end
  end
end

function M.on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  init_storage()
  local element = event.element
  if element and element.valid then
    if element.name == MONITOR_GUI then
      destroy_monitor(player)
    end
    return
  end
  local entity = event.entity
  if entity and entity.valid and entity.name == MONITOR then
    destroy_monitor(player)
  end
end

function M.on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not (player and element and element.valid) then
    return
  end
  if element.name == MONITOR_GUI .. "-refresh" then
    rebuild_monitor(player)
  elseif element.name == MONITOR_GUI .. "-close" then
    destroy_monitor(player)
  elseif element.name == MONITOR_GUI .. "-tabs" then
    -- User switched tabs; rebuild to render the newly active tab's content.
    rebuild_monitor(player)
  end
end

function M.on_lua_shortcut(event)
  if event.prototype_name == "chiptorio-network-monitor" then
    local player = game.players[event.player_index]
    if player then
      open_monitor(player)
    end
  end
end

remote.add_interface("chiptorio-network", {
  -- /c remote.call("chiptorio-network", "status")
  status = function()
    init_storage()
    M.graphs()
    for _, surface in pairs(game.surfaces) do
      local graph = scan_surface(surface)
      local nets = graph.networks or {}
      local unconn = graph.unconnected or {}
      log(string.format(
        "CHIPTORIO NETWORK surface=%d cables=%d networks=%d unconnected=%d",
        surface.index,
        graph.cable_count or 0,
        #nets,
        #unconn
      ))
    end
  end,
  topology = function()
    return storage.network.graphs or {}
  end,
  -- /c remote.call("chiptorio-network", "overlay", true)
  overlay = M.set_overlay,
})

return M
