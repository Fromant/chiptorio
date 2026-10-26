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
  "datacenter-lab",
  "cryostat",
}

local PROVIDERS = {
  "server-rack",
  "memory-bank",
  "datacenter",
}

local COMPUTE_MODULES = {
  "integrated-circuit",
  "microprocessor",
  "system-on-chip",
  "multi-core-cpu",
  "gpu",
  "quantum-processor",
}

local MEMORY_MODULES = {
  "sram-module",
  "dram-module",
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
      -- Recipes share a name with the item they make and carry a type, so
      -- require something entity-shaped before accepting a match.
      if
        proto.type == prototype_type
        and (proto.collision_box or proto.selection_box or proto.minable)
      then
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

-- Network wiring. Cable, switch, router and monitor are buildable containers;
-- the cable must sit on its own collision layer so cables stack-proof while
-- still passing under machines and belts.
local NETWORK_ENTITIES = {
  ["network-cable"] = { layer = "chiptorio-cable" },
  ["network-switch"] = { layer = nil },
  ["network-router"] = { layer = nil },
  ["network-monitor"] = { layer = nil },
}
for name, spec in pairs(NETWORK_ENTITIES) do
  local item = item(name)
  check(item, "missing network item " .. name)
  if item then
    check(not item.hidden, "network item is hidden: " .. name)
    check(item.place_result == name, "network item " .. name .. " does not place itself")
  end

  local proto = entity(name)
  check(proto, "missing network entity " .. name)
  if proto then
    check(not proto.hidden, "network entity is hidden: " .. name)
    check(proto.minable and proto.minable.result == name, "network entity " .. name .. " is not minable")
    check(
      proto.collision_box and proto.selection_box,
      "network entity " .. name .. " has no collision or selection box"
    )
    if spec.layer then
      local masks = proto.collision_mask and proto.collision_mask.layers or {}
      local layers = proto.collision_layer and proto.collision_layer.layers or {}
      check(masks[spec.layer], "network entity " .. name .. " is not on collision layer " .. spec.layer)
      check(layers[spec.layer], "network entity " .. name .. " does not collide on layer " .. spec.layer)
      check(
        not masks["object"] and not masks["player"] and not layers["object"],
        "network entity " .. name .. " should pass under machines and players"
      )
    end
  end

  local recipe = data.raw.recipe[name]
  check(recipe, "missing network recipe " .. name)
  if recipe then
    check(not recipe.hidden, "network recipe is hidden: " .. name)
    check(recipe.enabled == false, "network recipe should start locked: " .. name)
  end
end

check(
  data.raw["collision-layer"] and data.raw["collision-layer"]["chiptorio-cable"],
  "missing chiptorio-cable collision layer"
)

-- Compute chips and memory are modules, not plain items. The research runtime
-- reads them from a provider's module inventory, so a regression to an item
-- would silently remove all compute.
check(data.raw["module-category"]["chiptorio-chip"], "missing chiptorio-chip module category")
check(data.raw["module-category"]["chiptorio-memory"], "missing chiptorio-memory module category")
for _, name in ipairs(COMPUTE_MODULES) do
  local proto = data.raw.module[name]
  check(proto, "missing compute module " .. name)
  if proto then
    check(proto.category == "chiptorio-chip", "compute module " .. name .. " has the wrong category")
    check(proto.effect and next(proto.effect) == nil, "compute module " .. name .. " must have an empty effect")
    check(not proto.hidden, "compute module is hidden: " .. name)
  end
end
for _, name in ipairs(MEMORY_MODULES) do
  local proto = data.raw.module[name]
  check(proto, "missing memory module " .. name)
  if proto then
    check(proto.category == "chiptorio-memory", "memory module " .. name .. " has the wrong category")
    check(proto.effect and next(proto.effect) == nil, "memory module " .. name .. " must have an empty effect")
    check(not proto.hidden, "memory module is hidden: " .. name)
  end
  local recipe = data.raw.recipe[name]
  check(recipe, "missing memory module recipe " .. name)
  check(recipe and recipe.enabled == false, "memory module recipe should start locked: " .. name)
end

-- Providers are lab clones with no science inputs and a readable module
-- inventory. A provider that accepts a science pack would become an ordinary
-- lab and bypass the network.
for _, name in ipairs(PROVIDERS) do
  local proto = data.raw.lab[name]
  check(proto, "missing provider entity " .. name)
  if proto then
    check(not proto.hidden, "provider is hidden: " .. name)
    check(#(proto.inputs or {}) == 0, "provider " .. name .. " must have no science inputs")
    check((proto.module_slots or 0) > 0, "provider " .. name .. " has no module slots")
    local categories = {}
    for _, category in ipairs(proto.allowed_module_categories or {}) do
      categories[category] = true
    end
    check(categories["chiptorio-chip"], "provider " .. name .. " does not accept chips")
    check(categories["chiptorio-memory"], "provider " .. name .. " does not accept memory modules")
    check(
      not (data.raw["assembling-machine"] and data.raw["assembling-machine"][name]),
      "provider " .. name .. " must not be a crafting machine"
    )
  end
  local item = data.raw.item[name]
  check(item, "missing provider item " .. name)
  check(item and item.place_result == name, "provider item " .. name .. " does not place itself")
  local recipe = data.raw.recipe[name]
  check(recipe, "missing provider recipe " .. name)
  check(recipe and recipe.enabled == false, "provider recipe should start locked: " .. name)
end

check(data.raw.item["assembly-fab"], "missing assembly-fab item")
check(data.raw.recipe["assembly-fab"], "missing assembly-fab recipe")
check(
  data.raw["assembling-machine"] and data.raw["assembling-machine"]["assembly-fab"],
  "missing assembly-fab entity"
)

local internet = data.raw.technology["internet"]
check(internet, "missing internet technology")
if internet then
  check(not internet.hidden, "internet technology is hidden")
  local unlocked = {}
  for _, effect in ipairs(internet.effects or {}) do
    if effect.type == "unlock-recipe" then
      unlocked[effect.recipe] = true
    end
  end
  for name in pairs(NETWORK_ENTITIES) do
    check(unlocked[name], "internet does not unlock " .. name)
  end
  check(unlocked["server-rack"], "internet does not unlock the server-rack provider")
  check(unlocked["memory-bank"], "internet does not unlock the memory bank")
  check(unlocked["sram-module"], "internet does not unlock SRAM")
  check(unlocked["assembly-fab"], "internet does not unlock the assembly fab")
end

local datacenter_tech = data.raw.technology["datacenter"]
check(datacenter_tech, "missing datacenter technology")
if datacenter_tech then
  local unlocked = {}
  for _, effect in ipairs(datacenter_tech.effects or {}) do
    if effect.type == "unlock-recipe" then
      unlocked[effect.recipe] = true
    end
  end
  check(unlocked["datacenter"], "datacenter technology does not unlock the provider")
  check(unlocked["datacenter-lab"], "datacenter technology does not unlock the lab")
  check(unlocked["dram-module"], "datacenter technology does not unlock DRAM")
end

local vlsi = data.raw.technology["vlsi-process"]
check(vlsi, "missing vlsi-process technology")
if vlsi then
  local prerequisites = {}
  for _, name in ipairs(vlsi.prerequisites or {}) do
    prerequisites[name] = true
  end
  check(prerequisites["internet"], "vlsi-process must require the internet")
end

local overlay_input = data.raw["custom-input"]["chiptorio-network-overlay"]
check(overlay_input, "missing chiptorio-network-overlay custom input")

local monitor_shortcut = data.raw.shortcut["chiptorio-network-monitor"]
check(monitor_shortcut, "missing chiptorio-network-monitor shortcut")
if monitor_shortcut then
  check(monitor_shortcut.technology_to_unlock == "internet", "monitor shortcut is not gated on internet")
end

if #failures > 0 then
  error("CHIPTORIO-TEST FAIL data: " .. table.concat(failures, "; "))
end

log("CHIPTORIO-TEST PASS data")
