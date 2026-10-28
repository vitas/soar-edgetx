# EdgeTX SD Card Structure

`dist/SDCARD` is not a complete EdgeTX SD card. It has no EdgeTX voice pack,
and its stock folders (`THEMES`, `IMAGES`, `SCRIPTS`, and the stock widgets)
come from a development card, not from an official EdgeTX release. Do not copy
the whole folder to a radio card. Install on a radio this way:

1. Back up the SD card, at least `MODELS` and `RADIO`.
2. Run EdgeTX 2.12 on the radio. Update older firmware with EdgeTX Buddy
   (https://buddy.edgetx.org) or as the EdgeTX manual describes
   (https://manual.edgetx.org). If the radio uses ExpressLRS, also update the
   TX module and the receiver to the same ExpressLRS 3 release with the
   ExpressLRS Configurator
   (https://github.com/ExpressLRS/ExpressLRS-Configurator/releases).
3. Download the official SD-card content for the radio screen from the latest
   2.12 release at https://github.com/EdgeTX/edgetx-sdcard/releases:

   | Radio | Screen | Archive |
   | --- | --- | --- |
   | TX16S, TX16S Mark II, T16, T18 | 480x272 | `c480x272.zip` |
   | TX15 | 480x320 | `c480x320.zip` |
   | TX16S MK3 | 800x480 | `c800x480.zip` |

4. Download a voice pack of the same version from
   https://github.com/EdgeTX/edgetx-sdcard-sounds/releases, for example
   `edgetx-sdcard-sounds-en-2.12.3.zip`. The widget speaks times, heights, and
   battery warnings with these prompts.
5. Unzip both archives to the card root and overwrite existing files. Models
   and files you added stay on the card.
6. Copy only these items from `dist/SDCARD` to the card root:
   `WIDGETS/SoarF5J`, `TEMPLATES/3.SoarEdgeTx`, and the `.wav` files in
   `SOUNDS/en`. If the radio voice language is not English, copy the same
   `.wav` files into that language folder too, for example `SOUNDS/ru`.

When updating an existing card, delete `WIDGETS/SoarF5J` first and then copy
the new folder, so old Lua or compiled `.luac` files cannot remain on the card.

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

Layout of `dist/SDCARD` in this repo. The EdgeTX Companion simulator can use
the folder itself as its SD Structure path:

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

Only the custom voice prompts referenced by the committed model templates are
tracked under `dist/SDCARD/SOUNDS/en/`. The rest of the EdgeTX sound pack is
large and remains local/untracked.
