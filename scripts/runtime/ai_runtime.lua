-- Runtime: Training Cluster and Inference Lab.
--
-- DESIGN §20.8. The Training Cluster reserves network compute and draws data
-- from QLN storage to produce Model items. The Inference Lab installs a Model
-- and draws compute + data to grant insight (reduced dataset size for
-- technologies, temporary compute bonus).
--
-- Event registration lives in control.lua.

local ai_meta = require("scripts.ai_meta")
local meta = require("scripts.research_meta")
local network = require("scripts.runtime.network_runtime")
local qln = require("scripts.runtime.qln_runtime")

local M = {}

--- Initialize AI storage.
function M.init_storage()
  storage.ai = storage.ai or {}
  storage.ai.training_clusters = storage.ai.training_clusters or {}
  storage.ai.inference_labs = storage.ai.inference_labs or {}
  storage.ai.insight_multipliers = storage.ai.insight_multipliers or {}
  for _, force in pairs(game.forces) do
    storage.ai.insight_multipliers[force.index] =
      storage.ai.insight_multipliers[force.index] or {}
  end
end

--- Find a Training Cluster record by entity.
local function find_training_cluster(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  return storage.ai.training_clusters[entity.unit_number]
end

--- Ensure a Training Cluster record exists.
local function ensure_training_cluster(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  local record = storage.ai.training_clusters[entity.unit_number]
  if not record then
    record = {
      entity = entity,
      model_name = nil,
      progress = 0,
      remainder = {},
    }
    storage.ai.training_clusters[entity.unit_number] = record
  end
  record.entity = entity
  return record
end

--- Find an Inference Lab record by entity.
local function find_inference_lab(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  return storage.ai.inference_labs[entity.unit_number]
end

--- Ensure an Inference Lab record exists.
local function ensure_inference_lab(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  local record = storage.ai.inference_labs[entity.unit_number]
  if not record then
    record = {
      entity = entity,
      model_name = nil,
      insight_until = 0,
    }
    storage.ai.inference_labs[entity.unit_number] = record
  end
  record.entity = entity
  return record
end

--- Look up an AI tier by model item name.
local function tier_for_model(model_name)
  for _, tier in ipairs(ai_meta.AI_TIERS) do
    if tier.name == model_name then
      return tier
    end
  end
  return nil
end

--- Check if a model tier is unlocked (its gate technology is researched).
local function is_unlocked(force, tier)
  local tech = force.technologies[tier.gate]
  return tech and tech.researched
end

--- Get the highest unlocked model tier for a force.
local function highest_unlocked_model(force)
  local best = nil
  for _, tier in ipairs(ai_meta.AI_TIERS) do
    if is_unlocked(force, tier) then
      best = tier
    end
  end
  return best
end

--- Get compute stats for the network behind an entity.
local function network_stats(entity)
  local graph = network.graph_for(entity.surface)
  if not graph then
    return nil
  end
  local network_id = graph.device_network and graph.device_network[entity.unit_number]
  if not network_id then
    return nil
  end
  local net = graph.networks[network_id]
  if not net then
    return nil
  end
  return {
    scalar = net.scalar or 0,
    vector = net.vector or 0,
    tensor = net.tensor or 0,
    quantum = net.quantum or 0,
    memory = net.memory or 0,
    bandwidth = net.bandwidth or 0,
  }
end

--- Check if the network can supply the compute required for a tier.
local function check_compute(stats, tier)
  if not stats then
    return false
  end
  local required = tier.train_compute or {}
  for profile, amount in pairs(required) do
    local have = stats[profile] or 0
    if have < amount then
      return false
    end
  end
  return true
end

--- Draw data items from QLN storage for a tier's training recipe.
local function consume_data(entity, tier)
  local train_data = tier.train_data or {}
  local requirements = {}
  for _, req in ipairs(train_data) do
    requirements[#requirements + 1] = {
      item = req.name,
      count = req.amount,
    }
  end
  if #requirements == 0 then
    return true
  end
  local ok, _ = qln.consume(entity, requirements)
  return ok
end

--- Tick one Training Cluster.
local function tick_training_cluster(record)
  local entity = record.entity
  if not (entity and entity.valid) then
    return
  end

  local model_name = record.model_name
  if not model_name then
    -- No model configured; try to auto-select highest unlocked.
    local tier = highest_unlocked_model(entity.force)
    if tier then
      record.model_name = tier.name
      model_name = tier.name
    else
      return
    end
  end

  local tier = tier_for_model(model_name)
  if not tier then
    return
  end

  local stats = network_stats(entity)
  if not stats then
    return
  end

  -- Check compute availability.
  if not check_compute(stats, tier) then
    return
  end

  -- Check data availability and consume.
  if not consume_data(entity, tier) then
    return
  end

  -- Accumulate progress.
  record.progress = record.progress + 1
  if record.progress >= tier.train_energy then
    record.progress = 0
    -- Produce one model into QLN storage.
    qln.deposit(entity, model_name, 1)
  end
end

--- Tick one Inference Lab.
local function tick_inference_lab(record)
  local entity = record.entity
  if not (entity and entity.valid) then
    return
  end

  local model_name = record.model_name
  if not model_name then
    return
  end

  local tier = tier_for_model(model_name)
  if not tier then
    return
  end

  local stats = network_stats(entity)
  if not stats then
    return
  end

  -- Check compute availability.
  local required = tier.train_compute or {}
  local ok = true
  for profile, amount in pairs(required) do
    local have = stats[profile] or 0
    if have < amount then
      ok = false
      break
    end
  end
  if not ok then
    return
  end

  -- Grant insight: extend the insight window.
  local now = game.tick
  record.insight_until = now + 60 * 60 -- 1 minute of insight per tick of support

  -- Apply force-level insight multiplier.
  local force_index = entity.force.index
  local multipliers = storage.ai.insight_multipliers[force_index] or {}
  multipliers[model_name] = record.insight_until
  storage.ai.insight_multipliers[force_index] = multipliers
end

--- Reconcile Training Cluster records (remove invalid entities).
local function reconcile_training_clusters()
  local seen = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({ name = "training-cluster" })) do
      if entity.valid and entity.unit_number then
        seen[entity.unit_number] = true
        ensure_training_cluster(entity)
      end
    end
  end
  for unit_number, record in pairs(storage.ai.training_clusters) do
    if not seen[unit_number] or not record.entity or not record.entity.valid then
      storage.ai.training_clusters[unit_number] = nil
    end
  end
end

--- Reconcile Inference Lab records (remove invalid entities).
local function reconcile_inference_labs()
  local seen = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({ name = "inference-lab" })) do
      if entity.valid and entity.unit_number then
        seen[entity.unit_number] = true
        ensure_inference_lab(entity)
      end
    end
  end
  for unit_number, record in pairs(storage.ai.inference_labs) do
    if not seen[unit_number] or not record.entity or not record.entity.valid then
      storage.ai.inference_labs[unit_number] = nil
    end
  end
end

--- Tick all Training Clusters and Inference Labs.
function M.tick()
  if not storage.ai then
    M.init_storage()
  end
  reconcile_training_clusters()
  reconcile_inference_labs()

  for _, record in pairs(storage.ai.training_clusters) do
    tick_training_cluster(record)
  end
  for _, record in pairs(storage.ai.inference_labs) do
    tick_inference_lab(record)
  end
end

--- Get the active insight multiplier for a force and model tier.
--- Returns the insight reduction factor (0 = no insight, >0 = active).
function M.insight_factor(force, model_name)
  local multipliers = storage.ai.insight_multipliers[force.index] or {}
  local until_tick = multipliers[model_name] or 0
  if game.tick >= until_tick then
    return 0
  end
  local tier = tier_for_model(model_name)
  if not tier then
    return 0
  end
  return tier.insight.dataset_size_reduction or 0
end

--- Set the model a Training Cluster should train.
function M.set_model(entity, model_name)
  local record = ensure_training_cluster(entity)
  if record then
    record.model_name = model_name
    record.progress = 0
    record.remainder = {}
  end
end

--- Install a model in an Inference Lab.
function M.install_model(entity, model_name)
  local record = ensure_inference_lab(entity)
  if record then
    record.model_name = model_name
    record.insight_until = 0
  end
end

--- Uninstall a model from an Inference Lab.
function M.uninstall_model(entity)
  local record = find_inference_lab(entity)
  if record then
    record.model_name = nil
    record.insight_until = 0
  end
end

--- Handle a built entity: ensure it has a record if it's an AI building.
function M.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  if entity.name == "training-cluster" then
    ensure_training_cluster(entity)
  elseif entity.name == "inference-lab" then
    ensure_inference_lab(entity)
  end
end

--- Handle a removed entity: drop its record.
function M.on_removed(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  if entity.name == "training-cluster" and entity.unit_number then
    storage.ai.training_clusters[entity.unit_number] = nil
  elseif entity.name == "inference-lab" and entity.unit_number then
    storage.ai.inference_labs[entity.unit_number] = nil
  end
end

--- Get the status of all AI entities for debug/remote interface.
function M.status()
  local clusters = {}
  for unit_number, record in pairs(storage.ai.training_clusters or {}) do
    local tier = record.model_name and tier_for_model(record.model_name) or nil
    clusters[#clusters + 1] = {
      unit_number = unit_number,
      model = record.model_name,
      progress = record.progress,
      target = tier and tier.train_energy or 0,
      entity_valid = record.entity and record.entity.valid or false,
    }
  end
  local labs = {}
  for unit_number, record in pairs(storage.ai.inference_labs or {}) do
    labs[#labs + 1] = {
      unit_number = unit_number,
      model = record.model_name,
      insight_until = record.insight_until,
      entity_valid = record.entity and record.entity.valid or false,
    }
  end
  return {
    training_clusters = clusters,
    inference_labs = labs,
  }
end

return M
