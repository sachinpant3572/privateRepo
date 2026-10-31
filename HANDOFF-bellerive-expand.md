# HANDOFF: Bellerive build-out (fill the planned outline to city grade)

Sachin, 2026-10-28: "Yes please, also expand belleriv as we discussed earlier".

## Reading of the request (BX-0)

- "As we discussed" = the size options given earlier: A, keep the planned outline (4.7 km², 2-3
  sessions, "build out the city, including the remaining wealth phases"); B, Liberty City size
  (about 8 km², 4-6 sessions). Taken as **A** (recommended, and in line with "the city keeps its
  planned size", HANDOFF-wealth.md). B stays open: almost all of A carries over to it.
- The outline [5550,6550,2700,1750] is already covered by streets: the plan in the middle, the
  country-layer suburbs round it (P-7). What the suburbs lack is city grade: no pedestrians, no
  parked cars, no enterable places. The east side is 595 near-identical 15 x 30 m houses (606 of
  672 homes T2), and the wealth ladder has no dense poor block and no T5 tower.

## Survey (2026-10-28)

Inside the outline: eastside 623 lots, bayou_town 121, beach_town 109, shore 101, heights 84
(+ estates as plots). Kinds: house 681, cape_house 98, deco_hotel 64, bar 41, shack 43,
stilt_house 24, beach_bar 22, shopfront 12, condo_tower 11, mansion 11, strip_mall 8,
garden_apartments 7, diner 6, gas_station 3, civic 9.

## Decisions

- **BX-1 Suburb sidewalks for people.** The generator polygonises the country road graph inside
  the outline, cuts each road's half width plus the sidewalk middle (1.25 m) out of each block,
  and stores the remaining block rings as `walks` (closed loops, points every ≤6 m, local
  metres). city.gd appends them to `sidewalk_loops` with a grid index, so pedestrians, cops and
  `nearest_sidewalk` use them like plan loops. Rejected: walking along edge polylines (peds would
  need a new graph walker; loops reuse pedestrian.gd unchanged).
- **BX-2 Parked cars in the suburbs.** Kerbside spots were the plan, but the country street and
  avenue classes are 4 lanes wall to wall (HANDOFF-wide-roads), so there is no parking strip.
  Instead the kit's drive cars on home lots in the suburb zones become live parked cars: with
  `Kit.live_cars` on, the kit records each drive car as a `{"park", "yaw", "tier"}` entry in `out`
  instead of a static mesh; country_tiles turns them into world spots and appends them to
  `city.parked_spots` (stable indices, one set per lot), so population fills them like city spots.
  As built: zones in country_tiles LIVE_CAR_ZONES; a spot is [pos, yaw, open]; country.gd opens a
  tile's spots on load and closes them on unload, and population skips closed spots.
- **BX-3 Suburb places.** Diner, general store, shopfront and strip-mall lots inside the outline
  get place records (diner, corner_store), with the door at the kit building's door. Interiors,
  maps and the phone already iterate `city.places`.
- **BX-4 Wealth phase 2 kinds** (country kit, built by a parallel agent; it owns
  scripts/kits/country_kit.gd): `res_tower` (T5: penthouse crown, roof pool, doorman canopy,
  garage ramp), `midrise_condo` (T3-T4), `cheap_block` (T0-T1 walk-up block, outside stairs and
  walkways), `exec_house` (T4, three-car garage, pool), `gatehouse` (estate entry with a boom
  gate). Shady kit kinds (motel, liquor_store, pawn_shop, check_cashing, sro_hotel,
  bungalow_barred, burned_lot) become buildable on country lots too.
- **BX-5 Wealth phase 3 placement, suburbs only.** Cheap blocks and the shady strip by the freeway
  and industry on the east side; residential towers on the Brisa Beach front; mid-rise condos on
  the shore and along arterials; exec houses where V is highest in the Heights flats and the east
  side; lots sized by tier inside the house kind (T3-T4 wider). City-side placement (Midtown and
  Gilt towers, cheap blocks in the Wards) is left for later: it changes city_cells, and the
  suburbs are what this request is about.
- **BX-5 as built (upgrade_lots in tools/build_country.py, before lot_reach).** By land value
  (wealth.value): the 30 poorest east side house pairs (neighbours on one frontage, 17 m pitch)
  merge into one lot each, 24 `cheap_block` and every 5th a `liquor_store`; the 35 poorest single
  east side lots become 20 `bungalow_barred`, 5 `pawn_shop`, 5 `check_cashing`, 5 `burned_lot`;
  the 12 richest pairs on the east side and 12 in the Heights flats `exec_house`; the dearer half
  of Brisa Beach's condo towers `res_tower` (7); the best third of the shore/east/fringe garden
  apartments `midrise_condo` (9) and the worst 4 `cheap_block`; the cheaper third of the hill
  mansions off estates `exec_house` (5). A refitted lot stays within 0.75-1.27 of its kind's size,
  keeps its front line and never grows, so no new overlaps (self-check: 0). Each straight-on
  estate (12 of 19) gets a `gatehouse` lot inside its gate, the drive and tree rows starting
  behind it. Result: 2054 lots, wealth ladder 0 problems, T0-T5 74/285/707/393/137/19.
  Not done: "lots sized by tier inside the house kind" (exec houses carry the wide lots instead).
- **BX-6 Bayou town bars.** 40 of 121 bayou-town lots were bars (the style asks for about 1 in 9).
  Cause: dwellings there go in 48-64 m clusters; a failed cluster moves on 4 m and redraws, and a
  16 m bar fits where a cluster can't, so bars filled the gaps. Fix: in cluster styles a shop or
  bar stands at least CLUSTER_SHOP_GAP (220 m) from another of its kind.
- **BX-3 detail.** Places.build_suburbs picks up to 16 diner/general_store/shopfront/strip_mall
  lots in the suburb zones, spaced like the city's (SPACING, MIN_GAP); face and parcel are -1.
  The door point mirrors each kit front (Places.suburb_door).

## Gates

tests/run.sh after each game-code change; country preview after each generator change; shots
of a suburb street with people and parked cars, a place door, and the new kinds; APK 0.20.

## Review outcome (one run, 2026-10-28)

- Fixed: a home's stalls and bays (about 2.6 m apart) used the 4 m occupancy radius, so a car in
  one stall blocked the next; spots with a tier now use 2 m. The live-car test now counts spots
  left open on unloaded tiles. The kind test now builds the shady kinds too (they take the 8k
  big-lot budget: scrapyard and housing_project reach 5.1k-7.2k triangles).
- Not fixed, unreachable: "a lot refused by try_lot loses its car tier". `try_lot` with
  plot >= 0 never refuses.
- Left as is: `Kit.live_cars` is a static flag set and cleared round each build, the same
  pattern as reach, wealth and route_step. Safe while builds stay on one thread.
- Noted: regenerating shifted the towns' lot counts (Larkspur 33 to 25 lots, Wheaton bars
  2 to 7).

## Open questions

- None. Next work (enterable places and brands) waits on Sachin's pick from
  BRANDS_AND_PLACES_PLAN.md.

## Traps

- Regenerate: `python3 tools/build_country.py <plan dump>`; plan dump:
  `godot --headless -s res://tests/plan_dump.gd -- out.json`.
- Lot coordinates in country.json are local (state minus origin [6150, 6650]).
- test_people_walk_the_suburbs was written for BX-1 but left out of the runner's list, so it
  never ran until BX-2 added it. A new test must go into `var tests := [` in test_runner.gd.
