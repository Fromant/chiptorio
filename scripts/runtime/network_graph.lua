-- Pure network topology builder.
--
-- Nothing in this file touches `game`, `storage`, or prototypes. The runtime
-- layer turns entities into plain descriptors, calls `M.build`, and stores the
-- result. Keeping the graph pure is what lets it be unit tested in the data
-- stage without a running map.
--
-- Vocabulary (DESIGN §5.2):
--   cable   1x1 node. Adjacent cables conduct.
--   switch  conductor. Merges every cable and switch within reach.
--   router  bridge. Does not conduct: it joins subnets into one network.
--   device  anything else. Attaches to the nearest conductor within reach.
--   subnet  connected component of cables and switches.
--   network connected component of subnets joined by routers.

local M = {}

-- A cable or switch reaches a device, and a switch reaches a cable, when the
-- Chebyshev distance between their tile centres is at most this many tiles.
M.REACH = 2

-- Abstract latency units, not seconds. They only exist so the monitor can show
-- that a routed network is slower than a single subnet.
M.CABLE_LATENCY = 1
M.ROUTER_LATENCY = 10

-- A single cable tile carries this much abstract bandwidth. Switches add their
-- own backplane on top; the cable is the bottleneck of a bare subnet.
M.CABLE_BANDWIDTH = 10

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

-- Factorio positions are tile centres: an entity at x = 4.5 occupies tile 4.
-- Flooring is what makes a device and the cable it sits next to land on the
-- same tile.
local function tile_of(value)
  return math.floor(value)
end

local function chebyshev(ax, ay, bx, by)
  local dx = math.abs(ax - bx)
  local dy = math.abs(ay - by)
  if dx > dy then
    return dx
  end
  return dy
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
    if root_a == root_b then
      return
    end
    if rank[root_a] < rank[root_b] then
      root_a, root_b = root_b, root_a
    end
    parent[root_b] = root_a
    if rank[root_a] == rank[root_b] then
      rank[root_a] = rank[root_a] + 1
    end
  end

  return find, union
end

