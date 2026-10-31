extends Node3D
## Wild animals of the hill country: deer (herds of 2 to 5, a buck with
## antlers among the does) and rabbits by day, coyote packs at dusk and by
## night, and the odd mountain lion deep in the forest at night. They live
## within RADIUS of the camera's focus on the raised ground of the "mountain"
## and "hillside" zones (never in the city, the lakes, the streams or on a
## lot), and are drawn with kits/animal_kit.gd: one MultiMesh and one draw
## call per model, the legs, head and tail animated in its vertex shader.
##
## What they do. Deer graze, idle and wander as a herd behind a leader, and
## bolt together from a person on foot within 25 m (rabbits 12 m, zigzagging)
## or a moving car, tails up. Coyotes trot between spots and, when someone on
## foot is within 75 m, circle at about 28 m without coming closer, and run
## if they are pressed. The lion prowls, stalks a person on foot in the dark
## and, if they stay within 10 m, charges and strikes once through the
## player's own take_hit, then runs off; it also runs when it is hit. A
## moving car kills what it runs into (blood, a body left for a minute; a
## deer jolts the car).
##
## For hunting (HANDOFF-hill-content.md, phase H): animals_in(), kill(),
## hurt(), carcass_near(), take_carcass(), the killed signal, and the static
## Wildlife.startle(pos, radius) beside Birds.startle for loud events.
##
## Atmosphere owns it (`Wildlife.attach(self)`), like the birds: it reads
## atmosphere.hour, .weather, .indoors and .focus.

const Terrain = preload("res://scripts/terrain.gd")
const AnimalKit = preload("res://scripts/kits/animal_kit.gd")
const GameLog = preload("res://scripts/game_log.gd")

## An animal died: its kind, where, and by whom ("car", "player", "other").
signal killed(kind: String, pos: Vector3, by: String)

## Most alive near the focus (half of it on Low quality).
const MAX_ALIVE := 16
## Animals live within RADIUS of the focus; new ones appear out of view
## between NEAR and RADIUS (the first fill: from START_CLEAR on) and go
## when they are past DESPAWN.
const RADIUS := 200.0
const NEAR := 130.0
const START_CLEAR := 32.0
const DESPAWN := 270.0
## Raised ground only.
const MIN_HEIGHT := 8.0
## Below this the ground is a shore or a bed; steeper than this normal.y is a cliff.
const SHORE_HEIGHT := 3.0
const CLIFF := 0.75
const CARCASS_TIME := 60.0
const SINK_TIME := 4.0
const POLL := 0.2
## A car kills at this speed (m/s) and above.
const CAR_KILL_SPEED := 3.0
const HABITAT_ZONES := ["mountain", "hillside"]
const LOT_CELL := 64.0
const STREAM_CELL := 32.0
## in_city is cached on a grid this fine (m), by the cell's centre.
const CITY_CELL := 8.0
## Lion: the player stays this close for ATTACK_AFTER seconds and it charges.
const LION_ZONE := 10.0
const LION_CLOSE := 6.5
const ATTACK_AFTER := 1.8
const STRIKE_RANGE := 1.9
const LION_DAMAGE := 26.0
## Coyotes circle a person on foot at this radius once within CIRCLE_ENTER.
const CIRCLE_R := 28.0
const CIRCLE_ENTER := 75.0
const CIRCLE_EXIT := 100.0
const CIRCLE_RATE := 0.1
## Angles tried to get round something in the way.
const DETOURS := [0.7, -0.7, 1.4, -1.4, 2.1, -2.1, 2.8]

## Per kind: hp; group size; cap alive; active hours (from, to; to < from
## wraps midnight); wander speed `travel`, trot, run (m/s); `stride` metres
## per gait cycle at walk, trot, gallop; turn rate (rad/s); scare radius
## `flee` on a person on foot and `car` from a moving car; herd `spread`;
## `graze` odds of grazing when resting, `rest` seconds, `walk_odds` of
## wandering when a rest ends, `hop` distance range of a wander; spawn
## weight.
const KINDS := {
	"deer": {"models": ["doe", "buck"], "hp": 40.0, "group": [2, 5], "cap": 10, "from": 5.5, "to": 20.5,
		"travel": 1.2, "walk": 1.2, "trot": 3.4, "run": 11.0, "stride": [1.3, 2.4, 4.2], "turn": 4.5,
		"flee": 25.0, "car": 34.0, "spread": 4.5, "graze": 0.7, "rest": [6.0, 16.0], "walk_odds": 0.55,
		"hop": [10.0, 38.0], "weight": 4.0},
	"rabbit": {"models": ["rabbit"], "hp": 6.0, "group": [1, 1], "cap": 4, "from": 6.0, "to": 19.5,
		"travel": 1.0, "walk": 1.0, "trot": 2.6, "run": 7.0, "stride": [0.55, 1.1, 1.5], "turn": 9.0,
		"flee": 12.0, "car": 20.0, "spread": 0.0, "graze": 0.6, "rest": [3.0, 9.0], "walk_odds": 0.5,
		"hop": [4.0, 16.0], "weight": 2.0},
	"coyote": {"models": ["coyote"], "hp": 30.0, "group": [2, 4], "cap": 8, "from": 18.0, "to": 6.0,
		"travel": 2.6, "walk": 1.4, "trot": 3.8, "run": 9.5, "stride": [1.1, 1.8, 3.0], "turn": 6.0,
		"flee": 16.0, "car": 26.0, "spread": 5.5, "graze": 0.0, "rest": [3.0, 9.0], "walk_odds": 0.7,
		"hop": [14.0, 45.0], "weight": 3.0},
	"lion": {"models": ["lion"], "hp": 70.0, "group": [1, 1], "cap": 1, "from": 19.0, "to": 5.5,
		"travel": 1.3, "walk": 1.3, "trot": 3.0, "run": 12.0, "stride": [1.4, 2.4, 4.0], "turn": 5.0,
		"flee": 0.0, "car": 24.0, "spread": 0.0, "graze": 0.0, "rest": [8.0, 20.0], "walk_odds": 0.5,
		"hop": [12.0, 40.0], "stalk": 1.2, "weight": 0.7},
}

## Instance slots (alive and lying) per model.
const SLOTS := {"doe": 16, "buck": 8, "rabbit": 8, "coyote": 12, "lion": 6}

## Gait amp (the shader's custom data y) for standing, walking, trotting, galloping.
const AMPS := [0.0, 0.3, 0.62, 1.0]

## Every live Wildlife node (Wildlife.startle reaches them all).
static var _all: Array = []

