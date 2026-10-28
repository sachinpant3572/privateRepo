extends CharacterBody3D
## Shared body for the player, pedestrians and police on foot: health,
## punches (and the player's punch-punch-kick combo), knockdowns, and a
## skeletal cartoon model from CharacterKit animated by Rig.
## Subclasses put their behaviour in _think() and react to hits in _on_hit().
##
## People who call listen() also perceive the street (Senses): an event in
## range is turned into a reaction class for this person's category and
## personality, queued, and started on the first physics tick at or after
## its reaction time; the look, one-shot action or gesture starts on that
## same tick. Subclasses move the body for it in _on_reaction().

const Terrain = preload("res://scripts/terrain.gd")
const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const CharacterKit = preload("res://scripts/kits/character_kit.gd")
const Rig = preload("res://scripts/rig.gd")
const Senses = preload("res://scripts/senses.gd")
const L = preload("res://scripts/layers.gd")
const GameLog = preload("res://scripts/game_log.gd")

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
## Cutscene, mission and indoor poses (Rig.GESTURES). Empty for normal
## movement; reactions show theirs only while this is empty.
var gesture := ""
## Gait (Rig.STYLES): "" walks plainly.
var style := ""
## A gesture the body does on its own (a pause on the street); reactions
## show over it, `gesture` over both.
var activity := ""
## Sitting on a scooter or bike (set by the vehicle).
var riding := false
## Sitting on a chair, stool or bench (indoors).
var sitting := false
## Who this is to Senses.choose(): Senses.CATEGORIES, Senses.PERSONALITIES.
var category := "general"
var personality := "calm"

var dead := false
var dead_time := 0.0
var knocked_time := 0.0
var punch_timer := 0.0
var combat_time := 0.0
## Who landed the last blow before death (null for none or a vehicle).
var killer = null
## The model: Skeleton3D; its child "Body" is the skinned mesh.
var model: Skeleton3D
var body_mesh: MeshInstance3D
var rig
var anim

## The reaction playing (a Senses.HOLD key) or "", the event kind behind it,
## where it was, who caused it, its data, and seconds left.
var reaction := ""
var reaction_kind := ""
var reaction_pos := Vector3.ZERO
var reaction_source = null
var reaction_data := {}
var reaction_time := 0.0
## Physics clock (seconds): reactions are queued for a time on it, and
## reacted_at is when the current one started.
var clock := 0.0
var reacted_at := -1.0

var _combo := 0
var _combo_time := 0.0
var _punch_t := -1.0
var _kick_t := -1.0
var _punch_left := false
var _flinch := 0.0
var _anim_skip := 0.0
var _pending := {}
var _action := ""
var _action_t := -1.0
var _action_side := 1.0
var _act_gesture := ""
var _act_gesture_time := 0.0
var _look_at := Vector3.ZERO
var _look_time := 0.0
var _look_pitch := 0.0
var _look := 0.0
var _last_yaw := 0.0
var _turn := 0.0
var _last_speed := 0.0
var _accel := 0.0
var _face_down := false
var _knock_total := 0.0


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
	_last_yaw = rotation.y


func _physics_process(delta: float) -> void:
	clock += delta
	punch_timer = maxf(punch_timer - delta, 0.0)
	if dead:
		dead_time += delta
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		_drop_reactions()
	elif knocked_time > 0.0:
		knocked_time -= delta
		velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
		_drop_reactions()
		if knocked_time <= 0.0:
			_set_standing_layers()
	else:
		_update_reaction(delta)
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
		best.knock_down(1.6, forward())
	Fx.hit(best.global_position, kick, is_in_group("player") or best.is_in_group("player"))
	landed_hit.emit(best, kick)
	# Everyone around sees and hears the fight (not the two in it).
	Senses.emit(get_tree(), "fight", best.global_position, self, {"from": global_position, "victim": best})


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
	if push.length_squared() > 0.0001:
		# Struck from behind, the body goes down on its front.
		_face_down = push.dot(forward()) > 0.0
	_flinch = 1.0
	combat_time = 2.5
	_drop_reactions()
	_on_hit(attacker)
	if health <= 0.0:
		killer = attacker
		_die()
	elif damage >= 25.0:
		knock_down(1.5, push)


func hit_by_vehicle(vehicle, impact_speed: float) -> void:
	if dead or knocked_time > 0.0 or impact_speed < 2.5:
		return
	var away: Vector3 = global_position - vehicle.global_position
	away.y = 0.0
	velocity = away.normalized() * impact_speed * 0.6 + vehicle.velocity * 0.4
	_face_down = away.dot(forward()) > 0.0
	GameLog.person("hit_by_car", self, {"kmh": impact_speed * 3.6, "car": vehicle.kind, "by_player": vehicle.driver_node() != null and vehicle.driver_node().is_in_group("player")})
	take_hit(vehicle.driver_node(), impact_speed * 3.5, Vector3.ZERO)
	if not dead:
		knock_down(2.0, away)
	Senses.emit(get_tree(), "crash", global_position, self, {"loud": clampf(impact_speed / 10.0, 0.4, 1.2)})


