# F5J EdgeTX Design

Date: 2026-06-05

## Goal

Create an F5J-only EdgeTX color-radio project for the Radiomaster TX15.
The project starts from the existing SoarETX color widget code and brings
over the missing F5J behavior from SoarOTX. It does not support black-and-
white radios and does not include F3K, F3J, F3RES, or F5K behavior.

The user wants a modular Lua codebase, shared helpers, widget-driven setup
screens, and F5J competition timing. A model wizard is not required for the
first version; a ready TX15 model template is acceptable.

## Source Material

- `/Users/vitas/Downloads/SoarETX` is the implementation starting point.
  It already contains color EdgeTX widget code and some F5J runtime logic.
- `/Users/vitas/Downloads/xlite_f5j.otx` is the Xlite Pro F5J model
  reference. It contains one model and references the SoarOTX F5J stack:
  `JF5Jsk`, `JFXJcf`, `JFgrph`, and `JFutil`.
- `https://github.com/jfrickmann/SoarOTX` is the behavioral reference for
  mature F5J timing and configuration flows.

SoarOTX and SoarETX-derived code use GPLv2 headers. The repository license
should be changed from Apache-2.0 to a GPL-compatible license before derived
source code is committed.

## Project Shape

The project should be a source-first Lua repo with installable SD-card output.

Proposed layout:

```text
src/SoarF5J/
  main.lua
  lib/
  pages/
  competition/
  setup/
dist/WIDGETS/SoarF5J/
models/reference/
models/tx15/
docs/
tools/
```

`src/SoarF5J` holds maintainable source. `dist/WIDGETS/SoarF5J` is generated
or copied install output for the EdgeTX SD card. `models/reference` may hold
the Xlite reference archive if the user wants it committed. `models/tx15`
will hold the TX15 model template once migrated.

## Architecture

The widget app should be F5J-specific rather than a generic soaring framework.
Shared helpers should remove duplicated EdgeTX and UI code, but they should
not preserve class-specific branching from SoarETX.

Core modules:

- `lib/gui.lua`: shared color widget UI primitives from SoarETX, reduced and
  cleaned up where needed.
- `lib/edgetx.lua`: wrappers for EdgeTX model, curve, sensor, switch, timer,
  and global-variable access.
- `lib/safety.lua`: motor-disabled prompts and checks used by setup pages
  that can move outputs or mixes.
- `competition/state.lua`: pure F5J state machine where possible.
- `competition/widget.lua`: runtime widget glue for timers, events, audio,
  telemetry reads, and screen refresh.
- `setup/*.lua`: focused pages for switches, mixes/GVs, outputs, wing
  alignment, brake curves, aileron/camber, and battery warning.

The runtime code should keep EdgeTX side effects at the edges. Pure or mostly
pure modules should be testable outside the radio.

## Model Template

The first version should use a TX15 model template instead of a model-creation
wizard. The Xlite `.otx` is a binary OpenTX model archive, so it should be used
as a migration reference rather than parsed as source code.

The TX15 template should capture:

- F5J flight modes, including launch/motor mode.
- Timers for flight and motor timing.
- Logical switches for altitude calls, motor arm, start/stop trigger, and
  setup helpers.
- Global variables used for mixes, timer control, setup adjustment, and battery
  warning.
- Curves for wing alignment and airbrake behavior.
- Mixes and outputs for a four-servo wing F5J model.
- Widget screen assignments/options for the SoarF5J pages.

If model migration cannot be made repeatable through Companion CLI, the repo
should document the manual Companion workflow and keep the template artifact
under version control.

## Competition Mode

Competition mode should implement F5J timing and safety behavior, not score
logging.

Required states:

- Initial: model is ready, timer target can be set.
- Motor: motor is running, motor timer is announced.
- Glide: flight timer runs, motor-off height window is active.
- Landing points: user enters landing points after stopping the flight.
- Start height: user can correct captured start height.
- Time correction: user can correct flight time.
- Finished/reset: user can reset for the next flight.

Required behavior:

- Motor arm resets altitude and prepares the flight.
- Motor flight mode starts motor timing and flight timing.
- Motor off starts the 10-second F5J height capture window.
- Start height is captured from altitude telemetry, with a safe default when no
  altimeter value exists.
- Remaining flight time is announced at sensible intervals.
- Restarting the motor after glide/landing forces a zero result state.
- No CSV flight log saving or score browser is required in the first version.

## Setup Pages

Setup pages should match the useful SoarOTX/SoarETX workflows for model tuning:

- Switch assignment page.
- Mix/GV page for adjustable F5J mix values.
- Output page with strong motor-disabled warning.
- Four-servo wing alignment page.
- Airbrake curve page.
- Aileron/camber or equivalent wing geometry page.
- Battery warning page.

Each page should be F5J-only and should use shared helpers for top bars,
close buttons, prompts, field labels, and model access.

## Error Handling

The app should fail visibly and locally on the radio when model assumptions are
not met. Examples:

- Missing curve or wrong number of curve points.
- Missing expected output curve assignment.
- Missing timer, logical switch, or telemetry source.
- Altimeter not discovered.
- Battery telemetry not discovered.

Setup pages that can move outputs or change curves should display motor safety
warnings before allowing edits.

## Testing And Verification

The repo should include linter support from the start, because repo
instructions require lint before declaring work complete.

Recommended local verification:

- Lua syntax check for every source file.
- Lua linting via `luacheck` or a small configured equivalent.
- Unit tests for pure state-machine behavior, score/timer calculations, CSV
  parsing if later reintroduced, and template-data validation.
- Packaging check that expected `dist/WIDGETS/SoarF5J` files exist.

Radio verification remains manual:

- Copy package to TX15 SD card.
- Load the TX15 model template.
- Confirm widget pages open.
- Confirm setup pages can edit GVs/curves/outputs.
- Confirm motor arm/start/stop/timer/height behavior with motor disabled first.

## Non-Goals For First Version

- No BW radio support.
- No F3K, F3J, F3RES, or F5K support.
- No model wizard.
- No flight CSV logging.
- No score browser.
- No LVGL-only dependency unless later needed.
- No attempt to parse `.otx` binary model archives as source.

## Open Decisions

- Whether to commit `/Users/vitas/Downloads/xlite_f5j.otx` into
  `models/reference`.
- Exact TX15 channel order and physical slider/switch mapping.
- Whether the final license should be GPL-2.0-only or GPL-2.0-or-later.
