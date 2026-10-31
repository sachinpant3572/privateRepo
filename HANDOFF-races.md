# Package R: races and cycling (decisions note)

Phase 3 of HANDOFF-hill-content.md. Files: game/scripts/races.gd (the module),
game/scripts/race_course.gd (course builder), game/tests/race_tests.gd (15 tests),
game/tests/race_shots.gd/.tscn (8 screenshots), game/tests/race_calib.gd/.tscn
(manual pace probe, not in the suite), one TEST_MODULES line in tests/test_runner.gd.
Resumed from a cut-off builder's snapshot (wip/snapshots/R.patch).

## Status

Built and tested; what is missing is the main-session wiring below. Test pass
lines are in the report. Screenshots were taken with the wiring applied
temporarily (never committed). Not touched: main.gd, hud.gd, player.gd,
vehicle.gd, humanoid.gd, mission_manager.gd.

## Main-session patch (needed to switch the feature on)

The four shared files are NOT edited here. Apply HANDOFF-races-wiring.patch at the
repo root with `git apply HANDOFF-races-wiring.patch` (the exact diff is also
pasted at the foot of this note). Without it nothing creates the module: the tests
build their own `Races` node, and `test_races_wired_into_the_game` passes by
skipping its HUD / E press / save / map checks until `game.races` exists (with
the patch applied it runs them).

- main.gd: `Races` preload, `var races`, create after hunting, `map_markers()`
  appends `races.map_markers()`.
- hud.gd: `_race` label (race panel), set from `hud_text()`; the prompt in the
  car and on foot from `prompt()`.
- player.gd: E in a car (`_races_take_press()`, before the roof exit) and on foot.
- mission_manager.gd: `"races": to_save()` in the save, `load_save` in load_game
  and reset_progress.

## Decisions

- API (races.gd): `prompt()`, `try_interact()`, `hud_text()`, `map_markers()`,
  `to_save()/load_save()`; also `start_race(mode)` (day/night), `start_trial()`,
  `rent_bike()`, `cancel()`, `standings()`, `place()`, `medal_for()`,
  `hill_course()`, `trail_course()`. States: IDLE, COUNTDOWN, RACING, DONE.
- Courses are built at run time from `country.roads` (East Hills Road, Whistler
  Track, Copperback Cut/Track; Calder Trail for the bike). Gates ~150 m apart.
  Gate 0, the lap lines and the finish share the ring junction, which is ~134 m
  from the start. Teleporting ahead counts only the next gate in order.
- Grid: the player takes the BACK row, rivals in front or beside. The script AI
  does not brake for the player's car, so a rival behind rams him and pins
  himself on the parked car (slots `[[0,1],[0,-1],[1,1]]`, player `_slot(1,-1)`).
- Finish: `_pass_through_player()` adds collision exceptions between the player's
  car and the rivals; the field reaches a parked finisher ~5 s after he stops and
  used to wreck him.
- Rival pace: `script_throttle = vlim[k] * skill * band / max_speed`, BAND 0.04
  rubber band, A_LAT 5 / BRAKE 5.5 profile in race_course.gd. Measured with
  race_calib: day field 236-247 s over 3788 m (15.3-16.0 m/s, no rescues) at skills
  0.86/0.90/0.95; night field 203-211 s (no rescues) at 0.98/1.02/1.06. The test
  needs night slowest skill > day fastest skill (it was a 0.95 tie) and the day
  field inside 14..30 m/s.
- Rival health x3 (`RIVAL_HEALTH`): the sports car and roadster were scraped to a
  wreck at the hairpins (path idx ~212 and ~245-250), and the swap-in restarted
  them at their last rescue point, so each lost 120-150 s and the night field
  came out slower than the day field. Now `_replace_rival` restarts the fresh car
  on the wreck's stretch (`recover_rival(r, from)`). Lowering A_LAT/BRAKE was not
  taken: it slows the day field and does not clear the hairpins.
- Night run: open 21:00-04:00, stake 100-500 (default a quarter of the cash),
  taken at the start; the winner collects stake x 4, anything else loses it. A
  patrol car or officer with a clear ray within 35 m (police_manager SIGHT_RANGE)
  gives one star (`Wanted.report_crime(1)`). Cancelling or leaving the car ends it.
