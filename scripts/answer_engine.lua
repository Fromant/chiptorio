-- Runtime: The Answer Engine.
--
-- The engine itself does not consume science packs. It watches the factory's
-- rolling production statistics and advances a 42-minute clock only while
-- every required line is at or above its target. Dropping below any target
-- pauses the clock; the clock resumes automatically when production recovers.

local answer = require("scripts.answer_meta")
local rates = require("scripts.rates")

local M = {}

local DURATION_TICKS = answer.runtime_seconds * 60
local WARN_INTERVAL = 60 * 60

local GREEN = { r = 0.55, g = 1.0, b = 0.55 }
local RED = { r = 1.0, g = 0.45, b = 0.45 }
local GOLD = { r = 1.0, g = 0.82, b = 0.30 }
local GREY = { r = 0.75, g = 0.80, b = 0.85 }

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
  return tech and tech.level or 0
end

local function demand_scale(force)
  local level = question_level(force)
  local scale = 1 + answer.rate_scale_per_level * math.max(0, level - 1)
  return scale, level
end

local function requirements_for(force)
  local scale, level = demand_scale(force)
  local list = {}
  for _, req in ipairs(answer.requirements) do
    list[#list + 1] = { item = req.item, rate = req.rate * scale }
  end
  return list, level, scale
end

local function check_engine(record)
  local list, level, scale = requirements_for(record.entity.force)
  local ok, results = rates.check(record.entity.force, list)
  return ok, results, level, scale
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
  return record
end

local function reconcile()
  local seen = {}
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered({ name = "answer-engine" })
    for _, entity in ipairs(entities) do
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

  local ok, results, level, scale = check_engine(record)
  local status = frame["answer-status"]
  local progress = frame["answer-progress"]
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

  for _, req in ipairs(results) do
    local label = frame["answer-req-" .. req.item]
    if label then
      label.caption = {
        "chiptorio.answer-requirement",
        { "item-name." .. req.item },
        string.format("%.2f", req.rate),
        string.format("%.2f", req.required),
      }
      label.style.font_color = req.ok and GREEN or RED
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
  for _, req in ipairs(answer.requirements) do
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

  frame.add({ type = "label", name = "answer-demand" })
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

  local _, level, _ = requirements_for(entity.force)
  level = math.max(1, level)

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

local function update_record(record)
  local entity = record.entity
  if not (entity and entity.valid) then
    return
  end

  if record.state == "running" then
    local ok = check_engine(record)
    if ok then
      record.elapsed = record.elapsed + 60
      if record.elapsed >= DURATION_TICKS then
        complete(record)
      end
    else
      record.state = "paused"
      if game.tick >= (record.next_warn or 0) then
        record.next_warn = game.tick + WARN_INTERVAL
        force_print(entity.force, { "chiptorio.answer-paused" })
      end
    end
  elseif record.state == "paused" then
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
  player.print({ "chiptorio.answer-booted" })
  refresh_gui(player, record)
end

M.on_gui_opened = on_gui_opened
M.on_gui_closed = on_gui_closed
M.on_gui_click = on_gui_click

remote.add_interface("chiptorio-answer", {
  -- Debug helper: /c remote.call("chiptorio-answer", "status")
  status = function()
    init_storage()
    for unit_number, record in pairs(storage.answer_engines) do
      if record.entity and record.entity.valid then
        local ok, _, level = check_engine(record)
        log(string.format(
          "CHIPTORIO ANSWER status engine=%d state=%s elapsed=%d/%d level=%d ok=%s score=%d",
          unit_number,
          tostring(record.state),
          record.elapsed,
          DURATION_TICKS,
          level,
          tostring(ok),
          storage.answer_score[record.entity.force.name] or 0
        ))
      end
    end
  end,

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
