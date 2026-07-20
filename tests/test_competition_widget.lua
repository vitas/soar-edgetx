local savedGlobals = {}
local globalNames = {
  "LCD_W",
  "LCD_H",
  "COLOR_THEME_PRIMARY1",
  "COLOR_THEME_PRIMARY2",
  "COLOR_THEME_PRIMARY3",
  "COLOR_THEME_SECONDARY1",
  "COLOR_THEME_SECONDARY2",
  "COLOR_THEME_SECONDARY3",
  "SMLSIZE",
  "MIDSIZE",
  "DBLSIZE",
  "XXLSIZE",
  "RIGHT",
  "EVT_VIRTUAL_ENTER",
  "EVT_TOUCH_TAP",
  "EVT_VIRTUAL_INC",
  "EVT_VIRTUAL_DEC",
  "lcd",
  "model",
  "getTime",
  "getFlightMode",
  "getLogicalSwitchValue",
  "getValue",
  "playNumber",
  "playDuration",
  "UNIT_METERS",
  "UNIT_SECONDS",
  "loadScript"
}

for _, name in ipairs(globalNames) do
  savedGlobals[name] = _G[name]
end

local function restore_globals()
  for _, name in ipairs(globalNames) do
    _G[name] = savedGlobals[name]
  end
end

local function new_widget_env()
  restore_globals()

  local env = {
    now = 0,
    flightMode = 0,
    altitude = nil,
    switches = {},
    timerWrites = {},
    gvWrites = {},
    playNumbers = {},
    playDurations = {},
    drawTexts = {},
    drawTimers = {},
    timers = {
      [0] = { start = 600, value = 600 },
      [1] = { start = 0, value = 0 }
    },
    resetAltitudeCount = 0
  }

  LCD_W = 480
  LCD_H = 272
  COLOR_THEME_PRIMARY1 = 1
  COLOR_THEME_PRIMARY2 = 2
  COLOR_THEME_PRIMARY3 = 3
  COLOR_THEME_SECONDARY1 = 4
  COLOR_THEME_SECONDARY2 = 5
  COLOR_THEME_SECONDARY3 = 6
  SMLSIZE = 10
  MIDSIZE = 20
  DBLSIZE = 30
  XXLSIZE = 40
  RIGHT = 100
  UNIT_METERS = 9
  UNIT_SECONDS = 10
  EVT_VIRTUAL_ENTER = 1
  EVT_TOUCH_TAP = 2
  EVT_VIRTUAL_INC = 3
  EVT_VIRTUAL_DEC = 4

  lcd = {
    drawFilledRectangle = function() end,
    drawTimer = function(x, y, value, flags)
      env.drawTimers[#env.drawTimers + 1] = {
        x = x,
        y = y,
        value = value,
        flags = flags
      }
    end,
    drawText = function(x, y, text, flags)
      env.drawTexts[#env.drawTexts + 1] = {
        x = x,
        y = y,
        text = tostring(text),
        flags = flags
      }
    end,
    RGB = function(r, g, b)
      return 1000000 + r * 10000 + g * 100 + b
    end
  }

  model = {
    getTimer = function(index)
      return env.timers[index]
    end,
    setTimer = function(index, values)
      env.timerWrites[#env.timerWrites + 1] = {
        index = index,
        values = values
      }
      env.timers[index] = env.timers[index] or {}
      for key, value in pairs(values) do
        env.timers[index][key] = value
      end
    end,
    setGlobalVariable = function(index, phase, value)
      env.gvWrites[#env.gvWrites + 1] = {
        index = index,
        phase = phase,
        value = value
      }
    end
  }

  function getTime()
    return env.now
  end

  function getFlightMode()
    return env.flightMode
  end

  function getLogicalSwitchValue(index)
    return env.switches[index] or false
  end

  function getValue(name)
    if name == "Alt+" then
      return env.altitude
    elseif name == "Alt" then
      return env.altitude
    end
    return nil
  end

  function playNumber(value, unit)
    env.playNumbers[#env.playNumbers + 1] = {
      value = value,
      unit = unit
    }
  end

  function playDuration(duration, hourFormat)
    env.playDurations[#env.playDurations + 1] = {
      duration = duration,
      hourFormat = hourFormat
    }
  end

  function loadScript(path)
    local localPath = path:gsub("^/WIDGETS/SoarF5J/", "src/SoarF5J/")
    return assert(loadfile(localPath))
  end

  env.widget = { zone = { w = 480, h = 160 } }
  env.soarGlobals = {
    path = "/WIDGETS/SoarF5J/",
    libGUI = {
      colors = {
        primary1 = COLOR_THEME_PRIMARY1,
        primary2 = COLOR_THEME_PRIMARY2,
        primary3 = COLOR_THEME_PRIMARY3,
        secondary1 = COLOR_THEME_SECONDARY1,
        secondary3 = COLOR_THEME_SECONDARY3
      }
    },
    edgetx = {
      resetAltitude = function()
        env.resetAltitudeCount = env.resetAltitudeCount + 1
      end
    }
  }

  assert(loadfile("src/SoarF5J/competition/widget.lua"))(env.widget, env.soarGlobals)
  return env
