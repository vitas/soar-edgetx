# EdgeTX SD Card Structure

Copy the contents of `dist/SDCARD` to the root of a supported EdgeTX landscape
color-radio SD card. When updating an existing card, delete `WIDGETS/SoarF5J`
first and then copy the new folder, so old Lua or compiled `.luac` files cannot
remain on the card.

The widget is intended for landscape color-radio screens at `480x272`,
`480x320`, and `800x480`. Radios with those screen sizes should be compatible
when the active model provides the required F5J template structure. Manual
radio/simulator testing is currently limited to TX15 and T16/TX16S-class
radios.

For widget-only updates, use the Makefile target:

```sh
make install-widget SDCARD=/Volumes/TX15
```

`make sdcard SDCARD=/Volumes/TX15` is a shorter alias. Replace `/Volumes/TX15`
with the mounted SD-card path for the radio being updated.

Expected layout:

```text
SDCARD/
  edgetx.sdcard.version
  RADIO/
  MODELS/
  SOUNDS/        # full sound pack stays local; custom model prompts are tracked
  SCRIPTS/
  TEMPLATES/
  THEMES/
  WIDGETS/
    SoarF5J/
      main.lua
      lib/
      competition/
      setup/
      pages/
    ShowAll/
```

In EdgeTX, add a SoarF5J widget to a model screen and select the required page
in the widget `Page` option. See `docs/widget-setup-and-usage.md` for full
setup and usage instructions.

Only the custom voice prompts referenced by the committed TX15 model templates
are tracked under `dist/SDCARD/SOUNDS/en/`. The rest of the EdgeTX sound pack is
large and remains local/untracked.
