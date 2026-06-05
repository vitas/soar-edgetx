# TX15 Model Template

The first TX15 template is committed at:

```text
models/tx15/f5j_tmpl_t15.etx
```

The archive currently contains:

```text
RADIO/radio.yml
MODELS/model1.yml
MODELS/f5j.txt
MODELS/labels.yml
```

It was created manually in Companion from the F5J migration work.

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

Commit updated TX15 template artifacts under `models/tx15/` after they have been created and checked in EdgeTX Companion or on the TX15.
