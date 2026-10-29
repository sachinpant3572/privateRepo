# PR #2: full description

The pull request's own body holds only the latest release; this file keeps the whole description, kept up to date with each release.

This PR adds the concept, the world, the map, the act 1 missions, the MVP design, the top-down games research and a playable Godot build of **Solvera**, a free-to-play, classic top-down (3/4 view) open-world crime game for Android and iOS.

**`GANGSTAR_CONCEPT.md`**: the full concept, the design pillar for high replayability and retention, and the assessment.

**`WORLD_BIBLE.md`** (names approved): tone, history, the cities (four since world v3, with Porto Brisa as expansion 1), the countryside, Isla Serena, transport, factions, the cast, the four-act story spine with three endings, and legends for hidden content.

**`WORLD_V3_PLAN.md`**: the four-city state and the expansions (see *World v3* below). Phase 2 is built (see *World v3 phase 2* and *Road-square plots* below).

**`ACT1_MISSIONS.md`**: act 1, "Homecoming", in Bellerive: 13 story missions that double as the tutorial, approach choices, and the three-way finale. Missions 1–3 are playable; the doc notes where the demo differs from the outline.

**`INTERIORS_SERVICES_PLAN.md`**: the plan for places you can walk into and services (shops, food, garages, fuel, gyms and martial arts, police stations, transit and road types), with decisions D1–D7 and phases 0–6. Phase 0 is built (see *Interiors phase 0* below).

**`BRANDS_AND_PLACES_PLAN.md`** (new, plan only): enterable places for every major category in every district, and a roster of about 220 fictional brands by tier and price, with costed options (see *Bellerive build-out* below).

**`ACTIVITY_ROADMAP.md`** (new, plan only): what GTA V, San Andreas and MadOut2 offer against Solvera today, and 27 costed packages ordered by how much livelier each makes the city per session (about 57 sessions in all; a first wave of packages 1–11 is about 17). It includes an arcade and gaming café framework with five original games, and the open decisions.

**`HANDOFF-wealth.md`**: homes by land value and wealth, six household tiers from the poorest to owners and CEOs, and how wealth shows (lot size, privacy, cars, upkeep, towers with penthouses). Phase 1 is built (see *Homes by wealth* below); phases 2–3 are plans. Bellerive keeps its planned size (Sachin's decision, Oct 28).

**`ACTIVITY_IDEAS.md`** (from a parallel session, plan only): a catalogue of activities to keep players busy.

**`HANDOFF-camera-demo.md`**: the camera options demo (see *Camera demo* below).

**`HANDOFF-perspective-camera.md`**: the perspective camera that was adopted (see *Perspective camera* below).

**`HANDOFF-heading-camera.md`**: the camera that turns with the car (see *Camera turns with the car* below).

**`TODO.md`**: a new high-priority entry lists what players disliked in GTA Chinatown Wars, with Solvera's answer to each, research on the iOS and Android ports' patches, and the work still to do.

**`reference/`**: research for the game:
- the top-down games reference bible: four sourced dossiers, a main volume with 25 proposed changes, and a searchable reader page built by `reference/build_viewer.py`;
- **`MAP_BUILDING.md`**: research on city map design (Lynch, grids and superblocks, the New Orleans crescent, Vice City, Chinatown Wars, procedural streets), plus a section on **how GTA and Watch Dogs built their cities**, and the rules and measured results of map v2;
- **`world/`**: research for world v3 (San Andreas; GTA V and VI; Vice City, GTA IV and series systems; the real cities), with a synthesis in `world/README.md`, and `california_topdown.md` for the California street plan.

**The world map**: `game/data/world_map.json` and `game/data/missions_act1.json` drive the game, the rendered maps and the interactive atlas. `game/data/country.json` (generated) holds the countryside round Bellerive.

**`MVP_DESIGN.md`** records these decisions:
- Godot 4 as the engine; a perspective top-down camera since Oct 28 (the classic 60° view stays in Settings), turning with the car by default (North up stays in Settings).
- **Look** (Oct 27): stylised but modern and detailed, replacing the earlier toon look (see *Modern look* below).
- **Free-to-play**, with guardrails.
- **Milestone 1 passed**: 120 fps on a Galaxy S25 Ultra and 30 fps on a low-end phone.
- **Characters**: code-built skeletal characters stand in until AI-generated models (no credits spent yet).
- **Map v2** (Oct 27): the street graph below replaces the warped grid.

**`game/`**: the Godot 4.7 build, milestone 2 (the vertical slice).

*Perspective camera* (Oct 28; Sachin: "Keep top-down, but switch the camera to true perspective, the way GTA Chinatown Wars does it", then on the options for towers blocking the view, "Yes lets build this as best as possible", then "Give me a setting to change camera angle too ... but also give option to reset the camera angle and zooming"). Decisions, measurements and traps are in `HANDOFF-perspective-camera.md`.
- **Perspective by default**, north up, with a 35° lens. Settings > View switches back to the classic flat 60° view.
- **Tilt by sight**: every 0.25 s the camera tries 65–85° and takes the lowest from which the player and the open ground round the view are in sight. It tips up at once only while the player is hidden, waits 0.75 s when only ground is hidden, and eases back down after a 1.5 s hold. Downtown the hero is hidden 7% of the time (18–20% at a fixed 65°, 20% in the classic view); among low buildings the camera stays at 65°.
- **Speed zoom-out and look-ahead**: driving flat out, the view widens to 62 m and leads the car by up to 1.1 s, capped so the car stays on screen. That shows about 100 m of road ahead east-west and 60 m north-south on a 20:9 phone.
- **Streaming**: the city loads round the middle of the screen as well as round the player.
- **See-through buildings**: buildings that still hide the ground round and ahead of the player turn into a pale, dithered ghost (31% of pixels) instead of a hole, at the same cost. The view band never ghosts roads or hills. Character outlines and hidden roofs indoors stay as they were.
- **Back-out over towers**: the camera steps back along its line until it is clear and narrows its lens to keep the framing; shadows stretch to match.
- **Settings**:
  - Distance (was Zoom): 60–130%;
  - Angle: 40–90°, the camera's lowest pitch;
  - Tilt near towers: on or off;
  - Reset camera: 65°, tilt on, 100% (and, since 0.18, Drive zoom-out 100%).
  
  Below 65° the city loads further out and shadows reach further.
- **Not built, on purpose**:
  - speed does not steepen the tilt: at 75° the road ahead north-south fell from 62 to 57 m;
  - the camera did not rotate in this step; since the next one it turns with the car (see below);
  - flying waits for aircraft.
- **Review fixes**:
  - whole shadows, hills never cut, and a cached tower search;
  - pitch hunting at speed: 9–12 turn-backs a minute, now 2.8;
  - then a hold that kept the camera steep in low-rise districts: 35–44% of the time, now 7–11%;
  - tests that could not tell the old picker from the new;
  - a streaming check that depended on thread timing;
  - rooms and shadows at low angles.

*Camera turns with the car* (Oct 28; Sachin: "Is the camera moving in the same direction as the car or the player, same as happens in chinatown wars?", then "Research more on this, I am sure you will come up with much better design while keeping the same Camera movement as chinatown wars."). Decisions, measured numbers and open points are in `HANDOFF-heading-camera.md`.
- **Follow by default** (the setting read "With car" in 0.17): in a car the view turns so the car heads up the screen and looks about 72 m ahead (sedan, 3.5 s at speed). It turns at most 90°/s and settles about 1 s after the car finishes its turn. In a slide it leans toward where the car is actually going. It holds still in a spin (more than 90° of slip), while reversing and below 3 m/s, so it does not whirl round. Settings > Camera turn keeps North up as an option.
- **On foot** (0.18) the view follows the way the player walks, calmer than in a car (see the 0.18 notes below). Standing still, it eases to the nearest compass direction (the city grid runs north-south almost everywhere). Tapping the minimap's N re-centres it: behind the car when driving, north up on foot. Inside places the view is north up.
- **Entering a car** turns the view to the car's heading at once, even when the car is parked.
- **Stick steering when the view turns**: the stick steers relative to the car (up is gas, left and right steer, down brakes and reverses). Full lock lifts off the gas.
- **Minimap** turns with the view and its N marker shows north.

*Camera settings and on-foot follow* (0.18, Oct 28; Sachin: "Game runs smoothly at 120FPS, but the zoom out once the car starts driving is too much. Keep it default but give me settings to change the camera distance, and angle please. Also, camera should follow the player not the car, right now it only follows the car. And there is no Setting icon in the build you shared."). Decisions H-13 to H-18 in `HANDOFF-heading-camera.md`.
- **Gear button** on the HUD, under the clock and always shown (the PHONE button only shows once the story unlocks the phone; until then the gear takes its slot). It opens Settings straight away, and its back button closes the phone. It does not count as checking the phone for mission 2.
- **Settings > Camera**, with - and + buttons that stop at the ends:
  - Distance: 60–130% (60% and 70% are new);
  - Drive zoom-out: Off, 25, 50, 75 or 100% (default 100%, the 0.17 framing). It scales how far the view widens with speed, and the flattening with it, so Off keeps the on-foot framing while driving. The look-ahead is still capped to the frame, so the car stays on screen;
  - Angle: 40–90°.
- **The camera follows the player on foot**: walking, the view turns toward the way the stick sends the player (not the velocity, so a shove or a wall slide does not swing it). It is calmer than in a car: turns under 20° are ignored, it closes half the gap in 0.6 s, and it turns at most 60°/s.
- **The stick on foot**: its directions are read in the view as it was when the thumb went down, and held while the thumb stays put, so a sideways push walks straight instead of circling as the view follows. Swinging the thumb more than 25° quickly reads it in the view as it is now; a slow drift only bends the walk by the drift, and a thumb brushing the dead zone for under 0.2 s keeps the frame. This replaces 0.17's catch-up, which would spiral with the view following the walk. Letting go mid-turn eases the view to a stop where it is.
- **Settings > Camera turn: 90° turns** (Sachin: "Give an option to stop Camera from following the player if the player does not move full 90 degrees, just wwnt to test if the wobbly camera can be fixed"). The view holds still until the car, or the walk, has been at least 80° off it for 0.4 s, then turns a whole quarter, square to the street grid; steering, lane changes and dodges never move it. Getting in, the compass and a snap square it too. The button cycles Follow → 90° turns → North up (saved "car", "steps", "north").
- **Not built, on purpose**: no automatic flip when reversing, no lazy mode, and the camera does not look 100 m ahead (that would load about 1.6x as much city). Reset camera leaves the turn mode alone.
- **Shots**: `SHOTS=view` adds 84 shots that drive east, south and west with the view turning.

*Settings page* (0.19, Oct 28).
- **Settings is a full-screen page** with tabs (Camera, Graphics, Controls, Game), a hint under each setting, and a live preview beside the list while the game stays paused. The preview follows every camera change, and a "Preview: Driving fast" toggle shows the Drive zoom-out on foot.
- **The paused world stays current in the preview**: clock skips relight it, weather changes at once and rain falls, headlights switch, and wider views stream in with the game's own threaded streaming.
- **FPS limit**: 30, 60, 75, 90 or 120 (default 120).
- **Easier scrolling**: buttons pass drags to their list, a drag that becomes a scroll cancels the button under the finger, and the scrollbars are wider (36 px).
- **"Tilt near towers" is now "Look down near towers"**, and its hint explains it.
- **Headlights drape over hills**: a ground-following shader reads the terrain height, so they no longer vanish on slopes at night. Headlights also switch off when the player gets out of a car.
- **Tests**: 787 checks pass. APK: `solvera-0.19-settings-debug.apk`.

*Bellerive build-out* (0.20, Oct 28; Sachin: "Yes please, also expand belleriv as we discussed earlier"). Option A: the city keeps its planned 4.7 km² outline, and the suburbs inside it are brought to city grade. Decisions and traps are in `HANDOFF-bellerive-expand.md`.
- **People walk the suburbs**: the generator cuts sidewalk loops round every suburb block (`walks` in `country.json`), and pedestrians and cops use them like the city's.
- **Live parked cars at suburb homes**: the drive and garage cars on home lots are live parked cars the player can get into, and each keeps its home's wealth tier (a T4 drive gets a T4 car). Spots open and close with their tiles.
- **Suburb places**: up to 16 diners, general stores, shopfronts and strip malls in the suburbs are enterable, with the door at the building's door.
- **New home kinds**: `res_tower` (T5, penthouse crown and roof pool), `midrise_condo`, `cheap_block` (T0-T1 walk-up), `exec_house` (three-car garage and pool) and `gatehouse` (estate gate with a boom). The shady kinds (motel, liquor store, pawn shop, check cashing, barred bungalow, burned lot) can now stand on country lots.
- **Placed by land value, suburbs only**: cheap blocks and the shady strip on the poorest east side frontages, exec houses where the Heights flats and the east side are dearest, residential towers on the Brisa Beach front, mid-rise condos on the shore, and a gatehouse inside 12 of the 19 estates. The suburbs now run T0-T5 74/285/707/393/137/19 homes. Not done: "lots sized by tier inside the house kind" (the exec houses carry the wide lots), and city-side placement (Midtown towers, Wards blocks) is left for later.
- **Bayou town bars**: 40 of its 121 lots had become bars; a shop or bar now stands at least 220 m from another of its kind there. Regenerating shifted other towns' lot counts too (Larkspur 33 to 25 lots, Wheaton's bars 2 to 7).
- **Next, plan only: `BRANDS_AND_PLACES_PLAN.md`** answers "Build some enterable buildings too ... one for every major category ... create brands for different things ... Research well and then recommend": 19 place categories, an anchor table of about 42 enterable places across all 17 districts, about 220 fictional brands by tier and price, cost options, and open questions. Nothing in it is built yet.
- **Tests**: 806 checks pass. APK: `solvera-0.20-bellerive-debug.apk` (version code 20).

