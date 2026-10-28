# Solvera: activity gap inventory and roadmap (2026-10-28)

Brief, from Sachin (word for word): "Lets keep it the same as it is planned for now, lets not make it
bigger, we will introduce more things inside so the whole city feels much more lively than GTA V it
will have everything that is in GTA V and san andreas and madout2, but also have much more to do,
like several video games completely new and built by us, inside the gaming cafes, etc."

Research only: written before any of these packages started. Status: proposed, waiting on the decisions in section 6.

## 0. Method and limits

- **Web**: WebFetch could not reach the sources. `play.google.com`, `gtabase.com` and
  `www.gtabase.com` do not resolve in this container (network allowlist), so no page was opened
  directly. Every web fact below comes from **WebSearch result summaries** that quote the named
  wiki page. This is the same method `reference/world/gta_systems.md` used.
- **Labels**:
  - **V**: verified. A wiki or official-listing URL in the search summary states it (source ids
    in section 5).
  - **R**: verified earlier in `reference/world/gta_systems.md`, which lists its URLs.
  - **2**: secondary only (a guide site, not a wiki or store page).
  - **U**: unverified (from memory). Treat these as leads.
- **MadOut2** (MO2): the Google Play listing could not be opened. MO2 facts come from the Apple App
  Store listing of the same app (id1214765807; developer Vladislav Ivanchuk, now MadOut Games
  LLC-FZ), from APKMirror release notes, and from BlueStacks guides (secondary). No MO2 wiki was
  found.
- **Solvera survey**:
  - read: `game/README.md`, `WORLD_BIBLE.md`, `MVP_DESIGN.md`, `INTERIORS_SERVICES_PLAN.md`,
    `TODO.md`, `ACT1_MISSIONS.md`, `GANGSTAR_CONCEPT.md`, `WORLD_V3_PLAN.md` sections 5-7, and
    `HANDOFF-interiors.md` and `HANDOFF-wealth.md`; the other HANDOFF files were checked by topic;
  - code checked with grep in `game/scripts/`. "Have" means it is in code, not only in a plan.
- **Session**: one long sitting of 3-5 h by one AI agent, tests and screenshots included. The
  interiors plan used 4-6 h sessions, so its figures, reused here, are slightly conservative.

## 1. Checklist: reference games against Solvera today

Columns: who has the item (V5 = GTA V, SA = San Andreas, MO2 = MadOut2) with its label and
source; Solvera's status (**have** / **partial** / **missing**) with file references.

### 1.1 Activities, sports, minigames, gambling, arcades

| Item | Who / label / source | Solvera |
|---|---|---|
| Golf, tennis, darts | V5, V [S9][S5] | missing. A tennis court exists as estate scenery only (`kits/grounds_kit.gd:101`) |
| Yoga, triathlon | V5, 2 [S10] | missing; packages 28 and 29 |
| Flight school, parachute jumps (13) | V5, V [S5]; SA pilot and boat schools, R | missing; packages 30 and 31 |
| Shooting range | V5, V [S5] | missing (planned: interiors phase 6) |
| Street basketball | SA, V [S15] | partial: the Wharfside Courts exterior (`city_cells.gd:789`); no game |
| Boxing / gym fights | SA, R | partial: The Pit exterior (`city_cells.gd:1389`); one hard-coded combo (`humanoid.gd:124`) |
| Pool ($50-1000 bets) | SA, V [S15] | missing |
| Dancing (rhythm), lowrider bounce challenge | SA, V [S15] | missing |
| Arcade cabinets (4 games, free, high scores, in 24-7 stores) | SA, 2 [S16] | missing (TODO.md "arcades") |
| Casino: blackjack, roulette, video poker, slots, wheel | SA, V [S11]; V5 casino is Online only, U | missing. **Conflict**: `GANGSTAR_CONCEPT.md:101` says avoid simulated gambling |
| Horse betting (Inside Track) | SA, V [S11] | missing (same conflict) |
| Cinema, bar, strip club (friend activities) | V5, V [S9] | missing. Strip club: recommend never (tone and age rating) |
| Fairground rides | V5, V [S9] | missing; package 32 |
| Hunting / wildlife photography challenge | V5, V [S4] | missing |
| Stock market | V5, R | missing; designed in `STOCK_MARKET_DESIGN.md` (lite about 2.5 sessions, full about 6) |
| Dating, girlfriends, friends | SA, V [S15]; V5 friends, V [S9] | missing |
| 1v1 races, clan seasons, daily and weekly tasks | MO2, V [M2]; tasks 2 [M3] | missing |

