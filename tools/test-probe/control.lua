-- Runtime contract probe. Runs after chiptorio's on_init on a fresh map and
-- checks that the enemy/robot removal is real, not just hidden prototypes, and
-- that the network graph builds from real entities.

local failures = {}

local nodes = require("__chiptorio__/scripts/process_nodes")
local qmeta = require("__chiptorio__/scripts/qln_meta")
local answer_meta = require("__chiptorio__/scripts/answer_meta")
local ai_meta = require("__chiptorio__/scripts/ai_meta")
local research_meta = require("__chiptorio__/scripts/research_meta")
local computers_meta = require("__chiptorio__/scripts/computers_meta")

-- `--benchmark` raises tick handlers only at tick 0, so suites that need real
-- elapsed time run in a hosted server. Each server runner opts in by copying
-- `server_suite.lua` into the probe mod with the suite name; the file is absent
-- everywhere else and `require` throws when it is missing.
local function server_suite()
  local ok, name = pcall(require, "server_suite")
  if ok and type(name) == "string" then
    return name
  end
  return nil
end

local SERVER_SUITE = server_suite()

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
--- surface:network:force, so this also gives the probe a real network id. The
--- force argument keeps the force-isolation probe from reading the player pool.
local function force_group(force_name, min_capacity)
  local state = remote.call("chiptorio-qln", "state", force_name)
  local best
  for _, group in ipairs(state or {}) do
    if group.capacity >= (min_capacity or 1) and (not best or group.capacity > best.capacity) then
      best = group
    end
  end
  return best
end

local function force_group_by_key(force_name, key)
  for _, group in ipairs(remote.call("chiptorio-qln", "state", force_name) or {}) do
    if group.key == key then
      return group
    end
  end
end

local function qln_group(min_capacity)
  return force_group("player", min_capacity)
end

local function group_network(group)
  local surface_index, network_id = string.match(group.key, "^(%d+):(%d+):")
  return tonumber(surface_index), tonumber(network_id)
end

local function group_force_index(group)
  local force_index = string.match(group.key, "^%d+:%d+:(%d+)$")
  return tonumber(force_index)
end

local function qln_deposit(group, name, count, force_name)
  local surface_index, network_id = group_network(group)
  return remote.call("chiptorio-qln", "deposit", force_name or "player", surface_index, network_id, name, count)
end

local function qln_withdraw(group, name, count, force_name)
  local surface_index, network_id = group_network(group)
  return remote.call("chiptorio-qln", "withdraw", force_name or "player", surface_index, network_id, name, count)
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

