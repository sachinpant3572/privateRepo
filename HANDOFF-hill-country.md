# Hill country behind Bellerive: land (decisions note)

Approved 2026-10-30. Sachin quoted the recommendation and said "Lets go!":
"Land now (~10-18 h): a design map, the hills grown to 3 km² or more, more
peaks with their own roads and viewpoints, plus dirt roads and shortcuts.
This is what finishes 'the mountain'. Content later: towns, the cult
compound, the secret lab, wildlife, hunting and small-town events."
His earlier asks are in TODO.md ("hill country behind Bellerive").

## Facts (Explore brief, 2026-10-31; G = game/)

- Height field: G/tools/mountain.py `_base()` (304-337). It combines the
  Calder cone (SUMMIT 950,-2750, PEAK_H 995), the APRON, 8 `CRESTS` ridge
  polylines (84-107, these are the real peaks), the foothill `RIDGES`
  bumps in `FOOTHILLS` (30-32, 65-81), noise, a fade to 0 within
  CITY_FADE 260 m of the flat city, and the Morrow gorge walls.
- `PEAKS` (109-111) only labels points on the crests. Peaks today:
  calder 1010, east 762, north_knob 738, raven 726, hawk 599, calder_knob
  455, larkspur_knob 333, pine_knob 205. Display names are in
  mountain_world_map.py:251.
- Zone outline: `_outline()` (349-361) takes ground over 1 m inside
  (-1600,-4800)-(3400,-200), unioned with FOOTHILLS.
- Terrain grid: origin (-864,-5112), 8 m cells, 541x608 nodes, uint16
  dm, built by `grid()` (685-770). City ground must be 0 (test 6243).
- Roads: mountain_plan.py is an offline A* with hairpins (SPECS 408-497)
  that writes tools/mountain_lines.json (minutes per line).
  `Mountain.grade()` caps grades (GRADE, mountain.py:137): highway 7.5 %,
  road/street 13 %, lane 14 %, track 25 %, trail 30 %.
- Classes (road_classes.py): track (6 m, drivable, dirt 60 % / gravel
  40 %), trail (3.5 m, not in the graph). Existing 4x4 shortcuts: West
  Ridge Track, Larkspur Track; Calder and Raven trails.
- Viewpoints: only the summit deck (SUMMIT_SITES, mountain.py:119),
  exported as a world_map "viewpoint" landmark; the map has the icon.
- Hill districts: build_country `_hill_roads` (1163-1416), HILL_BOX,
  3-180 m, slope <= 0.35, 0.91 km² (test >= 0.85).
- Areas: mountain zone 12.93 km², hillside zone 1.34 km². The play area
  is x -6150..3450, y -4808..2000. Red Pine (phase 3) gets terrain, roads
  and forest only; homes only up to 400 m (HOME_TOP).
- Rebuild: `godot --headless -s res://tests/plan_dump.gd -- /tmp/plan.json`,
  then `python3 tools/build_country.py /tmp/plan.json`; then
  mountain_plan.py [ids] and mountain_world_map.py. Re-dump the plan first.
  A change in RNG use shifts lots everywhere.
- Tests that pin it: test_mount_calder (6226; >= 4 lesser peaks of
  380-780 m, the grade caps of 8 named roads), test_hill_districts,
  test_bellerive_hills, test_hill_heights_are_flat_checks,
  test_rail_crossings_are_grade_separated, test_country_joins_the_city,
  test_movers_stand_on_hill_ground, test_flora_kit_and_hill_ecology,
  test_heli_walls_and_mountain_stop_it, and a labels check (>= 5 peaks).
- The "about 5.1 km² of usable ground" in TODO.md has no traceable
  source. Step 0 measures it again with a defined metric.

## Step 0: measure (tools/hill_area.py, 2026-10-31)

Hill ground = 3-450 m, slope <= 0.45, within 150 m of a road, track or
trail. Today: 3.54 km² (6.11 km² with no reach limit; 14.14 km² of
ground over 3 m). By band (gentle and reached): 3-50 m 1.69, 50-120 1.17,
120-200 0.32, 200-300 0.21, 300-450 0.16. True rolling hills (50-450 m)
reached: ~1.86 km². The range is a steep dome; only a thin ring is gentle,
and the east and north-east apron (x 2400-3450, y -4400..-1500, 0-60 m,
gentle, in the mountain zone and the play area) has no road at all.

## Design (built 2026-10-31)

- **Corridor first.** The east apron is not empty: Route 1, Route 3,
  Route 9's dead end (2100,-4050), Old Post Road, the Pinecrest Logging
  Road, the Corran Commuter and Solvera rails and the fence all run there.
  So the hills sit west of that corridor, capped at
  CLEAR_SLOPE 0.3 x (distance - CLEAR_W 60 m) from every one of those ways,
  the fence (CLEAR_FENCE) and the grid's north and east edges (CLEAR_EDGES,
  else the taper left a step). tools/mountain.py HILLS (rounded tents like
  CRESTS, slope 0.24) + the cap, soft-min/max blended into the massif.
- **Hills as built** (true tops, not the chain points; the cap pulled the
  tops west, so the labels moved onto them): Whistler Hill (2536,-3656)
  168 m, Tallow Knob (2576,-3968) 136 m, Fernmoor Hill (1944,-4704) 118 m,
  Copperback (2600,-2720) 132 m, a shoulder under the East Ridge (like
  Larkspur Knob). Designed 165-265 m; the cap keeps them lower.
- **Roads** (mountain_plan.py, tag "hills" except the two shortcuts):
  East Hills Road (lane, 2.6 km) from Old Post Road (2750,-2010) up the
  hills' east side to Route 9's end; a track to each top (Copperback,
  Whistler, Tallow, Fernmoor, plus Tallow Top and Whistler Top to the true
  tops); shortcuts Copperback Cut (Whistler-Copperback) and Spur Track
  (Tallow up the north-east spur to East Peak, 3.8 km of switchbacks);
  Tallow Trail along the crest; back-country lines into the gentle ground
  the first build left unreached: Fernmoor Ridge Track (Tallow round the
  low north ridge to Fernmoor, 1.25 km), Brackett Track (dead end west
  from East Hills Road into the south hills, 0.9 km), Hollin Trail (Spur
  Track down the west flank to Route 9) and Moor Trail (Fernmoor west to
  the logging road). "hills" is in build_country MTN_TAGS
  (else _grade_rest graded them again as suburb streets).
- **Viewpoints** (mountain.py VIEWPOINTS): a 20 x 12 m level pull-out on
  Tallow, Whistler, Copperback, Fernmoor and East Peak, at the end of the
  track(s) that climb there (their last VIEW_FLAT 20 m level, as Calder
  Road into the summit car park), and beside the way on Raven (440,-3188)
  and Hawk (76,-2502) peaks (15 m clear, at their own ground). Each is a
  "view_<peak>" site (country.json mountain.sites) and a viewpoint
  landmark on the map. No rail or bench meshes: the summit deck is data
  only too (#113); props come with the content step.
- **Not in this step** (later, on Sachin's word): rivers, lakes and ponds
  in the valleys, the huge forest, places, wildlife, events. Bridges and
  tunnels need #110.

## Decisions

- East apron for the new hills: it is the only large gentle ground left
  in the play area with no roads, far from the city (no CITY_FADE clash),
  and next to East Peak, so new crests join the range naturally. Rejected:
  raising the south foothills (hill districts and the city edge there are
  pinned by tests), and the north (y < -4800 lies outside the play area).
- Grass is not part of this: it is optional, 6-10 h, and it is a separate
  rendering job. It can follow once the land is final.
