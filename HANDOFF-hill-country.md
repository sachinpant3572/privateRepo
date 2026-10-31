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

## Design (step 0)

- **East Hills**, new: the east apron becomes rolling hills. Three new
  knobs on short crests, linked by saddles to East Peak (1760,-2880):
  Tallow Knob (2750,-3700) ~300 m, Whistler Hill (3050,-2750) ~240 m,
  Copperback (2700,-2050) ~200 m. The ground between them rolls at
  60-180 m with slopes mostly <= 0.35, easing to 0 at the play-area edge
  (x ~3450) and keeping the Larkspur village flat (2350,-950).
- **Roads**: East Hills Road (lane class, paved) from Larkspur north
  through the saddles to the north side of the range; a dirt track up to
  each new knob; two 4x4 shortcut tracks over saddles (Whistler-Copperback,
  Tallow-East Peak); trails along the crests.
- **Viewpoints**: a gravel pull-out with a rail and a bench and a map
  icon on each new knob, plus Raven Peak, East Peak and Hawk Peak (each
  on its own road or track). The summit deck stays data only (#113).
- **Target**: hill ground >= 5.0 km² overall and the 50-450 m band
  reached >= 3.0 km² (from 1.86). The tests pin the new peaks, the
  roads' grade caps and the hill-ground figure.
- **Not in this step** (later, on Sachin's word): rivers, lakes and ponds
  in the valleys (the design keeps the valleys open for them), the huge
  forest, places, wildlife, events. Bridges and tunnels need #110.

## Decisions

- East apron for the new hills: it is the only large gentle ground left
  in the play area with no roads, far from the city (no CITY_FADE clash),
  and next to East Peak, so new crests join the range naturally. Rejected:
  raising the south foothills (hill districts and the city edge there are
  pinned by tests), and the north (y < -4800 lies outside the play area).
- Grass is not part of this: it is optional, 6-10 h, and it is a separate
  rendering job. It can follow once the land is final.
