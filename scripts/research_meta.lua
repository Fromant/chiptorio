-- Research, compute and memory metadata.
--
-- This module is pure: it is required by the data stage (for module profiles
-- and provider recipes) and by the runtime (for allocation and decay). It must
-- never touch `data`, `game` or `storage`.
--
-- DESIGN §5.3, §6 and §7. One table is the source of truth for both stages.

local M = {}

-- Below the compute floor, progress decays by at most this fraction of the
-- current technology per minute. A technology at 50% progress that is fully
-- starved loses 0.02 of the bar per minute, not 2% of its remaining progress.
M.MAX_DECAY_PER_MINUTE = 0.02

-- Base compute demand of one lab, in compute units per second. The effective
-- demand is max(base, technology.per_lab): a late technology cannot be
-- researched by a room full of analytical engines.
M.LAB_DEMAND = {
  ["analytical-engine"] = 0.5,
  ["tube-mainframe"] = 2,
  ["mainframe-cluster"] = 8,
  ["datacenter-lab"] = 32,
  ["cryostat"] = 128,
}

-- Compute modules. The script reads the provider's module inventory; the
-- module prototype itself has an empty vanilla effect.
--
-- `power` is kW and `heat` is an abstract heat unit. They are summed by the
-- graph but do not throttle research yet (DESIGN §5.4 is a later phase).
M.CHIP_PROFILES = {
  ["integrated-circuit"] = { scalar = 1, power = 5, heat = 0.5 },
  ["microprocessor"] = { scalar = 2, power = 10, heat = 1 },
  ["system-on-chip"] = { scalar = 8, power = 25, heat = 2 },
  ["multi-core-cpu"] = { scalar = 32, power = 60, heat = 4 },
  ["gpu"] = { scalar = 2, vector = 16, power = 100, heat = 6 },
  ["quantum-processor"] = { quantum = 64, power = 500, heat = 20 },
}

-- Memory modules. Capacity is the research dataset size; bandwidth is added
-- to the network's memory bus. QLN storage will reuse the same items in a
-- later phase.
M.MEMORY_PROFILES = {
  ["sram-module"] = { capacity = 16, bandwidth = 8, power = 2, heat = 0.5 },
  ["dram-module"] = { capacity = 128, bandwidth = 16, power = 6, heat = 1 },
}

-- Compute providers. Every provider is a lab clone with no science inputs, so
-- it can expose module slots without being usable as a research lab.
M.PROVIDERS = {
  ["server-rack"] = {
    chip_slots = 4,
    memory_slots = 0,
    bandwidth = 25,
    power = 150,
    drain = "20kW",
    heat = 4,
    cooling = 0,
  },
  ["memory-bank"] = {
    chip_slots = 0,
    memory_slots = 4,
    bandwidth = 25,
    power = 80,
    drain = "10kW",
    heat = 2,
    cooling = 0,
  },
  ["datacenter"] = {
    chip_slots = 8,
    memory_slots = 4,
    bandwidth = 100,
    power = 1000,
    drain = "100kW",
    heat = 20,
    cooling = 20,
  },
}

