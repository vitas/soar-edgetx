# TX15 Model Templates

The committed TX15 templates are:

```text
models/tx15/tx15-MTail.etx
models/tx15/tx15-VTail.etx
models/tx15/tx15-XTail.etx
```

Each `.etx` archive currently contains:

```text
RADIO/radio.yml
MODELS/model1.yml
MODELS/f5j.txt
MODELS/labels.yml
```

It was created manually in Companion from the F5J migration work.

## Tail Variants

All variants keep the same wing and motor channel layout:

```text
CH1/CH2  Ailerons
CH3      Motor
CH4/CH5  Flaps
```

Tail outputs:

```text
tx15-MTail  CH6 rudder, CH7/CH8 elevator servos
tx15-VTail  CH7/CH8 left/right V-tail, CH6 unused
tx15-XTail  CH6 rudder, CH7 elevator, CH8 unused
```

`tx15-VTail` puts the V-tail servos on `CH7/CH8`, leaving `CH6` centered and
unused. This keeps the template usable with a standard 8-channel receiver
without receiver output remapping.

`tx15-XTail` is for a conventional rudder plus one elevator servo. Its single
elevator output intentionally does not include the switchable
aileron-to-elevator mix.

## Referenced OpenTX Scripts

The reference model is expected to use these SoarOTX scripts:

- `JF5Jsk`
- `JFXJcf`
- `JFgrph`
- `JFutil`

These names are migration references. They should not be copied as runtime dependencies for the F5J-only EdgeTX widget unless a specific behavior still needs to be ported.

## TX15 Template Scope

The TX15 templates should define:

- Flight modes.
- Timers.
- Logical switches.
- Global variables.
- Curves.
- Mixes.
- Outputs.
- Widget screen assignments.

Manual Companion migration is acceptable until a repeatable model export path exists.

## Current Artifact Policy

Commit updated TX15 template artifacts under `models/tx15/` after they have
been created and checked in EdgeTX Companion or on the TX15. Also commit the
matching exported template YAML files under
`dist/SDCARD/TEMPLATES/3.SoarEdgeTx/`.

For radio and simulator operation, including the required widget `Page` values,
setup-page workflow, and competition-widget usage, see
`docs/widget-setup-and-usage.md`.
