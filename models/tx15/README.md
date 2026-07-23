# TX15 Model Template

This directory is for TX15 model-template artifacts.

Current templates:

```text
tx15-MTail.etx
tx15-VTail.etx
tx15-XTail.etx
```

Pick the file that matches the aircraft tail. All three templates keep the
same wing and motor layout for a normal 8-channel receiver:

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

`tx15-XTail` deliberately has no aileron-to-elevator mix on the single elevator
output. `tx15-VTail` uses `CH7/CH8` for the tail so an 8-channel receiver can
be wired without receiver remapping.

Create or update the templates in EdgeTX Companion or on the TX15, then export
them here once the model structure is repeatable and reviewed.

Expected template contents:

- Flight modes.
- Timers.
- Logical switches.
- Global variables.
- Curves.
- Mixes.
- Outputs.
- Widget screen assignments for SoarF5J.
