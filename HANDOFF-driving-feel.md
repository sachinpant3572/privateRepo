# Driving feel

Task: Sachin, Oct 27: "I think the graphics are good, just that all roads
seem to be small to drive comfortably without hitting anything, maybe the
cars speed are too high or roads are too narrow or that habdling is not
handled correctly?"

## Findings (measured before changing anything)
- Roads are not narrow for the cars: a street is 11 m curb to curb, so
  5.5 m per direction (real lanes are 3-3.7 m); cars are 1.75-2.05 m wide.
  Parked cars are sparse (one on a quarter of the streets).
- Full throttle down a 70 m block reaches top speed in every model
  (compact 75 km/h, sedan 86, sports 111, super 129), and a 90-degree turn
  on the stick barely slows the car: it runs on 10-20 m past the turn
  point (sedan 13.5, SUV 17.6, muscle 19.5). A junction of two 11 m
  streets leaves about 8 m before the far sidewalk, its poles and the
  building fronts.
- The camera shows about 30 m ahead driving north or south at speed
  (ortho size 38 at 60 degrees plus a 0.35 s lead), about 1.2 s.
- A scrape at more than 4 m/s into a wall or prop halves the speed and
  damages the car, and the floating body counts it again every frame it
  stays pressed in.

## Decisions
1. Corner assist (vehicle.gd): when the stick asks for a turn sharper than
   about 20-60 degrees, the target speed drops toward the speed at which
   the model can turn on a 5 m radius (`CORNER_RADIUS`), and the car
   brakes for it at its own brake rate; no power slide while it brakes.
   The handbrake skips the assist (drifts stay). Player only: on traffic
   it broke the AI's own junction speeds (a pickup looped against a
   corner and passed 1 junction in the traffic test), so AI keeps its
   tuning.
2. Lower city speeds: every model's top speed x0.85 and acceleration
   x0.75, so ranks and character stay and top speed is no longer reached
   in one block. Cheaper option: leave speeds and rely on 1 and 3.
3. Camera: zooms out further with speed (38 -> 48 m) and leads further
   (0.35 -> 0.55 s of travel).
4. Wall hits: the velocity into the wall is slid off, so a hit counts
   once, and `speed` drops to what is left along the heading (plus the
   accel/grip lag), so head-on stops and a scrape costs little. Police
   "stuck" now reads real movement, since a pinned car's speed sits ~2.
5. Roads stay as they are (widening moves every block and landmark).
6. TRAFFIC_THROTTLE 0.5 -> 0.6 keeps traffic cruise speed about where it
   was after the x0.85 (sedan 12 -> 12.3 m/s).
7. Spawns (population.gd `_in_view`): people, traffic and parked cars no
   longer appear on screen. The 48 m camera sees up to ~60 m ahead, inside
   the old bands. Parked cars appear anywhere out of view within 90 m (the
   55 m floor would leave curbs empty that were in view on the way in).

## Review (one run) and fixes
- Assist braked on any partial stick on a straight (20 -> 14.3 m/s in
  0.5 s at 0.7 stick): it now brakes only when it lowers the target
  itself (now 16.0, coasting). Tried scaling the brake by the angle and a
  later onset; both made run-on 1-1.5 m worse, so the brake stays full.
- Pinned on a wall, `speed` wound up to top speed (HUD 68 km/h, police
  never reversing): fixed by decision 4.
- Spawns in view at the wider zoom: decision 7.
- No tests for the new behaviour: added below.

## Results
- Corner run-on past the turn point, stick snapped from north to east
  after a 70 m run from rest (m), before -> after: sedan 13.5 -> 8.7,
  SUV 17.6 -> 9.7, muscle 19.5 -> 12.5; after: compact 7.2, EV 9.2,
  sports 9.5, super 9.9, motorbike 9.4, scooter 5.5. From exactly top
  speed (the test): sedan 8.2, SUV 10.8, super 10.8. What is left is
  braking to corner speed plus the time to rotate 90 degrees.
- Swerve (stick 30 degrees off, 0.25 s at 20 m/s) costs about 1 m/s.
- 15-degree scrape at 20 m/s: keeps 20.5 m/s, 3.2 health (was 9.5 m/s,
  8.8 in 3 hits). Pinned 2 s: speed 1.8 m/s, 3.3 health (was 48).
- Tests: the drive test waits 120 frames (slower launch); speed ranks time
  0-15 m/s instead of 0-20 (lower top speeds, and sedan and luxury tied at
  20); the box truck check is now "never reaches 15 m/s"; the scooter's
  "never reaches 20" check went, since nothing slow reaches 20 now.
- `test_player_driving_assists`: easing off coasts, a swerve keeps speed,
  90-degree run-on under 11 m (sedan, SUV, super), a scrape keeps speed,
  a pinned car's speed stays low and its crash counts once.
- `test_city_runs_with_population` also drives flat out along the
  straightest streets and checks nothing new appears in view (without
  the fix 3 of 57 did). 296 checks pass.

## Open questions
- At top speed most models still run on past the ~8 m a junction gives
  (sedan 8.2, SUV and super 10.8). A player who brakes or turns earlier
  makes it; a stronger assist would take control away. Next levers if it
  still feels tight: turn rate, then a smaller CORNER_RADIUS.
- The drawn area is ~1.6x larger at full zoom; phone FPS not measured.
- Feel on a phone is not verified; the numbers are from scripted stick
  inputs. If turns still feel late, the next lever is turn rate, then a
  smaller CORNER_RADIUS.
- Roads unchanged; widening is the bigger option if Sachin still wants it.

## Traps
- A corner test scene needs `Controls.override_vector` as a Vector2; the
  camera-relative path needs a camera (`ground_axes` on Nil otherwise).