## Atmosphere (hour, weather, focus, indoors).
var atmosphere: Node
## Live animals, alive and lying: {id, kind, model, position (Vector3), alive,
## hp, yaw, speed, state, timer, target, group, offset, ...}.
var animals: Array = []
var rng := RandomNumberGenerator.new()
var _views := {}
var _mms := {}
var _specs := {}
var _next_id := 1
var _next_group := 1
var _spawn_wait := 0.0
var _poll := 0.0
var _last_hour := -1.0
var _last_focus := Vector3.INF
var _game: Node
var _inside := false
var _player: Node3D
var _on_foot := false
var _ppos := Vector3.ZERO
var _pspeed := 0.0
var _punch_prev := 0.0
var _cars: Array = []
var _low := false
# Caches of the country, built on first use.
var _cache_for: Object
var _habitat: Array = []
var _lot_cells := {}
var _stream_cells := {}
var _city_cells := {}


## Gives `atm` its wildlife (atmosphere.gd calls this after the birds): the
## node is added as a child and, if the atmosphere has a `wildlife`
## property, stored there. Returns the existing one if it has one already.
static func attach(atm: Node) -> Node:
	var have = atm.get("wildlife")
	if have is Node and is_instance_valid(have):
		return have
	var w: Node = load("res://scripts/wildlife.gd").new()
	w.atmosphere = atm
	atm.add_child(w)
	atm.set("wildlife", w)
	return w


## Startles every animal within `radius` of `pos` (a gunshot, a crash, an
## explosion): they bolt away from it. Returns how many took fright.
static func startle(pos: Vector3, radius: float) -> int:
	var n := 0
	for w in _all:
		if is_instance_valid(w):
			n += w.scare(pos, radius)
	return n


## Whether `kind` is out and about at `hour`.
static func is_active(kind: String, hour: float) -> bool:
	var k: Dictionary = KINDS[kind]
	var from: float = k.from
	var to: float = k.to
	if from < to:
		return hour >= from and hour < to
	return hour >= from or hour < to


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)
	for i in range(animals.size() - 1, -1, -1):
		_remove(i)


func _ready() -> void:
	rng.randomize()
	for model in AnimalKit.MODELS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# Colours on as well as the custom data: with the data alone the
		# Compatibility renderer feeds it to COLOR. White leaves the mesh's own.
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = AnimalKit.mesh(model)
		mm.instance_count = int(SLOTS[model])
		for slot in mm.instance_count:
			mm.set_instance_color(slot, Color.WHITE)
		mm.visible_instance_count = 0
		var view := MultiMeshInstance3D.new()
		view.name = String(model).capitalize()
		view.multimesh = mm
		view.material_override = AnimalKit.material(model)
		view.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 4e3, 2e5))
		view.visible = false
		# Instances are moved in _process: no physics interpolation for them.
		view.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(view)
		_views[model] = view
		_mms[model] = mm
		_specs[model] = AnimalKit.spec(model)


func _process(delta: float) -> void:
	if atmosphere == null:
		return
	if atmosphere.indoors:
		for model in _views:
			_views[model].visible = false
		_inside = true
		return
	delta = minf(delta, 0.1)
	var hour: float = atmosphere.hour
	var focus := _focus()
	var jump := _last_hour < 0.0 or absf(wrapf(hour - _last_hour, -12.0, 12.0)) > 0.5 \
		or Vector2(focus.x - _last_focus.x, focus.z - _last_focus.z).length() > NEAR
	_last_hour = hour
	_last_focus = focus
	if jump:
		refresh()
		return
	if _inside:
		_inside = false
	_update_player()
	for i in animals.size():
		_step(animals[i], delta)
	_punches()
	_car_kills(delta)
	_reap(focus)
	_spawn_wait -= delta
	if _spawn_wait <= 0.0:
		_spawn_wait = 1.5
		_retire(focus, hour)
		_populate(focus, false)
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_check_threats()
	_push()


## Clears the hills and fills them again for the hour, weather and place (a
## clock jump, a teleport, a test).
func refresh() -> void:
	var focus := _focus()
	for i in range(animals.size() - 1, -1, -1):
		var a: Dictionary = animals[i]
		var p: Vector3 = a.position
		# A carcass stays through a clock jump while the player is near it.
		if not a.alive and Vector2(p.x - focus.x, p.z - focus.z).length() < DESPAWN:
			continue
		_remove(i)
	if atmosphere == null:
		return
	_last_hour = atmosphere.hour
	_last_focus = focus
	_update_player()
	_populate(_last_focus, true)
	_check_threats()
	_push()


# --- The API for hunting and tests -------------------------------------------------

## Most animals alive near the focus now (graphics quality Low halves it).
func max_alive() -> int:
	_low = _quality() == "low"
	return MAX_ALIVE / 2 if _low else MAX_ALIVE


## Animals alive now, of `kind` ("" for all).
func alive_count(kind := "") -> int:
	var n := 0
	for a in animals:
		if a.alive and (kind == "" or a.kind == kind):
			n += 1
	return n


## The animals within `radius` (flat) of `pos`: dictionaries with kind,
## model, position (Vector3, feet), alive, hp ... Only the living, unless
## `with_dead`.
func animals_in(pos: Vector3, radius: float, with_dead := false) -> Array:
	var out := []
	for a in animals:
		if not a.alive and not with_dead:
			continue
		var p: Vector3 = a.position
		if Vector2(p.x - pos.x, p.z - pos.z).length() <= radius:
			out.append(a)
	return out


## Starts a group of `kind` at `pos` (its height is found), `count` strong (0:
## a random size for the kind). Ignores the hour, the habitat and the cap, and
## the animals stay until they are out of range: for tests and scripted scenes.
## Returns the animals (fewer if a model's slots are full, none for a bad kind).
func spawn(kind: String, pos: Vector3, count := 0) -> Array:
	return _spawn(kind, pos, count, false)


