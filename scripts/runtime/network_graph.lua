-- Pure network topology builder (physical layer).
--
-- DESIGN §5.2. Networking is a physical layer problem:
--   * Cables collide with everything; they route around machines.
--   * A machine connects only if physically adjacent to a cable/switch tile,
--     or within a router's wireless reach.
--   * Switches merge segments into one subnet; routers bridge subnets and
--     act as WiFi access points.
--   * Five cable tiers exist; a segment runs at the bandwidth of its weakest
--     link (weakest-link rule).
--
-- Nothing in this file touches `game`, `storage`, or prototypes. It receives
-- plain descriptors and returns a graph. The runtime layer turns entities
-- into descriptors and stores the result.

local M = {}

-- Cable tier table. Bandwidth and latency are abstract units.
-- Tier is used for the weakest-link rule: a segment's bandwidth is the
-- minimum of all cable tiers present in it.
local CABLE_TIERS = {
  ["network-cable"] = { tier = 1, bandwidth = 50, latency = 2 },
  ["network-coaxial-cable"] = { tier = 2, bandwidth = 200, latency = 2 },
  ["network-fiber-mm-cable"] = { tier = 3, bandwidth = 1000, latency = 1 },
  ["network-fiber-sm-cable"] = { tier = 4, bandwidth = 5000, latency = 1 },
}

-- Wireless reach of a router (tiles, Chebyshev).
local WIRELESS_REACH = 16
-- Wireless bandwidth cap (abstract units).
local WIRELESS_BANDWIDTH = 100
-- Wireless latency penalty (abstract units).
local WIRELESS_LATENCY = 10
-- Switch latency per traversal.
local SWITCH_LATENCY = 1
-- Router latency per traversal.
local ROUTER_LATENCY = 10

local CAPACITY_FIELDS = {
  "compute",
  "scalar",
  "vector",
  "tensor",
  "quantum",
  "memory",
  "bandwidth",
  "power",
  "heat",
  "cooling",
  "demand_compute",
  "demand_memory",
  "demand_bandwidth",
}

local function tile_key(x, y)
  return x .. ":" .. y
end

local function chebyshev(ax, ay, bx, by)
  local dx = math.abs(ax - bx)
  local dy = math.abs(ay - by)
  return math.max(dx, dy)
end

local function new_stats()
  local stats = { latency = 0 }
  for _, field in ipairs(CAPACITY_FIELDS) do
    stats[field] = 0
  end
  return stats
end

local function accumulate(stats, device)
  for _, field in ipairs(CAPACITY_FIELDS) do
    stats[field] = stats[field] + (device[field] or 0)
  end
end

-- ---------------------------------------------------------------------------
-- Union-find
-- ---------------------------------------------------------------------------

local function new_union(count)
  local parent = {}
  local rank = {}
  for i = 1, count do
    parent[i] = i
    rank[i] = 0
  end

  local function find(node)
    while parent[node] ~= node do
      parent[node] = parent[parent[node]]
      node = parent[node]
    end
    return node
  end

  local function union(a, b)
    local root_a = find(a)
    local root_b = find(b)
    if root_a ~= root_b then
      if rank[root_a] < rank[root_b] then
        root_a, root_b = root_b, root_a
      end
      parent[root_b] = root_a
      if rank[root_a] == rank[root_b] then
        rank[root_a] = rank[root_a] + 1
      end
    end
  end

  return find, union
end

-- ---------------------------------------------------------------------------
-- Cable segment formation
-- ---------------------------------------------------------------------------

