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
    drawTexts = {},
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
  EVT_VIRTUAL_ENTER = 1
  EVT_TOUCH_TAP = 2
  EVT_VIRTUAL_INC = 3
  EVT_VIRTUAL_DEC = 4

  lcd = {
    drawFilledRectangle = function() end,
    drawTimer = function() end,
    drawText = function(x, y, text)
      env.drawTexts[#env.drawTexts + 1] = {
        x = x,
        y = y,
        text = tostring(text)
      }
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
    end
    return nil
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

local function latest_drawn_text(env, prefix)
  for i = #env.drawTexts, 1, -1 do
    local text = env.drawTexts[i].text
    if text:sub(1, #prefix) == prefix then
      return text
    end
  end
  return nil
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

widget_test("explicit arm and target adjustment still write timer 0", function()
  local env = new_widget_env()

  env.switches[22] = true
  env.widget.background()
  local afterArm = count_timer_writes(env, 0)
  assert_equal(afterArm > 0, true, "arm timer write")

  env.widget.refresh(EVT_VIRTUAL_INC, nil)
  assert_equal(count_timer_writes(env, 0) > afterArm, true, "target adjustment timer write")
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
  assert_equal(gv_values(env, 8), "0,1,1,0", "scoring GV8")

  local afterScoring = count_gv_writes(env, 8)
  env.widget.background()
  env.widget.refresh(nil, nil)
  assert_equal(count_gv_writes(env, 8), afterScoring, "idle scoring GV8")

  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  local beforeFinishedReset = count_gv_writes(env, 8)
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(count_gv_writes(env, 8), beforeFinishedReset + 1, "finished reset GV8")
  assert_equal(gv_values(env, 8), "0,1,1,0,0", "finished reset GV8 values")
end)

widget_test("pending start height is captured after early landing trigger", function()
  local env = new_widget_env()

  env.flightMode = 2
  env.widget.background()
  env.now = 500
  env.flightMode = 0
  env.widget.background()
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  env.now = 1600
  env.altitude = 87
  env.drawTexts = {}
  env.widget.background()
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "87 m"), "87 m", "captured start height")

  env.altitude = 123
  env.drawTexts = {}
  env.widget.background()
  env.widget.refresh(nil, nil)

  assert_equal(latest_drawn_text(env, "87 m"), "87 m", "start height remains captured")
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
  assert_equal(latest_drawn_text(env, "Mode: initial"), "Mode: initial", "initial mode")
  assert_equal(count_timer_writes(env, 0) > 0, true, "timer reset")
  assert_equal(gv_values(env, 8), "0", "GV8 reset")
end)

restore_globals()
