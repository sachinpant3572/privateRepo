extends Node
## Doors and rooms (INTERIORS_SERVICES_PLAN.md, D1): walk up to a place's
## lit doorstep and press ENTER. The screen fades for a moment while the
## room is built on a worker thread far from the city (ORIGIN); the street
## waits frozen exactly as it was (every node stops processing and hides)
## and is put back when you leave. Inside: the shopkeeper and customers
## going about their business, the counter's menu (shop_menu.gd), seats
## for diner meals, and the doorway back out.
##
## Doors are locked while the police are after you or a mission is
## running, and shut outside opening hours.

const InteriorKit = preload("res://scripts/kits/interior_kit.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const Places = preload("res://scripts/places.gd")
const Patron = preload("res://scripts/patron.gd")
const ShopMenu = preload("res://scripts/shop_menu.gd")
const Inventory = preload("res://scripts/inventory.gd")
const MapImage = preload("res://scripts/map_image.gd")
const L = preload("res://scripts/layers.gd")

## Rooms are built here, well away from the city.
const ORIGIN := Vector3(-4000, 0, -4000)
## How close to a door (outside) or to the exit and counter (inside) the
## ENTER button works.
const DOOR_RANGE := 1.8
const USE_RANGE := 1.5
const FADE_TIME := 0.3
## Camera zoom that frames a room.
const ROOM_ZOOM := 15.0
## A diner meal takes this long; health comes up over it.
const MEAL_TIME := 4.0
## Customers: at most this many at once, arriving every few seconds.
const CROWD := {"corner_store": 3, "diner": 7}
const ARRIVALS := Vector2(7.0, 15.0)

enum State { OUTSIDE, ENTERING, INSIDE, LEAVING }

var game
var state := State.OUTSIDE
## The place the player is in (or going into).
var place: Dictionary = {}
## The room (InteriorKit.build()).
var room: Dictionary = {}
## Outside: the place whose doorstep the player stands on.
var near: Dictionary = {}
var menu
var rng := RandomNumberGenerator.new()

var _root: Node3D
var _markers: Array = [] # [place, MeshInstance3D]
var _marker_mats := {}
var _layer: CanvasLayer
var _fade: ColorRect
var _frozen: Array = [] # [node, process_mode, visible]
var _taken := {} # spot index -> patron or the player
var _next_arrival := 0.0
var _meal := 0.0
var _meal_heal := 0.0
var _meal_seat := -1
var _snack_pose := 0.0
var _cooldown := 0.0
var _blink := 0.0
## Bumped by force_out(), so a fade in progress knows it was cut short.
var _visit := 0
var _tween: Tween


func _ready() -> void:
	rng.randomize()
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	menu = ShopMenu.new()
	menu.game = game
	menu.on_buy = buy
	menu.on_close = _menu_closed
	_layer.add_child(menu)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)
	for p in game.city.places:
		_add_marker(p)


func is_inside() -> bool:
	return state == State.INSIDE


## Entering or leaving: the screen is fading.
func busy() -> bool:
	return state == State.ENTERING or state == State.LEAVING


## Why the player can't go in right now ("" when they can).
func lock_reason(p: Dictionary) -> String:
	if Wanted.level > 0:
		return "Lose the cops first"
	if game.missions != null and game.missions.active != null:
		return "Finish the job first"
	if not Places.is_open(p, game.atmosphere.hour):
		return "Closed until %02d:00" % int(p.hours[0])
	return ""


## [text, button] for the HUD, or [] when there's nothing to do here.
func prompt() -> Array:
	match state:
		State.OUTSIDE:
			if near.is_empty():
				return []
			var why := lock_reason(near)
			if why == "":
				return ["%s: E / ENTER" % near.name, "ENTER"]
			return ["%s. %s" % [near.name, why], "CLOSED" if why.begins_with("Closed") else "LOCKED"]
		State.INSIDE:
			if _meal > 0.0 or menu.visible:
				return ["Eating...", "EATING"] if _meal > 0.0 else []
			match _use_target():
				"exit":
					return ["Leave: E / EXIT", "EXIT"]
				"counter":
					return ["Order food: E / ORDER", "ORDER"] if place.type == "diner" else ["Shop: E / BUY", "BUY"]
	return []


