# GTA San Andreas (2004): how the state map was built

Research for Solvera's 4-city state map, Oct 27, 2026. San Andreas is the
closest model: three themed cities joined by countryside on one streamed map.

## How this was researched, and the labels

- **Pages that could not be opened.** WebFetch could not resolve any host,
  and the sandbox proxy refused direct access to Wikipedia, the GTA Wiki
  (fandom), web.archive.org, GTAForums, GTABase, X/Twitter, GameSpot and
  Guinness. For those sites only the search engine's summary of the page was
  read. Each such claim is marked *(summary)*.
- **Search limit.** The shared web-search budget ran out partway through.
  Topics with no source this session are marked **unchecked** (see below).
- **Primary data from GitHub, which could be read:**
  - the reverse-engineered SA engine (`gta-reversed`): world bounds, weather
    regions, population zone types and "levels";
  - Multi Theft Auto (MTA) source: the vehicle list and vehicle types;
  - a community copy of the game's zone table, with 160 named zones and
    their boxes;
  - MTA's 600 x 600 px radar map of the state (1 px = 10 m), used to measure
    land use myself.
- **Labels used on every claim:**
  - **V**: verified by two independent sources.
  - **S**: one source.
  - **I**: inferred. My own measurement or calculation from the data above;
    the method is given.
  - **U** (unchecked): from general knowledge of the game, with no source
    opened this session. Check these before relying on them.
- **Coordinates.** Game coordinates are x east, y north, in metres. One game
  unit is one metre: the GTA Wiki "Unit" page says the 3D-era games
  standardised on 1 unit = 1 m *(summary)* [6], and the car and building
  sizes in the zone table fit that. **S**

## 1. Scale

### 1.1 Map size

- **The box.** The world runs from -3000 to +3000 on both axes, a 6 x 6 km
  square of **36 km²**:
  - the engine defines `WORLD_BOUNDS{-3000,-3000,3000,3000}` and
    `MAX_WORLD_UNITS = 6000` [1];
  - the GTA Wiki gives the same bounds and 36.0 km² *(summary)* [6].

  **V**
- **The streaming grid.** The world is split into 120 x 120 sectors of 50 m
  [1], and the car-path graph into 8 x 8 areas of 750 m each [1d]. **S**
- **Published area figures disagree:**

  | Figure | Source | Method |
  |---|---|---|
  | 36 km² | GTA Wiki [6] | the coordinate bounds |
  | 33 km² (12.7 sq mi) | another GTA Wiki page [6] | not stated *(summary)* |
  | 38.2 km² total: 31.55 land + 6.67 water | KeWiS, GTAForums [7] | bounding rectangle around the map's extreme points, water measured with rectangles, triangles and trapezoids |
  | ~44 km² (17 sq mi) | Guinness World Records [8] | not stated *(summary)* |

  - KeWiS's total is larger than the engine's 6 x 6 km box, so his scale is
    probably a little off.
  - The Guinness figure cannot be reconciled with the bounds; it may count
    the sea out to the edge, or interiors.
  - **Use 36 km²** (6 x 6 km) as the engine truth.
- **My measurement from the radar image** [4]: I classified pixels by
  colour after a 2 px blur.
  - Water: **6.3 km² (17.5 %)**.
  - Land: **29.7 km²**.

  The water figure matches KeWiS's 6.67 km² to within 6 %. **I**, with **S**
  agreement.

### 1.2 City footprints

The engine defines four "levels": `COUNTRY_SIDE`, `LOS_SANTOS`,
`SAN_FIERRO` and `LAS_VENTURAS` [1b]. **S** Two measures of each city's size
follow.

| City | Engine weather-region box [1a] **S** | Land in named city districts (incl. airport, docks, parks) **I** | Named districts in the zone table [3] **S** |
|---|---|---|---|
| Los Santos | x 250..3000, y -3000..-850: 2.75 x 2.15 km = **5.9 km²** | **4.3 km²** | 30 |
| San Fierro | x <-1430, y -580..1430: ~1.57 x 2.0 km = **3.2 km²** | **3.6 km²** | 26 |
| Las Venturas | x >1000, y >910: 2.0 x 2.09 km = **4.2 km²** | **4.1 km²** | 43 (casinos and strip blocks split finely) |
| Desert (not a city) | x -850..1000, y >1280: 1.85 x 1.72 km = **3.2 km²** | n/a | n/a |

- **All three cities** cover about **12 km² of land: 40 % of the land, a
  third of the box**. **I** (land pixels inside city sub-zones.)
- **The administrative boxes** in the zone table are much larger:
  - Los Santos 2.95 x 2.13 km;
  - Las Venturas 2.13 x 2.40 km;
  - San Fierro 1.78 x 2.78 km.

  They include sea and fringe land. [3] **S**
- **Developers on the city size.** In the GTA V era, Rockstar described the
  San Andreas cities as "very small, sketch like cities", which is why GTA V
  went back to one large city *(summary)* [18]. **S**

### 1.3 Distances between cities

Straight-line distances, from zone-box centres [3]. **I**

