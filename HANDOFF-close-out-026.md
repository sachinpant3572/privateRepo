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

Main-thread add (`city._add_cell`: mesh instance plus one CollisionShape3D
per box) over all 842 cells, headless in the container, one sample per cell:
median 1.66 ms, p90 3.12 ms. Biggest park (cell 16, parkland, 240-tree
budget): 7.1 ms, 260 shapes, 57k triangles, 13th of 842. Slower: golf 18.3
(open land too, and noisy: the same cell gave 5.8 ms in a parks-only run),
then dense urban blocks painted 17.5 (282 shapes), havana 17.4 / 15.7,
heights 11.4, quarter 10.9. Single samples, so the ranking is rough. The
worker build (Cells.build) is off the main thread.
Verdict: a parkland cell is no worse than a dense block, so no park fix.
A phone is maybe 3-5x slower and also uploads the mesh to the GPU (the dummy
renderer skips that), so the worst cells may cost a 30-90 ms frame there.
That applies to every block type; not measured on a phone. If Sachin's
logs show hitches on cell loads: add shapes over several frames, or build
the static bodies through PhysicsServer3D directly.

## Decisions

- Grass: not in this close-out. Decided at the hill country start (see
  HANDOFF-hill-country.md).

## Review (Opus, 1 round)

No serious findings. Fixed: the park verdict above (golf is open land, single
samples), this section, and a lake check added to
test_heli_exit_only_when_low. Left as designed: a car still burning at the
old spot can explode after a respawn and leave a new mark (a new blast, not
a leftover); `open_ground_near` looks the game node up again (harmless).

## Gates

- Full suite before review: exit 0, 1824 checks passed, 0 failed.
- Focused after the fixes: test_heli_exit_only_when_low,
  test_wasted_respawns_at_hospital PASS.
- Full suite after the fixes: RESULT
- APK: tools/build_apk.sh exit 0, signed, 32.2 MB,
  build/solvera-0.26-debug.apk (the test-only fix does not change it; tests/
  is excluded from export).
- Screenshots: none, no visual change.
