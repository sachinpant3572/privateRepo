# World v3 plan: four cities and the country between them

Status: **plan**, 2026-10-27. Built so far: the map data (`game/data/world_map.json` v3),
the world picture (`world_map.svg`) and the in-game state map (full map zoomed out, and
the minimap past the city's edge). Bellerive is still the only playable city. Research
behind every choice: `reference/world/README.md`. Decisions and open questions:
`HANDOFF-world-v3.md`. Names marked *(working)* are not approved yet.

Sachin's brief, in short: four themed cities based on real life:
- a best-planned city (San Francisco, New York, Washington DC);
- a desolate one (Detroit);
- a Vegas;
- a Florida.

Each city gets its own architecture, monuments, places, characters, vibe, missions and
transit (airport, metro, buses, trains, trams) in the condition the city is in, and NPCs
spread by that condition. Between the cities sit mountains, rivers, swamps, desert, lakes,
counties, towns, ghost towns and military sites (one biggest), plus:
- cults, unions, drug mafias, Italian dons, syndicates, corporates and riots;
- police, hospitals, eateries, vending machines and car shops;
- planes, helicopters, airships and boats with their own physics, to own, rent or ride
  on schedules, and taxis.

## 1. The map at a glance

12 x 9 km (108 km², about 75 km² of land), up from 8 x 6. Coordinates in metres, x east, y south.

```
 Fort Granite   Cinder Ridge (peaks, pass)    Lake Corran ~~~~~~~~~
 (big base)     Silverbell  Pinecrest         STEELHAVEN    Port Ash
   LAS BRASAS   Lake Miravel  Red Pine        Corran County
   Hollow Mesa  (dam)         (forest)          Sovereign Bay ~~~
   (desert)     Golden Flats (farms)           CONCORDIA (capital)
 Bottle Flats   Wheaton    Morrow River        Verdant Hills
   Saltgrass Parish (swamp)    BELLERIVE        Signal Hill
 ~~~~~~~~~~~~~ Gulf of Solvera ~~~~~~~~~~~~~~~  Serena Keys -> Isla Serena
```

| Pair | Gap | Links |
|---|---|---|
| Bellerive - Concordia | about 2 km | Route 1, Solvera Line, Old Post Road (lane), flights |
| Bellerive - Las Brasas | about 3.5 km | Route 40, freight rail, Salt Flats and Bottle Flats tracks, flights |
| Concordia - Steelhaven | about 1 km | Route 3 Turnpike, Corran Commuter, Shore Road |
| Steelhaven - Las Brasas | about 4 km | Route 7 Ridge Road over the pass, Devil's Staircase (4x4) |
| Bellerive - Steelhaven | about 4.5 km | Route 9 River Road along the Morrow, freight rail |

Roads thin out from city to wild, five kinds:
- **highway** (8 named, wide, scenic);
- **road** (paved two-lane);
- **lane** (short paved county road: farm sections, lake drives, the observatory
  switchbacks);
- **track** (unpaved dirt or gravel: logging roads, desert flats, levees);
- **trail** (steep 4x4 or hiking: Widow's Ridge, the Silver Train, the Devil's Staircase,
  the Headlands).

Where a dirt track or trail crosses a creek there is a ford; every other crossing (any road
over a river, any lane or highway over anything) gets a bridge. Both are computed from the
data, so a moved road or creek moves its crossings.

## 2. The cities

Conditions drive everything below: transit, NPC density, police, prices, what is broken.

### 2.1 Concordia *(working)*: the planned capital (Washington DC, Manhattan, San Francisco), phase 5

- **Vibe**: monumental, orderly, watched; marble and green. Prosperous.
- **Plan**: L'Enfant-style radials and circles over a grid; a long Mall from the Capitol to
  the memorial; Manhattan-style long blocks in Midtown; San Francisco hills, cable cars and
  a red bridge (Crimson Gate) across Sovereign Bay to the Headlands.
- **Architecture**: Beaux-Arts and Neoclassical civic buildings, an even skyline under a
  height limit, painted Victorian row houses on the hills, a modernist far airport.
- **Districts**: Capitol Mall, Midtown, Market Seam (finance), The Wharfline (waterfront),
  Olive Hill (old town), Commons Park, Bayview Heights, Foggy Row.
- **Monuments and places**: the Capitol, Founders' Obelisk, Unity Memorial, the State
  Museums row, Union Station, the Ferry Building, the Painted Row, the Slant (the one
  diagonal avenue, theatres), Commons Park reservoir, cable-car hill streets.
- **Transit (excellent)**: Metro Red and Blue lines every 2 minutes (cheap fast travel,
  transit police); cable cars you can ride on the outside; the bay ferry; Union Station for
  the Solvera Line and the Corran Commuter; Capital Downtown Airport (close, on the metro)
  and Sovereign International (far).
- **NPCs**: dense in the core by day (office workers, tourists, school groups, guards,
  joggers, protesters), medium at night. More police per street than anywhere: crime here
  draws stars fast.
- **Factions**: The Ledger (lobbyists and launderers), Castellane Family (dons; restaurants,
  the docks union, protection), Halberd Security (private army), Aurum's state office.
- **Characters** *(new, working)*:
  - Senator Imogen Vance, Aurum's best friend in the Capitol;
  - Don Aurelio Castellane, an old don who still eats at the same table every night;
  - Wren Okafor, a Ledger accountant who wants out;
  - Halberd's Colonel Marsh.
- **Missions (ideas)**:
  - steal a vote by kidnapping a lobbyist from a gala;
  - a cable-car chase down Bayview Hill;
  - the Castellanes' dock strike, end it or break it;
  - lift a painting from the State Museums for the Ledger;
  - a protest that turns into a riot on the Mall.

### 2.2 Steelhaven *(working)*: the desolate motor city (Detroit), phase 6

- **Vibe**: grit, rust, prairie silence; a comeback in a few streets. Decaying.
- **Plan**: a radial street plan from a fire-era rebuild, the lake and a river in front,
  vast plant sites, whole blocks gone back to prairie.
- **Architecture**: a gold Art Deco tower (the Brass Tower), mirrored HQ towers on the
  river, concrete plant halls, wooden houses on big lots, a ruined Beaux-Arts station,
  market sheds.
- **Districts**: Riverfront, Market Sheds, Midtown Revival, the Prairie, Plant Row,
  Ashgrove (an enclave town inside the city), Lakeshore Pointe (rich suburb over the line).
- **Monuments and places**: the Brass Tower, Ostrander Motors HQ, Steelhaven Central (the
  ruined station), the Old Ostrander Plant, the Polka Dot Block (art street), the Narrows
  Toll Bridge to Northland, the Local 12 Union Hall, Heron Isle park, Port Ash (dying lake
  port).
- **Transit (decaying)**: the Loop (an elevated people mover that runs nearly empty, good
  for an ambush); one new streetcar on the avenue (the "comeback corridor"); buses late or
  missing ("next bus: 40 min"); two Corran Commuter trains a day; a dead city airport (a
  smuggling strip) and the working Corran County Airport outside town; a rusty lake ferry.
- **NPCs**: very few in the prairie, medium downtown, low at night: plant workers,
  scrappers, artists, students, the homeless, union men. Few police (slow response, low
  heat); broken vending machines, closed shops, cheap houses.
- **Factions**: Tenmile Crew (heroin, teen runners), Copper Kings (scrap and arson),
  Assembly Workers Local 12 (shrinking union), Aurum (buying the riverfront for nothing).
- **Characters** *(new, working)*:
  - Ray "Gauge" Kowalczyk, Local 12's last steward;
  - Tamsin Hart, an artist turning the Polka Dot Block into a movement;
  - "Sixteen", the Tenmile Crew's teenage runner boss;
  - Emergency Manager Pruitt, who sells the city by the acre.
- **Missions (ideas)**:
  - Devil's Night: stop (or start) the arson wave;
  - strip the dead plant for the Copper Kings before Aurum's demolition crew;
  - run contraband over the Narrows Toll Bridge;
  - a union vote under threat;
  - a chase through the empty Loop.

### 2.3 Las Brasas: the neon desert city (Las Vegas), phase 4

- **Vibe**: neon, heat, excess, 3 am. Booming.
- **Architecture**: themed resorts (the Sun King Pyramid, the Colosseo), decorated sheds
  behind giant neon, a 1950s old town under an LED canopy, gated suburbs on golf greens.
- **Districts**: the Blaze (strip), Old Town Brasas, Ember Heights, Dust Yards.
- **Monuments and places**: the Sign Yard (neon boneyard), the Racket Museum (old
  courthouse), the Old Town Canopy, the Skyhook Airship Pier, the Flood Tunnels (secret),
  Granite Gorge Dam, Ember Canyon drive, Mesa Arch, the ghost towns of Bottle Flats and
  Dust Hollow.
- **Transit (tourist-only)**: the Blaze Monorail (twice bankrupt, behind the resorts); the
  Doubler, a 24-hour strip bus with night surge prices; Brasas International; the Skyhook
  airship tour over Cinder Ridge; no train until the Solvera Line opens (a story beat).
- **NPCs**: very dense on the Blaze at night, empty by day in the heat; tourists, gamblers,
  showgirls, card sharps, casino workers, bikers; a hidden community in the tunnels.
- **Factions**: Velvet Aces (casino skim), Dust Riders (bikers, guns and meth on Route 40),
  the Skyward Fellowship cult near Fort Granite, Hospitality Workers Local 7 (casino and
  hotel workers; a walkout darkens the Blaze).
- **Characters**: Duke Calloway (bible); new *(working)*:
  - Lady Opal, a card counter banned from every casino;
  - Brother Halcyon, the Skyward Fellowship's smiling leader.
- **Missions (ideas)**:
  - a casino count-room skim;
  - win back a car in a rigged game;
  - airship heist over the canyon;
  - Dust Riders gun run to Sable Junction;
  - walk the Fellowship's desert pilgrimage to find where the savings go.

### 2.4 Bellerive: the Gulf city (Miami and Florida, with its New Orleans core), phase 1 (playable)

Bellerive keeps its name, districts and every Act 1 mission. It becomes the Florida city by
adding what Florida has and it lacked:
- **Brisa Beach**, a pastel Art Deco beach district (phase 2);
- **the Keys**, an island highway to Isla Serena;
- the cruise port;
- the swamp park with airboats (Saltgrass Glades).

- **Vibe**: humid, pastel, Latin and Creole, fast money, storm risk. Rebuilding.
- **Architecture**: the French Quarter's iron balconies, pastel Deco and MiMo hotels, glass
  condo towers (Gilt District), shotgun houses in the storm-scarred wards, stilt houses in
  the Keys.
- **Transit (car-centric with showpieces)**: the Lantern Line streetcar (restored, slow),
  the free Downtown People Mover, Union Station, Bellerive International, the Serena ferry
  and the cruise route, airboats.
- **NPCs**: medium by day, high at night in the Quarter and on the beach: tourists, club
  crowds, dockers, retirees.
- **Factions**: Marrow Krewe, High Water, Comando Maré (speedboat smugglers on the Keys),
  Os Corvos (beach club crew), Dockers' Brotherhood, Aurum.
- **Missions**: Act 1 (`ACT1_MISSIONS.md`); later, speedboat runs through the Keys, a
  hurricane evacuation with the bridges closing, and a smuggling war over the Keys.

## 3. The countryside

Each region has one biome, one landmark, one faction and one sentence of mood, and most
have a town (Fort Granite, a fenced base, has none).

| Region (county) | Biome | Towns | Hook and places |
|---|---|---|---|
| Hollow Mesa County | Desert, mesas, dry lakes | Sable Junction; Bottle Flats and Dust Hollow (ghost towns) | Dust Riders, Skyward camp, Mesa Arch, Sable Butte, the Old Salt Mine, Last Chance Gas, Starlite Motel |
| Fort Granite Reservation | Military | none | **The biggest base**: airfield, jets, dry-lake test range, the Vault (secret); instant high wanted level |
| Cinder County | Mountains | Silverbell (ghost), Pinecrest | Cinder Peak (2,140 m) with the observatory switchbacks, Granite Dome, Widow's Tooth, Cinder Pass, Silverbell Mine, the Silver Train (secret), Cinder Peak Radar |
| Miravel Shores | Lake and dam | Harlow | Lakeshore Drive, Granite Gorge Dam, Miravel Pines campground, the drowned village (secret), boat rentals |
| Red Pine County | Forest | Dellwood, Fernmoor | Logging roads and fords, the sawmill ruin, Red Pine fire lookout and campground, the Greenhold commune (cult) |
| Golden Flats County | Farmland | Wheaton, Ridley Crossing (truck stop) | Section-line lanes, Hollis Farm, grain elevators, crop-duster strip (rent planes), Solvera Line building sites |
| Saltgrass Parish | Swamp | Cypress Bend, Gator Point | Black Bayou, Turtle Slough, levee road, the moonshine still, airboat tours, gator farm |
| Verdant Hills | Hills and vineyards | Larkspur | Old Post Road, Larkspur Estate vineyard, Bluegill Lake |
| Sovereign County | Parkland | Haverly | Estates, Signal Hill, Sovereign International |
| Corran County | Rust belt lake country | Port Ash (ghost) | Shore Road, Camp Corran (State Guard), Corran County Airport, the Headlands with Naval Air Station Headlands and the lighthouse trail |
| The Keys and Isla Serena | Islands | Serena Town | Serena Causeway, Keys Fuel Dock, Coast Guard station, Serena Grand, Smugglers' Cove, the Sunken Casino (secret) |

**Military**:
- **Fort Granite** is the one huge base: fenced, with its own airfield and jets, 4 stars on
  entry (2-3 on a phone is kinder), the late-game jets and the Vault.
- Four small sites:
  - Naval Air Station Headlands (helicopters, docks);
  - Camp Corran (State Guard);
  - Cinder Peak Radar;
  - Coast Guard Station Pelican Key (patrol boats).

**Roadside life**: 10-30 short events weighted by region: hitchhikers (the Greenhold picks
them up), breakdowns, Dust Rider ambushes, speed traps, a gator on the road, a crop duster
low over Route 40.

## 4. Factions

| Kind | Faction | Home | How it plays |
|---|---|---|---|
| Corporate | Aurum Consortium | statewide | The story's villain; acts through Halberd, buys land, owns the line |
| Corporate | Halberd Security | Concordia | Private army; guards Aurum sites, heavy response |
| Syndicate | The Ledger | Concordia | Launders for everyone; heists, blackmail |
| Syndicate | Velvet Aces | Las Brasas | Casino skim; card games, count rooms |
| Mafia (dons) | Castellane Family | Concordia | Restaurants, protection, the docks union; old-school favours. The family is the faction, not a people |
| Drug mafia | Comando Maré | Bellerive Keys | Speedboat smuggling, swamp drops |
| Drug mafia | Tenmile Crew | Steelhaven | Heroin with teen runners in the emptied east side |
| Gang | Marrow Krewe, High Water, Os Corvos | Bellerive | Turf (Act 1 already) |
| Gang | Dust Riders | Hollow Mesa | Bikers, guns on Route 40 |
| Gang | Copper Kings | Steelhaven | Scrap theft and arson |
| Union | Local 12, Dockers' Brotherhood | Steelhaven, Bellerive and Concordia | Strikes close a port, ferry or plant: a ready-made gate |
| Cult | Skyward Fellowship | Hollow Mesa | Escalating money sinks ending in a payout heist |
| Cult | The Greenhold | Red Pine | Commune fed by hitchhikers |
| Law | City PDs, State Police, Capitol Guard | everywhere | Strength by city condition |
| Military | Solvera Defence Forces | Fort Granite and small sites | High wanted level on trespass |

**Riots** are a city-state switch (SA's riot): inside one boundary, NPCs turn aggressive,
cars get stolen, fires start and police helicopters fly, until a story flag clears it.
Uses: a protest riot on Concordia's Mall, Devil's Night in Steelhaven, a blackout on the
Blaze.

## 5. Services, by city condition

Already planned in `INTERIORS_SERVICES_PLAN.md`; v3 sets where and how well:

| Service | Concordia | Steelhaven | Las Brasas | Bellerive | Countryside |
|---|---|---|---|---|---|
| Police stations | many, fast | one, understaffed | strip-heavy | city PD | State Police posts |
| Hospitals | two, best (Concordia General, Bayview Medical Center) | one, overrun (Steelhaven Municipal) | one (Sagebrush General) | Floodline Clinic now; Bellerive General planned | Golden Flats County Hospital near Wheaton |
| Eateries | bistros, food trucks | diners, coney stands | buffets, 24-hour diners | Creole, Cuban, seafood | truck stops, gas-station food |
| Vending machines | everywhere, work | rare, half broken | in every casino | common | at gas stations |
| Torque & Tone (upgrades) | luxury | muscle and restorations | lowriders and neon | tuners | none; fuel and repair at gas stations |

**Transit by city** (in `world_map.json`, each city's `transit`):

| | Concordia | Steelhaven | Las Brasas | Bellerive |
|---|---|---|---|---|
| Condition | excellent | decaying | tourist-only | car-centric with showpieces |
| Metro | Red and Blue lines | the Loop (elevated, nearly empty) | the Blaze Monorail | Skyline Metro, one elevated line to the airport (phase 2) |
| Tram | Wharfline heritage tram | one new streetcar ("comeback corridor") | none: a car city | Lantern Line streetcar |
| Bus | Concordia Coach Terminal | Steelhaven Bus Depot ("next bus: 40 min") | Old Town Bus Depot, the Doubler strip bus | Bellerive Bus Terminal (phase 2) |
| Train | Concordia Union Station | a platform beside the ruined Central | Las Brasas Union, a shell until the Solvera Line opens | Union Station |
| Airport | Sovereign International, Capital Downtown | City Airport closed; Corran County Airport | Brasas International | Bellerive International, Ironwharf Seaplane Base |

## 6. Vehicles, rides and travel

**Physics classes** (handling by archetype, about 10 profiles):

| Class | Examples | Feel |
|---|---|---|
| Light plane | crop duster, trainer | Slow, forgiving, short strips |
| Stunt plane | aerobatic | Twitchy, loops |
| Seaplane | Keys hopper | Lands on water |
| Jet | Fort Granite fighter (late game) | Fast, wide turns |
| Light helicopter | heli tours, news | Hover, gentle |
| Heavy helicopter | Halberd, NAS Headlands | Slow, strong |
| Airship | Skyhook tour | Very slow, drifts with wind, fragile |
| Speedboat | Maré runners | Fast straight, wide turns |
| Airboat | Saltgrass Glades | Skates over the swamp, no brakes |
| Jet ski, yacht, ferry | marinas, Isla Serena | Nimble, then slow and heavy |

**Ways to ride:**
- **Steal or own**: anything on the street; bases and marinas for the exotic.
- **Rent**: Harlow Marina (boats), the crop-duster strip (planes), Pinecrest heli tours, the
  Skyhook pier (airship), Glades airboats. You pay by the minute, and an unreturned rental
  gives a star.
- **Schools** gate the exotic families (planes, helicopters, boats, airships), each
  teaching its physics and paying out a vehicle.
- **Scheduled flights, trains, ferries and ships**: a kiosk, a ticket, a fade and arrival
  at the destination terminal, with an optional bail-out into the countryside. They are not
  simulated rides (GTA IV cut its ferries over physics trouble). The first trip between two
  cities should be driven.
- **Taxis**: hail or phone; ride along, or pay extra to skip. Prices follow the city (cheap
  in Steelhaven, surge on the Blaze).

## 7. Build phases and costs

Rough costs in build sessions. A session is about one working day of agent time plus its
gates; these are estimates from earlier phases (Bellerive's map v2 took about 3 sessions,
interiors phase 0 about 2).

| Phase | Content | Cost |
|---|---|---|
| 1 (done) | Bellerive, Act 1 | built |
| 2 | Bellerive edges: Brisa Beach, Golden Flats, Saltgrass, Verdant Hills; streaming past the window; the first countryside roads and towns; taxis | 6-8 |
| 3 | Desert, mountains, lake, forest; Route 40 and 7; towns, ghost towns, Fort Granite; rentals (boats, crop duster, heli) | 8-10 |
| 4 | Las Brasas and the Keys; airship; scheduled flights and ferries | 6-8 |
| 5 | Concordia; metro, cable cars; Castellanes, Ledger, Halberd | 8-10 |
| 6 | Steelhaven and Corran; the Loop; Local 12, Tenmile, Copper Kings; riots | 6-8 |

**Recommended: a seamless state built in phases** (one streamed world, about 34-44
sessions in all). Each city still ships as its own phase, behind a story gate (the Great
Storm's closed bridges, a dock strike).

**Cheaper options** (Sachin can switch):
- **City-hop**: each city is its own map; travel between them is a kiosk and fade, with
  small countryside pockets. About 60 % of the cost (20-26 sessions), but there is no
  driving between cities, which the research rates as what makes the country feel real.
- **8 x 6 km state**: the same four cities, packed closer (about 1 minute apart), with
  little countryside. Saves about 4-6 sessions of countryside work.

## 8. Open questions

- The names Concordia and Steelhaven. Alternatives: Federal City or Capitola; Ironmouth or
  Rustwater.
- Retiring Porto Brisa (Rio) and moving its beach crews to Bellerive's beach and the Keys.
  Act 2 ("the money route") then moves to Concordia and the Keys. Jules's backstory as a
  getaway driver in Porto Brisa becomes the Keys and Isla Serena.
- Whether trespass into Fort Granite gives 4 stars or 2-3 on a phone.
- Comando Maré and Os Corvos keep their approved Porto Brisa names. In a Florida setting
  two Portuguese-named crews could read as an ethnic group cast as criminals, which the
  bible forbids. Renaming them, or giving them mixed membership on screen, is Sachin's call.
