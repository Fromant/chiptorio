-- Runtime: The Answer Engine.
--
-- DESIGN §12. The engine is a network client and a QLN consumer. It advances
-- its 42-minute clock only while the network behind it supplies every compute
-- profile, enough memory, enough backplane bandwidth, and the continuous item
-- draw listed in scripts/answer_meta.lua.
--
-- Items are consumed from QLN storage, not from the engine's own inventory:
-- the engine has no science-pack inputs. That is what makes the endgame a
-- logistics problem rather than another lab.

local answer = require("scripts.answer_meta")
local meta = require("scripts.research_meta")
local network = require("scripts.runtime.network_runtime")
local qln = require("scripts.runtime.qln_runtime")

local M = {}

local DURATION_TICKS = answer.runtime_seconds * 60
local WARN_INTERVAL = 60 * 60

local GREEN = { r = 0.55, g = 1.0, b = 0.55 }
local RED = { r = 1.0, g = 0.45, b = 0.45 }
local GOLD = { r = 1.0, g = 0.82, b = 0.30 }
local GREY = { r = 0.75, g = 0.80, b = 0.85 }

local COMPUTE_ROWS = {
  { profile = "scalar", icon = "microprocessor" },
  { profile = "vector", icon = "gpu" },
  { profile = "tensor", icon = "neural-processor" },
  { profile = "quantum", icon = "quantum-processor" },
}

local function init_storage()
  storage.answer_engines = storage.answer_engines or {}
  storage.answer_gui = storage.answer_gui or {}
  storage.answer_score = storage.answer_score or {}
  storage.answer_victory = storage.answer_victory or false
end

M.init_storage = init_storage

local function force_print(force, message)
  local printed = false
  for _, player in pairs(force.players) do
    player.print(message)
    printed = true
  end
  if not printed then
    game.print(message)
  end
end

local function question_level(force)
  local tech = force.technologies and force.technologies["the-question"]
  if not tech then
    return 0
  end
  -- LuaTechnology.level for an infinite technology is the level being
  -- researched next: it reads 1 before the first completion and 2 after it.
  -- The engine counts *completed* levels, so the first victory is level 1 and
  -- uses the base demand and the base 42 points.
  return math.max(0, (tech.level or 1) - 1)
end

local function demand_scale(force)
  local level = question_level(force)
  local scale = 1 + answer.rate_scale_per_level * math.max(0, level - 1)
  return scale, level
end

local function network_stats(entity)
  local graph = network.graph_for(entity.surface)
  local network_id = graph.device_network[entity.unit_number]
  if not network_id then
    return nil
  end
  return graph.networks[network_id]
end

