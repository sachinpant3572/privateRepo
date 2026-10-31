# Interiors and services: milestone plan

Sachin's list (the one this plan answers): "highways, bypasses, circular
cross sections, train stations, bus stations, trains and tram routes,
metros, food stalls, weapons/ammo shops, food shops, restaurants, barber
shops, clothing shops, supermarkets that are fully enterable, and can
purchase variety of things, car garages, police stations, car/bike/truck
service shops with services being offered, petrol pumps, gyms, boxing
rings, karate, kung fu, martial arts training centres where the player can
go and learn things, people buying things inside, or training in these
places, or eating etc"; then: "go ahead with the interiors and services
plan".

This plan covers all of it in two milestones:
- **Interiors and services**: places to enter, buy from, eat, train and get
  vehicles serviced.
- **Transit and roads**: highways, bypasses, roundabouts, and working
  trams, buses, trains and metro.

Everything stays built in code, like the rest of the game, with no credits
spent. Sizes below are in sessions: one long working session is about 4-6
hours of build, tests, review and APK.

## 1. Where the game stands (measured Oct 27)

| Area | Today |
|---|---|
| Buildings | Exterior only. Shopfronts (townhouse ground floors, 50% of eligible ones) are decoration; no shop type, door or id is recorded. Each city block is one mesh, one draw call, and solid box colliders. |
| Landmarks with a "door" | `landmark_front(id)` gives a sidewalk point (missions use it). The Pit, the precinct, the clinic, Union Station and Moreau House exist as exteriors. |
| Money | `cash` comes from mission rewards only (500 / 300 / 800); nothing spends it. |
| Save | Missions done, cash, phone and settings. Not saved: position, outfit, vehicles, health. |
| Player look | Fixed (Jules), built once; no way to change clothes or hair. |
| Fighting | One hard-coded set: punch combo ending in a knockdown kick (`humanoid.gd`). No move tables or styles. |
| Weapons | None. |
| Vehicles | 16 models, health and wrecks; paint set at spawn; no fuel, ownership or garage. |
| People | Pedestrians walk sidewalk loops; mission NPCs can walk to points. Poses: walk, run, punch, kick, guard, flinch, down, ride, gestures (phone, talk, wave, hands up, cower, point, search). No sitting, eating or training poses. |
| Transit | Streetcar rails and wires on the Lantern Line with parked streetcars as scenery; bus shelters as props. Nothing moves. |
| Roads | Planar street graph with junction nodes; classes from boulevard (24 m) to quarter (9 m). No grade separation, ramps, roundabouts or highways. |
| UI | HUD, phone and dialogue are built in code (no UI scenes). Touch buttons: PUNCH, RUN, ENTER (relabelled per context). |

Docs already decided some of this (`MVP_DESIGN.md`):
- enterable clothing, weapons, vehicle-tuning and food shops;
- three street businesses: food stand, garage, nightclub front;
- three safehouses with save, garage and wardrobe;
- about 8 weapons;
- one fighting style plus one to unlock;
- boxing and street basketball with ranks;
- a streetcar line and taxis.

Trains and metro were put in Expansion 1. This plan adds what your list
asks for beyond that: barbers, supermarkets, restaurants, gyms, karate and
kung fu schools, petrol stations, police-station and station interiors,
buses, roundabouts and a highway ring.

## 2. Key decisions (picked; each can be overruled)

**D1. How interiors work: enter through a door with a quick fade (picked).**
Walk to a lit door and press ENTER. The screen fades for about 0.3 s, and
the interior is built and shown on its own while the street waits outside.
Leaving fades back to the doorstep. This is how GTA San Andreas and
Stardew Valley do shops.
- Why:
  - an interior can be bigger and richer than its shopfront (a
    supermarket with aisles behind a 10 m front);
  - it costs nothing while you are outside;
  - while inside, only the room is drawn, so a phone has budget for detail
    and people.
