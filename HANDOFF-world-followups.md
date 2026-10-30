# World follow-ups (Sachin, 2026-10-30: "Yes to all these please")

The open list and the go-ahead list from the world-build report: camera test,
two mountain roads, rail sharing Route 9, Solvera rail-road crossings, pump
house, cruise terminal, reviewer Lows, Liberty City-sized map (~8 km² land,
4-6 sessions), helicopters (#82, heli part only). Phases #110-#113 are NOT
approved by this.

## Done

- **Camera test** (test_perspective_camera): the tower spots filled the six
  inside spots first, after which no random spot was checked for a hidden
  player. The search now carries on past them. Committed.
- **Slope check** (build_country.py mountain_check): grade and off-profile
  are measured only where the road has a profile (not over a bridge deck or
  a tunnel). Wheaton's 174 % was its bridge span; Summit Fire's 265 m "off"
  was `profile_at() or 0.0` on profile-less points.
- **Route 9 off the rail** (mountain_plan.py): the rail pass is pinned to
  the gorge's one shelf (2.2 %, 30 m cells, inside the range); every avoid
  cost on the rail either planned the same line or found no path (the A*
  keys states on a 0.5 m height offset, so a cost change can lose the only
  grade-feasible route). So the road moves instead: Route 9 drops its
  (-700,-2400) waypoint (on the rail, with the river right beside it) and
  takes `avoid=(("rail_pass", 30.0, 10.0),)`. Close running (< 28 m) fell
  from 2,460 m to 480 m: two crossings and the road over the rail tunnel.
  Everything after Route 9 (lines joining it) is re-planned with it.
  That 30 m line climbed 15-20 m up the gorge wall above the rail, and
  Wheaton and Dam roads (river, rail, then Route 9) could not climb to it:
  Wheaton 219 %, Dam 113 %, Route 9 86 % where its (-720,-3250) waypoint
  sat 10 m off the rail. Now: avoid 22 m at a high cost (just clear of the
  shelf, near the rail's level), waypoint moved to (-704,-3250), and the
  grader's shared-stretch pins must be in reach of the rail crossings
  (mountain.py). The old line ran 548 m within 8 m of the rail.
- **Level crossings and hugging roads** (mountain.py): a road at a level
  crossing holds the rail's height out to LEVEL_REACH (20 m) from it. Wheaton
  (108 % after that) crosses over the rail and curls back 7-9 m beside it,
  7 m above the rail's strip; each rail crossing now records `hug` (how far
  along the rail the road stays within 20 m) and the rail span covers it.
  Wheaton now 15.1 % (cap 13 %).
- **Summit Fire Road** (mountain.py): graded after Calder (ROAD_ORDER), and
  a road end within JOIN_REACH (20 m) of an earlier road takes its height
  (it stopped 16 m short of Calder's middle and took the terrain instead).
  265 % (fake) -> 32 % -> 31.2 %, worst near its Calder end (1105,-1258).
- **Known planning limits, not fixed**: West Ridge Track 50.7 % at
  (508,-3006) is a switchback leg 14 m from the next with ~11 m between
  them, below the 8 m height grid; Firebreak 30.6 % at its junction with
  West Ridge Track's start (150,-4034). Both are trails, not traffic roads.
- **Hill road pieces 4 -> 3.5 m** (country_tiles HILL_PIECE): at the Canyon
  Freeway / Crest Drive junction (2223,-1247) the ground twists ~1 m per
  8 m cell, and a 4 m triangle's chord sat 5.5 cm off it (test 5 cm).
- **City exits 139 -> 133** after the open land: the city edge moved
  north near Halcyon (y -166 -> -220) and shifted in the east.

## Reference maps (Sachin, 2026-10-30)

Files in reference/world/ref_maps/; what they show is in
HANDOFF-world-followups-archive.md (big blocks, open land, water, clusters).

## Liberty City size (#116): design (to write before building)

Sachin, 2026-10-30, on the sloped-districts option (+40-70 h): "Lets do
these as part of the expansion we are doing to make it as big as Liberty
city. Our city grid only seems to have buildings, no lakes or big parks, or
ponds ... they all have multiple things in between parts from just houses,
corporate buildings." So sloped districts are in #116's scope.

Checked (2026-10-30, /tmp/plan.json): it is not just the map view. The plan
has 613 land blocks and one park block (Liberty Green, ~3,000 m²), plus
City Hall grounds, Moreau Square, the Esplanade and 8 traffic circles. It
has no lake, pond, big park, golf course, cemetery, stadium, rail yard,
container port or airport inside the city.

Design (2026-10-30). How the plan works now (street_plan.gd "SP"): the
core outline is hand data (world_map cities.bellerive.core, 74 pts,
4.24 km², local x -300..2220, y -570..1945); arterials sit on fixed lines
ART_X / ART_Y_NORTH / ART_Y_SOUTH (SP:142-144, 310-450 m apart); each patch
splits a superblock into a grid ([4,6] gives ~80-110 x 60 m blocks) or a
field (dsep [270, 74]). Open land = a snapped Rect2 in `_voids` (Liberty
Green, PARK_SIZE SP:63); `is_park` handles one park only. `_thin` (SP:2036)
merges blocks by a patch's `cut` chance (only docks uses it). Water: the
Morrow only; the land is cut into north/south banks (SP:627), so a bay
needs new bank logic. Every block is playable (no block cap); tests pin
the size (test_runner :309 km² 3.9-4.5) and block shapes.

Stages, in order (rough cost; xhigh effort suits them):
A. **Open land in the city we have** (~8-12 h). Open-land set pieces as a
   list (kind, rect, water): a central park with a lake (~500 x 280 m), 4-6
   neighbourhood parks with ponds, a cemetery, a stadium, a rail yard and
   container stacks on the docks; `_thin` on the residential patches so
   their blocks grow to ~100-160 m; lakes and ponds drawn in city_cells and
   on the maps; tests for parks, water and block sizes.
B. **Grow the core to ~8 km²** (~14-20 h). Outline east and west (the Gulf
   is south, the range north), more ART lines, new patches with big blocks
   (industrial and port dsep ~[400, 140]), a golf course and an airport edge
   as open land, then re-run urban, country and their tests.
   Where it can grow (checked 2026-10-30 on world_map.json): water on
   three sides. The Morrow runs down the core's west side (local x -750
   -> -350, y -650..1350), turns east under it and south to the Gulf at
   x ~1550; the Gulf is south, the coast diagonal south-east, the range
   north. Room: (1) **west across the Morrow**, local x ~-1500..-450, y
   ~-300..1700 (~2 km²; flat, no terrain grid there), on the plan's
   "south" piece (the bend's outer side), reached by bridges carrying
   Magnolia, Aurum and Crescent west; (2) **north-east** into Verdant
   Hills, x ~1500..2700, y ~-500..300 (~1 km²). With the foothills in C
   that reaches ~8 km². Country terrain grid: origin (-864,-5112), 8 m,
   541 x 606 (ends at y -264). East: the coast runs (2250,1150) ->
   (3450,250), so land east of the core to x ~3000-3300 at y -600..600.
   Build approach (stage B, before editing): (1) world_map core = current
   core union a west lobe (x -1600..-300 incl. the river) and an east lobe
   (x 2000..3100, y -600..700), wobbled, then `build_country.py --urban`;
   plan bounds follow the core bbox. (2) street_plan: ARTERIALS with bank
   "south" for the west borough (x and y lines, new road names), new
   patches (west industrial dsep ~[400,140], west residential, east
   patch on bank "north"), Magnolia/Crescent/Aurum carried over the
   Morrow's west leg as bridges like the Morrow Bridge (b0/b1 code in
   _layout). (3) districts in city.gd (patch prefix -> district) and
   world_map districts; open land: golf course, airport edge. (4) tests:
   km² range, exits, block counts; check city build time on load.
   Plot helper: scratchpad planplot.py (plan.json -> png).
   Stage B layout (2026-10-30, decided before editing; worktree /tmp/bwt):
   - River banks are picked by side (`_chain`: nearest chain the river does
     / does not lie between from (300,300)); mean height swapped them once
     the core crossed the west leg.
   - New arterial lines without moving old streets: ART_X gains -1300,
     -1000 (west) and 2480, 2820, 3150 (east); ART_Y_SOUTH gains -580..860
     in front. `_splits` keys shift by the count prepended (as -580 did).
   - West inner strip (river to x -390) cut off by a seam at x -390:
     Magnolia Heights (north of Crescent, style heights) and Blackwater
     Bayou (south, style bayou), both world_map districts already.
   - West bank: seam x -330 parts it from Morrow Point; Tallow Bank (new,
     industrial, big blocks); Aurum and Crescent cross the west leg on
     bridges (class bridge) where the country's Route 40 / Route 1 bridges
     were. Presidio runs on there with no bridge.
   - East: seam on Mangrove (x 2130) north of Crescent; Verdant Park (new,
     style heights) with a golf course (open land, kind golf). The airport
     marker (local 1750,300) sits on the stadium: left for later.
C. **Sloped districts** (~40-70 h, Sachin's yes): the foothills north of
   the city as hill districts (hill_n's contour rings, Vinewood-style):
   city ground on a height field, roads graded, buildings stepped onto it,
   traffic, people and cameras on heights.
D. **A bay and a beach borough** (~10-16 h): a second water body in the
   plan (bank logic), a barrier-island beach borough reached by 2-3
   causeways (the existing bridge class).
Total ~72-118 h. Cheaper option: A + B only (~22-32 h, ~8 km², flat, no
bay); D can be dropped and the beach kept on the Gulf shore.
Milestone APK after A (with #114 and the helicopters), then after B, C, D.

Stage A build (2026-10-30, approach before editing):
- street_plan.gd: OPEN_LAND list {id, kind, at, size, lake}; `_open_land()`
  after `_thin` kills the district links (edge_patch >= 0) between land
  blocks whose middles lie in the site, keeping the graph joined and never
  merging a landmark's block; each site is a set piece (kind park /
  cemetery / stadium / railyard / containers). Sites sit between
  arterials, so no arterial crosses them. Lakes are plan polygons
  (`lakes`), not river water (is_water_point would make the face "water").
- Sites: Halcyon Park + lake (wards_n, x 1010-1460, y -220..140); parks
  with ponds in quarter_w, point_w, point_e, havana_e (Liberty Green stays);
  Old Morrow Cemetery (south bank); Bellerive Bowl stadium (x 1470-1760,
  y 150-490); container yard and rail yard on the docks.
- city.gd block_style returns the kind; city_cells.gd builders per kind
  (trees capped per block for the frame budget); lakes have a stone rim
  and a railing with collision (no swimming in the game, so no walking on
  water). map_image draws lakes as water and the kinds in their colours.
- wards / wards_n get `cut` so their blocks grow (bigger blocks).
- Tests: each site came out as one block of its kind and size; lakes in
  their block; landmark blocks kept; land area still in range.
- Built (stage A): sites as above, all 9 one block each; ponds 2,000-2,500
  m², Halcyon lake ~19,000 m². Halcyon covers y -120..140 (not the whole
  superblock), so the outline still trims its north row; covering it made
  Presidio a 450 m straight city edge. `_grow_blocks` never takes an
  open-land block for a landmark (the Ferry Building took the rail yard).
  Bigger residential blocks: a wards `cut` 0.3 was tried and reverted (it
  left streets stopping short, breaking the streets-run-through rule); big
  blocks come with stage B's new patches (re-cutting the old ones moves
  every landmark lot and test-pinned block shape). The rail yard moved to
  x 1010-1115 so the Ferry Building keeps its lot (face 116, 129 x 98).

## Recorded for later phases (reviewer Low #7)

- The reserved rail corridor (phase 4) crosses Lantern Blvd where it meets
  the Morrow Bridge's north approach (city x ~330). Trains (#111) need a
  grade separation there; it is not built and not approved.
- Solvera Line grade separations: the map has a flyover or overpass at each
  crossing (tools/mountain_world_map.py); country.json carries those in the
  play area as `planned` structures. Track and road stay at grade until the
  grade-separation phase (#110, not approved).

## Traps

- country.json and mountain_lines.json are single-line multi-MB files:
  never grep them (output overflow); read them with python json.
- Blocked hosts: sportskeeda.com, bragitoff.com, wixmp.com.
