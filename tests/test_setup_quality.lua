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
  "COLOR_THEME_DISABLED",
  "COLOR_THEME_FOCUS",
  "COLOR_THEME_EDIT",
  "COLOR_THEME_ACTIVE",
  "SMLSIZE",
  "MIDSIZE",
  "DBLSIZE",
  "CENTER",
  "VCENTER",
  "RIGHT",
  "BOLD",
  "INVERS",
  "PREC1",
  "SOLID",
  "DOTTED",
  "FORCE",
  "EVT_VIRTUAL_ENTER",
  "lcd",
  "model",
  "bit32",
  "getFieldInfo",
  "getValue",
  "getFlightMode",
  "switches",
  "setStickySwitch",
  "getStickySwitch",
  "getLogicalSwitchValue",
  "playTone",
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

local function read_file(path)
  local previous = io.input()
  local file = assert(io.input(path))
  local content = io.read("*a")
  io.input(previous)
  file:close()
  return content
end

local function new_gui_stub(env)
  local function element()
    return {
      drawFocus = function() end
    }
  end

  local function make_gui()
    local gui
    gui = {
      customs = {},
      x = 0,
      y = 0,
      drawFilledRectangle = function(...) lcd.drawFilledRectangle(...) end,
      drawRectangle = function(...) lcd.drawRectangle(...) end,
      drawText = function(...) lcd.drawText(...) end,
      drawNumber = function(...) lcd.drawNumber(...) end,
      drawTextLines = function(...) lcd.drawTextLines(...) end,
      drawLine = function(...) lcd.drawLine(...) end,
      drawFilledCircle = function(...) lcd.drawFilledCircle(...) end,
      drawCircle = function(...) lcd.drawCircle(...) end,
      run = function(self, event, touchState)
        if type(self) ~= "table" then
          touchState = event
          event = self
          self = gui
        end
        if self.fullScreenRefresh then
          self.fullScreenRefresh()
        end
      end,
      showPrompt = function(prompt)
        env.prompts[#env.prompts + 1] = prompt
        env.activePrompt = prompt
      end,
      dismissPrompt = function()
        env.dismissedPrompts = env.dismissedPrompts + 1
        env.activePrompt = nil
      end,
      custom = function()
        local custom = element()
        gui.customs[#gui.customs + 1] = custom
        return custom
      end,
      gui = function()
        return make_gui()
      end,
      verticalSlider = function(x, y, h, value)
        local slider = element()
        slider.value = value
        return slider
      end,
      button = function() return element() end,
      menu = function() return element() end,
      dropDown = function(x, y, w, h, items, selected, onChange, flags)
        local dropDown = element()
        dropDown.items = items
        dropDown.selected = selected
        dropDown.onChange = onChange
        dropDown.flags = flags
        env.dropDowns[#env.dropDowns + 1] = dropDown
        return dropDown
      end,
      label = function(x, y, w, h, text)
        env.labels[#env.labels + 1] = text
        return element()
      end,
      number = function(x, y, w, h, value, onChangeValue)
        env.numbers[#env.numbers + 1] = value
        local number = element()
        number.value = value
        number.onChangeValue = onChangeValue
        return number
      end
    }
    return gui
  end

  return {
    colors = {
      primary1 = COLOR_THEME_PRIMARY1,
      primary2 = COLOR_THEME_PRIMARY2,
      primary3 = COLOR_THEME_PRIMARY3,
      secondary1 = COLOR_THEME_SECONDARY1,
      secondary2 = COLOR_THEME_SECONDARY2,
      secondary3 = COLOR_THEME_SECONDARY3,
      focus = COLOR_THEME_FOCUS,
      edit = COLOR_THEME_EDIT,
      active = COLOR_THEME_ACTIVE
    },
    flags = 0,
    newGUI = make_gui
  }
end

local function setup_env(options)
  restore_globals()
  options = options or {}

  local env = {
    drawCalls = {},
    drawTexts = {},
    drawTextLines = {},
    labels = {},
    dropDowns = {},
    numbers = {},
    prompts = {},
    dismissedPrompts = 0,
    gvWrites = {},
    stickyWrites = {},
    sticky = options.sticky or {},
    curves = options.curves or {},
    outputs = options.outputs or {},
    gvs = options.gvs or {},
    logicalSwitches = options.logicalSwitches or {},
    values = options.values or {},
    input8 = options.input8,
    parameterValue = options.parameterValue
  }

  local screen = options.screen or { w = 480, h = 272 }
  LCD_W = screen.w
  LCD_H = screen.h
  COLOR_THEME_PRIMARY1 = 1
  COLOR_THEME_PRIMARY2 = 2
  COLOR_THEME_PRIMARY3 = 3
  COLOR_THEME_SECONDARY1 = 4
  COLOR_THEME_SECONDARY2 = 5
  COLOR_THEME_SECONDARY3 = 6
  COLOR_THEME_DISABLED = 7
  COLOR_THEME_FOCUS = 8
  COLOR_THEME_EDIT = 9
  COLOR_THEME_ACTIVE = 10
  SMLSIZE = 0x0010
  MIDSIZE = 0x0020
  DBLSIZE = 0x0040
  CENTER = 0x0100
  VCENTER = 0x0200
  RIGHT = 0x0400
  BOLD = 0x0800
  INVERS = 0x1000
  PREC1 = 0x2000
  SOLID = 1
  DOTTED = 2
  FORCE = 4
  EVT_VIRTUAL_ENTER = 1
  bit32 = {
    band = function(a, b) return 0 end,
    rshift = function(a, b) return 0 end,
    bor = function(a, b) return (a or 0) + (b or 0) end
  }

  local function recordDraw(method, ...)
    env.drawCalls[#env.drawCalls + 1] = { method = method, args = { ... } }
  end

  lcd = {
    clear = function() end,
    drawFilledRectangle = function(...) recordDraw("drawFilledRectangle", ...) end,
    drawRectangle = function(...) recordDraw("drawRectangle", ...) end,
    drawLine = function(...) recordDraw("drawLine", ...) end,
    drawFilledCircle = function(...) recordDraw("drawFilledCircle", ...) end,
    drawCircle = function(...) recordDraw("drawCircle", ...) end,
    drawPie = function(...) recordDraw("drawPie", ...) end,
    drawAnnulus = function(...) recordDraw("drawAnnulus", ...) end,
    drawArc = function(...) recordDraw("drawArc", ...) end,
    drawText = function(x, y, text, flags)
      recordDraw("drawText", x, y, text, flags)
      env.drawTexts[#env.drawTexts + 1] = tostring(text)
    end,
    drawNumber = function(...) recordDraw("drawNumber", ...) end,
    drawTextLines = function(x, y, w, h, text, flags)
      recordDraw("drawTextLines", x, y, w, h, text, flags)
      env.drawTextLines[#env.drawTextLines + 1] = tostring(text)
    end,
    exitFullScreen = function() end,
    sizeText = function() return 24, 12 end,
    getColor = function() return 0 end,
    RGB = function() return 0 end
  }

  model = {
    getCurve = function(index)
      return env.curves[index]
    end,
    setCurve = function(index, curve)
      env.curves[index] = curve
    end,
    getOutput = function(index)
      return env.outputs[index]
    end,
    setOutput = function(index, output)
      env.outputs[index] = output
    end,
    getGlobalVariable = function(index)
      return env.gvs[index] or 0
    end,
    setGlobalVariable = function(index, phase, value)
      env.gvWrites[#env.gvWrites + 1] = { index = index, phase = phase, value = value }
      env.gvs[index] = value
    end,
    getLogicalSwitch = function(index)
      env.logicalSwitches[index] = env.logicalSwitches[index] or { v1 = 1 }
      return env.logicalSwitches[index]
    end,
    setLogicalSwitch = function(index, value)
      env.logicalSwitches[index] = value
    end
  }

  function switches()
    local names = {
      "SA-",
      "SA+",
      "SB-",
      "SB0",
      "SB+",
      "SC-",
      "SC0",
      "SC+",
      "SD-",
      "SD+",
      "SE-",
      "SE0",
      "SE+"
    }
    local i = 0
    return function()
      i = i + 1
      if names[i] then
        return i, names[i]
      end
    end
  end

  function getFieldInfo(name)
    if name == "input8" and env.input8 then
      return { id = env.input8 }
    elseif name == "trim-rud" or name == "trim-thr" or name == "trim-ail" or name == "trim-ele" then
      return { id = name }
    elseif name == "T1" or name == "T2" or name == "T3" or name == "T4" then
      return { id = name }
    end
    return nil
  end

  function getValue(source)
    if source ~= nil and env.values[source] ~= nil then
      return env.values[source]
    end
    return 0
  end

  function getFlightMode()
    return 0, "Normal"
  end

  function setStickySwitch(index, value)
    env.stickyWrites[#env.stickyWrites + 1] = { index = index, value = value }
    env.sticky[index] = value
  end

  if not options.omitGetStickySwitch then
    function getStickySwitch(index)
      return env.sticky[index] or false
    end
  else
    getStickySwitch = nil
  end

  function getLogicalSwitchValue(index)
    return env.sticky[index] or false
  end

  function playTone() end

  function loadScript(path)
    local localPath = path:gsub("^/WIDGETS/SoarF5J/", "src/SoarF5J/")
    return assert(loadfile(localPath))
  end

  env.soarGlobals = {
    libGUI = new_gui_stub(env),
    path = "/WIDGETS/SoarF5J/",
    getCurve = function(index)
      return env.curves[index]
    end,
    battery = 11.2,
    batteryParameter = 1,
    getParameter = function()
      return env.parameterValue
    end,
    setParameter = function(index, value)
      env.parameterValue = value
    end
  }
  env.widget = {
    zone = { w = 200, h = 100 }
  }

  return env
end

local function load_setup_page(path, env)
  return assert(loadfile(path))(env.widget, env.soarGlobals)
end

local function text_rendered(env)
  local out = {}
  for _, text in ipairs(env.drawTexts) do out[#out + 1] = text end
  for _, text in ipairs(env.drawTextLines) do out[#out + 1] = text end
  return table.concat(out, "\n")
end

local function five_point_curve()
  return { y = { -100, -50, 0, 50, 100 } }
end

local function valid_wing_outputs()
  return {
    [0] = { curve = 0, min = -1000, offset = 0, max = 1000 },
    [1] = { curve = 1, min = -1000, offset = 0, max = 1000 },
    [2] = { curve = 2, min = -1000, offset = 0, max = 1000 },
    [3] = { curve = 3, min = -1000, offset = 0, max = 1000 }
  }
end

local function setup_quality_test(name, fn)
  test(name, function()
    local ok, err = pcall(fn)
    restore_globals()
    if not ok then
      error(err, 0)
    end
  end)
end

local supported_screens = {
  { name = "480x272", w = 480, h = 272 },
  { name = "480x320", w = 480, h = 320 },
  { name = "800x480", w = 800, h = 480 }
}

local function assert_screen_size(screen)
  assert_equal(LCD_W, screen.w, screen.name .. " width")
  assert_equal(LCD_H, screen.h, screen.name .. " height")
end

local function bounds_label(method, screen, index, subject)
  if subject then
    return string.format("%s %s draw call %d on %s", subject, method, index, screen.name)
  end
  return string.format("%s draw call %d on %s", method, index, screen.name)
end

local function assert_point_in_screen(x, y, screen, label)
  assert(type(x) == "number" and type(y) == "number", label .. " has non-numeric coordinates")
  assert(x >= 0, label .. " x is negative")
  assert(y >= 0, label .. " y is negative")
  assert(x <= screen.w, label .. " x exceeds screen width")
  assert(y <= screen.h, label .. " y exceeds screen height")
end

local function assert_box_in_screen(x, y, w, h, screen, label)
  assert_point_in_screen(x, y, screen, label)
  assert(type(w) == "number" and type(h) == "number", label .. " has non-numeric size")
  assert(w >= 0, label .. " width is negative")
  assert(h >= 0, label .. " height is negative")
  assert(x + w <= screen.w, label .. " extends past screen width")
  assert(y + h <= screen.h, label .. " extends past screen height")
end

local function assert_circle_in_screen(x, y, r, screen, label)
  assert(type(r) == "number" and r >= 0, label .. " has invalid radius")
  assert_box_in_screen(x - r, y - r, r * 2, r * 2, screen, label)
end

local function assert_draw_calls_in_screen(env, screen, subject)
  for i, call in ipairs(env.drawCalls) do
    local label = bounds_label(call.method, screen, i, subject)
    local a = call.args

    if call.method == "drawFilledRectangle" or call.method == "drawRectangle" or call.method == "drawTextLines" then
      assert_box_in_screen(a[1], a[2], a[3], a[4], screen, label)
    elseif call.method == "drawLine" then
      assert_point_in_screen(a[1], a[2], screen, label .. " start")
      assert_point_in_screen(a[3], a[4], screen, label .. " end")
    elseif call.method == "drawText" or call.method == "drawNumber" then
      assert_point_in_screen(a[1], a[2], screen, label)
    elseif call.method == "drawFilledCircle" or call.method == "drawCircle" or
        call.method == "drawPie" or call.method == "drawAnnulus" or call.method == "drawArc" then
      assert_circle_in_screen(a[1], a[2], a[3], screen, label)
    end
  end
end

local function render_after_warning(env)
  env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  if env.prompts[1] and env.prompts[1].customs and env.prompts[1].customs[1] then
    env.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
    env.drawCalls = {}
    env.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  end
end

setup_quality_test("curve setup pages load with valid stubs", function()
  local brake = setup_env({
    input8 = 800,
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  assert(pcall(function() brake.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "brake curves valid refresh crashed")

  local wing = setup_env({
    input8 = 800,
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
  assert(pcall(function() wing.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "wing alignment valid refresh crashed")
end)

setup_quality_test("setup pages render inside supported landscape screen sizes", function()
  for _, screen in ipairs(supported_screens) do
    local switches = setup_env({ screen = screen })
    load_setup_page("src/SoarF5J/setup/switches.lua", switches)
    render_after_warning(switches)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(switches, screen, "switches")

    local mixes = setup_env({ screen = screen })
    load_setup_page("src/SoarF5J/setup/mixes.lua", mixes)
    render_after_warning(mixes)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(mixes, screen, "mixes")

    local brake = setup_env({
      screen = screen,
      input8 = 800,
      curves = {
        [4] = five_point_curve(),
        [5] = five_point_curve()
      }
    })
    load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
    render_after_warning(brake)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(brake, screen, "brake curves")

    local wing = setup_env({
      screen = screen,
      input8 = 800,
      curves = {
        [0] = five_point_curve(),
        [1] = five_point_curve(),
        [2] = five_point_curve(),
        [3] = five_point_curve()
      },
      outputs = valid_wing_outputs()
    })
    load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
    render_after_warning(wing)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(wing, screen, "wing alignment")

    local aileron = setup_env({
      screen = screen,
      gvs = {
        [0] = 57,
        [1] = 24,
        [3] = 0,
        [6] = 153,
        [9] = 33
      }
    })
    load_setup_page("src/SoarF5J/setup/aileron_camber.lua", aileron)
    render_after_warning(aileron)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(aileron, screen, "aileron camber")

    local outputs = setup_env({ screen = screen })
    local outputNames = {
      "AilL",
      "FlpL",
      "FlpR",
      "AilR"
    }
    for i = 0, 31 do
      outputs.outputs[i] = { name = outputNames[i + 1] or "", min = -1000, offset = 0, max = 1000 }
    end
    function getFieldInfo(name)
      if name == "ch1" then
        return { id = 100 }
      end
      return nil
    end
    outputs.modelMixes = {}
    model.getMixesCount = function(channel)
      local mixes = outputs.modelMixes[channel] or {}
      return #mixes
    end
    model.getMix = function(channel, index)
      return outputs.modelMixes[channel] and outputs.modelMixes[channel][index + 1] or {}
    end
    model.deleteMix = function(channel, index) end
    model.insertMix = function(channel, index, mix) end
    load_setup_page("src/SoarF5J/setup/outputs.lua", outputs)
    render_after_warning(outputs)
    assert_screen_size(screen)
    assert_draw_calls_in_screen(outputs, screen, "outputs")
  end
end)

setup_quality_test("switches page exposes landing and landing-off switches", function()
  local switchesPage = setup_env({
    logicalSwitches = {
      [5] = { v1 = 1 },
      [44] = { v1 = 1 },
      [45] = { v1 = 1 },
      [46] = { v1 = 1 }
    }
  })
  load_setup_page("src/SoarF5J/setup/switches.lua", switchesPage)
  switchesPage.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(switchesPage.labels[1], "Launch mode (Motor Arm) and flight timer control", "first switches row")
  assert_equal(switchesPage.labels[2], "Start/Stop timer and Motor", "second switches row")

  local sawLandingLabel = false
  local sawLandingOffLabel = false
  local sawAileronElevatorLabel = false
  for _, label in ipairs(switchesPage.labels) do
    if label == "Landing" then
      sawLandingLabel = true
    elseif label == "Landing off / crow off" then
      sawLandingOffLabel = true
    elseif label == "Aileron -> Elevator" then
      sawAileronElevatorLabel = true
    end
  end
  assert(sawLandingLabel, "switches page missing Landing label")
  assert(sawLandingOffLabel, "switches page missing Landing off label")
  assert(sawAileronElevatorLabel, "switches page missing Aileron -> Elevator label")

  local sawLandingSwitch = false
  local sawLandingOffSwitch = false
  local sawAileronElevatorSwitch = false
  for _, dropDown in ipairs(switchesPage.dropDowns) do
    if dropDown.ls == 5 then
      sawLandingSwitch = true
    elseif dropDown.ls == 44 then
      sawLandingOffSwitch = true
    elseif dropDown.ls == 45 then
      sawAileronElevatorSwitch = true
    end
  end
  assert(sawLandingSwitch, "switches page missing L06 dropdown")
  assert(sawLandingOffSwitch, "switches page missing L45 dropdown")
  assert(sawAileronElevatorSwitch, "switches page missing L46 dropdown")
end)

setup_quality_test("switches page keeps crow-off audio edge switch aligned", function()
  local switchesPage = setup_env({
    logicalSwitches = {
      [44] = { v1 = 1 },
      [46] = { v1 = 1 }
    }
  })
  load_setup_page("src/SoarF5J/setup/switches.lua", switchesPage)
  switchesPage.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  local landingOff
  for _, dropDown in ipairs(switchesPage.dropDowns) do
    if dropDown.ls == 44 then
      landingOff = dropDown
      break
    end
  end

  assert(landingOff, "missing L45 landing-off dropdown")
  landingOff.selected = 3
  landingOff.onChange(landingOff)

  assert_equal(switchesPage.logicalSwitches[44].v1, 3, "L45 landing-off switch")
  assert_equal(switchesPage.logicalSwitches[46].v1, 3, "L47 crow-off audio switch")
end)

setup_quality_test("curve setup pages show motor warning prompt before edits", function()
  local brake = setup_env({
    input8 = 800,
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(brake.prompts[1], "brake curves did not show motor warning prompt")
  assert(#brake.stickyWrites == 0, "brake curves wrote step switch before warning acknowledgment")
  brake.prompts[1].fullScreenRefresh()
  assert(text_rendered(brake):find("Please disable the motor", 1, true), "brake curves warning copy missing")
  brake.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  assert(brake.stickyWrites[1] and brake.stickyWrites[1].value == true, "brake curves did not enable step switch after warning acknowledgment")

  local wing = setup_env({
    input8 = 800,
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
  wing.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(wing.prompts[1], "wing alignment did not show motor warning prompt")
  assert(#wing.gvWrites == 0, "wing alignment wrote GV8 before warning acknowledgment")
  wing.prompts[1].fullScreenRefresh()
  assert(text_rendered(wing):find("Please disable the motor", 1, true), "wing alignment warning copy missing")
  wing.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  assert(wing.gvWrites[1] and wing.gvWrites[1].value == 1, "wing alignment did not enable GV8 after warning acknowledgment")
end)

setup_quality_test("brake curves supports radios without getStickySwitch", function()
  local brake = setup_env({
    input8 = 800,
    omitGetStickySwitch = true,
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })

  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(brake.prompts[1], "brake curves did not show motor warning prompt")

  local ok, err = pcall(function()
    brake.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  end)

  assert(ok, "brake curves crashed without getStickySwitch: " .. tostring(err))
  assert(brake.stickyWrites[1] and brake.stickyWrites[1].value == true, "brake curves did not enable step switch")
end)

setup_quality_test("brake curves trims adjust selected flap and aileron landing points", function()
  local brake = setup_env({
    input8 = 800,
    values = { [800] = -512 },
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })

  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  brake.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  assert(brake.stickyWrites[1] and brake.stickyWrites[1].index == 11 and brake.stickyWrites[1].value == true,
    "brake curves did not enable live step switch")

  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  local flapBefore = brake.curves[4].y[2]
  local aileronBefore = brake.curves[5].y[2]

  brake.values["trim-thr"] = 1024
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(brake.curves[4].y[2], flapBefore + 1, "throttle trim flap point")
  assert_equal(brake.curves[5].y[2], aileronBefore, "throttle trim aileron point")

  brake.values["trim-thr"] = 0
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  flapBefore = brake.curves[4].y[2]
  aileronBefore = brake.curves[5].y[2]

  brake.values["trim-ele"] = -1024
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  assert_equal(brake.curves[4].y[2], flapBefore, "elevator trim flap point")
  assert_equal(brake.curves[5].y[2], aileronBefore - 1, "elevator trim aileron point")
end)

setup_quality_test("curve setup pages report missing step input without load crash", function()
  local brake = setup_env({
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  assert(pcall(function() load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake) end), "brake curves load crashed")
  assert(pcall(function() brake.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "brake curves refresh crashed")
  assert(text_rendered(brake):find("input8", 1, true), "brake curves did not report missing input")

  local wing = setup_env({
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  assert(pcall(function() load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing) end), "wing alignment load crashed")
  assert(pcall(function() wing.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "wing alignment refresh crashed")
  assert(text_rendered(wing):find("input8", 1, true), "wing alignment did not report missing input")
end)

setup_quality_test("curve setup pages report missing curves without refresh crash", function()
  local brake = setup_env({ input8 = 800, curves = {} })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  assert(pcall(function() brake.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "brake curves missing curve crashed")
  assert(text_rendered(brake):find("CV", 1, true), "brake curves did not report missing curve")

  local wing = setup_env({
    input8 = 800,
    curves = {},
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
  assert(pcall(function() wing.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "wing alignment missing curve crashed")
  assert(text_rendered(wing):find("CV", 1, true), "wing alignment did not report missing curve")
end)

setup_quality_test("battery threshold values are clamped in setup pages", function()
  local values = {
    { nil },
    { "bad" },
    { -250 },
    { 250 }
  }

  for _, entry in ipairs(values) do
    local parameterValue = entry[1]
    local mixes = setup_env({ parameterValue = parameterValue })
    load_setup_page("src/SoarF5J/setup/mixes.lua", mixes)
    assert(pcall(function() mixes.widget.refresh(EVT_VIRTUAL_ENTER, nil) end), "mixes page crashed")
    assert(mixes.numbers[#mixes.numbers] and mixes.numbers[#mixes.numbers] >= 0 and mixes.numbers[#mixes.numbers] <= 200, "mixes value not clamped")
  end
end)

setup_quality_test("mixes page enables and restores trim adjustment mode", function()
  local mixes = setup_env()
  load_setup_page("src/SoarF5J/setup/mixes.lua", mixes)
  mixes.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  mixes.widget.background()

  local sawOn, sawOff = false, false
  for _, write in ipairs(mixes.gvWrites) do
    if write.index == 7 and write.value == 4 then sawOn = true end
    if write.index == 7 and write.value == 0 then sawOff = true end
  end
  assert(sawOn, "mixes page did not enable GV8 mix trim mode")
  assert(sawOff, "mixes page did not restore owned GV8 mode")

  local previousMode = setup_env({ gvs = { [7] = 2 } })
  load_setup_page("src/SoarF5J/setup/mixes.lua", previousMode)
  previousMode.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  previousMode.widget.background()

  local restoredPrevious = false
  for _, write in ipairs(previousMode.gvWrites) do
    if write.index == 7 and write.value == 2 then restoredPrevious = true end
  end
  assert(restoredPrevious, "mixes page did not restore previous GV8 mode")
end)

setup_quality_test("outputs reinsert saved mix list deterministically", function()
  local content = read_file("src/SoarF5J/setup/outputs.lua")
  assert(content:find("ipairs(mixes[3 - i])", 1, true), "saved mix list reinsertion is not deterministic")
end)

setup_quality_test("aileron camber cleanup tracks owned state", function()
  local content = read_file("src/SoarF5J/setup/aileron_camber.lua")

  assert(content:find("ctrOwned", 1, true), "missing owned switch state")
  assert(content:find("adjustModePrevious", 1, true), "missing owned adjustment state")
  assert(not content:find("if getLogicalSwitchValue(LS_CTR) then", 1, true), "cleanup still clears unowned switch")
end)

setup_quality_test("aileron camber cleanup restores previous GV8 mode", function()
  local previousMode = setup_env({ gvs = { [7] = 1 } })
  load_setup_page("src/SoarF5J/setup/aileron_camber.lua", previousMode)
  previousMode.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(previousMode.activePrompt, "aileron camber warning prompt was not active")
  assert(#previousMode.gvWrites == 0, "aileron camber wrote GV8 before warning acknowledgment")
  assert(#previousMode.stickyWrites == 0, "aileron camber wrote center switch before warning acknowledgment")
  previousMode.prompts[1].fullScreenRefresh()
  assert(text_rendered(previousMode):find("Please disable the motor", 1, true), "aileron camber warning copy missing")
  previousMode.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  previousMode.widget.background()

  local restoredPrevious = false
  for _, write in ipairs(previousMode.gvWrites) do
    if write.index == 7 and write.value == 1 then restoredPrevious = true end
  end
  assert(restoredPrevious, "aileron camber did not restore previous GV8 mode")
end)

setup_quality_test("aileron camber layout keeps diagram clear of copy", function()
  local aileron = setup_env({
    gvs = {
      [0] = 57,
      [1] = 24,
      [3] = 0,
      [6] = 153,
      [9] = 33
    }
  })
  load_setup_page("src/SoarF5J/setup/aileron_camber.lua", aileron)
  aileron.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  aileron.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  aileron.widget.refresh(EVT_VIRTUAL_ENTER, nil)

  local diagram
  local help
  local throttle
  for _, call in ipairs(aileron.drawCalls) do
    if call.method == "drawPie" and not diagram then
      diagram = {
        x = call.args[1],
        y = call.args[2],
        r = call.args[3]
      }
    elseif call.method == "drawTextLines" and tostring(call.args[5]):find("maximum reflex", 1, true) then
      help = {
        x = call.args[1],
        y = call.args[2],
        w = call.args[3]
      }
    elseif call.method == "drawText" and call.args[3] == "Throttle trim" then
      throttle = {
        y = call.args[2]
      }
    end
  end

  assert(diagram, "missing aileron/camber diagram")
  assert(help, "missing aileron/camber help copy")
  assert(throttle, "missing throttle trim row")
  local smallTextH = select(2, lcd.sizeText("", SMLSIZE))
  assert(diagram.y - diagram.r >= 44, "diagram overlaps top bar")
  assert(diagram.x - diagram.r >= 220, "diagram overlaps trim/help copy column")
  assert(diagram.x + diagram.r <= LCD_W - 50, "diagram overlaps slider area")
  assert(throttle.y + smallTextH + 8 <= help.y, "help copy overlaps trim rows")
  assert(help.x + help.w <= diagram.x - diagram.r, "help copy overlaps diagram")
end)

setup_quality_test("wing alignment cleanup tracks owned GV8 state", function()
  local alreadyAdjusting = setup_env({
    input8 = 800,
    gvs = { [7] = 1 },
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", alreadyAdjusting)
  alreadyAdjusting.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  alreadyAdjusting.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  alreadyAdjusting.widget.background()
  for _, write in ipairs(alreadyAdjusting.gvWrites) do
    assert(not (write.index == 7 and write.value == 0), "wing alignment cleared unowned GV8")
  end

  local ownedAdjusting = setup_env({
    input8 = 800,
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", ownedAdjusting)
  ownedAdjusting.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  ownedAdjusting.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  ownedAdjusting.widget.background()

  local sawOn, sawOff = false, false
  for _, write in ipairs(ownedAdjusting.gvWrites) do
    if write.index == 7 and write.value == 1 then sawOn = true end
    if write.index == 7 and write.value == 0 then sawOff = true end
  end
  assert(sawOn, "wing alignment did not enable owned GV8")
  assert(sawOff, "wing alignment did not restore owned GV8")

  local previousMode = setup_env({
    input8 = 800,
    gvs = { [7] = 3 },
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", previousMode)
  previousMode.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  previousMode.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  previousMode.widget.background()

  local restoredPrevious = false
  for _, write in ipairs(previousMode.gvWrites) do
    if write.index == 7 and write.value == 3 then restoredPrevious = true end
  end
  assert(restoredPrevious, "wing alignment did not restore previous GV8 mode")
end)

setup_quality_test("wing alignment trims move and align flap and aileron curve pairs", function()
  local function new_wing()
    local wing = setup_env({
      input8 = 800,
      values = { [800] = -512 },
      curves = {
        [0] = five_point_curve(),
        [1] = five_point_curve(),
        [2] = five_point_curve(),
        [3] = five_point_curve()
      },
      outputs = valid_wing_outputs()
    })

    load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
    wing.widget.refresh(EVT_VIRTUAL_ENTER, nil)
    wing.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
    return wing
  end

  local function deltas_after(source)
    local wing = new_wing()
    local before = {
      leftAileron = wing.curves[0].y[4],
      rightAileron = wing.curves[1].y[2],
      leftFlap = wing.curves[2].y[4],
      rightFlap = wing.curves[3].y[2]
    }

    wing.values[source] = 1024
    wing.widget.refresh(EVT_VIRTUAL_ENTER, nil)

    return {
      leftAileron = wing.curves[0].y[4] - before.leftAileron,
      rightAileron = wing.curves[1].y[2] - before.rightAileron,
      leftFlap = wing.curves[2].y[4] - before.leftFlap,
      rightFlap = wing.curves[3].y[2] - before.rightFlap
    }
  end

  local flapMove = deltas_after("trim-thr")
  assert_equal(flapMove.leftAileron, 0, "left aileron unchanged by flap move")
  assert_equal(flapMove.rightAileron, 0, "right aileron unchanged by flap move")
  assert(flapMove.leftFlap * flapMove.rightFlap < 0, "flap move did not move pair together")

  local aileronMove = deltas_after("trim-ele")
  assert_equal(aileronMove.leftFlap, 0, "left flap unchanged by aileron move")
  assert_equal(aileronMove.rightFlap, 0, "right flap unchanged by aileron move")
  assert(aileronMove.leftAileron * aileronMove.rightAileron < 0, "aileron move did not move pair together")

  local flapAlign = deltas_after("trim-rud")
  assert_equal(flapAlign.leftAileron, 0, "left aileron unchanged by flap align")
  assert_equal(flapAlign.rightAileron, 0, "right aileron unchanged by flap align")
  assert(flapAlign.leftFlap * flapAlign.rightFlap > 0, "flap align did not move sides opposite each other")

  local aileronAlign = deltas_after("trim-ail")
  assert_equal(aileronAlign.leftFlap, 0, "left flap unchanged by aileron align")
  assert_equal(aileronAlign.rightFlap, 0, "right flap unchanged by aileron align")
  assert(aileronAlign.leftAileron * aileronAlign.rightAileron > 0, "aileron align did not move sides opposite each other")
end)

setup_quality_test("brake curves cleanup tracks owned step switch state", function()
  local alreadyStepping = setup_env({
    input8 = 800,
    sticky = { [11] = true },
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", alreadyStepping)
  alreadyStepping.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  alreadyStepping.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  alreadyStepping.widget.background()
  for _, write in ipairs(alreadyStepping.stickyWrites) do
    assert(not (write.index == 11 and write.value == false), "brake curves cleared unowned step switch")
  end

  local ownedStepping = setup_env({
    input8 = 800,
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", ownedStepping)
  ownedStepping.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  ownedStepping.prompts[1].customs[1].onEvent(EVT_VIRTUAL_ENTER)
  ownedStepping.widget.background()

  local sawOn, sawOff = false, false
  for _, write in ipairs(ownedStepping.stickyWrites) do
    if write.index == 11 and write.value == true then sawOn = true end
    if write.index == 11 and write.value == false then sawOff = true end
  end
  assert(sawOn, "brake curves did not enable owned step switch")
  assert(sawOff, "brake curves did not restore owned step switch")
end)

setup_quality_test("motor warning prompts are dismissed before page background cleanup", function()
  local brake = setup_env({
    input8 = 800,
    curves = {
      [4] = five_point_curve(),
      [5] = five_point_curve()
    }
  })
  load_setup_page("src/SoarF5J/setup/brake_curves.lua", brake)
  brake.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(brake.activePrompt, "brake curves warning prompt was not active")
  brake.widget.background()
  assert(not brake.activePrompt, "brake curves left warning prompt active")
  assert(brake.dismissedPrompts > 0, "brake curves did not dismiss prompt")

  local wing = setup_env({
    input8 = 800,
    curves = {
      [0] = five_point_curve(),
      [1] = five_point_curve(),
      [2] = five_point_curve(),
      [3] = five_point_curve()
    },
    outputs = valid_wing_outputs()
  })
  load_setup_page("src/SoarF5J/setup/wing_alignment.lua", wing)
  wing.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(wing.activePrompt, "wing alignment warning prompt was not active")
  wing.widget.background()
  assert(not wing.activePrompt, "wing alignment left warning prompt active")
  assert(wing.dismissedPrompts > 0, "wing alignment did not dismiss prompt")

  local outputs = setup_env()
  local outputNames = {
    "AilL",
    "FlpL",
    "FlpR",
    "AilR"
  }
  for i = 0, 31 do
    outputs.outputs[i] = { name = outputNames[i + 1] or "", min = -1000, offset = 0, max = 1000 }
  end
  function getFieldInfo(name)
    if name == "ch1" then
      return { id = 100 }
    end
    return nil
  end
  outputs.modelMixes = {}
  model.getMixesCount = function(channel)
    local mixes = outputs.modelMixes[channel] or {}
    return #mixes
  end
  model.getMix = function(channel, index)
    return outputs.modelMixes[channel] and outputs.modelMixes[channel][index + 1] or {}
  end
  model.deleteMix = function(channel, index) end
  model.insertMix = function(channel, index, mix) end
  load_setup_page("src/SoarF5J/setup/outputs.lua", outputs)
  outputs.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(outputs.activePrompt, "outputs warning prompt was not active")
  outputs.widget.background()
  assert(not outputs.activePrompt, "outputs left warning prompt active")
  assert(outputs.dismissedPrompts > 0, "outputs did not dismiss prompt")

  local outputsTile = setup_env()
  for i = 0, 31 do
    outputsTile.outputs[i] = { name = outputNames[i + 1] or "", min = -1000, offset = 0, max = 1000 }
  end
  function getFieldInfo(name)
    if name == "ch1" then
      return { id = 100 }
    end
    return nil
  end
  outputsTile.modelMixes = {}
  model.getMixesCount = function(channel)
    local mixes = outputsTile.modelMixes[channel] or {}
    return #mixes
  end
  model.getMix = function(channel, index)
    return outputsTile.modelMixes[channel] and outputsTile.modelMixes[channel][index + 1] or {}
  end
  model.deleteMix = function(channel, index) end
  model.insertMix = function(channel, index, mix) end
  load_setup_page("src/SoarF5J/setup/outputs.lua", outputsTile)
  outputsTile.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(outputsTile.activePrompt, "outputs tile warning prompt was not active")
  outputsTile.widget.refresh(nil, nil)
  assert(not outputsTile.activePrompt, "outputs tile refresh left warning prompt active")
  assert(outputsTile.dismissedPrompts > 0, "outputs tile refresh did not dismiss prompt")

  local aileron = setup_env()
  load_setup_page("src/SoarF5J/setup/aileron_camber.lua", aileron)
  aileron.widget.refresh(EVT_VIRTUAL_ENTER, nil)
  assert(aileron.activePrompt, "aileron camber warning prompt was not active")
  aileron.widget.background()
  assert(not aileron.activePrompt, "aileron camber left warning prompt active")
  assert(aileron.dismissedPrompts > 0, "aileron camber did not dismiss prompt")
end)
