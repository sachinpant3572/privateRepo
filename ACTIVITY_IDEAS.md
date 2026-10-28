# Solvera: "never bored" activity catalogue (2026-10-28)

Brief, from Sachin (word for word): "Research and think of things we can build and add into the
Gangstar game to enable players to do shitload of things within the game and never feel bored. From
listening to AI generated songs, to gymming, golf, boxing, table tennis, shopping, robbery, racings,
learning different marital arts, playing our completely new games inside the gaming cafes, eating
out in different restaurants, what else can we introduce?"

Research and ideas only; nothing here is built. Status: proposed, waiting on section 7.

**How this relates to `ACTIVITY_ROADMAP.md`**: the roadmap (same day) is the *parity* list, meaning
everything GTA V, San Andreas and MadOut2 have, with 27 costed packages. This file is the *beyond
parity* list: what other activity-heavy games do that those three don't, plus original ideas
that fit Solvera's world. Where an idea is already a roadmap package, it says "R-n" (roadmap
package n) and only adds what is new.

**Where each activity happens**: `ACTIVITY_ATLAS.md` lists every planned activity from both
files by region, place and terrain.

## 0. Method and labels

- Sources: WebSearch result summaries only. The roadmap found that WebFetch can't reach the wikis
  from this container. Labels follow the roadmap:
  - **V**: a primary source (an official site, docs, a model card, or Wikipedia for a game) states it;
  - **2**: guide or news sites only;
  - **U**: from memory, so treat it as a lead.
- Sources are numbered [A1]... in section 8.
- Costs are in the roadmap's unit: one **session** is one 3-5 h sitting of one agent, tests and
  screenshots included. They're rough and meant for ordering, not promises.
- The roadmap's constraints all still hold (section 2 there):
  - the city size stays as planned, and new activities go into existing places;
  - phone budget: 30 fps on the min-spec phone, and minigames run with the city frozen;
  - fictional brands only, cartoon violence;
  - no strip clubs, pimping or drug dealing;
  - gambling waits on Sachin's call.

## 1. What the best "lots to do" games teach

| Game | What it does | Lesson for Solvera | Label |
|---|---|---|---|
| Yakuza 0 | Two full business sims, Real Estate Royale and Cabaret Club Czar: buy property, collect payouts, fight off rival tycoons | A long **business loop** keeps players coming back between story beats | 2 [A1] |
| Like a Dragon: Infinite Wealth | Dondoko Island (rebuild an island resort), Crazy Delivery (bike food delivery with trick tips), Sujimon (collect beaten enemies and battle them) | A **build-up-a-place** sim and a **collect-the-city** meta loop can each carry 10+ hours | 2 [A2] |
| Sleeping Dogs | Karaoke, four martial-arts clubs; 12 jade statues found in the city unlock new moves at the dojo | **Collectibles that unlock abilities**, not just a checklist | 2 [A3] |
| Shenmue | A daily forklift job that opens with a race against co-workers; capsule-toy machines; darts and full arcade games | **Daily jobs with a fun twist**, and cheap collectible **capsule toys** | V [A4] |
| Watch Dogs 2 | Drone races, sailboat races, eKart, motocross; ride-hail missions in a phone app | Racing in **many vehicle types**; jobs launched **from the phone** | 2 [A5] |
| Saints Row 2 | Absurd scored diversions, such as Insurance Fraud (throw yourself at cars for payouts) and Septic Avenger | **Comedy chaos with a score** suits a cartoon tone and costs little | 2 [A6] |
| Red Dead Redemption 2 | Poker, blackjack, dominoes, Five Finger Fillet; fishing and hunting | **Table games in bars and camp** fill quiet moments (for Solvera: dominoes and card games played for points; no poker or blackjack until the gambling call) | 2 [A7] |
| Bully | Classes are minigames (chemistry, art, English, maths, music, geography...), and passing them unlocks perks | **Learning is play**: a class teaches a skill you then use | 2 [A8] |
| Marvel's Spider-Man (2018) | Lab puzzles (circuits, spectrograph) and 55 backpack collectibles with story | **Quiet puzzles** pace action; **collectibles tell lore** | 2 [A9] |

The main takeaway: these games don't hand-build 80 separate activities. They build a few
**engines** and re-skin each one many times. Section 3 does the same for Solvera.

## 2. Sachin's list, made concrete

Each line gives the Solvera twist and what ties it to the rest of the game.

### 2.1 AI-generated songs: listening, making and performing

- **Radio by district** (R-6 builds the base: 3 stations). Grow it to about 8 fictional stations,
  each with an AI-generated catalogue and a DJ: Lantern Quarter brass and jazz, Wards bounce and hip-hop,
  bayou stomp (accordion and fiddle), Gilt synth-pop, a talk station that satirises Aurum, and
  Latin beach for Brisa (v3).
- **Adaptive score**: Godot's `AudioStreamInteractive` switches song sections by rules (at once,
  at the end, or on the next beat), and `AudioStreamSynchronized` plays layered stems in sync. Use
  them to lift the music in a chase or a fight and drop it when you hide (V [A10]).
- **Music app on the phone**: songs you have heard are saved to a library; make playlists; play
  your own playlist in any car.
