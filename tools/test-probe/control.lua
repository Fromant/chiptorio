-- Runtime contract probe. Runs after chiptorio's on_init on a fresh map and
-- checks that the enemy/robot removal is real, not just hidden prototypes, and
-- that the network graph builds from real entities.

local failures = {}

local nodes = require("__chiptorio__/scripts/process_nodes")

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
  return remote.call("chiptorio-network", "topology", surface_index)
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
    check(before.subnets == 2, "expected 2 subnets but got " .. tostring(before.subnets))
    check(before.networks == 1, "expected 1 network but got " .. tostring(before.networks))
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
  local player = game.players[1]
  local monitor = surface.create_entity({ name = "network-monitor", position = { 52.5, 51.5 }, force = force })
  check(monitor, "could not place network-monitor")
  if monitor and player then
    raise(defines.events.script_raised_built, monitor)
    player.opened = monitor
    check(player.gui.screen["chiptorio-network-monitor"], "monitor window did not open")
    player.opened = nil
    check(not player.gui.screen["chiptorio-network-monitor"], "monitor window did not close")
    monitor.destroy()
  end

  raise(defines.events.script_raised_destroy, left)
  left.destroy()

  local after = topology(surface.index)
  check(after, "topology returned nothing after removal")
  if after then
    check(after.cable_count == 1, "expected 1 cable tile after removal but got " .. tostring(after.cable_count))
    check(after.subnets == 1, "expected 1 subnet after removal but got " .. tostring(after.subnets))
    check(after.networks == 1, "expected 1 network after removal but got " .. tostring(after.networks))
  end

  router.destroy()
  right.destroy()
end

-- Exercise the research path end to end: a datacenter full of chips, a memory
-- bank full of SRAM and an analytical engine on the same cable run. The
-- allocator must support vlsi-process, pause the lab when memory disappears,
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

  datacenter.get_module_inventory().insert({ name = "integrated-circuit", count = 8 })
  bank.get_module_inventory().insert({ name = "sram-module", count = 4 })

  for _, entity in ipairs(created) do
    raise(defines.events.script_raised_built, entity)
  end

  local topo = topology(surface.index)
  check(topo, "topology returned nothing after research setup")
  if topo then
    check(topo.providers == 2, "expected 2 providers but got " .. tostring(topo.providers))
    check(topo.labs == 1, "expected 1 lab but got " .. tostring(topo.labs))
    check(topo.scalar == 8, "expected 8 scalar compute but got " .. tostring(topo.scalar))
    check(topo.memory == 64, "expected 64 memory capacity but got " .. tostring(topo.memory))
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

  datacenter.get_module_inventory().insert({ name = "integrated-circuit", count = 8 })
  local recovered = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(recovered, "research evaluate returned nothing after reinstalling chips")
  if recovered then
    check(recovered.supported == true, "vlsi-process should recover once chips are reinstalled")
    check(lab.disabled_by_script == false, "recovered lab must be enabled")
  end

  raise(defines.events.script_raised_destroy, bank)
  bank.destroy()

  local starved = remote.call("chiptorio-research", "evaluate", "vlsi-process")
  check(starved, "research evaluate returned nothing without memory")
  if starved then
    check(starved.supported == false, "vlsi-process must not run without memory")
    check(starved.reason == "memory", "memory-starved reason was " .. tostring(starved.reason))
    check(
      math.abs(starved.decay - 0.02) < 1e-9,
      "memory starvation should decay at the maximum rate, got " .. tostring(starved.decay)
    )
    check(lab.disabled_by_script == true, "memory-starved lab must be paused")
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
  rack.get_module_inventory().insert({ name = "integrated-circuit", count = 4 })
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
  local boosted = topology(surface.index)
  check(boosted, "topology returned nothing after qualification")
  if boosted then
    local expected = 4 * first.bonus.compute
    check(math.abs(boosted.scalar - expected) < 1e-6,
      "scalar compute was " .. tostring(boosted.scalar) .. ", expected " .. tostring(expected))
    check(boosted.memory == 64, "memory capacity was scaled by the compute bonus: " .. tostring(boosted.memory))
  end

  -- 800 nm needs a network. A 4.2-scalar network must fail on compute even
  -- though the lab is connected, powered and has memory and bandwidth.
  local second_tech = force.technologies[nodes.half_tech_name(second.key)]
  check(second_tech, "missing refinement technology on the force: " .. nodes.half_tech_name(second.key))
  if second_tech then
    second_tech.research_recursive()
  end
  local gated = remote.call("chiptorio-qualification", "evaluate", second.key)
  check(gated, "qualification evaluate returned nothing for " .. second.key)
  if gated then
    check(gated.supported == false, second.key .. " should not run on 4.2 scalar")
    check(gated.reason == "compute", second.key .. " reason was " .. tostring(gated.reason))
  end

  -- Two microprocessors per slot clear the floor: 4 * 2 * 1.05 = 8.4 scalar.
  rack.get_module_inventory().clear()
  rack.get_module_inventory().insert({ name = "microprocessor", count = 4 })
  local recovered = remote.call("chiptorio-qualification", "evaluate", second.key)
  check(recovered, "qualification evaluate returned nothing after installing microprocessors")
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
  local expected_final = 4 * 2 * first.bonus.compute * second.bonus.compute
  check(final_topo and math.abs(final_topo.scalar - expected_final) < 1e-6,
    "stacked compute bonus was " .. tostring(final_topo and final_topo.scalar) .. ", expected " .. tostring(expected_final))

  for _, entity in ipairs(created) do
    if entity.valid then
      raise(defines.events.script_raised_destroy, entity)
      entity.destroy()
    end
  end
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
  finish("runtime")
end)
