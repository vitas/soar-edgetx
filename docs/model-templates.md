# Model Templates

Model templates provide the EdgeTX model structure that the `SoarF5J` widget
reads and edits: flight modes, timers, logical switches, global variables,
curves, mixes, outputs, telemetry names, and widget screen assignments.

Pick a template by GVAR capability, radio family, and tail type. The widget
code is shared across supported radios; the template family handles radio-
specific EdgeTX limits and artifact formats.

## Supported Template Families

| Family | Use on | Artifacts |
| --- | --- | --- |
| 9-GVAR compatible family: `tx16s-*` | TX16S, TX16S Mark II, T16/T18-class landscape color radios | SD-card YAML files under `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`. |
| 15-GVAR full family: `tx15-*` | RadioMaster TX15 | `.etx` archives under `models/tx15/` and matching SD-card YAML files. |
| 15-GVAR full family: `tx16s-mk3-*` | TX16S MK3 | SD-card YAML files under `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`. |

TX15 artifacts:

```text
models/tx15/tx15-MTail.etx
models/tx15/tx15-VTail.etx
models/tx15/tx15-XTail.etx
```

Each TX15 `.etx` archive currently contains:

```text
RADIO/radio.yml
MODELS/model1.yml
MODELS/f5j.txt
MODELS/labels.yml
```

9-GVAR compatible TX16S/T16-class artifacts:

```text
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-MTail.yml
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-VTail.yml
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-XTail.yml
```

15-GVAR full TX16S MK3 artifacts:

```text
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-mk3-MTail.yml
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-mk3-VTail.yml
dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx16s-mk3-XTail.yml
```

## Tail Variants

All template families use the same tail variant names.

| Variant | Tail outputs |
| --- | --- |
| `MTail` | `CH6` rudder, `CH7/CH8` elevator servos. |
| `VTail` | `CH7/CH8` left/right V-tail, `CH6` unused. |
| `XTail` | `CH6` rudder, `CH7` elevator, `CH8` unused. |

`VTail` puts the V-tail servos on `CH7/CH8`, leaving `CH6` centered and unused.
This keeps the template usable with a standard 8-channel receiver without
receiver output remapping.

The V-tail servos mix two virtual channels. `CH18` `Rudd` carries the rudder
stick plus the `AilRud` aileron-to-rudder mix (`GV3` / `AiR`). `CH19` `Elev`
carries the elevator stick plus the elevator compensation from `CH22`. `CH7`
gets 50% of `CH18` minus 50% of `CH19`, and `CH8` gets 50% of both, so rudder
moves the two servos the same way and elevator moves them in opposite
directions. Each servo gets half of the rudder and elevator travel; set the
throws with the output endpoints.

`XTail` is for a conventional rudder plus one elevator servo. Its single
elevator output intentionally does not include the switchable aileron-to-
elevator mix.

## Channel Layout

All variants keep the same wing and motor channel layout:

```text
CH1/CH2  Ailerons
CH3      Motor
CH4/CH5  Flaps
```

Template artifacts must stay airframe-neutral: no copied output endpoints,
centers, reversals, or curve-point tuning from a flown aircraft. The wing
alignment curves CV1 through CV4 start with the linear sequence
`-100, -50, 0, 50, 100`. The brake curves CV5 `BrF`, CV6 `BrA`, and CV14 `BrE`
start at the brake page `Reset` values, so the ailerons sit at center and the
elevator gets no compensation with brakes off. Tune them for the actual model
through the setup pages and EdgeTX output checks.

## Current Control Assignments

Primary stick inputs are shared by the committed template families. Motor uses
the throttle stick on every family; thermal camber source defaults remain
family-specific. The `setup/switches` widget page can reassign rows that use
logical switches. Stick and trim names below are EdgeTX source names; the
physical stick or trim location depends on the radio stick mode.

### Physical Sources

| Control | Model name/source | Default assignment | What it does |
| --- | --- | --- | --- |
| `Rud` | `Rudder` / `I1:Rud` | Stick source `Rud` | Rudder/yaw input. On `VTail` it feeds the virtual rudder channel `CH18` that drives both V-tail servos instead of a separate rudder channel. On `MTail` it also feeds the optional rudder-to-elevator mix. |
| `Ele` | `Elev` / `I2:Ele` | Stick source `Ele` | Elevator/pitch input. |
| `Ail` | `Ailero` / `I3:Ail` | Stick source `Ail` | Aileron input, plus source for aileron-to-rudder and optional aileron-to-elevator mixes. |
| `Thr` | `Brake` / `I5:Brk` | Stick source `Thr`, inverted | Landing brake/crow control. |
| `Thr` | `Adjust` / `I8:Adj` | Stick source `Thr`, inverted | Setup-page adjustment source, used for live curve-point selection on wing and brake setup pages. |

### Template-Family Source Defaults

