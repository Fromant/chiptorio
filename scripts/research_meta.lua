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
  ["neural-processor"] = { tensor = 32, power = 150, heat = 8 },
  ["quantum-processor"] = { quantum = 64, power = 500, heat = 20 },
}

-- Memory modules. Capacity is the research dataset size; bandwidth is added
-- to the network's memory bus. The same items also provide QLN cells through
-- qln_meta.DRIVE_CELLS (DESIGN §8.2). Later generations add capacity faster
-- than bandwidth; the two exotic lines trade one for the other: HBM is the
-- bandwidth ceiling and 3D NAND is the density ceiling.
M.MEMORY_PROFILES = {
  ["sram-module"] = { capacity = 16, bandwidth = 8, power = 2, heat = 0.5 },
  ["dram-module"] = { capacity = 128, bandwidth = 16, power = 6, heat = 1 },
  ["sdram-module"] = { capacity = 256, bandwidth = 24, power = 8, heat = 1.5 },
  ["ddr-module"] = { capacity = 384, bandwidth = 32, power = 10, heat = 2 },
  ["ddr2-module"] = { capacity = 512, bandwidth = 40, power = 12, heat = 2.5 },
  ["ddr3-module"] = { capacity = 768, bandwidth = 48, power = 14, heat = 3 },
  ["ddr4-module"] = { capacity = 1024, bandwidth = 56, power = 16, heat = 3.5 },
  ["ddr5-module"] = { capacity = 1536, bandwidth = 64, power = 18, heat = 4 },
  ["hbm-module"] = { capacity = 2048, bandwidth = 96, power = 24, heat = 5 },
  ["hbm3-module"] = { capacity = 3072, bandwidth = 128, power = 30, heat = 6 },
  ["3d-nand-module"] = { capacity = 4096, bandwidth = 16, power = 12, heat = 2 },
}

-- Compute providers. Every provider is a lab clone with no science inputs, so
-- it can expose module slots without being usable as a research lab.
-- Providers accept computer modules (`category = chiptorio-computer`) in their
-- computer slots, and memory modules in their memory slots. A computer bundles
-- its own compute and memory; memory banks provide additional bulk memory.
M.PROVIDERS = {
  ["server-rack"] = {
    computer_slots = 4,
    memory_slots = 0,
    bandwidth = 25,
    power = 150,
    drain = "20kW",
    heat = 4,
    cooling = 0,
  },
  ["memory-bank"] = {
    computer_slots = 0,
    memory_slots = 4,
    bandwidth = 25,
    power = 80,
    drain = "10kW",
    heat = 2,
    cooling = 0,
  },
  ["datacenter"] = {
    computer_slots = 8,
    memory_slots = 4,
    bandwidth = 100,
    power = 1000,
    drain = "100kW",
    heat = 20,
    cooling = 20,
  },
}

-- Computer profiles. Each computer module contributes compute profiles,
-- memory capacity, bandwidth, power and heat when installed in a provider.
-- These replace the old per-chip CHIP_PROFILES lookups in provider_descriptor.
M.COMPUTER_PROFILES = {
  ["microcomputer"] = { scalar = 8, capacity = 256, bandwidth = 32, power = 25, heat = 2 },
  ["server"] = { scalar = 32, capacity = 512, bandwidth = 64, power = 60, heat = 4 },
  ["supercomputer"] = { scalar = 8, vector = 64, capacity = 1024, bandwidth = 128, power = 100, heat = 6 },
  ["neural-computer"] = { scalar = 4, vector = 32, tensor = 128, capacity = 2048, bandwidth = 256, power = 150, heat = 8 },
  ["quantum-computer"] = { scalar = 2, vector = 16, tensor = 64, quantum = 256, capacity = 4096, bandwidth = 512, power = 500, heat = 20 },
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
  ["qln"] = {
    floor = 48,
    per_lab = 12,
    memory = 96,
    bandwidth = 48,
    profiles = { scalar = 1 },
  },
  ["qln-quantum"] = {
    floor = 192,
    per_lab = 48,
    memory = 384,
    bandwidth = 192,
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

--- Infinite research scales. Each entry maps a technology name to its per-level
--- multiplier and the stat it affects. Level 1 is the base (no multiplier).
--- Applied by the runtime to network capacities, provider stats, and recipe
--- productivity. Caps are enforced where the design specifies them.
M.INFINITE_RESEARCH_SCALES = {
  ["chip-performance"] = {
    per_level = 0.05,   -- +5% compute per level
    field = "compute",
    cap = nil,
  },
  ["chip-efficiency"] = {
    per_level = -0.02,  -- −2% power per level
    field = "power",
    cap = 0.10,         -- 90% reduction max (multiplier floor 0.10)
  },
  ["memory-density"] = {
    per_level = 0.05,   -- +5% memory capacity per level
    field = "memory",
    cap = nil,
  },
  ["memory-bandwidth"] = {
    per_level = 0.05,   -- +5% memory bandwidth per level
    field = "bandwidth",
    cap = nil,
  },
  ["network-bandwidth"] = {
    per_level = 0.05,   -- +5% link throughput per level
    field = "network_bandwidth",
    cap = nil,
  },
  ["cooling-efficiency"] = {
    per_level = 0.05,   -- +5% cooling capacity per level
    field = "cooling",
    cap = nil,
  },
  ["quantum-correction"] = {
    per_level = 0.05,   -- +5% QPU compute per level
    field = "quantum",
    cap = nil,
  },
  -- Process Yield uses recipe productivity_bonus directly, capped at 300%.
  -- It has no entry here because it is applied through LuaRecipe, not a
  -- scripted multiplier.
}

--- Infinite-research multiplier for a given tech and level.
--- Returns 1 + per_level * (level - 1), clamped by cap if present.
function M.infinite_multiplier(tech_name, level)
  local spec = M.INFINITE_RESEARCH_SCALES[tech_name]
  if not spec then
    return 1
  end
  local mult = 1 + spec.per_level * ((level or 1) - 1)
  if spec.cap then
    local floor = 1 - spec.cap
    if mult < floor then
      mult = floor
    end
  end
  return mult
end

--- Infinite-research multiplier. Level 1 is the researched technology itself.
function M.scale(spec, level)
  local per_level = spec and spec.infinite_scale or 0
  return 1 + per_level * ((level or 1) - 1)
end

return M
