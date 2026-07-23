# TX15 Model Templates

The committed TX15 templates are:

```text
models/tx15/tx15-MTail.etx
models/tx15/tx15-VTail.etx
models/tx15/tx15-XTail.etx
```

Each `.etx` archive currently contains:

```text
RADIO/radio.yml
MODELS/model1.yml
MODELS/f5j.txt
MODELS/labels.yml
```

These archives are the current TX15 EdgeTX template artifacts for this project.

## Tail Variants

All variants keep the same wing and motor channel layout:

```text
CH1/CH2  Ailerons
CH3      Motor
CH4/CH5  Flaps
```

Tail outputs:

```text
tx15-MTail  CH6 rudder, CH7/CH8 elevator servos
tx15-VTail  CH7/CH8 left/right V-tail, CH6 unused
tx15-XTail  CH6 rudder, CH7 elevator, CH8 unused
```

`tx15-VTail` puts the V-tail servos on `CH7/CH8`, leaving `CH6` centered and
unused. This keeps the template usable with a standard 8-channel receiver
without receiver output remapping.

`tx15-XTail` is for a conventional rudder plus one elevator servo. Its single
elevator output intentionally does not include the switchable
aileron-to-elevator mix.

Template artifacts must stay airframe-neutral: no copied output endpoints,
centers, reversals, or setup-owned curve point values from a flown aircraft.
Those values should start at zero and be tuned on the actual model through the
setup pages and EdgeTX output checks.

## Current Control Assignments

These defaults are shared by `tx15-MTail`, `tx15-VTail`, and `tx15-XTail`.
The `setup/switches` widget page can reassign the rows that use logical
switches. Stick and trim names below are EdgeTX source names; the physical
stick or trim location depends on the radio stick mode.

### Physical Sources

| Control | Model name/source | Default assignment | What it does |
| --- | --- | --- | --- |
| `Rud` | `Rudder` / `I1:Rud` | Stick source `Rud` | Rudder/yaw input. On `tx15-VTail` it feeds the V-tail yaw mix instead of a separate rudder channel. |
| `Ele` | `Elev` / `I2:Ele` | Stick source `Ele` | Elevator/pitch input. |
| `Ail` | `Ailero` / `I3:Ail` | Stick source `Ail` | Aileron input, plus source for aileron-to-rudder and optional aileron-to-elevator mixes. |
| `P1` | `mot` / `I4:Mot` | `P1` slider, inverted | Motor throttle source in the `Motor` flight mode. Outside `Motor`, the `Off` input line holds the motor at idle. |
| `Thr` | `Brake` / `I5:Brk` | Stick source `Thr` | Landing brake/crow control. |
| `T3` | `CambPs` / `I6:CbP` | Trim source `T3` | Thermal camber position between maximum reflex and the configured camber amount. Change this input source in Companion if you want camber on a switch. |
| `Thr` | `Adjust` / `I8:Adj` | Stick source `Thr` | Setup-page adjustment source, used for live curve-point selection on wing and brake setup pages. |

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
| `L46` | Aileron -> Elevator | `SA up` / `SA0` | Enables the `AilEle` mix on `tx15-MTail` and `tx15-VTail`; `tx15-XTail` leaves that mix disconnected. |
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
| `Motor` | `L26` | Launch/motor mode; enables the `P1` motor input line and Timer 2 motor timing. |
| `KAPOW` | `L32` | Launch/snap helper mode used by the template's internal launch logic. |
| `Speed` | `L3` | Speed flight mode, defaulted to `SD up`. |
| `Float` | `L4` | Float flight mode, defaulted to `SD down`. |

## TX15 Template Scope

The TX15 templates should define:

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

## Current Artifact Policy

Commit updated TX15 template artifacts under `models/tx15/` after they have
been created and checked in EdgeTX Companion or on the TX15. Also commit the
matching exported template YAML files under
`dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`.

For radio and simulator operation, including the required widget `Page` values,
setup-page workflow, and competition-widget usage, see
`docs/widget-setup-and-usage.md`.
