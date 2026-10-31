# 0.25.1: people-spawn stutter and stiff turns

Sachin, 2026-10-29, with log `solvera_log_2026-10-29_13-51-45.txt`: "See the
log please, there are a lot of stuttering issues and frame rate drops. Also,
the vehicle turns are still stiff."

## What the log shows (0.25 session, S25 Ultra, Ultra, 60 fps cap)

- 60 hitches against 11 in 0.23. fps median 59.9, p10 41.
- On foot, t=1-7 s: people 1 -> 19, one every 0.25 s, and `phys` (the
  slowest physics step each second) reads 38-45 ms, with 52-60 ms frames.
  Once the crowd is full (t=8-21) phys falls to 2-13 ms.
- Driving at 100-150 km/h (t=22-39): people despawn and respawn all the
  time, phys 44-52 ms every second, and fps holds at 32-41. When the crowd
  stops churning (t=40 on), it is a steady 60 again.
- Cause: every new person is built (CharacterKit.build_rig: MakeHuman blend,
  clothes, mesh) on the main thread, inside Population's physics tick.
  Desktop timing (60 category looks): 6 ms a person with warm caches and
  14 ms with cold ones; that is about 40-50 ms on the phone.
- Traffic spawns at t=15-17 show cpu 25-31 ms without dropping frames.
  Open-top cars (roadster, cabriolet) also build one or two seated people on
  their first frame; that build moves off the main thread too.

## Decisions

- The build is split. `CharacterKit.prepare(look)` does the slow, scene-free
  half: joints, MeshBuilder geometry and surface arrays. It is safe on any
  thread and holds `CharacterKit.lock` (BodyKit's caches are shared).
  `CharacterKit.assemble(made)` does the main-thread half: the Skeleton3D,
  the Skin and the ArrayMesh upload. `build_rig = assemble(prepare(look))`.
- `PeopleBuilder` (scripts/people_builder.gd) runs prepare() as
  WorkerThreadPool tasks: `request(look)` returns a ticket and `ready(t)`
  says when it is done. It waits on every finished task, orphaned ones
  included, so none is left un-waited.
- Population keeps up to 3 people building or built ahead (look and
  category picked on the main thread from its rng). A sidewalk spawn takes
  a finished one; if none is ready it skips that tick rather than build
  inline. `spawn_ped_at` (missions, tests) still builds at once when
  nothing is ready.
- Open cars order their seated people from PeopleBuilder and show them
  once built (a few frames later).
- Rejected: a recycle pool of despawned bodies. The worker builds a person
  in well under the 0.25 s between spawns even on the phone, and reuse would
  show the same person twice.

## Stiff turns

- Sachin drives with `controls=arrows` (digital steer buttons) and holds
  the gas pedal. A probe (gas and full lock held from a steady speed)
  showed the car kept accelerating through every turn: the crossover went
  from 12 to 25 m/s within one 90-degree turn. Its circle grows with the
  square of speed, so held turns ran wide: 21 m at 43 km/h and 42 m at
  72 km/h, against 7 m and 18 m coasting. The stick scheme has a corner
  assist; arrows, tilt and the on-screen wheel had nothing. That is why
  three rounds of more grip (0.22-0.24) never fixed "stiff".
- Fix: tyre scrub (`TURN_RADIUS` 9 m, `SCRUB` 6 m/s²) for the player's
  wheel schemes. Gas can't push past the speed whose grip-limited circle
  is TURN_RADIUS / lock, and above it the tyres shed up to SCRUB x lock,
  on or off the gas. Not while drifting or on the handbrake; traffic
  unchanged.
- After, gas held, 90-degree turn: crossover 43 km/h 10 m / 1.32 s
  (was 21 m / 1.87 s), 72 km/h 17 m / 1.63 s (was 42 m / 2.58 s); sports
  72 km/h 12 m / 0.98 s (was 22 m / 1.35 s), 100 km/h 20 m / 1.27 s (was
  38 m / 1.73 s). Test: `test_held_gas_turns_stay_tight`.
- Rejected: a fourth grip raise. Lateral grip is already 1.65g
  (crossover) to 3.4g (sports); held gas, not grip, made the turns wide.

## Review (one run)

- Fixed:
  - **The crowd test missed the sidewalk refill.** Reverting the refill to an inline build still passed. It now checks the refill takes the oldest built body, and fails on the revert.
  - **People builds queued behind city streaming.** Godot gives low-priority tasks about one thread on 4 CPUs, and builds that wait on the lock blocked city streaming. PeopleBuilder now runs one build at a time, at high priority.
  - **The kit lock stayed locked after a script error.** prepare() now unlocks after a helper call, so an error can't leave it locked.
  - **The stick steering through a turning view counts as a wheel scheme.** It always skipped the corner assist, so it gets the tyre scrub. The comment is fixed and the test now has a stick case.
- Open, minor:
  - **Foot cops, interior patrons and mission NPCs still build on the main thread.** That was already true before 0.25.1. They may now also wait up to one worker build for the lock.
  - **Population._exit_tree drains up to 3 builds.** This only happens at quit.

## Traps

- A test that times or checks BodyKit's caches must not race a background
  build: wait for PeopleBuilder to go idle first (`PeopleBuilder.drain()`).
- Headless test frames run faster than real time: a wait on background
  builds uses `_within(cond, seconds)` (wall clock), not a frame count.
  (`_until` is the taxi tests' frame-count helper; a second `_until`
  stopped the whole runner with a parse error.)
