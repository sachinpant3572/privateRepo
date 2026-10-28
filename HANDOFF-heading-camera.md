# Handoff: camera that turns with the car (task #54)

Sachin, 2026-10-28, after asking whether the camera turns with the car the way Chinatown Wars does:
"Research more on this, I am sure you will come up with much better design while keeping the same
Camera movement as chinatown wars."

Builds on HANDOFF-perspective-camera.md (pitch, tower tilt, see-through ghost, look-ahead).

## Research (2026-10-28, search excerpts only: the research agent's page fetches were blocked)

- Chinatown Wars: an overhead chase camera "slightly behind the lead character" that "rotates to keep
  the action mostly facing up the screen" (GamesRadar hands-on); re-centre on a shoulder button
  (Fandom controls page: L on DS); PDA > System > Settings has "Vehicle Camera Look Ahead" 0-10 (car
  sits lower on screen at speed) and "Auto Reverse Vehicle Camera" (camera swings round when backing
  up; players advise turning it off). Steering is car-relative: D-pad on DS, left/right arrows on
  iOS (analog option). Radar has a north blip.
- Complaints: dizziness from constant turning (GameSpot user review, GameFAQs PSP board), hard to see
  down the street so players overcorrect (Engadget), slow behind tall buildings (GameSpot review).
- Craft: rotating in place disorients; lag must not change the control frame (Haigh-Hutchinson,
  Real-Time Cameras); critically damped springs; let players turn auto camera off (Xbox AG 117);
  freeze the stick's frame until release (dual-stick article, Unity thread); north-up maps build a
  mental map, heading-up suits following a route (Aretz 1991).
- Not verified: Chinatown Wars' turn speed, pitch, whether it follows facing or velocity, on-foot
  behaviour, whether its radar turns. No source gives numbers; all values below are ours, tuned by
  tests.

## Decisions

- H-1 Settings > Camera turn: "With car" (default) or "North up" (the camera before this task).
- H-2 In a vehicle the yaw follows the car: facing blended toward the velocity heading as the slip
  grows (sliding), held while slip > 90 degrees (spins) or reversing (no auto-flip), held below
  3 m/s, ignores wobbles under a small dead zone. Critically damped, quicker at speed, capped turn
  rate and acceleration (comfort).
- H-3 Seeing ahead: heading-up on a 20:9 landscape phone puts the road on the short axis (60 m,
  2.9 s ahead before). At speed the car sits lower (lead cap 0.76 keeps it >= 8 m off the bottom
  edge, lead 1.8 s), the view flattens 10 degrees (65 -> 55) and widens to 68 m (from 60). Measured
  flat out: sedan 72 m ahead at 20.5 m/s (3.5 s), super 74 m at 30.5 m/s. The tower tilt still
  overrides. The 100 m target was dropped: it needs about 1.6x the loaded area and the car at the
  screen edge; this middle option loads about 1.5x (screen corners reach 111 m vs 90 m).
- H-4 Stick layout in a car, With car: steer by stick (x = wheel, push up = gas, down = brake and
  reverse; gas eases off as the stick leans over, so full lock lifts off as a
  d-pad did). Point-to-go under a turning camera ties the turn rate to how fast the camera catches up;
  steer-by-stick ties it to the thumb only. Arrows and tilt layouts unchanged; North up keeps
  point-to-go.
- H-5 On foot the camera stops turning, so the screen-relative stick never circles. Standing still,
  it eases to the nearest compass direction (90-degree steps; the city grid is north-south almost
  everywhere). The stick's frame is frozen while held.
- H-6 Compass: tap the minimap's N to re-centre (behind the car; north-up on foot).
- H-7 Minimap turns with the camera, N rides the rim; the full map stays north-up.
- H-8 Inside places the camera is north-up (rooms were built for it).
- H-9 Turn dynamics (tuned in a Python model, then measured): critically damped toward the goal with
  half-life 0.35 s stopped -> 0.25 s at 22 m/s (0.25 s for a re-centre), an 8 deg/s floor so the
  tail ends, capped at 90 deg/s and 180 deg/s^2; it lands exactly on the goal (north stays square
  to the pixels). A 90-degree car turn: the view settles about 1 s after the car, peak lag ~28 deg.
