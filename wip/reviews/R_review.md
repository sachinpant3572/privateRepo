# Package R (races) Opus review, session 5 (on R df9c56b), read-only, Godot not run
Sent back to builder R; fix status is in R's HANDOFF-races.md (in wip/snapshots/R.patch).

High
- H1 Player can end up in a rival car the AI drives: during the countdown E exits
  the player's car, the grid rival beside it (driver NONE) can be entered with no
  crime; at GO `_go` (races.gd ~432) calls drive_path on it (driver SCRIPT, player
  loses control). Same mid-race after carjacking a rival; recover_rival (~647-658)
  keeps teleporting it and it stays scored. Fix: skip/drop any rival whose car ==
  game.player.vehicle or driver == PLAYER, in _go and _update_rivals.
Medium
- M2 try_interact (~287-297) returns true even when start_race refuses (wanted > 0,
  night < $100): no car exit within 22 m of the arch, incl. in a police chase; on a
  bike within 30 m of the trail top E starts the trial instead of dismounting (rented
  bike spawns inside that range). race_tests.gd ~413 asserts the old behaviour.
  Fix: return start_race's result; offer the prompt only when nearly stopped.
- M3 No missions.active check (~304): race mid-mission teleports the car and
  _finish saves mid-mission. Refuse "Finish the job first" (interiors.gd:103, taxi.gd:393).
- M4 Police sight (~758-767) counts empty/parked police cars, ignores the cop's
  active flag (wider than police_manager._anyone_sees); the star test relies on it.
- M5 Finished rivals stop on the finish gate (race_course.gd ~317-330); the player
  finishing 2nd-4th hits them. Run-off past the line or join_traffic_here() on finish.
- M6 No shot with the HUD patch applied: race panel and in-car prompt never seen.
  Main session: shots after the wiring patch lands.
Low
- hud_text() allocs place()+standings() each frame: cache on a 0.25 s tick.
- _beam makes a Shader per beam (8): share one.
- Night buy-in not saved when taken (app kill refunds the stake).
- set_wager has no caller: no way to choose $100-500 (brief asks).
- races.gd ~890 dead branch; wreck swap queue_frees a burning wreck in view (~676).
- TEST_MODULES is one line: merge by hand with G/P appends.
Verified OK: night window wrap, ordered checkpoints, lap count, prizes once, medal
cash on improvement only, old saves without "races", reset, death cancels and frees
rivals, rivals not in population.cars, main.gd order (after city.build, before missions),
E order on foot (cab, hunting, races, interiors); git apply --check of the patch on 98a02e1.
