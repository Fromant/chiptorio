-- data-updates.lua: touch vanilla once every mod has finished adding content.

local M = require("scripts.util")

-- 1. The vanilla lab is a lie: research is done by computers now.
local lab_item = data.raw.item["lab"]
local lab_entity = data.raw.lab["lab"]
local lab_recipe = data.raw.recipe["lab"]
if lab_item then
  lab_item.hidden = true
  lab_item.hidden_in_factoriopedia = true
end
if lab_entity then
  lab_entity.hidden = true
  lab_entity.hidden_in_factoriopedia = true
end
if lab_recipe then
  lab_recipe.hidden = true
  lab_recipe.enabled = false
end

-- 1b. Vanilla unlocks the first science pack with a *trigger*: "craft a lab".
--     That lab no longer exists, so point the trigger at the replacement
--     computer. Without this the first science pack can never be unlocked and
--     a fresh save is dead on arrival.
local starter_recipe = data.raw.recipe["analytical-engine"]
if not starter_recipe then
  error("chiptorio: analytical-engine recipe missing; cannot wire the starter trigger")
end
if starter_recipe.enabled == false then
  error("chiptorio: analytical-engine must be craftable without research, or there is no way to research anything")
end
if not data.raw.item["analytical-engine"] then
  error("chiptorio: analytical-engine item missing; the starter trigger would point at nothing")
end

local starter_tech = data.raw.technology["automation-science-pack"]
if not starter_tech then
  error("chiptorio: automation-science-pack technology missing; the starter trigger cannot be retargeted")
end
starter_tech.research_trigger = {
  type = "craft-item",
  item = "analytical-engine",
}
starter_tech.icons = {
  { icon = "__chiptorio__/graphics/technology/automation-science-pack.png", icon_size = 256 },
}
starter_tech.icon = nil
starter_tech.icon_size = nil

-- 2. Control logic is a technology, not a starter capability.
M.add_prerequisite("circuit-network", "electromechanics")
M.add_prerequisite("advanced-combinators", "electromechanics")

-- 2b. The vanilla `electronics` technology is replaced by the Thermionics chain.
--     `thermionics` now unlocks vacuum tubes, glass, and the Control Board
--     (`electronic-circuit`). `electronics` becomes a gate that requires
--     `thermionics`, so no circuit recipe is available before the tube era.
local electronics_tech = data.raw.technology["electronics"]
if electronics_tech then
  M.add_prerequisite("electronics", "thermionics")
  local effects = electronics_tech.effects or {}
  local filtered = {}
  for _, effect in ipairs(effects) do
    if effect ~= "electronic-circuit" then
      table.insert(filtered, effect)
    end
  end
  electronics_tech.effects = filtered
end

-- 2c. The vanilla `advanced-circuit` and `processing-unit` technologies keep
--     their existing prerequisites. Progression to the board ladder is enforced
--     through recipe ingredients (you need chips from the matching node), not
--     through extra tech prerequisites that would cycle with the node tree.
--     No changes needed here beyond the `electronics` → `thermionics` swap above.

-- 3. Anything "smart" needs silicon. This is the core promise of the mod:
--    you cannot build the late game without a chip industry. The era 5-6
--    upgrades make the most advanced vanilla machines depend on the new
--    packages as well, so the new production lines are not optional.
M.add_ingredient("assembling-machine-3", M.item("integrated-circuit", 2))
M.add_ingredient("assembling-machine-3", M.item("microprocessor", 1))
M.add_ingredient("beacon", M.item("microprocessor", 1))
M.add_ingredient("beacon", M.item("system-on-chip", 1))
M.add_ingredient("programmable-speaker", M.item("microprocessor", 1))

-- 4. No enemies, no robots, no combat. See scripts/prune.lua for why this
--    hides prototypes instead of deleting them.
require("scripts.prune").apply()