-- Group cable tiles into raw segments by 4-way adjacency (N/S/E/W).
-- Each raw segment has: cable tiles, min tier, total latency.
-- Cable positions are floored to tile coordinates before comparison.
local function build_raw_segments(cables)
  local at = {}
  local list = {}
  for _, cable in ipairs(cables) do
    local tx = math.floor(cable.x)
    local ty = math.floor(cable.y)
    local k = tile_key(tx, ty)
    if not at[k] then
      at[k] = #list + 1
      list[#list + 1] = { x = tx, y = ty, tier = cable.tier }
    end
  end

  local n = #list
  if n == 0 then
    return {}, {}
  end

  local find, union = new_union(n)

  -- Union 4-way adjacent cables (on tile coordinates).
  for index, cable in ipairs(list) do
    local neighbours = {
      tile_key(cable.x + 1, cable.y),
      tile_key(cable.x - 1, cable.y),
      tile_key(cable.x, cable.y + 1),
      tile_key(cable.x, cable.y - 1),
    }
    for _, k in ipairs(neighbours) do
      local other = at[k]
      if other then
        union(index, other)
      end
    end
  end

  -- Group by root.
  local segments = {}
  local segment_of = {}
  for index, cable in ipairs(list) do
    local root = find(index)
    local seg = segments[root]
    if not seg then
      seg = {
        cables = {},
        min_tier = math.huge,
        total_latency = 0,
        bandwidth = 0,
        latency = 0,
      }
      segments[root] = seg
    end
    local tier_info = CABLE_TIERS[cable.tier] or CABLE_TIERS["network-cable"]
    seg.cables[#seg.cables + 1] = { x = cable.x, y = cable.y, tier = cable.tier }
    if tier_info.tier < seg.min_tier then
      seg.min_tier = tier_info.tier
    end
    seg.total_latency = seg.total_latency + tier_info.latency
    segment_of[index] = root
  end

  -- Finalize bandwidth and latency.
  for _, seg in pairs(segments) do
    local tier_info = CABLE_TIERS["network-cable"]
    for _, info in pairs(CABLE_TIERS) do
      if info.tier == seg.min_tier then
        tier_info = info
        break
      end
    end
    seg.bandwidth = tier_info.bandwidth
    seg.latency = seg.total_latency
  end

  local roots = {}
  for root in pairs(segments) do
    roots[#roots + 1] = root
  end
  table.sort(roots)

  return segments, roots
end

-- ---------------------------------------------------------------------------
-- Device occupancy tiles (for 3×2 switch/router)
-- ---------------------------------------------------------------------------

-- Return the tile coordinates occupied by a 3×2 entity at (x, y) facing
-- `direction`. Direction 0 = south (long side east-west), direction 2 = east
-- (long side north-south), etc. Factorio rotates the collision box with
-- direction; we replicate the tile coverage.
local function entity_tiles(x, y, direction)
  local cx = math.floor(x)
  local cy = math.floor(y)

  -- Base 3×2 footprint (long side east-west): 3 tiles wide, 2 tall
  local tiles = {}
  local dx, dy
  if direction == 0 or direction == 2 then
    -- Long side horizontal: 3 wide, 2 tall
    for ox = -1, 1 do
      for oy = 0, 1 do
        tiles[#tiles + 1] = { cx + ox, cy + oy }
      end
    end
  else
    -- Long side vertical: 2 wide, 3 tall
    for ox = 0, 1 do
      for oy = -1, 1 do
        tiles[#tiles + 1] = { cx + ox, cy + oy }
      end
    end
  end

  return tiles
end

-- Check if any tile of an entity occupies or is adjacent (4-way) to a cable
-- tile. Returns true if the entity is wired to the segment.
local function is_wired_to(entity_tiles_list, cable_at)
  for _, tile in ipairs(entity_tiles_list) do
    local x, y = tile[1], tile[2]
    -- Cable adjacent to any of the 4 sides of any entity tile
    if cable_at[tile_key(x + 1, y)] or cable_at[tile_key(x - 1, y)]
       or cable_at[tile_key(x, y + 1)] or cable_at[tile_key(x, y - 1)] then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Graph build
-- ---------------------------------------------------------------------------

function M.build(spec)
  spec = spec or {}

  local cables = spec.cables or {}
  local devices = spec.devices or {}

  -- Index cables by tile for fast lookup.
  local cable_at = {}
  local cable_list = {}
  for _, cable in ipairs(cables) do
    local k = tile_key(cable.x, cable.y)
    if not cable_at[k] then
      cable_at[k] = true
      cable_list[#cable_list + 1] = cable
    end
  end

  -- 1. Raw segments from cable adjacency.
  local raw_segments, raw_roots = build_raw_segments(cable_list)
  local raw_segment_of_cable = {}
  for root, seg in pairs(raw_segments) do
    for _, cable in ipairs(seg.cables) do
      raw_segment_of_cable[tile_key(cable.x, cable.y)] = root
    end
  end

  -- Map cable tile → raw segment root.
  local cable_tile_segment = {}
  for _, cable in ipairs(cable_list) do
    local tx = math.floor(cable.x)
    local ty = math.floor(cable.y)
    local root = raw_segment_of_cable[tile_key(tx, ty)]
    cable_tile_segment[tile_key(tx, ty)] = root
  end

  -- 2. Switches merge raw segments.
  local switches = {}
  local routers = {}
  local other_devices = {}
  for _, device in ipairs(devices) do
    if device.kind == "switch" then
      switches[#switches + 1] = device
    elseif device.kind == "router" then
      routers[#routers + 1] = device
    else
      other_devices[#other_devices + 1] = device
    end
  end

  -- Index raw segment roots.
  local raw_root_index = {}
  for i, root in ipairs(raw_roots) do
    raw_root_index[root] = i
  end

  local n_raw = #raw_roots
  local switch_find, switch_union = new_union(n_raw)

  -- For each switch, find all raw segments wired to it and union them.
  for _, switch in ipairs(switches) do
    local tiles = entity_tiles(switch.x, switch.y, switch.direction or 0)
    local seg_roots = {}
    for _, tile in ipairs(tiles) do
      local x, y = tile[1], tile[2]
      -- Check 4-way adjacent tiles for cables
      for _, adj in ipairs({ {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1} }) do
        local k = tile_key(adj[1], adj[2])
        local root = cable_tile_segment[k]
        if root then
          seg_roots[root] = true
        end
      end
    end
    local roots = {}
    for root in pairs(seg_roots) do
      roots[#roots + 1] = root
    end
    switch.segments = roots
    if #roots > 1 then
      for i = 2, #roots do
        switch_union(raw_root_index[roots[1]], raw_root_index[roots[i]])
      end
    end
  end

  -- 3. Build switch-merged segments: union of raw segments via switches.
  local merged_segment_of_raw = {}
  local merged_segments = {}
  for _, root in ipairs(raw_roots) do
    local mroot = switch_find(raw_root_index[root])
    if not merged_segments[mroot] then
      merged_segments[mroot] = {
        raw_roots = {},
        bandwidth = math.huge,
        latency = 0,
        switches = {},
        devices = {},
      }
    end
    merged_segments[mroot].raw_roots[#merged_segments[mroot].raw_roots + 1] = root
  end

  -- Aggregate bandwidth (min) and latency (sum) across raw segments in merged segment.
  for _, mseg in pairs(merged_segments) do
    local bw = math.huge
    local lat = 0
    for _, root in ipairs(mseg.raw_roots) do
      local seg = raw_segments[root]
      if seg then
        if seg.bandwidth < bw then bw = seg.bandwidth end
        lat = lat + seg.latency
      end
    end
    mseg.bandwidth = bw == math.huge and 0 or bw
    mseg.latency = lat
  end

  -- Index merged segments.
  local merged_roots = {}
  for mroot in pairs(merged_segments) do
    merged_roots[#merged_roots + 1] = mroot
  end
  local merged_root_index = {}
  for i, mroot in ipairs(merged_roots) do
    merged_root_index[mroot] = i
  end

  -- Record which merged segment each switch belongs to, and add switch
  -- bandwidth to the merged segment.
  for _, switch in ipairs(switches) do
    if #switch.segments > 0 then
      local mroot = switch_find(raw_root_index[switch.segments[1]])
      switch.merged_segment = mroot
      merged_segments[mroot].switches[#merged_segments[mroot].switches + 1] = switch.id
      -- Switches add backplane bandwidth to their merged segment.
      merged_segments[mroot].bandwidth = merged_segments[mroot].bandwidth + 100
    end
  end

  -- 4. Routers bridge merged segments (wired side) and provide WiFi.
  local router_find, router_union = new_union(#merged_roots)

  for _, router in ipairs(routers) do
    local tiles = entity_tiles(router.x, router.y, router.direction or 0)
    local seg_roots = {}
    for _, tile in ipairs(tiles) do
      local x, y = tile[1], tile[2]
      for _, adj in ipairs({ {x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1} }) do
        local k = tile_key(adj[1], adj[2])
        -- Find merged segment containing this cable tile
        local raw_root = cable_tile_segment[k]
        if raw_root then
          local mroot = switch_find(raw_root_index[raw_root])
          seg_roots[mroot] = true
        end
      end
    end
    local roots = {}
    for mroot in pairs(seg_roots) do
      roots[#roots + 1] = mroot
    end
    router.segments = roots
    if #roots > 1 then
      for i = 2, #roots do
        local a = merged_root_index[roots[1]]
        local b = merged_root_index[roots[i]]
        if a and b then
          router_union(a, b)
        end
      end
    end
  end

  -- 5. Build networks from router-bridged merged segments.
  local network_of_merged = {}
  local networks = {}
  for _, mroot in ipairs(merged_roots) do
    local nroot = router_find(merged_root_index[mroot])
    if not networks[nroot] then
      networks[nroot] = {
        id = nroot,
        merged_segments = {},
        routers = {},
        labs = {},
        providers = {},
        qln_nodes = {},
        compute = 0, memory = 0, bandwidth = 0, latency = 0,
        scalar = 0, vector = 0, tensor = 0, quantum = 0,
        power = 0, heat = 0, cooling = 0,
        demand_compute = 0, demand_memory = 0, demand_bandwidth = 0,
      }
    end
    network_of_merged[mroot] = nroot
    networks[nroot].merged_segments[#networks[nroot].merged_segments + 1] = mroot
  end

  -- Aggregate network stats from merged segments.
  for _, net in pairs(networks) do
    for _, mroot in ipairs(net.merged_segments) do
      local mseg = merged_segments[mroot]
      accumulate(net, mseg)
      net.latency = net.latency + mseg.latency
    end
  end

  -- Add router stats to networks and record routers per network.
  for _, router in ipairs(routers) do
    if #router.segments > 0 then
      local mroot = router.segments[1]
      local nroot = network_of_merged[mroot]
      if nroot then
        networks[nroot].routers[#networks[nroot].routers + 1] = router.id
        accumulate(networks[nroot], router)
        networks[nroot].latency = networks[nroot].latency + ROUTER_LATENCY
      end
    end
  end

  -- 6. Device attachment.
  -- A device connects to the network if:
  --   a) It is adjacent (4-way) to a cable tile belonging to a merged segment,
  --   b) OR it is within wireless reach of a router.
  -- Conflict: if a device can reach multiple different networks, it is offline.
  local device_network = {}
  local device_wired_segment = {}
  local device_wireless_router = {}
  local unconnected = {}
  local conflicts = {}

  local function device_networks(device)
    local nets = {}
    local seen = {}

    -- Wired: check 4-way adjacency to cable tiles.
    local cx = math.floor(device.x)
    local cy = math.floor(device.y)
    for _, adj in ipairs({ {cx + 1, cy}, {cx - 1, cy}, {cx, cy + 1}, {cx, cy - 1} }) do
      local k = tile_key(adj[1], adj[2])
      local raw_root = cable_tile_segment[k]
      if raw_root then
        local mroot = switch_find(raw_root_index[raw_root])
        local nroot = network_of_merged[mroot]
        if nroot and not seen[nroot] then
          seen[nroot] = true
          nets[#nets + 1] = nroot
        end
      end
    end

    -- Wireless: check routers within reach.
    for _, router in ipairs(routers) do
      if chebyshev(cx, cy, math.floor(router.x), math.floor(router.y)) <= WIRELESS_REACH then
        if #router.segments > 0 then
          local mroot = router.segments[1]
          local nroot = network_of_merged[mroot]
          if nroot and not seen[nroot] then
            seen[nroot] = true
            nets[#nets + 1] = nroot
          end
          device_wireless_router[device.id] = router.id
        end
      end
    end

    return nets
  end

  for _, device in ipairs(other_devices) do
    local nets = device_networks(device)
    if #nets == 0 then
      unconnected[#unconnected + 1] = device.id
    elseif #nets == 1 then
      device_network[device.id] = nets[1]
      local net = networks[nets[1]]
      if device.kind == "lab" then
        net.labs[#net.labs + 1] = device.id
      elseif device.kind == "provider" then
        net.providers[#net.providers + 1] = device.id
      elseif device.kind == "qln" or device.kind == "qln-drive" then
        net.qln_nodes[#net.qln_nodes + 1] = device.id
      end
      accumulate(net, device)
    else
      -- Conflict: device touches multiple networks.
      conflicts[device.id] = nets
      unconnected[#unconnected + 1] = device.id
    end
  end

  -- Register switches and routers on their networks for lookup.
  for _, switch in ipairs(switches) do
    if switch.merged_segment then
      local nroot = network_of_merged[switch.merged_segment]
      if nroot then
        device_network[switch.id] = nroot
      end
    end
  end
  for _, router in ipairs(routers) do
    if #router.segments > 0 then
      local mroot = router.segments[1]
      local nroot = network_of_merged[mroot]
      if nroot then
        device_network[router.id] = nroot
      end
    end
  end

  -- Sort lists for determinism.
  for _, net in pairs(networks) do
    table.sort(net.labs)
    table.sort(net.providers)
    table.sort(net.qln_nodes)
    table.sort(net.routers)
  end
  table.sort(unconnected)

  local network_list = {}
  for _, net in pairs(networks) do
    network_list[#network_list + 1] = net
  end
  table.sort(network_list, function(a, b) return a.id < b.id end)

  -- Index device positions by id for the runtime overlay and QLN lookups.
  local positions = {}
  local device_by_id = {}
  for _, device in ipairs(devices) do
    positions[device.id] = { x = device.x, y = device.y }
    device_by_id[device.id] = device
  end

  return {
    cable_count = #cable_list,
    raw_segments = raw_segments,
    merged_segments = merged_segments,
    networks = network_list,
    network_by_id = networks,
    device_network = device_network,
    conflicts = conflicts,
    unconnected = unconnected,
    switches = switches,
    routers = routers,
    positions = positions,
    devices = device_by_id,
  }
end

--- The network stats for a device id, or nil.
function M.device_stats(networks, device_id)
  -- Not implemented in pure form; runtime layer holds device descriptors.
  return nil
end

return M
