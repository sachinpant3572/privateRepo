# GTA V and GTA VI: how the maps are built

Researched Oct 27, 2026, for the Solvera state map (4 themed cities with
countryside between them). Topic: **GTA V (2013)** and **GTA VI (out Nov 19,
2026)**. Sachin's brief says "GTA 8"; no such game exists, so it is read here
as **GTA VI**, the newest game.

## How to read this note

- **Access.** WebFetch and curl were blocked from this container (Wikipedia,
  rockstargames.com, gta.fandom.com, archive.org, GTAForums, Sportskeeda and
  GameSpot all refused or failed DNS). Every claim comes from
  **search-engine summaries of the cited pages**, not from the pages
  themselves. The shared search budget then ran out; see "Gaps" at the end.
- **Labels:** **verified** = two independent sources agree. **single** = one
  source, or several repeating one origin. **inferred** = worked out here
  from sourced numbers. **speculative** = 2022 leak, fan maps, unconfirmed
  reports. **unchecked** = the researcher's prior knowledge, with no source
  opened this session; check before relying on it.
- [n] points to the Sources list.

## 1. GTA V scale

### 1.1 Map area

| Measure | Value | Label |
|---|---|---|
| Land | **48.15 km²** | verified [1][2] (KeWiS on GTAForums, repeated by Sportskeeda and GTABoom) |
| Water inside the playable bounds | **27.69 km²** | single [1] |
| Total | **75.84 km²** | single [1] |
| Wikipedia | "49 square miles (130 km²)", "about an eightieth of Los Angeles County" | single [3]; Beebom repeats it [4] |
| Another fan figure | ~81 km² | single [5] |

- The 49 sq mi (127 km²) figure most likely counts open ocean out to the map
  edge (inferred). **Use about 48 km² of land and 76 km² in all**; water is
  **about 37 %** of the measured total (inferred, 27.69 / 75.84).
- Garbut estimated V's world could hold San Andreas, GTA IV and Red Dead
  Redemption combined: a developer's estimate, not a measurement. single [3]
- The New Yorker (2013): V is "3 times the size of Liberty City". single [6]

### 1.2 Bounds and distances

- **Coordinates:** modders use about X −4000 to +4000…6000 and Y −4000 to
  +8000, so about **12 km north to south**. single [7]. Rockstar never
  published bounds.
- **LS to Paleto Bay:** about **11 km**, by the Great Ocean Highway (west
  coast) or the LS and Senora freeways (inland). single [8]
- **Drive time:** no measured LS–Paleto time was found. At 100 to 150 km/h it
  is **about 5 to 8 minutes** of real time (inferred). The Paleto Score setup
  (Sandy Shores to the Paleto bank) gives gold for **3:30** or less
  single [9]. A 2013 attempt tried to cross the whole world by car in under
  12 minutes single [10].
- **On foot:** corner to corner in **52 minutes**. verified [11][12]

### 1.3 Los Santos's share against Blaine County

- **Los Santos County** is about the **lower two thirds** of the map,
  **Blaine County** the northern third. single [13]
- The city of Los Santos is "about a third" of Los Santos County. single [14]
- **So (inferred):** the city is 2/3 × 1/3 ≈ **20 to 25 % of V's land**,
  about **10 to 12 km²**. Some 36 to 38 km² are hills, mountain, desert,
  farmland and forest: **about three quarters of the land is not city.**
- Blaine is called the series' largest rural area. single [15]

### 1.4 How Los Angeles was compressed

- **Research:** over **250,000 photographs** and hours of video; trips with
  location scouts, architectural historians and off-duty police. verified
  [16][17]. "More than a hundred days of research in Los Angeles". single [6]
- **Method, in Garbut's words:** "We compress, we edit, we emphasise certain
  things", so the result matches the popular image of the place, not the
  real city. single [18]
- **Kept:** the freeways (four Interstates: Los Santos, Del Perro, Olympic
  and La Puerta) single [19]; the real neighbourhoods, each mapped to a
  district (section 3) verified [20][21]; the landmarks and their rough
  relative positions, with minor streets dropped and winding roads
  favoured (single; MAP_BUILDING.md section 6, ref [25] there).
- **Dropped:** no district stands for the San Fernando Valley, Long Beach or
  Pasadena; hills and countryside replace the sprawl. unchecked

## 2. GTA V countryside (Blaine County and the LS County hills)

### 2.1 Areas and towns

