-- The Answer endgame, shared by the data stage and the runtime.
--
-- DESIGN §12. The final exam is a network and logistics check, not a
-- production-statistics check:
--   * a minimum rate of every compute profile
--   * a large memory dataset
--   * a minimum backplane bandwidth
--   * a continuous QLN supply of science packs, microprocessors and quantum
--     processors
--   * a 42-minute computation
--
-- Every number below is per second. The Question scales all of them by 25% per
-- level, so the engine stays a megabase sink after the first victory.

local answer = {
  runtime_seconds = 42 * 60,

  -- Minimum network compute rate, by profile. Requiring all four is what makes
  -- the neural processor and the quantum processor endgame parts, not optional
  -- curiosities.
  compute = {
    scalar = 128,
    vector = 128,
    tensor = 128,
    quantum = 128,
  },

  -- Memory reserved by the computation. Memory capacity is a hard gate: a
  -- shortfall pauses the clock instead of decaying a research bar.
  memory = 2048,

  -- Backplane bandwidth. Routers and switches are the only sources, so a bare
  -- cable run cannot run the engine even with enough compute.
  bandwidth = 512,

  -- Continuous QLN draw. These items are consumed from network storage; the
  -- engine never accepts them from a belt or an inserter directly.
  item_demand = {
    { item = "automation-science-pack", rate = 10 }, -- punched cards
    { item = "logistic-science-pack", rate = 10 }, -- punched tape
    { item = "military-science-pack", rate = 8 }, -- magnetic tape
    { item = "chemical-science-pack", rate = 6 }, -- disk packs
    { item = "production-science-pack", rate = 4 }, -- solid-state drives
    { item = "utility-science-pack", rate = 2 }, -- mainframe modules
    { item = "chiptorio-optical-science-pack", rate = 1.5 }, -- optical discs
    { item = "chiptorio-hbm-science-pack", rate = 1 }, -- HBM stacks
    { item = "chiptorio-quantum-science-pack", rate = 0.5 }, -- qubit arrays
    { item = "microprocessor", rate = 2 },
    { item = "quantum-processor", rate = 0.5 },
  },

  -- While the engine is paused its stability drains. It is a visible warning,
  -- not a second failure state: the clock resumes as soon as every line is met.
  stability_decay_per_minute = 0.02,

  -- Post-game: every level of The Question raises the demand and the score.
  rate_scale_per_level = 0.25,
  score_per_level = 42,
}

return answer