end

local function count_timer_writes(env, timerIndex)
  local count = 0
  for _, write in ipairs(env.timerWrites) do
    if write.index == timerIndex then
      count = count + 1
    end
  end
  return count
end

local function count_gv_writes(env, gvIndex)
  local count = 0
  for _, write in ipairs(env.gvWrites) do
    if write.index == gvIndex then
      count = count + 1
    end
  end
  return count
end

local function gv_values(env, gvIndex)
  local values = {}
  for _, write in ipairs(env.gvWrites) do
    if write.index == gvIndex then
      values[#values + 1] = tostring(write.value)
    end
  end
  return table.concat(values, ",")
end

local function duration_values(env)
  local values = {}
  for _, call in ipairs(env.playDurations) do
    values[#values + 1] = tostring(call.duration)
  end
  return table.concat(values, ",")
end

local function play_numbers_with_unit(env, unit)
  local values = {}
  for _, call in ipairs(env.playNumbers) do
    if call.unit == unit then
      values[#values + 1] = call
    end
  end
  return values
end

local function latest_drawn_text(env, prefix)
  for i = #env.drawTexts, 1, -1 do
    local text = env.drawTexts[i].text
    if text:sub(1, #prefix) == prefix then
      return text
    end
  end
  return nil
end

local function latest_drawn_entry(env, exact)
  for i = #env.drawTexts, 1, -1 do
    if env.drawTexts[i].text == exact then
      return env.drawTexts[i]
    end
  end
  return nil
end

local function drawn_text_exists(env, exact)
  for _, entry in ipairs(env.drawTexts) do
    if entry.text == exact then
      return true
    end
  end
  return false
end

local function widget_test(name, fn)
  test(name, function()
    local ok, err = pcall(fn)
    restore_globals()
    if not ok then
      error(err, 0)
    end
  end)
end

widget_test("widget load and initial idle do not write timer 0", function()
  local env = new_widget_env()

  env.widget.background()
  env.widget.refresh(nil, nil)
  env.widget.background()

  assert_equal(count_timer_writes(env, 0), 0, "timer 0 writes")
end)

widget_test("widget load and initial idle do not write GV8", function()
  local env = new_widget_env()

  env.widget.background()
  env.widget.refresh(nil, nil)
  env.widget.background()

  assert_equal(count_gv_writes(env, 8), 0, "GV8 writes")
end)

widget_test("competition timers are drawn in separated vertical rows", function()
  local env = new_widget_env()
  env.widget.zone.h = 220

  env.widget.refresh(nil, nil)

  assert_equal(#env.drawTimers, 2, "timer draw count")
  assert_equal(env.drawTimers[1].y >= 54, true, "first timer starts lower on page")
  assert_equal(env.drawTimers[2].y - env.drawTimers[1].y >= 64, true, "timer row spacing")
end)

widget_test("competition labels and timers use contest colors", function()
  local env = new_widget_env()
  env.widget.zone.h = 220

  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_entry(env, "F5J").flags, COLOR_THEME_PRIMARY3 + MIDSIZE, "model title size")
  assert_equal(latest_drawn_entry(env, "Ready").flags, COLOR_THEME_PRIMARY3 + MIDSIZE + RIGHT, "ready label color")
  assert_equal(latest_drawn_entry(env, "Target").flags, COLOR_THEME_PRIMARY3 + DBLSIZE, "target label color")
  assert_equal(latest_drawn_entry(env, "Motor").flags, COLOR_THEME_PRIMARY3 + DBLSIZE, "motor label color")
  assert_equal(latest_drawn_entry(env, "Max alt").flags, COLOR_THEME_PRIMARY3 + SMLSIZE, "altitude label color")
  assert_equal(env.drawTimers[1].flags, lcd.RGB(0, 70, 20) + XXLSIZE + RIGHT, "flight timer color")
  assert_equal(env.drawTimers[2].flags, lcd.RGB(110, 0, 0) + XXLSIZE + RIGHT, "motor timer color")
end)

widget_test("explicit arm and target adjustment still write timer 0", function()
  local env = new_widget_env()

  env.switches[22] = true
  env.widget.background()
  local afterArm = count_timer_writes(env, 0)
  assert_equal(afterArm > 0, true, "arm timer write")

  env.widget.refresh(EVT_VIRTUAL_INC, nil)
  assert_equal(count_timer_writes(env, 0) > afterArm, true, "target adjustment timer write")
end)

widget_test("target adjustment reaches zero without one second residue", function()
  local env = new_widget_env()

  env.timers[0].start = 60
  env.timers[0].value = 60
  env.widget.background()

  env.widget.refresh(EVT_VIRTUAL_DEC, nil)
  env.widget.background()
  env.drawTimers = {}
  env.widget.refresh(nil, nil)
  assert_equal(env.drawTimers[1].value, 0, "zero target timer")

  env.widget.refresh(EVT_VIRTUAL_INC, nil)
  env.drawTimers = {}
  env.widget.refresh(nil, nil)
  assert_equal(env.drawTimers[1].value, 60, "one minute target timer")
end)

widget_test("target adjustment normalizes stale one second residue", function()
  local env = new_widget_env()

  env.timers[0].start = 1
  env.timers[0].value = 1
  env.widget.background()

  env.widget.refresh(EVT_VIRTUAL_INC, nil)
  env.drawTimers = {}
  env.widget.refresh(nil, nil)

  assert_equal(env.drawTimers[1].value, 60, "normalized target timer")
end)

widget_test("target time ignores stale countdown value while ready", function()
  local env = new_widget_env()

  env.timers[0].value = 589
  env.widget.background()
  env.drawTimers = {}
  env.widget.refresh(nil, nil)

  assert_equal(env.drawTimers[1].value, 600, "ready target timer")
end)

widget_test("arm reset keeps configured target when countdown value is stale", function()
  local env = new_widget_env()

  env.timers[0].value = 589
  env.switches[22] = true
  env.widget.background()

  assert_equal(env.timers[0].start, 600, "radio flight timer start")
  assert_equal(env.timers[0].value, 600, "radio flight timer value")
end)

widget_test("target time follows edited timer start while ready", function()
  local env = new_widget_env()

  env.widget.background()
  env.timers[0].start = 420
  env.widget.background()
  env.drawTimers = {}
  env.widget.refresh(nil, nil)

  assert_equal(env.drawTimers[1].value, 420, "ready target timer")
end)

widget_test("reset after finished ignores stale countdown timer value", function()
  local env = new_widget_env()

  env.widget.background()
  env.flightMode = 2
  env.widget.background()
  env.flightMode = 0
  env.timers[0].value = 541
  env.widget.background()

  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert_equal(latest_drawn_text(env, "Finished"), "Finished", "finished label")

  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  env.timers[0].value = 541
  env.drawTimers = {}
  env.widget.background()
  env.widget.refresh(nil, nil)

  assert_equal(env.drawTimers[1].value, 600, "reset target timer")
end)

widget_test("flight timer display clamps countdown below zero", function()
  local env = new_widget_env()

  env.widget.background()
  env.flightMode = 2
  env.widget.background()
  env.flightMode = 0
  env.widget.background()
  env.now = 1200
  env.timers[0].value = -262
  env.drawTimers = {}
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "Glide"), "Glide", "glide label")
  assert_equal(env.drawTimers[1].value, 0, "flight timer value")
  assert_equal(env.timers[0].value, 0, "radio flight timer value")
end)

widget_test("GV8 writes only on flight timer transitions", function()
  local env = new_widget_env()
  env.gvWrites = {}

  env.switches[22] = true
  env.widget.background()
  assert_equal(gv_values(env, 8), "0", "arm GV8")

  local afterArm = count_gv_writes(env, 8)
  env.widget.background()
  env.widget.refresh(nil, nil)
  assert_equal(count_gv_writes(env, 8), afterArm, "idle after arm GV8")

  env.flightMode = 2
  env.widget.background()
  assert_equal(gv_values(env, 8), "0,1", "launch GV8")

  local afterLaunch = count_gv_writes(env, 8)
  env.widget.background()
  env.widget.refresh(nil, nil)
  assert_equal(count_gv_writes(env, 8), afterLaunch, "idle motor GV8")

  env.now = 500
  env.flightMode = 0
  env.widget.background()
  assert_equal(gv_values(env, 8), "0,1,1", "motor off GV8")

  env.timers[0].value = 540
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert_equal(latest_drawn_text(env, "Finished"), "Finished", "finished label")
  assert_equal(gv_values(env, 8), "0,1,1,0", "finished GV8")

  local afterFinished = count_gv_writes(env, 8)
  env.widget.background()
  env.widget.refresh(nil, nil)
  assert_equal(count_gv_writes(env, 8), afterFinished, "idle finished GV8")

  local beforeFinishedReset = count_gv_writes(env, 8)
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(count_gv_writes(env, 8), beforeFinishedReset + 1, "finished reset GV8")
  assert_equal(gv_values(env, 8), "0,1,1,0,0", "finished reset GV8 values")
end)

widget_test("motor voice reports elapsed motor time every 10 seconds", function()
  local env = new_widget_env()

  env.flightMode = 2
  env.widget.background()

  env.timers[1].value = 9
  env.widget.background()
  assert_equal(duration_values(env), "", "no early motor voice")

  env.timers[1].value = 10
  env.widget.background()
  env.widget.background()
  assert_equal(duration_values(env), "10", "first motor voice")

  env.timers[1].value = 20
  env.widget.background()
  assert_equal(duration_values(env), "10,20", "second motor voice")
end)

widget_test("height window voice counts down after motor stops", function()
  local env = new_widget_env()

  env.flightMode = 2
  env.widget.background()

  env.now = 500
  env.flightMode = 0
  env.widget.background()
  assert_equal(duration_values(env), "", "height window does not use duration voice")
  assert_equal(#env.playNumbers, 1, "height window first number count")
  assert_equal(env.playNumbers[1].value, 10, "height window starts at 10")
  assert_equal(env.playNumbers[1].unit, 0, "height window first number has no unit")

  env.now = 600
  env.widget.background()
  env.widget.background()
  assert_equal(#env.playNumbers, 2, "height window avoids duplicate 9")
  assert_equal(env.playNumbers[2].value, 9, "height window second number")
  assert_equal(env.playNumbers[2].unit, 0, "height window second number has no unit")

  env.now = 700
  env.widget.background()
  assert_equal(#env.playNumbers, 3, "height window continues countdown")
  assert_equal(env.playNumbers[3].value, 8, "height window third number")
  assert_equal(env.playNumbers[3].unit, 0, "height window third number has no unit")

  env.now = 1500
  env.widget.background()
  assert_equal(#env.playNumbers, 3, "height window does not announce zero")
end)

widget_test("max altitude tracks motor and height window after early finish", function()
  local env = new_widget_env()

  env.altitude = 44
  env.flightMode = 2
  env.widget.background()
  env.altitude = 60
  env.widget.background()
  env.now = 500
  env.flightMode = 0
  env.widget.background()
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(latest_drawn_text(env, "Finished"), "Finished", "finished after trigger")

  env.now = 1400
  env.altitude = 87
  env.drawTexts = {}
  env.widget.background()
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "87 m"), "87 m", "captured max altitude")

  env.now = 1600
  env.altitude = 123
  env.drawTexts = {}
  env.widget.background()
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "87 m"), "87 m", "max altitude remains captured")
  assert_equal(drawn_text_exists(env, "Landing"), false, "landing label")
  assert_equal(drawn_text_exists(env, "Start h"), false, "start height label")
  assert_equal(drawn_text_exists(env, "Max alt"), true, "max altitude label")
end)

widget_test("periodic altitude voice follows L8 after height window", function()
  local env = new_widget_env()
  env.switches[7] = true

  env.flightMode = 2
  env.widget.background()
  env.now = 500
  env.flightMode = 0
  env.widget.background()

  env.altitude = 87
  env.now = 1600
  env.widget.background()
  local altitudeCalls = play_numbers_with_unit(env, UNIT_METERS)
  assert_equal(#altitudeCalls, 1, "first altitude call count")
  assert_equal(altitudeCalls[1].value, 87, "first altitude call value")

  env.widget.background()
  altitudeCalls = play_numbers_with_unit(env, UNIT_METERS)
  assert_equal(#altitudeCalls, 1, "same interval duplicate count")

  env.altitude = 93
  env.now = 2600
  env.widget.background()
  altitudeCalls = play_numbers_with_unit(env, UNIT_METERS)
  assert_equal(#altitudeCalls, 2, "second altitude call count")
  assert_equal(altitudeCalls[2].value, 93, "second altitude call value")
end)

widget_test("periodic altitude voice is silent when L8 is off", function()
  local env = new_widget_env()

  env.flightMode = 2
  env.widget.background()
  env.now = 500
  env.flightMode = 0
  env.widget.background()

  env.altitude = 87
  env.now = 1600
  env.widget.background()
  env.now = 2600
  env.widget.background()

  assert_equal(#play_numbers_with_unit(env, UNIT_METERS), 0, "altitude call count")
end)

widget_test("zero result can recover to initial on enter", function()
  local env = new_widget_env()

  env.flightMode = 2
  env.widget.background()
  env.now = 500
  env.flightMode = 0
  env.widget.background()
  env.flightMode = 2
  env.widget.background()
  env.drawTexts = {}
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "Zero result"), "Zero result", "zero label")

  env.flightMode = 0
  env.timerWrites = {}
  env.gvWrites = {}
  env.drawTexts = {}
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(latest_drawn_text(env, "Ready"), "Ready", "ready label")
  assert_equal(drawn_text_exists(env, "Mode: initial"), false, "initial mode footer")
  assert_equal(count_timer_writes(env, 0) > 0, true, "timer reset")
  assert_equal(gv_values(env, 8), "0", "GV8 reset")
end)

restore_globals()
