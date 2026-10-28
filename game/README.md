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
- **Places you can walk into** (phase 0 of `INTERIORS_SERVICES_PLAN.md`):
  corner stores in every district and diners in the Gilt District,
  Ironwharf and Morrow Point, each with its own storefront, name, map icon
  and opening hours.
  - Walk onto the glowing ring at the door and press ENTER. The screen
    fades and you're inside, with the street frozen exactly as you left it.
  - Inside: a shopkeeper (or a cashier, cook and server), and customers
    who browse, pay, sit down to eat and leave.
  - At the counter: corner-store snacks (eat now or take; the bag holds
    three, the SNACK button or H eats the best one) and diner meals
    (Jules sits down and health comes up while eating).
  - Doors lock while the police are after you or a mission is running,
    and shut outside opening hours. Hitting someone inside calls the
    police (one star).
  - The bag is saved with your progress (save version 2; older saves
    load with an empty bag).
- **Phone** (unlocked in Empty Rooms; PHONE button or P): Messages and
  Contacts that fill in with the story, the Map, Places (nearest first,
  open or closed, GO sets a waypoint), Missions (progress and
  replays) and Settings. The gear button under the clock (always shown, even
  before the phone is unlocked) opens Settings straight away. Settings is a
  full-screen page with tabs, a line under each setting saying what it
  does, and a live preview of the game view beside the list (the game stays
  paused; "Preview: Driving fast" shows the view at full speed, and touching
  Drive zoom-out switches to it). Camera: view, Distance 60-130%, Drive
  zoom-out Off-100%, Angle 40-90° with - and + buttons, look down near
  towers (among tall buildings the camera tips further down, up to 85°, then
  back to your Angle), camera turn, reset. Graphics: Quality (Low, Medium, High,
  Ultra) and its effects one by one (bloom, smooth edges, vivid colour, real
  lights), detail high/low, shadows, FPS limit (30, 60, 75, 90, 120), FPS counter. Controls: driving
  layout. Game: weather, skip time, new game.
- **Minimap and full map**: round north-up minimap with landmark icons,
  mission blips (on the rim when off the map), police while wanted and the
  GPS route; tap it (or M) for the full map: pan, pinch or scroll to zoom,
  tap to set a waypoint. Zoom out past the city and the full map becomes
  the whole state of Solvera (`scripts/state_map.gd`, baked from the world
  map at 6 m a pixel in about 0.1 s):
  - terrain textured by kind (forest, ridges, desert, fields, swamp);
  - highways, roads, county lanes, dashed dirt tracks and dotted trails;
  - rivers and creeks, the four cities and the towns and ghost towns;
  - peaks with heights;
  - pins for airports, bases, stations, gas and campsites.
  Labels that would overlap are left out until you zoom in. A tap on a place
  that isn't open yet says so. The minimap runs on into the same state map
  past the city's edge.
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
  Present-day clothes: hoodies, puffers, bombers, joggers, jeans and
  sneakers, caps and beanies, backpacks, crossbody bags, headphones and
  phones in hand, plus work wear (delivery rider, hi-vis, scrubs).
  Pedestrians step round street furniture in their way, building side
  first, without leaving the curb.
- **Demo map**: about 1.3 km x 1.5 km of Bellerive on both banks of the
  Morrow, from the world map (`data/world_map.json`, the city's
  `demo_window`). You start outside **Union Station** in Midtown.
  The window is open: its margin ring is drivable and the country carries on.
