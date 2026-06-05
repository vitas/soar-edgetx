---------------------------------------------------------------------------
-- SoarF5J EdgeTX helper functions                                       --
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

local M = {}

function M.getCurve(index)
  local curve = model.getCurve(index)
  if not curve then return nil end
  if curve.y and #curve.y == 5 then return curve end

  if curve.y and #curve.y == 4 then
    local fixed = { y = {}, smooth = 1, name = curve.name }
    for i = 1, 5 do
      fixed.y[i] = curve.y[i - 1]
    end
    return fixed
  end

  return curve
end

function M.findBatterySource()
  return getFieldInfo("Cels") or getFieldInfo("RxBt") or getFieldInfo("A1") or getFieldInfo("A2")
end

function M.readScalarValue(source)
  if not source then return nil end

  local value = getValue(source.id)
  if type(value) == "table" then
    local min = value[1]
    for i = 2, #value do
      min = math.min(min, value[i])
    end
    return min
  end
  return value
end

function M.resetAltitude()
  for i = 0, 31 do
    local sensor = model.getSensor(i)
    if sensor and sensor.name == "Alt" then
      model.resetSensor(i)
      return true
    end
  end
  return false
end

return M
