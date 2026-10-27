-- Runtime contract probe. Runs after chiptorio's on_init on a fresh map and
-- checks that the enemy/robot removal is real, not just hidden prototypes, and
-- that the network graph builds from real entities.

local failures = {}

local nodes = require("__chiptorio__/scripts/process_nodes")
local qmeta = require("__chiptorio__/scripts/qln_meta")
local answer_meta = require("__chiptorio__/scripts/answer_meta")

local function check(condition, message)
  if not condition then
    failures[#failures + 1] = message
  end
end

local function finish(suite)
  if #failures > 0 then
    error("CHIPTORIO-TEST FAIL " .. suite .. ": " .. table.concat(failures, "; "))
  end
  log("CHIPTORIO-TEST PASS " .. suite)
end

local function raise(event, entity)
  script.raise_event(event, { entity = entity })
end

local function topology(surface_index)
  local ok, res = pcall(function()
    -- Force rebuild
    pcall(function() remote.call("chiptorio-network", "status") end)
    return remote.call("chiptorio-network", "topology", surface_index)
  end)
  if not ok or type(res) ~= "table" then
    return { cable_count = 0, networks = {}, unconnected = {}, conflicts = {} }
  end
  res.networks = res.networks or {}
  res.unconnected = res.unconnected or {}
  res.conflicts = res.conflicts or {}
  if type(res.networks) == "table" then
    -- if it's array-like
  end
  return res
end

local function clear_area(surface, area)
  for _, entity in ipairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
end

local function place(surface, force, created, name, x, y)
  local entity = surface.create_entity({ name = name, position = { x, y }, force = force })
  check(entity, "could not place " .. name .. " at " .. x .. "," .. y)
  if entity then
    created[#created + 1] = entity
  end
  return entity
end

local function cable_run(surface, force, created, first_x, last_x, y)
  for x = first_x, last_x do
    place(surface, force, created, "network-cable", x + 0.5, y + 0.5)
  end
end

local function raise_built(created)
  for _, entity in ipairs(created) do
    if entity.valid then
      raise(defines.events.script_raised_built, entity)
    end
  end
end

local function destroy_all(created)
  for _, entity in ipairs(created) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
end

local function qln_step(seconds)
  return remote.call("chiptorio-qln", "step", seconds or 1)
end

--- Benchmark maps have no player and 2.1 has no script API to create one, so
--- GUI paths are only exercised in a normal save. The hook stays explicit so
--- the probe reports the skip instead of silently missing coverage.
local function probe_player()
  return game.players[1]
end

--- The QLN group with at least this much capacity. The runtime keys groups by
--- surface:network:force, so this also gives the probe a real network id.
local function qln_group(min_capacity)
  local state = remote.call("chiptorio-qln", "state", "player")
  local best
  for _, group in ipairs(state or {}) do
    if group.capacity >= (min_capacity or 1) and (not best or group.capacity > best.capacity) then
      best = group
    end
  end
  return best
end

local function group_network(group)
  local surface_index, network_id = string.match(group.key, "^(%d+):(%d+):")
  return tonumber(surface_index), tonumber(network_id)
end

local function qln_deposit(group, name, count)
  local surface_index, network_id = group_network(group)
  return remote.call("chiptorio-qln", "deposit", "player", surface_index, network_id, name, count)
end

local function qln_withdraw(group, name, count)
  local surface_index, network_id = group_network(group)
  return remote.call("chiptorio-qln", "withdraw", "player", surface_index, network_id, name, count)
end

-- Place a router between two cable runs and check that the graph joins two
-- subnets into one network. Then remove the far cable and check the subnet
-- count drops. The graph is cached, so the probe raises the same build and
-- destroy events chiptorio listens to instead of reaching into storage.
local function check_network()
  local network = remote.interfaces["chiptorio-network"]
  check(network and network.topology, "missing chiptorio-network topology interface")
  if not (network and network.topology) then
    return
  end

  local surface = game.surfaces[1]
  local area = { { 47, 47 }, { 56, 56 } }
  for _, entity in ipairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy()
    end
  end

  local force = game.forces.player
  local router = surface.create_entity({ name = "network-router", position = { 50.5, 50.5 }, force = force })
  local left = surface.create_entity({ name = "network-cable", position = { 49.5, 50.5 }, force = force })
  local right = surface.create_entity({ name = "network-cable", position = { 52.5, 50.5 }, force = force })
  check(router, "could not place network-router")
  check(left, "could not place left network-cable")
  check(right, "could not place right network-cable")
  if not (router and left and right) then
    return
  end

  for _, entity in ipairs({ router, left, right }) do
    raise(defines.events.script_raised_built, entity)
  end

  local before = topology(surface.index)
  check(before, "topology returned nothing")
  if before then
    check(before.cable_count == 2, "expected 2 cable tiles but got " .. tostring(before.cable_count))
    check(#before.networks == 1, "expected 1 network but got " .. tostring(#before.networks))
  end

  -- Exercise the overlay rendering path. Custom-input events cannot be raised
  -- from script, so this goes through the remote hook instead of the keybind.
  local ok, err = pcall(function()
    check(remote.call("chiptorio-network", "overlay", true) == true, "overlay did not turn on")
    check(remote.call("chiptorio-network", "overlay", false) == false, "overlay did not turn off")
  end)
  check(ok, "overlay toggle failed: " .. tostring(err))

  -- The monitor is a container clone, so opening it raises on_gui_opened.
  -- Open and close it through a real player to exercise the window build.
  local player = probe_player()
  local monitor = surface.create_entity({ name = "network-monitor", position = { 52.5, 51.5 }, force = force })
  check(monitor, "could not place network-monitor")
  if monitor then
    raise(defines.events.script_raised_built, monitor)
    if player then
      player.opened = monitor
      check(player.gui.screen["chiptorio-network-monitor"], "monitor window did not open")
      player.opened = nil
      check(not player.gui.screen["chiptorio-network-monitor"], "monitor window did not close")
    end
    -- The monitor has to go even without a player, or it stays on the map as
    -- an unconnected device and pollutes every later topology count.
    raise(defines.events.script_raised_destroy, monitor)
    monitor.destroy()
  end

  raise(defines.events.script_raised_destroy, left)
  left.destroy()

  local after = topology(surface.index)
  check(after, "topology returned nothing after removal")
  if after then
    check(after.cable_count == 1, "expected 1 cable tile after removal but got " .. tostring(after.cable_count))
    check(#after.networks == 1, "expected 1 network after removal but got " .. tostring(#after.networks))
  end

  router.destroy()
  right.destroy()

  -- A switch (3×2) merges multiple cable runs into one segment. Place cables
  -- touching different sides of the switch; they should all be one network.
  clear_area(surface, { { 44, 58 }, { 76, 64 } })
  local created = {}
  place(surface, force, created, "network-switch", 50.5, 60.5)
  place(surface, force, created, "network-cable", 49.5, 60.5)
  place(surface, force, created, "network-cable", 53.5, 60.5)
  place(surface, force, created, "network-cable", 50.5, 59.5)
  raise_built(created)

  local switched = topology(surface.index)
  check(switched, "topology returned nothing for a switch")
  if switched then
    check(switched.cable_count == 3,
      "switch: expected 3 cables but got " .. tostring(switched.cable_count))
    check(#switched.networks == 1,
      "switch: expected 1 network but got " .. tostring(#switched.networks))
  end
  destroy_all(created)

  -- A router provides WiFi: a machine within 16 tiles connects wirelessly.
  -- Place a router and a cable beyond normal wired reach, separated by a gap.
  clear_area(surface, { { 44, 66 }, { 76, 72 } })
  created = {}
  place(surface, force, created, "network-router", 50.5, 69.5)
  place(surface, force, created, "network-cable", 49.5, 69.5)
  -- Cable at 69.5 is 20 tiles from the router at 50.5 (too far for WiFi).
  -- Cable at 58.5 is within 16 tiles.
  place(surface, force, created, "network-cable", 58.5, 69.5)
  raise_built(created)

  local routed = topology(surface.index)
  check(routed, "topology returned nothing for a router")
  if routed then
    check(#routed.networks >= 1, "router: expected at least 1 network")
  end
  destroy_all(created)

  -- A device just across a chunk border must still be found. The chunk index
  -- is seeded from the wiring, so a lab two tiles into the next chunk is only
  -- visible through the scan margin. Missing it would leave the lab unpaused
  -- and researching for free.
  clear_area(surface, { { 90, 56 }, { 100, 66 } })
  created = {}
  place(surface, force, created, "network-cable", 95.5, 60.5)
  place(surface, force, created, "analytical-engine", 97.5, 60.5)
  raise_built(created)

  local boundary = topology(surface.index)
  check(boundary, "topology returned nothing at a chunk border")
  if boundary then
    check(boundary.cable_count == 1,
      "chunk border: expected 1 cable but got " .. tostring(boundary.cable_count))
    check(boundary.labs == 1, "a lab two tiles across a chunk border was not indexed")
    check(boundary.unconnected == 0, "the lab across a chunk border was not connected")
  end
  destroy_all(created)
end

-- Exercise the research path end to end: a datacenter full of computers, a
-- memory bank full of SRAM and an analytical engine on the same cable run. The
-- allocator must support vlsi-process, pause the lab when compute disappears,
-- and never mistake a scalar-only network for a mixed workload.
local function check_research()
  local iface = remote.interfaces["chiptorio-research"]
  check(iface and iface.evaluate, "missing chiptorio-research evaluate interface")
  if not (iface and iface.evaluate) then
    return
  end

  local surface = game.surfaces[1]
  local area = { { 58, 58 }, { 74, 74 } }
  for _, entity in ipairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end

  local force = game.forces.player
  local created = {}

  local cables = {}
  for y = 62, 66 do
    local cable = surface.create_entity({ name = "network-cable", position = { 64.5, y + 0.5 }, force = force })
    if cable then
      cables[#cables + 1] = cable
      created[#created + 1] = cable
    end
  end

  local datacenter = surface.create_entity({ name = "datacenter", position = { 62.5, 62.5 }, force = force })
  local bank = surface.create_entity({ name = "memory-bank", position = { 62.5, 66.5 }, force = force })
  local lab = surface.create_entity({ name = "analytical-engine", position = { 66.5, 64.5 }, force = force })
  check(datacenter, "could not place datacenter provider")
  check(bank, "could not place memory bank")
  check(lab, "could not place analytical engine")
  check(#cables == 5, "expected 5 network cables")
  if not (datacenter and bank and lab and #cables == 5) then
    return
  end
  created[#created + 1] = datacenter
  created[#created + 1] = bank
  created[#created + 1] = lab

  -- One microcomputer provides 8 scalar, 256 memory, 32 bandwidth -- enough
  -- for vlsi-process (floor=8, memory=16, bandwidth=8).
  datacenter.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  bank.get_module_inventory().insert({ name = "sram-module", count = 4 })

  for _, entity in ipairs(created) do
    raise(defines.events.script_raised_built, entity)
  end

  local topo = topology(surface.index)
  check(topo, "topology returned nothing after research setup")
  if topo then
    check((topo.providers or 0) == 2, "expected 2 providers but got " .. tostring(topo.providers))
    check((topo.labs or 0) == 1, "expected 1 lab but got " .. tostring(topo.labs))
    check((topo.scalar or 0) >= 8, "expected at least 8 scalar compute but got " .. tostring(topo.scalar))
    check((topo.memory or 0) >= 16, "expected at least 16 memory capacity but got " .. tostring(topo.memory))
  end

  local supported = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(supported, "research evaluate returned nothing")
  if supported then
    check(supported.supported == true, "vlsi-process should be supported")
    check(supported.active_labs == 1, "expected 1 active lab but got " .. tostring(supported.active_labs))
    check(supported.decay == 0, "supported research must not decay")
    check(lab.disabled_by_script == false, "supported lab must be enabled")
  end

  local player_force = game.forces.player
  if player_force.current_research then
    player_force.cancel_current_research()
  end
  -- A fresh map has only the first technology unlocked. Force-research the
  -- prerequisites (and enable the technology) on this disposable map so it can
  -- become the current research; the gate maths does not depend on the chain
  -- being legitimately reachable.
  local function research_prerequisites(force, name)
    local tech = force.technologies[name]
    if not tech then
      return
    end
    -- LuaTechnology.prerequisites is a dictionary keyed by technology name.
    for _, prereq in pairs(tech.prerequisites or {}) do
      if prereq.valid and not prereq.researched then
        prereq.research_recursive()
      end
    end
  end

  local vlsi_tech = player_force.technologies["vlsi-process"]
  check(vlsi_tech, "missing vlsi-process technology on the force")
  if vlsi_tech then
    research_prerequisites(player_force, "vlsi-process")
    vlsi_tech.enabled = true
    player_force.add_research("vlsi-process")
  end
  -- Without a current research the progress bar cannot be written, so the
  -- decay tests below are skipped rather than erroring out of the probe.
  local started = player_force.current_research ~= nil
  check(started, "could not start vlsi-process for the decay test")
  if started then
    player_force.research_progress = 0.5
    local supported_decay = remote.call("chiptorio-research", "step", 60)
    check(supported_decay == 0, "supported research must not decay, got " .. tostring(supported_decay))
    check(
      math.abs(player_force.research_progress - 0.5) < 1e-9,
      "supported research progress changed to " .. tostring(player_force.research_progress)
    )
  end

  local mixed = remote.call("chiptorio-research", "evaluate", "heterogeneous-compute")
  check(mixed, "research evaluate returned nothing for heterogeneous-compute")
  if mixed then
    check(mixed.supported == false, "heterogeneous-compute must not run on scalar-only compute")
    -- A connected network must always report a real gate, never "no-network".
    check(
      mixed.reason == "memory" or mixed.reason == "bandwidth" or mixed.reason == "compute",
      "heterogeneous-compute reason was " .. tostring(mixed.reason)
    )
    check(mixed.reason ~= "no-network", "a connected network must not report no-network")
    check(lab.disabled_by_script == true, "unsupported lab must be paused")
  end

  -- Empty the datacenter but leave memory alone: this is a pure compute
  -- shortfall, so the reason must be compute and decay must be proportional.
  datacenter.get_module_inventory().clear()
  local starved_compute = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(starved_compute, "research evaluate returned nothing without compute")
  if starved_compute then
    check(starved_compute.supported == false, "vlsi-process must not run without compute")
    check(starved_compute.reason == "compute", "compute-starved reason was " .. tostring(starved_compute.reason))
    check(
      math.abs(starved_compute.decay - 0.02) < 1e-9,
      "zero compute should decay at the maximum rate, got " .. tostring(starved_compute.decay)
    )
    check(lab.disabled_by_script == true, "compute-starved lab must be paused")
  end

  datacenter.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  local recovered = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(recovered, "research evaluate returned nothing after reinstalling computer")
  if recovered then
    check(recovered.supported == true, "vlsi-process should recover once computer is reinstalled")
    check(lab.disabled_by_script == false, "recovered lab must be enabled")
  end

  -- Remove the memory bank: memory drops but vlsi-process still runs because
  -- the computer provides its own memory. This confirms computers are
  -- self-contained for both compute and memory.
  raise(defines.events.script_raised_destroy, bank)
  bank.destroy()
  local still_supported = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(still_supported, "research evaluate returned nothing without memory bank")
  if still_supported then
    check(still_supported.supported == true, "vlsi-process still runs with computer memory only")
  end

  -- Now starve on compute: clear the datacenter. vlsi-process must decay.
  datacenter.get_module_inventory().clear()
  local starved = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(starved, "research evaluate returned nothing without compute")
  if starved then
    check(starved.supported == false, "vlsi-process must not run without compute")
    check(starved.reason == "compute", "compute-starved reason was " .. tostring(starved.reason))
    check(math.abs(starved.decay - 0.02) < 1e-9, "zero compute should decay at the maximum rate, got " .. tostring(starved.decay))
    check(lab.disabled_by_script == true, "compute-starved lab must be paused")
  end

  if started then
    local before = player_force.research_progress
    local starved_decay = remote.call("chiptorio-research", "step", 60)
    check(
      math.abs(starved_decay - 0.02) < 1e-9,
      "one minute of starvation should remove 2% of the bar, got " .. tostring(starved_decay)
    )
    check(
      math.abs((before - player_force.research_progress) - 0.02) < 1e-9,
      "research_progress did not decay: " .. tostring(before) .. " -> " .. tostring(player_force.research_progress)
    )
    player_force.cancel_current_research()
  end

  for _, entity in ipairs(created) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
end

-- Exercise qualification end to end. A Metrology Lab on a small network must
-- analyse the pre-internet 6 µm refinement offline, and the 800 nm refinement
-- must refuse to run until the network reaches its compute gate. Values come
-- from scripts/process_nodes.lua so this probe tracks the table, not a copy.
local function check_qualification()
  local iface = remote.interfaces["chiptorio-qualification"]
  check(iface and iface.evaluate and iface.step, "missing chiptorio-qualification interface")
  if not (iface and iface.evaluate and iface.step) then
    return
  end

  local surface = game.surfaces[1]
  local force = game.forces.player
  local area = { { 78, 56 }, { 96, 74 } }
  for _, entity in ipairs(surface.find_entities_filtered({ area = area })) do
    if entity.valid and entity.type ~= "character" then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end

  local created = {}
  for y = 60, 68 do
    local cable = surface.create_entity({ name = "network-cable", position = { 84.5, y + 0.5 }, force = force })
    check(cable, "could not place qualification cable at " .. y)
    if cable then
      created[#created + 1] = cable
    end
  end

  local metrology = surface.create_entity({ name = "metrology-lab", position = { 82.5, 60.5 }, force = force })
  local rack = surface.create_entity({ name = "server-rack", position = { 82.5, 64.5 }, force = force })
  local bank = surface.create_entity({ name = "memory-bank", position = { 82.5, 68.5 }, force = force })
  check(metrology, "could not place metrology-lab")
  check(rack, "could not place server-rack for qualification")
  check(bank, "could not place memory-bank for qualification")
  if not (metrology and rack and bank) then
    return
  end
  created[#created + 1] = metrology
  created[#created + 1] = rack
  created[#created + 1] = bank

  local inventory = metrology.get_inventory(defines.inventory.lab_input)
  check(inventory, "metrology-lab has no lab input inventory")
  if not inventory then
    return
  end

  local first = nodes.HALF_NODES[1]
  local second = nodes.HALF_NODES[3]
  check(first.requires_network == false, "the first half-node should work offline")
  check(second.requires_network == true, "the third half-node should need the internet")

  inventory.insert({ name = nodes.qualification_item(first.key), count = first.samples })
  rack.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  bank.get_module_inventory().insert({ name = "sram-module", count = 4 })

  -- The map has no power grid. Fill the lab buffer so the power gate passes;
  -- the probe is testing analysis and network gating, not electricity.
  metrology.energy = 1e9

  for _, entity in ipairs(created) do
    raise(defines.events.script_raised_built, entity)
  end

  local topo = topology(surface.index)
  check(topo and topo.metrology == 1, "topology does not see the Metrology Lab")

  local tech = force.technologies[nodes.half_tech_name(first.key)]
  check(tech, "missing refinement technology on the force: " .. nodes.half_tech_name(first.key))
  if tech then
    tech.research_recursive()
    check(tech.researched, "refinement technology did not research: " .. tech.name)
  end

  local before = remote.call("chiptorio-qualification", "evaluate", first.key)
  check(before, "qualification evaluate returned nothing")
  if before then
    check(before.supported == true, first.key .. " should be supported offline")
    check(before.reason == "ok", first.key .. " reason was " .. tostring(before.reason))
    check(before.qualified == false, first.key .. " started qualified")
  end

  -- The map has no power grid. Fill the lab buffer so the power gate passes;
  -- the probe is testing analysis and network gating, not electricity.
  remote.call("chiptorio-qualification", "step", first.samples * first.analysis_time * 2)

  local state = remote.call("chiptorio-qualification", "state")
  check(state, "qualification state returned nothing")
  local qualified = false
  for _, key in ipairs(state and state.qualified or {}) do
    if key == first.key then
      qualified = true
    end
  end
  check(qualified, first.key .. " was not qualified after analysing a full batch")

  local after = remote.call("chiptorio-qualification", "evaluate", first.key)
  check(after and after.qualified == true, first.key .. " did not report qualified")
  check(inventory.get_item_count(nodes.qualification_item(first.key)) == 0,
    "qualification did not consume its PQWs")

  -- Yield is applied to the node the half-node refines, on wafer and die.
  local refined = nodes.items(nodes.refined_node(first.key))
  local wafer_bonus = force.recipes[refined.wafer] and force.recipes[refined.wafer].productivity_bonus
  local die_bonus = force.recipes[refined.die] and force.recipes[refined.die].productivity_bonus
  check(wafer_bonus and math.abs(wafer_bonus - (first.bonus.yield - 1)) < 1e-6,
    "wafer yield bonus was " .. tostring(wafer_bonus))
  check(die_bonus and math.abs(die_bonus - (first.bonus.yield - 1)) < 1e-6,
    "die yield bonus was " .. tostring(die_bonus))

  -- The compute multiplier must reach the graph through the provider, but it
  -- must not scale memory capacity or backplane bandwidth.
  local before_topo = topology(surface.index)
  local boosted = topology(surface.index)
  check(boosted, "topology returned nothing after qualification")
  if boosted then
    local expected = 8 * first.bonus.compute
    check(math.abs((boosted.scalar or 0) - expected) < 1e-6,
      "scalar compute was " .. tostring(boosted.scalar) .. ", expected " .. tostring(expected))
    if before_topo then
      check((boosted.memory or 0) == (before_topo.memory or 0),
        "memory capacity was scaled by the compute bonus: " .. tostring(boosted.memory)
        .. " vs " .. tostring(before_topo.memory))
    end
  end

  -- 800 nm needs a network. With no compute it must fail even though the lab
  -- is connected, powered and has memory and bandwidth.
  rack.get_module_inventory().clear()
  local second_tech = force.technologies[nodes.half_tech_name(second.key)]
  check(second_tech, "missing refinement technology on the force: " .. nodes.half_tech_name(second.key))
  if second_tech then
    second_tech.research_recursive()
  end
  local gated = remote.call("chiptorio-qualification", "evaluate", second.key)
  check(gated, "qualification evaluate returned nothing for " .. second.key)
  if gated then
    check(gated.supported == false, second.key .. " should not run without compute")
    check(gated.reason == "compute", second.key .. " reason was " .. tostring(gated.reason))
  end

  -- One computer clears the floor: 1 * 8 * 1.05 = 8.4 scalar, above the
  -- 800 nm floor of 8.
  rack.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  local recovered = remote.call("chiptorio-qualification", "evaluate", second.key)
  check(recovered, "qualification evaluate returned nothing after installing computer")
  if recovered then
    check(recovered.supported == true, second.key .. " should run on 8.4 scalar")
    check(recovered.reason == "ok", second.key .. " reason was " .. tostring(recovered.reason))
  end

  inventory.insert({ name = nodes.qualification_item(second.key), count = second.samples })
  metrology.energy = 1e9
  remote.call("chiptorio-qualification", "step", second.samples * second.analysis_time * 2)

  local final = remote.call("chiptorio-qualification", "evaluate", second.key)
  check(final and final.qualified == true, second.key .. " did not qualify on a qualified network")

  local final_topo = topology(surface.index)
  local expected_final = 8 * first.bonus.compute * second.bonus.compute
  check(final_topo and math.abs((final_topo.scalar or 0) - expected_final) < 1e-6,
    "stacked compute bonus was " .. tostring(final_topo and final_topo.scalar) .. ", expected " .. tostring(expected_final))

  for _, entity in ipairs(created) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
end

-- Exercise the pre-quantum Data Bus, the terminal, the FOUP Dock, the
-- Construction Core and the quantum storage merge. The pass is driven through
-- the same remote hooks a player would use, so it covers the runtime paths and
-- not just the prototypes.
local function check_qln()
  local iface = remote.interfaces["chiptorio-qln"]
  check(
    iface and iface.state and iface.step and iface.deposit and iface.withdraw and iface.set_foup_mode,
    "missing chiptorio-qln remote interface"
  )
  if not (iface and iface.state and iface.step and iface.deposit and iface.withdraw and iface.set_foup_mode) then
    return
  end

  local surface = game.surfaces[1]
  local force = game.forces.player
  clear_area(surface, { { 96, 46 }, { 134, 75 } })

  local created = {}
  cable_run(surface, force, created, 99, 128, 60)

  local drive = place(surface, force, created, "qln-storage-drive", 100.5, 58.5)
  local import_node = place(surface, force, created, "qln-import-node", 103.5, 58.5)
  local import_chest = place(surface, force, created, "wooden-chest", 103.5, 57.5)
  -- The dock sits between the Import and Export Nodes so both touch it. That
  -- lets the probe drive the whole FOUP chain through the network instead of
  -- inserting items by hand.
  local dock = place(surface, force, created, "foup-dock", 104.5, 58.5)
  local export_node = place(surface, force, created, "qln-export-node", 105.5, 58.5)
  local export_chest = place(surface, force, created, "wooden-chest", 105.5, 57.5)
  local terminal = place(surface, force, created, "qln-terminal", 111.5, 58.5)
  local provider = place(surface, force, created, "qln-provider-node", 119.5, 58.5)
  local requester = place(surface, force, created, "qln-requester-node", 123.5, 58.5)
  local accept = place(surface, force, created, "wooden-chest", 123.5, 57.5)
  local core = place(surface, force, created, "construction-core", 127.5, 58.5)
  if not (drive and import_node and export_node and terminal and dock and provider and requester and core) then
    destroy_all(created)
    return
  end

  drive.get_module_inventory().insert({ name = "sram-module", count = 4 })
  import_chest.insert({ name = "iron-plate", count = 100 })

  raise_built(created)
  qln_step(1)

  local group = qln_group(1)
  check(group, "the Storage Drive did not create a QLN group")
  if not group then
    destroy_all(created)
    return
  end
  check(group.capacity == 4096, "drive capacity was " .. tostring(group.capacity) .. ", expected 4096")
  check(group.drives == 1, "expected 1 drive but got " .. tostring(group.drives))
  check(group.used == 0, "a new storage group should be empty")

  -- A 30-cable run carries 10 bandwidth, so the shared transport budget is 40
  -- items/s across the four transfer nodes. Fourteen seconds moves all 100.
  qln_step(14)
  check(
    import_chest.get_item_count("iron-plate") == 0,
    "the Import Node left " .. tostring(import_chest.get_item_count("iron-plate")) .. " of 100 iron"
  )
  check(
    export_chest.get_item_count("iron-plate") == 100,
    "the Export Node moved " .. tostring(export_chest.get_item_count("iron-plate")) .. " of 100 iron"
  )

  -- FOUP logistics use the same network. An Export Node pushes an empty
  -- carrier and a wafer batch from storage into the sealing dock, the dock
  -- seals them into one carrier, and the Import Node pulls that carrier back
  -- into storage. Remove the chests first: an Export Node fills every adjacent
  -- inventory, and a chest would steal the batch before the dock could seal it.
  for _, entity in ipairs({ import_chest, export_chest }) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
  local dock_inventory = dock.get_inventory(defines.inventory.chest)
  local wafer = "node-" .. nodes.NODES[1].key .. "-wafer"
  local sealed = "foup-sealed-" .. nodes.NODES[1].key
  group = qln_group(1)
  qln_deposit(group, "foup", 1)
  qln_deposit(group, wafer, qmeta.FOUP_BATCH)
  qln_step(6)

  group = qln_group(1)
  check(
    group and (group.items[sealed] or 0) == 1,
    "the FOUP chain delivered "
      .. tostring(group and group.items[sealed] or 0)
      .. " of 1 sealed carrier to storage"
  )
  check(
    group and (group.items[wafer] or 0) == 0,
    "the FOUP chain left " .. tostring(group and group.items[wafer] or 0) .. " wafers in storage"
  )
  check(
    group and (group.items["foup"] or 0) == 0,
    "the FOUP chain left an empty carrier in storage"
  )
  check(dock_inventory.is_empty(), "the FOUP Dock kept items after its sealed carrier left")

  -- Remove import/export before the provider/requester phase: an Export Node
  -- would otherwise drain the copper the Requester is waiting for.
  for _, entity in ipairs({ import_node, import_chest, export_node, export_chest }) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
  qln_step(1)

  provider.get_inventory(defines.inventory.chest).insert({ name = "copper-plate", count = 60 })
  requester.get_inventory(defines.inventory.chest).insert({ name = "copper-plate", count = 1 })
  qln_step(12)

  check(
    provider.get_inventory(defines.inventory.chest).is_empty(),
    "the Provider Node left "
      .. tostring(provider.get_inventory(defines.inventory.chest).get_item_count("copper-plate"))
      .. " of 60 copper in its buffer"
  )
  check(
    accept.get_item_count("copper-plate") == qmeta.REQUESTER_TARGET,
    "the Requester stocked "
      .. tostring(accept.get_item_count("copper-plate"))
      .. " of "
      .. tostring(qmeta.REQUESTER_TARGET)
      .. " copper"
  )
  check(
    requester.get_inventory(defines.inventory.chest).get_item_count("copper-plate") == 1,
    "the Requester consumed its filter item"
  )
  group = qln_group(1)
  check(
    group and (group.items["copper-plate"] or 0) == 10,
    "the Requester left " .. tostring(group and group.items["copper-plate"] or 0) .. " of 10 copper in storage"
  )

  -- Remove the remaining transfer nodes: the construction core needs the group
  -- to itself to prove the ghost cost is paid from storage.
  for _, entity in ipairs({ provider, requester, accept }) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
  qln_step(1)

  -- Transfer nodes must reach real machine inventories, not only chests. 2.1
  -- renamed the crafter inventories to crafter_input/crafter_output and dropped
  -- furnace_source/furnace_result, assembler_input/assembler_output and
  -- miner_result; a stale define silently yields no inventory at all, so the
  -- node would look connected and move nothing.
  check(defines.inventory.crafter_input ~= nil, "defines.inventory.crafter_input is missing")
  check(defines.inventory.crafter_output ~= nil, "defines.inventory.crafter_output is missing")
  local machines = {}
  local furnace = place(surface, force, machines, "stone-furnace", 109.5, 56.5)
  local furnace_import = place(surface, force, machines, "qln-import-node", 109.5, 58.5)
  -- An assembling machine with no recipe has no item filters and accepts
  -- nothing, so give it one exactly like a player would.
  local assembler = surface.create_entity({
    name = "assembling-machine-1",
    position = { 113.5, 56.5 },
    force = force,
    recipe = "iron-gear-wheel",
  })
  check(assembler, "could not place assembling-machine-1 at 113.5,56.5")
  if assembler then
    machines[#machines + 1] = assembler
  end
  local assembler_export = place(surface, force, machines, "qln-export-node", 113.5, 58.5)
  if furnace and furnace_import and assembler and assembler_export then
    raise_built(machines)
    qln_step(1)
    local furnace_output = furnace.get_inventory(defines.inventory.crafter_output)
    local assembler_input = assembler.get_inventory(defines.inventory.crafter_input)
    check(furnace_output, "a stone furnace has no crafter_output inventory")
    check(assembler_input, "an assembling machine has no crafter_input inventory")
    if furnace_output and assembler_input then
      furnace_output.insert({ name = "iron-plate", count = 40 })
      qln_step(8)
      check(
        furnace_output.is_empty(),
        "the Import Node left "
          .. tostring(furnace_output.get_item_count("iron-plate"))
          .. " of 40 iron in the furnace output"
      )
      -- The Export Node on the same group then feeds the plate to the
      -- assembler, so the items travel furnace output -> QLN -> crafter input
      -- in one pass. Nothing may be left behind in storage.
      check(
        assembler_input.get_item_count("iron-plate") == 40,
        "the Export Node put "
          .. tostring(assembler_input.get_item_count("iron-plate"))
          .. " of 40 iron plate into the assembling machine"
      )
      group = qln_group(1)
      check(
        group and (group.items["iron-plate"] or 0) == 0,
        "the transfer through storage left " .. tostring(group and group.items["iron-plate"] or 0)
          .. " iron plate behind"
      )
    end
  end
  destroy_all(machines)
  qln_step(1)

  -- GUI windows need a player, and a benchmark map has none. The transfer
  -- logic above still runs through the remote step hooks; when a real player
  -- exists, exercise the terminal and FOUP windows as well.
  local player = probe_player()
  if player then
    local inventory = player.get_inventory(defines.inventory.character_main)
    inventory.clear()
    inventory.insert({ name = "coal", count = 50 })

    -- `player.opened = entity` does not reliably raise on_gui_opened when the
    -- assignment comes from script, so raise it explicitly. The handler is
    -- idempotent: it closes both custom windows and rebuilds the one that
    -- belongs to this entity.
    local function open_entity(entity)
      player.opened = entity
      script.raise_event(defines.events.on_gui_opened, {
        player_index = player.index,
        entity = entity,
        gui_type = defines.gui_type.entity,
      })
    end

    open_entity(terminal)
    local frame = player.gui.screen["chiptorio-qln-terminal"]
    check(frame, "the QLN terminal window did not open")
    if frame then
      local toolbar = frame.children[1]
      local search = toolbar and toolbar["chiptorio-qln-terminal-search"]
      check(search, "missing the QLN terminal search field")
      local deposit = toolbar and toolbar["chiptorio-qln-terminal-deposit"]
      check(deposit, "missing the QLN terminal deposit button")
      if deposit then
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = deposit })
      end
      group = qln_group(1)
      check(
        group and group.items["coal"] == 50,
        "terminal deposit stored " .. tostring(group and group.items["coal"] or 0) .. " of 50 coal"
      )
      check(inventory.get_item_count("coal") == 0, "terminal deposit left coal in the player inventory")

      -- The search field filters the item rows. A non-matching filter must
      -- hide the withdraw button, and clearing it must bring the row back.
      if search then
        script.raise_event(defines.events.on_gui_text_changed, {
          player_index = player.index,
          element = search,
          text = "zzzz-no-such-item",
        })
        local filtered = frame["chiptorio-qln-terminal-body"]
        check(
          filtered and not filtered["chiptorio-qln-terminal-take:coal"],
          "the QLN terminal search did not hide a non-matching item"
        )
        script.raise_event(defines.events.on_gui_text_changed, {
          player_index = player.index,
          element = search,
          text = "coal",
        })
        local matched = frame["chiptorio-qln-terminal-body"]
        check(
          matched and matched["chiptorio-qln-terminal-take:coal"],
          "the QLN terminal search did not show a matching item"
        )
      end

      local body = frame["chiptorio-qln-terminal-body"]
      local take = body and body["chiptorio-qln-terminal-take:coal"]
      check(take, "missing the QLN terminal withdraw button for coal")
      if take then
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = take })
      end
      check(
        inventory.get_item_count("coal") == 50,
        "terminal withdraw returned " .. tostring(inventory.get_item_count("coal")) .. " of 50 coal"
      )
      group = qln_group(1)
      check(group and (group.items["coal"] or 0) == 0, "terminal withdraw left coal in storage")

      local close = toolbar and toolbar["chiptorio-qln-terminal-close"]
      check(close, "missing the QLN terminal close button")
      if close then
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = close })
      end
    end
    player.opened = nil
    check(not player.gui.screen["chiptorio-qln-terminal"], "the QLN terminal window did not close")

    -- The FOUP Dock keeps the vanilla container window (the player has to be
    -- able to insert wafers) and adds its mode switch as a relative panel.
    open_entity(dock)
    local foup_frame = player.gui.relative["chiptorio-qln-foup"]
    check(foup_frame, "the FOUP Dock window did not open")
    if foup_frame then
      local body = foup_frame["chiptorio-qln-foup-body"]
      local toggle = body and body["chiptorio-qln-foup-toggle"]
      check(toggle, "missing the FOUP mode toggle")
      if toggle then
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = toggle })
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = toggle })
      end
      local close = foup_frame["chiptorio-qln-foup-close"]
      check(close, "missing the FOUP Dock close button")
      if close then
        script.raise_event(defines.events.on_gui_click, { player_index = player.index, element = close })
      end
      check(not player.gui.relative["chiptorio-qln-foup"], "the FOUP Dock window did not close")
    end
    player.opened = nil

    -- Opening another entity must dismiss the terminal frame instead of
    -- leaving it floating underneath the new window.
    open_entity(terminal)
    check(player.gui.screen["chiptorio-qln-terminal"], "the terminal did not reopen for the cleanup check")
    open_entity(dock)
    check(
      not player.gui.screen["chiptorio-qln-terminal"],
      "opening another entity left the QLN terminal window open"
    )
    check(player.gui.relative["chiptorio-qln-foup"], "the FOUP Dock window did not replace the terminal")
    player.opened = nil
  else
    log("CHIPTORIO-TEST SKIP qln-gui: benchmark maps have no player")
  end

  -- FOUP seal/unseal. One carrier holds exactly one batch of one node's wafers.
  dock_inventory = dock.get_inventory(defines.inventory.chest)
  check(
    remote.call("chiptorio-qln", "set_foup_mode", dock, "seal") == true,
    "could not switch the FOUP Dock to seal"
  )
  dock_inventory.insert({ name = "foup", count = 1 })
  dock_inventory.insert({ name = wafer, count = qmeta.FOUP_BATCH })
  qln_step(1)
  check(dock_inventory.get_item_count(sealed) == 1, "the FOUP Dock did not seal the wafer batch")
  check(dock_inventory.get_item_count(wafer) == 0, "the FOUP Dock left wafers after sealing")
  check(dock_inventory.get_item_count("foup") == 0, "the FOUP Dock left the empty carrier after sealing")

  check(
    remote.call("chiptorio-qln", "set_foup_mode", dock, "unseal") == true,
    "could not switch the FOUP Dock to unseal"
  )
  qln_step(1)
  check(
    dock_inventory.get_item_count(wafer) == qmeta.FOUP_BATCH,
    "the FOUP Dock unsealed " .. tostring(dock_inventory.get_item_count(wafer)) .. " wafers"
  )
  check(dock_inventory.get_item_count("foup") == 1, "the FOUP Dock did not return the empty carrier")
  check(dock_inventory.get_item_count(sealed) == 0, "unsealing left a sealed carrier behind")

  -- A dock that is not on any network still seals: the operation is local, and
  -- a dock between two fabs that share no cable is a normal layout.
  local standalone = place(surface, force, created, "foup-dock", 96.5, 50.5)
  if standalone then
    raise_built({ standalone })
    local standalone_inventory = standalone.get_inventory(defines.inventory.chest)
    standalone_inventory.insert({ name = "foup", count = 1 })
    standalone_inventory.insert({ name = wafer, count = qmeta.FOUP_BATCH })
    qln_step(1)
    check(
      standalone_inventory.get_item_count(sealed) == 1,
      "a FOUP Dock outside every network did not seal its batch"
    )
    if standalone_inventory.get_item_count(sealed) > 0 then
      remote.call("chiptorio-qln", "set_foup_mode", standalone, "unseal")
      qln_step(1)
      check(
        standalone_inventory.get_item_count(wafer) == qmeta.FOUP_BATCH,
        "a standalone FOUP Dock did not unseal its batch"
      )
    end
    raise(defines.events.script_raised_destroy, standalone)
    standalone.destroy()
  end

  -- Construction Core: mine a marked entity, then build a ghost. The core pays
  -- for a build with the entity's own building item, exactly like a
  -- construction robot, and returns mined items to QLN storage. The map has no
  -- power grid, so fill the buffer directly.
  local target = surface.create_entity({ name = "wooden-chest", position = { 127.5, 64.5 }, force = force })
  check(target, "could not place the construction deconstruction target")
  if target then
    target.order_deconstruction(force)
    check(target.to_be_deconstructed(force), "the construction target was not marked for deconstruction")
  end
  core.energy = 1e9
  qln_step(1)

  check(target and not target.valid, "the Construction Core did not mine the deconstruction target")
  group = qln_group(1)
  check(
    group and (group.items["wooden-chest"] or 0) == 1,
    "the mined chest did not reach QLN storage"
  )

  local ghost = surface.create_entity({
    name = "entity-ghost",
    inner_name = "wooden-chest",
    position = { 130.5, 64.5 },
    force = force,
  })
  check(ghost, "could not place a construction entity ghost")
  core.energy = 1e9
  qln_step(1)

  check(surface.find_entity("wooden-chest", { 130.5, 64.5 }), "the Construction Core did not build the ghost")
  group = qln_group(1)
  check(
    group and (group.items["wooden-chest"] or 0) == 0,
    "the Construction Core did not spend the ghost cost"
  )

  -- A core-built network entity must be indexed immediately. Without
  -- raise_revive the cable exists in the world but the network graph never
  -- sees it until a configuration change.
  local before_topology = topology(surface.index)
  qln_deposit(group, "network-cable", 1)
  local cable_ghost = surface.create_entity({
    name = "entity-ghost",
    inner_name = "network-cable",
    position = { 126.5, 61.5 },
    force = force,
  })
  check(cable_ghost, "could not place a construction cable ghost")
  core.energy = 1e9
  qln_step(1)
  check(
    surface.find_entity("network-cable", { 126.5, 61.5 }),
    "the Construction Core did not build the cable ghost"
  )
  local after_topology = topology(surface.index)
  check(
    after_topology and before_topology
      and after_topology.cable_count == before_topology.cable_count + 1,
    "a Construction Core build was not indexed by the network"
  )
  local built_cable = surface.find_entity("network-cable", { 126.5, 61.5 })
  if built_cable then
    raise(defines.events.script_raised_destroy, built_cable)
    built_cable.destroy()
  end

  destroy_all(created)

  -- Quantum Entanglement Cores pair in build order. Two separate cable runs
  -- with one core each must become one pool, and an import on the first network
  -- must feed an export on the second.
  clear_area(surface, { { 96, 62 }, { 134, 77 } })
  local quantum_created = {}
  cable_run(surface, force, quantum_created, 99, 101, 70)
  cable_run(surface, force, quantum_created, 109, 111, 70)
  local core_a = place(surface, force, quantum_created, "quantum-entanglement-core", 100.5, 68.5)
  local core_b = place(surface, force, quantum_created, "quantum-entanglement-core", 110.5, 68.5)
  local drive_a = place(surface, force, quantum_created, "qln-storage-drive", 100, 72)
  local drive_b = place(surface, force, quantum_created, "qln-storage-drive", 110, 72)
  local import_a = place(surface, force, quantum_created, "qln-import-node", 97.5, 70.5)
  local supply_a = place(surface, force, quantum_created, "wooden-chest", 97.5, 69.5)
  local export_b = place(surface, force, quantum_created, "qln-export-node", 113.5, 70.5)
  local accept_b = place(surface, force, quantum_created, "wooden-chest", 113.5, 69.5)
  if not (core_a and core_b and drive_a and drive_b and import_a and export_b) then
    destroy_all(quantum_created)
    return
  end

  drive_a.get_module_inventory().insert({ name = "sram-module", count = 4 })
  drive_b.get_module_inventory().insert({ name = "sram-module", count = 4 })
  supply_a.insert({ name = "iron-plate", count = 30 })
  raise_built(quantum_created)
  qln_step(1)

  local merged = qln_group(8000)
  check(merged, "paired Quantum Entanglement Cores did not merge the two storage groups")
  if merged then
    check(merged.capacity == 8192, "merged capacity was " .. tostring(merged.capacity) .. ", expected 8192")
    check(merged.drives == 2, "the merged group has " .. tostring(merged.drives) .. " drives, expected 2")
  end

  qln_step(1)
  check(supply_a.get_item_count("iron-plate") == 0, "the Import Node on the first network did not run")
  check(
    accept_b.get_item_count("iron-plate") == 30,
    "the Export Node on the paired network moved "
      .. tostring(accept_b.get_item_count("iron-plate"))
      .. " of 30 iron"
  )

  destroy_all(quantum_created)
end

-- Exercise The Answer Engine end to end. Five datacenters supply every compute
-- profile, the memory dataset and the backplane; a Storage Drive supplies the
-- item draw. The probe boots the engine through the remote hook, advances ten
-- seconds, starves one item line to check pausing, then uses the debug hook to
-- finish the clock and the victory path.
local function check_answer()
  local iface = remote.interfaces["chiptorio-answer"]
  check(
    iface and iface.evaluate and iface.boot and iface.step and iface.debug_complete,
    "missing chiptorio-answer test interface"
  )
  if not (iface and iface.evaluate and iface.boot and iface.step and iface.debug_complete) then
    return
  end

  local surface = game.surfaces[1]
  local force = game.forces.player
  clear_area(surface, { { 96, 76 }, { 164, 92 } })

  local created = {}
  cable_run(surface, force, created, 99, 160, 82)

  -- Each datacenter has eight computer slots. Computers bundle compute and
  -- memory; the mix below covers all four profiles the Answer Engine needs.
  local racks = {
    { 100.5, { { "server", 4 } } },                                       -- 128 scalar
    { 104.5, { { "supercomputer", 2 } } },                                -- 16 scalar, 128 vector
    { 108.5, { { "neural-computer", 2 } } },                              -- 8 scalar, 64 vector, 256 tensor
    { 112.5, { { "quantum-computer", 1 } } },                             -- 2 scalar, 16 vector, 64 tensor, 256 quantum
    { 116.5, { { "server", 2 }, { "quantum-computer", 1 } } },            -- 66 scalar, 16 vector, 64 tensor, 256 quantum
  }
  local racks_ok = true
  for _, spec in ipairs(racks) do
    local provider = place(surface, force, created, "datacenter", spec[1], 80.5)
    if not provider then
      racks_ok = false
    else
      local modules = provider.get_module_inventory()
      for _, module in ipairs(spec[2]) do
        modules.insert({ name = module[1], count = module[2] })
      end
      modules.insert({ name = "dram-module", count = 4 })
    end
  end

  local engine = place(surface, force, created, "answer-engine", 120.5, 80.5)
  local drive = place(surface, force, created, "qln-storage-drive", 122.5, 84.5)
  -- A lab clone is 3x3 and snaps to a tile centre, so the drive ends up at
  -- 123,85. One stub cable keeps it within Chebyshev reach of the main run.
  place(surface, force, created, "network-cable", 122.5, 83.5)
  if not (racks_ok and engine and drive) then
    destroy_all(created)
    return
  end
  local inserted = drive.get_module_inventory().insert({ name = "sram-module", count = 4 })
  check(inserted == 4, "could not install 4 SRAM modules in the Answer Storage Drive: " .. tostring(inserted))

  raise_built(created)
  qln_step(1)

  local group = qln_group(1)
  if not group then
    local state = remote.call("chiptorio-qln", "state", "player")
    local parts = {}
    for _, entry in ipairs(state or {}) do
      parts[#parts + 1] = entry.key .. "=" .. tostring(entry.capacity)
    end
    local topo = topology(1)
    check(
      false,
      "the Answer Engine has no QLN storage group (groups: "
        .. table.concat(parts, ",")
        .. "; networks: "
        .. tostring(topo and topo.networks)
        .. "; drive valid: "
        .. tostring(drive.valid)
        .. ")"
    )
    destroy_all(created)
    return
  end

  local deposited = 0
  for _, req in ipairs(answer_meta.item_demand) do
    deposited = deposited + qln_deposit(group, req.item, 200)
  end
  local expected_deposit = 200 * #answer_meta.item_demand
  check(
    deposited == expected_deposit,
    "deposited " .. tostring(deposited) .. " of " .. tostring(expected_deposit) .. " Answer items"
  )

  local evaluation = remote.call("chiptorio-answer", "evaluate")
  check(evaluation, "the Answer Engine evaluate hook returned nothing")
  if not evaluation then
    destroy_all(created)
    return
  end
  check(evaluation.ok == true, "the Answer Engine gate did not open")
  check(
    evaluation.duration == answer_meta.runtime_seconds * 60,
    "the Answer clock was "
      .. tostring(evaluation.duration)
      .. " ticks, expected "
      .. tostring(answer_meta.runtime_seconds * 60)
  )

  local compute = {}
  for _, line in ipairs(evaluation.lines) do
    if line.kind == "compute" then
      compute[line.profile] = line
    end
  end
  for _, profile in ipairs({ "scalar", "vector", "tensor", "quantum" }) do
    local line = compute[profile]
    check(line and line.ok, "the Answer Engine compute gate failed for " .. profile)
    check(
      line and line.have >= answer_meta.compute[profile],
      "Answer compute " .. profile .. " was " .. tostring(line and line.have)
    )
  end

  check(remote.call("chiptorio-answer", "boot") == true, "the Answer Engine did not boot")

  local before = qln_group(1)
  check(remote.call("chiptorio-answer", "step", 10) == 10, "the Answer Engine step hook did not advance")
  local after = qln_group(1)
  local elapsed = remote.call("chiptorio-answer", "evaluate")
  check(
    elapsed and elapsed.elapsed == 600,
    "the Answer clock was " .. tostring(elapsed and elapsed.elapsed) .. " ticks after ten steps"
  )
  local consumed = (before and before.used or 0) - (after and after.used or 0)
  check(consumed == 455, "the Answer Engine consumed " .. tostring(consumed) .. " items in ten seconds, expected 455")

  local short = qln_withdraw(group, "automation-science-pack", 100)
  check(short == 100, "could not withdraw the automation-science-pack line: " .. tostring(short))
  local starved = remote.call("chiptorio-answer", "evaluate")
  check(starved and starved.ok == false, "the Answer Engine did not notice a missing item line")
  remote.call("chiptorio-answer", "step", 1)
  local paused = remote.call("chiptorio-answer", "evaluate")
  check(paused and paused.state == "paused", "the Answer Engine did not pause on a missing item")
  remote.call("chiptorio-answer", "step", 1)
  local decayed = remote.call("chiptorio-answer", "evaluate")
  check(decayed and decayed.stability < 1, "paused stability did not drain")

  qln_deposit(group, "automation-science-pack", 100)
  remote.call("chiptorio-answer", "step", 1)
  local resumed = remote.call("chiptorio-answer", "evaluate")
  check(resumed and resumed.state == "running", "the Answer Engine did not resume after restocking")
  check(
    resumed and resumed.elapsed == 600,
    "the paused clock advanced to " .. tostring(resumed and resumed.elapsed)
  )

  remote.call("chiptorio-answer", "debug_complete")
  local complete = remote.call("chiptorio-answer", "evaluate")
  check(complete and complete.state == "complete", "debug_complete did not complete the engine")
  check(
    complete and complete.elapsed == complete.duration,
    "the completed clock is at " .. tostring(complete and complete.elapsed)
  )
  check(
    complete and complete.score == answer_meta.score_per_level,
    "the first completion scored " .. tostring(complete and complete.score)
  )
  check(complete and complete.victory == true, "the victory screen was not recorded")

  -- The Question is infinite: a level scales every demand and the score. A
  -- LuaTechnology has no `infinite` field; the prototype marks it with a count
  -- formula, so that is what the test asserts.
  local question = force.technologies["the-question"]
  check(
    question and question.prototype.research_unit_count_formula ~= nil,
    "the-question is not an infinite technology"
  )
  if question then
    question.level = 2
    local scaled = remote.call("chiptorio-answer", "evaluate")
    check(scaled and scaled.level == 2, "The Question level was " .. tostring(scaled and scaled.level))
    local expected_scale = 1 + answer_meta.rate_scale_per_level
    check(
      scaled and math.abs(scaled.scale - expected_scale) < 0.0001,
      "The Question scale was " .. tostring(scaled and scaled.scale)
    )
    for _, line in ipairs(scaled and scaled.lines or {}) do
      if line.kind == "compute" then
        local base = answer_meta.compute[line.profile] or 0
        check(
          math.abs(line.required - base * expected_scale) < 0.0001,
          "level-two " .. line.profile .. " demand was " .. tostring(line.required)
        )
      end
    end
    question.level = 1
  end

  destroy_all(created)
end

script.on_init(function()
  local map = game.map_settings
  check(map.enemy_evolution and map.enemy_evolution.enabled == false, "enemy evolution is enabled")
  check(map.enemy_expansion and map.enemy_expansion.enabled == false, "enemy expansion is enabled")
  check(map.pollution and map.pollution.enabled == false, "pollution is enabled")
  check(remote.interfaces["chiptorio-answer"], "missing chiptorio-answer remote interface")
  finish("runtime-init")
end)

script.on_nth_tick(120, function()
  if storage.runtime_checked then
    return
  end
  storage.runtime_checked = true

  for _, surface in pairs(game.surfaces) do
    local enemies = surface.find_entities_filtered({ force = "enemy" })
    check(#enemies == 0, "enemy entities still exist on " .. surface.name)

    for _, prototype_type in ipairs({
      "unit-spawner",
      "logistic-robot",
      "construction-robot",
      "spider-vehicle",
    }) do
      local robots = surface.find_entities_filtered({ type = prototype_type })
      check(#robots == 0, "removed entity type still exists on " .. surface.name .. ": " .. prototype_type)
    end
  end

  check_network()
  check_research()
  check_qualification()
  check_qln()
  check_answer()
  finish("runtime")
end)
