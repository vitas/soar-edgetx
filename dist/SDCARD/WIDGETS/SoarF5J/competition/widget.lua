---------------------------------------------------------------------------
-- SoarF5J competition widget                                            --
--                                                                       --
-- SoarF5J contributor: Vitaliy Ryumshyn                                --
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

local LS_ALT10 = 7
local LS_TRIGGER = 8
local LS_ARM = 22
local GV_FLIGHT_TIMER = 8
local FM_LAUNCH = 2
local DEFAULT_TARGET_TIME = 600
local TARGET_TIME_STEP = 60
local ALTITUDE_CALL_INTERVAL = 10
local MOTOR_CALL_INTERVAL = 10
local HEIGHT_CAPTURE_WINDOW = 10
local FLIGHT_TIMER_COLOR = lcd.RGB(0, 70, 20)
local MOTOR_TIMER_COLOR = lcd.RGB(110, 0, 0)

local state
local prevArm
local prevTrigger
local lastMotorOn
local heightRemaining = 0
local flightTimerRunning
local nextAltitudeCall = 0
local nextMotorCall = MOTOR_CALL_INTERVAL
local lastHeightCall
local previousFlightCallValue
local observedTimerStart

local modeLabels = {
  initial = "Ready",
  motor = "Motor ON",
  glide = "Glide",
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
  local start = timer_number(timer.start, 0)
  local value = timer_number(timer.value, 0)
  local target = state and state.target_time or nil

  if observedTimerStart == nil then
    if start > 0 then
      target = start
    elseif value > 0 then
      target = value
    end
  elseif start > 0 and start ~= observedTimerStart then
    target = start
  elseif type(target) ~= "number" or target <= 0 then
    if start > 0 then
      target = start
    elseif value > 0 then
      target = value
    end
  end

  observedTimerStart = start

  if type(target) ~= "number" or target < 0 then
    return DEFAULT_TARGET_TIME
  end
  return target
end

local function set_timer(index, values)
  local timer = read_timer(index)
  for key, value in pairs(values) do
    timer[key] = value
  end
  model.setTimer(index, timer)
end

local function set_flight_timer_running(running, force)
  local value = running and 1 or 0
  if force or flightTimerRunning ~= value then
    model.setGlobalVariable(GV_FLIGHT_TIMER, 0, value)
    flightTimerRunning = value
  end
end

local function announce_seconds(seconds)
  if seconds <= 0 then
    return
  end

  if type(playDuration) == "function" then
    playDuration(seconds, 0)
  elseif type(playNumber) == "function" then
    playNumber(seconds, UNIT_SECONDS or 0)
  end
end

local function announce_number(seconds)
  if seconds <= 0 then
    return
  end

  if type(playNumber) == "function" then
    playNumber(seconds, 0)
  elseif type(playDuration) == "function" then
    playDuration(seconds, 0)
  end
end

local function reset_voice_calls()
  nextMotorCall = MOTOR_CALL_INTERVAL
  lastHeightCall = nil
  previousFlightCallValue = nil
end

local function reset_radio_timers()
  local target = state.target_time or read_target_time()
  set_timer(0, { start = target, value = target })
  set_timer(1, { start = 0, value = 0 })
  if type(model.resetTimer) == "function" then
    model.resetTimer(0)
    model.resetTimer(1)
  end
  observedTimerStart = target
end

local function initialize_flight(resetAltitude)
  local target = read_target_time()

  State.arm(state)
  State.set_target_time(state, target)
  reset_radio_timers()
  set_flight_timer_running(false, true)
  reset_voice_calls()

  if resetAltitude then
    soarGlobals.edgetx.resetAltitude()
  end
end

local function read_max_altitude()
  if type(getValue) ~= "function" then
    return nil
  end
  return getValue("Alt+")
end

local function read_current_altitude()
  if type(getValue) ~= "function" then
    return nil
  end
  return getValue("Alt")
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
  State.set_target_time(state, clamp(seconds, 0, 3600))
  reset_radio_timers()
end

local function step_target_time(seconds, delta)
  local current = clamp(timer_number(seconds, DEFAULT_TARGET_TIME), 0, 3600)
  local minutes

  if delta > 0 then
    minutes = math.floor(current / TARGET_TIME_STEP)
  elseif delta < 0 then
    minutes = math.ceil(current / TARGET_TIME_STEP)
  else
    return current
  end

  return clamp((minutes + delta) * TARGET_TIME_STEP, 0, 3600)
end

local function record_flight_time()
  local timer = read_timer(0)
  local start = timer_number(timer.start, state.target_time or DEFAULT_TARGET_TIME)
  local value = clamp(timer_number(timer.value, start), 0, start)
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
  reset_voice_calls()
end

local function enforce_flight_timer_floor()
  local value = timer_number(read_timer(0).value, state.target_time or DEFAULT_TARGET_TIME)

  if value < 0 then
    set_timer(0, { value = 0 })
  end

  if value <= 0 then
    set_flight_timer_running(false, false)
  end
end

local function adjust_current_field(delta)
  if delta == 0 then
    return
  end

  if state.mode == "initial" then
    set_target_time(step_target_time(state.target_time or read_target_time(), delta))
  end
end

local function advance_scoring_state()
  if state.mode == "glide" then
    record_flight_time()
  elseif state.mode == "finished" or state.mode == "zero" then
    State.trigger(state)
    reset_radio_timers()
    set_flight_timer_running(false, true)
    reset_voice_calls()
    return
  end

  State.trigger(state)
end

local function update_height_window(now)
  State.capture_max_altitude(state, read_max_altitude(), now)
  State.tick(state, { now = now })

  if state.height_capture_pending and state.height_window_started_at then
    heightRemaining = math.max(0, math.ceil(HEIGHT_CAPTURE_WINDOW - (now - state.height_window_started_at)))
  else
    heightRemaining = 0
  end

  if state.height_window_elapsed then
    heightRemaining = 0
  end
end

local function report_motor_time()
  local elapsed = math.floor(timer_number(read_timer(1).value, 0))
  if elapsed < nextMotorCall then
    return
  end

  local announced = math.floor(elapsed / MOTOR_CALL_INTERVAL) * MOTOR_CALL_INTERVAL
  if announced < nextMotorCall then
    announced = nextMotorCall
  end

  announce_seconds(announced)
  nextMotorCall = announced + MOTOR_CALL_INTERVAL
end

local function report_height_window()
  if heightRemaining <= 0 or heightRemaining == lastHeightCall then
    return
  end

  announce_number(heightRemaining)
  lastHeightCall = heightRemaining
end

local function flight_call_interval(remaining)
  if remaining > 120 then
    return 60
  elseif remaining > 60 then
    return 15
  elseif remaining > 10 then
    return 5
  end
  return 1
end

local function report_flight_time()
  local remaining = math.floor(timer_number(read_timer(0).value, state.target_time or DEFAULT_TARGET_TIME))
  if remaining < 0 then
    remaining = 0
  end

  if previousFlightCallValue == nil then
    previousFlightCallValue = remaining
    return
  end

  local interval = flight_call_interval(remaining)
  if math.ceil(previousFlightCallValue / interval) > math.ceil(remaining / interval) then
    if remaining > 10 then
      announce_seconds(remaining)
    elseif remaining > 0 then
      announce_number(remaining)
    end
  end

  previousFlightCallValue = remaining
end

local function report_altitude(now)
  if state.height_capture_pending or not getLogicalSwitchValue(LS_ALT10) then
    return
  end

  if now < nextAltitudeCall then
    return
  end

  local altitude = read_current_altitude()
  if type(altitude) == "number" and type(playNumber) == "function" then
    playNumber(altitude, UNIT_METERS or 0)
    nextAltitudeCall = now + ALTITUDE_CALL_INTERVAL
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
    nextAltitudeCall = 0
  end

  if state.height_capture_pending then
    update_height_window(now)
  end

  if state.mode == "initial" then
    sync_target_from_timer()
    adjust_current_field(event_delta(event))

    if motorOn then
      State.motor_started(state)
      State.capture_max_altitude(state, read_max_altitude(), now)
      reset_radio_timers()
      set_flight_timer_running(true, true)
      reset_voice_calls()
    end
  elseif state.mode == "motor" then
    State.capture_max_altitude(state, read_max_altitude(), now)
    if not motorOn then
      State.motor_stopped(state, now)
      set_flight_timer_running(true, true)
      update_height_window(now)
      report_height_window()
    else
      enforce_flight_timer_floor()
      report_motor_time()
    end
  elseif state.mode == "glide" then
    if motorOn and not lastMotorOn then
      zero_result()
    else
      enforce_flight_timer_floor()
      report_flight_time()
      update_height_window(now)
      report_height_window()
      report_altitude(now)
      if triggerEdge then
        advance_scoring_state()
      end
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

  return math.max(0, timer_number(read_timer(0).value, state.target_time or DEFAULT_TARGET_TIME))
end

local function motor_timer_value()
  return timer_number(read_timer(1).value, 0)
end

local function draw_metric(label, value, suffix, x, y, w)
  lcd.drawText(x, y, label, colors.primary3 + SMLSIZE)
  lcd.drawText(x + w, y, tostring(value) .. suffix, colors.primary1 + MIDSIZE + RIGHT)
end

local function draw()
  local w = widget.zone.w
  local h = widget.zone.h
  local pad = 8
  local headerH = 26
  local textYOffset = 20
  local right = w - pad
  local rowY = headerH + pad + textYOffset
  local compact = h < 190
  local timerSize = compact and DBLSIZE or XXLSIZE
  local labelSize = compact and MIDSIZE or DBLSIZE
  local timerGap = compact and 46 or 68
  local metricGap = compact and 42 or 54
  local flightTimerFlags = FLIGHT_TIMER_COLOR + timerSize + RIGHT
  local motorTimerFlags = MOTOR_TIMER_COLOR + timerSize + RIGHT

  lcd.drawFilledRectangle(0, 0, w, h, colors.secondary3)
  lcd.drawFilledRectangle(0, 0, w, headerH, colors.secondary1)
  lcd.drawText(pad, 5 + textYOffset, "F5J", colors.primary3 + MIDSIZE)
  lcd.drawText(right, 7 + textYOffset, status_text(), colors.primary3 + MIDSIZE + RIGHT)

  lcd.drawText(pad, rowY + 8, state.mode == "initial" and "Target" or "Flight", colors.primary3 + labelSize)
  lcd.drawTimer(right, rowY, flight_timer_value(), flightTimerFlags)

  rowY = rowY + timerGap
  lcd.drawText(pad, rowY + 8, "Motor", colors.primary3 + labelSize)
  lcd.drawTimer(right, rowY, motor_timer_value(), motorTimerFlags)

  rowY = rowY + metricGap
  draw_metric("Max alt", state.max_altitude or 0, " m", pad, rowY, w - 2 * pad)
end

state = State.new({ target_time = read_target_time() })
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
