-- Data-stage contract probe. Loaded as a separate mod after chiptorio, so
-- every prototype has been created and data-updates has run.
--
-- A failure raises a data-stage error. The PowerShell wrapper also scans the
-- log for the FAIL marker so a failed assertion cannot be mistaken for a
-- successful load.

local failures = {}

local nodes = require("__chiptorio__/scripts/process_nodes")
local qmeta = require("__chiptorio__/scripts/qln_meta")
local rmeta = require("__chiptorio__/scripts/research_meta")
local answer_meta = require("__chiptorio__/scripts/answer_meta")

local function check(condition, message)
  if not condition then
    failures[#failures + 1] = message
  end
end

-- Chiptorio-created prototype detection (moved up for use in early tests)
local chiptorio_prefixes = {
  "chiptorio-", "network-", "qln-", "foup-", "node-", "refine-",
}

local function is_chiptorio_created(name)
  -- Chiptorio-created prototypes use these prefixes.
  for _, prefix in ipairs(chiptorio_prefixes) do
    if name:sub(1, #prefix) == prefix then
      return true
    end
  end
  -- Also cover vanilla-internal names that Chiptorio re-themes and explicitly
  -- sets locale/icons on (circuits.lua, labs.lua, etc.).
  if name == "electronic-circuit" or name == "advanced-circuit" or name == "processing-unit"
     or name == "analytical-engine" then
    return true
  end
  return false
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

local COMPUTER_MODULES = {
  "microcomputer",
  "server",
  "supercomputer",
  "neural-computer",
  "quantum-computer",
}

local AI_MODEL_ITEMS = {
  "small-model",
  "specialist-model",
  "general-model",
  "frontier-model",
  "agi-model",
}

local AI_BUILDINGS = {
  "training-cluster",
  "inference-lab",
}

local AI_TECHNOLOGIES = {
  "machine-learning",
  "ai-specialist",
  "ai-general",
  "ai-frontier",
  "artificial-general-intelligence",
}

-- DESIGN §8.3. Order matters: the ladder is asserted to be monotonic in both
-- research capacity and QLN cells.
local MEMORY_MODULES = {
  "sram-module",
  "dram-module",
  "sdram-module",
  "ddr-module",
  "ddr2-module",
  "ddr3-module",
  "ddr4-module",
  "ddr5-module",
  "hbm-module",
  "hbm3-module",
  "3d-nand-module",
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

--- Find the first filename inside a Sprite / Sprite4Way so the probe can tell a
--- real world sprite from an item icon scaled onto the map.
local function picture_filename(sprite)
  if type(sprite) ~= "table" then
    return nil
  end
  if type(sprite.filename) == "string" then
    return sprite.filename
  end
  if type(sprite.layers) == "table" then
    for _, layer in ipairs(sprite.layers) do
      local filename = picture_filename(layer)
      if filename then
        return filename
      end
    end
  end
  return nil
end

local function check_world_picture(proto, name)
  -- Containers and combinators keep a single `picture`; connection-aware pipe
  -- clones keep one sprite per connection shape in `pictures`.
  local picture = proto.picture
  if not picture and type(proto.pictures) == "table" then
    picture = proto.pictures.straight_vertical_single
      or proto.pictures.straight_vertical
      or proto.pictures.single
      or proto.pictures.north
  end
  local filename = picture_filename(picture)
  check(filename, "entity " .. name .. " has no world sprite")
  if filename then
    check(
      not string.find(filename, "graphics/icons/", 1, true),
      "entity " .. name .. " still uses an item icon as its world sprite"
    )
  end
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

-- Bootstrap power and cable. The Analytical Engine needs a pole to run, and
-- Punched Cards need copper cable. Both recipes come from `electronics`, the
-- vanilla "craft copper plates" trigger, so that technology must stay
-- reachable without research. Gating it behind Thermionics deadlocks the game:
-- Electromechanics costs punched cards, which need the cable it unlocks.
local electronics = data.raw.technology["electronics"]
check(electronics, "missing electronics technology")
if electronics then
  check(
    not electronics.prerequisites or #electronics.prerequisites == 0,
    "electronics must be an early trigger technology, not a research-gated one"
  )
  check(
    electronics.research_trigger and electronics.research_trigger.item == "copper-plate",
    "electronics must still be triggered by crafting copper plates"
  )
  local electronics_effects = {}
  for _, effect in ipairs(electronics.effects or {}) do
    if effect.type == "unlock-recipe" then
      electronics_effects[effect.recipe] = true
    end
  end
  check(electronics_effects["copper-cable"], "electronics must unlock copper-cable for the bootstrap")
  check(
    electronics_effects["small-electric-pole"],
    "electronics must unlock small-electric-pole so the Analytical Engine can be powered"
  )
  check(
    not electronics_effects["electronic-circuit"],
    "electronics must not unlock the Control Board before Thermionics"
  )
  for _, name in ipairs({ "copper-cable", "small-electric-pole" }) do
    local recipe = data.raw.recipe[name]
    check(recipe and not recipe.hidden, name .. " must be a visible recipe")
  end
end

-- Everything the starter science pack requires must itself be reachable
-- without research. Otherwise the first technology has a cost deadlock: the
-- trigger technology is waiting on the first research it is supposed to pay for.
local starter_tech = data.raw.technology["automation-science-pack"]
if starter_tech then
  local unlocks_starter = false
  for _, effect in ipairs(starter_tech.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == "automation-science-pack" then
      unlocks_starter = true
    end
  end
  check(unlocks_starter, "the starter technology must unlock the Punched Cards recipe")
  local starter_recipe = data.raw.recipe["automation-science-pack"]
  check(starter_recipe and not starter_recipe.hidden, "Punched Cards must be a visible recipe")
  for _, prereq in ipairs(starter_tech.prerequisites or {}) do
    local tech = data.raw.technology[prereq]
    check(tech, "automation-science-pack has missing prerequisite " .. prereq)
    if tech then
      check(
        tech.research_trigger ~= nil
          and (not tech.prerequisites or #tech.prerequisites == 0),
        "starter prerequisite " .. prereq .. " must be reachable without research"
      )
    end
  end
end

local thermionics = data.raw.technology["thermionics"]
check(thermionics, "missing thermionics technology")
if thermionics then
  local unlocks_control_board = false
  for _, effect in ipairs(thermionics.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe == "electronic-circuit" then
      unlocks_control_board = true
    end
  end
  check(unlocks_control_board, "thermionics must unlock electronic-circuit (Control Board)")
end

-- The workload technologies are named after the medium they unlock. The
-- prototype-level localised_name must point at the item key, not the vanilla
-- technology key: the base game ships translations for the latter, and they
-- take precedence over this mod's technology-name entries.
local WORKLOAD_TECH_NAMES = {
  { "automation-science-pack", "punched-card" },
  { "logistic-science-pack", "punched-tape" },
  { "military-science-pack", "magnetic-tape" },
  { "chemical-science-pack", "disk-pack" },
  { "production-science-pack", "solid-state-drive" },
  { "utility-science-pack", "mainframe-module" },
}
for _, entry in ipairs(WORKLOAD_TECH_NAMES) do
  local name, label = entry[1], entry[2]
  local tech = data.raw.technology[name]
  check(tech, "missing workload technology " .. name)
  if tech then
    local localised_name = tech.localised_name
    check(
      type(localised_name) == "table" and localised_name[1] == "item-name." .. label,
      name .. " must be named after item-name." .. label
    )
  end
end

-- Vanilla gates the military pack behind combat technologies, which
-- scripts/prune.lua removes. It must stay gated on the two workloads that
-- precede it instead, or it would be researchable from a fresh save.
local military = data.raw.technology["military-science-pack"]
check(military, "missing military-science-pack technology")
if military then
  check(not military.hidden, "military-science-pack must remain visible after pruning")
  local prerequisites = {}
  for _, prereq in ipairs(military.prerequisites or {}) do
    prerequisites[prereq] = true
  end
  check(
    prerequisites["automation-science-pack"],
    "military-science-pack must require automation-science-pack (punched cards)"
  )
  check(
    prerequisites["logistic-science-pack"],
    "military-science-pack must require logistic-science-pack (punched tape)"
  )
  for _, prereq in ipairs({ "automation-science-pack", "logistic-science-pack" }) do
    local tech = data.raw.technology[prereq]
    check(tech and not tech.hidden, prereq .. " must remain visible so it can gate military-science-pack")
  end
end

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

-- Helper: check if input is in the expected list
local function expected_input(input, expected_list)
  for _, w in ipairs(expected_list) do
    if w == input then
      return true
    end
  end
  return false
end

-- Every research computer accepts only the workloads up to its tier.
-- Gating packs by lab prevents deadlocks and keeps the GUI clean.
-- The Answer Engine is a lab clone with no inputs by design and is deliberately excluded.
local EXPECTED_LAB_INPUTS = {
  ["analytical-engine"] = {
    "automation-science-pack",
  },
  ["tube-mainframe"] = {
    "automation-science-pack",
    "logistic-science-pack",
  },
  ["mainframe-cluster"] = {
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
  },
  ["datacenter-lab"] = {
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
    "chemical-science-pack",
  },
  ["cryostat"] = {
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "chiptorio-optical-science-pack",
    "chiptorio-hbm-science-pack",
    "chiptorio-quantum-science-pack",
    "microprocessor",
  },
}
for _, name in ipairs(LABS) do
  local lab = data.raw.lab[name]
  check(lab, "missing research computer " .. name)
  if lab then
    check(not lab.hidden, "research computer is hidden: " .. name)
    local expected = EXPECTED_LAB_INPUTS[name]
    check(expected, "no expected inputs defined for lab " .. name)
    if expected then
      local actual = {}
      for _, input in ipairs(lab.inputs or {}) do
        actual[input] = true
      end
      -- Check every expected input is present
      for _, workload in ipairs(expected) do
        check(actual[workload], "lab " .. name .. " does not accept " .. workload)
      end
      -- Check no unexpected inputs are present
      for input in pairs(actual) do
        check(expected_input(input, expected), "lab " .. name .. " accepts unexpected input " .. input)
      end
    end
  end
end

-- Network wiring. Switches, routers and monitors are buildable containers.
-- Cables collide with everything (object layer) so they route around machines;
-- they cannot pass under belts or assemblers. Switches and routers are 3×2
-- rotatable junction boxes and gateways.
local NETWORK_ENTITIES = {
  ["network-cable"] = { layer = "object", collides_with_everything = true },
  ["network-switch"] = { layer = nil },
  ["network-router"] = { layer = nil },
  ["network-monitor"] = { layer = nil },
}
-- Newer cable tiers are unlocked by later process nodes.
local CABLE_TIER_TECHS = {
  ["network-coaxial-cable"] = "process-350nm",
  ["network-fiber-mm-cable"] = "process-90nm",
  ["network-fiber-sm-cable"] = "process-7nm",
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
    check_world_picture(proto, name)
    if spec.layer then
      local masks = proto.collision_mask and proto.collision_mask.layers or {}
      local layers = proto.collision_layer and proto.collision_layer.layers or {}
      check(masks[spec.layer], "network entity " .. name .. " is not on collision layer " .. spec.layer)
      check(layers[spec.layer], "network entity " .. name .. " does not collide on layer " .. spec.layer)
      if spec.collides_with_everything then
        check(masks["object"], "network entity " .. name .. " should collide with objects")
        check(layers["object"], "network entity " .. name .. " should be on object layer")
      else
        check(
          not masks["object"] and not masks["player"] and not layers["object"],
          "network entity " .. name .. " should pass under machines and players"
        )
      end
    end
  end

  local recipe = data.raw.recipe[name]
  check(recipe, "missing network recipe " .. name)
  if recipe then
    check(not recipe.hidden, "network recipe is hidden: " .. name)
    check(recipe.enabled == false, "network recipe should start locked: " .. name)
  end
end

-- Newer cable tiers must exist as entities and recipes, unlocked by their node techs.
for name, tech_name in pairs(CABLE_TIER_TECHS) do
  local item = item(name)
  check(item, "missing cable tier item " .. name)
  local proto = entity(name)
  check(proto, "missing cable tier entity " .. name)
  check(proto.collision_mask and proto.collision_mask.layers and proto.collision_mask.layers["object"],
    "cable tier " .. name .. " should collide with objects")
  check(proto.collision_layer and proto.collision_layer.layers and proto.collision_layer.layers["object"],
    "cable tier " .. name .. " should be on object layer")
  local recipe = data.raw.recipe[name]
  check(recipe, "missing cable tier recipe " .. name)
  local tech = data.raw.technology[tech_name]
  check(tech, "missing tier unlock technology " .. tech_name)
  if tech then
    local unlocked = {}
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" then
        unlocked[effect.recipe] = true
      end
    end
    check(unlocked[name], tech_name .. " does not unlock " .. name)
  end
end

check(
  data.raw["collision-layer"] and data.raw["collision-layer"]["chiptorio-cable"],
  "missing chiptorio-cable collision layer"
)

-- Cables are pipe clones so the engine auto-tiles the sprite from the
-- connection shape (straight, corner, T, cross, ending), but every shape is
-- custom cable art generated by tools/make-icons.ps1. The private fluid
-- connection category is what makes the clone safe: a cable must never join a
-- vanilla fluid network, and every tier must share the category so mixed runs
-- still look continuous and follow the weakest-link rule.
local CABLE_NAMES = {
  "network-cable",
  "network-coaxial-cable",
  "network-fiber-mm-cable",
  "network-fiber-sm-cable",
}
local CABLE_SHAPES = {
  "straight_vertical_single",
  "straight_vertical",
  "straight_horizontal",
  "corner_up_right",
  "corner_up_left",
  "corner_down_right",
  "corner_down_left",
  "t_up",
  "t_down",
  "t_left",
  "t_right",
  "cross",
  "ending_up",
  "ending_down",
  "ending_left",
  "ending_right",
}
for _, name in ipairs(CABLE_NAMES) do
  local proto = entity(name)
  check(proto, "missing cable prototype " .. name)
  if proto then
    check(proto.type == "pipe",
      "cable " .. name .. " must be a pipe prototype for connection-aware sprites")
    for _, shape in ipairs(CABLE_SHAPES) do
      local sprite = proto.pictures and proto.pictures[shape]
      check(sprite, "cable " .. name .. " has no " .. shape .. " sprite")
      local filename = picture_filename(sprite)
      check(
        filename and string.find(filename, "__chiptorio__/graphics/entity/cable/", 1, true),
        "cable " .. name .. " " .. shape .. " must use a generated cable sprite"
      )
      check(sprite and sprite.tint, "cable " .. name .. " " .. shape .. " sprite must be tier-tinted")
    end
    -- The fluid window shapes are aliases: a cable never carries fluid, but the
    -- pipe renderer may still ask for the keys.
    check(proto.pictures and proto.pictures.straight_vertical_window,
      "cable " .. name .. " is missing the vertical window sprite alias")
    check(proto.pictures and proto.pictures.straight_horizontal_window,
      "cable " .. name .. " is missing the horizontal window sprite alias")
    -- The whole picture table must be custom art: a leftover base sprite would
    -- show up as a vanilla pipe segment inside a cable run.
    for shape, sprite in pairs(proto.pictures or {}) do
      local filename = picture_filename(sprite)
      check(
        filename and not string.find(filename, "__base__", 1, true),
        "cable " .. name .. " shape " .. shape .. " still points at vanilla pipe art"
      )
    end
    check(proto.fluid_box and not proto.fluid_box.pipe_covers,
      "cable " .. name .. " must not draw vanilla pipe covers")
    local connections = proto.fluid_box and proto.fluid_box.pipe_connections or {}
    check(#connections == 4, "cable " .. name .. " must have four pipe connections")
    for _, connection in ipairs(connections or {}) do
      local categories = connection.connection_category
      local list = type(categories) == "table" and categories or { categories }
      check(#list == 1 and list[1] == "chiptorio-cable",
        "cable " .. name .. " must use only the private chiptorio-cable connection category")
    end
    check(proto.fluid_box and proto.fluid_box.volume == 1,
      "cable " .. name .. " fluid box must stay inert")
  end
end

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

-- Computer modules are modules, not plain items. Providers read them from
-- their module inventory to supply network compute.
check(data.raw["module-category"]["chiptorio-computer"], "missing chiptorio-computer module category")
for _, name in ipairs(COMPUTER_MODULES) do
  local proto = data.raw.module[name]
  check(proto, "missing computer module " .. name)
  if proto then
    check(proto.category == "chiptorio-computer", "computer module " .. name .. " has the wrong category")
    check(proto.effect and next(proto.effect) == nil, "computer module " .. name .. " must have an empty effect")
    check(not proto.hidden, "computer module is hidden: " .. name)
  end
  local recipe = data.raw.recipe[name]
  check(recipe, "missing computer module recipe " .. name)
  check(recipe and recipe.enabled == false, "computer module recipe should start locked: " .. name)
end

-- AI model items are modules consumed by the Training Cluster to produce models.
for _, name in ipairs(AI_MODEL_ITEMS) do
  local proto = data.raw.item[name]
  check(proto, "missing AI model item " .. name)
  local recipe = data.raw.recipe[name]
  check(recipe, "missing AI model recipe " .. name)
  check(recipe and recipe.enabled == false, "AI model recipe should start locked: " .. name)
end

-- AI buildings: Training Cluster (assembling-machine) and Inference Lab (lab).
for _, name in ipairs(AI_BUILDINGS) do
  local entity = data.raw["assembling-machine"][name] or data.raw.lab[name]
  check(entity, "missing AI building entity " .. name)
  local item = data.raw.item[name]
  check(item, "missing AI building item " .. name)
  local recipe = data.raw.recipe[name]
  check(recipe, "missing AI building recipe " .. name)
end

-- AI technologies must exist and be reachable.
for _, name in ipairs(AI_TECHNOLOGIES) do
  local tech = data.raw.technology[name]
  check(tech, "missing AI technology " .. name)
end


-- Every memory generation must be reachable, and it must carry both uses:
-- research dataset/bandwidth (research_meta) and QLN cells (qln_meta). The
-- ladder is monotonic, so no generation is a downgrade in capacity or storage.
local memory_unlock = {}
for tech_name, tech in pairs(data.raw.technology) do
  for _, effect in ipairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" and data.raw.recipe[effect.recipe] and effect.recipe:find("module$") then
      check(
        memory_unlock[effect.recipe] == nil,
        "memory recipe unlocked by two technologies: " .. effect.recipe
      )
      memory_unlock[effect.recipe] = tech_name
    end
  end
end

local previous_capacity = 0
local previous_cells = 0
for _, name in ipairs(MEMORY_MODULES) do
  local profile = rmeta.MEMORY_PROFILES[name]
  check(profile, "memory module has no research profile: " .. name)
  if profile then
    check(profile.capacity > previous_capacity,
      "memory capacity is not monotonic at " .. name .. ": " .. tostring(profile.capacity))
    check(profile.bandwidth > 0, "memory module has no bandwidth: " .. name)
    previous_capacity = profile.capacity
  end
  local cells = qmeta.DRIVE_CELLS[name]
  check(cells, "memory module has no QLN cells: " .. name)
  if cells then
    check(cells > previous_cells,
      "QLN cells are not monotonic at " .. name .. ": " .. tostring(cells))
    previous_cells = cells
  end
  local tech_name = memory_unlock[name]
  check(tech_name, "memory module recipe is never unlocked: " .. name)
  if tech_name and name ~= "sram-module" then
    check(tech_name:find("^process%-"), "memory module " .. name .. " is unlocked by " .. tech_name)
  end
end
check(memory_unlock["sram-module"] == "internet", "SRAM must stay an Internet unlock")
check(memory_unlock["dram-module"] == "process-3um", "DRAM must stay on the 3 µm node")
check(memory_unlock["3d-nand-module"] == "process-7nm", "3D NAND must arrive with the 7 nm node")

-- Providers are standalone assembling-machine clones with crafting disabled
-- (crafting_speed = 0.001, effectively never crafts) and a readable module
-- inventory. A provider that accepts a science pack would become an ordinary
-- lab and bypass the network.
for _, name in ipairs(PROVIDERS) do
  local proto = data.raw["assembling-machine"][name]
  check(proto, "missing provider entity " .. name)
  if proto then
    check(not proto.hidden, "provider is hidden: " .. name)
    check((proto.crafting_speed or 0) < 0.01, "provider " .. name .. " crafting must be disabled")
    check((proto.module_slots or 0) > 0, "provider " .. name .. " has no module slots")
    local categories = {}
    for _, category in ipairs(proto.allowed_module_categories or {}) do
      categories[category] = true
    end
    check(categories["chiptorio-computer"], "provider " .. name .. " does not accept computer modules")
    -- Only memory-bank and datacenter have memory slots; server-rack does not.
    local expect_memory = (name == "memory-bank" or name == "datacenter")
    check((categories["chiptorio-memory"] or false) == expect_memory,
      "provider " .. name .. " memory category mismatch: expected " .. tostring(expect_memory))
    check(
      data.raw["assembling-machine"] and data.raw["assembling-machine"][name],
      "provider " .. name .. " must be an assembling machine"
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
  -- Production science packs are assembled in the Assembly Fab, and the
  -- technology tree needs them before it can reach the internet. Gating the
  -- fab on the internet closes a research cycle, so it must NOT be here.
  check(not unlocked["assembly-fab"], "internet unlocks the assembly fab and deadlocks production science")
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

-- Process-node ladder. Every node must be a complete manufacturing family:
-- three item prototypes, three locked recipes and one technology that unlocks
-- all three plus one packaging recipe per supported architecture. A node whose
-- technology forgets a recipe is unreachable content.
local ARCHITECTURES = {
  ["integrated-circuit"] = true,
  ["microprocessor"] = true,
  ["system-on-chip"] = true,
  ["gpu"] = true,
  ["multi-core-cpu"] = true,
  ["quantum-processor"] = true,
}
local function unlocked_recipes(tech_name)
  local unlocked = {}
  local tech = data.raw.technology[tech_name]
  if not tech then
    return unlocked
  end
  for _, effect in ipairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" then
      unlocked[effect.recipe] = true
    end
  end
  return unlocked
end

for _, node in ipairs(nodes.NODES) do
  local names = nodes.items(node.key)
  for _, name in ipairs({ names.mask, names.wafer, names.die }) do
    local proto = item(name)
    check(proto, "missing process-node item " .. name)
    check(proto and not proto.hidden, "process-node item is hidden: " .. name)
    local recipe = data.raw.recipe[name]
    check(recipe, "missing process-node recipe " .. name)
    check(recipe and recipe.enabled == false, "process-node recipe should start locked: " .. name)
  end

  local tech_name = nodes.tech_name(node.key)
  local tech = data.raw.technology[tech_name]
  check(tech, "missing process-node technology " .. tech_name)
  local unlocked = unlocked_recipes(tech_name)
  for _, name in ipairs({ names.mask, names.wafer, names.die }) do
    check(unlocked[name], tech_name .. " does not unlock " .. name)
  end
  if node.key == "10um" then
    -- The Assembly Fab packages the first die. It belongs with the first
    -- process node, not with the internet (see the internet block above).
    check(unlocked["assembly-fab"], "process-10um does not unlock the assembly fab")
  end
  check(#node.chips > 0, "process node " .. node.key .. " packages no architecture")
  for _, chip in ipairs(node.chips) do
    check(ARCHITECTURES[chip], "process node " .. node.key .. " packages unknown architecture " .. chip)
    local packaging = chip .. "-from-" .. node.key
    check(data.raw.recipe[packaging], "missing packaging recipe " .. packaging)
    check(unlocked[packaging], tech_name .. " does not unlock " .. packaging)
  end
end

-- Half-node refinements. Researching a refine technology must create a real
-- pilot line and a real Metrology Lab, and the lab must accept every PQW.
-- Qualification itself is runtime state, so the data contract checks the
-- unlocking, the items and the lab inputs, not the bonus.
for _, node in ipairs(nodes.NODES) do
  local names = nodes.items(node.key)
  for _, name in ipairs({ names.wafer, names.die }) do
    local recipe = data.raw.recipe[name]
    check(recipe and recipe.allow_productivity == true, "node recipe cannot take the yield bonus: " .. name)
  end
end

local metrology_lab = data.raw["assembling-machine"]["metrology-lab"]
check(metrology_lab, "missing metrology-lab entity")
check(metrology_lab and not metrology_lab.hidden, "metrology-lab is hidden")
check((metrology_lab.crafting_speed or 0) < 0.01, "metrology-lab crafting must be disabled")
local metrology_item = item("metrology-lab")
check(metrology_item, "missing metrology-lab item")
check(metrology_item and not metrology_item.hidden, "metrology-lab item is hidden")
local metrology_recipe = data.raw.recipe["metrology-lab"]
check(metrology_recipe, "missing metrology-lab recipe")
check(metrology_recipe and metrology_recipe.enabled == false, "metrology-lab recipe should start locked")
check(item("metrology-test-structure"), "missing metrology-test-structure item")
local test_recipe = data.raw.recipe["metrology-test-structure"]
check(test_recipe, "missing metrology-test-structure recipe")
check(test_recipe and test_recipe.enabled == false, "metrology-test-structure recipe should start locked")

local lab_inputs = {}
for _, input in ipairs(metrology_lab and metrology_lab.inputs or {}) do
  lab_inputs[input] = true
end

local function has_prerequisite(tech, name)
  for _, prereq in ipairs(tech.prerequisites or {}) do
    if prereq == name then
      return true
    end
  end
  return false
end

for _, half in ipairs(nodes.HALF_NODES) do
  local wafer = nodes.qualification_item(half.key)
  local proto = item(wafer)
  check(proto, "missing qualification wafer " .. wafer)
  check(proto and not proto.hidden, "qualification wafer is hidden: " .. wafer)

  local recipe = data.raw.recipe[nodes.qualification_recipe(half.key)]
  check(recipe, "missing pilot recipe " .. nodes.qualification_recipe(half.key))
  check(recipe and recipe.enabled == false, "pilot recipe should start locked: " .. wafer)
  check(
    recipe and recipe.results and recipe.results[1] and recipe.results[1].name == wafer,
    "pilot recipe does not produce its PQW: " .. wafer
  )

  local tech_name = nodes.half_tech_name(half.key)
  local tech = data.raw.technology[tech_name]
  check(tech, "missing refinement technology " .. tech_name)
  check(tech and has_prerequisite(tech, nodes.tech_name(half.between[1])),
    tech_name .. " must require the node it refines")
  check(tech and half.requires_network == has_prerequisite(tech, "internet"),
    tech_name .. " internet requirement does not match its gate")
  local unlocked = unlocked_recipes(tech_name)
  check(unlocked[nodes.qualification_recipe(half.key)], tech_name .. " does not unlock its pilot recipe")
  if half.key == nodes.HALF_NODES[1].key then
    check(unlocked["metrology-lab"], tech_name .. " does not unlock the Metrology Lab")
    check(unlocked["metrology-test-structure"], tech_name .. " does not unlock the test structure")
  end
end

local the_question = data.raw.technology["the-question"]
check(the_question, "missing the-question technology")
if the_question then
  for _, half in ipairs(nodes.HALF_NODES) do
    local tech_name = nodes.half_tech_name(half.key)
    check(has_prerequisite(the_question, tech_name), "the-question must require " .. tech_name)
  end
end

-- The three custom workloads are item prototypes with their own recipes. The
-- two that are not node-specific are unlocked by the node that introduces
-- their feedstock; the Qubit Array comes from the Quantum Fab.
local CUSTOM_WORKLOADS = {
  ["chiptorio-optical-science-pack"] = "process-350nm",
  ["chiptorio-hbm-science-pack"] = "process-90nm",
  ["chiptorio-quantum-science-pack"] = "quantum-computing",
}
for name, tech_name in pairs(CUSTOM_WORKLOADS) do
  local proto = item(name)
  check(proto, "missing custom science pack " .. name)
  check(proto and not proto.hidden, "custom science pack is hidden: " .. name)
  local recipe = data.raw.recipe[name]
  check(recipe, "missing custom science pack recipe " .. name)
  check(recipe and recipe.enabled == false, "custom science pack recipe should start locked: " .. name)
  check(unlocked_recipes(tech_name)[name], tech_name .. " does not unlock " .. name)
end
check(not item("quantum-science-pack"), "unprefixed quantum-science-pack still exists")

-- QLN: the pre-quantum Data Bus and the phase-six quantum layer. Every node
-- must be placeable, every recipe locked, and the two technology lines must
-- unlock exactly the machines the runtime looks for.
local QLN_NODES = {
  "qln-import-node",
  "qln-export-node",
  "qln-provider-node",
  "qln-requester-node",
  "qln-terminal",
  "qln-storage-drive",
  "construction-core",
  "quantum-entanglement-core",
  "foup-dock",
  "wireless-access-point",
}
for _, name in ipairs(QLN_NODES) do
  local proto = entity(name)
  check(proto, "missing QLN entity " .. name)
  if proto then
    check(not proto.hidden, "QLN entity is hidden: " .. name)
    check(proto.minable and proto.minable.result == name, "QLN entity is not minable: " .. name)
    check(proto.collision_box and proto.selection_box,
      "QLN entity " .. name .. " has no collision or selection box")
    if data.raw.container[name] then
      check_world_picture(proto, name)
    elseif data.raw["assembling-machine"][name] then
      -- Assembling-machine clones keep their sprite footprint; collision box
      -- must cover the art.
      local box = proto.collision_box
      check(box and box[1] and box[1][1] <= -1.1 and box[2][1] >= 1.1,
        "QLN assembling-machine " .. name .. " collision box does not match its sprite")
    elseif data.raw.lab[name] then
      -- Lab clones keep the 3x3 lab sprite, so the collision box has to cover
      -- the art instead of a small 1.6x1.6 square in the middle.
      local box = proto.collision_box
      check(box and box[1] and box[1][1] <= -1.1 and box[2][1] >= 1.1,
        "QLN lab clone " .. name .. " collision box does not match its 3x3 sprite")
    elseif data.raw.accumulator[name] then
      check(proto.energy_source and proto.energy_source.buffer_capacity,
        "QLN accumulator clone " .. name .. " has no energy buffer")
    end
  end
  local qln_item = item(name)
  check(qln_item, "missing QLN item " .. name)
  check(qln_item and qln_item.place_result == name, "QLN item " .. name .. " does not place itself")
  local recipe = data.raw.recipe[name]
  check(recipe, "missing QLN recipe " .. name)
  check(recipe and recipe.enabled == false, "QLN recipe should start locked: " .. name)
end

local drive = data.raw["assembling-machine"]["qln-storage-drive"]
check(drive, "qln-storage-drive must be an assembling machine")
if drive then
  check(#(drive.inputs or {}) == 0, "qln-storage-drive must have no science inputs")
  check(drive.module_slots == qmeta.DRIVE_SLOTS, "qln-storage-drive module slots do not match qln_meta")
  local categories = {}
  for _, category in ipairs(drive.allowed_module_categories or {}) do
    categories[category] = true
  end
  check(categories["chiptorio-memory"], "qln-storage-drive does not accept memory modules")
  check(not categories["chiptorio-chip"], "qln-storage-drive must not accept compute chips")
end
for _, name in ipairs({ "quantum-entanglement-core" }) do
  local proto = data.raw["assembling-machine"][name]
  check(proto, name .. " must be an assembling machine")
  if proto then
    check((proto.crafting_speed or 0) < 0.01, name .. " crafting must be disabled")
    check((proto.module_slots or 0) == 0, name .. " must have no module slots")
  end
end

-- The Construction Core reads and writes its `energy` as a build budget, so it
-- is an accumulator clone: a lab only energies while it researches, and an
-- idle lab would leave the core permanently at zero.
local core_proto = data.raw.accumulator["construction-core"]
check(core_proto, "construction-core must be an accumulator clone")
check(not data.raw.lab["construction-core"], "construction-core must not be a lab clone")
if core_proto then
  check(core_proto.energy_source and core_proto.energy_source.type == "electric",
    "construction-core is not electric")
  check(core_proto.energy_source and core_proto.energy_source.buffer_capacity,
    "construction-core has no battery")
end

-- The FOUP loader and its sealed carriers. Every process node gets its own
-- sealed item so a batch can never be confused with another node's batch.
check(item("foup"), "missing FOUP item")
local foup_recipe = data.raw.recipe["foup"]
check(foup_recipe, "missing FOUP recipe")
check(foup_recipe and foup_recipe.enabled == false, "FOUP recipe should start locked")
for _, node in ipairs(nodes.NODES) do
  local sealed = "foup-sealed-" .. node.key
  local proto = item(sealed)
  check(proto, "missing sealed FOUP " .. sealed)
  check(proto and not proto.hidden, "sealed FOUP is hidden: " .. sealed)
end

-- The neural processor is the tensor source. It must be a real module and the
-- quantum-advantage technology must unlock its recipe.
local neural = data.raw.module["neural-processor"]
check(neural, "missing neural-processor module")
if neural then
  check(neural.category == "chiptorio-chip", "neural-processor has the wrong module category")
  check(neural.effect and next(neural.effect) == nil, "neural-processor must have an empty effect")
end
check(unlocked_recipes("quantum-advantage")["neural-processor"],
  "quantum-advantage does not unlock neural-processor")

local qln_tech = data.raw.technology[qmeta.TECH_QLN]
check(qln_tech, "missing qln technology")
if qln_tech then
  local unlocked = unlocked_recipes(qmeta.TECH_QLN)
  for _, name in ipairs({
    "qln-import-node", "qln-export-node", "qln-provider-node", "qln-requester-node",
    "qln-terminal", "qln-storage-drive", "construction-core",
  }) do
    check(unlocked[name], qmeta.TECH_QLN .. " does not unlock " .. name)
  end
end
local quantum_tech = data.raw.technology[qmeta.TECH_QUANTUM]
check(quantum_tech, "missing qln-quantum technology")
if quantum_tech then
  local unlocked = unlocked_recipes(qmeta.TECH_QUANTUM)
  for _, name in ipairs({
    "quantum-entanglement-core", "foup-dock", "foup",
    "wireless-access-point",
  }) do
    check(unlocked[name], qmeta.TECH_QUANTUM .. " does not unlock " .. name)
  end
  check(has_prerequisite(quantum_tech, qmeta.TECH_QLN), "qln-quantum must require qln")
end
if the_question then
  check(has_prerequisite(the_question, qmeta.TECH_QLN), "the-question must require qln")
  check(has_prerequisite(the_question, qmeta.TECH_QUANTUM), "the-question must require qln-quantum")
end

-- The Construction Core must be a powered accumulator clone with a real
-- buffer, so the runtime can read and spend its energy as the work budget.
local core = data.raw.accumulator["construction-core"]
check(core, "missing construction-core accumulator prototype")
if core then
  check(core.energy_source and core.energy_source.type == "electric", "construction-core is not electric")
  check(core.energy_source and core.energy_source.buffer_capacity, "construction-core has no buffer")
end

-- Every item the Answer Engine consumes must exist as an item.
for _, req in ipairs(answer_meta.item_demand or {}) do
  check(item(req.item), "Answer Engine demand names a missing item: " .. req.item)
  check(req.rate > 0, "Answer Engine demand has a non-positive rate: " .. req.item)
end

local overlay_input = data.raw["custom-input"]["chiptorio-network-overlay"]
check(overlay_input, "missing chiptorio-network-overlay custom input")

local monitor_shortcut = data.raw.shortcut["chiptorio-network-monitor"]
check(monitor_shortcut, "missing chiptorio-network-monitor shortcut")
if monitor_shortcut then
  check(monitor_shortcut.technology_to_unlock == "internet", "monitor shortcut is not gated on internet")
end

-- ---------------------------------------------------------------------------
-- P1.2 Global prototype integrity: every prototype reference resolves
-- ---------------------------------------------------------------------------

local circuits_meta = require("__chiptorio__/scripts/circuits_meta")
local computers_meta = require("__chiptorio__/scripts/computers_meta")
local ai_meta = require("__chiptorio__/scripts/ai_meta")

--- Resolve an ingredient/result reference. Unknown prototype types are a
--- failure, not a skip: a typo in `type` silently removes an ingredient.
local function resolves(kind, name)
  if type(name) ~= "string" then
    return false
  end
  if kind == nil or kind == "item" then
    return item(name) ~= nil
  end
  if kind == "fluid" then
    return data.raw.fluid and data.raw.fluid[name] ~= nil
  end
  local prototypes = data.raw[kind]
  return prototypes ~= nil and prototypes[name] ~= nil
end

local recipe_categories = {}
for name in pairs(data.raw["recipe-category"] or {}) do
  recipe_categories[name] = true
end

--- 2.1 merged RecipePrototype.category into `categories`. Older and
--- hand-written prototypes may still use the scalar field, and a recipe with
--- neither falls back to the default `crafting` category.
local function categories_of(recipe)
  local categories = {}
  for _, name in ipairs(recipe.categories or {}) do
    categories[name] = true
  end
  if recipe.category then
    categories[recipe.category] = true
  end
  if next(categories) == nil then
    categories["crafting"] = true
  end
  return categories
end

-- Every recipe category must exist and every ingredient and result must name a
-- real prototype. This is the net that catches a renamed item left behind in a
-- recipe the targeted checks do not mention (the silicon, era and endgame
-- chains are covered by construction, not by name).
for name, recipe in pairs(data.raw.recipe) do
  for category in pairs(categories_of(recipe)) do
    check(recipe_categories[category], "recipe " .. name .. " uses missing category " .. category)
  end
  for _, ingredient in ipairs(recipe.ingredients or {}) do
    local kind = ingredient.type or "item"
    check(
      resolves(kind, ingredient.name),
      "recipe " .. name .. " consumes missing " .. kind .. " " .. tostring(ingredient.name)
    )
  end
  for _, result in ipairs(recipe.results or {}) do
    local kind = result.type or "item"
    check(
      resolves(kind, result.name),
      "recipe " .. name .. " produces missing " .. kind .. " " .. tostring(result.name)
    )
  end
  if recipe.result then
    check(resolves("item", recipe.result), "recipe " .. name .. " produces missing item " .. recipe.result)
  end
end

-- Technology science ingredients are positional {name, amount} pairs. A
-- technology that costs a pack which no longer exists is silently unresearchable.
for name, tech in pairs(data.raw.technology) do
  for _, ingredient in ipairs((tech.unit and tech.unit.ingredients) or {}) do
    local pack = ingredient.name or ingredient[1]
    local amount = ingredient.amount or ingredient[2]
    check(
      type(pack) == "string" and is_item_name(pack),
      "technology " .. name .. " costs missing science pack " .. tostring(pack)
    )
    check(
      type(amount) == "number" and amount > 0,
      "technology " .. name .. " costs a non-positive amount of " .. tostring(pack)
    )
  end
  if tech.research_trigger then
    -- Triggers are not always craft-item: oil processing and uranium mining
    -- use a fluid or a mined entity, so resolve whichever field is present.
    local trigger = tech.research_trigger
    if trigger.item then
      check(
        resolves("item", trigger.item),
        "technology " .. name .. " triggers on missing item " .. tostring(trigger.item)
      )
    elseif trigger.fluid then
      check(
        resolves("fluid", trigger.fluid),
        "technology " .. name .. " triggers on missing fluid " .. tostring(trigger.fluid)
      )
    elseif trigger.entity then
      check(
        entity(trigger.entity) ~= nil,
        "technology " .. name .. " triggers on missing entity " .. tostring(trigger.entity)
      )
    end
  end
end

-- Every metadata gate must point at a technology that exists, and every profile
-- at a prototype that exists. A rename in one module with no matching edit in
-- the other is otherwise invisible until it silently removes compute.
for tech_name in pairs(rmeta.TECHS) do
  check(data.raw.technology[tech_name], "research gate names missing technology " .. tech_name)
end
for tech_name in pairs(rmeta.INFINITE_RESEARCH_SCALES) do
  check(data.raw.technology[tech_name], "infinite scale names missing technology " .. tech_name)
end
for key in pairs(rmeta.QUALIFICATION_GATES) do
  check(nodes.half_node(key), "qualification gate names missing half-node " .. key)
  check(
    data.raw.technology[nodes.half_tech_name(key)],
    "qualification gate names missing refinement technology " .. nodes.half_tech_name(key)
  )
end
-- Chips are packaged by per-node recipes (`<chip>-from-<node>`), not by a
-- recipe named after the module, so look for any recipe that produces them.
local produced_items = {}
for _, recipe in pairs(data.raw.recipe) do
  if recipe.result then
    produced_items[recipe.result] = true
  end
  for _, result in ipairs(recipe.results or {}) do
    local kind = result.type or "item"
    local result_name = result.name or result[1]
    if kind == "item" and result_name then
      produced_items[result_name] = true
    end
  end
end

for profile_name in pairs(rmeta.CHIP_PROFILES) do
  check(data.raw.module[profile_name], "chip profile names missing module " .. profile_name)
  check(produced_items[profile_name], "chip profile has no recipe producing " .. profile_name)
end
for profile_name in pairs(rmeta.MEMORY_PROFILES) do
  check(data.raw.module[profile_name], "memory profile names missing module " .. profile_name)
  check(data.raw.recipe[profile_name], "memory profile names missing recipe " .. profile_name)
end
for profile_name in pairs(rmeta.COMPUTER_PROFILES) do
  check(data.raw.module[profile_name], "computer profile names missing module " .. profile_name)
  check(data.raw.recipe[profile_name], "computer profile names missing recipe " .. profile_name)
end
for lab_name in pairs(rmeta.LAB_DEMAND) do
  check(data.raw.lab[lab_name], "lab demand names missing research computer " .. lab_name)
end

-- Every custom recipe category must have a machine that accepts it. A recipe in
-- a category no entity can craft is unreachable content.
local CUSTOM_CATEGORY_MACHINES = {
  ["chiptorio-circuit"] = "circuit-assembler",
  ["chiptorio-computer"] = "computer-assembler",
  ["chiptorio-ai-training"] = "training-cluster",
  ["chiptorio-fab"] = "wafer-fab",
  ["chiptorio-crystal"] = "crystal-puller",
  ["chiptorio-compute"] = "assembly-fab",
  ["chiptorio-vlsi"] = "vlsi-fab",
  ["chiptorio-cooling"] = "cooling-tower",
  ["chiptorio-quantum"] = "quantum-fab",
}
local accepting_machines = {}
for category, machine_name in pairs(CUSTOM_CATEGORY_MACHINES) do
  check(recipe_categories[category], "missing recipe category " .. category)
  local machine = (data.raw["assembling-machine"] or {})[machine_name]
    or (data.raw.furnace or {})[machine_name]
  check(machine, "missing machine " .. machine_name .. " for category " .. category)
  if machine then
    local accepted = {}
    for _, name in ipairs(machine.crafting_categories or {}) do
      accepted[name] = true
      accepting_machines[name] = (accepting_machines[name] or 0) + 1
    end
    check(accepted[category], machine_name .. " does not accept category " .. category)
  end
end
for category in pairs(recipe_categories) do
  if category:find("^chiptorio%-") then
    check(accepting_machines[category], "custom recipe category has no machine: " .. category)
  end
end

-- Circuit boards: item, base recipe and every cheaper alternative recipe must
-- exist, live in the board category and be unlocked by their own gate.
check(data.raw["recipe-category"]["chiptorio-circuit"], "missing chiptorio-circuit recipe category")
check(data.raw["item-subgroup"]["chiptorio-circuits"], "missing chiptorio-circuits item subgroup")
for _, board in ipairs(circuits_meta.BOARDS) do
  local proto = item(board.name)
  check(proto, "missing board item " .. board.name)
  check(proto and not proto.hidden, "board item is hidden: " .. board.name)

  local function check_board_recipe(recipe_name, gate, energy, results)
    local recipe = data.raw.recipe[recipe_name]
    check(recipe, "missing board recipe " .. recipe_name)
    if recipe then
      check(categories_of(recipe)["chiptorio-circuit"], "board recipe " .. recipe_name .. " is not in chiptorio-circuit")
      check(recipe.enabled == false, "board recipe should start locked: " .. recipe_name)
      check(recipe.energy_required == energy, "board recipe " .. recipe_name .. " craft time drifted")
      local ok = false
      for _, result in ipairs(recipe.results or {}) do
        if result.name == board.name and result.amount == results then
          ok = true
        end
      end
      check(ok, "board recipe " .. recipe_name .. " does not produce its board")
    end
    local unlocked = unlocked_recipes(gate)
    check(unlocked[recipe_name], gate .. " does not unlock " .. recipe_name)
  end

  check_board_recipe(board.name, board.gate, board.energy, board.results)
  for _, alt in ipairs(board.alts or {}) do
    check_board_recipe(board.name .. "-from-" .. alt.gate, alt.gate, alt.energy, alt.results)
  end
end

local circuit_assembler = circuits_meta.ASSEMBLER
local circuit_entity = (data.raw["assembling-machine"] or {})[circuit_assembler.name]
check(circuit_entity, "missing circuit-assembler entity")
if circuit_entity then
  check(circuit_entity.crafting_categories and circuit_entity.crafting_categories[1] == circuit_assembler.category,
    "circuit-assembler does not use its own category")
end
check(item(circuit_assembler.name), "missing circuit-assembler item")
local circuit_recipe = data.raw.recipe[circuit_assembler.name]
check(circuit_recipe, "missing circuit-assembler recipe")
check(circuit_recipe and circuit_recipe.enabled == false, "circuit-assembler recipe should start locked")
check(unlocked_recipes(circuit_assembler.gate)[circuit_assembler.name],
  circuit_assembler.gate .. " does not unlock the circuit assembler")

-- Computer modules: recipe category, gate and the Computer Assembler.
for _, computer in ipairs(computers_meta.COMPUTERS) do
  local recipe = data.raw.recipe[computer.name]
  check(recipe, "missing computer recipe " .. computer.name)
  if recipe then
    check(categories_of(recipe)["chiptorio-computer"],
      "computer recipe " .. computer.name .. " is not in chiptorio-computer")
    check(recipe.enabled == false, "computer recipe should start locked: " .. computer.name)
  end
  check(unlocked_recipes(computer.gate)[computer.name],
    computer.gate .. " does not unlock " .. computer.name)
end

local computer_assembler = computers_meta.ASSEMBLER
local computer_entity = (data.raw["assembling-machine"] or {})[computer_assembler.name]
check(computer_entity, "missing computer-assembler entity")
if computer_entity then
  check(computer_entity.crafting_categories and computer_entity.crafting_categories[1] == computer_assembler.category,
    "computer-assembler does not use its own category")
end
check(item(computer_assembler.name), "missing computer-assembler item")
local computer_recipe = data.raw.recipe[computer_assembler.name]
check(computer_recipe, "missing computer-assembler recipe")
check(computer_recipe and computer_recipe.enabled == false, "computer-assembler recipe should start locked")
check(unlocked_recipes(computer_assembler.gate)[computer_assembler.name],
  computer_assembler.gate .. " does not unlock the computer assembler")

-- Late board/computer recipes must be gated on a technology that can already
-- unlock every locked ingredient. `quantum-advantage` is the join point of the
-- two late columns: error correction supplies the logical qubit, the 7 nm node
-- supplies the quantum processor, HBM3 and 3D NAND, and quantum-advantage
-- itself supplies the neural processor. Moving a gate earlier announces a
-- recipe the player cannot build until the next technology.
local quantum_advantage = data.raw.technology["quantum-advantage"]
check(quantum_advantage, "missing quantum-advantage technology")
if quantum_advantage then
  check(has_prerequisite(quantum_advantage, "quantum-error-correction"),
    "quantum-advantage must require quantum-error-correction")
  check(has_prerequisite(quantum_advantage, "process-7nm"),
    "quantum-advantage must require process-7nm")
end

local function tech_closure(name)
  local closure = {}
  local function visit(tech_name)
    if closure[tech_name] or not data.raw.technology[tech_name] then
      return
    end
    closure[tech_name] = true
    for _, prereq in ipairs(data.raw.technology[tech_name].prerequisites or {}) do
      visit(prereq)
    end
  end
  visit(name)
  return closure
end

local function closure_unlocks(closure)
  local unlocked = {}
  for tech_name in pairs(closure) do
    for _, effect in ipairs(data.raw.technology[tech_name].effects or {}) do
      if effect.type == "unlock-recipe" then
        unlocked[effect.recipe] = true
      end
    end
  end
  return unlocked
end

-- Recipes that no technology unlocks are available from the start (iron plates,
-- copper cable, water, ...). Only a recipe that some technology *does* unlock
-- can be an ordering failure, so build that set once.
local recipe_has_tech = {}
for _, tech in pairs(data.raw.technology) do
  for _, effect in ipairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" then
      recipe_has_tech[effect.recipe] = true
    end
  end
end

-- Only the late gates are checked here. The early bootstrap (copper cable,
-- small electric poles, the Analytical Engine and Punched Cards) has its own
-- contract above. These two gates are where an ingredient can silently arrive
-- one technology late.
local LATE_GATES = {
  ["quantum-advantage"] = true,
  ["process-7nm"] = true,
}

local function check_gate_covers(recipe_name, gate, ingredients)
  if not LATE_GATES[gate] then
    return
  end
  local unlocked = closure_unlocks(tech_closure(gate))
  for _, ingredient in ipairs(ingredients or {}) do
    local recipe = data.raw.recipe[ingredient.name]
    if recipe and recipe_has_tech[ingredient.name] and not unlocked[ingredient.name] then
      check(false, gate .. " unlocks " .. recipe_name .. " before " .. ingredient.name)
    end
  end
end

for _, board in ipairs(circuits_meta.BOARDS) do
  check_gate_covers(board.name, board.gate, board.base)
  for _, alt in ipairs(board.alts or {}) do
    check_gate_covers(board.name .. "-from-" .. alt.gate, alt.gate, alt.ingredients)
  end
end
for _, computer in ipairs(computers_meta.COMPUTERS) do
  check_gate_covers(computer.name, computer.gate, computer.base)
end

-- AI: model recipes are real training recipes, the Training Cluster crafts them
-- and the Inference Lab is a lab clone.
check(data.raw["recipe-category"]["chiptorio-ai-training"], "missing chiptorio-ai-training recipe category")
for _, tier in ipairs(ai_meta.AI_TIERS) do
  local recipe = data.raw.recipe[tier.name]
  check(recipe, "missing AI model recipe " .. tier.name)
  if recipe then
    check(categories_of(recipe)["chiptorio-ai-training"],
      "AI model recipe " .. tier.name .. " is not in chiptorio-ai-training")
    check(recipe.enabled == false, "AI model recipe should start locked: " .. tier.name)
  end
  check(unlocked_recipes(tier.gate)[tier.name], tier.gate .. " does not unlock " .. tier.name)
  for _, entry in ipairs(tier.train_data) do
    check(item(entry.name), "AI tier " .. tier.name .. " trains on missing item " .. entry.name)
  end
  check(data.raw.technology[tier.gate], "AI tier " .. tier.name .. " names missing gate " .. tier.gate)
end

local training = (data.raw["assembling-machine"] or {})[ai_meta.TRAINING_CLUSTER.name]
check(training, "missing training-cluster entity")
if training then
  local accepted = {}
  for _, name in ipairs(training.crafting_categories or {}) do
    accepted[name] = true
  end
  check(accepted[ai_meta.TRAINING_CLUSTER.category],
    "training-cluster does not accept " .. ai_meta.TRAINING_CLUSTER.category)
end
local inference = (data.raw.lab or {})[ai_meta.INFERENCE_LAB.name]
check(inference, "missing inference-lab entity")
if inference then
  check(not inference.hidden, "inference-lab is hidden")
  check(inference.inputs ~= nil, "inference-lab has no lab input inventory")
end
check(unlocked_recipes(ai_meta.TRAINING_CLUSTER.gate)[ai_meta.TRAINING_CLUSTER.name],
  "machine-learning does not unlock the Training Cluster")
check(unlocked_recipes(ai_meta.INFERENCE_LAB.gate)[ai_meta.INFERENCE_LAB.name],
  "machine-learning does not unlock the Inference Lab")

-- The endgame machine is a real recipe in the compute category, unlocked only
-- by The Question.
check(item("answer-engine"), "missing answer-engine item")
check(data.raw["assembling-machine"] and data.raw["assembling-machine"]["answer-engine"], "missing answer-engine entity")
local answer_recipe = data.raw.recipe["answer-engine"]
check(answer_recipe, "missing answer-engine recipe")
if answer_recipe then
  check(categories_of(answer_recipe)["chiptorio-compute"],
    "answer-engine recipe is not in chiptorio-compute")
  check(answer_recipe.enabled == false, "answer-engine recipe should start locked")
  check(unlocked_recipes("the-question")["answer-engine"],
    "the-question does not unlock the answer engine")
end

-- ---------------------------------------------------------------------------
-- P2.1 Visible recipe without unlocking technology
-- ---------------------------------------------------------------------------
-- Every visible recipe with enabled=false must be unlocked by at least one
-- visible technology. This catches recipes that are locked but have no gate.
local unlocked_by_visible_tech = {}
for _, tech in pairs(data.raw.technology) do
  if not tech.hidden then
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe then
        unlocked_by_visible_tech[effect.recipe] = true
      end
    end
  end
end
for name, recipe in pairs(data.raw.recipe) do
  if not recipe.hidden and recipe.enabled == false then
    check(unlocked_by_visible_tech[name],
      "visible recipe " .. name .. " is locked but not unlocked by any visible technology")
  end
end

-- ---------------------------------------------------------------------------
-- P2.2 Ingredient-gate prerequisite check (Chiptorio technologies only)
-- ---------------------------------------------------------------------------
-- For each Chiptorio technology T that unlocks recipe R, each ingredient I in R
-- must have its unlocking technology G as a (transitive) prerequisite of T.
-- This prevents unlocking recipes whose ingredients aren't craftable yet.
-- Only applies to Chiptorio-created technologies and recipes.

-- Build map: recipe -> set of technologies that unlock it (Chiptorio only)
local recipe_gates = {}
for _, tech in pairs(data.raw.technology) do
  if not tech.hidden and is_chiptorio_created(tech.name) then
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe then
        recipe_gates[effect.recipe] = recipe_gates[effect.recipe] or {}
        recipe_gates[effect.recipe][tech.name] = true
      end
    end
  end
end

-- Build transitive prerequisite closure for each Chiptorio technology
local tech_prereqs = {}
for _, tech in pairs(data.raw.technology) do
  if not tech.hidden and is_chiptorio_created(tech.name) then
    local closure = {}
    local function add_prereqs(tname)
      local t = data.raw.technology[tname]
      if t and t.prerequisites then
        for _, p in ipairs(t.prerequisites) do
          if not closure[p] then
            closure[p] = true
            add_prereqs(p)
          end
        end
      end
    end
    add_prereqs(tech.name)
    tech_prereqs[tech.name] = closure
  end
end

-- Check each Chiptorio technology's unlocked recipes
for _, tech in pairs(data.raw.technology) do
  if not tech.hidden and is_chiptorio_created(tech.name) then
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" and effect.recipe then
        local recipe = data.raw.recipe[effect.recipe]
        if recipe and not recipe.hidden and is_chiptorio_created(effect.recipe) then
          for _, ingredient in ipairs(recipe.ingredients or {}) do
            local iname = ingredient.name or ingredient[1]
            -- Find a Chiptorio technology that unlocks this ingredient
            local gates = recipe_gates[iname]
            if gates then
              local ok = false
              for gname in pairs(gates) do
                if tech_prereqs[tech.name] and tech_prereqs[tech.name][gname] then
                  ok = true
                  break
                end
                -- Also allow if the gate IS the technology itself (self-unlock)
                if gname == tech.name then
                  ok = true
                  break
                end
              end
              if not ok then
                local gate_list = {}
                for k in pairs(gates) do gate_list[#gate_list+1] = k end
                check(false,
                  "technology " .. tech.name .. " unlocks recipe " .. effect.recipe ..
                  " which needs ingredient " .. iname ..
                  " unlocked by " .. table.concat(gate_list, ", ") ..
                  " but none are prerequisites")
              end
            end
          end
        end
      end
    end
  end
end

if #failures > 0 then
  error("CHIPTORIO-TEST FAIL data: " .. table.concat(failures, "; "))
end

-- ---------------------------------------------------------------------------
-- P1.1 Global data contracts: recipe/technology graph integrity
-- ---------------------------------------------------------------------------

-- Build the set of every technology that is reachable from a start technology.
-- Uses transitive closure: start with techs that have no prerequisites, then
-- iteratively add any tech whose prerequisites are all reachable.
local function reachable_techs()
  local reachable = {}
  -- Start: techs with no prerequisites
  for _, tech in pairs(data.raw.technology) do
    if not tech.prerequisites or #tech.prerequisites == 0 then
      reachable[tech.name] = true
    end
  end
  -- Iterate until no change
  local changed = true
  while changed do
    changed = false
    for _, tech in pairs(data.raw.technology) do
      if not reachable[tech.name] and tech.prerequisites then
        local all_reachable = true
        for _, prereq in ipairs(tech.prerequisites) do
          if not reachable[prereq] then
            all_reachable = false
            break
          end
        end
        if all_reachable then
          reachable[tech.name] = true
          changed = true
        end
      end
    end
  end
  return reachable
end

local reachable = reachable_techs()

-- Check every enabled/disabled recipe has a technology that unlocks it.
local orphaned_recipes = {}
for _, recipe in pairs(data.raw.recipe) do
  if recipe.name:find("^chiptorio") or recipe.name:find("^node-") or recipe.name:find("^refine-") or recipe.name:find("^foup-") or recipe.name:find("^qln-") or recipe.name:find("^network-") then
    local unlocked = false
    for _, tech in pairs(data.raw.technology) do
      for _, effect in ipairs(tech.effects or {}) do
        if effect.type == "unlock-recipe" and effect.recipe == recipe.name then
          unlocked = true
          break
        end
      end
      if unlocked then break end
    end
    if not unlocked and not recipe.hidden then
      orphaned_recipes[#orphaned_recipes + 1] = recipe.name
    end
  end
end
if #orphaned_recipes > 0 then
  table.insert(failures, "orphaned recipes (no technology unlocks them): " .. table.concat(orphaned_recipes, ", "))
end

-- The same rule for vanilla recipes: a visible recipe that starts locked but
-- has no visible unlocking technology is dead content. Removing robot
-- technologies used to orphan the flying robot frame and the storage chest,
-- which then sat in Factoriopedia unlocked by nothing.
local visible_recipe_gates = {}
for _, tech in pairs(data.raw.technology) do
  if not tech.hidden then
    for _, effect in ipairs(tech.effects or {}) do
      if effect.type == "unlock-recipe" then
        visible_recipe_gates[effect.recipe] = true
      end
    end
  end
end
local orphaned_visible_recipes = {}
for name, recipe in pairs(data.raw.recipe) do
  if not recipe.hidden and recipe.enabled == false and not visible_recipe_gates[name] then
    orphaned_visible_recipes[#orphaned_visible_recipes + 1] = name
  end
end
table.sort(orphaned_visible_recipes)
if #orphaned_visible_recipes > 0 then
  table.insert(
    failures,
    "visible recipes with no unlocking technology: " .. table.concat(orphaned_visible_recipes, ", ")
  )
end

-- Check every Chiptorio technology has a path from a start tech (no unreachable islands).
-- Vanilla technologies are excluded: Chiptorio adds prerequisites but doesn't remove them,
-- so vanilla techs remain reachable through their vanilla prerequisites.
local unreachable_techs = {}
for _, tech in pairs(data.raw.technology) do
  if is_chiptorio_created(tech.name) and not tech.hidden and not reachable[tech.name] then
    -- Exempt intentional islands: pilot recipes, The Answer Engine, trigger-unlocked starters.
    if not tech.name:find("^refine-") and tech.name ~= "the-question" and tech.name ~= "analytical-engine" then
      unreachable_techs[#unreachable_techs + 1] = tech.name
    end
  end
end
if #unreachable_techs > 0 then
  table.insert(failures, "unreachable technologies: " .. table.concat(unreachable_techs, ", "))
end

-- Check for prerequisite cycles using DFS.
local function find_cycles()
  local cycles = {}
  local color = {} -- 0=white, 1=gray, 2=black
  local path = {}

  local function dfs(name)
    color[name] = 1
    path[#path + 1] = name
    local tech = data.raw.technology[name]
    if tech then
      for _, prereq in ipairs(tech.prerequisites or {}) do
        if color[prereq] == 1 then
          -- Found a cycle: extract it from path.
          local cycle_start = nil
          for i = #path, 1, -1 do
            if path[i] == prereq then
              cycle_start = i
              break
            end
          end
          if cycle_start then
            local cycle = {}
            for i = cycle_start, #path do
              cycle[#cycle + 1] = path[i]
            end
            cycles[#cycles + 1] = table.concat(cycle, " -> ")
          end
        elseif color[prereq] == 0 then
          dfs(prereq)
        end
      end
    end
    path[#path] = nil
    color[name] = 2
  end

  for _, tech in pairs(data.raw.technology) do
    if not color[tech.name] then
      dfs(tech.name)
    end
  end
  return cycles
end

local cycles = find_cycles()
if #cycles > 0 then
  table.insert(failures, "technology prerequisite cycles: " .. table.concat(cycles, "; "))
end

-- Factorio never sets `researched = true` on an infinite technology, so an
-- infinite technology can never satisfy a prerequisite. A technology that
-- depends on one is unreachable: `LuaForce::add_research` silently returns
-- false even when the prerequisite is at level 2 or higher. This is how the
-- scripted infinite ladder (chip-performance et al.) was lost behind
-- `the-question`; the check keeps it from happening again.
local infinite_prereqs = {}
for _, tech in pairs(data.raw.technology) do
  for _, prereq_name in ipairs(tech.prerequisites or {}) do
    local prereq = data.raw.technology[prereq_name]
    if prereq and prereq.max_level == "infinite" then
      infinite_prereqs[#infinite_prereqs + 1] = tech.name .. " -> " .. prereq_name
    end
  end
end
if #infinite_prereqs > 0 then
  table.insert(
    failures,
    "technologies gated on infinite research (unreachable): " .. table.concat(infinite_prereqs, ", ")
  )
end

-- ---------------------------------------------------------------------------
-- P1.1b Progression reachability, not just prerequisite reachability
-- ---------------------------------------------------------------------------
--
-- A technology tree can be acyclic and still be unresearchable: if a science
-- pack is made in a machine that the same science pack unlocks, the first pack
-- can never be crafted. The Assembly Fab had exactly this bug (production
-- science -> Assembly Fab -> production science). The checks below simulate the
-- real progression: seed the items that have no producer (ore, water, crude
-- oil), then close over recipes that are unlocked, whose machine item is
-- available, and whose ingredients are available. Unbarreling is ignored as a
-- source: an empty barrel only exists after the fluid did, so counting it as a
-- producer makes every fluid look manufactured and hides real deadlocks.

local sim_producers = {}
local sim_results = {}
for name, recipe in pairs(data.raw.recipe) do
  local results = {}
  if recipe.result then
    results[#results + 1] = recipe.result
  end
  for _, result in ipairs(recipe.results or {}) do
    local kind = result.type or "item"
    local result_name = result.name or result[1]
    if (kind == "item" or kind == "fluid") and result_name then
      results[#results + 1] = result_name
    end
  end
  sim_results[name] = results
  local unbarreling = name:match("^empty%-") ~= nil and name:match("%-barrel$") ~= nil
  if not unbarreling then
    for _, result_name in ipairs(results) do
      sim_producers[result_name] = sim_producers[result_name] or {}
      table.insert(sim_producers[result_name], name)
    end
  end
end

local sim_gates = {}
for _, tech in pairs(data.raw.technology) do
  for _, effect in ipairs(tech.effects or {}) do
    if effect.type == "unlock-recipe" and effect.recipe then
      sim_gates[effect.recipe] = sim_gates[effect.recipe] or {}
      sim_gates[effect.recipe][tech.name] = true
    end
  end
end

local sim_raw = {}
for name in pairs(data.raw.item or {}) do
  if not sim_producers[name] then
    sim_raw[name] = true
  end
end
for name in pairs(data.raw.fluid or {}) do
  if not sim_producers[name] then
    sim_raw[name] = true
  end
end

local function simulate_items(researched)
  local items = {}
  for name in pairs(sim_raw) do
    items[name] = true
  end
  local craftable = {}
  local changed = true
  while changed do
    changed = false
    for name, recipe in pairs(data.raw.recipe) do
      if not recipe.hidden and not craftable[name] then
        local unlocked = recipe.enabled ~= false
        if not unlocked then
          for tech in pairs(sim_gates[name] or {}) do
            if researched[tech] then
              unlocked = true
              break
            end
          end
        end
        if unlocked then
          local ok = true
          for category in pairs(categories_of(recipe)) do
            local machine = CUSTOM_CATEGORY_MACHINES[category]
            if machine and not items[machine] then
              ok = false
              break
            end
          end
          if ok then
            for _, ingredient in ipairs(recipe.ingredients or {}) do
              if not items[ingredient.name] then
                ok = false
                break
              end
            end
          end
          if ok then
            craftable[name] = true
            changed = true
            for _, result_name in ipairs(sim_results[name] or {}) do
              items[result_name] = true
            end
          end
        end
      end
    end
  end
  return items
end

-- A machine that performs category C must be buildable without an item that
-- only category C produces: otherwise the machine needs itself to exist.
local bootstrap_failures = {}
for category, machine_name in pairs(CUSTOM_CATEGORY_MACHINES) do
  local build = data.raw.recipe[machine_name]
  if build then
    for _, ingredient in ipairs(build.ingredients or {}) do
      local visible_producers = {}
      for _, producer in ipairs(sim_producers[ingredient.name] or {}) do
        local proto = data.raw.recipe[producer]
        if proto and not proto.hidden then
          visible_producers[#visible_producers + 1] = producer
        end
      end
      if #visible_producers > 0 then
        local self_only = true
        for _, producer in ipairs(visible_producers) do
          if not categories_of(data.raw.recipe[producer])[category] then
            self_only = false
            break
          end
        end
        if self_only then
          bootstrap_failures[#bootstrap_failures + 1] = machine_name
            .. " needs "
            .. ingredient.name
            .. ", produced only by "
            .. category
        end
      end
    end
  end
end
if #bootstrap_failures > 0 then
  table.insert(failures, "self-locked machine recipes: " .. table.concat(bootstrap_failures, "; "))
end

-- Close the research tree over what the factory can actually build.
local sim_researched = {}
local sim_changed = true
while sim_changed do
  sim_changed = false
  local items = simulate_items(sim_researched)
  for name, tech in pairs(data.raw.technology) do
    if not tech.hidden and not sim_researched[name] then
      local prereqs_ok = true
      for _, prereq in ipairs(tech.prerequisites or {}) do
        if not sim_researched[prereq] then
          prereqs_ok = false
          break
        end
      end
      if prereqs_ok then
        local available = true
        local trigger = tech.research_trigger
        if trigger then
          if trigger.type == "craft-item" and trigger.item then
            available = items[trigger.item] == true
          elseif trigger.type == "craft-fluid" and trigger.fluid then
            available = data.raw.fluid[trigger.fluid] ~= nil
          elseif trigger.type == "mine-entity" then
            -- The resource entity exists; mining it is a player action.
            available = true
          elseif trigger.type == "send-item-to-orbit" and trigger.item then
            available = items[trigger.item] == true
          else
            -- kill / capture-spawner / build-entity: content Chiptorio removes.
            available = false
          end
        else
          for _, ingredient in ipairs((tech.unit or {}).ingredients or {}) do
            local pack = ingredient.name or ingredient[1]
            if not items[pack] then
              available = false
              break
            end
          end
        end
        if available then
          sim_researched[name] = true
          sim_changed = true
        end
      end
    end
  end
end

local sim_frontier = {}
for name, tech in pairs(data.raw.technology) do
  if not tech.hidden and not sim_researched[name] then
    local prereqs_ok = true
    for _, prereq in ipairs(tech.prerequisites or {}) do
      if not sim_researched[prereq] then
        prereqs_ok = false
        break
      end
    end
    if prereqs_ok then
      local items = simulate_items(sim_researched)
      local missing = {}
      if tech.research_trigger then
        local trigger = tech.research_trigger
        if trigger.type == "craft-item" and trigger.item and not items[trigger.item] then
          missing[#missing + 1] = "trigger " .. trigger.item
        elseif trigger.type == "send-item-to-orbit" and trigger.item and not items[trigger.item] then
          missing[#missing + 1] = "trigger " .. trigger.item
        end
      else
        for _, ingredient in ipairs((tech.unit or {}).ingredients or {}) do
          local pack = ingredient.name or ingredient[1]
          if not items[pack] then
            missing[#missing + 1] = pack
          end
        end
      end
      sim_frontier[#sim_frontier + 1] = name .. " (" .. table.concat(missing, ", ") .. ")"
    end
  end
end
table.sort(sim_frontier)
if #sim_frontier > 0 then
  table.insert(
    failures,
    "research deadlock, no first technology is affordable: " .. table.concat(sim_frontier, "; ")
  )
end

-- ---------------------------------------------------------------------------
-- P1.9 Locale and icon completeness for every prototype
-- ---------------------------------------------------------------------------

-- Icons are critical: Factorio won't auto-resolve missing icons.
-- Locale keys are auto-resolved (item-name.<name>, technology-name.<name>),
-- so only check icons here.
local missing_icon = {}

-- Items
for name, proto in pairs(data.raw.item) do
  if is_chiptorio_created(name) and not proto.hidden then
    if not proto.icon and not proto.icons then
      missing_icon[#missing_icon + 1] = "item " .. name
    end
  end
end

-- Entities (all types)
for _, type_name in ipairs({
  "container", "lab", "accumulator", "assembling-machine", "furnace",
  "display-panel", "constant-combinator", "pipe",
}) do
  local prototypes = data.raw[type_name]
  if prototypes then
    for name, proto in pairs(prototypes) do
      if is_chiptorio_created(name) and not proto.hidden then
        if not proto.icon and not proto.icons then
          missing_icon[#missing_icon + 1] = type_name .. "/" .. name
        end
      end
    end
  end
end

-- Technologies
for name, proto in pairs(data.raw.technology) do
  if is_chiptorio_created(name) and not proto.hidden then
    if not proto.icon and not proto.icons then
      missing_icon[#missing_icon + 1] = "technology " .. name
    end
  end
end

if #missing_icon > 0 then
  table.insert(failures, "missing icons: " .. table.concat(missing_icon, ", "))
end

-- P1.9: every Chiptorio-created prototype should have a locale entry.
-- Factorio auto-resolves item-name.<name>, entity-name.<name>, etc., so
-- we check locale.cfg for the corresponding key.
local locale_ok, locale_entries = pcall(function()
  local path = (function()
    -- Try common locations for locale.cfg relative to the game directory.
    local candidates = {
      "locale/en/locale.cfg",
      "data/locale/en/locale.cfg",
    }
    for _, c in ipairs(candidates) do
      local f = io.open(c, "r")
      if f then
        f:close()
        return c
      end
    end
    return nil
  end)()
  if not path then
    return nil
  end
  local f = io.open(path, "r")
  local content = f:read("*a")
  f:close()
  return content
end)

if locale_ok and locale_entries then
  local missing_locale = {}
  local function check_locale(name, section)
    local key = section .. "." .. name
    if not locale_entries:find(key, 1, true) then
      missing_locale[#missing_locale + 1] = key
    end
  end

  for name, proto in pairs(data.raw.item) do
    if is_chiptorio_created(name) and not proto.hidden then
      check_locale(name, "item-name")
    end
  end
  for name, proto in pairs(data.raw.entity) do
    if is_chiptorio_created(name) and not proto.hidden then
      check_locale(name, "entity-name")
    end
  end
  for name, proto in pairs(data.raw.technology) do
    if is_chiptorio_created(name) and not proto.hidden then
      check_locale(name, "technology-name")
    end
  end
  for name, proto in pairs(data.raw.recipe) do
    if is_chiptorio_created(name) and not proto.hidden then
      check_locale(name, "recipe-name")
    end
  end
  for name, proto in pairs(data.raw.fluid) do
    if is_chiptorio_created(name) and not proto.hidden then
      check_locale(name, "fluid-name")
    end
  end

  if #missing_locale > 0 then
    table.insert(failures, "missing locale entries: " .. table.concat(missing_locale, ", "))
  end
end

if #failures > 0 then
  error("CHIPTORIO-TEST FAIL data: " .. table.concat(failures, "; "))
end

log("CHIPTORIO-TEST PASS data")
