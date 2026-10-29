# Bellerive at Las Venturas size, California + San Fierro + Florida

Sachin, 2026-10-29: "Make Bellerive the size of Las Venturas then, but with
California + San Fierro + Florida mix." (After being told Bellerive's city
is ~2.6 km² of land against San Fierro 3.2-3.6, Las Venturas 4.1-4.2,
Liberty City 8.06, Los Santos ~10-12.) This lifts the 2026-10-28 "keep the
planned size" rule for the city; #104 (organic outline) carries on inside it.

## Target

- City land (as test_city_outline_is_organic measures it: land inside the
  edge loops, sampled every 20 m) **4.1-4.3 km²**, from 2.62 km² now: about
  +1.6 km². Las Venturas: 4.1 km² of land in named districts, 4.2 km² engine
  box (reference/world/gta_san_andreas.md 1.2).
- The outline stays organic (fill < 0.8, no straight edge run > ~420 m).

## Geography (local metres = world - (6150, 6650))

- Now: core bbox (-300,-330)..(1660,1800); the Morrow River comes down the
  west side and crosses the city east-west at y ~1110-1220, then turns south
  to the Gulf at (1550, 2000). The Gulf coast is y 2000 in the south and
  runs diagonally (1450,2000)-(2250,1350)-(2750,650) in the east. The
  Bellerive Hills (terrain grid x 152..2232, y -1848..-408, peaks ~72 m) lie
  just north; their foothills are 0-15 m at y -600.
- Growth, three directions:
  - **North, San Fierro** (~0.35-0.45 km²): the edge moves from y ~-330 up to
    ~-700 between x ~0 and ~1300, onto the foothills. Painted Victorian rows
    (style "painted" exists), a Chinatown (new style), a cable car line from
    downtown up the hill, a hilltop park with a tower, a crooked street.
  - **East and south-east, Florida** (~0.8-0.9 km²): from x ~1460 out to the
    beach, taking in Brisa Beach (now country beach_town / eastside suburbs).
    Ocean Drive along the sand with Deco hotels, palms, lifeguard towers and
    condo towers; a Little Havana strip (calle with low pastel shops) behind.
  - **South bank to the Gulf** (~0.2-0.3 km²): Morrow Point grows down to the
    coast (y ~1960): a waterfront with piers (SF Embarcadero / FL marina).
- California stays the frame: the arterial grid and boulevards run on into
  the new districts, palms along them, strip malls on the arterials.
- The New Orleans Lantern Quarter, the DC civic centre and Manhattan Midtown
  stay (built, missions use them); the request adds a mix, it does not ask
  to remove them.

## Decided

- **SF district flat for now (2026-10-29).** Feasibility read (Explore):
  cars, people, camera, blood, debris and birds already follow
  Terrain.height and there is no ground collider, but the city builds its
  ground and streets from large flat primitives (city_cells.gd:214, 219,
  273, 284, 312, 323, 329; lots :173) with y = 0 throughout. Real slopes need
  an offline grading of the city street graph (like tools/mountain.py), a
  drape pass with subdivided ground and road pieces, building plinths, and
  lifted lenses and doors, plus Terrain.drop returning 0 inside the city
  (country.gd:438-470 would sink cars 0.26 m). Estimate 40-70 h for one
  0.5-0.8 km² district. Chosen: SF flavour on flat ground at the foot of the
  Bellerive Hills (painted rows, Chinatown, cable car, piers, hilltop view
  on the real hill behind), ~16-23 h for the whole growth. Real slopes are
  the bigger option for Sachin to switch to.

- **Core = old core + four lobes (2026-10-29).** Lobes in local metres:
  sf (-290..520, y to -570), ne (1420..1800, y to -200), florida (1450..2220,
  y 180..1820, 70 m inland of the Gulf), south (-80..1430, y to 1945).
  World-map shapely: core 4.16 km², land 3.86 km². Built with /tmp/co/grow.py
  (union, buffer 15/-15 mitre, simplify 4). The north edge stops at the
  mountain's foot (y -430 for x 270..1640): the hills' FALLOFF ends there.
