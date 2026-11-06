# California from the top down: street patterns, districts and places (for Bellerive)

Research for Sachin's request of 2026-10-27. He said Bellerive "looks more like Delhi", with "literally all" streets
diagonal. He wants mostly big parallel roads with only a few diagonal or uneven ones, plus skyscrapers, monuments
and shady places, all fictional and modelled on California seen from far out and then zoomed in.

**Tags.** [V] means a source states it (URL given). [M] means I measured it from real geometry (file named).
[I] means inferred or general knowledge not checked in this session.

**Renders** (in `reference/world/california/`, about 0.7 MB in all):

| File | What it shows |
|---|---|
| `01_california_zoomed_out.png` | Fully zoomed out: 58 counties, the outlines of 4 cities, and every bus route of 17 agencies, which trace the arterial grids |
| `02`-`05_*_neighbourhoods.png` | Region views: LA basin, San Francisco, San Diego and Oakland, with neighbourhood names and bus routes over them |
| `10`-`16_*_arterials.png` | Zoom-ins of the arterial network: central LA, San Fernando Valley, Irvine, Inland Empire, Fresno, Coachella desert, San Diego. Each route is coloured by angle: dark = main grid, blue = second grid, green = third grid, orange = diagonal or curved |
| `20_sf_downtown_soma_mission_streets.png` | Zoom-in on every street: real OSM streets, coloured the same way, with closed blocks filled |

`metrics.json` holds every number tagged [M] below. `src/` holds the scripts that made the renders and numbers.

**Data used** (all fetched from raw.githubusercontent.com; [M] facts name these files):
- `codeforamerica/click_that_hood` `public/data/{california-counties,los-angeles,san-francisco,san-diego,oakland}.geojson`: county and neighbourhood polygons.
- `aickin/visualize-density` `data/transit/agencies/<agency>/shapes.txt`: 2017-18 GTFS route shapes for 17 Californian bus agencies.
  - **What it measures.** Bus routes run on arterials, so these trace the big roads. They do not trace local streets.
  - **What it misses.** An arterial with no bus is missing, so a measured gap can be twice the true spacing.
  - **How I used it.** I removed overlapping routes by resampling every 25 m and keeping only unique samples.
- `willgdjones/grand-tech-auto-sf` `web/public/art/district-roads/*.json`: 329 cells of OSM roads (with highway class) for central SF, about 4.3 x 6.4 km.
  - The cells come from a fan game. I checked their axes against lon/lat OSM: Eddy St, Market St and Mission St bearings match exactly. Some cells are missing, mostly the Financial District and the far north.
- `gboeing/osmnx` `tests/input_data/West-Oakland.osm.bz2`: 66 ways only, too small to render; used for numbers only.

**Method [M].**
- **Grid share:** the length-weighted street bearing (mod 180) falls within +-5 deg of a grid's two axes. I fitted up to 3 grids, best first.
- **Arterial spacing:** I scanned the network in its own grid frame for roads that run straight through at least 25% of the window, then took the gaps between neighbouring roads.
- **Blocks:** I polygonized the drivable network (no service roads, no footways). Block sizes are the sides of each block's minimum rotated rectangle.

---

## 1. Zoomed-out California: regions and what each stands for

**From the state view** (`01`): urban California is a few dense patches (Bay Area, Sacramento, Fresno, Bakersfield,
the LA basin running into the Inland Empire, San Diego). Between them lie farmland, desert and mountains, crossed by a few
long highways [M from the render]. Each dense patch is a **grid**, and from far out every one looks like graph paper,
not a web [M: renders 10-16].

