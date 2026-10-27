# Handoff: interiors and services

Plan: `INTERIORS_SERVICES_PLAN.md` (D1-D7, phases 0-6). Sachin: "go ahead
with the interiors and services plan". This note tracks the build.

## Status

- Phase 0 (foundation, corner store, diner): in progress.

## Phase 0 approach (decided before editing)

1. **Places come from block geometry, not from the cell build.**
   - `scripts/places.gd` lists places when the city is built (main
     thread). It walks the same parcels `city_cells._land_block` would
     (`_split` of the lot rectangle; front row only, front edge on the
     sidewalk). It picks blocks with its own RNG, seeded
     `hash([seed, "places"])`, so the cell RNG streams don't change.
   - Skipped: landmark blocks, the park, docks blocks with a quay, and
     blocks outside the window.
   - Each place has:
     - id, type, name, district, face, `parcel` (an index into the
       front-row parcels);
     - `rect`, a shop rect in front-frame coordinates;
     - door (sidewalk point) and yaw, hours, seed.
2. **Storefront in the cell build.**
   - The cell build looks up `city.place_at_parcel(face, k)`. That parcel
     becomes:
     - a shop building at the front centre;
     - the parcel's left, right and back remainders, each built by the
       normal `_district_parcel` (the landmark pattern).
   - Neighbours stay native to the district.
   - Building kit: `Buildings.storefront(type, ...)` with a type sign.
3. **Interiors are built far away** at `Interiors.ORIGIN` (-4000, 0,
   -4000), one at a time.
   - Entering:
     1. fade, then disable and hide every child of `main` except the
        player, camera, atmosphere, HUD, missions and interiors;
     2. `atmosphere.indoors` gives fixed warm lighting: no rain, no wet,
        no night;
     3. the camera frames the room (size 15).
   - Leaving restores each node's saved `visible` and `process_mode`, puts
     the player at the door and snaps the camera.
   - Rooms are built on the WorkerThreadPool during the fade.
4. **Doors are locked**:
   - with stars ("Lose the cops first");
   - during an active mission ("Finish the job first");
   - outside opening hours (CLOSED).
   - On foot only.
5. **Phase 0 types and districts.** Corner store in all five districts;
   diner in Gilt, Ironwharf and Morrow Point. The plan's table had diners
   in Morrow Point only, but phase 0 must be reachable from the start.
   - Counts: corner store 2 per district; diners 2 in Gilt and Morrow
     Point, 1 in Ironwharf (see P0-1).
   - Blocks are picked at least 110 m apart.
6. **Items** (`inventory.gd`):
   - Corner-store snacks go in the bag: carry up to 3; the HUD SNACK
     button or H eats one.
   - Diner meals are eaten seated: Jules sits at a free seat for 4 s and
     health rises over that time.
7. **Patrons** (`patron.gd`, a humanoid) go door → spots → till → door.
   They collide with the world and the player, not with each other.
   Staff stay at their posts.
8. **Save v2**: `version: 2` and `inventory`. A save with no version is
   v1 and loads with an empty bag.

## Decisions log

| # | Decision | Why | Cheaper / bigger option |
|---|---|---|---|
| P0-1 | Ironwharf gets 1 diner, not 2; bigger shop types are placed first | Ironwharf is mostly quay yards: seeds 3 and 99 leave only 2-3 blocks that can take a shop | Bigger: let two places share a block (about 1 h) |
| P0-2 | Doors lock during a mission | Missions set up their own street; going inside would leave them waiting | Unlock with a mission pause (about 2 h) |
| P0-3 | Hitting someone inside gives 1 star and they run out; staff cower | Same rule as the street (`Wanted.report_crime(1)`); robbing tills is phase 1 (D5) | - |
| P0-4 | Snacks: bag of 3, SNACK button / H eats the best one, only when hurt | Light-touch healing that is worth buying; no full inventory screen yet | Bigger: inventory screen (phase 2 with clothes) |
| P0-5 | Phone "Places" app: places sorted by distance, open or closed, GO sets a waypoint | The minimap needs a way to find shops | - |
| P0-6 | Diner glass porch is 0.7 m deep; sidewalk props never stand on a doorstep (`_put` rolls the prop back) | The 1.5 m porch and benches or planters blocked the door point | - |
| P0-8 | `interiors.force_out()` (instant, no fade) runs on respawn, new game and every mission start; `enter()` gives up if Jules is downed during the fade | Review run 1: those paths left the street frozen and the camera on an empty room | Cheaper: hide REPLAY / New game / Retry while inside (leaves the death-in-fade case) |
| P0-9 | Hit or knocked-out diners free their seat; a hit diner slides out of the booth first | Review run 1: the diner filled up for good and ORDER stopped working | - |
| P0-7 | Standing up from a seat is a slide out without collisions, like sitting down | Booth diners got stuck inside the bench collider | - |

## Traps and constraints

- City cells build on a worker thread: places must be plain data, built
  before streaming starts.
- Missions use landmark fronts and their keys: places never take
  landmark blocks.
- Tests: the menu sets a 0.3 s interact cooldown and leaving sets 0.5 s.
  `_enter` and `_leave` in the test runner wait them out.
- Tests that look at far-away cells must move the player there too: the
  streamer unloads cells far from the player on the next frame.
- `ONLY=test_a,test_b` in the environment runs just those tests.
- Touch exclusions must use `is_visible_in_tree()`: the shop menu hides
  its root, not the panel, and the panel covers the right-hand buttons on
  a 16:9 screen. The headless test window is square, so the test resizes
  it to 1280x720.

## Open questions

- None yet.