## Kills `animal` (one of animals_in's): blood, a carcass that lies for a
## minute, the killed signal, and its herd bolts. `dir` is the way the blow
## went (its length a speed in m/s for the slide, up to 6); `by` is "car",
## "player" (the hunting rifle) or "other".
func kill(animal, dir := Vector3.ZERO, by := "player") -> void:
	if not animal is Dictionary or not animals.has(animal) or not animal.alive:
		return
	var spec: Dictionary = _specs[animal.model]
	var s: float = float(spec.scale) * float(animal.size)
	var flat := Vector3(dir.x, 0.0, dir.z)
	var pos: Vector3 = animal.position
	animal.alive = false
	animal.state = "dead"
	animal.hp = 0.0
	animal.dead_t = 0.0
	animal.roll = 0.0
	animal.side = 1.0 if rng.randf() < 0.5 else -1.0
	animal.speed = 0.0
	animal.slide = Vector2(flat.x, flat.z).limit_length(6.0)
	if flat.length() > 0.01:
		animal.yaw = atan2(-flat.x, -flat.z) + (PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5)
	var group = animal.group
	if group != null:
		(group.members as Array).erase(animal)
		for m in group.members:
			if m.alive:
				_flee(m, pos)
	animal.group = null
	var fx = _fx()
	if fx != null:
		fx.blood(pos + Vector3(0.0, float(spec.body_y) * s, 0.0), flat, clampf(0.5 + s * 0.6, 0.6, 1.6))
		fx.blood_pool(pos, clampf(0.55 * s + 0.3, 0.4, 1.3), 4.0)
	GameLog.event("animal_killed", {"kind": animal.kind, "by": by, "x": snappedf(pos.x, 0.1), "z": snappedf(pos.z, 0.1)})
	killed.emit(animal.kind, pos, by)


## `damage` to `animal` (a punch, a wound): it dies at 0 hp, otherwise it
## bolts (a lion retreats). Returns whether it died.
func hurt(animal, damage: float, dir := Vector3.ZERO, by := "player") -> bool:
	if not animal is Dictionary or not animals.has(animal) or not animal.alive:
		return false
	animal.hp -= damage
	if animal.hp <= 0.0:
		kill(animal, dir, by)
		return true
	var pos: Vector3 = animal.position
	var fx = _fx()
	if fx != null:
		fx.blood(pos + Vector3(0.0, 0.5, 0.0), dir, 0.4)
	if animal.kind == "lion":
		_retreat(animal, pos - dir * 3.0, 30.0)
	else:
		_flee(animal, pos - dir * 3.0)
		if animal.group != null:
			for m in animal.group.members:
				if m.alive and m != animal:
					_flee(m, pos - dir * 3.0)
	return false


## The nearest carcass within `radius` (flat) of `pos`, or {}.
func carcass_near(pos: Vector3, radius: float) -> Dictionary:
	var best := {}
	var best_d := radius
	for a in animals:
		if a.alive:
			continue
		var p: Vector3 = a.position
		var d := Vector2(p.x - pos.x, p.z - pos.z).length()
		if d <= best_d and absf(p.y - pos.y) < 4.0:
			best = a
			best_d = d
	return best


## Takes the carcass `c` (carcass_near's): it is gone from the hills and its
## kind comes back ("deer", "rabbit", "coyote", "lion"; "" if it was not a
## carcass here).
func take_carcass(c) -> String:
	if not c is Dictionary or c.is_empty():
		return ""
	var i := animals.find(c)
	if i < 0 or c.alive:
		return ""
	var kind: String = c.kind
	_remove(i)
	return kind


## The wild animals' ground: raised hill ground of the mountain or hillside
## zones, outside the city. (Whether an animal can stand there: _clear().)
func habitat_at(p: Vector2) -> bool:
	if not Terrain.bounds.has_point(p) or Terrain.height(p.x, p.y) < MIN_HEIGHT:
		return false
	_ensure_caches()
	var inside := false
	for h in _habitat:
		if (h.rect as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, h.poly):
			inside = true
			break
	if not inside:
		return false
	var city = _city()
	return city == null or city.plan == null or not city.plan.in_city(p)


## Startles everything within `radius` of `pos`; see Wildlife.startle.
func scare(pos: Vector3, radius: float) -> int:
	var n := 0
	for a in animals:
		if not a.alive:
			continue
		var p: Vector3 = a.position
		if Vector2(p.x - pos.x, p.z - pos.z).length() > radius:
			continue
		n += 1
		if a.kind == "lion":
			_retreat(a, pos, 20.0)
		else:
			_flee(a, pos)
	return n


# --- Spawning ---------------------------------------------------------------------

func _spawn(kind: String, pos: Vector3, count: int, natural: bool) -> Array:
	var made := []
	if not KINDS.has(kind):
		return made
	var k: Dictionary = KINDS[kind]
	var n := count if count > 0 else rng.randi_range(int(k.group[0]), int(k.group[1]))
	_next_group += 1
	var g := {"gid": _next_group, "kind": kind, "members": [], "angle": rng.randf() * TAU, "mode": "roam"}
	var has_buck: bool = kind == "deer" and n >= 2 and rng.randf() < 0.7
	for i in n:
		var model: String = k.models[0]
		if kind == "deer":
			model = "buck" if has_buck and i == n - 1 else "doe"
		if _slots_used(model) >= int(SLOTS[model]):
			continue
		var off := Vector2.ZERO
		if i > 0 and float(k.spread) > 0.0:
			off = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(1.5, float(k.spread))
		var p := Vector2(pos.x + off.x, pos.z + off.y)
		if i > 0 and _blocked(p):
			p = Vector2(pos.x, pos.z)
			off = Vector2.ZERO
		var a := _make(kind, model, Vector3(p.x, 0.0, p.y), g)
		a.offset = off if i > 0 else Vector2.ZERO
		a.natural = natural
		if i > 0 and float(k.spread) > 0.0 and a.offset == Vector2.ZERO:
			a.offset = Vector2.from_angle(rng.randf() * TAU) * 2.0
		g.members.append(a)
		animals.append(a)
		made.append(a)
	return made


func _make(kind: String, model: String, pos: Vector3, group) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var drop := Terrain.drop(pos.x, pos.z)
	pos.y = Terrain.height(pos.x, pos.z) - drop
	var a := {
		"id": _next_id, "kind": kind, "model": model, "position": pos, "alive": true, "natural": false,
		"hp": float(k.hp), "yaw": rng.randf() * TAU - PI, "speed": 0.0, "state": "idle", "timer": rng.randf_range(0.5, 5.0),
		"target": Vector2.ZERO, "group": group, "offset": Vector2.ZERO, "go": Vector2.ZERO, "pace": 0.0,
		"look": Vector2.ZERO, "flee_dir": Vector2.RIGHT, "zig": 0.0, "detour": Vector2.ZERO, "detour_t": 0.0,
		"look_t": rng.randf() * 0.15, "drop": drop, "drop_t": rng.randf() * 0.5,
		"amp": 0.0, "phase": rng.randf(), "head": 0.0, "tail": 0.0, "size": rng.randf_range(0.94, 1.06),
		"cool": 0.0, "threat_t": 0.0, "dead_t": 0.0, "roll": 0.0, "side": 1.0, "slide": Vector2.ZERO,
	}
	_next_id += 1
	a.state = "graze" if rng.randf() < float(k.graze) else "idle"
	return a


