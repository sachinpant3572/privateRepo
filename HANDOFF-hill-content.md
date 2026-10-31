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
- Bungee: no sheer cliff at the pad, so P builds a 36 m jump arm (60 m drop).

## Handover (paused 2026-10-31, session 5, at Sachin's request) - start here
Branch `ccr-ac909a1c-kp0vp0`, draft PR #3 (stacked on #2's branch), pushed.
Session 4's builders died with its container; session 5 relaunched them.
All three builders stopped at a clean point and committed; their work is
in wip/snapshots/<G|P|R>.patch (base 236c09c; all three pass
`git apply --check` on e0a7614). Worktrees and their branches are local
only and die with the container: the patches are the record.

| pkg | state at pause | its note (in its patch) |
| G ground/air/stunts (Opus) | built; 8 tests 71/0 on final code; 51 neighbour tests (vehicle/walk/traffic/taxi/heli) last 505/0 BEFORE ramps moved (stale); stunt shots not taken; not reviewed | HANDOFF-ground.md |
| P parachute/bungee (Opus) | done 74be212; 7 tests 67/0; +neighbours 163/0 with patch; 13 shots OK; Opus review stopped at pause (not done) | HANDOFF-air-sports.md |
| R races/bike (Sonnet) | done df9c56b, reviewed (wip/reviews/R_review.md: 1 H, 5 M, Lows); fixes for all written at 7cdfb19 but UNRUN; tests half-updated; tests last 152/0 (stale) | HANDOFF-races.md (STATUS) |

G detail: ramps bend, rise, crest_south all on the east shoulder (Crest
North dropped; west shoulder has poles every 15.6 m at x 2634 and a
tilted bank); Rise Hop heads south from (2646.5, -2992). Screenshots need
a wrapper script that takes /tmp/godot.lock itself (the harness refused
inline flock + xvfb-run). Expect 6 `saved` lines from stunt_shots.tscn.
R detail: H1 rival car taken by player dropped; M2 refused press falls
through, start only < 3 m/s, TRIAL_RANGE 14; M3 "Finish the job first";
M4 uses police _anyone_sees; M5 260 m run-off; buy-in pick (first E opens
4 s pick, E steps 100/200/300/500). Left: TESTS list, star test (real
cop), new tests per fix, race_shots night press, re-check its patch.
P open: ground_under() -> Ground.height once G is in; lot still named
"129 m drop" (jump is 60 m); BASE hands-off flight ~135 s, ~1 km.

Resume steps (in order):
1. `game/tools/setup_cloud.sh` (background). Per package, a builder in an
   isolation worktree: `git apply --3way wip/snapshots/<X>.patch`, read
   wip/briefs/brief_common.md + package_<X>.md and its own HANDOFF note,
   finish its listed next steps (G: neighbour tests, shots; R: tests and
   shots for the fixes, re-check patch; P: nothing to build). Builders
   commit in their worktree at milestones; main runs wip/snapshot.sh
   (update its agent-id map and base) and commits after each report.
2. Reviews: P's Opus review (rerun, brief as for R); G's Opus review once
   G reports; R needs no second review unless its fixes hit trouble.
3. Main session wires each: patches for main.gd/hud.gd/player.gd/
   mission_manager.gd (G and R: in their HANDOFF notes / HANDOFF-races.patch;
   P: wip/P/main_hud.patch). Clashes: all three append TEST_MODULES in
   test_runner.gd (merge by hand); P edits player.gd bail code and G's
   patch switches three exit/bail lines in player.gd to Ground.height;
   R's and P's hud.gd branches both go near the hunting/interiors prompt.
   Then switch P's ground_under() to Ground.height. Run each package's
   tests after wiring.
4. After all three: full `game/tests/run.sh`, screenshots with the HUD
   wired (race panel and in-car prompt were never seen: R review M6),
   contact sheet, one Opus review of the integration, delete wip/, push.
5. Phase 4 (plan below): bridges/tunnels on G's Ground API, Opus + review.
Nothing needs Sachin's approval so far.

Report-only items: trail loop 904 (nobody passed in 20 s at noon); calendar
Lows (archive); in_city cost unmeasured on a device; godot once hung at
its banner (check `pgrep -af godot`).

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
- Cost: R Sonnet xhigh ~0.5-1 h used, G/P Opus xhigh ~45-50 min each in
  session 5, plus a 5-40 min Opus review each; shared /tmp/godot.lock.

Archive: phase 1-2 history, phase 2 package plan, sessions 2-3.
