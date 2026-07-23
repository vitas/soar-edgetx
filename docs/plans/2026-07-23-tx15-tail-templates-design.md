# TX15 Tail Templates Design

Date: 2026-07-23

## Goal

Replace the single TX15 F5J template artifact with three named tail variants:
`tx15-MTail`, `tx15-VTail`, and `tx15-XTail`.

## Channel Layout

All variants must fit a standard 8-channel receiver without receiver output
remapping.

- Common channels: `CH1/CH2` ailerons, `CH3` motor, `CH4/CH5` flaps.
- `tx15-MTail`: keep the current conventional M-tail layout with `CH6` rudder,
  `CH7/CH8` elevator servos.
- `tx15-VTail`: use `CH7/CH8` as left/right V-tail outputs. `CH6` remains
  unused/centered.
- `tx15-XTail`: use `CH6` rudder and `CH7` single elevator. `CH8` remains
  unused/centered. The single elevator must not include the aileron-to-elevator
  mix.

## Artifact Layout

Commit one `.etx` archive per variant under `models/tx15/` and one exported
template YAML per variant under `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`.

Remove the old single-template artifact names from docs/tests so users pick a
tail variant explicitly.

## Verification

Template tests should validate that all three artifacts exist, assign the
`SoarF5J` widget pages, preserve shared F5J setup, and have the expected tail
channel mapping.
