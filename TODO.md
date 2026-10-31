# TODO

## NEXT, first after Bellerive's city and mountain are fully done: MadOut2 lessons

Sachin, 2026-10-30: "Also, add the MadOut2 findings to the TODO lost to be taken up as the
first thing, after Belleriv (Only the City and the Mountain part is fully done."

Order: this starts as soon as the Bellerive city and mountain work (#116, without the parts
not yet approved, such as the bay and the hill country) is fully done, ahead of every other
item below, the HIGH PRIORITY Chinatown Wars section included. Full findings, sources and
labels: `MADOUT2_COMPARISON.md` (sections 5 and 6). Sizes are AI sessions of 3-5 hours.
Each step still starts on Sachin's word, with its own plan, gates and review.

What Solvera lacks next to MadOut2, most noticed first: guns and shootouts; any sound;
repeatable ways to earn (races, jobs); things to buy and show off (cars, tuning, clothes,
homes); a reason to come back daily; other players (not even leaderboards); volume (24 cars
vs 70+, 3 missions vs 30+); wanted levels above 2 stars; real players' feedback.

1. **Close the core loop before adding more world**: earn (repeatable jobs and street races on
   existing roads, through the mission system), spend (buy cars, a tuning garage, a clothes
   shop), show off. 8-12 sessions.
2. **Guns and wanted levels 3-5** (already planned as phase 6). 6-8 sessions.
3. **First audio pass**: engines, tyres, impacts, punches, ambience, UI, from CC0 or
   code-synthesised sounds. 3-5 sessions.
4. **Players early**: a Play closed test, then an open beta in one region, with crash
   reports and simple analytics. 2-4 sessions plus store setup.
5. **Daily and weekly tasks plus "light online"** (`MVP_DESIGN.md`): leaderboards, ghost
   races, weekly events. 3-5 sessions plus a small backend.
6. **Turn MadOut2's weak spots into ours to win**: rewarded ads only, a low-end frame-rate
   gate on a real cheap phone, no fall-through bugs, good controls. Ongoing.
7. **Store presence**: searchable title and description, localised listings, a short
   trailer, photo mode. 1-2 sessions plus art.
8. **Real-time multiplayer** only after the single-player loop works, as a separate
   decision (months, not sessions).

Cheaper start if only one step is taken: 3 (audio) plus the earn half of 1 (street races
and one job), about 6-8 sessions; it fixes the two gaps a new player meets in the first
five minutes.

## Thursday, Oct 30, 2026: real grass on the hills, parks and lawns, with a Grass setting

Sachin, 2026-10-30: "Can we add grass to the hills or other green areas in the game, and
give 4 settings for grass, no grass, some grass, more grass, full grass, or name them
appropriately. Add this to TODO, having grass is a sign of a fully modern game. Also,
right now every green area looks devoid of grass, so."

Now: green ground is a flat shaded surface (the GRASS surface code draws a mown-lawn
pattern) with a few scattered tuft props from flora_kit (`tufts`, 3-5 blades per
patch). There is no field of blades anywhere.

Plan (not started, awaiting his word; rough cost 6-10 h with gates):
- Blades as GPU-instanced MultiMesh clumps (a few crossed cards or 3-5 thin tris
  each) laid in a ring of tiles round the camera, streamed with the city and country
  tiles, faded out by distance so there is no hard edge.
- Where: lawns and yards (short, mown, even), parks and verges (medium), hills and
  open land (taller, clumpy; green on wet north faces and canyon floors, straw on dry
  south faces, matching flora's green/dry mix), none on roads, pads, sidewalks, sand,
  water or under buildings. Colour taken from the ground under it so it blends.
- Wind sway in the vertex shader (one shared material, drawn at load like the fire
  prewarm so Android does not hitch); blades bend away from the player and cars
  passing through (optional, High and up).
- Setting **Grass** in Settings > Graphics: **Off**, **Sparse**, **Lush**, **Dense**
  (no grass, some, more, full). Each step raises density and draw distance. Graphics
  presets: Low Off, Medium Sparse, High Lush, Ultra Dense; Sachin can pick any.
- Gates: a frame-time probe on each step at the busiest green spot (perf_probe), a
  test that no blades sit on roads/pads, screenshots of a lawn, a park and the hills at
  each step, by day and night.

## Thursday, Oct 30, 2026: hill country behind Bellerive (land done 2026-10-31, content later)

Status: the land step he approved ("Lets go!", 2026-10-30) is built: the East Hills (Whistler,
Tallow, Copperback, Fernmoor), East Hills Road, dirt tracks and trails to each top, two
shortcuts, back-country lines and seven viewpoints; true rolling hills 3.10 km² (was 1.86);
the design map `docs/hill_country_design_map.png` places the content below as proposals.
Details: `HANDOFF-hill-country.md`. Content (places, wildlife, hunting, events) waits for his word.

Sachin, 2026-10-30: "I think Hills area should be increased to at least 3 km2, as it is
too small right now not even the same as Gta San Andreas maps Hills. We can add cults,
villages, towns, trailer towns, truck stops, petrol pumps, racing activities, illegal
racing etc strategically at appropirate places, highways, town roads, unpaved roads,
shortcuts, stunt jumps/places, forests, shady areas, mystery places, creepy areas,
scenic places, eateries, acitivities like cycling, parachuting, bungee jumping, cable
car etc to it comfortably then. What do you think?"
Then: "We could have multiple mountain peaks with different views, roads etc, a stretch
of hilly region behind the city to explore, do things, chill, have fun etc."
Then: "Also, events that happen only in small towns or counties + secret govt/milotary
research labs in mountains, far away from the city, religious cults, hunters, animals,
flora and fauna, can add hunting activity too, hikers, runners, etc too"

Status: steps 0 and 1 **done** (2026-10-31); steps 2-4 **not approved**, wait for his word.
Order, rough costs:
0. Done: design map `docs/hill_country_design_map.png` (tools/hill_design_map.py),
   everything below placed as proposals, quiet and busy zones with buffers.
1. Done: land, true rolling hills (50-450 m, slope <= 0.45, within 150 m of a way)
   1.86 -> 3.10 km2 (tools/hill_area.py), more peaks with
   roads and viewpoints (~8-14 h).
2. Places: villages, towns, trailer towns, truck stops, petrol pumps, eateries, scenic,
   shady, creepy and mystery spots, an original cult compound (fictional beliefs, no real
   religion), a secret research lab in a closed valley behind the range with one guarded
   road (ties in with the agency and nuclear plant above) (~20-35 h).
3. Life: wildlife (deer, coyotes, mountain lions, rabbits; models, animation, wander,
   flee, attack) ~25-45 h; hunting on top (licence, seasons, a hunting store, selling
   pelts) ~10-20 h; flora bands by height on top of #91 ~6-10 h; hikers, runners and
   hunters on the trails as NPC roles ~8-15 h; small-town events (fair, rodeo, market,
   festival, speed trap) on the calendar ~15-30 h.
4. Activities: racing and illegal racing, stunt jumps, cycling, parachuting, bungee
   (~35-70 h); the cable car is #113 (not approved).

Sachin, 2026-10-30: "There will be lakes, rivers, ponds flowing between, or inside the
mountain appropriately, + springs (3 -4 hot cold both, strategically), rave parties in
mountains, bridges above the rivers or lakes + between mountains themselves, 1-2 train
bridges too, 5start hotels and restaurants with their good as well as twisted history
and staff. Add these too to TODO for the Mountain, but keep Rivers, Lakes, Bridges,
Train tracks, Tunnels, roads, shortcuts, animals, and huge forest on priority."

**Priority (his word), first when the hill country is approved:**
- Rivers, lakes and ponds that flow between and inside the range, along valleys
  the terrain allows (the Morrow gorge is the first).
- Bridges over rivers and lakes and between peaks, plus 1-2 rail bridges. This
  needs the grade separation in #110 (not approved) to draw them.
- Train tracks through the range (#111, not approved).
- Tunnels (#110; underground spaces cannot be drawn yet).
- Roads, unpaved roads and shortcuts.
- Animals (wildlife, step 3 above).
- One huge forest across the back of the range.

**After those:**
- 3-4 springs, hot and cold, placed for views and trails.
- Rave parties in remote clearings, at night, on the event calendar.
- 5-star mountain hotels and restaurants, each with its staff and a history,
  good and twisted (original names; story hooks for missions).

Sachin, 2026-10-30: "Because 3km2 is going to be a huge area, we have to balance out
secluded areas for calm and peace, and the activities going on, add an illegal forest
tree cutting/delivering job too."
- **Balance**: the design map marks quiet zones (no events, races or raves; trails,
  springs, viewpoints, wildlife) apart from the busy ones (towns, truck stops, race
  routes, rave clearings), with buffers between, so calm places stay calm.
- **Illegal logging job**: fell trees deep in the forest, load a log truck, haul it
  out on unpaved roads to a buyer at a shady sawmill, dodging rangers (wanted level if
  seen). Needs the huge forest and unpaved roads above.

## Thursday, Oct 30, 2026: industry, secret sites, a busy airport and everyday-life services

Sachin, 2026-10-30: "Add to TODO, build a Quarry in map, away from the city, behind
the mountains, and a Coal Mine too somewhere appropriate + Caves to explore with their
own mysteries + A Nuclear Energy facility + An FBI/CIA like agency in the game + One
large airport in Belleriv with more than 30 big airliner planes capacity and remains
continously busy, ability to purchase flight tickets from the counter or througu phone,
same for trains, buses, trams, taxi booling through phone app, quick commerce app on
phone for daily items + online clothing shopping(Amazon like service) + most of the
things that happens in everyday life. We will bhuld a detailed plan for this and
execute later."

Status: **plan first, build later**, on his word. Nothing here is approved to build yet.
All names below are placeholders to be replaced by original ones in the plan (no real
agencies, brands or places).

- **Quarry**: away from the city, behind Mount Calder (the range's north side, past
  the Morrow gorge). Terraced pit, haul road, crushers, conveyors, dump trucks; ties in
  with the quarry job in ACTIVITY_ROADMAP.md (row "Trucking, quarry, valet ...").
- **Coal mine**: somewhere it fits geologically and economically (a rust-belt or hill
  county, on the freight line so coal trains have a reason to run, #111): headframe,
  tipple, spoil heaps, a mine town.
- **Caves to explore, each with its own mystery**: limestone or lava caves in the
  range and the hill counties; a story or secret per cave (collectibles, an old
  smuggling stash, a sealed lab, a lost expedition). Needs underground spaces, which the
  game cannot draw yet (the range's tunnels are data only, HANDOFF-world-mountain.md).
- **Nuclear power station**: a guarded plant with cooling towers on a lake or the
  coast, far from the city; restricted area, wanted level for trespass, possible heist
  or sabotage-prevention missions.
- **A federal agency** (FBI/CIA-like, fictional name): a headquarters building,
  agents and unmarked cars, a top wanted-level tier, a black site, and story missions
  for or against it.
- **One large airport in Bellerive** (Bellerive International in WORLD_V3_PLAN.md):
  gates and stands for **30+ wide-body airliners**, continuously busy (planes taxiing,
  taking off and landing on a schedule, ground vehicles, a terminal crowd). Needs stage
  B's airport edge to grow into a full site, plane models and simple flight paths.
- **Tickets for travel**: buy flight tickets at the counter or on the phone; the same
  for trains, buses and trams (WORLD_V3_PLAN.md "Scheduled flights, trains, ferries and
  ships": kiosk, ticket, fade, arrival). Trams and buses need routes and stops first
  (#111 for trains).
- **Phone apps for everyday life**: taxi booking (a ride-hailing app on top of the
  existing phone cab call), a quick-commerce app for daily items delivered to the door,
  an online clothes shop (Amazon-like) delivering to home (ties into the wardrobe, #98),
  and more of what happens in everyday life (bills, food delivery, banking, bookings).
- **The plan to write** (when Sachin says go): research how GTA V, Watch Dogs and
  similar games do each item, then for each one the place on the map, what the player
  can do there, systems it needs, a rough cost and an order, written up as a plan doc.

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
| 2 | Top-down view put off players who wanted modern GTA's third-person view | Perspective top-down, a camera that turns with the car and follows the walk, settings for angle, distance, drive zoom-out and turn behind a HUD gear button | Full 3D stays parked (entry below); find what makes top-down feel modern rather than retro |
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

## Thursday, Oct 29, 2026: launch-readiness rework checklist

Status: **checklist only, nothing started**. From a read-only review of the
code on 2026-10-29 (this branch at 92409f3), comparing the prototype with
what a big studio would ship. Asked by Sachin: "Add this as a checklist in
both repos' TODOs". Per CLAUDE.md, an item here is not a request on its own:
each one waits on his word. Efforts are rough, for one developer with AI
agents. Paths are under `game/`.

### Must fix before launch
- [ ] **Audio, from scratch**: no AudioStreamPlayer, AudioServer or sound
  file exists. Engines, crashes, sirens, hits, ambience, UI, music; mixer
  buses, 3D attenuation, voice limits, ducking, streamed music, AI-music
  rights records (GANGSTAR_CONCEPT.md risk 7). 4-8 weeks.
- [ ] **Ads, billing, analytics, crash reporting, remote config, cloud
  save**: none exist. MVP_DESIGN.md commits to F2P (rewarded ads, premium
  currency, season track) and "Analytics from build one". game_log.gd is
  local only and can't catch native crashes. Plus a consent layer (Google
  UMP for GDPR, iOS ATT). 3-6 weeks.
- [ ] **Core crime loop** (missing content more than rework):
  `MAX_LEVEL := 2` in scripts/wanted.gd ("the prototype stops at two");
  police are cop.gd + police_manager.gd (about 250 lines), no roadblocks,
  helicopters or spike strips; no guns or aiming (inventory.gd: weapons
  "in later phases"); 3 missions of 50+. Months.
- [ ] **Store-ready build** (export_presets.cfg): `use_gradle_build=false`
  means APK only; Play needs an AAB, and Billing, ads, Firebase and Play
  Asset Delivery need the Gradle build. Package id `com.solvera.prototype`
  can't change after the first upload. No release keystore
  (setup_cloud.sh makes a fresh debug keystore per container). No iOS
  preset (needs a Mac). About 1 week Android, 1-2 weeks iOS.
- [ ] **Release defaults**: scripts/main.gd line 44 ships `show_fps`,
  `log`, `log_button` (the BUG button) on, `quality: "high"` and
  `fps_limit: 120`, with no device-tier detection, so a min-spec phone
  starts on High. 2-4 days.
- [ ] **Save hardening** (scripts/missions/mission_manager.gd
  `save_game`/`load_game`): writes in place with no write-then-rename or
  backup; a corrupt file silently becomes a new game and the next save
  overwrites it; plain JSON with cash in clear text (a problem once premium
  currency exists); settings share the file with progress; one
  `version >= 2` migration; nothing saves on Android pause (only
  game_log.gd handles NOTIFICATION_APPLICATION_PAUSED). About 1 week.
- [ ] **Loading screen and boot**: startup is one blocking call in
  main.gd (street plan, 4.05 MB country.json parsed on the main thread,
  places, sidewalks, every vehicle model and paint prewarmed). No loading
  screen or main menu; a long black screen on a cheap phone risks an ANR
  kill (unverified). Record `boot_ms` from a real phone. Seed is
  hard-coded (`city.build(1234)`). 1-2 weeks.
- [ ] **Safe area / notches**: no `get_display_safe_area` with
  `immersive_mode=true`; HUD corners may sit under cutouts (check on a
  device). 2-3 days.
- [ ] **Localization**: no `tr()` or TranslationServer; about 160+ English
  strings inline (HUD, phone, settings, mission dialogue such as
  m01_homecoming.gd). Only Godot's default font: no brand font, no
  Devanagari or CJK. 2-3 weeks, more per language.
- [ ] **Licences screen**: Godot's MIT licence and third-party notices
  must ship in the app. (MakeHuman use is fine: CC0 data only, no AGPL
  code, per HANDOFF-people-v2.md.) 1 day.
- [ ] **Re-measure on the min-spec phone**: the 30 fps low-end result
  predates people at about 2.4k triangles (from about 790 in 0.24), the
  country and the flora. Each pedestrian builds its own skinned mesh on
  the main thread when it spawns (humanoid.gd -> build_rig).

### Should fix
- [ ] **City generator is Bellerive-only**: street_plan.gd (2,243 lines)
  hard-codes names and coordinates (59 Bellerive references; 32 in
  city_cells.gd); city.gd `CITY_ID := "bellerive"`; one city loads. Four
  cities plus country plus island need a general generator or baked
  sectors. 4-8 weeks.
- [ ] **One world pipeline**: the city is generated at runtime in
  GDScript, the country is baked by about 6.5k lines of untested Python
  (build_country.py, farmland.py, mountain.py) into one JSON read whole at
  boot (about 35 km², 3,516 tiles, 4 MB; the full state would be roughly
  15-20 MB, unverified). Stream baked binary sectors instead.
- [ ] **Parallel streaming**: one worker task at a time for city cells
  (city.gd) and country tiles (country.gd); node and physics-shape assembly
  on the main thread; hill tiles take 67-76 ms each on desktop
  (HANDOFF-0.23-flora.md). Freeway speed on a phone could outrun it and pop
  in (unverified). 1-2 weeks.
- [ ] **God files and no scenes**: country_kit.gd is 5,098 lines (134
  static functions), shady_kit.gd 2,549; one main.tscn, no .tres, no UI
  Theme, so designers and artists can't iterate without a programmer.
- [ ] **World stability**: the world exists only as code, so any kit
  change moves it (the plan-dump baseline test guards this); layout depends
  on `hash()` of arrays (city_cells.gd), which could change between Godot
  versions (unverified).
- [ ] **Art ceiling**: no textures; every surface is vertex colour plus one
  uber-shader keyed by vertex-alpha codes (mesh_builder.gd). Great for draw
  calls, but caps quality below authored, textured assets.
- [ ] **Authored characters and animation**: 17 bones (character_kit.gd,
  no fingers, toes, shoulders or jaw), all animation procedural in rig.gd
  (no AnimationPlayer/AnimationTree, no mocap). Swapping in modelled
  characters needs retargeting and a new outfit system: weeks.
- [ ] **Mission tooling for 50+ missions**: missions are coroutine scripts
  with dialogue and positions inline; data/missions_act1.json isn't read by
  the game (only tools/render_map.py). Add dialogue tables (localization,
  voice-over), checkpoints and a mission skip/debug tool. About 2 weeks.
- [ ] **CI and tests**: no CI (.github missing); no device, performance
  regression, save-corruption or lifecycle tests. Blood RNG was flaky
  (6ac03ef). test_country_kit_builds_every_kind was recorded failing
  (farmhouse_big overlap, HANDOFF-0.23-traffic.md); current status
  unverified.
- [ ] **Accessibility and controls**: no colour-blind, text-size or
  subtitle options, no haptics; touch controls can't be moved or resized
  (this TODO lists that as a must for touch driving).
- [ ] **Compliance**: 17+ / IARC rating (blood on by default); privacy
  policy and Data Safety form once SDKs land (game_log.gd records device
  model, CPU and locale locally).

### Nice to have
- [ ] Per-frame allocations (police_manager.gd filters two arrays every
  physics frame).
- [ ] Neighbour scans over whole groups (humanoid.gd, vehicle.gd,
  pedestrian.gd): fine at 18 pedestrians and 8-18 cars, won't scale to
  GTA-level density.
- [ ] LOD for city cells (people already have it, body_kit.gd).
- [ ] Precompile shaders (mesh_builder.gd compiles at runtime; possible
  first-use hitch, unverified).

### Known gaps the repo's own notes admit
- Milestone 2: random-event set and a playtest (MVP_DESIGN.md).
- Tilt steering untested on a phone (HANDOFF-world-v3.md).
- Ultra stutter fix inferred, not measured (PR_DESCRIPTION.md).
- Traffic density needs a phone frame-time check (HANDOFF-0.23-traffic.md).
- People LOD by quality preset and the mesh-cache prewarm (HANDOFF-0.24).

### Already solid (no rework needed)
- Cell streaming: worker-threaded, distance-based, 105 m load and 150 m
  unload radii.
- About one draw call per cell, car or person; MultiMesh for lenses,
  blood, fx, birds and puffs.
- Seeded, deterministic generation per cell; no global RNG.
- Code quality: about 8.3k typed variables against 273 untyped.
- Traffic signals, IDM following and siren yielding, each with tests; 137
  headless integration tests in all.
- Arcade vehicle model per class; four quality presets with resolution
  scale; per-finger multi-touch and gamepad mapping (controls.gd); a good
  in-game logger with hitch snapshots.
- About 6 MB of assets and data (no Play Asset Delivery needed yet); no
  brand or licensing problems found; no committed secrets.

### Suggested order
1. Release defaults, save hardening, safe area, store-ready build,
   licences screen, min-spec re-measure.
2. Loading screen and boot, parallel streaming.
3. Audio.
4. Ads, billing, analytics, crash reporting, cloud save, consent.
5. Generalize the city generator and the world pipeline (before city 2).
6. Mission tooling and localization, then the core crime loop content.

## Wednesday, Oct 28, 2026: NPC interactions, conversations and daily routines

Status: **not started** (later; Sachin: "Add this to todo as it is not important as of now").
Sachin: "Also, add NPC interactions, dialogues to start with them, and each NPC should have a
routine of their own, so player can notice then doing things and also explore what they do."

- Talk to any NPC: an interact prompt near a person opens a short exchange (greet, ask, provoke,
  buy, ask directions); lines come from the dialogue plan's line table (`DIALOGUE_VO_PLAN.md`,
  phases 0, 1 and 3).
- Daily routines: each NPC gets a home, a job or school and a schedule (sleep, commute, work,
  lunch, errands, evening out) on the game clock, so the same people turn up at the same places
  and the player can follow one and see where they go and what they do.
- Situation behaviour (`npc.gd`, `senses.gd`) stays on top: a routine pauses for danger, rain or
  a crowd, and resumes after.
- Cost: plan it after dialogue phase 0; routines need persistent NPC identities beyond the
  streaming bubble (a few hundred named locals per district, simulated cheaply when off screen).

## Later expansions: parks, fairs and amusement parks

Status: **later expansions** (Sachin, 2026-10-28: "Add parks, fairs of different kinds, amidement
parks, roller coasters etc in later expansions.")

- Extends package 32 in `ACTIVITY_ROADMAP.md` (a travelling fair on Liberty Green and a fun pier
  with a coaster on Brisa Beach).
- Parks of different kinds: city parks, waterfront promenades, skate parks, dog parks, state and
  national parks with trails.
- Fairs of different kinds: county and farm fairs in Golden Flats, street fairs and food festivals,
  carnival in the Quarter, a seasonal travelling midway (on the weather and calendar plan).
- Amusement parks: a full theme park with roller coasters, a Ferris wheel, drop towers, water
  rides and dark rides, rideable by the player.

## Wednesday, Oct 28, 2026: dialogue and voiceover plan

Status: **not started** (plan written). Sachin: "Also, plan meticulousyl and thoroughly for
immaculate, fully realistic player, and NPC dialogues, during free roam or during missions, and plan
voiceovers too in the late stages of the game. Or see how rockstar and other studios famous for open
world games plan such things and then add the same to our TODO."

- Plan, with studio research and sources: `DIALOGUE_VO_PLAN.md` (sections 1 and 13 first).
- Core: every line gets an ID in a data table from day one; a rule matcher (most specific rule wins,
  with cooldowns and memory) picks lines; one speech manager owns priority, interrupt and resume.
- Text first, voice last: barks and subtitles now, non-verbal sounds next, recorded VO only after
  the script is locked. No cloned or AI voice of a real actor without written consent and pay.
- Phases (effort in sessions):
  - [ ] 0. Line table and build tool, fact store, selector, speech manager, story box, bark
    bubbles, Dialogue settings; m01-m03 moved to line IDs (3-4)
  - [ ] 1. Ambient barks wired to `senses.gd`; bump and carjack lines; overheard conversations;
    repetition metrics and lint in tests (3)
  - [ ] 2. Conversations with interrupt and resume; mission barks; phone calls and messages from
    the table; retry variants (2-3)
  - [ ] 3. Jules's barks; GREET / PROVOKE / CALM DOWN; NPC memory and faction reputation (2-3)
  - [ ] 4. Writing pass for all of Act 1, reviewed by Sachin (4-6)
  - [ ] 5. Shot generator for in-engine scenes; choice panel for missions 6 and 13 (2-3)
  - [ ] 6. Localization pipeline and a first language (2, plus translator time)
  - [ ] 7. Non-verbal efforts for every voice type; radio DJ and news rules (2)
  - [ ] 8. VO pilot: casting, main cast for missions 1-3, Ogg pipeline, asset pack (3-4, plus
    studio time)
  - [ ] 9. Full Act 1 VO, cutscene mouth shapes, dubs if chosen (external, months)
- Open questions for Sachin are in section 14 of the plan (rating, languages, VO budget, AI voice
  stance, fixed or custom Jules).

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