| Place | What it is | Label |
|---|---|---|
| **Sandy Shores** | Desert town on the Alamo Sea's south shore. Decaying motels, drained pools, trailers. Modelled on the Salton Sea towns (Bombay Beach); street names echo Niland and Joshua Tree. | verified [22][23] |
| **Alamo Sea** | Big inland lake at the foot of Chiliad; stands for the Salton Sea | single [23] |
| **Grand Senora Desert** | South of the Alamo Sea. Scrapyards (Thomson), the Rebel Radio building | single [24][25] |
| **Harmony** | Small town on the desert's west edge; Route 68 is its main street | single [26] |
| **Grapeseed** | Farm town in the north; O'Neil Ranch, McKenzie Field | single [27][28] |
| **Paleto Bay** | Small "factory town" on the north coast; the Paleto Score bank. Real model disputed (Fillmore, Piru, Morro Bay). | single [27][29] |
| **Stab City** | Trailer park on the Alamo Sea, held by the Lost MC; modelled on Slab City | verified [30][31] |
| Other settlements | North Chumash, Galilee, Dignity Village, Cape Catfish | single [27] |
| **Mount Chiliad** (Chiliad Mountain State Wilderness) | Highest peak (model: San Gorgonio Wilderness), cable car to the top, Altruist camp | single [23][32][33] |
| Mountains and passes | Raton Canyon; Braddock Pass (between Mount Gordo and Chiliad, links Grapeseed and Paleto Bay); Mount Gordo; Mount Josiah; San Chianski range | single [27][34] |
| **Zancudo River, Lago Zancudo** | River and swamp on the west side, beside Fort Zancudo | single [35][36] |
| Paleto Forest | Pine forest between Paleto Bay and Chiliad | unchecked |
| Tongva Hills | Hills west of the Vinewood Hills | unchecked |
| Vinewood Hills | Mansions north of the city; almost no cul-de-sacs or dead ends | single (MAP_BUILDING.md section 6) |

Garbut: the team "drove all over Los Angeles and out into the surrounding
desert, towns, and forests". Rockstar North built "a load of tech" for the
countryside alone: heat haze, cloud shadows, water and fog. single [16]

### 2.2 Abandoned and ghost places

- **Derelict Motel**, Panorama Drive, Sandy Shores: gutted, boarded, dry
  pool, and a player ghost myth. single [37]
- **Rebel Radio building**, Grand Senora Desert: broadcast tower, outside
  speakers playing the station. single [25]
- **Abandoned mine**: in Great Chaparral, **Los Santos County** (not
  Blaine); can be entered in GTA Online. single [38]
- **Stab City**, a squatter and biker trailer camp verified [30][31];
  **Lago Zancudo**, swamp beside the base single [35].
- **Pattern (inferred):** V's ghost places are single buildings or half-dead
  towns, not empty ghost towns. They read as decline and are cheap: a few
  props, dry pools, boarded windows.

### 2.3 Military and government sites

| Site | Where | Notes | Label |
|---|---|---|---|
| **Fort Zancudo** (the big one) | West side, south of Paleto Bay on the Great Ocean Highway, on Lago Zancudo, at the foot of Mount Josiah | Army, Marine Corps and Air Force; restricted, high wanted level on entry; modelled on Vandenberg | single [35][39][40] |
| Humane Labs and Research | East coast, about Zancudo's latitude | Bio-lab guarded by Merryweather's Chem Security | single [41] |
| NOOSE Headquarters | Palomino Highlands (east LS County) | Federal tactical police HQ | single [42]; [41] says "east coast", which agrees |
| Merryweather Security | LS naval port, Elysian Island | Private military base | single [42] |
| Bolingbroke Penitentiary | Grand Senora Desert, south-east of Harmony | Restricted airspace; 4 or 2 stars (source gives both) | single [26][43] |

**Pattern (inferred):** one huge base with its own airfield and jets on the
coast road between the city and the far north, plus three or four small
secure sites (lab, police HQ, private-army dock, prison) spread so most
regions have one "do not go here" place.

### 2.4 How roads thin out

- **Great Ocean Highway (US Route 1):** from Del Perro up the west and north
  coast. Past Paleto Bay it turns east along Procopio Beach as the four-lane
  **Senora Freeway**, then south through Braddock Pass, becoming **Route 13**
  near Grapeseed. single [19][44]
- **Los Santos Freeway (I-1):** along the west edge of the Tataviam
  Mountains; past the Palomino Freeway junction it continues north as the
  Senora Freeway, the inland trunk through the desert. single [45]
- **Route 68:** Harmony's main street, meeting the Great Ocean Highway at
  its west end: the east–west cross road from the Zancudo coast to the
  desert. single [26][44]
- **Local desert roads:** Cholla, Joshua, Nowhere and Smoke Tree Roads.
  single [46]. Dirt tracks: no source found (gap).
- **Shape (inferred):** in the city, a dense grid plus four Interstates. In
  the country, a **loop of two long roads** (coast highway west and north,
  Senora Freeway inland east), **one cross road** (Route 68), and one or two
  town roads per settlement with named desert roads off them: perhaps **5 to
  7 through-roads** in all of Blaine, against hundreds of city streets.

### 2.5 How the countryside paces travel (inferred)

- **Distance is the reward:** a few minutes of driving with a view (coast,
  then forest and mountain, or desert and lake).
- **Each region has a set piece:** a bank to rob, a cult to find, a base to
  break into.
- **Detours fill the gaps:** **57 random events** (+3 in the later versions),
  14 of them needed for 100 %: hitchhikers, robberies, crashes, mostly on
  country roads. verified [47][48]

## 3. GTA V city themes

### 3.1 Los Santos districts

