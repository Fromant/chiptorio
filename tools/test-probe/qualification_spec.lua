-- Unit tests for scripts/runtime/qualification_alloc.lua and the half-node
-- metadata it reads.
--
-- Plain tables only: no map, no entities, no storage.

local alloc = require("__chiptorio__/scripts/runtime/qualification_alloc")
local meta = require("__chiptorio__/scripts/research_meta")
local nodes = require("__chiptorio__/scripts/process_nodes")
local H = require("unit_harness")

local function close(actual, expected, label)
  if math.abs(actual - expected) > 1e-9 then
    error((label or "value") .. " expected " .. tostring(expected) .. " but got " .. tostring(actual), 2)
  end
end

local function network(spec)
  return {
    scalar = spec.scalar or 0,
    vector = spec.vector or 0,
    tensor = spec.tensor or 0,
    quantum = spec.quantum or 0,
    memory = spec.memory or 0,
    bandwidth = spec.bandwidth or 0,
  }
end

return function()
  H.test("the pre-internet half-nodes have no qualification gate", function()
    H.eq(meta.qualification_gate("6um"), nil, "6 um gate")
    H.eq(meta.qualification_gate("1-5um"), nil, "1.5 um gate")
    local supported, reason = alloc.support("6um", nil)
    H.eq(supported, true, "6 um supported offline")
    H.eq(reason, "ok", "6 um reason")
  end)

  H.test("every network half-node has a gate", function()
    for _, half in ipairs(nodes.HALF_NODES) do
      local gate = meta.qualification_gate(half.key)
      if half.requires_network then
        H.truthy(gate, "missing qualification gate for " .. half.key)
        H.truthy(gate.floor > 0, "gate floor for " .. half.key)
        H.truthy(gate.memory > 0, "gate memory for " .. half.key)
        H.truthy(gate.bandwidth > 0, "gate bandwidth for " .. half.key)
        H.truthy(next(gate.profiles) ~= nil, "gate profiles for " .. half.key)
      else
        H.eq(gate, nil, "offline half-node has a gate: " .. half.key)
      end
    end
  end)

  H.test("an unconnected lab cannot support a network half-node", function()
    local supported, reason = alloc.support("800nm", nil)
    H.eq(supported, false, "800 nm without a network")
    H.eq(reason, "no-network", "800 nm reason")
  end)

  H.test("a network that meets every gate supports qualification", function()
    local gate = meta.qualification_gate("800nm")
    local net = network({
      scalar = gate.floor,
      memory = gate.memory,
      bandwidth = gate.bandwidth,
    })
    local supported, reason = alloc.support("800nm", net)
    H.eq(supported, true, "800 nm supported")
    H.eq(reason, "ok", "800 nm support reason")
  end)

  H.test("compute, memory and bandwidth are separate hard stops", function()
    local gate = meta.qualification_gate("800nm")

    local poor = network({ scalar = gate.floor - 1, memory = gate.memory, bandwidth = gate.bandwidth })
    local supported, reason = alloc.support("800nm", poor)
    H.eq(supported, false, "compute shortfall")
    H.eq(reason, "compute", "compute reason")

    local cramped = network({ scalar = gate.floor, memory = gate.memory - 1, bandwidth = gate.bandwidth })
    supported, reason = alloc.support("800nm", cramped)
    H.eq(supported, false, "memory shortfall")
    H.eq(reason, "memory", "memory reason")

    local narrow = network({ scalar = gate.floor, memory = gate.memory, bandwidth = gate.bandwidth - 1 })
    supported, reason = alloc.support("800nm", narrow)
    H.eq(supported, false, "bandwidth shortfall")
    H.eq(reason, "bandwidth", "bandwidth reason")
  end)

  H.test("a later gate needs both profile shares", function()
    local gate = meta.qualification_gate("65nm")
    -- Scalar alone is not enough once the profile asks for vector compute.
    local scalar_only = network({
      scalar = gate.floor * 2,
      vector = 0,
      memory = gate.memory * 2,
      bandwidth = gate.bandwidth * 2,
    })
    local supported, reason = alloc.support("65nm", scalar_only)
    H.eq(supported, false, "65 nm with no vector")
    H.eq(reason, "compute", "65 nm reason")
  end)

  H.test("only powered and supported labs add samples", function()
    local half = nodes.half_node("6um")
    close(alloc.gain(half, 3, true, true), 2, "3 seconds at 1.5 s/sample")
    close(alloc.gain(half, 3, false, true), 0, "unpowered gain")
    close(alloc.gain(half, 3, true, false), 0, "unsupported gain")
    close(alloc.gain(nil, 3, true, true), 0, "missing half")
  end)

  H.test("advance clamps to the batch and reports completion", function()
    local after, complete = alloc.advance(0, 50, 20)
    close(after, 20, "partial samples")
    H.eq(complete, false, "partial completion")

    after, complete = alloc.advance(40, 50, 20)
    close(after, 50, "clamped samples")
    H.eq(complete, true, "complete")

    after, complete = alloc.advance(10, 50, -20)
    close(after, 0, "negative progress is clamped")
    H.eq(complete, false, "negative completion")
  end)

  H.test("wafers are consumed only for whole samples", function()
    H.eq(alloc.samples_to_take(0, 0.9), 0, "fractional sample")
    H.eq(alloc.samples_to_take(0.9, 1.2), 1, "one completed sample")
    H.eq(alloc.samples_to_take(3.5, 6.1), 3, "three completed samples")
    H.eq(alloc.samples_to_take(6.1, 3.5), 0, "rollback takes nothing")
  end)

  H.test("the bar fraction is clamped", function()
    close(alloc.fraction(25, 50), 0.5, "half done")
    close(alloc.fraction(80, 50), 1, "over-complete")
    close(alloc.fraction(-5, 50), 0, "negative")
    close(alloc.fraction(1, 0), 1, "zero batch")
  end)
end
