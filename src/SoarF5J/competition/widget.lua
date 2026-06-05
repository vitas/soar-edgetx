---------------------------------------------------------------------------
-- SoarF5J competition widget                                            --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

local widget, soarGlobals = ...
local State = loadScript(soarGlobals.path .. "competition/state.lua")()
local colors = soarGlobals.libGUI.colors

local LS_TRIGGER = 8
local LS_ARM = 22
local GV_FLIGHT_TIMER = 8
local FM_LAUNCH = 2
local DEFAULT_TARGET_TIME = 600
local DEFAULT_START_HEIGHT = 100

local state
local prevArm
local prevTrigger
local lastMotorOn
local heightRemaining = 0
local flightTimerRunning

local modeLabels = {
  initial = "Ready",
  motor = "Motor ON",
  glide = "Glide",
  landing_points = "Landing points",
  start_height = "Start height",
  time_correction = "Time correction",
  finished = "Finished",
  zero = "Zero result"
}

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  elseif value > maximum then
    return maximum
  end
  return value
end

local function now_seconds()
  return getTime() / 100
end

local function read_timer(index)
  local timer = model.getTimer(index)
  if type(timer) == "table" then
    return timer
  end
  return { start = 0, value = 0 }
end

local function timer_number(value, fallback)
  if type(value) == "number" then
    return value
  end
  return fallback or 0
end

local function read_target_time()
  local timer = read_timer(0)
  local target = timer_number(timer.start, timer_number(timer.value, DEFAULT_TARGET_TIME))
  if target <= 0 then
    return DEFAULT_TARGET_TIME
  end
  return target
end

local function set_timer(index, values)
  model.setTimer(index, values)
end

local function set_flight_timer_running(running, force)
  local value = running and 1 or 0
  if force or flightTimerRunning ~= value then
    model.setGlobalVariable(GV_FLIGHT_TIMER, 0, value)
    flightTimerRunning = value
  end
end

local function reset_radio_timers()
  local target = state.target_time or read_target_time()
  set_timer(0, { start = target, value = target })
  set_timer(1, { start = 0, value = 0 })
end

local function initialize_flight(resetAltitude)
  local target = read_target_time()

  State.arm(state)
  State.set_target_time(state, target)
  reset_radio_timers()
  set_flight_timer_running(false, true)

  if resetAltitude then
    soarGlobals.edgetx.resetAltitude()
  end
end

local function read_start_altitude()
  if type(getValue) ~= "function" then
    return nil
  end
  return getValue("Alt+")
end

local function flight_mode_is_motor()
  return getFlightMode() == FM_LAUNCH
end

local function logical_switch_edge(index, previous)
  local current = getLogicalSwitchValue(index)
  return current, current and not previous
end

local function trigger_event(event)
  if not event then
    return false
  end
  return event == EVT_VIRTUAL_ENTER or event == EVT_TOUCH_TAP
end

local function event_delta(event)
  if not event then
    return 0
  end
  if event == EVT_VIRTUAL_INC then
    return 1
  elseif event == EVT_VIRTUAL_DEC then
    return -1
  end
  return 0
end

local function sync_target_from_timer()
  State.set_target_time(state, read_target_time())
end

local function set_target_time(seconds)
  State.set_target_time(state, clamp(seconds, 1, 3600))
  reset_radio_timers()
end

local function record_flight_time()
  local timer = read_timer(0)
  local start = timer_number(timer.start, state.target_time or DEFAULT_TARGET_TIME)
  local value = timer_number(timer.value, start)
  local elapsed = start - value

  if elapsed < 0 then
    elapsed = 0
  end

  state.flight_time = elapsed
  set_timer(0, { value = elapsed })
  set_flight_timer_running(false, true)
end

local function zero_result()
  State.restart_motor(state)
  set_timer(0, { value = 0 })
  set_flight_timer_running(false, true)
end

local function adjust_current_field(delta)
  if delta == 0 then
    return
  end

  if state.mode == "initial" then
    set_target_time((state.target_time or read_target_time()) + delta * 60)
  elseif state.mode == "landing_points" then
    state.landing_points = clamp(state.landing_points + delta * 5, 0, 50)
  elseif state.mode == "start_height" then
    state.start_height = clamp(state.start_height + delta, 0, 1000)
  elseif state.mode == "time_correction" then
    state.flight_time = clamp((state.flight_time or 0) + delta, 0, 3600)
    set_timer(0, { value = state.flight_time })
  end
end

local function advance_scoring_state()
  if state.mode == "glide" then
    record_flight_time()
  elseif state.mode == "finished" or state.mode == "zero" then
    State.trigger(state)
    reset_radio_timers()
    set_flight_timer_running(false, true)
    return
  end

  State.trigger(state)
end