- **Country round Bellerive** (phase 2 of `../WORLD_V3_PLAN.md`;
  `scripts/country.gd`, `country_tiles.gd`, `kits/country_kit.gd`): the
  suburbs (Magnolia Heights, Blackwater Bayou, the east side, the south shore,
  Brisa Beach with Seabreeze Drive and Deco Row), Golden Flats (Wheaton, Ridley
  Crossing, farms and grain elevators; irrigated farmland laid out by
  `tools/farmland.py`: centre-pivot circles with sprinkler arms, strip fields
  in rows, canals with pump houses, a 600 m section grid of paved roads and
  dirt tracks with curving shortcuts, paved and dirt, and the 6-lane Golden
  Flats Expressway off the Beltway; farmsteads with a big, plain, adobe or
  ranch farmhouse, some with a hired hand's cottage, and homesteads between
  them with a small cottage, ranch house, farmhouse or adobe. Each farm home
  draws one of three plans by its lot's size (`country_kit._tier`): e.g. the
  small cottage is a log cabin on a small lot and gains a lean-to, hen house
  and shed on a big one; the adobe is a pueblo, a farmhouse or a hacienda.
  Yards that differ from the land round them are fenced or walled. Every
  home has a way in from the road: its drive or walk runs out to the road
  in a surface that suits it (concrete, gravel, caliche, terracotta pavers,
  a dirt two-track, asphalt), farmyard fences open for the farm homes, and
  cluster homes get a dirt, gravel or plank path to their camp's track),
  Saltgrass (bayou, the Gator Farm,
  airboats) and Verdant Hills (Larkspur, the vineyard). Suburb streets run
  straight on from the city's: nearly every city street that reaches the
  edge carries on out to the Beltway, Sunvale Boulevard, Seabreeze Drive or
  Bayou Drive, and no road round the city stops dead. The Ironwharf quay is
  a drivable apron the docks streets end on. One road graph covers both, so
  traffic, the GPS, police and taxis drive out. The play area ends in a fence and storm
  closure barricades; banks, the coast and bridge parapets keep cars out of
  the water. Built offline by `tools/build_country.py` into
  `data/country.json` and streamed in 100 m tiles (load at 130 m, about
  5 ms and 2k triangles each before the buildings).
  Every lot and plot is a rectangle square to its road (`../HANDOFF-plots.md`).
  Only estate houses may turn, 45 degrees toward water or the sun, inside
  walled or hedged grounds with a gate, drive, parterres, a tennis court and
  orchards. Villages, bayou camps and trailer parks put uneven homes inside a
  square yard. Farmyards have a windbreak, and the fields are cells along
  their road. `kits/grounds_kit.gd` draws the parts of each plot.
- **The Bellerive Hills** (`tools/mountain.py`, `scripts/terrain.gd`;
  `../HANDOFF-roads-mountain.md`): a chaparral ridge north of the Beltway,
  like the Santa Monica Mountains above LA, up to 114 m at Calder Peak. It
  is drivable: the **Canyon Freeway** climbs from the Beltway through the
  saddle to Route 1, **Crest Drive** runs along the ridge between Route 9
  and Route 1, **Coyote Canyon Road** and **Observatory Road** (hairpins)
  come up from the city, and a fire road climbs to two red-and-white radio
  masts on the summit. The **Lumen Observatory** looks down on the city and
  the **Hillside Letters** stand on the slope below the peak. Roads are
  graded (cut and fill), homes sit on level pads, cars pitch and roll on the
  slopes and slow going uphill, and the ground is shaded so the relief reads
  from above (dark scrub on the north faces, gold grass on the south).
- **Taxis** (`scripts/taxi.gd`): hail a cab (TAXI / T) or call one from the
  phone's Cab app, pick a landmark or town, then ride along or pay 1.5x to
  skip there. $4 plus $3 a km.
- **World map v3** (`data/world_map.json`, plan in `../WORLD_V3_PLAN.md`):
  - a 12 x 9 km state with four cities: Bellerive (Florida and New Orleans),
    Concordia (the planned capital), Steelhaven (the desolate motor city) and
    Las Brasas (Vegas);
  - 16 regions with counties, 16 towns, villages and ghost towns, and military
    sites;
  - 59 routes (highways down to trails, rail, metro, trams, ferries, flights),
    158 landmarks (bus and train stations, airports, fords and bridges among them)
    and 20 factions.
  - Porto Brisa (Rio de Janeiro) is expansion 1, across the Gulf and off this
    map: an `expansions` entry that the game does not read yet.
  The game reads only Bellerive's window. Items with `"phase"` above 1 inside
  it are planned, and are skipped when the city loads.
- **Street plan** (`scripts/street_plan.gd`; research and rules in
  `reference/MAP_BUILDING.md`):
  - **Layout**: a real street network, not a grid. Each district has
    its own street pattern at its own angle; the streets curve and fan out
    like New Orleans streets round the river's crescent, and they meet the
    next district along seam roads. Blocks come in many shapes. Blocks
    are big in Gilt, tight in the Quarter, long and staggered in the
    Wards, with T-junctions where streets were dropped.
  - **Long roads**:
    - **Liberty Avenue**, the diagonal from Founders Circle across Midtown
      (like Broadway) to Ironwharf;
    - **Magnolia Avenue**, curving through Gilt to the City Hall grounds and
      on beyond them, like DC's diagonals;
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
  - **Bellerive v3 set pieces** (borrowed from DC, New York and California;
    `../HANDOFF-bellerive-v3.md`, research in
    `../reference/world/bellerive_patterns.md`):
    - **the civic centre**: City Hall on its lawn, one grid block with
      through streets on all four sides, the
      **Esplanade** (a mall with a reflecting pool and elm rows) running east
      to **Founders Circle**, a traffic circle with the Founders Obelisk where
      Lantern Boulevard meets Liberty Avenue. The Parish Courthouse, the
      Federal Building, the Public Library and Police Headquarters face the
      mall;
    - **Midtown**: Manhattan's long thin blocks between wide avenues, Liberty
      cutting across with a bowtie at **Liberty Square** (LED tower), the Main
      Post Office and Fire Headquarters nearby;
    - **Moreau Square**: a square park ringed by painted Victorian rows (SF's
      Alamo Square);
    - **Morrow Point**: brownstone rows round green block cores (Brooklyn);
    - the **Ferry Building** on the Ironwharf quay (SF);
    - palm-lined boulevards (LA);
    - four more traffic circles where arterials cross: **Liberty Circle**
      (a statue), **Aurum**, **Cypress** and **Harbor Circle** (fountains);
    - the **Bellerive Beltway** round the city is a highway.
  - **Liberty Green**, a long park on Liberty Avenue (Central Park, scaled
    down) with paths, a bandstand, a pond and oaks.
  - Some downtown blocks are plazas or car parks, and some Ward blocks are
    pocket parks or a chapel.
  - Buildings stand on parcels in each block, facing its front street;
    leftover corners get trees, planters or barrels.
- Each block takes its layout from the map district it falls in:
  - **Gilt District**: mid-rise glass towers on stone plazas, street lights,
    traffic lights, rooftop helipads and gardens; about a third of its lots
    are skyscrapers, 30 to 150 m (`kits/skyline_kit.gd`: setback glass,
    an art-deco crown, flat-roof helipad towers, a finned slab), and some
    plazas carry an abstract statue on a plinth.
  - **Midtown**: the same towers, taller, with LED towers and more
    skyscrapers (twin towers with a sky bridge among them).
  - **Morrow Point**: brownstone rows; the blocks on Moreau Square have
    painted Victorian rows.
  - **Lantern Quarter**: rings of Creole townhouses with cast-iron galleries
    round shady courtyards, gas lamps, crepe myrtles.
  - **Floodline Wards**: rows of shotgun houses with porches and backyards,
    storm-damaged houses with blue tarps, empty lots, power lines; barred
    bungalows, a housing project here and there, burned lots, and run-down
    strips on its avenues and boulevards: motels, liquor stores, pawn
    shops, check cashers and SRO hotels (`kits/shady_kit.gd`).
  - **Ironwharf**: warehouses, container yards and gantry cranes over the
    river; inland, chop shops, scrapyards, and abandoned warehouses with a
    row of tents along the sidewalk.
  - **The Esplanade** ends in a memorial arch at its west end.
  - **The Morrow River** curves along the south with a river road on its
    bank: animated water, railings, moored boats.
  - **Landmarks** from the map get their own blocks: Union Station, Aurum
    Tower, The Blue Lantern, Lantern Square, the precinct (BUSTED respawn),
    Floodline Clinic (WASTED respawn), Wharfside Courts, Moreau House, Teo's
    apartment, Warehouse 9, The Pit, the Old Streetcar Depot and the
    Drowned Streetcar, and the government buildings (`kits/civic_kit.gd`).
  - **Streetcars**: the Lantern Line runs from Union Station down to the
    river (rails, overhead wires, streetcars at stops); the rusty drowned
    line leads into the old depot.
  - Zebra crossings, lane markings, hydrants, benches, bins and mailboxes;
    "road closed" barricades where streets leave the playable area, and
    simpler blocks past the edge so the city doesn't just stop.
- **Streaming**: the map is split into cells (one block plus its roads;
  the bridge is a cell of its own). Cells whose block comes within ~105 m of
  the player are built on a worker thread and freed past ~150 m; each cell is one mesh (one draw call) and one static body.
  Parked cars come and go with the player too. A cell averages about 3.5k
  triangles (90% under 7.1k, the densest 17.1k) and builds in about 6 ms
  (90% under 16 ms, measured in the cloud container before the trees and
  props of the second detail pass).
- **Asset kits** (`scripts/kits/`): code-built, vertex-coloured low-poly
  buildings, props (live oaks, palms, crepe myrtles and street trees with
  clumped canopies; bins, benches, hydrants, signal cabinets, banners, bike
  racks, sidewalk works), 20 vehicles, one per category (compact, sedan,
  EV, luxury, taxi, police, crossover, SUV, pickup, van, sports, muscle,
  supercar, motorbike, scooter, a tuk-tuk and a cargo trike, a 6-wheel
  box truck, a 10-wheel tipper and an 18-wheel semi; fictional makes),
  each with its own mass, grip, brakes, power curve, steering and
  durability, body roll and bike lean (cabins, dashboards and seats are
  painted on the glass; the semi is one rigid body and only sets off on
  streets with two or more lanes each way), and people (skin, hair and clothes mixed per
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
  following right-hand lanes and stopping for obstacles. Streets and avenues
  have two lanes each way and a parking strip, boulevards and highways three,
  the Beltway four; cars pick a lane and keep it.
- **Breakable roadside props** (`scripts/breakables.gd`): lamp posts, signals,
  street trees, hydrants (they gush), benches, bins, signs and the like go
  down when a car hits them, and the car keeps most of its speed.
- **Wanted levels 1-2**: assault or carjacking gives one star (police on foot);
  hitting a cop or stealing a police car gives two (plus police cars, which
  stop and send an officer out when you're on foot). Stay out of sight to lose
  them. Getting held by a cop means **BUSTED** (respawn at the police
  station); dying means **WASTED** (respawn at the hospital).
- **Classic top-down camera**: north up, tilted to a 3/4 view (60°) so the
  fronts of buildings and people show, like Stardew Valley and the Java-era
  Gangstar games. Leads ahead of
  cars and zooms out with speed (Settings > Drive zoom-out sets how far).
  The view turns with the car like GTA Chinatown Wars, and on foot follows
  the way you walk (Settings > Camera turn: Follow, 90° turns or North up;
  90° turns holds the view still until the car or the walk has been a
  corner off it for 0.4 s, then turns a whole quarter); tap the minimap's
  N to swing it back behind the car.
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
| Move / steer (stick layout in a car with the camera turning: left/right steer, up gas, down brake and reverse) | Left half of screen (floating stick) | WASD / arrows | Left stick |
| Gas / brake (held at a stop: reverse) | GAS / BRAKE pedals | W / S (arrows and tilt layouts) | RT / LT |
| Punch | PUNCH | Space / J | X |
| Run / handbrake | RUN / DRIFT | Shift | A |
| Get in / out, search, go into a place, shop | ENTER / EXIT / SEARCH / BUY / ORDER | E / F | Y |
| Eat a snack from the bag | SNACK | H | |
| Map | Tap the minimap | M | Back |
| Re-centre the turning camera | Tap the minimap's N | | |
| Phone | PHONE | P | |
| Settings | Gear button | | |
| Hail a cab (one passing within 15 m) | TAXI | T | B |
| Skip a line of dialogue | Tap it | Enter | |

Tab toggles the on-screen controls on desktop.

Driving has three layouts, picked in Settings > Controls and saved:

- **Stick + pedals** (default): the car heads where the stick points, as on
  foot, with a corner assist that slows for tight turns. GAS alone drives
  straight on; BRAKE stops, then reverses.
- **Arrows + pedals**: two arrow buttons on the left turn the wheel, the
  pedals on the right drive, as in most phone racers. A thumb can slide
  from one arrow or pedal to the other. Off the pedals the car rolls on.
  On a keyboard this is W/S gas and brake, A/D steer.
- **Tilt + pedals**: turn the phone like a wheel (full lock at about 25
  degrees, a small dead zone near level); a gauge on the left shows the
  wheel.

## Play it on Android

Install `build/solvera-prototype-debug.apk` (built by `tools/build_apk.sh`, arm64,
debug-signed). Android will ask you to allow installing from that source.

If a low-end phone struggles at night or in the rain, set Settings >
Graphics > Quality to Low (or Medium), or set Detail to LOW (flat colours,
lighter rain) or turn shadows off; a lower FPS limit there saves battery
and heat.

## Develop in a cloud session

```bash
game/tools/setup_cloud.sh   # Godot, Android templates, signing tools (once per container)
game/tests/run.sh           # headless tests, ~10 s (VERBOSE=1 lists every check)
game/tools/build_apk.sh     # debug APK into game/build/
```

Screenshots (needs a virtual display):

```bash
cd game && xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 \
  --resolution 1280x720 res://tests/screenshots.tscn -- /path/to/out_dir
```

With `res://tests/sky_shots.tscn` the sky (16 views): looking up at night
from downtown, the suburbs, the hills, a beach and the desert's edge, the
moon, a cloudy night, sunrise and sunset, birds by day from below and above,
and the sky in the river, the sea and wet roads from above.
`ONLY=s03_hills_night,...` shoots just those; `SKY_DEBUG=1` prints where the
flocks near each view are on screen.

The same command with `res://tests/gallery.tscn` renders the asset gallery
(every building, landmark, vehicle and prop, and posed people; `-- <out_dir>
vehicles` shoots only the vehicles: every kind, each row and the trucks close
up, from nearly overhead and from the driving camera's distance), and with
`res://tests/mission_shots.tscn` shots of the missions, the phone and the
dialogue, with `res://tests/place_shots.tscn` the storefronts by day
and night, the rooms, the shop menu, a diner meal and the Places app, and
with `res://tests/control_shots.tscn` the touch controls on foot and in
each driving layout and every Settings tab, and with `res://tests/map_shots.tscn` the full map
zoomed out to the state and on the countryside, a tap on a closed place,
and the minimap past the city's edge, with `res://tests/country_shots.tscn`
the country (suburbs, Brisa Beach, towns, farms, bridges, barricades, the
fence, estates, villages, a farmyard and fields, by day and night; `ONLY=c17_hale_estate,...`
shoots just those views) and with `res://tests/taxi_shots.tscn` hailing,
the fare panel, a ride and a skip. `res://tests/civic_gallery.tscn`,
`res://tests/skyline_gallery.tscn` and `res://tests/shady_gallery.tscn`
render every kind of the civic, skyline and shady kits; the screenshots
include aerial views of Gilt, Midtown, the Wards, Ironwharf and the
Esplanade's arch (shots 37 to 41), and the traffic circles and the
Bellerive Hills (45 to 52; `SHOTS=hills` before the command shoots just
those). `SHOTS=roads` shoots the wide roads (53 to 58), `SHOTS=props` a car
through a lamp, a tree and a hydrant (59 to 64), `SHOTS=farm` Golden
Flats' farmland (65 to 72), `SHOTS=routes` the way in to one home of
each kind and setting (73), and `SHOTS=wealth` one home of each kind at each
household tier it takes (74). `SHOTS=view` compares the classic and perspective cameras
at the Aurum Tower, Midtown and Lantern Square, on foot and driving (80),
the perspective camera backed out of a tower and with the view band
turning buildings round the player see-through (81), and driving flat out
east and north through Midtown and past the Aurum Tower (82), and Settings > Angle at
45, 55, 65, 75 and 90° with tilt off at the Aurum Tower and Lantern Square (83), and the camera turning with the car flat out east, south and west (84). `SHOTS=lights` shows a car's headlights at night on the flat and up and down the hills (86); `SHOTS=nightfx` shows real headlights, street lamps and a police light bar at each graphics quality (87) and the Lantern Quarter's gas lamps (88). `res://tests/occlusion_probe.tscn`
(headless) measures how much of the hero and the street each camera
setting hides (HANDOFF-perspective-camera.md).

The country is generated, not hand-made. After changing `data/world_map.json`
or the street plan, dump the plan and rebuild it (needs `pip install shapely`):

```bash
cd game && godot --headless -s res://tests/plan_dump.gd -- /tmp/plan.json
python3 tools/build_country.py /tmp/plan.json
python3 tools/country_preview.py /tmp/country.png /tmp/plan.json   # a quick look
```

`ONLY=test_a,test_b` before the test command runs just those tests.

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
| `scripts/kits/` | Asset kits: `building_kit`, `prop_kit`, `vehicle_kit`, `character_kit`, `interior_kit`, `country_kit`, `grounds_kit` |
| `data/world_map.json` | The world map: regions, cities, districts, routes, landmarks |
| `scripts/country.gd`, `country_tiles.gd` | The country past the plan: data, road graph, tile streaming; one tile's build |
| `data/country.json`, `tools/build_country.py` | The generated country (play area, roads, lots, walls) and its generator |
| `tools/mountain.py`, `scripts/terrain.gd` | The Bellerive Hills: height field, graded roads and pads (generator side); the height grid the game reads |
| `scripts/taxi.gd` | Taxis: hail, phone call, destinations, fares, ride and skip |
| `tools/render_map.py` | Renders the map data to `world_map.svg` and `bellerive_map.svg` |
| `scripts/mesh_builder.gd` | Bakes coloured boxes into single meshes; surface codes, city shader, shared and x-ray materials |
| `scripts/humanoid.gd` | Shared body: health, punches, combo kick, knockdowns |
| `scripts/rig.gd` | Code animation for the character skeleton |
| `scripts/player.gd`, `pedestrian.gd`, `cop.gd`, `npc.gd` | Characters (`npc.gd`: mission people and enemies) |
| `scripts/missions/` | Mission manager (progress, saving, markers, retry), mission base helpers, missions 1-3, cast looks |
| `scripts/atmosphere.gd` | Time of day, sun and moon, weather, rain |
| `scripts/fx.gd` | Hit-stop, shake, sparks, smoke, splashes, skid marks (autoload) |
| `scripts/minimap.gd`, `full_map.gd`, `map_image.gd`, `state_map.gd` | Minimap, full map, the baked city map and the baked state map |
| `scripts/phone.gd` | The phone and its apps |
| `scripts/places.gd` | Which blocks hold a corner store or diner: names, doors, hours |
| `scripts/interiors.gd`, `kits/interior_kit.gd` | Doors, the fade, building rooms far from the city, people inside, buying and eating |
| `scripts/patron.gd`, `shop_menu.gd`, `inventory.gd` | People inside places, the counter menu, the snack bag and item list |
| `scripts/vehicle.gd` | Car physics; traffic, police, scripted and chaser drivers; riders; lights and effects |
| `scripts/police_manager.gd` | Police spawning and line of sight |
| `scripts/wanted.gd` | Wanted level (autoload) |
| `scripts/population.gd` | Pedestrian and traffic bubble around the player |
| `scripts/controls.gd`, `touch_controls.gd` | Input (autoload) and multi-touch UI |
| `scripts/hud.gd`, `top_down_camera.gd` | HUD and camera |
| `tests/` | Headless tests, screenshot tour and asset gallery (`gallery.tscn`) |
| `tools/` | Cloud setup and APK build |

## Not yet (later milestones)

Missions 4-13, weapons, the rest of the places and services in
`INTERIORS_SERVICES_PLAN.md` (phases 1-6), businesses, audio, wanted levels
3-5, drivable boats and streetcars, people and parked cars in the country,
the rest of the state (phase 3 on), modelled characters (AI-generated models with a
standard animation set, which the skeleton is ready for) and final-quality
art outside the Lantern Quarter.
