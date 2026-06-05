# TX15 Model Template

The first TX15 template is expected to be migrated manually in Companion, using the Xlite F5J model as the reference.

## Reference Archive

Reference archive:

```text
/Users/vitas/Downloads/xlite_f5j.otx
```

Archive contents observed locally:

```text
RADIO/radio.bin
MODELS/model1.bin
RADIO/models.txt
```

That means the archive contains one model slot.

## Referenced OpenTX Scripts

The reference model is expected to use these SoarOTX scripts:

- `JF5Jsk`
- `JFXJcf`
- `JFgrph`
- `JFutil`

These names are migration references. They should not be copied as runtime dependencies for the F5J-only EdgeTX widget unless a specific behavior still needs to be ported.

## TX15 Template Scope

The TX15 template should define:

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

Do not commit a TX15 model template until it has been created and checked in EdgeTX Companion or on the TX15.
