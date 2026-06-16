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

local function lines_from(content)
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

local function top_level_section(content, name)
  local section = {}
  local in_section = false

  for _, line in ipairs(lines_from(content)) do
    if line == name .. ":" then
      in_section = true
      section[#section + 1] = line
    elseif in_section and line:match("^%S") then
      break
    elseif in_section then
      section[#section + 1] = line
    end
  end

  assert(#section > 0, "missing section: " .. name)
  return table.concat(section, "\n")
end

local function indexed_block(content, section_name, index)
  local section = top_level_section(content, section_name)
  local header = "  " .. tostring(index) .. ":"
  local block = {}
  local in_block = false

  for _, line in ipairs(lines_from(section)) do
    if line == header then
      in_block = true
      block[#block + 1] = line
    elseif in_block and line:match("^  %S") then
      break
    elseif in_block then
      block[#block + 1] = line
    end
  end

  assert(#block > 0, "missing " .. section_name .. " block " .. tostring(index))
  return table.concat(block, "\n")
end

local function mix_blocks_for(content, dest_ch)
  local section = top_level_section(content, "mixData")
  local blocks = {}
  local block = nil

  local function finish_block()
    if not block then return end
    local text = table.concat(block, "\n")
    for _, line in ipairs(block) do
      if line:match("destCh:%s*" .. tostring(dest_ch) .. "%s*$") then
        blocks[#blocks + 1] = text
        break
      end
    end
  end

  for _, line in ipairs(lines_from(section)) do
    if line:match("^  %-") then
      finish_block()
      block = { line }
    elseif block then
      block[#block + 1] = line
    end
  end
  finish_block()

  return blocks
end

local function assert_contains(content, needle, label)
  assert(content:find(needle, 1, true), label .. " missing " .. needle)
end

local function assert_mix_block(block, expected, label)
  for _, needle in ipairs(expected) do
    assert_contains(block, needle, label)
  end
end

local function tx15_template_models()
  return {
    {
      label = "TX15 ETX model",
      content = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")
    },
    {
      label = "exported TX15 template",
      content = read_file("dist/SDCARD/TEMPLATES/f5J-t15.yml")
    }
  }
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

test("exported TX15 template assigns SoarF5J pages 1 through 7", function()
  local model = read_file("dist/SDCARD/TEMPLATES/f5J-t15.yml")
  local pages = {}

  assert(model:find("LayoutId: Layout1x1", 1, true), "missing competition 1x1 screen")
  assert(model:find("LayoutId: Layout1x6", 1, true), "missing setup 1x6 screen")

  for block in model:gmatch("widgetName: SoarF5J(.-)stringValue:%s*competition/widget") do
    local page = block:match("signedValue:%s*(%d+)")
    if page then
      pages[tonumber(page)] = true
    end
  end

  for page = 1, 7 do
    assert(pages[page], "missing SoarF5J page " .. page .. " widget")
  end
end)

test("TX15 templates swap CH4 and CH7 mixer output references", function()
  for _, model in ipairs(tx15_template_models()) do
    local ch4_mixes = mix_blocks_for(model.content, 3)
    local ch7_mixes = mix_blocks_for(model.content, 6)
    local lftv_mixes = mix_blocks_for(model.content, 8)
    local rgtv_mixes = mix_blocks_for(model.content, 9)

    assert_equal(#ch4_mixes, 2, model.label .. " CH4 mix count")
    assert_equal(#ch7_mixes, 2, model.label .. " CH7 mix count")
    assert_equal(#lftv_mixes, 2, model.label .. " LftV mix count")
    assert_equal(#rgtv_mixes, 2, model.label .. " RgtV mix count")

    assert_mix_block(ch4_mixes[1], { "srcRaw: I0", "weight: 100" }, model.label .. " CH4 rudder")
    assert_mix_block(ch4_mixes[2], { "srcRaw: I2", "weight: gv(2)", "name: AilRud" }, model.label .. " CH4 aileron-rudder")
    assert_mix_block(ch7_mixes[1], { "srcRaw: ch(21)", "weight: 100" }, model.label .. " CH7 elevator")
    assert_mix_block(ch7_mixes[2], { "srcRaw: I1", "weight: gv(10)" }, model.label .. " CH7 KAPOW elevator")

    assert_mix_block(lftv_mixes[1], { "srcRaw: ch(3)", "weight: 50", "name: Vt-l" }, model.label .. " LftV rudder source")
    assert_mix_block(lftv_mixes[2], { "srcRaw: ch(6)", "weight: -50" }, model.label .. " LftV elevator source")
    assert_mix_block(rgtv_mixes[1], { "srcRaw: ch(3)", "weight: 50" }, model.label .. " RgtV rudder source")
    assert_mix_block(rgtv_mixes[2], { "srcRaw: ch(6)", "weight: 50", "name: Vt-R" }, model.label .. " RgtV elevator source")

    assert_contains(indexed_block(model.content, "limitData", 3), "name: Rudd", model.label .. " CH4 output")
    assert_contains(indexed_block(model.content, "limitData", 6), "name: ElevL", model.label .. " CH7 output")
    assert_contains(indexed_block(model.content, "failsafeChannels", 3), "val: -189", model.label .. " CH4 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 6), "val: -122", model.label .. " CH7 failsafe")
  end
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
