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

- M-1 **Civic centre on the grid** (the DC Mall pattern kept, its streets made the grid's). Built:
  - Grounds = one grid rectangle x 27-125, y 203-320 (`CIVIC_GROUNDS`, snapped), cut out as a void like
    Liberty Green; its four sides are through grid streets. Founders Circle sits on the mall axis at
    (330, 261.5). The mall runs x 125 to the circle; x 229 meets it at T-junctions; the cross street west
    of the grounds is dropped (a stub).
  - Rejected: grounds at y 255-383 (circle at y 319 put Liberty 2.6 m off Midtown junctions, merges bent
    streets). The courthouse (needs 40 m depth) did not fit 229-330 x 140-203 beside the Aurum
    boulevard, so it swapped with Police HQ: Federal Building (76,172), Police HQ (280,172, faces south),
    Courthouse (280,352, faces north), Library (177,352), City Hall (76,261.5).
  - Liberty Avenue bends at Liberty Circle to the nearest grid y at the east edge, so its frame
    crossing does not sit 14 m from a grid junction (which had blocked y 987 from carrying on).
- M-2 **Roundabouts** (`street_plan.gd ROUNDABOUTS`): Liberty Circle (690,500) r30 with a statue,
  Aurum (1010,140), Cypress (1010,500), Harbor (690,1400) r26 with fountains; rings are avenue class.
- M-3 **Every drivable edge street carries on**: east y 621 was blocked by the 40 m keep-clear round the
  Torque & Tone garage (a map landmark at local (1600,650)); now 25 m. DMV and east school moved east
  of Sunvale. Frame junctions: w 21/22, n 15/15, e 18/18, s 18/19; the two left are the levee path and
  the quay (width 0, not streets). So every drivable edge street carries on: 72 of 74 frame junctions
  by this count (the earlier "72 of 75" was before the civic re-cut changed the frame). The test counts frame junctions
  with a drivable street inward and the corners left out, 70 of 70, and now requires all of them.
- M-4 **Taxi test** (intermittent "cab 20 m off"): from 17 of 153 start nodes a called cab stopped across
  Aurum Boulevard, because the near side's shortest route ran along the curb street (a U-turn). Fix:
  `_round_the_block` enters that end by another street; the far side costs 600 m (a block loop), not
  250. Probe: all 153 starts now stop 6.6 m away.
- M-5 **Highways**: the Bellerive Beltway (6.6 km ring) becomes highway class, and a new **Canyon
  Freeway** runs from the Beltway north through the mountain's saddle to Route 1 (about 2.5 km).
- M-6 **Mountain: drivable** (about 7 h; the cheaper option, scenery only with flat roads round it,
  about 3 h). Where: the empty ground north of the Beltway between Route 9 and Route 1 (local x
  250-1800, y -420 to -1800), like the Santa Monica Mountains above LA. Data: `tools/mountain.py`
  (height field, roads, landmarks) used by `build_country.py`, exported as a height grid in
  `country.json`. Game: `terrain.gd` height lookup; vehicles and people follow it (the two y pins);
  country tiles in the mountain drape their vertices and draw a subdivided ground.
  Content: Crest Drive on the ridge, Coyote Canyon Road with hillside houses, Observatory Road with a
  hairpin, a fire road to the radio masts, the hillside letters, chaparral.

## The mountain as built (M-6 detail)

- **Shape** (`tools/mountain.py`): the Bellerive Hills, outline local (165..2210, -430..-1840); ridges are
  Gaussian bumps along polylines (a spine plus spurs toward the city and the north), value noise, an
  edge falloff. Calder Peak 114 m at (1100,-1255). Map: region `bellerive_hills` (type mountains,
  phase 1) and landmarks `lumen_observatory`, `hill_letters`, `calder_peak` in `world_map.json`.
- **Roads** graded to a profile (max grade per class: highway 7.5 %, road 13 %, track 25 %), pinned at
  their ends and at crossings with earlier roads; the grid is cut and filled to them with banks no
  steeper than 0.4. Canyon Freeway (Beltway x 690 -> saddle (770,-1262) -> Route 1), Crest Drive
  (Route 9 -> ridge -> Route 1), Coyote Canyon Road, Observatory Road (hairpins), Summit Fire Road
  (track), Letters Trail. Steepest measured on the final grid: freeway 10.7 % (bilinear 8 m cells
  round the saddle bends), Crest 17.4 %, fire road 29 %.
- **Pads**: every plot and lot near the hills sits on a flat pad at the height of the road it fronts
  (a lot in a plot at the plot's; both masts on one summit compound level with the fire road's end).
  Each grid node takes its nearest pad's height, flat a cell past the lot, fading over 12 m; inside
  a lot always the pad; a road keeps its own grading a cell past its edge. Report: worst pad 1.06 m
  off flat. Hillside homes only where the road climbs under 9 % past the frontage, 60 % skipped.
- **Game**: `terrain.gd` (static height grid, bilinear); `vehicle.gd` and `humanoid.gd` set y from it,
  cars pitch and roll to the ground and feel a slope pull; `country_tiles.gd` subdivides the ground
  on hill tiles (9 m), lifts lots and plots rigidly to their pad and drapes everything else per
  vertex, and bakes a hillshade into the ground colour (north-west light, dark scrub on north faces,
  gold on south faces, rock near the top).
- **Landmarks** reuse the skyline kit's monuments (`observatory`, `hillside_letters`, `radio_mast`),
  dispatched from `country_kit.gd`. Lot sizes 64x44, 150x26 (letters about 15 m tall), 18x18.
- **Cost**: a hill tile builds in about 19 ms (flat about 8 ms) on the worker thread, desktop.
- Test: `test_bellerive_hills`. Shots 45-52 (`SHOTS=hills` runs just those).

## Review fixes (one independent review, nothing blocking)

- Hill roads followed a straight chord between nodes while cars follow the bilinear ground: up to
  0.52 m off it, so grass showed through and lane lines were buried. Now road strips, junction
  discs, drives and trails on hill tiles are cut into triangles of 4 m or less (`_flat`), solid lines
  into 4 m pieces, kerbs into 4 m pieces, and markings sit 5 cm up. Measured in the test from the
  built tiles: road 0.011 m off the ground at worst, edge lines 0.05-0.08 m above it.
- A car stopped on a slope with nobody on the gas now holds, as if on its parking brake, and goes to
  sleep (it crept about 1 cm/s downhill and never slept).
- Traffic look-ahead measured its distance from the lane in 3D against a lane point at y 0; on the
  hills that is the height, so it clamped to 2 m and traffic weaved. Now flat (x, z).
- Taxi: the round-the-block loop is now one more option beside the U-turn (scored +400) instead of
  replacing it, so a sparse country grid takes no long loop. City probe unchanged (stops on the
  player's side from every start).
- Observatory Road ends 7.5 m short of the lot (the generator keeps lots 2.5 m off a road's edge); a
  drive (`paths`) now runs from its end to the forecourt. The dead-end exemption is narrowed from
  "within 30 m of any landmark front" to "a road end where a drive carries on to a lot".
- Not fixed: pads up to 1.06 m off flat at one mansion (a corner floats or sinks by that much at
  most); grades over the class limits (freeway 10.7 %, Crest 17.4 %) from 8 m cells at bends; two
  rare test checks that skip silently when no patron or seated diner exists (pre-existing; making them
  fail instead would make the suite flaky).

## Traps

- `profile_at` only answers within a road's shoulder; a pad needs `profile_near` (the fronting road).
- One big box (a forecourt) draped per vertex tilts between its corners and the subdivided ground
  pokes through: lots on pads must rise rigidly.
- Pads processed in order let a later one override an earlier neighbour: use nearest-pad.
- Any change to the generator's RNG use shifts lots in every zone (fronting lots 1531 -> 1511).
- A long box draped per vertex cuts a chord through curved ground: anything long on a hill tile
  (road strips, lines, kerbs) must be cut into short pieces before `_drape`.
- Sampling a mesh exactly where two pieces meet misses both (barycentric round-off): test points
  sit off the middle of an edge.
