---------------------------------------------------------------------------
-- SoarF5J motor idle setup, loadable component                          --
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
local libGUI = soarGlobals.libGUI
local gui
local colors = libGUI.colors
local title = "Motor"
local safety = loadScript(soarGlobals.path .. "lib/safety.lua")()
local warningPrompt = libGUI.newGUI()
local adjustModePrevious
local beginEditing
local potCurve
local idle
local trimFunction = false

-- Screen drawing constants
-- Fonts are larger on high resolution screens, so sizes follow the title font.
local FONT_SCALE = math.max(1, select(2, lcd.sizeText(title, DBLSIZE)) / 40)
local HEADER = math.floor(40 * FONT_SCALE)
local MARGIN = 20
local LINE = 28
local COL_TRIM = math.floor(0.42 * LCD_W)
local W_IDLE = math.floor(60 * FONT_SCALE)
local CLOSE_W = math.floor(28 * FONT_SCALE)
local CLOSE_Y = math.floor(6 * FONT_SCALE)
local CLOSE_X = LCD_W - CLOSE_Y - CLOSE_W

-- In the Motor flight mode, CV13 "Pot" adds its first point to the motor channel at minimum
-- throttle and nothing at full throttle, so that point is the idle.
local CRV_POT = 12
local IDLE_MIN = 0
local IDLE_MAX = 60

-- While this page holds GV8 at ADJUST_MODE, L49 is on and SF39 moves GV8 one step per
-- throttle trim click instead of moving the trim. The page turns each step into idle.
local GV_ADJUST_MODE = 7
local ADJUST_MODE = 100
local TRIM_THRESHOLD = 50
local LS_TRIM = 48
local SF_TRIM = 38
local GVAR_MODE_SOURCE = 1

-- Setup warning prompt
do
  local PROMPT_W = math.floor(300 * FONT_SCALE)
  local PROMPT_H = math.floor(172 * FONT_SCALE)
  local BTN_W = math.floor(20 * FONT_SCALE)
  local BTN_Y = math.floor(10 * FONT_SCALE)
  local BTN_X = PROMPT_W - BTN_Y - BTN_W
  warningPrompt.x = (LCD_W - PROMPT_W) / 2
  warningPrompt.y = (LCD_H - PROMPT_H) / 2
  warningPrompt.colors = libGUI.colors
  warningPrompt.motor_warning_width = PROMPT_W
  warningPrompt.motor_warning_height = PROMPT_H
  warningPrompt.motor_warning_header = HEADER
  warningPrompt.motor_warning_margin = MARGIN

  function warningPrompt.fullScreenRefresh()
    safety.drawMotorRunsWarning(warningPrompt)
  end

  local buttonClose = warningPrompt.custom({ }, BTN_X, BTN_Y, BTN_W, BTN_W)

  function buttonClose.draw(focused)
    warningPrompt.drawRectangle(BTN_X, BTN_Y, BTN_W, BTN_W, colors.primary2)
    warningPrompt.drawText(BTN_X + BTN_W / 2, BTN_Y + BTN_W / 2, "X", MIDSIZE + CENTER + VCENTER + colors.primary2)
    if focused then
      buttonClose.drawFocus()
    end
  end

  function buttonClose.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      gui.dismissPrompt()
      beginEditing()
    end
  end
end -- Warning prompt

-- Read CV13 as 1-based points, or nil when it is not the templates' three-point idle curve.
local function readPotCurve()
  local curve = soarGlobals.getCurve(CRV_POT)
  if type(curve) ~= "table" or curve.name ~= "Pot" or curve.type ~= 1 or
      type(curve.x) ~= "table" or type(curve.y) ~= "table" then
    return nil
  end

  -- Older EdgeTX versions number the points from 0.
  local first = curve.y[0] ~= nil and 0 or 1
  local x, y = { }, { }
  for i = 1, 3 do
    x[i] = curve.x[first + i - 1]
    y[i] = curve.y[first + i - 1]
    if type(x[i]) ~= "number" or type(y[i]) ~= "number" then
      return nil
    end
  end
  if curve.y[first + 3] ~= nil then
    return nil
  end

  return { name = curve.name, type = curve.type, smooth = curve.smooth, x = x, y = y }
end

local function hasTrimFunction()
  local gvar8 = getFieldInfo("gvar8")
  local throttleTrim = getFieldInfo("trim-thr")
  local counter = model.getLogicalSwitch(LS_TRIM)
  local trim = model.getCustomFunction(SF_TRIM)

  return gvar8 ~= nil and throttleTrim ~= nil and counter ~= nil and trim ~= nil and
    counter.func == LS_FUNC_VPOS and counter.v1 == gvar8.id and counter.v2 == TRIM_THRESHOLD and
    trim.func == FUNC_ADJUST_GVAR and trim.param == GV_ADJUST_MODE and trim.mode == GVAR_MODE_SOURCE and
    trim.value == throttleTrim.id and trim.active == 1 and trim.switch == getSwitchIndex("L49")
end

