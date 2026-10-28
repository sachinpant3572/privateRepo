# TODO

## Wednesday, Oct 28, 2026: Solvera robbery missions and heists

Status: **not started**. Sachin: "Abb robbery missions too, they will allow to rob most of the
houses/buildings, with different things to rob. These will be first part of the main stroyline
and then become side quests that can be taken up anytime. Add Bank and Restaurant and Hotel
robbery too, this one will need planning. Add other robbery missions too accordingly. Add Car
and Bike showroom robbery/theft too. Add these to TODO."

What exists today, to build on:
- interiors phase 0: places, doors, the interior manager, corner stores and diners with staff
  and customers, shop menus, the bag (`INTERIORS_SERVICES_PLAN.md`);
- that plan's decision D5 already says "Robbing a till is a crime (+2 stars), and the
  shopkeeper flees or fights". It is not built yet;
- wanted stars and the police; carjacking; 16 vehicle models, motorbikes and scooters among
  them;
- act 1 (`ACT1_MISSIONS.md`): 13 missions. Mission 10, Magnolia, already teaches disguises and
  safe cracking at the Hale Estate;
- `GANGSTAR_CONCEPT.md` has heists as "multi-stage planned jobs as late-game set pieces", and
  `MVP_DESIGN.md` left heists beyond one story mission out of the MVP. Sachin now wants
  robberies early in the main story, so update both docs when this starts.

To build:
- **Robbery in the main story first, then side quests**: a run of story missions teaches
  robbing. Each target type then opens as a side job that can be taken any time, with
  repeat runs varied (layouts, guards, loot, timing). Decide with Sachin where the run goes
  in act 1: added missions, or a rework of some of the existing 13.
- **Rob most houses and buildings**:
  - break in to homes and businesses across the city and the country;
  - things to steal by building type: cash, safes, jewellery, electronics, art, guns, drugs,
    documents, keys to cars in the garage;
  - a fence or pawn shop to sell the goods to;
  - alarms, owners at home by time of day, dogs, guards, cameras and witnesses, all tied to
    the wanted level.
  - This needs many more enterable interiors than the two room types built now. Plan room
    kits that generate many layouts, not one room per building.
- **Planned heists, for the bank, a restaurant and a hotel**:
  - a planning phase: scout the place, take photos or blueprints, pick an approach (quiet,
    loud, disguise), pick a crew with their skills and cut, and buy gear and a getaway car;
  - set-ups as smaller missions;
  - the job itself, then the escape;
  - pay depends on the choices made.
- **Car and bike showrooms**: steal from the floor, from the lot by night, or with a fake test
  drive. A showroom gets the models a district would have, with no real brands.
- **Other robberies to add** (proposed; Sachin to confirm or trim):
  - shop tills, gas stations and ATMs;
  - jewellery stores, pawn shops and an art gallery or museum;
  - a casino in Las Brasas;
  - an armoured truck;
  - a train, and cargo at the Ironwharf docks and the airport;
  - mansions in Magnolia Heights;
  - mugging people in the street, as a small crime with a reputation cost.
- Everything stays fictional per WORLD_BIBLE: no real banks, hotels, restaurant chains or car
  makers, and no ethnic group as the criminal faction.

## Wednesday, Oct 28, 2026: Solvera weather, seasons and a yearly calendar

## Wednesday, Oct 28, 2026: Solvera weather, seasons and a yearly calendar

Status: **not started**. Sachin: "We have to build a robust weather system, yesrly calendar
with different seasons, and day and night cycle too. We will have rain, snow, spring, summer,
winters, autumn etc all showijg clearly and changing the region accordingly. All of these have
to be implemented in the best way possible. Add these to TODO so that we take it up later on."

What exists today (`game/scripts/atmosphere.gd`, README "Day and night" and "Weather"), to build
on rather than replace:
- day and night at one game minute per real second (a 24-minute day), with the sun's shadows,
  lit windows, street lights, neon and headlights done in the city shader, not real lights;
- weather: clear, cloudy, rain and storms with lightning, wet ground and puddles that mirror
  the sky, rain and splashes round the camera, a Settings switch;
- the world is the 12 x 9 km state with four cities and 16 regions, including the Bellerive
  Hills. It is in `game/data/world_map.json`. Neither that file nor `WORLD_V3_PLAN.md` has
  climate data yet; the cities are themed on Miami and New Orleans (Bellerive), DC (Concordia),
  Detroit (Steelhaven) and Las Vegas (Las Brasas).

To build:
- **A yearly calendar**: date, day of week, months and the four seasons, saved with the game
  and shown on the phone and HUD. Set how long a game year runs in real time.
- **Seasons that show clearly**:
  - spring: blossom and fresh green;
  - summer: lush, harsh light, heat haze;
  - autumn: turning leaves and leaf litter;
  - winter: bare trees and grey light.
  - Each season changes the ground, foliage, sky, light, day length and sunrise and sunset
    times, the people's clothes, traffic and events.
- **Weather in more kinds**:
  - rain, storms, snow, sleet, fog, wind and heat;
  - snow that settles and melts on roads, roofs and the hills, with tyre tracks;
  - puddles that freeze to ice, and roads that are slippery while they stay icy;
  - weather that changes driving, walking, visibility and how NPCs behave (umbrellas, people
    staying indoors).
- **By region**: each region and city has its own climate and odds of each weather in each
  season, and the look changes as you cross from one region to another. A Florida-style
  Bellerive should rarely see snow, while Steelhaven, Concordia and the mountains should get
  real winters. Decide with Sachin how much snow Bellerive gets.
