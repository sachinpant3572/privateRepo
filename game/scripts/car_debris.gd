extends Node3D
## A body panel torn off in a hard crash: it flies, tumbles, lands, slides
## to a stop and lies in the street for LIFE seconds. At most MAX lie about;
## a new one clears the oldest.

const Terrain = preload("res://scripts/terrain.gd")

const MAX := 12
const LIFE := 20.0
const GRAVITY := 14.0

static var _alive: Array = []
static var _materials := {}

var vel := Vector3.ZERO
var _spin := Vector3.ZERO
var _age := 0.0
var _resting := false


## Throws a panel of paint `color` from `at` with velocity `fly`; `size` 0..1
## (a door skin to a bonnet).
static func throw(parent: Node, at: Vector3, fly: Vector3, color: Color, size := 0.5):
	_alive = _alive.filter(func(d): return is_instance_valid(d))
	while _alive.size() >= MAX:
		_alive.pop_front().queue_free()
	var piece = load("res://scripts/car_debris.gd").new()
	piece.vel = fly
	var mesh := BoxMesh.new()
	var s := lerpf(0.45, 1.0, clampf(size, 0.0, 1.0))
	mesh.size = Vector3(0.9 * s, 0.04, 0.6 * s)
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.3
		mat.roughness = 0.35
		_materials[key] = mat
	mesh.material = _materials[key]
	var model := MeshInstance3D.new()
	model.mesh = mesh
	piece.add_child(model)
	parent.add_child(piece)
	piece.global_position = at
	piece._spin = Vector3(randf_range(-9, 9), randf_range(-6, 6), randf_range(-9, 9))
	_alive.append(piece)
	return piece


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFE:
		queue_free()
		return
	if _age > LIFE - 1.0:
		scale = Vector3.ONE * maxf(LIFE - _age, 0.05) # shrinks away
	if _resting:
		return
	vel.y -= GRAVITY * delta
	global_position += vel * delta
	rotation += _spin * delta
	var ground := Terrain.height(global_position.x, global_position.z) + 0.03
	if global_position.y <= ground:
		global_position.y = ground
		if absf(vel.y) > 2.0:
			# Bounces, losing most of it.
			vel = Vector3(vel.x * 0.5, -vel.y * 0.3, vel.z * 0.5)
			_spin *= 0.4
		else:
			# Slides to a stop, lying flat.
			vel = Vector3(vel.x, 0.0, vel.z).move_toward(Vector3.ZERO, 9.0 * delta)
			rotation = Vector3(0.0, rotation.y, 0.0)
			_spin = Vector3.ZERO
			if vel.length() < 0.05:
				_resting = true
