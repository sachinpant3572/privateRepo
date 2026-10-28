# Handoff: perspective top-down camera (task #53)

Sachin, 2026-10-28, after the camera demo (HANDOFF-camera-demo.md): "Keep top-down, but switch the
camera to true perspective, the way GTA Chinatown Wars does it: towers lean out as you pass, and the
city feels deep. ... Full 3D seems the best but we will have to overhaul all of our 3D models ... So
we can park it in TODO ... The only concern I have with top down true perspective is that now the
hero and other things will be more hidden as buildings heights will block the view more."

Then: "WE should also give an option is setting to allow players to zoom in or out to some degree",
and "I think it is also better to complete hide the buildings whenever they are blocking any view,
either walking, running, driving, racing or flying ... this does not give us a true perspective of
what is at least 100mtrs ahead which will lead to car crahes or plane crashes."

## Decisions

- D-1 Perspective is the default (`top_down_camera.gd`, `perspective := true`). Settings > View
  switches to the classic orthographic 60° view and back (saved as `"view"`).
- D-2 Pitch 65°, field of view 35°. Measured with `tests/occlusion_probe.tscn` (160 random open-ground
  spots, half downtown, 20:9 screen):

  | View | hero hidden, downtown | street hidden, downtown | elsewhere |
  |---|---|---|---|
  | classic 60° | 19% | 11-13% | 4-5% |
  | persp 60°/35 | 19-20% | 18% | 5-7% |
  | persp 65°/35 | 16-19% | 15% | - |
  | persp 70°/35 | 14-16% | 11-12% | - |
  | persp 60°/28 | - | 16-17% | - |

  70° hides least but flattens people and fronts (less of the 3/4 look the art is made for), so 65.
  These are before the view-band cut (D-5), which clears the near band anyway.
- D-3 The distance frames the same `size` at the focus as the classic view. When the base camera spot
  is inside a tower (towers reach 150 m; the camera sits about 35-90 m up, by size and zoom), `_clear_back` steps it out
  along the view line until it is clear, plus 9 m (`ROOF_AIR`), and narrows the field of view so the
  framing stays the same. It eases out fast and back in slowly; the look-ahead spot is checked too,
  so the camera backs out before reaching a tower.
- D-4 Near fade: surfaces within 0.15 x the base distance of the eye dither out, so a roof just under
  the camera never fills the screen.
- D-5 View band (the "complete hide"): in the cutaway shader, a building pixel is cut when the ground
  it covers (where the eye's ray through it meets the ground at the player's height) lies in a capsule
  round the player and ahead of them: radius 12 m on foot, 16 m in a vehicle (times Zoom), and ahead
  along the velocity by min(speed x 2.5 s, 90 m). Only pixels that hide more than 4 m of ground
  (`HIDE_MIN`) are cut, so low walls, kerbs and fences stay. Footprints and colliders stay, so there
  are no invisible walls. Applies on foot, running, driving and to anything later that flies.
- D-6 Cut edges use an ordered 4x4 Bayer dither (screen-door transparency), not alpha: no sorting and
  no extra pass on phones. The old player-to-camera cutaway cylinder stays, now following the real
  eye (a cone that narrows toward it).
- D-7 Driving lead 0.8 s of velocity (was 0.55), so more of the road ahead is on screen.
- D-8 Settings > Zoom: 80, 90, 100, 115, 130%. City and country streaming radii scale with it above
  100% (105/150 m and 130/210 m times the zoom), and crowds with `Population.reach()` (cap 2.1).
- D-9 Shadows: in perspective the shadow distance is 160 m with tighter splits (`Atmosphere.set_view`).
- D-10 Full 3D is parked in TODO.md (Sachin's condition quoted there). No model changes were needed
  for this camera.

## Rejected

- Pitch 70°: least hidden, but people and shop fronts flatten.
- Dark caps for cut buildings (back faces drawn dark): cut stubs show the ground inside, but drawing
  back faces doubles fill on the tallest meshes, a mobile cost. Revisit if the stubs read badly.
- Whole-building fade (Diablo 4 style): fades the far side of a block the player needs to see, and
  needs per-building alpha sorting.
- Rotating camera (Chinatown Wars): north-up is a design rule (MVP_DESIGN.md), and rotation does not
  fix towers in front.

## Traps

- With the low perspective camera, buildings near or behind the camera are outside the frustum; that is
  correct, not a culling bug.
- The near fade must use the base distance, not the backed-out one, or the whole screen dithers.
- Tests that need "blocked" spots must place the player first, then ask `_view_blocked`; the camera
  position is stale until `_frame` runs.
- The headless window is 16:9; screen-corner tests build a 20:9 frustum by hand.
- `camera_demo.gd` still sets `cam.perspective`; `_frame` now sets `far` and the pitch itself.

## Open

- About 50 m of road shows ahead at top speed to the north (more east and west). 100 m needs about
  1.6x zoom at speed (GTA 2 style speed zoom-out); offer as a Settings option if Sachin wants it.
- A straight-down 90° "2D" view: about 1-2 hours for the camera, plus 0.5-1 session for roof signs
  and stronger hair and hat colours. Not started.
- Aircraft do not exist yet; the band follows any vehicle the camera targets.
- Sachin prefers moving the camera over cutting holes (Oct 28). Probe with the real tower back-out,
  120 spots, downtown hero / street hidden: persp65 18-20% / 15-16%; persp75 15-17% / 10-11%;
  persp85 7% / 4-5% (elsewhere 0-3%); ortho60 20% / 11-14%. A narrower 25° lens changed nothing.
  Proposed: pitch steepens toward 85° near towers and at speed, speed zoom-out, and ghosted (part-
  dithered) buildings instead of holes for what is left. Awaiting his pick.

## Gates

- `game/tests/run.sh`: 696 checks passed, 0 failed (61 tests; new `test_perspective_camera`).
- Shots: tour (53), place shots (12), `SHOTS=view` (12) rendered with no errors.
