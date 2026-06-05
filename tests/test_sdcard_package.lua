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

test("TX15 template assigns SoarF5J widget", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")

  assert(model:find("widgetName: \"SoarF5J\"", 1, true) or model:find("widgetName: SoarF5J", 1, true), "missing SoarF5J widget")
  assert(model:find("stringValue: \"competition/widget\"", 1, true) or model:find("stringValue: competition/widget", 1, true), "missing competition widget page")
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
