# World follow-ups (Sachin, 2026-10-30: "Yes to all these please")

The open list and the go-ahead list from the world-build report: camera test,
two mountain roads, rail sharing Route 9, Solvera rail-road crossings, pump
house, cruise terminal, reviewer Lows, Liberty City-sized map (~8 km² land,
4-6 sessions), helicopters (#82, heli part only). Phases #110-#113 are NOT
approved by this.

## Done

- Done, detail in the archive: camera test; slope check measures only
  profiled road; Route 9 off the rail (avoid 22 m, waypoint moved); level
  crossings flat to 20 m and `hug` spans; Summit Fire graded after Calder.
  Residual grades: Wheaton 15.1 % (cap 13), Summit Fire 30.9 %.
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
   Design detail (where it can grow, build approach): the archive.
   Stage B build (2026-10-30): core 6.89 km², urban 8.42 km², plan land
   faces 6.10 km², 156 city exits. Outline rules learned:
   - `_trim_to_outline` keeps a block by its centre, then drops one-
     neighbour spurs and refills three-neighbour notches: an edge step must
     be 2 blocks deep or long, or a corner (a corner block has 2).
   - Outline past ART_Y_SOUTH[0] (-580) makes tall faces out to the plan
     bounds; the west lobe's north edge stays at -520, with a corner notch
     (col x -1209..-1104, row -473..-335) breaking a 429 m north run.
   - East lobe pulled back from the coast (y >= -500, notch to -390);
     Fairway Drive dropped; golf at (2295,-40) between Mangrove and Juniper.
   - River banks are picked by side (`_chain`); ART_X gains -1300, -1000,
     2460 (Juniper), 2780 (Sycamore); `_splits` keys shift by the count
     prepended to ART_Y_SOUTH.
   - West: seams x -390 / -330 part Magnolia Heights, Blackwater Bayou,
     Tallow Bank (industrial) and Morrow Point; Aurum and Crescent cross
     the west leg on bridges. Civic void stops at Laurel.
   - Serena Causeway: `_split_at_landing` gives Ocean Drive a junction at
     the landing (1753,1657); land clipping drops the collinear vertex, and
     the nearest junction can sit 40 m off (country lead-in fails).
   - Landmarks moved out of the west lobe: Krewe Hall (-1620,860), Hale
     estate (-1650,-250, now sun-turned so one estate turns). The east
     lobe took most Verdant Hills fields (177 -> 66; field floor now 50).
   - Core corner (-250,1135) -> (-250,1095): keeps the docks freight spur
     out of the city; Bayou Drive's bank stops 40 m short of any rail it
     would cross under 30 deg (the spur's loop at (-238,1199)).
   - Country: a merged junction keeps the city exit's position (averaging
     put one 7.3 m off plan node 448); a shallow axial estate (no room for
     a court behind) shrinks its house up to 8 m to fit tennis beside it.
   - Tests re-measured: downtown falloff by block centre (generator's
     measure); roof x-ray picks a shelter whose roof runs along the view;
     Golden Flats: the expressway fords the Morrow nowhere.
   - The street field was NOT regenerated (no new field patch).
   - Suite fixes: heliport aprons kept clear in the country; a district
     with one block shares it for its shop; `_thin` rolls by a link's
     midpoint (new streets shifted one stream and re-cut the docks) and
     never joins a landmark or open-land block (re-dump the plan before a
     country rebuild); interact boards a waiting cab before a shop door;
     a cab's curb stop is capped at the lanes' edge less half a cab
     (CURB_SHIFT put it on the sidewalk of the 28 m street at Union
     Station). Residual: seed 1 only, the_pit sits in the containers site
     (`_open_land`'s prune merges it); the game seed is clean. City build
     (seed 1234, headless): 1794 / 1675 ms before (d4ec25e), 2044 / 1873
     ms after, about +13 %; the plan alone is 1356 ms.
   - Review fixes: a mission REPLAY mid-flight finished the bail's fall at
     the start point (`stand_at` now clears it); a forced exit over a roof
     falls to open ground (`open_ground_near`); rail yard wagon count fits
     short tracks. City proper is ~6.9 km² after B (8.4 with the fringe);
     ~8 km² of city needs stage C. Open: one open-land cell can add 240
     trees in one main-thread add (phone hitch unmeasured; MultiMesh later).
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

Stage A build (approach in the archive):
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