| Pair | Centre to centre | Gap between the city edges (weather boxes) |
|---|---|---|
| Los Santos Downtown to Las Venturas Strip | **2.8 km** | 1.76 km of Red County and river |
| Los Santos Downtown to San Fierro Downtown | **3.9 km** | ~1.7 km of Flint County and bay |
| San Fierro Downtown to Las Venturas Strip | **4.0 km** | ~2.4 km of bay, Tierra Robada and the Bone County desert |
| Grove Street (Ganton) to San Fierro Downtown | 4.9 km | n/a |

- **No sourced drive times were found.** One search found none *(summary)*.
- **My estimate** of a road trip, inferred from the distances:
  - assume roads run 1.3 times the straight line, at about 30 m/s
    (108 km/h);
  - Los Santos to Las Venturas then takes about **2 min**;
  - either city to San Fierro takes about **3 min**. **I**
- **Car speeds for scale.** The handling table's `fMaxVelocity` is:
  - Landstalker 160;
  - Infernus 240 (fastest stock car class);
  - lorries 110 to 120.

  These are roughly km/h. [5c] **S** for the values, **I** for the units.
- **The longest highway.** The Los Santos Freeway is 5.5 mi (8.8 km) long.
  It is a loop that links Los Santos, Red County and Las Venturas
  *(summary)* [17]. **S**

### 1.4 Land use

Measured from the radar image [4] with the zone boxes [3]. **I** It is
accurate to about ±3 points, because city parks read as green and some city
textures read as sand.

| Class | km² | Share of the 36 km² box |
|---|---|---|
| Water (sea, bay, rivers, lakes) | 6.3 | 17.5 % |
| City districts (land) | 12.0 | 33 % |
| Rural, green (forest, farmland, hills) | 11.9 | 33 % |
| Rural, sand (desert, plus beaches) | 3.5 | 10 % |
| Rural, grey (rock, Mount Chiliad, quarry, towns, roads) | 2.3 | 6 % |

- **Rural land is about 60 % of the land.** It splits 67 % green, 20 %
  desert and 13 % rock or town. **I**
- **By county** (whole administrative box, water included):

  | County | Water | Sand | Green | Grey (rock, built) |
  |---|---|---|---|---|
  | Bone County | 2 % | **70 %** | 24 % | 4 % |
  | Tierra Robada | 29 % | 15 % | 43 % | 13 % |
  | Red County | 21 % | 0 % | 67 % | 12 % |
  | Flint County | 8 % | 3 % | 83 % | 6 % |
  | Whetstone | 10 % | 7 % | 69 % | 15 % |
  | Los Santos (city box) | 26 % | 1 % | 46 % | 27 % |
  | San Fierro (city box) | 19 % | 0 % | 45 % | 36 % |
  | Las Venturas (city box) | 1 % | 17 % | 47 % | 35 % |

  City "green" is overstated: dark city textures and parks read as green.

  **I**

## 2. Layout

### 2.1 How the pieces fit

The state is one island in a 6 x 6 km sea box, shaped like a squared "S".
The layout below is read from the radar image [4] and the zone boxes [3].
**I**

```
 N  +---------------------------+-----------------------------+
    | TIERRA ROBADA (NW)        | BONE COUNTY  | LAS VENTURAS  |
    | Bayside, El Quebrados,    | desert, Area | (NE) Strip,   |
    | Sherman Dam, canyons      | 69, airstrip | airport, rail |
    +----bay (Garver, Kincaid, Gant bridges)--+----river------+
    | SAN FIERRO (W)  |  Easter Bay | RED COUNTY (centre/E):   |
    | hills, grid,    |  airport    | Montgomery, Palomino Cr, |
    | Chinatown       |             | Dillimore, Blueberry     |
    +--------+--------+-------------+-------------+------------+
    |WHETSTONE (SW)   | FLINT COUNTY (S-centre) | LOS SANTOS     |
    |Mount Chiliad,   | forest, farms, river    | (SE) downtown, |
    |Angel Pine       |                         | hood, Vinewood |
 S  +---------------------------+-----------------------------+
```

- **Los Santos (south-east)** faces the sea on the south. Its airport and
  docks sit on the south coast. [3] **S**
- **San Fierro (west)** sits on a peninsula with the Pacific on the west and
  a bay on the east. Bridges carry it north over the bay to Tierra Robada.
  [3][4] **S/I**
- **Las Venturas (north-east)** sits inland in the desert, with only a river
  on its south edge. [3][4] **S/I**
- **A river** runs east to west across the middle of the map. It is the
  border between the green south and the dry north, and it feeds into the
  San Fierro bay. [4] **I**

### 2.2 Counties and towns

The towns below come from the zone table [3] **S**, with sizes from their
zone boxes. Landscape descriptions come from the radar image **I** unless
marked. On real-world inspirations, Simple Wikipedia says Bone County is
based on the Nevada desert *(summary)* [20] **S**; the other inspirations
are **U**.

