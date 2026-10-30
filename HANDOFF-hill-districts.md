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
  them (pedestrian, taxi `_pulled_up_by`, population, player
  `_free_spot_beside`, m03 lantern lights).
- **Sonnet trial** (CLAUDE.md): packages run on sonnet/high, each with its
  own Opus review; metrics below. Godot runs serialized with
  `flock /tmp/godot.lock`.

## Sonnet trial record

| Package | Review findings (severity) | First-run gate fails | Main fix time |
|---|---|---|---|
| (pending) | | | |

## Open questions

## Traps

- country.json / mountain_lines.json: read with python json, never grep.
- Never two godot runs at once (flock /tmp/godot.lock).
- Re-dump the plan (tests/plan_dump.gd) before a country rebuild.
