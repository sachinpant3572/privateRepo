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
  is inside a tower (towers reach 150 m; the camera sits about 30-90 m up, by size and zoom), `_clear_back` steps it out
  along the view line until it is clear, plus 9 m (`ROOF_AIR`), and narrows the field of view so the
  framing stays the same. It eases out fast and back in slowly; the look-ahead spot is checked too,
  so the camera backs out before reaching a tower.
- D-4 Near fade: surfaces within 0.15 x the base distance of the eye dither out, so a roof just under
  the camera never fills the screen.
- D-5 View band (the "complete hide"; since E-4 a see-through ghost, not a cut): in the cutaway shader, a building pixel is cut when the ground
  it covers (where the eye's ray through it meets the ground at the player's height) lies in a capsule
  round the player and ahead of them: radius 12 m on foot, 16 m in a vehicle (times Zoom), and ahead
  along the velocity by min(speed x 2.5 s, 90 m). Only pixels that hide more than 4 m of ground
  (`HIDE_MIN`) are cut, so low walls, kerbs and fences stay. Footprints and colliders stay, so there
  are no invisible walls. Applies on foot, running, driving and to anything later that flies.
- D-6 Cut edges use an ordered 4x4 Bayer dither (screen-door transparency), not alpha: no sorting and
  no extra pass on phones. The old player-to-camera cutaway cylinder stays, now following the real
  eye (a cone that narrows toward it).
- D-7 Driving lead 0.8 s of velocity (was 0.55). Superseded by E-2 (1.1 s, capped to the screen).
- D-8 Settings > Zoom: 80, 90, 100, 115, 130%. City and country streaming radii scale with it above
  100% (105/150 m and 130/210 m times the zoom), and crowds with `Population.reach()` (cap 2.1).
- D-9 Shadows: in perspective the shadow distance is 160 m with tighter splits (`Atmosphere.set_view`).
  It grows to 1.4 x the camera's distance when the camera backs out over a tower (`_fit_shadows`).
- D-11 Review fixes (Oct 28): no cut reaches the shadow pass (`IN_SHADOW_PASS`), so buildings keep
  whole shadows; ground (terrain, roads) carries UV2.x 1 (`MeshBuilder.mark_ground`) and the band never
  cuts it, so hills ahead stay whole; the band widens up to 3x while the camera is backed out over a
  tower; `_clear_back` keeps each caller's answer while its point stays within 1.5 m (refreshed every
  30 frames); crowds ignore points behind the camera; classic `far` reaches an aircraft's ground.
