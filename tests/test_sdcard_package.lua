local function file_exists(path)
  local previous = io.input()
  local ok, file = pcall(io.input, path)
  io.input(previous)
  if ok and file then file:close() end
  return ok
end

local function command_lines(cmd)
  local pipe = assert(io.popen(cmd))
  local out = {}
  for line in pipe:lines() do
    out[#out + 1] = line
  end
  local ok = pipe:close()
  assert(ok, "command failed: " .. cmd)
  return out
end

local function command_output(cmd)
  local pipe = assert(io.popen(cmd))
  local out = pipe:read("*a")
  local ok = pipe:close()
  assert(ok, "command failed: " .. cmd)
  return out
end

local function read_file(path)
  local previous = io.input()
  local file = assert(io.input(path))
  local content = io.read("*a")
  io.input(previous)
  file:close()
  return content
end

test("static SD card content survives package rebuild", function()
  local required_files = {
    "dist/SDCARD/edgetx.sdcard.version",
    "dist/SDCARD/RADIO/README.txt",
    "dist/SDCARD/MODELS/README.txt",
    "dist/SDCARD/TEMPLATES/4.SoarETX_v2/F5J_v2.yml",
    "dist/SDCARD/WIDGETS/ShowAll/main.lua"
  }

  for _, path in ipairs(required_files) do
    assert(file_exists(path), "missing static SD card file after package rebuild: " .. path)
  end
end)

test("TX15 F5J template artifact is committed", function()
  assert(file_exists("models/tx15/f5j_tmpl_t15.etx"), "missing TX15 template artifact")
end)

test("SD card sounds are ignored and untracked", function()
  local ignore = read_file(".gitignore")
  assert(ignore:find("dist/SDCARD/SOUNDS/", 1, true), "missing exact SD card sounds ignore rule")

  local tracked = command_lines("git ls-files dist/SDCARD/SOUNDS")
  assert_equal(#tracked, 0, "tracked SD card sound file count")
end)

test("compiled Lua bytecode is ignored and untracked", function()
  local ignore = read_file(".gitignore")
  assert(ignore:find("*.luac", 1, true), "missing compiled Lua ignore rule")

  local tracked = command_lines("git ls-files '*.luac'")
  assert_equal(#tracked, 0, "tracked compiled Lua file count")
end)

test("Makefile installs packaged widget to configured SD card", function()
  local makefile = read_file("Makefile")

  assert(makefile:find("install%-widget: package"), "missing install-widget package dependency")
  assert(makefile:find("SDCARD", 1, true), "missing SDCARD variable")
  assert(makefile:find("rm -rf \"$(SDCARD)/WIDGETS/SoarF5J\"", 1, true), "missing stale widget removal")
  assert(makefile:find("cp -R dist/SDCARD/WIDGETS/SoarF5J \"$(SDCARD)/WIDGETS/\"", 1, true), "missing widget copy")
end)

test("TX15 template assigns SoarF5J widget", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")

  assert(model:find("widgetName: \"SoarF5J\"", 1, true) or model:find("widgetName: SoarF5J", 1, true), "missing SoarF5J widget")
  assert(model:find("stringValue: \"competition/widget\"", 1, true) or model:find("stringValue: competition/widget", 1, true), "missing competition widget page")
end)

test("TX15 template maps throttle trim to GV10 CbX in aileron camber setup", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")

  assert(model:find("name: CbX", 1, true), "missing GV10 CbX name")
  assert(model:find("def: 9,Src,T3,1", 1, true), "missing T3 adjustment for GV10 CbX")
  assert(not model:find("def: 6,Src,T3,1", 1, true), "T3 should not duplicate CbA adjustment")
end)

test("TX15 template does not bind altitude report switch to speed mode", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")

  assert(model:find("def: SB2,L1", 1, true), "missing voice-reporting default for L8 altitude reports")
  assert(not model:find("def: SC0,L1", 1, true), "altitude reports should not default to SC down speed mode")
end)

test("TX15 template has no legacy SoarOTX scripts, logs, or non-F5J sound references", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")
  local forbidden = {
    "PLAY_SCRIPT",
    "JFutil",
    "func: LOGS",
    "f3j",
    "f3k"
  }
  local lower_model = model:lower()

  for _, pattern in ipairs(forbidden) do
    if pattern:lower() == pattern then
      assert(not lower_model:find(pattern, 1, true), "template contains forbidden legacy reference: " .. pattern)
    else
      assert(not model:find(pattern, 1, true), "template contains forbidden legacy reference: " .. pattern)
    end
  end
end)
