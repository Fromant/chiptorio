-- Runtime: enforce the "sustained compute" requirements.
--
-- We measure *production* of a workload item over a rolling one-minute
-- window using the force's item statistics. Production (not consumption) is
-- deliberate: stockpiling does not satisfy the gate, only a running factory.

local meta = require("scripts.tech_meta")
local rates = require("scripts.rates")

local WARN_INTERVAL = 60 * 30

-- Fraction of research progress lost per second at 100% deficit. The design
-- target is 2% per minute, so one minute's worth is split over 60 checks.
local DECAY_PER_SECOND = 0.02 / 60

local function force_print(force, message)
  local printed = false
  if force.players then
    for _, player in pairs(force.players) do
      player.print(message)
      printed = true
    end
  end
  if not printed then
    game.print(message)
  end
end

local M = {}

local function init_storage()
  storage.last_research = storage.last_research or {}
  storage.warn_at = storage.warn_at or {}
  storage.gate_progress = storage.gate_progress or {}
end

function M.tick()
  init_storage()
  local setting = settings.global["chipotrio-strict-compute"]
  local enforce = setting and setting.value

  for _, force in pairs(game.forces) do
    local tech = force.current_research
    if not tech then
      storage.last_research[force.name] = nil
      storage.gate_progress[force.name] = nil
    else
      local gate = meta[tech.name]
      if gate then
        if storage.last_research[force.name] ~= tech.name then
          storage.last_research[force.name] = tech.name
          storage.gate_progress[force.name] = nil
          force_print(force, {
            "chipotrio.gate-required",
            tostring(gate.rate),
            { "item-name." .. gate.item },
          })
        end

        local rate = rates.production_rate(force, gate.item)
        if enforce and rate < gate.rate then
          local ratio = math.max(0, rate / gate.rate)
          local deficit = 1 - ratio
          local progress = force.research_progress
          local previous = storage.gate_progress[force.name]

          -- Throttle: only the share of progress the factory actually earned
          -- survives. With no production the bar freezes, then decays. A
          -- stockpile can keep the labs fed, but it cannot outrun production.
          if previous and progress >= previous then
            progress = previous + (progress - previous) * ratio
          end
          progress = math.max(0, math.min(1, progress - DECAY_PER_SECOND * deficit))
          storage.gate_progress[force.name] = progress
          force.research_progress = progress

          if game.tick >= (storage.warn_at[force.name] or 0) then
            storage.warn_at[force.name] = game.tick + WARN_INTERVAL
            force_print(force, {
              "chipotrio.gate-warning",
              string.format("%.1f", rate),
              tostring(gate.rate),
              { "item-name." .. gate.item },
            })
          end
        else
          storage.gate_progress[force.name] = force.research_progress
        end
      else
        storage.last_research[force.name] = tech.name
        storage.gate_progress[force.name] = nil
      end
    end
  end
end

script.on_init(init_storage)
script.on_configuration_changed(init_storage)

remote.add_interface("chipotrio", {
  -- Debug helper: /c remote.call("chipotrio", "rates")
  rates = function()
    local out = {}
    for _, force in pairs(game.forces) do
      for tech_name, gate in pairs(meta) do
        out[#out + 1] = string.format(
          "%s: %s %.2f/s (needs %d/s)",
          force.name,
          gate.item,
          rates.production_rate(force, gate.item),
          gate.rate
        )
      end
    end
    game.print(table.concat(out, "\n"))
  end,
})

return M
