extends CharacterBody3D
## Shared body for the player, pedestrians and police on foot: health,
## punches (and the player's punch-punch-kick combo), knockdowns, and a
## skeletal cartoon model from CharacterKit animated by Rig.
## Subclasses put their behaviour in _think() and react to hits in _on_hit().

const Terrain = preload("res://scripts/terrain.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const Rig = preload("res://scripts/rig.gd")
const L = preload("res://scripts/layers.gd")

signal died(who)
## A punch or kick connected; `kick` is true for the combo finisher.
signal landed_hit(target, kick)

const PUNCH_RANGE := 1.6
const KICK_RANGE := 1.9
const PUNCH_COOLDOWN := 0.4
const PUNCH_TIME := 0.28
const KICK_TIME := 0.45
## Bodies animate every frame near the player, every other frame further
## out, and not at all beyond ANIMATE_RANGE.
const ANIMATE_NEAR := 22.0
const ANIMATE_RANGE := 55.0

var max_health := 100.0
var health := 100.0
var walk_speed := 1.6
var run_speed := 5.0
var punch_damage := 12.0
## Clothes, skin and hair; see CharacterKit.build().
var look := {}
## Silhouette colour shown through buildings; transparent means none.
var xray_color := Color(0, 0, 0, 0)

## Third hit of a quick combo is a kick that knocks down.
var can_kick := false
## Cutscene, mission and indoor poses: phone, talk, wave, hands_up, cower,
## point, search, eat, browse, work, pay. Empty for normal movement.
var gesture := ""
## Sitting on a scooter or bike (set by the vehicle).
var riding := false
## Sitting on a chair, stool or bench (indoors).
var sitting := false

var dead := false
var dead_time := 0.0
var knocked_time := 0.0
var punch_timer := 0.0
var combat_time := 0.0
## The skeleton; its child "Body" is the skinned mesh.
var model: Skeleton3D
var body_mesh: MeshInstance3D
var rig
var anim

var _combo := 0
var _combo_time := 0.0
var _punch_t := -1.0
var _kick_t := -1.0
var _punch_left := false
var _flinch := 0.0
var _anim_skip := 0.0


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
	global_position.y = Terrain.height(global_position.x, global_position.z)


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
	_combo = _combo + 1 if _combo_time > 0.0 else 1
	_combo_time = 0.8
	combat_time = 2.5
	var kick := can_kick and _combo >= 3
	if kick:
		_combo = 0
		_kick_t = 0.0
		_punch_t = -1.0
		punch_timer = PUNCH_COOLDOWN * 1.5
	else:
		_punch_t = 0.0
		_punch_left = _combo % 2 == 0
		punch_timer = PUNCH_COOLDOWN
	var best = _melee_target(KICK_RANGE if kick else PUNCH_RANGE)
	if best == null:
		return
	best.take_hit(self, punch_damage * (2.0 if kick else 1.0), forward() * (2.2 if kick else 1.0))
	if kick and not best.dead:
		best.knock_down(1.6)
	Fx.hit(best.global_position, kick, is_in_group("player") or best.is_in_group("player"))
	landed_hit.emit(best, kick)


func _melee_target(reach: float):
	var best = null
	var best_d := reach
	for other in get_tree().get_nodes_in_group("humanoids"):
		if other == self or other.dead or not other.visible:
			continue
		var to: Vector3 = other.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d < best_d and (d < 0.4 or forward().dot(to / d) > 0.2):
			best = other
			best_d = d
	return best


func take_hit(attacker, damage: float, push: Vector3) -> void:
	if dead:
		return
	health -= damage
	velocity += push * 3.0
	_flinch = 1.0
	combat_time = 2.5
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
	model = CharacterKit.build_rig(look)
	body_mesh = model.get_node("Body")
	add_child(model)
	rig = Rig.new(model)
	anim = Rig.State.new()
	set_xray(xray_color)


func set_xray(color: Color) -> void:
	xray_color = color
	body_mesh.material_override = MeshBuilder.xray_material(color) if color.a > 0.0 else MeshBuilder.material()


## Animation runs every rendered frame (not per physics tick) so limbs stay
## smooth on 90 and 120 Hz screens.
func _process(delta: float) -> void:
	_combo_time -= delta
	combat_time -= delta
	_flinch = maxf(_flinch - delta * 4.0, 0.0)
	if _punch_t >= 0.0:
		_punch_t += delta / PUNCH_TIME
		if _punch_t > 1.0:
			_punch_t = -1.0
	if _kick_t >= 0.0:
		_kick_t += delta / KICK_TIME
		if _kick_t > 1.0:
			_kick_t = -1.0
	if not visible:
		return
	var d2 := _player_distance_squared()
	if d2 > ANIMATE_RANGE * ANIMATE_RANGE:
		return
	_anim_skip += delta
	if d2 > ANIMATE_NEAR * ANIMATE_NEAR and (Engine.get_process_frames() + get_instance_id()) % 2 == 0:
		return
	delta = _anim_skip
	_anim_skip = 0.0
	anim.speed = Vector2(velocity.x, velocity.z).length()
	anim.run_speed = run_speed
	anim.punch = _punch_t
	anim.punch_left = _punch_left
	anim.kick = _kick_t
	anim.flinch = _flinch
	anim.guard = combat_time > 0.0
	anim.down = dead or knocked_time > 0.0
	anim.ride = riding
	anim.sit = sitting
	anim.gesture = gesture
	anim.texting = look.has("phone") and combat_time <= 0.0
	rig.pose(anim, delta)


func _player_distance_squared() -> float:
	if is_in_group("player"):
		return 0.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return 0.0 if p == null else p.global_position.distance_squared_to(global_position)
