-- Unit tests for scripts/research_meta.lua.
--
-- The table is the single source of truth for lab demand, chip/memory/computer
-- profiles, provider cooling and every network research gate. A silent edit
-- here changes both the data contract and the runtime, so the invariants are
-- checked against the pure modules the data stage also reads.

local meta = require("__chiptorio__/scripts/research_meta")
local nodes = require("__chiptorio__/scripts/process_nodes")
local qmeta = require("__chiptorio__/scripts/qln_meta")
local computers = require("__chiptorio__/scripts/computers_meta")
local H = require("unit_harness")

local function close(actual, expected, label)
  if math.abs(actual - expected) > 1e-9 then
    error((label or "value") .. " expected " .. tostring(expected) .. " but got " .. tostring(actual), 2)
  end
end

local function count(tbl)
  local total = 0
  for _ in pairs(tbl) do
    total = total + 1
  end
  return total
end

local function profile_total(profiles)
  local total = 0
  for _, value in pairs(profiles) do
    total = total + value
  end
  return total
end

local function assert_profile(name, spec)
  local total = profile_total(spec.profiles)
  close(total, 1, name .. " profile share total")
  for field, value in pairs(spec.profiles) do
    H.truthy(value > 0, name .. " profile " .. field .. " must be positive")
    local known = false
    for _, candidate in ipairs(meta.COMPUTE_PROFILES) do
      if candidate == field then
        known = true
      end
    end
    H.truthy(known, name .. " uses unknown compute profile " .. field)
  end
end

local half_gate_keys = {}
for _, half in ipairs(nodes.HALF_NODES) do
  if half.requires_network then
    half_gate_keys[half.key] = true
  end
end