- **Record shop** (Lantern Quarter): buy vinyl to unlock songs; rare pressings are collectibles.
- **"The Lost Tapes"**: about 20 cassettes by a jazz legend who vanished in the Great Storm, hidden
  around the city. Each one unlocks a song and a piece of lore, and finding them all finishes a story
  thread (fits WORLD_BIBLE's legends).
- **Karaoke bar**: a rhythm-and-lyrics game on the same songs, scored on timing. Optional: real
  singing scored on pitch. Godot can read the microphone on Android and iOS (`audio/driver/enable_input`;
  V [A11]). The Android permission flow is **unverified**, so make it opt-in. Bring friends (R-24) to
  sing duets.
- **Studio** (a "make a song" minigame): pick a genre, then arrange 4-8 pre-generated stems on a
  timeline (drums, bass, keys, voice). Your track goes on the radio, climbs an in-game chart, and earns
  royalties. Stems are AI-made ahead of time, so nothing is generated on the phone.
- **Busking and the jazz jam**: learn trumpet, sax, drums or guitar (a rhythm game). Play for tips in
  Lantern Square, then sit in at Celeste's Blue Lantern.
- **Licensing** (this is the open question in the roadmap, section 6 point 3):
  - Suno: paid plans give commercial use; the free plan is non-commercial. Suno's own blog states the
    paid-plan right (V [A12], from a search summary, not a read of the terms page). Guides say new terms
    took effect on 2026-09-03 (2), and they **disagree** on ownership: some say that since its Warner
    deal Suno keeps authorship and grants a perpetual commercial licence, others that paid tiers still
    get the songs assigned (2). Read the live terms page before generating the catalogue.
  - ACE-Step: an open model released under **Apache 2.0** (V [A13], model card), so it can run
    self-hosted with no per-song fee. Its training-data provenance was **not checked**.

### 2.2 Gym and body

R-17 has the gyms and stats. New here:
- reps as a rhythm minigame (bench, bag, treadmill) instead of tapping;
- a trainer NPC with weekly plans, and a gym rival who sets your target;
- an outdoor calisthenics spot in Liberty Green;
- a smoothie bar where what you drink tunes the session;
- your build shows on Jules (SA-style fat and muscle);
- strength opens doors in the world: push a dumpster to reach a roof, carry a crate.

### 2.3 Golf

- **Phase 1 (Bellerive)**:
  - a storm-themed **mini-golf** on a Lantern Quarter rooftop: 9 holes with flood gates and a
    streetcar that blocks putts;
  - a **driving range** on the levee.
- **Later**: 9 real holes at Ember Heights (Las Brasas, v3). Golf suits a top-down camera.
- **One swing-meter engine** (section 3, E4): swipe back for power, curve the swipe to fade or draw.
  The same engine drives pool, darts, bowling and basketball free throws.

### 2.4 Boxing

The Pit ladder is R-17. New here:
- between rounds, a 5-second **corner** choice (cut man, game plan, rest) shapes the next round;
- **fight nights** on the calendar with a crowd and a purse (prize money, not betting, until the
  gambling call);
- a title belt that NPC challengers come to the street to take.

### 2.5 Table tennis

Spin Rally is arcade game C in the roadmap, and also drives real tables. New here: doubles with a
friend; a park "king of the table" queue in Liberty Green; badminton and tennis on the same
racket engine (E4).

### 2.6 Shopping

R-8 covers clothes and barbers, and IS-1 covers food stores. New here:
- a **thrift shop** whose stock rerolls every day: rare finds and full outfit sets;
- **sneaker drops**: limited stock on a set day; queue at dawn or outbid resellers;
- a **pawn shop** that buys loot and sells odd things, including keys and maps that start side jobs;
- a **weekend flea market** in Lantern Square;
- **furniture** for the safehouse;
- phone shopping delivered to your door by a courier NPC you can see arrive;
- **phone vending and capsule machines** (Shenmue): 1-2 coin pulls for figures of Solvera characters,
  shown on your shelf at home.

### 2.7 Robbery

Hold-ups, burglary and heists are R-23. New, all in cartoon tone:
- **pickpocketing** as a timing minigame;
- an **armoured van** ambush that shows up as a random event;
- a **gallery swap** where you trade a painting for your forgery, painted earlier in the art
  minigame (E1);
- a **building-site job** on the Solvera Line works (steal a payroll or a prototype; trains stay in the WORLD_V3 phases);
- a **storm-night heist**, where the hurricane covers the noise (ties to the weather system);
- **getaway driver for hire**: NPC crews call Jules, who was Porto Brisa's best getaway driver
  (WORLD_BIBLE). You wait outside, then shake the police. R-5 already has a one-off getaway-driver
  event; this makes it a repeatable job with a rank and harder crews. Cheap, because it reuses
  driving and wanted.

### 2.8 Racing

R-14 covers street races, bike races and stunts. New here, all on one checkpoint engine (E3):
- airboat races in Blackwater Bayou;
- drone races through Gilt's towers (Watch Dogs 2);
- a soapbox derby down the levee;
- go-karts at an Ironwharf track;
- a demolition derby;
- drift and night car-meet contests where NPCs vote on your tuned car;
- on-foot rooftop parkour races in the Lantern Quarter;
- a river regatta.

### 2.9 Martial arts

R-17 covers learned styles, as SA's gyms do. New here, the Sleeping Dogs lesson:
- each style has a **master hidden somewhere in the city**, found by a clue chain;
- **lost fight manuals** found while exploring each unlock one move.
- Styles to offer (real art names are generic, not brands). Already planned in IS-4 and the
  roadmap: boxing (The Pit), kickboxing, karate (Lantern Quarter dojo) and kung fu (Wards school).
  **New here, by region** (`ACTIVITY_ATLAS.md` D2; each is built with its place's city pack, so
  a new art means a trip): Muay Thai (Las Brasas), judo and krav maga (Concordia), wrestling
  (Steelhaven), capoeira and Brazilian jiu-jitsu (Porto Brisa), kalaripayattu (Cinder County),
  silat (the Keys) and a stunt-fighting school (the California city). N10 builds the hidden
  masters and the manuals for the four Bellerive styles, and the hooks the packs reuse.
- Each style changes the combo, gives one special move, and adds a defence trait (parry,
  throw, dodge).

### 2.10 Gaming cafés: more of our own games

The roadmap has the framework (R-11) and five games: Floodline Brawlers, Bayou Rush, Spin Rally,
Green Wave and Eye of the Storm. More original pitches for the same host:

| Game | Pitch | Cost |
|---|---|---|
| F. **Krewe Cards** | A collectible card duel, also played with NPCs in bars and parks. The name is a deliberate tie: the Marrow Krewe's old-timers run the bayou card circuit, and Mama Odette is its unbeaten champion. Cards show Solvera's people and places; you win them from NPC duels, capsule machines and quests. Never sold for real money. This is the strongest long-term hook (U: the "card game inside an RPG" pattern) | 2 |
| G. **Levee Line** | Tower defence: build levees and pumps against rising storm surges; one map per Bellerive district | 1 |
| H. **Night Shift** | DJ rhythm game: mix two decks of the radio catalogue; scores feed the club business (E6) | 1 |
| I. **Gator Gulp** | A snake-like game in a bayou maze; a daily seed with a leaderboard | 0.5 |
| J. **Tower of Aurum** | A physics stacking game. Each floor is a satire panel; it collapses when you get greedy | 0.5 |
| K. **Brass Pinball** | A Mardi-Gras-style pinball table with multiball parades | 1 |
| L. **Café Quiz** | A trivia night about Solvera lore and general knowledge, against NPC teams each week | 0.5 |

### 2.11 Eating out

IS-1 builds the restaurants. New here:
- **cuisines give different buffs**: bayou gumbo for stamina, a coffee house for focus (brief
  slow-mo aim), steakhouse for health, street tacos for a cheap heal;
- a **food passport**: stamp every dish, with a reward for each full page;
- a **food critic** side line: review places, and your reviews move their prices and crowds;
- **eating contests** at fairs;
- a **cooking minigame** (E1) at home, as a line-cook job, or in your own **food truck** (E6);
- **regular-customer perks**: the cook learns your order, and there are discounts and staff gossip that
  hints at missions.

## 3. The engines: build each once, re-skin it many times

| # | Engine | What it powers | Builds on | Cost |
|---|---|---|---|---|
| E1 | **Minigame host** (the R-11 framework) | Arcade games A-L, cards, cooking, tattoo and art painting, lock-picking, hacking, puzzles, the studio | R-11 | (in R-11) |
| E2 | **Rhythm engine**: a beat map plus input lanes | Karaoke, dance, DJ, busking, jazz jam, gym reps, second-line parade march | R-6 audio | 1.5 |
| E3 | **Checkpoint race engine**, with ghost replay | Every race in 2.8, delivery runs, time trials, parkour | R-14 | (in R-14) +0.5 for karts; about +0.5 per further vehicle type |
| E4 | **Swing and shot engine**: power, aim and curve | Golf, mini-golf, pool, darts, bowling, free throws, table tennis, badminton, tennis | none | 1.5 |
| E5 | **Shift job framework**: clock in, a task loop, a rank that pays more | Delivery, crane stacking, barista, line cook, streetcar driver, tour guide, lifeguard, photographer | R-16 | 1 |
| E6 | **Business sim**: buy, staff, stock, set prices, income tick, events and raids | Club nights, food truck, your own gaming café, car wash, record label, real estate | R-22 | 2 |
| E7 | **Collection log**: one book with tabs | Fish, food, vinyl, Lost Tapes, cards, capsule toys, photos, fight manuals; a "% complete" page | R-7 | 0.5 |
| E8 | **Hangouts**: invite, activity, chat, then a perk | Friends, dates, a pet, the band, rivals who remember you | R-24 | (in R-24) |
| E9 | **City calendar**: weekly and seasonal events | Fight nights, festivals, flea market, car meets, hurricane season, elections | R-25 | (in R-25) |

New engine cost, beyond what the roadmap already counts: about **7 sessions** (E2 1.5, E4 1.5,
E5 1, E6 2, E7 0.5, E3 +0.5 for karts). Each further race vehicle in 2.8 (drone, soapbox, derby
car) adds about 0.5; the airboat, regatta and jet ski also need R-26 (drivable boats). With the
engines in place, most items below cost **0.3-1 session each**, because they are content on an
engine rather than new systems.

## 4. More to add: the "what else" list

Grouped by mood. **Engine** gives what it rides on. **Where** is an existing Bellerive place,
because the city does not grow.

### 4.1 Calm hobbies (between missions)

| Activity | Twist | Engine | Where |
|---|---|---|---|
| **Fishing** | River, bayou, pier and boat. About 40 species with a log; night species; a monthly tournament; legendary catfish | E4 cast plus a reel minigame, E7 | Morrow River, Blackwater Bayou |
| **Photography** | Wildlife, street and landmark photo jobs; a newspaper buys your shots; a weekly contest in the phone feed | phone camera, E7 | everywhere |
| **Diving for storm wrecks** | Dive in the flooded Wards for salvage, lore and the Lost Tapes. Keep clear of the Drowned Streetcar legend (WORLD_BIBLE: it leads to Teo's hideout); the story sets when it can be dived | swim state, E7 | Floodline Wards |
| **Metal detecting** | Beach and levee treasure; buried storm loot; treasure maps from the pawn shop | E7 | levee, bayou banks |
| **Skate park** | Skateboard and inline-skate trick scores; S-K-A-T-E against NPCs | E3 + trick score | Liberty Green |
| **Park table games** | Chess, dominoes and checkers with old-timers; a ladder; they tell stories | E1 | Moreau Square |
| **Newspaper puzzles** | Daily crossword, sudoku and word search in the phone paper (sudoku is likely the TODO's "sucu"; roadmap 4.2 already costs it at 0.3 session) | E1 | phone |
| **Gardening** | Rooftop garden at the safehouse; grow herbs and chillies for the cooking game | timers, E1 | safehouse |
| **Pet** | Adopt a dog or cat from a shelter. The dog follows you, sniffs out hidden packages, and growls at ambushes | E8, animals (R-3) | shelter in the Wards |
| **Kite flying, birdwatching** | Calm, low-cost collections | E7 | levee, bayou |

### 4.2 Fun venues (indoor, one interior each)

| Venue | Inside | Engine |
|---|---|---|
| **Bowling alley** | Lanes, a league night, a rival team | E4 |
| **Pool hall and darts bar** | R-21 already has them; add trick-shot challenges | E4 |
| **Escape rooms** | 3 themed rooms built from existing room kits, solved against the clock | E1 + interiors |
| **Laser tag and paintball** | Paintball in Ironwharf's container maze; laser tag in an empty shopfront; team AI | combat, R-19 |
| **Trampoline park, climbing wall** | Score runs and a parkour training ground | E3 |
| **Claw machines, capsule toys** | In every arcade and corner store | E7 |
| **Cinema** | R-10 already has it; add a "make a film" replay editor whose shorts play on screen (U: GTA V's Rockstar Editor) | replay |
| **Batting cage** | A Yakuza staple (2 [A1]); one minigame | E4 |

### 4.3 Legit careers with ranks (money without crime)

On E5. Each career has 5 ranks, an outfit, and a perk at the top rank.
- **Line cook** and **barista**: rush-hour order games. Perk: cheaper food.
- **Crane operator at Ironwharf**: container-stacking puzzle (Shenmue's forklift lesson). Perk:
  crane access in heists.
- **Streetcar driver**: keep to the timetable, pick up at stops. Perk: free rides. Needs running
  streetcars, which come with the transit milestone (INTERIORS_SERVICES_PLAN section 5), not this plan.
- **Tour guide**: drive tourists to landmarks and answer their trivia. Perk: hidden spots on the map.
- **Bike courier** (Crazy Delivery lesson): tricks earn tips. Perk: a faster bike.
- **News photographer**: chase crime scenes for shots. Perk: police scanner on the phone.
- **Tattoo artist**: a drawing minigame on NPC skin. Perk: free tattoos.
- **Mechanic**: diagnose and fix (a puzzle). Perk: cheaper tuning.
- **Storm chaser**: in season, drive into storm cells and place sensors. Ties to lore and to arcade
  game E.
- **Private investigator**: a clue board with photos, phone records and stake-outs. Small cases
  that grow into a story.

### 4.4 Businesses (Yakuza's lesson)

On E6. Each business runs while you play elsewhere, and calls you when something goes wrong.
- **Blue Lantern club nights**: book acts (your Studio tracks too), set the door price, and stop
  fights. Night Shift (game H) is the DJ booth.
- **Food truck**: choose the menu and the route. Crowds follow the calendar (E9).
- **Your own gaming café**: install our arcade games, set prices, and run tournaments. The games
  inside the game make money inside the game.
- **Record label**: sign buskers you meet, release tracks, and climb the chart.
- **Buy back the Wards** (the flagship business, R-22 and the wealth system): buy storm-damaged
  houses, renovate them in a room editor, and either rent them to Wards families (High Water
  reputation) or flip them (money, but Aurum-style). Real Estate Royale's loop fits Solvera's story,
  because Aurum bought flooded land cheap. Uses the land values from wealth phase 1.

### 4.5 Comedy chaos (scored sandbox, cartoon tone)

- **Fender-bender fraud**: ragdoll into traffic for "compensation", a Saints Row-style score run.
  Needs the ragdoll and pain to stay cartoonish.
- **RC cars, RC planes and a camera drone** that you drive around the city; races and scouting for heists.
- **Wrecking ball** at Solvera Line building sites: knock down Aurum billboards for points.
- **Mascot suit jobs**: hand out flyers dressed as a giant crawfish, and get chased by kids and dogs.
- **Parade float hijack**: steer a Mardi-Gras-style float through the crowd during the festival
  (R-25 calendar).

### 4.6 Learning (Bully's lesson): night classes at a community college

Each class is a short minigame course that unlocks a skill:
- **driving school** (cone tests; a licence lowers police interest);
- **pilot school**, later (WORLD_V3 aircraft);
- **cooking class** (recipes);
- **mechanics** (self-repair);
- **coding** (phone hacking: traffic lights, cameras, ATMs, all cartoon);
- **languages**: French and Portuguese phrases unlock bayou and Porto Brisa dialogue and discounts.
  This is unusual for the genre, and fits Solvera's mixed cultures.
- **First aid**: revive downed friends and NPCs, which feeds the paramedic job (R-9).

### 4.7 Living city events (on E9)

- Weekly:
  - fight night;
  - flea market;
  - Friday night car meet;
  - Sunday jazz in Lantern Square;
  - a quiz night.
- Seasonal:
  - a Mardi-Gras-style parade with a **second-line brass march** (rhythm, E2; secular, from
    New Orleans' street tradition);
  - a crawfish festival with an eating contest;
  - a jazz festival;
  - **hurricane season**: evacuation orders, looters, boat rescues and a blackout night. A one-week
    systemic event that brings back the Great Storm.
- Civic: a mayoral **election** in act 2 or 3. Back a candidate with jobs; the winner changes
  prices, police strength or Aurum's power. This is satire, and it gives the player a choice that
  matters.

### 4.8 Creating and expressing (high replay, low content cost)

- **Graffiti editor**: draw your own tag; it sprays on walls and spreads with your crew's turf.
- **Car livery editor and outfit designer**: decals and colours; the designs show up on NPCs.
- **Safehouse decorating**: furniture, trophies, capsule-toy shelves, Lost Tapes on a cassette rack.
- **Studio tracks and film shorts** (above), shown in the world: the radio plays them and the cinema
  screens them.

### 4.9 The meta layer that ties everything together

Without this, 80 activities feel like a list. With it, every activity counts toward something.
- **City Fame**: one score that every activity adds to (a race win, a karaoke hit, a full food-passport
  page, a business milestone). Fame tiers unlock outfits, NPC reactions, VIP doors and better
  job offers.
- **Challenge board** on the phone: 3 daily and 5 weekly challenges drawn from what you have
  unlocked ("catch a night species", "win a duel of Krewe Cards in Moreau Square"). R-27 only has
  leaderboards; this works offline.
- **Achievements and a 100% sheet**, the collection log's front page (E7).
- **"Something new" nudges**: the phone feed and NPC chatter point to an activity you haven't tried
  yet nearby (the Yakuza substory pattern, U).
- Cost: about 1 session on top of E7 and the phone.

### 4.10 Water fun in phase 1

- **Jet ski** and **river swimming** in the Morrow, with buoy courses on E3. Needs R-26 (drivable
  boats).
- **Riverboat cruise** at sunset with a live band. A calm ride; the band's set uses the radio
  catalogue.
- **Pier diving** off the levee piers, scored on spin and splash.

### 4.11 GTA V, GTA Online and GTA VI: what they add (pass of 2026-10-28)

Sachin asked to check the GTA V and GTA VI activity lists for more ideas. The roadmap's section 1
already covers GTA V's story mode (91 items; golf, tennis, darts, yoga, triathlon, flight school,
hunting, the stock market and so on; GTA V's hobbies list, 2 [A14]). This pass looks at the two places it didn't: **GTA Online**
(GTA V's online mode, updated until 2025 and beyond) and **GTA VI**. It lists only what is not
already in the roadmap or in sections 2-4 above.

**GTA VI status**: due on **19 November 2026** (2 [A21]), so it is not out yet. Everything below
comes from trailers, the 27 August 2026 "Extended Look" and Rockstar's place descriptions, as
reported by news sites (2 [A20][A22]). Game Informer itself says it doesn't know which of these
are playable. Re-check after launch. GTA VI is set in Leonida, a Florida parody; Bellerive is
also the state's Florida in world v3 (Keys, swamp park, airboats, Brisa Beach). Solvera keeps its
own names and story, and should avoid copying any Leonida set piece.

**Already in our plans, so not repeated here**: from GTA VI (2 [A20]), the gym and bench press
(2.2), fishing (4.1), basketball, pool, mini-golf (N2), jet skis (4.10), scuba diving (4.1 storm
wrecks), shooting range, clubbing (4.4), kickboxing and martial arts (2.9), street and off-road
racing (2.8), skydiving (roadmap 1.1), wildlife photography (roadmap 1.1; hunting is out), and short social clips of the
player's chaos (R-13's short-video app). From GTA Online, the nightclub (4.4 Blue Lantern), the
arcade (R-11), the tow truck (R-16) and heists (R-23).

| Idea | From (label, source) | Solvera version | Engine / needs |
|---|---|---|---|
| **Bail bonds: bounty hunter** | V5: four bail jumpers for Maude; alive pays $10,000, dead pays $5,000 (2 [A15]). Online: the Bail Office (2 [A17]) | A bondsman in the Lantern Quarter hands you skips. Clues come in the PI clue board style (4.3); the skip runs, hides or bribes. Bring them in **alive for full pay**: tackle, cuff, or trick them into your car. Cartoon tone, and a non-lethal reason to chase | R-5, R-20; PI board (4.3) |
| **Daily wanted-car list** | Online: Exotic Exports, a daily list of 10 cars (U); V5's Simeon export requests (U) | A fence at Ironwharf posts 10 wanted cars each in-game day; find, steal and deliver them undamaged. Feeds the car collection and teaches the map | E7, existing cars |
| **Roaming black-market van** | Online: the Gun Van moves to one of 30 spots each day at 06:00 UTC (2 [A16]) | A van at one of about 20 spots per in-game day, hinted by a phone rumour. It sells rare tuning parts, outfits and a few weapons (after R-19), with a daily deal | `shop_menu.gd`, E9 |
| **Money fronts and laundering** | Online "Money Fronts" (June 2025): a car wash, a smoke shop and helicopter tours; laundering raises Heat, legal jobs lower it, the car-wash safe caps at $100,000 (2 [A18]) | Crime pays **dirty cash**. Big purchases (property, shares, top cars) need **clean cash**, laundered through your fronts (food truck, car wash, your gaming café). Cleaning too fast raises heat; honest shifts at the front lower it. A strong money sink and a reason to run legit businesses. See decision 8 in section 7 | E6, R-22 |
| **Payphone jobs** | Online: Payphone Hits (U) | Payphones across Bellerive ring now and then. The voice offers a strange job: tail someone, deliver a parcel, solve a riddle, or (later) a hit. A cheap way to deliver random jobs and lore | R-5 |
| **Pop-up city challenges** | Online freemode events such as King of the Castle and checkpoint hunts (U) | Five-minute challenges announced on the phone: "pop 15 parade balloons in the Quarter", "hold the rooftop", "longest wheelie along the levee road". Score against NPC rivals or your best | E9, R-5 |
| **Daily buried stash** | Online: daily shipwreck and hidden-cache spots (U) | One Marrow Krewe stash per day, found from a map scrap. Pairs with metal detecting (4.1) | E7 |
| **Race creator** | Online: the Content Creator (U) | Place checkpoints on the city map from the phone; race your own ghost; share a code through R-27. High replay at almost no content cost | E3, R-27 for sharing |
| **Transform races** | Online: the vehicle changes at set checkpoints, e.g. car to plane or parachute (2 [A19]) | Bellerive suits it: car, then airboat through the bayou, then bike up the levee | E3, R-26 |
| **Car meet with rep levels and a test track** | Online LS Car Meet: membership, rep from races and daily visits, a test track for drifting (2 [A19]) | Grows 4.7's Friday car meet: an Ironwharf warehouse with membership, rep tiers that unlock parts and paints, and a test track | E3, tuning (IS-3) |
| **Arena car-combat show** | Online Arena War: car-combat modes in an arena with a goofy host (2 [A19]) | Turns 2.8's demolition derby into a TV game show: traps, a loud host, sponsor fees. Cartoon tone only | E3, vehicle damage (have) |
| **Arm wrestling** | Online clubhouse arm wrestling (U) | A tap-and-hold duel in bars and the gym. Tiny, and good for NPC rivalries | E1 |
| **Community service** | GTA VI: litter picking seen in trailer 2 (2 [A20]) | After Busted, choose a fee **or** a cleanup shift in the Floodline Wards. Clearing storm debris raises High Water reputation and ties to the Wards rebuild (4.4) | E5 |
| **TV at the safehouse** | GTA VI: watching TV (2 [A20]) | Channels with the city news reacting to your deeds (R-13), cartoons, a cooking show, and your own film shorts (4.2). Reuses content that already exists | R-13 |
| **Kayaking** | GTA VI: kayaking at Mount Kalaga (2 [A20][A22]) | Paddle trails through the bayou, a calm photo tour, and a slalom course on the Morrow | E3, R-26 |
| **Base jumping** | GTA VI Extended Look (2 [A20]) | Jump from the Aurum Tower and Solvera Line bridges. An illegal jump from Aurum property earns a wanted star. The jumps are R-31's; N25 adds only the illegal version | parachute (roadmap 1.1) |
| **Backyard wrestling league** | GTA VI Extended Look (2 [A20]) | A Floodline Wards league with folding chairs, paddling pools and a ring announcer; cartoon slams on the R-17 fight system | R-17 |
| **Bayou wildlife rescue** | GTA VI: zoos (2 [A20]); the city size is fixed, so no zoo | Not a zoo but a rescue centre in Blackwater Bayou: rescue injured animals during events, feed and release them, and photograph them | R-3 animals, E8 |
| **Snorkelling** | GTA VI: Leonida Keys (2 [A20][A22]) | Later, for the Keys and Isla Serena in world v3. Bellerive's river is too murky | v3 |

**Keep out**, from the same lists:
- Online's drug labs and street dealers (roadmap section 2);
- strip clubs (GTA VI coverage mentions them);
- rampages (mass violence, not our tone);
- GTA V's Epsilon cult parody: WORLD_BIBLE keeps religious institutions out, and a cult reads as one;
- the casino's Lucky Wheel and podium car: they wait on the gambling decision.

### 4.12 Stock market

The full design, its anti-exploit rules and a simulation that proves them are in
`STOCK_MARKET_DESIGN.md` and `tools/stock_market_sim.py`. In short:
- the phone app opens in Bellerive in phase 1 and becomes the Concordia Exchange in phase 5;
- prices move on city events (calendar, random events, faction wars, storms, story beats),
  never on real-world news;
- caps on position size and daily buys, a one-day hold, prices that drift back, no shorts or
  leverage, a regulator that opens a case on suspicious gains, and diminishing returns on the
  player's own sabotage;
- nothing rerolls on load, and the market has its own clock that never reads the device clock;
- the seeded simulation (150 runs of 60 game days, 8 checks, all pass) shows that a passive
  holder earns about 8% of a day's side-job pay per game day, a skilled trader about 13%, and
  every tested in-game manipulation loop (sabotage, insider buys, pump and dump, scalping, time
  skips) earns no more than skilled trading; copying the save file outside the game does beat
  skilled trading per real hour (0.76 W against 0.33) but stays well under side jobs (2.5 W),
  which is the honest limit on an open platform;
- cost: about 2.5 sessions for a lite version, about 6 for the full one.

### 4.13 GTA III, the Liberty City games, Watch Dogs and Sleeping Dogs: what they add (pass of 2026-10-28)

Sachin asked to check GTA III, Watch Dogs, Sleeping Dogs and "GTA Liberty City" too. Two games
are set in Liberty City besides GTA III: **Liberty City Stories** (LCS) and **GTA IV**, with its
episodes The Lost and Damned (TLAD) and The Ballad of Gay Tony (TBoGT). For Watch Dogs, this pass
covers Watch Dogs 1 and Legion; Watch Dogs 2 is already in section 1. Same rule as 4.11: only what
is not already planned. All facts come from guide and wiki search summaries (2 [A23]-[A28]).

**Already in our plans, so not repeated here**:
- GTA III and LCS (2 [A23][A24]): the taxi, paramedic, firefighter and vigilante jobs (R-9,
  R-16); 100 hidden packages (R-7); RC Toyz (4.5); payphone jobs (4.11); the off-road and
  car-park checkpoint challenges (E3, R-14); the export lists (4.11, daily wanted-car list).
- GTA IV and its episodes (2 [A25]): friends who call for bowling, pool, darts, food, a show or a
  boat ride (R-24, 4.2); club management (4.4); golf (2.3); arm wrestling (4.11).
- Watch Dogs (2 [A26][A27]): races in many vehicle types (2.8); deliveries (R-16); darts (R-21);
  chess (4.1); the investigator cases (4.3); Watch Dogs 1's "Digital Trips" surreal games
  (our own café games, 2.10).
- Sleeping Dogs (2 [A28]): street races (2.8), fight clubs (2.4 fight nights), karaoke (2.1),
  jade statues that unlock moves (2.9), lockboxes (hidden packages), and people asking for
  favours (R-5 random events).

| Idea | From (label, source) | Solvera version | Engine / needs |
|---|---|---|---|
| **Car salesman** | LCS "Car Salesman": sell 24 cars over 6 levels by test drives that match each buyer's taste; then the lot pays a daily profit (2 [A24]) | A used-car lot in Ironwharf. Each buyer wants something: "smooth" (no bumps), "show me speed", "make me scream" (jumps). Drive well and they buy. Finish the 6 levels and the lot becomes a business on E6 | E5, then E6 |
| **Dumpster dash** | LCS: three hidden Trashmaster missions, empty the dumpsters against the clock (2 [A24]) | A sanitation route in the Floodline Wards: a garbage truck, dumpsters on a timer, and storm-debris bonus piles. A cheap shift job | E5 |
| **Lowrider bounce-off** | LCS "Low Rider Rumble" (2 [A24]); SA's bounce challenge is in roadmap 1.1, but in no package yet | A hydraulics rhythm contest at the car meet: hit the bounces on the beat of an AI track. The same beats as E2 | E2, car meet (4.11) |
| **Studio gauntlet show** | LCS "Slash TV": survive waves in a TV studio (2 [A24]). Kept, but **non-lethal** | A TV obstacle show in the Gilt District: foam bats, paint guns, a spinning floor, a shouting host. A foot version of 4.11's arena car show; knocks people down, never kills | combat, R-19 |
| **Crimes detected** | Watch Dogs 1: the phone flags a likely victim; you wait, see who strikes, then stop the crime (2 [A26]) | A "Street Cam" phone app from a hacker friend. It marks someone at risk; you watch from a distance, pick the right suspect from the crowd, then chase or tackle them. Bring them down **alive** for a bonus | R-5, R-9, the coding class (4.6) |
| **Spot-the-suspect camera busts** | Sleeping Dogs: hack a camera, watch the footage at home, pick out the dealer, then make the bust (2 [A28]) | Same loop with **contraband**, not drugs: fake designer goods, stolen phones, illegal fireworks. Spot the courier on the camera feed, then raid the spot | E1 camera puzzle, R-20 |
| **Convoy takedowns** | Watch Dogs 1 "Criminal Convoys": stop a convoy, take down the target (2 [A26]) | Aurum or Halberd armoured convoys on the Gilt District roads, or Marrow Krewe smuggling convoys from Ironwharf. Plan an ambush point, then box in the target car | R-19, R-20 |
| **Hideout takedowns** | Watch Dogs 1 "Gang Hideouts": take out the leader **non-lethally** (2 [A26]) | Faction hideouts (warehouses, a bayou camp, a rooftop) where you knock out the boss without raising the alarm. Each cleared hideout weakens that faction's turf (R-22) | stealth stat (R-17), R-22 |
| **Camera-mast puzzles** | Watch Dogs 1 ctOS towers: a short puzzle that reveals the area (2 [A26]) | One relay mast per district. Climb it and solve a short node-turning puzzle (E1) to show that district's activities on the map. Teaches the city | E1, map |
| **AR phone games** | Watch Dogs 1 AR games such as Cash Run, played on the real streets (2 [A26]) | Phone games played on Bellerive's real streets: "Coin Rush" (run through coins between two points), "Gator Tag" (shoot cartoon gators that pop out of the drains). Points go to the challenge board (4.9) | E3, phone |
| **Hit-and-run chases** | Sleeping Dogs: a police friend sends you after hit-and-run drivers (2 [A28]) | A detective friend calls in a driver who fled a crash. Find them from witness hints, then ram them to a stop. Ties to the bail bonds work (4.11) | E3, R-5, R-24 |
| **Keepy-uppy** | Watch Dogs Legion "Kick-Ups" (2 [A27]) | A tap-on-time football juggle in parks and on the beach. Tiny; leads to football later (Porto Brisa) | E2 |
| **Air hockey** | GTA IV TBoGT and TLAD (2 [A25]) | Tables in bars, the arcade and your own gaming café. One finger, two minutes, good with friends | E1 |
| **Comedy club and cabaret** | GTA IV friend shows: a comedy club and a cabaret (2 [A25]) | A Lantern Quarter comedy club and a cabaret night with **fictional acts** whose jokes react to your deeds and the city news. Take a friend; it raises friendship (R-24) | R-10 venue, R-13 news |
| **Recruit from the street** | Watch Dogs Legion: recruit anyone in the city (2 [A27]) | Not playable as anyone (Jules stays the hero). Some NPCs you help become **crew** you can call: a mechanic, a hacker, a driver, a lookout. Each one has a perk for heists and turf | R-22, R-23, E8 |
| **Street-art pasting** | Watch Dogs Legion: 47 paste-up spots (2 [A27]) | Paste posters satirising Aurum at marked spots; each one cuts Aurum's grip on that block slightly and joins the graffiti editor (4.8) | E7, 4.8 |
| **Drink before darts** | Watch Dogs Legion: a pint before darts pays more (2 [A27]); GTA IV drinking with friends (2 [A25]) | Both versions (Sachin, 2026-10-28: "Both"): a cartoon drink or a **lucky soda** or hot-sauce dare before darts adds wobble and doubles the stake. No drunk driving, and no reward for drinking more than one | E4 |

**Keep out**, from the same games:
- Watch Dogs 1's privacy invasions (peeking into homes through cameras): voyeurism, so cameras
  in Solvera only show streets and crime spots;
- Watch Dogs 1's poker and shell game (gambling decision), its drinking game, and its
  human-trafficking strand;
- Sleeping Dogs' health shrines (a religious site) and cockfighting (animal cruelty);
- LCS's Slash TV chainsaw gore (kept only as the non-lethal studio show above);
- GTA IV's friend shows with real comedians (Solvera uses fictional acts);
- drunk-driving effects and drink-more-to-win games. Sachin's answer (2026-10-28, "Both"):
  bar minigames may use a cartoon drink (one, with a short wobble) or the soda and hot-sauce
  dares; driving is never affected.

### 4.14 Bully, Saints Row and Yakuza: what they add (pass of 2026-10-28)

Sachin asked to check Bully, Saints Row and Yakuza too. Section 1 already took one lesson from
each (Bully's classes, Saints Row 2's scored chaos, Yakuza's business sims and Like a Dragon's
long loops). This pass reads their full activity lists: Bully and its Scholarship Edition; Saints
Row 2, The Third and the 2022 reboot; Yakuza 0 to 6, Kiwami 2, Like a Dragon and Infinite Wealth.
Same rule as 4.11: only what is not already planned. Facts come from guide and wiki search
summaries (2 [A29]-[A31]); details remembered but not confirmed by a search are marked U.

**Already in our plans, so not repeated here**:
- Bully (2 [A29]): classes as minigames (4.6 night classes); go-kart and bike races (2.8, R-14);
  arcade games (R-11); collectibles (R-7).
- Saints Row (2 [A30]): Insurance Fraud (4.5 fender-bender fraud); Chop Shop (4.11 daily
  wanted-car list); Demolition Derby (2.8, 4.11 arena show); Hitman's target list as the
  non-lethal bail bonds version (4.11); Zombie Uprising, a game inside the game (our café games,
  2.10); the reboot's ventures, such as a garage, a food truck and a laundromat (E6, and the
  money fronts in 4.11); its activities sorted by district (this is what `ACTIVITY_ATLAS.md`
  does); Tank Mayhem (the tank row in roadmap 1.1, for Fort Granite in phase 3).
- Yakuza and Like a Dragon (2 [A31]): karaoke (2.1); the batting cage (4.2); disco dancing (R-10
  dance rhythm game); darts, bowling and arcade classics (R-21, R-11); go-karts (2.8);
  taxi jobs and Crazy Delivery (R-16 shift jobs); busking (2.1); vocational exams (4.6);
  business sims (4.4, E6); Dondoko Island (the "buy back the Wards" renovation in 4.4); Sujimon
  (the collection log, E7); the Miss Match dating app (R-24); Revelations, learning a move from
  an odd sight (U; our fight manuals in 2.9 do the same job).

| Idea | From (label, source) | Solvera version | Engine / needs |
|---|---|---|---|
| **Paper route** | Bully: newspaper delivery missions on a bike (2 [A29]) | A dawn route on a bike through Magnolia Heights: flick papers onto porches on the beat of your speed, with bonuses for the doormat and for dodging dogs and sprinklers. The paper prints a front page about your latest big deed | E5, E3 |
| **Yard jobs** | Bully: lawn mowing for pay (U); snow shovelling in winter (U) | Mow lawns in Magnolia Heights; after a storm, clear branches and debris from Wards yards (pays in High Water reputation too). Snow shovelling waits for Steelhaven's winter (phase 6) | E5 |
| **Neighbour errands** | Bully: 50 errands for townsfolk, some of which unlock clothes (2 [A29]) | Named neighbours post small jobs on a phone "street board": fetch a lost cat, carry a sousaphone to the march, fix a fence. Each neighbour's chain ends in a **unique reward** (a jacket, a discount, a shortcut key) | R-5, E7 |
| **Travelling fair** | Bully: the carnival's games pay tickets for prizes (2 [A29]); roadmap 1.1 lists fairground rides as missing; now roadmap package 32 | A fair on Liberty Green for one week each season (E9): ring toss, high striker, a water-pistol race, a dunk tank with Aurum's mascot, a Ferris wheel and bumper cars. Tickets are earned only, never bought (section 6) | E1, E9, R-32 |
| **Sludge Avenger** | Saints Row 2 "Septic Avenger": spray sewage on buildings to drop their value (2 [A6][A30]) | A pump truck from the flood works sprays mud on Aurum show homes and billboards against the clock. Each soaked block lowers Aurum's land value slightly (wealth phase 1). Cartoon mess only, never on people | E3, R-22 |
| **Wrecking crew** | Saints Row 2 "Mayhem": damage property for a cash score (2 [A30]) | Grows 4.5's wrecking ball into a timed score run: a rival developer pays you to wreck one Aurum building site's props (fences, cones, portable toilets) with a digger or a pickup. Multipliers for chains | E3, physics props |
| **Bodyguard gigs** | Saints Row 2 "Crowd Control": guard a VIP from fans; it unlocks clothing discounts (2 [A30]) | Walk a fictional celebrity through the Gilt District while fans, paparazzi and a rival's goons rush in; shove, block and steer. Pays in shop discounts | R-5, light combat |
| **Reality cop show** | Saints Row 2 "FUZZ": a reality TV show films you as a cop (2 [A30]) | "Street Patrol" films your vigilante jobs (R-9). Clean, **non-lethal** arrests score style points; a good episode airs on the city news and lowers your police heat for a day | R-9, R-13 news |
| **Paint-trail quad run** | Saints Row 2 "Trail Blazing": a quad bike leaving a trail of fire through targets (2 [A30]); fire swapped out | A quad on the levee and in the bayou leaves a trail of coloured powder; drive it through marked targets (Aurum signs, festival floats) before the timer ends | E3 |
| **Chopper spotter** | Saints Row 2 "Heli Assault": cover a friend's car from a helicopter (2 [A30]) | Ride in a friend's helicopter and guide their getaway: mark roadblocks, call turns, drop smoke. No shooting. Waits for helicopters | E3, helicopters (roadmap) |
| **Pocket racers** | Yakuza 0 and Kiwami "Pocket Circuit": build tiny cars from parts found around town, race them on tracks (2 [A31]) | A hobby shop in the Lantern Quarter runs a mini-car league. Parts come from capsule toys, side jobs and hidden spots; you tune (motor, tyres, weight) and the race runs itself. Good for short phone sessions | E3 (auto race), E7 |
| **The Shakedown** | Yakuza 0 "Mr. Shakedown": a strong roaming enemy who takes your cash if he wins; beat him to win it back with extra (2 [A31]) | A huge debt collector roams at night. Lose and he takes 10% of your **pocket cash** (never bank or stock holdings); beat him for that cash back plus a bonus. A soft money sink that makes carrying cash a choice | combat (R-17) |
| **Crew defence** | Yakuza Kiwami 2 "Clan Creator": top-down battles defending sites with a crew (2 [A31]) | Defend a Wards building site or your club with the crew you recruited (4.13), each with a skill. Runs on the Levee Line tower-defence engine (2.10) | 2.10 Levee Line, 4.13 crew |
| **Cat café** | Yakuza 6: a cat café you help run; you find cats around town (U) | A cat café in Magnolia Heights that takes shelter cats. Find strays, bring them in, and the café earns more; regulars can adopt them. Ties to the pet shelter (4.1) | E6, animals (R-3) |
| **Fish-tagging dive** | Yakuza 6: spearfishing with a fisherman (2 [A31]) | An old fisherman takes you out off the Keys (phase 4): aim a tag dart at fish swimming past in waves, for the marine station's survey (no killing, like hunting becoming photography); rare fish go in the collection log | E4, diving, E7 |
| **Water-balloon fight** | Yakuza 5: a snowball-fight arena (U) | A summer water-balloon fight in Liberty Green for teams; a snowball version in Steelhaven later | E1, light combat |
| **Can run** | Like a Dragon "Can Quest": collect cans on a bike against the clock (2 [A31]) | Collect recyclables around the Wards with a bike cart before rival collectors take them; trade them in at the recycling yard. Pairs with the dumpster dash (4.13) | E3, E5 |
| **Oddball snaps** | Infinite Wealth "Sicko Snap": photograph strange people around town (2 [A31]) | A list of odd sights to photograph (a man walking a gator on a leash, a dog in the brass band); each one goes in the photo log (E7) with a gag caption | phone camera, E7 |
| **Personality traits** | Like a Dragon: personality stats such as kindness, charisma and confidence that rise from activities and open jobs and dialogue (U) | Five traits (Nerve, Charm, Smarts, Heart, Style) rise from hobbies: karaoke raises Charm, chess raises Smarts, volunteering raises Heart. Some jobs, dates and story options need a level. Gives every small activity a reason | stats (R-17), E8 |
| **Sandlot baseball** | Yakuza 6: a local baseball team you manage (U) | Coach a Wards amateur team: pick the lineup and hit in the batting cage minigame at the big moments. Wins raise the Wards' mood | E4 batting, E6 |

**Keep out**, from the same games:
- Saints Row 2's Snatch (pimping), Escort (sexual) and Drug Trafficking;
- Yakuza's hostess and cabaret clubs and its adult live chat (4.13's cabaret is a stage show
  only, with no hostesses);
- casinos, pachinko, mahjong and Koi Koi (the gambling decision);
- Hitman's killing contracts (only the alive-pays-more bail bonds version stays);
- Trail Blazing's fire on people, and any harm to bystanders in chaos runs;
- Bully's fights with children: no Solvera activity sets the player against kids.

## 5. Picking: the next wave after the roadmap's first wave

Scored the same way as the roadmap: liveliness (1-5) divided by cost. Most rows build on the
roadmap's first wave (packages 1-11); the **Needs** column names every roadmap package a row
depends on, including later ones.

| Order | Package | Contents | Needs | Cost | Life |
|---|---|---|---|---|---|
| N1 | E7 collection log + capsule toys + Lost Tapes | One book for every collectible; 20 tapes; capsule machines | R-7, R-6 | 1 | 4 |
| N2 | E4 swing engine + mini-golf + driving range + bowling | Three venues on one engine (pool and darts stay in R-21) | none | 2.5 | 4 |
| N3 | E2 rhythm engine + karaoke + busking | Songs become playable, not just heard | R-6 | 2.5 | 4 |
| N4 | Fishing | Biggest calm hobby; uses E4 and E7 | N1, N2 | 1.5 | 4 |
| N5 | E5 shift jobs + 4 careers (crane, courier, line cook, barista) | Legit money; teaches the map | R-16, IS-1, R-26 (bike) | 2 | 3 |
| N6 | Krewe Cards (game F) | Long-term collection hook, playable everywhere | R-11, N1 | 2 | 4 |
| N7 | Getaway driver for hire + pickpocketing + armoured van | Cheap crime variety on existing driving and wanted systems | R-5, R-20 | 1.5 | 4 |
| N8 | E6 business sim + food truck + Buy back the Wards | The long loop, tied to the story | R-22 | 3.5 | 4 |
| N9 | Studio + music app + record shop + 5 more stations | The AI-music promise in full | R-6, N3 | 2.5 | 3 |
| N10 | Martial-arts masters + fight manuals (2.9) | Hidden masters and manuals for the four Bellerive styles, on top of R-17; the regional styles come with the city packs (`ACTIVITY_ATLAS.md` D5) | R-17, N1 | 1 | 3 |
| N11 | Night classes (driving, coding, languages, first aid) | Learning as play | R-9 (first aid) | 2 | 2 |
| N12 | Hurricane-season event + election | Signature systemic events | R-25, R-9, R-26 (boats) | 3 | 5 |
| N13 | Arcade games G-L | Six small games | R-11 | 4.5 | 2 |
| N14 | Comedy chaos set + RC and drone | Cheap laughs | none | 1.5 | 3 |
| N15 | Daily variety set (4.11) | Daily wanted-car list, black-market van, payphone jobs, pop-up challenges, buried stash, community service | R-5, R-13, R-16, N1 (E7), N5 (E5) | 2.5 | 4 |
| N16 | Bail bonds + race creator + hit-and-run chases (4.11, 4.13) | Bounty work and player-made races | R-5, R-14, R-24 | 2.5 | 3 |
| N17 | Stock market (4.12) | The Exchange app with city-event prices and the anti-exploit rules | R-13 | 2.5 (lite; full 6) | 3 |
| N18 | Crime set (4.13) | Crimes detected, camera busts, convoy takedowns, hideout takedowns | R-5, R-9, R-17, R-19, R-20, R-22 | 3 | 4 |
| N19 | Liberty City and venue extras (4.13) | Car salesman, dumpster dash, lowrider bounce-off, air hockey, keepy-uppy, comedy club | N3, N5, N8 (E6, the car lot), R-10, R-11, R-13 | 2.5 | 3 |
| N20 | Money fronts and laundering (4.11) | Dirty and clean cash with laundering routes through people, gangs and companies that open with the story (`PROGRESSION_UNLOCKS.md` section 4) | R-22, N8, N26 | 2.5 | 3 |
| N21 | Neighbourhood jobs (4.14) | Paper route, yard jobs, can run, neighbour errands | N5, R-5, R-26 | 1.5 | 3 |
| N22 | Bully, Saints Row and Yakuza extras (4.14) | Sludge Avenger, wrecking crew, bodyguard gigs, reality cop show, paint-trail quad, pocket racers, the Shakedown, cat café, water-balloon fight, oddball snaps | R-3, R-5, R-9, R-13, R-17, R-22, N1, N8 | 4 | 3 |
| N23 | Crew and character (4.13, 4.14) | Recruit from the street, crew defence, personality traits, sandlot baseball | R-17, R-22, R-24, N2, N13 (Levee Line engine) | 3 | 3 |
| N24 | Street and car extras (4.11, 4.13) | Car meet with rep and a test track, transform races, arena car-combat show, arm wrestling, backyard wrestling league, TV at the safehouse, street-art pasting, the soda dare at darts | R-11, R-13, R-14, R-15, R-17, R-21, R-26, N1 | 2.5 | 3 |
| N25 | Outdoors and phone extras (4.11, 4.13) | Kayaking, the illegal base jump (wanted star; the jumps are R-31's), wildlife photography challenge (the bayou, the Glades, Red Pine), bayou wildlife rescue, studio gauntlet show, camera-mast puzzles, AR phone games | R-3, R-11, R-13, R-14, R-17, R-19, R-24, R-26, R-31 (parachute) | 2.5 | 3 |
| N26 | Story unlock framework (`PROGRESSION_UNLOCKS.md`) | Unlock registry and save key, "Opening soon" hoardings that turn into venues, opening-day events, the phone's "New in town" page, first-visit discovery | none | 2 | 4 |

- **All 14**: about **31 sessions**, on top of the roadmap's 57.
- **N15-N26** (added with 4.11-4.14 and the story unlocks): about **31 sessions** more with the lite stock market (N17;
  the full market adds 3.5). The roadmap's new packages 28-32 (yoga, triathlon, flight school, parachute
  jumps, fairground) add about 8, and the city activity packs in `ACTIVITY_ATLAS.md` Part D
  about 19 (cheaper: 7), both spread over the world phases. Every item in 4.11-4.14 now sits in
  N15-N25, in roadmap package 32 (the travelling fair), in a city pack (snorkelling and fish
  tagging in CP-2) or in the list below.
- **Not costed yet** (in no N row, roadmap package or city pack): much of sections 2 and 4 sits
  outside N1-N14 as content for later rounds:
  - the racing extras (2.8);
  - the boxing, gym, shopping and eating-out extras;
  - the Haverly links (real golf in Sovereign County, CP-3's core set; Ember Heights' 9 desert
    holes are the Las Brasas signature in CP-2, on N2's engine);
  - the gallery and storm heists;
  - photography beyond package 7 and N25, diving (needed by CP-2's snorkelling and fish
    tagging), pets, and the first Bellerive homes of escape rooms, laser tag, paintball, the
    trampoline park, the climbing wall and the batting cage (`ACTIVITY_ATLAS.md` D4);
  - the D4 repeats outside the packs' contents: Bottle Flats paintball, the Bayview climbing gym,
    the Steelhaven ballpark derby and hobby shop, and the Foggy Row pub;
  - 7 of the 11 careers;
  - water fun (4.10), including the swimming that R-29's swim legs need; the meta layer (4.9) is costed there (about 1 session) but not yet scheduled;
  - the chopper spotter, which waits for helicopters.

  On the engines, most of these are 0.3-1 session each. A rough guess for all of them is another
  15-20 sessions.
- **Cheaper option**: N1-N7 only, about **13 sessions**. From Sachin's list this covers:
  - AI songs, in part (karaoke, busking, Lost Tapes);
  - golf (mini-golf and the range);
  - robbery extras;
  - café games (cards);
  - a little shopping (capsule toys).

  Gym, boxing, table tennis, racing, martial arts and eating out come from the roadmap's own
  packages (R-1, R-14, R-17, R-18, R-21) and from N10 (the regional martial arts come with the
  city packs).
- **Recommendation**: the cheaper option first, then N15 and N21 (cheap daily variety). Re-score after players (or Sachin) have played the
  first wave, and order the rest by what they actually return to.

## 6. Things to keep out

- **Pay-to-win, and paid card packs or loot boxes**: capsule machines, claw machines and Krewe Card
  pulls are random rewards. They use **tickets or tokens that can never be bought with real money,
  directly or through a purchasable currency**. If cash is ever sold (the concept plans
  free-to-play), random items bought with it count as paid random items, which store ratings must
  label ("In-Game Purchases (Includes Random Items)").
- **Real casinos, horse betting and cockfights**: fight nights pay purses, not bets, until the
  gambling decision.
- **Drug-making classes or jobs**: the coding class stays cartoon (traffic lights, cameras).
- **Real songs, sound-alikes or real artists' voices**: AI prompts must not name real artists.
- **Religious practices**: voodoo, saints and churches stay out (WORLD_BIBLE). The second-line march and
  festivals are secular street culture.

## 7. Decisions for Sachin

1. **Order**: take the next wave (section 5) after the roadmap's first wave, cheaper option
   N1-N7 (about 13 sessions) first? Or pull some forward, such as karaoke and fishing?
2. **AI music source**: Suno paid plan (fast, per-month fee, terms changed in Sept 2026), or
   self-hosted ACE-Step (Apache 2.0, free per song, needs a GPU session)? Either way, generation
   needs credits or compute, which isn't spent yet.
3. **Real singing in karaoke** (microphone, opt-in), or rhythm-only?
4. **Fender-bender fraud**: keep it (cartoon comedy), or cut it for tone?
5. **Krewe Cards**: should it become a stand-alone mobile game later (marketing for Solvera)?
6. The roadmap's open points still stand: gambling, audio timing, first-wave order, and "sucu".
Answered by Sachin on 2026-10-28:

7. **Stock market**: approved ("Sure"); the ten recommended answers in `STOCK_MARKET_DESIGN.md`
   section 11 are the defaults until he changes one.
8. **Money laundering**: dirty and clean cash, with several laundering routes (people, gangs,
   companies) that open as the story goes on (`PROGRESSION_UNLOCKS.md` section 4; N20).
9. **Alcohol in minigames**: both: a cartoon drink (one, short wobble) or the soda and hot-sauce
   dares; never drunk driving.
10. **City activity packs**: the cheaper version first (about 7 sessions; `ACTIVITY_ATLAS.md` D5
    lists exactly what it buys); the full packs (about 19) stay costed for later.
11. **Story unlocks** (new, 2026-10-28): activities, showrooms and regions open with the story
    and with exploration (`PROGRESSION_UNLOCKS.md`; N26). Its open points are in that doc.

## 8. Sources

- [A1] Yakuza 0 business sims and batting cage (guides):
  https://medium.com/super-jump/a-ux-analysis-of-cabaret-club-czar-yakuza-0s-game-within-a-game-a2f8525ad7b0 ·
  https://unseen-japan.com/yakuza-0-japan-bubble-economy/ ·
  https://segaretro.org/Yakuza:_Like_a_Dragon/Gameplay/Minigames ·
  https://deltiasgaming.com/like-a-dragon-pirate-yakuza-in-hawaii-complete-mini-games-guide
- [A2] Infinite Wealth: https://gematsu.com/2023/12/like-a-dragon-infinite-wealth-details-minigames ·
  https://www.gamepressure.com/like-a-dragon-infinite-wealth/all-mini-games/ze11219 ·
  https://ryu-ga-gotoku.com/eight/asia_en/adventure
- [A3] Sleeping Dogs: https://gamesbeat.com/sleeping-dogs-game-guide/ ·
  https://www.trueachievements.com/game/Sleeping-Dogs/walkthrough/8
- [A4] Shenmue: https://en.wikipedia.org/wiki/Shenmue_(video_game) ·
  https://strategywiki.org/wiki/Shenmue/Arcade_Games
- [A5] Watch Dogs 2: https://primagames.com/eguides/watch-dogs-2-eguide/side-operations ·
  https://www.gamepressure.com/watchdogs2/driver-sf-missions/za938f
- [A6] Saints Row 2: https://www.supercheats.com/guides/saints-row-2/activities ·
  https://saintsrow.fandom.com/wiki/Septic_Avenger_(Activity)
- [A7] Red Dead Redemption 2: https://www.gtabase.com/red-dead-redemption-2/activities/ ·
  https://www.pushsquare.com/guides/red-dead-redemption-2-all-mini-games-and-where-to-find-them
- [A8] Bully: https://www.giantbomb.com/games/3030-5092/ ·
  https://manualmachine.com/activision/bully/2410741-user-manual
- [A9] Marvel's Spider-Man: https://www.powerpyx.com/guide/marvels-spider-man/ ·
  https://selphie1999gaming.com/game-guides/marvels-spider-man-all-55-backpacks-locations-backpacker-trophy-achievement-guide/ ·
  https://www.gamepressure.com/marvels-spider-man/secrets-and-side-activities/z6b479
- [A10] Godot adaptive music: https://docs.godotengine.org/en/4.3/classes/class_audiostreaminteractive.html ·
  https://docs.godotengine.org/en/4.3/classes/class_audiostreamsynchronized.html
- [A11] Godot microphone: https://docs.godotengine.org/en/4.2/classes/class_audiostreammicrophone.html ·
  https://docs.godotengine.org/it/4.4/tutorials/audio/recording_with_microphone.html
- [A12] Suno terms: https://about.suno.com/blog/suno-updates-tos (primary) ·
  https://www.musicinafrica.net/magazine/suno-adjusts-ai-music-ownership-terms-after-warner-music-partnership ·
  https://dynamoi.com/learn/ai-music-distribution/suno-commercial-rights-explained
- [A13] ACE-Step model card: https://huggingface.co/ACE-Step/ACE-Step-v1-3.5B
- [A14] GTA V hobbies and pastimes (guides): https://www.gtabase.com/grand-theft-auto-v/side-missions/ ·
  https://sportskeeda.com/gta/gta-5-100-completion-checklist
- [A15] GTA V bail bonds and towing: https://www.gtabase.com/grand-theft-auto-v/side-missions/bail-bonds ·
  https://www.grandtheftwiki.com/Bail_Bonds_-_Glenn_Scoville ·
  https://www.gtabase.com/side-missions/grand-theft-auto-v/towing-missions
- [A16] GTA Online Gun Van: https://sportskeeda.com/gta/why-gta-online-gun-van-changes-location-every-day ·
  https://pcgamer.com/gta-online-gun-van-location
- [A17] GTA Online businesses: https://www.sportskeeda.com/gta/list-every-business-available-players-gta-online-properties-required ·
  https://deltiasgaming.com/?p=164609
- [A18] GTA Online Money Fronts: https://gta.wiki/w/GTA_Online:_Money_Fronts ·
  https://www.gtabase.com/articles/gta-online-money-fronts-releases-june-17 ·
  https://massivelyop.com/2025/06/12/gta-online-will-introduce-money-laundering-mechanics-in-the-money-fronts-update-june-17/
- [A19] GTA Online Arena War, Transform Races, LS Car Meet: https://www.pcgamesn.com/grand-theft-auto-v/gta-online-arena-war ·
  https://www.pcgamer.com/gta-onlines-transform-races-are-crazy ·
  https://pcgamer.com/gta-online-los-santos-tuners-update-guide-rep
- [A20] GTA VI activities (pre-release): https://gameinformer.com/2026/08/27/every-potential-side-activity-we-saw-in-the-grand-theft-auto-vi-extended-look ·
  https://www.gamesradar.com/games/grand-theft-auto/gta-6-side-activities/ ·
  https://www.redbull.com/us-en/gta-6-side-activities ·
  https://www.gamingbible.com/news/gta-6-confirms-side-activities-158807-20250507
- [A21] GTA VI release date: https://www.gamesradar.com/gta-6-release-date-news-trailers-map-gameplay-rumours/ ·
  https://gameluster.com/?p=140202
- [A22] GTA VI regions: https://gameinformer.com/2025/05/06/rockstar-shows-off-six-major-areas-of-vice-city-in-grand-theft-auto-vi ·
  https://www.gamerguides.com/grand-theft-auto-vi/news/regions-of-grand-theft-auto-vi
- [A23] GTA III side missions: https://gtabase.com/gta-3/side-missions ·
  https://www.igrandtheftauto.com/gta3/guides/side-missions ·
  https://www.igrandtheftauto.com/gta3/guides/100-percent-completion-checklist
- [A24] GTA Liberty City Stories side missions (Car Salesman, Trash Dash, Low Rider Rumble, Slash TV):
  https://gtabase.com/gta-liberty-city-stories/missions/ ·
  https://gta.wiki/w/Missions_in_GTA_Liberty_City_Stories ·
  https://www.igrandtheftauto.com/gtalcs/guides/vehicle-sub-missions
- [A25] GTA IV, TLAD and TBoGT friend activities: https://gta.wiki/w/Friendships_in_GTA_IV ·
  https://gta.wiki/w/Friendships_in_The_Ballad_of_Gay_Tony ·
  https://bloxodes.com/gta/wiki/gta-4-tlad/activities ·
  https://www.gamepressure.com/grandtheftautoiv/friends/z9125a
- [A26] Watch Dogs 1 side missions and minigames: https://www.gamepressure.com/watchdogs/activities-and-hints/z0631f ·
  https://www.dualshockers.com/watch_dogs-side-missions-and-mini-games/ ·
  https://www.honestgamers.com/guides/watch-dogs/4/read/137.html
- [A27] Watch Dogs Legion activities: https://powerpyx.com/watch-dogs-legion-all-darts-locations ·
  https://windowscentral.com/watch-dogs-legion-vuide-minigames-how-play-them ·
  https://www.giga.de/galerie/watch-dogs-legion-alle-47-paste-up-orte-fundorte-auf-der-karte/
- [A28] Sleeping Dogs side activities: https://www.trueachievements.com/game/Sleeping-Dogs/walkthrough/6 ·
  https://www.gamepressure.com/sleepingdogs/secondary-missions/z23ee5 ·
  https://segmentnext.com/sleeping-dogs-all-random-events
- [A29] Bully side activities (errands, paper route, carnival, races, classes):
  https://bully.fandom.com/wiki/100%25_Completion ·
  https://skillnation.in/posts/bully-scholarship-edition-100/ ·
  https://www.wand.com/en/maps/bully-scholarship-edition/bullworth/checklist ·
  https://tcrf.net/Bully_(PlayStation_2)
- [A30] Saints Row activities (SR2, The Third, the 2022 reboot):
  https://www.supercheats.com/guides/saints-row-2/activities ·
  https://www.trueachievements.com/game/Saints-Row-2/walkthrough/4 ·
  https://www.giantbomb.com/wiki/Games/Saints_Row_2 ·
  https://saintsrow.wiki/wiki/Activities_in_Saints_Row ·
  https://saintsrow.wiki/wiki/Activities_in_Saints_Row:_The_Third ·
  https://saintsrow.wiki/wiki/Tank_Mayhem ·
  https://www.gamepressure.com/saints-row-v/list-of-all-side-activities/zd102d6 ·
  https://www.gamepressure.com/saints-row-v/list-of-all-ventures/zf102d8
- [A31] Yakuza and Like a Dragon minigames:
  https://www.gamepressure.com/yakuza-6/minigames-list/z6aca1 ·
  https://samurai-gamers.com/yakuza-like-a-dragon/mini-games/ ·
  https://www.gamepressure.com/like-a-dragon-infinite-wealth/all-mini-games/ze11219 ·
  https://www.gematsu.com/2023/12/like-a-dragon-infinite-wealth-details-minigames ·
  https://www.gamerguides.com/like-a-dragon-infinite-wealth/guide/minigames/sicko-snap ·
  https://blogs.tuni.fi/playlab/game-reviews/yakuza-kiwami-2-gangster-drama-with-lots-of-minigames/ ·
  https://www.sportskeeda.com/esports/7-great-mini-games-yakuza-like-dragon-franchise
