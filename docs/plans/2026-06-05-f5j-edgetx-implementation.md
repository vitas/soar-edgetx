# F5J EdgeTX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a GPL-compatible, F5J-only EdgeTX color widget project for the Radiomaster TX15, starting from the SoarETX color code and filling in missing F5J competition/setup behavior from SoarOTX.

**Architecture:** Keep the project source-first: maintain Lua under `src/SoarF5J`, package SD-card output under `dist/WIDGETS/SoarF5J`, and document the TX15 model-template workflow under `docs/` and `models/`. Runtime model mutations stay in setup pages and EdgeTX wrappers; testable competition logic lives in pure Lua modules.

**Tech Stack:** Lua, EdgeTX widget APIs, local `lua`/`luac`, repo-owned lint/test scripts, Makefile, GPL-2.0-compatible licensing.

---

## Context

Approved design: `docs/plans/2026-06-05-f5j-edgetx-design.md`

Reference code:

- `/Users/vitas/Downloads/SoarETX`
- `/Users/vitas/Downloads/xlite_f5j.otx`
- `/tmp/SoarOTX` if already cloned, otherwise clone `https://github.com/jfrickmann/SoarOTX`

Important scope:

- F5J only.
- TX15/color EdgeTX only.
- No BW support.
- No F3K/F3J/F3RES/F5K branching.
- No flight CSV logging or score browser in first version.
- No model wizard in first version.

Worktree:

- Implement in `/Users/vitas/git/soar-edgetx/.worktrees/f5j-edgetx`.

## Task 1: License And Project Skeleton

**Files:**

- Modify: `LICENSE`
- Create: `NOTICE`
- Create: `README.md`
- Create: `Makefile`
- Create: `src/SoarF5J/.gitkeep`
- Create: `tests/.gitkeep`
- Create: `tools/.gitkeep`
- Create: `dist/.gitkeep`
- Create: `models/reference/.gitkeep`
- Create: `models/tx15/.gitkeep`

**Step 1: Update license**

Replace `LICENSE` with GPL-2.0 text. Use GPL-2.0-only unless the user explicitly chooses GPL-2.0-or-later before implementation starts.

**Step 2: Add notice**

Create `NOTICE`:

```text
SoarF5J EdgeTX

This project is derived from and inspired by SoarOTX and SoarETX.

SoarOTX:
  Author: Jesper Frickmann
  License: GPL-2.0
  URL: https://github.com/jfrickmann/SoarOTX

SoarETX starter code:
  Authors: Jesper Frickmann, Frankie Arzu, EdgeTX contributors
  License headers: GPL-2.0
```

**Step 3: Add initial README**

Create `README.md` with:

```markdown
# SoarF5J EdgeTX

F5J-only EdgeTX color-radio widget and model-template project for the Radiomaster TX15.

## Status

Early development. The first target is a TX15 SD-card package plus model-template documentation.

## Structure

- `src/SoarF5J/`: maintainable Lua source.
- `dist/WIDGETS/SoarF5J/`: SD-card widget package output.
- `models/reference/`: reference model archives used for migration.
- `models/tx15/`: TX15 model template artifacts.
- `docs/`: setup, emulator, and SD-card documentation.
- `tools/`: local build, lint, packaging, and test helpers.
- `tests/`: local Lua tests for pure modules and template validation.

## Verification

Run:

```sh
make lint
make test
make package
```
```

**Step 4: Add Makefile shell**

Create `Makefile`:

```make
.PHONY: lint test package verify clean

lint:
	lua tools/lint.lua

test:
	lua tests/run.lua

package:
	lua tools/package.lua

verify: lint test package

clean:
	rm -rf dist/WIDGETS/SoarF5J
```

**Step 5: Add placeholder directories**

Use empty `.gitkeep` files only for directories that otherwise have no files yet.

**Step 6: Run verification**

Run: `make verify`

Expected: fail because `tools/lint.lua`, `tests/run.lua`, and `tools/package.lua` do not exist yet.

**Step 7: Commit**

```sh
git add LICENSE NOTICE README.md Makefile src tests tools dist models
git commit -m "Initialize F5J EdgeTX project skeleton"
```

## Task 2: Local Tooling

**Files:**

- Create: `tools/lint.lua`
- Create: `tools/package.lua`
- Create: `tests/run.lua`

**Step 1: Add lint script**

Create `tools/lint.lua` that:

- Walks `src`, `tests`, and `tools`.
- Runs `luac -p` on each `.lua` file.
- Fails on copied non-F5J script names under `src/SoarF5J` such as `f3k`, `f3j`, `f5k`, `f3r`, `f3res`, or `bw`.
- Prints `lint ok` when clean.

Minimal implementation:

