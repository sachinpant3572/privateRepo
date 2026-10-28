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
  **New here, the 6 in N10**: Muay Thai, judo, Brazilian jiu-jitsu, capoeira (taught by a Porto
  Brisa émigré), wrestling and kalaripayattu. Later: silat and krav maga.
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
| N10 | Martial-arts masters + fight manuals + 6 new styles (2.9) | On top of R-17 | R-17, N1 | 2 | 3 |
| N11 | Night classes (driving, coding, languages, first aid) | Learning as play | R-9 (first aid) | 2 | 2 |
| N12 | Hurricane-season event + election | Signature systemic events | R-25, R-9, R-26 (boats) | 3 | 5 |
| N13 | Arcade games G-L | Six small games | R-11 | 4.5 | 2 |
| N14 | Comedy chaos set + RC and drone | Cheap laughs | none | 1.5 | 3 |

- **All 14**: about **32 sessions**, on top of the roadmap's 57.
- **Not costed yet**: much of sections 2 and 4 sits outside N1-N14 as content for later rounds:
  - the racing extras (2.8);
  - the boxing, gym, shopping and eating-out extras;
  - real golf;
  - the gallery and storm heists;
  - photography, diving, pets, escape rooms, laser tag and paintball;
  - 7 of the 11 careers;
  - water fun (4.10); the meta layer (4.9) is costed there (about 1 session) but not yet scheduled.

  On the engines, most of these are 0.3-1 session each. A rough guess for all of them is another
  15-20 sessions.
- **Cheaper option**: N1-N7 only, about **13 sessions**. From Sachin's list this covers:
  - AI songs, in part (karaoke, busking, Lost Tapes);
  - golf (mini-golf and the range);
  - robbery extras;
  - café games (cards);
  - a little shopping (capsule toys).

  Gym, boxing, table tennis, racing, martial arts and eating out come from the roadmap's own
  packages (R-1, R-14, R-17, R-18, R-21) and from N10.
- **Recommendation**: the cheaper option first. Re-score after players (or Sachin) have played the
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
