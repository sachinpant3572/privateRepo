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

## Liberty City size (#116): design (to write before building)

Open. Draft direction: new boroughs across water with large blocks
(120-250 m, buildings filling them, mid-block alleys not streets), 1-2 big
parks, docks; existing districts thinned (drop minor streets where blocks
are < ~4,000 m²). Cost and options to be written here before the build.

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
