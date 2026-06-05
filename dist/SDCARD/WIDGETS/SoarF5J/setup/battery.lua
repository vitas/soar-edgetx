---------------------------------------------------------------------------
-- SoarF5J battery setup, loadable component                             --
--                                                                       --
-- Derived from SoarETX by Jesper Frickmann and EdgeTX contributors.     --
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
local title = "Battery"

local HEADER = 40
local MARGIN = 20
local LINE = 34
local LABEL_W = 190
local VALUE_W = 90
local TOP = HEADER + MARGIN

local function batteryThresholdValue()
  local value = soarGlobals.getParameter(soarGlobals.batteryParameter)
  if type(value) ~= "number" then
    value = 0
  end
  return math.max(0, math.min(200, value + 100))
end

local function currentBatteryText()
  if soarGlobals.battery and soarGlobals.battery > 0 then
    return string.format("%1.1f V", soarGlobals.battery)
  end
  return "--.- V"
end

local function thresholdValue()
  return batteryThresholdValue()
end

local function thresholdText()
  return string.format("%1.1f V", 0.1 * thresholdValue())
end

local function drawTile()
  local flags = CENTER + VCENTER + MIDSIZE
  if soarGlobals.battery and soarGlobals.battery > 0 then
    flags = flags + COLOR_THEME_PRIMARY2
  else
    flags = flags + COLOR_THEME_DISABLED
  end

  lcd.drawText(widget.zone.w / 2, widget.zone.h / 2 - 12, currentBatteryText(), flags)
  lcd.drawText(widget.zone.w / 2, widget.zone.h / 2 + 18, "Warn " .. thresholdText(), CENTER + VCENTER + SMLSIZE + colors.primary2)
end

local function init()
  libGUI.flags = 0
  gui = libGUI.newGUI()

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    -- Row background
    for i = 0, 2 do
      local y = TOP - 4 + i * LINE
      if i % 2 == 1 then
        lcd.drawFilledRectangle(0, y, LCD_W, LINE, COLOR_THEME_SECONDARY2)
      else
        lcd.drawFilledRectangle(0, y, LCD_W, LINE, COLOR_THEME_SECONDARY3)
      end
    end

    lcd.drawText(MARGIN, TOP, "Current battery", MIDSIZE + colors.primary1)
    lcd.drawText(MARGIN + LABEL_W + VALUE_W, TOP, currentBatteryText(), RIGHT + MIDSIZE + colors.primary1)
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

  local y = TOP + LINE
  gui.label(MARGIN, y, LABEL_W, LINE - 4, "Battery warning level (V)")

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

  local warning = gui.number(MARGIN + LABEL_W, y, VALUE_W, LINE - 4, thresholdValue(), changeBattery, RIGHT + PREC1 + libGUI.flags)

  function warning.update()
    warning.value = thresholdValue()
  end
end -- init()

function widget.background()
  gui = nil
end -- background()

function widget.refresh(event, touchState)
  if not event then
    gui = nil
    drawTile()
    return
  elseif gui == nil then
    init()
    return
  end

  gui.run(event, touchState)
end -- refresh(...)
