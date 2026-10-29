# World build: variation 2 city, 1000 m range, trains, summit (2026-10-29)

Sachin, 2026-10-29: "Lets continue with 2." / "Mountain should be raised to
1000mtrs, with several small mountains around it, and continuing mountain
line, seemlessly mering with the city and around it, just like we have in
San Andreas and GTA V." / "we have built a train line too, for regular travel
and for freightlines too this will cover every district, cover the mountain
(can build a tunnel or go around it) so scenic views can be seen, and will
cross it in between too. Build this too as best as possible." / underpasses
and tunnels: "No this wont be skipped. We will build everything."

Research behind it: reference/world/map_and_mountain_research.md.
#105 (Bellerive at LV size) folds into phase 1: its open test failures are
on the street plan that phase 1 rewrites.

## Phases (rough cost; order fixed by dependencies)

1. **City plan, variation 2 adjusted** (~30-42 h). Downtown grid kept;
   field-traced curves outside it; Wards, Ironwharf and docks keep a tight
   straight grid (class divide); rich districts (Cable Hill contour streets,
   Florida coast, river edge) curve, with variation 4's stronger pull along
   water; main-road crossings kept for malls; roundabouts where field
   arterials cross; A's Mirador and Canyon roads. Reserve the rail corridor
   (phase 4) in the plan. Then #105's tests, full suite.
2. **Mountain range** (~25-40 h). Calder massif ~1000 m, smaller peaks
   (400-750 m) around it, a ridge line running on east into Verdant Hills and
   west toward Cinder Ridge, foothills (50-300 m) starting at the city's north
   edge. Bigger terrain grid, roads re-graded (main road with switchbacks,
   forest trails, shortcuts), country regenerated.
3. **Grade separation** (~14-22 h). Bridge decks over roads and valleys,
   underpasses, tunnels (portals, see-through for the top-down camera),
   vehicles and people on deck heights. Trains reuse it.
4. **Trains** (~30-50 h). Passenger line through every district with
   stations; freight line to the docks, Ironwharf, Golden Flats and the
   quarry; across the range by a pass with tunnels, viaducts and a scenic
   shelf on the flank (grade <= 2.5 %). Ride as passenger; freight and
   passenger trains run on a timetable; level crossings in town.
5. **Far view** (~16-24 h). Low-detail whole-city and whole-terrain meshes,
   haze, lit windows at night; summit view mode; telescope that streams the
   real cells where it aims.
6. **Summit set** (~18-28 h). Cable car Cable Hill to summit (long, two stages
   with a mid-station), summit restaurant with terrace, helipad, deck,
   telescopes, off-road grip on trails.

Total ~135-205 h. Milestone APKs after phases 2, 4 and 6. Flying from the
helipad needs helicopters: task #82, not started (Sachin's word needed).

## Phase 1 approach (as built)

- **Street field**: `game/tools/street_field.py` (numpy, offline) sums a
  tensor field from the downtown grid (450,300) w1 s650, the Gulf coast
  (-39 deg) w1.6 s480, the Morrow w2.0 s230 (4's water pull) and Mirador,
  Canyon, Liberty (s70 w1.2) into `game/data/street_field.json` (u8 angles,
  20 m grid). Rerun it on a plan dump when those roads move:
  `python3 tools/street_field.py /tmp/plan.json`.
- **Tracing at build time** (street_plan.gd "The street field", ~1 s whole
  plan): RK2, 8 m steps, per-family spatial hash. A trace joins a line
  ahead within the join distance, stops beside one, carries on past one
  behind; it stops past a turn limit (ART_TURN 80, STREET_TURN 100 deg),
  which keeps lines off the field's singularities.
- **Which streets where** (class divide in the pattern itself):
  - field: havana_e (Calle Luna), brisa_e, point_w, point_e;
  - contour: hill_n (Cable Hill), rings 130/200/270 m round the crest and
    8 radials; the crest inside the first ring is one block of estates;
  - grid kept: gilt_w, midtown, quarter_w/e, wards, wards_n, docks, china_n.
- **Arterials**: city arterials end at a field region's edge as entries; the
  field arterial carries each on along the field (so the main roads go
  through), new field arterials fill the gaps; roundabouts where field
  arterials of different families cross (>= 220 m apart). Grid crossings
  stay for malls. Mirador and Canyon (CURVES) stay; BOWS removed.
- No cul-de-sacs: the plan prunes dead ends (exits come from the trim).
- **Rail reserve**: freight on a 16 m strip between the north River Road
  and the water (`FREIGHT_STRIP`, north bank only; city_cells draws ballast
  and moves the railing to the water). Passenger line: elevated over
  boulevard medians (Aurum past Union Station (390,166)), own viaduct
  elsewhere; built in phase 4 on phase 3's decks.

- **Measured (2026-10-29)**: city land 4.22 km² (fill 0.63), on target
  (Las Venturas 4.1-4.3). Core outline bulges a block east of Tamarind
  (world (8060, 6690)) so the edge doesn't run straight 423 m.
- **Integration with phase 2 (2026-10-29)**, after the first regeneration
  left 37 plan exits unlinked:
  - Core notch at Aurum (local x 1180-1500, y -120..190) removed: it cut
    Aurum and the streets at y 15/75/140 into east/west exits facing a
    225 m slot the country could not reach. North edge now steps: a
    two-block bump to row y -166 at x 1235-1460, row -97 elsewhere, NE
    corner pulled to y -80 (one-block bumps are spurs the trim drops; a
    gap of one block between kept ones is a notch it fills). Longest
    non-water edge run 310 m; land ~4.28 km².
  - Serena Causeway: world_map `overseas` starts on the axis of its
    Ocean Drive junction (local (1753,1657), dir (0.661,0.750)) and runs
    on it 300 m before turning east; CAUSEWAY_FROM matches. A 44 m
    sideways offset failed the lead-in's min radius.
  - build_country.py: Verdant Hills sites try an estate first until one
    house has turned to its view (`view_turns`); the coin toss alone left
    none turned.

## Decided

- **1000 m geometry [M].** A 1000 m peak needs a base of ~2-3 km to the city
  (mean slope 35-45 %, like Chiliad's 798 m). Peak goes north into Red Pine
  (phase 3, unbuilt), around world (7100, 3900): ~2.2 km from the city's
  north edge (world y ~6080). From there the city lies 10-22 degrees below the
  horizon (near edge 2.2 km, far corners ~5 km). Today's Bellerive Hills
  (114 m) become the foothills and lower peaks.
- **Seam with the city:** foothills start at the city edge; the country layer
  (already terrain-following) carries hillside streets and homes up from the
  city's streets, Vinewood Hills style. The city itself stays flat
  (HANDOFF-bellerive-lv "SF district flat"). Sloped city districts are the
  bigger option (+40-70 h).
- Dellwood (phase 3 town at (6800, 3700), unbuilt) sits on the new massif:
  move it to the north foot.

## Open

- Golden Flats Expressway and phase 2 roads on the new west flank: re-route
  or pass; settle with the terrain sketch in phase 2.

## Traps

- Godot runs need `timeout`; gates per CLAUDE.md.
- The field rotates near the river bend (x ~1000-1450, south bank): a line
  can swing onto the other family. The turn limits stop it; a long straight
  join jump (Morrow, 103 m) came from a join distance of art_sep*0.4, now
  ART_JOIN 45 m.
- Cable Hill: a ring within ~75 m of the crest grazes Mirador and the hug
  check drops it whole (with the radials' inner ends).
- Plan renders: /tmp/p1/view.py-style script on a `tests/plan_dump.gd`
  dump; blue = no face (water or outside).
