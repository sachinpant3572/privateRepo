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
- Bungee: no sheer 60 m cliff within 600 m of the Calder lot, so P built
  a 38 m arm over a 60 m drop (cheaper: ARM_MAX 20, 35-40 m drop).

## Handover (session 3, 2026-10-31) - start here
Kept current at each milestone (Sachin 10-31: a handoff with proper
details for when the 5-hour limit is reached; a limit stop gives no
warning, so this section is the handoff). Branch
`claude/gangstar-game-content-tunnels-kszhz9`, pushed. Session 2 notes:
archive.

Done this session:
1. Full suite on fe9f7ec: exit 0, 2134 passed, 0 failed.
2. Whole-task Opus review (4197417..fe9f7ec close, 75eda1f^.. for
   integration): 0 High, 1 Medium, 4 Low, all fixed (b6efeeb) with tests:
   M1 pelts only from the player's rifle kills (kill() keeps `by` on the
   carcass; carcass_near(pos, r, "rifle")), L1 no lion skinning, an old
   save's lion pelt dropped, L2 a mission's start hour goes through
   Atmosphere.advance (a start < 1 h behind steps back, same day), L3 a
   spent lion that ends idle walks off ("leave"), L4 pelt total capped on
   load. 9 focused tests PASS (77 checks); full suite after the fixes:
   exit 0, 2145 passed, 0 failed. No second review needed (no High).

Session 4 (10-31, other account): new container; wave A relaunched from
wip/snapshots (isolation worktrees on acb9be2; R moves its main/hud/
player/mission_manager edits into its note as patches).

In progress: phase 3 wave A, three builders in local worktrees (branches
not pushed; base fe9f7ec). Their briefs: wip/briefs/ (paths made
worktree-relative in c53c27b).
| pkg | builder | worktree (.claude/worktrees/) | files so far |
| G ground/air/stunts | Opus xhigh | agent-a51e54d60601755b1 | ground.gd, ramp_kit.gd, vehicle.gd, humanoid.gd |
| P parachute/bungee | Opus xhigh | agent-a33a1bd59f718629f | parachute.gd, bungee.gd, kits/air_sports_kit.gd, player.gd |
| R races/cycling | Sonnet xhigh | agent-a9c0ec2e48144bf73 | races.gd, race_course.gd (moved from wip/R), race_shots, race_calib |
- R had edited main.gd, hud.gd, player.gd, mission_manager.gd against its
  brief; told to revert them and report patches instead.
- `wip/snapshot.sh` saves each worktree's work (commits, uncommitted,
  untracked) to wip/snapshots/<pkg>.patch; run and commit at milestones.

Resume (if this session stopped): worktrees present -> run
wip/snapshot.sh, commit; then (or if gone) per package a builder with
isolation worktree: `git apply --3way wip/snapshots/<X>.patch`, then
wip/briefs/brief_common.md + package_<X>.md, continuing from the files.
Then, per package as it reports: its own Opus review (diff + gate output
+ the brief quoted), fixes, then the main session applies the builder's
main.gd/hud.gd/player.gd/mission_manager patches, merges the branch,
runs that package's tests. After all three: full suite, screenshots
(contact sheet), delete wip/, commit, push. Then phase 4 (wave B: bridges
and tunnels on G's Ground deck/cut API; one Opus builder + review).
Next for Sachin: report at the end; nothing needs his approval so far.

Open items not in Sachin's list (report only): trail loop 904 (nobody
passed in 20 s at noon; 26/128 points within 6 m of a road); calendar
Lows (archive); in_city cost unmeasured on a device; session 2's runs
hung at the Godot banner once (check `pgrep -af godot`).

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
- Session 3 launch cost: R Sonnet xhigh, G and P Opus xhigh, each about
  1.5-3 h plus a 20-40 min Opus review; started while the step-1 suite ran
  (own worktrees, shared /tmp/godot.lock).

Archive (HANDOFF-hill-content-archive.md): phase 1-2 history, phase 2
package plan, session 2 handover.
