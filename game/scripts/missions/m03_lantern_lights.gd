extends "res://scripts/missions/mission.gd"
## Mission 3, Lantern Lights: Celeste sends Jules to the precinct for her
## bandleader, Marcel, arrested on a made-up charge; Captain Reyes lets him
## go. On the way back Aurum security ambushes the car and wrecks it: steal
## another, lose the police, and get Marcel home to the Blue Lantern.

const Cast = preload("res://scripts/missions/cast.gd")

const BOARD_RANGE := 12.0

var marcel


func _init() -> void:
	reward = 800
	unlocks = "Celeste's number"


func start_point() -> Vector3:
	return front("blue_lantern")


func start_hour() -> float:
	return 20.5


func run() -> void:
	var club := front("blue_lantern")
	if not await card("LANTERN LIGHTS", "Act 1  ·  Mission 3"):
		return
	var celeste = npc("Celeste", Cast.CELESTE, club + Vector3(1.8, 0, -0.5))
	celeste.gesture = "talk"
	if not await reach(club + Vector3(0.2, 0, 0), "Meet Celeste at the Blue Lantern", 3.0, true, "Celeste"):
		return
	if not await say([
		["Celeste", "Jules Moreau. Your mother's eyes and your father's timing."],
		["Celeste", "My bandleader, Marcel, got picked up tonight. A made-up charge."],
		["Celeste", "The precinct will release him to family. Tonight, you're family."],
	], true):
		return
	celeste.gesture = ""

	# The precinct.
	var station := front("bpd_lantern")
	var reyes = npc("Reyes", Cast.REYES, station + Vector3(-1.6, 0, -0.4))
	marcel = npc("Marcel", Cast.MARCEL, station + Vector3(1.6, 0, -0.4))
	marcel.max_health = 160.0
	marcel.health = 160.0
	fail_if(func(): return marcel.dead, "Marcel didn't make it.")
	if not await reach(station, "Pick up Marcel at the Lantern Quarter Precinct", 3.0, true, "Precinct"):
		return
	if not await say([
		["Reyes", "Captain Dana Reyes. You must be the Moreau kid."],
		["Reyes", "Your friend's free to go. Stay out of trouble. This city has a long memory."],
		["Marcel", "Bless you. Let's go before she changes her mind."],
	], true):
		return
	reyes.walk_to(station + Vector3(-1.6, 0, -6.0))
	marcel.mode = Npc.Mode.FOLLOW
	marcel.show_marker(BLUE)

	# Into a car, then towards the club until Aurum shows up.
	if not await _board("Get in a car with Marcel"):
		return
	var club_mark := mark(curb("blue_lantern"), "The Blue Lantern")
	objective("Drive Marcel to the Blue Lantern")
	await until(func(): return player_pos().distance_to(station) > 45.0 or player_pos().distance_to(club) < 30.0)
	if ended:
		return
	await _ambush()
	if ended:
		return

	# A new car, then lose the police.
	if not await _board("Steal a car! Marcel will follow you"):
		return
	if Wanted.level > 0:
		objective("Lose the police")
		while Wanted.level > 0:
			if not await _keep_marcel():
				return
	if not await _board("Get back in a car with Marcel"):
		return
	objective("Drive Marcel to the Blue Lantern")
	while player_pos().distance_to(curb("blue_lantern")) > 8.0 or game.player.vehicle == null:
		if not await _keep_marcel():
			return
	unmark(club_mark)

	# Home safe.
	game.player.vehicle.speed = 0.0
	marcel.dismount(club + Vector3(1.0, 0, 0))
	marcel.hide_marker()
	celeste.global_position = club + Vector3(-1.5, 0, 0)
	celeste.reset_physics_interpolation()
	await say([
		["Celeste", "Marcel! Look at you. Not a scratch."],
		["Marcel", "Aurum boys tried to box us in. Jules drives like the old man."],
		["Celeste", "Aurum. So Victor Hale wants something from the Moreaus."],
		["Celeste", "Keep my number, Jules. I hear everything that's said in this city after midnight."],
	])


## Aurum vans box the car in; the engine is shot out and the police are on
## the way.
func _ambush() -> void:
	line("Marcel", "Black vans! That's Aurum!")
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
	var placed := 0
	for d in dirs:
		if placed >= 2:
			break
		var spot: Vector2i = game.city.nearest_node(player_pos() + d * 40.0)
		if not game.city.in_grid(spot):
			continue
		var pos: Vector3 = game.city.node_pos(spot)
		if pos.distance_to(player_pos()) < 20.0:
			continue
		var to := player_pos() - pos
		var van = car("van", Color(0.08, 0.08, 0.1), pos, atan2(-to.x, -to.z))
		van.driver = Vehicle.Driver.CHASER
		van.officer_deployed.connect(_guards_out)
		placed += 1
	# Gunfire on a busy street: the police are on their way.
	Wanted.report_crime(2)
	var ride = game.player.vehicle
	await until(func(): return ride == null or ride.wrecked, 4.0)
	if ended:
		return
	if ride != null and not ride.wrecked:
		Fx.crash(ride.global_position, 18.0, true)
		ride._damage(ride.health + 1.0)
	line("Marcel", "They shot out the engine! Get us another ride!")
	marcel.mode = Npc.Mode.FOLLOW


func _guards_out(van) -> void:
	for side in [-1.0, 1.0]:
		var g = npc("Aurum", Cast.AURUM, van.global_position + van.global_basis.x * 1.8 * side, true)
		g.max_health = 50.0
		g.health = 50.0
		g.punch_damage = 7.0
		g.swing_pause = 1.0
		g.fight()


## Waits until the player is driving a car (not a scooter) with Marcel in it.
func _board(text: String) -> bool:
	objective(text)
	while marcel.vehicle == null or marcel.vehicle != game.player.vehicle:
		if not await _keep_marcel():
			return false
	return true


## One frame of looking after Marcel: he follows on foot, climbs into the
## player's car when it's close, and gets out with the player.
func _keep_marcel() -> bool:
	var ride = game.player.vehicle
	if marcel.vehicle != null and marcel.vehicle != ride:
		marcel.dismount(marcel.vehicle.global_position + marcel.vehicle.global_basis.x * 2.0)
		marcel.mode = Npc.Mode.FOLLOW
	if marcel.vehicle == null and ride != null and not ride.wrecked:
		if ride.shows_rider:
			if marcel.global_position.distance_to(ride.global_position) < BOARD_RANGE and randf() < 0.01:
				line("Marcel", "I'm not getting on that thing. Find a car.")
		elif marcel.global_position.distance_to(ride.global_position) < BOARD_RANGE:
			marcel.mount(ride)
			marcel.hide_marker()
	if marcel.vehicle == null:
		marcel.mode = Npc.Mode.FOLLOW
		marcel.show_marker(BLUE)
	return await tick()