## The player pressed ENTER on foot. Returns true when a door, the exit or
## the counter took it.
func try_interact() -> bool:
	if _cooldown > 0.0 or busy():
		return busy()
	match state:
		State.OUTSIDE:
			if near.is_empty() or lock_reason(near) != "":
				return false
			enter(near)
			return true
		State.INSIDE:
			if _meal > 0.0 or menu.visible:
				return true
			match _use_target():
				"exit":
					leave()
				"counter":
					game.player.controllable = false
					game.player.velocity = Vector3.ZERO
					menu.open(place)
			return true
	return false


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var player = game.player
	if state == State.OUTSIDE:
		near = {}
		if player.vehicle == null and not player.dead and not game.respawning:
			var best := DOOR_RANGE
			for p in game.city.places:
				var d: float = player.global_position.distance_to(p.door)
				if d < best:
					best = d
					near = p
	elif state == State.INSIDE:
		_update_people(delta)
		if _meal > 0.0:
			var step := minf(delta, _meal)
			player.health = minf(player.max_health, player.health + _meal_heal * step / MEAL_TIME)
			_meal -= step
			if _meal <= 0.0:
				_finish_meal()
	if _snack_pose > 0.0:
		_snack_pose -= delta
		if _snack_pose <= 0.0 and player.gesture == "eat":
			player.gesture = ""


func _process(delta: float) -> void:
	_blink += delta
	var pulse := 0.45 + 0.25 * sin(_blink * 3.0)
	for type in _marker_mats:
		var mat: StandardMaterial3D = _marker_mats[type]
		mat.albedo_color.a = pulse
	if state == State.OUTSIDE and _markers.size() > 0:
		# Shut doors show dim.
		var hour: float = game.atmosphere.hour
		for m in _markers:
			m[1].transparency = 0.0 if Places.is_open(m[0], hour) else 0.7


# --- Going in and out --------------------------------------------------------------

func enter(p: Dictionary) -> void:
	if state != State.OUTSIDE:
		return
	state = State.ENTERING
	place = p
	near = {}
	var player = game.player
	player.controllable = false
	player.velocity = Vector3.ZERO
	var visit := _visit
	var result := {}
	var task := WorkerThreadPool.add_task(func(): result["room"] = InteriorKit.build(p.type, p.seed), false, "interior")
	await _fade_to(1.0)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if visit != _visit:
		return
	if player.dead or game.respawning:
		# Knocked down on the doorstep during the fade: stay outside.
		state = State.OUTSIDE
		place = {}
		await _fade_to(0.0)
		return
	room = result.room
	_freeze_street()
	_make_room()
	player.global_position = ORIGIN + room.hub + Vector3(0, 0, -0.4)
	player.rotation.y = 0.0
	player.reset_physics_interpolation()
	game.camera.fixed_focus = ORIGIN + room.focus
	game.camera.room_size = ROOM_ZOOM
	game.camera.snap()
	game.atmosphere.indoors = true
	_spawn_people()
	state = State.INSIDE
	# Inside on the exit spot: a double tap of ENTER doesn't walk back out.
	_cooldown = 0.5
	game.hud.show_banner(place.name)
	await _fade_to(0.0)
	if state == State.INSIDE and visit == _visit:
		player.controllable = true


func leave() -> void:
	if state != State.INSIDE:
		return
	state = State.LEAVING
	menu.close()
	var player = game.player
	player.controllable = false
	player.velocity = Vector3.ZERO
	var visit := _visit
	await _fade_to(1.0)
	if visit != _visit:
		return
	_clear_room()
	_thaw_street()
	player.sitting = false
	player.gesture = ""
	player._set_standing_layers()
	player.global_position = place.door
	player.rotation.y = place.yaw + PI
	player.reset_physics_interpolation()
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.camera.snap()
	game.atmosphere.indoors = false
	state = State.OUTSIDE
	place = {}
	room = {}
	_cooldown = 0.5
	await _fade_to(0.0)
	if state == State.OUTSIDE and visit == _visit:
		player.controllable = true


## Back on the street at once, no fade: for a respawn, a mission (re)start
## or a new game while inside or on the way in or out. Whoever calls it
## puts the player where they need to be.
func force_out() -> void:
	if state == State.OUTSIDE:
		return
	_visit += 1
	if _tween:
		_tween.kill()
	_fade.color.a = 0.0
	menu.visible = false
	_clear_room()
	_thaw_street()
	var player = game.player
	player.sitting = false
	player.gesture = ""
	player._set_standing_layers()
	player.controllable = true
	game.camera.fixed_focus = null
	game.camera.room_size = 0.0
	game.atmosphere.indoors = false
	state = State.OUTSIDE
	place = {}
	room = {}
	near = {}
	_cooldown = 0.5