- H-10 The stick's frame follows the view while driving (steer-by-stick does not need it frozen);
  on foot it is frozen while the stick is held and the view turns, then eases round to the landed
  view at 86 deg/s (a compass tap or getting out mid-swing no longer leaves it off).
- H-12 Getting into a car turns the view behind it at once, parked or not (review finding 1).
- H-11 Settings > Reset camera leaves Camera turn alone (a mode, not a tuning value).
- H-13 (0.18, Sachin: "camera should follow the player not the car") On foot with Camera turn
  on, the view follows the walking heading too: moving over 1 m/s, the goal is the walk direction,
  with a wider dead zone (20 deg), a slower half-life (0.6 s) and a 60 deg/s cap, so short dodges
  and fights don't swing it. Standing still still squares it up after 1.2 s. Setting relabelled
  "Camera turn: Follow" (saved value stays "car"); the variable is now `turn_view`.
- H-14 The stick's frame on foot replaces H-10's catch-up: captured from the view when the stick
  is pressed, held while it is held steady (so a sideways push never circles as the view follows),
  and re-captured from the view when the thumb swings more than 25 degrees from where the frame was
  taken, so a deliberate change of direction always reads in the screen as it is now. The catch-up
  was dropped: with the view following the walk, it would spiral.
- H-15 Settings > Drive zoom-out (Off, 25..100%, default 100% = 0.17's framing): scales how far the
  view widens with speed in a car, and the flatten with it, so Off keeps the on-foot framing
  while driving. The look-ahead is capped to the frame, so the car stays on screen. Distance (was
  Zoom) gains 60% and 70%; Angle unchanged. All three are - / + steppers under a Camera heading.
- H-16 A gear button on the HUD, always shown (the PHONE button only shows once the phone is
  unlocked), opens the phone straight to Settings.

## Rejected

- Fuel Overdose "lazy" camera (turns only to stop the car pointing down the screen): calmer, but not
  the Chinatown Wars movement asked for. Could be a third setting later.
- Auto-reverse flip: players turn it off in Chinatown Wars.

## Gates (2026-10-28)

- test_camera_turns_with_car: steer-by-stick, 80-degree turn with the view settling within 4 deg at
  <= 90 deg/s (80 measured), screen up = car heading, reverse holds, < 3 m/s holds, compass
  re-centre, North up back to 0, look-ahead (sedan >= 3.3 s, super >= 70 m), on foot no turn, minimap
  N tap, route drive with every screen corner loaded (0 of 219 outside). Older tests run north-up.
- Shots 84_turn_* (SHOTS=view).
- Review (one run): no hard bug; fixed: entering a car, the on-foot stick frame, the back-off memo
  ignoring yaw, full-lock gas, `screen_from_world` frame. Suite timeout 180 -> 300 s (188 s now).
- Phone FPS: Sachin reports 120 FPS on his phone with 0.17 (2026-10-28), so the 1.5x area holds.

## Open

- A ~100 m look-ahead option (1.6x area) if 72 m feels short at speed.
- Lazy camera as a third setting (Rejected above) if constant turning makes anyone dizzy.
- Chinatown Wars' own numbers are unverified (see Research).
- The wider streaming reach applies whenever With car is on, on foot too (about 1.5x the area);
  scaling it with speed would save load, but measure on a phone first.
- In the Lantern Quarter's 30-degree grid, squaring on foot settles 30 degrees off the streets.
- No mission, chase or taxi test runs in With car mode (they all start north-up).
- test_taxi_phone_call_and_skip failed once in a full run (the cab never arrived) and passed alone
  and on the next runs: intermittent, not traced.
