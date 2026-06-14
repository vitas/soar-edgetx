local required_sources = {
  "src/SoarF5J/setup/switches.lua",
  "src/SoarF5J/setup/mixes.lua",
  "src/SoarF5J/setup/outputs.lua",
  "src/SoarF5J/setup/wing_alignment.lua",
  "src/SoarF5J/setup/brake_curves.lua",
  "src/SoarF5J/setup/aileron_camber.lua",
  "src/SoarF5J/lib/safety.lua"
}

local setup_sources = {
  "src/SoarF5J/setup/switches.lua",
  "src/SoarF5J/setup/mixes.lua",
  "src/SoarF5J/setup/outputs.lua",
  "src/SoarF5J/setup/wing_alignment.lua",
  "src/SoarF5J/setup/brake_curves.lua",
  "src/SoarF5J/setup/aileron_camber.lua"
}

local forbidden_class_labels = {
  "F" .. "3K",
  "F" .. "3J",
  "F" .. "5K",
  "F" .. "3RES",
  "F" .. "3R",
  "B" .. "W"
}

local forbidden_review_patterns = {
  "widget" .. ".options" .. ".Type",
  "model" .. "Type",
  "Data " .. "logging",
  "LO" .. "GS",
  "Sco" .. "res",
  "F" .. "3K",
  "F" .. "3J",
  "F" .. "5K",
  "F" .. "3RES",
  "F" .. "3R",
  "B" .. "W",
  "io" .. ".open",
  "io" .. ".write"
}

local function file_exists(path)
  local previous = io.input()
  local ok, file = pcall(io.input, path)
  io.input(previous)
  if ok and file then file:close() end
  return ok
end

local function read_file(path)
  local previous = io.input()
  local file = assert(io.input(path))
  local content = io.read("*a")
  io.input(previous)
  file:close()
  return content
end

local function dist_path(source_path)
  return source_path:gsub("^src/SoarF5J/", "dist/SDCARD/WIDGETS/SoarF5J/")
end

test("required setup source files exist", function()
  for _, path in ipairs(required_sources) do
    assert(file_exists(path), "missing required source file: " .. path)
  end
end)

test("packaged setup files exist and match sources", function()
  for _, source_path in ipairs(required_sources) do
    local packaged_path = dist_path(source_path)
    assert(file_exists(packaged_path), "missing packaged file: " .. packaged_path)
    assert_equal(read_file(packaged_path), read_file(source_path), packaged_path)
  end
end)

test("setup pages do not include non-F5J class labels", function()
  for _, path in ipairs(setup_sources) do
    local content = read_file(path)
    for _, label in ipairs(forbidden_class_labels) do
      assert(not content:find(label, 1, true), path .. " contains " .. label)
    end
  end
end)

test("review forbidden patterns are absent from setup tests and sources", function()
  local paths = {
    "tests/test_setup_pages.lua",
    "src/SoarF5J/lib/safety.lua"
  }
  for _, path in ipairs(setup_sources) do
    paths[#paths + 1] = path
  end

  for _, path in ipairs(paths) do
    local content = read_file(path)
    for _, pattern in ipairs(forbidden_review_patterns) do
      assert(not content:find(pattern, 1, true), path .. " contains review-forbidden pattern")
    end
  end
end)

test("aileron camber page includes SoarOTX adjustment behavior", function()
  local content = read_file("src/SoarF5J/setup/aileron_camber.lua")

  assert(content:find("Aileron and camber", 1, true), "missing aileron/camber title")
  assert(content:find("Aileron trim", 1, true), "missing aileron trim label")
  assert(content:find("Rudder trim", 1, true), "missing rudder trim label")
  assert(content:find("Elevator trim", 1, true), "missing elevator trim label")
  assert(content:find("Throttle trim", 1, true), "missing throttle trim label")
  assert(content:find("GV_AIL_TO_FLAP = 1", 1, true), "missing aileron-to-flap GV index")
  assert(content:find("GV_CAMBER_TO_AIL = 6", 1, true), "missing camber-to-aileron GV index")
  assert(content:find("GV_THERMAL_CAMBER = 9", 1, true), "missing thermal camber GV index")
  assert(content:find("ADJUST_MODE = 3", 1, true), "missing adjustment mode")
end)

test("battery setup remains on mixes page only", function()
  local content = read_file("src/SoarF5J/setup/mixes.lua")

  assert(content:find("getParameter", 1, true), "missing threshold read")
  assert(content:find("setParameter", 1, true), "missing threshold write")
  assert(content:find("batteryParameter", 1, true), "missing battery parameter index")
  assert(content:find("Battery warning level", 1, true), "missing threshold label")
  assert(not file_exists("src/SoarF5J/setup/battery.lua"), "battery setup page should be removed")
end)

test("mixes page leaves thermal camber to aileron camber setup", function()
  local content = read_file("src/SoarF5J/setup/mixes.lua")

  assert(not content:find("Thermal camber", 1, true), "thermal camber belongs on aileron/camber page")
  assert(not content:find('{ "Thermal camber", 9, 0, 100 }', 1, true), "GV10 CbX should not be on mixes page")
end)

test("safety helper loads without EdgeTX globals", function()
  local safety = assert(loadfile("src/SoarF5J/lib/safety.lua"))()

  assert_equal(type(safety), "table", "safety")
  assert_equal(type(safety.motor_warning_title), "string", "motor_warning_title")
  assert_equal(type(safety.motor_warning_text), "string", "motor_warning_text")
  assert_equal(type(safety.drawMotorDisabledWarning), "function", "drawMotorDisabledWarning")
end)

test("motor warning helper draws warning copy through GUI", function()
  local safety = assert(loadfile("src/SoarF5J/lib/safety.lua"))()
  local calls = {}
  local gui = {
    drawText = function(...)
      calls[#calls + 1] = { method = "drawText", args = { ... } }
    end,
    drawTextLines = function(...)
      calls[#calls + 1] = { method = "drawTextLines", args = { ... } }
    end,
    drawFilledRectangle = function(...)
      calls[#calls + 1] = { method = "drawFilledRectangle", args = { ... } }
    end,
    drawRectangle = function(...)
      calls[#calls + 1] = { method = "drawRectangle", args = { ... } }
    end
  }

  safety.drawMotorDisabledWarning(gui)

  local drawn_text = {}
  for _, call in ipairs(calls) do
    for _, arg in ipairs(call.args) do
      if type(arg) == "string" then
        drawn_text[#drawn_text + 1] = arg
      end
    end
  end
  local rendered = table.concat(drawn_text, "\n")

  assert(#calls > 0, "expected GUI draw calls")
  assert(rendered:find(safety.motor_warning_title, 1, true), "missing warning title")
  assert(rendered:find(safety.motor_warning_text, 1, true), "missing warning text")
end)
