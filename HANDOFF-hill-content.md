# Hill country content, then tunnels and bridges (started 2026-10-31)

Sachin, 2026-10-31: "Build the content, and then the tunnels and bridges"
(after the land step; content = TODO.md hill country steps 2-4; tunnels and
bridges = #110). Design: `docs/hill_country_design_map.png`,
tools/hill_design_map.py (places, zones, lines). Land notes:
HANDOFF-hill-country.md. Rough cost from TODO: steps 2-4 ~140-260 h, #110
on top; built in phases, each committed; `/effort xhigh` suits it.

## Phases

1. **Places** (#122): done; plan text in the archive.
2. **Life** (#123): wildlife (deer, coyote, mountain lion, rabbit: built
   meshes, leg animation, wander/flee/attack), hunting (rifle sold with a
   licence at the hunting store, seasons, pelts), flora bands by height,
   hikers/runners/hunters on trails, a weekday calendar with small-town
   events (fair, rodeo, market, festival, speed trap) and night raves.
3. **Activities** (#124): checkpoint races and illegal night races on the
   hill loop, stunt jumps (ramp surface + airtime), cycling, parachuting,
   bungee.
4. **Tunnels and bridges** (#125, #110): a deck layer (polylines with width
   and z profile) that vehicles and people stand on when near its level;
   bridge meshes; tunnel portals, tubes, terrain cut at portals, the
   see-through view inside; then the 26 `structures`, stream crossings,
   the sky bridge, rail bridges.

## Decisions

- Hunting goes ahead (Sachin 2026-10-30 asked for licence, seasons, store,
  pelts); the older ACTIVITY_ROADMAP line "Hunting: never" is superseded.
  No weapons exist: a hunting rifle that fires only at animals, only in the
  hunting ground, keeps it from becoming a general weapons system.
- Cult: fictional beliefs, no real religious symbols or text (world bible).
- Parachuting: the summit helipad is #113 (not asked), so jumps start from
  a helicopter (#115) or a cliff BASE exit.
- Stunt ramps need a surface above the ground grid: built as the first use
  of the phase-4 deck layer, or as a ramp pad in the grid if that is enough.
- Hill places run after every other lot step and the trailer clusters draw
  from their own rng (HILL_SEED), so no existing lot moves.
- Lakes fill real closed basins of the raw grid below a set level
  (HILL_LAKES), so shores are natural; the bed is dug up to LAKE_DEPTH
  (mountain.grid, `lakes`), the water mesh runs LAKE_EDGE past the shore
  under the rising ground, at level - 0.3; invisible kind-3 walls on the
  shore keep movers out (no swimming yet).
- Streams: steepest descent on the smoothed grid from HILL_STREAMS springs,
  stopping at a lake, the sea or height 3; cut at roads (culverts implied
  until phase 4 adds crossings); ribbons in the tile's `water` mesh.
- Lab road (lane, 14 % at the cap) and Timber Haul (track, 25 %) are
  mountain_plan SPECS. The design's logging camp on the ridge west of the
  Morrow (-332, -4300) is off the play land (A), and a crossing there lands
  on a 13 m bank the game's low deck can't climb, so the camp and the haul
  moved into the forest east of Route 9 (250, -4110); no bridge.
- Village walks: a loop down both shoulders of each village road (no
  sidewalks on hill roads). Village diners/stores open as places in their
  own cap (places.gd HILL_MAX) after the suburbs', so suburb picks hold.

## Facts

- No ground collider: vehicles and people set y = Terrain.height
  (vehicle.gd:1368, humanoid.gd:170); colliders are boxes only.
- One water plane at y -0.55; lakes at a level need their own mesh.
- No peds in the hills: population spawns on `walks`, made only in
  WALK_ZONES (build_country.py:275).
- places.gd opens diners/stores only in SUBURB_ZONES (52-54).
- Rebuild: plan_dump, then build_country, then mountain_plan / world map
  (HANDOFF-hill-country.md). RNG use changes shift lots everywhere.

## Traps

- `_wet_only` keeps a planned bridge only over water; when the planner's
  span ends high on a bank, the road climbs it at 90 %+ (check the build
  log's "steepest" lines after adding a bridged way).

## Open
- Timber Haul hairpin_r 14 (8 put the hairpin's legs 16 m apart; one leg's
  carve broke the other's profile: 54.7 % at (304, -4192)).
- Lab gate stands beside Kestrel Hollow Road, not astride it (review M1):
  lay it across the road (yaw along it, excused from the lot-on-road
  check) in the phase-4 rebuild. Its arm is drawn raised until then.
- Bungee platform sits on a level pad: phase 3 needs a cliff-edge site.

## Status
Phases 1-2 history (status, the 10-31 handover list): archive.

## Handover (paused 2026-10-31, session 2) - start here
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
Last full suite (before the two fixes below): 2132 passed, 2 failed:
- test_wildlife_stays_out_of_lakes: flaky (2/3 alone). Cause: player
  18 m from the herd, flee radius standing 25 x 0.7 = 17.5 m. Fixed (player
  12 m off); the fix is committed but not yet re-run.
- test_country_plots_square_to_their_roads: kestrel_lab 80.2 deg off
  Kestrel Hollow Road; fails on 4197417 too (previous session). Fix:
  build_country.py `_site_skew` rejects a site spot whose front is within
  10 m of a road and more than 3.5 deg off it (committed). The country
  data is NOT rebuilt yet (see step 1).
Next steps, in order:
1. Rebuild the country (README "The country is generated"): plan_dump,
   then `python3 tools/build_country.py /tmp/plan.json` (pip install
   shapely numpy contourpy scipy). Check the log for "kestrel" / "no site"
   / WARNING; diff data/country.json lots against git: only kestrel_lab
   (and anything it displaced) may move. Then check whether mountain_plan /
   world map need a rerun (HANDOFF-hill-country.md). Commit the data.
2. ONLY=test_country_plots_square_to_their_roads,test_wildlife_stays_out_of_lakes
   (lake test 3 times), then the full suite (`game/tests/run.sh`).
3. One Opus review of the whole task (phases 1-2 + this session; diff
   4197417..HEAD; quote Sachin's order; give the gate outputs). Fix, rerun
   the suite. Two review runs at most.
4. Phase 3 builders (stopped at the pause, early): briefs in
   wip/briefs/ (package_R/G/P.md + brief_common.md; fix its /tmp paths).
   WIP files from the stopped builders, untested: wip/R/ (races.gd 1016
   lines, race_course.gd, race_calib probe) and wip/G/ground.gd (232
   lines). Copy them into a fresh worktree as a head start or discard.
   P had written nothing. Plan: "Phase 3 and 4 plan" below; each package
   gets its own Opus review; the main session wires main.gd, hud.gd,
   player.gd and mission_manager save, then merges. Delete wip/ when done.
5. Phase 4 (wave B after G): bridges and tunnels on G's deck layer.
Open items not in Sachin's list (report only): no trail person passed
trail loop 904 in 20 s at noon (shot scripts a party); 26/128 of its
points lie within 6 m of a road; calendar Lows (archive); the wildlife
reviewer could not measure in_city cost on a device.

## Phase 3 and 4 plan (decided 2026-10-31)
- vehicle.gd has no air state (y = Terrain.height each frame), so stunt
  jumps and the deck layer share one change: a ground layer (decks: ramps,
  bridges, tunnel floors) and a ballistic air state. One Opus package owns
  vehicle.gd/humanoid.gd ground code: G = deck layer + airtime + stunt
  ramps. Wave A in parallel worktrees: R (races, illegal night races,
  downhill bike time trial; Sonnet xhigh), G (Opus xhigh), P (parachute
  and bungee; Opus xhigh, physics). Wave B after G: bridges and tunnels
  (Opus). Main session wires each into main.gd/hud.gd and merges.
  Cheaper option named for Sachin: all in the main session, sequential.

Phase 2 package plan: HANDOFF-hill-content-archive.md.
