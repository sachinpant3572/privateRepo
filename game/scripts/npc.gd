extends "res://scripts/humanoid.gd"
## Mission character: story people (Nia, Celeste, Reyes...) and enemies.
## Missions set a mode and the NPC carries it out: stand (facing the player
## when they're close), walk or run to a point, follow the player, fight
## them, flee, ride a scooter or sit hidden inside a car.
## Standing idle they notice what goes on around them (Senses) but only
## react on the spot (a look, a start, a duck) so a mission never loses them.

enum Mode { IDLE, GOTO, FOLLOW, FIGHT, FLEE, RIDING, PASSENGER }

const HOSTILE_XRAY := Color(1.0, 0.3, 0.25, 0.6)
const FRIEND_XRAY := Color(0.4, 1.0, 0.55, 0.6)

var display_name := ""
var mode := Mode.IDLE
var hostile := false
var goto_point := Vector3.ZERO
var goto_run := false
var arrived := false
var vehicle = null
## Seconds between swings while fighting (on top of the punch cooldown).
var swing_pause := 0.6

var _marker: MeshInstance3D
var _marker_t := 0.0
var _swing := 0.0
var _last_pos := Vector3.ZERO
var _stuck := 0.0
var _detour := 0.0
var _detour_side := 1.0


func setup(name_: String, look_: Dictionary, hostile_ := false) -> void:
	display_name = name_
	look = look_
	hostile = hostile_
	xray_color = HOSTILE_XRAY if hostile else FRIEND_XRAY


func _ready() -> void:
	super()
	add_to_group("npcs")
	listen()


func can_perceive() -> bool:
	return super() and mode == Mode.IDLE


func _choose_reaction(kind: String, near: bool, source, data: Dictionary) -> String:
	var r := super(kind, near, source, data)
	match r:
		"ignore", "look", "startle", "duck", "dodge":
			return r
		"flee", "cower", "hands_up":
			return "duck" if Senses.danger(kind) >= 3 else "startle"
	return "look"


func walk_to(point: Vector3, run := false) -> void:
	goto_point = Vector3(point.x, 0.0, point.z)
	goto_run = run
	arrived = false
	mode = Mode.GOTO


func fight() -> void:
	hostile = true
	set_xray(HOSTILE_XRAY)
	mode = Mode.FIGHT


## A bobbing arrow over the head (mission targets).
func show_marker(color: Color) -> void:
	if _marker == null:
		var mb := MeshBuilder.new()
		mb.tri(Vector3(-0.35, 0.5, 0), Vector3(0.35, 0.5, 0), Vector3(0, 0, 0), Vector3.BACK, color)
		mb.tri(Vector3(0, 0.5, -0.35), Vector3(0, 0.5, 0.35), Vector3(0, 0, 0), Vector3.RIGHT, color)
		_marker = MeshInstance3D.new()
		_marker.mesh = mb.commit()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		_marker.material_override = mat
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
	_marker.visible = true


func hide_marker() -> void:
	if _marker:
		_marker.visible = false


## Sits on a scooter (visible) or rides inside a car (hidden).
func mount(car) -> void:
	vehicle = car
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	if car.shows_rider:
		car.rider = self
		riding = true
		mode = Mode.RIDING
	else:
		car.passengers.append(self)
		visible = false
		mode = Mode.PASSENGER


func dismount(at: Vector3) -> void:
	if vehicle != null and is_instance_valid(vehicle):
		if vehicle.rider == self:
			vehicle.rider = null
		vehicle.passengers.erase(self)
	vehicle = null
	riding = false
	visible = true
	global_position = Vector3(at.x, 0.0, at.z)
	reset_physics_interpolation()
	_set_standing_layers()
	mode = Mode.IDLE


func _physics_process(delta: float) -> void:
	if mode == Mode.RIDING or mode == Mode.PASSENGER:
		return # the vehicle carries us
	super(delta)


func _process(delta: float) -> void:
	super(delta)
	if _marker and _marker.visible:
		_marker_t += delta
		_marker.position = Vector3(0, 2.5 + sin(_marker_t * 4.0) * 0.15, 0)
		_marker.rotation.y = _marker_t * 2.0


func _think(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var to := Vector3.ZERO
	var d := INF
	if player != null:
		to = player.focus_node().global_position - global_position
		to.y = 0.0
		d = to.length()
	match mode:
		Mode.IDLE:
			velocity = Vector3.ZERO
			if not hostile and d < 7.0:
				face(to, delta)
		Mode.GOTO:
			var g := goto_point - global_position
			g.y = 0.0
			if g.length() < 0.8:
				arrived = true
				velocity = Vector3.ZERO
			else:
				_steer(g.normalized(), run_speed if goto_run else walk_speed * 1.2, delta)
		Mode.FOLLOW:
			if d > 2.6:
				_steer(to / d, run_speed if d > 6.0 else walk_speed * 1.6, delta)
			else:
				velocity = Vector3.ZERO
				face(to, delta)
		Mode.FIGHT:
			if player == null or player.dead:
				velocity = Vector3.ZERO
			elif d > 1.3:
				_steer(to / d, run_speed, delta)
			else:
				velocity = Vector3.ZERO
				face(to, delta)
				_swing -= delta
				if _swing <= 0.0 and player.vehicle == null:
					_swing = swing_pause * randf_range(0.7, 1.4)
					punch()
		Mode.FLEE:
			if d < 40.0:
				walk(-to / maxf(d, 0.01), run_speed, delta)
			else:
				velocity = Vector3.ZERO


## Walks along `dir`, stepping round lamp posts and benches: when progress
## stalls, it sidesteps for a moment.
func _steer(dir: Vector3, speed: float, delta: float) -> void:
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if _detour > 0.0:
		_detour -= delta
		var side := Vector3(-dir.z, 0, dir.x) * _detour_side
		walk((dir * 0.35 + side).normalized(), speed, delta)
		return
	_stuck = _stuck + delta if moved < speed * delta * 0.3 else 0.0
	if _stuck > 0.25:
		_stuck = 0.0
		_detour = 0.45
		_detour_side = -_detour_side
	walk(dir, speed, delta)


func _on_hit(attacker) -> void:
	if attacker != null and attacker.is_in_group("player") and hostile and mode != Mode.FIGHT:
		fight()
