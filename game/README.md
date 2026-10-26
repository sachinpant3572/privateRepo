# Solvera prototype (Godot 4.7)

Milestone 1 of `MVP_DESIGN.md`: prove that driving, fighting and the wanted
system are fun on a phone and run at 30 fps on a min-spec device, now on the
demo map that later milestones build on.

## What's in it

- **Demo map**: 1.3 km x 1.1 km of Bellerive, 25 x 22 blocks, from the world
  map (`data/world_map.json`, the city's `demo_window`). You start outside
  **Union Station** in the Gilt District. Each block takes its layout from
  the map district it falls in:
  - **Gilt District**: mid-rise glass towers on stone plazas, street lights,
    traffic lights, rooftop helipads and gardens.
  - **Lantern Quarter**: rings of Creole townhouses with cast-iron galleries
    round shady courtyards, gas lamps, crepe myrtles.
  - **Floodline Wards**: rows of shotgun houses with porches and backyards,
    storm-damaged houses with blue tarps, empty lots, power lines.
  - **Ironwharf**: warehouses, container yards and gantry cranes over the
    river.
  - **The Morrow River** cuts across the south: animated water, railings,
    moored boats; roads stop at the water.
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
- **Streaming**: the map is split into cells (one block plus its roads).
  Cells within ~115 m of the player are built on a worker thread and freed
  past ~165 m; each cell is one mesh (one draw call) and one static body.
  Parked cars come and go with the player too. Every cell is about
  0.1k-3.6k triangles and builds in under ~10 ms.
- **Asset kits** (`scripts/kits/`): code-built, vertex-coloured low-poly
  buildings, props, vehicles (sedan, taxi, police, pickup, van, sports car,
  each with its own handling) and people (skin, hair and clothes mixed per
  pedestrian). No textures; everything shares one toon material.
- **On foot**: jog, sprint, punch.
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
- **HUD**: health, wanted stars (flashing while police can't see you),
  speed, prompts, FPS and draw-call readout.

## Controls

| Action | Touch | Keyboard | Gamepad |
|---|---|---|---|
| Move / steer | Left half of screen (floating stick) | WASD / arrows | Left stick |
| Punch | PUNCH | Space / J | X |
| Run / handbrake | RUN / BRAKE | Shift | A |
| Get in / out | ENTER / EXIT | E / F | Y |

Tab toggles the on-screen controls on desktop.

## Play it on Android

Install `build/solvera-prototype-debug.apk` (built by `tools/build_apk.sh`, arm64,
debug-signed). Android will ask you to allow installing from that source.

**Performance check for this milestone**: play for a few minutes on a
min-spec phone (~4 GB RAM, mid-range 2021 chip) and note the FPS in the top
left, on foot and while driving through traffic.

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
(every building, landmark, vehicle, person and prop in a row).

FPS in screenshots is meaningless: the container renders without a GPU.

## Layout

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Entry point; wires systems, BUSTED/WASTED |
| `scripts/city.gd` | Map data, road graph, sidewalks, cell streaming |
| `scripts/city_cells.gd` | Builds one cell: roads, district block layouts, landmarks, street furniture |
| `scripts/kits/` | Asset kits: `building_kit`, `prop_kit`, `vehicle_kit`, `character_kit` |
| `data/world_map.json` | The world map: regions, cities, districts, routes, landmarks |
| `tools/render_map.py` | Renders the map data to `world_map.svg` and `bellerive_map.svg` |
| `scripts/mesh_builder.gd` | Bakes coloured boxes into single meshes; shared toon and x-ray materials |
| `scripts/humanoid.gd` | Shared body: health, punches, knockdowns |
| `scripts/player.gd`, `pedestrian.gd`, `cop.gd` | Characters |
| `scripts/vehicle.gd` | Car physics plus traffic and police AI |
| `scripts/police_manager.gd` | Police spawning and line of sight |
| `scripts/wanted.gd` | Wanted level (autoload) |
| `scripts/population.gd` | Pedestrian and traffic bubble around the player |
| `scripts/controls.gd`, `touch_controls.gd` | Input (autoload) and multi-touch UI |
| `scripts/hud.gd`, `top_down_camera.gd` | HUD and camera |
| `tests/` | Headless tests, screenshot tour and asset gallery (`gallery.tscn`) |
| `tools/` | Cloud setup and APK build |

## Not yet (later milestones)

Weapons, missions, phone, shops, businesses, interiors, day/night and
weather, audio, wanted levels 3-5, drivable boats and streetcars, bridges
across the river, Magnolia Heights and Blackwater Bayou, and final-quality
art.