- Cost: interiors milestone as planned, about 10 sessions.
- Bigger option: seamless interiors in place. The roof cuts away as you
  walk in, the street stays live, and police can follow you in.
  - Needs hollow buildings with real walls in every cell, door gaps, and
    the interior mesh streamed in when near.
  - About +3-4 sessions, and more triangles per city block.
  - It's a nicer moment, but it limits interior size to the facade.
- Cheaper option: menu shops (GTA Chinatown Wars, Gangstar style). Walk to
  the door and a catalogue opens, with no room and no people inside.
  - About 3 sessions for all the shop types.
  - Fails "fully enterable" and "people buying, training or eating
    inside".

**D2. Shops come from the city itself.**
The block builder already rolls shopfronts; it will also give each one a
type, a name, a door point and a facing, and record them as places. The
roll is deterministic per block, so the same shop is always in the same
place. District mix:

| District | Places |
|---|---|
| Gilt (downtown) | supermarket, clothing (boutique), restaurant, café, gym, barber |
| Lantern Quarter | restaurant, café, clothing (vintage), barber, corner store, karate dojo |
| Floodline Wards | food stalls and a food truck, corner store, barber, clothing (streetwear), kung fu school |
| Ironwharf | service shop (car, bike, truck), petrol station, weapons and ammo, The Pit (boxing) |
| Morrow Point | petrol station, diner, corner store |

Landmarks keep their fixed interiors: The Pit, the precinct, the clinic,
Union Station and Moreau House. Each district gets at least one of each of
its types; more come from the roll. Every place shows on the minimap and
the full map with an icon, and the phone gets a "Places" list.

**D3. Jules stays the protagonist; clothes and hair change.**
This settles open decision 1 in `MVP_DESIGN.md` the way GTA San Andreas did
it with CJ.
- Clothing shops sell items in the existing `character_kit.gd` slots
  (top, bottom, headwear, bag, colours).
- Barbers change hair style and colour.
- The look is rebuilt on change and saved.

**D4. Fuel: light (picked).**
- A full tank lasts about 20 minutes of driving.
- On a low tank a warning shows and the car tops out at half speed; it
  never strands you.
- Refill at a pump or with a can from any store.
- This gives petrol stations a purpose without friction.
- Cheaper option: no fuel. Pumps would then sell car washes and repair
  kits only; about 0.2 session less.

**D5. Wanted and doors.**
- With stars, shop doors are locked ("Not while the cops are after you");
  hiding in shops would break the wanted system.
- Robbing a till is a crime (+2 stars), and the shopkeeper flees or fights.
- Entering the police station with stars counts as surrendering: you are
  busted, without losing your weapons.

**D6. Learning to fight.**
Fighting moves to data: move tables, each move with its timing, reach,
damage, knockdown and pose. Each school teaches a style through three
lessons, each a guided practice of one combo; then you spar against the
teacher to earn the style. This follows GTA San Andreas (beat the gym
trainer) and Sleeping Dogs (learn a combo, do it three times, then win
fights).

| Style | Where | Character |
|---|---|---|
| Street (default) | none | current punch combo and kick |
| Boxing | The Pit | fast jabs, guard, body blows, best one-on-one |
| Karate | Lantern Quarter dojo | long-reach kicks, sweeps |
| Kung fu | Wards school | flowing combos, crowd control |
| Kickboxing | Gilt gym | heavy knees and kicks, stagger |

You pick the active style in the phone (Skills). Gyms also train strength
and stamina through short tap mini-games, capped per in-game day as in San
Andreas.

**D7. Research proposals adopted for this milestone** (from
`reference/README.md`, part C2):
- #8: claimed garages as fast-travel points;
- #13: weapon classes with one job each;
- #15: no stash micromanagement;
- #16: garage time instead of real-time timers;
- #17: safehouse slots for garage, armory, bed and wardrobe;
- #19: a collection log for outfits, cars and moves.

## 3. The shared foundation (phase 0)

Every place uses these, so they come first.

