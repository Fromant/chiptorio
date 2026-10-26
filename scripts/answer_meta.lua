-- The Answer endgame, shared by the data stage and the runtime.
--
-- The same table drives the engine GUI, the runtime rate checks and the
-- generated documentation, so the displayed numbers cannot drift away from
-- the enforced ones.

local answer = {
  runtime_seconds = 42 * 60,

  -- The final exam: every workload tier, plus the chip that started the whole
  -- industry. These are production rates, not stockpiles.
  requirements = {
    { item = "automation-science-pack", rate = 10 }, -- punched cards
    { item = "logistic-science-pack", rate = 10 }, -- punched tape
    { item = "military-science-pack", rate = 10 }, -- magnetic tape
    { item = "chemical-science-pack", rate = 6 }, -- disk packs
    { item = "production-science-pack", rate = 4 }, -- solid-state drives
    { item = "utility-science-pack", rate = 2 }, -- mainframe modules
    { item = "quantum-science-pack", rate = 0.5 }, -- qubit arrays
    { item = "microprocessor", rate = 1 },
  },

  -- Post-game: every level of The Question raises the demand and the score.
  rate_scale_per_level = 0.25,
  score_per_level = 42,
}

return answer
