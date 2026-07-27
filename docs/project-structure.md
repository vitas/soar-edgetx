# Project Structure

This project is source-first for SoarF5J Lua. Edit Lua under `src/SoarF5J`;
treat `dist/SDCARD/WIDGETS/SoarF5J` as generated widget output inside the
committed EdgeTX landscape color-radio SD-card root.

## Top-Level Directories

- `src/SoarF5J/`: maintainable EdgeTX widget source.
- `dist/SDCARD/`: EdgeTX landscape color-radio SD-card root. Most files are static SD-card content; `WIDGETS/SoarF5J` is refreshed by `make package`.
- `docs/`: design notes, implementation plans, install notes, and simulator documentation.
- `models/`: radio-family-specific model-template artifacts. TX15 `.etx`
  archives currently live under `models/tx15/`.
- `tests/`: local Lua tests for state logic, widget behavior, setup pages, and packaging checks.
- `tools/`: local linting and packaging scripts.

## Source And Package Output

Runtime Lua loads files from `/WIDGETS/SoarF5J/` on the radio SD card. In this repo that path is generated as:

```text
dist/SDCARD/WIDGETS/SoarF5J/
```

Run `make package` to rebuild only `dist/SDCARD/WIDGETS/SoarF5J` from `src/SoarF5J`. Other SD-card folders are preserved.

Run `make clean` to remove the generated SoarF5J widget output.

Run `make verify` before committing changes. It runs linting, rebuilds the package, and runs tests.

EdgeTX documents `WIDGETS` as the SD-card folder for widget files on color radios: https://manual.edgetx.org/color-radios/radio-settings/storage
