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
4. Scrapes: a hit costs speed by how square it is (head-on still halves
   it), and a hit counts once for the player too, as for traffic.
5. Roads stay as they are (widening moves every block and landmark).

## Results
- Corner run-on past the turn point, stick snapped from north to east at
  full speed (m), before -> after: sedan 13.5 -> 8.7, SUV 17.6 -> 9.7,
  muscle 19.5 -> 12.5; after: compact 7.2, EV 9.2, sports 9.5,
  super 9.9, motorbike 9.4, scooter 5.5. What is left is the time a model
  needs to rotate 90 degrees at its turn rate.
- Tests: the drive test waits 120 frames (slower launch); speed ranks time
  0-15 m/s instead of 0-20 (lower top speeds, and sedan and luxury tied at
  20); the box truck check is now "never reaches 15 m/s"; the scooter's
  "never reaches 20" check went, since nothing slow reaches 20 now.
  285 checks pass (one fewer than before).

## Open questions
- Feel on a phone is not verified; the numbers are from scripted stick
  inputs. If turns still feel late, the next lever is turn rate, then a
  smaller CORNER_RADIUS.
- Roads unchanged; widening is the bigger option if Sachin still wants it.

## Traps
- A corner test scene needs `Controls.override_vector` as a Vector2; the
  camera-relative path needs a camera (`ground_axes` on Nil otherwise).
