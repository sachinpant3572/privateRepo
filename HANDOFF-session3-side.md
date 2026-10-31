# Session 3 side work while session 4 drives phase 3 (2026-10-31)

Sachin, 10-31 (asked whether session 3 or session 4 carries on): "Wait for
session 4, but see what other things you can do completed unrelates to
session 4". Session 3 touches no file session 4's builders or wiring use
(races, ground, stunts, parachute, bungee, vehicle, humanoid, player,
main, hud, mission_manager, test_runner) and does not edit
HANDOFF-hill-content.md (session 4 keeps it). Fold this note into the
hill-content archive when phase 3 closes, then delete it.

## Done (862bad9)
Calendar review Lows (review of 39bb3df, left as "not in Sachin's list"):
- Queued PeopleBuilder tickets built after the event was freed:
  PeopleBuilder.cancel(t) drops a waiting ticket; events.gd `_free` and
  `_exit_tree` cancel their in-flight orders. Test: rave freed while its
  people are queued (precondition checks some are queued) -> none left.
- Phone Events: no GO button for an event whose centre is INF (place not
  in the map); GO used nearest_node(INF). No test: every shipped event has
  a place.
- Already fixed earlier (no change): dressing ArrayMesh cached per kind
  (events.gd `_dress_cache`); the stale comments at calendar_tests.gd:7-8
  and sky.gd:47-48 now read right.
- Left: show_banner shares the district label (hud.gd, which session 4
  edits for the phase-3 wiring).
Gates: calendar module 12/12 PASS (146 checks); full suite on 862bad9
(session 4's d4d9a18 + this): exit 0, 2147 passed, 0 failed.

## Looked at, not changed
- Trail loop 904 (26/128 points within 6 m of a road): the loop follows
  its trail, which runs beside a road. Moving it means a country rebuild
  (country.json), which session 4's race course, BASE lip and bungee arm
  measure from: wait until phase 3 is merged.

## Continuation check on 48075d3 (Sachin 10-31: "check and see if the work can be continued without issues")
- Branch level with origin; wip/snapshots G and P apply with `git apply
  --3way`, conflicts only keep-both: tests/test_runner.gd TEST_MODULES, and
  player.gd's E handler (R's `_races_take_press` vs P's `_air_sport_interact`).
- Full suite on 48075d3: 2342 passed, 1 failed:
  test_wildlife_herds_flee_a_walking_player ("whole herd breaks away 3 of 4").
  Flaky, at its threshold (`gone >= 3` beyond 30 m 120 frames after the flee):
  solo on HEAD 2 of 7 FAIL (1/4 at 30 m, 2/4 farthest 48 m); HEAD with
  `add_child(races)` commented out 3 of 6 FAIL (2/4 44 m, 2/4 47 m, 1/4
  47 m) -> the races node is not the cause; pre-R e4cc388 0 of 4 FAIL
  (small sample). Not fixed: needs a seed-pinned herd or a looser bound
  (e.g. 3 of 4 beyond 25 m, or more frames), or bisect e4cc388..48075d3.
  Session 4 owns the merge; flagged, no APK until it is green.