```lua
local roots = { "src", "tests", "tools" }
local banned = { "f3k", "f3j", "f5k", "f3r", "f3res", "bw" }

local function lines(cmd)
  local p = assert(io.popen(cmd))
  local out = {}
  for line in p:lines() do out[#out + 1] = line end
  local ok = p:close()
  return out, ok
end

local files = {}
for _, root in ipairs(roots) do
  local out = lines("find " .. root .. " -type f -name '*.lua' 2>/dev/null")
  for _, file in ipairs(out) do files[#files + 1] = file end
end

local failed = false
for _, file in ipairs(files) do
  local ok = os.execute(string.format("luac -p %q >/dev/null 2>&1", file))
  if ok ~= true and ok ~= 0 then
    io.stderr:write("syntax failed: " .. file .. "\n")
    failed = true
  end

  local lower = file:lower()
  if lower:match("^src/soarf5j/") then
    for _, word in ipairs(banned) do
      if lower:find(word, 1, true) then
        io.stderr:write("banned non-F5J path: " .. file .. "\n")
        failed = true
      end
    end
  end
end

if failed then os.exit(1) end
print("lint ok")
```

**Step 2: Add test runner**

Create `tests/run.lua`:

```lua
local tests = {}

function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

function assert_equal(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
  end
end

local test_files = {}
local p = assert(io.popen("find tests -type f -name 'test_*.lua' | sort"))
for file in p:lines() do test_files[#test_files + 1] = file end
p:close()

for _, file in ipairs(test_files) do
  assert(dofile(file))
end

local failures = 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    print("ok - " .. t.name)
  else
    failures = failures + 1
    print("not ok - " .. t.name .. ": " .. err)
  end
end

if failures > 0 then os.exit(1) end
print(string.format("%d tests ok", #tests))
```

**Step 3: Add package script**

Create `tools/package.lua` that:

- Removes and recreates `dist/WIDGETS/SoarF5J`.
- Copies source `.lua` files from `src/SoarF5J` to `dist/WIDGETS/SoarF5J`.
- Preserves relative directories.
- Prints `package ok`.

Use `mkdir -p`, `rm -rf`, and `cp` through `os.execute` for the first version.

**Step 4: Run verification**

Run: `make verify`

Expected: pass with zero tests and generated `dist/WIDGETS/SoarF5J`.

**Step 5: Commit**

```sh
git add tools tests dist
git commit -m "Add local Lua tooling"
```

## Task 3: Core Source From SoarETX

**Files:**

- Create: `src/SoarF5J/main.lua`
- Create: `src/SoarF5J/lib/gui.lua`
- Create: `src/SoarF5J/lib/edgetx.lua`
- Create: `src/SoarF5J/pages/name.lua`
- Modify: `tools/package.lua`

**Step 1: Copy GUI library**

Copy `/Users/vitas/Downloads/SoarETX/libgui.lua` to `src/SoarF5J/lib/gui.lua`.
Keep the original GPL header.

**Step 2: Create EdgeTX helper module**

Create `src/SoarF5J/lib/edgetx.lua`:

```lua
local M = {}

function M.getCurve(index)
  local curve = model.getCurve(index)
  if not curve then return nil end
  if curve.y and #curve.y == 5 then return curve end

  if curve.y and #curve.y == 4 then
    local fixed = { y = {}, smooth = 1, name = curve.name }
    for i = 1, 5 do fixed.y[i] = curve.y[i - 1] end
    return fixed
  end

  return curve
end

function M.findBatterySource()
  return getFieldInfo("Cels") or getFieldInfo("RxBt") or getFieldInfo("A1") or getFieldInfo("A2")
end

function M.readScalarValue(source)
  local value = getValue(source.id)
  if type(value) == "table" then
    local min = value[1]
    for i = 2, #value do min = math.min(min, value[i]) end
    return min
  end
  return value
end

function M.resetAltitude()
  for i = 0, 31 do
    local sensor = model.getSensor(i)
    if sensor and sensor.name == "Alt" then
      model.resetSensor(i)
      return true
    end
  end
  return false
end

return M
```

**Step 3: Create F5J-only widget entry**

Create `src/SoarF5J/main.lua` from `/Users/vitas/Downloads/SoarETX/main.lua`, with these changes:

- `path = "/WIDGETS/SoarF5J/"`
- widget name `SoarF5J`
- remove `Type` option
- keep `Version` and `FileName`
- load `lib/gui.lua` and `lib/edgetx.lua`
- default dynamic page can be `competition/widget.lua`
- keep battery background check through shared helper

**Step 4: Add model-name page**

Copy `/Users/vitas/Downloads/SoarETX/2/name.lua` to `src/SoarF5J/pages/name.lua`.
Adjust only the path/header if needed.

**Step 5: Update package paths**

