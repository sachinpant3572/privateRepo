extends Node3D
## The soft top of an open car (VehicleKit kinds with "convertible") and the
## people seen in it. The top is raised or folded (set_roof, with a short
## fold); with it down, the player, mission passengers and an AI car's own
## driver (and sometimes a passenger) show in their seats (VehicleKit.SEATS).
## A child of Vehicle._model, so it rolls with the body. The tops are cached
## per kind apart from the body mesh, so a roof change never swaps the body
## (dents copy that). Seats are filled on the physics tick after the car
## and the player have moved: physics interpolation is on.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const VehicleKit = preload("res://scripts/kits/vehicle_kit.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const Rig = preload("res://scripts/rig.gd")

## Seconds to raise or fold the top.
const FOLD_TIME := 0.7
## The player works the roof only below this speed (m/s).
const ROOF_SPEED := 1.5
## Chance an AI-driven open car carries a passenger too.
const PASSENGER_CHANCE := 0.4

## "kind|up" / "kind|down" -> [fabric mesh, glass mesh or null].
static var _tops := {}

var car
## 0 with the top raised, 1 folded away.
var fold := 0.0
var _goal := 0.0
var _raised: MeshInstance3D
var _folded: MeshInstance3D
## The AI driver's and passenger's figures (built when first shown).
var _crew: Array = [null, null]
## Whether an AI driver has company (PASSENGER_CHANCE, fixed per car).
var _company := false
var _seated: Array = []


func _init(vehicle) -> void:
	car = vehicle
	name = "Convertible"
	process_physics_priority = 50
	_raised = _top(true)
	_folded = _top(false)
	_goal = 0.0 if car.roof_up else 1.0
	fold = _goal
	_apply()
	var r := RandomNumberGenerator.new()
	r.seed = hash(vehicle.get_instance_id())
	_company = r.randf() < PASSENGER_CHANCE


## Kind `kind`'s top, raised or folded: [fabric mesh, glass mesh or null],
## built once (Vehicle.prewarm builds them all at load).
static func top_meshes(kind: String, up: bool) -> Array:
	var key := "%s|%s" % [kind, "up" if up else "down"]
	if not _tops.has(key):
		var mb := MeshBuilder.new()
		var g := MeshBuilder.new()
		VehicleKit.build_top(mb, kind, up, g)
		_tops[key] = [mb.commit(), null if g.verts.is_empty() else g.commit()]
	return _tops[key]


func _top(up: bool) -> MeshInstance3D:
	var meshes := top_meshes(car.kind, up)
	var inst := MeshInstance3D.new()
	inst.mesh = meshes[0]
	if meshes[1] != null:
		var glass := MeshInstance3D.new()
		glass.mesh = meshes[1]
		inst.add_child(glass)
	add_child(inst)
	return inst


## Follows the body's materials (x-ray, wreck).
func skin(body: Material, shell: Material) -> void:
	for top in [_raised, _folded]:
		top.material_override = body
		for glass in top.get_children():
			glass.material_override = shell


func is_open() -> bool:
	return fold > 0.5


## Raises (`up`) or folds the top, over FOLD_TIME unless `animate` is false.
func set_roof(up: bool, animate := true) -> void:
	car.roof_up = up
	_goal = 0.0 if up else 1.0
	if not animate:
		fold = _goal
	_apply()


## The player's roof button: only when nearly stopped.
func can_toggle() -> bool:
	return absf(car.speed) < ROOF_SPEED and not car.wrecked


func toggle() -> bool:
	if not can_toggle():
		return false
	set_roof(not car.roof_up)
	return true


## The raised top swings up and back about its rear edge as it shrinks
## away; the folded stack grows out of the deck.
func _apply() -> void:
	var f := smoothstep(0.0, 1.0, fold)
	_raised.visible = fold < 0.999
	_folded.visible = fold > 0.001
	var p: Vector3 = VehicleKit.top_pivot(car.kind, true)
	var b := Basis(Vector3.RIGHT, f * 1.6).scaled(Vector3.ONE * (1.0 - 0.92 * f))
	_raised.transform = Transform3D(b, p - b * p)
	var q: Vector3 = VehicleKit.top_pivot(car.kind, false)
	var s := Basis.from_scale(Vector3(1.0, maxf(f, 0.01), maxf(f, 0.01)))
	_folded.transform = Transform3D(s, q - s * q)


func _physics_process(delta: float) -> void:
	if fold != _goal:
		fold = move_toward(fold, _goal, delta / FOLD_TIME)
		_apply()
	var want := _who_sits() if is_open() and not car.wrecked else []
	for p in _seated:
		if is_instance_valid(p) and not want.has(p):
			_unseat(p)
	_seated = []
	var yaw: float = car.global_rotation.y
	for i in want.size():
		var p = want[i]
		if p == null:
			continue
		_seated.append(p)
		p.global_position = global_transform * VehicleKit.seat(car.kind, i)
		p.rotation = Vector3(0, yaw, 0)
		p.visible = true
		p.sitting = true
		if p.anim != null:
			p.anim.car = 2 if i == 0 else 1
	for i in 2:
		var show: bool = i < want.size() and want[i] == null
		if show and _crew[i] == null:
			_crew[i] = _figure(i)
		if _crew[i] != null:
			_crew[i].visible = show


## Who is in each seat with the top down: the player at the wheel (or null
## for an AI car's own driver), then the mission passengers; an AI car's
## own passenger (null) takes seat 1 when nobody real sits there.
func _who_sits() -> Array:
	var out := []
	if car.occupant != null and is_instance_valid(car.occupant):
		out.append(car.occupant)
	elif car.has_ai_driver():
		out.append(null)
	else:
		return out
	for p in car.passengers:
		if is_instance_valid(p) and out.size() < VehicleKit.seat_count(car.kind):
			out.append(p)
	if out.size() == 1 and car.has_ai_driver() and _company:
		out.append(null)
	return out


## Out of the seat: the pose goes back to standing, and anyone still in
## the car (the roof went up) is hidden again.
func _unseat(p) -> void:
	p.sitting = false
	if p.anim != null:
		p.anim.car = 0
	if car.occupant == p or car.passengers.has(p):
		p.visible = false


## A seated stranger for seat `i`, posed once (they don't move).
func _figure(i: int) -> Node3D:
	var r := RandomNumberGenerator.new()
	r.seed = car.get_instance_id() * 31 + i
	var look := CharacterKit.random_look(r)
	look.erase("bag")  # in the footwell, not hanging through the seat
	var skel := CharacterKit.build_rig(look)
	skel.get_node("Body").material_override = MeshBuilder.material()
	var holder := Node3D.new()
	holder.position = VehicleKit.seat(car.kind, i)
	add_child(holder)
	holder.add_child(skel)
	var rig = Rig.new(skel)
	var st = Rig.State.new()
	st.sit = true
	st.car = 2 if i == 0 else 1
	for k in 4:
		rig.pose(st, 0.5)
	return holder