*0.23: vehicles, blood, smoke, traffic, hills* (Oct 28–29; Sachin: GTA IV-style "collision, suspensions and damage physics" by vehicle class, "bloodwork", "convertible cars", exhaust and tyre smoke and marks by type and US emission norms, realistic traffic lights and traffic, a screen-shake slider, and "more variety of trees, in the mountains, bushes, shrubs" with "greenary + dry land a mix of both"). Decisions and traps are in `HANDOFF-0.23-*.md` (vehicles, models, blood, exhaust, settings, traffic, flora).

- **Vehicle classes** (`vehicle_classes.gd`): two-wheeler, cycle, hatchback, sedan, SUV, MUV, truck, performance and three-wheeler. Each class sets its own suspension (spring Hz and damping, so bodies bounce and overshoot), roll and pitch, crumple and damage, and mass. Riders are thrown off over a crash speed. Hard hits dent the mesh near the contact point and throw off a panel. Heavier vehicles shove lighter ones. Boats, ships and aircraft come later; their class rows are reserved.
- **New models**: the Vesper Lido roadster and Aurelle Riviera cabriolet, both convertibles whose roofs open and close; the Kaito Septa seven-seat MUV; and the Ardeno Corso bicycle. A bicycle never burns.
- **Blood** (`blood.gd`): spurts from melee and vehicle hits, and ground drops, smears and pools that fade. All marks are one pooled MultiMesh, so they cost one draw call. A pool grows under the dead. `bleed()` is ready for guns. Settings > Game has a Blood toggle.
- **Exhaust and tyres**: each kind has its own fuel, tailpipes or stacks, and tyre width. Old diesels and smokers are rolled by district poverty. Cold starts give off vapour. Drifts and locked brakes raise tyre smoke and leave marks. ABS cars leave only faint marks when they stop.
- **Traffic**: signals run phases with a yellow, and flash late at night. All-way stops are first come, first served. Cars follow at a gap (IDM) and keep to speed limits by road class. Density and the mix of vehicles follow the district and the hour, with surges, and traffic yields to sirens. Zebra crossings match each district's style. Traffic spawns just off screen: the ring moves out with the edge of a wider view instead of scaling with it.
- **Hills**: 13 plant kinds (trees, bushes and shrubs) are placed by height, slope, aspect and moisture. Ground is green on north faces and in canyons and dry gold on south faces; a hill sample is about 63% gold and 37% green. Low quality draws half the cover.
- **Fixes**: vehicle meshes are built at load; the x-ray works in the classic view; corners are looser, with a steer-and-brake drift; the hero stays visible (bus stop) and mission intros open on the hero's face; screen shake has a slider (default 50%), and multi-option settings are sliders.
- **Tests**: 1438 checks pass, 0 failed. APK: `solvera-0.23-debug.apk` (version code 23).

*0.24: grounded cars, brakes by class, new people* (Oct 29; Sachin: "See the car, it seems to be in air even when brakes are applied", "all cars take the same amount of time to brake and handle on curves", the red sports car "takes a lot of time to brake and again has stiff handling", "the human models are very outdated and primitive"). Decisions are in `HANDOFF-0.24-fixes.md`.

- **Floating**: hill ground is drawn 0.26 m under the terrain height off the paving, but cars and people stood at the terrain height. Movers now drop with the ground (`Terrain.drop`), eased off the paving.
- **Brakes**: braking while steering (from 9 m/s with a third of the lock) starts a drift, and the drift scrubbed speed at a flat 6 m/s² whatever the car, so every car braked alike into corners (the sports car took about 1.9 s from 90 km/h). The scrub is now 0.65 of the car's own brake: from 90 km/h in a braking drift the sports car stops in 0.73 s and a sedan in 0.98 s.
- **Handling by class**: each class row has brake, cornering, turning and wheel multipliers for the player's car (traffic is unchanged). The performance class brakes at 43.7 m/s² and grips 33 m/s² in corners (a sedan: 20.9). Straight stops from 90 km/h: sports 0.43 s, SUV 0.75 s, box truck 1.23 s.
- **People**: smooth-shaded bodies, one lofted torso instead of two creased balls, hands with four fingers and a thumb, rounded shoes (sneakers, dress, boots, heels, slides), and faces with eye whites and irises, brows, a nose, lips and a chin. Same rig and outfits, one draw call a person; about 2440 triangles a person (was 790).
- **Fix**: breakable props no longer log a `get_meta('glow')` error.
- **Review**: one independent review. Its main finding was that the first brakes fix (ending the coast) changed nothing; the real cause, the flat drift scrub, is fixed above and covered by a new test. Also fixed from it: the head is one lofted shape, so no jaw seam shows across the cheeks, people ease onto the lower ground instead of jumping at the paving edge, and shoved cars, blood and car debris sit on the lowered ground. Still open, minor: a small spring bounce when a car crosses a kerb onto the lowered ground.
- **Tests**: full suite 1453 checks passed, 0 failed (headless, after the review fixes). APK: `build/solvera-0.24-debug.apk`.