local function update_height_window(now)
  State.tick(state, { now = now })

  if state.height_capture_pending and state.height_window_started_at then
    heightRemaining = math.max(0, math.ceil(10 - (now - state.height_window_started_at)))
  else
    heightRemaining = 0
  end

  if state.height_window_elapsed then
    State.capture_start_height(state, read_start_altitude())
    heightRemaining = 0
  end
end

local function run_runtime(event)
  local now = now_seconds()
  local motorOn = flight_mode_is_motor()
  local armEdge
  local triggerEdge

  prevArm, armEdge = logical_switch_edge(LS_ARM, prevArm)
  prevTrigger, triggerEdge = logical_switch_edge(LS_TRIGGER, prevTrigger)
  triggerEdge = triggerEdge or trigger_event(event)

  if armEdge then
    initialize_flight(true)
  end

  if state.height_capture_pending then
    update_height_window(now)
  end

  if state.mode == "initial" then
    sync_target_from_timer()
    adjust_current_field(event_delta(event))

    if motorOn then
      State.motor_started(state)
      reset_radio_timers()
      set_flight_timer_running(true, true)
    end
  elseif state.mode == "motor" then
    if not motorOn then
      State.motor_stopped(state, now)
      set_flight_timer_running(true, true)
    end
  elseif state.mode == "glide" then
    if motorOn and not lastMotorOn then
      zero_result()
    else
      update_height_window(now)
      if triggerEdge then
        advance_scoring_state()
      end
    end
  elseif state.mode == "landing_points" then
    if motorOn and not lastMotorOn then
      zero_result()
    else
      adjust_current_field(event_delta(event))
      if triggerEdge then
        advance_scoring_state()
      end
    end
  elseif state.mode == "start_height" or state.mode == "time_correction" then
    adjust_current_field(event_delta(event))
    if triggerEdge then
      advance_scoring_state()
    end
  elseif state.mode == "finished" then
    if triggerEdge then
      advance_scoring_state()
    end
  elseif state.mode == "zero" then
    if triggerEdge then
      advance_scoring_state()
    end
  end

  lastMotorOn = motorOn
end

local function status_text()
  if state.mode == "glide" and state.height_capture_pending then
    return "Height +" .. heightRemaining .. "s"
  end
  return modeLabels[state.mode] or state.mode
end

local function flight_timer_value()
  if state.mode == "initial" then
    return state.target_time or read_target_time()
  elseif state.flight_time then
    return state.flight_time
  end

  return timer_number(read_timer(0).value, state.target_time or DEFAULT_TARGET_TIME)
end

local function motor_timer_value()
  return timer_number(read_timer(1).value, 0)
end

local function draw_metric(label, value, suffix, x, y, w)
  lcd.drawText(x, y, label, colors.primary2 + SMLSIZE)
  lcd.drawText(x + w, y, tostring(value) .. suffix, colors.primary1 + MIDSIZE + RIGHT)
end

local function draw()
  local w = widget.zone.w
  local h = widget.zone.h
  local pad = 8
  local headerH = 26
  local right = w - pad
  local rowY = headerH + pad
  local compact = h < 190
  local timerSize = compact and DBLSIZE or XXLSIZE
  local labelSize = compact and MIDSIZE or DBLSIZE
  local timerGap = compact and 46 or 68
  local metricGap = compact and 42 or 54
  local timerFlags = colors.primary1 + timerSize + RIGHT

  lcd.drawFilledRectangle(0, 0, w, h, colors.secondary3)
  lcd.drawFilledRectangle(0, 0, w, headerH, colors.secondary1)
  lcd.drawText(pad, 5, "F5J", colors.primary3 + DBLSIZE)
  lcd.drawText(right, 7, status_text(), colors.primary3 + MIDSIZE + RIGHT)

  lcd.drawText(pad, rowY + 8, state.mode == "initial" and "Target" or "Flight", colors.primary2 + labelSize)
  lcd.drawTimer(right, rowY, flight_timer_value(), timerFlags)

  rowY = rowY + timerGap
  lcd.drawText(pad, rowY + 8, "Motor", colors.primary2 + labelSize)
  lcd.drawTimer(right, rowY, motor_timer_value(), timerFlags)

  rowY = rowY + metricGap
  local colW = math.floor((w - pad * 3) / 2)
  draw_metric("Landing", state.landing_points, " pt", pad, rowY, colW)
  draw_metric("Start h", state.start_height, " m", pad * 2 + colW, rowY, colW)

  rowY = rowY + 24
  lcd.drawText(pad, rowY, "Mode: " .. state.mode, colors.primary2 + SMLSIZE)
end

state = State.new({ target_time = read_target_time(), start_height = DEFAULT_START_HEIGHT })
prevArm = getLogicalSwitchValue(LS_ARM)
prevTrigger = getLogicalSwitchValue(LS_TRIGGER)
lastMotorOn = flight_mode_is_motor()

function widget.background()
  run_runtime(nil)
end

function widget.refresh(event, touchState)
  run_runtime(event)
  draw()
end
