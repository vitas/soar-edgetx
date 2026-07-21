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
    if line:match("^" .. name .. ":%s*$") then
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
  local block = {}
  local in_block = false
  local block_indent = nil

  for _, line in ipairs(lines_from(section)) do
    local indent = line:match("^(%s+)" .. tostring(index) .. ":%s*$")
    if not in_block and indent then
      in_block = true
      block_indent = indent
      block[#block + 1] = line
    elseif in_block and line:match("^" .. block_indent .. "%S") then
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
    if line:match("^%s*%-") then
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

local function find_mix_block(blocks, name)
  for _, block in ipairs(blocks) do
    if block:find("name: " .. name, 1, true) then
      return block
    end
  end
  return nil
end

local function find_mix_block_containing(blocks, needle)
  for _, block in ipairs(blocks) do
    if block:find(needle, 1, true) then
      return block
    end
  end
  return nil
end

local function normalize_model_content(content)
  content = content:gsub("\r\n", "\n")

  for _, key in ipairs({ "srcRaw", "weight", "swtch", "value", "name", "val" }) do
    content = content:gsub("(" .. key .. ":%s*)\"([^\"\n]*)\"", "%1%2")
  end

  return content
end

local EXPORTED_TX15_TEMPLATE = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx/f5J-t15.yml"

local function tx15_template_models()
  return {
    {
      label = "TX15 ETX model",
      content = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")
    },
    {
      label = "exported TX15 template",
      content = read_file(EXPORTED_TX15_TEMPLATE)
    }
  }
end

local function tx15_output_models()
  local models = tx15_template_models()
  for _, model in ipairs(models) do
    model.content = normalize_model_content(model.content)
  end
  models[#models + 1] = {
    label = "SD card model",
    content = normalize_model_content(read_file("dist/SDCARD/MODELS/model1.yml"))
  }
  return models
end

test("static SD card content survives package rebuild", function()
  local required_files = {
    "dist/SDCARD/edgetx.sdcard.version",
    "dist/SDCARD/RADIO/README.txt",
    "dist/SDCARD/MODELS/README.txt",
    EXPORTED_TX15_TEMPLATE,
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
  local model = read_file(EXPORTED_TX15_TEMPLATE)
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

test("TX15 templates map CH4/CH5 to flaps and CH6 to rudder", function()
  for _, model in ipairs(tx15_output_models()) do
    local ch4_mixes = mix_blocks_for(model.content, 3)
    local ch5_mixes = mix_blocks_for(model.content, 4)
    local ch6_mixes = mix_blocks_for(model.content, 5)
    local ch7_mixes = mix_blocks_for(model.content, 6)
    local lftv_mixes = mix_blocks_for(model.content, 8)
    local rgtv_mixes = mix_blocks_for(model.content, 9)

    assert_equal(#ch4_mixes, 2, model.label .. " CH4 mix count")
    assert_equal(#ch5_mixes, 2, model.label .. " CH5 mix count")
    assert_equal(#ch6_mixes, 2, model.label .. " CH6 mix count")
    assert(#ch7_mixes == 2 or #ch7_mixes == 3, model.label .. " CH7 mix count expected 2 or 3, got " .. #ch7_mixes)
    assert_equal(#lftv_mixes, 2, model.label .. " LftV mix count")
    assert_equal(#rgtv_mixes, 2, model.label .. " RgtV mix count")

    assert_mix_block(ch4_mixes[1], { "srcRaw: ch(31)", "weight: 100", "value: !gv(12)" }, model.label .. " CH4 left flap")
    assert_mix_block(ch4_mixes[2], { "srcRaw: ch(30)", "weight: -100" }, model.label .. " CH4 left flap camber")
    assert_mix_block(ch5_mixes[1], { "srcRaw: ch(31)", "weight: 100", "value: gv(12)" }, model.label .. " CH5 right flap")
    assert_mix_block(ch5_mixes[2], { "srcRaw: ch(30)", "weight: 100" }, model.label .. " CH5 right flap camber")
    assert_mix_block(ch6_mixes[1], { "srcRaw: I0", "weight: 100" }, model.label .. " CH6 rudder")
    assert_mix_block(ch6_mixes[2], { "srcRaw: I2", "weight: gv(2)", "name: AilRud" }, model.label .. " CH6 aileron-rudder")
    local ch7_elevator = find_mix_block_containing(ch7_mixes, "srcRaw: ch(21)")
    local ch7_kapow = find_mix_block_containing(ch7_mixes, "weight: gv(10)")

    assert(ch7_elevator, model.label .. " missing CH7 elevator mix")
    assert(ch7_kapow, model.label .. " missing CH7 KAPOW elevator mix")
    assert_mix_block(ch7_elevator, { "srcRaw: ch(21)", "weight: 100" }, model.label .. " CH7 elevator")
    assert_mix_block(ch7_kapow, { "srcRaw: I1", "weight: gv(10)" }, model.label .. " CH7 KAPOW elevator")

    assert_mix_block(lftv_mixes[1], { "srcRaw: ch(5)", "weight: 50", "name: Vt-l" }, model.label .. " LftV rudder source")
    assert_mix_block(lftv_mixes[2], { "srcRaw: ch(6)", "weight: -50" }, model.label .. " LftV elevator source")
    assert_mix_block(rgtv_mixes[1], { "srcRaw: ch(5)", "weight: 50" }, model.label .. " RgtV rudder source")
    assert_mix_block(rgtv_mixes[2], { "srcRaw: ch(6)", "weight: 50", "name: Vt-R" }, model.label .. " RgtV elevator source")

    assert_contains(indexed_block(model.content, "limitData", 3), "name: Fl-L", model.label .. " CH4 output")
    assert_contains(indexed_block(model.content, "limitData", 4), "name: Fl-R", model.label .. " CH5 output")
    assert_contains(indexed_block(model.content, "limitData", 5), "name: Rudd", model.label .. " CH6 output")
    assert_contains(indexed_block(model.content, "limitData", 6), "name: ElevL", model.label .. " CH7 output")
    assert_contains(indexed_block(model.content, "gvars", 12), "name: FlD", model.label .. " GV13 name")
    assert_contains(indexed_block(model.content, "failsafeChannels", 3), "val: 38", model.label .. " CH4 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 4), "val: 57", model.label .. " CH5 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 5), "val: -189", model.label .. " CH6 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 6), "val: -122", model.label .. " CH7 failsafe")
  end
end)

test("TX15 templates add switchable GV12 aileron to elevator mix", function()
  for _, model in ipairs(tx15_template_models()) do
    model.content = normalize_model_content(model.content)
    local elevator_mixes = mix_blocks_for(model.content, 21)
    local left_elevator_mixes = mix_blocks_for(model.content, 6)
    local right_elevator_mixes = mix_blocks_for(model.content, 7)
    local aileron_elevator =
      find_mix_block(elevator_mixes, "AilEle") or
      find_mix_block(left_elevator_mixes, "AilEle") or
      find_mix_block(right_elevator_mixes, "AilEle")

    assert(aileron_elevator, model.label .. " missing AilEle mix")
    assert_mix_block(aileron_elevator, {
      "srcRaw: I2",
      "swtch: L46",
      "mltpx: ADD",
      "name: AilEle"
    }, model.label .. " aileron-elevator mix")
    assert(aileron_elevator:find("weight: gv%(11%)") or aileron_elevator:find("weight: !gv%(11%)"),
      model.label .. " aileron-elevator mix missing GV12 weight")

    assert_contains(indexed_block(model.content, "logicalSw", 4), "def: SA2,NONE", model.label .. " L5 motor arm switch")
    assert_contains(indexed_block(model.content, "logicalSw", 45), "def: SA0,NONE", model.label .. " L46 switch")
    assert_contains(indexed_block(model.content, "gvars", 11), "name: AiE", model.label .. " GV12 name")
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

test("TX15 templates preserve retained voice tracks for mode and window cues", function()
  local expected = {
    [6] = { "swtch: L6", 'def: "landin\\x00\\x00,1,1x"' },
    [26] = { "swtch: L37", 'def: "\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00,1,5"' },
    [32] = { "swtch: FM0", 'def: "f3j_t2\\x00\\x00,1,1x"' },
    [33] = { "swtch: FM2", 'def: "f3jlau\\x00\\x00,1,1x"' },
    [34] = { "swtch: FM5", 'def: "f3j_t1\\x00\\x00,1,1x"' },
    [35] = { "swtch: FM4", 'def: "f3j_t3\\x00\\x00,1,1x"' },
    [36] = { "swtch: L35", 'def: "f3jlnd\\x00\\x00,1,1x"' }
  }

  for _, model in ipairs(tx15_template_models()) do
    for index, needles in pairs(expected) do
      local block = indexed_block(model.content, "customFn", index)
      assert_contains(block, "func: PLAY_TRACK", model.label .. " SF" .. tostring(index + 1))
      for _, needle in ipairs(needles) do
        assert_contains(block, needle, model.label .. " SF" .. tostring(index + 1))
      end
    end
  end
end)

test("TX15 templates play crow-off from landing-off logical switch", function()
  for _, model in ipairs(tx15_template_models()) do
    assert_mix_block(indexed_block(model.content, "customFn", 37), {
      "swtch: L45",
      "func: PLAY_TRACK",
      'def: "crowof\\x00\\x00,1,1x"'
    }, model.label .. " SF38 crow-off track")
  end
end)

test("TX15 ETX brake-off follows landing-off switch state directly", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")
  local brake_mixes = mix_blocks_for(model, 20)
  local brake_off = find_mix_block(brake_mixes, "BrkOff")

  assert(brake_off, "TX15 ETX model missing BrkOff mix")
  assert_mix_block(brake_off, {
    "srcRaw: MAX",
    "swtch: L44",
    "mltpx: REPL",
    "name: BrkOff"
  }, "TX15 ETX BrkOff mix")
  assert(not brake_off:find("swtch: L36", 1, true), "TX15 ETX BrkOff should not use sticky L36")
end)

test("TX15 template has no legacy SoarOTX scripts, logs, or non-F5J class references", function()
  local model = command_output("unzip -p models/tx15/f5j_tmpl_t15.etx MODELS/model1.yml")
  local forbidden = {
    "PLAY_SCRIPT",
    "JFutil",
    "func: LOGS",
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