## Down for `seconds`; the last stretch of it is spent getting up. `push`,
## when given, decides the fall: away from the facing goes onto the back,
## along it onto the front.
func knock_down(seconds: float, push := Vector3.ZERO) -> void:
	if seconds > 0.0:
		GameLog.person("knockdown", self, {"secs": seconds})
	knocked_time = seconds
	_knock_total = seconds
	if push.length_squared() > 0.0001:
		_face_down = push.dot(forward()) > 0.0
	collision_layer = L.DOWNED
	collision_mask = L.WORLD | L.PROPS


func _die() -> void:
	GameLog.person("death", self, {"killer": GameLog.name_of(killer)})
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
	killer = null
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


# --- Perception and reactions -------------------------------------------------

## Joins the "perceivers" group, so Senses.emit() reaches this person.
func listen() -> void:
	add_to_group("perceivers")


## Whether events reach this person now: standing, alive and in the world.
func can_perceive() -> bool:
	return not dead and knocked_time <= 0.0 and visible and is_inside_tree()


## Senses calls this for an event `distance` metres away. The reaction is
## chosen now and starts after Senses.delay(). A more dangerous event
## replaces a queued or playing reaction and a lesser one never does; for an
## equally dangerous one see _replaces().
func perceive(kind: String, pos: Vector3, source, distance: float, data := {}) -> void:
	if not can_perceive() or data.get("victim") == self:
		return
	var r := _choose_reaction(kind, Senses.is_near(kind, distance), source, data)
	if r == "" or r == "ignore":
		return
	var danger := Senses.danger(kind)
	if not _pending.is_empty() and not _replaces(r, danger, String(_pending.reaction), int(_pending.danger)):
		return
	if reaction != "":
		if kind == reaction_kind and source == reaction_source:
			# The same thing going on: keep reacting to it a while longer.
			reaction_time = maxf(reaction_time, float(Senses.HOLD.get(reaction, 2.0)) * 0.6)
			reaction_pos = pos
			return
		if not _replaces(r, danger, reaction, Senses.danger(reaction_kind)):
			return
	_pending = {
		"kind": kind, "reaction": r, "pos": pos, "source": source, "data": data, "danger": danger,
		"at": clock + Senses.delay(kind, distance, personality, category),
	}


## Whether reaction `r` to an event of `danger` takes over from `old` (queued
## or playing) for an event of `old_danger`. Between equally dangerous
## events only two things change what someone does: a move to get away or
## take cover (Senses.ESCAPE: a scream sends an onlooker running, but it
## does not stop a cheer to look round), and a fuller reaction taking over
## from a bare look (hearing the victim scream, then seeing the punch).
func _replaces(r: String, danger: int, old: String, old_danger: int) -> bool:
	if danger != old_danger:
		return danger > old_danger
	if r in Senses.ESCAPE:
		return old not in Senses.ESCAPE
	return old == "look" and r != "look"


## The reaction class for an event; subclasses narrow it (Senses.choose).
func _choose_reaction(kind: String, near: bool, _source, _data: Dictionary) -> String:
	return Senses.choose(category, personality, kind, near)


## Seconds until the queued reaction starts, or -1 when none is queued.
func pending_in() -> float:
	return -1.0 if _pending.is_empty() else float(_pending.at) - clock


## The queued reaction class, or "".
func pending_reaction() -> String:
	return "" if _pending.is_empty() else String(_pending.reaction)


func _update_reaction(delta: float) -> void:
	if reaction != "":
		reaction_time -= delta
		if reaction_time <= 0.0:
			_end_reaction()
	if not _pending.is_empty() and clock >= float(_pending.at) - 0.0001:
		var p := _pending
		_pending = {}
		_start_reaction(p)


func _start_reaction(p: Dictionary) -> void:
	if reaction != "":
		_end_reaction()
	reaction = p.reaction
	reaction_kind = p.kind
	reaction_pos = p.pos
	reaction_source = p.source
	reaction_data = p.data
	reaction_time = float(Senses.HOLD.get(reaction, 2.0))
	reacted_at = clock
	var from: Vector3 = p.data.get("from", p.pos)
	look_toward(from, minf(reaction_time, 3.0), -0.35 if reaction_kind == "body" else 0.0)
	var v := get_instance_id() % 2 == 0
	match reaction:
		"startle":
			play_action("startle", side_of(from))
		"dodge":
			play_action("dodge", float(p.data.get("side", -side_of(from))))
		"duck":
			play_action("duck")
		"cower":
			act_gesture("cower", reaction_time)
		"hands_up":
			act_gesture("hands_up", reaction_time)
		"film":
			act_gesture("film", reaction_time)
		"call":
			act_gesture("call", reaction_time)
		"cheer":
			act_gesture("cheer" if v else "clap", reaction_time)
		"shout":
			act_gesture("shake_fist" if v else "argue", reaction_time)
	_on_reaction(p)