Modify `tools/package.lua` so `src/SoarF5J/main.lua` packages as `dist/WIDGETS/SoarF5J/main.lua`, and all subdirectories package under `dist/WIDGETS/SoarF5J/`.

**Step 6: Run verification**

Run:

```sh
make verify
find dist/WIDGETS/SoarF5J -type f | sort
```

Expected: lint/test/package pass, and dist includes `main.lua`, `lib/gui.lua`, `lib/edgetx.lua`, and `pages/name.lua`.

**Step 7: Commit**

```sh
git add src tools dist
git commit -m "Add SoarF5J widget core"
```

## Task 4: F5J Competition State Tests

**Files:**

- Create: `tests/test_competition_state.lua`
- Create: `src/SoarF5J/competition/state.lua`

**Step 1: Write failing tests**

Create tests for:

- initial state after reset
- arm event resets to initial/prepared
- motor starts competition timing
- motor off enters glide and opens 10-second height window
- landing trigger enters landing-points state
- motor restart after glide forces zero result

Example test skeleton:

```lua
local State = dofile("src/SoarF5J/competition/state.lua")

test("initial state", function()
  local s = State.new({ target_time = 600 })
  assert_equal(s.mode, "initial")
  assert_equal(s.target_time, 600)
end)
```

**Step 2: Run tests to verify failure**

Run: `make test`

Expected: fail because `competition/state.lua` does not exist.

**Step 3: Implement pure state module**

Create `src/SoarF5J/competition/state.lua` with:

- `new(opts)`
- `arm(state)`
- `motor_started(state)`
- `motor_stopped(state, now)`
- `tick(state, inputs)`
- `trigger(state)`
- `restart_motor(state)`

Use string modes: `initial`, `motor`, `glide`, `landing_points`, `start_height`, `time_correction`, `finished`, `zero`.

**Step 4: Run verification**

Run: `make verify`

Expected: pass.

**Step 5: Commit**

```sh
git add src/SoarF5J/competition/state.lua tests/test_competition_state.lua
git commit -m "Add F5J competition state machine"
```

## Task 5: Competition Widget Runtime

**Files:**

- Create: `src/SoarF5J/competition/widget.lua`
- Modify: `src/SoarF5J/main.lua`
- Test: `tests/test_competition_state.lua`

**Step 1: Extend tests for height capture and timer labels**

Add pure tests for:

- height capture after the 10-second window
- fallback start height when telemetry is missing
- timer target correction before launch

**Step 2: Run tests to verify failure**

Run: `make test`

Expected: fail until state helpers are extended.

**Step 3: Implement runtime widget**

Create `competition/widget.lua` based on `/Users/vitas/Downloads/SoarETX/2/f5J.lua`, but:

- remove score file constants and CSV save code
- use shared state module
- use shared EdgeTX helpers
- keep EdgeTX audio/timer/altitude side effects in this file
- draw color widget fields for flight timer, motor timer, landing points, start height, and status

**Step 4: Update entry default**

Set the default `FileName` option in `main.lua` to `competition/widget`.

**Step 5: Run verification**

Run: `make verify`

Expected: pass.

**Step 6: Commit**

```sh
git add src tests
git commit -m "Add F5J competition widget"
```

## Task 6: F5J Setup Pages

**Files:**

- Create: `src/SoarF5J/setup/switches.lua`
- Create: `src/SoarF5J/setup/mixes.lua`
- Create: `src/SoarF5J/setup/outputs.lua`
- Create: `src/SoarF5J/setup/wing_alignment.lua`
- Create: `src/SoarF5J/setup/brake_curves.lua`
- Create: `src/SoarF5J/setup/aileron_camber.lua`
- Create: `src/SoarF5J/setup/battery.lua`
- Create: `src/SoarF5J/lib/safety.lua`

**Step 1: Add safety helper**

Create `lib/safety.lua` with motor warning prompt text and a reusable `drawMotorDisabledWarning(gui)` helper.

**Step 2: Copy and trim setup pages**

Use these SoarETX files as sources:

- `2/switch.lua` -> `setup/switches.lua`
- `2/mixes.lua` -> `setup/mixes.lua`
- `2/outputs.lua` -> `setup/outputs.lua`
- `2/wing4.lua` -> `setup/wing_alignment.lua`
- `2/brkcrv.lua` -> `setup/brake_curves.lua`
- `2/ailctr.lua` and SoarOTX `JFXJ/AILCMB.lua` -> `setup/aileron_camber.lua`
- battery logic from `2/battery.lua` and `main.lua` -> `setup/battery.lua`

Remove all class branching. Keep only F5J/FxJ behavior.

**Step 3: Normalize page names**

Each setup page should expose `widget.refresh` and optional `widget.background` the same way as SoarETX loadable components.