*0.25: people v2, real bodies* (Oct 29; Sachin on the hybrid plan: "Yeah lets do this. But will this affect the Framerates?"; then "The human shoulders are too high, looks like a deformity", body types by height, weight, muscle and age, "a bit chubby, then fatty, and then super fat", fat in the faces, the backs, and "Ensure that our hero has much better structure and looks than the NPCs"). Decisions are in `HANDOFF-people-v2.md` (history in `HANDOFF-people-v2-archive.md`).

- **Bodies**: MakeHuman's CC0 body (base mesh, macro targets, rig weights), posed and decimated offline by `game/tools/people/build_people.py` into `game/assets/people/body.bin` and `body.json`. Crowd mesh: 1502 vertices, 3000 triangles near and 1000 far; the hero has its own denser mesh (5002 vertices, 10000 near, 3000 far). Same skeleton and animations as before; shoulders now sit under the chin (male chin 1.51 m, shoulder top 1.49 m).
- **Body types**: per gender, shapes for base, fat, thin, muscle, old, young, tall and short, blended per look. A body-type table picks normal, skinny, chubby, fatty, super fat, muscular, short, very tall, just-18, mid-aged, old and mixes. Fat fills the belly, hips, limbs, neck and cheeks; wide bodies hold their arms out so they don't cut into the sides.
- **Clothes**: tops, sleeves, bottoms, socks and the beard are regions of the body, cut cleanly at their borders (level waistbands, a neckline per angle) and pushed out by the cloth's thickness; the kit's prints, collars, belts and shoes are warped onto each body. Covering hats flatten the hair under them. Clothes are still close-fitting; loose, layered garments are the wardrobe work (0.26, `HANDOFF-wardrobe.md`).
- **Frame rate**: a crowd person is about 4230 triangles near on average (was 2440), the hero about 11200; 20 people are about 85k of a 180-200k frame budget, and the far LOD is under half. Building a person takes about 5 ms (hero 8-14 ms) with cached cut recipes, against 25-85 ms before the review.
- **Review**: two independent reviews. Fixed from them: seat and ride heights follow each body's hip height; build time (above); hair through hats; T-junction cracks between clothing regions; ragged lip, beard and scalp lines (margins now exported with the body data); a jagged neck edge under collars; the recipe cache holds 256 dresses (at 64, 30% of crowd spawns missed it and took 12-13 ms). Known and minor: about 18 open edges at shoe height on shod looks (hidden by the shoe), and collars can sit up to 8 mm inside the back of a woman's blazer neck.
- **Tests**: full suite NNNN checks passed, 0 failed (headless, after the review fixes). APK: `build/solvera-0.25-debug.apk` (version code 25).

*0.22 fixes* (Oct 28; Sachin, after playing 0.21 on an S25 Ultra: stutter on Ultra, stiff corners, the see-through tint on open road, the stuck 18-wheeler in his video, and "enable a Logger in the game"). Causes, fixes and traps are in `HANDOFF-0.22-fixes.md`.
- **18-wheeler stuck and the view shaking**: spawns checked other cars by centre distance only, so a parked car could appear under a 15 m trailer. Traffic, parked and police spawns now check the full rotated footprint (`footprints_meet`), and a police car whose junction is taken tries a spot up the road. The camera's lead and turn and the HUD speed read the car's real flat motion, eased over 0.12 s, not the commanded velocity (which showed 22 km/h on a pinned truck). A parked or lighter car sunk into another is moved out (`shove`) and set back on the ground. Verified: the overlap and the velocity spikes. Inferred, not reproduced headless: the stuck-and-shaking state itself.
- **Softer corners**: turning grip is 1.5x (`CORNER_GRIP`) for every car except 18-wheelers, which keep the old grip so the trailer does not swing into walls. Steering eases in faster (0.22 s) and the tightest circle is 3.2 m.
- **See-through tint only when hidden**: the silhouette was always on, and its stencil also drew where one limb is behind another. Now it shows only when rays from the legs and chest to the camera are all blocked by a building or a vehicle (checked every 0.12 s). Lamp posts and trees never trigger it. Inside the cutaway hole, where walls are already cut away, only vehicles count. The silhouette shaders compile at load, not on first use.
- **Ultra stutter**: vehicle meshes are cached per model and paint, not rebuilt for every car. Ultra keeps 4x MSAA and now runs the same light budget as High (2 car lights, no headlight shadow). This is inferred; the logger's fps rows from the device are the real check.
- **Logger** (Settings > Game > Log, and a BUG button on the HUD): the log records a header (device, GPU, settings), a snapshot once a second and on every hitch, events (car in and out, crashes, hits, deaths, wanted level and more) and every engine and script error. Report issue marks the moment and opens Export (the Android Save dialog); Copy log puts the newest 200 KB on the clipboard. See `game/LOGGING.md`.
- **Called cab never arrived** (found by the suite): its curb stop could sit on a parked car or on the player, so the cab braked short. The stop now moves along the street, and a cab braking for the player on its last leg counts as arrived.
- **Review**: two independent reviews ran. Fixes from them: the shove re-grounds the car; 18-wheelers keep their grip; wrecked cars leave the x-ray list; the cab arrival rule; and logger tuning (hitch threshold, the 3 nearest vehicles, real speed). Still open, all minor: mesh-cache prewarming at load, and the orthographic view's aim for far silhouettes.
- **Tests**: 1130 checks pass, 0 failed. APK: `solvera-0.22-fixes-debug.apk` (version code 22).

*Realism pass* (0.21, Oct 28; Sachin, after playing 0.20: lights, driving, camera, sky, quality presets, models, animation, roads and boundaries, "Test verify everything thoroughly"). The main session built lights, driving, camera, graphics and the Look up sky view. Four agents (VEH, CHAR, WORLD, SKY), each in its own worktree, built the rest, and the main session merged them. Decisions and traps are in `HANDOFF-realism-pass.md`, `HANDOFF-realism-char.md` and `HANDOFF-realism-sky.md`.
- **Lights light the scene**: headlights are real spot lights (32° cone, 30 m) that light the road, props and people. Street lights and gas lamps are real lights too, and they go dark when knocked down. A police car's bar alternates red and blue. The renderer lights each mesh in extra passes, so the quality preset sets how many real lights may be live: cars/lamps 1/0, 1/2, 2/4 and 3/4 from Low to Ultra, plus a shadow on the player's headlight on Ultra. The police bar runs only on High and Ultra. The ground-glow decals stay as the cheap far layer.
- **Driving**: every driver's turn rate is capped by grip (per-kind cornering g over speed) and a 3.5 m tightest circle, and the player's steering eases in over 0.18 s. Top speeds are now close to real cars' (sedan 112 km/h, super 173 km/h, scooter 72 km/h).
- **Camera, no more dizziness**: turning with the car is capped at 45°/s and 60°/s², with a 0.6–0.8 s half-life. Only deliberate swings (getting into a car, compass or north-up) use 90°/s. Once you drive off in a new car, its swing calms back to the 45°/s cap.
- **Graphics quality**: Settings has Low, Medium, High and Ultra presets, and toggles for bloom, shadows, anti-aliasing, vivid colour and real lights. Changing a toggle marks the preset "High *". Bloom is additive at 0.45. Low draws 3D at 80% resolution. Fog and haze were rejected, because from top-down distances they wash the whole view.
- **Sky**: a sky shader with a sun disc, a moon (it starts as a waxing crescent), and stars dimmed by light pollution from the map. Downtown keeps about 8% of the stars and the suburbs about 20%; the hills, beach and desert show 80–90%, including the Milky Way. City glow shows as domes over the towns. Birds fly in flocks that land, perch and flee in one draw call; there are none at night or in storms, and bats come out at dusk. The top-down camera rarely frames the sky, so a **Look up** view (HUD SKY button or L, on foot outdoors) shows it.
- **Vehicles**: every car now has its cabin painted on the glass, grilles, mirrors, trims and panel lines. Bikes get forks, frames, spokes and seats. New kinds: a tuk-tuk and a cargo trike (three-wheelers), a 10-wheel tipper, and an 18-wheel semi; the box truck is the rebuilt 6-wheeler. The semi sets off only on streets with two or more lanes each way and turns only into them.
- **Hero and NPC models**: better heads, hair, hands, shoes and layered clothing, with body types by category. Jules is about 880 triangles; the street average is 789 per person (budget 1035).
- **Animation and reactions**: smoother walk, run and sprint cycles; idle variants; and situational poses (flinch, duck, cower, flee, point, film on a phone, call the police, hands up, hail a taxi, sit on a bench, lean, smoke, chat, limp, get up, cheer, dodge a car, hurry in rain). `senses.gd` broadcasts what NPCs see and hear (a 65° sight cone, a hearing radius, 3 m all-round awareness, no raycasts) to ten categories of people with four personalities. Each reacts 0.15–0.6 s after the event, by distance and temperament. Witnesses call the police only for a player crime.
- **Roads**: each road gets a surface from its own hash: fresh, worn, washed-out, concrete, or white or brown tiles in the city, by district; fresh, worn, washed-out, gravel or dirt in the country, by road class. Each cell is still one draw call. Each district has two or three **roadworks** on four- and six-lane streets: the curb lane is dug up, with cones, breakable barriers, a ROAD WORK AHEAD sign, and a roller or digger. Traffic keeps one lane fewer there, so it never steers into the pit; taxis and parking keep clear and the sidewalk goes round. There are no roadworks in the country, because closing one of its two lanes needs stop-and-go traffic control.
- **Boundaries and gates by household**: each home gets its own front and back boundary (open, broken, chain-link, ply, wire, block, picket, low wall, slat, hedge, iron, stone, rendered wall, brick) at 0.6–2.6 m. Its gate can be none, swing, double or sliding, with mixed widths, heights and walk gates. The pick follows wealth tier and place: poorer homes lean open and makeshift, richer ones tall and masonry, and stone is used in the mountains. Gates are drawn open, so the drive or path into every home stays clear.
- **Brands plan**: Sachin's answers are recorded in `BRANDS_AND_PLACES_PLAN.md` §9. Places open from the start, by cash or after missions; there are several malls, each with its own character; and a trademark knockout search will be run on any name before it goes to merch. The A/B/C and B1/B2 picks (§10) are still open.
- **Review fixes**: one independent review ran. Fixed: the camera's quick swing now ends on driving off; 18-wheelers turn only into wide streets; the police bar is held to the light budget; birds come back after you leave an interior. The suite's time cap rose from 300 s to 450 s.
- **Tests**: 1080 checks pass, 0 failed. APK: `solvera-0.21-realism-debug.apk` (version code 21).