| Region | Street pattern | Buildings | Landmark types | Character |
|---|---|---|---|---|
| **Downtown LA** (Bunker Hill, Financial District, Historic Core) | Own grid tilted about 36 deg: 62% of arterial length within +-5 deg of 36/126 deg [M la_dtla_core]. Old Spanish plan aimed at 45 deg; the river forced 36 deg [V KCET] | Towers 150-335 m on the hill, 1900s-1920s 8-13 storey commercial blocks below [I] | City-hall tower, concert hall, old theatres street [I] | Office core by day, empty by night; Skid Row on its east edge [V Chamber, see 5] |
| **Hollywood Hills / Beverly Hills / Bel-Air** | Grid "flats" south of the main boulevard; curving hill roads north of it. Beverly Hills flats lots about 15 x 37.5 m [V via bellerive_patterns.md] | Mansions, gated drives, palm-lined streets | Hillside letter sign, observatory on a ridge [V/I, see 4] | Wealth, celebrities, privacy |
| **Westside / Santa Monica / Venice** | Coast-aligned grid at about 54/144 deg: 51% of arterial length, 78% within 3 grids [M la_westside] | Low-rise apartments, beach houses, a few mid-rises | Pier with rides, boardwalk, canals | Beach tourism, money, homeless camps at the edges [I] |
| **South LA** | Strict cardinal grid: **91% of arterial length within +-5 deg of N-S/E-W; only 4.6% diagonal or curved** [M la_south] | Single-storey bungalows on small lots, corner stores, strip malls on arterials [I] | Coliseum and museums park [I] | Working-class, poorer; liquor stores and churches on corners [I] |
| **East LA / Boyle Heights** | Grid broken by freeways and the river channel [I; render 10, NE] | Bungalows, murals, small shops [I] | Bridges over a concrete river channel [V 1938 channelization: KCET] | Working-class, old immigrant gateway [I] |
| **Industrial belt** (Vernon, the river corridor, Port of LA/Long Beach) | Superblocks of warehouses, rail yards on diagonals [I] | Meatpacking, cold storage, container yards | Cranes, container stacks, rail bridges | Vernon: 222 residents (2020) but about 50,000 daily workers; "exclusively industrial" [V Wikipedia]. Busiest US container gateway: 10.3M + 9.6M TEU in 2024 [V ttnews] |
| **Orange County (Irvine)** | Rotated master-plan grid of wide arterials (39% at 38/128 deg) plus curving parkways (29% curved or diagonal) [M 12]. Villages separated by six-lane arterials [V Wikipedia] | Identical tract houses, office parks, malls | Ring roads, lakes, greenbelts | Safe, rich, bland |
| **Anaheim / Santa Ana** (older OC) | 75% of arterial length cardinal; arterials about every mile (1.6 km) [M oc_anaheim] | Tracts, strip malls | Theme-park resort zone [I] | Mixed |
| **San Fernando Valley** | 68% of arterial length cardinal [M 11]. Boulevards every half mile, 31 in a row [V garbell, informal]. Bus-carrying N-S boulevards measured every 1.5-1.7 km [M] | Ranch houses, strip malls, studios | Studio backlots, dam basins | Suburban, film industry, "the Valley" |
| **Inland Empire** (Ontario/Fontana) | 88% cardinal; arterials at 800 m and 1.6 km (section lines) [M 13] | Giant warehouses; Ontario alone holds over 112.5M sq ft [V freightwaves 2022] | Airport, rail yards, truck stops | Logistics, cheap housing, long commutes |
| **Central Valley** (Fresno, Bakersfield) | Section-line roads one mile apart [V Wikipedia; townshipamerica]. Fresno: 86% cardinal; gaps 775-900 m and 1.5-1.75 km [M 14]. Downtown on a 45-deg railroad grid (8%) [M]. Bakersfield: 77% cardinal, gaps about 1.6 km [M] | Farms, packing sheds, low towns | Water towers, grain elevators, canals | Agriculture, poverty pockets, meth-belt reputation [I] |
| **Desert** (Coachella, Victorville) | Sparse mile grid (67% cardinal) plus one long valley highway on the diagonal (17% at 38 deg) [M 15]; Victorville 49% cardinal [M] | Resorts, golf, trailer parks, empty lots | Wind farms, dry lakes [I] | Retirees and resorts versus trailer poverty [I] |
| **San Francisco** | Two grids meet at Market St [V Wikipedia]. Measured: **70% on the north grid (83/173 deg), 22% on the SoMa grid (46/136 deg), only 6% other** [M 20] | Victorian rowhouses, SRO hotels, a tower cluster | Bridge, cable-car hills, domed city hall, big park | Tech money next to the Tenderloin |
| **Oakland / East Bay** | Many small grids, each rotated to its own shore or slope: the top 3 grids hold only 55% [M oakland_flats]. West Oakland itself: **96% on two grids, 0.4% other** [M West-Oakland.osm] | Victorians, port, rail yards | Lake in the middle of town, cranes | Port and rail town, working-class [I] |
| **San Diego** | Mesas and canyons break the grid: 33% cardinal, 61% within 3 grids [M 16]. Downtown blocks 200 x 300 ft (61 x 91 m); the Gaslamp is 16 blocks [V SD Reader, TCLF] | Downtown towers, bay front, mesa suburbs | Harbor, naval yards, big park with museums | Navy, tourism, border [I] |
| **Silicon Valley** | Mile-spaced arterials (gaps about 1.6 km) on several rotated grids; 42% other [M silicon_valley] | Low campuses in parking lots | Ring-shaped campus [I] | Rich, sterile [I] |
| **Sacramento** | Downtown grid at 15/105 deg (25%) inside cardinal suburbs (35%) [M sacramento] | Capitol mall, rowhouses | Domed capitol | Government town [I] |

