-- AI tier definitions.
--
-- Pure: no `data`, `game` or `storage` access. `scripts/ai.lua` turns these
-- entries into prototypes.
--
-- Each AI tier:
--   name      internal item/prototype name for the Model
--   label     visible name key prefix
--   order     prototype sort order
--   gate      technology that unlocks the tier (and its Training Cluster recipe)
--   tint      icon tint
--   train_energy  seconds to train one model in the Training Cluster
--   train_data    data items consumed per model (QLN draw per second)
--   train_compute compute reserved per model (vector/tensor)
--   train_output  models produced per training cycle
--   insight       insight granted when the model is used in an Inference Lab
--               (dataset_size_reduction, compute_bonus, duration)
--   tier          1=Narrow … 5=AGI, used for ordering and tech costs

local M = {}

M.AI_TIERS = {
  {
    name = "small-model",
    label = "small-model",
    order = "a[ai-model]",
    gate = "machine-learning",
    tint = { r = 0.80, g = 0.60, b = 0.20 },
    train_energy = 30,
    train_data = { { type = "item", name = "chemical-science-pack", amount = 1 } },
    train_compute = { vector = 8 },
    train_output = 1,
    insight = { dataset_size_reduction = 0.10, duration = 300 },
    tier = 1,
  },
  {
    name = "specialist-model",
    label = "specialist-model",
    order = "b[ai-model]",
    gate = "ai-specialist",
    tint = { r = 0.90, g = 0.50, b = 0.30 },
    train_energy = 60,
    train_data = { { type = "item", name = "production-science-pack", amount = 1 } },
    train_compute = { vector = 16, tensor = 4 },
    train_output = 1,
    insight = { dataset_size_reduction = 0.20, duration = 600 },
    tier = 2,
  },
  {
    name = "general-model",
    label = "general-model",
    order = "c[ai-model]",
    gate = "ai-general",
    tint = { r = 0.70, g = 0.40, b = 0.80 },
    train_energy = 120,
    train_data = { { type = "item", name = "utility-science-pack", amount = 1 } },
    train_compute = { tensor = 32 },
    train_output = 1,
    insight = { dataset_size_reduction = 0.40, duration = 900 },
    tier = 3,
  },
  {
    name = "frontier-model",
    label = "frontier-model",
    order = "d[ai-model]",
    gate = "ai-frontier",
    tint = { r = 0.40, g = 0.70, b = 0.90 },
    train_energy = 180,
    train_data = { { type = "item", name = "chiptorio-hbm-science-pack", amount = 1 } },
    train_compute = { tensor = 64, quantum = 8 },
    train_output = 1,
    insight = { dataset_size_reduction = 0.70, duration = 1200 },
    tier = 4,
  },
  {
    name = "agi-model",
    label = "agi-model",
    order = "e[ai-model]",
    gate = "artificial-general-intelligence",
    tint = { r = 0.20, g = 0.20, b = 0.80 },
    train_energy = 300,
    train_data = { { type = "item", name = "chiptorio-quantum-science-pack", amount = 1 } },
    train_compute = { quantum = 64 },
    train_output = 1,
    insight = { dataset_size_reduction = 1.0, duration = 3600 },
    tier = 5,
  },
}

-- Training Cluster machine definition.
M.TRAINING_CLUSTER = {
  name = "training-cluster",
  base_type = "assembling-machine",
  base = "assembling-machine-2",
  category = "chiptorio-ai-training",
  speed = 1.0,
  power = "400kW",
  modules = 2,
  craft_time = 15,
  order = "a[training-cluster]",
  tint = { r = 0.40, g = 0.60, b = 0.80 },
  ingredients = {
    { type = "item", name = "server", amount = 2 },
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "electronic-circuit", amount = 10 },
  },
  gate = "machine-learning",
}

-- Inference Lab machine definition.
M.INFERENCE_LAB = {
  name = "inference-lab",
  base_type = "lab",
  base = "lab",
  order = "b[inference-lab]",
  tint = { r = 0.60, g = 0.40, b = 0.80 },
  researching_speed = 1.0,
  energy_usage = "200kW",
  modules = 4,
  gate = "machine-learning",
  ingredients = {
    { type = "item", name = "supercomputer", amount = 1 },
    { type = "item", name = "steel-plate", amount = 20 },
    { type = "item", name = "electronic-circuit", amount = 10 },
  },
}

return M