| County (box) | Landscape | Towns and places (zone size) |
|---|---|---|
| **Red County** (4.2 x 1.4 km) | green hills and farmland, a river, a lake (Fisher's Lagoon), a chemical plant | Palomino Creek 420 x 380 m; Montgomery 460 x 370 m; Dillimore 280 x 270 m; Blueberry 330 x 560 m; Blueberry Acres; Fern Ridge; Hampton Barns; Hilltop Farm; Hankypanky Point; North Rock; The Panopticon (forest); Mulholland (rich hills, inside Los Santos's edge) |
| **Flint County** (1.26 x 2.1 km) | forest and farmland, the least built-up county (83 % green) | Back o Beyond; Leafy Hollow; Flint Range; Beacon Hill; The Farm; Flint Intersection (freeway junction). No real town. |
| **Whetstone** (1.8 x 1.8 km) | Mount Chiliad massif, pine forest, coast | Angel Pine 360 x 370 m (the only town); Shady Creeks (forest, 0.8 x 0.9 km); Shady Cabin |
| **Tierra Robada** (2.5 x 2.4 km plus a strip) | dry canyons, the bay coast, the Sherman reservoir | Bayside 390 x 550 m (with Bayside Marina); El Quebrados 270 x 280 m; Las Barrancas 210 x 240 m; Valle Ocultado; Aldea Malvada 95 x 117 m; Arco del Oeste; The Sherman Dam 490 x 230 m |
| **Bone County** (1.35 x 2.4 km) | desert (70 % sand), mesas, the quarry | Fort Carson 500 x 390 m; Las Payasadas 220 x 240 m; Las Brujas 160 x 95 m; Verdant Meadows (airstrip) 400 x 340 m; El Castillo del Diablo; Octane Springs; Green Palms; Hunter Quarry 520 x 320 m; The Big Ear (radio dish); Lil' Probe Inn; Regular Tom |

- **Town size.** A rural town is typically **0.1 to 0.2 km²**, about
  300 to 500 m across: two to five city blocks. **I**
- **Town spacing.** Along the main routes the nearest towns sit **about 1 km
  apart** (median distance to the nearest town 1.05 km):
  - Dillimore to Blueberry 0.7 km;
  - Fort Carson to Las Barrancas 0.85 km;
  - Palomino Creek to Montgomery 1.05 km.

  Angel Pine is the outlier, 3.2 km from the next town. **I**
- **Distance to a city.** Most towns are 1.1 to 2.8 km from the nearest city
  centre, so each city has "its" towns. Palomino Creek and Montgomery sit
  between Los Santos and Las Venturas (about 1.5 km from each). **I**
- **Named places per area.** The countryside has 53 named places over about
  19 km² of county boxes; the cities have 99 in about 16 km² [3]. **I**

### 2.3 Ghost towns and abandoned places

- **Las Brujas** (160 x 95 m) and **Aldea Malvada** (95 x 117 m) are the
  two smallest named settlements [3] **S**. That they are abandoned ghost
  towns is **U**.
- **Verdant Meadows** is the abandoned airstrip in Bone County that the
  player buys during the story. The zone exists [3] **S**; the purchase is
  **U**.
- **Las Payasadas** is a near-empty desert hamlet **U**.

### 2.4 Mountains, water and the dam

- **Mount Chiliad** is the tallest mountain in the state, in west Whetstone
  *(summary)* [19]. **V** (two wiki pages)
  - Height: the only metric figure found is 527.5 m, from a user-generated
    Q&A page [19], so treat it as low confidence. The 797 m figure belongs
    to GTA V's Chiliad. **S**
  - On the radar image the massif is about 1.5 km across. **I**
- **The Sherman Dam** sits in Tierra Robada at about (-725, 2042), between
  the reservoir and the Bone County canyon [3]. **S** That it parodies the
  Hoover Dam is **U**.
- **Lakes:**
  - Fisher's Lagoon (Red County, 215 x 250 m) [3] **S**;
  - the Sherman reservoir **I**.
- **Swamps.** There is no swamp region; no swamp-named zone exists [3].
  **I**
- **Water as structure.** About 17.5 % of the box is water. The bay and the
  central river split the land into three blocks, one per city, so the
  water is what gates and frames the cities. **I**

### 2.5 Military sites: one big, two small

| Site | Where | Size and features | Penalty |
|---|---|---|---|
| **Area 69** ("Restricted Area") | Bone County desert, north of Fort Carson, near Verdant Meadows *(summary)* [13] **V** | the largest and most secret: four SAM batteries guard it; the No Fly Zone [13] **S** | **instant 5 stars** on entry [13] **S** |
| **Easter Basin Naval Station** | Easter Basin, San Fierro docks [13] **S** | submarine pen, docking points, the assault ship LHD-069 [13] **S**; Easter Basin district 0.55 x 0.63 km [3] | **5 stars** on entry [13] **S** |
| **K.A.C.C. Military Fuels Depot** | north-east Las Venturas [3] **S** | 250 x 235 m zone; one wiki calls it the Military Aviation Fuel Depot [13] | not found |

- **Which is the big one.** Area 69 is the flagship: the only one with SAM
  batteries and its own no-fly airspace. The naval station is a district
  feature, and the fuel depot is a small yard. **I** from [13]
- **The military in general** chases the player at 6 stars [13]. **S**

## 3. Roads

### 3.1 Hierarchy

**Freeways.** A named freeway system loops around and between the cities:
- the Los Santos Freeway (8.8 km) *(summary)* [17];
- the Julius Thruway around Las Venturas, made of four named zones, North,
  South, East and West, each 100 to 320 m wide [3].

