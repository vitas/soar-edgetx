---------------------------------------------------------------------------
-- SoarF5J widget                                                        --
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

local pageFiles = {
  "competition/widget",
  "setup/switches",
  "setup/mixes",
  "setup/outputs",
  "setup/wing_alignment",
  "setup/brake_curves",
  "setup/aileron_camber"
}

local options = {
  { "Page", VALUE, 1, 1, #pageFiles }
}

local soarGlobals

-- Battery - kept in main because EdgeTX may not call background() on topbar widgets.
local rxBatNxtWarn = 0
local rxBatNxtCheck = 0

local function rxBatCheck()
  local now = getTime()

  if now < rxBatNxtCheck then
    return
  end

  rxBatNxtCheck = now + 100

  local rxBatSrc = soarGlobals.edgetx.findBatterySource()
  local battery = soarGlobals.edgetx.readScalarValue(rxBatSrc)
  if battery then
    soarGlobals.battery = battery
  end

  -- Warn about low receiver battery.
  local rxBatMin = 0.1 * (soarGlobals.getParameter(soarGlobals.batteryParameter) + 100)
  if now > rxBatNxtWarn and soarGlobals.battery > 0 and soarGlobals.battery < rxBatMin then
    playHaptic(200, 0, 1)
    playFile("lowbat.wav")
    playNumber(10 * soarGlobals.battery + 0.5, 1, PREC1)
    rxBatNxtWarn = now + 2000
  end
end

local function resolvePage(widgetOptions)
  local page = tonumber(widgetOptions.Page)

  if page and pageFiles[page] then
    return page
  end

  return 1
end

-- Load a Lua component dynamically based on option values.
local function Load(widget)
  local page = resolvePage(widget.options)
  local fileName = pageFiles[page]
  widget.errMsg = nil
  widget.page = page
  widget.fileName = fileName

  local chunk, errMsg = loadScript(soarGlobals.path .. fileName .. ".lua")
  if errMsg then
    widget.errMsg = errMsg
  else
    local ok, err = pcall(chunk, widget, soarGlobals)
    if not ok then
      widget.errMsg = err
    elseif type(widget.refresh) ~= "function" then
      widget.errMsg = fileName .. ".lua did not define widget.refresh"
    end
  end
end

-- Initialize the first time this widget is instantiated.
local function init()
  soarGlobals = {
    path = "/WIDGETS/SoarF5J/",
    battery = 0,
    batteryParameter = 1
  }
  soarGlobals.libGUI = loadScript(soarGlobals.path .. "lib/gui.lua")()
  soarGlobals.edgetx = loadScript(soarGlobals.path .. "lib/edgetx.lua")()
  soarGlobals.getCurve = soarGlobals.edgetx.getCurve

  -- Functions to handle persistent model parameters stored in curve 32.
  local parameterCurve = soarGlobals.getCurve(31)

  if not parameterCurve then
    error("Curve #32 is missing! It is used to store persistent model parameters for Lua.")
  end

  function soarGlobals.getParameter(idx)
    return parameterCurve.y[idx]
  end

  function soarGlobals.setParameter(idx, value)
    parameterCurve.y[idx] = value
    model.setCurve(31, parameterCurve)
  end
end

local function create(zone, options)
  if not soarGlobals then
    init()
  end

  local widget = {
    zone = zone,
    options = options
  }
  Load(widget)
  return widget
end

local function update(widget, options)
  if resolvePage(options) ~= widget.page then
    local zone = widget.zone

    -- Erase all fields in widget.
    local keys = {}
    for key in pairs(widget) do
      keys[#keys + 1] = key
    end
    for i, key in ipairs(keys) do
      widget[key] = nil
    end

    widget.zone = zone
    widget.options = options
    Load(widget)
  end
end

local function refresh(widget, event, touchState)
  rxBatCheck()

  if widget.errMsg then
    lcd.drawTextLines(0, 0, widget.zone.w, widget.zone.h, widget.errMsg .. "\nPlease check widget settings!", COLOR_THEME_WARNING)
  else
    widget.refresh(event, touchState)
  end
end

local function background(widget)
  rxBatCheck()

  if type(widget.background) == "function" then
    widget.background()
  end
end

return {
  name = "SoarF5J",
  create = create,
  refresh = refresh,
  options = options,
  update = update,
  background = background
}