local function pending_demand(record, scale)
  local demand = {}
  local remainder = record.remainder or {}
  for _, req in ipairs(answer.item_demand) do
    local amount = (remainder[req.item] or 0) + req.rate * scale
    local whole = math.floor(amount)
    if whole > 0 then
      demand[#demand + 1] = { item = req.item, count = whole }
    end
  end
  return demand
end

local function check_engine(record)
  local entity = record.entity
  local stats = network_stats(entity)
  local scale, level = demand_scale(entity.force)
  local results = {}
  local ok = true

  local function add(line)
    if not line.ok then
      ok = false
    end
    results[#results + 1] = line
  end

  for _, profile in ipairs(meta.COMPUTE_PROFILES) do
    local required = (answer.compute[profile] or 0) * scale
    local have = stats and stats[profile] or 0
    add({ kind = "compute", profile = profile, required = required, have = have, ok = have >= required })
  end

  local memory_required = answer.memory * scale
  local memory_have = stats and stats.memory or 0
  add({ kind = "memory", required = memory_required, have = memory_have, ok = memory_have >= memory_required })

  local bandwidth_required = answer.bandwidth * scale
  local bandwidth_have = stats and stats.bandwidth or 0
  add({
    kind = "bandwidth",
    required = bandwidth_required,
    have = bandwidth_have,
    ok = bandwidth_have >= bandwidth_required,
  })

  local storage = qln.group_status(entity)
  local demand = pending_demand(record, scale)
  local want = {}
  for _, req in ipairs(demand) do
    want[req.item] = req.count
  end
  for _, req in ipairs(answer.item_demand) do
    local have = storage and storage.items[req.item] or 0
    local count = want[req.item] or 0
    add({
      kind = "item",
      item = req.item,
      rate = req.rate * scale,
      required = count,
      have = have,
      ok = have >= count,
    })
  end

  return ok, results, level, scale, stats, storage
end

local function consume_items(record, scale)
  local next_remainder = {}
  local demand = {}
  for _, req in ipairs(answer.item_demand) do
    local amount = (record.remainder and record.remainder[req.item] or 0) + req.rate * scale
    local whole = math.floor(amount)
    next_remainder[req.item] = amount - whole
    if whole > 0 then
      demand[#demand + 1] = { item = req.item, count = whole }
    end
  end
  if #demand == 0 then
    record.remainder = next_remainder
    return true, {}
  end
  local ok, missing = qln.consume(record.entity, demand)
  if ok then
    record.remainder = next_remainder
  end
  return ok, missing
end

local function ensure_record(entity)
  if not (entity and entity.valid and entity.unit_number) then
    return nil
  end
  local record = storage.answer_engines[entity.unit_number]
  if not record then
    record = {}
    storage.answer_engines[entity.unit_number] = record
  end
  record.entity = entity
  record.state = record.state or "idle"
  record.elapsed = record.elapsed or 0
  record.runs = record.runs or 0
  record.next_warn = record.next_warn or 0
  record.stability = record.stability or 1
  record.remainder = record.remainder or {}
  return record
end

local function reconcile()
  local seen = {}
  for _, surface in pairs(game.surfaces) do
    for _, entity in ipairs(surface.find_entities_filtered({ name = "answer-engine" })) do
      if entity.valid and entity.unit_number then
        seen[entity.unit_number] = true
        ensure_record(entity)
      end
    end
  end
  for unit_number, record in pairs(storage.answer_engines) do
    if not seen[unit_number] or not record.entity or not record.entity.valid then
      storage.answer_engines[unit_number] = nil
    end
  end
end

local function format_time(seconds)
  seconds = math.max(0, math.floor(seconds + 0.5))
  return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function format_value(value)
  if value >= 10000 then
    return string.format("%.1fk", value / 1000)
  end
  if value >= 100 then
    return string.format("%.0f", value)
  end
  return string.format("%.1f", value)
end

local function frame_for(player)
  local relative = player.gui.relative
  if not relative then
    return nil
  end
  local frame = relative["chiptorio-answer"]
  if frame and frame.valid then
    return frame
  end
  return nil
end

local function refresh_gui(player, record)
  local frame = frame_for(player)
  if not frame then
    return
  end

  local ok, results, level, scale, _, pool = check_engine(record)
  local status = frame["answer-status"]
  local progress = frame["answer-progress"]
  -- `pool` is the QLN group status; the score lives in game storage, which the
  -- QLN result must not shadow or the score label would always read zero.
  local score = storage.answer_score[record.entity.force.name] or 0

  if status then
    if record.state == "running" then
      status.caption = {
        "chiptorio.answer-status-running",
        format_time((DURATION_TICKS - record.elapsed) / 60),
      }
      status.style.font_color = GREEN
    elseif record.state == "paused" then
      status.caption = {
        "chiptorio.answer-status-paused",
        format_time((DURATION_TICKS - record.elapsed) / 60),
      }
      status.style.font_color = GOLD
    elseif record.state == "complete" then
      status.caption = { "chiptorio.answer-status-complete", tostring(score) }
      status.style.font_color = GOLD
    else
      status.caption = { "chiptorio.answer-status-idle" }
      status.style.font_color = GREY
    end
  end

  if progress then
    progress.value = math.max(0, math.min(1, record.elapsed / DURATION_TICKS))
  end

  for _, line in ipairs(results) do
    local label
    if line.kind == "compute" then
      label = frame["answer-compute-" .. line.profile]
      if label then
        label.caption = {
          "chiptorio.answer-compute",
          { "chiptorio.compute-" .. line.profile },
          format_value(line.have),
          format_value(line.required),
        }
      end
    elseif line.kind == "item" then
      label = frame["answer-req-" .. line.item]
      if label then
        label.caption = {
          "chiptorio.answer-requirement",
          { "item-name." .. line.item },
          format_value(line.have),
          format_value(line.rate),
        }
      end
    elseif line.kind == "memory" then
      label = frame["answer-memory"]
      if label then
        label.caption = { "chiptorio.answer-memory", format_value(line.have), format_value(line.required) }
      end
    elseif line.kind == "bandwidth" then
      label = frame["answer-bandwidth"]
      if label then
        label.caption = {
          "chiptorio.answer-bandwidth",
          format_value(line.have),
          format_value(line.required),
        }
      end
    end
    if label then
      label.style.font_color = line.ok and GREEN or RED
    end
  end

  local storage_label = frame["answer-qln"]
  if storage_label then
    if pool then
      storage_label.caption = {
        "chiptorio.answer-qln",
        format_value(pool.used),
        format_value(pool.capacity),
      }
      storage_label.style.font_color = pool.used < pool.capacity and GREEN or GOLD
    else
      storage_label.caption = { "chiptorio.answer-qln-missing" }
      storage_label.style.font_color = RED
    end
  end

  local demand = frame["answer-demand"]
  if demand then
    demand.caption = {
      "chiptorio.answer-demand",
      tostring(level),
      string.format("%.2f", scale),
    }
  end

  local stability = frame["answer-stability"]
  if stability then
    stability.caption = { "chiptorio.answer-stability", tostring(math.floor((record.stability or 1) * 100)) }
  end

  local score_label = frame["answer-score"]
  if score_label then
    score_label.caption = { "chiptorio.answer-score", tostring(score) }
  end

  local button = frame["answer-boot"]
  if button then
    if record.state == "complete" then
      button.caption = { "chiptorio.answer-run-again" }
      button.enabled = ok
    elseif record.state == "idle" then
      button.caption = { "chiptorio.answer-boot" }
      button.enabled = ok
    else
      button.caption = { "chiptorio.answer-computing" }
      button.enabled = false
    end
  end
end

local function destroy_gui(player)
  local frame = frame_for(player)
  if frame then
    frame.destroy()
  end
end

local function create_gui(player, record)
  destroy_gui(player)
  local frame = player.gui.relative.add({
    type = "frame",
    name = "chiptorio-answer",
    direction = "vertical",
    caption = { "chiptorio.answer-title" },
    anchor = {
      gui = defines.relative_gui_type.lab_gui,
      position = defines.relative_gui_position.right,
      name = "answer-engine",
    },
  })
  frame.tags = { engine = record.entity.unit_number }
  frame.add({ type = "label", name = "answer-status" })
  frame.add({ type = "progressbar", name = "answer-progress", size = { 380, 20 }, style = "progressbar" })

  local req_table = frame.add({ type = "table", name = "answer-requirements", column_count = 2 })
  for _, row in ipairs(COMPUTE_ROWS) do
    req_table.add({
      type = "sprite-button",
      name = "answer-icon-compute-" .. row.profile,
      sprite = "item/" .. row.icon,
      enabled = false,
      style = "slot_button",
      tooltip = { "chiptorio.compute-" .. row.profile },
    })
    req_table.add({
      type = "label",
      name = "answer-compute-" .. row.profile,
      caption = "",
    })
  end

  for _, spec in ipairs({ { kind = "memory", icon = "memory-bank" }, { kind = "bandwidth", icon = "network-switch" } }) do
    req_table.add({
      type = "sprite-button",
      name = "answer-icon-" .. spec.kind,
      sprite = "item/" .. spec.icon,
      enabled = false,
      style = "slot_button",
      tooltip = { "chiptorio.answer-" .. spec.kind },
    })
    req_table.add({ type = "label", name = "answer-" .. spec.kind, caption = "" })
  end

  for _, req in ipairs(answer.item_demand) do
    req_table.add({
      type = "sprite-button",
      name = "answer-icon-" .. req.item,
      sprite = "item/" .. req.item,
      enabled = false,
      style = "slot_button",
      tooltip = { "item-name." .. req.item },
    })
    req_table.add({
      type = "label",
      name = "answer-req-" .. req.item,
      caption = "",
    })
  end

  frame.add({ type = "label", name = "answer-qln" })
  frame.add({ type = "label", name = "answer-demand" })
  frame.add({ type = "label", name = "answer-stability" })
  frame.add({ type = "label", name = "answer-score" })
  frame.add({ type = "button", name = "answer-boot", caption = { "chiptorio.answer-boot" } })

  storage.answer_gui[player.index] = record.entity.unit_number
  refresh_gui(player, record)
end

local function update_open_guis()
  for player_index, unit_number in pairs(storage.answer_gui) do
    local player = game.players[player_index]
    local record = storage.answer_engines[unit_number]
    if player and record and record.entity and record.entity.valid and frame_for(player) then
      refresh_gui(player, record)
    else
      storage.answer_gui[player_index] = nil
    end
  end
end

local function complete(record)
  local entity = record.entity
  if not (entity and entity.valid) then
    return
  end

  local level = math.max(1, question_level(entity.force))

  record.state = "complete"
  record.elapsed = DURATION_TICKS
  record.runs = (record.runs or 0) + 1

  local points = answer.score_per_level * level
  local force_name = entity.force.name
  storage.answer_score[force_name] = (storage.answer_score[force_name] or 0) + points

  force_print(entity.force, { "chiptorio.answer-complete" })
  force_print(entity.force, { "chiptorio.answer-score-earned", tostring(points), tostring(level) })
  log(string.format(
    "CHIPTORIO ANSWER complete force=%s level=%d points=%d score=%d",
    force_name,
    level,
    points,
    storage.answer_score[force_name]
  ))

  rendering.draw_text({
    text = { "chiptorio.answer-42" },
    surface = entity.surface,
    target = { type = "entity", entity = entity, offset = { 0, -4 } },
    color = GOLD,
    scale = 4,
    time_to_live = 60 * 20,
  })

  for _, player in pairs(entity.force.players) do
    player.play_sound({
      path = "__chiptorio__/sound/answer-fanfare.ogg",
      volume_modifier = 0.8,
    })
  end

  if not storage.answer_victory then
    storage.answer_victory = true
    game.set_win_ending_info({
      title = { "chiptorio.answer-victory-title" },
      message = { "chiptorio.answer-victory-message" },
      bullet_points = {
        { "chiptorio.answer-victory-bullet-1" },
        { "chiptorio.answer-victory-bullet-2" },
        { "chiptorio.answer-victory-bullet-3" },
      },
      final_message = { "chiptorio.answer-victory-final" },
      image_path = "__chiptorio__/graphics/answer-ending.png",
    })
    game.set_game_state({
      game_finished = true,
      player_won = true,
      can_continue = true,
    })
  end
end

local function pause(record, reason)
  record.state = "paused"
  local entity = record.entity
  if entity.valid and game.tick >= (record.next_warn or 0) then
    record.next_warn = game.tick + WARN_INTERVAL
    force_print(entity.force, { reason or "chiptorio.answer-paused" })
  end
end

local function update_record(record)
  local entity = record.entity
  if not (entity and entity.valid) then
    return
  end

  if record.state == "running" then
    local ok, _, _, scale = check_engine(record)
    if ok then
      local consumed = consume_items(record, scale)
      if consumed then
        record.elapsed = record.elapsed + 60
        record.stability = math.min(1, (record.stability or 1) + 0.01)
        if record.elapsed >= DURATION_TICKS then
          complete(record)
        end
      else
        pause(record, "chiptorio.answer-paused-items")
      end
    else
      pause(record)
    end
  elseif record.state == "paused" then
    record.stability = math.max(0, (record.stability or 1) - answer.stability_decay_per_minute)
    local ok = check_engine(record)
    if ok then
      record.state = "running"
      force_print(entity.force, { "chiptorio.answer-resumed" })
    end
  end
end

function M.tick()
  init_storage()
  reconcile()
  for _, record in pairs(storage.answer_engines) do
    update_record(record)
  end
  update_open_guis()
end

local function on_gui_opened(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end

  init_storage()
  storage.answer_gui[player.index] = nil
  destroy_gui(player)

  local entity = event.entity
  if not (entity and entity.valid and entity.name == "answer-engine") then
    return
  end

  local record = ensure_record(entity)
  if record then
    create_gui(player, record)
  end
end

local function on_gui_closed(event)
  local player = game.players[event.player_index]
  if not player then
    return
  end
  init_storage()
  storage.answer_gui[player.index] = nil
  destroy_gui(player)
end

local function on_gui_click(event)
  local player = game.players[event.player_index]
  local element = event.element
  if not player or not element or not element.valid or element.name ~= "answer-boot" then
    return
  end

  init_storage()
  local frame = frame_for(player)
  if not frame then
    return
  end

  local unit_number = frame.tags and frame.tags.engine
  local record = unit_number and storage.answer_engines[unit_number]
  if not (record and record.entity and record.entity.valid) then
    return
  end

  if record.state == "complete" then
    record.state = "idle"
    record.elapsed = 0
    record.remainder = {}
  end
  if record.state ~= "idle" then
    return
  end

  local ok = check_engine(record)
  if not ok then
    player.print({ "chiptorio.answer-boot-failed" })
    refresh_gui(player, record)
    return
  end

  record.state = "running"
  record.elapsed = 0
  record.next_warn = 0
  record.stability = 1
  player.print({ "chiptorio.answer-booted" })
  refresh_gui(player, record)
end

M.on_gui_opened = on_gui_opened
M.on_gui_closed = on_gui_closed
M.on_gui_click = on_gui_click

--- Advance every engine without waiting for the 60-tick dispatcher. Test and
--- debug helper, analogous to the research and qualification step hooks.
function M.step(seconds)
  init_storage()
  reconcile()
  local count = math.max(0, math.floor(seconds or 60))
  for _ = 1, count do
    for _, record in pairs(storage.answer_engines) do
      update_record(record)
    end
  end
  update_open_guis()
  return count
end

local function first_engine()
  for _, record in pairs(storage.answer_engines) do
    if record.entity and record.entity.valid then
      return record
    end
  end
  return nil
end

--- Test/debug helper: the current gate and clock as a plain table.
function M.evaluate()
  init_storage()
  reconcile()
  local record = first_engine()
  if not record then
    return nil
  end
  local ok, results, level, scale = check_engine(record)
  local lines = {}
  for _, line in ipairs(results) do
    lines[#lines + 1] = {
      kind = line.kind,
      item = line.item,
      profile = line.profile,
      required = line.required,
      have = line.have,
      rate = line.rate,
      ok = line.ok,
    }
  end
  return {
    ok = ok,
    state = record.state,
    elapsed = record.elapsed,
    duration = DURATION_TICKS,
    level = level,
    scale = scale,
    stability = record.stability,
    runs = record.runs,
    score = storage.answer_score[record.entity.force.name] or 0,
    victory = storage.answer_victory,
    lines = lines,
  }
end

--- Test/debug helper: boot the first engine without opening its window.
function M.boot()
  init_storage()
  reconcile()
  local record = first_engine()
  if not record then
    return false
  end
  record.state = "idle"
  record.elapsed = 0
  record.remainder = {}
  if not check_engine(record) then
    return false
  end
  record.state = "running"
  record.elapsed = 0
  record.next_warn = 0
  record.stability = 1
  return true
end

remote.add_interface("chiptorio-answer", {
  -- Debug helper: /c remote.call("chiptorio-answer", "status")
  status = function()
    init_storage()
    for unit_number, record in pairs(storage.answer_engines) do
      if record.entity and record.entity.valid then
        local ok, _, level, scale = check_engine(record)
        log(string.format(
          "CHIPTORIO ANSWER status engine=%d state=%s elapsed=%d/%d level=%d scale=%.2f ok=%s stability=%.2f score=%d",
          unit_number,
          tostring(record.state),
          record.elapsed,
          DURATION_TICKS,
          level,
          scale,
          tostring(ok),
          record.stability or 1,
          storage.answer_score[record.entity.force.name] or 0
        ))
      end
    end
  end,

  -- Test/debug helpers. `evaluate` returns the gate as a table and `boot`
  -- starts the first engine without the GUI, so the probe does not depend on
  -- window layout.
  evaluate = M.evaluate,
  boot = M.boot,

  -- /c remote.call("chiptorio-answer", "step", 600)
  step = M.step,

  -- Test helper. Completes every engine immediately and exercises the victory
  -- screen, fanfare and score path.
  debug_complete = function()
    init_storage()
    for _, record in pairs(storage.answer_engines) do
      if record.entity and record.entity.valid and record.state ~= "complete" then
        complete(record)
      end
    end
  end,
})

return M
