# Package R: races and cycling (decisions note)

Phase 3 of HANDOFF-hill-content.md. Files in game/: scripts/races.gd (module),
scripts/race_course.gd (courses), tests/race_tests.gd (20 tests), tests/race_shots.*
(8 shots), tests/race_calib.* (manual pace probe, not run by the suite), a
TEST_MODULES line in test_runner.gd.

## Status

Built, tested, and fixed after the independent review (acb9be2..c7d721e). Not
touched: main.gd, hud.gd, player.gd, vehicle.gd, humanoid.gd, mission_manager.gd.

## Wiring (needed to switch the feature on)

The four shared files are NOT edited here. `git apply HANDOFF-races-wiring.patch`
at the repo root adds the `Races` node and map markers (main.gd), the race label
and prompts (hud.gd, one `prompt()` call per frame), E in a car and on foot
(player.gd) and save/load/reset of `races` (mission_manager.gd). The diff lives
only in that file.

`test_races_wired_into_the_game` FAILS until the patch is applied: its first
check is `game.get("races") != null` (no skipping). That is intended. With the
patch applied all 20 race tests pass.

## Decisions

- API (races.gd): `prompt()`, `try_interact()`, `hud_text()`, `map_markers()`,
  `to_save()/load_save()`; also `start_race(mode)` (day/night), `start_trial()`,
  `rent_bike()`, `cancel()`, `standings()`, `place()`, `medal_for()`,
  `hill_course()`, `trail_course()`. States: IDLE, COUNTDOWN, RACING, DONE.
- Courses are built at run time from `country.roads` (East Hills Road, Whistler
  Track, Copperback Cut/Track; Calder Trail for the bike). Gates ~150 m apart.
  Teleporting ahead counts only the next gate in order.
- Grid: the player takes the BACK row; the script AI does not brake for the
  player's car. Finish: `_pass_through_player()` adds collision exceptions.
- Rival pace: `script_throttle = vlim[k] * skill * band / max_speed`, BAND 0.04.
  Measured with race_calib: day field 236-247 s over 3788 m (skills 0.86/0.90/0.95),
  night 203-211 s (0.98/1.02/1.06). Rival health x3 (`RIVAL_HEALTH`): the light cars
  were scraped to wrecks at the hairpins; `_replace_rival` restarts the fresh car
  on the wreck's stretch (`recover_rival(r, from)`).
- Night run: 21:00-04:00, stake 100-500, winner takes stake x 4. Police see the
  race by police_manager.gd's rule (`driver == POLICE` or `_deployed`, active
  non-dead cops, SIGHT_RANGE): an empty parked patrol car sees nothing.
- Day prize 400/200/80. Bike: $10 at the stand (990,-1502), Calder Trail (855 m),
  medals by average speed 4.6/5.6/6.6 m/s paying once per tier (60/150/300).

## Review fixes (this round)

- A rival the player jacks is out of the field (`_drop_jacked_rivals` in `_go`,
  `_update_rivals`; guards in `recover_rival`/`_replace_rival`): never driven,
  recovered, replaced or freed.
- E: `try_interact()` is true only when a race/trial/hire really started, else E
  falls through to getting out. The start is offered only at <= START_SPEED
  (3 m/s), never during a mission (`game.missions.active`) or a taxi trip
  (`game.taxi.state != IDLE`). Refusal texts carry the button E really is (EXIT
  / ENTER). TRIAL_RANGE is 10 m and a hired bike appears RENT_ARC (16 m) down
  the trail facing the top, so getting off it does not start the trial; a hired
  bike left > 60 m from the stand and > 40 m from the player is freed.
- Jacked rivals (second review): the night pot is paid on the field at the start
  (`_field`); dropped cars are kept in `_dropped` and freed by `_clear_rivals`
  unless the player is in one; `recover_rival`/`_replace_rival` return a flag and
  never edit `rivals` (`_update_rivals` drops after its loop).
- `_player_ok` rechecks the ride (NO_RACE, bicycle only in the trial, not a cab
  passenger) and gates count only in a ride. HUD place is cached (0.25 s); the
  beam shader is one static Shader; the dead `5.4 if i >= 0` is gone.

## Traps

- `GROUPS` is a bash variable: the probe reads `RUNS=` (also `DIAG=1`,
  `TRACE=from,to`). Every godot run goes under `flock`.
- A test that parks the player's car must put it back on the lead-in (`_to_start`)
  before the next `_start_day`. The runner does not fail on SCRIPT ERROR: grep it.
- The HUD centre message is one 84 px line: ~28 characters at 1280 px; keep
  `_say` text short. A gate is passed within 15 m (bike 11 m), so a parked camera
  shot of a gate must stand off the line (see race_shots.gd).
- Shots: apply the patch temporarily to see the HUD prompt; never commit it.