| District | Real place | Theme | Label |
|---|---|---|---|
| Vinewood / West Vinewood | Hollywood | Film industry, the sign; West Vinewood is the nightlife hub | verified [20][21]; nightlife single [49] |
| Rockford Hills | Beverly Hills | Rich; Michael's mansion | verified [20][50] |
| Richman, Vinewood Hills | Bel Air, Hollywood Hills | Wealth, gated hills | single [20] |
| Vespucci Beach | Venice Beach | Surfers, gym, "the attractive crowd" | verified [20][51] |
| Del Perro (Pier) | Santa Monica (Pier) | Beach resort, pier fair | single [20] |
| Downtown | Downtown LA | Towers, banks | unchecked |
| Little Seoul | Koreatown | Middle class, Korean and Asian immigrants | single [52] |
| Mirror Park | Silver Lake | Hipster lakeside | single [20] |
| Strawberry | Echo Park per [20]; South LA per prior knowledge | Working class | conflicting |
| Davis / Rancho | Compton / Watts | Low income, gang turf | single [52] |
| Chamberlain Hills | South LA | High crime, Families turf | single [53] |
| Elysian Island, Port of LS | Terminal Island, Port of LA | Docks, containers, Merryweather | single [52] |

**Monuments:** only the **Vinewood sign** is verified [20][21]. Unchecked: Del
Perro Pier's ferris wheel, Galileo Observatory (Griffith), Kortz Center
(Getty), Maze Bank Tower (the tallest), the Chiliad aerial tramway.

### 3.2 Factions and where they spread

| Faction | Territory | Label |
|---|---|---|
| The Families | Strawberry, Chamberlain Hills, Forum Drive, Carson Ave, Davis, Grove Street | single [42] |
| Ballas | Davis, Chamberlain Hills, Rancho | single [42] |
| Vagos | Rancho, Cypress Flats | single [42] |
| Aztecas | Rancho, and Blaine County | single [42] |
| Marabunta Grande | El Burro Heights | single [42] |
| The Lost MC | East Vinewood clubhouse, Stab City, Grand Senora Desert, North Chumash, Grapeseed | single [42] |
| O'Neil brothers | O'Neil Ranch, Grapeseed | single [42] |
| Madrazo cartel | La Fuente Blanca (ranch), Senora Road | single [42] |
| Altruist Cult | Fortified camp in the Chiliad wilderness; Trevor delivers hitchhikers to them | verified [33][54] |
| Epsilon Program | Satirical cult; no location found | single [55] |
| Merryweather | Elysian Island port; Chem Security at Humane Labs | single [41][42] |
| Korean mob | Little Seoul. A "Korean Mob" is listed; the name Kkangpae was not confirmed | single [52] |
| Triads (Wei Cheng) | Nothing found | gap |

**Spread (inferred):** street gangs pack the poor south and east, with
overlapping turf (Davis and Rancho each held by two gangs). Each rural
faction owns **one** recognisable place (ranch, camp, trailer park). One
faction, the Lost MC, **bridges** city and country.

### 3.3 Ambient population and life

- The wealthy live in Vespucci, Del Perro and Richman; Rockford Hills is
  "high-class"; Chamberlain Hills has high crime and gangs. single [50][53]
- Blaine's rural lots are "trailers, gas stations and roadside bars".
  single [56]
- No per-area pedestrian data was found. Thinner crowds and "hillbilly"
  pedestrian models in Blaine: unchecked.
- Random events: 57 (+3). verified [47][48]. Strangers and Freaks missions
  and the Altruist hitchhiker chain tie encounters to places. single [54]

## 4. GTA V transport

| Item | Notes | Label |
|---|---|---|
| **LSIA** | Big terminal, several runways; the secure side gives a wanted level without hangar or flight-school access | single [57] |
| **Sandy Shores Airfield** | Private desert field: two parallel E–W runways and one short NE–SW; takes most aircraft; loosely based on George AFB | single [58][23] |
| **McKenzie Field** (Grapeseed) | Small dirt strip and hangar; based on Bakersfield Municipal | single [28] |
| **Fort Zancudo** | Military runway, restricted | single [39] |
| **LS Transit Metro** | Light rail, overground and underground; ridden from a platform. Line runs **LSIA to Davis** and loops, so it does not cover the city. Lore calls it "incredibly unpopular". | single [59][60] |
| **Pala Springs Aerial Tramway** | Cable car up Chiliad; ridden but not controlled; story mode only | single [61][62] |
| Freight trains | Long loop through the desert that can be boarded | unchecked (gap) |
| **Taxi, Online** | Skip a ride for **$1,000** (free with GTA+), only to **10 fixed destinations**, 48-min cooldown | verified [63][64] |
| **Taxi, story** | Free once Franklin owns Downtown Cab Co. Skipping any ride for a small fee: unchecked | single [65] |
| Kraken submarine | Story: after the Wildlife Photography challenge. Online: DockTease, delivered by **Pegasus** | single [66][67] |
| Submersible | After buying Sonar Collections Dock (post-Merryweather Heist) | single [66] |
| Pegasus (story), bike rentals at Vespucci, Atomic blimp | Aircraft and boat rental to hangar or dock; beach bikes; pre-order blimp | unchecked |
| Handling classes | Separate controls for fixed-wing (throttle, pitch, roll, rudder, gear), helicopter (lift, yaw) and boats; LSIA flight school; a per-character flying stat | unchecked |