func _end_reaction() -> void:
	var was := reaction
	reaction = ""
	reaction_kind = ""
	reaction_source = null
	reaction_data = {}
	reaction_time = 0.0
	_act_gesture = ""
	_act_gesture_time = 0.0
	if was != "":
		_on_reaction_end(was)


## Drops queued and playing reactions (hit, knocked down or dead).
func _drop_reactions() -> void:
	_pending = {}
	if reaction != "":
		_end_reaction()
	_action = ""
	_action_t = -1.0


## Subclass hooks: a reaction starts (move the body for it) and ends.
func _on_reaction(_p: Dictionary) -> void:
	pass


func _on_reaction_end(_was: String) -> void:
	pass


## Turns the head (and some of the chest) toward `pos` for `seconds`.
func look_toward(pos: Vector3, seconds: float, pitch := 0.0) -> void:
	_look_at = pos
	_look_time = seconds
	_look_pitch = pitch


## Plays a one-shot Rig.ACTIONS move; `side` +1 is the body's right.
func play_action(action_name: String, side := 1.0) -> void:
	if not Rig.ACTIONS.has(action_name):
		return
	_action = action_name
	_action_t = 0.0
	_action_side = 1.0 if side >= 0.0 else -1.0


## Holds a gesture for `seconds` (shown while `gesture` is empty).
func act_gesture(g: String, seconds: float) -> void:
	_act_gesture = g
	_act_gesture_time = seconds


## The gesture showing now.
func shown_gesture() -> String:
	if gesture != "":
		return gesture
	return _act_gesture if _act_gesture != "" else activity


## +1 when `pos` is on this body's right, -1 on its left.
func side_of(pos: Vector3) -> float:
	var to := pos - global_position
	return 1.0 if to.dot(global_basis.x) >= 0.0 else -1.0


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
	if _action_t >= 0.0:
		_action_t += delta / float(Rig.ACTIONS[_action])
		if _action_t > 1.0:
			_action_t = -1.0
			_action = ""
	if _act_gesture_time > 0.0:
		_act_gesture_time -= delta
		if _act_gesture_time <= 0.0:
			_act_gesture = ""
	_look_time -= delta
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
	var speed := Vector2(velocity.x, velocity.z).length()
	if delta > 0.0:
		var yaw_rate := angle_difference(_last_yaw, rotation.y) / delta
		_turn = lerpf(_turn, yaw_rate, 1.0 - exp(-8.0 * delta))
		_accel = lerpf(_accel, (speed - _last_speed) / delta, 1.0 - exp(-6.0 * delta))
	_last_yaw = rotation.y
	_last_speed = speed
	_look = move_toward(_look, 1.0 if _look_time > 0.0 else 0.0, delta * 4.0)
	var down := dead or knocked_time > 0.0
	anim.speed = speed
	anim.run_speed = run_speed
	anim.punch = _punch_t
	anim.punch_left = _punch_left
	anim.kick = _kick_t
	anim.flinch = _flinch
	anim.guard = combat_time > 0.0
	anim.down = down
	anim.dead = dead
	anim.face_down = _face_down
	anim.getup = _getup_progress()
	anim.ride = riding
	anim.sit = sitting
	anim.gesture = shown_gesture()
	anim.style = style
	anim.action = _action
	anim.action_t = _action_t
	anim.action_side = _action_side
	anim.texting = look.has("phone") and combat_time <= 0.0 and anim.gesture == ""
	anim.turn = _turn
	anim.accel = _accel
	anim.idle = reaction == ""
	anim.idle_seed = get_instance_id() % 997
	anim.look_amount = _look if not down else 0.0
	if _look > 0.0:
		var to: Vector3 = (_look_at - global_position) * global_basis
		anim.look_yaw = atan2(-to.x, -to.z)
		anim.look_pitch = _look_pitch
	rig.pose(anim, delta)


## 0..1 through getting up at the end of a knockdown, -1 otherwise. Long
## knockdowns get the full Rig.GETUP_TIME, short ones a quicker scramble;
## the fall itself always plays out first.
func _getup_progress() -> float:
	if dead or knocked_time <= 0.0:
		return -1.0
	var length := minf(clampf(_knock_total - Rig.FALL_TIME - 0.3, 0.6, Rig.GETUP_TIME), _knock_total - Rig.FALL_TIME)
	if length <= 0.0 or knocked_time >= length:
		return -1.0
	return clampf(1.0 - knocked_time / length, 0.0, 1.0)


func _player_distance_squared() -> float:
	if is_in_group("player"):
		return 0.0
	var p := get_tree().get_first_node_in_group("player") as Node3D
	return 0.0 if p == null else p.global_position.distance_squared_to(global_position)
