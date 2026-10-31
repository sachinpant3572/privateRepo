# 0.26 close-out (2026-10-31)

Sachin, 2026-10-30, approving the recommendation ("Lets go!"): close-out and
the 0.26 APK first, then hill country land only (bay dropped), then the
MadOut2 lessons. Grass optional.

## Done

- Version 0.26 (Android version code 28) in project.godot and
  export_presets.cfg.
- Stage D (bay and beach borough) marked dropped in
  HANDOFF-world-followups.md; the beach stays on the Gulf coast.
- `Helicopter.open_ground_near` skips water: ground under the water plane
  (the sea, banks), the plan's river band and the park lakes
  (`Helicopter._wet`). Test: test_heli_exit_only_when_low, 20 m into the
  river finds the bank.
- A respawn (wasted or busted) clears blasts and burn marks
  (`Fx.boom.clear()` in main.gd `_respawn`). Test:
  test_wasted_respawns_at_hospital.

## Park cell hitch (probe: tests/cell_probe.tscn, headless)

PROBE_RESULTS

## Decisions

- Grass: not in this close-out. Decided at the hill country start (see
  HANDOFF-hill-country.md).

## Gates

GATES
