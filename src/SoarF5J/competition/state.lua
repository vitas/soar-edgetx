local State = {}

local function reset_flight(state)
  state.mode = "initial"
  state.landing_points = 0
  state.start_height = state.default_start_height
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
    default_start_height = opts.start_height or 100,
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
  end

  return state
end

function State.trigger(state)
  if state.mode == "glide" then
    state.mode = "landing_points"
  elseif state.mode == "landing_points" then
    state.mode = "start_height"
  elseif state.mode == "start_height" then
    state.mode = "time_correction"
  elseif state.mode == "time_correction" then
    state.mode = "finished"
  elseif state.mode == "finished" then
    State.arm(state)
  end

  return state
end

function State.restart_motor(state)
  if state.mode == "glide" or state.mode == "landing_points" then
    state.mode = "zero"
    state.flight_time = 0
    state.result = 0
    state.start_height = 0
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