func _slots_used(model: String) -> int:
	var n := 0
	for a in animals:
		if a.model == model:
			n += 1
	return n


func _populate(focus: Vector3, initial: bool) -> void:
	if atmosphere.weather == "storm":
		return
	var hour: float = atmosphere.hour
	var cap := max_alive()
	var live := alive_count()
	var tries := 0
	while tries < (28 if initial else 4) and live < cap:
		tries += 1
		var kind := _pick_kind(hour, cap - live)
		if kind == "":
			break
		var ang := rng.randf() * TAU
		var d := rng.randf_range(START_CLEAR, RADIUS) if initial else rng.randf_range(NEAR, RADIUS)
		var c := focus + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
		var p := Vector2(c.x, c.z)
		if not habitat_at(p) or not _clear(p, 8.0):
			continue
		if kind == "lion" and not _deep(p):
			continue
		var k: Dictionary = KINDS[kind]
		var n := mini(rng.randi_range(int(k.group[0]), int(k.group[1])), mini(cap - live, int(k.cap) - alive_count(kind)))
		var group := _spawn(kind, Vector3(c.x, 0.0, c.z), maxi(n, 1), true)
		live += group.size()
		if not initial and not group.is_empty():
			break


## A kind that is out at `hour`, below its cap and with room for a group.
func _pick_kind(hour: float, room: int) -> String:
	var total := 0.0
	var pool := {}
	for kind in KINDS:
		var k: Dictionary = KINDS[kind]
		if not is_active(kind, hour) or alive_count(kind) >= int(k.cap) or room < int(k.group[0]):
			continue
		var w: float = k.weight
		if kind == "lion":
			w = 0.7 if rng.randf() < 0.4 else 0.0
		pool[kind] = w
		total += w
	if total <= 0.0:
		return ""
	var roll := rng.randf() * total
	for kind in pool:
		roll -= pool[kind]
		if roll <= 0.0:
			return kind
	return ""


## Animals that have gone out of hours walk off (and vanish once out of sight).
func _retire(focus: Vector3, hour: float) -> void:
	for a in animals:
		if a.alive and a.natural and a.state != "leave" and not is_active(a.kind, hour):
			a.state = "leave"
			var p: Vector3 = a.position
			var away := Vector2(p.x - focus.x, p.z - focus.z)
			a.flee_dir = away.normalized() if away.length() > 1.0 else Vector2.from_angle(rng.randf() * TAU)


func _reap(focus: Vector3) -> void:
	for i in range(animals.size() - 1, -1, -1):
		var a: Dictionary = animals[i]
		var p: Vector3 = a.position
		var d := Vector2(p.x - focus.x, p.z - focus.z).length()
		var gone: bool = d > DESPAWN
		if a.alive and a.state == "leave" and d > 70.0:
			gone = true
		if not a.alive and a.dead_t >= CARCASS_TIME:
			gone = true
		if gone:
			_remove(i)


func _remove(i: int) -> void:
	var a: Dictionary = animals[i]
	var g = a.group
	if g != null:
		(g.members as Array).erase(a)
	a.group = null
	animals.remove_at(i)


# --- Ground ----------------------------------------------------------------------

## The Fx autoload, looked up by name: fx.gd preloads this script (for
## startle), so naming `Fx` here would make the two scripts depend on each other.
func _fx() -> Node:
	return get_node_or_null("/root/Fx") if is_inside_tree() else null


func _country():
	var city = _city()
	return city.get("country") if city != null else null


func _city():
	var g = _game_node()
	return g.get("city") if g != null else null


func _game_node() -> Node:
	if _game == null or not is_instance_valid(_game):
		_game = get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	return _game


func _quality() -> String:
	var g = _game_node()
	var gfx = g.get("graphics") if g != null else null
	var q = gfx.get("quality") if gfx != null else null
	return String(q) if q != null else "high"


func _focus() -> Vector3:
	var focus = atmosphere.get("focus")
	if focus is Node3D and is_instance_valid(focus) and focus.is_inside_tree():
		return focus.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


## The suburb polygons of the habitat, the lots and plots in cells, and the
## streams in cells, built once per country.
func _ensure_caches() -> void:
	var country = _country()
	if country == _cache_for:
		return
	_cache_for = country
	_habitat = []
	_lot_cells = {}
	_stream_cells = {}
	_city_cells = {}
	if country == null:
		return
	for s in country.suburbs:
		if not HABITAT_ZONES.has(s.zone):
			continue
		var poly := PackedVector2Array()
		for q in s.poly:
			poly.append(Vector2(q[0], q[1]))
		var rect := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			rect = rect.expand(q)
		_habitat.append({"poly": poly, "rect": rect})
	for rows in [country.lots, country.plots]:
		for row in rows:
			var r := 0.5 * Vector2(float(row[3]), float(row[4])).length() + 24.0
			var c := Vector2(float(row[0]), float(row[1]))
			var lo := Vector2i(floori((c.x - r) / LOT_CELL), floori((c.y - r) / LOT_CELL))
			var hi := Vector2i(floori((c.x + r) / LOT_CELL), floori((c.y + r) / LOT_CELL))
			for i in range(lo.x, hi.x + 1):
				for j in range(lo.y, hi.y + 1):
					var key := Vector2i(i, j)
					if not _lot_cells.has(key):
						_lot_cells[key] = []
					_lot_cells[key].append(row)
	for s in country.streams:
		var pts: PackedVector2Array = s.pts
		var w: float = s.w
		for k in pts.size() - 1:
			var a := pts[k]
			var b := pts[k + 1]
			var g := 0.5 * w + 6.0
			var lo := Vector2i(floori((minf(a.x, b.x) - g) / STREAM_CELL), floori((minf(a.y, b.y) - g) / STREAM_CELL))
			var hi := Vector2i(floori((maxf(a.x, b.x) + g) / STREAM_CELL), floori((maxf(a.y, b.y) + g) / STREAM_CELL))
			for i in range(lo.x, hi.x + 1):
				for j in range(lo.y, hi.y + 1):
					var key := Vector2i(i, j)
					if not _stream_cells.has(key):
						_stream_cells[key] = []
					_stream_cells[key].append([a, b, 0.5 * w])


