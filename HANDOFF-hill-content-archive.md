# Hill content: archived notes

## Phase 2 plan (life)

- Flora bands by height already exist (flora_kit `pick`: pine from 120 m,
  oaks thinning above 450 m, rock above 680 m); phase 2 adds wildflower
  meadows and ferns only.
- Packages (cost ~ each builder 1-2 h + an Opus review; the cheaper option
  is all in the main session, slower and serial):
  W wildlife (builder): scripts/wildlife.gd, kits/animal_kit.gd,
  tests/wildlife_tests.gd. C calendar + events (builder): scripts/calendar.gd,
  scripts/events.gd, tests/calendar_tests.gd. H hunting (after W; touches
  inventory, shop, hud, player): main session. Hikers/runners/hunters on
  trails (generator walks + population looks): main session.
- Test modules: test_runner.gd runs `TEST_MODULES` (each a script with
  `const TESTS` and `func test_x(t)`), so builders never edit test_runner.gd.

## Phase 1 plan (done)

1. **Places** (#122). Generator (main session): a `hill_places` step in
   build_country.py before `street_lots`, from a HILL_PLACES table (kind,
   x, y, id): frontage lots along the nearest way for the two villages, a
   trailer park cluster, single sites for the rest; the lab road and the
   timber haul as mountain_plan SPECS; Tallow Lake and Fernmoor Pond as
   level water with dug beds; streams as ribbons; walks in the villages so
   people spawn; mountain-zone diner/store/hunting store open as places.
   Kit (builder agent, owns scripts/kits/hill_kit.gd): research_lab,
   lab_gate, sawmill, cult_compound, ranger_post, logging_camp,
   mine_entrance, stone_ring, hot_spring, cold_spring, mountain_hotel,
   lodge_hotel, rave_clearing, bungee_platform, fairground, hunting_store.
   Reused kinds: diner, gas_station, general_store, motel, truck_stop, bar,
   house, garage, town_hall, trailer park (cluster style "trailers").

# Moved from HANDOFF-hill-content.md (2026-10-31, session 2)

## Status
- Phase 1 committed: hill_kit (e3f7d00, review fixes in), TEST_MODULES
  hook (a708f59). Hikers/hunters on 14 trail loops (trail_walks read
  self.trails; a point-offset loop on the 12 m resampled line, since round
  joins and switchbacks put points 6 m off). Hunting store opens as a place.
- Sachin 10-31: "It can be single hikers, couples or group of hikers, not
  same all the time" -> trail parties (Pedestrian.TRAIL_PARTY/pick_party,
  join_party slots; population queues bodies by party). Hikers 1-4,
  runners 1-2, hunters 1-2 in file. Done, tested (aa80800).
- hunting.gd + shop rows + save in (tests/hunting_tests.gd); shooting
  waits on the wildlife API.
