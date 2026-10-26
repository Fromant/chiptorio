-- Runtime contract probe. Runs after chiptorio's on_init on a fresh map and
-- checks that the enemy/robot removal is real, not just hidden prototypes, and
-- that the network graph builds from real entities.

local failures = {}

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
  finish("runtime")
end)