## Whether p is inside a lot or plot, `margin` m outside its edge included.
func _in_lot(p: Vector2, margin: float) -> bool:
	for row in _lot_cells.get(Vector2i(floori(p.x / LOT_CELL), floori(p.y / LOT_CELL)), []):
		var d := (p - Vector2(float(row[0]), float(row[1]))).rotated(float(row[2]))
		if absf(d.x) <= float(row[3]) * 0.5 + margin and absf(d.y) <= float(row[4]) * 0.5 + margin:
			return true
	return false


## Whether a lot or plot has its centre within `r` (up to 90 m) of p.
func _lot_within(p: Vector2, r: float) -> bool:
	var cx := floori(p.x / LOT_CELL)
	var cy := floori(p.y / LOT_CELL)
	for i in range(cx - 2, cx + 3):
		for j in range(cy - 2, cy + 3):
			for row in _lot_cells.get(Vector2i(i, j), []):
				if Vector2(float(row[0]) - p.x, float(row[1]) - p.y).length() < r:
					return true
	return false


func _near_stream(p: Vector2, room: float) -> bool:
	for seg in _stream_cells.get(Vector2i(floori(p.x / STREAM_CELL), floori(p.y / STREAM_CELL)), []):
		if Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1]).distance_to(p) < float(seg[2]) + room:
			return true
	return false


## Where an animal cannot stand: off the ground, on a shore or a cliff, in a
## lake, a stream, a lot or the city.
func _blocked(p: Vector2) -> bool:
	if not Terrain.bounds.has_point(p) or Terrain.height(p.x, p.y) < SHORE_HEIGHT:
		return true
	if Terrain.normal(p.x, p.y).y < CLIFF:
		return true
	_ensure_caches()
	var country = _cache_for
	if country != null and not country.lake_at(p, 3.0).is_empty():
		return true
	if _near_stream(p, 2.5) or _in_lot(p, 3.0):
		return true
	var cell := Vector2i(floori(p.x / CITY_CELL), floori(p.y / CITY_CELL))
	if not _city_cells.has(cell):
		var city = _city()
		_city_cells[cell] = city != null and city.plan != null \
			and city.plan.in_city((Vector2(cell) + Vector2(0.5, 0.5)) * CITY_CELL)
	return _city_cells[cell]


## Open ground to start or settle on: not blocked and off the roads.
func _clear(p: Vector2, road_gap: float) -> bool:
	if _blocked(p):
		return false
	var country = _cache_for
	return country == null or country.road_distance(p, 30.0) > road_gap


## Deep forest for a lion: well up, far from roads and from any lot.
func _deep(p: Vector2) -> bool:
	if Terrain.height(p.x, p.y) < 25.0:
		return false
	var country = _cache_for
	if country != null and country.road_distance(p, 60.0) < 50.0:
		return false
	return not _lot_within(p, 90.0)


# --- Threats ----------------------------------------------------------------------

func _update_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_on_foot = false
	_pspeed = 0.0
	if _player == null or not _player.is_inside_tree():
		return
	_on_foot = _player.get("vehicle") == null and _player.get("dead") != true
	_ppos = _player.global_position
	var vel = _player.get("velocity")
	if vel is Vector3:
		_pspeed = Vector2(vel.x, vel.z).length()


## Moving cars and the person on foot against every animal, four or five
## times a second.
func _check_threats() -> void:
	_cars.clear()
	if animals.is_empty():
		return
	for car in get_tree().get_nodes_in_group("vehicles"):
		var v = car.get("speed")
		if car is Node3D and v is float and absf(v) > 1.5:
			_cars.append(car)
	var stealth := 1.0
	if _pspeed < 0.6:
		stealth = 0.7
	elif _pspeed > 6.0:
		stealth = 1.3
	for a in animals:
		if not a.alive or (a.state == "leave" and a.kind == "lion"):
			continue
		var k: Dictionary = KINDS[a.kind]
		var p: Vector3 = a.position
		var threat := Vector3.INF
		if _on_foot and float(k.flee) > 0.0:
			if Vector2(_ppos.x - p.x, _ppos.z - p.z).length() < float(k.flee) * stealth:
				threat = _ppos
		if threat == Vector3.INF:
			for car in _cars:
				var cp: Vector3 = car.global_position
				if absf(cp.y - p.y) > 6.0:
					continue
				if Vector2(cp.x - p.x, cp.z - p.z).length() < float(k.car) + absf(float(car.speed)) * 0.5:
					threat = cp
					break
		if threat == Vector3.INF:
			continue
		if a.kind == "lion":
			if a.state != "retreat" and a.state != "charge":
				_retreat(a, threat, 0.0)
		elif a.state != "flee":
			_flee_group(a, threat)
		else:
			a.timer = maxf(a.timer, 1.2)
			var away := Vector2(p.x - threat.x, p.z - threat.z)
			if away.length() > 0.1:
				a.flee_dir = away.normalized()
	# Packs circle a person on foot who comes near.
	var seen := {}
	for a in animals:
		if not a.alive or a.kind != "coyote" or a.group == null or seen.has(a.group.gid):
			continue
		seen[a.group.gid] = true
		var p: Vector3 = a.position
		var d := Vector2(_ppos.x - p.x, _ppos.z - p.z).length()
		if _on_foot and d < CIRCLE_ENTER:
			a.group.mode = "circle"
		elif not _on_foot or d > CIRCLE_EXIT:
			a.group.mode = "roam"


## `a` and its herd bolt from `from`.
func _flee_group(a: Dictionary, from: Vector3) -> void:
	_flee(a, from)
	if a.group != null:
		for m in a.group.members:
			if m.alive and m != a and m.state != "flee":
				_flee(m, from)


func _flee(a: Dictionary, from: Vector3) -> void:
	if not a.alive:
		return
	if a.kind == "lion":
		_retreat(a, from, 0.0)
		return
	var k: Dictionary = KINDS[a.kind]
	var p: Vector3 = a.position
	var away := Vector2(p.x - from.x, p.z - from.z)
	if away.length() < 0.1:
		away = Vector2.from_angle(rng.randf() * TAU)
	a.flee_dir = away.normalized().rotated(rng.randf_range(-0.35, 0.35))
	a.state = "flee"
	a.timer = rng.randf_range(3.5, 6.0) if a.kind != "rabbit" else rng.randf_range(2.5, 4.0)
	a.zig = rng.randf_range(0.2, 0.5)
	a.detour_t = 0.0
	a.look_t = 0.0