---

## 2. Street pattern rules, with numbers

**2.1 Most streets are parallel. Diagonals are rare.**
- **San Francisco (central):** of 364 km of drivable street, 70% sits within +-5 deg of one grid and 22% within +-5 deg of the second. Only **6%** is diagonal or curved (the freeway ramps, Market St itself and a few hill streets) [M 20].
- **West Oakland:** 0.4% off-grid [M].
- **South LA arterials:** 4.6% off-grid; Fresno 4.4%; Inland Empire 6.3% [M].
- **Central LA, 20 x 20 km:** the cardinal grid holds 48%, the downtown grid 14% and the coast grid 10%. The remaining 28% is mostly hill roads in the Hollywood and Baldwin Hills, a few long diagonal boulevards, and bus runs on freeways [M 10].
- **Rule for Bellerive [I from M]:**
  - Flat districts: 90% or more of street length on the district's grid, and no more than 10% diagonal or curved.
  - Hill or coast districts: up to 30% curved.
  - Whole city: no more than about 20% off its grids.

**2.2 Arterial spacing: a big road every half mile, sometimes every mile.**
- **LA:** the median arterial gap in central LA is **800 m** (p25 500, p75 838). 46% of gaps are 700-900 m, 17% are 350-450 m (quarter mile) and 9% are 1.5-1.7 km (mile) [M 10].
  - South LA shows the rhythm clearly. The across-grid gaps run 400, 825, 800, 800, 800, 825, 800, 425, 400 [M la_south].
  - Downtown LA, on its own grid: gaps of 750, 825 and 775 m [M].
- **Planning rule:** principal arterials every 1 mile, minor arterials every half mile [V Riverside County, cited in bellerive_patterns.md].
- **Suburbs on section lines:** Inland Empire, Anaheim, Bakersfield and Silicon Valley carry bus arterials every **1.6 km** (one mile), with an 800 m road between them in places [M]. Section lines are 1 mile apart [V Wikipedia "Section line road"].
- **Inside SF** the big streets are much closer together. In SoMa, the six long 45-deg streets are **190-200 m** apart and the numbered cross streets **280 m** apart. In the Mission, the N-S streets are 170-180 m apart, and wide E-W streets come every 190-390 m [M 20].

**2.3 Local streets and blocks.**
- **SF, measured:** 1,259 closed blocks with a median area of **13,400 m^2** (p25 7,300, p75 16,900). The median block is **86 x 147 m**, a long-side to short-side ratio of 1.7 [M 20].
  - North of Market, streets are 100-110 m apart one way and 140-160 m the other [M].
  - SoMa's big blocks are split by alleys every 60-130 m [M].
  - The source grids: the north 50-vara blocks are 412 x 275 ft (126 x 84 m) [V Wikipedia SoMa]. SoMa blocks are larger and aligned with Mission St, with triangular lots where the grids meet at Market [V Wikipedia].
