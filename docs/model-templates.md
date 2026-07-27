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
| 13-GVAR full family: `tx15-*` | RadioMaster TX15 | `.etx` archives under `models/tx15/` and matching SD-card YAML files. |
| 13-GVAR full family: `tx16s-mk3-*` | TX16S MK3 | SD-card YAML files under `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`. |

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

13-GVAR full TX16S MK3 artifacts:

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
centers, reversals, or setup-owned curve point values from a flown aircraft.
Those values should start at zero and be tuned on the actual model through the
setup pages and EdgeTX output checks.

## Current Control Assignments

Primary stick inputs are shared by the committed template families. Motor and
thermal camber source defaults are family-specific so TX16-class radios use the
side sliders by default. The `setup/switches` widget page can reassign rows
that use logical switches. Stick and trim names below are EdgeTX source names;
the physical stick or trim location depends on the radio stick mode.

### Physical Sources

| Control | Model name/source | Default assignment | What it does |
| --- | --- | --- | --- |
| `Rud` | `Rudder` / `I1:Rud` | Stick source `Rud` | Rudder/yaw input. On `VTail` it feeds the V-tail yaw mix instead of a separate rudder channel. |
| `Ele` | `Elev` / `I2:Ele` | Stick source `Ele` | Elevator/pitch input. |
| `Ail` | `Ailero` / `I3:Ail` | Stick source `Ail` | Aileron input, plus source for aileron-to-rudder and optional aileron-to-elevator mixes. |
| `Thr` | `Brake` / `I5:Brk` | Stick source `Thr` | Landing brake/crow control. |
| `Thr` | `Adjust` / `I8:Adj` | Stick source `Thr` | Setup-page adjustment source, used for live curve-point selection on wing and brake setup pages. |

### Template-Family Source Defaults

| Template family | Model input | Default assignment | What it does |
| --- | --- | --- | --- |
| `tx15-*` | `I4:Mot` | `P1` slider, inverted | Motor throttle source in the `Motor` flight mode. Outside `Motor`, the `Off` input line holds the motor at idle. |
| `tx15-*` | `I6:CbP` | `T3` trim source | Thermal camber position between maximum reflex and the configured camber amount. |
| `tx16s-*` | `I4:Mot` | `LS` left slider, inverted | TX16S/T16-class motor throttle source in the `Motor` flight mode. |
| `tx16s-*` | `I6:CbP` | `RS` right slider | TX16S/T16-class thermal camber position source. |
| `tx16s-mk3-*` | `I4:Mot` | `LS` left slider, inverted | TX16S MK3 motor throttle source in the `Motor` flight mode. |
| `tx16s-mk3-*` | `I6:CbP` | `RS` right slider | TX16S MK3 thermal camber position source. |

### Switch Setup Defaults

EdgeTX stores three-position switch positions as `0`, `1`, and `2`; this table
uses normal position names and also shows the raw template value.

| Logical switch | Switches page name | Default assignment | What it does |
| --- | --- | --- | --- |
| `L5` | Launch mode (Motor Arm) and flight timer control | `SA down` / `SA2` | Arms the launch/motor logic and is part of the flight-timer reset/control path. |
| `L9` | Start/Stop timer and Motor | `SE down` / `SE2` | Starts the motor/timer trigger path; internal logic keeps the motor sequence latched as needed. |
| `L1` | Allow vario and voice reporting of altitude | `SB down` / `SB2`, gated by flight timer `L19` | Enables the altitude voice/vario gate while the flight timer is active. |
| `L2` | Variometer sound | Not assigned (`NONE`), blocked while `SA down` | Drives the EdgeTX `VARIO` special function when assigned. |
| `L3` | Speed flight mode | `SD up` / `SD0` | Selects the `Speed` flight mode. |
| `L4` | Float flight mode | `SD down` / `SD2` | Selects the `Float` flight mode. |
| `L6` | Landing | `SF down` / `SF2`, blocked in `Motor` | Enables landing/crow mode and plays the landing voice prompt. |
| `L45` | Landing off / crow off | `SF up` / `SF0`, blocked in `Motor` | Leaves landing/crow mode and plays the crow-off voice prompt. The setup page also mirrors this assignment to the linked crow-off audio helper. |
| `L46` | Aileron -> Elevator | `MTail`: `SA up` / `SA0`; `VTail` and `XTail`: `NONE` | Enables the optional `AilEle` mix only on `MTail`. It is disabled in the V-tail and single-elevator templates. |
| `L7` | Model Timer 1 report every 10 sec. | `SC down` / `SC2` | Speaks Timer 1 every 10 seconds. |
| `L8` | Report current altitude every 10 sec. | `SB up` / `SB0`, gated by `L1` | Speaks current altitude every 10 seconds after the F5J height window has closed. |

Internal logical switches such as `L23`, `L24`, `L26`, `L35`, `L36`, `L37`,
and `L44` are model-state and audio helpers. Do not assign them directly from
the setup page unless you are intentionally editing the template logic.

### Flight Modes

| Flight mode | Switch | What it does |
| --- | --- | --- |
| `Cruise` | Default | Normal flight mode when no higher-priority mode is active. |
| `Adjust` | `L17` | Setup/adjustment mode used by the widget pages while editing model values. |
| `Motor` | `L26` | Launch/motor mode; enables the family-specific motor input line and Timer 2 motor timing. |
| `KAPOW` | `L32` | Launch/snap helper mode used by the template's internal launch logic. |
| `Speed` | `L3` | Speed flight mode, defaulted to `SD up`. |
| `Float` | `L4` | Float flight mode, defaulted to `SD down`. |

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

TX15 and TX16S MK3 templates use GV1 through GV13. The 9-GVAR compatible
family uses GV1 through GV9. GV10-GV13 are replaced by fixed mixer values so the
model can run on radios where Lua cannot read or write the extended global
variables.

| Extended value | 9-GVAR compatible family behavior |
| --- | --- |
| `GV10` / `CbX` thermal camber amount | Fixed at the current template amount. The family-specific camber source still drives the `CambPs` input. |
| `GV11` / `Elv` KAPOW elevator travel | Fixed at the current template amount. |
| `GV12` / `AiE` aileron-to-elevator | Fixed on `MTail`; disabled on `VTail` and `XTail`. |
| `GV13` / `FlD` flap differential | Fixed at neutral `0`. |

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
