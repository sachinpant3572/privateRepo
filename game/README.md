# Solvera prototype (Godot 4.7)

Milestone 1 of `MVP_DESIGN.md` is done: driving, fighting and the wanted
system run smoothly on a phone (120 fps on a Galaxy S25 Ultra, 30 fps on a
low-end phone). Now on the way to milestone 2, the vertical slice: the first
three story missions are playable, the Lantern Quarter is getting its final
look (day and night, rain, effects), and there's a minimap, a full map and a
phone.

## What's in it

- **Story missions 1-3** (`scripts/missions/`), from `ACT1_MISSIONS.md`:
  - **Homecoming**: a kid snatches Jules's bag outside Union Station; chase
    him to his scooter, take another one, follow him through the Lantern
    Quarter (don't fall too far behind), beat his crew at Lantern Square,
    take their car and drive home to an empty Moreau House.
  - **Empty Rooms**: Nia turns up angry and gets Jules's phone going (Teo's
    last messages); search Teo's ransacked apartment for three clues, then
    hear Remy's story at the Floodline Clinic.
  - **Lantern Lights** (at night): spring Celeste's bandleader Marcel from
    the precinct (Captain Reyes lets him go), survive an Aurum ambush that
    wrecks your car, steal another, lose the police and get Marcel home.
  - Objectives, dialogue (tap to skip), title cards, glowing markers, a GPS
    line, mission failed and retry, cash rewards. Progress, cash and settings
    are saved; the next mission's yellow marker waits on the map.
- **Phone** (unlocked in Empty Rooms; PHONE button or P): Messages and
  Contacts that fill in with the story, the Map, Missions (progress and
  replays) and Settings (detail high/low, shadows, FPS counter, weather,
  skip time, new game).
- **Minimap and full map**: round north-up minimap with landmark icons,
  mission blips (on the rim when off the map), police while wanted and the
  GPS route; tap it (or M) for the full map: pan, pinch or scroll to zoom,
  tap to set a waypoint.
