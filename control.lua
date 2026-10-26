-- Runtime entry point.
--
-- Factorio keeps one handler per event, so every module exposes plain
-- functions and this file owns the registration and the single tick
-- dispatcher. Do not register script.on_init or script.on_nth_tick from a
-- module: a later registration would silently replace an earlier one.

local answer_engine = require("scripts.answer_engine")
local enemy_cleanup = require("scripts.enemy_cleanup")

script.on_init(function()
  answer_engine.init_storage()
  enemy_cleanup.on_init()
end)

script.on_configuration_changed(function()
  answer_engine.init_storage()
  enemy_cleanup.on_configuration_changed()
end)

script.on_nth_tick(60, function()
  answer_engine.tick()
end)