**Scheduled passenger flights.**
- **GTA V has none** (unchecked; no source suggests otherwise, and no reason
  from Rockstar was found). Likely reasons (inferred): one city, and nowhere
  far enough to need a flight (Sandy Shores is minutes from LSIA); and V
  treats flying as a player skill, not a cutscene.
- **GTA San Andreas did: confirmed.** A ticket machine at each airport sells
  flights between Los Santos, Easter Bay (San Fierro) and Las Venturas. The
  take-off and landing cutscene can be skipped, the player can bail out
  mid-flight, and it costs "a few hundred dollars" (exact price
  unconfirmed). single [68][69]
- **Lesson (inferred):** a ticketed hop suits several cities separated by
  countryside (SA, and Solvera), not a single city (V).

## 5. GTA VI: Leonida (Florida)

- **Release:** Thursday **Nov 19, 2026**, PS5 and Xbox Series X|S, delayed
  from May 26, 2026 (announced Nov 2025). verified [70][71]
- **Six regions** on Rockstar's official site. verified [72][73] There is no
  official full map, borders or distances. single [74]
- Official text below is quoted from secondary sites that reproduce
  Rockstar's site; the wording may vary slightly.

| Region | Real model | Official or reported description | Label |
|---|---|---|---|
| **Vice City** | Miami | Neon metropolis and main city, rebuilt and expanded for today; both trailers open there | verified [72][75] |
| **Leonida Keys** | Florida Keys | South of Vice City; archipelago of bridges, marinas, smuggling routes. "Gateway to paradise", "the dress code is casual". Brian Heder, a smuggler, lives there. | single [72][76] |
| **Grassrivers** | Everglades | "The untamable jewel of Leonida's crown"; "far deadlier predators and weirder discoveries among the mangroves" | single [77][78] |
| **Port Gellhorn** | Panhandle | "Leonida's forgotten coast": cheap motels, closed attractions, empty strip malls; economy of alcohol, painkillers, truck-stop energy drinks | verified [72][79] |
| **Ambrosia** | Inland rural Florida | "The Allied Crystal sugar refinery provides the jobs, while the local biker gang provides almost everything else." | verified [72][80] |
| **Mount Kalaga National Park** | North Florida uplands | On the northern border; "lush"; hunting, fishing, off-road trails; "hillbilly mystics and paranoid radicals" | verified [72][81] |

**Characters (official site):** Jason Duval (raised among grifters, works for
drug dealers) and Lucia Caminos (out of Leonida Penitentiary), the leads;
Cal Hampton (conspiracy-minded friend); Boobie Ike (Vice City legend:
property, strip club, studio); Brian Heder (Keys smuggler); DreQuan Priest,
Real Dimez, Raul Bautista. verified [75][76]

### 5.1 Size relative to V

| Claim | Source | Label |
|---|---|---|
| "About twice the size" of V; Rockstar's biggest; more density, interaction, interiors | Aaron Garbut (Rockstar North co-head), Game Informer issue 382, Sep 29, 2026 | verified [82][83][84] |
| About **3×** RDR2's playable area | Rockstar to The New York Times | verified as a quote [85][86] (all relay the NYT) |
| "Vice City alone is twice the size of Los Santos"; built-up areas outside the city **11×** V's | Rob Nelson, relayed by YouTubers TGG and Davy Jones | single [87][88] |
| ~160 km² | Press arithmetic on the 2× claim | inferred [83][89] |
| The map "is not expected to grow much" | Player.One (Oct 26), contradicted by Garbut | single, speculative [90] |
| The story does not cover the whole map | Game Informer interview | verified [91][92] |