| Template family | Model input | Default assignment | What it does |
| --- | --- | --- | --- |
| `tx15-*` | `I4:Mot` | `Thr` stick, inverted | Motor throttle source in the `Motor` flight mode. Outside `Motor`, the `Off` input line holds the motor off. |
| `tx15-*` | `I6:CbP` | `T3` trim source | Thermal camber position between maximum reflex and the configured camber amount. |
| `tx16s-*` | `I4:Mot` | `Thr` stick, inverted | TX16S/T16-class motor throttle source in the `Motor` flight mode. |
| `tx16s-*` | `I6:CbP` | `T3` trim source | TX16S/T16-class thermal camber position source. The physical trim depends on the radio stick mode. |
| `tx16s-mk3-*` | `I4:Mot` | `Thr` stick, inverted | TX16S MK3 motor throttle source in the `Motor` flight mode. |
| `tx16s-mk3-*` | `I6:CbP` | `T3` trim source | TX16S MK3 thermal camber position source. The physical trim depends on the radio stick mode. |

Pilots who prefer a pot or side slider can remap `I4:Mot` after importing the
template. Enable the control in radio hardware settings first, then check the
servo monitor with the motor disconnected.

### Switch Setup Defaults

EdgeTX stores three-position switch positions as `0`, `1`, and `2`; this table
uses normal position names and also shows the raw template value.

`NONE` on the Switches page turns a function off. EdgeTX treats an empty switch
as always on, so the templates and the page store `NONE` as the always-off
source `!ON`; `L48`, for example, is stored as `"!ON,NONE"`. Select `ON` on the
Switches page to keep a function on without a physical switch.

| Logical switch | Switches page name | Default assignment | What it does |
| --- | --- | --- | --- |
| `L5` | Launch mode (Motor Arm) and flight timer control | `SA down` / `SA2` | Arms the launch/motor logic and is part of the flight-timer reset/control path. |
| `L9` | Start/Stop timer and Motor | `SE down` / `SE2` | Start/stop trigger for the motor/timer path. Use a brief down-up switch action; a spring-loaded momentary switch is optional. |
| `L1` | Allow vario and voice reporting of altitude | `SB down` / `SB2`, gated by flight timer `L19` | Enables the altitude voice/vario gate while the flight timer is active. |
| `L2` | Variometer sound | Not assigned (`NONE`), blocked while `SA down` | Drives the EdgeTX `VARIO` special function. It is off until you assign a switch or select `ON`. |
| `L3` | Speed flight mode | `SD up` / `SD0` | Selects the `Speed` flight mode. |
| `L4` | Float flight mode | `SD down` / `SD2` | Selects the `Float` flight mode. |
| `L6` | Landing | `SF down` / `SF2`, blocked in `Motor` | Enables landing/crow mode and plays the landing voice prompt. |
| `L45` | Landing off / crow off | `SF up` / `SF0`, blocked in `Motor` | Leaves landing/crow mode and plays the crow-off voice prompt. The setup page also mirrors this assignment to the linked crow-off audio helper. |
| `L46` | Aileron -> Elevator | `MTail`: `SA up` / `SA0`; `VTail` and `XTail`: `NONE` | Enables the optional `AilEle` mix only on `MTail`. It is disabled in the V-tail and single-elevator templates. |
| `L48` | Rudder -> Elevator | Not assigned (`NONE`) | Enables the optional `RudEle` mix only on `MTail`. It is off until you assign a physical switch on the Switches page or select `ON`. |
| `L7` | Model Timer 1 report every 10 sec. | `SC down` / `SC2` | Speaks Timer 1 every 10 seconds. |
| `L8` | Report current altitude every 10 sec. | `SB up` / `SB0`, gated by `L1` | Speaks current altitude every 10 seconds after the F5J height window has closed. |

Internal logical switches such as `L23`, `L24`, `L26`, `L35`, `L36`, `L37`,
`L44`, `L49`, and `L50` are model-state, audio, and setup helpers. Do not assign them
directly from the setup page unless you are intentionally editing the template
logic.

Default launch sequence: arm with `SA down`, flick `SE down` and back, then
control motor power with the throttle stick. Holding `SE down` is also part of
the stop path, so do not leave it down after starting. The default `SE`
assignment is a manual stand-in for the original momentary trigger behavior; if
the radio has a spring-loaded momentary switch, assign `L9` to that switch for a
better launch workflow.

### Flight Modes

| Flight mode | Switch | What it does |
| --- | --- | --- |
| `Cruise` | Default | Normal flight mode when no higher-priority mode is active. |
| `Adjust` | `L17` | Setup/adjustment mode used by the widget pages while editing model values. |
| `Motor` | `L26` | Launch/motor mode; enables the family-specific motor input line and Timer 2 motor timing. |
| `KAPOW` | `L32` | Launch/snap helper mode used by the template's internal launch logic. |
| `Speed` | `L3` | Speed flight mode, defaulted to `SD up`. |
| `Float` | `L4` | Float flight mode, defaulted to `SD down`. |

### Motor Idle

