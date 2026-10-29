# 0.25.2: frame rate still dropping (Sachin's 0.25.1 log)

Sachin, 2026-10-29, with a 0.25.1 device log (SM-S938B, Ultra, arrows):
"Also check this, frwne rates are still dropping".

## What the log shows

- Sustained drop, t=946-949: 45-52 fps while driving 67-85 km/h, camera
  backed out (cam_d 42-47 m, pitch 42-43 degrees). prims 250-306k a frame
  against about 210k parked; cpu (which includes rendering) up to 19.9 ms.
- One 61 ms frame at t=940.8, the frame Settings closed (cpu max that second
  7.6 ms, phys 0.7 ms: not script or physics work).
- 87 ms at t=957 (paused): the log export while sharing (1.77 MB). 8.3 s:
  the app in the background. Both expected.

## Cause of the sustained drop (measured, tests/perf_probe.tscn)

- The sun's shadow reached at least 160 m in 4 cascades, while the
  perspective camera frames 30-65 m of ground. Each cascade draws every
  caster in it again: on the probe (llvmpipe, the log's spot at night,
  Ultra) shadow passes were 171-181k of 201-226k triangles.
- Fitted to the view (1.4 x view_depth) in 2 cascades: shadow 56-72k,
  total 87-111k (about half), frame about 356 ms against 700-780 ms on
  llvmpipe (CPU-rendered, so only the ratio means anything).

## Decisions

- atmosphere.gd: perspective uses SHADOW_PARALLEL_2_SPLITS (split 0.4) and
  max distance = 1.1 x max(40 m, 1.4 x view_depth); grows at once, shrinks
  only when 25% too far (no refit every frame, no cascade shimmer). Classic
  view keeps 4 splits and 300 m (its ground is 205-235 m away).
- The 160 m floor (commit 96a29b5, D-9 in HANDOFF-perspective-camera.md)
  had no recorded reason beyond "reach past the screen"; the tower test
  (shadows >= 1.25 x view_depth when backed out) still holds.
- Near cascade is sharper than before (about 24 m deep against 48 m).

## Results (2026-10-29)

- perf_probe with the fit as shipped: parked 104k triangles (shadow 74k),
  fast 114k (shadow 69k), against 201k / 218-226k in 0.25.1.
- Shots (perf_probe -- <dir>, 15:30, parked and fast, 0.25.1 vs fit): the
  same shadows, the near ones a touch sharper; draws 92 -> 71, 100 -> 77.
- Log snap gains `shd_prims` (shadow-pass triangles) for the next log.
- Tests: test_perspective_camera checks 2 cascades and a reach of
  1.25-2x view_depth, and 4 cascades / 300 m in classic.

## Review fixes

- Look up and mission close-ups see toward the horizon, past view_depth:
  while either is on, the reach is at least SHADOW_FAR (160 m).
- Grows once want x 1.05 passes the reach (was want), and perspective
  fades shadows over the last 10% (fade_start 0.9): the top strip of the
  screen is never in the fade while the camera backs out.
- Still open: looking downhill, ground past view_depth can sit outside the
  reach (view_depth assumes level ground).

## Settings-close hitch (not changed)

- One 61 ms frame on the frame Settings closed (paused -> playing), with
  cpu 7.6 / phys 0.7 ms that second: GPU-side (likely the game view's 3D
  coming back on: disable_3d false, buffers and shadow maps redrawn).
- perf_probe times the 8 frames after close: no long frame on llvmpipe, so
  it can't be reproduced here. A one-off on closing a menu, not in play;
  left as is. If it matters: turn 3D back on two frames before the page
  hides (close() would turn async; 16 tests call it).

## Traps

- Performance TIME_PROCESS includes rendering on this build (the probe's
  cpu tracks frame ms); prims = visible + shadow passes.
- perf_probe ms figures on llvmpipe are noisy and CPU-bound; compare
  triangles, not ms.
