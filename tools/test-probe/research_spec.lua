-- Unit tests for scripts/runtime/research_alloc.lua.
--
-- Plain tables only: no map, no entities, no storage.

local alloc = require("__chiptorio__/scripts/runtime/research_alloc")
local meta = require("__chiptorio__/scripts/research_meta")
local H = require("unit_harness")

local function close(actual, expected, label)
  if math.abs(actual - expected) > 1e-9 then
    error((label or "value") .. " expected " .. tostring(expected) .. " but got " .. tostring(actual), 2)
  end
end

local function lab(id, demand)
  return { id = id, demand = demand or 0.5 }
end

return function()
  H.test("no networks means no support and maximum decay", function()
    local result = alloc.evaluate({ floor = 8, memory = 16, bandwidth = 8, profiles = { scalar = 1 } }, {})
    H.eq(result.supported, false, "supported")
    H.eq(result.reason, "no-network", "reason")
    close(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("a network that meets every gate supports research", function()
    local result = alloc.evaluate(
      { floor = 8, per_lab = 2, memory = 16, bandwidth = 8, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 8, memory = 16, bandwidth = 8, labs = { lab(1), lab(2) } },
      }
    )
    H.eq(result.supported, true, "supported")
    H.eq(result.reason, "ok", "reason")
    H.eq(result.decay, 0, "decay")
    H.eq(result.active_labs, 2, "active labs")
  end)

  H.test("labs are enabled greedily by id until compute runs out", function()
    local result = alloc.evaluate(
      { floor = 8, per_lab = 2, memory = 16, bandwidth = 8, profiles = { scalar = 1 } },
      {
        {
          id = 1,
          scalar = 8,
          memory = 16,
          bandwidth = 8,
          labs = { lab(5), lab(3), lab(1), lab(4), lab(2) },
        },
      }
    )
    H.eq(result.active_labs, 4, "four labs fit into eight compute at two each")
    H.truthy(result.networks[1].active_labs[1], "lab 1 active")
    H.truthy(result.networks[1].active_labs[2], "lab 2 active")
    H.truthy(result.networks[1].active_labs[4], "lab 4 active")
    H.nil_value(result.networks[1].active_labs[5], "lab 5 paused")
  end)

  H.test("a lab whose demand does not fit is paused, not partially fed", function()
    local result = alloc.evaluate(
      { floor = 8, per_lab = 4, memory = 16, bandwidth = 8, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 9, memory = 16, bandwidth = 8, labs = { lab(1, 4), lab(2, 4), lab(3, 4) } },
      }
    )
    H.eq(result.active_labs, 2, "two labs fit into nine compute")
  end)

  H.test("a profile shortfall cannot be covered by another compute kind", function()
    local result = alloc.evaluate(
      {
        floor = 10,
        memory = 0,
        bandwidth = 100,
        profiles = { scalar = 0.5, vector = 0.5 },
      },
      {
        { id = 1, scalar = 1000, vector = 0, memory = 0, bandwidth = 100, labs = { lab(1, 1) } },
      }
    )
    H.eq(result.supported, false, "supported")
    H.eq(result.reason, "compute", "reason")
    H.eq(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("surplus of one kind does not inflate a mixed profile", function()
    local result = alloc.evaluate(
      { floor = 10, memory = 0, bandwidth = 100, profiles = { scalar = 0.5, vector = 0.5 } },
      {
        { id = 1, scalar = 10, vector = 1000, memory = 0, bandwidth = 100, labs = { lab(1, 1) } },
      }
    )
    H.eq(result.supported, true, "supported")
    H.eq(result.reason, "ok", "reason")
  end)

  H.test("memory below the requirement is a hard stop", function()
    local result = alloc.evaluate(
      { floor = 8, memory = 64, bandwidth = 8, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 8, memory = 32, bandwidth = 8, labs = { lab(1, 1) } },
      }
    )
    H.eq(result.supported, false, "supported")
    H.eq(result.reason, "memory", "reason")
    close(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("bandwidth below the requirement is a hard stop", function()
    local result = alloc.evaluate(
      { floor = 8, memory = 16, bandwidth = 32, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 8, memory = 16, bandwidth = 16, labs = { lab(1, 1) } },
      }
    )
    H.eq(result.supported, false, "supported")
    H.eq(result.reason, "bandwidth", "reason")
    close(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("compute below the floor decays in proportion to the gap", function()
    local result = alloc.evaluate(
      { floor = 8, memory = 16, bandwidth = 100, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 4, memory = 16, bandwidth = 100, labs = { lab(1, 1) } },
      }
    )
    H.eq(result.supported, false, "supported")
    H.eq(result.reason, "compute", "reason")
    close(result.decay, meta.MAX_DECAY_PER_MINUTE * 0.5, "decay")
  end)

  H.test("zero compute decays at the maximum rate", function()
    local result = alloc.evaluate(
      { floor = 8, memory = 16, bandwidth = 100, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 0, memory = 16, bandwidth = 100, labs = { lab(1, 1) } },
      }
    )
    close(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("capacity without a lab freezes and decays", function()
    local result = alloc.evaluate(
      { floor = 8, memory = 16, bandwidth = 8, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 8, memory = 16, bandwidth = 8, labs = {} },
      }
    )
    H.eq(result.supported, true, "supported")
    H.eq(result.reason, "no-labs", "reason")
    close(result.decay, meta.MAX_DECAY_PER_MINUTE, "decay")
  end)

  H.test("effective compute is capped by bandwidth", function()
    local result = alloc.evaluate(
      { floor = 8, per_lab = 1, memory = 0, bandwidth = 8, profiles = { scalar = 1 } },
      {
        { id = 1, scalar = 100, memory = 0, bandwidth = 8, labs = { lab(1, 1), lab(2, 1), lab(3, 1) } },
      }
    )
    H.eq(result.active_labs, 3, "three labs fit in eight bandwidth")
    H.eq(result.networks[1].effective, 8, "effective")
  end)

  H.test("decay_amount converts a per-minute rate to seconds", function()
    local spec = { floor = 8, memory = 0, bandwidth = 100, profiles = { scalar = 1 } }
    local result = alloc.evaluate(spec, {
      { id = 1, scalar = 4, memory = 0, bandwidth = 100, labs = { lab(1, 1) } },
    })
    close(alloc.decay_amount(spec, result, 30), meta.MAX_DECAY_PER_MINUTE * 0.5 * 0.5, "30s decay")
  end)

  H.test("lab demand is the larger of base demand and the technology per-lab cost", function()
    H.eq(meta.lab_demand({ per_lab = 4 }, "analytical-engine"), 4, "per-lab floor raises demand")
    H.eq(meta.lab_demand({ per_lab = 0.1 }, "analytical-engine"), 0.5, "base demand is a floor")
  end)
end
