# F5J Window Voice Design

Date: 2026-07-22

## Goal

Restore the SoarETX-style working-window voice countdown in the SoarF5J
competition widget without reintroducing timer target reset regressions.

## Current Behavior

The widget currently reports motor time every 10 seconds, counts the F5J
height-capture window, and optionally reports altitude after that window. The
TX15 model template still has an EdgeTX `PLAY_VALUE` function for `Tmr1`, but a
single model interval cannot reproduce the previous stepped countdown schedule.

## Desired Behavior

When the flight timer is running in glide state, announce remaining Timer 1
value using the old SoarETX schedule:

- Above 2 minutes: announce at minute boundaries.
- From 2 minutes down to 1 minute: announce every 15 seconds.
- From 1 minute down to 10 seconds: announce every 5 seconds.
- From 10 seconds down to 1 second: announce every second as plain numbers.

Announcements should not duplicate when the widget refreshes repeatedly at the
same timer value, should reset for each new flight, and should stop after a
finished or zero-result state.

## Approach

Keep the behavior in `src/SoarF5J/competition/widget.lua` so it is testable and
independent from the model template's coarse `PLAY_VALUE` interval. Track the
previous announced flight-timer value separately from the target-time tracking
state. Use `playDuration` for values above 10 seconds and `playNumber` for the
final 10..1 countdown, matching the legacy implementation. Keep motor-time
announcements separate and unchanged.

## Tests

Add widget tests that drive Timer 1 remaining values through the boundary
schedule and assert the emitted voice calls. Keep existing target reset tests to
guard the recent timer-start fix.
