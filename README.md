# SoarF5J EdgeTX

F5J-only EdgeTX color-radio widget and model-template project for the Radiomaster TX15.

## Status

Early development. The first target is a TX15 SD-card package plus model-template documentation.

## Structure

- `src/SoarF5J/`: maintainable Lua source.
- `dist/WIDGETS/SoarF5J/`: SD-card widget package output.
- `models/reference/`: reference model archives used for migration.
- `models/tx15/`: TX15 model template artifacts.
- `docs/`: planned setup, emulator, and SD-card documentation.
- `tools/`: will contain local build, lint, packaging, and test helpers.
- `tests/`: will contain local Lua tests for pure modules and template validation.

## Verification

The intended verification interface is:

```sh
make lint
make test
make package
```

These commands will become available once local tooling lands in the next implementation step.
