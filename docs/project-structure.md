# Project Structure

This project is source-first. Edit Lua under `src/SoarF5J`; treat `dist/SDCARD` as generated install output.

## Top-Level Directories

- `src/SoarF5J/`: maintainable EdgeTX widget source.
- `dist/SDCARD/`: generated SD-card install root created by `make package`.
- `docs/`: design notes, implementation plans, install notes, and simulator documentation.
- `models/reference/`: external model archives or notes used for migration.
- `models/tx15/`: TX15 model-template artifacts or notes.
- `tests/`: local Lua tests for state logic, widget behavior, setup pages, and packaging checks.
- `tools/`: local linting and packaging scripts.

## Source And Package Output

Runtime Lua loads files from `/WIDGETS/SoarF5J/` on the radio SD card. In this repo that path is generated as:

```text
dist/SDCARD/WIDGETS/SoarF5J/
```

Run `make package` to rebuild it from `src/SoarF5J`.

Run `make clean` to remove generated SD-card output.

Run `make verify` before committing changes. It runs linting, rebuilds the package, and runs tests.

EdgeTX documents `WIDGETS` as the SD-card folder for widget files on color radios: https://manual.edgetx.org/color-radios/radio-settings/storage