-- Unique cables, ordered by discovery, keyed by tile.
local function collect_cables(cables)
  local list = {}
  local at = {}
  for _, cable in ipairs(cables) do
    local x = tile_of(cable.x)
    local y = tile_of(cable.y)
    local k = tile_key(x, y)
    if not at[k] then
      list[#list + 1] = { x = x, y = y }
      at[k] = #list
    end
  end
  return list, at
end

-- Union cables with their forward neighbours and switches with every cable and
-- switch within reach. Returns the union-find over cable and switch nodes.
local function build_conductor_union(cable_list, cable_at, switches)
  local find, union = new_union(#cable_list + #switches)

  for index, cable in ipairs(cable_list) do
    local neighbours = {
      tile_key(cable.x + 1, cable.y),
      tile_key(cable.x, cable.y + 1),
      tile_key(cable.x + 1, cable.y + 1),
      tile_key(cable.x - 1, cable.y + 1),
    }
    for _, k in ipairs(neighbours) do
      local other = cable_at[k]
      if other then
        union(index, other)
      end
    end
  end

  local switch_at = {}
  for offset, device in ipairs(switches) do
    switch_at[tile_key(tile_of(device.x), tile_of(device.y))] = #cable_list + offset
  end

  for offset, device in ipairs(switches) do
    local node = #cable_list + offset
    local sx = tile_of(device.x)
    local sy = tile_of(device.y)
    for dx = -M.REACH, M.REACH do
      for dy = -M.REACH, M.REACH do
        local k = tile_key(sx + dx, sy + dy)
        local cable = cable_at[k]
        if cable then
          union(node, cable)
        end
        local peer = switch_at[k]
        if peer and peer ~= node then
          union(node, peer)
        end
      end
    end
  end

  return find
end

-- Every subnet in a deterministic order: top-to-bottom, then left-to-right.
local function collect_groups(find, cable_list, switches)
  local groups = {}

  local function group_for(root)
    local group = groups[root]
    if not group then
      group = {
        cables = {},
        switches = {},
        key_x = math.huge,
        key_y = math.huge,
      }
      groups[root] = group
    end
    return group
  end

  local function extend_key(group, x, y)
    if y < group.key_y or (y == group.key_y and x < group.key_x) then
      group.key_x = x
      group.key_y = y
    end
  end

  for index, cable in ipairs(cable_list) do
    local group = group_for(find(index))
    group.cables[#group.cables + 1] = cable
    extend_key(group, cable.x, cable.y)
  end
  for offset, device in ipairs(switches) do
    local group = group_for(find(#cable_list + offset))
    group.switches[#group.switches + 1] = device
    extend_key(group, tile_of(device.x), tile_of(device.y))
  end

  local roots = {}
  for root in pairs(groups) do
    roots[#roots + 1] = root
  end
  table.sort(roots, function(a, b)
    local ga = groups[a]
    local gb = groups[b]
    if ga.key_y ~= gb.key_y then
      return ga.key_y < gb.key_y
    end
    if ga.key_x ~= gb.key_x then
      return ga.key_x < gb.key_x
    end
    return a < b
  end)

  return roots, groups
end

-- Nearest conductor to a point. Returns the subnet id of the closest one and
-- the sorted list of subnets at that distance. More than one id means the
-- device sits within reach of two subnets at once.
local function nearest_subnets(conductor_at, x, y)
  local best
  local ids = {}
  local seen = {}
  for dx = -M.REACH, M.REACH do
    for dy = -M.REACH, M.REACH do
      local id = conductor_at[tile_key(x + dx, y + dy)]
      if id then
        local distance = chebyshev(x, y, x + dx, y + dy)
        if not best or distance < best then
          best = distance
          ids = { id }
          seen = { [id] = true }
        elseif distance == best and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
        end
      end
    end
  end
  table.sort(ids)
  return ids[1], ids, best
end

function M.build(spec)
  spec = spec or {}
  local cable_list, cable_at = collect_cables(spec.cables or {})

  local positions = {}
  local device_by_id = {}
  for _, device in ipairs(spec.devices or {}) do
    positions[device.id] = { x = device.x, y = device.y }
    device_by_id[device.id] = device
  end

  local switches = {}
  local routers = {}
  local others = {}
  for _, device in ipairs(spec.devices or {}) do
    if device.kind == "switch" then
      switches[#switches + 1] = device
    elseif device.kind == "router" then
      routers[#routers + 1] = device
    else
      others[#others + 1] = device
    end
  end

  local find = build_conductor_union(cable_list, cable_at, switches)
  local roots, groups = collect_groups(find, cable_list, switches)

  -- 1. Turn each conductor component into a subnet.
  local subnets = {}
  local node_subnet = {}
  for id, root in ipairs(roots) do
    node_subnet[root] = id
    local group = groups[root]
    local subnet = new_stats()
    subnet.id = id
    subnet.cables = group.cables
    subnet.cable_count = #group.cables
    subnet.switches = {}
    subnet.devices = {}
    subnet.latency = #group.cables * M.CABLE_LATENCY
    subnet.x = group.key_x == math.huge and 0 or group.key_x
    subnet.y = group.key_y == math.huge and 0 or group.key_y
    for _, device in ipairs(group.switches) do
      subnet.switches[#subnet.switches + 1] = device.id
    end
    subnets[id] = subnet
  end

  -- 2. Every conductor tile can host a device.
  local conductor_at = {}
  local subnet_by_tile = {}
  for index, cable in ipairs(cable_list) do
    local id = node_subnet[find(index)]
    subnet_by_tile[tile_key(cable.x, cable.y)] = id
    conductor_at[tile_key(cable.x, cable.y)] = id
  end
  for offset, device in ipairs(switches) do
    local id = node_subnet[find(#cable_list + offset)]
    conductor_at[tile_key(tile_of(device.x), tile_of(device.y))] = id
  end

  -- 3. Switches join their subnet and contribute backplane bandwidth.
  local device_subnet = {}
  local unconnected = {}
  local contested = {}
  for offset, device in ipairs(switches) do
    local subnet_id = node_subnet[find(#cable_list + offset)]
    local subnet = subnets[subnet_id]
    accumulate(subnet, device)
    subnet.devices[#subnet.devices + 1] = device.id
    device_subnet[device.id] = subnet_id
  end

  -- 4. Ordinary devices attach to the nearest conductor.
  for _, device in ipairs(others) do
    local x = tile_of(device.x)
    local y = tile_of(device.y)
    local subnet_id, ids = nearest_subnets(conductor_at, x, y)
    if subnet_id then
      local subnet = subnets[subnet_id]
      accumulate(subnet, device)
      subnet.devices[#subnet.devices + 1] = device.id
      device_subnet[device.id] = subnet_id
      if #ids > 1 then
        contested[device.id] = ids
      end
    else
      unconnected[#unconnected + 1] = device.id
    end
  end

  -- 5. A bare cable run is the bandwidth bottleneck; switches add on top.
  for _, subnet in ipairs(subnets) do
    if subnet.cable_count > 0 then
      subnet.bandwidth = subnet.bandwidth + M.CABLE_BANDWIDTH
    end
    table.sort(subnet.devices)
    table.sort(subnet.switches)
  end

  -- 6. Routers join subnets into networks. A router only bridges the subnets
  --    whose cables or switches it can reach.
  local router_subnets = {}
  local router_by_id = {}
  for _, router in ipairs(routers) do
    router_by_id[router.id] = router
    local rx = tile_of(router.x)
    local ry = tile_of(router.y)
    local ids = {}
    local seen = {}
    for dx = -M.REACH, M.REACH do
      for dy = -M.REACH, M.REACH do
        local id = conductor_at[tile_key(rx + dx, ry + dy)]
        if id and not seen[id] then
          seen[id] = true
          ids[#ids + 1] = id
        end
      end
    end
    table.sort(ids)
    router_subnets[router.id] = ids
  end

  local subnet_find, subnet_union = new_union(#subnets)
  for _, ids in pairs(router_subnets) do
    for index = 2, #ids do
      subnet_union(ids[1], ids[index])
    end
  end

  local network_groups = {}
  for id = 1, #subnets do
    local root = subnet_find(id)
    local group = network_groups[root]
    if not group then
      group = { subnets = {}, routers = {}, min_subnet = id }
      network_groups[root] = group
    end
    group.subnets[#group.subnets + 1] = id
    if id < group.min_subnet then
      group.min_subnet = id
    end
  end
  for _, router in ipairs(routers) do
    local ids = router_subnets[router.id]
    if ids and #ids > 0 then
      local group = network_groups[subnet_find(ids[1])]
      group.routers[#group.routers + 1] = router.id
    else
      unconnected[#unconnected + 1] = router.id
    end
  end

  local network_roots = {}
  for root in pairs(network_groups) do
    network_roots[#network_roots + 1] = root
  end
  table.sort(network_roots, function(a, b)
    return network_groups[a].min_subnet < network_groups[b].min_subnet
  end)

  -- 7. Roll subnet stats into networks.
  local networks = {}
  local subnet_network = {}
  for id, root in ipairs(network_roots) do
    local group = network_groups[root]
    local network = new_stats()
    network.id = id
    network.subnets = group.subnets
    network.routers = group.routers
    network.labs = {}
    network.providers = {}
    table.sort(network.routers)
    network.router_bandwidth = nil

    for _, subnet_id in ipairs(group.subnets) do
      local subnet = subnets[subnet_id]
      subnet_network[subnet_id] = id
      for _, field in ipairs(CAPACITY_FIELDS) do
        network[field] = network[field] + subnet[field]
      end
      network.latency = network.latency + subnet.latency
    end

    for _, router_id in ipairs(network.routers) do
      local router = router_by_id[router_id]
      accumulate(network, router)
      local bandwidth = router.bandwidth or 0
      if not network.router_bandwidth or bandwidth < network.router_bandwidth then
        network.router_bandwidth = bandwidth
      end
    end
    network.latency = network.latency + #network.routers * M.ROUTER_LATENCY
    networks[id] = network
  end

  -- 8. Resolve device -> network once, so callers never walk the graph.
  local device_network = {}
  for device_id, subnet_id in pairs(device_subnet) do
    device_network[device_id] = subnet_network[subnet_id]
  end
  for _, router in ipairs(routers) do
    local ids = router_subnets[router.id]
    if ids and #ids > 0 then
      device_network[router.id] = subnet_network[ids[1]]
    end
  end

  -- 9. Keep the lab and provider lists per network, so the allocator does not
  --    have to walk every device on every tick.
  for _, device in ipairs(spec.devices or {}) do
    local network_id = device_network[device.id]
    if network_id then
      local network = networks[network_id]
      if device.kind == "lab" then
        network.labs[#network.labs + 1] = device.id
      elseif device.kind == "provider" then
        network.providers[#network.providers + 1] = device.id
      end
    end
  end
  for _, network in ipairs(networks) do
    table.sort(network.labs)
    table.sort(network.providers)
  end

  table.sort(unconnected)

  return {
    cable_count = #cable_list,
    subnets = subnets,
    networks = networks,
    subnet_by_tile = subnet_by_tile,
    device_subnet = device_subnet,
    device_network = device_network,
    positions = positions,
    devices = device_by_id,
    router_subnets = router_subnets,
    contested = contested,
    unconnected = unconnected,
  }
end

--- The input descriptor for a device id, or nil.
function M.device(graph, device_id)
  if not graph then
    return nil
  end
  return graph.devices[device_id]
end

--- Subnet id at a tile, or nil.
function M.subnet_at(graph, x, y)
  if not graph then
    return nil
  end
  return graph.subnet_by_tile[tile_key(tile_of(x), tile_of(y))]
end

--- Network id for a device id, or nil.
function M.network_for(graph, device_id)
  if not graph then
    return nil
  end
  return graph.device_network[device_id]
end

return M
