-- data-updates pruning: Chiptorio has no enemies, robots, or combat.
--
-- We do not delete vanilla prototypes. Deleting an item or entity means
-- scrubbing every prototype that references it, and one missed reference is a
-- load-stage crash. Instead we hide the content, disable its recipes, remove
-- its technologies, and rewire the remaining technology graph. Hidden
-- prototypes cannot be built, researched, or seen in the crafting menu, which
-- is the gameplay contract that matters.
--
-- The test probe in tools/test-probe asserts the contract after this module
-- runs.

local M = {}

local util = require("scripts.util")

local function find_prototype(name)
  for _, prototypes in pairs(data.raw) do
    local proto = prototypes[name]
    if proto then
      return proto
    end
  end
  return nil
end

local function for_each_item(fn)
  for _, prototypes in pairs(data.raw) do
    for name, proto in pairs(prototypes) do
      if type(proto) == "table" and proto.subgroup then
        fn(name, proto)
      end
    end
  end
end

-- Item subgroups that are pure combat. Armour and utility equipment are
-- deliberately excluded: the character still uses armour, exoskeletons, and
-- personal power, and none of those need a gun.
local COMBAT_SUBGROUPS = {
  gun = true,
  ammo = true,
  capsule = true,
  ["defensive-structure"] = true,
  turret = true,
  ["military-equipment"] = true,
}

-- Radar shares the defensive-structure subgroup with walls and mines but is
-- not combat content. Keep it visible.
local COMBAT_WHITELIST = {
  radar = true,
}

-- Robots, their ports, their chests, and the spidertron. The spidertron is a
-- bot platform in all but name and the design removes it.
local ROBOT_ITEMS = {
  "roboport",
  "logistic-robot",
  "construction-robot",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
  "requester-chest",
  "buffer-chest",
  "active-provider-chest",
  "passive-provider-chest",
  "spidertron",
  "spidertron-remote",
}

-- Vehicles and weapons that are not in a combat item subgroup.
local EXTRA_COMBAT_ITEMS = {
  "tank",
  "artillery-wagon",
}

local ROBOT_TECHS = {
  "robotics",
  "construction-robotics",
  "logistic-robotics",
  "worker-robots-speed-1",
  "worker-robots-speed-2",
  "worker-robots-speed-3",
  "worker-robots-speed-4",
  "worker-robots-speed-5",
  "worker-robots-speed-6",
  "worker-robots-storage-1",
  "worker-robots-storage-2",
  "worker-robots-storage-3",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
  "spidertron",
}

-- Effects that only make sense with enemies or robots. Removing them lets the
-- generic pass below notice that a technology is now empty and hide it.
local REMOVED_EFFECT_TYPES = {
  ["ammo-damage"] = true,
  ["gun-speed"] = true,
  ["turret-attack"] = true,
  ["artillery-range"] = true,
  ["maximum-following-robots-count"] = true,
  ["worker-robot-speed"] = true,
  ["worker-robot-storage"] = true,
  ["character-logistic-slots"] = true,
  ["vehicle-logistics"] = true,
}

local hidden_items = {}
local hidden_recipes = {}
local hidden_techs = {}

local function hide_item(name)
  local hidden = false
  for_each_item(function(item_name, item)
    if item_name == name then
      item.hidden = true
      item.hidden_in_factoriopedia = true
      hidden_items[name] = true
      hidden = true
    end
  end)
  return hidden
end

local function hide_entity(name)
  for _, prototypes in pairs(data.raw) do
    local proto = prototypes[name]
    if proto and proto.type and proto.type ~= "item" then
      proto.hidden = true
      proto.hidden_in_factoriopedia = true
    end
  end
end

local function hide_place_results()
  for name in pairs(hidden_items) do
    -- A hidden item and its recipe share a name, so search every prototype
    -- for a place_result instead of trusting the first name match.
    for _, prototypes in pairs(data.raw) do
      local proto = prototypes[name]
      if proto and proto.place_result then
        hide_entity(proto.place_result)
      end
    end
  end
end

