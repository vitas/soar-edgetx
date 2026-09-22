# SoarF5J EdgeTX

`SoarF5J` is an F5J package for EdgeTX landscape color radios. A single widget
covers the whole workflow:

- **Competition** - the F5J contest flow, from launch and motor run through
  glide timing, finish, and zero result.
- **Model setup** - a full in-radio setup UI for switches, outputs, wing
  alignment, brake curves, camber, and mixes, so a model can be configured from
  the radio screen without a PC or Companion.

The widget runs from the radio SD card. The active model template supplies the
flight modes, timers, logical switches, global variables, curves, mixes, and
named outputs that the widget reads or edits.

## Pages

`Page` is the only widget option; it selects the competition page or one of the
six setup pages.

| Page | Purpose |
| --- | --- |
| `1` | Competition: launch, motor, glide, finish, zero result, working-window voice, motor timer, and F5J start-height capture from `Alt+`. |
| `2` | Switches: assign physical switch positions to the model's logical switches. |
| `3` | Mixes: edit the mix global variables for the selected flight mode. |
| `4` | Outputs: reorder named outputs, reverse direction, and set offset, range, center, and endpoints. |
| `5` | Wing alignment: align the four flaperon outputs with the trims and on-screen sliders. |
| `6` | Brake curves: edit the airbrake flap and aileron curves. |
| `7` | Aileron/camber: aileron travel, aileron-to-flap, camber-to-aileron, and thermal camber around maximum reflex. |

Pages `2..7` are the setup UI. They write model changes immediately, so
disconnect the motor before output, wing, brake, or camber setup. Open a page
with `Enter` or a tap; the normal EdgeTX keys, trims, and touch gestures drive
the controls, and there is no separate save button. See [widget setup and
usage](docs/widget-setup-and-usage.md#setup-pages) for the full workflow.

## What To Configure

| Area | Configure | Details |
| --- | --- | --- |
| Template | Pick the correct tail template and wire outputs. | [model templates](docs/model-templates.md) |
| SD card | Install the widget package and custom sound prompts. | [SD-card structure](docs/sdcard-structure.md) |
| Widget | Add `SoarF5J` and choose `Page`. | [widget setup and usage](docs/widget-setup-and-usage.md) |
| Switches | Assign launch, motor, landing, voice, vario, and flight-mode switches on `Page = 2`. | [control assignments](docs/model-templates.md#current-control-assignments) |
| Model setup | Tune outputs, wing alignment, brake curves, camber, mixes, and battery warning on `Page = 3..7`. | [setup pages](docs/widget-setup-and-usage.md#setup-pages) |
| Simulator | Test layout and setup pages before using the radio. | [emulator workflow](docs/emulator.md) |

## Build And Verify

From the repo root:

```sh
make package
make verify
```

Install to a mounted SD card:

```sh
make install-widget SDCARD=/Volumes/TX15
```

Copy `dist/SDCARD` to the radio SD card, or point the Companion SD Structure
path at it, then add the `SoarF5J` widget and pick a `Page`.

## More Docs

- [project structure](docs/project-structure.md)
- [TX15 artifact notes](models/tx15/README.md)
