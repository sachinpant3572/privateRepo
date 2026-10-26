# Port Lafitte prototype (Godot 4.7)

Milestone 1 of `MVP_DESIGN.md`: one grey-box district to prove that driving,
fighting and the wanted system are fun on a phone and run at 30 fps on a
min-spec device.

## What's in it

- **District**: a 6 x 6 block grid built in code, with pastel low-rise blocks
  with iron balconies, downtown towers, docks with containers, two parks, a
  basketball court, a police station, a hospital and a river. The whole city
  is baked into one mesh, so it draws in a single call.
- **On foot**: jog, sprint, punch. The player shows as a silhouette when
  buildings hide them.
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

Install `build/port-lafitte-debug.apk` (built by `tools/build_apk.sh`, arm64,
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

FPS in screenshots is meaningless: the container renders without a GPU.

## Layout

| Path | Purpose |
|---|---|
| `scripts/main.gd` | Entry point; wires systems, BUSTED/WASTED |
| `scripts/city.gd` | District generator and road graph |
| `scripts/mesh_builder.gd` | Bakes coloured boxes into single meshes; shared toon and x-ray materials |
| `scripts/humanoid.gd` | Shared body: health, punches, knockdowns |
| `scripts/player.gd`, `pedestrian.gd`, `cop.gd` | Characters |
| `scripts/vehicle.gd` | Car physics plus traffic and police AI |
| `scripts/police_manager.gd` | Police spawning and line of sight |
| `scripts/wanted.gd` | Wanted level (autoload) |
| `scripts/population.gd` | Pedestrian and traffic bubble around the player |
| `scripts/controls.gd`, `touch_controls.gd` | Input (autoload) and multi-touch UI |
| `scripts/hud.gd`, `iso_camera.gd` | HUD and camera |
| `tests/` | Headless tests and screenshot scene |
| `tools/` | Cloud setup and APK build |

## Not yet (later milestones)

Weapons, missions, phone, shops, businesses, interiors, day/night and
weather, audio, wanted levels 3-5, boats, and the real Old Quarter art.
