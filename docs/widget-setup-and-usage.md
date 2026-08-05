# SoarF5J Widget Setup And Usage

This guide explains how to install, configure, and use the `SoarF5J` EdgeTX
widget on supported EdgeTX landscape color radios or in the EdgeTX Companion
simulator.

The setup pages are not standalone EdgeTX tool scripts. They are widget pages
loaded by `WIDGETS/SoarF5J/main.lua` through widget options.

## Supported Screens

The widget is intended for EdgeTX landscape color-radio screens at:

```text
480x272
480x320
800x480
```

Radios with those screen sizes should work when the active model provides the
required F5J template structure. The widget code uses EdgeTX screen dimensions
and widget-zone dimensions rather than a radio board name. Manual
radio/simulator testing is currently limited to TX15 and T16/TX16S-class
radios.

Portrait color screens and monochrome radios are not currently supported.

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

Copy the contents of `dist/SDCARD` to the radio SD-card root, or point the
EdgeTX Companion simulator SD Structure path at `dist/SDCARD`.

When updating an existing radio SD card, delete the old `WIDGETS/SoarF5J`
folder first, then copy the new one. This avoids stale compiled `.luac` files
or old widget code being left behind.

## Model Requirements

Select a template that matches the radio's GVAR capability, radio family, and
tail type. TX15 users can use the committed `.etx` archives:

```text
models/tx15/tx15-MTail.etx
models/tx15/tx15-VTail.etx
models/tx15/tx15-XTail.etx
```

Choose the variant by tail type:

```text
tx15-MTail  CH6 rudder, CH7/CH8 elevator servos
tx15-VTail  CH7/CH8 left/right V-tail, CH6 unused
tx15-XTail  CH6 rudder, CH7 elevator, CH8 unused
```

9-GVAR compatible TX16S/T16-class users can use the matching SD-card YAML
template:

```text
tx16s-MTail.yml
tx16s-VTail.yml
tx16s-XTail.yml
```

13-GVAR full TX16S MK3 users can use the matching SD-card YAML template:

```text
tx16s-mk3-MTail.yml
tx16s-mk3-VTail.yml
tx16s-mk3-XTail.yml
```

All variants keep `CH1/CH2` for ailerons, `CH3` for motor, and `CH4/CH5` for
flaps. `VTail` uses `CH7/CH8` for the V-tail so an 8-channel receiver can be
wired without receiver remapping. `XTail` has no aileron-to-elevator mix on the
single elevator output.

The templates start with neutral output endpoints, centers, and reversals.
CV1 through CV6 start linear at `-100, -50, 0, 50, 100`; tune those curves for
the actual airframe during wing alignment and brake curve setup.

The widget expects the model to provide the template structure:

- Flight modes, timers, logical switches, global variables, mixes, outputs,
  and curves used by the F5J setup pages.
- Curve 32, used by Lua for persistent model parameters such as the receiver
  battery warning threshold.
- Input `input8`, used as the step input for the curve setup pages.
- Named output channels. The output setup page only shows outputs whose
  channel name is not empty.
- Receiver battery telemetry, if low-battery warning should work.

If a setup page reports a missing input, curve, or output, the active model does
not match what that page needs. Start from a compatible F5J template for your
radio, or repair the missing model item in Companion.

## Safety Preflight

Setup pages write changes to the active model immediately. Before using them:

- Work on a copy of the model until the setup is verified.
- Disconnect the motor or ESC during output, wing, airbrake, and camber setup.
- Verify channel order, direction, endpoints, and failsafe after setup.
- Test first in the simulator, then on the radio with the aircraft secured.

Do not rely only on a switch position as motor protection while editing outputs
or curves.

## Add The Widget

On the radio or in the EdgeTX simulator:

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

The shared GUI uses the normal EdgeTX virtual events. EdgeTX sends these events
to widgets only in full-screen mode, so open the widget full-screen before using
the keys below:

- `Next` / `Prev`: move focus between controls.
- `Enter`: open a page, activate a button, start editing a number, or confirm.
- `Inc` / `Dec`: change the focused value while editing.
- `Exit`: leave the current edit control or nested prompt.
- Touch tap: select or activate the touched control.
- Touch slide: adjust sliders, scroll output rows, or edit slider-style values.

Number fields are written when changed. Buttons and toggles apply immediately.
There is no separate save button in the widget.

## Recommended Setup Order

1. Install the SD-card package and open a compatible F5J template model.
2. Add the main widget with `Page = 1`.
3. Add a setup widget or temporarily change the main widget `Page`.
4. Run `Page = 2` and confirm the physical switch assignments.
5. Run `Page = 4` with the motor disconnected.
6. Run `Page = 5` to align flaperon outputs and curves.
7. Run `Page = 6` to tune the flap and aileron airbrake curves.
8. Run `Page = 7` to set maximum reflex and related camber values.
9. Run `Page = 3` in each relevant flight mode and set receiver battery warning level.
10. Return the contest widget to `Page = 1`.

