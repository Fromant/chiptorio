-- Runtime: labs as network clients, research gating and progress decay.
--
-- The decision maths live in scripts/runtime/research_alloc.lua and are pure.
-- This module is the only research code that reads entities or writes
-- `storage`: it gathers each force's labs and networks, asks the allocator what
-- should run, pauses the rest with `disabled_by_script`, and applies decay to
-- the force's research bar when the network cannot support the technology.
--
-- Event registration lives in control.lua.

local alloc = require("scripts.runtime.research_alloc")
local meta = require("scripts.research_meta")
local network = require("scripts.runtime.network_runtime")

local M = {}

local function init_storage()
  storage.research = storage.research or {}
  storage.research.version = 1
  storage.research.infinite_multipliers = storage.research.infinite_multipliers or {}
  for _, force in pairs(game.forces) do
    storage.research.infinite_multipliers[force.index] =
      storage.research.infinite_multipliers[force.index] or {}
  end
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

--- Every lab of this force that the network runtime scanned, including labs
--- that are not attached to any cable (so they can be paused too).
local function labs_for(force)
  local labs = {}
  for _, graph in pairs(network.graphs()) do
    for _, device in pairs(graph.devices or {}) do
      if
        device.kind == "lab"
        and device.force_index == force.index
        and device.entity
        and device.entity.valid
      then
        labs[#labs + 1] = device
      end
    end
  end
  table.sort(labs, function(a, b)
    return a.id < b.id
  end)
  return labs
end

--- Force-level infinite-research multipliers. Returns a table of tech_name ->
--- multiplier for the given force. Level 0 means not researched (multiplier 1).
local function force_multipliers(force_index)
  local levels = storage.research.infinite_multipliers[force_index] or {}
  local result = {}
  for tech_name, spec in pairs(meta.INFINITE_RESEARCH_SCALES) do
    local level = levels[tech_name] or 0
    if level > 0 then
      result[spec.field] = meta.infinite_multiplier(tech_name, level)
    end
  end
  return result
end

--- Apply force-level multipliers to a network table before it reaches the
--- allocator. Compute fields are scaled; memory, bandwidth, power and cooling
--- are scaled.
local function apply_multipliers(network, mults)
  if mults.compute then
    network.scalar = network.scalar * mults.compute
    network.vector = network.vector * mults.compute
    network.tensor = network.tensor * mults.compute
    network.quantum = network.quantum * mults.compute
  end
  if mults.quantum then
    network.quantum = network.quantum * mults.quantum
  end
  if mults.memory then
    network.memory = network.memory * mults.memory
  end
  if mults.bandwidth then
    network.bandwidth = network.bandwidth * mults.bandwidth
  end
  if mults.network_bandwidth then
    network.bandwidth = network.bandwidth * mults.network_bandwidth
  end
  if mults.power then
    network.power = network.power * mults.power
  end
  if mults.cooling then
    network.cooling = network.cooling * mults.cooling
  end
end

--- Plain per-force network tables for the allocator. Network ids are prefixed
--- with the surface index so two surfaces cannot collide. Force-level infinite
--- research multipliers are applied before the table reaches the allocator.
local function networks_for(force)
  local list = {}
  local mults = force_multipliers(force.index)
  for surface_index, graph in pairs(network.graphs()) do
    for _, net in ipairs(graph.networks) do
      local labs = {}
      for _, id in ipairs(net.labs or {}) do
        local device = graph.devices[id]
        if device and device.kind == "lab" and device.force_index == force.index then
          labs[#labs + 1] = {
            id = id,
            name = device.name,
            demand = device.base_demand or meta.LAB_DEMAND[device.name] or 1,
          }
        end
      end
      local entry = {
        id = surface_index .. ":" .. net.id,
        surface_index = surface_index,
        scalar = net.scalar,
        vector = net.vector,
        tensor = net.tensor,
        quantum = net.quantum,
        memory = net.memory,
        bandwidth = net.bandwidth,
        power = net.power or 0,
        heat = net.heat or 0,
        cooling = net.cooling or 0,
        labs = labs,
      }
      apply_multipliers(entry, mults)
      list[#list + 1] = entry
    end
  end
  return list
end

local function set_lab_active(device, active)
  local entity = device.entity
  if not (entity and entity.valid) then
    return
  end
  if entity.disabled_by_script ~= not active then
    entity.disabled_by_script = not active
  end
end

--- Evaluate one technology for one force and apply the lab pausing.
---
--- `tech_name` exists for tests and remote debugging; in normal play the
--- current research is used. An ungated technology (no entry in TECHS) needs no
--- compute, so every lab is re-enabled.
function M.evaluate_force(force, tech_name)
  local tech = nil
  if tech_name then
    tech = force.technologies[tech_name]
  elseif force.current_research then
    tech = force.current_research
  end

  local name = tech and tech.name or nil
  local spec = name and meta.tech_spec(name) or nil

  if name and not spec then
    local labs = labs_for(force)
    for _, lab in ipairs(labs) do
      set_lab_active(lab, true)
    end
    return {
      tech = name,
      gated = false,
      supported = true,
      decay = 0,
      reason = "ok",
      active_labs = #labs,
    }
  end

  if not spec then
    return {
      tech = nil,
      gated = false,
      supported = false,
      decay = 0,
      reason = "idle",
      active_labs = 0,
    }
  end

  local result = alloc.evaluate(spec, networks_for(force))
  local active = {}
  for _, detail in pairs(result.networks) do
    for id in pairs(detail.active_labs) do
      active[id] = true
    end
  end

  local active_count = 0
  for _, lab in ipairs(labs_for(force)) do
    local run = active[lab.id] == true
    if run then
      active_count = active_count + 1
    end
    set_lab_active(lab, run)
  end

  result.tech = name
  result.gated = true
  result.active_labs = active_count
  return result
end

local function apply_decay(force, spec, result, seconds)
  if not spec or not result then
    return 0
  end
  local amount = alloc.decay_amount(spec, result, seconds)
  if amount <= 0 then
    return 0
  end
  local progress = force.research_progress or 0
  if progress <= 0 then
    return 0
  end
  local next_progress = progress - amount
  if next_progress < 0 then
    next_progress = 0
  end
  force.research_progress = next_progress
  return amount
end

function M.init_storage()
  init_storage()
end

function M.on_init()
  init_storage()
end

function M.on_configuration_changed()
  init_storage()
end

function M.tick()
  init_storage()
  for _, force in ipairs(forces()) do
    local tech = force.current_research
    if tech then
      local spec = meta.tech_spec(tech.name)
      if spec then
        local result = M.evaluate_force(force, tech.name)
        apply_decay(force, spec, result, 1)
      else
        M.evaluate_force(force, tech.name)
      end
    end
  end
end

--- /c remote.call("chiptorio-research", "status")
function M.status()
  init_storage()
  for _, force in ipairs(forces()) do
    local tech = force.current_research
    if tech then
      local result = M.evaluate_force(force, tech.name)
      log(string.format(
        "CHIPTORIO RESEARCH force=%s tech=%s gated=%s supported=%s decay=%.4f active_labs=%d reason=%s",
        force.name,
        tostring(result.tech),
        tostring(result.gated),
        tostring(result.supported),
        result.decay,
        result.active_labs,
        result.reason
      ))
    else
      log(string.format("CHIPTORIO RESEARCH force=%s idle", force.name))
    end
  end
end

--- Machine-readable evaluation for tests and debugging. Applies lab pausing
--- exactly like the tick, so the probe can assert disabled_by_script.
function M.evaluate(tech_name, force_index)
  init_storage()
  local force = game.forces[force_index or 1] or game.forces.player
  if not force then
    return nil
  end
  local result = M.evaluate_force(force, tech_name)
  return {
    tech = result.tech,
    gated = result.gated,
    supported = result.supported,
    decay = result.decay,
    reason = result.reason,
    active_labs = result.active_labs,
  }
end

--- Advance decay by `seconds` for the current research without waiting for a
--- tick. Used by runtime tests; normal play calls tick() once per second.
function M.step(seconds)
  init_storage()
  local applied = 0
  for _, force in ipairs(forces()) do
    local tech = force.current_research
    if tech then
      local spec = meta.tech_spec(tech.name)
      if spec then
        local result = M.evaluate_force(force, tech.name)
        applied = applied + apply_decay(force, spec, result, seconds or 1)
      end
    end
  end
  return applied
end

--- Handle a technology being researched. Infinite researches increment their
--- level in storage, which changes the force-level multipliers on the next
--- graph rebuild. Returns true if the level changed.
function M.on_technology_researched(force, tech_name)
  init_storage()
  local spec = meta.INFINITE_RESEARCH_SCALES[tech_name]
  if not spec then
    return false
  end
  local levels = storage.research.infinite_multipliers[force.index] or {}
  local old_level = levels[tech_name] or 0
  local new_level = old_level + 1
  levels[tech_name] = new_level
  storage.research.infinite_multipliers[force.index] = levels
  -- Multipliers changed: force the network graph to rebuild so the new
  -- values reach the allocator.
  network.mark_dirty()
  return true, old_level, new_level
end

return M
