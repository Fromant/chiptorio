-- Runtime entry point.
--
-- Factorio keeps only one handler per nth-tick interval, so both runtime
-- modules expose a tick function and are registered together here. Registering
-- them separately would make the second module silently replace the first.

local research_gate = require("scripts.research_gate")
local answer_engine = require("scripts.answer_engine")

script.on_nth_tick(60, function()
  research_gate.tick()
  answer_engine.tick()
end)
