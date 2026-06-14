---------------------------------------------------------------------------
-- SoarF5J setup safety helpers                                          --
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

local M = {
  motor_warning_title = "W A R N I N G",
  motor_warning_text = "Please disable the motor!\n\n" ..
                       "Sudden spikes may occur when channels are moved.\n\n" ..
                       "Press ENTER to proceed."
}

local function global(name)
  return _G and _G[name] or 0
end

local function gui_color(gui, key, fallback)
  if gui and gui.colors and gui.colors[key] then
    return gui.colors[key]
  end
  return global(fallback)
end

function M.drawMotorDisabledWarning(gui)
  local promptW = gui.motor_warning_width or 300
  local promptH = gui.motor_warning_height or 172
  local header = gui.motor_warning_header or 40
  local margin = gui.motor_warning_margin or 10
  local textW = promptW - 2 * margin
  local textH = promptH - 2 * margin
  local titleFlags = global("DBLSIZE") + global("VCENTER") + gui_color(gui, "primary2", "COLOR_THEME_PRIMARY2")

  gui.drawFilledRectangle(0, 0, promptW, header, global("COLOR_THEME_SECONDARY1"))
  gui.drawFilledRectangle(0, header, promptW, promptH - header, gui_color(gui, "primary2", "COLOR_THEME_PRIMARY2"))
  gui.drawRectangle(0, 0, promptW, promptH, gui_color(gui, "primary1", "COLOR_THEME_PRIMARY1"), 2)
  gui.drawText(margin, header / 2, M.motor_warning_title, titleFlags)
  gui.drawTextLines(margin, header + margin, textW, textH, M.motor_warning_text)
end

return M
