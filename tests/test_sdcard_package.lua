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