**S**

**Engine data.** The engine stores car paths as nodes in 64 areas of
750 x 750 m [1d]. There are no separate road classes in the data seen here.
**S**

**On the radar image** [4] **I**:
- The cities are dense grids:
  - San Fierro: a strict grid on hills;
  - Los Santos: a grid with a freeway ring;
  - Las Venturas: the Strip spine with casino blocks.
- Two-lane highways link the towns.
- Thin dirt tracks run into the hills, the desert and Mount Chiliad.
- Road density outside the cities is perhaps a fifth to a tenth of the
  city grid's. This is a visual estimate, not a measured figure.

### 3.2 Routes between cities

Counted from the radar image and the named bridge zones [3][4]. **I**

| Pair | Main road links | Chokepoints |
|---|---|---|
| Los Santos to Las Venturas | 3 to 4 crossings of the central river: a freeway on **The Mako Span** (Montgomery Intersection), **Frederick Bridge** (east), **Fallow Bridge**, and **Martin Bridge** (west, to Fort Carson) | the river bridges |
| Los Santos to San Fierro | 2 to 3 roads through Flint County and the Flint Intersection freeway junction, plus coast and hill roads past Mount Chiliad | Flint Intersection, the bridges by the San Fierro airport |
| San Fierro to the north and Las Venturas | 3 bay bridges: **Gant Bridge** (to Bayside), **Garver Bridge** (freeway), **Kincaid Bridge** (road and rail); then desert highways past the Sherman Dam and Fort Carson | the three bridges |

- **So each city pair has about 2 to 4 road links.** All of them funnel
  through a named bridge or junction. **I**
- **The rail line.** It is a loop with stops at Unity, then Linden, then
  Yellow Bell, then Cranberry, then Market. That is, it goes Los Santos, Las
  Venturas, San Fierro and back to Los Santos *(summary)* [16]. **S**

### 3.3 Gating and unlocking

- **The in-world reason.** A fictional 1992 earthquake closed the
  inter-county bridges; this keeps the player in Los Santos at the start. No
  earthquakes happen during play, and the bridges show no obvious damage
  *(summary)* [14]. **V** (two wikis)
- **The sequence:**
  1. Los Santos first.
  2. After the mission "The Green Sabre": San Fierro, Flint County and
     Whetstone.
  3. After "Yay Ka-Boom-Boom": Las Venturas, Tierra Robada and Bone County.

  *(summary)* [14] **S** (one guide, Gamepur). Fan sources disagree on the
  details: one wiki says the first reopening is the bridges between Red
  County and Flint County [14].
- **Gant Bridge** is open only at its San Fierro end until Las Venturas
  unlocks *(summary)* [14]. **S**
- **The penalty for trespass.** Crossing into a locked region gives an
  instant **4-star** wanted level. This includes crossing water past a
  blocked bridge *(summary)* [14]. **V** (a guide and a Steam thread)
- **Closing the roads.** The engine can switch whole areas of car-path nodes
  on or off (`m_aNodeSwitches`) [1d], so traffic does not spawn into closed
  areas. **S**

## 4. City themes

### 4.1 The three cities

| City | Real model | Look and landmarks | Factions |
|---|---|---|---|
| **Los Santos** | Los Angeles **U**; Unity Station is modelled on LA's Union Station *(summary)* [16] | Districts from the zone table [3]: Vinewood, Rodeo, Richman and Mulholland (rich hills); Ganton, Idlewood, Jefferson, East Los Santos, El Corona, Little Mexico (poor, gang land); Downtown, Commerce, Pershing Square; Santa Maria and Verona beaches; Ocean Docks; LS International | Ballas, Grove Street Families, Los Santos Vagos, Varrios Los Aztecas. All four are population groups in the engine [1c] **S**. Which gang holds which district is **U** (Grove in Ganton; Aztecas in El Corona and Little Mexico). |
| **San Fierro** | San Francisco **U** | Zone names [3]: Chinatown, Downtown, Financial, Calton Heights, Juniper Hill, Hashbury, Queens, Doherty, Garcia, Easter Basin, Battery Point, Palisades; Avispa Country Club. A steep grid on hills, with a red suspension bridge (Garver) [4] **I** | San Fierro Rifa, Da Nang Boys, Triads [1c] **S**. Triads in Chinatown and Da Nang Boys at the docks: **U** |
| **Las Venturas** | Las Vegas **U** | Zone names [3]: The Strip, Old Venturas Strip, Caligula's Palace, The Four Dragons Casino, The Visage, Come-A-Lot, The Pink Swan, The High Roller, Royal Casino, Starfish Casino; Redsands; Prickle Pine; LV Airport. A flat desert grid with a ring freeway (the Julius Thruway) [4] **I** | The Italian mafia is one engine group [1c] **S**. Leone, Sindacco and Forelli families at Caligula's, and Triads at the Four Dragons: **U** |

### 4.2 How the engine changes the mood by area

This is the cheapest and most useful thing to copy.