func _retreat(a: Dictionary, from: Vector3, cool: float) -> void:
	var p: Vector3 = a.position
	var away := Vector2(p.x - from.x, p.z - from.z)
	if away.length() < 0.1:
		away = Vector2.from_angle(rng.randf() * TAU)
	a.flee_dir = away.normalized().rotated(rng.randf_range(-0.3, 0.3))
	a.state = "retreat"
	a.timer = 5.0
	a.cool = maxf(a.cool, cool)
	a.threat_t = 0.0
	a.detour_t = 0.0


## A new punch by the player lands on whatever is in front of it.
func _punches() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var t = _player.get("punch_timer")
	if not t is float:
		return
	var swung: bool = t > _punch_prev + 0.01 and _on_foot
	_punch_prev = t
	if not swung:
		return
	var fwd := -_player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var dmg = _player.get("punch_damage")
	for a in animals:
		if not a.alive:
			continue
		var to: Vector3 = a.position - _ppos
		to.y = 0.0
		if to.length() < 1.9 and (to.length() < 0.4 or fwd.dot(to.normalized()) > 0.2):
			hurt(a, float(dmg) if dmg is float else 12.0, fwd, "player")
			return


## A moving car that overlaps an animal kills it; the animal is flung along
## with the car and a deer jolts it.
func _car_kills(delta: float) -> void:
	for car in _cars:
		if not is_instance_valid(car) or not car.is_inside_tree():
			continue
		var speed: float = car.speed
		if absf(speed) < CAR_KILL_SPEED:
			continue
		var cp: Vector3 = car.global_position
		var fwd: Vector3 = -car.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var size: Vector3 = car._size
		var half_len := size.z * 0.5 + absf(speed) * delta
		var half_wid := size.x * 0.5
		for a in animals:
			if not a.alive:
				continue
			var rel: Vector3 = a.position - cp
			if absf(rel.y) > 2.0 or rel.x * rel.x + rel.z * rel.z > (half_len + 3.0) * (half_len + 3.0):
				continue
			var spec: Dictionary = _specs[a.model]
			var r: float = float(spec.radius)
			if absf(rel.dot(right)) < half_wid + r and absf(rel.dot(fwd)) < half_len + r:
				var vdir: Vector3 = fwd * signf(speed)
				kill(a, vdir * minf(absf(speed) * 0.35, 6.0), "car")
				if a.kind != "rabbit":
					var big: bool = a.kind == "deer"
					car.bump(-vdir * (1.4 if big else 0.6), a.position + Vector3(0.0, 0.6, 0.0))


# --- Behaviour --------------------------------------------------------------------

func _step(a: Dictionary, delta: float) -> void:
	if not a.alive:
		_step_dead(a, delta)
		return
	a.look_t -= delta
	a.drop_t -= delta
	if a.drop_t <= 0.0:
		a.drop_t = 0.5
		var p: Vector3 = a.position
		a.drop = Terrain.drop(p.x, p.z)
	a.go = Vector2.ZERO
	a.pace = 0.0
	a.look = Vector2.ZERO
	var k: Dictionary = KINDS[a.kind]
	match a.kind:
		"lion":
			_step_lion(a, k, delta)
		"coyote":
			_step_coyote(a, k, delta)
		_:
			_step_prey(a, k, delta)
	_locomote(a, k, delta)
	_gait(a, k, delta)


func _step_prey(a: Dictionary, k: Dictionary, delta: float) -> void:
	match a.state:
		"flee":
			_flee_step(a, k, delta)
		"alert":
			_alert_step(a, delta)
		"leave":
			_leave_step(a, k)
		_:
			_wander_step(a, k, delta)


func _step_coyote(a: Dictionary, k: Dictionary, delta: float) -> void:
	match a.state:
		"flee":
			_flee_step(a, k, delta)
		"alert":
			_alert_step(a, delta)
		"leave":
			_leave_step(a, k)
		_:
			var g = a.group
			if g != null and g.mode == "circle":
				_circle_step(a, g, k)
			else:
				if a.state == "circle":
					_rest(a, k)
				_wander_step(a, k, delta)


func _step_lion(a: Dictionary, k: Dictionary, delta: float) -> void:
	a.cool = maxf(0.0, a.cool - delta)
	var p: Vector3 = a.position
	var to := Vector2(_ppos.x - p.x, _ppos.z - p.z)
	var d := to.length() if _player != null else INF
	var dir := to / maxf(d, 0.01) if d < INF else Vector2.ZERO
	var hunting: bool = _on_foot and a.cool <= 0.0 and is_active("lion", atmosphere.hour)
	match a.state:
		"charge":
			a.timer -= delta
			if not _on_foot or a.timer <= 0.0:
				_retreat(a, _ppos, 30.0)
				return
			a.go = dir
			a.pace = float(k.run)
			if d < STRIKE_RANGE and absf(_ppos.y - p.y) < 2.5:
				_strike(a, dir)
		"stalk":
			if not hunting or d > 80.0:
				a.state = "idle"
				a.timer = rng.randf_range(2.0, 5.0)
				a.threat_t = 0.0
				return
			a.look = dir
			if d > LION_CLOSE:
				a.go = dir
				a.pace = float(k.stalk)
			if d <= LION_ZONE:
				a.threat_t += delta
			else:
				a.threat_t = maxf(0.0, a.threat_t - 0.5 * delta)
			if a.threat_t >= ATTACK_AFTER:
				a.state = "charge"
				a.timer = 6.0
				_warn("The mountain lion charges: run or shoot!")
		"retreat":
			a.timer -= delta
			a.go = a.flee_dir
			a.pace = float(k.run)
			if a.timer <= 0.0:
				# A lion that has struck once walks off for good.
				a.state = "leave" if a.get("spent", false) else "idle"
				a.timer = rng.randf_range(4.0, 8.0)
		"alert":
			_alert_step(a, delta)
		"leave":
			_leave_step(a, k)
		_:
			if hunting and d < 55.0 and not a.get("spent", false):
				a.state = "stalk"
				a.threat_t = 0.0
				if not a.get("warned", false):
					a.warned = true
					_warn("Something is stalking you in the trees")
				return
			_wander_step(a, k, delta)


## The lion's one strike: the player's own take_hit, a knockdown at 25.
func _strike(a: Dictionary, dir: Vector2) -> void:
	var push := Vector3(dir.x, 0.0, dir.y) * 2.0
	if _player != null and _player.has_method("take_hit"):
		_player.take_hit(null, LION_DAMAGE, push, true)
	GameLog.event("animal_attack", {"kind": "lion", "damage": LION_DAMAGE})
	_retreat(a, _ppos, 45.0)
	a.spent = true


