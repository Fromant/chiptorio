-- AI layer: Model items, Training Cluster, Inference Lab, AI technologies.
--
-- Runs after boards/chips/computers/technologies exist so it can create model
-- items, wire model recipes into gate technology effects, and register the
-- Training Cluster and Inference Lab.

local M = require("scripts.util")
local meta = require("scripts.ai_meta")

-- ---------------------------------------------------------------------------
-- Recipe categories for AI buildings.
-- ---------------------------------------------------------------------------

data:extend({
  { type = "recipe-category", name = "chiptorio-ai-training" },
})

-- ---------------------------------------------------------------------------
-- Item subgroup for AI models.
-- ---------------------------------------------------------------------------

data:extend({
  {
    type = "item-subgroup",
    name = "chiptorio-ai",
    group = "chiptorio",
    order = "e[ai]",
  },
})

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function set_item_flavour(proto, tier)
  proto.localised_name = { "item-name." .. tier.label }
  proto.localised_description = { "item-description." .. tier.label }
  if tier.tint then
    proto.icons = {
      {
        icon = "__chiptorio__/graphics/icons/" .. tier.name .. ".png",
        icon_size = 64,
        tint = tier.tint,
      },
    }
  else
    M.set_icon(proto, tier.name)
  end
end

--- Ensure a model item exists. All models are new.
local function ensure_model_item(tier)
  local proto = M.item_proto("processing-unit", tier.name, "chiptorio-ai", tier.order)
  proto.stack_size = 50
  set_item_flavour(proto, tier)
  data:extend({ proto })
  return proto
end

--- Ensure a model recipe exists.
local function ensure_model_recipe(tier)
  local spec = {
    name = tier.name,
    enabled = false,
    category = "chiptorio-ai-training",
    energy_required = tier.train_energy,
    ingredients = tier.train_data,
    results = { { type = "item", name = tier.name, amount = tier.train_output } },
  }
  M.recipe(spec)
  return spec
end

-- ---------------------------------------------------------------------------
-- Model items and recipes
-- ---------------------------------------------------------------------------

for _, tier in ipairs(meta.AI_TIERS) do
  ensure_model_item(tier)
  ensure_model_recipe(tier)
end

-- ---------------------------------------------------------------------------
-- Training Cluster machine
-- ---------------------------------------------------------------------------

local function make_training_cluster(spec)
  local entity = M.copy(data.raw[spec.base_type][spec.base])
  if not entity then
    error("chiptorio: base machine '" .. spec.base .. "' not found")
  end

  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.2, result = spec.name }
  entity.corpse = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.fast_replaceable_group = "chiptorio-machines"
  entity.crafting_categories = { spec.category }
  entity.crafting_speed = spec.speed
  entity.energy_usage = spec.power
  entity.module_slots = spec.modules
  M.set_entity_icon(entity, spec.name)
  if spec.tint then
    M.tint_entity(entity, spec.tint)
  end
  data:extend({ entity })

  local item = M.copy(data.raw.item[spec.base])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-machines"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = spec.craft_time,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_training_cluster(meta.TRAINING_CLUSTER)

-- ---------------------------------------------------------------------------
-- Inference Lab machine
-- ---------------------------------------------------------------------------

local function make_inference_lab(spec)
  local base = data.raw.lab[spec.base]
  if not base then
    error("chiptorio: base lab prototype '" .. spec.base .. "' not found")
  end

  local entity = M.copy(base)
  entity.name = spec.name
  entity.localised_name = nil
  entity.localised_description = nil
  entity.minable = { mining_time = 0.2, result = spec.name }
  entity.corpse = nil
  entity.next_upgrade = nil
  entity.hidden = false
  entity.hidden_in_factoriopedia = false
  entity.researching_speed = spec.researching_speed
  entity.energy_usage = spec.energy_usage
  entity.module_slots = spec.modules
  M.set_entity_icon(entity, spec.name)
  if spec.tint then
    M.tint_entity(entity, spec.tint)
  end
  data:extend({ entity })

  local item = M.copy(data.raw.item[spec.base])
  item.name = spec.name
  item.localised_name = nil
  item.localised_description = nil
  item.place_result = spec.name
  item.subgroup = "chiptorio-machines"
  item.order = spec.order
  item.hidden = false
  item.hidden_in_factoriopedia = false
  M.set_icon(item, spec.name)
  data:extend({ item })

  M.recipe({
    name = spec.name,
    enabled = false,
    category = "crafting",
    energy_required = 15,
    ingredients = spec.ingredients,
    results = { M.item(spec.name, 1) },
  })
end

make_inference_lab(meta.INFERENCE_LAB)

-- ---------------------------------------------------------------------------
-- Wire model recipes into gate technology effects.
-- ---------------------------------------------------------------------------

local function add_tech_effect(tech_name, effect_name)
  local tech = data.raw.technology[tech_name]
  if not tech then
    error("chiptorio: technology '" .. tostring(tech_name)
      .. "' not found; cannot unlock AI recipe '" .. tostring(effect_name) .. "'")
  end
  tech.effects = tech.effects or {}
  for _, existing in ipairs(tech.effects) do
    if type(existing) == "table" and existing.recipe == effect_name then
      return
    end
    if type(existing) == "string" and existing == effect_name then
      return
    end
  end
  table.insert(tech.effects, { type = "unlock-recipe", recipe = effect_name })
end

for _, tier in ipairs(meta.AI_TIERS) do
  add_tech_effect(tier.gate, tier.name)
end

-- Training Cluster and Inference Lab recipes unlocked by machine-learning.
add_tech_effect(meta.TRAINING_CLUSTER.gate, meta.TRAINING_CLUSTER.name)
add_tech_effect(meta.INFERENCE_LAB.gate, meta.INFERENCE_LAB.name)

return true
