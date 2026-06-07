local State = {}

local function reset_flight(state)
  state.mode = "initial"
  state.max_altitude = 0
  state.flight_time = nil
  state.result = nil
  state.zero_result = false
  state.motor_restarted = false
  state.timing_active = false
  state.height_window_started_at = nil
  state.height_capture_pending = false
  state.height_window_elapsed = false
end

function State.new(opts)
  opts = opts or {}

  local state = {
    target_time = opts.target_time,
  }

  reset_flight(state)
  return state
end

function State.arm(state)
  reset_flight(state)
  return state
end

function State.motor_started(state)
  if state.mode == "initial" then
    state.mode = "motor"
    state.timing_active = true
  end
  return state
end

function State.motor_stopped(state, now)
  if state.mode == "motor" then
    state.mode = "glide"
    state.timing_active = true
    state.height_window_started_at = now
    state.height_capture_pending = true
    state.height_window_elapsed = false
  end
  return state
end

function State.tick(state, inputs)
  inputs = inputs or {}

  if state.height_capture_pending and state.height_window_started_at and inputs.now then
    state.height_window_elapsed = (inputs.now - state.height_window_started_at) >= 10
    if state.height_window_elapsed then
      state.height_capture_pending = false
      state.height_window_started_at = nil
    end
  end

  return state
end

function State.capture_max_altitude(state, altitude, now)
  if type(altitude) ~= "number" or altitude <= 0 then
    return state
  end

  local active = state.mode == "motor"
  if not active and state.height_capture_pending and state.height_window_started_at and type(now) == "number" then
    active = (now - state.height_window_started_at) <= 10
  end

  if active and altitude > state.max_altitude then
    state.max_altitude = altitude
  end

  return state
end

function State.set_target_time(state, seconds)
  if state.mode == "initial" and type(seconds) == "number" and seconds >= 0 then
    state.target_time = seconds
  end

  return state
end

function State.trigger(state)
  if state.mode == "glide" then
    state.mode = "finished"
  elseif state.mode == "finished" then
    State.arm(state)
  elseif state.mode == "zero" then
    State.arm(state)
  end

  return state
end

function State.restart_motor(state)
  if state.mode == "glide" then
    state.mode = "zero"
    state.flight_time = 0
    state.result = 0
    state.max_altitude = 0
    state.zero_result = true
    state.motor_restarted = true
    state.timing_active = false
    state.height_capture_pending = false
    state.height_window_started_at = nil
    state.height_window_elapsed = false
  end

  return state
end

return State
