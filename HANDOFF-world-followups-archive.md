# World follow-ups: archive

Moved from HANDOFF-world-followups.md (2026-10-30).

## Reference maps (Sachin, 2026-10-30)

"See how meticulously the city grid is planned so everything doesn't seem
like only roads and roads." Files: reference/world/ref_maps/ (Leonida fan
map, an extended San Andreas fan map, an island city in Cities: Skylines,
Liberty City from Chinatown Wars). He also linked a GTA V satellite map
(bragitoff.com) and a GTA VI Vice City map (wixmp.com / DeviantArt): both
hosts are blocked here (403), not fetched. GTA V/VI facts:
reference/world/gta_v_vi.md.

What they show:
- **Big blocks, few roads.** Liberty City's blocks are large and full of
  buildings; a hierarchy of a few wide roads frames them. Ours (2026-10-30,
  /tmp/plan.json): 613 land blocks, **median 3,340 m² (~58x58 m)**, p90
  5,570 m²; streets and river take ~41 % of the edge loop's 3.95 km².
  Manhattan: ~80x270 m (21,600 m²).
- **Open land inside the city:** big parks (Middle Park), plazas, docks, an
  airport, beaches. Not every gap is a street.
- **Water splits the boroughs**; few bridges cross it (2-4 per channel).
- **Cities are dense clusters in wild country** (Leonida, SA): a few
  winding roads between them, not road everywhere.

Two more from Sachin (2026-10-30, uploads; files gta_v_satellite.jpg,
gta_vi_leonida_fan_avatarsd.jpg):
- **GTA V:** one city in the island's south corner (~1/5 of the land),
  held between the Vinewood Hills and the sea. Much of the city is not
  street: the airport (as big as downtown), the port's piers and container
  yards, the concrete river channel, a golf club, the beach strip, and
  elevated freeways with interchanges cutting through. The grid is fine
  only downtown and loosens outward. A freeway loop runs round the island
  with small towns along it.
- **GTA VI fan map (Leonida):** several coastal cities round a central
  lake and swamp with few roads between them. A beach borough on a barrier
  island is reached by causeways (Vice Beach). The airport sits inside the
  city. A chain of keys runs south on long bridges.

## Done: follow-up detail (moved 2026-10-30)

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

## Stage A build approach (moved 2026-10-30)

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

## Stage B design detail (#116, moved 2026-10-30)

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
