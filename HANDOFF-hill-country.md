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
  380-780 m, the grade caps of 19 named roads), test_hill_districts,
  test_bellerive_hills, test_hill_heights_are_flat_checks,
  test_rail_crossings_are_grade_separated, test_country_joins_the_city,
  test_movers_stand_on_hill_ground, test_flora_kit_and_hill_ecology,
  test_heli_walls_and_mountain_stop_it, and a labels check (>= 5 peaks).

## Step 0: measure (in HANDOFF-hill-country-archive.md; metric in tools/hill_area.py)

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
  Larkspur Knob; existing ground, only labelled now, so three tops are new). Designed 165-265 m; the cap keeps them lower.
- **Roads** (mountain_plan.py, tag "hills" except the two shortcuts):
  East Hills Road (lane, 2.6 km) from Old Post Road (2750,-2010) up the
  hills' east side to Route 9's end; a track to each top (Copperback,
  Whistler, Tallow, Fernmoor, plus Tallow Top and Whistler Top to the true
  tops); shortcuts Copperback Cut (Whistler-Copperback) and Spur Track
  (Tallow up the north-east spur to East Peak, 3.8 km of switchbacks);
  Tallow Trail along the crest; back-country lines into the gentle ground
  the first build left unreached: Fernmoor Ridge Track (Tallow round the
  low north ridge to Fernmoor, 1.25 km), Brackett Track (dead end west
  from East Hills Road into the south hills, 0.9 km), Hollin Trail (from
  Route 9 up the west flank, a dead end: joined to Spur Track it wound
  round through a hairpin and broke its grade) and Moor Trail (Fernmoor west to
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

## Result (tools/hill_area.py, 2026-10-31)

Hill ground 4.85 km² (was 3.54); true rolling hills (50-450 m, gentle,
reached) 3.10 km² (was 1.86): 50-120 2.04, 120-200 0.62, 200-300 0.24,
300-450 0.20. Ask "3 km² or more": met. Not clipped to the play area.
Clipped to the play area: 3.07 km². In-game test_east_hills: the hills'
box (x 1800..3000, y -4750..-2550) in the play area holds 1.21 km² of
gentle 50-450 m ground (HILL_KM2 1.1; the old terrain held 0.62, so the
check fails on it).

## Design map (tools/hill_design_map.py, 2026-10-31)

`docs/hill_country_design_map.png`: the land as built (with the Morrow)
plus PROPOSED content, numbered 1-25 with a key panel; nothing built. The
tool prints each place's height, slope and nearest way, line lengths and
the rail's tunnels. Zones: quiet (Fernmoor, Whistler-Tallow ridge, high
range to x 1880), busy (Hollin Crossing, East Hills Road strip, Copperback
race country) with a 250 m ring, the forest (tint on hills only). East
Hills Road crosses the quiet ridge as a through way; the race loop
(existing ways) is drawn only south of y -3340. Places sit on ground with
slope <= 0.36 unless the cliff is the point (mine, bungee, summit set):
Brackett village (2412,-2116), Hollin Crossing village with the sawmill
(1448,-4408), truck stop (2790,-2310), shady motel by Route 1, trailer
town, race start, jump, 2 raves, cult (2316,-4024, 108 m off Spur Track),
4 springs, logging camp on the Morrow's far bank (-332,-4300; no flat
ground on the near side), ranger post, 2 hotels, mine, stone ring,
bungee, parachutes, Calder Trail downhill. Secret lab in a real hollow
(528,-4048), 129 m up, rim +247 m, 232 m from any way; no public way
enters its box; guarded road (dashed red, 285 m, needs switchbacks) up the
outlet from the gate on Route 9 (472,-4288). Haul: log bridge over the
Morrow to Route 9. Sky bridge North Knob-Raven Peak (798 m). Rail branch
Freight Line to Corran Commuter at 2 %: 1.9 km, 1.6 km of it tunnel (the
hills stand 45-110 m over both ends), so #110/#111 decide if it is worth
it. Water traced from the ground: Raven Creek through the lab hollow to the
Morrow, Hollin creek to Fernmoor Pond, Copperback brook to Tallow Lake
(2248,-4144, 57 m), Whistler brook east. Not placed: wildlife (forest zone
only), small-town events (busy zones only). Crossings need #110.

## Traps

- A via point at a turn back (Spur Track's old (1950,-3750)) forces a
  hairpin whose legs the 8 m grid cannot keep apart: 26.7 % over 32 m.
  Let the planner choose the switchbacks.
- A trail joined at a hairpin wound round through it (cut 2 m) and broke
  it; Hollin Trail is a dead end instead.
- Trails are ungated for grade. Over 32 m on the 8 m grid: Hollin 0.47,
  Tallow 0.32, Moor 0.27 (older: Calder 0.56, Raven 0.59). Known, fine on foot.
- On the map each new top's peak label and its view_ landmark share a
  position, so the viewpoint icon sits on the label. Left as is.
- mountain_check "steepest" is a 4 m spot value; the gate is the 32 m
  check in test_mount_calder (list new driven lines there).

## Decisions

- East apron for the hills (why: HANDOFF-hill-country-archive.md).
- Grass is not part of this: it is optional, 6-10 h, and it is a separate
  rendering job. It can follow once the land is final.
