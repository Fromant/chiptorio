-- Working art for scripted containers. Owners report real activity; this module
-- only owns render lifetime. It registers no events and never polls the world.
local M = {}
local SUPPORTED = {
  ["metrology-lab"] = true,
  ["answer-engine"] = true,
  ["qln-storage-drive"] = true,
  ["quantum-entanglement-core"] = true,
  ["foup-dock"] = true,
  ["wireless-access-point"] = true,
  ["qln-import-node"] = true,
  ["qln-export-node"] = true,
  ["qln-provider-node"] = true,
  ["qln-requester-node"] = true,
  ["qln-terminal"] = true,
  ["training-cluster"] = true,
  ["inference-lab"] = true,
  ["network-monitor"] = true,
  ["network-switch"] = true,
  ["network-router"] = true,
  ["memory-bank"] = true,
  ["datacenter"] = true,
}
-- Only the revised facilities get deterministic per-entity phase offsets.
-- Approved terminal and earlier batches retain their exact existing behavior.
local PHASE_FRAMES = { ["network-monitor"] = 48, ["training-cluster"] = 24, ["inference-lab"] = 32,
  ["network-switch"] = 24, ["network-router"] = 24, ["memory-bank"] = 24, ["datacenter"] = 48 }

local function records()
  storage.chiptorio_device_visuals = storage.chiptorio_device_visuals or {}
  return storage.chiptorio_device_visuals
end

local function remove(all, id, record)
  if record.render and record.render.valid then record.render.destroy() end
  all[id] = nil
end

function M.set_active(entity, active)
  if not (entity and entity.valid and entity.unit_number and SUPPORTED[entity.name]) then return end
  -- Future staged art has no runtime animation until its publication.
  if not helpers.is_valid_animation_path("chiptorio-device-" .. entity.name) then return end
  local all = records()
  local id = entity.unit_number
  local record = all[id]
  if not active then
    if record then remove(all, id, record) end
    return
  end
  if not record then
    record = { entity = entity }
    all[id] = record
  end
  -- A missed report (disconnected device, no work, removed entity) returns to
  -- idle on the next dispatcher pass. Repeated reports do not restart a loop.
  record.expires = game.tick + 60
  if not (record.render and record.render.valid) then
    record.render = rendering.draw_animation({
      animation = "chiptorio-device-" .. entity.name,
      target = entity, surface = entity.surface, render_layer = "object",
      animation_speed = 0.2,
      animation_offset = PHASE_FRAMES[entity.name] and (entity.unit_number * 7) % PHASE_FRAMES[entity.name] or 0,
    })
  end
end

function M.tick()
  local all = records()
  for id, record in pairs(all) do
    if not (record.entity and record.entity.valid) or game.tick >= record.expires then
      remove(all, id, record)
    end
  end
end

function M.init()
  local all = records()
  for id, record in pairs(all) do remove(all, id, record) end
end

function M.status()
  local result = {}
  for id, record in pairs(records()) do
    if record.entity and record.entity.valid and record.render and record.render.valid then
      result[#result + 1] = { unit_number = id, name = record.entity.name,
        force_index = record.entity.force.index, expires = record.expires }
    end
  end
  table.sort(result, function(a, b) return a.unit_number < b.unit_number end)
  return result
end

return M