## A warning on the HUD (a lion stalking or charging), each text at most
## every 8 s.
signal warned(text: String)
var _warn_at := {}


func _warn(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_warn_at.get(text, -1e9)) < 8.0:
		return
	_warn_at[text] = now
	warned.emit(text)
	var g = _game_node()
	var hud = g.get("hud") if g != null else null
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text)


func _flee_step(a: Dictionary, k: Dictionary, delta: float) -> void:
	a.timer -= delta
	if a.kind == "rabbit":
		a.zig -= delta
		if a.zig <= 0.0:
			a.zig = rng.randf_range(0.35, 0.8)
			a.flee_dir = a.flee_dir.rotated(rng.randf_range(-0.7, 0.7))
	a.go = a.flee_dir
	a.pace = float(k.run)
	if a.timer <= 0.0:
		a.state = "alert"
		a.timer = rng.randf_range(1.5, 3.5)


func _alert_step(a: Dictionary, delta: float) -> void:
	a.timer -= delta
	if a.timer <= 0.0:
		_rest(a, KINDS[a.kind])


func _leave_step(a: Dictionary, k: Dictionary) -> void:
	a.go = a.flee_dir
	a.pace = maxf(float(k.travel) * 1.3, 1.6)


func _circle_step(a: Dictionary, g: Dictionary, k: Dictionary) -> void:
	a.state = "circle"
	var members: Array = g.members
	if _leader(a) == a:
		g.angle = wrapf(g.angle + CIRCLE_RATE * get_process_delta_time(), 0.0, TAU)
	var ang: float = g.angle + TAU * float(maxi(members.find(a), 0)) / float(maxi(members.size(), 1))
	var radius := CIRCLE_R + 4.0 * sin(float(a.id) * 1.7)
	var goal := Vector2(_ppos.x, _ppos.z) + Vector2(cos(ang), sin(ang)) * radius
	var p: Vector3 = a.position
	var to := goal - Vector2(p.x, p.z)
	var d := to.length()
	if d > 1.2:
		a.go = to / d
		a.pace = clampf(d * 0.9, 1.2, float(k.trot))
	else:
		a.look = Vector2(_ppos.x - p.x, _ppos.z - p.z).normalized()


## Graze, idle and wander, the herd behind its leader.
func _wander_step(a: Dictionary, k: Dictionary, delta: float) -> void:
	var leader := _leader(a)
	var p: Vector3 = a.position
	var p2 := Vector2(p.x, p.z)
	if a.state == "walk":
		var goal: Vector2 = a.target
		var speed: float = k.travel
		if leader != a:
			var lp: Vector3 = leader.position
			goal = Vector2(lp.x, lp.z) + a.offset
			speed = minf(float(k.trot), float(k.travel) * clampf(0.7 + p2.distance_to(goal) / 5.0, 0.8, 3.5))
		var to := goal - p2
		var d := to.length()
		a.timer -= delta
		var arrived: bool = d < 1.5 and (leader == a or leader.state != "walk")
		if arrived or a.timer <= 0.0:
			_rest(a, k)
			return
		if d > 0.6:
			a.go = to / d
			a.pace = speed
		return
	# Graze or idle.
	a.timer -= delta
	var lp2 := Vector2.ZERO
	if leader != a:
		var lp: Vector3 = leader.position
		lp2 = Vector2(lp.x, lp.z)
	if leader != a and leader.state == "walk" and p2.distance_to(lp2) > 3.5:
		a.state = "walk"
		a.timer = 40.0
	elif a.timer <= 0.0:
		if leader == a and rng.randf() < float(k.walk_odds):
			var goal := _pick_target(a, k)
			if goal != Vector2.INF:
				a.state = "walk"
				a.target = goal
				a.timer = 40.0
				return
		_rest(a, k)


## A spot to wander to: ahead more often than not, on hill ground, clear of
## water, lots and roads.
func _pick_target(a: Dictionary, k: Dictionary) -> Vector2:
	var p: Vector3 = a.position
	var p2 := Vector2(p.x, p.z)
	var heading := Vector2(-sin(a.yaw), -cos(a.yaw))
	for i in 8:
		var dir := heading.rotated(rng.randf_range(-1.8, 1.8)) if i < 5 else Vector2.from_angle(rng.randf() * TAU)
		var d := rng.randf_range(float(k.hop[0]), float(k.hop[1]))
		var q := p2 + dir * d
		if habitat_at(q) and _clear(q, 6.0) and not _blocked(p2 + dir * d * 0.5):
			return q
	return Vector2.INF


func _rest(a: Dictionary, k: Dictionary) -> void:
	a.state = "graze" if rng.randf() < float(k.graze) else "idle"
	a.timer = rng.randf_range(float(k.rest[0]), float(k.rest[1]))
	if a.state == "idle":
		a.timer = minf(a.timer, float(k.rest[1]) * 0.5)


func _leader(a: Dictionary) -> Dictionary:
	var g = a.group
	if g == null:
		return a
	for m in g.members:
		if m.alive:
			return m
	return a


## Turns toward a.go (or a.look when standing), speeds up or down to a.pace,
## walks round what is in the way, and moves.
func _locomote(a: Dictionary, k: Dictionary, delta: float) -> void:
	_avoid(a, delta)
	var go: Vector2 = a.go
	var target := 0.0
	var turn_rate: float = float(k.turn)
	if a.state == "flee" or a.state == "charge" or a.state == "retreat":
		turn_rate *= 1.8
	if go != Vector2.ZERO:
		var diff := angle_difference(a.yaw, atan2(-go.x, -go.y))
		a.yaw = wrapf(a.yaw + clampf(diff, -turn_rate * delta, turn_rate * delta), -PI, PI)
		target = a.pace * (1.0 if absf(diff) < 0.9 else 0.35)
	elif a.look != Vector2.ZERO:
		var diff2 := angle_difference(a.yaw, atan2(-a.look.x, -a.look.y))
		a.yaw = wrapf(a.yaw + clampf(diff2, -turn_rate * 0.6 * delta, turn_rate * 0.6 * delta), -PI, PI)
	a.speed = move_toward(a.speed, target, (16.0 if target < a.speed else 8.0) * delta)
	var p: Vector3 = a.position
	if a.speed > 0.01:
		p.x -= sin(a.yaw) * a.speed * delta
		p.z -= cos(a.yaw) * a.speed * delta
	p.y = Terrain.height(p.x, p.z) - a.drop
	a.position = p