### 1.2 Jobs, businesses and properties

| Item | Who / label / source | Solvera |
|---|---|---|
| Taxi driver job | SA, V [S14]; MO2, 2 [M3] | partial: the player rides cabs only (`taxi.gd`: hail, fares, skip) |
| Vigilante, paramedic, firefighter (permanent perks) | SA, V [S14] | missing (MVP lists vigilante) |
| Burglary | SA, V [S14] | missing (TODO.md robberies) |
| Trucking, quarry, valet, courier, freight train | SA, V [S14] | missing (courier in ACT1 side content) |
| Parking and parcel delivery jobs | MO2, 2 [M3] | missing |
| Pimping | SA, V [S14] | recommend never (tone) |
| Store hold-ups | V5, V [S5] | missing (plan D5 in INTERIORS_SERVICES_PLAN) |
| Heists: 6, approach choice, hired crew, setups | V5, V [S7] | missing (TODO.md heists) |
| Buyable businesses with weekly income (mod shop, cab co., cinemas, hangars) | V5, V [S1] | missing |
| Assets: safehouses, income properties | SA, R | partial: Moreau House is a story place, not owned |
| Real estate from apartment to mansion | MO2, V [M2] (12.03 notes); 2 [M3] | missing |
| Street business (food stand, garage, club front) | Solvera plan (MVP) | missing |
| Gang turf wars, recruiting | SA, R; MO2 clans, 2 [M3] | missing (district `faction` is never read; HANDOFF-wealth) |

### 1.3 Vehicles, tuning, garages

| Item | Who / label / source | Solvera |
|---|---|---|
| Cars, motorbikes, scooters | all | **have**: 16 models in 13 classes with their own handling (`kits/vehicle_kit.gd:17`, `vehicle.gd`) |
| 70+ car types, tractors to premium | MO2, V [M1] | partial (16) |
| Bicycles, BMX | SA, V [S17] | missing |
| Boats, airboat, jetski, sub | SA and V5, R | partial: moored boats and an airboat dock as props (`kits/country_kit.gd:143`) |
| Planes, helicopters, blimp, jetpack, RC | SA and V5, R / V [S17] | missing (world phase 3 rentals) |
| Tank | MO2, V [M2] (single player) | missing |
| Trains, metro, trams you ride | SA and V5, R | partial: streetcars and rails are scenery |
| Tuning (engine, suspension, tyres; paint, wheels) | MO2, V [M1]; V5 LSC and SA mod garages, R | missing (planned: interiors phase 3) |
| Respray clears the wanted level | series, R | missing |
| Auto service repair | MO2, 2 [M3] | missing |
| Owned cars, garages | V5 hangar and garage, V [S1] | missing |
| Fuel | none of the three, U | missing (plan D4: light fuel) |
| Carjacking, damage, wrecks, breakable props | all | **have** (`vehicle.gd`, `breakables.gd`) |

### 1.4 Weapons and combat

| Item | Who / label / source | Solvera |
|---|---|---|
| Firearms, 8-slot weapon wheel | V5, V [S8] | missing (planned: phase 6, 8 weapons) |
| Attachments and tints at the gun shop | V5, V [S8] | missing |
| Weapon skill tiers, dual wield | SA, V [S17] | missing |
| Weapon upgrades and skins | MO2, V [M1] | missing |
| Melee: punch combo, knockdown, hit-stop | all | **have** (`humanoid.gd`, `fx.gd`) |
| Fighting styles learned at gyms | SA, R | missing (plan D6) |
| Throwables (molotov, grenade) | V5, V [S8] | missing |

