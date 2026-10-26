-- Shared production-rate reading for both the mid-game research gate and the
-- Answer Engine.
--
-- `input` in LuaFlowStatistics is the production column and `output` is the
-- consumption column. We always measure production, so stockpiles do not
-- satisfy a gate.

local M = {}

function M.surface()
  return game.surfaces["nauvis"] or game.surfaces[1]
end

--- Items per second produced on the main surface over the last minute.
function M.production_rate(force, item)
  local s = M.surface()
  if not s then
    return 0
  end
  local stats = force.get_item_production_statistics(s)
  local per_minute = stats.get_flow_count({
    name = item,
    category = "input",
    precision_index = defines.flow_precision_index.one_minute,
  })
  return (per_minute or 0) / 60
end

--- Check a list of { item = "...", rate = n } requirements.
--- Returns ok, results where each result has item, rate, required and ok.
function M.check(force, requirements)
  local results = {}
  local ok = true
  for _, req in ipairs(requirements) do
    local rate = M.production_rate(force, req.item)
    local met = rate >= req.rate
    results[#results + 1] = {
      item = req.item,
      rate = rate,
      required = req.rate,
      ok = met,
    }
    if not met then
      ok = false
    end
  end
  return ok, results
end

return M