- **Day and night**: one game minute per second. The sun's shadows swing
  round; after dusk windows light up, gas lamps and street lights throw
  pools of light, neon signs glow and cars drive with headlight beams. None
  of it uses real lights (they're expensive on phones): glowing surfaces are
  marked in the vertex colours and lit by the city shader.
- **Weather**: clear, cloudy, rain and storms with lightning. Rain falls
  around the camera, the ground darkens and puddles mirror the sky, with
  splashes and ripples.
- **Effects**: hit-stop and screen shake on punches, kicks and crashes,
  sparks, debris, tyre smoke and skid marks when drifting or braking hard,
  smoke from damaged engines, splashes on wet roads (`scripts/fx.gd`).
- **People** are skeletal now: rounded body parts on a humanoid skeleton
  (standard bone names, so modelled characters can replace them later),
  animated in code: idle, walk, run, punch, kick, guard, flinch, knockdown,
  riding, and gestures for cutscenes (phone, talk, search, cower...).
  Outfits: tee, jacket, hoodie, dress, tank, suit, uniform.
- **Demo map**: about 1.3 km x 1.5 km of Bellerive on both banks of the
  Morrow, from the world map (`data/world_map.json`, the city's
  `demo_window`). You start outside **Union Station** in the Gilt District.
- **Street plan** (`scripts/street_plan.gd`; research and rules in
  `reference/MAP_BUILDING.md`):
  - **Layout**: a real street network, not a grid. Each district has
    its own street pattern at its own angle; the streets curve and fan out
    like New Orleans streets round the river's crescent, and they meet the
    next district along seam roads. Blocks come in many shapes. Blocks
    are big in Gilt, tight in the Quarter, long and staggered in the
    Wards, with T-junctions where streets were dropped.
  - **Long roads**:
    - **Liberty Avenue**, the diagonal from Aurum Tower to Ironwharf;
    - **Magnolia Avenue**, curving through Gilt;
    - **Lantern Boulevard**, which crosses the river on **Morrow Bridge**
      to **Morrow Point**, a far-bank district.
  - **Street classes**:
    - **Lantern Boulevard** (the streetcar) and **Crescent Boulevard** have
      neutral grounds with oaks or palms;
    - **Rampart Avenue**, Liberty, Magnolia and Point avenues, and Wharf
      Street;
    - the River Road and the Levee Road along the banks;
    - ordinary streets;
    - narrow Quarter streets paved with old pavers;
    - pedestrian lanes with bollards and string lights.
  - **Liberty Green**, a park on Liberty Avenue with paths, a bandstand, a
    pond and oaks.
  - Some downtown blocks are plazas or car parks, and some Ward blocks are
    pocket parks or a chapel.
  - Buildings stand on parcels in each block, facing its front street;
    leftover corners get trees, planters or barrels.
- Each block takes its layout from the map district it falls in:
  - **Gilt District**: mid-rise glass towers on stone plazas, street lights,
    traffic lights, rooftop helipads and gardens.
  - **Lantern Quarter**: rings of Creole townhouses with cast-iron galleries
    round shady courtyards, gas lamps, crepe myrtles.
  - **Floodline Wards**: rows of shotgun houses with porches and backyards,
    storm-damaged houses with blue tarps, empty lots, power lines.
  - **Ironwharf**: warehouses, container yards and gantry cranes over the
    river.
  - **The Morrow River** curves along the south with a river road on its
    bank: animated water, railings, moored boats.
  - **Landmarks** from the map get their own blocks: Union Station, Aurum
    Tower, The Blue Lantern, Lantern Square, the precinct (BUSTED respawn),
    Floodline Clinic (WASTED respawn), Wharfside Courts, Moreau House, Teo's
    apartment, Warehouse 9, The Pit, the Old Streetcar Depot and the
    Drowned Streetcar.
  - **Streetcars**: the Lantern Line runs from Union Station down to the
    river (rails, overhead wires, streetcars at stops); the rusty drowned
    line leads into the old depot.
  - Zebra crossings, lane markings, hydrants, benches, bins and mailboxes;
    "road closed" barricades where streets leave the playable area, and
    simpler blocks past the edge so the city doesn't just stop.
- **Streaming**: the map is split into cells (one block plus its roads;
  the bridge is a cell of its own). Cells whose block comes within ~105 m of
  the player are built on a worker thread and freed past ~150 m; each cell is one mesh (one draw call) and one static body.
  Parked cars come and go with the player too. A cell averages about 2.7k
  triangles (90% under 5.9k, the densest 12k) and builds in about 6 ms
  (90% under 16 ms, measured in the cloud container).
- **Asset kits** (`scripts/kits/`): code-built, vertex-coloured low-poly
  buildings, props, vehicles (sedan, taxi, police, pickup, van, sports car,
  each with its own handling) and people (skin, hair and clothes mixed per
  pedestrian). No textures: a surface code in each vertex colour's alpha
  picks the material in the city shader (glass, metal, asphalt, concrete,
  pavers, brick, siding, seam metal, roof membrane, solar, grass), with
  Burley/GGX shading and ACES tonemapping. `tests/lookdev.tscn` renders a
  few fixed spots for look reviews.
- **On foot**: jog, sprint, punch; three quick hits make a punch-punch-kick
  combo that knocks people down. Scooters can be ridden (the rider stays in
  view).
- **Nothing hidden behind buildings**: when a building blocks the view of
  the player, it dissolves in a circle around them (city shader, `mesh_builder.gd`),
  and silhouettes show through walls: the player and their car in yellow,
  police in blue, anyone attacking in red.
- **Driving**: arcade cars steered toward the stick direction (reverse by
  pointing behind), handbrake drift, damage and wrecks, parked cars,
  carjacking.
- **City life**: pedestrians walking the sidewalks (some fight back), traffic
  following right-hand lanes and stopping for obstacles.
- **Wanted levels 1-2**: assault or carjacking gives one star (police on foot);
  hitting a cop or stealing a police car gives two (plus police cars, which
  stop and send an officer out when you're on foot). Stay out of sight to lose
  them. Getting held by a cop means **BUSTED** (respawn at the police
  station); dying means **WASTED** (respawn at the hospital).
- **Classic top-down camera**: north up, tilted to a 3/4 view (60°) so the
  fronts of buildings and people show, like Stardew Valley and the Java-era
  Gangstar games. Leads ahead of
  cars and zooms out with speed.
- **HUD**: minimap, health, wanted stars (flashing while police can't see
  you), cash, clock, phone, objective, speed, prompts, FPS and draw-call
  readout.
- **Lantern Quarter detail**: shopfronts with lit windows, striped awnings
  and neon blade signs, café tables with parasols, festoon lights strung
  across the streets, oil stains and cracks on the asphalt, graffiti on the
  docks.

## Controls

| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move / steer | Left half of screen (floating stick) | WASD / arrows | Left stick |
| Punch | PUNCH | Space / J | X |
| Run / handbrake | RUN / BRAKE | Shift | A |
| Get in / out, search | ENTER / EXIT / SEARCH | E / F | Y |
| Map | Tap the minimap | M | Back |
| Phone | PHONE | P | |
| Skip a line of dialogue | Tap it | Enter | |

Tab toggles the on-screen controls on desktop.

## Play it on Android

Install `build/solvera-prototype-debug.apk` (built by `tools/build_apk.sh`, arm64,
debug-signed). Android will ask you to allow installing from that source.

If a low-end phone struggles at night or in the rain, set Phone > Settings >
Detail to LOW (flat colours, lighter rain) or turn shadows off.

## Develop in a cloud session

```bash
game/tools/setup_cloud.sh   # Godot, Android templates, signing tools (once per container)
game/tests/run.sh           # headless tests, ~10 s
game/tools/build_apk.sh     # debug APK into game/build/
```

Screenshots (needs a virtual display):

```bash
cd game && xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
  --resolution 1280x720 res://tests/screenshots.tscn -- /path/to/out_dir
```

The same command with `res://tests/gallery.tscn` renders the asset gallery
(every building, landmark, vehicle and prop, and posed people), and with
`res://tests/mission_shots.tscn` shots of the missions, the phone and the
dialogue.

FPS in screenshots is meaningless: the container renders without a GPU.

A quick top-down look at the street plan alone (a few seconds, no
display; the landmark points are rough, so it differs a little from the
game's plan):

```bash
cd game && godot --headless -s res://tests/plan_dump.gd -- /tmp/plan.json \
  && python3 tools/plan_preview.py /tmp/plan.json /tmp/plan.png --scale 0.6
```

## Layout

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Entry point; wires systems, BUSTED/WASTED |
| `scripts/city.gd` | Map data, road graph, sidewalks, landmark frames, cell streaming |
| `scripts/street_plan.gd` | The street plan: district patches, seam and long roads, the street graph, blocks |
| `scripts/city_cells.gd` | Builds one cell: streets by class, block layouts fitted to each block, landmarks, parks, street furniture |
| `scripts/kits/` | Asset kits: `building_kit`, `prop_kit`, `vehicle_kit`, `character_kit` |
| `data/world_map.json` | The world map: regions, cities, districts, routes, landmarks |
| `tools/render_map.py` | Renders the map data to `world_map.svg` and `bellerive_map.svg` |
| `scripts/mesh_builder.gd` | Bakes coloured boxes into single meshes; surface codes, city shader, shared and x-ray materials |
| `scripts/humanoid.gd` | Shared body: health, punches, combo kick, knockdowns |
| `scripts/rig.gd` | Code animation for the character skeleton |
| `scripts/player.gd`, `pedestrian.gd`, `cop.gd`, `npc.gd` | Characters (`npc.gd`: mission people and enemies) |
| `scripts/missions/` | Mission manager (progress, saving, markers, retry), mission base helpers, missions 1-3, cast looks |
| `scripts/atmosphere.gd` | Time of day, sun and moon, weather, rain |
| `scripts/fx.gd` | Hit-stop, shake, sparks, smoke, splashes, skid marks (autoload) |
| `scripts/minimap.gd`, `full_map.gd`, `map_image.gd` | Minimap, full map and the baked map texture |
| `scripts/phone.gd` | The phone and its apps |
| `scripts/vehicle.gd` | Car physics; traffic, police, scripted and chaser drivers; riders; lights and effects |
| `scripts/police_manager.gd` | Police spawning and line of sight |
| `scripts/wanted.gd` | Wanted level (autoload) |
| `scripts/population.gd` | Pedestrian and traffic bubble around the player |
| `scripts/controls.gd`, `touch_controls.gd` | Input (autoload) and multi-touch UI |
| `scripts/hud.gd`, `top_down_camera.gd` | HUD and camera |
| `tests/` | Headless tests, screenshot tour and asset gallery (`gallery.tscn`) |
| `tools/` | Cloud setup and APK build |

## Not yet (later milestones)

Missions 4-13, weapons, shops, businesses, interiors, audio, wanted levels
3-5, drivable boats and streetcars, more bridges, Magnolia
Heights and Blackwater Bayou, modelled characters (AI-generated models with a
standard animation set, which the skeleton is ready for) and final-quality
art outside the Lantern Quarter.
