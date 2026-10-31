# HANDOFF archive: #116 stage C, the sloped hill districts

Finished history moved from HANDOFF-hill-districts.md.

## Build results (2026-10-30)


- Generator: 0.91 km2, terraces 28 (6.2 km), climbs 29 (2.7 km), hillside
  lots 207 (house 110, rows/painted ladies/garden apartments 28 each, exec
  13); "hillside" in WALK_ZONES gave 8 hill sidewalk loops (82 -> 90).
- Climbs: traced at 0.12 on the smoothed ground, every one graded to the
  0.13 cap and three measured 0.149-0.185 over 32 m (each street is graded
  on its own raw ground, steeper than the smoothed one). Now traced at
  HILL_CONNECT 0.10, leaving 3 points under the cap.
- Pads: the 8 m grid blends a pad into any pad or road at another height
  within about a cell. Mountain lots already in the game slope ~1 m at the
  front (the road's grading runs into the front yard), accepted as the
  standard; at the back and sides 22 of 207 hill lots were off level. Now
  `mountain_terrain` measures each hill lot on the final grid (`_pad_tilt`,
  middle/back/sides 1 m in) and drops those off by > HILL_PAD_TOL 0.2 m,
  worst first, one per 24 m group a round, remaking the grid (<= 4 rounds).
  test_hill_districts checks the same rows at 0.3 m.
- Run 3 (65d235a): terraces 25 (5.7 km, 3 cut off), climbs 32 (3.3 km),
  22 lots dropped, hillside lots 183, walks 92. Basalt/Onyx Rise measured
  0.26-0.27: the climbs of the 3 cut-off terraces were still built, and
  join_ends tied their loose ends to the nearest street with straight,
  ungraded links. Fix: a cut-off group is dropped whole (its climbs too).
- Crest Drive (mountain road, 0.143 before stage C) measured 0.148 in run 3:
  its shape is unchanged, but its end now reaches 10.5 m further to meet
  Harrier Rise, so grade() resamples its 4 m points and the 60 m smoothing
  lands a little differently by the hairpin at (1760,-1130).
- Run 4 (cut-off groups dropped whole): terraces 25 (3 cut off), climbs 27
  (2.6 km), 17 dropped, lots 179; Basalt/Onyx fixed. Crest Drive still 0.148:
  the ground there is identical to before stage C; only the centre line
  moved (<= 0.22 m), and an exact 1 m resample reads 0.144 then, 0.151 now.
  Mica Way 0.146 (6.7 m over a 46 m piece between two climbs). Cause, both:
  a way graded right at its cap reads up to ~0.02 steeper on the 8 m grid,
  the whole of the test's 0.015 slack. Fix (the test kept as is): hill
  streets graded to HILL_GRADE 0.12, Crest Drive to MTN_CAP 0.125.
- Run 5 (those caps): Crest Drive 0.143, Mica Way 0.130, both fixed. Gully
  Rise (a 45 m climb, Bluff View Drive down to Crest Drive) 0.166: its ends
  are pinned 7 m apart, 0.155 end to end, which no grading fits. Fix: trace()
  rejects a climb whose ends (terrace on the raw ground, the way it meets at
  its graded height via `mtn.profile_at`, mountain roads being graded first)
  rise more than HILL_RISE 0.11 x its length. Run 6: 28 terraces (0 cut
  off), 28 climbs, 177 hillside lots, hill tests pass.
- Sachin, 2026-10-30: "We can have some steep hills too, is good for
  variety, pnly if they match real life hills." Real hill towns: most streets
  under ~10-15 %, a few blocks 20-31 % (SF Filbert St 31.5 %, 22nd St 31.5 %;
  LA Eldred St 33 %; Pittsburgh Canton Ave 37 %). Decision: up to
  HILL_STEEP_MAX 6 climbs <= 160 m may rise HILL_STEEP_RISE 0.18 end to end,
  tagged "steep", graded to 0.19 (cap 0.20); every 4th climb start tries a
  trace at 0.15 (straighter up the slope). Kept at the mild end so every car
  and truck climbs them (vehicle.gd SLOPE_PULL; Firebreak tracks are 25 %).
  Test: hill streets 13 % (+0.015), short (<= 200 m) ones 20 % (+0.015), <= 6.
- Run 7 (steep climbs): terraces 26 (2 cut off), climbs 27 (3.0 km), lots
  178; steep: Flint Rise, Jasper Rise, Opal Way, Garnet Rise, Feldspar Way,
  0.157-0.193 measured over 32 m on the grid. Hill tests pass (101 checks).
  Shots: tests/country_shots.tscn c30-c35 (ONLY=...).
- Shot c35 showed grass through the asphalt of Madrone Drive's turning
  circle. All 29 hill turning circles (none before stage C) followed the
  slope across the contour, 2-10 m from side to side. Fix: `_grade_rest`
  grades a hill circle's arcs level at its street end's height
  (`flat_bulbs`, ends pinned, cap 0), cut and filled like real hillside
  cul-de-sacs. test_hill_districts checks the arcs are level within 0.5 m.
