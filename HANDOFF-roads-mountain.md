# HANDOFF: civic re-cut, roundabouts, highways, taxi test, mountain

Task (Sachin, 2026-10-28, after the 0.12-california report): "Bigger (about 3 more hours): re-cut the
civic grounds so the last edge street can carry on out (reaching 73 of 75), and rework the City Hall
ring into through streets. Lets do this. Also add more rounabouts, some highways if there are less.
Also, fix the Taxi test. Also build the mountain near it, just like we have in cakifornia."

Follows `HANDOFF-bellerive-ca.md` (C-1 to C-9), which is full; this note carries on as M-1...

## Starting state (measured, seed 1234)

- Civic centre (`street_plan.gd _civic_centre`): City Hall grounds were a 100 x 120 m rectangle off the
  Gilt grid (x 34-134, y 236-356) with its own ring (Capitol Drive); the Esplanade, 64 m wide, ran east to
  Founders Circle (330, 296). Gilt grid lines: x -80, 27, 125, 229, 330; y 140, 203, 255, 320, 383, 440,
  500. Streets cut round it: x 27 (gap y 203-440, `_trim_holes`), x 125 (gap 140-236), y 203 (gap 27-229)
  and y 383 (gap -80-229, both from landmark block growth), and a 26 m stub of y 383.
- Highways round the city: Route 1 Gulf Highway 8.9 km, Route 40 2.5 km, Route 9 1.9 km. The Beltway
  (6.6 km) is an avenue. No highway inside the plan. One roundabout: Founders Circle.
- Ground is flat everywhere: vehicles, people and cops pin y to 0 (`vehicle.gd`, `humanoid.gd`).

## Decisions

- M-1 **Civic centre on the grid** (the DC Mall pattern kept, its streets made the grid's):
  - The grounds become one grid rectangle, x 27-125 by y 255-383 (two Gilt rows), cut out as a void like
    Liberty Green, so its four sides are through grid streets. City Hall (70 x 56) faces east down the mall.
  - The Esplanade's drives are the grid streets y 255 and y 383; the mall runs from x 125 to Founders
    Circle, which moves to (330, 319) on the mall's axis. x 229 meets the mall at T-junctions from both
    sides (one set piece face); y 320 west of the grounds is dropped (it would be a 130 m stub).
  - Government buildings move into single grid blocks that already hold them, so no block has to grow
    and drop streets: Federal Building (76, 172), Courthouse (280, 172), Library (177, 412), Police HQ
    (280, 412) (`world_map.json`). Magnolia Avenue ends at the grounds' north-west corner (27, 255).
