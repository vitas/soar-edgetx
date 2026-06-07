local State = dofile("src/SoarF5J/competition/state.lua")

test("initial state after new", function()
  local s = State.new({ target_time = 600 })

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.target_time, 600, "target_time")
  assert_equal(s.max_altitude, 0, "max_altitude")
  assert_equal(s.landing_points, nil, "landing_points")
  assert_equal(s.timing_active, false, "timing_active")
end)

test("arm resets flight to prepared initial state", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.capture_max_altitude(s, 120, 1)
  State.motor_stopped(s, 12)
  State.restart_motor(s)

  State.arm(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.zero_result, false, "zero_result")
  assert_equal(s.motor_restarted, false, "motor_restarted")
  assert_equal(s.max_altitude, 0, "max_altitude")
  assert_equal(s.height_window_started_at, nil, "height_window_started_at")
  assert_equal(s.height_capture_pending, false, "height_capture_pending")
  assert_equal(s.timing_active, false, "timing_active")
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
  assert_equal(s.height_capture_pending, false, "height_capture_pending after window")
end)

test("max altitude tracks motor run and height window only", function()
  local s = State.new({ target_time = 600 })

  State.capture_max_altitude(s, 200, 0)
  assert_equal(s.max_altitude, 0, "idle max_altitude")

  State.motor_started(s)
  State.capture_max_altitude(s, 80, 2)
  State.capture_max_altitude(s, 75, 3)
  assert_equal(s.max_altitude, 80, "motor max_altitude")

  State.motor_stopped(s, 10)
  State.capture_max_altitude(s, 120, 19)
  assert_equal(s.max_altitude, 120, "height window max_altitude")

  State.capture_max_altitude(s, 130, 21)
  assert_equal(s.max_altitude, 120, "late height max_altitude")

  State.tick(s, { now = 21 })
  State.capture_max_altitude(s, 140, 21)
  assert_equal(s.max_altitude, 120, "closed window max_altitude")
end)

test("invalid altitude values are ignored", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)

  State.capture_max_altitude(s, nil, 1)
  State.capture_max_altitude(s, 0, 2)
  State.capture_max_altitude(s, -5, 3)

  assert_equal(s.max_altitude, 0, "max_altitude")
end)

test("target time can be corrected before launch only", function()
  local s = State.new({ target_time = 600 })

  State.set_target_time(s, 540)
  assert_equal(s.target_time, 540, "initial target_time")

  State.motor_started(s)
  State.set_target_time(s, 420)

  assert_equal(s.target_time, 540, "launched target_time")
end)

test("landing trigger finishes flight without landing points", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 20)

  State.trigger(s)

  assert_equal(s.mode, "finished", "mode")
  assert_equal(s.landing_points, nil, "landing_points")
end)

test("trigger from finished resets flight", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.motor_stopped(s, 20)
  State.trigger(s)

  State.trigger(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.max_altitude, 0, "max_altitude")
end)

test("motor restart after glide forces zero result", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.capture_max_altitude(s, 110, 1)
  State.motor_stopped(s, 20)
  s.flight_time = 120
  s.result = 350

  State.restart_motor(s)

  assert_equal(s.mode, "zero", "mode")
  assert_equal(s.flight_time, 0, "flight_time")
  assert_equal(s.result, 0, "result")
  assert_equal(s.max_altitude, 0, "max_altitude")
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

test("trigger from zero result resets to initial state", function()
  local s = State.new({ target_time = 600 })
  State.motor_started(s)
  State.capture_max_altitude(s, 110, 1)
  State.motor_stopped(s, 20)
  State.restart_motor(s)

  State.trigger(s)

  assert_equal(s.mode, "initial", "mode")
  assert_equal(s.zero_result, false, "zero_result")
  assert_equal(s.motor_restarted, false, "motor_restarted")
  assert_equal(s.max_altitude, 0, "max_altitude")
end)
