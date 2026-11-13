-- The GX10 F3K template carries the GX12 F3K setup to the RadioMaster GX10 color radio. Color
-- EdgeTX runs no telemetry scripts, so logical switches time the flights and the working window
-- from the launch switch, and built-in Timer widgets show them.
local TEMPLATE = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx/gx10-F3K.yml"

-- Voice prompts the template plays from the stock EdgeTX voice pack; the rest ship in SOUNDS/en.
local STOCK_PROMPTS = { flapup = true }

local function read_file(path)
  local file = assert(io.open(path, "r"))
  local content = file:read("a")
  file:close()
  return content
end

local function command_lines(cmd)
  local pipe = assert(io.popen(cmd))
  local out = {}
  for line in pipe:lines() do
    out[#out + 1] = line
  end
  assert(pipe:close(), "command failed: " .. cmd)
  return out
end

-- Returns the body of a top-level YAML section, up to the next top-level key.
local function section(content, name)
  local start = content:find("\n" .. name .. ":\n", 1, true)
  assert(start, TEMPLATE .. " has no section " .. name)
  local body = content:sub(start + #name + 3)
  local stop = body:find("\n%S")
  return stop and body:sub(1, stop) or body
end

-- Parses the "  N:" entries of a section whose fields are "    key: value" lines.
local function entries(content, name)
  local list = {}
  local current
  for line in section(content, name):gmatch("[^\n]+") do
    local index = line:match("^  (%d+):%s*$")
    if index then
      current = {}
      list[tonumber(index)] = current
    else
      local key, value = line:match("^    ([%w_]+): ?(.*)$")
      if current and key then
        current[key] = (value:gsub('^"(.*)"$', "%1"))
      end
    end
  end
  return list
end

test("GX10 F3K template is a color model without telemetry scripts", function()
  local content = read_file(TEMPLATE)
  assert(content:find("\nheader:\n  name: GX10 F3K\n", 1, true), TEMPLATE .. " is not named GX10 F3K")

  -- The score keeper and the setup menu are B&W telemetry scripts, and GV9 was their timer state.
  for _, word in ipairs({ "PLAY_SCRIPT", "\nscreens:", "JF3Ksk", "JFXKcf", "JFutil", "gv(8)", "name: Tmr" }) do
    assert(not content:find(word, 1, true), TEMPLATE .. " still has " .. word)
  end
end)

test("GX10 F3K times the flight in the window and counts the window down by voice", function()
  local timers = entries(read_file(TEMPLATE), "timers")
  local flight, window = timers[0], timers[1]

  assert_equal(flight.name, "Fli", "timer 1 name")
  assert_equal(flight.swtch, "L32", "flight timer switch")
  assert_equal(flight.mode, "ON", "flight timer mode")
  assert_equal(flight.start, "0", "flight timer start")
  assert_equal(flight.minuteBeep, "0", "flight timer minute calls")
  assert_equal(flight.countdownBeep, "0", "flight timer countdown")

  assert_equal(window.name, "Win", "timer 2 name")
  assert_equal(window.swtch, "L16", "window timer switch")
  assert_equal(window.mode, "ON", "window timer mode")
  assert_equal(window.start, "600", "window length in seconds")
  assert_equal(window.minuteBeep, "1", "window minute calls")
  assert_equal(window.countdownBeep, "2", "window voice countdown")
  assert_equal(window.countdownStart, "-1", "window countdown from 10 seconds")
end)

test("GX10 F3K logical switches time the flights from the launch switch", function()
  local ls = entries(read_file(TEMPLATE), "logicalSw")
  -- { index, function, definition, delay, duration }. L10 comes before L17, so the catch check
  -- reads whether the glider was flying before this pass updates L17.
  local expected = {
    { 6, "FUNC_OR", "SG2,L9", "0", "0" },        -- L7: launch switch, a tap held 0.3 s by L9
    { 9, "FUNC_AND", "L7,L17", "0", "1" },       -- L10: launch switch pulled in flight = catch
    { 14, "FUNC_STICKY", "L10,!L7", "0", "0" },  -- L15: the catch, until the switch is let go
    { 15, "FUNC_STICKY", "L32,L28", "0", "0" },  -- L16: window running
    { 16, "FUNC_STICKY", "L23,L7", "0", "0" },   -- L17: flying
    { 17, "FUNC_AND", "L7,!L15", "1", "0" },     -- L18: launch hold, after L15 can mark a catch
    { 22, "FUNC_EDGE", "L18,0,-", "0", "1" },    -- L23: launch released
    { 27, "FUNC_VNEG", "Tmr2,1", "0", "0" },     -- L28: window over
    { 31, "FUNC_AND", "L17,!L28", "0", "0" },    -- L32: flying in the window
    { 40, "FUNC_AND", "L18,!L16", "0", "0" },    -- L41: a launch while no window runs
  }

  for _, want in ipairs(expected) do
    local label = "L" .. tostring(want[1] + 1)
    local got = ls[want[1]]
    assert(got, TEMPLATE .. " has no " .. label)
    assert_equal(got.func, want[2], label .. " function")
    assert_equal(got.def, want[3], label .. " definition")
    assert_equal(got.delay, want[4], label .. " delay")
    assert_equal(got.duration, want[5], label .. " duration")
    assert_equal(got.andsw, "NONE", label .. " AND switch")
  end

  -- L1, L5 and L6 were the score keeper's altitude and voice switches on SE and SB.
  for _, index in ipairs({ 0, 4, 5 }) do
    assert(ls[index] == nil, "L" .. tostring(index + 1) .. " should be free")
  end
end)

test("GX10 F3K resets the flight timer at a launch and the window when none runs", function()
  local resets = {}
  local count = 0
  for _, fn in pairs(entries(read_file(TEMPLATE), "customFn")) do
    if fn.func == "RESET" then
      resets[fn.swtch] = fn.def
      count = count + 1
    end
  end

  assert_equal(resets.L18, "Tmr1,1", "launch hold resets the flight timer")
  assert_equal(resets.L41, "Tmr2,1", "a launch with no window running resets the window")
  assert_equal(count, 2, "reset functions")
end)

test("GX10 F3K uses only the GX10 switches in positions they have", function()
  local content = read_file(TEMPLATE)
  local positions = { SA = 2, SB = 3, SC = 3, SD = 2, SE = 3, SF = 3, SG = 2, SH = 2 }
  local found = 0

  for switch, position in content:gmatch("%f[%w](S[A-Z])([0-2])%f[%W]") do
    found = found + 1
    local count = positions[switch]
    assert(count, TEMPLATE .. " uses " .. switch .. ", which the GX10 does not have")
    assert(count == 3 or position ~= "1", TEMPLATE .. " uses the middle of the 2-position " .. switch)
  end

  assert(found > 0, TEMPLATE .. " uses no physical switch")
  assert(content:find("SG2,L9", 1, true), "the launch switch is not SG")
end)

test("GX10 F3K main view shows the window and flight timers on the 320x240 screen", function()
  local content = read_file(TEMPLATE)
  local screen = section(content, "screenData")
  assert(screen:find("\n    LayoutId: Layout1x2\n", 1, true), "main view is not Layout1x2")

  local timers = {}
  for zone, timer in screen:gmatch("\n        (%d+):\n          widgetName: Timer\n.-unsignedValue: (%d+)") do
    timers[tonumber(zone)] = tonumber(timer)
  end
  assert_equal(timers[0], 1, "upper zone timer index (Win)")
  assert_equal(timers[1], 0, "lower zone timer index (Fli)")

  -- A 320-pixel-wide screen has five topbar zones.
  local topbar = section(content, "topbarData")
  for zone in topbar:gmatch("\n    (%d+):\n") do
    assert(tonumber(zone) <= 4, "topbar zone " .. zone .. " does not exist on a 320x240 screen")
  end
  local widths = 0
  for index in pairs(entries(content, "topbarWidgetWidth")) do
    assert(index <= 4, "topbar width " .. tostring(index) .. " does not exist on a 320x240 screen")
    widths = widths + 1
  end
  assert_equal(widths, 5, "topbar zone widths")

  assert(not content:find("SoarF5J", 1, true), TEMPLATE .. " should not use the F5J widget")
end)

test("GX10 F3K voice prompts ship in SOUNDS/en or come with the EdgeTX voice pack", function()
  local tracked = {}
  for _, path in ipairs(command_lines("git ls-files dist/SDCARD/SOUNDS/en")) do
    tracked[path:match("([^/]+)%.wav$")] = true
  end

  local played = 0
  for _, fn in pairs(entries(read_file(TEMPLATE), "customFn")) do
    if fn.func == "PLAY_TRACK" then
      local name = fn.def:match("^([^\\,]*)")
      if name ~= "" then
        played = played + 1
        assert(tracked[name] or STOCK_PROMPTS[name], TEMPLATE .. " plays " .. name .. ", which nothing ships")
      end
    end
  end

  assert(played > 0, TEMPLATE .. " plays no voice prompt")
end)

test("documentation describes the GX10 F3K template", function()
  local docs = read_file("docs/model-templates.md")
  for _, needle in ipairs({ "## GX10 F3K Template", "gx10-F3K.yml", "`SG`", "`Win`", "`Fli`", "10:00" }) do
    assert(docs:find(needle, 1, true), "docs/model-templates.md does not mention " .. needle)
  end

  local readme = read_file("README.md")
  assert(readme:find("(docs/model-templates.md#gx10-f3k-template)", 1, true),
    "README does not link the GX10 F3K template")

  local sdcard = read_file("docs/sdcard-structure.md")
  assert(sdcard:find("| GX10 | 320x240 | `c320x240.zip` |", 1, true),
    "SD-card guide does not name the GX10 archive")
end)
