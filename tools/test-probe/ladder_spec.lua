-- Unit tests for the three prototype-generation ladders:
--   scripts/circuits_meta.lua   boards and the Circuit Assembler
--   scripts/computers_meta.lua  computer modules and the Computer Assembler
--   scripts/ai_meta.lua         model tiers, Training Cluster, Inference Lab
--
-- These modules are pure. `data-updates.lua` checks that the prototypes match
-- the tables; this spec checks the tables themselves stay internally coherent.

local circuits = require("__chiptorio__/scripts/circuits_meta")
local computers = require("__chiptorio__/scripts/computers_meta")
local ai = require("__chiptorio__/scripts/ai_meta")
local meta = require("__chiptorio__/scripts/research_meta")
local H = require("unit_harness")

local function count(tbl)
  local total = 0
  for _ in pairs(tbl) do
    total = total + 1
  end
  return total
end

local function check_ingredients(list, label)
  H.truthy(type(list) == "table" and #list > 0, label .. " has no ingredients")
  for _, ingredient in ipairs(list) do
    H.truthy(ingredient.type == "item" or ingredient.type == "fluid",
      label .. " has an unknown ingredient type " .. tostring(ingredient.type))
    H.truthy(type(ingredient.name) == "string" and ingredient.name ~= "",
      label .. " has an unnamed ingredient")
    H.truthy(type(ingredient.amount) == "number" and ingredient.amount > 0,
      label .. " ingredient " .. tostring(ingredient.name) .. " has no amount")
  end
end

local function check_tint(tint, label)
  H.truthy(type(tint) == "table", label .. " has no tint")
  for _, channel in ipairs({ "r", "g", "b" }) do
    local value = tint[channel]
    H.truthy(type(value) == "number" and value >= 0 and value <= 1,
      label .. " tint channel " .. channel .. " is out of range")
  end
end

local board_index = {}
for index, board in ipairs(circuits.BOARDS) do
  board_index[board.name] = index
end

local function check_boards()
  H.eq(#circuits.BOARDS, 6, "board count")
  local expected = {
    "electronic-circuit",
    "advanced-circuit",
    "processing-unit",
    "accelerator-board",
    "neural-board",
    "quantum-board",
  }
  local recipe_names = {}
  local previous_order = ""
  for index, board in ipairs(circuits.BOARDS) do
    H.eq(board.name, expected[index], "board order")
    H.truthy(board.label and board.label ~= "", board.name .. " has no label")
    H.truthy(board.gate and board.gate ~= "", board.name .. " has no gate")
    H.truthy(board.order and board.order > previous_order, board.name .. " order is not ascending")
    previous_order = board.order
    H.truthy(board.energy > 0, board.name .. " has no craft time")
    H.truthy(board.results >= 1, board.name .. " produces nothing")
    check_tint(board.tint, board.name)
    check_ingredients(board.base, board.name)

    H.eq(recipe_names[board.name], nil, "duplicate board recipe " .. board.name)
    recipe_names[board.name] = true

    -- A board may only be built from boards earlier in the ladder, never from
    -- itself or from a board that does not exist yet.
    for _, ingredient in ipairs(board.base) do
      if board_index[ingredient.name] then
        H.truthy(board_index[ingredient.name] < index,
          board.name .. " is built from a later board " .. ingredient.name)
      end
    end

    for _, alt in ipairs(board.alts or {}) do
      H.truthy(alt.gate and alt.gate ~= "", board.name .. " alternative has no gate")
      H.truthy(alt.energy > 0, board.name .. " alternative has no craft time")
      H.truthy(alt.results >= 1, board.name .. " alternative produces nothing")
      check_ingredients(alt.ingredients, board.name .. " from " .. alt.gate)
      local recipe_name = board.name .. "-from-" .. alt.gate
      H.eq(recipe_names[recipe_name], nil, "duplicate board recipe " .. recipe_name)
      recipe_names[recipe_name] = true
      for _, ingredient in ipairs(alt.ingredients) do
        if board_index[ingredient.name] then
          H.truthy(board_index[ingredient.name] < index,
            recipe_name .. " is built from a later board " .. ingredient.name)
        end
      end
    end
  end

  H.eq(circuits.ASSEMBLER.name, "circuit-assembler", "circuit assembler name")
  H.eq(circuits.ASSEMBLER.base_type, "assembling-machine", "circuit assembler base type")
  H.eq(circuits.ASSEMBLER.category, "chiptorio-circuit", "circuit assembler category")
  H.eq(circuits.ASSEMBLER.gate, "thermionics", "circuit assembler gate")
  H.truthy(circuits.ASSEMBLER.modules > 0, "circuit assembler has no module slots")
  H.truthy(circuits.ASSEMBLER.speed > 0, "circuit assembler has no speed")
  H.truthy(circuits.ASSEMBLER.craft_time > 0, "circuit assembler has no craft time")
  check_ingredients(circuits.ASSEMBLER.ingredients, "circuit assembler")
end

local function check_computers()
  H.eq(#computers.COMPUTERS, 5, "computer count")
  local expected = {
    "microcomputer",
    "server",
    "supercomputer",
    "neural-computer",
    "quantum-computer",
  }
  local seen = {}
  local previous_order = ""
  for index, computer in ipairs(computers.COMPUTERS) do
    H.eq(computer.name, expected[index], "computer order")
    H.eq(seen[computer.name], nil, "duplicate computer " .. computer.name)
    seen[computer.name] = true
    H.truthy(computer.label and computer.label ~= "", computer.name .. " has no label")
    H.truthy(computer.gate and computer.gate ~= "", computer.name .. " has no gate")
    H.truthy(computer.order and computer.order > previous_order, computer.name .. " order is not ascending")
    previous_order = computer.order
    H.truthy(computer.energy > 0, computer.name .. " has no craft time")
    H.truthy(computer.results >= 1, computer.name .. " produces nothing")
    check_tint(computer.tint, computer.name)
    check_ingredients(computer.base, computer.name)

    -- Every computer bundles a board, a chip and a memory module.
    local has_board, has_chip, has_memory = false, false, false
    for _, ingredient in ipairs(computer.base) do
      if board_index[ingredient.name] then
        has_board = true
      elseif meta.CHIP_PROFILES[ingredient.name] then
        has_chip = true
      elseif meta.MEMORY_PROFILES[ingredient.name] then
        has_memory = true
      end
    end
    H.truthy(has_board, computer.name .. " has no board ingredient")
    H.truthy(has_chip, computer.name .. " has no chip ingredient")
    H.truthy(has_memory, computer.name .. " has no memory ingredient")

    H.truthy(computer.profile.scalar > 0, computer.name .. " has no scalar compute")
    H.truthy(computer.profile.memory > 0, computer.name .. " has no memory")
    H.truthy(computer.profile.bandwidth > 0, computer.name .. " has no bandwidth")
    H.truthy(computer.power > 0, computer.name .. " has no power draw")
    H.truthy(computer.heat > 0, computer.name .. " has no heat")
  end

  H.eq(computers.ASSEMBLER.name, "computer-assembler", "computer assembler name")
  H.eq(computers.ASSEMBLER.base_type, "assembling-machine", "computer assembler base type")
  H.eq(computers.ASSEMBLER.category, "chiptorio-computer", "computer assembler category")
  H.eq(computers.ASSEMBLER.gate, "internet", "computer assembler gate")
  H.truthy(computers.ASSEMBLER.modules > 0, "computer assembler has no module slots")
  H.truthy(computers.ASSEMBLER.craft_time > 0, "computer assembler has no craft time")
  check_ingredients(computers.ASSEMBLER.ingredients, "computer assembler")
end

local function check_ai()
  H.eq(#ai.AI_TIERS, 5, "AI tier count")
  local expected = {
    "small-model",
    "specialist-model",
    "general-model",
    "frontier-model",
    "agi-model",
  }
  local seen = {}
  local previous_energy = 0
  local previous_reduction = 0
  local previous_duration = 0
  for index, tier in ipairs(ai.AI_TIERS) do
    H.eq(tier.name, expected[index], "AI tier order")
    H.eq(seen[tier.name], nil, "duplicate AI model " .. tier.name)
    seen[tier.name] = true
    H.eq(tier.tier, index, tier.name .. " tier number")
    H.truthy(tier.label and tier.label ~= "", tier.name .. " has no label")
    H.truthy(tier.gate and tier.gate ~= "", tier.name .. " has no gate")
    check_tint(tier.tint, tier.name)

    H.truthy(tier.train_energy > previous_energy, tier.name .. " training time is not ascending")
    previous_energy = tier.train_energy
    H.truthy(tier.train_output >= 1, tier.name .. " trains nothing")

    check_ingredients(tier.train_data, tier.name .. " data")
    for _, entry in ipairs(tier.train_data) do
      H.eq(entry.type, "item", tier.name .. " data must be items")
    end

    local compute = 0
    H.truthy(next(tier.train_compute) ~= nil, tier.name .. " has no compute cost")
    for field, amount in pairs(tier.train_compute) do
      local known = false
      for _, profile in ipairs(meta.COMPUTE_PROFILES) do
        if profile == field then
          known = true
        end
      end
      H.truthy(known, tier.name .. " uses unknown compute profile " .. field)
      H.truthy(amount > 0, tier.name .. " compute " .. field .. " must be positive")
      compute = compute + amount
    end
    H.truthy(compute > 0, tier.name .. " has no compute cost")

    local reduction = tier.insight.dataset_size_reduction
    H.truthy(reduction > previous_reduction, tier.name .. " insight does not improve")
    H.truthy(reduction > 0 and reduction <= 1, tier.name .. " insight reduction is out of range")
    previous_reduction = reduction
    H.truthy(tier.insight.duration > previous_duration, tier.name .. " insight duration is not ascending")
    previous_duration = tier.insight.duration
  end

  H.eq(ai.TRAINING_CLUSTER.name, "training-cluster", "training cluster name")
  H.eq(ai.TRAINING_CLUSTER.base_type, "assembling-machine", "training cluster base type")
  H.eq(ai.TRAINING_CLUSTER.category, "chiptorio-ai-training", "training cluster category")
  H.eq(ai.TRAINING_CLUSTER.gate, "machine-learning", "training cluster gate")
  H.truthy(ai.TRAINING_CLUSTER.modules > 0, "training cluster has no module slots")
  H.truthy(ai.TRAINING_CLUSTER.craft_time > 0, "training cluster has no craft time")
  check_ingredients(ai.TRAINING_CLUSTER.ingredients, "training cluster")
  local has_computer = false
  for _, ingredient in ipairs(ai.TRAINING_CLUSTER.ingredients) do
    if computers.COMPUTERS and ingredient.name == "server" then
      has_computer = true
    end
  end
  H.truthy(has_computer, "training cluster is not built from a computer")

  H.eq(ai.INFERENCE_LAB.name, "inference-lab", "inference lab name")
  H.eq(ai.INFERENCE_LAB.base_type, "lab", "inference lab base type")
  H.eq(ai.INFERENCE_LAB.gate, "machine-learning", "inference lab gate")
  H.truthy(ai.INFERENCE_LAB.modules > 0, "inference lab has no module slots")
  H.truthy(ai.INFERENCE_LAB.researching_speed > 0, "inference lab has no research speed")
  check_ingredients(ai.INFERENCE_LAB.ingredients, "inference lab")
end

-- Late-era boards and computers must be gated on the technology that unlocks
-- their newest ingredient, not one era early. The neural processor arrives with
-- quantum-advantage; the quantum processor, HBM3 and 3D NAND arrive with the
-- 7 nm node, which quantum-advantage requires. A too-early gate shows a recipe
-- the player cannot build, so pin the gates here as well as in the playthrough.
local function check_late_gates()
  local expected_board_gates = {
    ["neural-board"] = "quantum-advantage",
    ["quantum-board"] = "quantum-advantage",
  }
  local expected_alt_gates = {
    ["accelerator-board"] = "quantum-advantage",
    ["neural-board"] = "process-7nm",
  }
  for _, board in ipairs(circuits.BOARDS) do
    if expected_board_gates[board.name] then
      H.eq(board.gate, expected_board_gates[board.name], board.name .. " gate")
    end
    if expected_alt_gates[board.name] then
      H.eq(#board.alts, 1, board.name .. " alternative count")
      H.eq(board.alts[1].gate, expected_alt_gates[board.name], board.name .. " alternative gate")
    end
  end

  local expected_computer_gates = {
    ["neural-computer"] = "quantum-advantage",
    ["quantum-computer"] = "quantum-advantage",
  }
  for _, computer in ipairs(computers.COMPUTERS) do
    if expected_computer_gates[computer.name] then
      H.eq(computer.gate, expected_computer_gates[computer.name], computer.name .. " gate")
    end
  end
end

return function()
  H.test("the board ladder is six coherent tiers", check_boards)
  H.test("the computer ladder bundles board, chip and memory", check_computers)
  H.test("the AI tier ladder is five ascending models", check_ai)
  H.test("late boards and computers gate on their newest ingredient", check_late_gates)
end
