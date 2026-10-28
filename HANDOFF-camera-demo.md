# Handoff: camera options demo

Sachin, 2026-10-28, after the cost of a 3D conversion: "Can you build a short demo of both options and
show to me? Show it in three perspectives, player walking, driving a car and flying a plane."

The two options were (from my cost answer the same day):
- Option 1, perspective top-down: the same 60° camera, but true perspective, so towers and aircraft
  loom. About half a session to adopt.
- Option 2, full 3D: a third-person camera behind the player, car or plane. About 6-10 sessions to
  adopt (far view with simple distant buildings, phone performance, ceilings in interiors, street-level
  gaps, tests).

## Decisions

- D-1 Show the current top-down camera too, as the reference, so each perspective has three clips:
  now, option 1, option 2.
- D-2 A recorded video (Godot Movie Maker, 30 fps, 1280x720), not an APK: Sachin can watch it at
  once on his phone. `tests/camera_demo.tscn` records it; each clip opens with a title card.
- D-3 Prototype code kept small and off by default, so the game plays exactly as before:
  - `top_down_camera.gd`: `perspective` (35° field of view, distance set so the view frames the same
    `size` at the focus) and `zoom_override` (for aircraft);
  - `scripts/chase_camera.gd`: the third-person camera (behind, swings to the heading, pulls in at
    walls);
  - `City.LOAD_RADIUS` / `UNLOAD_RADIUS` and the country's are static vars, so the demo can widen
    streaming for the far views (330 m on the ground, 740 m round the plane's loop); depth fog hides
    where streaming stops. A real option 2 needs distant low-detail buildings instead.
- D-4 The plane is a box model on a scripted loop round downtown (320 m radius, 150 m up, 42 m/s,
  banked). There is no flyable aircraft in the game yet (world v3 plans aircraft).
- D-5 The car is a red sports car on a scripted drive along a downtown avenue (the taxi autopilot).
  The walk is along the Lantern Square sidewalk.

## Traps

- `Plane` is a built-in Godot type; the demo's aircraft class is `Aircraft`.
- `--check-only` on a script that names the `Controls` autoload reports "Identifier not found"; the
  real run is fine.