*October 28: civic centre, roundabouts, the Bellerive Hills, wide roads, breakable props, farmland, farm homes and routes.* Decisions, rejected options and traps are in `HANDOFF-roads-mountain.md`, `HANDOFF-wide-roads.md` and `HANDOFF-routes.md`.
- **Civic centre on the grid** (Sachin: "re-cut the civic grounds so the last edge street can carry on out ... add more rounabouts, some highways if there are less. Also, fix the Taxi test. Also build the mountain near it"):
  - City Hall's grounds are one grid block, and its four sides are through streets (the Capitol Drive ring is gone);
  - four more roundabouts: Liberty, Aurum, Cypress and Harbor circles;
  - every drivable edge street carries on out of the city; the test now requires all 70 of 70.
- **Highways**: the Bellerive Beltway is a freeway, and the new Canyon Freeway runs from it through the hills' saddle to Route 1.
- **The Bellerive Hills**: a drivable mountain north of the Beltway, like the Santa Monica Mountains above LA.
  - A height field in `country.json`; cars, people and police follow the ground.
  - Crest Drive on the ridge, Coyote Canyon Road with hillside houses, Observatory Road with a hairpin, a fire road to the radio masts, the hillside letters and chaparral.
- **Taxi**: a called cab comes round the block to the player's side (all 153 start points now stop within 6.6 m). The cab waiting for you is boarded even when another car stands nearer; that was the intermittent `test_taxi_phone_call_and_skip` failure.
- **Wide roads** (Sachin: "4 cars can drive around in the same road at once comfortably, 2 in one lane 2 in opposite lane"):
  - boulevards have 6 lanes and a median; avenues and streets have 4 lanes and a parking strip;
  - the Beltway has 8 lanes and highways 6;
  - old-town inner streets, the quay, mountain roads, lanes and tracks stay narrow;
  - traffic picks a lane and keeps to it.
- **Breakable props**: lamps, signals, small trees, hydrants, benches, bins, signs and more fall when hit faster than 2.5 m/s, and the car keeps 82–92% of its speed (a hydrant gushes for 6 s). Big oaks, palms, bollards, power poles and fences stay solid.
- **Golden Flats farmland** (Sachin: "sprawling irrigation fields ... with major highways or espressways going through them, with shirtcuts in between, on paved and unpaved roads leading to farmhouses"): 24 centre-pivot circles, strip fields, canals, a section-road grid and an expressway through them, with paved and dirt shortcuts.
- **Farm homes**: big, small, ranch and adobe farmhouses and homesteads, in fenced yards, with three plans per size. Section roads never stop dead.
- **Routes to every home** (Sachin: "Ensure there are routes leading to all houses from the street or road, can be single lane but there should be routes, match the route textures to the building and surroundings"):
  - every home lot has a drive or walk out to the road, surfaced to match the house: concrete for suburban homes, gravel for farmhouses, packed caliche for adobe, terracotta pavers for the hacienda, a dirt two-track for the cabin, asphalt for apartments;
  - homes in clusters get an apron and a footpath to the shared track: planks for stilt houses, gravel for trailers, dirt for the rest. Trailers now face their track;
  - farmyard front fences open where each home's route leaves;
  - on hills the route bends from the house pad down to the road;
  - town rows facing the city meet the city's edge street;
  - a side blocked by rails or another lot sends the route out by the clear side.
  - The generator counts homes with no way in, and it prints 0: 1441 by drive or walk, 181 by cluster path, 19 by estate drive.
- **Routes review fixes** (two reviews):
  - trailer paths ran under the trailers;
  - route slabs floated on hill lots;
  - a route was still drawn over a rail bed on a blocked side;
  - the farmhouse inside Hollis Farm drew a second drive through the farm fence;
  - tests that did not reach a real tile build.

*Homes by wealth, phase 1* (Oct 28; Sachin: "the richer the people get the more bigger and private property they live in ... and the less money the person has the closeby they live"). Decisions, results and open points are in `HANDOFF-wealth.md`.
- **Country homes only**: city homes already follow their district.
- **Land value and tier** (`tools/wealth.py`): every home lot gets a value from its zone, the coast, lakes and river, height in the hills and nearness to downtown, less freeways, rails, industry and flood ground. A tier from 0 (poorest) to 5 (owners and CEOs) follows from it, with pockets of about 160 m, clamped to what the kind can be (a shack T0–T1, a house T1–T4, a mansion T4–T5, an estate T5). No lot moves.
- **How it shows** (`kits/country_kit.gd`): upkeep (faded paint, a tarp, boarded or barred windows, junk, a dead lawn), cars (beaters, sedans, luxury cars), privacy (chain-link, a board fence, a picket front, a hedge and front wall) and pools.
- **Results**: 1655 homes; mean value rises with tier, and private ground per household runs 81, 183, 371, 528, 544 and 5706 m² from T0 to T5.
- **Review fixes**: a T4 car on hill lots hung past the lot front (it now pulls into an open garage); the T4 hedge narrowed the drive gate; mansion cars overlapped; a tarp could overhang the roof.
- **Open, by design for phases 2–3**: ground rises with tier through the mix of kinds, not yet within a kind (phase 3 sizes lots by tier); the east side is nearly all T2; there is no dense poor block and no T5 tower yet.

*Camera demo* (Oct 28; Sachin: "Can you build a short demo of both options and show to me? Show it in three perspectives, player walking, driving a car and flying a plane"). Decisions and traps are in `HANDOFF-camera-demo.md`.
- `tests/camera_demo.tscn` records a 90 s video: walking, driving and flying past the Aurum Tower, each in the current top-down view, option 1 (the same camera in perspective) and option 2 (a third-person 3D camera).
- The prototype pieces: `perspective` and `zoom_override` on `top_down_camera.gd`, the new `scripts/chase_camera.gd`, and the streaming radii of `city.gd` and `country.gd` as static vars the demo widens.
- Option 1 was adopted (see *Perspective camera* above); full 3D is parked in `TODO.md`.

*Bellerive on a California street plan* (Oct 27; Sachin: "the streets look so diagonal ... rest all have bigger parallel roads. Check California's map from top down ... Also, add skyscrapers, monuments, all fictional, shady places, ghettos etc too", then "Ensure most of the roads are reaching the city end to end and then joining the highways ... they should not end abruptly or should not be short"). Decisions C-1 to C-9, the measurements and the rejected options are in `HANDOFF-bellerive-ca.md`; the research is in `reference/world/california_topdown.md`. This replaces the district angles of *Map v2* below.
- **One citywide grid** (`street_plan.gd`).
  - Arterial boulevards and avenues run north-south and east-west at uneven LA-like gaps. District streets split each superblock at shared fractions, so they carry on across the boulevards.
  - The old-town plaza grid is the one rotated grid, at 30°. Liberty Avenue is the one long diagonal, and River Road follows the water.
  - Measured: 83% of street length runs within 5° of north-south or east-west, and 96% runs on the two grids. Before, it was 17%.