local function readModel()
  potCurve = readPotCurve()
  idle = potCurve and potCurve.y[1]
  trimFunction = potCurve ~= nil and hasTrimFunction()
end

-- Keep the middle point at half the idle, so the throttle rises evenly as in the templates.
local function setIdle(value)
  value = math.max(IDLE_MIN, math.min(IDLE_MAX, value))
  if value ~= idle then
    idle = value
    potCurve.y = { value, math.floor(value / 2), 0 }
    model.setCurve(CRV_POT, potCurve)
  end
  return idle
end

local function adjustModeOn()
  if adjustModePrevious ~= nil then
    return
  end

  -- A count left over from an interrupted session would keep the throttle trim on GV8.
  local current = model.getGlobalVariable(GV_ADJUST_MODE, 0)
  if type(current) ~= "number" or current > TRIM_THRESHOLD then
    current = 0
  end
  adjustModePrevious = current
  model.setGlobalVariable(GV_ADJUST_MODE, 0, ADJUST_MODE)
end

local function adjustModeOff()
  if adjustModePrevious ~= nil then
    model.setGlobalVariable(GV_ADJUST_MODE, 0, adjustModePrevious)
    adjustModePrevious = nil
  end
end

-- Turn the throttle trim clicks counted in GV8 into idle steps, then reset the count.
local function applyTrimClicks()
  if adjustModePrevious == nil then
    return
  end

  local count = model.getGlobalVariable(GV_ADJUST_MODE, 0)
  if type(count) == "number" and count > TRIM_THRESHOLD and count ~= ADJUST_MODE then
    setIdle(idle + count - ADJUST_MODE)
    model.setGlobalVariable(GV_ADJUST_MODE, 0, ADJUST_MODE)
  end
end

local function dismissPrompt()
  if gui then
    gui.dismissPrompt()
  end
end

beginEditing = function()
  readModel()
  if trimFunction then
    adjustModeOn()
  end
end -- beginEditing()

local function helpText()
  if not potCurve then
    return "Curve CV13 Pot is missing or changed, so this page cannot set the idle."
  elseif trimFunction then
    return "Start the motor with the launch switches and hold the throttle at minimum. " ..
           "The throttle trim changes the idle while this page is open, and the motor follows at once. " ..
           "At 0 the motor stops at minimum throttle."
  end
  return "This model has no throttle trim function for the idle, so the throttle trim works as usual. " ..
         "Select the value and turn the wheel, or tap it and slide, to change the idle. " ..
         "At 0 the motor stops at minimum throttle."
end

-------------------------------- Setup GUI --------------------------------

local function setup_gui()
  gui = libGUI.newGUI()
  readModel()
  gui.showPrompt(warningPrompt)

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Flight mode, so the pilot sees when the motor run is on
    local fmIdx, fmStr = getFlightMode()
    lcd.drawText(LCD_W - HEADER, HEADER / 2, "FM" .. fmIdx .. ":" .. fmStr, RIGHT + VCENTER + MIDSIZE + colors.primary2)

    -- Idle row
    local y = HEADER + LINE / 2
    lcd.drawText(MARGIN, y, "Motor idle", VCENTER + colors.primary1)
    if trimFunction then
      lcd.drawText(COL_TRIM, y, "Throttle trim", VCENTER + colors.primary1)
    end

    -- Help text
    local helpY = HEADER + LINE + 25
    lcd.drawTextLines(MARGIN, helpY, LCD_W - 2 * MARGIN, LCD_H - helpY - MARGIN, helpText(), colors.primary1)
  end

  -- Close button
  local buttonClose = gui.custom({ }, CLOSE_X, CLOSE_Y, CLOSE_W, CLOSE_W)

  function buttonClose.draw(focused)
    lcd.drawRectangle(CLOSE_X, CLOSE_Y, CLOSE_W, CLOSE_W, colors.primary2)
    lcd.drawText(CLOSE_X + CLOSE_W / 2, CLOSE_Y + CLOSE_W / 2, "X", CENTER + VCENTER + MIDSIZE + colors.primary2)

    if focused then
      buttonClose.drawFocus()
    end
  end

  function buttonClose.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      lcd.exitFullScreen()
    end
  end

  -- Idle value, also editable with the wheel or by touch on models without the trim function
  local function changeIdle(delta)
    if idle == nil then
      return "N/A"
    end
    return setIdle(idle + delta)
  end

  local idleNumber = gui.number(LCD_W - MARGIN - W_IDLE, HEADER + 2, W_IDLE, LINE - 4, idle or "N/A", changeIdle,
    RIGHT + libGUI.flags, IDLE_MIN, IDLE_MAX)

  function idleNumber.update()
    idleNumber.disabled = idle == nil
    idleNumber.value = idle or "N/A"
  end
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  dismissPrompt()
  applyTrimClicks()
  adjustModeOff()
  gui = nil
end -- background()

function widget.refresh(event, touchState)
  if not event then
    widget.background()
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif gui == nil then
    setup_gui()
    return
  end

  applyTrimClicks()
  gui.run(event, touchState)
end -- refresh(...)
