# SoarF5J Widget Setup And Usage

This guide explains how to install, configure, and use the `SoarF5J` EdgeTX
widget on a Radiomaster TX15 or in the EdgeTX Companion simulator.

The setup pages are not standalone EdgeTX tool scripts. They are widget pages
loaded by `WIDGETS/SoarF5J/main.lua` through widget options.

## Build The SD Card Package

From the repo root:

```sh
make package
```

The generated SD-card root is:

```text
dist/SDCARD
```

The widget files are installed under:

```text
dist/SDCARD/WIDGETS/SoarF5J/
```

Copy the contents of `dist/SDCARD` to the TX15 SD-card root, or point the
EdgeTX Companion simulator SD Structure path at `dist/SDCARD`.

When updating an existing radio SD card, delete the old `WIDGETS/SoarF5J`
folder first, then copy the new one. This avoids stale compiled `.luac` files
or old widget code being left behind.

## Model Requirements

Use the committed TX15 template when possible:

```text
models/tx15/f5j_tmpl_t15.etx
```

The widget expects the model to provide the template structure:

- Flight modes, timers, logical switches, global variables, mixes, outputs,
  and curves used by the F5J setup pages.
- Curve 32, used by Lua for persistent model parameters such as the receiver
  battery warning threshold.
- Input `input8`, used as the step input for the curve setup pages.
- Named output channels. The output setup page only shows outputs whose
  channel name is not empty.
- Receiver battery telemetry, if battery display and warning should work.

If a setup page reports a missing input, curve, or output, the active model does
not match what that page needs. Start from the TX15 template or repair the
missing model item in Companion.

## Safety Preflight

Setup pages write changes to the active model immediately. Before using them:

- Work on a copy of the model until the setup is verified.
- Disconnect the motor or ESC during output, wing, airbrake, and camber setup.
- Verify channel order, direction, endpoints, and failsafe after setup.
- Test first in the simulator, then on the radio with the aircraft secured.

Do not rely only on a switch position as motor protection while editing outputs
or curves.

## Add The Widget

On the TX15 or in the EdgeTX simulator:

1. Open the F5J model.
2. Open screen/widget setup for the model.
3. Add a widget in the desired screen zone.
4. Select widget type `SoarF5J`.
5. Set widget option `Page` to the page you want to run.

`Page` is the only operator option. Older `FileName` text selection is not
used, because EdgeTX text widget options are too short for several full page
paths.

Page values:

```text
1  Competition
2  Switches
3  Mixes
4  Outputs
5  Wing alignment
6  Brake curves
7  Aileron/camber
8  Battery
```

The underlying file paths are:

```text
competition/widget
setup/switches
setup/mixes
setup/outputs
setup/wing_alignment
setup/brake_curves
setup/aileron_camber
setup/battery
```

The easiest bench workflow is to keep one `SoarF5J` widget on a setup screen
and change only its `Page` option when moving between setup pages. You can also
create multiple setup screens with separate `SoarF5J` widgets, each using a
different `Page`.

## Opening A Setup Page

Most setup pages first draw a title tile in the widget zone. Press `Enter` or
tap the widget to open the full setup UI.

Pages that can move controls or rewrite curves show a motor-disabled warning
prompt before editing starts. Close the prompt only after the motor is
physically safe.

Use the `X` button in the page header to exit full screen. Leaving a setup page
also clears temporary adjustment modes used by that page.

## Navigation

The shared GUI uses the normal EdgeTX virtual events:

- `Next` / `Prev`: move focus between controls.
- `Enter`: open a page, activate a button, start editing a number, or confirm.
- `Inc` / `Dec`: change the focused value while editing.
- `Exit`: leave the current edit control or nested prompt.
- Touch tap: select or activate the touched control.
- Touch slide: adjust sliders, scroll output rows, or edit slider-style values.

Number fields are written when changed. Buttons and toggles apply immediately.
There is no separate save button in the widget.

## Recommended Setup Order

1. Install the SD-card package and open the TX15 template model.
2. Add the main widget with `Page = 1`.
3. Add a setup widget or temporarily change the main widget `Page`.
4. Run `Page = 2` and confirm the physical switch assignments.
5. Run `Page = 4` with the motor disconnected.
6. Run `Page = 5` to align flaperon outputs and curves.
7. Run `Page = 6` to tune the flap and aileron airbrake curves.
8. Run `Page = 7` to set maximum reflex and related camber values.
9. Run `Page = 3` in each relevant flight mode.
10. Run `Page = 8` to set receiver battery warning level.
11. Return the contest widget to `Page = 1`.

## Setup Pages

### `setup/switches`

Assigns physical switch positions to the logical switches used by the model.
The page currently covers:

- Altitude voice reporting.
- Variometer sound.
- Speed flight mode.
- Float flight mode.
- Window time reports every 10 seconds.
- Altitude reports every 10 seconds.
- Launch mode, motor arm, and flight timer control.
- Start/stop timer and motor trigger.

Use the drop-down fields to select the desired physical switch position for
each function.

### `setup/outputs`

