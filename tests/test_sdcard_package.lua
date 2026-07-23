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

local function find_mix_block_matching(blocks, expected)
  for _, block in ipairs(blocks) do
    local matches = true
    for _, needle in ipairs(expected) do
      if not block:find(needle, 1, true) then
        matches = false
        break
      end
    end
    if matches then
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

local TX15_TEMPLATE_VARIANTS = {
  {
    id = "MTail",
    etx = "models/tx15/tx15-MTail.etx",
    exported = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-MTail.yml"
  },
  {
    id = "VTail",
    etx = "models/tx15/tx15-VTail.etx",
    exported = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-VTail.yml"
  },
  {
    id = "XTail",
    etx = "models/tx15/tx15-XTail.etx",
    exported = "dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-XTail.yml"
  }
}

local function tx15_variant(id)
  for _, variant in ipairs(TX15_TEMPLATE_VARIANTS) do
    if variant.id == id then
      return variant
    end
  end
  error("unknown TX15 variant: " .. tostring(id), 0)
end

local function tx15_variant_models(id)
  local variant = tx15_variant(id)
  return {
    {
      label = "TX15 " .. variant.id .. " ETX model",
      variant = variant.id,
      content = command_output("unzip -p " .. variant.etx .. " MODELS/model1.yml")
    },
    {
      label = "exported TX15 " .. variant.id .. " template",
      variant = variant.id,
      content = read_file(variant.exported)
    }
  }
end

