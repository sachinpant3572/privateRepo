extends Node
## Base for story missions. A mission is a script whose run() is one
## coroutine: it sets objectives, places markers, spawns people and cars,
## and awaits the helpers below. Every helper returns false once the mission
## has ended (failed or abandoned), so steps read as
##     if not await reach(point, "Go home"): return
## Anything spawned through the helpers is cleaned up when the mission ends.

const Npc = preload("res://scripts/npc.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")

const YELLOW := Color(1.0, 0.78, 0.2)
const BLUE := Color(0.35, 0.65, 1.0)
const RED := Color(1.0, 0.3, 0.25)

var id := ""
var title := ""
var reward := 0
## Shown on the pass screen, e.g. "Phone".
var unlocks := ""
var game
var manager
var ended := false
var spawned: Array = []
var _fail_checks: Array = []


## Where the player is put for a retry, and the hour it starts at (-1 keeps
## the clock).
func start_point() -> Vector3:
	return game.city.spawn_point


func start_hour() -> float:
	return -1.0


## The mission itself; override.
func run() -> void:
	pass


# --- Flow ----------------------------------------------------------------------

func objective(text: String) -> void:
	manager.set_objective(text)


## Adds a map marker (and a glowing ring in the world unless `ring` is false).
func mark(pos: Vector3, label: String, color := YELLOW, ring := true) -> Dictionary:
	return manager.add_marker(pos, label, color, ring)


## A map marker that tracks a moving node (a fleeing car, a person).
func mark_node(node: Node3D, label: String, color := RED) -> Dictionary:
	var m := mark(node.global_position, label, color, false)
	m["follow"] = node
	return m


func unmark(m: Dictionary) -> void:
	manager.remove_marker(m)


func clear_marks() -> void:
	manager.clear_markers()


## Fails the mission whenever `cond` becomes true.
func fail_if(cond: Callable, reason: String) -> void:
	_fail_checks.append([cond, reason])


func fail(reason: String) -> void:
	if not ended:
		manager.fail(self, reason)


func check_fail() -> void:
	for c in _fail_checks:
		if c[0].call():
			fail(c[1])
			return


func tick() -> bool:
	await get_tree().physics_frame
	return not ended


func wait(seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if not await tick():
			return false
		t += get_physics_process_delta_time()
	return true


## Waits until `cond` is true. With a timeout, returns false when it runs
## out (the mission continues; check `ended` if that matters).
func until(cond: Callable, timeout := -1.0) -> bool:
	var t := 0.0
	while not cond.call():
		if not await tick():
			return false
		t += get_physics_process_delta_time()
		if timeout > 0.0 and t > timeout:
			return false
	return true


## Lines of dialogue, one after another: [[speaker, text], ...]. The player
## can still move unless `hold` is set.
func say(lines: Array, hold := false) -> bool:
	if hold:
		game.player.controllable = false
	for line in lines:
		var done := [false]
		var on_done := func(): done[0] = true
		manager.hud.show_dialogue(line[0], line[1], on_done)
		if not await until(func(): return done[0]):
			break
	manager.hud.hide_dialogue()
	if hold:
		game.player.controllable = true
	return not ended


## One line of dialogue that doesn't hold up the mission.
func line(speaker: String, text: String) -> void:
	manager.hud.show_dialogue(speaker, text)


## Shows a prompt for the interact button ("Search: E", "SEARCH").
func prompt(text: String, button: String) -> void:
	manager.hud.context_prompt = [text, button]


func clear_prompt() -> void:
	manager.hud.context_prompt = []


## Objective plus marker; waits for the player (on foot or driving) to get
## within `radius` of `pos`.
func reach(pos: Vector3, text: String, radius := 4.0, on_foot := false, label := "") -> bool:
	objective(text)
	var m := mark(pos, label if label != "" else text)
	var ok := await until(func():
		var p: Vector3 = game.player.focus_node().global_position
		return Vector2(p.x - pos.x, p.z - pos.z).length() < radius and (not on_foot or game.player.vehicle == null))
	unmark(m)
	return ok


## Waits for every NPC in `group` to be down or dead.
func defeat(group: Array, text: String) -> bool:
	objective(text)
	for n in group:
		n.show_marker(RED)
	return await until(func(): return group.all(func(n): return not is_instance_valid(n) or n.dead or n.knocked_time > 0.0 and n.health < 25.0))


## Full-screen title card ("HOMECOMING", "Later that night...").
func card(text: String, sub := "", seconds := 2.5) -> bool:
	manager.hud.show_card(text, sub, seconds)
	return await wait(seconds * 0.6)


# --- Spawning ------------------------------------------------------------------

func npc(name_: String, look: Dictionary, pos: Vector3, hostile := false):
	var n = Npc.new()
	n.setup(name_, look, hostile)
	n.position = Vector3(pos.x, 0.0, pos.z)
	game.add_child(n)
	spawned.append(n)
	return n


func car(kind: String, paint: Color, pos: Vector3, yaw: float):
	var c = Vehicle.new()
	c.kind = kind
	c.body_color = paint
	c.city = game.city
	c.position = Vector3(pos.x, 0.0, pos.z)
	c.rotation.y = yaw
	game.add_child(c)
	spawned.append(c)
	return c


## Frees what the mission spawned (except a car the player is sitting in).
func cleanup() -> void:
	clear_prompt()
	for node in spawned:
		if not is_instance_valid(node):
			continue
		if node == game.player.vehicle:
			node.unload_all()
			continue
		if node.get("vehicle") != null and node.vehicle == game.player.vehicle:
			continue
		node.queue_free()
	spawned.clear()


# --- Map helpers ----------------------------------------------------------------

## The sidewalk in front of a landmark (where people meet).
func front(id_: String) -> Vector3:
	return game.city.landmark_front(id_)


## In the near lane of the street in front of a landmark, `along` metres to
## the right (where cars stop).
func curb(id_: String, along := 0.0) -> Vector3:
	return game.city.landmark_curb(id_, along)


## A point in a landmark's street frame: x along the street (right as seen
## from it), z out towards the street (negative is into the block).
func near(id_: String, local: Vector3) -> Vector3:
	return game.city.landmark_frame(id_) * local


## Yaw for a car parked in front of a landmark, facing along the street.
func street_yaw(id_: String) -> float:
	return game.city.curb_yaw(game.city.landmark_block(id_))


func player_pos() -> Vector3:
	return game.player.focus_node().global_position