Configures named output channels.

This page can:

- Move a named output channel up or down. Moving a channel also swaps its mixer
  lines and channel-source references.
- Toggle output direction.
- Adjust output offset, range, lower endpoint, center, or upper endpoint.
- Show live output position indicators.

Only named output channels are shown. Name the channel in the model output page
if it does not appear.

### `setup/wing_alignment`

Aligns the four flaperon outputs:

- Left aileron.
- Left flap.
- Right flap.
- Right aileron.

Use the throttle stick to select one of the five curve points. Use the screen
sliders to adjust the selected point. The page writes to the flaperon curves and
the related output center/endpoints.

Use `Reset` only when you intentionally want to return the flaperon alignment
curves and endpoints to the page defaults.

### `setup/brake_curves`

Edits the airbrake flap and aileron curves.

Use the throttle stick to select one of the five curve points, then adjust the
flap and aileron sliders. The page writes to the flap and aileron airbrake
curves.

Use `Reset` only when you intentionally want to restore the default airbrake
curve shapes.

### `setup/aileron_camber`

Sets aileron travel and aileron-to-flap behavior around the maximum reflex
position.

Use the vertical slider to adjust the flaperon position. The page writes the
related global variables and temporarily enables the model adjustment mode while
editing. When the page exits, it restores the previous adjustment state.

The TX15 template uses the page's adjustment mode for these trim-button edits:
aileron trim adjusts `Ail`, rudder trim adjusts `AiF`, elevator trim adjusts
`CbA`, and throttle trim adjusts the thermal camber amount `GV10` / `CbX`.

### `setup/mixes`

Edits mix-related global variables for the current flight mode:

- Aileron to rudder.
- Aileron travel.
- Aileron to flap.
- Aileron differential.
- Brake to elevator.
- Snap flap.
- Camber to aileron.
- Battery warning level.

Some values are flight-mode specific. Select the flight mode first, then edit
the values for that mode.

While this page is open, the widget sets the model adjustment mode so the TX15
trim buttons can adjust the mix GVARs through the model's `ADJUST_GVAR` special
functions. Leaving the page restores the previous adjustment mode.

### `setup/battery`

Displays the current receiver battery value and edits the low-battery warning
threshold.

If the current battery reads `--.- V`, the widget has not found usable receiver
battery telemetry yet. The warning threshold can still be set.

## Competition Widget

Use:

```text
Page = 1
```

The competition widget shows:

- F5J state.
- Target or flight timer.
- Motor timer.
- Landing points.
- Start height.

The target time is read from Timer 1. If Timer 1 has no usable start value, the
widget falls back to 10 minutes.

Basic flow:

1. Arm or reset the flight using the model's configured arm control.
2. In the initial state, use `Inc` / `Dec` to adjust target time in one-minute
   steps if needed.
3. Start the motor using the model's launch/motor flight mode.
4. When the motor stops, the widget moves to glide timing.
5. The widget captures start height from `Alt+` after the F5J height window.
6. Press the configured trigger, `Enter`, or tap the widget to move through
   scoring fields.
7. Adjust landing points, start height, or time correction with `Inc` / `Dec`.
8. Confirm through the final scoring states with the trigger or `Enter`.

Restarting the motor after glide has started produces a zero result. The widget
does not save flight logs.

## Troubleshooting

`SoarF5J` is not in the widget list:

- Check that `WIDGETS/SoarF5J/main.lua` exists on the active SD card.
- Re-run `make package`.
- Confirm the simulator or radio is using the expected SD-card path.
- Restart the simulator or radio after changing SD-card contents.

The widget says to check settings:

- Confirm `Page` is set to the intended page number.
- Confirm the selected file exists under `WIDGETS/SoarF5J/`.

A setup screen still shows the competition timers:

- Confirm the widget on that screen has `Page` set to the setup page, for
  example `Page = 3` for Mixes or `Page = 5` for Wing alignment.
- Delete the old `WIDGETS/SoarF5J` folder from the SD card and copy the new
  package folder again.
- Restart the simulator/radio after copying a new `main.lua`; EdgeTX can keep
  the old widget Lua loaded until restart.
- Remove and add the widget again if the screen was created before this
  Page-only option layout existed.

The widget reports `Curve #32 is missing`:

- Use the TX15 template, or add curve 32 to the model before loading the
  widget.

A setup page reports missing `input8`, a curve, or an output:

- The active model does not match the setup page assumptions.
- Re-open the TX15 template or add the missing model item in Companion.

A setup page only shows its title tile:

- This is normal. Press `Enter` or tap the widget to open the full setup page.

Battery shows `--.- V`:

- Discover or configure the receiver battery telemetry sensor first.
- Confirm the sensor is visible to EdgeTX before relying on the warning.

Edits seem to affect the wrong flight mode:

- Many mix global variables are flight-mode specific. Select the desired flight
  mode before opening or editing the page.

After changing Lua files locally:

- Run `make package`.
- Restart the simulator/radio widget, or remove and add the widget again if the
  old Lua state remains loaded.
