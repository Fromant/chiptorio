-- Workloads: the six vanilla science packs, re-flavoured as the storage
-- media you feed into computers. We keep the prototype *names* so the entire
-- vanilla technology tree keeps working and only rewrite visuals + recipes.
--
-- Rule for the chain: every tier consumes a little of the previous tier, so
-- research has a real vertical dependency without multiplying costs 5x.

local M = require("scripts.util")

local workloads = {
  {
    name = "automation-science-pack",
    label = "punched-card",
    amount = 4,
    time = 4,
    ingredients = {
      M.item("iron-plate", 2),
      M.item("copper-cable", 2),
    },
  },
  {
    name = "logistic-science-pack",
    label = "punched-tape",
    amount = 4,
    time = 6,
    ingredients = {
      M.item("automation-science-pack", 2),
      M.item("electronic-circuit", 2),
    },
  },
  {
    name = "military-science-pack",
    label = "magnetic-tape",
    amount = 4,
    time = 8,
    ingredients = {
      M.item("logistic-science-pack", 2),
      M.item("steel-plate", 1),
      M.item("electronic-circuit", 1),
    },
  },
  {
    name = "chemical-science-pack",
    label = "disk-pack",
    amount = 2,
    time = 10,
    ingredients = {
      M.item("military-science-pack", 2),
      M.item("steel-plate", 2),
      M.item("electronic-circuit", 1),
    },
  },
  {
    name = "production-science-pack",
    label = "solid-state-drive",
    amount = 2,
    time = 12,
    category = "chiptorio-compute",
    ingredients = {
      M.item("chemical-science-pack", 1),
      M.item("integrated-circuit", 2),
      M.item("plastic-bar", 2),
    },
  },
  {
    name = "utility-science-pack",
    label = "mainframe-module",
    amount = 1,
    time = 16,
    category = "chiptorio-compute",
    ingredients = {
      M.item("production-science-pack", 1),
      M.item("microprocessor", 2),
      M.item("processing-unit", 1),
    },
  },
}

for _, w in ipairs(workloads) do
  local item = data.raw.item[w.name]
  local recipe = data.raw.recipe[w.name]
  if not item or not recipe then
    error("chiptorio: expected vanilla workload prototype '" .. w.name .. "'")
  end

  item.localised_name = { "item-name." .. w.label }
  item.localised_description = { "item-description." .. w.label }
  M.set_icon(item, w.label)

  if w.category then
    recipe.categories = { w.category }
  end
  recipe.ingredients = w.ingredients
  recipe.results = { M.item(w.name, w.amount) }
  recipe.energy_required = w.time
end