**Working figure (inferred):** about **150 km² in all**, with Vice City about
**20 km²** of city (2 × 75.84; 2 × V's ~10 km² city from 1.3).

### 5.2 Roads, density, NPCs, weather

- **Roads "significantly narrower"** than V's, decided at the start (Garbut
  to Bloomberg's Jason Schreier). Narrower roads meant **more buildings** to
  fill the space ("All these things sort of come [back] to bite you later"),
  and traffic is denser. verified [93][94][95]
- A few artists have planned the map since about 2015. verified [93][94]
- **600,000+ animations**, against ~55,000 in V and ~300,000 in RDR2 (NYT).
  verified [85][96]
- **NPCs vary by neighbourhood** in height, build and clothing (Game
  Informer). single [97]
- **Weather:** local storms (rain here, sun nearby), lasting puddles,
  rainbows, tropical storms and hurricanes. verified [82][98]. **170+
  animal species** in Rare, Discoverable and Legendary tiers. verified
  [82][83]
- Disney World and the Space Coast are left out. single [99]

### 5.3 Speculative, not used for design

- The **Sept 2022 leak** and fan maps: Port Gellhorn on the west edge in
  "Kelly County", a county layout, "three major cities". [100][80]
- A claim that GTA VI was once planned to span North and South America
  rests on a weak source. [101]

## 6. Comparison across the series

| Game | Total | Land | Cities | Countryside | Label |
|---|---|---|---|---|---|
| Vice City (2002) | 9.11 km² | 5.62 km² | 1 | Almost none: city islands, beach, docks | single [1] |
| San Andreas (2004) | 38.2 km² | 31.55 km² | **3** (LS, San Fierro, Las Venturas) | Forest, desert and mountain between the cities; share not measured | single [1]; ratio gap |
| GTA IV (2008) | not measured here | — | 1 (Liberty City, with Alderney) | Almost none | V ≈ 3× Liberty City single [6] |
| GTA V (2013) | 75.84 km² | 48.15 km² | 1 + small towns | **About 75 %** of land not city | inferred [1][13][14] |
| GTA VI (2026) | ~2× V (~150 km²) | — | 1 big city + towns + Keys | Six regions, one urban; "11× built-up outside the city" | [82][87]; ratio inferred |

**Trend (inferred):** SA had three cities with country between them. V and VI
have one big city and grow the countryside and towns; VI adds density
(narrow roads, interiors), not cities. **Solvera's brief (4 cities plus
countryside) follows SA's model**, not V's or VI's.

## 7. Lessons for Solvera (top-down mobile, small budget), ranked by impact

`game/data/world_map.json` is **8 × 6 km = 48 km²**, the same as V's land
area. Its city rectangles are Bellerive 2.5 km², Porto Brisa 1.8 km² and Las
Brasas 1.9 km².

### Copy

1. **About one quarter city, three quarters country.** V's city is about 20
   to 25 % of its land (inferred, 1.3). Four cities on 48 km² gives **2 to 3
   km² each**, which is what the json already uses. Keep the city sizes; let
   the country between them carry the scale.
2. **Few rural roads, each with a character.** V serves all of Blaine with a
   coast highway, an inland freeway, one cross road and a few named desert
   roads (2.4). For Solvera: one coast road, one inland highway, one
   mountain pass, and dirt spurs to each village or site. Each is a ride
   with views, not a grid.
3. **One town, one landmark, one faction per rural region**, as in V (Sandy
   Shores with the Alamo Sea, Lost MC and Stab City; Grapeseed with the
   O'Neils; Paleto with its bank; Chiliad with the cult and cable car;
   Zancudo with the army). One memorable hook per region beats detail
   everywhere.
4. **Military exactly as V does it:** **one huge base** (own airfield and
   jets, fenced, instant high wanted level, on a main road between cities)
   and **three or four small secure sites** (lab, federal police HQ,
   private-army dock, prison).
5. **Ghost places from decline, not empty land.** V's motel, radio shack,
   trailer camp and mine are single props or half-dead towns, cheap in a
   top-down tile set (boarded windows, dry pools, wrecks). VI's Port
   Gellhorn is the same idea at town scale.
6. **Compress and emphasise (Garbut).** Keep each city's 3 to 5 signature
   districts and its one best landmark (the Vinewood-sign rule); drop the
   sprawl.
7. **One sentence of mood per region**, as VI's six regions have (glamour,
   island smugglers, swamp danger, dying coast, refinery and bikers,
   mountain paranoia). Cheap to write before building, and it drives props,
   NPCs and missions.
8. **Fill long roads with events.** V has 57 random events, mostly roadside.
   On a phone, 10 to 20 short ones (hitchhiker, breakdown, ambush, chase)
   make 1 to 3 minutes of country driving feel full.
9. **Let water frame the map.** About 37 % of V's measured area is water
   (inferred). Coast, lakes and rivers are the cheapest big terrain to draw
   top-down, and they give boats a reason to exist.

### Avoid

10. **VI's narrow roads.** They cost Rockstar extra buildings. With
    top-down thumb steering, **keep roads wide**, especially rural ones;
    density comes from props, not lane width.
11. **Transport nobody uses.** V's metro (LSIA to Davis only) is "incredibly
    unpopular" in its own lore. Build lines only where they save real time
    between cities (the Solvera Line, a taxi skip, an SA-style ticketed
    flight); a one-off ride like the Chiliad cable car is fine as a set
    piece.
12. **One undifferentiated wilderness.** V's country works because desert,
    lake, forest, mountain and swamp sit in separate bands. Give each
    Solvera zone one biome and one palette, readable from above.
13. **Cutscene-only travel on core routes.** SA's tickets are a good
    convenience, but the first trip between two cities should be driven so
    the player sees the country in between.

## Gaps (not verified this session)

No page could be opened (see "How to read this note"); the search budget ran
out before these were covered: Pegasus in story mode, bike rentals, blimps,
aircraft and boat handling, freight-train routes, the SA ticket price and
unlock, Triad and Epsilon locations, Paleto Forest and Tongva Hills, GTA IV's
measured area, a measured LS–Paleto drive time, and per-area pedestrian
data.

