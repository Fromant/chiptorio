-- Runtime entry point.
--
-- Factorio keeps one handler per event, so every module exposes plain
-- functions and this file owns the registration and the single tick
-- dispatcher. Do not register script.on_init, script.on_event, or
-- script.on_nth_tick from a module: a later registration silently replaces an
-- earlier one.

local answer_engine = require("scripts.answer_engine")
local enemy_cleanup = require("scripts.enemy_cleanup")
local network = require("scripts.runtime.network_runtime")
local research = require("scripts.runtime.research_runtime")

script.on_init(function()
  answer_engine.init_storage()
  enemy_cleanup.on_init()
  network.on_init()
  research.on_init()
end)

script.on_configuration_changed(function()
  answer_engine.init_storage()
  enemy_cleanup.on_configuration_changed()
  network.on_configuration_changed()
  research.on_configuration_changed()
end)

script.on_nth_tick(60, function()
  answer_engine.tick()
  network.tick()
  -- Network first: the allocator reads the freshly rebuilt graph.
  research.tick()
end)

-- Network topology only needs to know that *something* changed. The graph is
-- rebuilt at most once per second by the dispatcher above. Register each event
-- explicitly: a nil entry inside an ipairs list would silently stop the loop.
script.on_event(defines.events.on_built_entity, network.on_built)
script.on_event(defines.events.on_robot_built_entity, network.on_built)
script.on_event(defines.events.script_raised_built, network.on_built)
script.on_event(defines.events.script_raised_revive, network.on_built)

-- Network entities have no fast_replaceable_group, so a fast replace can never
-- remove one. The build events above already cover every way wiring appears.

script.on_event(defines.events.on_player_mined_entity, network.on_removed)
script.on_event(defines.events.on_robot_mined_entity, network.on_removed)
script.on_event(defines.events.on_entity_died, network.on_removed)
script.on_event(defines.events.script_raised_destroy, network.on_removed)
script.on_event(defines.events.on_pre_player_mined_item, network.on_removed)

script.on_event(defines.events.on_gui_opened, function(event)
  answer_engine.on_gui_opened(event)
  network.on_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  answer_engine.on_gui_closed(event)
  network.on_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
  answer_engine.on_gui_click(event)
  network.on_gui_click(event)
end)

script.on_event(defines.events.on_lua_shortcut, network.on_lua_shortcut)
script.on_event("chiptorio-network-overlay", network.on_toggle_overlay)

remote.add_interface("chiptorio-network", {
  -- /c remote.call("chiptorio-network", "status")
  status = network.status,
  topology = network.summary,
  -- /c remote.call("chiptorio-network", "overlay", true)
  -- Custom-input events cannot be raised from script, so the overlay tests and
  -- debug hooks go through this instead of faking a keypress.
  overlay = network.set_overlay,
})

remote.add_interface("chiptorio-research", {
  -- /c remote.call("chiptorio-research", "status")
  status = research.status,
  -- /c remote.call("chiptorio-research", "evaluate", "vlsi-process")
  evaluate = research.evaluate,
  -- /c remote.call("chiptorio-research", "step", 60)
  step = research.step,
})
