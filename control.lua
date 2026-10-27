-- Runtime entry point.
--
-- Factorio keeps one handler per event, so every module exposes plain
-- functions and this file owns the registration and the single tick
-- dispatcher. Do not register script.on_init, script.on_event, or
-- script.on_nth_tick from a module: a later registration silently replaces an
-- earlier one.

local qln = require("scripts.runtime.qln_runtime")
local answer_engine = require("scripts.answer_engine")
local enemy_cleanup = require("scripts.enemy_cleanup")
local network = require("scripts.runtime.network_runtime")
local qualification = require("scripts.runtime.qualification_runtime")
local research = require("scripts.runtime.research_runtime")
local ai = require("scripts.runtime.ai_runtime")
local computer_gui = require("scripts.runtime.computer_gui")

script.on_init(function()
  answer_engine.init_storage()
  enemy_cleanup.on_init()
  network.on_init()
  qualification.on_init()
  research.on_init()
  qln.on_init()
  ai.init_storage()
end)

script.on_configuration_changed(function()
  answer_engine.init_storage()
  enemy_cleanup.on_configuration_changed()
  network.on_configuration_changed()
  qualification.on_configuration_changed()
  research.on_configuration_changed()
  qln.on_configuration_changed()
  ai.init_storage()
end)

script.on_nth_tick(60, function()
  answer_engine.tick()
  network.tick()
  -- Network first: qualification, QLN and the allocator read the freshly
  -- rebuilt graph. Qualification can complete a half-node and mark the graph
  -- dirty, so it runs before research and its chip multiplier is visible
  -- immediately. QLN transport runs after the graph so it uses this second's
  -- topology. AI runs last so it can consume from QLN storage and read the
  -- final network capacities.
  qualification.tick()
  qln.tick()
  research.tick()
  ai.tick()
end)

-- Network topology only needs to know that *something* changed. The graph is
-- rebuilt at most once per second by the dispatcher above. Register each event
-- explicitly: a nil entry inside an ipairs list would silently stop the loop.
script.on_event(defines.events.on_built_entity, function(event)
  network.on_built(event)
  qln.on_built(event)
  ai.on_built(event)
end)
script.on_event(defines.events.on_robot_built_entity, function(event)
  network.on_built(event)
  qln.on_built(event)
  ai.on_built(event)
end)
script.on_event(defines.events.script_raised_built, function(event)
  network.on_built(event)
  qln.on_built(event)
  ai.on_built(event)
end)
script.on_event(defines.events.script_raised_revive, function(event)
  network.on_built(event)
  qln.on_built(event)
  ai.on_built(event)
end)

-- Network entities have no fast_replaceable_group, so a fast replace can never
-- remove one. The build events above already cover every way wiring appears.

script.on_event(defines.events.on_player_mined_entity, function(event)
  network.on_removed(event)
  qln.on_removed(event)
  ai.on_removed(event)
end)
script.on_event(defines.events.on_robot_mined_entity, function(event)
  network.on_removed(event)
  qln.on_removed(event)
  ai.on_removed(event)
end)
script.on_event(defines.events.on_entity_died, function(event)
  network.on_removed(event)
  qln.on_removed(event)
  ai.on_removed(event)
end)
script.on_event(defines.events.script_raised_destroy, function(event)
  network.on_removed(event)
  qln.on_removed(event)
  ai.on_removed(event)
end)
script.on_event(defines.events.on_pre_player_mined_item, function(event)
  network.on_removed(event)
  qln.on_removed(event)
  ai.on_removed(event)
end)

script.on_event(defines.events.on_gui_opened, function(event)
  answer_engine.on_gui_opened(event)
  network.on_gui_opened(event)
  qln.on_gui_opened(event)
  computer_gui.on_gui_opened(event)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  answer_engine.on_gui_closed(event)
  network.on_gui_closed(event)
  qln.on_gui_closed(event)
  computer_gui.on_gui_closed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
  answer_engine.on_gui_click(event)
  network.on_gui_click(event)
  qln.on_gui_click(event)
  computer_gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_text_changed, qln.on_gui_text_changed)

script.on_event(defines.events.on_lua_shortcut, network.on_lua_shortcut)
script.on_event(defines.events.on_research_finished, function(event)
  local ok = pcall(function()
    if not event then return end
    local tech = event.research
    if not tech then return end
    local tech_name
    local name_ok = pcall(function() tech_name = tech.name end)
    if not name_ok or type(tech_name) ~= "string" then
      return
    end
    local force = event.force
    if not force and event.force_index then
      local f_ok = pcall(function() force = game.forces[event.force_index] end)
      if not f_ok then force = nil end
    end
    if not force then return end
    research.on_technology_researched(force, tech_name)
  end)
end)

if not remote.interfaces["chiptorio-network"] then
  remote.add_interface("chiptorio-network", {
    -- /c remote.call("chiptorio-network", "status")
    status = network.status,
    topology = network.summary,
    -- /c remote.call("chiptorio-network", "overlay", true)
    -- Custom-input events cannot be raised from script, so the overlay tests and
    -- debug hooks go through this instead of faking a keypress.
    overlay = network.set_overlay,
  })
end

if not remote.interfaces["chiptorio-research"] then
  remote.add_interface("chiptorio-research", {
    -- /c remote.call("chiptorio-research", "status")
    status = research.status,
    -- /c remote.call("chiptorio-research", "evaluate", "vlsi-process")
    evaluate = research.evaluate,
    -- /c remote.call("chiptorio-research", "step", 60)
    step = research.step,
  })
end

if not remote.interfaces["chiptorio-qualification"] then
  remote.add_interface("chiptorio-qualification", {
    -- /c remote.call("chiptorio-qualification", "status")
    status = qualification.status,
    -- /c remote.call("chiptorio-qualification", "state")
    state = qualification.state,
    -- /c remote.call("chiptorio-qualification", "evaluate", "6um")
    evaluate = qualification.evaluate,
    -- /c remote.call("chiptorio-qualification", "step", 600)
    step = qualification.step,
  })
end

-- chiptorio-qln and chiptorio-answer register their own interfaces from
-- scripts/runtime/qln_runtime.lua and scripts/answer_engine.lua. Registering
-- them here as well would silently replace the module's interface.

if not remote.interfaces["chiptorio-ai"] then
  remote.add_interface("chiptorio-ai", {
    -- /c remote.call("chiptorio-ai", "status")
    status = ai.status,
    -- /c remote.call("chiptorio-ai", "set_model", entity, "small-model")
    set_model = ai.set_model,
    -- /c remote.call("chiptorio-ai", "install_model", entity, "small-model")
    install_model = ai.install_model,
    -- /c remote.call("chiptorio-ai", "uninstall_model", entity)
    uninstall_model = ai.uninstall_model,
  })
end

