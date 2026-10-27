# Handoff: driving layouts and the four-city world (v3)

Started 2026-10-27. Sachin's asks (verbatim in the session):

1. "Give a button for acceleration, or give 3 different control panels just like we have in driving
   games. Improve map view and actual city map. It should be like 4 different cities ..."
2. "go ahead with both, research and controls. For the city, ensure that one city has one of the best
   architectural plans setup (Like San Francisco, New York, Washington DC, California etc), 2nd would
   be a desolate city like Detroit, 3rd would be like Las Vegas, and the last can be like Florida ..."
   (plus transit per city condition, countryside, military, factions, services, aircraft, boats,
   rentals, scheduled travel, taxis).
3. Mid-task: "Add more details to the map, add short routes, non paved roites through mountains etc too."

## Status

- Controls: done (commit a12cd13). 411/411 checks.
- Research: done, `reference/world/` (4 notes + README synthesis).
- World v3 plan: `WORLD_V3_PLAN.md`; bible and game README updated.
- Map data v3, with a detail layer:
  - routes: lanes, dirt tracks and trails;
  - creeks and Bluegill Lake;
  - peaks, fords and bridges;
  - roadside stops: gas, motel, campsites, farms, lookout, mine, lighthouse.
- SVGs carry terrain patterns.
- In-game state map: full map zoomed out and minimap past the edge.
  `test_state_map_shows_the_whole_state`; `tests/map_shots.tscn`.
- Suite 420/420. The plan dump equals the baseline (only its `ms` timing field differs).
- Next: review, APK 0.9-world, commit, PR.

## Decisions (Sachin can overrule any of these)

- **C-1 Three layouts, pedals in all.** Stick + pedals (the old direction stick, plus GAS/BRAKE),
  Arrows + pedals (wheel steering, the phone-racer standard), Tilt + pedals (gravity sensor). Picked
  in Phone > Settings, saved. Cheaper option was a lone GAS button on the old layout.
- **C-2 Wheel layouts drive like a car:** no corner assist, off the pedals the car coasts, brake held
  at a stop reverses, the tail swings the way the wheel turns. Steering eases in over 0.2 s.
- **C-3 Tilt reads `Input.get_gravity()`** (falls back to the accelerometer); both sensors are enabled
  in project.godot (off by default in 4.7). Sign checked against Godot's Android source (values are
  turned to the screen and point along gravity). Not yet tried on a real phone.
- **W-1 City mapping.** Bellerive becomes the Florida-like Gulf city (it already has the Gulf, the
  swamp, the hurricane and the port; it keeps its name, districts and all missions, and gains a
  Deco beach district and the Keys). Las Brasas stays the Vegas city. Two new cities: **Concordia**,
  the planned capital (DC radials and Mall, Manhattan blocks, SF bay, hills and red bridge), and
  **Steelhaven**, the desolate motor city on Lake Corran (Detroit). Porto Brisa is retired; its
  beach crews (Os Corvos, Comando Maré) move to Bellerive's beach and the Keys. The two new names
  are working names: the bible's names were approved, these are not yet.
  Rejected: Bellerive as the desolate city (it has no motor industry; its storm wards already give
  it a ruined edge).
- **W-2 State size 12 x 9 km** (108 km² with the sea, about 75 km² of land), up from 8 x 6. Cities
  take about a fifth of the land, near San Andreas's and GTA V's ratios; neighbouring cities sit
  2-4 km apart (about 2 minutes by car). Cheaper option: keep 8 x 6 and squeeze four cities in
  (about 1 minute apart, little room for countryside).
- **W-3 v3 data shifts the old map by (+2000, +3000)** so Bellerive's local coordinates (and so the
  playable city) are unchanged: the game reads everything relative to `demo_window.origin`. Mission
  `pos` stops shift too. Checked by a plan dump before and after, and the suite.
- **W-4 Seamless state, built in phases** (recommended) vs **city-hop** (cheaper: each city its own
  map, travel by fade). Costs in WORLD_V3_PLAN.md.
- **W-5 Scheduled flights, trains and ships are a kiosk, a fade and arrival** (San Andreas's tickets,
  GTA IV's skippable taxi), not simulated rides: Rockstar cut GTA IV's ferries for physics trouble.

- **W-6 Detail layer** (Sachin's mid-task ask):
  - Three new road kinds below `road`:
    - `lane`, a paved county road;
    - `track`, unpaved, drawn dashed;
    - `trail`, 4x4 or hiking, drawn dotted.
  - Where a lane, track or trail crosses a river or creek, a bridge (lane) or ford
    landmark is computed.
  - The new items carry `"detail": true` and a phase of 2 or more, and lie outside
    Bellerive's window (the generator asserts it).
  - Generator: scratchpad `add_detail.py` (one-off; the json is the source of truth now).
- **W-7 State map bake at runtime** (about 0.1 s on the desktop, more on a phone)
  rather than a shipped PNG: it follows the json with no export step. Cheaper on load:
  cache the image to `user://` keyed by the json hash. Not done; not needed yet.

## Traps and lessons

- Research agents could not open source pages (proxy blocked); facts rest on search summaries,
  each labelled in the notes. Treat single-source numbers as rough.
- Full-map zoom changes need `queue_redraw()`; screenshots taken without it show the
  previous frame.
- Image colours round to 8 bits: compare with a tolerance (`_same_color`), not
  `is_equal_approx`.
- `city.district_at` falls back to the nearest district: districts outside the playable window must
  be marked with a phase above 1 and skipped when loading, or they can win that fallback.

## Open questions for Sachin

- The names Concordia and Steelhaven (alternatives in WORLD_V3_PLAN.md).
- Retiring Porto Brisa (Rio).
- Tilt steering needs a check on a real phone.