-- Force isolation. Research, qualification and QLN are all per force, but the
-- network graph is per surface, so two forces sharing a cable segment would
-- still see each other's providers. The probe gives two dedicated forces their
-- own separated cable run, Storage Drive and lab, then proves that deposits,
-- withdraws, qualification state, compute gates and lab pausing never cross the
-- force boundary.
local function check_isolation()
  local first_failure = #failures + 1
  local qln = remote.interfaces["chiptorio-qln"]
  check(
    qln and qln.state and qln.deposit and qln.withdraw,
    "missing chiptorio-qln interface for force isolation"
  )
  if not (qln and qln.state and qln.deposit and qln.withdraw) then
    return
  end

  local surface = game.surfaces[1]
  local force_a = game.forces["chiptorio-isolation-a"] or game.create_force("chiptorio-isolation-a")
  local force_b = game.forces["chiptorio-isolation-b"] or game.create_force("chiptorio-isolation-b")
  check(force_a and force_b, "could not create the isolation forces")
  if not (force_a and force_b) then
    return
  end

  -- Both rows are land that earlier suites already built on, and the two cable
  -- runs are ten tiles apart so they cannot form one segment.
  clear_area(surface, { { 96, 55 }, { 114, 63 } })
  clear_area(surface, { { 96, 65 }, { 114, 73 } })

  local created = {}
  cable_run(surface, force_a, created, 99, 110, 60)
  local drive_a = place(surface, force_a, created, "qln-storage-drive", 100.5, 58.5)
  local datacenter_a = place(surface, force_a, created, "datacenter", 104.5, 58.5)
  local lab_a = place(surface, force_a, created, "analytical-engine", 108.5, 58.5)
  cable_run(surface, force_b, created, 99, 110, 70)
  local drive_b = place(surface, force_b, created, "qln-storage-drive", 100.5, 68.5)
  local lab_b = place(surface, force_b, created, "analytical-engine", 104.5, 68.5)
  if not (drive_a and datacenter_a and lab_a and drive_b and lab_b) then
    destroy_all(created)
    return
  end

  -- Force A can clear the vlsi-process gate; force B has a lab but no provider.
  drive_a.get_module_inventory().insert({ name = "sram-module", count = 4 })
  drive_b.get_module_inventory().insert({ name = "sram-module", count = 4 })
  datacenter_a.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  raise_built(created)
  qln_step(1)

  -- Storage: each drive creates a group on its own force only.
  local group_a = force_group(force_a.name, 1)
  local group_b = force_group(force_b.name, 1)
  check(group_a, "force A's Storage Drive did not create a QLN group")
  check(group_b, "force B's Storage Drive did not create a QLN group")
  if not (group_a and group_b) then
    destroy_all(created)
    return
  end
  check(group_a.capacity == 4096, "force A capacity was " .. tostring(group_a.capacity) .. ", expected 4096")
  check(group_b.capacity == 4096, "force B capacity was " .. tostring(group_b.capacity) .. ", expected 4096")
  check(
    group_force_index(group_a) == force_a.index,
    "force A's group is keyed to force " .. tostring(group_force_index(group_a)) .. ", expected " .. tostring(force_a.index)
  )
  check(
    group_force_index(group_b) == force_b.index,
    "force B's group is keyed to force " .. tostring(group_force_index(group_b)) .. ", expected " .. tostring(force_b.index)
  )

  -- Deposits and withdraws use the same hook signature a player would trigger.
  local a_key, b_key = group_a.key, group_b.key
  check(qln_deposit(group_a, "solar-panel", 5, force_a.name) == 5, "force A could not deposit 5 solar panels")
  check(qln_deposit(group_b, "small-lamp", 7, force_b.name) == 7, "force B could not deposit 7 lamps")
  group_a = force_group_by_key(force_a.name, a_key)
  group_b = force_group_by_key(force_b.name, b_key)
  check(group_a and (group_a.items["solar-panel"] or 0) == 5, "force A did not keep its 5 solar panels")
  check(group_a and (group_a.items["small-lamp"] or 0) == 0, "force B's lamps leaked into force A")
  check(group_b and (group_b.items["small-lamp"] or 0) == 7, "force B did not keep its 7 lamps")
  check(group_b and (group_b.items["solar-panel"] or 0) == 0, "force A's solar panels leaked into force B")

  local leaked = false
  for _, group in ipairs(remote.call("chiptorio-qln", "state", "player") or {}) do
    if (group.items["solar-panel"] or 0) > 0 or (group.items["small-lamp"] or 0) > 0 then
      leaked = true
    end
  end
  check(not leaked, "a deposit made on an isolation force leaked into the player pool")

  check(
    qln_withdraw(group_b, "solar-panel", 1, force_b.name) == 0,
    "force B could withdraw force A's solar panels"
  )
  check(
    qln_withdraw(group_a, "small-lamp", 1, force_a.name) == 0,
    "force A could withdraw force B's lamps"
  )
  check(qln_withdraw(group_b, "small-lamp", 3, force_b.name) == 3, "force B could not withdraw its own lamps")
  group_a = force_group_by_key(force_a.name, a_key)
  group_b = force_group_by_key(force_b.name, b_key)
  check(group_a and (group_a.items["solar-panel"] or 0) == 5, "force A's panels changed after force B withdrew")
  check(group_b and (group_b.items["small-lamp"] or 0) == 4, "force B's own withdraw removed the wrong count")
  check(
    remote.call("chiptorio-qln", "deposit", "chiptorio-isolation-missing", surface.index, 1, "solar-panel", 1) == 0,
    "depositing into a missing force was not a no-op"
  )

  -- Qualification: the player force qualified two half-nodes earlier in the
  -- probe. Neither isolation force may inherit that state or its bonus.
  local qualification = remote.interfaces["chiptorio-qualification"]
  if qualification and qualification.state and qualification.evaluate then
    local player_state = remote.call("chiptorio-qualification", "state", game.forces.player.index)
    check(
      player_state and #(player_state.qualified or {}) >= 1,
      "the player force has no qualified half-node to compare against"
    )

    for _, force in ipairs({ force_a, force_b }) do
      local state = remote.call("chiptorio-qualification", "state", force.index)
      check(state and state.force == force.name, "qualification state did not report force " .. force.name)
      check(
        state and #(state.qualified or {}) == 0,
        force.name .. " inherited " .. tostring(state and #(state.qualified or {})) .. " qualified half-nodes"
      )
      check(
        state and state.bonus and state.bonus.compute == 1,
        force.name .. " inherited a compute bonus of " .. tostring(state and state.bonus and state.bonus.compute)
      )
    end

    local first = nodes.HALF_NODES[1]
    local player_half = remote.call("chiptorio-qualification", "evaluate", first.key, game.forces.player.index)
    local isolated_half = remote.call("chiptorio-qualification", "evaluate", first.key, force_a.index)
    check(player_half and player_half.qualified == true, "the player force lost its qualified " .. first.key)
    check(isolated_half and isolated_half.qualified == false, "force A reported the player's qualified " .. first.key)
  end

  -- Research: force A has enough compute, force B does not. Pausing one force's
  -- lab must leave the other force's lab alone, even though the graph is shared
  -- per surface and the allocator sees both networks.
  local research = remote.interfaces["chiptorio-research"]
  if research and research.evaluate then
    local supported_a = remote.call("chiptorio-research", "evaluate", "vlsi-process", force_a.index)
    check(supported_a and supported_a.active_labs == 1,
      "force A should run one lab, got " .. tostring(supported_a and supported_a.active_labs))
    check(lab_a.disabled_by_script == false, "force A's supported lab was paused")

    local unsupported_b = remote.call("chiptorio-research", "evaluate", "vlsi-process", force_b.index)
    check(unsupported_b and unsupported_b.active_labs == 0,
      "force B should run no lab, got " .. tostring(unsupported_b and unsupported_b.active_labs))
    check(lab_b.disabled_by_script == true, "force B's compute-starved lab was not paused")
    check(lab_a.disabled_by_script == false, "pausing force B also paused force A's lab")

    remote.call("chiptorio-research", "evaluate", "vlsi-process", game.forces.player.index)
    check(lab_a.disabled_by_script == false, "evaluating the player force paused force A's lab")
    check(lab_b.disabled_by_script == true, "evaluating the player force re-enabled force B's lab")
  end

  destroy_all(created)

  if #failures >= first_failure then
    local mine = {}
    for i = first_failure, #failures do
      mine[#mine + 1] = failures[i]
    end
    log("CHIPTORIO-TEST FAIL force-isolation: " .. table.concat(mine, "; "))
  else
    log("CHIPTORIO-TEST PASS force-isolation")
  end
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
    -- A real first completion leaves `level` at 2 (the engine counts completed
    -- levels), so level 3 is the second completion and the first scaled run.
    question.level = 3
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

-- Recursively find a GUI element by name. The computer GUI nests its close
-- button inside a toolbar flow, so a direct child lookup misses it.
local function find_gui(root, name)
  if not (root and root.valid) then
    return nil
  end
  if root.name == name then
    return root
  end
  for _, child in pairs(root.children or {}) do
    local found = find_gui(child, name)
    if found then
      return found
    end
  end
  return nil
end

-- Exercise the Training Cluster and Inference Lab on a real network. A server
-- rack supplies the vector compute, a Storage Drive with SRAM holds the data
-- and the produced model, and the AI buildings must attach to the same cable
-- run. The AI hooks advance training without waiting for the 60-tick
-- dispatcher, exactly like the research and QLN step helpers.
local function check_ai()
  local iface = remote.interfaces["chiptorio-ai"]
  local usable = iface
    and iface.status
    and iface.set_model
    and iface.install_model
    and iface.uninstall_model
    and iface.tick
    and iface.insight
  check(usable, "missing chiptorio-ai test interface")
  if not usable then
    return
  end

  local surface = game.surfaces[1]
  local force = game.forces.player
  clear_area(surface, { { 146, 48 }, { 172, 62 } })

  local created = {}
  cable_run(surface, force, created, 148, 168, 54)

  local rack = place(surface, force, created, "server-rack", 150.5, 56.5)
  local drive = place(surface, force, created, "qln-storage-drive", 154.5, 56.5)
  local cluster = place(surface, force, created, "training-cluster", 158.5, 56.5)
  local inference = place(surface, force, created, "inference-lab", 163.5, 56.5)
  if not (rack and drive and cluster and inference) then
    destroy_all(created)
    return
  end

  local inserted = rack.get_module_inventory().insert({ name = "supercomputer", count = 1 })
  check(inserted == 1, "could not install the supercomputer training needs: " .. tostring(inserted))
  drive.get_module_inventory().insert({ name = "sram-module", count = 4 })

  -- machine-learning unlocks both buildings and every tier gate. Researching it
  -- recursively also covers the prerequisite chain on this disposable map.
  local learning = force.technologies["machine-learning"]
  check(learning, "missing machine-learning technology")
  if learning then
    learning.enabled = true
    learning.research_recursive()
  end
  check(learning and learning.researched, "machine-learning did not research")

  raise_built(created)
  qln_step(1)

  local topo = topology(surface.index)
  check((topo.vector or 0) >= 64, "the AI network provides " .. tostring(topo.vector) .. " vector compute")
  -- AI buildings attach to the network but are not research labs: counting
  -- them as labs would add phantom demand to the allocator.
  check((topo.labs or 0) == 0, "the AI buildings were counted as research labs")
  check((topo.providers or 0) >= 1, "the AI network has no provider")

  local group = qln_group(1)
  check(group, "the AI Storage Drive did not create a QLN group")
  if not group then
    destroy_all(created)
    return
  end
  check(group.capacity >= 4096, "the AI storage group holds " .. tostring(group.capacity) .. " cells")

  local tier = ai_meta.AI_TIERS[1]
  local fed = qln_deposit(group, tier.train_data[1].name, 40)
  check(fed == 40, "could not deposit training data: " .. tostring(fed))

  remote.call("chiptorio-ai", "set_model", cluster, tier.name)
  local configured = remote.call("chiptorio-ai", "status")
  local trained_cluster
  for _, record in ipairs(configured and configured.training_clusters or {}) do
    if record.unit_number == cluster.unit_number then
      trained_cluster = record
    end
  end
  check(trained_cluster, "the Training Cluster has no AI record")
  check(
    trained_cluster and trained_cluster.model == tier.name,
    "the Training Cluster trains " .. tostring(trained_cluster and trained_cluster.model)
  )

  for _ = 1, tier.train_energy do
    remote.call("chiptorio-ai", "tick")
  end

  group = qln_group(1)
  check(
    group and (group.items[tier.name] or 0) == tier.train_output,
    "training produced " .. tostring(group and group.items[tier.name] or 0)
      .. " of " .. tostring(tier.train_output) .. " " .. tier.name
  )
  check(
    group and (group.items[tier.train_data[1].name] or 0) == 40 - tier.train_energy,
    "training consumed "
      .. tostring(40 - (group and group.items[tier.train_data[1].name] or 0))
      .. " data items, expected " .. tostring(tier.train_energy)
  )

  local after_training = remote.call("chiptorio-ai", "status")
  local progress = nil
  for _, record in ipairs(after_training and after_training.training_clusters or {}) do
    if record.unit_number == cluster.unit_number then
      progress = record.progress
    end
  end
  check(progress == 0, "the Training Cluster kept " .. tostring(progress) .. " ticks of progress")

  -- The Inference Lab grants the tier's insight while it has a model and
  -- enough compute. Nothing is granted without a model.
  check(remote.call("chiptorio-ai", "insight", "player", tier.name) == 0, "insight was active before a model was installed")
  remote.call("chiptorio-ai", "install_model", inference, tier.name)
  remote.call("chiptorio-ai", "tick")
  local insight = remote.call("chiptorio-ai", "insight", "player", tier.name)
  check(
    math.abs(insight - tier.insight.dataset_size_reduction) < 1e-9,
    "installed model insight was " .. tostring(insight) .. ", expected " .. tostring(tier.insight.dataset_size_reduction)
  )

  local after_inference = remote.call("chiptorio-ai", "status")
  local installed
  for _, record in ipairs(after_inference and after_inference.inference_labs or {}) do
    if record.unit_number == inference.unit_number then
      installed = record
    end
  end
  check(installed, "the Inference Lab has no AI record")
  check(
    installed and installed.model == tier.name,
    "the Inference Lab installed " .. tostring(installed and installed.model)
  )
  check(
    installed and installed.insight_until > game.tick,
    "the Inference Lab did not open an insight window"
  )

  remote.call("chiptorio-ai", "uninstall_model", inference)
  local removed = remote.call("chiptorio-ai", "status")
  for _, record in ipairs(removed and removed.inference_labs or {}) do
    if record.unit_number == inference.unit_number then
      check(record.model == nil, "the Inference Lab kept its model after uninstall")
    end
  end

  destroy_all(created)
end

-- Exercise the custom computer GUI. The benchmark map normally has no player,
-- so this reports a skip instead of pretending the path is covered.
local function check_computer_gui()
  local player = probe_player()
  if not player then
    log("CHIPTORIO-TEST SKIP computer-gui: the benchmark map has no player")
    return
  end

  local surface = game.surfaces[1]
  local force = player.force
  local created = {}
  clear_area(surface, { { 146, 64 }, { 160, 72 } })
  local rack = place(surface, force, created, "server-rack", 151.5, 67.5)
  if not rack then
    destroy_all(created)
    return
  end
  rack.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  raise_built(created)

  local raised, err = pcall(function()
    script.raise_event(defines.events.on_gui_opened, {
      player_index = player.index,
      entity = rack,
    })
  end)
  if not raised then
    log("CHIPTORIO-TEST SKIP computer-gui: on_gui_opened cannot be raised: " .. tostring(err))
    destroy_all(created)
    return
  end

  local frame = player.gui.screen["chiptorio-computer-gui"]
  check(frame and frame.valid, "the computer GUI did not open for a server rack")
  if not (frame and frame.valid) then
    destroy_all(created)
    return
  end
  check(player.opened == frame, "the computer GUI was not assigned to the player")
  check(find_gui(frame, "chiptorio-computer-gui-body"), "the computer GUI has no body")

  local close = find_gui(frame, "chiptorio-computer-gui-close")
  check(close, "the computer GUI has no close button")
  if close then
    script.raise_event(defines.events.on_gui_click, {
      player_index = player.index,
      element = close,
      button = defines.mouse_button_type.left,
    })
  end
  local remaining = player.gui.screen["chiptorio-computer-gui"]
  check(not (remaining and remaining.valid), "the computer GUI did not close on the close button")
  check(player.opened == nil, "the close button did not release the player's open element")

  destroy_all(created)
end

-- ---------------------------------------------------------------------------
-- Playthrough probe
-- ---------------------------------------------------------------------------
-- Walk the whole gated technology ladder the way a player does: at every step
-- build the best research network the parts that are actually craftable right
-- then can supply, prove the gate opens, and only then complete the technology.
--
-- "Craftable" is recursive: a computer counts only when its own recipe and
-- every ingredient recipe are unlocked. That is what turns an unlock that
-- arrives before its ingredients into a blocked gate instead of hiding it
-- behind `recipe.enabled` (for example a computer whose recipe asks for a
-- memory generation from two eras later).
--
-- The suite runs on its own force so the research state the other probes
-- examine on the player force is untouched. The final Answer Engine run uses
-- the same force, so the whole loop - early ladder, megabase gate, 42-minute
-- computation, victory - is one continuous playthrough.

local PT_TECHS = {
  "vlsi-process",
  "process-350nm",
  "datacenter",
  "advanced-packaging",
  "qln",
  "process-180nm",
  "process-90nm",
  "heterogeneous-compute",
  "quantum-computing",
  "process-45nm",
  "quantum-error-correction",
  "process-22nm",
  "process-14nm",
  "process-7nm",
  "qln-quantum",
  "quantum-advantage",
  "process-3nm",
  "process-1-4nm",
  "the-question",
}

local PT_AREA = { { 96, 76 }, { 166, 98 } }
local PT_CABLE_Y = 82
local PT_FORCE = "chiptorio-playthrough"
local PT_MAX_PROVIDERS = 13

--- True when `item_name` has no recipe (a raw resource or fluid), or its recipe
--- and every ingredient recipe are unlocked on this force. A recipe cycle is
--- treated as satisfied: vanilla barrel recipes are the usual case.
local function pt_craftable(force, item_name, visiting)
  if visiting[item_name] then
    return true
  end
  local recipe = force.recipes[item_name]
  if not recipe then
    return true
  end
  if not recipe.enabled then
    return false
  end
  visiting[item_name] = true
  for _, ingredient in pairs(recipe.ingredients) do
    if not pt_craftable(force, ingredient.name, visiting) then
      visiting[item_name] = nil
      return false
    end
  end
  visiting[item_name] = nil
  return true
end

--- Every computer module this force can build right now, with its profile.
local function pt_available_computers(force)
  local list = {}
  for _, computer in ipairs(computers_meta.COMPUTERS) do
    local profile = research_meta.COMPUTER_PROFILES[computer.name]
    if profile and pt_craftable(force, computer.name, {}) then
      list[#list + 1] = { name = computer.name, profile = profile, heat = profile.heat or 0 }
    end
  end
  return list
end

--- The best provider chassis this force can build: a datacenter once the
--- datacenter technology is done, otherwise the internet-era server rack.
local function pt_provider(force)
  for _, name in ipairs({ "datacenter", "server-rack" }) do
    if pt_craftable(force, name, {}) then
      return name
    end
  end
  return nil
end

--- Greedy, cooling-aware bench planner. It adds the computer that covers the
--- largest share of the remaining gate until the gate is met, and adds a
--- provider whenever the chassis cooling budget or the module slots run out.
--- Returns provider count, a flat list of computer names, and the totals.
local function pt_plan(spec, available, provider)
  local profile = research_meta.PROVIDERS[provider]
  local headroom = (profile.cooling or 0) - (profile.heat or 0)
  local slots = profile.computer_slots or 0
  if headroom <= 0 or slots <= 0 then
    return nil
  end

  local totals = {
    scalar = 0,
    vector = 0,
    tensor = 0,
    quantum = 0,
    memory = 0,
    bandwidth = 0,
    heat = 0,
  }
  local plan = {}
  local providers = 1

  local function met()
    for _, kind in ipairs(research_meta.COMPUTE_PROFILES) do
      local share = (spec.profiles or {})[kind] or 0
      if share > 0 and (totals[kind] or 0) / share < spec.floor then
        return false
      end
    end
    if (spec.memory or 0) > totals.memory then
      return false
    end
    if (spec.bandwidth or 0) > totals.bandwidth + providers * (profile.bandwidth or 0) then
      return false
    end
    return true
  end

  local function score(candidate)
    local sum, lines = 0, 0
    for _, kind in ipairs(research_meta.COMPUTE_PROFILES) do
      local share = (spec.profiles or {})[kind] or 0
      if share > 0 then
        local need = spec.floor * share
        local missing = need - (totals[kind] or 0)
        if missing > 0 then
          sum = sum + math.min(missing, candidate.profile[kind] or 0) / need
        end
        lines = lines + 1
      end
    end
    if (spec.memory or 0) > totals.memory then
      sum = sum + math.min(spec.memory - totals.memory, candidate.profile.capacity or 0) / spec.memory
    end
    lines = lines + 1
    local have_bandwidth = totals.bandwidth + providers * (profile.bandwidth or 0)
    if (spec.bandwidth or 0) > have_bandwidth then
      sum = sum + math.min(spec.bandwidth - have_bandwidth, candidate.profile.bandwidth or 0) / spec.bandwidth
    end
    lines = lines + 1
    return sum / lines
  end

  local guard = 0
  while not met() do
    guard = guard + 1
    if guard > 500 then
      return nil, nil, totals
    end
    local best, best_score
    for _, candidate in ipairs(available) do
      if totals.heat + candidate.heat <= headroom * providers and #plan < slots * providers then
        local value = score(candidate)
        if value > (best_score or 0) + 1e-9 then
          best, best_score = candidate, value
        end
      end
    end
    if best and best_score and best_score > 1e-9 then
      plan[#plan + 1] = best.name
      totals.heat = totals.heat + best.heat
      for _, kind in ipairs(research_meta.COMPUTE_PROFILES) do
        totals[kind] = totals[kind] + (best.profile[kind] or 0)
      end
      totals.memory = totals.memory + (best.profile.capacity or 0)
      totals.bandwidth = totals.bandwidth + (best.profile.bandwidth or 0)
    elseif providers < PT_MAX_PROVIDERS then
      providers = providers + 1
    else
      return nil, nil, totals
    end
  end
  return providers, plan, totals
end

--- Place a bench on the shared cable row: one lab, N provider chassis and the
--- planned computers. `extras` adds the endgame entities before the build
--- events are raised.
local function pt_build_bench(surface, force, created, provider, providers, plan, extras)
  cable_run(surface, force, created, 99, 160, PT_CABLE_Y)
  place(surface, force, created, "analytical-engine", 100.5, 80.5)
  local index = 0
  local slots = research_meta.PROVIDERS[provider].computer_slots or 0
  for i = 1, providers do
    local entity = place(surface, force, created, provider, 104.5 + (i - 1) * 4, 80.5)
    if entity then
      local modules = entity.get_module_inventory()
      for _ = 1, slots do
        index = index + 1
        if not plan[index] then
          break
        end
        modules.insert({ name = plan[index], count = 1 })
      end
    end
  end
  if extras then
    extras(created)
  end
  raise_built(created)
end

local function pt_describe(available, provider, providers, totals)
  local names = {}
  for _, computer in ipairs(available) do
    names[#names + 1] = computer.name
  end
  return string.format(
    "parts=[%s] provider=%s providers=%d scalar=%d vector=%d tensor=%d quantum=%d memory=%d bandwidth=%d heat=%d/%d",
    table.concat(names, ","),
    tostring(provider),
    providers or 0,
    totals and totals.scalar or 0,
    totals and totals.vector or 0,
    totals and totals.tensor or 0,
    totals and totals.quantum or 0,
    totals and totals.memory or 0,
    totals and totals.bandwidth or 0,
    totals and totals.heat or 0,
    provider and (research_meta.PROVIDERS[provider].cooling or 0) * (providers or 0) or 0
  )
end

--- Research every prerequisite that is not itself a gated technology. The
--- gated ones must be reached through the loop, so a prerequisite that is
--- still unresearched there is a real ordering failure.
local function pt_unlock_prereqs(force, tech, gated)
  for _, prereq in pairs(tech.prerequisites or {}) do
    if not prereq.researched then
      if gated[prereq.name] then
        check(false, tech.name .. " requires gated " .. prereq.name .. " before its own gate")
        prereq.research_recursive()
      else
        prereq.research_recursive()
      end
    end
  end
end

local function check_playthrough()
  local first_failure = #failures + 1
  local surface = game.surfaces[1]
  local force = game.forces[PT_FORCE] or game.create_force(PT_FORCE)
  check(force, "could not create the playthrough force")
  if not force then
    return
  end
  clear_area(surface, PT_AREA)

  -- Early game: the chain behind the first gated technology has no compute
  -- gate, so a player researches it with the analytical engine alone.
  local gated = {}
  for _, name in ipairs(PT_TECHS) do
    gated[name] = true
  end
  local first = force.technologies[PT_TECHS[1]]
  check(first, "missing the first gated technology " .. PT_TECHS[1])
  if not first then
    return
  end
  for _, prereq in pairs(first.prerequisites or {}) do
    if not prereq.researched then
      prereq.research_recursive()
    end
  end

  local created = {}
  for _, name in ipairs(PT_TECHS) do
    local tech = force.technologies[name]
    check(tech and not tech.researched, "technology is missing or already researched: " .. name)
    if not tech then
      break
    end

    pt_unlock_prereqs(force, tech, gated)

    local spec = research_meta.tech_spec(name)
    check(spec, "the-playthrough has no gate spec for " .. name)
    if not spec then
      break
    end

    local available = pt_available_computers(force)
    local provider = pt_provider(force)
    local providers, plan, totals = nil, nil, nil
    if provider and #available > 0 then
      providers, plan, totals = pt_plan(spec, available, provider)
    end
    check(
      providers and plan,
      "no craftable bench can meet the " .. name .. " gate (" .. pt_describe(available, provider, providers, totals) .. ")"
    )

    destroy_all(created)
    created = {}
    if providers and plan then
      pt_build_bench(surface, force, created, provider, providers, plan)
      local result = remote.call("chiptorio-research", "evaluate", name, force.index)
      check(
        result and result.supported == true,
        "the real " .. name .. " gate failed (reason=" .. tostring(result and result.reason) .. ", "
          .. pt_describe(available, provider, providers, totals) .. ")"
      )
    end

    if tech.prototype.max_level == "infinite" then
      -- Finish the way a player does: queue the research and complete it
      -- through the normal research path. `research_recursive` is a debug
      -- shortcut whose level accounting for infinite technologies is not the
      -- same as a real completion, and the Answer Engine reads that level.
      check(force.add_research(name) ~= false, "could not queue the infinite research " .. name)
      force.research_progress = 1
    else
      tech.research_recursive()
    end

    -- Unlock-order diagnostics. A recipe whose ingredients are still locked is
    -- not always a deadlock (the missing part may arrive one era later), but a
    -- player would not be able to build what the technology just announced.
    local gaps = {}
    for _, effect in pairs(tech.prototype.effects or {}) do
      if effect.type == "unlock-recipe" then
        local recipe = force.recipes[effect.recipe]
        if recipe and not pt_craftable(force, effect.recipe, {}) then
          gaps[#gaps + 1] = effect.recipe
        end
      end
    end
    if #gaps > 0 then
      log(
        "CHIPTORIO-TEST INFO playthrough: "
          .. name
          .. " unlocked recipes that are not craftable yet: "
          .. table.concat(gaps, ", ")
      )
    end
  end

  -- Endgame. The Answer Engine gate is every compute profile at 128, memory
  -- 2048 and bandwidth 512. Express it as a weighted floor so the same planner
  -- sizes the megabase network: share = required amount, floor = 1.
  --
  -- `the-question` is infinite and the engine scales every requirement by
  -- `rate_scale_per_level` per level, so read the level the playthrough just
  -- reached instead of planning against level 1. Planning against the unscaled
  -- numbers is exactly how a real megabase ends up one scalar generation short.
  local question = force.technologies["the-question"]
  -- Mirror the engine's accounting: for an infinite technology `level` is the
  -- level being researched next, so completed levels are `level - 1`.
  local completed_levels = math.max(0, (question and question.level or 1) - 1)
  local answer_scale = 1 + answer_meta.rate_scale_per_level * math.max(0, completed_levels - 1)
  local answer_spec = {
    floor = 1,
    profiles = {
      scalar = math.ceil(answer_meta.compute.scalar * answer_scale),
      vector = math.ceil(answer_meta.compute.vector * answer_scale),
      tensor = math.ceil(answer_meta.compute.tensor * answer_scale),
      quantum = math.ceil(answer_meta.compute.quantum * answer_scale),
    },
    memory = math.ceil(answer_meta.memory * answer_scale),
    bandwidth = math.ceil(answer_meta.bandwidth * answer_scale),
  }
  local available = pt_available_computers(force)
  local provider = pt_provider(force)
  local providers, plan, totals = nil, nil, nil
  if provider and #available > 0 then
    providers, plan, totals = pt_plan(answer_spec, available, provider)
  end
  check(
    providers and plan,
    "no craftable bench can meet the Answer Engine gate ("
      .. pt_describe(available, provider, providers, totals)
      .. ")"
  )
  log(string.format(
    "CHIPTORIO-TEST INFO playthrough: endgame level=%d scale=%.2f plan=%d computers in %d providers",
    completed_levels,
    answer_scale,
    plan and #plan or 0,
    providers or 0
  ))

  destroy_all(created)
  created = {}
  local engine, drive
  if providers and plan then
    pt_build_bench(surface, force, created, provider, providers, plan, function(list)
      drive = place(surface, force, list, "qln-storage-drive", 152.5, 84.5)
      engine = place(surface, force, list, "answer-engine", 157.5, 86.5)
    end)
  end

  if engine and drive then
    local inserted = drive.get_module_inventory().insert({ name = "3d-nand-module", count = 4 })
    check(inserted == 4, "could not install four 3d-nand modules in the Answer Storage Drive: " .. tostring(inserted))

    qln_step(2)

    local total_required = 0
    for _, req in ipairs(answer_meta.item_demand) do
      total_required = total_required + math.ceil(req.rate * answer_scale * answer_meta.runtime_seconds)
    end

    local group
    for _, entry in ipairs(remote.call("chiptorio-qln", "state", force.name) or {}) do
      if entry.capacity >= total_required and (not group or entry.capacity > group.capacity) then
        group = entry
      end
    end
    check(group, "the playthrough Storage Drive did not create a QLN group with room for " .. total_required .. " items")
    if group then
      local _, network_id = string.match(group.key, "^(%d+):(%d+):")
      local deposited = 0
      for _, req in ipairs(answer_meta.item_demand) do
        local want = math.ceil(req.rate * answer_scale * answer_meta.runtime_seconds) + 200
        deposited = deposited + remote.call(
          "chiptorio-qln",
          "deposit",
          force.name,
          surface.index,
          tonumber(network_id),
          req.item,
          want
        )
      end
      check(
        deposited >= total_required,
        "deposited " .. tostring(deposited) .. " of " .. tostring(total_required) .. " Answer items"
      )

      local gate = remote.call("chiptorio-answer", "evaluate")
      if not (gate and gate.ok) then
        local failed = {}
        for _, line in ipairs(gate and gate.lines or {}) do
          if not line.ok then
            failed[#failed + 1] = string.format(
              "%s %s have=%.0f need=%.0f",
              line.kind,
              tostring(line.profile or line.item),
              line.have or 0,
              line.required or 0
            )
          end
        end
        log("CHIPTORIO-TEST INFO playthrough: answer gate closed: " .. table.concat(failed, "; "))
        log("CHIPTORIO-TEST INFO playthrough: answer bench " .. pt_describe(available, provider, providers, totals))
        local topo = remote.call("chiptorio-network", "topology", surface.index)
        log(string.format(
          "CHIPTORIO-TEST INFO playthrough: answer network providers=%s labs=%s scalar=%s vector=%s tensor=%s quantum=%s memory=%s bandwidth=%s heat=%s cooling=%s",
          tostring(topo.providers),
          tostring(topo.labs),
          tostring(topo.scalar),
          tostring(topo.vector),
          tostring(topo.tensor),
          tostring(topo.quantum),
          tostring(topo.memory),
          tostring(topo.bandwidth),
          tostring(topo.heat),
          tostring(topo.cooling)
        ))
      end
      check(gate and gate.ok == true, "the Answer Engine gate did not open on the playthrough network")
      check(remote.call("chiptorio-answer", "boot") == true, "the Answer Engine did not boot")

      local used_before = 0
      for _, entry in ipairs(remote.call("chiptorio-qln", "state", force.name) or {}) do
        if entry.key == group.key then
          used_before = entry.used
        end
      end
      check(
        remote.call("chiptorio-answer", "step", answer_meta.runtime_seconds) == answer_meta.runtime_seconds,
        "the Answer Engine clock hook did not advance a full run"
      )
      local final = remote.call("chiptorio-answer", "evaluate")
      check(final and final.state == "complete", "the Answer Engine did not complete: " .. tostring(final and final.state))
      check(
        final and final.elapsed == final.duration,
        "the completed Answer clock is at " .. tostring(final and final.elapsed)
      )
      check(
        final and final.score >= answer_meta.score_per_level,
        "the playthrough scored " .. tostring(final and final.score)
      )
      local after = remote.call("chiptorio-qln", "state", force.name) or {}
      local remaining = 0
      for _, entry in ipairs(after) do
        if entry.key == group.key then
          remaining = entry.used
        end
      end
      check(
        remaining <= used_before - total_required,
        "the Answer Engine consumed " .. tostring(used_before - remaining) .. " of " .. tostring(total_required) .. " items"
      )
    end
  end

  destroy_all(created)

  if #failures >= first_failure then
    local mine = {}
    for i = first_failure, #failures do
      mine[#mine + 1] = failures[i]
    end
    log("CHIPTORIO-TEST FAIL playthrough: " .. table.concat(mine, "; "))
  else
    log("CHIPTORIO-TEST PASS playthrough")
  end
end

-- ---------------------------------------------------------------------------
-- Save/load probe (P1.2)
-- ---------------------------------------------------------------------------
-- A `--benchmark` run loads a save and ticks it, but it cannot prove that
-- runtime state survived serialisation on its own. This probe runs in two
-- processes:
--
--   1. A headless server (`--start-server`) builds a small state: a QLN drive
--      with four SRAM cells and a deposit, a qualified half-node, and a real
--      two-level infinite research completion. It writes `chiptorio-reload.zip`
--      with `game.server_save` and marks `storage.save_load.phase = "saved"`.
--   2. `tools/test-save-load.ps1` benchmarks that zip. The phase marker is
--      inside the save, so the reload process verifies every value against the
--      snapshot taken before saving and logs `PASS save-load`.
--
-- The whole probe runs on its own force so the player force's research,
-- qualification and QLN state are left exactly as the tick-120 suites expect.

local SAVE_LOAD_FORCE = "chiptorio-saveload"
local SAVE_LOAD_AREA = { { 40, 80 }, { 88, 100 } }
local SAVE_LOAD_CABLE_Y = 88

--- Queue one level of chip-performance and complete it through the engine. The
--- research bar is only consumed at the end of the tick, so this is called once
--- per probe tick until the stored level reaches 2.
local function save_load_queue_level(force)
  local chiptech = force.technologies["chip-performance"]
  if not chiptech then
    check(false, "missing chip-performance on the save-load force")
    return
  end
  -- `research_recursive` does not necessarily propagate the enabled flag to
  -- dependants in the same tick; the data guard has already proved the
  -- prerequisite chain is finite, so enabling it here is legitimate.
  chiptech.enabled = true
  if force.current_research and force.current_research.name == "chip-performance" then
    force.research_progress = 1
    return
  end
  check(
    force.add_research("chip-performance") ~= false,
    "could not queue chip-performance on the save-load force"
  )
  force.research_progress = 1
end

local function save_load_build()
  local surface = game.surfaces[1]
  local force = game.forces[SAVE_LOAD_FORCE] or game.create_force(SAVE_LOAD_FORCE)
  if not force then
    check(false, "could not create the save-load force")
    return
  end
  clear_area(surface, SAVE_LOAD_AREA)

  local created = {}
  cable_run(surface, force, created, 44, 60, SAVE_LOAD_CABLE_Y)
  local drive = place(surface, force, created, "qln-storage-drive", 46.5, 86.5)
  local metrology = place(surface, force, created, "metrology-lab", 50.5, 86.5)
  local rack = place(surface, force, created, "server-rack", 54.5, 86.5)
  local bank = place(surface, force, created, "memory-bank", 58.5, 86.5)
  if not (drive and metrology and rack and bank) then
    destroy_all(created)
    return
  end

  local inserted = drive.get_module_inventory().insert({ name = "sram-module", count = 4 })
  check(inserted == 4, "could not install 4 SRAM modules in the save-load drive: " .. tostring(inserted))
  rack.get_module_inventory().insert({ name = "microcomputer", count = 1 })
  bank.get_module_inventory().insert({ name = "sram-module", count = 4 })
  raise_built(created)

  -- The map has no power grid; fill the buffer so the power gate passes. The
  -- probe tests serialisation, not electricity.
  metrology.energy = 1e9

  -- Qualification of the first half-node (offline, 6 µm era).
  local half = nodes.HALF_NODES[1]
  local inventory = metrology.get_inventory(defines.inventory.lab_input)
  check(inventory, "save-load metrology-lab has no lab input inventory")
  if inventory then
    local tech = force.technologies[nodes.half_tech_name(half.key)]
    check(tech, "missing refinement technology on the save-load force: " .. nodes.half_tech_name(half.key))
    if tech then
      tech.research_recursive()
    end
    inventory.insert({ name = nodes.qualification_item(half.key), count = half.samples })
    remote.call("chiptorio-qualification", "step", half.samples * half.analysis_time * 2)
  end

  -- A real infinite-research completion, twice: `add_research` + setting the
  -- progress bar finishes a level through the engine, which is the only path
  -- that raises `on_research_finished` and the scripted multiplier. Completion
  -- lands at the end of the tick, so the handler queues the second level on the
  -- next probe tick rather than in this callback.
  local process = force.technologies["process-1-4nm"]
  check(process, "missing process-1-4nm on the save-load force")
  if process then
    process.research_recursive()
  end

  -- QLN: the drive contributes a storage group; a deposit proves item counts
  -- are serialised, not just the capacity.
  qln_step(1)
  local group = force_group(SAVE_LOAD_FORCE, 1)
  check(group, "the save-load Storage Drive did not create a QLN group")
  if group then
    check(group.capacity == 4096, "save-load capacity was " .. tostring(group.capacity) .. ", expected 4096")
    check(qln_deposit(group, "solar-panel", 12, SAVE_LOAD_FORCE) == 12,
      "could not deposit 12 solar panels into the save-load group")
  end

  if #failures > 0 then
    error("CHIPTORIO-TEST FAIL save-load: " .. table.concat(failures, "; "))
  end

  storage.save_load = {
    phase = "researching",
    force = SAVE_LOAD_FORCE,
    area = SAVE_LOAD_AREA,
    attempts = 0,
  }
  save_load_queue_level(force)
  log("CHIPTORIO-TEST SAVE-RESEARCH 1")
end

local function save_load_finish()
  local surface = game.surfaces[1]
  local force = game.forces[SAVE_LOAD_FORCE]
  local half = nodes.HALF_NODES[1]
  check(force, "the save-load force disappeared before the snapshot")
  check(half, "the first half-node is missing")
  if not (force and half) then
    return
  end

  -- Rebuild after qualification and both infinite levels, then snapshot what
  -- the reload must reproduce exactly.
  local topo = topology(surface.index)
  check(topo and (topo.scalar or 0) > 0, "the save-load network has no compute")
  local infinite = remote.call("chiptorio-research", "infinite", force.index) or {}
  check(infinite["chip-performance"] == 2,
    "chip-performance reached level " .. tostring(infinite["chip-performance"]) .. ", expected 2")
  local multipliers = remote.call("chiptorio-research", "multipliers", force.index) or {}
  local expected_multiplier = research_meta.infinite_multiplier("chip-performance", 2)
  check(math.abs((multipliers.compute or 1) - expected_multiplier) < 1e-9,
    "chip-performance multiplier was " .. tostring(multipliers.compute)
      .. ", expected " .. tostring(expected_multiplier))

  local refined = nodes.items(nodes.refined_node(half.key))
  local wafer = force.recipes[refined.wafer]
  check(wafer, "missing refined wafer recipe on the save-load force: " .. tostring(refined.wafer))

  -- The graph reports hardware compute with the qualification bonus folded in.
  -- The infinite multiplier is applied later by the allocator, so it is checked
  -- through `multipliers` above rather than here.
  local expected_scalar = 8 * half.bonus.compute
  check(topo and math.abs((topo.scalar or 0) - expected_scalar) < 1e-6,
    "save-load scalar was " .. tostring(topo and topo.scalar) .. ", expected " .. tostring(expected_scalar))

  local group = force_group(SAVE_LOAD_FORCE, 1)

  if #failures > 0 then
    error("CHIPTORIO-TEST FAIL save-load: " .. table.concat(failures, "; "))
  end

  storage.save_load = {
    phase = "saved",
    force = SAVE_LOAD_FORCE,
    area = SAVE_LOAD_AREA,
    expected = {
      half = half.key,
      scalar = topo and topo.scalar or 0,
      capacity = group and group.capacity or 0,
      items = group and (group.items["solar-panel"] or 0) or 0,
      infinite = 2,
      compute_multiplier = multipliers.compute or 1,
      wafer_bonus = wafer and wafer.productivity_bonus or 0,
      yield_bonus = half.bonus.yield - 1,
    },
  }

  local ok, err = pcall(function()
    game.server_save("chiptorio-reload")
  end)
  if not ok then
    check(false, "game.server_save failed: " .. tostring(err))
    return
  end
  log("CHIPTORIO-TEST SAVE-READY chiptorio-reload")
end

local function save_load_advance()
  local state = storage.save_load
  local force = game.forces[state.force or SAVE_LOAD_FORCE]
  if not force then
    error("CHIPTORIO-TEST FAIL save-load: the save-load force disappeared while researching")
  end
  local infinite = remote.call("chiptorio-research", "infinite", force.index) or {}
  local level = infinite["chip-performance"] or 0
  state.attempts = (state.attempts or 0) + 1
  if level >= 2 then
    save_load_finish()
    return
  end
  if state.attempts > 10 then
    error("CHIPTORIO-TEST FAIL save-load: chip-performance stopped at level " .. tostring(level))
  end
  save_load_queue_level(force)
end

local function save_load_verify()
  local state = storage.save_load
  local expected = state and state.expected
  check(expected, "the reloaded save has no save-load snapshot")
  if not expected then
    return
  end

  local surface = game.surfaces[1]
  local force = game.forces[state.force or SAVE_LOAD_FORCE]
  check(force, "the save-load force did not survive the reload")
  if not force then
    return
  end

  local half = nodes.half_node(expected.half)
  check(half, "the snapshot half-node no longer exists: " .. tostring(expected.half))

  -- QLN item counts and capacity.
  local group = force_group(force.name, 1)
  check(group, "the save-load QLN group did not survive the reload")
  if group then
    check(group.capacity == expected.capacity,
      "reloaded QLN capacity was " .. tostring(group.capacity) .. ", expected " .. tostring(expected.capacity))
    check((group.items["solar-panel"] or 0) == expected.items,
      "reloaded QLN items were " .. tostring(group.items["solar-panel"] or 0) .. ", expected " .. tostring(expected.items))
  end

  -- Qualification state and its recipe productivity bonus.
  local qualification = remote.call("chiptorio-qualification", "state", force.index)
  check(qualification, "qualification state did not survive the reload")
  if qualification then
    local qualified = false
    for _, key in ipairs(qualification.qualified or {}) do
      if key == expected.half then
        qualified = true
      end
    end
    check(qualified, "the qualified half-node " .. tostring(expected.half) .. " did not survive the reload")
  end
  if half then
    local refined = nodes.items(nodes.refined_node(half.key))
    local wafer = force.recipes[refined.wafer]
    check(wafer, "missing reloaded wafer recipe: " .. tostring(refined.wafer))
    if wafer then
      check(math.abs(wafer.productivity_bonus - expected.yield_bonus) < 1e-6,
        "reloaded wafer bonus was " .. tostring(wafer.productivity_bonus) .. ", expected " .. tostring(expected.yield_bonus))
    end
  end

  -- Infinite research level and the multiplier it feeds into the allocator.
  local infinite = remote.call("chiptorio-research", "infinite", force.index) or {}
  check(infinite["chip-performance"] == expected.infinite,
    "reloaded chip-performance level was " .. tostring(infinite["chip-performance"])
      .. ", expected " .. tostring(expected.infinite))
  local multipliers = remote.call("chiptorio-research", "multipliers", force.index) or {}
  check(math.abs((multipliers.compute or 1) - expected.compute_multiplier) < 1e-9,
    "reloaded compute multiplier was " .. tostring(multipliers.compute)
      .. ", expected " .. tostring(expected.compute_multiplier))
  local topo = topology(surface.index)
  check(topo, "topology returned nothing after the reload")
  if topo then
    check(math.abs((topo.scalar or 0) - expected.scalar) < 1e-6,
      "reloaded scalar compute was " .. tostring(topo.scalar) .. ", expected " .. tostring(expected.scalar))
  end

  finish("save-load")
end

-- ---------------------------------------------------------------------------
-- Real power grid probe (P1.7)
-- ---------------------------------------------------------------------------
-- The Construction Core is an accumulator clone: `entity.energy` is its work
-- budget and it refills from the grid while idle. The construction suite writes
-- energy directly so it can test mining in one tick; this staged check proves
-- the electrical path instead. A solar panel charges the core across real ticks,
-- then the panel is removed and the core must hold its charge.
--
-- This suite only exists in the hosted server started by test-power-grid.ps1,
-- because a benchmark raises tick handlers at tick 0 only. It keeps its own
-- failure list so a power-grid failure logs `FAIL power-grid` instead of being
-- attributed to whichever suite calls `finish` next.

local POWER_GRID_AREA = { { 178, 42 }, { 196, 56 } }
local power_grid_failures = {}

local function pcheck(condition, message)
  if not condition then
    power_grid_failures[#power_grid_failures + 1] = message
  end
end

local function pfinish(suite)
  if #power_grid_failures > 0 then
    error("CHIPTORIO-TEST FAIL " .. suite .. ": " .. table.concat(power_grid_failures, "; "))
  end
  log("CHIPTORIO-TEST PASS " .. suite)
end

local function power_grid_build()
  local surface = game.surfaces[1]
  local force = game.forces.player
  clear_area(surface, POWER_GRID_AREA)

  local created = {}
  local function create(name, x, y)
    local entity = surface.create_entity({ name = name, position = { x, y }, force = force })
    pcheck(entity, "could not place " .. name .. " at " .. x .. "," .. y)
    if entity then
      created[#created + 1] = entity
    end
    return entity
  end

  -- The pole's 5x5 supply area covers the centre of the neighbour, which is
  -- how an accumulator joins the electric network.
  local core = create("construction-core", 182.5, 46.5)
  local pole = create("small-electric-pole", 184.5, 46.5)
  if not (core and pole) then
    for _, entity in ipairs(created) do
      if entity.valid then
        entity.destroy()
      end
    end
    return
  end

  -- Start empty.
  core.energy = 0
  storage.power_grid = { phase = "charging", core = core, entities = created }
end

local function power_grid_advance()
  local state = storage.power_grid
  local core = state.core
  pcheck(core and core.valid, "the Construction Core disappeared during the power-grid check")
  if not (core and core.valid) then
    storage.power_grid = nil
    script.on_nth_tick(60, nil)
    pfinish("power-grid")
    return
  end

  if state.phase == "charging" then
    -- Inject energy into the network's accumulators. The core is on the pole's
    -- network, so this should flow into it.
    local net = core.electric_network
    pcheck(net, "the Construction Core is not connected to an electric network")
    if net then
      net.set_accumulators_energy({ energy = 8000 })
    end
    pcheck(core.energy >= 8000,
      "the Construction Core did not receive energy from the network: energy=" .. tostring(core.energy))

    -- Disconnect from the network by removing the pole. The isolated core
    -- must hold its charge (accumulators do not leak when unconnected).
    state.core_energy = core.energy
    for _, entity in ipairs(state.entities) do
      if entity.valid and entity ~= core then
        raise(defines.events.script_raised_destroy, entity)
        entity.destroy()
      end
    end
    state.phase = "removed"
    return
  end

  pcheck(math.abs(core.energy - state.core_energy) < 1e-6,
    "the Construction Core recharged without a grid: energy=" .. tostring(core.energy)
      .. ", expected " .. tostring(state.core_energy))
  if core.valid then
    raise(defines.events.script_raised_destroy, core)
    core.destroy()
  end
  storage.power_grid = nil
  script.on_nth_tick(60, nil)
  pfinish("power-grid")
end

script.on_init(function()
  local map = game.map_settings
  check(map.enemy_evolution and map.enemy_evolution.enabled == false, "enemy evolution is enabled")
  check(map.enemy_expansion and map.enemy_expansion.enabled == false, "enemy expansion is enabled")
  check(map.pollution and map.pollution.enabled == false, "pollution is enabled")
  check(remote.interfaces["chiptorio-answer"], "missing chiptorio-answer remote interface")
  finish("runtime-init")
end)

-- Runs before the tick-120 suites. On the save/load server it builds and saves;
-- in the reload benchmark it verifies and logs PASS save-load. A normal
-- benchmark has neither a save-load marker nor the server flag, so it is a
-- no-op there.
script.on_nth_tick(15, function()
  local state = storage.save_load
  if state and state.phase == "saved" then
    if not state.verified then
      state.verified = true
      save_load_verify()
    end
    return
  end
  if state and state.phase == "researching" then
    save_load_advance()
    return
  end
  if state then
    return
  end
  if SERVER_SUITE ~= "save-load" then
    return
  end
  save_load_build()
end)

-- One call per real second: build at tick 0, check the charge (and drop the
-- producer) at tick 60, then prove the isolated buffer holds at tick 120.
if SERVER_SUITE == "power-grid" then
  script.on_nth_tick(60, function()
    local state = storage.power_grid
    if not state or not state.armed then
      -- A map built by --create can leave a half-built state in the save. Start
      -- the measured window from this server process instead.
      if state and state.entities then
        for _, entity in ipairs(state.entities) do
          if entity.valid then
            entity.destroy()
          end
        end
      end
      power_grid_build()
      if not storage.power_grid then
        pfinish("power-grid")
        return
      end
      storage.power_grid.armed = true
      return
    end
    power_grid_advance()
  end)
end

script.on_nth_tick(120, function()
  -- Server suites and the reload benchmark are not second contract runs.
  if SERVER_SUITE or storage.save_load then
    return
  end
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
  check_isolation()
  check_answer()
  check_ai()
  check_computer_gui()
  check_playthrough()
  finish("runtime")
end)
