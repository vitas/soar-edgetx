# SoarF5J EdgeTX

F5J-only EdgeTX color-radio widget and model-template project for the Radiomaster TX15.

## Status

Early development. The first target is a TX15 SD-card package plus model-template documentation.

## What It Can Do

`SoarF5J` is an F5J-only EdgeTX color-radio widget for a TX15 model template.
It is not a general SoarOTX replacement and does not include F3K, F5K,
black-and-white radio support, or flight log saving.

The competition page can:

- Show the F5J contest state, target/flight timer, motor timer, landing points,
  start height, and current flight mode.
- Run the F5J launch, motor, glide, landing, and zero-result state flow.
- Capture start height from altitude telemetry after the motor-off height
  window.
- Force a zero result when the motor is restarted after launch.
- Sync the radio timers used by the template so normal EdgeTX timer voices and
  warnings can still be used.

The setup pages can:

- Assign the model switches used for launch, motor, timer, and flight controls.
- Edit flight-mode-specific mix global variables and battery warning level.
- Reorder named output channels while preserving their mixer lines.
- Align four-servo wing outputs and curves.
- Tune airbrake flap and aileron curves.
- Set aileron travel, aileron-to-flap, camber-to-aileron, and thermal camber
  values, including trim-button adjustment for `Ail`, `AiF`, `CbA`, and
  `GV10` / `CbX` in the TX15 template.
- Display receiver battery telemetry and configure the low-battery warning
  threshold.

The repository also provides:

- A TX15 EdgeTX model template under `models/tx15/`.
- A generated SD-card package under `dist/SDCARD/`.
- `make install-widget SDCARD=/path/to/card` for copying the current widget to
  a mounted radio SD card.

## Structure

- `src/SoarF5J/`: maintainable Lua source.
- `dist/SDCARD/`: TX15 SD-card root with generated SoarF5J widget output.
- `models/tx15/`: TX15 model template artifacts.
- `docs/`: project structure, emulator, TX15 template, setup, and SD-card documentation.
- `tools/`: local build, lint, packaging, and test helpers.
- `tests/`: local Lua tests for state modules, widgets, setup pages, and packaging checks.

## Verification

Run the full local gate with:

```sh
make verify
```

Individual targets are also available:

```sh
make lint
make package
make test
```

`make test` rebuilds the SoarF5J widget package before running tests because packaging checks compare `src/SoarF5J` with `dist/SDCARD/WIDGETS/SoarF5J`.

To rebuild the widget and install it onto a mounted SD card:

```sh
make install-widget SDCARD=/Volumes/TX15
```

`make sdcard SDCARD=/Volumes/TX15` is an alias. The target deletes the old
`WIDGETS/SoarF5J` folder first so stale Lua or `.luac` files are not kept.

## Documentation

- `docs/project-structure.md`: source layout and generated package output.
- `docs/sdcard-structure.md`: TX15 SD-card install layout.
- `docs/widget-setup-and-usage.md`: widget install, setup page, and competition usage guide.
- `docs/emulator.md`: local EdgeTX Companion simulator workflow.
- `docs/tx15-model-template.md`: committed TX15 template notes.
- `models/tx15/README.md`: TX15 template artifact notes.
