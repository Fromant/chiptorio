-- Runtime contract probe. Runs after chiptorio's on_init on a fresh map and
-- checks that the enemy/robot removal is real, not just hidden prototypes.

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

  finish("runtime")
end)
