extends "res://scripts/missions/mission.gd"
## Mission 1, Homecoming: Jules steps off the train, a kid snatches their
## bag and runs for a scooter; Jules takes another scooter, chases him through
## the Lantern Quarter to Lantern Square, beats his crew, takes their car and
## drives home to Moreau House, where nobody is waiting.

const Cast = preload("res://scripts/missions/cast.gd")

## Give up the chase when this far behind for this long.
const LOST_DISTANCE := 95.0
const LOST_TIME := 7.0

var kid
var getaway
var spare
var crew: Array = []
var crew_car


func _init() -> void:
	reward = 500
	unlocks = "The map"


func start_hour() -> float:
	return 17.0


func run() -> void:
	game.player.controllable = false
	# The first look at the hero is his face, not his back (Sachin,
	# 2026-10-28): he turns to the street and the camera comes round in front
	# for the card and his first line, then eases back for the snatch.
	close_up(game.player, curb("union_station"))
	if not await card("HOMECOMING", "Act 1  ·  Mission 1"):
		return
	if not await say([["Jules", "Twelve years. Bellerive still smells like rain and fried dough."]], true):
		return
	close_up(null)
	game.player.controllable = false

	# The snatch.
	kid = npc("Kid", Cast.THIEF, near("union_station", Vector3(-9.0, 0, 0.3)), true)
	kid.run_speed = 6.3
	kid.max_health = 45.0
	getaway = car("scooter", Color(0.2, 0.6, 0.35), curb("union_station", -34.0), street_yaw("union_station"))
	spare = car("scooter", Color(0.95, 0.8, 0.25), curb("union_station", -6.0), street_yaw("union_station"))
	kid.walk_to(game.player.global_position + Vector3(-0.6, 0, 0.4), true)
	await until(func(): return kid.arrived, 4.0)
	if ended:
		return
	game.player.take_hit(null, 0.0, Vector3.RIGHT * 0.5)
	kid.walk_to(near("union_station", Vector3(-34.0, 0, 0.6)), true)
	game.player.controllable = true
	line("Jules", "Hey! That's my bag!")
	objective("Catch the thief!")
	kid.show_marker(RED)

	# He reaches his scooter first (head start), then rides for the Square.
	await until(func(): return kid.arrived or kid.global_position.distance_to(getaway.global_position) < 2.2)
	if ended:
		return
	kid.mount(getaway)
	var square := curb("lantern_square")
	getaway.drive_path(game.city.route_lanes(getaway.global_position, square), 0.68)
	line("Jules", "A scooter? Fine. Two can play.")
	objective("Get on the scooter")
	var spare_mark := mark(spare.global_position, "Scooter")
	await until(func(): return game.player.vehicle != null)
	unmark(spare_mark)
	if ended:
		return

	# The chase.
	objective("Follow the thief")
	var thief_mark := mark_node(getaway, "Thief")
	var lost := 0.0
	var arrived := [false]
	getaway.path_done.connect(func(_c): arrived[0] = true)
	while not arrived[0]:
		if not await tick():
			return
		var d := player_pos().distance_to(getaway.global_position)
		lost = lost + get_physics_process_delta_time() if d > LOST_DISTANCE else 0.0
		if lost > LOST_TIME:
			fail("The thief got away.")
			return
		if getaway.wrecked:
			fail("The thief's scooter is wrecked. He needs to lead you to his crew.")
			return
		if crew.is_empty() and getaway.global_position.distance_to(square) < 140.0:
			# His crew waits at the Square, with their car.
			for i in Cast.CREW.size():
				var thug = npc("Crew", Cast.CREW[i], near("lantern_square", Vector3(-3.0 + i * 6.0, 0, -1.0)), true)
				thug.gesture = "talk"
				thug.max_health = 55.0
				thug.health = 55.0
				thug.punch_damage = 6.0
				crew.append(thug)
			crew_car = car("pickup", Color(0.38, 0.14, 0.18), curb("lantern_square", -14.0), street_yaw("lantern_square"))

	# Showdown at Lantern Square.
	unmark(thief_mark)
	var inward: Vector3 = -game.city.landmark_frame("lantern_square").basis.z
	kid.dismount(getaway.global_position + inward * 2.5)
	kid.health = kid.max_health
	crew.append(kid)
	line("Kid", "You followed me? Big mistake, tourist.")
	for n in crew:
		n.gesture = ""
		n.punch_damage = 6.0
		n.swing_pause = 0.9
		n.fight()
	if not await defeat(crew, "Beat the crew"):
		return
	for n in crew:
		if is_instance_valid(n) and not n.dead:
			n.hide_marker()
			n.mode = Npc.Mode.FLEE
	await wait(0.6)
	line("Jules", "I'll take the bag. And your car.")
	await wait(1.0)

	# Home.
	objective("Take the crew's car")
	var car_mark := mark(crew_car.global_position, "Their car", YELLOW, false)
	await until(func(): return game.player.vehicle != null and not game.player.vehicle.shows_rider)
	unmark(car_mark)
	if ended:
		return
	if not await reach(curb("moreau_house"), "Drive home to Moreau House", 7.0, false, "Moreau House"):
		return
	if not await reach(front("moreau_house"), "Go to the front door", 1.8, true, "Front door"):
		return
	await say([
		["Jules", "Teo? It's me. I'm home."],
		["Jules", "..."],
		["Jules", "Nobody. And Teo's room is cleaned out. What happened here?"],
	], true)
