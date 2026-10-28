---------------------------------------------------------------------------
-- SoarF5J aileron and camber setup, loadable component                  --
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
local gui
local colors =  libGUI.colors
local title =   "Aileron/camber"
local safety =  loadScript(soarGlobals.path .. "lib/safety.lua")()
local warningPrompt = libGUI.newGUI()
local adjustModePrevious
local beginEditing

-- Screen drawing constants
local HEADER =    40
local MARGIN =    20
local LINE =      28
local COL_CODE =  math.floor(0.42 * LCD_W)
local COL_TRIM =  math.floor(0.54 * LCD_W)

-- Setup warning prompt
do
  local PROMPT_W = 300
  local PROMPT_H = 172
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

  local buttonClose = warningPrompt.custom({ }, PROMPT_W - 30, 10, 20, 20)

  function buttonClose.draw(focused)
    warningPrompt.drawRectangle(PROMPT_W - 30, 10, 20, 20, colors.primary2)
    warningPrompt.drawText(PROMPT_W - 20, 20, "X", MIDSIZE + CENTER + VCENTER + colors.primary2)
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

-- Global variables
local GV_AIL = 0 -- Aileron travel
local GV_AIL_TO_FLAP = 1 -- Aileron -> flap
local GV_CAMBER_TO_AIL = 6 -- Camber -> aileron
local GV_THERMAL_CAMBER = 9 -- Thermal camber amount
local GV_ADJUST_MODE = 7
local ADJUST_MODE = 3

-- Values that the trim buttons adjust in ADJUST_MODE
local rows = {
  { "Aileron travel", "Ail", "Aileron trim", GV_AIL },
  { "Aileron -> flap", "AiF", "Rudder trim", GV_AIL_TO_FLAP },
  { "Camber -> aileron", "CbA", "Elevator trim", GV_CAMBER_TO_AIL },
  { "Thermal camber", "CbX", "Throttle trim", GV_THERMAL_CAMBER }
}

local function getGV(gv, phase)
  local value = model.getGlobalVariable(gv, phase)
  if type(value) == "number" then
    return value
  end
  return nil
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

local function dismissPrompt()
  if gui then
    gui.dismissPrompt()
  end
end

beginEditing = function()
  adjustModeOn()
end -- beginEditing()

local function drawAdjustmentRows()
  for i, row in ipairs(rows) do
    local y = HEADER + LINE * (i - 1)
    if i % 2 == 0 then
      lcd.drawFilledRectangle(0, y, LCD_W, LINE, COLOR_THEME_SECONDARY2)
    end

    y = y + LINE / 2
    lcd.drawText(MARGIN, y, row[1], VCENTER + colors.primary1)
    lcd.drawText(COL_CODE, y, row[2], VCENTER + colors.primary1)
    lcd.drawText(COL_TRIM, y, row[3], VCENTER + colors.primary1)
    local value = getGV(row[4], 0)
    if value == nil then
      lcd.drawText(LCD_W - MARGIN, y, "N/A", RIGHT + VCENTER + colors.primary1)
    else
      lcd.drawNumber(LCD_W - MARGIN, y, value, RIGHT + VCENTER + colors.primary1)
    end
  end
end

-------------------------------- Setup GUI --------------------------------

local function setup_gui()
  gui = libGUI.newGUI()
  gui.showPrompt(warningPrompt)

  function gui.fullScreenRefresh()
    lcd.clear(COLOR_THEME_SECONDARY3)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

    drawAdjustmentRows()

    -- Help text
    local txt = "Trim buttons adjust these values while this page is open."
    local helpY = HEADER + #rows * LINE + 25
    lcd.drawTextLines(MARGIN, helpY, LCD_W - 2 * MARGIN, LCD_H - helpY - MARGIN, txt, colors.primary1)
  end

  -- Close button
  local buttonClose = gui.custom({ }, LCD_W - 34, 6, 28, 28)

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
end -- Setup GUI

-------------------- Background and Refresh functions ---------------------

function widget.background()
  dismissPrompt()
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

  gui.run(event, touchState)
end -- refresh(...)
