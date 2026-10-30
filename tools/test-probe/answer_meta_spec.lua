-- Unit tests for scripts/answer_meta.lua.
--
-- The Answer Engine reads this table at runtime and the data contract uses it
-- to verify that every demanded item exists. The numbers are tuning, so the
-- test pins the shape (all four profiles, a memory and bandwidth gate, unique
-- QLN item lines) rather than every value.

local answer = require("__chiptorio__/scripts/answer_meta")
local H = require("unit_harness")

local function count(tbl)
  local total = 0
  for _ in pairs(tbl) do
    total = total + 1
  end
  return total
end

return function()
  H.test("the computation is forty-two minutes long", function()
    H.eq(answer.runtime_seconds, 42 * 60, "runtime seconds")
  end)

  H.test("every compute profile is required in equal measure", function()
    H.eq(count(answer.compute), 4, "compute profile count")
    local first
    for _, profile in ipairs({ "scalar", "vector", "tensor", "quantum" }) do
      local value = answer.compute[profile]
      H.truthy(value and value > 0, "missing compute demand for " .. profile)
      if not first then
        first = value
      end
      H.eq(value, first, profile .. " demand")
    end
  end)

  H.test("memory and bandwidth are hard positive gates", function()
    H.truthy(answer.memory and answer.memory > 0, "memory gate")
    H.truthy(answer.bandwidth and answer.bandwidth > 0, "bandwidth gate")
    H.truthy(answer.memory >= answer.compute.scalar, "memory gate is smaller than one compute profile")
    H.truthy(answer.bandwidth >= answer.compute.scalar, "bandwidth gate is smaller than one compute profile")
  end)

  H.test("the QLN item lines are unique and strictly positive", function()
    H.truthy(#answer.item_demand >= 9, "too few Answer item lines")
    local seen = {}
    local science = 0
    for _, entry in ipairs(answer.item_demand) do
      H.truthy(type(entry.item) == "string" and entry.item ~= "", "item line has no name")
      H.truthy(type(entry.rate) == "number" and entry.rate > 0, entry.item .. " has a non-positive rate")
      H.eq(seen[entry.item], nil, "duplicate Answer item line " .. entry.item)
      seen[entry.item] = true
      if entry.item:find("science%-pack$") then
        science = science + 1
      end
    end
    H.eq(science, 9, "Answer science pack line count")
    H.truthy(seen["microprocessor"], "the Answer consumes microprocessors")
    H.truthy(seen["quantum-processor"], "the Answer consumes quantum processors")
  end)

  H.test("stability decays slowly and post-game scaling is positive", function()
    H.truthy(answer.stability_decay_per_minute > 0, "stability decay")
    H.truthy(answer.stability_decay_per_minute < 0.1, "stability decay is too fast")
    H.truthy(answer.rate_scale_per_level > 0, "rate scale")
    H.truthy(answer.score_per_level > 0, "score per level")
  end)
end