1. **Place registry** (`places.gd`).
   - Each place has an id, type, name, district, door point and yaw, an
     interior template and seed, opening hours, and a stock table.
   - Sources: the cell builder (D2) and landmarks.
   - Places have no build cost when far away; the registry is plain data
     built with the street plan.
2. **Doors.**
   - A lit door marker with a sign and an open or closed state (hours from
     the game clock).
   - Near it, the ENTER button reads ENTER, CLOSED or LOCKED.
   - Vehicle service shops and petrol stations use a drive-in bay
     instead: stop in the bay to get the service menu.
3. **Interior manager.**
   - On entry: fade out, pause city streaming and street population
     around the door, then build the room from its template on a worker
     thread during the fade.
   - Put the player at the inside door; the camera switches to the
     interior framing (orthographic size about 16, same 60° pitch).
   - Walls on the camera side are drawn low (about 0.6 m, a doll-house
     cut) so nothing hides the player.
   - On exit: restore the street exactly as it was.
4. **Room kit** (`interior_kit.gd`): walls, floors (tile, wood, rubber gym
   mat, concrete), counters, tills, shelves and freezers, clothing racks,
   mirrors, barber chairs, booths and tables, kitchen pass, fuel pumps,
   car lifts, heavy bags, weights, treadmill, boxing ring, tatami, ticket
   machines, benches.
   - All built from the same mesh builder and surface codes as the city.
   - One room is one or two meshes, with collision boxes.
5. **Templates** per place type: size ranges, zones (entrance, aisles,
   counter, seating, training floor) and where people stand. The same
   seed gives the same room on every visit.
6. **People inside.**
   - Activity spots (browse a shelf, queue at the till, sit and eat, get a
     haircut, hit the bag, spar, lift, stretch) and a simple scheduler.
   - People come in through the door, do two or three activities, pay and
     leave.
   - Shopkeepers stand behind counters. Counts scale with the place size
     and time of day.
7. **New poses** (`rig.gd`): sit, eat or drink, carry a basket, browse
   (reach a shelf), lift, skip rope, stretch, and "work" (behind a
   counter or at a car).
8. **Shop menu UI** (built in code like the phone):
   - categories, items with price and stats, buy and equip;
   - "can't afford" state;
   - for clothes and hair, a live preview on Jules (camera closes in).
9. **Wallet and inventory** (`inventory.gd`):
   - cash;
   - items: food and drink (heal now or carry up to 3), fuel can, repair
     kit, ammo, weapons;
   - owned clothes, owned vehicles with paint and parts, learned styles,
     stats.
10. **Save v2**: everything in 9, plus the last safehouse position and
    business state. The current save migrates to it.

Phase 0 ships with two working places to prove the loop end to end: a
corner store (buy a snack, eat it to heal) and a diner (sit, order, eat).

## 4. Phases and sizes

| Phase | Content | Size |
|---|---|---|
| 0 Foundation | Section 3, plus the corner store and diner | 2 |
| 1 Food and daily life | Food stalls and a food truck, corner stores, the supermarket (aisles, basket, checkout queue), restaurants and cafés (sit, order, eat, a short heal-over-time or stamina buff), petrol stations (pumps, mini-mart, car wash) and light fuel (D4) | 1 |
| 2 Looks | Clothing shops in three styles (boutique, vintage, streetwear) with about 60 items, barbers, the wardrobe at Moreau House, collection log | 1 |
| 3 Vehicles | Owning cars (bought on the phone or taken and kept), the Moreau House garage (store 2, claim as fast travel), service shops for cars, bikes and trucks (repair, respray, performance parts per model: engine, brakes, tyres, suspension, with garage time), car wash | 1.5 |
| 4 Fighting and training | Move tables replacing the hard-coded combo, the four schools and styles (D6), gym stat training, The Pit boxing ladder (ranked fights), people training and sparring inside | 2 |
| 5 Civic | Precinct lobby (pay a fine to clear one star, impound lot to recover seized cars, bounty board for vigilante side jobs, busted respawn inside), clinic (wasted respawn inside, pay for full heal), Union Station hall (ready for trains) | 0.5 |
| 6 Weapons | The 8 MVP weapons (bat, knife, pistol, revolver, SMG, shotgun, rifle, molotov): aiming with soft auto-aim, a weapon wheel, ammo, armed police at 3+ stars, the weapons and ammo shop and a shooting range | 2 |

