# HANDOFF: #116 stage C, the sloped hill districts

Sachin, 2026-10-30: "Go" (on stage C, the sloped hill districts, run mostly
on Opus with Sonnet trial packages). Stage D (the bay) is NOT approved.

## Decisions (2026-10-30)

- **Approach B: hill districts as a country zone** ("hillside") in
  tools/build_country.py, on the mountain.py terrain we already have (no
  carve-out, no change to mountain.py). ~20-30 h.
  Rejected **option A**: a slope-aware city plan (street_plan.gd cells on a
  height field), ~40-70 h, high risk: the city plan, cells, traffic and
  tests all assume flat ground at y 0. The country already grades roads,
  pads lots and streams tiles on heights, so B reuses all of that.
- **Region**: grid 8 m over HILL_BOX (120,-1260,2320,-260); Z = mtn.raw,
  Zs = Z smoothed (separable numpy blur, no scipy dependency). Eligible
  where 3 <= Zs <= HILL_TOP and slope <= HILL_SLOPE, inside the mountain
  zone, minus freeway/highway sources (hw + 25), Red Pine, water + 30,
  reserved sites and landmark sites. Components >= 40,000 m2 kept.
- **Contour streets**: contours of Zs at 1 m steps, rising; a run is kept
  where it stays >= HILL_PITCH from every road and accepted street and is
  >= 120 m long. Ends get bulbs where they fit; join_ends/_settle take the
  rest. Tag "hill"; names from an original list (no real-place names).
- **Connectors** every ~220 m along a street, traced downhill at grade
  HILL_CONNECT (0.10): heading at angle t off the fall line with
  cos t = g / |grad Z| (straight down if the slope is under g), sides
  alternating, 4 m steps, <= 300 m; stops on the first street or road and
  snaps onto it; starts >= 120 m apart; no crossings. Streets are added
  before connectors so `_grade_rest` grades connectors after streets.
- **Zone**: the hillside polygon leaves the mountain zone; ("hillside",
  poly) is appended to self.zones; "hillside" appended to ZONES at the end
  (keeps every zone index). Districts (original names): Lumen Hills,
  Toyon Terraces, Coyote Bluffs.
- **Lots** (street_lots, style "hillside") by height band: < 40 m rows,
  painted ladies, garden apartments, houses; 40-90 m houses and exec
  houses; > 90 m exec houses and mansions. Mountain checks kept (frontage
  climb <= 9 %, switchback, Red Pine), no 60 % skip. Pads come from
  mountain_terrain.
- **Game side**: "hillside" in ZONE_GROUND, TREES, LIVE_CAR_ZONES, birds,
  country_kit fences; flat (3D) distance checks made 2D where hills break
  them (pedestrian `_wander`, taxi `_pulled_up_by`, player
  `_free_spot_beside`; population and m03 not changed).
- **Sonnet trial** (CLAUDE.md): packages run on sonnet/high, each with its
  own Opus review; metrics below. Godot runs serialized with
  `flock /tmp/godot.lock`.

## Sonnet trial record

| Package | Review findings (severity) | First-run gate fails | Main fix time |
|---|---|---|---|
| 1. Hill height fixes (pedestrian `_wander`, taxi `_pulled_up_by`, player `_free_spot_beside`, new test; ~9 min, 105k tokens) | 0 High, 1 Medium (test measured the player against the street node's height, 0.3 m slack: slope-dependent), 1 Low in package (exit spot ignored `Terrain.drop`), 2 Low in nearby code (heli `open_ground_near` y 0, vehicle `drive_path` 3D dot) | Parse errors on untyped `:=` (2), run hung to timeout (exit 124); clean on rerun. Reverting the fixes failed 4 of 5 checks, as it should | ~10 min (all 4 findings fixed) |
| 2. Fire and explosions (fire_fx.gd, explosion.gd, car_fire.gd rewrite, Fx.boom pool, per-quality LEVELS, test, SHOTS=fire) | 1 High (textures made in GDScript on the first fire/blast: a stall), 3 Medium (pool of 2 cut a live smoke column; lights ignored Settings > Real lights, 30 m flash; ~13 m column sprites, overdraw), 4 Low (scorch too small, heli ground without `Terrain.drop`, scorch survives a respawn, "explosion" sense unused) | Parse errors on untyped `:=` and a `for ... if ... else` (3), new test read only scorch slot 0, engine ERROR from `global_shader_parameter_get`, a first look too small, state left between tests | ~15 min (High, Mediums, 2 Lows fixed; 2 Lows left, below) |

Trial verdict (2 packages): both worked and looked right, but each needed an
Opus review to catch real defects (package 2 a High first-fire stall and a
setting it ignored), and both hit parse errors on their first run. Quality
did not hold well enough to drop the per-package review: builders go back to
Opus (CLAUDE.md rule), Sachin to overrule.
Final review (M1): shaders compiled at the first fire on Android; now
Fx.prewarm_fire draws every fire/blast material for 0.5 s at load.
Fire Lows left as they are: the scorch outliving a respawn (clear() only in
tests; it fades in 50 s) and the unused "explosion" sense (senses.gd: a
gameplay choice for Sachin; the blast still makes "crash").

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

- Full-suite flakes (2026-10-30): the birds test's hills sample drew no hawk
  (~1 in 500; the circle reads "hills" at 394/400 points), now a fixed 100-draw
  `_pick_kind` check; the city traffic count read 4 of 5 at one instant (passes
  alone), now waits up to 8 s for traffic to refill like the pedestrian check.
- Burnt car (2026-10-30, "too black"): the flat 0.12 grey is replaced by
  `MeshBuilder.burnt_material()`: grey ash with rust patches from 3D noise and
  soot low down and on the glass. It lives in MeshBuilder because the Fx
  autoload must preload it for prewarm (fx.gd can't see vehicle.gd).

## Open questions

## Traps

- country.json / mountain_lines.json: read with python json, never grep.
- Never two godot runs at once (flock /tmp/godot.lock).
- Re-dump the plan (tests/plan_dump.gd) before a country rebuild.