func _fade_to(alpha: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await _tween.finished


## Stops and hides everything on the street (people, traffic, police, the
## city's streaming) so it waits exactly as it was.
func _freeze_street() -> void:
	_frozen.clear()
	var keep := [game.player, game.camera, game.atmosphere, game.hud, game.missions, self]
	for child in game.get_children():
		if child in keep:
			continue
		_frozen.append([child, child.process_mode, child.get("visible")])
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is Node3D or child is CanvasItem:
			child.visible = false
	for m in _markers:
		m[1].visible = false


func _thaw_street() -> void:
	for f in _frozen:
		var node: Node = f[0]
		if not is_instance_valid(node):
			continue
		node.process_mode = f[1]
		if f[2] != null:
			node.visible = f[2]
	_frozen.clear()
	for m in _markers:
		m[1].visible = true


func _make_room() -> void:
	_root = Node3D.new()
	_root.name = "Interior"
	_root.position = ORIGIN
	add_child(_root)
	var inst: MeshInstance3D = room.mesh.make_instance()
	inst.material_override = MeshBuilder.cutaway_material()
	_root.add_child(inst)
	var body := StaticBody3D.new()
	body.collision_layer = L.WORLD
	body.collision_mask = 0
	_root.add_child(body)
	for c in room.colliders:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = c[1]
		shape.shape = box
		shape.position = c[0]
		body.add_child(shape)


func _clear_room() -> void:
	_meal = 0.0
	_meal_seat = -1
	_taken.clear()
	if _root:
		_root.queue_free()
		_root = null
	for n in get_tree().get_nodes_in_group("patrons"):
		n.remove_from_group("patrons")
		n.queue_free()
	for n in get_tree().get_nodes_in_group("patrons_out"):
		n.queue_free()


# --- People ---------------------------------------------------------------------

func _spawn_people() -> void:
	_taken.clear()
	for s in room.staff:
		var who = _add_patron(CharacterKit.random_look(rng, "polo"))
		who.staff = true
		who.global_position = ORIGIN + s.pos
		who.rotation.y = s.yaw
		who.gesture = s.gesture
	var crowd: int = CROWD.get(place.type, 3)
	# Some people are already here: seated diners, shoppers mid-aisle.
	var already := rng.randi_range(crowd / 2, crowd - 1)
	for k in already:
		var who = _new_customer()
		if who == null:
			break
		if place.type == "diner":
			var seat := _free_spot(["seat", "stool"])
			if seat < 0:
				who.queue_free()
				break
			_taken[seat] = who
			who.seat_now(room.spots[seat], rng.randf_range(8.0, 40.0))
		else:
			var spots := _spots_of(["browse"])
			var i: int = spots[rng.randi() % spots.size()]
			who.stops = [{"spot": room.spots[_spots_of(["till"])[0]], "time": 3.0}]
			who.seat_now(room.spots[i], rng.randf_range(2.0, 6.0))
	_next_arrival = rng.randf_range(2.0, 5.0)


func _update_people(delta: float) -> void:
	_next_arrival -= delta
	if _next_arrival > 0.0:
		return
	_next_arrival = rng.randf_range(ARRIVALS.x, ARRIVALS.y)
	if _customers() >= CROWD.get(place.type, 3):
		return
	var who = _new_customer()
	if who == null:
		return
	if place.type == "diner":
		var seat := _free_spot(["seat", "stool"])
		if seat < 0:
			who.queue_free()
			return
		_taken[seat] = who
		who.stops = [{"spot": room.spots[_spots_of(["order"])[0]], "time": 3.0},
			{"spot": room.spots[seat], "time": rng.randf_range(20.0, 45.0)}]
	else:
		var browse := _spots_of(["browse"])
		for k in rng.randi_range(1, 3):
			who.stops.append({"spot": room.spots[browse[rng.randi() % browse.size()]], "time": rng.randf_range(3.0, 7.0)})
		who.stops.append({"spot": room.spots[_spots_of(["till"])[0]], "time": 3.0})
	who.global_position = ORIGIN + room.door + Vector3(0, 0, -0.3)
	who.next_stop()


func _new_customer():
	var who = _add_patron(CharacterKit.random_look(rng))
	who.origin = ORIGIN
	who.hub = ORIGIN + room.hub
	who.door = ORIGIN + room.door + Vector3(0, 0, -0.3)
	who.left.connect(_on_left)
	who.died.connect(_on_died)
	return who


func _add_patron(look: Dictionary):
	var who = Patron.new()
	who.look = look
	_root.add_child(who)
	return who


func _customers() -> int:
	var n := 0
	for p in get_tree().get_nodes_in_group("patrons"):
		if not p.staff and not p.is_queued_for_deletion():
			n += 1
	return n


func _on_left(who) -> void:
	for k in _taken.keys():
		if _taken[k] == who:
			_taken.erase(k)


## Knocked out inside: the seat is free again, they no longer count in
## the crowd, and the body is taken away after a while.
func _on_died(who) -> void:
	_on_left(who)
	who.remove_from_group("patrons")
	who.add_to_group("patrons_out")
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(who):
			who.queue_free())


