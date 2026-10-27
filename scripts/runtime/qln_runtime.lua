-- Runtime: the Quantum Logistics Network.
--
-- DESIGN §9. Item storage lives on Storage Drives (a lab clone, so it exposes
-- a module inventory). A network sees every drive connected to it; Quantum
-- Entanglement Cores join two networks into one storage group. Import/Export
-- move items between the world and the group, Provider/Requester move between
-- a node buffer and the group, and the Construction Core builds and mines
-- ghosts inside its range.
--
-- The pure storage maths live in scripts/runtime/qln_transport.lua and the
-- tuning lives in scripts/qln_meta.lua. This module is the only QLN code that
-- reads entities or writes `storage`.
--
-- Event registration lives in control.lua.

local network = require("scripts.runtime.network_runtime")
local qmeta = require("scripts.qln_meta")
local transport = require("scripts.runtime.qln_transport")
local nodes = require("scripts.process_nodes")

local M = {}

local STORAGE_VERSION = 2

local IMPORT = "qln-import-node"
local EXPORT = "qln-export-node"
local PROVIDER = "qln-provider-node"
local REQUESTER = "qln-requester-node"
local TERMINAL = "qln-terminal"
local DRIVE = "qln-storage-drive"
local CONSTRUCTION = "construction-core"
local FOUP_DOCK = "foup-dock"
local QUANTUM = "quantum-entanglement-core"

local TRANSFER_NAMES = {
  [IMPORT] = true,
  [EXPORT] = true,
  [PROVIDER] = true,
  [REQUESTER] = true,
}

-- Inventories an Import Node may pull from, and an Export/Requester Node may
-- push into. Only the output side of a machine is a source and only the input
-- side is a destination, so an import node cannot steal a furnace's fuel.
--
-- 2.1 renamed the crafter inventories: `assembler_input`/`assembler_output`,
-- `furnace_source`/`furnace_result` and `miner_result` no longer exist. A
-- furnace and an assembling machine both expose `crafter_input` and
-- `crafter_output`, and a mining drill has no result inventory at all (it
-- pushes straight to a belt or the ground), so it cannot be a supply.
local SUPPLY_INVENTORIES = {
  container = { defines.inventory.chest },
  ["logistic-container"] = { defines.inventory.chest },
  furnace = { defines.inventory.crafter_output },
  ["assembling-machine"] = { defines.inventory.crafter_output },
}

local ACCEPT_INVENTORIES = {
  container = { defines.inventory.chest },
  ["logistic-container"] = { defines.inventory.chest },
  furnace = { defines.inventory.crafter_input },
  ["assembling-machine"] = { defines.inventory.crafter_input },
  lab = { defines.inventory.lab_input },
}

local QLN_NODE_NAMES = {
  [IMPORT] = true,
  [EXPORT] = true,
  [PROVIDER] = true,
  [REQUESTER] = true,
  [TERMINAL] = true,
  [DRIVE] = true,
  [CONSTRUCTION] = true,
  [QUANTUM] = true,
  -- The FOUP Dock is deliberately *not* listed. It has to be reachable by an
  -- adjacent Import/Export/Requester Node, or a sealed carrier could only be
  -- moved by hand or by belt. The transfer helpers below filter it by mode:
  -- a sealing dock accepts FOUPs and wafers and exports sealed carriers, an
  -- unsealing dock accepts sealed carriers and exports FOUPs and wafers.
}

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

local function init_storage()
  storage.qln = storage.qln or {}
  local state = storage.qln
  state.version = STORAGE_VERSION
  state.drives = state.drives or {}
  state.foup_mode = state.foup_mode or {}
  state.foup_entities = state.foup_entities or {}
  state.terminals = state.terminals or {}
  state.foup_guis = state.foup_guis or {}
  state.construction_inventory = state.construction_inventory or {}
  state.groups = state.groups or {}
end

function M.init_storage()
  init_storage()
end

