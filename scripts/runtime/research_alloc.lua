-- Pure research allocation and decay.
--
-- This file is the whole "does this technology run?" decision, with no `game`,
-- no `storage` and no prototypes. The runtime turns the network graph into the
-- plain tables this module expects, so the same maths can be unit tested in the
-- data stage (tools/test-probe/research_spec.lua).
--
-- Vocabulary (DESIGN §5.3 and §7):
--   spec      a gate from scripts/research_meta.lua TECHS
--   network   aggregate capacities plus a list of labs
--   profile   relative demand per compute kind, e.g. { scalar = 1 }
--   effective compute that can actually reach the labs, capped by bandwidth

local meta = require("scripts.research_meta")

local M = {}

local function sorted_labs(labs)
  local copy = {}
  for _, lab in ipairs(labs or {}) do
    copy[#copy + 1] = lab
  end
  table.sort(copy, function(a, b)
    if type(a.id) == "number" and type(b.id) == "number" then
      return a.id < b.id
    end
    return tostring(a.id) < tostring(b.id)
  end)
  return copy
end

--- Compute a network can deliver for a technology's profile mix.
---
--- The profile is a share, not an additive bonus: a technology that asks for
--- 25% scalar and 75% vector needs four times as much vector as scalar. Surplus
--- of one kind cannot cover a shortfall of another.
function M.profile_compute(network, profiles)
  local limit = nil
  for profile, share in pairs(profiles or {}) do
    if share > 0 then
      local available = network[profile] or 0
      local value = available / share
      if not limit or value < limit then
        limit = value
      end
    end
  end
  return limit or 0
end

--- The compute a lab can use: profile compute capped by bus bandwidth.
function M.effective(network, profiles)
  local compute = M.profile_compute(network, profiles)
  local bandwidth = network.bandwidth or 0
  if bandwidth < compute then
    return bandwidth
  end
  return compute
end

--- Why a network cannot run the technology, or "ok".
local function network_reason(network, spec, profile_compute)
  if profile_compute < spec.floor then
    return "compute"
  end
  if (network.memory or 0) < spec.memory then
    return "memory"
  end
  if (network.bandwidth or 0) < spec.bandwidth then
    return "bandwidth"
  end
  -- Cooling shortfall is a hard stop: without enough cooling, the network
  -- overheats and research stops entirely.
  local heat = network.heat or 0
  local cooling = network.cooling or 0
  if cooling < heat then
    return "cooling"
  end
  return "ok"
end

--- Greedy lab enablement. Labs are sorted by id so the result is deterministic:
--- the oldest lab runs first. A lab is enabled while the total demand of the
--- enabled labs still fits inside the effective compute.
local function enable_labs(network, spec, profiles)
  local active = {}
  local active_count = 0
  local used = 0
  local capacity = M.effective(network, profiles)

  for _, lab in ipairs(sorted_labs(network.labs)) do
    local demand = lab.demand or 0
    if demand < (spec.per_lab or 0) then
      demand = spec.per_lab or 0
    end
    if demand > 0 and used + demand <= capacity then
      active[lab.id] = true
      active_count = active_count + 1
      used = used + demand
    end
  end

  return active, active_count, used, capacity
end

--- Evaluate one technology against every network.
---
--- Returns:
---   supported      true when at least one network meets every gate
---   decay          fraction of the research bar lost per minute, 0..MAX
---   reason         "ok" | "no-network" | "no-labs" | "compute" |
---                  "memory" | "bandwidth" | "cooling" | "power"
---   active_labs    total number of labs that should run
---   networks       per-network result keyed by network id
function M.evaluate(spec, networks)
  spec = spec or {}
  local result = {
    supported = false,
    decay = meta.MAX_DECAY_PER_MINUTE,
    reason = "no-network",
    active_labs = 0,
    networks = {},
  }
  if not networks or #networks == 0 then
    return result
  end

  local total_active = 0
  -- Best network that at least has enough memory, bandwidth and cooling; only
  -- its compute and power can be limiting factors. -1 means no such network.
  local best_compute = -1
  local best_power = -1
  -- First hard stop (memory, bandwidth or cooling) among the networks that
  -- failed one.
  local blocked_reason = nil

  for _, network in ipairs(networks) do
    local profiles = spec.profiles or { scalar = 1 }
    local profile_compute = M.profile_compute(network, profiles)
    local reason = network_reason(network, spec, profile_compute)
    local qualified = reason == "ok"
    local active = {}
    local active_count = 0
    local used = 0
    local capacity = M.effective(network, profiles)

    if qualified then
      active, active_count, used, capacity = enable_labs(network, spec, profiles)
    else
      -- Track the least-bad networks so decay can be proportional to how close
      -- the player is to the compute or power floor.
      local memory_ok = (network.memory or 0) >= spec.memory
      local bandwidth_ok = (network.bandwidth or 0) >= spec.bandwidth
      local cooling_ok = (network.cooling or 0) >= (network.heat or 0)
      if memory_ok and bandwidth_ok and cooling_ok then
        if profile_compute > best_compute then
          best_compute = profile_compute
        end
        local power_supply = network.power or 0
        local power_demand = network.heat or 0
        local power_ratio = power_demand <= 0 and 1 or power_supply / power_demand
        if power_ratio > best_power then
          best_power = power_ratio
        end
      elseif not blocked_reason then
        blocked_reason = reason
      end
    end

    result.networks[network.id] = {
      id = network.id,
      supported = qualified,
      reason = reason,
      profile_compute = profile_compute,
      effective = capacity,
      used = used,
      active_count = active_count,
      active_labs = active,
    }

    if qualified then
      result.supported = true
      total_active = total_active + active_count
    end
  end

  result.active_labs = total_active

  if result.supported then
    if total_active > 0 then
      -- Even a qualified network can have power shortfall: power below heat
      -- causes proportional decay, matching the compute-shortfall rule.
      local best_power_ratio = 1
      for _, network in ipairs(networks) do
        local net_result = result.networks[network.id]
        if net_result.supported then
          local power_supply = network.power or 0
          local power_demand = network.heat or 0
          if power_demand > 0 then
            local ratio = power_supply / power_demand
            if ratio < best_power_ratio then
              best_power_ratio = ratio
            end
          end
        end
      end
      local missing_power = math.max(0, 1 - best_power_ratio)
      if missing_power > 0 then
        result.decay = meta.MAX_DECAY_PER_MINUTE * missing_power
        result.reason = "power"
      else
        result.decay = 0
        result.reason = "ok"
      end
    else
      -- Capacity exists, but no lab is connected: research cannot advance.
      result.decay = meta.MAX_DECAY_PER_MINUTE
      result.reason = "no-labs"
    end
    return result
  end

  -- No network passed every gate. Memory, bandwidth and cooling failures are
  -- hard stops. Compute and power shortfalls decay proportionally.
  if best_compute < 0 then
    result.decay = meta.MAX_DECAY_PER_MINUTE
    result.reason = blocked_reason or "no-network"
    return result
  end

  -- Combine compute and power shortfalls: the worse of the two sets the decay.
  local compute = best_compute
  local floor = spec.floor or 0
  local missing_compute = floor <= 0 and 0 or math.max(0, 1 - compute / floor)
  local missing_power = math.max(0, 1 - best_power)
  local missing = math.max(missing_compute, missing_power)

  result.reason = "compute"
  if missing_power > missing_compute then
    result.reason = "power"
  end
  if floor <= 0 or compute <= 0 then
    result.decay = meta.MAX_DECAY_PER_MINUTE
  else
    result.decay = meta.MAX_DECAY_PER_MINUTE * missing
  end
  return result
end

--- Fraction of the research bar to remove this many seconds.
function M.decay_amount(spec, result, seconds)
  if not spec or not result or result.decay <= 0 then
    return 0
  end
  return result.decay * (seconds / 60)
end

return M
