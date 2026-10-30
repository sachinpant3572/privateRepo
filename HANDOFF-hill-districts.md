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

Trial 1 cost (session logs, API list prices as the weight; cache reads cost
$0.20/MTok on both models, so Sonnet only halves input/output): Sonnet runs
$6.58 (same tokens at Opus prices $10.73), extra per-package Opus reviews
$3.25, main-session fixes ~$7-9 (estimated share of mixed windows).
Sonnet path ~$17-19 vs Opus-only ~$11-13 at high: ~40-60 % more.

## Sonnet trial 2 (Sachin, 2026-10-30: "Yes please" to a retest with briefs)

Packages: the two Lows left from the fire v2 review, small and patterned.
Sonnet 5.5 at high, briefs list the Godot traps, the agent runs its own
focused tests and shots, one Opus review per package. Sequential (both touch
fire_fx.gd). Est. ~$6-9 and 1-1.5 h in all; cheaper option: package 1 only.
1. Flame atlas mip bleed: frames become a Texture2DArray (one layer each).
2. Billboard cull margin on FireFx emitters, after verifying in Godot source.

| Package | Review findings (severity) | First-run gate fails | Main fix time |
|---|---|---|---|

## Build results (2026-10-30)

Run-by-run build history (runs 1-7, grades, pads, turning circles):
HANDOFF-hill-districts-archive.md.

- Full-suite flakes (2026-10-30): the birds test's hills sample drew no hawk
  (~1 in 500; the circle reads "hills" at 394/400 points), now a fixed 100-draw
  `_pick_kind` check; the city traffic count read 4 of 5 at one instant (passes
  alone), now waits up to 8 s for traffic to refill like the pedestrian check.
- Burnt car (2026-10-30, "too black"): the flat 0.12 grey is replaced by
  `MeshBuilder.burnt_material()`: 3D-noise patches and soot low down and on
  the glass (colours: see "No rust" below). It lives in MeshBuilder because the Fx
  autoload must preload it for prewarm (fx.gd can't see vehicle.gd).
  First version was ~3x too dark (near-black under lamps): it wrote
  `ALBEDO = pow(c, 2.2)`, but colours in this project's custom shaders go in
  as they are (a constant ash with no pow matched a plain StandardMaterial of
  the same grey; with pow it read 31 % vs 84 %). Fixed with no pow, plus
  lighter soot. SHOTS=wreck_lit shows it by its fire, lamps, headlight, day.
- Fire v2 (Sachin, 2026-10-30: "Improve fire layers, right now they look like
  simple cones" + glint on exposed steel, "Lets do this too"). Root bug: the
  particle billboard materials lacked `billboard_keep_scale`, so Godot dropped
  every particle's scale (Godot source: BILLBOARD_PARTICLES only multiplies the
  scale back with that flag): every flame stayed one fixed size. Fixed in
  FireFx.material/chunk_mesh (smoke and blast sizes now apply too). Flames now
  use FLAME_SHADER (FireFx.flame_material): 6 tongue pictures (single, thin,
  twins, fork, triple, low bed) bent by scrolling noise (more at the tip),
  torn into licks by a second noise (more with age), yellow-white where dense.
  Burnt shell: RIM/STEEL colours and TRIM patches at bumper height (not
  tyres: TYRE is 0.04 from TRIM) get metallic 0.6, roughness 0.3.
  The rim/steel colour keys are tight (0.006-0.012): at 0.05-0.1 a silver
  paint (0.75,0.75,0.72; roadster 0.75,0.77,0.8 is 0.017 from RIM) turned
  the whole shell into steel.
- No rust on wrecks (Sachin, 2026-10-30: "A car only rusts qhen it has been
  there for too long, but not just after explosion. After explosion it becomes
  brow-black mix." and "Rust should not be applied on destroyed cars, it should
  only be applied on rusted cars that are intentionally put in places by us").
  Sources (forums, salvage guides) agree: fresh = soot, scorched brown paint,
  grey ash where the paint burnt off; flash rust comes days later. Shell now
  scorch dark brown (0.23,0.155,0.1; Sachin: "Day wreck can be dark brown, night is good now"; 0.36,0.25,0.17 read orange in sun) / soot (0.14,0.125,0.11) blotches, ash grey on
  top panels only. Placed rusted-car props (graveyards etc.) are an idea for
  later, not approved.
- Fire v2 review (Opus, 2026-10-30): High, TRIM key caught black paints
  (POLICE_BLACK, muscle/roadster/muv black ~0.014 away): TRIM key now
  0.006-0.012 like RIM/STEEL, and test_burnt_steel_keys_miss_paints checks
  every paint after 8-bit rounding. Mediums, keep_scale grew blasts and car
  smoke (3-8x area at peak): smoke quads cut (column/cap 2.8, dust 1.7; car
  smoke scale 0.6-1.4) so the life-averaged size matches the old fill. Lows:
  softer blotch edges; prewarm test checks flame_2/3. Left: flame atlas mip
  bleed (frame edges are clear), particle AABB culling (not seen in shots).

## Open questions

## Traps

- country.json / mountain_lines.json: read with python json, never grep.
- Never two godot runs at once (flock /tmp/godot.lock).
- Re-dump the plan (tests/plan_dump.gd) before a country rebuild.
