local State = dofile("src/SoarF5J/competition/state.lua")

test("initial state after new", function()
  local s = State.new({ target_time = 600 })

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.target_time, 600, "target_time")
  assert_equal(s.landing_points, 0, "landing_points")
  assert_equal(s.start_height, 100, "start_height")
  assert_equal(s.timing_active, false, "timing_active")
end)

test("initial state accepts supplied start height", function()
  local s = State.new({ target_time = 600, start_height = 85 })

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.start_height, 85, "start_height")
end)

test("arm resets flight to prepared initial state", function()
  local s = State.new({ target_time = 600, start_height = 120 })
  State.motor_started(s)
  State.motor_stopped(s, 12)
  State.restart_motor(s)
  s.landing_points = 40

  State.arm(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.zero_result, false, "zero_result")
  assert_equal(s.motor_restarted, false, "motor_restarted")
  assert_equal(s.landing_points, 0, "landing_points")
  assert_equal(s.height_window_started_at, nil, "height_window_started_at")
  assert_equal(s.height_capture_pending, false, "height_capture_pending")
  assert_equal(s.timing_active, false, "timing_active")
end)

test("arm restores configured start height after zero result", function()
  local s = State.new({ target_time = 600, start_height = 120 })
  State.motor_started(s)
  State.motor_stopped(s, 12)
  State.restart_motor(s)

  State.arm(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.start_height, 120, "start_height")
end)

test("arm restores default start height after zero result", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 12)
  State.restart_motor(s)

  State.arm(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.start_height, 100, "start_height")
end)

test("motor starts competition timing", function()
  local s = State.new({ target_time = 600 })

  State.motor_started(s)

  assert_equal(s.mode, "motor", "mode")
  assert_equal(s.timing_active, true, "timing_active")
end)

test("motor off enters glide and opens height window", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)

  State.motor_stopped(s, 42)

  assert_equal(s.mode, "glide", "mode")
  assert_equal(s.timing_active, true, "timing_active")
  assert_equal(s.height_window_started_at, 42, "height_window_started_at")
  assert_equal(s.height_capture_pending, true, "height_capture_pending")

  State.tick(s, { now = 53 })
  assert_equal(s.height_window_elapsed, true, "height_window_elapsed")
end)

test("start height is captured after height window elapses", function()
  local s = State.new({ target_time = 600, start_height = 100 })
  State.motor_started(s)
  State.motor_stopped(s, 20)

  State.tick(s, { now = 29 })
  State.capture_start_height(s, 87)
  assert_equal(s.start_height, 100, "start_height before window")
  assert_equal(s.height_capture_pending, true, "height_capture_pending before window")

  State.tick(s, { now = 30 })
  State.capture_start_height(s, 87)

  assert_equal(s.start_height, 87, "start_height")
  assert_equal(s.height_capture_pending, false, "height_capture_pending")
  assert_equal(s.height_window_started_at, nil, "height_window_started_at")
end)

test("start height falls back when captured altitude is invalid", function()
  local s = State.new({ target_time = 600, start_height = 115 })
  State.motor_started(s)
  State.motor_stopped(s, 20)

  State.tick(s, { now = 31 })
  State.capture_start_height(s, 0)

  assert_equal(s.start_height, 115, "zero fallback")

  local missing = State.new({ target_time = 600, start_height = 115 })
  State.motor_started(missing)
  State.motor_stopped(missing, 50)
  State.tick(missing, { now = 60 })
  State.capture_start_height(missing, nil)

  assert_equal(missing.start_height, 115, "missing fallback")
  assert_equal(missing.height_capture_pending, false, "height_capture_pending")
end)

test("target time can be corrected before launch only", function()
  local s = State.new({ target_time = 600 })

  State.set_target_time(s, 540)
  assert_equal(s.target_time, 540, "initial target_time")

  State.motor_started(s)
  State.set_target_time(s, 420)

  assert_equal(s.target_time, 540, "launched target_time")
end)

test("landing trigger enters landing points state", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 20)

  State.trigger(s)

  assert_equal(s.mode, "landing_points", "mode")
end)

test("trigger advances scoring states and resets finished flight", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 20)

  State.trigger(s)
  assert_equal(s.mode, "landing_points", "landing mode")
  State.trigger(s)
  assert_equal(s.mode, "start_height", "start_height mode")
  State.trigger(s)
  assert_equal(s.mode, "time_correction", "time_correction mode")
  State.trigger(s)
  assert_equal(s.mode, "finished", "finished mode")
  State.trigger(s)
  assert_equal(s.mode, "initial", "reset mode")
end)

test("motor restart after glide forces zero result", function()
  local s = State.new({ target_time = 600, start_height = 110 })
  State.motor_started(s)
  State.motor_stopped(s, 20)
  s.flight_time = 120
  s.result = 350

  State.restart_motor(s)

  assert_equal(s.mode, "zero", "mode")
  assert_equal(s.flight_time, 0, "flight_time")
  assert_equal(s.result, 0, "result")
  assert_equal(s.start_height, 0, "start_height")
  assert_equal(s.zero_result, true, "zero_result")
  assert_equal(s.motor_restarted, true, "motor_restarted")
end)

test("motor restart clears elapsed height window state", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 20)
  State.tick(s, { now = 31 })

  State.restart_motor(s)

  assert_equal(s.mode, "zero", "mode")
  assert_equal(s.height_capture_pending, false, "height_capture_pending")
  assert_equal(s.height_window_started_at, nil, "height_window_started_at")
  assert_equal(s.height_window_elapsed, false, "height_window_elapsed")
end)

test("motor restart from landing points forces zero result", function()
  local s = State.new({ target_time = 600, start_height = 110 })
  State.motor_started(s)
  State.motor_stopped(s, 20)
  State.trigger(s)

  State.restart_motor(s)

  assert_equal(s.mode, "zero", "mode")
  assert_equal(s.flight_time, 0, "flight_time")
  assert_equal(s.result, 0, "result")
  assert_equal(s.start_height, 0, "start_height")
end)

test("trigger from zero result resets to initial state", function()
  local s = State.new({ target_time = 600, start_height = 110 })
  State.motor_started(s)
  State.motor_stopped(s, 20)
  State.restart_motor(s)

  State.trigger(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.zero_result, false, "zero_result")
  assert_equal(s.motor_restarted, false, "motor_restarted")
  assert_equal(s.start_height, 110, "start_height")
end)