- **Skyscrapers, monuments and shady districts** (`city_cells.gd`).
  - Gilt District and Midtown get skyline towers on big parcels.
  - Floodline Wards get run-down strips (liquor, pawn, check cashing, motels) wherever a parcel fronts an avenue, plus housing projects, barred bungalows and burned lots.
  - Ironwharf gets chop shops, scrapyards and abandoned warehouses with tent rows.
  - Gilt plazas get statues, and the Esplanade gets a memorial arch. All of it is fictional, with no brands.
- **Streets run end to end and join major roads** (`tools/build_country.py`).
  - **Through the city's edge.** City streets that reach the edge street carry straight on into the suburbs, to the Beltway, Sunvale Boulevard, Seabreeze Drive or the new Bayou Drive (since Oct 28, all of them; see above).
  - **Suburbs rebuilt.** The east side's cul-de-sacs became through tract streets, and the south shore's loops became a grid. Brisa Beach's cross streets end on Palmetto Row, now an avenue.
  - **The Ironwharf quay is drivable.** It is a 10 m road where there was a 3 m walkway, so the docks streets no longer dead-end at the water. Its cranes reach out over the water and it has street lamps.
  - **Dangling roads fixed.** Seabreeze Drive used to run past the Beltway at both ends, and Serena Causeway started on nothing. Both now end on roads; the Beltway now reaches Seabreeze Drive in the east.
  - **Measured:** no dead ends round the city (24 before). The causeway's exit over the Gulf is the world edge, as before.
    - Suburb streets with a major road at both ends: 55% of street length (28% before).
    - With each end on a major road, or on a street that has one at both ends: 86% (33% before).
    - Suburb streets under 150 m: 3 (40 before).
  - **Kept on purpose:** 8 short lines in the core and old-town seam connectors.
  - **Test.** A check requires the edge junctions to carry on out, and no dead end within 1100 m of the plan; farm lanes and tracks are exempt.

*World v3 phase 2* (Oct 27; Sachin: "go ahead with phase 2"). Bellerive's edges, streaming past the city window, the first countryside roads and towns, and taxis. Decisions P-1 to P-16, open questions and traps are in `HANDOFF-phase2.md`.
- **The window opens.** The city's edge walls and "road closed" boards are gone. The margin ring round the street plan is drivable, its silhouette blocks have colliders, and the country carries on past it. The street plan itself is untouched: it dumps identical to before, so blocks, landmarks and missions don't move.
- **The country** is a second streamed layer (`country.gd`, `country_tiles.gd`). It is generated offline by `tools/build_country.py` (Python and shapely, from `world_map.json` and the plan dump) into `data/country.json`. Tiles are 100 m, built on a worker thread, loaded within 130 m (ahead of the car you drive) and dropped past 210 m. The country covers:
  - the suburbs that fill the rest of Bellerive's rect: Magnolia Heights, Blackwater Bayou, the east side, the south shore, and **Brisa Beach** with Seabreeze Drive and Deco Row. Their grid streets run straight on from the city's frame-street junctions;
  - **Golden Flats**: Wheaton, Ridley Crossing, farms, grain elevators;
  - **Saltgrass**: bayou, the Gator Farm, airboats;
  - **Verdant Hills**: Larkspur and the vineyard (hills in look, not in height).
- **Roads**: highways, avenues, county roads, lanes, dirt tracks and trails, with markings, sidewalks and lights by class. There are bridges with parapets, power poles, fields, vines, ponds and trees by zone. The metro guideway and rail lines are scenery, with no trains yet.
- **Buildings** (`kits/country_kit.gd`, 41 kinds at phase 2): houses, shops, farms, the County Hospital, the gator farm, the vineyard, a cruise terminal and more. None carries text or brands.
- **One road graph.** Country junctions join the city's through `COUNTRY_BASE` ids, so traffic, police, the GPS, missions and taxis drive out with no changes of their own.
- **Edges**: the play area ends in a fence. Where a road leaves it there are storm-closure barricades (the Great Storm story gate). Banks, the coast and bridge parapets keep cars out of the water.
- **Moved landmarks**: phase 2 landmarks that sat inside the window moved just outside it, since the plan can't take new ones. These are Bellerive General, Torque & Tone, the seaplane base, Deco Row, the Brisa promenade and the cruise terminal.
- **Maps**: the state map bake draws the margin ring and every country road. The minimap past the window shows roads you can drive, and phase 2 pins now show.
- **Taxis** (`taxi.gd`):
  - Hail a passing cab (TAXI / T / B on the pad) or call one from the phone's Cab app.
  - Pick a landmark or town, then ride along or pay 1.5x to skip there.
  - Fares are $4 plus $3 a km.
  - Wanted players get thrown out. A cab that is stuck or wrecked gives up cleanly.
- **Scripted drivers** (taxis, the mission 1 getaway) now:
  - follow the line between their path points;
  - back off a wall they are pinned on and slide past it;
  - pass, on the left, anything that blocks their lane for 3 s.

  Before this, a car that ran wide out of a corner scraped the kerb props forever, and one behind a stalled car waited forever. That was also the cause of an intermittent population-test failure.
- **Review fixes** (two reviews):
  - Traffic rammed every storm barricade forever: the road's last stretch, behind the barricade, is now out of the drive graph, cut at the road's own dead end.
  - Ember Canyon Drive, cut off between two barricades, is out of the graph too.
  - Tiles now stream ahead of the car, not the seated player.
  - The cab's destination list fills in 8 rows a frame (it took about 96 ms all at once).
  - Scripted drivers no longer steer by a stale wall direction.
  - The wall test now checks that the car actually reached the wall.
  - "Ocean Drive" and "Collins Row" (real Miami streets) are now Seabreeze Drive and Palmetto Row.
- **Cost**: a tile takes about 5 ms and 2k triangles before buildings. The state-map bake went from 181 to 206 ms on desktop. Parked cars in the window sit in new spots, because the margin ring is drivable now.

*Road-square plots* (Oct 27; Sachin: "all plots are sold parallely, the only buildings that can be built like this are the ones for very wealthy people that also have gardens, sports courts, pools, big courtyard"). Decisions D-1 to D-12, research, open questions and traps are in `HANDOFF-plots.md`.
- **Why buildings came out diagonal**: landmarks, town civic buildings and the truck stop faced the nearest point of the buffered road edge. Near curves, junctions and road ends, that point lies off to the side. Fields sat on a world-axis grid, so even a square farm looked turned against them. Every lot now takes its yaw from the road piece it fronts and sits a fixed setback from it.
- **Plots** (new in `country.json`) are rectangles square to their road, with their parts laid out by the generator and drawn by `kits/grounds_kit.gd`:
  - **Estates** (Magnolia Heights mansions, Verdant Hills villas, the Hale Estate): a wall or hedge, a centred gate, a drive and avenue, mirrored parterres, a tennis court beside or behind the house, orchards, and tree rows. The mansion's own pool and fountain court stay. A house turns 45 degrees only on a square plot with a view of water or the sun, with a corner gate, a diagonal drive and a round court garden.
  - **Clusters** (Larkspur and Cypress Bend villages, the bayou camps, Blackwater Bayou, trailer parks): uneven homes in a square fenced or open yard with a shared track. Trailers stand in parallel rows.
  - **Farmyards**: a gravel yard, white fences, and an oak windbreak on the north and west sides.
  - **Fields and vines** are cells along their road, one crop per run.
- **Review fixes**: rear tennis courts; no second hedge and gate inside an estate; a plot house's curb point at the plot's edge, not inside its walls; gate leaves swing inward on mirrored plots and stay clear of the drive; stronger tests.
- **Cost**: per tile, plots about double the triangles (a mean of 1.8k, 12k at the worst, against 0.8k without them). Not measured on a device yet.
- **Tests**: every lot and plot is checked against its road (worst 2.2 and 3.4 degrees; the old data fails at 76). Estates and clusters are checked, and every grounds part is built. Country shots c17–c24 show the new plots.

*Driving controls* (Oct 27; Sachin: "Give a button for acceleration, or give 3 different control panels just like we have in driving games").
- Three layouts, picked in Phone > Settings > Driving and saved; all three have GAS and BRAKE pedals:
  - **Stick + pedals**: the old direction stick, plus the pedals;
  - **Arrows + pedals**: left and right arrows steer the car like a wheel, the phone-racer standard;
  - **Tilt + pedals**: steer by tilting the phone (the gravity sensor, with the accelerometer as a fallback).
- In the wheel layouts the car drives like a car:
  - there is no corner assist;
  - off the pedals it coasts;
  - holding BRAKE at a stop reverses, with the tail swinging the way the wheel turns;
  - steering eases in over 0.2 s.
- The pad uses RT for gas and LT for brake. Thumbs can slide between buttons. The labels have outlines, and a tilt gauge shows the steer.

*World v3* (Oct 27; Sachin: four themed cities based on real life with countryside, transit by condition, factions, services, aircraft and boats; then "Add more details to the map, add short routes, non paved roites through mountains etc too."). The plan is in `WORLD_V3_PLAN.md`, the decisions in `HANDOFF-world-v3.md`, and the research in `reference/world/`.
- **The state is now 12 x 9 km** (about 75 km² of land), with four cities:
  - **Bellerive**, the Florida city (Miami with its New Orleans core); the only one playable, now with its edges and countryside (phase 2);
  - **Concordia**, the planned capital (DC radials and Mall, Manhattan blocks, San Francisco hills and red bridge);
  - **Steelhaven**, the desolate motor city (Detroit);
  - **Las Brasas**, the Vegas city.
