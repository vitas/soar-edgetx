---------------------------------------------------------------------------
-- SoarETX Adjust airbrake curves for flaps, ailerons and elevator       --
--                                                                       --
-- Author:  Jesper Frickmann + Frankie Arzu                              --
-- Date:    2025-01-20                                                   --
-- Version: 1.2.4                                                        --
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

local widget, soarGlobals =  ...
local libGUI =  soarGlobals.libGUI
local gui =     nil
local colors =  libGUI.colors
local title =   "Airbrake curves"
local safety =  loadScript(soarGlobals.path .. "lib/safety.lua")()
local warningPrompt = libGUI.newGUI()
local errMsg

-- Screen drawing constants
-- Fonts are larger on high resolution screens, so sizes follow the title font.
local FONT_SCALE = math.max(1, select(2, lcd.sizeText(title, DBLSIZE)) / 40)
local HEADER =    math.floor(40 * FONT_SCALE)
local TOP =       HEADER + 10
local MARGIN =    20
local DIST_X =    40
local GAP =       10
local CURVES =    3
local WIDTH =     math.floor((LCD_W - CURVES * DIST_X - GAP) / CURVES)
-- The curves get the height left above three lines of help text, but stay at most a bit taller than wide.
local TEXT_H =    3 * select(2, lcd.sizeText(title, 0))
local HEIGHT =    math.min(LCD_H - TOP - TEXT_H - 2 * GAP, math.floor(1.25 * WIDTH))
local BUTTON_W =  80
local BUTTON_X =  LCD_W - BUTTON_W - MARGIN
local BUTTON_H =  36
local BUTTON_Y =  TOP + HEIGHT + GAP
local TEXT_Y =    BUTTON_Y
local CLOSE_W =   math.floor(28 * FONT_SCALE)
local CLOSE_Y =   math.floor(6 * FONT_SCALE)
local CLOSE_X =   LCD_W - CLOSE_Y - CLOSE_W
local beginEditing

-- Left edge of curve i, counted from 1
local function plotX(i)
  return DIST_X + (i - 1) * (WIDTH + DIST_X)
end

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
    safety.drawMotorDisabledWarning(warningPrompt)
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

local function setError(message)
  if not errMsg then
    errMsg = message
  end
end

local function safeFieldId(name)
  local field = getFieldInfo(name)
  if not field or not field.id then
    setError("Missing field " .. name .. ". Check model inputs.")
    return nil
  end
  return field.id
end

local function optionalFieldId(names)
  for _, name in ipairs(names) do
    local field = getFieldInfo(name)
    if field and field.id then
      return field.id
    end
  end
  return nil
end

local function optionalSwitchId(names)
  if type(getSwitchIndex) ~= "function" then
    return nil
  end

  for _, name in ipairs(names) do
    local ok, index = pcall(getSwitchIndex, name)
    if ok and index ~= nil then
      return index
    end
  end
  return nil
end

