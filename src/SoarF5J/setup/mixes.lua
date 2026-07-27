---------------------------------------------------------------------------
-- SoarF5J mix and battery warning setup, loadable component             --
--                                                                       --
-- Derived from SoarETX by Jesper Frickmann, Frankie Arzu, and EdgeTX    --
-- contributors.                                                         --
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
local gui = nil
local colors = libGUI.colors
local title = "Mixes & Battery"
local fm = getFlightMode()
local adjustModePrevious

-- Screen drawing constants
local LCD_W2 = LCD_W / 2
local HEADER = 40
local LINE = 28
local HEIGHT = LINE - 4
local MARGIN = 15
local W1 = 170
local W2 = LCD_W2 - 2 * MARGIN - W1

local mixes = {
  { "Aileron -> Rudder", 2, -100, 100 },
  { "Aileron Travel", 0, -100, 100 },
  { "Elevator Travel", 10, -100, 100 },
  { "Aileron -> Flap", 1, -100, 100 },
  { "Aileron -> Elevator", 11, -100, 100 },
  { "Aileron Differential", 3, -100, 100 },
  { "Flap Differential", 12, -100, 100 },
  { "Brake -> Elevator", 4, 0, 100 },
  { "Snap - flap", 5, -50, 0 }
}

local GV_ADJUST_MODE = 7
local ADJUST_MODE = 4

local function getGV(gv, phase)
  local value = model.getGlobalVariable(gv, phase)
  if type(value) == "number" then
    return value
  end
  return nil
end

local function batteryThresholdValue()
  local value = soarGlobals.getParameter(soarGlobals.batteryParameter)
  if type(value) ~= "number" then
    value = 0
  end
  return math.max(0, math.min(200, value + 100))
end

local function adjustModeOn()
  local current = model.getGlobalVariable(GV_ADJUST_MODE, 0)
  if adjustModePrevious == nil and current ~= ADJUST_MODE then
    adjustModePrevious = current
    model.setGlobalVariable(GV_ADJUST_MODE, 0, ADJUST_MODE)
  end
end

local function adjustModeOff()
  if adjustModePrevious ~= nil then
    model.setGlobalVariable(GV_ADJUST_MODE, 0, adjustModePrevious)
    adjustModePrevious = nil
  end
end

-------------------------------- Setup GUI --------------------------------

local function init()
  libGUI.flags = 0
  gui = libGUI.newGUI()
  adjustModeOn()

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Flight mode
    local fmIdx, fmStr = getFlightMode()
    lcd.drawText(LCD_W - HEADER, HEADER / 2, "FM" .. fmIdx .. ":" .. fmStr, RIGHT + VCENTER + MIDSIZE + colors.primary2)

    -- Line stripes
    local rows = math.ceil((#mixes + 1) / 2)
    for i = 1, rows - 1, 2 do
      lcd.drawFilledRectangle(0, HEADER + LINE * i, LCD_W, LINE, COLOR_THEME_SECONDARY2)
    end

    local bottom = HEADER + rows * LINE
    lcd.drawLine(LCD_W2, HEADER, LCD_W2, bottom, SOLID, colors.primary1)

    -- Help text
    local txt = "Some variables can be adjusted individually for each flight mode.\n" ..
                "Select the flight mode before adjusting.\n" ..
                "Trim buttons adjust active mix values while this page is open."
    local helpY = bottom + 25
    lcd.drawTextLines(MARGIN, helpY, LCD_W - 2 * MARGIN, LCD_H - helpY - MARGIN, txt, colors.primary1)
  end

  -- Close button
  local buttonClose = gui.custom({}, LCD_W - 34, 6, 28, 28)

  function buttonClose.draw(focused)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
    lcd.drawText(LCD_W - 20, 20, "X", CENTER + VCENTER + MIDSIZE + colors.primary2)

    if focused then
      buttonClose.drawFocus()
    end
  end

  function buttonClose.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      lcd.exitFullScreen()
    end
  end

  -- Grid for items
  local x, y = MARGIN, HEADER + 2

  local function move()
    if x == MARGIN then
      x = x + LCD_W2
    else
      x = MARGIN
      y = y + LINE
    end
  end

  -- Add label and number element for a GV.
  local function addGV(label, gv, min, max)
    gui.label(x, y, W1, HEIGHT, label)

    local function changeGV(delta, number)
      local current = type(number.value) == "number" and number.value or getGV(gv, fm)
      if current == nil then
        return "N/A"
      end
      local value = current + delta
      value = math.max(value, min)
      value = math.min(value, max)
      model.setGlobalVariable(gv, fm, value)
      return value
    end

    local number = gui.number(x + W1, y, W2, HEIGHT, 0, changeGV, RIGHT + libGUI.flags, min, max)

    function number.update()
      local value = getGV(gv, fm)
      number.disabled = value == nil
      number.value = value or "N/A"
    end

    move()
  end

  for _, mix in ipairs(mixes) do
    addGV(mix[1], mix[2], mix[3], mix[4])
  end

  -- Add battery warning
  gui.label(x, y, W1, HEIGHT, "Battery warning level (V)")

  local function changeBattery(delta, bat)
    local current = bat.value
    if type(current) ~= "number" then
      current = batteryThresholdValue()
    end
    local value = current + delta
    value = math.max(0, value)
    value = math.min(200, value)
    soarGlobals.setParameter(soarGlobals.batteryParameter, value - 100)
    return value
  end

  gui.number(x + W1, y, W2, HEIGHT, batteryThresholdValue(), changeBattery, RIGHT + PREC1 + libGUI.flags)
end -- init()

function widget.background()
  adjustModeOff()
  gui = nil
end -- background()

function widget.refresh(event, touchState)
  if not event then
    gui = nil
    lcd.drawFilledRectangle(6, 6, widget.zone.w - 12, widget.zone.h - 12, colors.focus)
    lcd.drawRectangle(7, 7, widget.zone.w - 14, widget.zone.h - 14, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + MIDSIZE + colors.primary2)
    return
  elseif gui == nil then
    init()
    return
  end

  fm = getFlightMode()
  gui.run(event, touchState)
end -- refresh(...)