- D-10 Full 3D is parked in TODO.md (Sachin's condition quoted there). No model changes were needed
  for this camera.

## Phase 2: move the camera first, see-through buildings last

Sachin, Oct 28, on the options (steeper tilt near towers, speed zoom-out and look-ahead, see-through
buildings, flying later, keep north-up and outlines): "Yes lets build this as best as possible."

- E-1 Steeper tilt by sight, not by height: every 0.25 s `best_pitch` tries 65, 70, 75, 80 and 85°
  and takes the lowest from whose (unbacked) camera spot the player and all but one of up to seven
  open-ground points (a ring at 0.3 x size and the look-ahead point) are in sight; going lower needs all
  in sight; if none works, the one hiding least, steeper on a tie. Pitch eases (~1 s).
  Tipping up is at once only while the player is hidden; for ground points alone it waits for 3
  agreeing checks (0.75 s); at most 10° a check. Tipping down waits 1.5 s after the last tip up and 3
  agreeing checks, then drops to the highest of them. Measured at 30 m/s (downtown / low-rise):
  turn-backs 9-12 a minute -> 2.8; tilt travel 116-149 -> 51°/min; time above 67° in low-rise
  districts 13-19% -> 7-11%. Rejected on review: tip up at once with a 3 s hold and 5° steps down
  (no hunting, but steep 35-44% of the time in low-rise districts, up to 28 s at a stretch).
  Rejected first try: tilting by the tallest roof round the view (25 -> 80 m) left the hero hidden 18%
  downtown, no better than 65°, because the tower in the way is often not the tallest sampled.
  Speed does not tip it: at 75° the road ahead north-south fell from about 62 to 57 m.
  Probe (120 spots, real tower back-out), downtown hero / street hidden: persp65 18-20% / 15-16%;
  persp85 7% / 4-7%; picker 7% / 6% on foot, 11% at driving zoom; elsewhere hero 0%; ortho60 20%.
- E-2 Speed zoom-out: DRIVE_SIZE 48 -> 62 m, reached at 28 m/s. Lead 1.1 s of velocity, capped per screen
  axis so the car stays on screen: east-west 0.6 x the half width, north-south 0.75 x the ground from the
  focus to the trailing edge (from the pitch and lens). Target: about 100 m ahead east-west, 60 m+
  north-south at top speed.
- E-3 Streaming follows the screen: the city loads round the camera's focus (TopDownCamera.stream_point)
  as well as round the player, so the lead never runs past loaded cells.
- E-4 See-through buildings: the view band and the player cutaway no longer discard to nothing; they
  thin a building to GHOST (31% of pixels, ordered dither) and pale it, so its shape stays and the street
  shows through. The near fade (camera inside a roof) still cuts fully. Same cost as before.
- E-5 Settings > Angle (40-90° in 5° steps, default 65), Tilt near towers (on/off) and Reset camera
  (65°, tilt on, Zoom 100%). Sachin, Oct 28: "Give me a setting to change camera angle too, so that I
  can test and share my feedback on which angle would be better, but also give option to reset the
  camera angle and zooming." The angle is the lowest pitch; with tilt on the picker steepens from it
  to 85°. Perspective view only (classic stays 60°). Saved as "angle" and "auto_tilt".

## Rejected

- Pitch 70°: least hidden, but people and shop fronts flatten.
- Dark caps for cut buildings (back faces drawn dark): doubles fill on the tallest meshes, a mobile
  cost; E-4's see-through ghost replaced the hollow stubs instead.
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

- From the review, left as is: trees, lamps and signals taller than about 4.4 m inside the band dither
  out (lamp halos then float); a low building can still hide a strip up to 4 m wide beside the player
  (`HIDE_MIN`); Zoom 130% loads about 1.7x the city cells (phone memory not measured).

- Phase 2 review leftovers: the ghost can cover the whole screen when the camera is backed out over
  a tower (the band widens up to 3x); the picker scores the unbacked eye, so a pitch change can still
  pop the camera out over a tower; city cells don't carry the ground mark (the city is flat, and the
  band only touches what is above the player's feet). Phone frame rate and the 4x4 ghost pattern at
  phone DPI are not measured; a phone builds city cells more slowly, so corner pop-in at 30 m/s
  may show there. Speed does not steepen the tilt (E-1); Sachin can overrule.
- A straight-down 90° "2D" view: about 1-2 hours for the camera, plus 0.5-1 session for roof signs
  and stronger hair and hat colours. Not started.
- Aircraft do not exist yet; the band follows any vehicle the camera targets (item 4: steep and high).

## Gates

- `game/tests/run.sh`: 714 checks passed, 0 failed (61 tests). `test_perspective_camera` (28 checks)
  drives city routes at 30 m/s: downtown turn-backs <= 12 a minute (old picker 19.5, now 7.5),
  low-rise time above 67° <= 15% (first hold 21%, now 0%), and 20:9 corners over streamed cells at
  100% and 130% zoom after the build queue drains. That last check also passes with the view
  streaming (E-3) reverted: the player's own radius covers the corners; E-3 starts builds earlier.
- Shots: tour (53), place shots (12), `SHOTS=view` (16, with 82_drive) rendered with no errors.
- Phase 2 reviews (two): pitch hunting at speed, then the steep hold in low-rise districts, a tilt
  check that passed on the old code and a streaming check that depended on build-thread timing; fixed.
  The hole cut no longer skips marked ground (a hill between player and camera ghosts like a
  building, and bridges cut again).