## Sources

1. Sportskeeda, GTA maps ranked by size (KeWiS / GTAForums measurements): https://www.sportskeeda.com/gta/gta-ranking-maps-order-size ; original thread https://gtaforums.com/topic/533282-km2-map/ (not opened)
2. GTABoom wiki, GTA 5 map: https://wiki.gtaboom.com/wiki/gta-5-map
3. Wikipedia, Grand Theft Auto V: https://en.wikipedia.org/wiki/Grand_Theft_Auto_V
4. Beebom, GTA 5 map guide: https://beebom.com/gta-5-map-guide/
5. Steam discussion, map size: https://steamcommunity.com/app/460930/discussions/0/135509724377245734
6. The New Yorker (2013), "Idling in Los Santos", repost: https://www.allnightmenu.la/stories/idling-in-los-santos
7. Cfx.re forum, syncing GTA V coordinates: https://forum.cfx.re/t/syncing-gta-v-coordinates-in-leaflet-map/5320113
8. Laps4, where is Paleto Bay: https://www.laps4.com/preguntas-y-respuestas/donde-esta-paleto-bay-en-gta-v
9. PowerPyx, Paleto Score Setup gold: https://www.powerpyx.com/gta-v-paleto-score-setup-gold-medal-walkthrough/
10. AOL (2013), drive through GTA 5's world: https://www.aol.com/amphtml/2013-12-30-watch-a-gamer-drive-through-gta-5s-entire-world.html
11. Kotaku, man walks across every GTA: https://kotaku.com/patient-man-walks-across-every-grand-theft-auto-game-1736620434
12. GTABoom, walk across the GTA franchise: https://www.gtaboom.com/you-can-walk-across-the-gta-franchise-in-5-hours-50d9
13. GTA Wiki via search (Blaine County / LS County split): https://gta.fandom.com/wiki/Blaine_County
14. CinemaBlend (2013), GTA 5 map leaked: https://cinemablend.com/games/GTA-5-Map-Leaked-58992.html
15. GTABoom, GTA V map and Los Angeles: https://www.gtaboom.com/gta-v-map-los-angeles/
16. BuzzFeed News (2013), "Way Beyond Anything We've Done Before" (Garbut): https://www.buzzfeednews.com/article/josephbernstein/way-beyond-anything-weve-done-before-building-the-world-of-g
17. Wikipedia, Development of GTA V: https://en.wikipedia.org/wiki/Development_of_Grand_Theft_Auto_V
18. DualShockers, Garbut on creating Los Santos: https://www.dualshockers.com/grand-theft-auto-vs-art-director-on-creating-los-santos-id-never-want-to-rebuild-a-city/
19. Grand Theft Wiki, Freeways / Great Ocean Highway: https://www.grandtheftwiki.com/Freeways , https://www.grandtheftwiki.com/Great_Ocean_Highway
20. ExpertBeacon, how accurate is the GTA map to LA: https://expertbeacon.com/how-accurate-is-gta-map-to-la/
21. GTABoom wiki, how well V's map emulates LA: https://wiki.gtaboom.com/wiki/How_Well_Does_GTA_V%27s_Map_Emulate_Los_Angeles
22. GTA Fandom mirror, Sandy Shores: https://breezewiki.discard.no/gta/wiki/Sandy_Shores
23. Laps4, what is Sandy Shores based on: https://www.laps4.com/preguntas-y-respuestas/what-is-sandy-shores-based-on
24. GTA Wiki, Thomson Scrapyard: https://gta.wiki/w/Thomson_Scrapyard
25. GTA Wiki, radio stations in GTA V (Rebel Radio building): https://gta.wiki/w/Radio_Stations_in_GTA_V
26. GTA Wiki, Harmony: https://gta.wiki/wiki/Harmony
27. onX wiki, list of municipal districts: https://onx.fandom.com/wiki/List_of_Municipal_Districts
28. GTA Wiki, McKenzie Field: https://gta.wiki/wiki/McKenzie_Field
29. Vintage is the New Old, what is Paleto Bay based on: https://www.vintageisthenewold.com/faq/what-is-paleto-bay-based-off-of-in-gta-v
30. GTA Fandom mirror, Stab City: https://breezewiki.discard.no/gta/wiki/Stab_City
31. Xataka Brasil, the ghost town that inspired GTA: https://www.xataka.com.br/diversos/eu-morei-na-cidade-fantasma-dos-estados-unidos-que-inspirou-fenomeno-gta-e-posso-provar-que-trevor-estava-certo-e-que-a-ia-tem-a-ver-com-isso
32. GTA Wiki, Mount Chiliad: https://gta.wiki/w/Mount_Chiliad_(HD_Universe)
33. GTA Fandom mirror, Altruist Camp: https://breezewiki.discard.no/gta/wiki/Altruist_Camp
34. GTA Fandom mirror, Braddock Pass: https://breezewiki.discard.no/gta/wiki/Braddock_Pass
35. Grand Theft Wiki, Restricted Areas: https://www.grandtheftwiki.com/Restricted_Areas
36. Grand Theft Wiki, GTA V areas template: https://www.grandtheftwiki.com/Template:Gtav_areas
37. GTA Myths Wiki, Derelict Motel: https://gta-myths.fandom.com/wiki/Derelict_Motel
38. Sportskeeda, abandoned mine on the GTA Online map: https://sportskeeda.com/gta/where-abandoned-mine-gta-online-map
39. Outsider Gaming, military base: https://outsidergaming.com/military-base-combat-vehicle-gta-5/
40. The Gun Zone, which base is Zancudo modelled on: https://thegunzone.com/?p=1055432
41. Gry-Online, GTA 5 government facilities: https://www.gry-online.pl/poradniki/gta-5/obiekty-rzadowe/z0fde1
42. GTA Base, GTA 5 gangs and factions: https://www.gtabase.com/grand-theft-auto-v/gangs/
43. Grand Theft Wiki, Restricted Areas (Bolingbroke): https://www.grandtheftwiki.com/Restricted_Areas
44. GTA Wiki, Highways: https://gta.wiki/w/Highways
45. GTA Fandom, Los Santos Freeway (HD Universe): https://gta.fandom.com/wiki/Los_Santos_Freeway_(HD_Universe)
46. GTA Fandom mirror, Popular Street (street index): https://breezewiki.discard.no/gta/wiki/Popular_Street
47. Grand Theft Wiki, Random Events: https://www.grandtheftwiki.com/Random_Events
48. GTA Base, 100 % completion checklist: https://www.gtabase.com/grand-theft-auto-v/guides/gta-5-100-completion-guide-checklist
49. GTA Fandom, West Vinewood: https://gta.fandom.com/wiki/West_Vinewood
50. GTA Fandom, Rockford Hills Police Station: https://gta.fandom.com/wiki/Rockford_Hills_Police_Station
51. Everyeye.it, GTA 5 Los Santos special: https://www.everyeye.it/articoli/speciale-gta-5-los-santos-20563.html
52. Grand Theft Wiki, Los Santos in GTA V: https://www.grandtheftwiki.com/Los_Santos_in_GTA_V_Era
53. GTA Fandom, Chamberlain Hills: https://gta.fandom.com/wiki/Chamberlain_Hills
54. TheGamer, 10 things about the Altruist Cult: https://www.thegamer.com/grand-theft-auto-v-10-things-you-never-knew-about-the-altruist-cult/
55. GGRecon, Epsilon cultists became real: https://www.ggrecon.com/articles/rockstar-legend-confirms-gta-v-accidentally-made-its-epsilon-cultists-real
56. La Prensa (2012), "Una ciudad para jugadores": https://www.laprensani.com/2012/12/01/tecnologia/125783-una-ciudad-para-jugadores
57. Grand Theft Wiki, LSIA in GTA V: https://www.grandtheftwiki.com/Los_Santos_International_Airport_in_GTA_V
58. GTA Fandom, Sandy Shores Airfield: https://gta.fandom.com/wiki/File:Sandy-shores-airfield.jpg
59. GTA Wiki, Los Santos Transit Metro: https://gta.wiki/w/Los_Santos_Transit_Metro
60. Dexerto FR, metro concept: https://www.dexerto.fr/gta/un-concept-gta-online-etonnant-pour-ameliorer-metro-et-tram-a-los-santos-1263507/
61. GTA Intel, Cable Car: https://gtaintel.com/games/gta-5/vehicles/cablecar-v
62. Red Bull, Mount Chiliad interview: https://www.redbull.com/au-en/gta-v-mount-chiliad-interview
63. Dexerto, fast travel with taxis in GTA Online: https://www.dexerto.com/gta/how-to-fast-travel-with-taxis-in-gta-online-2037578/
64. Charlie Intel, taxi fast travel: https://www.charlieintel.com/gta/how-to-use-fast-travel-with-taxis-in-gta-online-223106/
65. GTA Wiki, Downtown Cab Co.: https://gta.wiki/wiki/Downtown_Cab_Co.
66. GTA Base, Kraken: https://www.gtabase.com/grand-theft-auto-v/vehicles/kraken-submersibles-kraken
67. GTA Fandom, Kraken: https://gta.fandom.com/wiki/Kraken
68. GTA Fandom, Las Venturas Airport: https://gta.fandom.com/wiki/Las_Venturas_Airport
69. Grand Theft Wiki, Airports: https://www.grandtheftwiki.com/Airports
70. TechRadar, GTA 6 delayed to Nov 2026: https://www.techradar.com/gaming/grand-theft-auto-6-delayed-again-but-itll-still-ship-in-2026
71. Pure Xbox, GTA 6 delayed to Nov 2026: https://purexbox.com/news/2025/11/its-official-rockstar-games-has-delayed-gta-6-to-november-2026
72. PC Gamer, charting the GTA 6 map: https://www.pcgamer.com/games/grand-theft-auto/gta6-map/
73. GTA Base, Game Informer preview: https://www.gtabase.com/articles/gta-6/gta-6-game-informer-previews-new-details-on-leonida-weather-more
74. iTechGuides, six Leonida regions: https://www.itechguides.com/gta-6-map-guide-all-six-leonida-regions-key-locations-activities-and-exploration-tips/
75. Engadget, second GTA 6 trailer: https://engadget.com/gaming/second-gta-6-trailer-sheds-more-light-on-the-story-140452729.html
76. Soap Central, cities and characters in the new trailer: https://www.soapcentral.com/pop-culture/which-cities-characters-featured-gta-6-full-details-new-trailer-explored
77. The Games Wiki, Grassrivers: https://thegameswiki.com/grand-theft-auto-vi/wiki/grassrivers
78. Red Bull, GTA 6 biomes explained: https://www.redbull.com/us-en/gta-6-biomes-map-explained
79. Timesaver, Port Gellhorn: https://timesaver.gg/blog/gta-6-port-gellhorn-confirmed-2026
80. TalkEsport, Ambrosia guide: https://www.talkesport.com/guides/gta-6-ambrosia-guide/
81. PC Gamer, Mount Kalaga "hillbilly mystics and paranoid radicals": https://www.pcgamer.com/games/grand-theft-auto/the-gta-6-map-will-include-a-lush-national-park-in-the-mountains-featuring-hillbilly-mystics-and-paranoid-radicals/
82. Forbes (Oct 6, 2026), map about twice GTA 5: https://www.forbes.com/sites/brianmazique/2026/10/06/gta-6s-map-is-about-twice-the-size-of-gta-5-with-hurricanes-and-170-animal-species/
83. GTA Intel, Game Informer cover story: https://gtaintel.com/news/gta-6-game-informer-cover-story-new-details
84. KitGuru, map "twice as big": https://www.kitguru.net/gaming/matthew-wilson/gta-6-map-is-twice-as-big-as-gta-5/
85. VGC, 3× RDR2: https://www.videogameschronicle.com/news/grand-theft-auto-6s-map-is-three-times-bigger-than-red-dead-redemption-2/
86. iGrandTheftAuto, NYT details: https://www.igrandtheftauto.com/gta6/news/new-york-times-reveals-new-gta-6-details-600000-animations-huge-map-80-hour-playthrough-and-more
87. Insider Gaming, Vice City twice Los Santos: https://insider-gaming.com/gta-6-vice-city-twice-size-los-santos-map/
88. Gfinity, 3× RDR2 and what to expect: https://www.gfinityesports.com/article/gta-6-map-is-3x-the-size-of-red-dead-redemption-2-what-to-expect
89. Notebookcheck, Vice City map size: https://www.notebookcheck.net/GTA-6-Vice-City-map-size-and-completion-time-revealed.1381025.0.html
90. Tech-Insider, 2× claim against report: https://tech-insider.org/gta-vi-enterable-interiors-map-size-2x-claim-vs-report-2026/
91. TheGamer, story doesn't cover the whole map: https://www.thegamer.com/gta-6-map-so-massive-story-doesnt-cover-it-all-game-informer-interview/
92. Dexerto, won't see it all through story: https://www.dexerto.com/gta/rockstar-says-gta-6s-map-is-so-big-you-wont-see-it-all-just-by-playing-story-missions-3414118/
93. TechRadar, roads narrower, 11 years of map planning: https://techradar.com/gaming/rockstar-artists-have-been-working-on-gta-6-for-11-years-to-plan-out-the-map-co-head-says-roads-are-narrower-than-gta-5s-which-had-a-ripple-effect-as-the-studio-had-to-add-even-more-buildings-all-these-things-sort-of-come-to-bite-you-later
94. IBTimes UK, narrow roads forced more buildings: https://www.ibtimes.co.uk/gta-6-map-planning-began-11-years-ago-narrow-roads-forced-rockstar-add-more-buildings-1827014
95. PSU, "significantly narrower roads": https://www.psu.com/news/grand-theft-auto-vi-includes-significantly-narrower-roads-than-gta-v-weapons-system-more-like-red-dead-redemption-2/
96. Hitmarker, 10× the animations of GTA 5: https://hitmarker.net/news/gta-6-has-more-than-10-times-the-animations-of-gta-5-and-double-those-in-red-dead-redemption-2-rockstar-games-confirms-4628737
97. Grandtheft.gg, Game Informer details: https://grandtheft.gg/game-informers-gta-6-cover-story-details-revealed
98. Forbes (Oct 1, 2026), weather system: https://www.forbes.com/sites/brianmazique/2026/10/01/gta-6s-new-weather-system-sounds-ridiculously-detailed/
99. GTABoom, landmarks GTA 6 leaves out: https://www.gtaboom.com/these-are-the-famous-florida-landmarks-gta-6-is-leaving-out-8a8d
100. Sportskeeda, leak "three major cities": https://www.sportskeeda.com/gta/gta-6-leak-blunder-discloses-three-major-cities-game
101. Toy People, GTA 6 originally planned for the Americas: https://www.toy-people.com/en/?p=115486