- **Day and night**: tie day length and the sun's path to the date, add a moon phase and
  stars, and do a pass on dawn and dusk.
- **"In the best way possible"**: before building, research how open-world games do this
  (GTA, Red Dead, Forza Horizon's seasons, Zelda, Stardew Valley's seasonal recolours). Then
  plan it within mobile budgets: shader-driven snow and foliage tints, no real lights, and
  the frame rate checked on a low-end phone. Write the decisions into a HANDOFF note and add
  tests and screenshot stops for each season and weather.

## Tuesday, Oct 27, 2026: Solvera feature wishlist (GTA 6-scale content)

Status: **not started**. Sachin shared a post listing what GTA 6 packs in and said: "I want all
these things, note them down in the TODO list and we will take them up later."

Everything below is our own and fictional (WORLD_BIBLE: no real brands, apps, people or
institutions). Before starting an item, check what Solvera already has (the phone, interiors,
cars and bikes, police and wanted levels, pedestrians, missions) and build on it.

- High-quality textures and realistic visuals across a large open world.
- A large number of game mechanics.
- Fully modelled planes, cars, helicopters, motorcycles and the like.
- Lots of customisation (player look, clothes, vehicles, weapons).
- Wide NPC variety, wildlife and pets.
- Detailed weapons.
- A large amount of dialogue.
- Mini-games (see the arcades entry below).
- Random events in the world.
- Radio stations.
- TV shows, and a fictional short-video app, for the in-game phone.
- A big map: GTA 6's is said to be twice the size of Los Santos. Ours is the 12 x 9 km world map (Bellerive, Concordia, Steelhaven, Las Brasas).
- Detailed interiors.
- A very large animation set for NPCs (the post cites over 600,000 for GTA 6), with voice lines to match.
- Keep the install small, as the post praises GTA 6 for: Solvera ships as a mobile APK, so size matters even more.

## Tuesday, Oct 27, 2026: Solvera arcades (game stores) with our own mini-games

Status: **not started** (Sachin: "keep this in TODO"; we build these ourselves later).

- Game stores in the city that the player can walk into and play mini-games.
- Every mini-game is our own, built for Solvera; no licensed or copied games.
- Ideas named so far:
  - a one-on-one fighting game in the style of Street Fighter or Tekken;
  - racing;
  - ping pong / table tennis;
  - "multiple sucu games": read as sudoku and similar puzzles. Confirm with Sachin.
- Fits the interiors system (`INTERIORS_SERVICES_PLAN.md`: places, doors, interior manager), as a new place type, "arcade".

## Tuesday, Oct 27, 2026, 1:00 PM IST: Civilization Tech game idea

Status: **not started**. Research is on hold until the weekly usage limit resets on Tuesday.

### The idea (as described)

A 2D game where the player gives advanced technologies to a species or society
at different points in its history, then watches what happens.

- **Human mode**: give tech to human societies at different periods.
- **Species mode**: give tech to other species, such as Neanderthals, reptiles,
  dinosaurs, and later the creatures considered the next smartest after humans.
  The player decides what the species does with the tech.
- **Consequences**: every action has consequences, from very rewarding to
  catastrophic. They could be shown as cards (but better than plain cards) or as
  full 2D animation.
- **Tech tree and crafting**: players unlock new technologies, and some can be
  combined into completely new tech. All of it follows real, current science.
- **Create or destroy**: tech can be used to build or destroy things, people and
  buildings.
- **Scenarios**: the game sets scenarios for using the tech. The results of each
  scenario add up to the ending.
- **Progression**: runs up to a starfaring civilization. There are several
  starfaring endings, depending on which technologies were used. A civilization
  can also destroy itself well before that, by misusing tech or failing to use it
  properly.
- **References**: Age of Empires + a basic SimCity + Stickman Wars + TABS +
  Detroit: Become Human (for choices and consequences), all in 2D.
- **AI in the engine (optional)**: use the Claude API to generate results or
  new tech combinations only if its cost is very low compared with expected
  revenue. Otherwise build it without AI in the game engine.
- **Content rule**: no religious figures, to avoid controversy or bans.
- **Launch scope**: humans from different periods first, then other species.

### Agenda for Tuesday

1. [ ] **Originality check**: search thoroughly across Steam, Epic, itch.io,
   console stores, iOS/Android, and web/Poki/CrazyGames for any existing game
   with this concept. Look for anything close: tech-gifting, uplift,
   alternate-history or "what if" civilization sims, and tech-combination crafting
   (for example Doodle God/Little Alchemy-style games).
2. [ ] **TABS check**: does TABS (Totally Accurate Battle Simulator) allow or
   cover this concept, through its mechanics, mods/workshop, or IP/EULA? How is
   our idea the same as TABS, and how is it different?
3. [ ] **Assessment**: rate how valid, impressive, expansive, feasible,
   addictive and replayable the idea is, and how ambitious it is, with critical
   feedback.
4. [ ] **Claude can do it all?**: can Claude handle research, the feasibility
   study, implementation, testing, fixing, QA, and many high-quality animated 2D
   models, with the user making decisions from the options Claude gives? Be
   honest about what needs outside tools, assets or people (for example art and
   animation pipelines, and store publishing).
5. [ ] **AI cost model**: Claude API cost per player/session against projected
   revenue, to decide between using AI and no AI.
6. [ ] **Next steps**: choose engine/tech stack, MVP scope (human mode, a few
   eras), and art style.