- **Every named zone carries data** [1c] **S**:
  - a population type, one of 20: business, desert, entertainment,
    countryside, residential (rich, average, poor), gangland, beach,
    shopping (normal, busy, posh), park, industry, airport, golf club, out
    of town factory, airport runway and others;
  - a strength value for each of 10 gangs;
  - a dealer strength;
  - a "no cops" flag;
  - a bitmask of allowed ped races.
- **Pedestrian groups have one variant per city** [1c] **S**:
  - workers, business, clubbers, rich, average, poor, prostitutes,
    criminals, servants, aircrew and entertainers each come in Los Santos,
    San Fierro and Las Venturas versions (`_LA`, `_SF`, `_VG`);
  - farmers, golfers, desert folk, beach folk and out-of-town factory
    workers come in one version only.

  So the same "poor residential" zone looks different in each city.
- **Density by place.** `popcycle.dat` sets the maximum peds and cars for
  each zone type, by time of day and weekday or weekend [1c]. **S** The
  values themselves were not read.
- **Police by place.** The cop model and cop car change with the current
  level: Police LS, Police SF and Police LV, and Police Ranger in the
  countryside [5a][1e]. **S** (code)
- **Weather by place.** There are 5 regions (default, Los Santos, San
  Fierro, Las Venturas, desert), each with its own weather set [1a] **S**:
  - Los Santos: smog;
  - San Fierro: fog and rain;
  - Las Venturas: never rains;
  - countryside: rain;
  - desert: sandstorms.

## 5. Transport

### 5.1 Airports and flights

- **Four airfields:**
  - Los Santos International (0.95 x 0.55 km) [3];
  - Easter Bay Airport, San Fierro (0.85 x 1.3 km, the largest) [3];
  - Las Venturas Airport (0.54 x 0.74 km) [3];
  - the **Verdant Meadows** airstrip in the Bone County desert [3].

  **S** (zone table)
- **Paid flights between cities: yes.** They are bought at the airport
  passenger doors, through a ticket screen and a cutscene on an AT-400
  airliner *(summary)* [15]. **V** (the GTA Wiki's Airports, AT-400 and LV
  Airport pages, and a GameFAQs answer)
  - Unlocks after the "Learning to Fly" school *(summary)* [15]. **S**
  - One answer also requires San Fierro to be open [15]. **S**

### 5.2 Rail and trams

- **Brown Streak line.** It has five passenger stations [16]: **V** (two
  wikis)
  - **Unity Station** (El Corona, Los Santos);
  - **Market Station** (Market, Los Santos), the state's only underground
    station;
  - **Cranberry Station** (Doherty, San Fierro);
  - **Linden Station** (Linden Side, Las Venturas);
  - **Yellow Bell Station** (north Las Venturas).

  The Sobell Rail Yards lie between the two Las Venturas stations [16].
- **Station placement.** One forum thread complains that the Las Venturas
  stations are small and far from downtown [16]. **S**
- **Train types.** The vehicle list has the Freight and Streak locomotives,
  with freight, flatbed and Streak trailers, plus a **Tram** [5a]. **S** That
  the tram runs only in San Fierro's hills, like a cable car, is **U**.

### 5.3 Taxis and boats

- **Taxis.** There are two taxi models, Taxi and Cabbie [5a]. **S** A
  taxi-driver side mission exists **U**. No sourced taxi fast travel was
  found; I believe San Andreas had none (GTA IV added it). **U**
- **Boats.** There are 10 boat models [5a]: **S**
  - Predator and Coastguard (police and coastguard);
  - Squalo, Speeder and Jetmax (speedboats);
  - Marquis (a yacht);
  - Reefer and Tropic;
  - Dinghy and Launch.

  Marinas exist at Bayside and the Los Santos Marina [3]. Boats have their
  own ambient car group in the population code (`BOATS`) [1c].

### 5.4 Aircraft and other vehicles

- **Totals.** The engine has **212 vehicle models**: 144 cars, 10
  motorbikes, 3 bicycles, 1 quad, 5 monster or off-road trucks, 9 trailers
  and 6 train parts [5a][5b]. **S**
- **Planes (13):**
  - Dodo, Beagle, Cropduster, Stuntplane, Rustler, Nevada and Skimmer (a
    seaplane);
  - Shamal (business jet), AT-400 (airliner) and Andromada (cargo);
  - **Hydra** (a military VTOL jet);
  - the RC Baron (a toy);
  - the Vortex hovercraft, which the engine counts as a plane.

  **S**
- **Helicopters (11):**
  - Sparrow and Seasparrow;
  - Maverick, Police Maverick and News Chopper;
  - Raindance (rescue), Leviathan and Cargobob (heavy lift);
  - **Hunter** (attack helicopter);
  - RC Raider and RC Goblin (toys).

  **S**
- **No blimp.** None appears in the 212 vehicles. **I**
- **The jetpack** is a pickup, not a vehicle. **U**
- **Handling.**
  - Car handling comes from `handling.cfg`, for example the top speeds in
    section 1.3 [5c]. **S**
  - Flying handling is a separate table and was not read.
  - The general picture is **U**: light planes are slow and forgiving, jets
    are fast with wide turns, and helicopters hover. The Hydra and Hunter
    carry weapons.

## 6. Design intent (what the developers said)