func _spots_of(kinds: Array) -> Array:
	var list: Array = []
	for i in room.spots.size():
		if room.spots[i].kind in kinds:
			list.append(i)
	return list


## A random free seat of the given kinds, booths and tables first; -1 if
## the place is full.
func _free_spot(kinds: Array) -> int:
	for kind in kinds:
		var free: Array = []
		for i in _spots_of([kind]):
			if not _taken.has(i):
				free.append(i)
		if not free.is_empty():
			return free[rng.randi() % free.size()]
	return -1


# --- Buying and eating -------------------------------------------------------------

## What the player stands at inside: "exit", "counter" or "".
func _use_target() -> String:
	var p: Vector3 = game.player.global_position - ORIGIN
	if p.distance_to(room.hub) < USE_RANGE:
		return "exit"
	if p.distance_to(room.counter.pos) < USE_RANGE:
		return "counter"
	return ""


## Buys item `id`: "eat" (now), "take" (into the bag) or "order" (a diner
## meal, eaten seated). Returns false if it can't be done.
func buy(id: String, mode: String) -> bool:
	var item: Dictionary = Inventory.ITEMS.get(id, {})
	if item.is_empty() or game.cash < item.price or state != State.INSIDE:
		return false
	var player = game.player
	match mode:
		"take":
			if not game.inventory.add(id):
				return false
		"eat":
			if item.get("seated", false):
				return false
			player.health = minf(player.max_health, player.health + item.heal)
			_snack_pose = 1.5
			player.gesture = "eat"
		"order":
			if not item.get("seated", false):
				return false
			var seat := _free_spot(["seat", "stool"])
			if seat < 0:
				menu.say("No free seats right now")
				return false
			game.cash -= item.price
			game.missions.save_game()
			menu.close()
			_start_meal(seat, item.heal)
			return true
		_:
			return false
	game.cash -= item.price
	game.missions.save_game()
	menu.refresh()
	return true


func _start_meal(seat: int, heal: float) -> void:
	var player = game.player
	player.controllable = false
	_taken[seat] = player
	_meal_seat = seat
	_meal_heal = heal
	_meal = MEAL_TIME
	var spot: Dictionary = room.spots[seat]
	player.collision_layer = 0
	player.collision_mask = 0
	player.global_position = ORIGIN + spot.pos
	player.rotation.y = spot.yaw
	player.reset_physics_interpolation()
	player.sitting = true
	player.gesture = "eat"


func _finish_meal() -> void:
	var player = game.player
	var spot: Dictionary = room.spots[_meal_seat]
	var path: Array = spot.path
	_taken.erase(_meal_seat)
	_meal_seat = -1
	player.sitting = false
	player.gesture = ""
	player.global_position = ORIGIN + (path[path.size() - 2] if path.size() > 1 else room.hub)
	player.reset_physics_interpolation()
	player._set_standing_layers()
	player.controllable = true


func _menu_closed() -> void:
	_cooldown = 0.3
	if state == State.INSIDE and _meal <= 0.0:
		game.player.controllable = true


# --- Door markers -------------------------------------------------------------------

## A glowing ring on the doorstep in the place type's map colour.
func _add_marker(p: Dictionary) -> void:
	var type: String = p.type
	if not _marker_mats.has(type):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = (MapImage.icon(type)[1] as Color).lightened(0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_marker_mats[type] = mat
	var mb := MeshBuilder.new()
	var sides := 20
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		mb.quad(o0 * 0.55, o1 * 0.55, o1 * 0.75, o0 * 0.75, Vector3.UP, Color.WHITE)
	var inst := MeshInstance3D.new()
	inst.mesh = mb.commit()
	inst.material_override = _marker_mats[type]
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = p.door + Vector3(0, 0.2, 0)
	add_child(inst)
	_markers.append([p, inst])