local function forces()
  local list = {}
  for _, force in pairs(game.forces) do
    list[#list + 1] = force
  end
  table.sort(list, function(a, b)
    return a.index < b.index
  end)
  return list
end

local function network_key(surface_index, network_id, force_index)
  return surface_index .. ":" .. network_id .. ":" .. force_index
end

local function drive_record(entity)
  local id = entity.unit_number
  local record = storage.qln.drives[id]
  if not record then
    record = {
      items = {},
      force_index = entity.force.index,
      surface_index = entity.surface.index,
    }
    storage.qln.drives[id] = record
  end
  record.entity = entity
  return record
end

--- Storage cells installed in one drive. Only the first DRIVE_SLOTS memory
--- modules count; extra modules are stored but ignored, exactly like a
--- provider's slot limit.
local function drive_capacity(entity)
  local inventory = entity.get_module_inventory()
  if not inventory then
    return 0
  end
  local used = 0
  local cells = 0
  for _, item in ipairs(inventory.get_contents()) do
    local per_module = qmeta.DRIVE_CELLS[item.name]
    if per_module and used < qmeta.DRIVE_SLOTS then
      local count = item.count
      if count > qmeta.DRIVE_SLOTS - used then
        count = qmeta.DRIVE_SLOTS - used
      end
      used = used + count
      cells = cells + per_module * count
    end
  end
  return cells
end

local function prune_drive_records()
  for id, record in pairs(storage.qln.drives) do
    if not (record.entity and record.entity.valid) then
      storage.qln.drives[id] = nil
    end
  end
end

-- ---------------------------------------------------------------------------
-- Group storage maths
-- ---------------------------------------------------------------------------

local function group_insert(drives, name, count)
  local inserted = 0
  for _, record in ipairs(drives) do
    if inserted >= count then
      break
    end
    inserted = inserted + transport.insert(record.items, record.capacity or 0, name, count - inserted)
  end
  return inserted
end

local function group_remove(drives, name, count)
  local removed = 0
  for _, record in ipairs(drives) do
    if removed >= count then
      break
    end
    removed = removed + transport.remove(record.items, name, count - removed)
  end
  return removed
end

local function group_count(drives, name)
  local total = 0
  for _, record in ipairs(drives) do
    total = total + (record.items[name] or 0)
  end
  return total
end

local function group_items(drives)
  local items = {}
  for _, record in ipairs(drives) do
    for name, count in pairs(record.items) do
      items[name] = (items[name] or 0) + count
    end
  end
  return items
end

local function group_capacity(drives)
  local total = 0
  for _, record in ipairs(drives) do
    total = total + (record.capacity or 0)
  end
  return total
end

-- ---------------------------------------------------------------------------
-- Inventories around a node
-- ---------------------------------------------------------------------------

local function inventories_of(entity, map)
  local defs = map[entity.type]
  if not defs then
    return nil
  end
  local list = {}
  for _, definition in ipairs(defs) do
    local inventory = entity.get_inventory(definition)
    if inventory then
      list[#list + 1] = inventory
    end
  end
  if #list == 0 then
    return nil
  end
  return list
end

-- ---------------------------------------------------------------------------
-- FOUP Dock direction
-- ---------------------------------------------------------------------------

-- A dock is a normal container with a mode. A transfer node must only take its
-- products and only give it its inputs, or an Import Node would immediately
-- pull back the wafers an Export Node just delivered and the dock would never
-- fill. The same rule keeps unrelated storage items out of its ten slots.
local SEALED_PREFIX = "foup-sealed-"
local WAFER_PREFIX = "node-"
local WAFER_SUFFIX = "-wafer"

local function foup_mode(entity)
  return storage.qln.foup_mode[entity.unit_number] or "seal"
end

local function is_sealed_foup(name)
  return string.sub(name, 1, #SEALED_PREFIX) == SEALED_PREFIX
end

local function is_node_wafer(name)
  return string.sub(name, 1, #WAFER_PREFIX) == WAFER_PREFIX
    and string.sub(name, -#WAFER_SUFFIX) == WAFER_SUFFIX
end

--- Items a dock will take from the network for the current mode.
local function dock_accepts(entity, name)
  if foup_mode(entity) == "seal" then
    return name == "foup" or is_node_wafer(name)
  end
  return is_sealed_foup(name)
end

--- Items a dock offers to the network for the current mode.
local function dock_outputs(entity, name)
  if foup_mode(entity) == "seal" then
    return is_sealed_foup(name)
  end
  return name == "foup" or is_node_wafer(name)
end

--- Entities touching the node. The 3x3 box around a 1x1 node reaches every
--- directly adjacent tile; diagonal neighbours are included because an
--- inserter can also reach them.
local function adjacent_entities(node)
  local entity = node.entity
  local position = entity.position
  local area = {
    { position.x - 1.5, position.y - 1.5 },
    { position.x + 1.5, position.y + 1.5 },
  }
  local list = {}
  for _, other in ipairs(entity.surface.find_entities_filtered({ area = area })) do
    if other.valid
      and other.unit_number ~= node.id
      and not QLN_NODE_NAMES[other.name]
    then
      list[#list + 1] = other
    end
  end
  table.sort(list, function(a, b)
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  return list
end

local function collect_inventories(node, map)
  local list = {}
  for _, other in ipairs(adjacent_entities(node)) do
    for _, inventory in ipairs(inventories_of(other, map) or {}) do
      list[#list + 1] = { inventory = inventory, entity = other }
    end
  end
  return list
end

local function inventory_total(entries, name)
  local total = 0
  for _, entry in ipairs(entries) do
    if entry.entity.name ~= FOUP_DOCK or dock_accepts(entry.entity, name) then
      total = total + entry.inventory.get_item_count(name)
    end
  end
  return total
end

local function insert_into_inventories(entries, name, count)
  local inserted = 0
  for _, entry in ipairs(entries) do
    if inserted >= count then
      break
    end
    if entry.entity.name ~= FOUP_DOCK or dock_accepts(entry.entity, name) then
      inserted = inserted + entry.inventory.insert({ name = name, count = count - inserted })
    end
  end
  return inserted
end

-- ---------------------------------------------------------------------------
-- Topology snapshot and quantum grouping
-- ---------------------------------------------------------------------------

--- Collect the QLN devices of one force, keyed by surface:network:force.
--- Each device remembers its network key so a quantum core can link them.
local function collect_force(force, graphs)
  local infos = {}
  local cores = {}

  for surface_index, graph in pairs(graphs) do
    for id, device in pairs(graph.devices) do
      if device.force_index == force.index then
        local network_id = graph.device_network[id]
        if network_id then
          local key = network_key(surface_index, network_id, force.index)
          local info = infos[key]
          if not info then
            info = {
              key = key,
              surface_index = surface_index,
              network_id = network_id,
              force_index = force.index,
              network = graph.network_by_id[network_id],
              nodes = {},
              drives = {},
            }
            infos[key] = info
          end
          device.qln_network_key = key

          if device.kind == "qln-drive" then
            local record = drive_record(device.entity)
            record.capacity = drive_capacity(device.entity)
            info.drives[#info.drives + 1] = record
          elseif device.kind == "qln" then
            info.nodes[#info.nodes + 1] = device
            if device.name == QUANTUM then
              cores[#cores + 1] = device
            end
          end
        end
      end
    end
  end

  for _, info in pairs(infos) do
    table.sort(info.nodes, function(a, b)
      return a.id < b.id
    end)
    table.sort(info.drives, function(a, b)
      return a.entity.unit_number < b.entity.unit_number
    end)
  end
  table.sort(cores, function(a, b)
    return a.id < b.id
  end)

  return infos, cores
end

local function new_union(count)
  local parent = {}
  for index = 1, count do
    parent[index] = index
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
      parent[root_b] = root_a
    end
  end
  return find, union
end

--- Quantum Entanglement Cores are paired in build order. Each pair joins the
--- two networks it sits on; a chain of pairs is one group. Returns the groups
--- in deterministic key order and the network -> group map.
local function group_networks(infos, cores)
  local keys = {}
  local index = {}
  for key in pairs(infos) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  for position, key in ipairs(keys) do
    index[key] = position
  end

  local find, union = new_union(#keys)
  local pairs_possible = math.min(math.floor(#cores / 2), qmeta.QUANTUM_PAIRS)
  for pair = 1, pairs_possible do
    local first = cores[pair * 2 - 1]
    local second = cores[pair * 2]
    local first_key = first.qln_network_key
    local second_key = second.qln_network_key
    if first_key and second_key and index[first_key] and index[second_key] then
      union(index[first_key], index[second_key])
    end
  end

  local groups = {}
  for position, key in ipairs(keys) do
    local root = find(position)
    local group = groups[root]
    if not group then
      -- keys are sorted, so the first member is also the canonical key.
      group = { key = key, networks = {}, nodes = {}, drives = {} }
      groups[root] = group
    end
    local info = infos[key]
    group.networks[#group.networks + 1] = info
    for _, record in ipairs(info.drives) do
      group.drives[#group.drives + 1] = record
    end
    for _, device in ipairs(info.nodes) do
      group.nodes[#group.nodes + 1] = device
    end
  end

  local list = {}
  for _, group in pairs(groups) do
    table.sort(group.nodes, function(a, b)
      return a.id < b.id
    end)
    table.sort(group.drives, function(a, b)
      return a.entity.unit_number < b.entity.unit_number
    end)
    -- A quantum link is not free capacity: the group can only move as fast as
    -- the thinnest network in it. A single network keeps its own bandwidth.
    local bandwidth = nil
    for _, info in ipairs(group.networks) do
      local value = (info.network and info.network.bandwidth) or 0
      if not bandwidth or value < bandwidth then
        bandwidth = value
      end
    end
    group.bandwidth = bandwidth or 0
    group.capacity = group_capacity(group.drives)
    list[#list + 1] = group
  end
  table.sort(list, function(a, b)
    return a.key < b.key
  end)

  return list
end

local function store_groups(force, infos, groups)
  local by_network = {}
  local drives = {}
  local capacity = {}
  local node_count = {}
  for _, group in ipairs(groups) do
    for _, info in ipairs(group.networks) do
      by_network[info.key] = group.key
    end
    local ids = {}
    for _, record in ipairs(group.drives) do
      ids[#ids + 1] = record.entity.unit_number
    end
    drives[group.key] = ids
    capacity[group.key] = group.capacity
    node_count[group.key] = #group.nodes
  end
  for key in pairs(infos) do
    if not by_network[key] then
      by_network[key] = key
    end
  end
  storage.qln.groups[force.index] = {
    by_network = by_network,
    drives = drives,
    capacity = capacity,
    nodes = node_count,
  }
end

local function drives_for_group(force, group_key)
  local groups = storage.qln.groups[force.index]
  if not groups or not group_key then
    return nil, 0
  end
  local list = {}
  for _, id in ipairs(groups.drives[group_key] or {}) do
    local record = storage.qln.drives[id]
    if record then
      list[#list + 1] = record
    end
  end
  return list, groups.capacity[group_key] or 0
end

--- Resolve the storage group behind a QLN entity. Used by the terminal and by
--- the remote debug interface.
local function group_for_entity(entity, force)
  if not (entity and entity.valid) then
    return nil, nil
  end
  local graph = network.graph_for(entity.surface)
  local network_id = graph.device_network[entity.unit_number]
  if not network_id then
    return nil, nil
  end
  local key = network_key(entity.surface.index, network_id, force.index)
  local groups = storage.qln.groups[force.index]
  if not groups then
    return nil, nil
  end
  local group_key = groups.by_network[key]
  if not group_key then
    return nil, nil
  end
  return drives_for_group(force, group_key)
end

-- ---------------------------------------------------------------------------
-- Transport nodes
-- ---------------------------------------------------------------------------

local function import_node(node, drives, count)
  local remaining = count
  for _, other in ipairs(adjacent_entities(node)) do
    local inventories = inventories_of(other, SUPPLY_INVENTORIES)
    if inventories then
      for _, inventory in ipairs(inventories) do
        local contents = inventory.get_contents()
        table.sort(contents, function(a, b)
          return a.name < b.name
        end)
        for _, stack in ipairs(contents) do
          if remaining <= 0 then
            return
          end
          if other.name ~= FOUP_DOCK or dock_outputs(other, stack.name) then
            local moved = group_insert(drives, stack.name, math.min(stack.count, remaining))
            if moved > 0 then
              inventory.remove({ name = stack.name, count = moved })
              remaining = remaining - moved
            end
          end
        end
      end
    end
  end
end

local function provider_node(node, drives, count)
  local inventory = node.entity.get_inventory(defines.inventory.chest)
  if not inventory then
    return
  end
  local contents = inventory.get_contents()
  table.sort(contents, function(a, b)
    return a.name < b.name
  end)
  local remaining = count
  for _, stack in ipairs(contents) do
    if remaining <= 0 then
      return
    end
    local moved = group_insert(drives, stack.name, math.min(stack.count, remaining))
    if moved > 0 then
      inventory.remove({ name = stack.name, count = moved })
      remaining = remaining - moved
    end
  end
end

local function export_node(node, drives, count)
  local inventories = collect_inventories(node, ACCEPT_INVENTORIES)
  if #inventories == 0 then
    return
  end
  local remaining = count
  for _, name in ipairs(transport.sorted_names(group_items(drives))) do
    if remaining <= 0 then
      return
    end
    local have = group_count(drives, name)
    if have > 0 then
      local removed = group_remove(drives, name, math.min(have, remaining))
      local inserted = insert_into_inventories(inventories, name, removed)
      if inserted < removed then
        group_insert(drives, name, removed - inserted)
      end
      remaining = remaining - inserted
    end
  end
end

local function requester_node(node, drives, count)
  local filter = node.entity.get_inventory(defines.inventory.chest)
  if not filter then
    return
  end
  local contents = filter.get_contents()
  local name = contents[1] and contents[1].name
  if not name then
    return
  end
  local inventories = collect_inventories(node, ACCEPT_INVENTORIES)
  if #inventories == 0 then
    return
  end
  local wanted = qmeta.REQUESTER_TARGET - inventory_total(inventories, name)
  if wanted <= 0 then
    return
  end
  wanted = math.min(wanted, count, group_count(drives, name))
  if wanted <= 0 then
    return
  end
  local removed = group_remove(drives, name, wanted)
  local inserted = insert_into_inventories(inventories, name, removed)
  if inserted < removed then
    group_insert(drives, name, removed - inserted)
  end
end

local function base_rate(name)
  if name == PROVIDER then
    return qmeta.PROVIDER_RATE
  end
  return qmeta.NODE_RATE
end

local function process_transfer_nodes(group)
  local active = {}
  for _, node in ipairs(group.nodes) do
    if TRANSFER_NAMES[node.name] then
      active[#active + 1] = node
    end
  end
  if #active == 0 or #group.drives == 0 then
    return
  end

  local ids = {}
  for _, node in ipairs(active) do
    ids[#ids + 1] = node.id
  end
  local budget = transport.rate(0, group.bandwidth, qmeta.BANDWIDTH_ITEMS_PER_UNIT)
  local shares = transport.share(budget, ids)

  for _, node in ipairs(active) do
    local count = math.min(base_rate(node.name), shares[node.id] or 0)
    if count > 0 then
      if node.name == IMPORT then
        import_node(node, group.drives, count)
      elseif node.name == PROVIDER then
        provider_node(node, group.drives, count)
      elseif node.name == EXPORT then
        export_node(node, group.drives, count)
      elseif node.name == REQUESTER then
        requester_node(node, group.drives, count)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Construction Core
-- ---------------------------------------------------------------------------

local function construction_inventory(force)
  local inventory = storage.qln.construction_inventory[force.index]
  if inventory and inventory.valid then
    return inventory
  end
  local ok, created = pcall(function()
    return game.create_inventory(32)
  end)
  if not ok or not created then
    return nil
  end
  storage.qln.construction_inventory[force.index] = created
  return created
end

local function ghost_cost(ghost)
  local prototype = ghost.ghost_prototype
  local items = prototype and prototype.items_to_place_this
  if not items or #items == 0 then
    return nil
  end
  local cost = {}
  for _, stack in ipairs(items) do
    local name = stack.name or stack[1]
    local count = stack.count or stack[2]
    if name and count then
      cost[name] = (cost[name] or 0) + count
    end
  end
  return cost
end

local function can_pay(drives, cost)
  for name, count in pairs(cost) do
    if group_count(drives, name) < count then
      return false
    end
  end
  return true
end

local function build_ghost(ghost, force, drives)
  local cost = ghost_cost(ghost)
  if not cost then
    return false
  end
  if not can_pay(drives, cost) then
    return false
  end
  for name, count in pairs(cost) do
    group_remove(drives, name, count)
  end

  -- `revive` can return an overflow item array and the entity, and the order
  -- has changed between Factorio versions. Pick the valid entity out of the
  -- returns instead of trusting one position. `raise_revive` matters: it is
  -- what raises script_raised_revive, so the network indexes the new entity.
  local ok, revived = pcall(function()
    local values = { ghost.revive({ raise_revive = true }) }
    for _, value in ipairs(values) do
      if value and value.valid and value.name then
        return value
      end
    end
    return nil
  end)
  local built = ok and revived ~= nil
  if not built then
    -- Older ghosts and entities that revive() cannot handle fall back to a
    -- direct create. The ghost is removed only after the entity exists.
    local created = nil
    local created_ok = pcall(function()
      created = ghost.surface.create_entity({
        name = ghost.ghost_name,
        position = ghost.position,
        direction = ghost.direction,
        force = force,
        raise_built = true,
      })
      if created and ghost.valid then
        ghost.destroy()
      end
    end)
    built = created_ok and created ~= nil
  end

  if not built then
    for name, count in pairs(cost) do
      group_insert(drives, name, count)
    end
    return false
  end
  return true
end

local function mine_entity(target, force, drives)
  local inventory = construction_inventory(force)
  if not inventory then
    return false
  end
  -- 2.1 changed `force` on LuaEntity.mine to a boolean ("force mine if the items
  -- do not fit"). The owning force is implicit, so pass only the inventory.
  -- `mine` returns false when the inventory cannot hold the result, and the
  -- core must not spend energy on a failed mine.
  local mined = false
  local ok = pcall(function()
    mined = target.mine({ inventory = inventory })
  end)
  if not ok or not mined then
    return false
  end
  for _, stack in ipairs(inventory.get_contents()) do
    local moved = group_insert(drives, stack.name, stack.count)
    if moved > 0 then
      inventory.remove({ name = stack.name, count = moved })
    end
  end
  return true
end

local function construction_area(entity)
  local position = entity.position
  local range = qmeta.CONSTRUCTION_RANGE
  return {
    { position.x - range, position.y - range },
    { position.x + range, position.y + range },
  }
end

local function process_construction(node, force, drives)
  local entity = node.entity
  if not (entity and entity.valid) then
    return
  end
  local energy = entity.energy or 0
  if energy <= 0 or #drives == 0 then
    return
  end
  local surface = entity.surface
  local area = construction_area(entity)
  local work = 0

  -- Deconstruct first: clearing a tile makes room for the build pass.
  local marked = {}
  for _, target in ipairs(surface.find_entities_filtered({ area = area, force = force })) do
    if target.valid
      and target.unit_number ~= entity.unit_number
      and target.to_be_deconstructed(force)
    then
      marked[#marked + 1] = target
    end
  end
  table.sort(marked, function(a, b)
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)

  for _, target in ipairs(marked) do
    if work >= qmeta.CONSTRUCTION_BATCH or energy <= 0 then
      break
    end
    if target.valid and mine_entity(target, force, drives) then
      energy = math.max(0, energy - qmeta.CONSTRUCTION_ENERGY)
      work = work + 1
    end
  end

  local ghosts = surface.find_entities_filtered({ area = area, force = force, type = "entity-ghost" })

  table.sort(ghosts, function(a, b)
    return (a.unit_number or 0) < (b.unit_number or 0)
  end)
  for _, ghost in ipairs(ghosts) do
    if work >= qmeta.CONSTRUCTION_BATCH or energy <= 0 then
      break
    end
    if ghost.valid and build_ghost(ghost, force, drives) then
      energy = math.max(0, energy - qmeta.CONSTRUCTION_ENERGY)
      work = work + 1
    end
  end

  entity.energy = energy
end

-- ---------------------------------------------------------------------------
-- FOUP Dock
-- ---------------------------------------------------------------------------

--- Track a dock so the 60-tick dispatcher reaches it even when it is not on a
--- network. Sealing is a local operation; a dock between two separate fabs is
--- useful precisely because those fabs share no cables.
local function register_foup(entity)
  storage.qln.foup_entities[entity.unit_number] = entity
end

local function set_foup_mode(entity, mode)
  storage.qln.foup_mode[entity.unit_number] = mode
  register_foup(entity)
end

local function seal_foup(inventory)
  if inventory.get_item_count("foup") < 1 then
    return false
  end
  for _, node in ipairs(nodes.NODES) do
    local wafer = "node-" .. node.key .. "-wafer"
    if inventory.get_item_count(wafer) >= qmeta.FOUP_BATCH then
      local sealed = "foup-sealed-" .. node.key
      inventory.remove({ name = "foup", count = 1 })
      inventory.remove({ name = wafer, count = qmeta.FOUP_BATCH })
      if inventory.insert({ name = sealed, count = 1 }) == 1 then
        return true
      end
      inventory.insert({ name = "foup", count = 1 })
      inventory.insert({ name = wafer, count = qmeta.FOUP_BATCH })
      return false
    end
  end
  return false
end

local function unseal_foup(inventory)
  for _, node in ipairs(nodes.NODES) do
    local sealed = "foup-sealed-" .. node.key
    if inventory.get_item_count(sealed) >= 1 then
      inventory.remove({ name = sealed, count = 1 })
      if inventory.insert({ name = "foup", count = 1 }) ~= 1 then
        inventory.insert({ name = sealed, count = 1 })
        return false
      end
      local wafer = "node-" .. node.key .. "-wafer"
      if inventory.insert({ name = wafer, count = qmeta.FOUP_BATCH }) ~= qmeta.FOUP_BATCH then
        inventory.remove({ name = "foup", count = 1 })
        inventory.insert({ name = sealed, count = 1 })
        return false
      end
      return true
    end
  end
  return false
end

local function process_foup(entity)
  if not (entity and entity.valid) then
    return
  end
  local inventory = entity.get_inventory(defines.inventory.chest)
  if not inventory then
    return
  end
  if foup_mode(entity) == "seal" then
    seal_foup(inventory)
  else
    unseal_foup(inventory)
  end
end

local function prune_foup_modes()
  for id, entity in pairs(storage.qln.foup_entities) do
    if not (entity and entity.valid) then
      storage.qln.foup_entities[id] = nil
      storage.qln.foup_mode[id] = nil
    end
  end
end

--- Register the docks already on the map. A save created before build events
--- tracked the dock, or a dock placed by another mod's script, would otherwise
--- never be processed.
local function scan_foup_docks()
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({ name = FOUP_DOCK })) do
      if entity.valid then
        register_foup(entity)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Terminal GUI
-- ---------------------------------------------------------------------------

local TERMINAL_GUI = "chiptorio-qln-terminal"
local TAKE_PREFIX = TERMINAL_GUI .. "-take:"

local function terminal_state(player)
  return storage.qln.terminals[player.index]
end

local function close_terminal(player)
  local frame = player.gui.screen[TERMINAL_GUI]
  if frame and frame.valid then
    frame.destroy()
  end
  storage.qln.terminals[player.index] = nil
end

local function item_caption(name)
  local prototype = prototypes.item[name]
  if prototype and prototype.localised_name then
    return prototype.localised_name
  end
  return { "item-name." .. name }
end

local function add_item_row(body, name, count)
  local row = body.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"

  local button = row.add({
    type = "sprite-button",
    name = TAKE_PREFIX .. name,
    sprite = "item/" .. name,
    tooltip = { "chiptorio.qln-withdraw" },
  })
  button.style.minimal_width = 36
  button.style.minimal_height = 36

  local label = row.add({ type = "label", caption = item_caption(name) })
  label.style.minimal_width = 220

  row.add({ type = "label", caption = tostring(count) })
end

local function rebuild_terminal(player)
  local state = terminal_state(player)
  if not state then
    return
  end
  local frame = player.gui.screen[TERMINAL_GUI]
  if not (frame and frame.valid) then
    return
  end
  local body = frame[TERMINAL_GUI .. "-body"]
  if not (body and body.valid) then
    return
  end
  body.clear()

  local entity = state.entity
  if not (entity and entity.valid) then
    close_terminal(player)
    return
  end

  local drives, capacity = group_for_entity(entity, player.force)
  if not drives then
    body.add({ type = "label", caption = { "chiptorio.qln-no-network" } })
    return
  end

  local items = group_items(drives)
  local used = transport.used(items)
  local header = body.add({
    type = "label",
    caption = {
      "chiptorio.qln-capacity",
      math.floor(used),
      math.floor(capacity),
    },
  })
  header.style.font = "default-bold"

  local filter = string.lower(state.filter or "")
  local shown = 0
  for _, name in ipairs(transport.sorted_names(items)) do
    if filter == "" or string.find(string.lower(name), filter, 1, true) then
      add_item_row(body, name, items[name])
      shown = shown + 1
    end
  end
  if shown == 0 then
    body.add({ type = "label", caption = { "chiptorio.qln-empty" } })
  end
end

local function open_terminal(player, entity)
  close_terminal(player)
  storage.qln.terminals[player.index] = { entity = entity, filter = "" }

  local frame = player.gui.screen.add({
    type = "frame",
    name = TERMINAL_GUI,
    direction = "vertical",
    caption = { "chiptorio.qln-terminal-title" },
  })
  frame.auto_center = true

  local toolbar = frame.add({ type = "flow", direction = "horizontal" })
  toolbar.style.vertical_align = "center"
  local search = toolbar.add({
    type = "textfield",
    name = TERMINAL_GUI .. "-search",
    text = "",
  })
  search.style.minimal_width = 180
  toolbar.add({
    type = "button",
    name = TERMINAL_GUI .. "-deposit",
    caption = { "chiptorio.qln-deposit" },
  })
  toolbar.add({
    type = "button",
    name = TERMINAL_GUI .. "-close",
    caption = { "chiptorio.qln-close" },
  })

  local scroll = frame.add({
    type = "scroll-pane",
    name = TERMINAL_GUI .. "-body",
    direction = "vertical",
  })
  scroll.style.maximal_height = 460
  scroll.style.minimal_width = 360

  -- Opening an entity GUI happens before we can react, so the vanilla window
  -- is already on screen. Claiming `player.opened` asks that GUI to close and
  -- makes our frame the thing Esc closes; without it the entity window stays
  -- underneath and Esc closes the wrong GUI.
  player.opened = frame
  frame.bring_to_front()

  rebuild_terminal(player)
end

local function terminal_deposit(player, entity)
  local drives = group_for_entity(entity, player.force)
  if not drives then
    return
  end
  local inventory = player.get_inventory(defines.inventory.character_main)
  if not inventory then
    return
  end
  local contents = inventory.get_contents()
  table.sort(contents, function(a, b)
    return a.name < b.name
  end)
  for _, stack in ipairs(contents) do
    local moved = group_insert(drives, stack.name, stack.count)
    if moved > 0 then
      inventory.remove({ name = stack.name, count = moved })
    end
  end
end

local function terminal_withdraw(player, entity, name)
  local drives = group_for_entity(entity, player.force)
  if not drives then
    return
  end
  local prototype = prototypes.item[name]
  local stack_size = prototype and prototype.stack_size or 50
  local removed = group_remove(drives, name, math.min(stack_size, group_count(drives, name)))
  if removed <= 0 then
    return
  end
  local inserted = player.insert({ name = name, count = removed })
  if inserted < removed then
    group_insert(drives, name, removed - inserted)
  end
end

-- ---------------------------------------------------------------------------
-- FOUP Dock GUI
-- ---------------------------------------------------------------------------

local FOUP_GUI = "chiptorio-qln-foup"

local function close_foup_gui(player)
  local frame = player.gui.relative[FOUP_GUI]
  if frame and frame.valid then
    frame.destroy()
  end
  storage.qln.foup_guis[player.index] = nil
end

local function rebuild_foup_gui(player)
  local entity = storage.qln.foup_guis[player.index]
  if not (entity and entity.valid) then
    close_foup_gui(player)
    return
  end
  local frame = player.gui.relative[FOUP_GUI]
  if not (frame and frame.valid) then
    return
  end
  local body = frame[FOUP_GUI .. "-body"]
  if not (body and body.valid) then
    return
  end
  body.clear()
  local mode = foup_mode(entity)
  body.add({
    type = "label",
    caption = {
      mode == "seal" and "chiptorio.qln-foup-mode-seal" or "chiptorio.qln-foup-mode-unseal",
    },
  })
  body.add({
    type = "label",
    caption = { "chiptorio.qln-foup-hint", qmeta.FOUP_BATCH },
  })
  body.add({
    type = "button",
    name = FOUP_GUI .. "-toggle",
    caption = { mode == "seal" and "chiptorio.qln-foup-switch-unseal" or "chiptorio.qln-foup-switch-seal" },
  })
end

local function open_foup_gui(player, entity)
  close_foup_gui(player)
  storage.qln.foup_guis[player.index] = entity
  register_foup(entity)

  -- The dock is a real container: the player has to be able to put wafers and
  -- empty carriers into it. A screen frame would hide the inventory slots, so
  -- the mode switch is a relative panel next to the vanilla container window
  -- instead of replacing it.
  local frame = player.gui.relative.add({
    type = "frame",
    name = FOUP_GUI,
    direction = "vertical",
    caption = { "chiptorio.qln-foup-title" },
    anchor = {
      gui = defines.relative_gui_type.item_with_inventory_gui,
      position = defines.relative_gui_position.right,
      name = FOUP_DOCK,
    },
  })

  local body = frame.add({ type = "flow", name = FOUP_GUI .. "-body", direction = "vertical" })
  body.style.minimal_width = 240
  frame.add({
    type = "button",
    name = FOUP_GUI .. "-close",
    caption = { "chiptorio.qln-close" },
  })

  rebuild_foup_gui(player)
end

-- ---------------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------------

--- Keep an open Terminal live. The body is rebuilt by clicks and by the text
--- field, but storage also changes under it while Import/Export Nodes work.
--- Once a second is enough and matches the network monitor; the search field
--- lives in the toolbar, so rebuilding the body does not steal focus.
local function refresh_open_terminals()
  for index in pairs(storage.qln.terminals) do
    local player = game.players[index]
    local frame = player and player.gui.screen[TERMINAL_GUI]
    if player and player.valid and frame and frame.valid then
      rebuild_terminal(player)
    else
      storage.qln.terminals[index] = nil
    end
  end
end

local function prune_foup_guis()
  for index, entity in pairs(storage.qln.foup_guis) do
    if not (entity and entity.valid) then
      local player = game.players[index]
      if player and player.valid then
        close_foup_gui(player)
      else
        storage.qln.foup_guis[index] = nil
      end
    end
  end
end

function M.tick()
  init_storage()
  prune_drive_records()
  prune_foup_modes()

  local graphs = network.graphs()
  for _, force in ipairs(forces()) do
    local infos, cores = collect_force(force, graphs)
    local groups = group_networks(infos, cores)
    store_groups(force, infos, groups)

    for _, group in ipairs(groups) do
      process_transfer_nodes(group)
      for _, node in ipairs(group.nodes) do
        if node.name == CONSTRUCTION then
          process_construction(node, force, group.drives)
        end
      end
    end
  end

  -- FOUP Docks are not driven through the graph: sealing is a local operation,
  -- and a dock between two fabs that share no cable must still work. The
  -- registry is filled on build, on GUI open and by the init scan.
  for id, entity in pairs(storage.qln.foup_entities) do
    if entity and entity.valid then
      process_foup(entity)
    else
      storage.qln.foup_entities[id] = nil
      storage.qln.foup_mode[id] = nil
    end
  end

  refresh_open_terminals()
  prune_foup_guis()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

function M.on_init()
  init_storage()
  scan_foup_docks()
end

function M.on_configuration_changed()
  init_storage()
  scan_foup_docks()
end

--- Build hook, wired from control.lua next to network.on_built. Only the FOUP
--- Dock needs it: every other QLN entity is reached through the network graph.
function M.on_built(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == FOUP_DOCK then
    init_storage()
    register_foup(entity)
  end
end

function M.on_removed(event)
  init_storage()
  local entity = event.entity
  if entity and entity.unit_number then
    storage.qln.foup_mode[entity.unit_number] = nil
    storage.qln.foup_entities[entity.unit_number] = nil
  end
end

function M.on_gui_opened(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  init_storage()
  -- A screen frame is not closed by the game when another entity is opened,
  -- and a relative panel belongs to the previous entity's window. Always drop
  -- both, then rebuild only the window being opened. This also means opening a
  -- FOUP Dock no longer leaves an open QLN Terminal floating underneath it.
  close_terminal(player)
  close_foup_gui(player)
  if entity.name == TERMINAL then
    open_terminal(player, entity)
  elseif entity.name == FOUP_DOCK then
    open_foup_gui(player, entity)
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
    if element.name == TERMINAL_GUI then
      close_terminal(player)
    elseif element.name == FOUP_GUI then
      close_foup_gui(player)
    end
    return
  end
  -- `player.opened = frame` closes the vanilla entity GUI, which arrives here
  -- as an entity close with no element. Do not treat that as the player
  -- dismissing the terminal frame. The FOUP panel is relative to its entity,
  -- so an entity close is exactly how it disappears.
  local entity = event.entity
  if entity and entity.valid and entity.name == FOUP_DOCK then
    close_foup_gui(player)
  end
end

function M.on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not (player and element and element.valid) then
    return
  end
  init_storage()

  local state = terminal_state(player)
  if state and element.name:sub(1, #TERMINAL_GUI) == TERMINAL_GUI then
    if element.name == TERMINAL_GUI .. "-close" then
      close_terminal(player)
    elseif element.name == TERMINAL_GUI .. "-deposit" then
      terminal_deposit(player, state.entity)
      rebuild_terminal(player)
    elseif element.name:sub(1, #TAKE_PREFIX) == TAKE_PREFIX then
      local name = element.name:sub(#TAKE_PREFIX + 1)
      terminal_withdraw(player, state.entity, name)
      rebuild_terminal(player)
    end
    return
  end

  if storage.qln.foup_guis[player.index] then
    if element.name == FOUP_GUI .. "-toggle" then
      local entity = storage.qln.foup_guis[player.index]
      if entity and entity.valid then
        set_foup_mode(entity, foup_mode(entity) == "seal" and "unseal" or "seal")
        rebuild_foup_gui(player)
      end
    elseif element.name == FOUP_GUI .. "-close" then
      close_foup_gui(player)
      -- The panel is relative to the dock's container window, so closing it
      -- alone would leave the vanilla window open. Close the entity GUI too.
      player.opened = nil
    end
  end
end

function M.on_gui_text_changed(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not (player and element and element.valid) then
    return
  end
  local state = terminal_state(player)
  if state and element.name == TERMINAL_GUI .. "-search" then
    state.filter = event.text or ""
    rebuild_terminal(player)
  end
end

-- ---------------------------------------------------------------------------
-- Remote interface
-- ---------------------------------------------------------------------------

local function groups_summary(force)
  local groups = storage.qln.groups[force.index] or { drives = {}, capacity = {}, nodes = {} }
  local summary = {}
  for group_key, drive_ids in pairs(groups.drives) do
    local node_count = (groups.nodes and groups.nodes[group_key]) or 0
    -- store_groups records every network, including ordinary research
    -- networks with no QLN parts. They are not storage groups, so listing
    -- them would fill the monitor with empty rows.
    if #drive_ids > 0 or node_count > 0 then
      local drives = drives_for_group(force, group_key) or {}
      local items = group_items(drives)
      summary[#summary + 1] = {
        key = group_key,
        drives = #drive_ids,
        nodes = node_count,
        capacity = groups.capacity[group_key] or 0,
        used = transport.used(items),
        items = items,
      }
    end
  end
  table.sort(summary, function(a, b)
    return a.key < b.key
  end)
  return summary
end

--- Monitor section callback. network_runtime registers it the same way as the
--- qualification section, so this module can show storage without a cycle.
function M.monitor_section(player, body)
  init_storage()
  local summary = groups_summary(player.force)
  body.add({ type = "line" })
  local title = body.add({ type = "label", caption = { "chiptorio.qln-monitor-title" } })
  title.style.font = "default-bold"
  if #summary == 0 then
    body.add({ type = "label", caption = { "chiptorio.qln-monitor-empty" } })
    return
  end
  for _, group in ipairs(summary) do
    local row = body.add({ type = "flow", direction = "horizontal" })
    row.style.vertical_align = "center"
    local label = row.add({
      type = "label",
      caption = {
        "chiptorio.qln-monitor-group",
        group.key,
        group.drives,
        group.nodes,
        math.floor(group.used),
        math.floor(group.capacity),
      },
    })
    label.style.font_color = group.used < group.capacity and { r = 0.55, g = 1.0, b = 0.55 }
      or { r = 1.0, g = 0.82, b = 0.3 }
  end
end

network.set_qln_provider(M.monitor_section)

function M.state(force_name)
  init_storage()
  local force = game.forces[force_name or "player"]
  if not force then
    return {}
  end
  return groups_summary(force)
end

function M.status()
  init_storage()
  for _, force in ipairs(forces()) do
    for _, group in ipairs(groups_summary(force)) do
      log(string.format(
        "CHIPTORIO QLN force=%s group=%s drives=%d used=%d/%d nodes=%d",
        force.name,
        group.key,
        group.drives,
        math.floor(group.used),
        math.floor(group.capacity),
        group.nodes
      ))
    end
  end
end

--- Debug helper: put an item into a group without placing a node.
function M.debug_deposit(force_name, surface_index, network_id, name, count)
  init_storage()
  local force = game.forces[force_name or "player"]
  if not force then
    return 0
  end
  local key = network_key(surface_index or 1, network_id or 1, force.index)
  local groups = storage.qln.groups[force.index]
  local group_key = groups and groups.by_network[key]
  if not group_key then
    return 0
  end
  local drives = drives_for_group(force, group_key)
  if not drives then
    return 0
  end
  return group_insert(drives, name, count or 1)
end

--- Debug helper: pull an item out of a group.
function M.debug_withdraw(force_name, surface_index, network_id, name, count)
  init_storage()
  local force = game.forces[force_name or "player"]
  if not force then
    return 0
  end
  local key = network_key(surface_index or 1, network_id or 1, force.index)
  local groups = storage.qln.groups[force.index]
  local group_key = groups and groups.by_network[key]
  if not group_key then
    return 0
  end
  local drives = drives_for_group(force, group_key)
  if not drives then
    return 0
  end
  return group_remove(drives, name, count or 1)
end

--- Current contents and capacity of the storage group behind a QLN entity.
--- Used by the Answer Engine GUI and by the endgame item check.
function M.group_status(entity)
  if not (entity and entity.valid) then
    return nil
  end
  local drives, capacity = group_for_entity(entity, entity.force)
  if not drives then
    return nil
  end
  local items = group_items(drives)
  return {
    items = items,
    used = transport.used(items),
    capacity = capacity,
  }
end

--- Atomically withdraw a list of `{ item = name, count = n }` from the group
--- behind a QLN entity. Returns false and the missing list if any line is short,
--- so the caller can pause without consuming half a batch.
function M.consume(entity, requirements)
  if not (entity and entity.valid) then
    return false, {}
  end
  local drives = group_for_entity(entity, entity.force)
  if not drives then
    local missing = {}
    for _, req in ipairs(requirements or {}) do
      missing[#missing + 1] = { item = req.item, need = req.count, have = 0 }
    end
    return false, missing
  end

  local missing = {}
  for _, req in ipairs(requirements or {}) do
    local have = group_count(drives, req.item)
    if have < req.count then
      missing[#missing + 1] = { item = req.item, need = req.count, have = have }
    end
  end
  if #missing > 0 then
    return false, missing
  end

  for _, req in ipairs(requirements) do
    group_remove(drives, req.item, req.count)
  end
  return true, {}
end

--- Deposit `count` of `name` into the QLN group behind `entity`. Returns the
--- number actually deposited.
function M.deposit(entity, name, count)
  if not (entity and entity.valid) then
    return 0
  end
  init_storage()
  local graph = network.graph_for(entity.surface)
  if not graph then
    return 0
  end
  local network_id = graph.device_network and graph.device_network[entity.unit_number]
  if not network_id then
    return 0
  end
  local key = network_key(entity.surface.index, network_id, entity.force.index)
  local groups = storage.qln.groups[entity.force.index]
  local group_key = groups and groups.by_network[key]
  if not group_key then
    return 0
  end
  local drives = drives_for_group(entity.force, group_key)
  if not drives then
    return 0
  end
  return group_insert(drives, name, count or 1)
end

remote.add_interface("chiptorio-qln", {
  -- /c remote.call("chiptorio-qln", "status")
  status = M.status,
  -- /c remote.call("chiptorio-qln", "state", "player")
  state = M.state,
  -- /c remote.call("chiptorio-qln", "deposit", "player", 1, 1, "iron-plate", 10)
  deposit = M.debug_deposit,
  -- /c remote.call("chiptorio-qln", "withdraw", "player", 1, 1, "iron-plate", 10)
  withdraw = M.debug_withdraw,
  -- /c remote.call("chiptorio-qln", "step", 5)
  -- Test/debug helper: advance the transport without waiting for the tick.
  step = function(seconds)
    local count = math.max(0, math.floor(seconds or 1))
    for _ = 1, count do
      M.tick()
    end
    return count
  end,
  -- /c remote.call("chiptorio-qln", "set_foup_mode", entity, "unseal")
  -- Test/debug helper: flip a FOUP Dock without clicking its window.
  set_foup_mode = function(entity, mode)
    if not (entity and entity.valid and entity.name == FOUP_DOCK) then
      return false
    end
    set_foup_mode(entity, mode == "unseal" and "unseal" or "seal")
    return true
  end,
})

return M
