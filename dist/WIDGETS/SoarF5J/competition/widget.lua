---------------------------------------------------------------------------
-- SoarF5J competition placeholder widget                                --
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

local widget = ...

function widget.refresh(event, touchState)
  lcd.drawTextLines(
    0,
    0,
    widget.zone.w,
    widget.zone.h,
    "F5J competition page pending implementation",
    COLOR_THEME_PRIMARY2
  )
end
