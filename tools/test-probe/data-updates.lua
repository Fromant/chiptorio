-- Data-stage contract probe. Loaded as a separate mod after chiptorio, so
-- every prototype has been created and data-updates has run.
--
-- A failure raises a data-stage error. The PowerShell wrapper also scans the
-- log for the FAIL marker so a failed assertion cannot be mistaken for a
-- successful load.

local failures = {}

local function check(condition, message)
  if not condition then
    failures[#failures + 1] = message
  end
end

local ITEM_TYPES = {
  "item",
  "ammo",
  "gun",
  "armor",
  "capsule",
  "module",
  "tool",
  "item-with-entity-data",
  "item-with-tags",
  "rail-planner",
  "repair-tool",
  "selection-tool",
  "blueprint",
  "blueprint-book",
  "deconstruction-item",
  "upgrade-item",
  "copy-paste-tool",
  "spidertron-remote",
}

local COMBAT_SUBGROUPS = {
  gun = true,
  ammo = true,
  capsule = true,
  ["defensive-structure"] = true,
  turret = true,
  ["military-equipment"] = true,
}

local COMBAT_WHITELIST = {
  radar = true,
}

local ROBOT_ITEMS = {
  "roboport",
  "logistic-robot",
  "construction-robot",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
  "spidertron",
  "spidertron-remote",
}

local ROBOT_ENTITIES = { "roboport", "logistic-robot", "construction-robot", "spidertron" }

local ROBOT_TECHS = {
  "robotics",
  "construction-robotics",
  "logistic-robotics",
  "personal-roboport-equipment",
  "personal-roboport-mk2-equipment",
  "spidertron",
}

local EXTRA_COMBAT_ITEMS = { "tank", "artillery-wagon" }

local LABS = {
  "analytical-engine",
  "tube-mainframe",
  "mainframe-cluster",
  "datacenter",
  "cryostat",
}

local EXPECTED_HIDDEN_ITEMS = {}
for _, name in ipairs(ROBOT_ITEMS) do
  EXPECTED_HIDDEN_ITEMS[name] = true
end
for _, name in ipairs(EXTRA_COMBAT_ITEMS) do
  EXPECTED_HIDDEN_ITEMS[name] = true
end
for _, prototypes in pairs(data.raw) do
  for name, proto in pairs(prototypes) do
    if
      type(proto) == "table"
      and proto.subgroup
      and COMBAT_SUBGROUPS[proto.subgroup]
      and not COMBAT_WHITELIST[name]
    then
      EXPECTED_HIDDEN_ITEMS[name] = true
    end
  end
end

local function item(name)
  for _, item_type in ipairs(ITEM_TYPES) do
    local prototypes = data.raw[item_type]
    if prototypes and prototypes[name] then
      return prototypes[name]
    end
  end
  return nil
end

local function entity(name)
  for prototype_type, prototypes in pairs(data.raw) do
    if prototype_type ~= "item" and prototypes[name] then
      local proto = prototypes[name]
      if proto.type == prototype_type then
        return proto
      end
    end
  end
  return nil
end

local function is_item_name(name)
  return item(name) ~= nil
end

-- The starter chain must exist or a fresh save cannot research anything.
check(data.raw.recipe["analytical-engine"], "missing analytical-engine recipe")
check(
  data.raw.recipe["analytical-engine"] and data.raw.recipe["analytical-engine"].enabled ~= false,
  "analytical-engine must be craftable without research"
)
check(data.raw.item["analytical-engine"], "missing analytical-engine item")
check(data.raw.lab["lab"] and data.raw.lab["lab"].hidden, "the vanilla lab must be hidden")

local starter = data.raw.technology["automation-science-pack"]
check(starter, "missing automation-science-pack technology")
check(
  starter and starter.research_trigger and starter.research_trigger.item == "analytical-engine",
  "the first-science trigger must point at analytical-engine"
)

-- No enemy production on new maps.
for _, name in ipairs({
  "biter-spawner",
  "spitter-spawner",
  "small-worm-turret",
  "medium-worm-turret",
  "big-worm-turret",
  "behemoth-worm-turret",
}) do
  local proto = entity(name)
  check(proto, "missing enemy prototype " .. name)
  check(proto and proto.autoplace == nil, "enemy autoplace still enabled: " .. name)
  check(proto and proto.hidden, "enemy prototype is still visible: " .. name)
end

-- Robots, their infrastructure, and the spidertron are gone.
for _, name in ipairs(ROBOT_ITEMS) do
  local proto = item(name)
  check(proto, "missing robot prototype " .. name)
  check(proto and proto.hidden, "robot item is still visible: " .. name)
end
for _, name in ipairs(ROBOT_ENTITIES) do
  local proto = entity(name)
  check(proto, "missing robot entity " .. name)
  check(proto and proto.hidden, "robot entity is still visible: " .. name)
end
for _, name in ipairs(ROBOT_TECHS) do
  local tech = data.raw.technology[name]
  check(tech, "missing robot technology " .. name)
  check(tech and tech.hidden, "robot technology is still visible: " .. name)
end

-- Combat content is hidden by subgroup or by explicit name.
for name, hidden in pairs(EXPECTED_HIDDEN_ITEMS) do
  local proto = item(name)
  if proto then
    check(proto.hidden, "combat content is still visible: " .. name)
  end
end

-- A recipe counts as removed when it is named after, or produces, an item this
-- mod deliberately hides. Base-hidden items (rocket-part and friends) are not
-- part of this contract; they were hidden before chiptorio existed.
local function recipe_produces_removed_item(recipe)
  if EXPECTED_HIDDEN_ITEMS[recipe.name] then
    return true
  end
  local results = recipe.results or {}
  if recipe.result then
    results = { { type = "item", name = recipe.result } }
  end
  for _, result in ipairs(results) do
    if EXPECTED_HIDDEN_ITEMS[result.name] then
      return true
    end
  end
  return false
end

-- Hidden things must not leak into the visible tech tree or into visible
-- recipes. This is the contract that makes hiding safe.
for name, tech in pairs(data.raw.technology) do
  if not tech.hidden then
    for _, prereq in ipairs(tech.prerequisites or {}) do
      local prereq_tech = data.raw.technology[prereq]
      check(prereq_tech, "technology " .. name .. " has missing prerequisite " .. prereq)
      check(
        not (prereq_tech and prereq_tech.hidden),
        "visible technology " .. name .. " depends on hidden technology " .. prereq
      )
    end
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" then
        local recipe = data.raw.recipe[effect.recipe]
        check(recipe, "technology " .. name .. " unlocks missing recipe " .. effect.recipe)
        check(
          not (recipe and recipe_produces_removed_item(recipe)),
          "visible technology " .. name .. " unlocks removed recipe " .. effect.recipe
        )
      end
    end
  end
end

for name, recipe in pairs(data.raw.recipe) do
  if not recipe.hidden then
    local results = recipe.results or {}
    if recipe.result then
      results = { { type = "item", name = recipe.result } }
    end
    for _, result in ipairs(results) do
      if result.type == "item" or result.type == nil then
        local result_item = item(result.name)
        check(result_item, "recipe " .. name .. " produces missing item " .. result.name)
        check(
          not EXPECTED_HIDDEN_ITEMS[result.name],
          "visible recipe " .. name .. " produces hidden item " .. result.name
        )
      end
    end
    for _, ingredient in ipairs(recipe.ingredients or {}) do
      if (ingredient.type == "item" or ingredient.type == nil) and is_item_name(ingredient.name) then
        check(
          not EXPECTED_HIDDEN_ITEMS[ingredient.name],
          "visible recipe " .. name .. " consumes hidden item " .. ingredient.name
        )
      end
    end
  end
end

-- Every research computer must accept every workload. A pack that one lab
-- cannot read silently deadlocks the vanilla technology tree. The Answer
-- Engine is a lab clone with no inputs by design and is deliberately excluded.
local WORKLOADS = {
  "automation-science-pack",
  "logistic-science-pack",
  "military-science-pack",
  "chemical-science-pack",
  "production-science-pack",
  "utility-science-pack",
  "quantum-science-pack",
  "microprocessor",
}
for _, name in ipairs(LABS) do
  local lab = data.raw.lab[name]
  check(lab, "missing research computer " .. name)
  if lab then
    check(not lab.hidden, "research computer is hidden: " .. name)
    local inputs = {}
    for _, input in ipairs(lab.inputs or {}) do
      inputs[input] = true
    end
    for _, workload in ipairs(WORKLOADS) do
      check(inputs[workload], "lab " .. name .. " does not accept " .. workload)
    end
  end
end

if #failures > 0 then
  error("CHIPTORIO-TEST FAIL data: " .. table.concat(failures, "; "))
end

log("CHIPTORIO-TEST PASS data")
