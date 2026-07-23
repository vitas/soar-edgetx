# TX15 Tail Templates Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create separate TX15 F5J model templates for M-tail, V-tail, and X-tail layouts.

**Architecture:** Treat the current TX15 template as the MTail base. Generate VTail and XTail model YAML variants by changing only header names, tail output names, and the real tail output mix blocks. Keep shared widget, switch, timer, GVAR, wing, motor, camber, and voice behavior unchanged.

**Tech Stack:** EdgeTX `.etx` zip archives, exported model YAML, Lua package tests, `make lint`, `make test`, and `make verify`.

---

### Task 1: Add Failing Template Tests

**Files:**
- Modify: `tests/test_sdcard_package.lua`

**Steps:**
- Replace the single `f5j_tmpl_t15.etx` / `f5J-t15.yml` constants with variant tables for `tx15-MTail`, `tx15-VTail`, and `tx15-XTail`.
- Add existence checks for all six artifacts.
- Add mapping tests:
  - MTail: `CH6=Rudd`, `CH7=ElevL`, `CH8=ElevR`.
  - VTail: `CH7=LftV`, `CH8=RgtV`, `CH6` unused/centered.
  - XTail: `CH6=Rudd`, `CH7=Elev`, `CH8` unused/centered, and no `Ail->Elev` mix on the real elevator output.
- Run `lua tests/run.lua` and confirm failure on missing new artifacts.

### Task 2: Generate Template Artifacts

**Files:**
- Delete: `models/tx15/f5j_tmpl_t15.etx`
- Delete: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/f5J-t15.yml`
- Create: `models/tx15/tx15-MTail.etx`
- Create: `models/tx15/tx15-VTail.etx`
- Create: `models/tx15/tx15-XTail.etx`
- Create: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-MTail.yml`
- Create: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-VTail.yml`
- Create: `dist/SDCARD/TEMPLATES/3.SoarEdgeTx/tx15-XTail.yml`

**Steps:**
- Use current `f5j_tmpl_t15.etx` / exported YAML as the MTail source.
- Preserve all non-tail model sections.
- For VTail, replace real output CH7/CH8 with the existing virtual V-tail mixes from CH9/CH10 and center CH6.
- For XTail, keep CH6 rudder, make CH7 a single elevator output from the elevator internal channel/KAPOW path, and center CH8.
- Run `lua tests/run.lua` and confirm template tests pass.

### Task 3: Update Documentation

**Files:**
- Modify: `README.md`
- Modify: `models/tx15/README.md`
- Modify: `docs/tx15-model-template.md`
- Modify: `docs/widget-setup-and-usage.md`

**Steps:**
- Replace the old single-template filename with the three variant names.
- Document the channel layouts and receiver wiring expectations.
- Run `make lint`.

### Task 4: Full Verification

**Steps:**
- Run `make verify`.
- Confirm linter, package step, and all tests pass.
