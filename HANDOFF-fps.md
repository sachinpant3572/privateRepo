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

## Settings-close hitch

- (see Results)

## Traps

- Performance TIME_PROCESS includes rendering on this build (the probe's
  cpu tracks frame ms); prims = visible + shadow passes.
- perf_probe ms figures on llvmpipe are noisy and CPU-bound; compare
  triangles, not ms.