- Day race prize 400/200/80 by place. Bike: 10 to hire at the stand
  (990,-1502), timed run down Calder Trail (855 m); medals by average speed
  4.6/5.6/6.6 m/s; a medal pays its tier once (60/150/300, the difference when
  improving); 8 s out of the saddle abandons. `_update_rivals` returns early with
  no field (the trial has no speed profile).

## Traps

- `GROUPS` is a bash variable: `GROUPS=night cmd` is silently ignored. The probe
  reads `RUNS=` (and `DIAG=1`, `TRACE=from,to`). Every godot run goes under `flock`.
- A test that parks the player's car must put it back on the lead-in (`_to_start`)
  before the next `_start_day`, or the start prompt will not show.
- The runner does not fail on SCRIPT ERROR: grep for it.
- The HUD prompt in the screenshots only shows with the wiring patch applied.

## Appendix: the wiring patch, verbatim

```diff
diff --git a/game/scripts/hud.gd b/game/scripts/hud.gd
index e96f4e9..952a89a 100644
--- a/game/scripts/hud.gd
+++ b/game/scripts/hud.gd
@@ -30,6 +30,7 @@ var _stars: Control
 var _perf: Label
 var bug_button: Button
 var _prompt: Label
+var _race: Label
 var _message: Label
 var _message_tween: Tween
 var _district: Label
@@ -170,6 +171,10 @@ func _ready() -> void:
 	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 	_message.modulate.a = 0.0
 
+	_race = _label(root, 26)
+	_anchor(_race, Vector2(0.5, 0), Rect2(-330, 132, 660, 80))
+	_race.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
+
 	_district = _label(root, 30)
 	_anchor(_district, Vector2(0.5, 0), Rect2(-300, 84, 600, 44))
 	_district.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
@@ -227,6 +232,7 @@ func _process(delta: float) -> void:
 	_shown_cash = move_toward(_shown_cash, game.cash, maxf(absf(game.cash - _shown_cash) * 3.0, 50.0) * delta)
 	_cash.text = "$%d" % int(_shown_cash)
 	_clock.text = game.atmosphere.clock_text()
+	_race.text = game.races.hud_text() if game.races != null else ""
 	_phone_button.visible = game.missions != null and game.missions.phone_unlocked
 	# The gear takes PHONE's slot until the story unlocks the phone.
 	settings_button.offset_left = -196.0 if _phone_button.visible else -76.0
@@ -267,6 +273,10 @@ func _process(delta: float) -> void:
 		touch.set_label("brake", "BRAKE")
 		touch.set_label("interact", "EXIT")
 		touch.set_label("sprint", "DRIFT")
+		var race_prompt: Array = game.races.prompt() if game.races != null else []
+		if not race_prompt.is_empty():
+			_prompt.text = race_prompt[0]
+			touch.set_label("interact", race_prompt[1])
 	elif context_prompt.size() == 2:
 		_prompt.text = context_prompt[0]
 		touch.set_label("interact", context_prompt[1])
@@ -281,6 +291,11 @@ func _process(delta: float) -> void:
 		_prompt.text = hunt_prompt[0]
 		touch.set_label("interact", hunt_prompt[1])
 		touch.set_label("sprint", "RUN")
+	elif game.races != null and not game.races.prompt().is_empty():
+		var race_prompt: Array = game.races.prompt()
+		_prompt.text = race_prompt[0]
+		touch.set_label("interact", race_prompt[1])
+		touch.set_label("sprint", "RUN")
 	elif game.interiors != null and not game.interiors.prompt().is_empty():
 		var place_prompt: Array = game.interiors.prompt()
 		_prompt.text = place_prompt[0]
diff --git a/game/scripts/main.gd b/game/scripts/main.gd
index 11a5eaa..e6b006f 100644
--- a/game/scripts/main.gd
+++ b/game/scripts/main.gd
@@ -15,6 +15,7 @@ const Atmosphere = preload("res://scripts/atmosphere.gd")
 const MissionManager = preload("res://scripts/missions/mission_manager.gd")
 const Interiors = preload("res://scripts/interiors.gd")
 const Hunting = preload("res://scripts/hunting.gd")
+const Races = preload("res://scripts/races.gd")
 const Inventory = preload("res://scripts/inventory.gd")
 const Taxi = preload("res://scripts/taxi.gd")
 const Graphics = preload("res://scripts/graphics.gd")
@@ -40,6 +41,7 @@ var graphics
 var missions
 var interiors
 var hunting
+var races
 var taxi
 var heliports
 var calendar
@@ -90,6 +92,9 @@ func _ready() -> void:
 	atmosphere.calendar = calendar
 	hunting = Hunting.new()
 	add_child(hunting)
+	races = Races.new()
+	races.game = self
+	add_child(races)
 
 	missions = MissionManager.new()
 	missions.game = self
@@ -267,6 +272,8 @@ func map_markers() -> Array:
 		list.append_array(missions.markers)
 	if taxi:
 		list.append_array(taxi.map_markers())
+	if races:
+		list.append_array(races.map_markers())
 	if heliports:
 		for port in heliports.ports:
 			list.append({"pos": port.pos, "color": Color(0.35, 0.8, 1.0), "label": port.name, "gps": false, "icon": "H"})
diff --git a/game/scripts/missions/mission_manager.gd b/game/scripts/missions/mission_manager.gd
index e640935..c06e344 100644
--- a/game/scripts/missions/mission_manager.gd
+++ b/game/scripts/missions/mission_manager.gd
@@ -312,7 +312,7 @@ func save_game() -> void:
 	if not save_enabled:
 		return
 	var data := {"version": SAVE_VERSION, "done": done, "cash": game.cash, "phone": phone_unlocked,
-		"settings": game.settings, "inventory": game.inventory.to_save(), "hunting": game.hunting.to_save(), "calendar": game.calendar.to_save()}
+		"settings": game.settings, "inventory": game.inventory.to_save(), "hunting": game.hunting.to_save(), "races": game.races.to_save(), "calendar": game.calendar.to_save()}
 	var f := FileAccess.open(save_path, FileAccess.WRITE)
 	if f:
 		f.store_string(JSON.stringify(data))
@@ -334,6 +334,8 @@ func load_game() -> void:
 	game.inventory.load_save(inv if typeof(inv) == TYPE_DICTIONARY else {})
 	var hunt = data.get("hunting")
 	game.hunting.load_save(hunt if typeof(hunt) == TYPE_DICTIONARY else {})
+	var rc = data.get("races")
+	game.races.load_save(rc if typeof(rc) == TYPE_DICTIONARY else {})
 	var cal = data.get("calendar")
 	game.calendar.load_save(cal if typeof(cal) == TYPE_DICTIONARY else {})
 	GameLog.event("load", {"version": int(data.get("version", 1)), "done": done.size(), "cash": game.cash})
@@ -347,6 +349,7 @@ func reset_progress() -> void:
 	game.cash = 0
 	game.inventory.bag.clear()
 	game.hunting.load_save({})
+	game.races.load_save({})
 	game.calendar.load_save({})
 	save_game()
 	changed.emit()
diff --git a/game/scripts/player.gd b/game/scripts/player.gd
index ebd43a5..514dc20 100644
--- a/game/scripts/player.gd
+++ b/game/scripts/player.gd
@@ -58,6 +58,8 @@ func _physics_process(delta: float) -> void:
 			var game = get_tree().get_first_node_in_group("game") if passenger else null
 			if game != null and game.taxi != null:
 				game.taxi.request_exit() # the cab pulls up and you pay
+			elif _races_take_press():
+				pass # the race start line or the Calder trial
 			elif vehicle.has_method("exit_check") and vehicle.exit_check() == "roof":
 				# Nobody stands on a roof here: land on open ground first.
 				var g = get_tree().get_first_node_in_group("game")
@@ -113,10 +115,18 @@ func _think(delta: float) -> void:
 			pass
 		elif game != null and game.hunting != null and game.hunting.try_interact():
 			pass
+		elif _races_take_press():
+			pass # the bike hire stand
 		elif game == null or game.interiors == null or not game.interiors.try_interact():
 			try_enter_vehicle()
 
 
+## E at a race start line, or at the bike hire stand (races.gd).
+func _races_take_press() -> bool:
+	var g = get_tree().get_first_node_in_group("game")
+	return g != null and g.races != null and g.races.try_interact()
+
+
 ## The node the camera and police should track.
 func focus_node() -> Node3D:
 	return vehicle if vehicle != null else self
```