### 1.5 Police and wanted levels

| Item | Who / label / source | Solvera |
|---|---|---|
| Stars from crimes, escape by breaking line of sight | all | **have**, levels 1-2 only (`wanted.gd:7`, `police_manager.gd`) |
| 5 levels: roadblocks, SWAT, helicopter, boats | V5 and SA, U (Solvera's MVP lists them) | missing |
| Search cones, cops searching on foot | V5, V [S3] | partial: an unseen timer (`wanted.gd` EVADE_TIME) and flashing stars; no cones |
| Changing your look drops a star | V5, V [S3] | missing |
| Busted and Wasted respawns, fees | series, R | partial: the respawns (`main.gd:82,180`); no fees |
| Cops vs bandits role mode | MO2, V [M1] | n/a (online) |
| Police cars deploy officers | V5, U | **have** (`vehicle.gd:13` officer_deployed) |

### 1.6 Character systems

| Item | Who / label / source | Solvera |
|---|---|---|
| Stats: stamina, shooting, strength, stealth, flying, driving, lung capacity, special | V5, V [S2] | missing |
| Fat, muscle, respect, sex appeal, lung capacity, gambling skill | SA, V [S12] | missing |
| Hunger, vending machines | SA, R | partial: snacks and diner meals heal (`inventory.gd`, `interiors.gd`); no hunger |
| Clothes shops | SA and V5, R | partial: outfit slots in `kits/character_kit.gd:111`; no shop or wardrobe |
| Barbers, tattoos | SA, R | missing (barbers planned in phase 2; tattoos unplanned) |
| Gyms | SA, R | missing (planned: phase 4) |
| Food places you enter | SA, R | **have**: corner stores and diners (`places.gd:15`, `interiors.gd`) |
| Special abilities (slow-mo) | V5, V [S2] | missing |

### 1.7 World life

| Item | Who / label / source | Solvera |
|---|---|---|
| Pedestrians who flee or fight back | all | **have** (`pedestrian.gd`: WANDER, FLEE, FIGHT) |
| Ambient scenarios (benches, phones, chats, shopping bags) | V5, 2 [S19] | partial: inside places only (`patron.gd`); street peds only walk loops |
| Ped routines (home, work) | V5, U | missing (HANDOFF-wealth: NPCs have no home or job) |
| Density by zone and time | SA, R (popcycle) | missing: a fixed bubble of 18 peds and 8 cars (`population.gd:9`) |
| Random events (57; 60 in the enhanced version) | V5, V [S7] | missing (MVP lists about 15 types) |
| Strangers and Freaks (58) | V5, R | missing |
| Animals: dogs, cats, birds, deer, coyotes, boars, sharks | V5, V [S4] | missing |
| Weather | all | **have**: clear, cloudy, rain, storms (`atmosphere.gd:98`) |
| Seasons, snow, fog | none of the three, U | missing (TODO.md weather) |
| Day and night | all | **have** (`atmosphere.gd`; lights in the shader) |
| Traffic lanes, junctions | all | **have** (`vehicle.gd:450` _traffic_ai) |
| Traffic obeys signals; peds cross streets | V5, U | missing: signals are props; peds keep to the kerb |
| Emergency services (911 call, fire trucks, ambulances revive) | V5, V [S6] | missing (ambulances are country props: `kits/country_kit.gd:2316`) |
| Ambient audio, radio, ped speech | V5, U; radio in Solvera's MVP | missing: no AudioStream anywhere in `game/scripts` |
| Riots | SA, R | missing (planned for Steelhaven) |

### 1.8 Interiors, missions, collectibles, races, phone, online

| Item | Who / label / source | Solvera |
|---|---|---|
| Enterable shops and services | SA and V5, R | partial: 2 of about 14 planned types (`places.gd`, `interiors.gd`) |
| Story missions: chase, follow, brawl, search, escort, evade, steal | all | **have**: missions 1-3 (`missions/m01..m03`) |
| Mission replay | V5, U | **have** (`missions/mission_manager.gd:199`, phone Missions) |
| 30+ story missions, mafia RP | MO2, V [M1] | partial: 3 of 13 in act 1 |
| Robbery and car-theft events | MO2, V [M1] | missing |
| Collectibles: SA tags 100, snapshots 50, horseshoes 50, oysters 50; V5 letter scraps 50, ship parts 50 | V [S13][S5] | missing: graffiti is decoration (`kits/building_kit.gd:397`) |
| Stunt jumps (SA 70; V5 50), under-bridge (50), knife flights (15) | V [S13][S5] | missing |
| Races: street, off-road, sea, air | V5, V [S5] | missing (street races planned) |
| Phone hub | V5, U | **have**: Messages, Contacts, Map, Places, Missions, Cab, Settings (`phone.gd:112`) |
| Phone internet, social network, buy cars online | V5, V [S5] (buy from a website) | missing |
| Online lobbies (100-200 players), clans | MO2, V [M1][M2] | out of scope: single player. Use leaderboards and weekly tasks |

**Tally**: 91 items. **Have**: 13. **Partial**: 14. **Missing**: about 60. Excluded or out of
scope: 4. The engine,
driving, look, map and interiors foundation are strong. What is missing is **things to do and
signs of life**, which is what Sachin's brief asks for.

## 2. Constraints every package keeps

- **WORLD_BIBLE**:
  - no real brands, people, religious figures or institutions;
  - a crime family is never an ethnic group.
  - Arcade cabinets, games, sports leagues, shops and radio are all fictional. No song,
    cabinet or logo imitates a real one.
- **Tone and rating** (MVP, GANGSTAR_CONCEPT):
  - cartoon violence;
  - no strip clubs, pimping or drug selling;
  - hunting becomes wildlife photography;
  - no paid loot boxes.
  - **Gambling needs Sachin's call**: the concept says avoid it; the brief says "everything in
    SA". Proposed: a Las Brasas casino later, chips only, never bought with real money, with
    skill games (pool, darts) up front.
- **Phone budget**:
  - performance: 30 fps on the min-spec phone (~4 GB RAM, 2021 mid-range); no real lights;
  - city: one draw call per block; p90 under 7.1k triangles per block;
  - interiors: at most 30k triangles, 8 draw calls and 10 animated people; built during a 0.3 s
    fade;
  - install: base under 150 MB, the rest as content packs.
  - Life packages stay **inside the existing bubble**:
    - 18 peds and 8 cars; emergency vehicles count against the 8;
    - at most about 6 animals, with bird flocks as one MultiMesh or particles;
    - at most about 16 audio voices, with radio streamed from compressed files.
  - Minigames run **while the city is frozen** (as interiors do), so each has the whole budget:
    2D or SubViewport, under 50 draw calls, code-drawn, under 1 MB each.
- **City size stays as planned** (HANDOFF-wealth, 2026-10-28). Everything goes **into what exists**:
  - shopfronts become places;
  - parks (Liberty Green, Moreau Square), courts, the river and the bayou get activity spots;
  - nothing adds districts or blocks.
  - Aircraft, trains and far-away content stay in the `WORLD_V3_PLAN.md` phases. They are not
    counted here.

## 3. Roadmap packages, ordered by liveliness per session

Score = how much a player would feel "the city is alive" (1-5), divided by cost. Costs are rough
sessions. "IS-n" = `INTERIORS_SERVICES_PLAN.md` phase n (already costed there).

| # | Package | What it adds (one line) | Depends on | Cost | Life |
|---|---|---|---|---|---|
| 1 | IS-1 Food and daily life | Food stalls and a truck, supermarket, restaurants and cafés, petrol stations; light fuel | IS-0 (done) | 1 | 4 |
| 2 | IS-5 Civic | Precinct lobby (fines, impound), clinic, Union Station hall; respawns inside | IS-0 | 0.5 | 2 |
| 3 | Animals and pets | Dog walkers, strays, cats, pigeon and gull flocks, egrets and gators in the bayou, farm animals; flee and follow behaviour | rig poses | 1.5 | 4 |
| 4 | Street life pass | Ped scenarios (bench sit, phone, chat groups, jog, shopping bags, buskers, vendors), time-of-day density by district, crossings at zebras, traffic obeys signals | `pedestrian.gd`, `population.gd`, `vehicle.gd` | 2 | 5 |
| 5 | Random events v1 | About 15 events: purse snatch, mugging, crash and argument, breakdown, chase, street fight, lost tourist, getaway driver, rival ambush; with rewards | 4 | 2 | 5 |
| 6 | Audio foundation | Engines, footsteps, hits, sirens, horns, crowd and district ambience, ped barks; 3 radio stations with fictional DJs (music from CC0 or AI, see section 6) | none | 2 | 5 |
| 7 | Collectibles and photos | Hidden packages, graffiti tags you spray, landmark photos with the phone camera, collection log | phone | 1 | 3 |
| 8 | IS-2 Looks | Clothing shops in 3 styles, barbers, the wardrobe; add a tattoo parlour (+0.3) | IS-0 | 1.3 | 3 |
| 9 | Emergency services | Ambulances to the injured, fire trucks to burning wrecks, cops answer NPC crimes; paramedic, firefighter and vigilante jobs with perks | 5, vehicle kit | 2 | 4 |
| 10 | Nightlife | Bars and the Blue Lantern jazz club (live band, drinks), a dance rhythm game, a cinema showing original shorts | IS-0, 6 | 2 | 4 |
| 11 | **Arcade and gaming café framework** | See 4.1 | IS-0, inventory | 1.5 | 3 |
| 12 | Arcade games A and B | The first two games in 4.2 | 11 | 2.5 | 3 |
| 13 | Phone media | Reactive social feed and news about your deeds, a fictional short-video app, a fictional stock ticker, a car marketplace | `phone.gd` | 1.5 | 3 |
| 14 | Races and stunts | Checkpoint street races vs AI (sprint and circuit), bike races, stunt jumps with slow-mo, ghost of your best time | `vehicle.gd` | 1.5 | 3 |
| 15 | IS-3 Vehicles | Owned cars, garage, service shops (repair, respray, parts), car wash | IS-0 | 1.5 | 2 |
| 16 | Side jobs | Taxi driver, courier, delivery rider, tow truck, valet, parking challenge | 4, 15 | 2 | 3 |
| 17 | IS-4 Fighting and training, plus stats | Styles, gyms, the Pit ladder; stamina, strength, driving and shooting stats that grow with use | IS-0 | 2.5 | 3 |
| 18 | Arcade games C to E | The last three games in 4.2 | 11 | 2.5 | 2 |
| 19 | IS-6 Weapons | 8 weapons, wheel, auto-aim, ammo shop, range | IS-0 | 2 | 3 |
| 20 | Wanted 3-5 | Search cones, roadblocks, SWAT vans, helicopter spotlight, look change and respray drop stars, fines | 19 | 2.5 | 3 |
| 21 | Sports | 3v3 streetball at the Wharfside Courts with a weekly league; tennis at a club; pool and darts in bars | 10, 17 | 3 | 3 |
| 22 | Businesses and property | 3 street businesses, buying homes on the phone, income and raids, gang turf in the Wards | 15, 19 | 3 | 3 |
| 23 | Robberies, then heists | Till hold-ups and burglary (room kits), then planned bank, hotel and restaurant jobs with crew and approach (TODO.md) | 19, 20, 22 | 7 | 3 |
| 24 | Friends and dating | Call friends for activities (bar, pool, arcade, cinema); relationship perks | 10, 21 | 2 | 2 |
| 25 | Seasons and weather v2 | Calendar, seasons, fog, wind, heat, festivals such as a Mardi-Gras-style parade (TODO.md weather) | `atmosphere.gd` | 3.5 | 3 |
| 26 | Bicycles and drivable boats | Bikes and BMX, speedboat and airboat on the Morrow and bayou | `vehicle.gd` | 2 | 2 |
| 27 | Light online | Leaderboards for arcade games and races, weekly challenges, cloud save | 12, 14 | 1.5 | 1 |
| 28 | Yoga and wellness | A breathe-and-hold pose minigame (E2) in a Gilt studio, then at sunrise on Brisa Beach and in Concordia's Commons Park; a short calm buff (steadier aim, faster stamina refill) | 10 (rhythm engine) | 0.8 | 2 |
| 29 | Triathlon | Swim, bike and run legs on one checkpoint chain; a levee duathlon (run and bike) first, then the Brisa Beach sprint and the Miravel Shores lake triathlon; the stamina stat sets the pace | 14, 17, 26; swimming (`ACTIVITY_IDEAS.md` 4.10) | 1.5 | 2 |
| 30 | Flight school | Lessons in the light plane, seaplane and helicopter: take-off, landing, rings, crosswind, an engine-out landing, with bronze, silver and gold; the licence unlocks rentals and owning aircraft. At the Golden Flats crop-duster strip and the Ironwharf Seaplane Base | World v3 phase 3 aircraft | 2 | 2 |
| 31 | Parachute jumps | A parachute (open, steer, flare) for jumps from Cinder Peak, the Aurum Tower and the Solvera Line bridges, then from planes and helicopters; target landings and ring courses | World v3 phase 3; 30 for jumps from aircraft | 1.5 | 2 |
| 32 | Fairground and fun pier | A travelling fair on Liberty Green each season (midway games for earned tickets, bumper cars, a Ferris wheel), then a year-round fun pier on Brisa Beach with a coaster ride; the fair also tours Golden Flats, Concordia and Steelhaven | 11 (game host), 25 (calendar) | 2 | 3 |

**Totals**:
- all 27: about **57 sessions**, of which about 10 are the interiors plan already costed;
- packages 28-32 (added 2026-10-28; Sachin: "We will build packages for these too"): about
  **8 sessions** more. They close the last section 1.1 gaps. Phase 1 can take the Gilt yoga
  studio, the levee duathlon and the Liberty Green fair; the rest waits for the world phases
  they name. `ACTIVITY_ATLAS.md` Part D places them on the map;
- **first wave**, packages 1-11: about **17 sessions**. It covers food, civic, animals, street
  life, events, audio, collectibles, looks, emergency services, nightlife and the café framework.
  These carry most of the "lively" feel.
- **Cheaper option**: packages 1-7 only, about **10 sessions**. It gives the living street but no
  arcade yet.

Parallel work: after package 4, packages 3, 6, 7 and 11 touch separate files and can run as
parallel agents. This saves about a third of the wall-clock time and costs about 20% more tokens
for merging (same estimate as the interiors plan).

## 4. Arcade and gaming café

### 4.1 Framework (package 11, about 1.5 sessions)

- **New place types** in `places.gd`:
  - "arcade" (cabinets, neon, a prize counter) in the Lantern Quarter and the Wards;
  - "gaming café" (PC rows, a snack bar) in Midtown and Gilt.
  - Both are built from `kits/interior_kit.gd` pieces: cabinets, PC desks, stools, and a prize
    shelf.
- **A minigame host**:
  - a cabinet's ENTER opens the game full-screen in a CanvasLayer or SubViewport, with the
    interior frozen;
  - one shared API for all games: `start(seed, difficulty)`, `score`, `finished`, and a pause
    and quit;
  - touch controls are remapped per game from `touch_controls.gd`;
  - a gamepad and keyboard also work.
- **Cabinet look**:
  - cabinets show a baked attract-screen image, and only the cabinet in use renders live;
  - this keeps the room within its 8 draw calls.
- **Economy**:
  - $1 a play;
  - tickets by score, traded at the prize counter for cosmetics (tees and caps with the games'
    own logos) and phone themes;
  - saved in `inventory.gd` (save v3).
- **Life**:
  - patrons play cabinets as a `patron.gd` activity; they cheer, queue and watch;
  - per-cabinet high-score tables are seeded with NPC initials;
  - a rival NPC challenges you, and there is a weekly tournament.
- **Retention**: beating a game's top score unlocks it in a phone "Arcade" app for short
  sessions anywhere.
- **Tests**:
  - enter and quit restore the room;
  - tickets and save survive a reload;
  - each game is deterministic for a seed;
  - no patron is left stuck at a cabinet.

### 4.2 Original games (each fictional, no real brands, not a clone of any title)

| Game (working name) | Pitch | Cost |
|---|---|---|
| A. **Floodline Brawlers** (1v1 fighter) | Side-on fighter with 6 fighters drawn from Solvera's streets: a trombonist, a crane operator, a roller-skating courier, a storm chaser. Light, heavy and special buttons, with guard by holding back. Its own twist: a **tide meter** that rises each round and floods the stage edges, shrinking the arena. Reuses the humanoid rig, posed side-on in a SubViewport | 1.5 |
| B. **Bayou Rush** (racer) | Top-down micro-racer on generated bayou and levee tracks. Each lap the water rises and reroutes the track; drift to charge boost. Ghost of your best lap; 3 cups | 1 |
| C. **Spin Rally** (table tennis) | Swipe to return; the curve of the swipe sets topspin or slice. A ladder of 8 NPC opponents with styles. The same game drives a **real table** in cafés and Liberty Green, where Jules plays NPCs | 1 |
| D. **Green Wave** (logic puzzle) | A daily grid puzzle seeded by date. Set the traffic signals so every car reaches its exit without a jam. Hand-tuned packs of 60 levels; difficulty rises with the number of cars | 0.75 |
| E. **Eye of the Storm** (score attack) | Fly a hurricane-research drone through a spiralling storm cell: grab data pods, dodge lightning bolts and debris, ride updrafts. Ties into the Great Storm lore; high scores feed the café board | 0.75 |

- These five cost about 5 sessions; packages 12 and 18 schedule them.
- The TODO "sucu games" item may mean sudoku: a generic sudoku is a public-domain format and can
  sit in the phone app for about 0.3 session. Ask Sachin.

## 5. Sources

GTA V:
- [S1] Properties and assets: https://gta.fandom.com/wiki/Properties_in_GTA_V ·
  https://gta.wiki/w/Assets
- [S2] Skills: https://gta.fandom.com/wiki/Skills_in_GTA_V
- [S3] Wanted level: https://gta.fandom.com/wiki/Wanted_Level_in_GTA_V ·
  https://www.grandtheftwiki.com/Wanted_Level_in_GTA_V
- [S4] Animals and hunting: https://gta.fandom.com/wiki/Animals ·
  https://www.grandtheftwiki.com/Animals_in_GTA_V · https://gta.fandom.com/wiki/Hunting
- [S5] 100% completion, collectibles, jumps:
  https://gta.fandom.com/wiki/100%25_Completion_in_GTA_V ·
  https://gta.fandom.com/wiki/Spaceship_Parts · https://gta.fandom.com/wiki/Letter_Scraps ·
  https://gta.wiki/w/Unique_Stunt_Jumps_in_GTA_V · https://gta.fandom.com/wiki/Knife_Flights
- [S6] Emergency services: https://gta.fandom.com/wiki/Ambulance_(HD_Universe) ·
  https://gta.fandom.com/wiki/Los_Santos_Fire_Department
- [S7] Heists and random events: https://gta.fandom.com/wiki/Heists_in_GTA_V ·
  https://gta.fandom.com/wiki/Random_Events_in_GTA_V
- [S8] Weapons: https://www.grandtheftwiki.com/Weapons_in_GTA_V ·
  https://gta.fandom.com/wiki/Weapon_Wheel · https://gta.wiki/w/Attachments
- [S9] Friend activities and unlocks: https://gta.fandom.com/wiki/Friendships_in_GTA_V ·
  https://gta.fandom.com/wiki/Strip_Club
- [S10] Hobbies (secondary): https://www.sportskeeda.com/gta/list-hobbies-pastimes-gta-5-100-completion ·
  https://gtaintel.com/news/gta-5-hobbies-and-activities
- [S19] Pedestrians (secondary): https://gta.wiki/w/Pedestrians

San Andreas:
- [S11] Gambling: https://gta.fandom.com/wiki/Gambling · https://gta.fandom.com/wiki/Inside_Track ·
  https://gta.fandom.com/wiki/Caligula's_Palace
- [S12] Stats: https://strategywiki.org/wiki/Grand_Theft_Auto:_San_Andreas/Stats ·
  https://gta.fandom.com/wiki/Statistics_in_GTA_San_Andreas
- [S13] Collectibles: https://gta.fandom.com/wiki/Collectibles ·
  https://gta.fandom.com/wiki/100%25_Completion_in_GTA_San_Andreas ·
  https://gta.fandom.com/wiki/Unique_Stunt_Jumps
- [S14] Side missions: https://www.grandtheftwiki.com/Side_Missions ·
  https://gtabase.com/gta-san-andreas/side-missions
- [S15] Minigames and dating: https://gta.fandom.com/wiki/Pool ·
  https://gta.fandom.com/wiki/Rhythm-based_Minigames ·
  https://gta.fandom.com/wiki/Girlfriends_in_GTA_San_Andreas
- [S16] Arcade machines (secondary):
  https://www.sportskeeda.com/gta/how-gta-san-andreas-players-can-play-arcade-games
- [S17] Weapons, jetpack, RC: https://gta.fandom.com/wiki/Weapons_in_GTA_San_Andreas ·
  https://gta.fandom.com/wiki/Jetpack
- R: `reference/world/gta_systems.md` sections 3-5 and its source list. These cover gyms,
  barbers, tattoos, mod garages, hunger, vending machines, schools, trains, flights, turf and the
  Busted and Wasted fees.

MadOut2:
- [M1] App Store listing: https://apps.apple.com/us/app/madout2-bigcityonline/id1214765807
- [M2] Release notes 18.05 (tank, house destruction, 1v1 races), 12.03 (real estate) and 19.54
  (clan seasons, story missions):
  https://www.apkmirror.com/apk/ivanchuk-vladislav/madout2-big-city-online/madout2-big-city-online-18-05-release/ ·
  https://www.apkmirror.com/apk/madout-games-llc-fz/madout2-big-city-online/
- [M3] Guides (secondary):
  https://www.bluestacks.com/blog/game-guides/madout2-big-city-online/mdo-beginners-guide-en.html ·
  https://www.bluestacks.com/ru/blog/game-guides/madout2-big-city-online/mdo-professions-guide-ru.html
- Not opened: the Google Play listing (`com.MadOut.BIG`), because the host is outside this
  container's network allowlist.

## 6. Decisions and open questions for Sachin

1. **Gambling**: a chips-only casino in Las Brasas later, or none (the concept doc says avoid)?
2. **Excluded for tone**: strip clubs, pimping and drug dealing. Hunting becomes wildlife
   photography. Is that right?
3. **Audio source**: no credits are being spent, so start with CC0 or code-synthesised effects and
   ambience. AI-generated radio music (the concept's plan) needs credits. When?
4. **Order**: is the first wave (packages 1-11, about 17 sessions) the right start, or the
   cheaper packages 1-7 (about 10)?
5. **"sucu games"**: sudoku, or something else?