## Setup Pages

### `setup/switches`

Assigns physical switch positions to the logical switches used by the model.
The page currently covers:

- Launch mode, motor arm, and flight timer control.
- Start/stop timer and motor trigger.
- Altitude voice reporting.
- Variometer sound.
- Speed flight mode.
- Float flight mode.
- Landing.
- Landing off / crow off.
- Aileron to elevator mix enable, for templates that use that mix.
- Optional model Timer 1 reports every 10 seconds.
- Altitude reports every 10 seconds.

Use the drop-down fields to select the desired physical switch position for
each function. The current defaults are listed in `docs/model-templates.md`.
Select `NONE` when a function should be disabled or should not be assigned to
any physical switch.

The committed templates default motor arm to `SA down`. TX15 templates use
`P1` for motor control; TX16-family templates use the `P2` pot. `MTail`
defaults the aileron to elevator mix enable switch to `SA up`. `VTail` and
`XTail` default that switch to `NONE` and do not use the aileron-to-elevator
mix.

If `P1`, `S1`, or `S2` is used for motor control, configure that pot as a
slider in the radio settings first when the radio supports that hardware option.
The committed TX15 `.etx` archives already set `P1` as an inverted slider named
`mot`; YAML-only template families do not change radio hardware settings. Check
the live motor channel with the motor disconnected: if turning the pot clockwise
moves the channel from minimum to maximum throttle in the wrong direction for
your ESC setup, reverse that pot in the radio settings before connecting the
motor.

`tx16s-*` templates use internal multimodule RF with 8 channels by default so
they import cleanly in the TX16S simulator and work with a standard 8-channel
receiver. `tx16s-mk3-*` templates keep Crossfire RF with 16 channels. Change
the RF module setup on the model setup page after import if your radio hardware
or receiver setup is different.

The distributed TX16-family YAML uses `P2` and `T3` because those raw sources
survive Companion import. Pilots who prefer the TX16 side sliders can remap
`I4:Mot` from `P2` to `LS` and `I6:CbP` from `T3` to `RS` after import. First
check that `LS` and `RS` are enabled in the radio hardware settings; otherwise
Companion may clear those input sources on reload.

Default launch/motor operation is `SA down` to arm, then a brief down-up action
on `SE` to start or stop the motor/timer latch. A spring-loaded momentary
switch is optional; when using a normal switch, return it after the trigger.
`SE` is the default manual stand-in for the original momentary trigger behavior;
if the radio has a spring-loaded momentary switch, assign `L9` to that switch
for a better launch workflow. Motor power then comes from the family motor
source (`P1` on TX15, `P2` on TX16-family YAML templates).

To use the throttle stick for motor control only during the launch phase,
change the motor input source instead of changing the launch switch logic:

1. Disconnect the motor or remove the propeller.
2. Open the model's **Inputs** page.
3. Edit `I4:Mot`, line `On`.
4. Change the source from the family default (`P1` or `P2`) to `Thr`.
5. Keep this `On` line enabled only in the `Motor` flight mode.
6. Leave the `Off` line as `MAX -100`.
7. Check the servo monitor before connecting the motor again.

With the launch/motor switch off, the motor channel must stay at idle. With the
launch/motor switch on, the throttle stick should drive the motor channel. When
the model leaves the launch/motor flight mode, the motor input is disabled and
the throttle stick remains available for landing/brake control.

The committed templates default the altitude voice/vario gate `L1` to `SB down`
and the 10-second altitude report `L8` to `SB up`, gated by `L1`. The
competition widget reads `L8` during glide and calls the current `Alt` telemetry
value every 10 seconds after the F5J height window has closed.

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

Use the throttle stick to select one of the five curve points. Throttle trim
moves the flap pair up/down, and elevator trim moves the aileron pair up/down.
Rudder trim aligns the left/right flap pair, and aileron trim aligns the
left/right aileron pair. The screen sliders can still adjust individual
surfaces. The page writes to the flaperon curves and the related output
center/endpoints.

Use `Reset` only when you intentionally want to return the flaperon alignment
curves and endpoints to the page defaults.

### `setup/brake_curves`

Edits the airbrake flap and aileron curves.

Use the throttle stick to select one of the five curve points. Throttle trim
adjusts the flap landing curve, and elevator trim adjusts the aileron landing
curve. The flap and aileron sliders on the screen still work. While editing is
enabled, the page turns on the model step switch so the surfaces move live with
the selected curve point.

`I5:Brk` and `I8:Adj` must use the same input direction. The templates invert
both throttle-stick inputs so the point selected during setup is the point used
at that stick position in flight. On an existing model, set the `Adjust` input
weight to `-100` if it is still `100`.

Use `Reset` only when you intentionally want to restore the default airbrake
curve shapes.

### `setup/aileron_camber`

