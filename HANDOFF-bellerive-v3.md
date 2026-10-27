# HANDOFF: Bellerive v3, a blend of DC, New York and California, with government buildings

Task (Sachin, 2026-10-27): "Check California, Washington DC, New York maps from top down view and
build similar map, taking few things from every region and part of them. For the first map
Bellariva, whatever it is. For the main city part and outskirts of it. Also, do build Govt
buildings too".

## Starting point (verified in code, 2026-10-27)

- The city core is a runtime street graph (`street_plan.gd`, seed 1234). It has five districts:
  Gilt (downtown: Union Station, Aurum Tower), the Lantern Quarter, the Floodline Wards, Ironwharf
  and Morrow Point. They are cut apart by named seam roads. The window is 1300 x 1456 m, with 13
  landmarks and missions 1-3 placed on landmarks.
- The outskirts are generated offline (`tools/build_country.py`). They are simple grids of streets
  carried on from the city's frame junctions: Magnolia Heights (west), the north fringe, the east
  side, the south shore, Brisa Beach and Blackwater Bayou.
- Earlier research for Concordia (`reference/world/real_cities.md` section 1) already covers DC,
  Manhattan and SF. The new research covers LA, the suburbs, NY and DC civic sites, and government
  building types.
- Imagery can't be opened from the container (DNS fails for map and tile hosts), so "top-down"
  facts come from search summaries and the earlier research.

## Decisions

- B-1 **Blend, don't replace.** Bellerive keeps its river, seams, districts, landmarks and missions.
  Each borrowed pattern goes where it fits, as a set piece the generator places. Rejected: a fresh
  map. It would move every landmark and mission, for a similar look and about twice the cost.
- B-2 **Concordia overlap.** Concordia (the planned capital) still gets the full DC plan later.
  Bellerive borrows a smaller civic version (a mall axis, one circle, radials), because it is the
  city and county seat, not the state capital. So: no capitol, but a city hall, courts, federal
  offices, police and fire headquarters.
- B-3 **What goes where (city core):**

  | Pattern | From | Where in Bellerive |
  |---|---|---|
  | Mall axis with a domed hall at its head, government buildings along both sides, reflecting pool | DC National Mall, SF Civic Center | Gilt West: "The Esplanade", City Hall at the west end |
  | Traffic circle with an obelisk where the avenues meet | DC circles, Washington Monument, NY Columbus Circle | Founders Circle, at Lantern Boulevard and Liberty Avenue |
  | Radial avenue meeting the hall's grounds | DC Pennsylvania and Maryland Avenues | Magnolia Avenue rerouted round the City Hall grounds |
  | Long thin blocks, avenues wider than streets | Manhattan 1811 grid | Gilt East and South become "Midtown" |
  | Diagonal cutting the grid, bowtie plazas with billboards | Broadway at Times and Herald Squares | Liberty Avenue across Midtown: "Liberty Square" |
  | Long park with a lake and a loop drive | Central Park | Liberty Green, longer, with a pond |
  | Square park ringed by painted Victorian rows | SF Alamo Square | Moreau Square, Wards North |
  | Ferry building with a clock tower on the waterfront | SF Ferry Building, Embarcadero | Ironwharf quay, at the foot of Rampart Avenue |
  | Brownstone rows and a river promenade, over the bridge | Brooklyn Heights, Brooklyn Bridge | Morrow Point |
  | Palm-lined boulevards | LA Wilshire and Sunset | Lantern and Crescent Boulevards |

- B-4 **What goes where (outskirts):**

  | Pattern | From | Where |
  |---|---|---|
  | Straight palm-lined streets, then winding estate roads | Beverly Hills flats and hills | Magnolia Heights |
  | Rowhouse blocks with rear alleys | DC Capitol Hill | North fringe |
  | Arterial superblocks with strip malls and gas stations at the corners, and curving streets and cul-de-sacs inside | LA valley, Irvine | East side |
  | Curved loop streets of identical small houses, and a village green with shops and a pool | Levittown, Long Island | South shore |
  | Pier with a Ferris wheel and a coaster | Santa Monica Pier | Brisa Beach |
  | Fire station, post office, DMV, sheriff station, public school with fields | Any US suburb | East side, south shore and Heights |

