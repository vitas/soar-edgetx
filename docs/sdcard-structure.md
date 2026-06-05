# EdgeTX SD Card Structure

Copy the contents of `dist/SDCARD` to the root of the TX15 SD card. When
updating an existing card, delete `WIDGETS/SoarF5J` first and then copy the new
folder, so old Lua or compiled `.luac` files cannot remain on the card.

For widget-only updates, use the Makefile target:

```sh
make install-widget SDCARD=/Volumes/TX15
```

`make sdcard SDCARD=/Volumes/TX15` is a shorter alias.

Expected layout:

```text
SDCARD/
  edgetx.sdcard.version
  RADIO/
  MODELS/
  SOUNDS/        # local/untracked sound pack
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
