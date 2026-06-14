local savedGlobals = {}
local globalNames = {
  "VALUE",
  "model",
  "loadScript"
}

for _, name in ipairs(globalNames) do
  savedGlobals[name] = _G[name]
end

local function restore_globals()
  for _, name in ipairs(globalNames) do
    _G[name] = savedGlobals[name]
  end
end

local function load_main_with_stubs()
  restore_globals()

  local env = {
    loadedPaths = {}
  }

  VALUE = 1

  model = {
    setCurve = function() end
  }

  function loadScript(path)
    env.loadedPaths[#env.loadedPaths + 1] = path

    if path == "/WIDGETS/SoarF5J/lib/gui.lua" then
      return function()
        return { colors = {} }
      end
    elseif path == "/WIDGETS/SoarF5J/lib/edgetx.lua" then
      return function()
        return {
          getCurve = function()
            return { y = {} }
          end
        }
      end
    end

    return function(widget)
      widget.loadedPath = path
      widget.refresh = function() end
    end
  end

  env.main = assert(loadfile("src/SoarF5J/main.lua"))()
  return env
end

test("widget exposes Page as the only operator option", function()
  local env = load_main_with_stubs()

  restore_globals()

  assert_equal(#env.main.options, 1, "widget option count")
  assert_equal(env.main.options[1][1], "Page", "widget option")
  assert_equal(env.main.options[1][5], 7, "maximum page")
end)

test("Page option selects mixes setup page", function()
  local env = load_main_with_stubs()

  local widget = env.main.create({ w = 480, h = 220 }, {
    Page = 3
  })

  restore_globals()

  assert_equal(widget.loadedPath, "/WIDGETS/SoarF5J/setup/mixes.lua", "loaded widget page")
end)

test("Page option selects wing alignment setup page", function()
  local env = load_main_with_stubs()

  local widget = env.main.create({ w = 480, h = 220 }, {
    Page = 5
  })

  restore_globals()

  assert_equal(widget.loadedPath, "/WIDGETS/SoarF5J/setup/wing_alignment.lua", "loaded widget page")
end)

test("Page update reloads widget component", function()
  local env = load_main_with_stubs()

  local widget = env.main.create({ w = 480, h = 220 }, {
    Page = 1
  })
  env.main.update(widget, {
    Page = 5
  })

  restore_globals()

  assert_equal(widget.loadedPath, "/WIDGETS/SoarF5J/setup/wing_alignment.lua", "loaded widget page")
end)

test("Page 8 falls back to competition after battery page removal", function()
  local env = load_main_with_stubs()

  local widget = env.main.create({ w = 480, h = 220 }, {
    Page = 8
  })

  restore_globals()

  assert_equal(widget.loadedPath, "/WIDGETS/SoarF5J/competition/widget.lua", "loaded widget page")
end)