- B-5 **Government buildings** (new kit `scripts/kits/civic_kit.gd`):
  - city landmarks: City Hall (domed, DC and SF), County Courthouse (portico and steps, NY Foley
    Square), Federal Building (Federal Triangle block round a courtyard), Public Library,
    Police Headquarters, Main Post Office (long colonnade), Fire Headquarters, Founders Obelisk
    and reflecting pool, Ferry Building;
  - suburban kinds: fire station, post office, DMV office, sheriff station, public school;
  - homes: brownstone row, painted-lady row, DC rowhouse row, Levittown cape, pier with rides.
- B-6 **Who builds what.**
  - Main session: the city plan set pieces (`street_plan.gd`, `city.gd`, `city_cells.gd`,
    `world_map.json`), integration and tests.
  - A parallel agent: `civic_kit.gd` (new file only).
  - A second agent: the outskirts patterns in `build_country.py` and `grounds_kit.gd`.

  Agents do not touch each other's files or `test_runner.gd`, and they do not commit.

- B-7 **City plan as built** (`street_plan.gd`, all local metres):
  - **Set pieces** (`set_pieces`, `_holes`): district streets are clipped out of each set piece's outline, and a ring street closes it.
    - Founders Circle: centre on Lantern at y = 296, ring radius `CIRCLE_R` = 46 (avenue class).
    - City Hall grounds: 100 x 120 m, 296 m west of the circle.
    - Esplanade: `MALL_WIDTH` = 64 between two drives.
    - Moreau Square: 88 m, turned 30° to the Wards North grid.
    - Named roads (Lantern, Liberty, Magnolia) stop 3 m inside the circle and the grounds; the stubs are pruned.
  - **Midtown:** one patch replaces gilt_e and gilt_s. The grid is at 8°, streets 44-50 m apart, avenues (`cls_v`) 100-112 m apart, with no cuts or jogs.
    - Liberty is no longer a seam, so it crosses the grid. At the 21° crossing, `_drop_overlaps` offsets the avenue by 13 m along Liberty: a jogged bowtie.
    - Rejected: avenues as u-lines. Liberty would then cross the streets at a shallow angle and leave dozens of slivers.
  - **Liberty Green** is 230 x 95 m; `PARK_AT` is (850, 555). The plan dump now reads `City.PARK_AT`; it had hard-coded the old spot.
  - **`LANDMARK_FACING`** prefers a side facing that way when it fits as well. The Esplanade buildings face the mall and City Hall faces east.
- B-8 **Landmarks added** (world_map.json, type `government` unless noted):
  - city_hall, county_courthouse ("Parish Courthouse"), federal_building, public_library;
  - police_headquarters (type police), main_post_office, fire_headquarters;
  - liberty_square (type plaza, an LED tower by the bowtie);
  - ferry_building (type station).

  Aurum Tower moved to (420, 215), clear of the circle.
- B-9 **Districts:** Midtown (style `midtown`: taller towers ×1.4, 12% LED towers). Morrow Point's style is now `brownstone`. Wards blocks that front Moreau Square become `painted` rows.
- B-10 **Boulevard trees:** palms every 12 m, except where the streetcar runs through the Quarter, which keeps oaks (St. Charles Avenue).

## Cost (rough)

| Option | Scope | Time |
|---|---|---|
| Chosen | City set pieces, outskirts patterns, government kit, gates | About 10-14 hours of agent work, 3-5M tokens, one long session |
| Cheaper | City civic center and government buildings only; outskirts unchanged | About 5-6 hours |
| Cheapest | Government buildings dropped onto existing blocks; no map change | About 2-3 hours |

## Open questions

- Freeway interchanges (LA): left out. The world is flat and has no ramps; about half a day later.
- Traffic circles are two-way rings, because the traffic system has no one-way streets.

## Traps and constraints

- The plan used to dump identical across builds. Now it will change on purpose: check missions
  1-3, the landmark tests and the country links after each plan change.
- Landmarks are world_map.json points, local = map - (6150, 6650). Blocks grow to fit
  `LANDMARK_LOTS`.