local function recipe_result_names(recipe)
  local names = {}
  if recipe.results then
    for _, result in ipairs(recipe.results) do
      if result.type == "item" or result.type == nil then
        names[#names + 1] = result.name
      end
    end
  elseif recipe.result then
    names[#names + 1] = recipe.result
  end
  return names
end

local function hide_recipe(name)
  local recipe = data.raw.recipe[name]
  if recipe then
    recipe.hidden = true
    recipe.enabled = false
    hidden_recipes[name] = true
  end
end

local function hide_recipes_for_hidden_items()
  for name, recipe in pairs(data.raw.recipe) do
    local results = recipe_result_names(recipe)
    if #results > 0 then
      local all_hidden = true
      local any_hidden = false
      for _, result in ipairs(results) do
        if hidden_items[result] then
          any_hidden = true
        else
          all_hidden = false
        end
      end
      if all_hidden or any_hidden and #results == 1 then
        hide_recipe(name)
      end
    end
  end
  for name in pairs(hidden_items) do
    hide_recipe(name)
  end
end

-- Some visible recipes legitimately use a removed item. Cliff explosives are
-- terrain tools, not combat, but they consume a grenade. Rather than hide the
-- tool, substitute a harmless ingredient. Anything without a substitute makes
-- its recipe hidden, so a visible recipe can never consume a hidden item.
local INGREDIENT_SUBSTITUTES = {
  grenade = { type = "item", name = "steel-plate", amount = 1 },
}

local function scrub_hidden_ingredients()
  for name, recipe in pairs(data.raw.recipe) do
    if not recipe.hidden then
      local kept = {}
      local substituted = false
      local keep_recipe = true
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        if hidden_items[ingredient.name] then
          local replacement = INGREDIENT_SUBSTITUTES[ingredient.name]
          if replacement then
            kept[#kept + 1] = util.copy(replacement)
            substituted = true
          else
            keep_recipe = false
            break
          end
        else
          kept[#kept + 1] = ingredient
        end
      end
      if not keep_recipe then
        hide_recipe(name)
      elseif substituted then
        recipe.ingredients = kept
      end
    end
  end
end

local function remove_enemy_autoplace()
  -- These are the only base prototypes that place enemies on the map. Keeping
  -- the `enemy-base` autoplace control itself avoids invalidating the base
  -- planet map-gen tables; with no producer referencing it, it generates
  -- nothing.
  for _, name in ipairs({
    "biter-spawner",
    "spitter-spawner",
    "small-worm-turret",
    "medium-worm-turret",
    "big-worm-turret",
    "behemoth-worm-turret",
  }) do
    local proto = find_prototype(name)
    if proto then
      proto.autoplace = nil
      proto.hidden = true
      proto.hidden_in_factoriopedia = true
    end
  end
end

local function prune_technologies()
  for _, name in ipairs(ROBOT_TECHS) do
    hidden_techs[name] = true
  end

  local changed = true
  while changed do
    changed = false
    for name, tech in pairs(data.raw.technology) do
      if not hidden_techs[name] then
        local had_effects = tech.effects and #tech.effects > 0
        local kept = {}
        for _, effect in ipairs(tech.effects or {}) do
          local keep = true
          if REMOVED_EFFECT_TYPES[effect.type] then
            keep = false
          elseif effect.type == "unlock-recipe" and hidden_recipes[effect.recipe] then
            keep = false
          end
          if keep then
            kept[#kept + 1] = effect
          end
        end

        if tech.prerequisites then
          local prereqs = {}
          for _, prereq in ipairs(tech.prerequisites) do
            if not hidden_techs[prereq] then
              prereqs[#prereqs + 1] = prereq
            end
          end
          tech.prerequisites = prereqs
        end

        if had_effects and #kept == 0 and not tech.research_trigger then
          hidden_techs[name] = true
          changed = true
        else
          tech.effects = kept
        end
      end
    end
  end

  for name in pairs(hidden_techs) do
    local tech = data.raw.technology[name]
    if tech then
      tech.hidden = true
      tech.hidden_in_factoriopedia = true
    end
  end
end

function M.apply()
  remove_enemy_autoplace()

  for _, name in ipairs(ROBOT_ITEMS) do
    hide_item(name)
  end
  for _, name in ipairs(EXTRA_COMBAT_ITEMS) do
    hide_item(name)
  end

  for_each_item(function(name, item)
    if COMBAT_SUBGROUPS[item.subgroup] and not COMBAT_WHITELIST[name] then
      item.hidden = true
      item.hidden_in_factoriopedia = true
      hidden_items[name] = true
    end
  end)

  hide_place_results()
  hide_recipes_for_hidden_items()
  scrub_hidden_ingredients()
  prune_technologies()

  return {
    hidden_items = hidden_items,
    hidden_recipes = hidden_recipes,
    hidden_techs = hidden_techs,
  }
end

return M