return function()
  H.test("decay is a small positive share of the bar per minute", function()
    H.truthy(meta.MAX_DECAY_PER_MINUTE > 0, "decay")
    H.truthy(meta.MAX_DECAY_PER_MINUTE <= 0.05, "decay is too large")
  end)

  H.test("every research lab has a monotonically increasing base demand", function()
    local ladder = {
      "analytical-engine",
      "tube-mainframe",
      "mainframe-cluster",
      "datacenter-lab",
      "cryostat",
    }
    H.eq(count(meta.LAB_DEMAND), #ladder, "research lab count")
    local previous = 0
    for _, name in ipairs(ladder) do
      local demand = meta.LAB_DEMAND[name]
      H.truthy(demand, "missing lab demand for " .. name)
      H.truthy(demand > previous, "lab demand is not ascending at " .. name)
      previous = demand
    end
  end)

  H.test("chip profiles only define known compute fields with real power and heat", function()
    H.eq(count(meta.CHIP_PROFILES), 7, "chip profile count")
    for name, profile in pairs(meta.CHIP_PROFILES) do
      local compute = 0
      for _, field in ipairs(meta.COMPUTE_PROFILES) do
        local value = profile[field]
        if value then
          H.truthy(value > 0, name .. " compute " .. field .. " must be positive")
          compute = compute + value
        end
      end
      H.truthy(compute > 0, name .. " has no compute")
      H.truthy((profile.power or 0) > 0, name .. " has no power draw")
      H.truthy((profile.heat or 0) > 0, name .. " has no heat")
    end
  end)

  H.test("memory profiles and QLN cells describe the same eleven generations", function()
    H.eq(count(meta.MEMORY_PROFILES), 11, "memory profile count")
    H.eq(count(qmeta.DRIVE_CELLS), 11, "QLN cell count")
    local ladder = {}
    for name, profile in pairs(meta.MEMORY_PROFILES) do
      ladder[#ladder + 1] = name
    end
    table.sort(ladder, function(a, b)
      return meta.MEMORY_PROFILES[a].capacity < meta.MEMORY_PROFILES[b].capacity
    end)
    local previous_capacity = 0
    local previous_cells = 0
    for _, name in ipairs(ladder) do
      local profile = meta.MEMORY_PROFILES[name]
      H.truthy(qmeta.DRIVE_CELLS[name], "memory profile has no QLN cells: " .. name)
      H.truthy(profile.capacity > previous_capacity, "memory capacity is not ascending at " .. name)
      H.truthy(profile.bandwidth > 0, "memory bandwidth must be positive: " .. name)
      H.truthy((profile.power or 0) > 0, "memory power must be positive: " .. name)
      H.truthy((profile.heat or 0) > 0, "memory heat must be positive: " .. name)
      H.truthy(qmeta.DRIVE_CELLS[name] > previous_cells, "QLN cells are not ascending at " .. name)
      previous_capacity = profile.capacity
      previous_cells = qmeta.DRIVE_CELLS[name]
    end
    for name in pairs(qmeta.DRIVE_CELLS) do
      H.truthy(meta.MEMORY_PROFILES[name], "QLN cell entry has no memory profile: " .. name)
    end
  end)

  H.test("computer profiles match the computer ladder and bundle compute and memory", function()
    H.eq(count(meta.COMPUTER_PROFILES), #computers.COMPUTERS, "computer profile count")
    for _, computer in ipairs(computers.COMPUTERS) do
      local profile = meta.COMPUTER_PROFILES[computer.name]
      H.truthy(profile, "missing computer profile " .. computer.name)
      close(profile.scalar or 0, computer.profile.scalar, computer.name .. " scalar")
      close(profile.vector or 0, computer.profile.vector or 0, computer.name .. " vector")
      close(profile.tensor or 0, computer.profile.tensor or 0, computer.name .. " tensor")
      close(profile.quantum or 0, computer.profile.quantum or 0, computer.name .. " quantum")
      close(profile.capacity or 0, computer.profile.memory, computer.name .. " memory")
      close(profile.bandwidth or 0, computer.profile.bandwidth, computer.name .. " bandwidth")
      close(profile.power or 0, computer.power, computer.name .. " power")
      close(profile.heat or 0, computer.heat, computer.name .. " heat")
      H.truthy((profile.capacity or 0) > 0, computer.name .. " has no memory")
      H.truthy((profile.bandwidth or 0) > 0, computer.name .. " has no bandwidth")
    end
  end)

  H.test("provider cooling covers its own heat and its standard module load", function()
    H.eq(count(meta.PROVIDERS), 3, "provider count")
    local micro = meta.COMPUTER_PROFILES["microcomputer"]
    local sram = meta.MEMORY_PROFILES["sram-module"]
    for _, name in ipairs({ "server-rack", "memory-bank", "datacenter" }) do
      local provider = meta.PROVIDERS[name]
      H.truthy(provider, "missing provider " .. name)
      H.truthy(provider.computer_slots >= 0, name .. " computer slots")
      H.truthy(provider.memory_slots >= 0, name .. " memory slots")
      H.truthy(provider.computer_slots + provider.memory_slots > 0, name .. " has no module slots")
      H.truthy(provider.bandwidth > 0, name .. " has no backplane bandwidth")
      H.truthy(provider.power > 0, name .. " has no power draw")
      H.truthy(provider.heat > 0, name .. " has no base heat")
      local standard_heat =
        provider.heat +
        provider.computer_slots * micro.heat +
        provider.memory_slots * sram.heat
      H.truthy(
        provider.cooling >= standard_heat,
        name .. " cooling " .. tostring(provider.cooling)
          .. " does not cover its standard load " .. tostring(standard_heat)
      )
    end
    local sorting = meta.PROVIDERS["server-rack"]
    local bank = meta.PROVIDERS["memory-bank"]
    local datacenter = meta.PROVIDERS["datacenter"]
    H.eq(sorting.memory_slots, 0, "server rack must not take memory modules")
    H.eq(bank.computer_slots, 0, "memory bank must not take computer modules")
    H.truthy(datacenter.computer_slots > sorting.computer_slots, "datacenter has no more slots than a rack")
  end)

  H.test("every technology gate has the documented floor, memory and bandwidth shape", function()
    H.truthy(count(meta.TECHS) > 10, "too few technology gates")
    for name, spec in pairs(meta.TECHS) do
      H.truthy(spec.floor > 0, name .. " floor must be positive")
      H.truthy(spec.per_lab > 0, name .. " per-lab demand must be positive")
      close(spec.memory, spec.floor * 2, name .. " memory")
      close(spec.bandwidth, spec.floor, name .. " bandwidth")
      assert_profile(name, spec)
    end
    for _, node in ipairs(nodes.NODES) do
      local tech_name = nodes.tech_name(node.key)
      if node.key == "10um" or node.key == "3um" or node.key == "1um" then
        H.eq(meta.TECHS[tech_name], nil, tech_name .. " must not have a network gate")
      else
        H.truthy(meta.TECHS[tech_name], "missing network gate for " .. tech_name)
      end
    end
    H.eq(meta.TECHS["internet"], nil, "internet must stay offline")
    H.truthy(meta.TECHS["vlsi-process"], "missing vlsi-process gate")
    H.truthy(meta.TECHS["the-question"], "missing the-question gate")
    H.eq(meta.TECHS["the-question"].infinite_scale, 0.25, "the-question scale")
  end)

  H.test("qualification gates exist exactly for the network half-nodes", function()
    H.eq(count(meta.QUALIFICATION_GATES), count(half_gate_keys), "qualification gate count")
    for key in pairs(meta.QUALIFICATION_GATES) do
      H.truthy(half_gate_keys[key], "qualification gate has no network half-node: " .. key)
    end
    for key in pairs(half_gate_keys) do
      H.truthy(meta.QUALIFICATION_GATES[key], "missing qualification gate for " .. key)
    end
    H.eq(meta.qualification_gate("6um"), nil, "6 um must work offline")
    H.eq(meta.qualification_gate("1-5um"), nil, "1.5 um must work offline")

    local previous_floor = 0
    for _, half in ipairs(nodes.HALF_NODES) do
      local gate = meta.QUALIFICATION_GATES[half.key]
      if gate then
        close(gate.memory, gate.floor * 2, half.key .. " memory")
        close(gate.bandwidth, gate.floor, half.key .. " bandwidth")
        H.truthy(gate.floor > previous_floor, half.key .. " floor is not ascending")
        previous_floor = gate.floor
        assert_profile(half.key, gate)
        -- A vector requirement before the GPU exists at 90 nm deadlocks the
        -- ladder, so only the refinements at or below 65 nm may ask for it.
        local early = half.key == "800nm" or half.key == "250nm" or half.key == "130nm"
        if early then
          H.eq(gate.profiles.vector, nil, half.key .. " must not require a vector profile")
        else
          H.truthy((gate.profiles.vector or 0) > 0, half.key .. " should require a vector profile")
        end
      end
    end
  end)

  H.test("lab demand takes the larger of the chassis and the technology", function()
    close(meta.lab_demand({ per_lab = 2 }, "analytical-engine"), 2, "technology demand wins")
    close(meta.lab_demand({ per_lab = 0 }, "analytical-engine"), 0.5, "chassis demand wins")
    close(meta.lab_demand(nil, "tube-mainframe"), 2, "nil spec uses chassis demand")
    close(meta.lab_demand({ per_lab = 0.25 }, "unknown-machine"), 1, "unknown chassis defaults to one")
  end)

  H.test("infinite research scales apply per level and honour their caps", function()
    local expected_fields = {
      compute = true,
      power = true,
      memory = true,
      bandwidth = true,
      network_bandwidth = true,
      cooling = true,
      quantum = true,
    }
    for name, spec in pairs(meta.INFINITE_RESEARCH_SCALES) do
      H.truthy(spec.per_level ~= 0, name .. " has no per-level change")
      H.truthy(expected_fields[spec.field], name .. " has an unknown field " .. tostring(spec.field))
      if spec.cap then
        H.truthy(spec.cap > 0 and spec.cap < 1, name .. " cap must be a share below one")
      end
    end

    close(meta.infinite_multiplier("unknown", 5), 1, "unknown research multiplier")
    close(meta.infinite_multiplier("chip-performance", 1), 1, "level one is the base")
    close(meta.infinite_multiplier("chip-performance", 3), 1.10, "chip performance level three")
    close(meta.infinite_multiplier("memory-density", 2), 1.05, "memory density level two")
    close(meta.infinite_multiplier("chip-efficiency", 3), 0.96, "chip efficiency level three")
    close(meta.infinite_multiplier("chip-efficiency", 1000), 0.90, "chip efficiency cap")
  end)

  H.test("the-question rate scale grows linearly from the researched level", function()
    local spec = meta.TECHS["the-question"]
    close(meta.scale(spec, 1), 1, "level one scale")
    close(meta.scale(spec, 3), 1.5, "level three scale")
    close(meta.scale(nil, 3), 1, "missing spec scale")
  end)
end