- **Street plan for the growth (street_plan.gd).**
  - Arterials: ART_X += 2130; ART_Y_NORTH = -580 + old + 1580; ART_Y_SOUTH
    += 1990. Superblock bounds that were no road inside the city now are:
    Presidio Ave (y -220), Hibiscus (x 1460), Tamarind (x 1770), Mangrove
    (x 2130), Gulfview (y 1610 south), Pelican (y 1760 south). (Before, y
    1610 and x 1460 gave 126-200 m blocks.)
  - Seams: Presidio (y -220, west to Rampart) splits off **hill** (west of
    Lantern; Cable Hill, painted Victorian rows) and **china** (Lantern to
    Rampart; Jade Gate, new chinatown style). Hibiscus seam (x 1460, Crescent
    to Seagrape) ends the Wards and Ironwharf (Wharf St stops at 1460).
    **Seagrape Ave** (diagonal 330 m inland, parallel to the Gulf, dir
    (0.776,-0.630)) and **Ocean Drive** (75 m inland, the city's sea edge)
    bound **brisa** (Brisa Beach: grid turned -39 degrees to the coast, Deco
    hotels on Ocean Drive, condos behind). Between Hibiscus, Crescent and
    Seagrape: **havana** (Calle Luna: city grid, low pastel shops).
  - Liberty Avenue now ends at Seagrape (T junction) instead of the east
    edge. North of Crescent, east of 1460, the Wards North grid runs on.
  - City arterials on x clip out of the brisa region (its own grid).
- **Edge falloff**: outline edges within ~80 m of the Gulf are not edges
  for EDGE_OPEN/EDGE_LOW (the hotels front the sea).

## Traps carried over from #104

- The trim's notch/spur rules: outline wiggles must be 2+ blocks to show.
- Country package (agent, worktree) is generic over the core: rerun its
  generator after the core changes.
- perf_probe, 0.25.2 (c2cc2c2) and HEAD run back to back on one machine
  (2026-10-29): visible 31.3k/29.7k parked, 43.0k/34.3k fast; totals
  106k/115k parked, 110k/118k fast, 108k/107k fast again, 99k/93k parked
  fit 1.4. Only the shadow pass differs, both ways: no regression. (The
  earlier 123k/145k was a lone run, not like for like.)

## Built (2026-10-29)

- Styles: **painted** (Cable Hill, Victorian rows), **chinatown** (Jade Gate,
  `chinatown_row`), **havana** (Calle Luna, `havana_row`, bungalows),
  **beach** (Brisa Beach, `deco_hotel` on Ocean Drive, condos behind). Kits
  in civic_kit.gd (~2091-2249); style tables in map_image, traffic, sky,
  vehicle. Shots: `SHOTS=lv` (6 stops, prints each stop's district).
- Small-lot guards: a Deco hotel needs hx >= 9 and hz >= 8 (else
  `_downtown`); `_tower` keeps h >= 8 m (its lobby is 4.6 m; `_downtown(0.4)`
  rolled 4.4 m, a negative BoxShape3D in Calle Luna).
- Kit checks (civic/shady/skyline_check) accept a 4th collider field (the
  breakable Dictionary city.gd reads), as city.gd does.

## Traps (this task)

- Godot `Geometry2D.is_point_in_polygon` counts both edges when its ray
  grazes a vertex: a point 290 m outside the city read as inside. The tests
  use `_in_polygon` (even-odd along +x, half-open) in test_runner.gd.
- test_places_line_the_streets: country suburb shops "Levee Mart" (576,1860)
  and "Sunrise Grocery" (1852,1510) now sit inside the grown core, so city
  colliders block their doorsteps. The country agent's regeneration clips
  country plots out of the core; rerun that test after merging it.
- Street-plan exits come only from roads cut by the trim; a dead-end stub
  is pruned before the trim, so it never makes one. The causeway's exit is
  added after the trim (`_trim_to_outline`, the Ocean Drive junction nearest
  the landing), and world_map's `overseas` line starts at (7736, 8050) so it
  meets that junction square on (a 40 m sideways offset failed the lead-in's
  min radius).
- Country build order: the Golden Flats Expressway is routed right after the
  Beltway (`_flats_expressway`); routed with the farm roads, the suburb
  streets had already taken its west exits.

## Country merge (2026-10-29)

- Merged the country agent's branch (worktree adbfdb7): `--urban` redraft,
  lead-ins to free exits, carry-on streets, tee snapping, looser test floors.
- Urban footprint: **5.44 km² accepted** (fill 0.732). The agent's 4.72 km²
  aim was the old city box, not a target Sachin set; city land (the
  4.1-4.3 km² target) is measured on the street plan, not the footprint.
- Self-check after the fixes: 0 highway ends off an exit, 0 unreached nodes,
  112 of 158 exits used.

## Curved roads, Option A (Sachin 2026-10-29: "Lets do A for now")

Research: reference/world/curves_and_map.md. On hold: Sachin asked for rough
top-down sketches of A, B and C first. Sketch:
reference/world/curve_options_sketch.png (game/tools/curve_options_sketch.py
on a plan dump). Sachin then chose a mix: C's tensor field, B for Cable Hill,
A's 1-2 curved roads, roundabouts and the hand-placed set pieces. Four mix
variations: reference/world/mix_options_sketch.png (game/tools/mix_sketch.py).
Waiting for his pick of 1-4. In the sketch, field arterials don't always meet
the roundabouts; in the build, put roundabouts where field arterials cross.
- Drafted, never run (street_plan.gd): CURVES (Mirador, Canyon) and BOWS
  (amp*sin(pi*t) row bends); superseded by the mix. Map (#107) comes after.