-- Research gates. `profiles` are relative weights, not additive capacities:
-- a technology with { scalar = 0.5, vector = 0.5 } and a floor of 128 needs
-- 64 scalar and 64 vector. Surplus vector cannot cover a scalar shortfall.
--
-- The Internet technology is deliberately absent: it is the technology that
-- creates compute, so it must be researchable offline (DESIGN §7.4).
M.TECHS = {
  ["vlsi-process"] = {
    floor = 8,
    per_lab = 2,
    memory = 16,
    bandwidth = 8,
    profiles = { scalar = 1 },
  },
  -- Process nodes. The first three (10 um, 3 um, 1 um) are deliberately absent:
  -- they are the pre-network ladder and must be researchable offline. From
  -- 350 nm every node is a compute gate, so advancing a node needs a bigger
  -- network even though the chip profiles never change (DESIGN §4.4).
  ["process-350nm"] = {
    floor = 8,
    per_lab = 2,
    memory = 16,
    bandwidth = 8,
    profiles = { scalar = 1 },
  },
  ["process-180nm"] = {
    floor = 16,
    per_lab = 4,
    memory = 32,
    bandwidth = 16,
    profiles = { scalar = 1 },
  },
  ["process-90nm"] = {
    floor = 24,
    per_lab = 6,
    memory = 48,
    bandwidth = 24,
    profiles = { scalar = 1 },
  },
  ["process-45nm"] = {
    floor = 32,
    per_lab = 8,
    memory = 64,
    bandwidth = 32,
    profiles = { scalar = 1 },
  },
  ["process-22nm"] = {
    floor = 48,
    per_lab = 12,
    memory = 96,
    bandwidth = 48,
    profiles = { scalar = 0.75, vector = 0.25 },
  },
  ["process-14nm"] = {
    floor = 64,
    per_lab = 16,
    memory = 128,
    bandwidth = 64,
    profiles = { scalar = 0.75, vector = 0.25 },
  },
  ["process-7nm"] = {
    floor = 96,
    per_lab = 24,
    memory = 192,
    bandwidth = 96,
    profiles = { scalar = 0.6, vector = 0.4 },
  },
  ["process-3nm"] = {
    floor = 128,
    per_lab = 32,
    memory = 256,
    bandwidth = 128,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["process-1-4nm"] = {
    floor = 192,
    per_lab = 48,
    memory = 384,
    bandwidth = 192,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["datacenter"] = {
    floor = 32,
    per_lab = 8,
    memory = 64,
    bandwidth = 32,
    profiles = { scalar = 1 },
  },
  ["advanced-packaging"] = {
    floor = 64,
    per_lab = 16,
    memory = 128,
    bandwidth = 64,
    profiles = { scalar = 1 },
  },
  ["heterogeneous-compute"] = {
    floor = 128,
    per_lab = 32,
    memory = 256,
    bandwidth = 128,
    profiles = { scalar = 0.25, vector = 0.75 },
  },
  ["quantum-computing"] = {
    floor = 192,
    per_lab = 48,
    memory = 384,
    bandwidth = 192,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["quantum-error-correction"] = {
    floor = 256,
    per_lab = 64,
    memory = 512,
    bandwidth = 256,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["quantum-advantage"] = {
    floor = 384,
    per_lab = 96,
    memory = 768,
    bandwidth = 384,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["the-question"] = {
    floor = 512,
    per_lab = 128,
    memory = 1024,
    bandwidth = 512,
    profiles = { scalar = 0.4, vector = 0.4, quantum = 0.2 },
    infinite_scale = 0.25,
  },
}

-- Qualification gates for the half-node refinements (DESIGN §4.5.2). A missing
-- entry means the Metrology Lab works offline, which is what keeps 6 µm and
-- 1.5 µm reachable before the internet. From 800 nm the lab must be attached to
-- a network that meets the same shape of gate as a technology: compute floor,
-- memory, bandwidth and a profile mix.
--
-- The profile mix stays scalar-only until the GPU exists at 90 nm. A vector
-- requirement before then would be unsatisfiable and would deadlock the ladder.
M.QUALIFICATION_GATES = {
  ["800nm"] = {
    floor = 8,
    memory = 16,
    bandwidth = 8,
    profiles = { scalar = 1 },
  },
  ["250nm"] = {
    floor = 12,
    memory = 24,
    bandwidth = 12,
    profiles = { scalar = 1 },
  },
  ["130nm"] = {
    floor = 16,
    memory = 32,
    bandwidth = 16,
    profiles = { scalar = 1 },
  },
  ["65nm"] = {
    floor = 32,
    memory = 64,
    bandwidth = 32,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["32nm"] = {
    floor = 48,
    memory = 96,
    bandwidth = 48,
    profiles = { scalar = 0.75, vector = 0.25 },
  },
  ["10nm"] = {
    floor = 64,
    memory = 128,
    bandwidth = 64,
    profiles = { scalar = 0.75, vector = 0.25 },
  },
  ["5nm"] = {
    floor = 96,
    memory = 192,
    bandwidth = 96,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
  ["2nm"] = {
    floor = 128,
    memory = 256,
    bandwidth = 128,
    profiles = { scalar = 0.5, vector = 0.5 },
  },
}

M.COMPUTE_PROFILES = { "scalar", "vector", "tensor", "quantum" }

--- Gate table for a technology, or nil for technologies that work offline.
function M.tech_spec(name)
  return M.TECHS[name]
end

--- Network gate for a half-node qualification, or nil when it works offline.
function M.qualification_gate(key)
  return M.QUALIFICATION_GATES[key]
end

--- Effective compute demand of one lab for this technology.
function M.lab_demand(spec, lab_name)
  local base = M.LAB_DEMAND[lab_name] or 1
  local per_lab = spec and spec.per_lab or 0
  if per_lab > base then
    return per_lab
  end
  return base
end

--- Infinite-research multiplier. Level 1 is the researched technology itself.
function M.scale(spec, level)
  local per_level = spec and spec.infinite_scale or 0
  return 1 + per_level * ((level or 1) - 1)
end

return M