- **West Oakland blocks:** median 90 x 140 m (6 blocks only, so a weak sample) [M].
- **San Diego downtown:** blocks 61 x 91 m. Horton made them small to get more corner lots [V SD Reader, Frommer's].
- **LA streetcar-suburb blocks:** about 330 ft (100 m) [V properscale blog, weak]. Lots about 50 x 100 ft (15 x 30 m); 5,000 sq ft minimum in most single-family zones [V Streetsblog LA].
  - So about **7 local streets** lie between two half-mile arterials [I].
  - Residential blocks are long and thin, with their long side along the arterials and 2-row lot depth on the short side [I, consistent with the SF ratio of 1.7].

**2.4 Where the few diagonals come from.**
- **An older survey or settlement grid next to a newer one:** DTLA's 36-deg grid against the cardinal grid, with the seam at Hoover St [V KCET/PBS SoCal]. SF's two grids meet diagonally at Market St [V Wikipedia].
  - **Seam rule [I]:** the seam is **one** long, wide, straight boulevard. Triangular lots and small plazas line it. Each side keeps its own grid. Nothing in between is random.
- **Old roads and rail lines:** the long diagonal boulevards in render 10 cut across the grid, mostly in the west and south-west of the window. In Fresno the downtown sits on a 45-deg railroad grid [M 14, I for the cause].
- **Coast and valleys:** Santa Monica's grid follows the shore (54/144 deg) [M]. In the desert, the one diagonal highway follows the valley [M 15].
- **Section-line jogs:** roads bend slightly where survey corrections occur (standard parallels) [V KVPR].

**2.5 Where curves come from.**
- **Hills:** the Hollywood Hills, Baldwin Hills and San Diego canyons [M orange in 10 and 16].
- **Post-war and master-planned suburbs:** curved streets on slopes, cul-de-sacs, and T-intersections to slow traffic. FHA guidance discouraged the gridiron as "costly and monotonous" [V NPS NRHP nomination; Santa Ana city doc].
  - Irvine: a rotated grid of wide arterials with curving parkways, and villages inside with ring roads and cul-de-sacs [V Wikipedia; M 12].
  - **Curves sit inside a cell bounded by straight arterials. The arterials themselves stay straight [I from render 12].**

**2.6 Freeways.** Freeways are the big curves and diagonals. They cut across the grids on their own lines and do not follow
streets [I; render 10 orange runs]. Caltrans' minimum interchange spacing is 1 mile urban and 2 miles rural
[V via bellerive_patterns.md]. One freeway with interchanges every 1-2 arterials is enough for a city window [I].

**2.7 How two grids meet** (LA and SF):
- **DTLA [V KCET]:**
  - Ord's 1849 survey extended blocks south from the plaza at 36 deg.
  - The grid rights itself to N-S/E-W at Hoover, the old city edge.
  - Expansion after 1896 switched to the cardinal grid.
- **SF [V Wikipedia]:** Market St was laid out to mediate between the two grids. From render 20 (read by eye, not counted) [I]:
  - most north-grid streets end at Market in T-junctions or acute triangles;
  - a few cross it with a kink.

---

## 3. Skyscrapers: how towers cluster

- **LA:** most towers over 500 ft (152 m) stand in north-west downtown, west of the 110 freeway (Bunker Hill); the rest are mostly in Century City [V Wikipedia list].
  - The tallest is 1,100 ft (335 m, 73 floors, 2017, height from its spire); the next is 1,018 ft (310 m) [V Wikipedia].
  - The second cluster sits about 15 km west of downtown on the arterial grid, not on the downtown grid [I from the map].
- **Flat-roof helipad rule:** LA required a rooftop emergency helicopter landing area on high-rises (often described as 75 ft and up) from 1958 or the 1970s, depending on the source, until 2014. That is why its skyline is flat-topped.
  - The 2014 change exempts buildings of 420-1,000 ft that add fire-service elevators or extra stairs [V Beverly Press; Patch; ABC7].
  - Game use: most Gilt District towers get flat roofs with a painted H pad; only the newest one or two get spires [I].
- **SF:** the tallest is 1,070 ft (326 m); the pyramid tower is 853 ft (260 m) [V Wikipedia list; ABC7]. Most tall buildings are in the Financial District [V].
- **Falloff [I]:**
  - The core is a tight knot of about 10-20 towers spread over roughly 6-10 blocks.
  - Heights step down to 8-15 storey blocks within 2-3 blocks of the core, then to 2-4 storeys.
  - Plazas sit at tower feet, with a sunken or stepped plaza on one corner.
  - Freeways or the river ring the core.

---

## 4. Monuments and landmark types (all to be fictional; no real brands, people or religious buildings)

| Type | Real reference (for scale only) | Game version [I] |
|---|---|---|
| Hillside letters sign | 45 ft (14 m) letters, 350-352 ft (107 m) long, on Mount Lee (1,708 ft) [V Wikipedia mirrors] | A 9-letter fictional name on the Magnolia Heights ridge, readable from downtown |
| Observatory on a hill | On the south slope of Mount Hollywood (1,625 ft summit) [V geographyworlds]; its own elevation not verified | White domed observatory with lawn and switchback road, above the hills |
| Pier with rides | Santa Monica pier 503 m long, 2-acre amusement deck, 85 ft wheel [V via bellerive_patterns.md] | 250-300 m pier at Brisa Beach, Ferris wheel and coaster at its root |
| Big coliseum | Stadium in a museums park south of downtown [I] | Arched oval stadium in a park on the Floodline edge |
| Stadium in a ravine | Ballpark set in a hill ravine above downtown [I] | Ballpark in a dug-out bowl with terraced parking |
| City hall tower | SF dome 307 ft (94 m) at the end of a two-block plaza axis [V via bellerive_patterns.md]; LA has a stepped tower [I] | Stepped white tower on a plaza axis in the Gilt District |
| Big bridge | Golden Gate main span 4,200 ft (1,280 m) [I] | Suspension bridge out of the city window (skyline backdrop); a steel truss bridge over the river |
| Big park | Golden Gate Park 1,017 acres, about 3-3.5 mi x 0.5 mi [V CA OHP; Wikipedia] | Long rectangular park with lakes, 2-3 blocks wide |
| Cemetery park | Hillside memorial parks [I] | Walled lawn cemetery without religious symbols; mausoleum-like stone halls |
| Art museum on a hill | Hilltop museum campus reached by tram [I] | White stone museum on the Magnolia Heights spur with a funicular |
| Mission-style plaza | Old pueblo plaza at the DTLA grid origin [V KCET] | Arcaded adobe-style plaza with a fountain and market stalls; **no chapel or religious building** (WORLD_BIBLE rule) |
| Concrete river | LA River channelized after the 1938 flood, 1936-1959, about 2M cubic yards of concrete [V KCET, PBS SoCal]; "51 miles" is from a weak source | Bellerive's river runs in a trapezoid concrete channel through the industrial and Floodline stretch |

---

## 5. Shady places and poor districts (places, not people; crime is never tied to any ethnic group)

- **Tent blocks by warehouses:** Skid Row covers about 50 blocks (0.4 sq mi) between 3rd and 7th St and between Main St and Alameda St, on the east edge of downtown next to warehouses and missions [V LA Chamber brochure]. Some sources say it is now closer to 40 blocks [V city source].
  - Game: 4-6 game blocks of tents along warehouse walls, between the tower core and the rail and river corridor.
- **SRO hotels:** the Tenderloin has about 31 blocks in under 0.5 sq mi, holding "the world's largest collection" of historic SRO residential hotels [V Tenderloin Museum; Wikipedia]. SF has about 530 SRO hotels (undated) [V KQED].
  - Game: 5-8 storey brick hotels with fire escapes, sitting right against the tower core.
- **Motels on arterials, liquor stores, pawn shops, check-cashing [I]:** these sit on corners of the arterial grid in South LA style districts, in strip malls with parking in front.
  - Mini-mall origin: over 600 built after 1973, often on old gas-station corners [V via bellerive_patterns.md].
- **Chop shops, scrapyards, auto-body rows [I]:** these sit in the industrial superblocks near rail lines and under freeways.
- **Rail yards, abandoned lots, underpasses [I]:** these sit along the diagonal rail corridor, with freeway undercrossings, tagged walls and fenced lots.
- **Housing projects [I]:** a superblock of 2-3 storey barracks-style blocks around courtyards, cut out of the grid.
- **Bungalow grids [I]:** single-storey houses on 15 x 30 m lots, with security bars and chain-link fences.
- **Industrial-only town [V Vernon]:** a whole district with almost no residents, packing plants and warehouses, and a crowd of workers by day.

---

## 6. Mapping to Bellerive

**Scale assumption [I].**
- **Arterial spacing at 1:4.5:** real arterial spacing is 800 m, so arterials come every **180 m** in game (1.6 km becomes 360 m). That gives about **7 arterials across** the 1,300 m window and **8 down** the 1,456 m.
- **Blocks at about 1:1.5-1:2:** real blocks of 85-150 m become 55-100 m. At 1:4.5, local streets would be 20 m apart, which cannot fit buildings, so blocks get a milder scale.
- **Grid pitch:** keep the current 52 m pitch as the short side of a block. Make blocks rectangular, 52 x 88 m (the measured 1.7 ratio), with **2-3 local streets between arterials**.
- **Result:** 1 arterial per 3-4 block pitches in the core and 1 per 4-6 in the suburbs.

| Bellerive district | Californian pattern | Grid angle | Arterial spacing (game) | Block (game) | Diagonals / curves | Must-have places |
|---|---|---|---|---|---|---|
| **Gilt District / Midtown** (north of river) | DTLA Bunker Hill + SF Financial District + Century City | **City grid +30-36 deg**, aligned to the river like DTLA [V/M] | 160-180 m | 52 x 80 m | Only the seam boulevard (Market/Hoover-style) where it meets the cardinal grid | Tower knot of 10-15 flat-roof helipad towers plus 1 spire; city-hall tower on a plaza axis; sunken plaza; seam boulevard with triangular lots |
| **Lantern Quarter** (old quarter by river) | Old pueblo plaza + Gaslamp | Same angle as the Gilt grid (it is the origin) | 120-150 m | **40 x 60 m** (SD's 61 x 91 m scaled) | None inside; quarter edge cut by the river curve | Arcaded plaza (no church), 2-4 storey brick, nightlife street |
| **Floodline Wards** (east) | South LA + Boyle Heights + Skid Row | **Cardinal (0 deg)**: 91% on-grid in South LA [M] | 180 m, with a 90 m "quarter-mile" collector between | 52 x 100 m long blocks | One diagonal rail line + the river channel; less than 10% off-grid | Bungalow grid with bars, motels and liquor/pawn/check-cash on arterials, tent blocks by warehouses at the downtown edge, a projects superblock, coliseum park |
| **Ironwharf** (docks) | Port of LA/Long Beach + West Oakland + Vernon | Cardinal, or aligned to the quay | 250-360 m | Superblocks 120-200 m | Curving rail spurs into yards; freeway on a viaduct | Container yard and cranes, rail yard, scrapyards and chop shops, packing plants, Victorian rowhouse pocket (West Oakland) |
| **Morrow Point** (south bank) | SoMa / Mission | Its own grid at 45 deg to the north bank; **the river is its "Market St"** [M SF 22% grid] | Wide streets every 90 m one way and 130 m the other (SoMa's 190/280 m scaled) | 52 x 90 m with mid-block alleys | Freeway ramps only | Warehouse lofts, mural alleys, SRO strip, taco stands (generic), underpasses |
| **Magnolia Heights** (west hills) | Beverly Hills flats + Hollywood Hills + Bel-Air | Cardinal flats below a main boulevard; contours above | Flats 180 m; hill roads follow contours | Flats 40 x 75 m, deep lots | **Up to 30% curved, all of it above the boulevard**; cul-de-sacs, switchbacks | Hillside letters sign, observatory, museum on a spur, gated mansions, one palm species per street |
| **Blackwater Bayou** (swamp) | Delta levee roads / Ballona wetlands [I] | None | 1-3 levee roads | n/a | Curves follow levees | Stilt shacks, boat ramps, hidden chop shop, dump |
| **Brisa Beach** | Santa Monica + Venice | **Coast-parallel grid** (Santa Monica's is 54/144 deg [M]) | 160-180 m | 40 x 70 m | Boardwalk and coast road curve with the shore | Pier with wheel and coaster, boardwalk, canals 9 m wide about 50 m apart, beach motels |

**Generator rules [I, from the M numbers]:**
1. Each district has one grid angle: cardinal for most districts, river-aligned for Gilt/Lantern, coast-aligned for Brisa, 45 deg for Morrow Point.
2. Districts meet along one straight seam boulevard or along the river, never through a band of random angles.
3. Every 3rd or 4th street is an arterial, 4-6 lanes, straight through the whole district.
4. City-wide off-grid length stays under about 20%; flat districts stay under 10%.
5. Curves appear only in hills, on the coast and levees, on rail spurs, and on 1-2 freeways.

---

## 7. What could not be verified

- **Missing street data:**
  - No full LA street centerlines (Census TIGER, LA open data and Overpass are blocked, and no GitHub copy was found). LA local block sizes rest on weak sources, and **LA numbers cover arterials only** (bus routes).
  - No usable San Diego street geometry: the OSM neighbourhood extracts found hold only fragments, so I dropped those renders. SD street numbers are from MTS bus routes and the SD Reader.
  - The SF street data has gaps (Financial District, Nob Hill and Chinatown cells are missing).
- **Bus-route limits:** spacing measured from bus routes is an upper bound wherever an arterial has no bus (SFV, Irvine).
- **Unconfirmed figures:**
  - Arterial spacing of 1 mile in Irvine.
  - The elevation of the observatory.
  - Coliseum, ballpark and bridge figures (tagged [I]).
  - The 51-mile river channel length.
  - Skid Row population (sources range from 3,668 to 11,000).
  - The start date of the helipad rule (1958 versus the 1970s).
  - Region-wide Inland Empire warehouse totals.
- **Social character:** these lines are general knowledge [I], not sourced.

## Sources

- KCET/PBS SoCal, "Why L.A. has clashing street grids": https://pbssocal.org/shows/lost-la/why-la-has-clashing-street-grids ; original borders: https://www.kcet.org/shows/lost-la/los-angeles-original-borders
- SoMa / Market St: https://en.wikipedia.org/wiki/South_of_Market,_San_Francisco , https://en.wikipedia.org/wiki/Market_Street_(San_Francisco)
- SFV grid: https://garbell.com/SFVgrid.htm ; section lines: https://en.wikipedia.org/wiki/Section_line_road , https://www.kvpr.org/podcast/central-valley-roots/2025-08-02/7th-standard-road-herndon-avenue-how-thomas-jefferson-influenced-the-valley-roads-we-use-today , https://townshipamerica.com/learn/states/california
- Irvine: https://wikiwand.com/en/Irvine,_California , https://placesjournal.org/?p=10440 ; FHA: https://npgallery.nps.gov/NRHP/GetAsset/NRHP/64500221_text , https://publicdocs.santa-ana.org/WebLink/1/doc/225420/Page206.aspx , https://www.pbssocal.org/history-society/the-birth-of-sprawl-how-ending-the-great-depression-meant-inventing-the-suburbs
- LA blocks/lots: https://properscale.blogspot.com/2012/03/density-in-los-angeles-matter-of.html , https://la.streetsblog.org/2013/06/13/integrating-land-use-and-transportation-iii-homes-zone
- San Diego: https://www.sandiegoreader.com/news/2011/may/18/roam-gaslamp-quarter/ , https://tclf.org/gaslamp-quarter-historic-district , https://www.frommers.com/destinations/san-diego/663527
- Towers: https://en.wikipedia.org/wiki/List_of_tallest_buildings_in_Los_Angeles , https://en.wikipedia.org/wiki/Wilshire_Grand_Center , https://en.wikipedia.org/wiki/List_of_tallest_buildings_in_San_Francisco
- Helipads: https://beverlypress.com/2014/10/flat-roof-high-rise-policy-removed/ , https://abc7.com/los-angeles-helipad-new-rule-helipads-buildings-la/329190 , https://patch.com/california/studiocity/la-skyscrapers-no-longer-have-be-so-flat
- Landmarks: https://ipfs.ssi.eecc.de/ipns/en.wikipedia-on-ipfs.org/wiki/Hollywood_Sign , https://geographyworlds.com/blog/hollywood-sign-geography-guide/ , https://ohp.parks.ca.gov/ListedResources/Detail/N2271 , https://kcet.org/history-society/los-angeles-flood-of-1938-cementing-the-rivers-future
- Shady places: https://lachamber.com/clientuploads/LUCH_committee/102208_Homeless_brochure.pdf , https://www.tenderloinmuseum.org/permanent-collection , https://www.kqed.org/news/141726/photo-essay-life-inside-san-franciscos-single-room-occupancy-hotels , https://en.wikipedia.org/wiki/Vernon,_California , https://ttnews.com/articles/port-la-2024-containers , https://freightwaves.com/?p=209021
- Earlier notes reused: `reference/world/bellerive_patterns.md` (section 3, California).
