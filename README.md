# SoarF5J EdgeTX

F5J-only EdgeTX color-radio widget and model-template project for the Radiomaster TX15.

## Status

Early development. The first target is a TX15 SD-card package plus model-template documentation.

## Structure

- `src/SoarF5J/`: maintainable Lua source.
- `dist/SDCARD/`: generated SD-card install root.
- `models/reference/`: reference model archives used for migration.
- `models/tx15/`: TX15 model template artifacts.
- `docs/`: planned setup, emulator, and SD-card documentation.
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

`make test` rebuilds the generated package before running tests because packaging checks compare `src/SoarF5J` with `dist/SDCARD/WIDGETS/SoarF5J`.