- **Porto Brisa** (Rio de Janeiro) is **expansion 1** (Sachin: "Keep it as a fifth city, perhaps a later expansion. We will adding more cities in later expansions."):
  - it lies south across the Gulf, off the state map, reached by ferry and air;
  - Comando Maré and Os Corvos keep their home there and work in Bellerive until it opens;
  - act 2 moves to Concordia and the Keys, so the base story never needs an expansion;
  - `WORLD_V3_PLAN.md` section 9 sets the rules and open map edges for later expansion cities.
- Each city has data for:
  - its theme, condition, vibe and districts;
  - transit in the city's condition (excellent, decaying, tourist-only, car-centric): every city has an airport, a train station and a bus station; metro and tram follow the condition (Las Brasas has no tram);
  - NPC density by day and night;
  - landmarks.
- Between the cities:
  - 15 regions with counties: desert, the biggest base (Fort Granite), mountains, lake and dam, forest, rust-belt lake country, parkland, hills, farmland, swamp, the Keys;
  - 16 towns, villages, ghost towns and a truck stop;
  - four small military sites;
  - 20 factions (corporates, syndicates, dons, drug mafias, gangs, unions, cults, police, military).
- **Detail layer**:
  - three new road kinds below the highways: county **lanes**, unpaved **dirt tracks** and 4x4 or hiking **trails** (logging roads, desert flats, levees, the observatory switchbacks, Devil's Staircase, Widow's Ridge);
  - creeks and a lake;
  - peaks with heights;
  - fords and bridges computed where roads cross water (a ford only where a track or trail meets a creek);
  - gas, a motel, campsites, farms, a fire lookout, a mine and a lighthouse.
- **In-game map**: zoom the full map out past the city and it shows the whole state.
  - The state is baked at 6 m a pixel in about 0.1 s.
  - It shows textured terrain, every road kind (tracks dashed, trails dotted), water, cities, county names, towns, peaks and pins.
  - Labels that would overlap wait until you zoom in.
  - A tap on a place not open yet says so instead of setting a waypoint.
  - The minimap runs on into the state map past the playable window.
- **Review fixes**:
  - places moved out of lakes, and Dam Road kept on the shore;
  - no fords across the river;
  - county labels placed by hand;
  - the city bake's sea frame is gone from the state map;
  - real hospital names replaced, and a casino workers' union added.
  - A second review found nothing blocking. Its small findings were fixed too: a bus depot on top of another place, a metro line ending short of downtown, two more real names, bus pins and the docs.
- `world_map.svg` has terrain patterns, the new road styles, creek names and an arrow to Porto Brisa. v2 data was shifted so Bellerive's coordinates are unchanged.
- **Plan** (`WORLD_V3_PLAN.md`): per city, the architecture, monuments, places, working characters, mission ideas, transit and NPCs. It also covers:
  - the countryside table;
  - factions and riots;
  - services by city condition;
  - about 10 vehicle physics classes;
  - rentals and schools;
  - scheduled travel as a kiosk and fade;
  - taxis;
  - phases 2-6 and expansion 1 with rough costs.
- **Recommended**: a seamless state built in phases, about 34-44 sessions, then Porto Brisa (about 8-10). The cheaper options are city-hop (about 20-26 sessions) and a smaller 8 x 6 km state.

*Interiors phase 0* (Oct 27; Sachin: "go ahead with the interiors and services plan"). Decisions and traps are in `HANDOFF-interiors.md`. Everything is built in code, with no credits spent.
- **Places**: `places.gd` picks blocks for **corner stores** (two in each of the five districts) and **diners** (two each in the Gilt District and Morrow Point, one in Ironwharf, which is mostly quay yards). It uses its own random stream, so blocks without a place build exactly as before.
  - Each place has a name, a district, opening hours (stores 24 h, diners 6:00–24:00), a door on the sidewalk and a map icon on the minimap and full map.
  - A storefront stands at the front of its parcel, with the district's usual buildings beside and behind it. The diner is chrome and ribbon glass with a neon roof sign; the corner store has display windows, a lit sign band, an awning and produce crates.
  - Sidewalk props (benches, planters, racks, scooters) never stand on a doorstep.
- **Doors**: walk onto the glowing ring and press ENTER.
  - The screen fades for 0.3 s while the room is built on a worker thread far from the city.
  - The street freezes exactly as it was (every node stops and hides) and comes back when you leave.
  - Inside, the light is fixed and the camera frames the room.
  - Doors lock with stars ("Lose the cops first") and during a mission, and are shut outside opening hours.
  - A respawn, new game or mission start while inside puts you straight back on the street.
- **Rooms** (`interior_kit.gd`):
  - corner store: gondolas, wall shelving, drinks fridges, a counter with a till and a clerk;
  - diner: a kitchen line with a cook, a counter with stools, booths, two-tops, a register and a server.
- **People inside** (`patron.gd`): customers come in, browse, pay at the till, order, slide into booths and stools to eat, then leave. Hit one and they run out and the shopkeeper calls the police (one star); staff cower.
- **Buying** (`shop_menu.gd`, `inventory.gd`):
  - corner-store snacks ($2–9) can be eaten now or carried; the bag holds three, and the SNACK button or H eats the best one when hurt;
  - diner meals ($4–18) are eaten seated: Jules sits at a free seat and health rises over 4 s.
- **New poses**: sitting, plus eat, browse, work and pay gestures.
- **Phone**: a Places app lists places nearest first, open or closed, with GO to set a waypoint.
- **Save v2**: the bag is saved with cash and progress. Older saves load with an empty bag.