**Total: about 10 sessions, roughly 45-60 hours of build.**

Phases 1-5 depend only on phase 0, so after phase 0 two of them can run in
parallel on separate files (each with its own agent). That cuts wall-clock
time by about a third and costs about 20% more tokens for merging and
re-testing.

Order, and why:
1. Food first: it gives cash its first use and proves people inside.
2. Looks next: your most-asked visible change.
3. Vehicles: they build on the driving work just finished.
4. Fighting, then civic.
5. Weapons last: the largest single system, and it changes police
   balance.

## 5. Transit and roads (next milestone, about 6 sessions)

| Piece | Content | Size |
|---|---|---|
| Streetcar | Streetcars run the Lantern Line on the existing rails; ride as a passenger (fast travel between stops) or drive it as a side job | 1 |
| Buses | Two routes on the main streets with stops at the shelters, a bus station by Union Station, ride or drive the route job | 1 |
| Roundabouts | A new junction type in the street plan for 4-5 way junctions on boulevards; traffic AI yields on entry | 1 |
| Highway and bypass | Route 1 (already in `world_map.json`) as a raised highway ring past the demo area with on and off ramps and a bridge-level deck. Needs grade separation in the street graph: two levels with ramps. This is the riskiest change to the map, so it comes last, with the map tests extended. | 2 |
| Trains and metro | Union Station platforms, a train line to the edge of the map, the Porto Brisa metro (Expansion 1 in the concept: with the second city) | Expansion 1 |

## 6. Budgets and checks

- **Interior:**
  - at most about 30k triangles and 8 draw calls;
  - at most 10 people animated;
  - built within the 0.3 s fade on a mid-range phone (built on a worker
    thread, like city blocks).
- **Street:**
  - door markers add one small mesh per loaded place;
  - city blocks stay one draw call each;
  - per-block triangles stay within today's p90 (7.1k).
- **Gates for every phase:**
  - headless tests (below), the screenshot tour with new interior shots
    read through contact sheets, the asset gallery with a room-kit row;
  - an independent review (up to two runs);
  - an APK with a version bump, and the PR updated.
- **Tests:**
  - enter and leave restore the street (position, car, wanted, time);
  - buying takes the right cash, adds the item and survives save and
    load;
  - closed hours and LOCKED with stars;
  - people inside finish their activities and leave (none stuck after
    60 s);
  - every shop type appears in every district that lists it (seeds 1, 2,
    3, 7, 42, 99, 1234);
  - a learned style changes the moves;
  - service, respray and parts change the car;
  - fuel runs down and refills;
  - the save migrates from v1.

## 7. Risks

- **Cell builder:** recording places adds data to the worker-thread build.
  Shop rolls must stay deterministic, or lots after them lay out
  differently (the tree pass hit this).
- **Mission keys:** missions use landmark fronts and the keys "scooter",
  "sports" and the cast outfits. Those stay.
- **Save migration:** must keep the v1 progress of anyone who has played
  missions 1-3.
- **Phone frame rate:** phone FPS has not been measured since the modern
  look (cells now about 30% heavier) or the wider driving camera.
  Interiors are drawn alone, so they are not the risk; the street is.
  Measure on the S25 Ultra and the low-end phone with the phase 0 APK.

## 8. What Sachin can change

- D1 (fade doors versus seamless versus menu shops);
- D4 (fuel or no fuel);
- the phase order;
- which places each district gets;
- running two phases in parallel.

Nothing here needs a live-system change or spends credits.
