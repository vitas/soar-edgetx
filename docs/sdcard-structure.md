# EdgeTX SD Card Structure

Copy the contents of `dist/SDCARD` to the root of the TX15 SD card.

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

In EdgeTX, add a SoarF5J widget to a model screen and select the required page in widget options.