local function trimSwitchNames(switchNames)
  local names = {}
  for _, name in ipairs(switchNames) do
    names[#names + 1] = name
    if type(CHAR_TRIM) == "string" then
      names[#names + 1] = CHAR_TRIM .. name
    end
  end
  return names
end

local function trimInput(valueNames, upNames, downNames)
  return {
    value = optionalFieldId(valueNames),
    up = optionalSwitchId(trimSwitchNames(upNames)),
    down = optionalSwitchId(trimSwitchNames(downNames))
  }
end

local function drawError()
  local text = errMsg or "Setup page error"
  lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
  lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
  if lcd.drawTextLines then
    lcd.drawTextLines(12, 12, widget.zone.w - 24, widget.zone.h - 24, text, colors.primary2)
  else
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, text, CENTER + VCENTER + SMLSIZE + colors.primary2)
  end
end

-- Global variables
local INP_STEP = safeFieldId("input8")      -- Step input for selecting curve point
local INP_FLP_TRIM = trimInput({ "trim-thr", "T3" }, { "Thr+", "Tu" }, { "Thr-", "Td" })
local INP_AIL_TRIM = trimInput({ "trim-ail", "T4" }, { "Ail+", "Ar", "Au" }, { "Ail-", "Al", "Ad" })
local INP_ELE_TRIM = trimInput({ "trim-ele", "T2" }, { "Ele+", "Eu" }, { "Ele-", "Ed" })
local LS_STEP = 11                          -- Set this LS to apply step input
local N = 5 																-- Number of points on the curves
local MAX_Y = 100   												-- Max plot value
local TRIM_DEADBAND = 256
local TRIM_STEP = 5
local CRV_FLP = 4 													-- Index of the  flap curve
local CRV_AIL = 5 													-- Index of the  aileron curve
local CRV_ELE = 13                          -- Index of the elevator compensation curve
local tblFlp 																-- Table with data for the flap curve
local tblAil 																-- Table with data for the aileron curve
local tblEle                                -- Elevator curve, nil on models made before it
local activeP   														-- The point currently being edited
local stepOwned = false											-- Step input has be turned on by this widget
local editingEnabled = false
local trimAxes = {
  { source = INP_FLP_TRIM, curve = CRV_FLP, last = 0 },
  { source = INP_AIL_TRIM, curve = CRV_AIL, last = 0 },
  { source = INP_ELE_TRIM, curve = CRV_ELE, last = 0 }
}

-- CH22 adds BkE x (1 + CV14 / 100) to the elevator, so the bottom of the elevator curve is no
-- compensation. Its last point, brakes off, stays there, so normal flight keeps the elevator trim.
local ELE_NAME = "BrE"

-- While this page holds GV8 at ADJUST_MODE, L50 is on and SF40-SF42 move GV8 instead of the
-- throttle, aileron and elevator trims. The page reads the trim buttons and clears GV8 again.
local GV_ADJUST_MODE = 7
local ADJUST_MODE = -100
local TRIM_THRESHOLD = -50
local LS_TRIMS = 49
local SF_TRIMS = { [39] = "trim-thr", [40] = "trim-ail", [41] = "trim-ele" }
local GVAR_MODE_SOURCE = 1
local adjustModePrevious

local function clamp(value, minimum, maximum)
  return math.min(math.max(value, minimum), maximum)
end

local function resetTrimTracking()
  for _, axis in ipairs(trimAxes) do
    axis.last = 0
  end
end

local function hasTrimCapture()
  local gvar8 = getFieldInfo("gvar8")
  local counter = model.getLogicalSwitch(LS_TRIMS)
  if type(getSwitchIndex) ~= "function" or gvar8 == nil or counter == nil or counter.func ~= LS_FUNC_VNEG or
      counter.v1 ~= gvar8.id or counter.v2 ~= TRIM_THRESHOLD then
    return false
  end

  local switch = getSwitchIndex("L50")
  for index, trimName in pairs(SF_TRIMS) do
    local trim = getFieldInfo(trimName)
    local fn = model.getCustomFunction(index)
    if trim == nil or fn == nil or fn.func ~= FUNC_ADJUST_GVAR or fn.param ~= GV_ADJUST_MODE or
        fn.mode ~= GVAR_MODE_SOURCE or fn.value ~= trim.id or fn.active ~= 1 or fn.switch ~= switch then
      return false
    end
  end
  return true
end

local function adjustModeOn()
  if adjustModePrevious ~= nil then
    return
  end

  -- A count left over from an interrupted session here or on the Motor page would keep a trim on GV8.
  local current = model.getGlobalVariable(GV_ADJUST_MODE, 0)
  if type(current) ~= "number" or math.abs(current) > -TRIM_THRESHOLD then
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

-- The trim clicks GV8 counted are already handled through the trim buttons, so drop them.
local function clearTrimClicks()
  if adjustModePrevious ~= nil and model.getGlobalVariable(GV_ADJUST_MODE, 0) ~= ADJUST_MODE then
    model.setGlobalVariable(GV_ADJUST_MODE, 0, ADJUST_MODE)
  end
end

local function stickySwitchValue(index)
  if type(getStickySwitch) == "function" then
    return getStickySwitch(index)
  elseif type(getLogicalSwitchValue) == "function" then
    return getLogicalSwitchValue(index)
  end
  return false
end

-- Turn off step input (if it was turned on by this widget)
local function stepOff()
  if stepOwned then
    stepOwned = false
    setStickySwitch(LS_STEP, false)
  end
  adjustModeOff()
  editingEnabled = false
  resetTrimTracking()
end

local function stepOn()
  if not stickySwitchValue(LS_STEP) then
    setStickySwitch(LS_STEP, true)
    stepOwned = true
  end
end

local function dismissPrompt()
  if gui then
    gui.dismissPrompt()
  end
end

-- Make sure that we have the right number of points on the curve
local function GetCurve(crvIndex)
		local tbl = soarGlobals.getCurve(crvIndex)

  if not tbl or type(tbl.y) ~= "table" then
    stepOff()
    setError("Missing curve CV" .. crvIndex + 1)
    return nil
  end

  if #tbl.y ~= N then
    stepOff()
    setError("Wrong number of points on curve CV" .. crvIndex + 1)
    return nil
  end

		return tbl
end -- GetCurve()

-- Models made before the elevator curve have no CV14 BrE; the page then leaves the elevator out.
local function GetElevatorCurve()
  local tbl = soarGlobals.getCurve(CRV_ELE)
  if type(tbl) ~= "table" or tbl.name ~= ELE_NAME or type(tbl.y) ~= "table" or #tbl.y ~= N then
    return nil
  end
  return tbl
end

local function curveTable(crvIdx)
  if crvIdx == CRV_FLP then
    return tblFlp
  elseif crvIdx == CRV_AIL then
    return tblAil
  end
  return tblEle
end

local function init()
		tblFlp = GetCurve(CRV_FLP)
  if errMsg then
    return
  end
		tblAil = GetCurve(CRV_AIL)
  if errMsg then
    return
  end
  tblEle = GetElevatorCurve()
end -- init()

beginEditing = function()
  if not tblFlp or not tblAil then
    init()
  end
  if errMsg then
    return
  end
  stepOn()
  if hasTrimCapture() then
    adjustModeOn()
  end
  editingEnabled = true
  resetTrimTracking()
end -- beginEditing()

local function drawCurve(x, y, w, h, yValues)
  -- Background and lines
  gui.drawFilledRectangle(x, y, w + 1, h, colors.primary2)
  gui.drawRectangle(x, y, w + 1, h, COLOR_THEME_SECONDARY2)

  gui.drawLine(x + 0.25 * w, y, x + 0.25 * w, y + h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x + 0.50 * w, y, x + 0.50 * w, y + h, SOLID, COLOR_THEME_SECONDARY2)
  gui.drawLine(x + 0.75 * w, y, x + 0.75 * w, y + h, DOTTED, COLOR_THEME_SECONDARY2)

  gui.drawLine(x, y + 0.1667 * h, x + w, y + 0.1667 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.3333 * h, x + w, y + 0.3333 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.5000 * h, x + w, y + 0.5000 * h, SOLID, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.6667 * h, x + w, y + 0.6667 * h, DOTTED, COLOR_THEME_SECONDARY2)
  gui.drawLine(x, y + 0.8333 * h, x + w, y + 0.8333 * h, DOTTED, COLOR_THEME_SECONDARY2)

  -- And now to the curve
  local xs = { }
  local ys = { }

  for i = 1, N do
    xs[i] = x + math.floor(w * (i - 1) / (N - 1) + 0.5)
    ys[i] = y + math.floor(h * 0.5 * (1 - yValues[i] / MAX_Y) + 0.5)
  end

  for i = 2, N do
    gui.drawLine(xs[i - 1], ys[i - 1], xs[i], ys[i], SOLID, COLOR_THEME_SECONDARY1, 3)
  end

  for i = 1, N do
    if i == activeP then
      gui.drawFilledCircle(xs[i], ys[i], 4, colors.edit)
      gui.drawCircle(xs[i], ys[i], 5, COLOR_THEME_SECONDARY1)
      gui.drawCircle(xs[i], ys[i], 4, COLOR_THEME_SECONDARY1)
    else
      gui.drawFilledCircle(xs[i], ys[i], 2, colors.primary2)
      gui.drawCircle(xs[i], ys[i], 3, COLOR_THEME_SECONDARY1)
      gui.drawCircle(xs[i], ys[i], 2, COLOR_THEME_SECONDARY1)
    end
  end
end -- drawCurve()

-- Adjust a point, either on a curve or output
local function adjustPoint(crvIdx, crvTbl, slider)
  crvTbl.y[activeP] = slider.value
  model.setCurve(crvIdx, crvTbl)
end

local function trimDirection(source)
  if not source then
    return 0
  end

  if type(getSwitchValue) == "function" and source.up and getSwitchValue(source.up) then
    return 1
  elseif type(getSwitchValue) == "function" and source.down and getSwitchValue(source.down) then
    return -1
  elseif not source.value then
    return 0
  end

  local value = getValue(source.value)
  if type(value) ~= "number" then
    return 0
  elseif value > TRIM_DEADBAND then
    return 1
  elseif value < -TRIM_DEADBAND then
    return -1
  end
  return 0
end

local function adjustCurveFromTrim(axis, direction)
  local crvTbl = curveTable(axis.curve)
  if not crvTbl or not crvTbl.y or not activeP or (axis.curve == CRV_ELE and activeP == N) then
    return
  end

  crvTbl.y[activeP] = clamp(crvTbl.y[activeP] + direction * TRIM_STEP, -MAX_Y, MAX_Y)
  model.setCurve(axis.curve, crvTbl)
end

local function handleTrimAdjustments()
  if not editingEnabled or not activeP then
    return
  end

  for _, axis in ipairs(trimAxes) do
    local direction = trimDirection(axis.source)
    if direction ~= 0 and axis.last == 0 then
      adjustCurveFromTrim(axis, direction)
    end
    axis.last = direction
  end
end

-- Reset curves to defaults
local function reset()
	local ys = { -100, -50, 0, 25, 50 }
	for i, y in ipairs(ys) do
		tblFlp.y[i] = y
	end
	model.setCurve(CRV_FLP, tblFlp)

	ys = { 50, 50, 50, 25, 0 }
	for i, y in ipairs(ys) do
		tblAil.y[i] = y
	end
	model.setCurve(CRV_AIL, tblAil)

  -- The elevator follows the default flap travel: BkE at three quarters brake, 1.5 x BkE at full.
  if tblEle then
    ys = { 50, 0, -50, -75, -100 }
    for i, y in ipairs(ys) do
      tblEle.y[i] = y
    end
    model.setCurve(CRV_ELE, tblEle)
  end
  resetTrimTracking()
end
-------------------------------- Setup GUI --------------------------------

local function setup_gui()
  libGUI.flags =  0
  gui = libGUI.newGUI()
  gui.showPrompt(warningPrompt)

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

		-- Curves
    drawCurve(plotX(1), TOP, WIDTH, HEIGHT, tblFlp.y)
		lcd.drawText(plotX(1) + 2, TOP, "Flaps", SMLSIZE + colors.primary1)

    drawCurve(plotX(2), TOP, WIDTH, HEIGHT, tblAil.y)
		lcd.drawText(plotX(2) + 2, TOP, "Aileron", SMLSIZE + colors.primary1)

    if tblEle then
      drawCurve(plotX(3), TOP, WIDTH, HEIGHT, tblEle.y)
    else
      gui.drawFilledRectangle(plotX(3), TOP, WIDTH + 1, HEIGHT, colors.primary2)
      gui.drawRectangle(plotX(3), TOP, WIDTH + 1, HEIGHT, COLOR_THEME_SECONDARY2)
      lcd.drawText(plotX(3) + WIDTH / 2, TOP + HEIGHT / 2, "N/A", CENTER + VCENTER + colors.primary1)
    end
    lcd.drawText(plotX(3) + 2, TOP, "Elevator", SMLSIZE + colors.primary1)

    -- Help text
    local txt = "The throttle stick selects a point.\n" ..
                "Trims: Thr flaps, Ail ailerons, Ele elevator.\n" ..
                "The sliders also work."
    lcd.drawTextLines(MARGIN, TEXT_Y, BUTTON_X - MARGIN - GAP, LCD_H - TEXT_Y, txt, colors.primary1)
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

	-- Sliders, each in the gap left of its curve
	local flpSlider = gui.verticalSlider(plotX(1) - DIST_X / 2, TOP, HEIGHT, 0, -100, 100, 1, function(slider) adjustPoint(CRV_FLP, tblFlp, slider) end)

  function flpSlider.update()
    flpSlider.value = tblFlp.y[activeP]
  end

  local ailSlider = gui.verticalSlider(plotX(2) - DIST_X / 2, TOP, HEIGHT, 0, -100, 100, 1, function(slider) adjustPoint(CRV_AIL, tblAil, slider) end)

  function ailSlider.update()
    ailSlider.value = tblAil.y[activeP]
  end

  local eleSlider = gui.verticalSlider(plotX(3) - DIST_X / 2, TOP, HEIGHT, -100, -100, 100, 1, function(slider) adjustPoint(CRV_ELE, tblEle, slider) end)

  -- The brakes-off point keeps the elevator where it is, so it has no slider.
  function eleSlider.update()
    eleSlider.hidden = not tblEle or activeP == N
    if not eleSlider.hidden then
      eleSlider.value = tblEle.y[activeP]
    end
  end

  gui.button(BUTTON_X, BUTTON_Y, BUTTON_W, BUTTON_H, "Reset", reset)
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  if (gui ~= nil) then
    dismissPrompt()
    stepOff()
    gui = nil
  end
end -- background()

function widget.refresh(event, touchState)
  if not event then
    widget.background()
    if errMsg then
      drawError()
      return
    end
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif errMsg then
    drawError()
    return
  elseif gui == nil then
    setup_gui()
    init()
    if errMsg then
      drawError()
    end
    return
  end

  activeP = math.floor((N - 1) / 2048 * (getValue(INP_STEP) + 1024) + 1.5)
  handleTrimAdjustments()
  clearTrimClicks()
  gui.run(event, touchState)
end -- refresh(...)
