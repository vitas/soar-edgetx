# SoarF5J EdgeTX

`SoarF5J` is an F5J contest widget and TX15/TX16S model-template package for
EdgeTX landscape color radios.

The widget runs from the radio SD card. The active model template supplies the
flight modes, timers, logical switches, global variables, curves, mixes, and
named outputs that the widget reads or edits.

## How It Works

- Copy `dist/SDCARD` to the radio SD card, or use it as the Companion SD
  Structure folder.
- Use one tail template: `tx15-*` for TX15, or `tx16s-*` from the SD-card
  templates folder for TX16S/T16-class radios.
- Add the `SoarF5J` widget to a model screen.
- Set widget `Page = 1` for the contest page. Pages `2..7` are setup pages.
- The contest page handles launch, motor, glide, finish, zero result, working
  window voice, motor timer, and F5J start-height capture from `Alt+`.
- Setup pages write model changes immediately, so disconnect the motor before
  output, wing, brake, or camber setup.

## What To Configure

| Area | Configure | Details |
| --- | --- | --- |
| Template | Pick the correct tail template and wire outputs. | [model templates](docs/model-templates.md) |
| SD card | Install the widget package and custom sound prompts. | [SD-card structure](docs/sdcard-structure.md) |
| Widget | Add `SoarF5J`, choose `Page`, and use the competition flow. | [widget setup and usage](docs/widget-setup-and-usage.md) |
| Switches | Confirm launch, motor, landing, voice, vario, and flight-mode switches. | [control assignments](docs/model-templates.md#current-control-assignments) |
| Model setup | Tune outputs, wing alignment, brake curves, camber, mixes, and battery warning. | [setup pages](docs/widget-setup-and-usage.md#setup-pages) |
| Simulator | Test layout and setup pages before using the radio. | [emulator workflow](docs/emulator.md) |

## Build And Verify

```sh
make package
make verify
```

Install to a mounted SD card:

```sh
make install-widget SDCARD=/Volumes/TX15
```

## More Docs

- [project structure](docs/project-structure.md)
- [TX15 artifact notes](models/tx15/README.md)
