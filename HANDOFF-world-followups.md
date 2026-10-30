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