In the `Motor` flight mode, `I4:Mot` takes the throttle stick through curve
CV9 `Mot`, and `CH3` adds curve CV13 `Pot` to it. CV13 has three points, `37`,
`18`, and `0` by default: it lifts minimum throttle by `37` and leaves full
throttle alone, so its first point is the motor idle. At `0` the motor stops at
minimum throttle. Outside `Motor`, `CH3` holds the motor off.

The Motor setup page (`Page = 8`) sets the idle with the throttle trim while the
motor runs. `L49` is on while `GV8` is above `50`, and `SF39` then adjusts
`GV8` with the throttle trim `T3` instead of moving the trim. The page holds
`GV8` at `100` while it is open, turns each click into an idle step, and
restores `GV8` when it closes. In normal flying `GV8` stays below `50`, so
`L49` and `SF39` stay off.

### Brake Elevator Compensation

`CH22 EleM` adds the elevator compensation for the airbrakes. Its `BrkEle` mix
takes the brake channel `CH21` through curve CV14 `BrE`, with weight and offset
`GV5` / `BkE`, so the compensation is `BkE x (1 + BrE / 100)`. CV14 starts at
`50, 0, -50, -75, -100`: no compensation with brakes off, `BkE` at three
quarters brake, and `1.5 x BkE` at full brake, the same as when the
compensation followed the flap curve CV5. `BkE` sets the amount for each flight
mode; CV14 sets how it builds up along the brake travel.

The Airbrake curves page (`Page = 6`) edits CV14 with the elevator trim. While
it is open it holds `GV8` at `-100`: `L50` is on while `GV8` is below `-50`, and
`SF40`, `SF41`, and `SF42` then adjust `GV8` with the throttle trim `T3`, the
aileron trim `T4`, and the elevator trim `T2` instead of moving them. The page
reads the trim buttons, clears `GV8`, and restores it when it closes.

### M-tail Elevator Mixes

`MTail` drives the two elevator servos from `CH7` and `CH8`. Two optional
differential mixes are available on those channels and are active in `Cruise`,
`Speed`, and `Float`:

| Mix | Amount | Enable switch | Default assignment |
| --- | --- | --- | --- |
| `AilEle` aileron to elevator | `GV12` / `AiE`, default `20` | `L46` | `MTail`: `SA up` / `SA0`; `VTail` and `XTail`: `NONE` |
| `RudEle` rudder to elevator | `GV14` / `RuE`, default `20` | `L48` | Not assigned (`NONE`) |

`CH8` uses the negated amount (`!gv(12)` / `!gv(14)`) so the two mirrored
elevator servos move together. The 9-GVAR compatible family replaces both
amounts with the fixed values `20` and `-20`. `VTail` and `XTail` do not use
either mix.

`AilEle` also has an elevator differential, `GV15` / `ElD`, default `50`. It
reduces the travel of the elevator half that moves down during a roll: at `50`
the down-going half moves half as far as the up-going half, `0` moves both
halves the same amount, and a negative value reduces the up-going half instead.
Both `AilEle` lines use the same differential (`!gv(15)`), because EdgeTX
applies the differential after the negated `CH8` weight. The 9-GVAR compatible
family uses the fixed differential `-50`, the same as `ElD` = `50`. `RudEle`
has no differential.

## Template Contract

Every supported template family should define:

- Flight modes.
- Timers.
- Logical switches.
- Global variables.
- Curves.
- Mixes.
- Outputs.
- Widget screen assignments.

Manual Companion editing is acceptable until a repeatable model export path
exists.

## GVAR Capability Limits

TX15 and TX16S MK3 templates use GV1 through GV15. The 9-GVAR compatible
family uses GV1 through GV9. GV10-GV15 are replaced by fixed mixer values so the
model can run on radios where Lua cannot read or write the extended global
variables.

| Extended value | 9-GVAR compatible family behavior |
| --- | --- |
| `GV10` / `CbX` thermal camber amount | Fixed at the current template amount. The family-specific camber source still drives the `CambPs` input. |
| `GV11` / `Elv` KAPOW elevator travel | Fixed at the current template amount. |
| `GV12` / `AiE` aileron-to-elevator | Fixed on `MTail`; disabled on `VTail` and `XTail`. |
| `GV13` / `FlD` flap differential | Fixed at neutral `0`. |
| `GV14` / `RuE` rudder-to-elevator | Fixed on `MTail`; disabled on `VTail` and `XTail`. |
| `GV15` / `ElD` elevator differential | Fixed at `50` on `MTail`; not used on `VTail` and `XTail`. |

Setup page fields that belong to unsupported extended GV values show `N/A` on
9-GVAR compatible radios instead of editing the model.

## Artifact Policy

Commit updated radio-family artifacts after they have been created and checked
in EdgeTX Companion or on the target radio.

For TX15, commit the `.etx` archives under `models/tx15/` and the matching
exported YAML files under `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`.

For YAML-only radio families, commit the YAML files directly under
`dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`. Do not create `.etx` archives for a radio
family until they can be exported from that radio or a matching Companion
profile.

For radio and simulator operation, including the required widget `Page` values,
setup-page workflow, and competition-widget usage, see
`docs/widget-setup-and-usage.md`.