**Step 4: Run verification**

Run: `make verify`

Expected: pass; lint should fail if any copied file path contains non-F5J names or syntax errors.

**Step 5: Commit**

```sh
git add src/SoarF5J/setup src/SoarF5J/lib/safety.lua
git commit -m "Add F5J setup pages"
```

## Task 7: SD-Card Package Structure

**Files:**

- Modify: `tools/package.lua`
- Create: `docs/sdcard-structure.md`
- Create: `dist/SDCARD/.gitkeep` if needed

**Step 1: Update package output**

Package into:

```text
dist/SDCARD/WIDGETS/SoarF5J/
```

Keep `dist/WIDGETS/SoarF5J/` only if there is a strong compatibility reason; otherwise use `dist/SDCARD` as the install root.

**Step 2: Add SD-card docs**

Create `docs/sdcard-structure.md`:

```markdown
# EdgeTX SD Card Structure

Copy the contents of `dist/SDCARD` to the root of the TX15 SD card.

Expected layout:

```text
SDCARD/
  WIDGETS/
    SoarF5J/
      main.lua
      lib/
      competition/
      setup/
      pages/
```

In EdgeTX, add a SoarF5J widget to a model screen and select the required page in widget options.
```

**Step 3: Run verification**

Run:

```sh
make package
find dist/SDCARD -type f | sort
```

Expected: packaged widget files appear under `dist/SDCARD/WIDGETS/SoarF5J`.

**Step 4: Commit**

```sh
git add tools dist docs/sdcard-structure.md
git commit -m "Document EdgeTX SD card package"
```

## Task 8: Emulator And TX15 Documentation

**Files:**

- Create: `docs/project-structure.md`
- Create: `docs/emulator.md`
- Create: `docs/tx15-model-template.md`
- Create: `models/reference/README.md`
- Create: `models/tx15/README.md`

**Step 1: Document project structure**

`docs/project-structure.md` should explain every top-level directory and the difference between source and packaged output.

**Step 2: Document emulator/simulator workflow**

`docs/emulator.md` should document:

- EdgeTX Companion 2.11 path on this machine:
  `/Applications/EdgeTX Companion 2.11.app`
- OpenTX Companion 2.3 path for the Xlite reference:
  `/Applications/OpenTX Companion 2.3.app`
- How to open the TX15 simulator in Companion.
- How to mount or point the simulator at a copied SD-card structure.
- How to add the SoarF5J widget in the simulator.
- What cannot be fully verified locally without radio hardware and telemetry.

Do not claim CLI emulator support unless verified.

**Step 3: Document model template migration**

`docs/tx15-model-template.md` should document:

- Reference archive: `/Users/vitas/Downloads/xlite_f5j.otx`
- It contains one model slot.
- It references `JF5Jsk`, `JFXJcf`, `JFgrph`, and `JFutil`.
- The TX15 template is expected to define flight modes, timers, LS, GVs, curves, mixes, outputs, and widget screen assignments.
- Manual Companion migration is acceptable until a repeatable model export path exists.

**Step 4: Add model directory READMEs**

Explain whether artifacts are committed and how to refresh them.

**Step 5: Run verification**

Run: `make verify`

Expected: pass.

**Step 6: Commit**

```sh
git add docs models
git commit -m "Add project and simulator documentation"
```

## Task 9: Reference Model Artifact Decision

**Files:**

- Optional create: `models/reference/xlite_f5j.otx`
- Modify: `models/reference/README.md`

**Step 1: Ask before committing artifact**

Ask the user whether `/Users/vitas/Downloads/xlite_f5j.otx` should be committed.

**Step 2: If approved, copy artifact**

Copy to `models/reference/xlite_f5j.otx` and document source/date.

**Step 3: If not approved, document external path**

Keep only README references.

**Step 4: Commit if changed**

```sh
git add models/reference
git commit -m "Add Xlite F5J reference model"
```

Only run this commit if the user approves committing the model archive.

## Task 10: Final Verification Pass

**Files:**

- Modify only files needed to fix final verification issues.

**Step 1: Run local verification**

Run:

```sh
make clean
make verify
git status --short --branch
```

Expected:

- lint passes
- tests pass
- package succeeds
- worktree status is clean except intentional uncommitted final fixes, if any

**Step 2: Review generated package**

Run:

```sh
find dist/SDCARD/WIDGETS/SoarF5J -type f | sort
```

Expected: all widget Lua files are present.

**Step 3: Commit final fixes**

If any final fixes were needed:

```sh
git add <changed-files>
git commit -m "Finalize F5J EdgeTX package"
```

**Step 4: Report manual verification gaps**

Do not claim radio behavior is verified unless it has been tested in EdgeTX Companion simulator or on the TX15. Report manual checks still needed.