- Calendar + events (package C) in and wired (39bb3df): main.gd makes
  calendar and hunting BEFORE missions (missions._ready loads the save into
  them; hunting used to be null there), events after taxi; save/load/reset
  carry "calendar" and set atmosphere.sky.day = calendar.day() (moon and
  the cult's full-moon rule day % 8 == 2 must agree); phone Events app.
  calendar_tests use the game's own nodes (a second Events built twice).
  Gates: 9 calendar tests 129/0; hunting, bag/save, phone, taxi-phone,
  city-population pass.

## Handover (paused 2026-10-31 at Sachin's request)
Resume order (each step: focused tests, then commit and push):
1. Wildlife (package W, 6d820f8, committed WIP, unreviewed, NOT hooked in):
   scripts/wildlife.gd, kits/animal_kit.gd, tests/wildlife_tests.gd (9
   tests; run in TEST_MODULES), tests/wildlife_gallery.tscn. API: static
   attach(atm) -> node; static startle(pos, r); animals_in(pos, r,
   with_dead); kill(a, dir, by); hurt(a, dmg, dir, by); carcass_near(pos,
   r); take_carcass(c) -> kind; signal killed(kind, pos, by). Animal dict
   keys: check _make() (kind deer/rabbit/coyote/lion, pos, dead, hp, ...).
   a. Patch atmosphere.gd: `const Wildlife = preload(...wildlife.gd)`,
      `var wildlife: Node`, `wildlife = Wildlife.attach(self)` after the
      birds block. Patch fx.gd: same preload, and after each
      Birds.startle (4 calls) the matching Wildlife.startle with the same
      pos and radius 18-28 / 20+30*strength / 60*scale / 25.
   b. Render check: game/tests/wildlife_gallery.tscn "all" under xvfb
      (opengl3), contact sheet, judge buck/coyote/lion/rabbit colours and
      night eyeshine (only the doe was checked after the colour fix); tune
      hide colours in animal_kit _deer/_rabbit/_coyote/_lion. Gallery
      blood decals pile up on z=0 (give each row its own z).
   c. Per-package Opus review of W, fix findings.
2. Hunting on the real API (main session): hunting.gd already calls
   _wildlife() = atmosphere.wildlife; adapt to the dict keys, then tests:
   shoot a deer in season, poaching (closed season / no licence / lion)
   gives a star, skin a carcass for a pelt. Name clash: hunting passes
   "lion", calendar's season table says "mountain_lion": use one (L8).
3. Calendar review leftovers (review of 39bb3df; H1 and M2 fixed):
   M1 time skips lose days (phone Skip 3 h runs paused; call
   calendar.tick after each press) and sky.day drifts while indoors
   (_apply_indoors skips sky.update): make the calendar the only day
   counter and have sky.gd read it. M3 event lights sit on top of the
   street-lamp budget: graphics should subtract Events.lights_used.
   Lows: ArrayMesh not cached per kind (rebuilt on each re-entry); queued
   PeopleBuilder tickets still build after free; show_banner shares the
   district label; phone Events should skip non-finite pos; stale
   comments calendar_tests.gd:7-8, sky.gd:47-48.
4. Phase 1 screenshots never taken: Tallow Lake, a stream, Brackett,
   Hollin, hunting store interior, trail parties.
5. Phase 2 close: full game/tests/run.sh, screenshots, one Opus review
   of the whole task, then phases 3 and 4 (above).
Every godot run under `flock /tmp/godot.lock`; worst off-flat 4.25 m at
(2341,-2140) near Brackett is unchecked (new or old).



## Session 2 log (moved at the pause): Resumed 2026-10-31 (session 2, branch claude/gangstar-game-content-tunnels-kszhz9)
Sachin's order: wildlife hook-in + colours + Opus review; hunting on the
animals with tests; calendar fixes M1, M3; hill-place shots, full suite,
one review of the whole task; then phase 3 and phase 4.
- Done (8d8840f, + tests commit): wildlife attached in atmosphere.gd,
  Wildlife.startle beside each Birds.startle in fx.gd (radii 28/18,
  20+30s, 60*scale, 25). Colours retuned after the gallery (ACES makes
  hides orange): doe 0.55/0.45/0.35, buck 0.47/0.39/0.31, coyote fur
  0.52/0.47/0.40, lion fur 0.62/0.50/0.37. Eyeshine: a 1-px yellow glint
  at game range (eyes 3 cm), kept.
- Hunting: carcass_near returns {} (not null): hunting._carcass maps it
  to null (the HUD threw a script error every frame). Season table key
  is "lion" (wildlife's kind); "mountain_lion" still parses. Tests:
  shoot a deer in season, poaching (no licence / deer in winter / lion),
  skinning (full bag keeps the carcass).
- M1: Atmosphere.advance(hours) counts each midnight (calendar.add_days);
  phone Skip and taxi skip use it; sky.update ticks atm.calendar and reads
  its day (sky counts its own only with no calendar: galleries).
  M3: graphics._light_lamps budget = lamps - Events.lights_used.
  Calendar Lows (mesh cache, PeopleBuilder tickets after free, banner
  label, phone non-finite pos) not done: not in Sachin's list.
- Shots: SHOTS=hillplaces (screenshots.gd, hill_1..7) and PLACES=hill
  (place_shots.gd: the hunting store front, door, inside, menu).
- Trap: the test runner does NOT fail on SCRIPT ERROR; grep for it.
- Wildlife review (Opus, 0 High, 3 Medium, 8 Low), all fixed: lion warns
  on the HUD (wildlife.warned signal) when it stalks and charges, leaves
  for good after one strike (a.spent), a lion shot while stalking or
  charging is self-defence (no star); refresh keeps carcasses within
  DESPAWN; carcass slide stops at blocked ground or a road; in_city cached
  per 8 m cell; no work with no animals; leave kept at obstacles, leaving
  animals (not lions) still flee; cars >6 m above/below scare nothing,
  kill gap 2 m (bridges); _push sets only changes; MMI interpolation off
  (birds too). Tests tightened (startle, day lion, indoors) + Fx test.
- Trail shot: no trail person came by loop 904 in 20 s at noon, so the
  shot scripts a party; 26 of its 128 points lie within 6 m of a road.

## Session 2 handover (moved 2026-10-31, session 3)
Branch `claude/gangstar-game-content-tunnels-kszhz9` (pushed). Sachin's
order this session: wildlife hook-in + colours + Opus review; hunting on
the animals with tests; calendar fixes; hill-place shots, full suite, one
review of the whole task; then phase 3 and phase 4. Session log: archive.
Done and pushed (8d8840f, 5f75299, a3697f3, then the pause commits):
- Wildlife in atmosphere/fx, colours retuned (gallery checked), Opus
  review: 0 High, 3 Medium, 8 Low, all fixed (details in archive).
- Hunting: shoot a deer, poaching star (no licence, out of season, lion),
  lion shot while stalking/charging = self-defence, skinning; tests.
- Calendar: skip time keeps days (Atmosphere.advance), moon follows the
  calendar after indoors, event lights share the lamp budget; tests.
- SHOTS=hillplaces 7/7 checked (villages centred, trail party on the
  dirt trail) and PLACES=hill (hunting store) 6/6.
Last full suite (a3697f3): 2132 passed, 2 failed; both fixed since and
each verified alone (not yet in a full run):
- test_wildlife_stays_out_of_lakes: flaky (2/3 alone). The player stood
  18 m from the herd; a standing player's flee radius is 25 x 0.7 =
  17.5 m. Player moved to 12 m off: 3/3 PASS.
- test_country_plots_square_to_their_roads: kestrel_lab 80.2 deg off
  Kestrel Hollow Road (failed on 4197417 too). build_country.py
  `_site_skew` (= `_road_turn`, the test's own measure) rejects site spots
  over 3.5 deg off the road edge within 8 m of the front. Country rebuilt
  (a4837f3): only kestrel_lab moved (547.7,-4041.5 yaw 0.17 -> 561.2,
  -4038.8 yaw 0.44); terrain pad and Raven Creek's route there changed.
  mountain_plan/world map not needed (no route re-planned). PASS.
- Trap: right after the data commit, three runs under flock printed only
  the Godot banner and hung to their timeouts; the same tests run without
  flock a few minutes later passed (cause not found; no godot was left
  running). If a run hangs at the banner, check `pgrep -af godot`.
Next steps, in order (new container: `game/tools/setup_cloud.sh` first;
`pip install shapely numpy contourpy scipy` only for a country rebuild):
1. Full suite: `cd game && tests/run.sh > /tmp/tests.log 2>&1; echo $?`
   then grep (CLAUDE.md Token cost). Expect 0 failed.
2. One Opus review of the whole task (phases 1-2 + this session; diff
   4197417..HEAD; quote Sachin's order; give the gate outputs). Fix, rerun
   the suite. Two review runs at most.
3. Phase 3 builders (stopped at the pause, early): briefs in
   wip/briefs/ (package_R/G/P.md + brief_common.md; fix its /tmp paths).
   WIP files from the stopped builders, untested: wip/R/ (races.gd 1016
   lines, race_course.gd, race_calib probe) and wip/G/ground.gd (232
   lines). Copy them into a fresh worktree as a head start or discard.
   P had written nothing. Plan: "Phase 3 and 4 plan" below; each package
   gets its own Opus review; the main session wires main.gd, hud.gd,
   player.gd and mission_manager save, then merges. Delete wip/ when done.
4. Phase 4 (wave B after G): bridges and tunnels on G's deck layer.
Open items not in Sachin's list (report only): no trail person passed
trail loop 904 in 20 s at noon (shot scripts a party); 26/128 of its
points lie within 6 m of a road; calendar Lows (archive); the wildlife
reviewer could not measure in_city cost on a device.

