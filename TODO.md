# TODO

## HIGH PRIORITY. Wednesday, Oct 28, 2026: fix what players disliked in GTA Chinatown Wars

Status: **open, high priority.** Sachin: "These are the negative feedback regarding Chinatowan Wars,
one of the games that is the inpirstion for this game of mine. We have to ensure all these issues are
addressed properly, either though confirmed positive fixes done by isers through Mods or devise ways
by looking into other games that manages to fix this issue, or devise our own ways. Keep this in TODO
on high priority please." Also: "The mobile version they released had some fixes, we need to check
those too to see if they wwre found to be reliable by the players."

Complaints as Sachin listed them (not yet verified), and where Solvera stands today:

| # | Complaint about Chinatown Wars | Solvera today | Still to do |
|---|---|---|---|
| 1 | Touch driving slippery and imprecise; DS touch minigames gimmicky | Three driving layouts with pedals (HANDOFF-driving-feel.md); steering by stick when the camera turns with the car (HANDOFF-heading-camera.md) | Check the mobile ports' control fixes and how players rated them; consider steering assists that reviewers credit; play-test on a phone |
| 2 | Top-down view put off players who wanted modern GTA's third-person view | Perspective top-down, a camera that turns with the car, settings for angle, zoom and turn | Full 3D stays parked (entry below); find what makes top-down feel modern rather than retro |
| 3 | Triad bosses felt one-note or cartoonish | Cast in WORLD_BIBLE.md (Victor Hale, Mama Odette, Lua Ferreira, Duke Calloway, Simone Kessler) | Give each boss a want, a fear, a line they won't cross and a turn of their own; review ACT1_MISSIONS.md for it |
| 4 | Huang Lee a detached, sarcastic "straight man" | Jules Moreau has a stake: a missing cousin (Teo), home ground, a past as a getaway driver (WORLD_BIBLE.md) | Write Jules's voice so the player cares; choices that show who Jules is |
| 5 | Predictable revenge plot, twists easy to spot in a small cast | Four acts, three endings set by faction choices (Crown, Ashes, Light); Dex's betrayal already planned | Plant twists fairly but not obviously; enough cast that the traitor isn't the only suspect |
| 6 | Characters with promise killed off early (Ling Shan) | none yet | Rule: a character the marketing or opening builds up gets an arc that pays off |
| 7 | Repetitive touch minigames for car theft and lock-picking | Instant carjacking; minigames only as optional activities (ACTIVITY_ROADMAP.md) | Keep every core action one tap; any minigame skippable, varied or short |
| 8 | Mandatory drug dealing felt tedious | Drug dealing excluded for tone (ACTIVITY_ROADMAP.md) | Make sure no money system becomes a forced grind (stock market, businesses, heists stay optional) |
| 9 | Sold less than Liberty City Stories and Vice City Stories | not a design flaw as such | Note from research why (platform, the top-down look in marketing) and what it means for Solvera |

### Research, 2026-10-28 (search excerpts only: Reddit, store reviews and page fetches were blocked)

Mobile ports. Sources:
- Rockstar's update notes: https://support.rockstargames.com/articles/3npV5Ux53CdrzLJ9JuFHwb
- TouchArcade, iOS 7 return: https://toucharcade.com/2013/12/20/grand-theft-auto-chinatown-wars-returns-to-the-app-store-with-ios-7-fix-and-retina-display-support
- TouchArcade, iOS 12 update: https://toucharcade.com/2019/05/13/grand-theft-auto-chinatown-wars-ios-update/

Which versions exist and what they changed:
- iPhone, Jan 2010. Driving aid that lines the car up with the road, on by default. Reviewers
  credited it (Bit-Tech, TouchArcade).
- iPad HD, Sept 2010.
- Android, Dec 2014: widescreen, gamepads.
- GTA+ subscription, Oct 2023, on both phones.
- No Netflix release found.
- The only controls overhaul: iOS v4.1, Dec 2014. Resizable, movable touch controls and MFi
  controllers. The touch minigames stayed as they were.
- An Analog Driving on/off toggle exists. When it was added is unknown.

Patch history:
- 2013: iOS 7 had broken starting a new game; the fix came that year.
- 2016: 64-bit.
- 2019: iOS 12 and iPhone X. Before it, TouchArcade called the game "nigh unplayable" on new iOS.
- 2023, 2024 and Android 4.4.243 (9 Mar 2026): generic "bug fixes" only.
- No iOS update found for 2025 or 2026.
- So "Rockstar heavily optimized the controls over a decade" is overstated: one overhaul in 2014,
  then compatibility fixes.

