-- Pure qualification maths.
--
-- This file answers the two questions the runtime needs, with no `game`, no
-- `storage` and no prototypes:
--   1. can a network support analysing a half-node's pilot wafers?
--   2. how far does a batch of analysis seconds move the qualification bar?
--
-- The runtime turns the graph into plain network tables and the lab inventory
-- into an integer, so the same maths is unit tested in the data stage
-- (tools/test-probe/qualification_spec.lua). DESIGN §4.5.

local meta = require("scripts.research_meta")
local nodes = require("scripts.process_nodes")
local research = require("scripts.runtime.research_alloc")

local M = {}

--- Whether a network can support a half-node. A half-node without a gate in
--- research_meta.lua works offline (6 µm and 1.5 µm), so it never needs a cable.
---
--- Returns supported, reason. Reasons match the research allocator: "ok",
--- "no-network", "compute", "memory", "bandwidth".
function M.support(key, network)
  local gate = meta.qualification_gate(key)
  if not gate then
    return true, "ok"
  end
  if not network then
    return false, "no-network"
  end

  local profiles = gate.profiles or { scalar = 1 }
  local compute = research.profile_compute(network, profiles)
  if compute < (gate.floor or 0) then
    return false, "compute"
  end
  if (network.memory or 0) < (gate.memory or 0) then
    return false, "memory"
  end
  if (network.bandwidth or 0) < (gate.bandwidth or 0) then
    return false, "bandwidth"
  end
  return true, "ok"
end

--- Samples a lab adds in `seconds`. `analysis_time` is seconds per sample, so a
--- lab that is powered, supported and present always makes progress; there is no
--- random failure (DESIGN §4.5.3).
function M.gain(half, seconds, powered, supported)
  if not half or not (powered and supported) then
    return 0
  end
  local per_sample = half.analysis_time or 1
  if per_sample <= 0 then
    return 0
  end
  return (seconds or 0) / per_sample
end

--- Add `gain` samples and clamp to the batch size. Returns samples, complete.
function M.advance(samples, needed, gain)
  samples = samples or 0
  needed = needed or 0
  local next_samples = samples + (gain or 0)
  if next_samples > needed then
    next_samples = needed
  end
  if next_samples < 0 then
    next_samples = 0
  end
  return next_samples, needed > 0 and next_samples >= needed
end

--- How many whole PQWs this progress change consumes. The bar can hold a
--- fraction of a sample, so wafers are only taken when a sample completes.
function M.samples_to_take(before, after)
  local taken = math.floor(after or 0) - math.floor(before or 0)
  if taken < 0 then
    return 0
  end
  return taken
end

--- Fraction of the qualification bar, clamped to 0..1 for the GUI.
function M.fraction(samples, needed)
  if not needed or needed <= 0 then
    return 1
  end
  local value = (samples or 0) / needed
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

--- The force-wide multipliers of a qualified set.
function M.bonus(qualified)
  return nodes.total_bonus(qualified)
end

return M
