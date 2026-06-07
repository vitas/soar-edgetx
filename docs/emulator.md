# Emulator And Simulator Workflow

## Local Applications

Observed on this machine:

- EdgeTX Companion 2.10: `/Applications/EdgeTX Companion 2.10.app`
- EdgeTX Companion 2.12: `/Applications/EdgeTX Companion 2.12.app`
- OpenTX Companion 2.3: `/Applications/OpenTX Companion 2.3.app`

The planned EdgeTX Companion 2.11 path, `/Applications/EdgeTX Companion 2.11.app`, was not present when checked.

Use OpenTX Companion 2.3 only for inspecting the Xlite reference archive. Use EdgeTX Companion for TX15 simulation and model work.

## Prepare The SD Card Folder

From the repo root:

```sh
make package
```

The simulator SD-card root is:

```text
dist/SDCARD
```

It contains:

```text
WIDGETS/SoarF5J/
```

EdgeTX's color-radio manual describes `WIDGETS` as the SD-card folder where widget files are stored. The EdgeTX Lua guide also notes that Companion's SD Structure path should point at a valid copy of the transmitter SD-card contents.

## Open The TX15 Simulator

1. Open the installed EdgeTX Companion app.
2. Create or select a TX15-compatible radio profile.
3. Open the simulator from Companion for that profile.
4. In simulator settings or the Companion radio profile, point the SD-card path at this repo's `dist/SDCARD` folder, or copy `dist/SDCARD` contents into the simulator SD-card folder Companion uses.

Do not use a command-line emulator workflow until it has been verified locally.

## Add The Widget

1. Open a model in the simulator.
2. Open screen/widget setup.
3. Add a widget.
4. Select `SoarF5J`.
5. Configure the widget `Page` option for the page being tested.

See `docs/widget-setup-and-usage.md` for the full list of page numbers,
navigation controls, setup workflow, and competition-widget operation.

## Verification Limits

The simulator can check Lua loading, screen navigation, widget options, setup pages, and basic model mutations.

The simulator cannot fully verify without TX15 hardware and telemetry:

- Physical switch, slider, and added-slider behavior.
- Live motor safety behavior with a real ESC.
- Vario/altitude telemetry and F5J maximum-altitude capture.
- RF, receiver, and sensor integration.
- Field timing workflow under contest pressure.

## References

- EdgeTX color-radio storage: https://manual.edgetx.org/color-radios/radio-settings/storage
- EdgeTX Lua guide, Companion SD Structure path: https://luadoc.edgetx.org/edgetx_2.5/introduction/getting_started