*Modern look* (Oct 27; Sachin's feedback: "The graphics still seem primitive ... the game is set in the current modern times, and we need to show more details"). Decisions and traps are in `HANDOFF-modern-look.md`. Everything is built in code; there are no asset imports and no credits were spent.
- **Shading**: the city shader uses Burley diffuse and GGX specular instead of toon shading, with ACES tonemapping at exposure 0.85 (picked from side-by-side renders). Surface codes in vertex alpha give each surface its own material while each cell keeps one material and one draw call:
  - glass: sky reflection, sun glint, lit panes at night;
  - asphalt: grain, cracks and patches;
  - concrete, pavers and brick;
  - roof membrane, standing-seam metal and siding;
  - grass, solar cells, gloss paint and metal.
- **Water**: ripple normals, fresnel sky reflection and sparkle.
- **Roofs**: parapets with coping, HVAC, vents, dishes, stair huts, solar rows, terraces, skylights and sedum. Towers get plant roofs. The Aurum Tower has a gold and amber glass crown with a spire and a red beacon.
- **Facades**: curtain-wall glass with spandrels and mullions.
- **Streets**: stop bars, green bike boxes, and lane arrows on long runs.
- **Props**: LED cobra-head lights, mast-arm signals with cameras, bus shelters with lit ads, bike-share docks, EV chargers, wayfinding totems, pay stations, bins and e-scooters. The Lantern Quarter keeps its gas lamps as the historic district.
- **Vehicles**: shaped bodies, glass and gloss paint (`vehicle_kit.gd`, `vehicle.gd`).
- **Cost**: cells averaged 2.7k triangles (was 2.1k) and the densest had 12k (was 7.3k). Cell build p50 is 6 ms on desktop. Settings > Detail low skips the surface patterns.

*Detail pass 2* (Oct 27; Sachin: "do the next pass: trees, people's clothes, props. And lets add more vehicles, different categories, several models with each having a bit different vehicle physics."). Decisions and traps are in `HANDOFF-detail-pass-2.md`. Everything is still built in code, with no credits spent.
- **Trees**: canopies are lumpy, smooth-shaded clumps (`MeshBuilder.clump()`), darker underneath, with leaf clusters in the city shader.
  - Live oaks fork into four limbs and carry Spanish moss.
  - Palms have a ringed, leaning trunk, folded fronds and dead fronds.
  - Crepe myrtles bloom in pink, white, lilac or red.
  - Downtown sidewalks have street trees in grates.
- **Clothes**: hoodies, puffers, bombers, joggers, jeans and sneakers, caps and beanies, backpacks, crossbody bags, headphones and phones in hand (with a texting pose). Work wear covers delivery riders, hi-vis and scrubs. The named cast keep their looks.
- **Props**:
  - three-stream bins, a solar pay station, a detailed hydrant, slatted benches, a domed litter bin and mailbox, and steel bollards;
  - a signal cabinet at every mast arm;
  - district banners on half the downtown light runs;
  - bike racks and sidewalk works.
  - Steel now reads as steel: the shader fakes a sky-and-street reflection, since there are no reflection probes.
- **Vehicles**: 16 models in 13 categories, all with fictional makes: compact, sedan, EV, luxury, taxi, police, crossover, SUV, pickup, van, box truck, sports, muscle, supercar, motorbike and scooter.
  - Each model has its own mass, grip, handbrake drift, slide under power, brakes, power curve, low-speed and high-speed steering, and durability.
  - Collisions between vehicles share the speed loss, damage and shove by mass.
  - Cars roll and pitch, and bikes lean with their rider.
  - The HUD shows the model's name when you get in.
  - Traffic uses every car and truck type; parked spots also hold motorbikes and scooters.
  - Traffic now looks 9 m ahead on its lane, slows for junctions, picks its turn on the approach and backs off walls. The big models needed this to get through junctions.
- **Pedestrians** now step round street furniture, trying the building side first and staying on the curb. Before, a prop across their walking line held them there for good, at about 140 spots in the city. In a live sample, the number standing stuck for 6 s fell from 102 to 5 of about 190.
- **Cost**: cells average 3.5k triangles, up from 2.7k. 90% are under 7.1k (was 5.7k) and the densest has 17.1k (was 12k). Each vehicle is 224–408 triangles.

*Driving feel* (Oct 27; Sachin's feedback: "all roads seem to be small to drive comfortably without hitting anything"). Decisions and numbers are in `HANDOFF-driving-feel.md`. (Since Oct 28 the roads are wider too; see above.)
- At the time a street was 11 m curb to curb; the cars were the bigger cause: they reached top speed within one block, ran 10–20 m past a 90° turn, the camera showed about 1.2 s ahead, and a wall scrape halved speed every frame the car stayed pressed in.
- **Corner assist** (player only, stick layout): a sharp turn on the stick slows the car to the speed at which its model can turn on a 5 m radius. Easing off on a straight still coasts, and the handbrake skips it, so drifts stay. Run-on past the turn point: sedan 13.5 → 8.7 m, SUV 17.6 → 9.7 m, muscle 19.5 → 12.5 m.
- **City speeds**: top speed ×0.85 and acceleration ×0.75 for every model, so ranks and character stay.
- **Camera**: zooms out further with speed (38 → 48 m) and looks further ahead (0.35 → 0.55 s). Since Oct 28 the perspective camera goes further (see *Perspective camera*).
- **Walls**: a hit counts once and costs only the speed the wall took along the car's heading. A 15° scrape at 20 m/s now keeps 20.5 m/s and 3 health (was 9.5 m/s and 9 health over 3 hits); pinned on a wall costs 3 health, not 48.
- **Corners of the car are cut**, so clipping a post or a building corner glances off: a 10 cm clip at 15 m/s keeps 16.4 m/s instead of stopping at 1.8.
- **No pop-in**: people, traffic, parked cars and police neither appear nor disappear on screen at the wider zoom. Spawn spots come from out of view, and the bands widen with the zoom.

*Map v2* (`street_plan.gd`, rewritten as a planar street graph; Sachin's feedback: "It does look like a grid for sure"). Since the California street plan (above), the districts sit on one grid; the graph, blocks, landmarks and Morrow Bridge below carry over.
- Each district has its own angle, curve, fan and cross-curve. Cross streets often jog sideways between long streets, so they meet at offset T-junctions.
- Seams and long roads cross the districts: Crescent Boulevard, Rampart Avenue, Wharf Street, **Bayou Road**, Magnolia Avenue, the River Road and the Levee Road.
- **Liberty Avenue**, the diagonal, runs from Aurum Tower through the Crescent/Rampart junction to Ironwharf.
- **Morrow Bridge** carries Lantern Boulevard over the river to **Morrow Point**, a new district on the far bank.
- Blocks are faces of the graph with any number of sides. Minor streets are thinned per district, without stranding a junction or leaving a dead end.
- Landmark blocks grow until the landmark fits, and each landmark sits centred on a street side, which becomes its front.
- Liberty Green is a designed 120 x 80 m park.
- Build time is 0.65–0.9 s on desktop (up to 1.1 s under load).

*Demo map*: Gilt District, Lantern Quarter, Floodline Wards, Ironwharf and Morrow Point on both banks of the Morrow River (1.3 x 1.5 km); 13 landmarks; streetcar lines. It streams in cells built on a worker thread, and the bridge is its own cell. Since phase 2 the countryside carries on past it, and since Oct 28 the Bellerive Hills rise to the north.

*Story missions 1–3* (`game/scripts/missions/`): Homecoming, Empty Rooms and Lantern Lights, with objectives, dialogue, markers, GPS, fail and retry, cash and saved progress. Homecoming's chase now fails with a retry if the thief's scooter is wrecked (it used to wait forever).

*Phone, minimap and full map*, *Lantern Quarter* (day/night, rain, neon) and *game feel* (hit-stop, shake, sparks, skids) are as before. Parked cars now face the way traffic runs.

*Tests*
- 68 headless tests, 806 checks, including full runs of missions 1–3.
- The street-plan test checks that:
  - most street length runs on the citywide grid (the California test);
  - every junction can be reached;
  - there are no holes or bare land;
  - lots keep their corners;
  - all landmarks have room and face their street.
- The vehicle tests check:
  - every model builds;
  - each reaches its own top speed, and the speed and launch order holds;
  - a heavy truck shoves a sedan harder than the other way round;
  - stopping, understeer, roll and bike lean differ by model;
  - traffic of every kind gets through junctions.
- The clothes test checks every outfit builds as one skinned mesh within budget, and that texting raises the phone hand.
- The sidewalk-prop test checks pedestrians get past each downtown sidewalk prop without leaving the curb.
- The driving test checks easing off coasts, a swerve keeps speed, the 90° run-on, a scrape, a sideways slide into a wall, a pinned car and a post clip; the population test drives flat out on a phone-shaped screen and checks nothing appears or vanishes in view.
- The driving-controls tests check:
  - GAS drives on, and BRAKE stops and then reverses;
  - in the wheel layouts, steering turns the car with no corner-assist braking, and it coasts off the pedals;
  - reversing with the wheel swings the nose the right way;
  - tilt has a dead zone and full lock;
  - each layout shows its own touch buttons, and each button presses and lets go.
- The state-map test checks that:
  - the bake covers the whole state;
  - dirt tracks are drawn dashed;
  - zoomed out, the whole state fits the screen;
  - a tap on Concordia says it is not open, and a tap in Bellerive still sets a waypoint;
  - the minimap shows the city only inside the playable window, and the state beyond.
- The interiors tests (8) check:
  - every district gets its place types on seven seeds, every doorstep is clear and a storefront stands behind each door;
  - a shop visit freezes and restores the street exactly (traffic, people, clock, light, camera);
  - doors lock with stars, shut at night and can't be used from a car;
  - buying, eating and the bag;
  - a diner meal heals while seated;
  - customers come, pay, eat and leave for a minute in each room without getting stuck;
  - save v2 and loading a v1 save;
  - touch buttons with the shop menu shut;
  - a respawn, new game or death at the door while inside;
  - a hit diner leaving the booth.
- The phase 2 tests check:
  - the country joins the city: the links, every route step from Union Station to Wheaton following a road, every edge junction carrying on out, and no dead end within 1100 m of the plan;
  - Wheaton's district, `playable()`, and the landmarks on the maps;
  - tiles stream in and unload, and no city window walls are left;
  - cars stop at the bank and fence walls;
  - traffic drives out into the country and keeps to its roads;
  - traffic turns round short of every storm barricade;
  - routes reach a sample of 25 country junctions traffic may use;
  - every country building kind builds on its lot within budget;
  - a scripted car backs off a post, comes back to its line after running wide, and passes a stalled car;
  - taxis: hail, the destination list, the fare, riding, skipping, a phone call (with another car parked nearer than the cab), refusing wanted or broke players, and ending a ride cleanly.
- The plots tests check every lot and plot against the road it fronts, that only estate and cluster houses turn, that every lot stays inside its plot, estates' walls, gates and grounds, the Hale Estate's wall colliders on its edges, uneven cluster homes, and every grounds part.
- The wealth test checks every tier is present, that value and ground per household rise with tier, that T1 and T4 houses build differently (chain-link, cars), that a T4 car stays on a hill lot, and that every marked kind differs between its lowest and highest tier.
- The Oct 28 tests check the hills (roads on the ground, parked cars holding), lane counts and lane-keeping, breakable props, Golden Flats farmland (each farm-home kind builds a different plan at each size), and that every home has a way in:
  - the data gives each home a route, a cluster path or an estate drive, and no footpath runs under a home;
  - a real tile builds a street house's drive out to the road;
  - on the hill house furthest off its pad, route tops sit on the ground;
  - every home kit, at three sizes and four seeds, with a side blocked or not, sends its route out by a clear side through a gate gap; Hollis Farm has exactly one route out.
- The perspective camera test (34 checks) checks:
  - the back-out over towers, the framing, the shadow fit, the tilt at blocked and low-rise spots, the view band and the ground mark;
  - View, Distance, Drive zoom-out, Angle, Tilt near towers and Reset camera, pressed on the phone (the - and + stop at the ends), Drive zoom-out 50% and Off framing a flat-out car, and bad saved values;
  - drives along city routes at 30 m/s: the car stays on screen, the road shows far ahead, and the tilt neither hunts downtown nor stays steep among low buildings (these checks fail on the earlier pickers);
  - every 20:9 screen corner is over a loaded cell at 100% and 130% zoom.
- There is a screenshot tour (now with an aerial of the Ironwharf quay), place shots (`tests/place_shots.tscn`), state-map shots (`tests/map_shots.tscn`), country shots (`tests/country_shots.tscn`), taxi shots (`tests/taxi_shots.tscn`), farm and routes shots (`SHOTS=farm|routes`, see `game/README.md`), camera shots (`SHOTS=view`: classic against perspective, the see-through ghost, driving, and angles 45–90°), the occlusion probe (`tests/occlusion_probe.tscn`), skyline and shady galleries, a lookdev scene (`tests/lookdev.tscn`) and an asset gallery (buildings, landmarks, vehicles, people, outfits, props, trees, country buildings). `ONLY=test_a,test_b` runs single tests.
- The 90° turns test (15 checks) checks: Drive zoom-out's framing and flatten in Follow at 100, 50 and 0%; an 18° steer leaving the view put; a corner held for 0.4 s past 80° then turned a whole quarter; two quarter-second sidesteps a second apart ignored (the hold starts over) and a held one turning the view a quarter; a slow 30° thumb drift mid-turn bending the walk 30° with the frame kept; a dead-zone brush keeping it; letting go mid-turn easing to a stop; and the gear opening Settings and the Camera turn button cycling.
- The turning camera test (27 checks) checks: the stick drives and steers, the turn rate cap and settling, holding while backing up and below 3 m/s, entering a parked car, the minimap N and compass tap, the setting and a bad saved value, on foot the view following the walk at up to 60°/s while the stick's frame holds, a thumb wobble ignored and a thumb swing re-reading the stick in the view, and every 20:9 screen corner over a loaded cell on city routes with the view turning.
- Debug APK `0.23` (version code 23) via `game/tools/build_apk.sh`.

**Validation**
- All 1438 checks pass headless (0 failed) as of 0.23. The corner store test waited too briefly for its second shopper (a stay runs 20–55 s) and failed now and then; it now waits up to 150 s (8 of 8 runs pass).
- The California street plan changes Bellerive's layout on purpose, so the plan no longer dumps identical to earlier builds; missions 1–3 still run through in the tests.
- `country.json` regenerates from the generator with all self-checks at 0: no lot overlaps, no lots on roads or in water, no plots on roads, in water or outside, no home without a way in and no footpath under a home. It has 2054 lots, 1390 plots, 18 pivots, 73 links and 151 suburb sidewalk loops.
- On seeds 1, 2, 3, 7, 42, 99 and 2024 all 13 landmarks fit and face their streets, with no holes and no lot cut short.
- I reviewed the screenshots through contact sheets:
  - the tour, and lookdev renders of each district, night and rain;
  - the asset gallery, including the new vehicles, outfits and trees;
  - the place shots: storefronts by day and night, both rooms, the menus, a diner meal, the Places app;
  - the state-map shots: the whole state, zoomed regions, a closed city, the minimap past the edge;
  - the country shots: suburbs, Brisa Beach, Wheaton, farms, the vineyard, the gator farm, a bridge, a barricade, the fence, banks, night lights, and the estates, villages, farmyard and fields;
  - the California plan: the grid from above, skyline towers, the Wards strips, the outskirts streets and the Ironwharf quay;
  - Oct 28: the hills, wide roads, the farmland and farm homes, and the routes (street drives, trailers facing their track, city-edge walks meeting the street);
  - Oct 28, camera: classic against perspective at the Aurum Tower, Midtown and Lantern Square, ghosted towers, driving shots and the angle shots, and the view turning with a car driving east, south and west.
- The APK exports and is signed; I checked that it carries the final map and country data.
- Independent reviews ran; their findings were fixed:
  - Map v2 (two reviews): the Wards grid, a lot-outline bug, and connectivity checks when dropping streets.
  - Modern look (one review, nothing blocking): glass tint below the horizon, grass, lit panes, gable normals, the Aurum crown, lane arrows, stray parking lines.
  - Detail pass 2 (two reviews):
    - pedestrians stuck for good at the sidewalk works, and at about 140 older spots;
    - the first detour fix walked a quarter of pedestrians into the road;
    - bike lean against a wall;
    - the bus stop pole;
    - a test too weak to see pedestrians step into the road.
  - Driving feel (two reviews): the assist braked on any partial stick; a pinned car's speed wound up (HUD, police); spawns in view at the wider zoom and then too few people on a wide screen; drifts lost speed on walls; parked cars on occupied spots; police pop-in.
  - Interiors phase 0 (two reviews):
    - the closed shop menu swallowed PUNCH, RUN and ENTER on 16:9 phones;
    - a mission replay, retry, new game, or death during the door fade left the street frozen and the camera on an empty room;
    - hit booth diners stuck in the bench, and knocked-out ones kept their seat, so the diner filled up for good;
    - a double tap at the door walked straight back out;
    - the full map centred on the room;
    - no message when every seat was taken;
    - scooters on doorsteps;
    - a log error and a suspended fade on a forced exit.
  - World v3 (two reviews): see *Review fixes* under *World v3*.
  - World v3 phase 2 (two reviews): see *Review fixes* under *World v3 phase 2*.
  - Road-square plots (one review, nothing blocking): see *Review fixes* under *Road-square plots*.
  - Streets end to end (one review): Seabreeze Drive still ran 500 m past the Beltway in the east; the cranes no longer reached the water once the quay road moved back from it; the quay had no lamps; the carry-on angle test had no tie-break; the docs called the quay a concrete apron.
  - Hills (one review): roads off the ground, lane lines hidden, parked cars sliding.
  - Routes (two reviews): see *Routes review fixes* under *October 28*.
  - Homes by wealth (one review): see *Review fixes* under *Homes by wealth, phase 1*.
  - Perspective camera (reviews of the camera, of phase 2 twice, and of the angle settings): see *Review fixes* under *Perspective camera*.
  - Camera turning with the car (one review, nothing blocking): a parked car entered did not turn the view, a held stick jerked when the view landed, the building-clearing cache ignored the turn, and full lock kept full gas.
- Still open:
  - one old-town street in the city (plan point 477, 940) still ends where only pedestrian lanes carry on;
  - perspective camera:
    - downtown at the driving zoom, buildings still hide about 11% of the street round the player (6% on foot), and they show as ghosts;
    - trees and lamps inside the view band ghost too;
    - how the dithered ghost looks at phone resolution is not seen yet;
    - with the view turning, the city still loads in a fixed ring (about 1.5x the area, on foot too), and the view squares up 30° off the old-town streets;
    - Chinatown Wars' own camera numbers could not be measured, so ours are tuned by test and need a phone playtest;
  - the outskirts monuments and shady lots on the east side's arterials are not placed yet;
  - the Ferry Building's railing now faces the quay road rather than the water;
  - a rare bank-chain corner case (`_chain`) that hasn't shown up on any tested seed;
  - motorbikes and scooters don't drive in traffic yet (no AI riders);
  - about 1 pedestrian in 190 still steps off the curb near a corner;
  - clothes: a tote swings when punching, the phone stays in hand while riding, and no one wears a hood up;
  - the surface patterns have no anti-aliasing;
  - at top speed most models still run on 9.7–10.8 m past a snapped 90° turn, a little more than a junction gives; braking or turning earlier makes it;
  - rooms are lit flat (no lamps or shadows of their own yet) and read a little bright;
  - interiors phases 1–6 of the plan (more shop types, clothes, garages, fuel, gyms and martial arts, police stations, transit and road types);
  - world v3 phases 3–6 and expansion 1: only Bellerive and its edges are playable; the other cities, aircraft and boats are data and plan so far;
  - phase 2:
    - the cruise terminal and the seaplane base face their road, not the water;
    - pedestrians and live parked cars reach the Bellerive suburbs only, not the wider country;
    - respawn stays at the city clinic, and the County Hospital is a building only;
    - Wheaton's grid is axis-aligned rather than turned to Route 9;
    - the country has no LOD;
  - homes by wealth: lot sizing by tier inside the house kind, and city-side placement of the new kinds (Midtown towers, Wards blocks); the brands and places plan (`BRANDS_AND_PLACES_PLAN.md`) waits on Sachin's pick; the activity roadmap (`ACTIVITY_ROADMAP.md`) are plans;
  - the best camera angle: Sachin is trying angles with Settings > Angle;
  - whether trespass into Fort Granite gives 4 stars or 2–3 on a phone.
- Not yet checked:
  - FPS of this build on a real phone (0.17 ran at 120 FPS on Sachin's phone). Things that may cost frames:
    - cells carry more triangles, roads are wider, and the hills drape their ground;
    - the perspective driving view shows more ground and loads more cells, more again at Zoom 130% or a low Angle;
    - the tilt picker casts about 50 rays every 0.25 s;
    - country tiles stream in as you drive;
  - map and cell build time, country tile builds and the state-map bake on a phone, including whether cells build fast enough at 30 m/s;
  - tilt steering on a real phone;
  - a playtest, including how the new driving and controls feel, how the doors, menus and taxis feel on a phone, and how far the country feels worth driving.

The research ran partly on search-engine summaries, since several sites could not be opened from the build environment; summary-only sources are marked.
