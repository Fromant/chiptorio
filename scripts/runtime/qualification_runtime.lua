-- Runtime: half-node process qualification.
--
-- Researching a `refine-*` technology only unlocks the pilot line and the
-- Metrology Lab. The upgrade activates when the lab has analysed the required
-- number of Process Qualification Wafers. This module owns that state:
--
--   storage.qualification.forces[force_index].qualified[key] = true
--   storage.qualification.forces[force_index].samples[key]   = analysed wafers
--
-- The decision maths live in scripts/runtime/qualification_alloc.lua and are
-- pure. This is the only qualification code that reads entities or writes
-- `storage`. Event registration stays in control.lua. DESIGN §4.5.

local alloc = require("scripts.runtime.qualification_alloc")
local meta = require("scripts.research_meta")
local network = require("scripts.runtime.network_runtime")
local nodes = require("scripts.process_nodes")

local M = {}

local INPUT = defines.inventory.lab_input

local function init_storage()
  storage.qualification = storage.qualification or {}
  storage.qualification.version = 1
  storage.qualification.forces = storage.qualification.forces or {}
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

--- Per-force qualification state. `create` is false for read-only callers, so
--- inspecting a fresh save never writes storage.
local function force_state(force, create)
  init_storage()
  local state = storage.qualification.forces[force.index]
  if not state and create then
    state = { qualified = {}, samples = {} }
    storage.qualification.forces[force.index] = state
  end
  if state then
    state.qualified = state.qualified or {}
    state.samples = state.samples or {}
  end
  return state
end

local function researched(force, key)
  local tech = force.technologies[nodes.half_tech_name(key)]
  return tech ~= nil and tech.valid and tech.researched
end

