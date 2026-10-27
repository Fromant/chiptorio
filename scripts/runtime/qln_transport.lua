-- Pure QLN item-storage maths.
--
-- No `game`, no `storage`, no prototypes: the probe unit-tests this file
-- across mods. The runtime supplies plain item tables, capacities and rates.
--
-- A pool is `{ [item_name] = count }`. Capacity is a number of items, not
-- stacks. Insertions are clamped to the free capacity; removals are clamped to
-- what is actually stored. Both return the amount that changed.

local M = {}

--- Total number of stored items.
function M.used(items)
  local total = 0
  for _, count in pairs(items or {}) do
    total = total + count
  end
  return total
end

--- Storage cells contributed by a list of `{ name = ..., count = ... }`
--- modules. Entries with no known cell count are ignored.
function M.capacity(modules, cells)
  local total = 0
  for _, module in ipairs(modules or {}) do
    local per_module = (cells or {})[module.name]
    if per_module then
      total = total + per_module * (module.count or 0)
    end
  end
  return total
end

--- Free space in a pool with this capacity.
function M.free(items, capacity)
  local free = (capacity or 0) - M.used(items)
  if free < 0 then
    return 0
  end
  return free
end

--- Insert up to `count` items, clamped to the free capacity. Returns how many
--- were actually inserted.
function M.insert(items, capacity, name, count)
  if not items or not name or not count or count <= 0 then
    return 0
  end
  local free = M.free(items, capacity)
  if count > free then
    count = free
  end
  if count <= 0 then
    return 0
  end
  items[name] = (items[name] or 0) + count
  return count
end

--- Remove up to `count` items, clamped to what is stored. Returns how many
--- were actually removed and deletes a zero entry.
function M.remove(items, name, count)
  if not items or not name or not count or count <= 0 then
    return 0
  end
  local stored = items[name] or 0
  if count > stored then
    count = stored
  end
  if count <= 0 then
    return 0
  end
  local left = stored - count
  if left <= 0 then
    items[name] = nil
  else
    items[name] = left
  end
  return count
end

--- Move items between two pools. Positive `count` means source -> target.
--- Returns the amount moved.
function M.transfer(source, target, target_capacity, name, count)
  local removed = M.remove(source, name, count)
  if removed <= 0 then
    return 0
  end
  local inserted = M.insert(target, target_capacity, name, removed)
  if inserted < removed then
    M.insert(source, math.huge, name, removed - inserted)
  end
  return inserted
end

--- Merge several pools into one. The canonical pool is reused, so callers can
--- keep a stable table reference. Returns the canonical item table.
function M.merge(pools)
  local canonical = pools and pools[1] or {}
  if not canonical.items then
    canonical.items = {}
  end
  for index = 2, #(pools or {}) do
    local items = pools[index].items or {}
    for name, count in pairs(items) do
      canonical.items[name] = (canonical.items[name] or 0) + count
    end
    pools[index].items = {}
  end
  return canonical.items
end

--- Per-second item budget of a network. Nodes are intentionally capped by the
--- backplane: a large QLN on a thin cable cannot move a thousand items a
--- second. The base rate keeps a single node useful without any switch.
function M.rate(base_rate, bandwidth, per_bandwidth)
  local bonus = math.max(0, bandwidth or 0) * (per_bandwidth or 0)
  return math.max(1, math.floor((base_rate or 0) + bonus))
end

--- Split a per-second budget across several nodes, oldest first. Returns a
--- table keyed by node id. A leftover item goes to the first node, so the total
--- never exceeds the budget.
function M.share(budget, node_ids)
  local shares = {}
  local count = #(node_ids or {})
  if count == 0 then
    return shares
  end
  local each = math.floor((budget or 0) / count)
  local remainder = (budget or 0) - each * count
  for index, id in ipairs(node_ids) do
    shares[id] = each + (index <= remainder and 1 or 0)
  end
  return shares
end

--- Item names in a stable order, so transfers and GUI lists are deterministic.
function M.sorted_names(items)
  local names = {}
  for name, count in pairs(items or {}) do
    if count > 0 then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

return M
