-- Enemies are not part of chiptorio. New maps disable enemy autoplace in
-- data-updates.lua; this module cleans existing saves and stops the map
-- settings from reintroducing enemy pressure.

local M = {}

local function disable_enemy_settings()
  local map = game.map_settings
  if map.enemy_evolution then
    map.enemy_evolution.enabled = false
  end
  if map.enemy_expansion then
    map.enemy_expansion.enabled = false
  end
  if map.pollution then
    map.pollution.enabled = false
  end
end

local function destroy_enemies()
  for _, surface in pairs(game.surfaces) do
    local enemies = surface.find_entities_filtered({ force = "enemy" })
    for _, entity in ipairs(enemies) do
      if entity.valid then
        entity.destroy()
      end
    end
  end
end

local function cleanup()
  disable_enemy_settings()
  destroy_enemies()
end

M.on_init = cleanup
M.on_configuration_changed = cleanup

return M