--- Every Metrology Lab of this force, with the graph it belongs to. Labs are
--- sorted by unit number so two saves advance deterministically.
local function labs_for(force)
  local labs = {}
  for _, graph in pairs(network.graphs()) do
    for _, device in pairs(graph.devices or {}) do
      if
        device.kind == "metrology"
        and device.force_index == force.index
        and device.entity
        and device.entity.valid
      then
        labs[#labs + 1] = { device = device, graph = graph }
      end
    end
  end
  table.sort(labs, function(a, b)
    return a.device.id < b.device.id
  end)
  return labs
end

local function lab_network(graph, device)
  local id = graph.device_network and graph.device_network[device.id]
  if not id then
    return nil
  end
  return graph.networks[id]
end

local function powered(entity)
  if not (entity and entity.valid) then
    return false
  end
  return entity.energy > 0 or entity.status ~= defines.entity_status.no_power
end

local function lab_inventory(entity)
  if not (entity and entity.valid) then
    return nil
  end
  return entity.get_inventory(INPUT)
end

--- Remove up to `wanted` PQWs from the force's labs. Returns how many were
--- actually taken; the caller rolls the bar back for the rest.
local function take_samples(labs, item, wanted)
  local taken = 0
  for _, lab in ipairs(labs) do
    if taken >= wanted then
      break
    end
    local inventory = lab_inventory(lab.device.entity)
    if inventory then
      local have = inventory.get_item_count(item)
      local want = math.min(have, wanted - taken)
      if want > 0 then
        local removed = inventory.remove({ name = item, count = want })
        if type(removed) ~= "number" then
          removed = want
        end
        taken = taken + removed
      end
    end
  end
  return taken
end

--- A read-only snapshot of one half-node for the GUI, the monitor and tests.
local function half_status(force, half, labs, state)
  local needed = half.samples or 0
  local status = {
    key = half.key,
    label = half.label,
    samples = state and state.samples[half.key] or 0,
    needed = needed,
    qualified = state and state.qualified[half.key] == true or false,
    researched = researched(force, half.key),
    supported = false,
    powered = false,
    labs = #labs,
    reason = "locked",
    gate = meta.qualification_gate(half.key),
  }
  status.fraction = alloc.fraction(status.samples, needed)

  if status.qualified then
    status.samples = needed
    status.fraction = 1
    status.supported = true
    status.reason = "qualified"
    return status
  end
  if not status.researched then
    return status
  end

  local reason = #labs == 0 and "no-labs" or nil
  local supported = false
  local has_power = false
  for _, lab in ipairs(labs) do
    local ok, why = alloc.support(half.key, lab_network(lab.graph, lab.device))
    if reason == nil then
      reason = why
    end
    if ok then
      supported = true
      if powered(lab.device.entity) then
        has_power = true
      end
    end
  end

  status.supported = supported
  status.powered = has_power
  if not supported then
    status.reason = reason or "no-network"
  elseif not has_power then
    status.reason = "no-power"
  else
    status.reason = "ok"
  end
  return status
end

--- Apply this half-node's yield to the node it refines. One half-node refines
--- one node, so the bonus is set, not stacked: a second qualification cannot
--- multiply the same recipe twice. `allow_productivity` is set on those recipes
--- in scripts/node_recipes.lua.
local function apply_yield(force, half)
  local previous = nodes.node(half.between[1])
  if not previous then
    return
  end
  local names = nodes.items(previous.key)
  for _, recipe_name in ipairs({ names.wafer, names.die }) do
    local recipe = force.recipes[recipe_name]
    if recipe then
      recipe.productivity_bonus = half.bonus.yield - 1
    end
  end
end

local function apply_bonus(force, state)
  for _, half in ipairs(nodes.HALF_NODES) do
    if state.qualified[half.key] then
      apply_yield(force, half)
    end
  end
  network.set_chip_multipliers(force.index, nodes.total_bonus(state.qualified))
end

--- Whether any researched half-node still needs samples. Most of the game has
--- none, and this lets the tick skip the graph poll entirely (the network
--- module polls provider inventories once per second; qualification should not
--- make that three times).
local function needs_work(force, state)
  for _, half in ipairs(nodes.HALF_NODES) do
    if not state.qualified[half.key] and researched(force, half.key) then
      return true
    end
  end
  return false
end

--- Analyse every researched, unqualified half-node for one force.
local function advance_force(force, seconds)
  local state = force_state(force, true)
  if not needs_work(force, state) then
    return {}
  end
  local labs = labs_for(force)
  local results = {}

  for _, half in ipairs(nodes.HALF_NODES) do
    local status = half_status(force, half, labs, state)

    if status.researched and not status.qualified then
      local gain = 0
      for _, lab in ipairs(labs) do
        local supported = alloc.support(half.key, lab_network(lab.graph, lab.device))
        if supported and powered(lab.device.entity) then
          gain = gain + alloc.gain(half, seconds, true, true)
        end
      end

      local before = status.samples
      local after, complete = alloc.advance(before, status.needed, gain)

      -- One PQW per completed sample. If the lab does not have them, undo the
      -- progress: time alone must not qualify a process.
      local wanted = alloc.samples_to_take(before, after)
      if wanted > 0 then
        local taken = take_samples(labs, nodes.qualification_item(half.key), wanted)
        if taken < wanted then
          after = alloc.advance(after, status.needed, taken - wanted)
          complete = status.needed > 0 and after >= status.needed
        end
      end

      state.samples[half.key] = after
      status.samples = after
      status.fraction = alloc.fraction(after, status.needed)

      if complete then
        state.qualified[half.key] = true
        state.samples[half.key] = status.needed
        status.qualified = true
        status.samples = status.needed
        status.fraction = 1
        status.reason = "qualified"
        apply_bonus(force, state)
        -- Chip multipliers changed, so the graph has to be rebuilt before the
        -- next research allocation reads provider compute.
        network.mark_dirty()
        force.print({ "chiptorio.qualification-complete", half.label })
      end
    end

    results[#results + 1] = status
  end

  return results
end

function M.init_storage()
  init_storage()
end

function M.on_init()
  init_storage()
  for _, force in ipairs(forces()) do
    apply_bonus(force, force_state(force, true))
  end
end

function M.on_configuration_changed()
  init_storage()
  for _, force in ipairs(forces()) do
    -- A recipe added by a new version has no productivity bonus yet, so
    -- reapply every completed refinement to every force.
    apply_bonus(force, force_state(force, true))
  end
end

function M.tick()
  init_storage()
  for _, force in ipairs(forces()) do
    advance_force(force, 1)
  end
end

--- /c remote.call("chiptorio-qualification", "status")
function M.status()
  init_storage()
  for _, force in ipairs(forces()) do
    local state = force_state(force, true)
    local bonus = nodes.total_bonus(state.qualified)
    -- Debug only, so one graph poll per force is acceptable here.
    local labs = labs_for(force)
    for _, half in ipairs(nodes.HALF_NODES) do
      local status = half_status(force, half, labs, state)
      if status.researched then
        log(string.format(
          "CHIPTORIO QUALIFICATION force=%s half=%s qualified=%s samples=%d/%d supported=%s powered=%s reason=%s",
          force.name,
          status.key,
          tostring(status.qualified),
          math.floor(status.samples),
          status.needed,
          tostring(status.supported),
          tostring(status.powered),
          status.reason
        ))
      end
    end
    log(string.format(
      "CHIPTORIO QUALIFICATION force=%s bonus_yield=%.3f bonus_compute=%.3f bonus_power=%.3f",
      force.name,
      bonus.yield,
      bonus.compute,
      bonus.power
    ))
  end
end

--- Machine-readable state for tests and debugging.
function M.state(force_index)
  init_storage()
  local force = game.forces[force_index or 1] or game.forces.player
  if not force then
    return nil
  end
  local state = force_state(force, false) or { qualified = {}, samples = {} }
  local qualified = {}
  local samples = {}
  for _, half in ipairs(nodes.HALF_NODES) do
    if state.qualified[half.key] then
      qualified[#qualified + 1] = half.key
    end
    samples[half.key] = state.samples[half.key] or 0
  end
  return {
    force = force.name,
    qualified = qualified,
    samples = samples,
    bonus = alloc.bonus(state.qualified),
  }
end

--- Evaluate one half-node without changing anything.
function M.evaluate(key, force_index)
  init_storage()
  local force = game.forces[force_index or 1] or game.forces.player
  local half = nodes.half_node(key)
  if not (force and half) then
    return nil
  end
  local state = force_state(force, false) or { qualified = {}, samples = {} }
  local status = half_status(force, half, labs_for(force), state)
  status.bonus = alloc.bonus(state.qualified)
  status.gate = meta.qualification_gate(key)
  return status
end

--- Advance qualification by `seconds` without waiting for a tick. Tests use it;
--- normal play calls tick() once per second.
function M.step(seconds)
  init_storage()
  local total = 0
  for _, force in ipairs(forces()) do
    for _, status in ipairs(advance_force(force, seconds or 1)) do
      total = total + status.samples
    end
  end
  return total
end

-- ---------------------------------------------------------------------------
-- Monitor section
-- ---------------------------------------------------------------------------

local function profile_text(gate)
  local parts = {}
  for _, name in ipairs(meta.COMPUTE_PROFILES) do
    local share = gate.profiles and gate.profiles[name]
    if share and share > 0 then
      parts[#parts + 1] = string.format("%s %.2g", name, share)
    end
  end
  return table.concat(parts, ", ")
end

local function add_caption(parent, caption)
  local label = parent.add({ type = "label", caption = caption })
  label.style.single_line = false
  return label
end

--- Extra section in the network monitor. Registered with network_runtime so
--- that module never has to require this one (that would be a cycle).
function M.monitor_section(player, body)
  local force = player.force
  local state = force_state(force, false)
  local labs = labs_for(force)
  local shown = 0

  for _, half in ipairs(nodes.HALF_NODES) do
    local status = half_status(force, half, labs, state)
    if status.researched then
      if shown == 0 then
        body.add({ type = "line" })
        local title = body.add({ type = "label", caption = { "chiptorio.qualification-header" } })
        title.style.font = "default-bold"
      end
      shown = shown + 1

      if status.qualified then
        add_caption(body, { "chiptorio.qualification-done", half.label })
      else
        add_caption(body, {
          "chiptorio.qualification-line",
          half.label,
          math.floor(status.samples),
          status.needed,
        })
        if status.reason == "no-labs" then
          add_caption(body, { "chiptorio.qualification-no-lab" })
        elseif status.reason == "no-network" then
          add_caption(body, { "chiptorio.qualification-no-network" })
        elseif status.reason == "no-power" then
          add_caption(body, { "chiptorio.qualification-no-power" })
        elseif status.reason == "compute" then
          add_caption(body, { "chiptorio.qualification-short-compute" })
        elseif status.reason == "memory" then
          add_caption(body, { "chiptorio.qualification-short-memory" })
        elseif status.reason == "bandwidth" then
          add_caption(body, { "chiptorio.qualification-short-bandwidth" })
        end

        local gate = status.gate
        if gate and not status.qualified then
          add_caption(body, {
            "chiptorio.qualification-gate",
            gate.floor,
            profile_text(gate),
            gate.memory,
            gate.bandwidth,
          })
        end
        add_caption(body, { "chiptorio.qualification-inactive" })
      end
    end
  end
end

network.set_qualification_provider(M.monitor_section)

return M
