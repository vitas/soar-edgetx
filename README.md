# SoarF5J EdgeTX

F5J-only EdgeTX color-radio widget and model-template project for the Radiomaster TX15.

## Status

Early development. The first target is a TX15 SD-card package plus model-template documentation.

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

## Documentation

- `docs/project-structure.md`: source layout and generated package output.
- `docs/sdcard-structure.md`: TX15 SD-card install layout.
- `docs/emulator.md`: local EdgeTX Companion simulator workflow.
- `docs/tx15-model-template.md`: committed TX15 template notes.
- `models/tx15/README.md`: TX15 template artifact notes.