local function tx15_template_models()
  local models = {}
  for _, variant in ipairs(TX15_TEMPLATE_VARIANTS) do
    for _, model in ipairs(tx15_variant_models(variant.id)) do
      models[#models + 1] = model
    end
  end
  return models
end

local function tx15_output_models(id)
  local models = tx15_variant_models(id)
  for _, model in ipairs(models) do
    model.content = normalize_model_content(model.content)
  end
  if id == "MTail" then
    models[#models + 1] = {
      label = "SD card model",
      variant = id,
      content = normalize_model_content(read_file("dist/SDCARD/MODELS/model1.yml"))
    }
  end
  return models
end

test("static SD card content survives package rebuild", function()
  local required_files = {
    "dist/SDCARD/edgetx.sdcard.version",
    "dist/SDCARD/RADIO/README.txt",
    "dist/SDCARD/MODELS/README.txt",
    "dist/SDCARD/WIDGETS/ShowAll/main.lua"
  }

  for _, variant in ipairs(TX15_TEMPLATE_VARIANTS) do
    required_files[#required_files + 1] = variant.exported
  end

  for _, path in ipairs(required_files) do
    assert(file_exists(path), "missing static SD card file after package rebuild: " .. path)
  end
end)

test("TX15 F5J template variant artifacts are committed", function()
  for _, variant in ipairs(TX15_TEMPLATE_VARIANTS) do
    assert(file_exists(variant.etx), "missing TX15 " .. variant.id .. " ETX artifact")
    assert(file_exists(variant.exported), "missing TX15 " .. variant.id .. " exported template")
  end

  assert(not file_exists("models/tx15/f5j_tmpl_t15.etx"), "legacy single TX15 template artifact should be renamed")
  assert(not file_exists("dist/SDCARD/TEMPLATES/3.SoarEdgeTx/f5J-t15.yml"), "legacy exported TX15 template should be renamed")
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
  for _, model in ipairs(tx15_template_models()) do
    assert(model.content:find("widgetName: \"SoarF5J\"", 1, true) or model.content:find("widgetName: SoarF5J", 1, true),
      model.label .. " missing SoarF5J widget")
    assert(model.content:find("stringValue: \"competition/widget\"", 1, true) or
      model.content:find("stringValue: competition/widget", 1, true),
      model.label .. " missing competition widget page")
  end
end)

test("exported TX15 templates assign SoarF5J pages 1 through 7", function()
  for _, variant in ipairs(TX15_TEMPLATE_VARIANTS) do
    local model = read_file(variant.exported)
    local pages = {}

    assert(model:find("LayoutId: Layout1x1", 1, true), variant.id .. " missing competition 1x1 screen")
    assert(model:find("LayoutId: Layout1x6", 1, true), variant.id .. " missing setup 1x6 screen")

    for block in model:gmatch("widgetName: SoarF5J(.-)stringValue:%s*competition/widget") do
      local page = block:match("signedValue:%s*(%d+)")
      if page then
        pages[tonumber(page)] = true
      end
    end

    for page = 1, 7 do
      assert(pages[page], variant.id .. " missing SoarF5J page " .. page .. " widget")
    end
  end
end)

test("TX15 template variants keep common wing channels", function()
  for _, model in ipairs(tx15_template_models()) do
    model.content = normalize_model_content(model.content)
    local ch4_mixes = mix_blocks_for(model.content, 3)
    local ch5_mixes = mix_blocks_for(model.content, 4)

    assert_equal(#ch4_mixes, 2, model.label .. " CH4 mix count")
    assert_equal(#ch5_mixes, 2, model.label .. " CH5 mix count")
    assert_mix_block(ch4_mixes[1], { "srcRaw: ch(31)", "weight: 100", "value: !gv(12)" }, model.label .. " CH4 left flap")
    assert_mix_block(ch4_mixes[2], { "srcRaw: ch(30)", "weight: -100" }, model.label .. " CH4 left flap camber")
    assert_mix_block(ch5_mixes[1], { "srcRaw: ch(31)", "weight: 100", "value: gv(12)" }, model.label .. " CH5 right flap")
    assert_mix_block(ch5_mixes[2], { "srcRaw: ch(30)", "weight: 100" }, model.label .. " CH5 right flap camber")
    assert_contains(indexed_block(model.content, "limitData", 3), "name: Fl-L", model.label .. " CH4 output")
    assert_contains(indexed_block(model.content, "limitData", 4), "name: Fl-R", model.label .. " CH5 output")
    assert_contains(indexed_block(model.content, "gvars", 12), "name: FlD", model.label .. " GV13 name")
    assert_contains(indexed_block(model.content, "failsafeChannels", 3), "val: 38", model.label .. " CH4 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 4), "val: 57", model.label .. " CH5 failsafe")
  end
end)

test("TX15 MTail template maps CH6 rudder and CH7/CH8 elevator servos", function()
  for _, model in ipairs(tx15_output_models("MTail")) do
    local ch6_mixes = mix_blocks_for(model.content, 5)
    local ch7_mixes = mix_blocks_for(model.content, 6)
    local ch8_mixes = mix_blocks_for(model.content, 7)

    assert_equal(#ch6_mixes, 2, model.label .. " CH6 mix count")
    assert(#ch7_mixes == 2 or #ch7_mixes == 3, model.label .. " CH7 mix count expected 2 or 3, got " .. #ch7_mixes)
    assert(#ch8_mixes == 2 or #ch8_mixes == 3, model.label .. " CH8 mix count expected 2 or 3, got " .. #ch8_mixes)
    assert_mix_block(ch6_mixes[1], { "srcRaw: I0", "weight: 100" }, model.label .. " CH6 rudder")
    assert_mix_block(ch6_mixes[2], { "srcRaw: I2", "weight: gv(2)", "name: AilRud" }, model.label .. " CH6 aileron-rudder")

    local ch7_elevator = find_mix_block_matching(ch7_mixes, { "srcRaw: ch(21)", "weight: 100" })
    local ch8_elevator = find_mix_block_matching(ch8_mixes, { "srcRaw: ch(21)", "weight: 100" })
    local ch7_kapow = find_mix_block_matching(ch7_mixes, { "srcRaw: I1", "weight: gv(10)" })
    local ch8_kapow = find_mix_block_matching(ch8_mixes, { "srcRaw: I1", "weight: gv(10)" })

    assert(ch7_elevator, model.label .. " missing CH7 elevator mix")
    assert(ch8_elevator, model.label .. " missing CH8 elevator mix")
    assert(ch7_kapow, model.label .. " missing CH7 KAPOW elevator mix")
    assert(ch8_kapow, model.label .. " missing CH8 KAPOW elevator mix")
    assert_mix_block(ch7_elevator, { "srcRaw: ch(21)", "weight: 100" }, model.label .. " CH7 elevator")
    assert_mix_block(ch7_kapow, { "srcRaw: I1", "weight: gv(10)" }, model.label .. " CH7 KAPOW elevator")
    assert_mix_block(ch8_elevator, { "srcRaw: ch(21)", "weight: 100" }, model.label .. " CH8 elevator")
    assert_mix_block(ch8_kapow, { "srcRaw: I1", "weight: gv(10)" }, model.label .. " CH8 KAPOW elevator")

    assert_contains(indexed_block(model.content, "limitData", 5), "name: Rudd", model.label .. " CH6 output")
    assert_contains(indexed_block(model.content, "limitData", 6), "name: ElevL", model.label .. " CH7 output")
    assert_contains(indexed_block(model.content, "limitData", 7), "name: ElevR", model.label .. " CH8 output")
    assert_contains(indexed_block(model.content, "failsafeChannels", 5), "val: -189", model.label .. " CH6 failsafe")
    assert_contains(indexed_block(model.content, "failsafeChannels", 6), "val: -122", model.label .. " CH7 failsafe")
  end
end)

test("TX15 VTail template maps V-tail servos to CH7/CH8 only", function()
  for _, model in ipairs(tx15_output_models("VTail")) do
    local ch6_mixes = mix_blocks_for(model.content, 5)
    local ch7_mixes = mix_blocks_for(model.content, 6)
    local ch8_mixes = mix_blocks_for(model.content, 7)
    local ch9_mixes = mix_blocks_for(model.content, 8)
    local ch10_mixes = mix_blocks_for(model.content, 9)

    assert_equal(#ch6_mixes, 0, model.label .. " CH6 should be unused")
    assert_equal(#ch9_mixes, 0, model.label .. " CH9 should not be required")
    assert_equal(#ch10_mixes, 0, model.label .. " CH10 should not be required")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: I0", "weight: 50", "name: Vt-l" }), model.label .. " missing CH7 V-tail rudder source")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: ch(21)", "weight: -50" }), model.label .. " missing CH7 V-tail elevator source")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: I2", "weight: gv(11)", "name: AilEle" }), model.label .. " missing CH7 AilEle")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: I1", "weight: gv(10)" }), model.label .. " missing CH7 KAPOW elevator")
    assert(find_mix_block_matching(ch8_mixes, { "srcRaw: I0", "weight: 50" }), model.label .. " missing CH8 V-tail rudder source")
    assert(find_mix_block_matching(ch8_mixes, { "srcRaw: ch(21)", "weight: 50", "name: Vt-R" }), model.label .. " missing CH8 V-tail elevator source")
    assert(find_mix_block_matching(ch8_mixes, { "srcRaw: I2", "weight: !gv(11)", "name: AilEle" }), model.label .. " missing CH8 AilEle")
    assert(find_mix_block_matching(ch8_mixes, { "srcRaw: I1", "weight: gv(10)" }), model.label .. " missing CH8 KAPOW elevator")
    assert_contains(indexed_block(model.content, "limitData", 5), "name: Unused", model.label .. " CH6 output")
    assert_contains(indexed_block(model.content, "limitData", 6), "name: LftV", model.label .. " CH7 output")
    assert_contains(indexed_block(model.content, "limitData", 7), "name: RgtV", model.label .. " CH8 output")
  end
end)

test("TX15 XTail template maps one elevator to CH7 without aileron-elevator mix", function()
  for _, model in ipairs(tx15_output_models("XTail")) do
    local ch6_mixes = mix_blocks_for(model.content, 5)
    local ch7_mixes = mix_blocks_for(model.content, 6)
    local ch8_mixes = mix_blocks_for(model.content, 7)
    local ch9_mixes = mix_blocks_for(model.content, 8)
    local ch10_mixes = mix_blocks_for(model.content, 9)

    assert_equal(#ch6_mixes, 2, model.label .. " CH6 mix count")
    assert_equal(#ch8_mixes, 0, model.label .. " CH8 should be unused")
    assert_equal(#ch9_mixes, 0, model.label .. " CH9 should not be required")
    assert_equal(#ch10_mixes, 0, model.label .. " CH10 should not be required")
    assert_mix_block(ch6_mixes[1], { "srcRaw: I0", "weight: 100" }, model.label .. " CH6 rudder")
    assert_mix_block(ch6_mixes[2], { "srcRaw: I2", "weight: gv(2)", "name: AilRud" }, model.label .. " CH6 aileron-rudder")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: ch(21)", "weight: 100" }), model.label .. " missing CH7 elevator")
    assert(find_mix_block_matching(ch7_mixes, { "srcRaw: I1", "weight: gv(10)" }), model.label .. " missing CH7 KAPOW elevator")
    assert(not find_mix_block(ch7_mixes, "AilEle"), model.label .. " CH7 should not include AilEle")
    assert_contains(indexed_block(model.content, "limitData", 5), "name: Rudd", model.label .. " CH6 output")
    assert_contains(indexed_block(model.content, "limitData", 6), "name: Elev", model.label .. " CH7 output")
    assert_contains(indexed_block(model.content, "limitData", 7), "name: Unused", model.label .. " CH8 output")
  end
end)

test("TX15 MTail and VTail templates add switchable GV12 aileron to elevator mix", function()
  for _, id in ipairs({ "MTail", "VTail" }) do
    for _, model in ipairs(tx15_variant_models(id)) do
      model.content = normalize_model_content(model.content)
      local left_elevator_mixes = mix_blocks_for(model.content, 6)
      local right_elevator_mixes = mix_blocks_for(model.content, 7)
      local aileron_elevator =
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
  end
end)

test("TX15 templates map T3 to GV10 CbX in aileron camber setup", function()
  for _, model in ipairs(tx15_template_models()) do
    assert(model.content:find("name: CbX", 1, true), model.label .. " missing GV10 CbX name")
    assert(model.content:find("def: 9,Src,T3,1", 1, true), model.label .. " missing T3 adjustment for GV10 CbX")
    assert(not model.content:find("def: 6,Src,T3,1", 1, true), model.label .. " T3 should not duplicate CbA adjustment")
  end
end)

test("TX15 templates do not bind altitude report switch to speed mode", function()
  for _, model in ipairs(tx15_template_models()) do
    assert(model.content:find("def: SB2,L1", 1, true), model.label .. " missing voice-reporting default for L8 altitude reports")
    assert(not model.content:find("def: SC0,L1", 1, true), model.label .. " altitude reports should not default to SC down speed mode")
  end
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

test("TX15 ETX templates brake-off follows landing-off switch state directly", function()
  for _, model in ipairs(tx15_template_models()) do
    local brake_mixes = mix_blocks_for(model.content, 20)
    local brake_off = find_mix_block(brake_mixes, "BrkOff")

    assert(brake_off, model.label .. " missing BrkOff mix")
    assert_mix_block(brake_off, {
      "srcRaw: MAX",
      "swtch: L44",
      "mltpx: REPL",
      "name: BrkOff"
    }, model.label .. " BrkOff mix")
    assert(not brake_off:find("swtch: L36", 1, true), model.label .. " BrkOff should not use sticky L36")
  end
end)

test("TX15 templates have no legacy SoarOTX scripts, logs, or non-F5J class references", function()
  local forbidden = {
    "PLAY_SCRIPT",
    "JFutil",
    "func: LOGS",
    "f3k"
  }

  for _, model in ipairs(tx15_template_models()) do
    local lower_model = model.content:lower()

    for _, pattern in ipairs(forbidden) do
      if pattern:lower() == pattern then
        assert(not lower_model:find(pattern, 1, true), model.label .. " contains forbidden legacy reference: " .. pattern)
      else
        assert(not model.content:find(pattern, 1, true), model.label .. " contains forbidden legacy reference: " .. pattern)
      end
    end
  end
end)