## Looks ahead of a.go and turns away from water, a lot or a cliff; with
## nowhere to go the animal stops.
func _avoid(a: Dictionary, delta: float) -> void:
	if a.go == Vector2.ZERO:
		return
	if a.detour_t > 0.0:
		a.detour_t -= delta
		a.go = a.detour
		if a.state == "flee" or a.state == "retreat" or a.state == "leave":
			a.flee_dir = a.detour
		return
	if a.look_t > 0.0:
		return
	a.look_t = 0.15
	var p: Vector3 = a.position
	var p2 := Vector2(p.x, p.z)
	var reach := maxf(3.0, a.speed * 1.0 + 2.0)
	if not _blocked(p2 + a.go * reach):
		return
	var sgn := 1.0 if int(a.id) % 2 == 0 else -1.0
	for ang in DETOURS:
		var nd: Vector2 = (a.go as Vector2).rotated(float(ang) * sgn)
		if not _blocked(p2 + nd * reach):
			a.detour = nd
			a.detour_t = 1.0
			a.go = nd
			if a.state == "flee" or a.state == "retreat" or a.state == "leave":
				a.flee_dir = nd
			return
	a.go = Vector2.ZERO
	a.pace = 0.0
	if a.state == "flee" or a.state == "retreat":
		a.state = "alert"
		a.timer = 2.0
	elif a.state != "stalk" and a.state != "charge" and a.state != "leave":
		a.state = "idle"
		a.timer = 2.0


## Gait phase, amp, head and tail from what the animal is doing.
func _gait(a: Dictionary, k: Dictionary, delta: float) -> void:
	var sp: float = a.speed
	var want := AMPS[0]
	if sp > 0.15:
		var walk: float = k.walk
		var trot: float = k.trot
		var run: float = k.run
		if sp < (walk + trot) * 0.5:
			want = AMPS[1]
		elif sp < (trot + run) * 0.5:
			want = AMPS[2]
		else:
			want = AMPS[3]
	a.amp = move_toward(a.amp, want, 5.0 * delta)
	if sp > 0.05:
		var st: Array = k.stride
		var amp: float = a.amp
		var stride: float = lerpf(float(st[0]), float(st[1]), clampf((amp - AMPS[1]) / (AMPS[2] - AMPS[1]), 0.0, 1.0))
		stride = lerpf(stride, float(st[2]), clampf((amp - AMPS[2]) / (AMPS[3] - AMPS[2]), 0.0, 1.0))
		a.phase = fposmod(a.phase + sp * delta / maxf(stride, 0.2), 1.0)
	var head := 0.0
	var tail := 0.0
	match a.state:
		"graze":
			head = 1.0
		"stalk":
			head = 0.6
			tail = 0.0
		"idle", "alert", "circle":
			head = -0.15
		"flee":
			head = 0.0
			tail = 1.0 if a.kind == "deer" else 0.0
		"charge":
			head = 0.2
	if a.state == "alert" and a.kind == "deer":
		tail = 0.5
	a.head = move_toward(a.head, head, 3.0 * delta)
	a.tail = move_toward(a.tail, tail, 4.0 * delta)


func _step_dead(a: Dictionary, delta: float) -> void:
	a.dead_t += delta
	a.roll = minf(1.0, a.roll + delta / 0.4)
	a.amp = 0.0
	a.head = move_toward(a.head, 0.0, 4.0 * delta)
	a.tail = 0.0
	var sl: Vector2 = a.slide
	if sl.length() > 0.05:
		var p: Vector3 = a.position
		var to := Vector2(p.x + sl.x * delta, p.z + sl.y * delta)
		if _blocked(to) or (_cache_for != null and _cache_for.road_distance(to, 10.0) < 1.5):
			a.slide = Vector2.ZERO
			return
		p.x = to.x
		p.z = to.y
		p.y = Terrain.height(p.x, p.z) - a.drop
		a.position = p
		a.slide = sl.move_toward(Vector2.ZERO, 7.0 * delta)


# --- Drawing ----------------------------------------------------------------------

func _push() -> void:
	var used := {}
	for model in AnimalKit.MODELS:
		used[model] = 0
	for a in animals:
		var model: String = a.model
		var i: int = used[model]
		var mm: MultiMesh = _mms[model]
		if i >= mm.instance_count:
			continue
		mm.set_instance_transform(i, _transform(a))
		mm.set_instance_custom_data(i, Color(a.phase, a.amp, a.head, a.tail))
		used[model] = i + 1
	var shadows := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if _low else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for model in AnimalKit.MODELS:
		var view: MultiMeshInstance3D = _views[model]
		var mm: MultiMesh = _mms[model]
		if mm.visible_instance_count != used[model]:
			mm.visible_instance_count = used[model]
		if view.visible != (used[model] > 0):
			view.visible = used[model] > 0
		if view.cast_shadow != shadows:
			view.cast_shadow = shadows


## The model's transform: heading, the slope under it, a hop or a bob, a
## carcass rolled onto its side and sinking at the end.
func _transform(a: Dictionary) -> Transform3D:
	var spec: Dictionary = _specs[a.model]
	var s: float = float(spec.scale) * float(a.size)
	var pos: Vector3 = a.position
	if not a.alive and a.dead_t > CARCASS_TIME - SINK_TIME:
		s *= clampf((CARCASS_TIME - a.dead_t) / SINK_TIME, 0.05, 1.0)
	var fx := -sin(a.yaw)
	var fz := -cos(a.yaw)
	var reach: float = float(spec.length) * 0.5 * s
	var pitch := atan2(Terrain.height(pos.x + fx * reach, pos.z + fz * reach) - Terrain.height(pos.x - fx * reach, pos.z - fz * reach), reach * 2.0)
	var base := Basis(Vector3.UP, a.yaw) * Basis(Vector3.RIGHT, pitch)
	var origin := pos
	var b := base
	if a.alive:
		var amp: float = a.amp
		if spec.hop:
			origin.y += (0.03 + 0.14 * amp) * maxf(0.0, sin(TAU * a.phase)) * smoothstep(0.05, 0.2, amp)
		else:
			origin.y += float(spec.bob) * amp * (0.5 + 0.5 * sin(2.0 * TAU * a.phase))
	else:
		var ang: float = a.side * a.roll * PI * 0.5
		b = base * Basis(Vector3.BACK, ang)
		origin += base * Vector3(float(spec.body_y) * s * sin(ang), float(spec.half_w) * s * absf(sin(ang)), 0.0)
	return Transform3D(b * Basis.from_scale(Vector3.ONE * s), origin)