- **Three maps became one.** Obbe Vermeij (technical director, SA) wrote on
  the game's 20th anniversary:
  - The original plan was three separate maps, one per city, joined by
    trains and planes, as in GTA 1 and 2.
  - Separate maps would have saved PS2 memory, because the other cities'
    skylines would not be loaded.
  - They would also have made it easy to give each city its own emergency
    vehicles, pickups and weather.
  - They would have stopped players from reaching a city too early.
  - A late meeting of Benzies, Garbut, Fowler and Roger chose **one big
    map**.

  [9] **V** (Vermeij's X post, retold by GamesRadar, 80.lv and GTABoom)

  *Read*: the per-city police, weather and pedestrians in section 4.2 are
  what survived of that plan, as data switches on one map.
- **Streaming on PS2:**
  - In GTA III Fowler packed models that are near each other in the city
    near each other on the DVD.
  - When streaming could not keep up, the team **changed the road layout to
    slow the player down** [10]. **S** (Vermeij, about GTA III)
  - For San Andreas, a new LOD system lets many buildings share one
    low-detail model. Low-detail models stream in as the player moves,
    instead of loading per island as in Vice City [11]. **S** (GameSpot Q&A
    with Vermeij)
  - Location scripts (encounters, cranes, vending machines) also stream in
    and out [11]. **S**
- **Memory budget.** PS2 streaming had about **13.5 MB** (`stream.ini`) out
  of 32 MB of RAM [12]. **S** The PC engine's default streaming budget is
  25.6 MB [1e]. **S**
- **Hiding pop-in:**
  - The draw distance (far clip) and fog start are set per weather type and
    hour [1f].
  - Up to 20 "timecycle boxes" can override the far clip in local areas
    [1f].
  - So fog, haze, smog and sandstorm double as streaming cover.

  **S** (engine code) The PC version raised the clip distances [11]. **S**
- **The countryside's job:**
  - No 2004 developer interview was found that explains the countryside;
    the search for one came up empty *(summary)*.
  - Retrospectives describe it as small towns, farms, forests, mountains and
    deserts connecting the cities [21]. **S**
  - **A criticism Rockstar acknowledged.** For GTA V, Leslie Benzies said
    players in San Andreas could end up in the countryside and then have to
    drive all the way back to town. GTA V's character switching was partly
    the fix [18] *(summary)*. **S**
  - Benzies also said GTA V filled its countryside with wildlife to avoid a
    "hollow" feel [18]. **S**
  - Houser's "sketch like cities" remark (section 1.2) is the other half of
    that lesson [18].
- **Process (GTA V era, Garbut).** The team blocks the world in fast,
  gathers reference, and builds each area up to a visual bar. Terrain is
  hand-made, not procedural [22] *(summary)*. **S**
- **Not found:** the often-quoted claim that the map is "four times the size
  of Vice City". The search budget ran out before it was checked.

## 7. Lessons for Solvera

Solvera's current state is 8 x 6 km (48 km²), 1.33 times San Andreas's
36 km² box, with four cities planned instead of three. The lessons are
ranked by impact for a top-down phone game on a small budget. Each says what
to copy and what to avoid.

1. **Theme the cities with data, not art alone. Copy.** San Andreas gives
   every zone a population type and gang strengths, and every city a
   "level" that swaps police, pedestrian variants, weather sets and cop cars
   (section 4.2).
   - For Solvera: one `level` per city plus `countryside`, with a zone
     table carrying pop type, faction weights, a no-cops flag and density.
   - Cost: low. Effect: each city feels like a different place.
2. **Use water and a few bridges as the skeleton. Copy.**
   - In San Andreas, 17.5 % of the box is water. A bay and one river split
     the land into one block per city.
   - Each city pair has only about 2 to 4 road links, all through named
     bridges or junctions (section 3.2). The bridges serve as landmarks,
     chase chokepoints and unlock gates at once.
   - Plan 2 to 3 links per neighbouring city pair, and 1 to 2 for far
     pairs.
3. **Keep the scale compact. Copy the ratios, not the size.**
   - City centres 2.8 to 4 km apart, with countryside belts 1.2 to 2.4 km
     wide between city edges.
   - Cities take about **a third of the box and 40 % of the land**; the
     countryside takes about 60 % of the land (two-thirds green, a fifth
     desert).
   - In 48 km² with four cities, that gives roughly:
     - each city 3 to 4 km² (Las Venturas-sized);
     - countryside belts 1.5 to 2 km wide;
     - a drive between neighbouring cities of about 2 to 3 minutes.
4. **Put a town on every route, about 1 km apart. Copy.**
   - Rural towns are small, 300 to 500 m across (0.1 to 0.2 km²).
   - They sit near the main roads, about 1 km apart, and 1 to 3 km from
     their city.
   - Give each a role: a diner, a garage, a gang outpost, a mission
     contact.
   - Avoid long empty stretches. Angel Pine, 3 km from anything, is the
     exception, not the rule.
5. **Make the countryside dense in things to do. Avoid San Andreas's flaw.**
   Rockstar itself named the problem: players got stranded in a countryside
   with little to do (section 6). Instead:
   - put activities, collectibles and wildlife on the routes;
   - add fast travel back (see 7).
6. **One flagship restricted base, two small ones. Copy.**
   - Area 69 gives an instant 5 stars and has SAM sites and a no-fly zone.
     The naval station is a 5-star district feature, and the fuel depot is a
     small yard.
   - This maps directly onto the request for "one biggest, others smaller".
   - Put the big one in the most remote biome (the desert), next to an
     abandoned airstrip, so the late-game jets are near it.
7. **Layered travel with diegetic unlocks. Copy, but lighter.**
   - San Andreas has:
     - a rail loop joining all three cities (5 stations);
     - paid flights between three airports, unlocked by flight school;
     - roads.
   - For mobile, a station or airport "ticket" as fast travel is cheap. It
     also fixes lesson 5's stranding problem.
8. **Gate the map in story order with an in-world reason. Copy the reason,
   soften the penalty.**
   - San Andreas closes the bridges ("earthquake") and gives an instant 4
     stars for trespass, then unlocks one area per story act.
   - Solvera already has the Great Storm: closed bridges and flooded roads
     fit it.
   - Use 2 to 3 stars, not 4, on a phone; or show visible roadblocks.
9. **Hide streaming with weather and terrain. Adapt.**
   - San Andreas uses far clip and fog by weather and hour, local clip
     boxes, shared LOD models and curvy hill roads.
   - Top-down needs little draw distance. Still:
     - stream in chunks (San Andreas used 50 m sectors and 750 m path
       areas);
     - make zones the unit of density so the countryside costs little.
10. **Avoid "sketch-like" cities.**
    - Houser's own verdict was that the three cities were too small to feel
      real.
    - With four cities on a small budget, give each one or two dense
      signature districts, its own landmark skyline and its own police,
      weather and pedestrians, rather than spreading thin grids
      everywhere.
11. **Vehicle variety by biome.** Copy cheaply.
    - San Andreas has 212 vehicles, but the useful idea is placement:
      seaplanes and boats at marinas, cropdusters at farms, dirt bikes and
      off-roaders in the desert, jets and helicopters at the base.
    - Each biome gets a small spawn set.

## Sources

- **[1]** gta-reversed (reverse-engineered SA engine), GitHub. The letters are cited in the text: [1] World.h (bounds, sectors): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/World.h; [1a] Weather regions: Weather.cpp: https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Weather.cpp; Weather.h: https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Weather.h; eWeatherType.h: https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Enums/eWeatherType.h; [1b] eLevelName.h (levels): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Enums/eLevelName.h; [1c] Population and zones: PopCycle.h (ped groups): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/PopCycle.h; ZoneInfo.h (zone population types): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/ZoneInfo.h; [1d] PathFind.h (path areas, node switches): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/PathFind.h; [1e] Streaming (cop model per level, memory budget): Streaming.cpp: https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Streaming.cpp; Streaming.h: https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/Streaming.h; [1f] TimeCycle.h (far clip, fog, timecycle boxes): https://github.com/gta-reversed/gta-reversed/blob/master/source/game_sa/TimeCycle.h
- **[3]** San Andreas zone table, a community copy of the game's zone boxes (160 names): https://gist.github.com/oliverbooth/5750298
- **[4]** MTA radar map of San Andreas, 600 x 600 px: https://github.com/multitheftauto/mtasa-resources/blob/master/%5Badmin%5D/admin/client/images/map.png
- **[5]** Multi Theft Auto source: [5a] Client CVehicleNames.cpp: https://github.com/multitheftauto/mtasa-blue/blob/master/Client/mods/deathmatch/logic/CVehicleNames.cpp; [5b] Server CVehicleManager.cpp (vehicle type table): https://github.com/multitheftauto/mtasa-blue/blob/master/Server/mods/deathmatch/logic/CVehicleManager.cpp; [5c] Server CHandlingManager.cpp (original handling values): https://github.com/multitheftauto/mtasa-blue/blob/master/Server/mods/deathmatch/logic/CHandlingManager.cpp
- **[6]** GTA Wiki *(summary)*: State of San Andreas: https://gta.fandom.com/wiki/State_of_San_Andreas_(3D_Universe); Unit: https://gta.fandom.com/wiki/Unit
- **[7]** KeWiS, "The most accurate GTA map comparison ever!", GTAForums *(summary)*: https://gtaforums.com/topic/821812-the-most-accurate-gta-map-comparison-ever/ Repeated by Sportskeeda: https://www.sportskeeda.com/gta/gta-ranking-maps-order-size
- **[8]** Guinness World Records, "Largest playable area in a Grand Theft Auto videogame" *(summary)*: https://www.guinnessworldrecords.com/world-records/86419-largest-playable-area-in-a-grand-theft-auto-videogame
- **[9]** Obbe Vermeij on the three-map plan: *(all summary)* his X post: https://x.com/ObbeVermeij/status/1849940437596787037; GamesRadar: https://www.gamesradar.com/games/grand-theft-auto/on-its-20th-anniversary-gta-san-andreas-veteran-shares-the-open-world-was-originally-split-into-three-maps-memory-was-very-tight-on-the-ps2/; 80.lv: https://80.lv/articles/gta-san-andreas-world-could-have-looked-entirely-different; GTABoom: https://www.gtaboom.com/gta-san-andreas-turns-20-with-stories-of-a-game-that-almost-was-different-bb13
- **[10]** Obbe Vermeij on GTA III streaming, X *(summary)*: https://x.com/ObbeVermeij/status/1783484201171321148
- **[11]** GameSpot, "Grand Theft Auto: San Andreas Q&A: Under the Hood" *(summary)*: https://www.gamespot.com/articles/grand-theft-auto-san-andreas-qanda-under-the-hood/1100-6126774/
- **[12]** GMTK, "How Rockstar fit an entire city into PlayStation 2 memory" *(summary)*: https://gmtk.substack.com/p/how-rockstar-fit-an-entire-city-into
- **[13]** Military sites *(summary)*: GTA Wiki, Area 69: https://gta.fandom.com/wiki/Area_69_(3D_Universe); GTA Wiki, Easter Basin Naval Station: https://gta.fandom.com/wiki/Easter_Basin_Naval_Station; GTABase, Military: https://www.gtabase.com/gta-san-andreas/gangs/military; Grand Theft Wiki, Military: https://www.grandtheftwiki.com/Military
- **[14]** Unlocking *(summary)*: GTA Wiki, Earthquakes in San Andreas: https://gta.fandom.com/wiki/Earthquakes_in_San_Andreas; Grand Theft Wiki, San Andreas Earthquake: https://www.grandtheftwiki.com/San_Andreas_Earthquake; Grand Theft Wiki, Gant Bridge: https://www.grandtheftwiki.com/Gant_Bridge; Gamepur: https://www.gamepur.com/guides/how-to-unlock-all-cities-in-grand-theft-auto-san-andreas-definitive-edition; Steam discussion: https://steamcommunity.com/app/12120/discussions/0/1290690926867365591
- **[15]** Flights *(summary)*: GTA Wiki, Airports: https://gta.fandom.com/wiki/Airports; GTA Wiki, AT-400: https://gta.fandom.com/wiki/AT-400; GTA Wiki, Las Venturas Airport: https://gta.fandom.com/wiki/Las_Venturas_Airport; GameFAQs answer: https://gamefaqs.gamespot.com/ps2/914983-grand-theft-auto-san-andreas/answers/19921-how-do-u-book-a-flight
- **[16]** Rail *(summary)*: GTA Wiki, Brown Streak Railroad: https://gta.fandom.com/wiki/Brown_Streak_Railroad; GTA Wiki, Unity Station: https://gta.fandom.com/wiki/Unity_Station; Grand Theft Wiki, Market Station: https://www.grandtheftwiki.com/Market_Station; WikiGTA station list: https://en.wikigta.org/wiki/Train_station_locations_(GTA_San_Andreas); GTAForums thread on the Las Venturas station: https://gtaforums.com/topic/920306-why-is-las-venturas-train-station-so-small-and-faraway-from-downtown-in-comparison-to-unity-station-or-cranberry-station-in-ls-or-sf/
- **[17]** GTA Wiki *(summary)*: Los Santos Freeway: https://gta.fandom.com/wiki/Los_Santos_Freeway_(3D_Universe); San Andreas Highway System: https://gta.fandom.com/wiki/San_Andreas_Highway_System
- **[18]** Benzies and Houser on San Andreas, from the GTA V era *(summary)*: Rockstar Wiki, Los Santos (HD Universe): https://rockstargames.fandom.com/wiki/Los_Santos_(HD_Universe); GTAForums, Benzies and Sarwar interview: https://gtaforums.com/topic/566154-leslie-benzies-imran-sarwar-interview/
- **[19]** Mount Chiliad *(summary)*: gta.wiki: https://gta.wiki/w/Mount_Chiliad_(3D_Universe); WikiGTA: https://en.m.wikigta.org/wiki/Mount_Chiliad; LaPS4 Q&A (527.5 m figure): https://www.laps4.com/preguntas-y-respuestas/donde-esta-mt-chiliad
- **[20]** Simple English Wikipedia, GTA: San Andreas *(summary)*: https://simple.wikipedia.org/wiki/Grand_Theft_Auto:_San_Andreas
- **[21]** Retrospectives *(summary)*: Retro Replay, "GTA: San Andreas at 22": https://retro-replay.com/gta-san-andreas-at-22-when-rockstar-gave-us-more-of-everything/; Game Informer, "Gameography: Dan Houser": https://gameinformer.com/b/features/archive/2011/12/01/danhouserextra
- **[22]** BuzzFeed News, interview with Aaron Garbut on GTA V *(summary)*: https://www.buzzfeednews.com/article/josephbernstein/way-beyond-anything-weve-done-before-building-the-world-of-g

### Could not open or search

- **Blocked:** Wikipedia (English), the GTA Wiki (fandom), web.archive.org,
  GTAForums, GTABase, X, GameSpot, Guinness, Insider Gaming, and the raw
  file of the zone gist (the gist's HTML page did load).
- **Not researched,** because the search budget ran out:
  - which gang holds which district;
  - details of the San Fierro tram;
  - taxi missions;
  - flying handling;
  - the jetpack;
  - 2004 developer interviews on the countryside;
  - the "4x Vice City" size claim.

  Every claim on these topics is marked **U**.