Player verdict:
- Touch driving stayed the weak point: Engadget (overcorrecting), Pocket Gamer ("never feels fully
  precise", iPhone ranked third of three), Wired on the iPad.
- Android averages about 4.0/5. Later pieces mention sensitivity and technical issues on modern
  Android.
- The usual advice is to play with a controller.
- Not verified whether recent updates are reliable on new phones.

Checks on Sachin's list:
- 1. Touch driving: confirmed. But critics liked the DS minigames (GameSpot: "work well").
- 3, 4. Weak cast and hero: confirmed. Kotaku: "largely forgettable cast". Game Informer: Huang's
  sarcasm hurt the story.
- 5. Predictable plot: not verified. The story was called the weak link, but no source called the
  twist predictable.
- 6. Ling Shan: confirmed. About two missions despite heavy promo art.
- 7. Repetitive minigames: weak. Most are mandatory once. The PSP swapped them for quick button
  prompts, which were clearer but "not nearly as novel".
- 8. Drug dealing: not mandatory after the intro, but it is the main income.
- 9. Commercial underperformance: confirmed. 89k US units in the first month vs a 400k forecast;
  Take-Two blamed piracy and weak handheld demand.

Camera complaints:
- Slow to catch up, causing steering errors (Push Square).
- Unwieldy in reverse (Tech-Gaming).
- Buildings block the view (Kotaku).
- No dizziness reports found.

Ideas from other games:
- Reckless Getaway: auto-accelerate plus two arrows, praised.
- GTA SA mobile: three steering schemes.
- Asphalt: tilt, on-screen and tap schemes.
- Gangstar Vegas: tilt default panned.
- Sleeping Dogs: villains tied to the hero's past; Wei Shen's inner conflict.
- The Precinct (2025): top-down still criticised for not seeing ahead at speed.

Design rules to adopt:
- Driving:
  - keep several schemes: stick, arrows, tilt, and add auto-accelerate;
  - keep the corner assist (vehicle.gd), and consider a gentle road-alignment assist like CTW's;
  - stick dead zone and response curve;
  - a resizable, movable touch layout;
  - gamepad from launch.
- Camera: catch up fast at speed. The turning camera's 0.25 s half-life is aimed at this. Hold
  the view in reverse (CTW's auto-reverse flip is the opposite; revisit after play-tests). Keep
  the see-through ghost for buildings in the way.
- Core actions one tap; any minigame short, varied by vehicle tier and skippable once mastered.
- Several viable income streams; no single grind.
- Cast:
  - every boss has a tie to Jules and a goal of their own;
  - Jules has a stake and an inner conflict, and sarcasm is flavour only;
  - several credible suspects before a reveal;
  - a character the game builds up gets an arc before they die.
- Launch: free first chapter; controller support; test on many phone models.
- Next: turn these rules into build tasks (the driving ones are code: auto-accelerate, alignment
  assist, resizable layout).

## Wednesday, Oct 28, 2026: full 3D camera (parked)

Status: **parked**. The perspective top-down camera is built instead (HANDOFF-perspective-camera.md).
Sachin: "Full 3D seems the best but we will have to overhaul all of our 3D models wihich is very time
intensive. So we can park it in TODO as one of the things to do when token costs come down very much
and good 3D Models are very quick to build and use."

- Estimate from the camera demo (HANDOFF-camera-demo.md): about 6-10 sessions: a third-person camera,
  distant low-detail buildings, phone performance, interior ceilings, street-level gaps in the
  models, and tests. The demo's `scripts/chase_camera.gd` is the starting point.
- Start only on Sachin's word, when both conditions above hold.

## Wednesday, Oct 28, 2026: a California city as expansion 2

Status: **not started** (a later expansion). Sachin asked which city was our California. The
answer was none: Bellerive is the Florida city, built on an LA-style street plan with
California-style hills. Of the options he chose: "Add a California city later as an expansion,
the way Porto Brisa is planned: LA sprawl, Hollywood-style hills, beaches and freeways. It fits
the expansion rules already in the plan and touches nothing that exists. Yeah this looks
better."

- Planned in `WORLD_V3_PLAN.md` section 2.6, with expansion 2 in the section 7 cost table
  (10-12 sessions, rough).
- It goes on the west edge past Hollow Mesa and Las Brasas, and follows the rules in section 9.
- Nothing that exists changes; Bellerive stays the Florida city.
- When it starts:
  - pick its name, districts, factions, characters and story strand with Sachin;
  - add its `expansions` entry and map arrow;
  - research LA from the top down, the way `reference/world/california_topdown.md` was done
    for Bellerive.
- **Revisit the Bellerive Hills then.** Sachin, Oct 28, picking "decide later": "Keep the hills
  now and add a TODO to revisit them when the California city is built, so the letters and the
  canyon look end up there." The Bellerive Hills are a California-style ridge (chaparral, the
  Hillside Letters, canyon roads) above a Florida-style city; Florida's real high point is about
  105 m.
  - When the California city is built, move the Hollywood-style look there: the letters, and the
    chaparral and canyon roads.
  - Re-dress Bellerive's hills as Florida's central ridge: sand-pine scrub, citrus groves, small
    lakes and a bell tower. Keep the height, the roads and the observatory. Roughly one session.

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
