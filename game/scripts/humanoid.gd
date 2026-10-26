extends CharacterBody3D
## Shared body for the player, pedestrians and police on foot: health,
## punches, knockdowns and a cartoon model from CharacterKit.
## Subclasses put their behaviour in _think() and react to hits in _on_hit().

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const L = preload("res://scripts/layers.gd")

signal died(who)

const PUNCH_RANGE := 1.6
const PUNCH_COOLDOWN := 0.45

var max_health := 100.0
var health := 100.0
var walk_speed := 1.6
var run_speed := 5.0
var punch_damage := 12.0
## Clothes, skin and hair; see CharacterKit.build().
var look := {}
## Silhouette colour shown through buildings; transparent means none.
var xray_color := Color(0, 0, 0, 0)

var dead := false
var dead_time := 0.0
var knocked_time := 0.0
var punch_timer := 0.0
var model: MeshInstance3D

var _punch_anim := 0.0
var _step := 0.0


func _ready() -> void:
	add_to_group("humanoids")
	motion_mode = MOTION_MODE_FLOATING
	_set_standing_layers()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	_build_model()
	health = max_health


func _physics_process(delta: float) -> void:
	punch_timer = maxf(punch_timer - delta, 0.0)
	if dead:
		dead_time += delta
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
	elif knocked_time > 0.0:
		knocked_time -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		if knocked_time <= 0.0:
			_set_standing_layers()
	else:
		_think(delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	_animate(delta)


## Behaviour hook for subclasses; called only while standing and alive.
func _think(_delta: float) -> void:
	velocity = Vector3.ZERO


## Reaction hook for subclasses.
func _on_hit(_attacker) -> void:
	pass


func forward() -> Vector3:
	return -global_basis.z


func walk(dir: Vector3, speed: float, delta: float) -> void:
	dir.y = 0.0
	velocity = dir * speed
	if dir.length_squared() > 0.01:
		face(dir, delta)


func face(dir: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(1.0, 14.0 * delta))


func punch() -> void:
	if punch_timer > 0.0:
		return
	punch_timer = PUNCH_COOLDOWN
	_punch_anim = 0.15
	var best = null
	var best_d := PUNCH_RANGE
	for other in get_tree().get_nodes_in_group("humanoids"):
		if other == self or other.dead or not other.visible:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 0.4 or forward().dot(to / d) > 0.2):
			best = other
			best_d = d
	if best:
		best.take_hit(self, punch_damage, forward())


func take_hit(attacker, damage: float, push: Vector3) -> void:
	if dead:
		return
	health -= damage
	velocity += push * 3.0
	_on_hit(attacker)
	if health <= 0.0:
		_die()
	elif damage >= 25.0:
		knock_down(1.5)


func hit_by_vehicle(vehicle, impact_speed: float) -> void:
	if dead or knocked_time > 0.0 or impact_speed < 2.5:
		return
	var away: Vector3 = global_position - vehicle.global_position
	away.y = 0.0
	velocity = away.normalized() * impact_speed * 0.6 + vehicle.velocity * 0.4
	take_hit(vehicle.driver_node(), impact_speed * 3.5, Vector3.ZERO)
	if not dead:
		knock_down(2.0)


func knock_down(seconds: float) -> void:
	knocked_time = seconds
	collision_layer = L.DOWNED
	collision_mask = L.WORLD | L.PROPS


func _die() -> void:
	dead = true
	health = 0.0
	knocked_time = 0.0
	collision_layer = L.DOWNED
	collision_mask = L.WORLD | L.PROPS
	died.emit(self)


func revive(at: Vector3) -> void:
	dead = false
	dead_time = 0.0
	knocked_time = 0.0
	health = max_health
	velocity = Vector3.ZERO
	global_position = at
	reset_physics_interpolation()
	_set_standing_layers()


func _set_standing_layers() -> void:
	collision_layer = L.CHARACTERS
	collision_mask = L.WORLD | L.PROPS | L.CHARACTERS | L.VEHICLES


func _build_model() -> void:
	var mb := MeshBuilder.new()
	CharacterKit.build(mb, look)
	model = mb.make_instance()
	add_child(model)
	set_xray(xray_color)


func set_xray(color: Color) -> void:
	xray_color = color
	model.material_override = MeshBuilder.xray_material(color) if color.a > 0.0 else MeshBuilder.material()


func _animate(delta: float) -> void:
	if dead or knocked_time > 0.0:
		model.rotation.x = lerpf(model.rotation.x, -PI / 2.0, minf(1.0, 12.0 * delta))
		model.position = Vector3(0, 0.18, 0)
		return
	model.rotation.x = lerpf(model.rotation.x, 0.0, minf(1.0, 12.0 * delta))
	var moving := Vector2(velocity.x, velocity.z).length()
	_step += delta * moving * 2.5
	_punch_anim -= delta
	var lunge := -0.3 if _punch_anim > 0.0 else 0.0
	model.position = Vector3(0, absf(sin(_step)) * 0.08 * clampf(moving, 0.0, 1.0), lunge)