Sets aileron travel, aileron-to-flap behavior, camber-to-aileron coupling, and
thermal camber around the maximum reflex position.

Use the vertical slider to set maximum reflex. In normal flying, the templates
drive thermal camber through `I6:CbP`. TX15 templates default that input to
`T3`; TX16-family templates also default it to `T3` for Companion import
compatibility. On Mode 2 radios `T3` is commonly the throttle trim, but the
physical trim depends on the radio's stick mode. Moving the configured camber
source changes how much thermal camber is applied between maximum reflex and
the configured camber amount. The page writes the related global variables and
temporarily enables the model adjustment mode while editing. When the page
exits, it restores the previous adjustment state.

13-GVAR full templates use the page's adjustment mode for these trim-button
edits: aileron trim adjusts `Ail`, rudder trim adjusts `AiF`, elevator trim
adjusts `CbA`, and `T3` adjusts the thermal camber amount `GV10` / `CbX`.

9-GVAR compatible templates keep only GV1 through GV9. Controls backed by
GV10-GV13 are fixed in the template and show `N/A` in setup pages on radios
that do not expose those extended values to Lua.

To put thermal camber selection on a switch instead, edit the model in Companion
and change the `CambPs` input source from `T3` to the desired physical or
logical switch. Use weight/offset or a curve if the switch positions need
specific camber percentages. This is a model-template change, not a Lua widget
setting.

### `setup/mixes`

Edits mix-related global variables for the current flight mode:

- Aileron to rudder.
- Aileron travel.
- Elevator travel.
- Aileron to flap.
- Aileron to elevator. This is used by TX15 MTail and VTail; XTail
  intentionally leaves it disconnected from the single elevator output.
- Aileron differential.
- Flap differential for the aileron-to-flap path.
- Brake to elevator.
- Snap flap.
- Battery warning level.

Some values are flight-mode specific. Select the flight mode first, then edit
the values for that mode.

While this page is open, the widget sets the model adjustment mode so the
template's trim buttons can adjust the mix GVARs through the model's
`ADJUST_GVAR` special functions. Leaving the page restores the previous
adjustment mode.

## Competition Widget

Use:

```text
Page = 1
```

The competition widget shows:

- F5J state.
- Target or flight timer.
- Motor timer.
- Maximum launch altitude.

The working-window target time is read from Timer 1. EdgeTX shows this as
`Timer 1` in the model setup, while Lua accesses it as timer index `0`. If
Timer 1 has no usable start or current value, the widget falls back to 10
minutes.

To change the working window in the emulator or on the radio, keep the widget in
the `Ready` state and change Timer 1 `Start`; that is the configured model
default. The current Timer 1 value is treated as runtime countdown state and is
not used to change the target when a start value exists, so a stale remaining
time cannot become the next working window. To use the widget `Inc` / `Dec`
controls, first open the competition widget full-screen; EdgeTX does not send
those key events to the normal main-view widget after radio startup.

To reset the working-window timer back to the target time, use the model's arm
or reset control while the widget is on the competition page. After a flight,
press the trigger or `Enter` once to finish timing, then press it again from the
`Finished` or `Zero result` state to reset for the next flight.

During glide, the widget announces the remaining working-window time using this
schedule: minute boundaries above 2 minutes, 15-second boundaries from 2 minutes
to 1 minute, 5-second boundaries from 1 minute to 10 seconds, then every second
from 10 to 1. Values above 10 seconds use the normal duration voice; the final
10..1 countdown uses plain number voice calls.

During the 30-second motor run, the widget announces elapsed time at 10 and 15
seconds. From 20 seconds elapsed, it counts down the remaining motor time every
second from 10 to 1 using plain number voice calls.

Basic flow:

1. Arm or reset the flight using the model's configured arm control.
2. In the initial state, open the widget full-screen and use `Inc` / `Dec` to
   adjust target time in one-minute steps if needed.
3. Start the motor using the model's launch/motor flight mode.
4. When the motor stops, the widget moves to glide timing.
5. The widget tracks maximum altitude from `Alt+` during motor run and for 10
   seconds after motor-off.
6. Press the configured trigger, `Enter`, or tap the widget to finish timing.
7. Press the trigger or `Enter` again from the finished state to reset for the
   next flight.

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

- Use a compatible F5J template, or add curve 32 to the model before loading the
  widget.

A setup page reports missing `input8`, a curve, or an output:

- The active model does not match the setup page assumptions.
- Re-open a compatible F5J template or add the missing model item in Companion.

A setup page only shows its title tile:

- This is normal. Press `Enter` or tap the widget to open the full setup page.

Edits seem to affect the wrong flight mode:

- Many mix global variables are flight-mode specific. Select the desired flight
  mode before opening or editing the page.

After changing Lua files locally:

- Run `make package`.
- Restart the simulator/radio widget, or remove and add the widget again if the
  old Lua state remains loaded.
