extends "res://scripts/humanoid.gd"
## Civilian who strolls the sidewalks, flees when attacked and, if brave,
## fights back.

enum State { WANDER, FLEE, FIGHT }

var city
var state := State.WANDER
var state_time := 0.0
var threat = null
var brave := false
var loop_index := 0
var point_index := 0
var step := 1
## Stepping round something on the sidewalk: seconds left, which side
## (+1 into the block, -1 toward the street) and how long they have been
## held up.
var _detour := 0.0
var _detour_side := 1.0
var _stuck := 0.0


func setup(c, rand: RandomNumberGenerator, loop: int, point: int) -> void:
	city = c
	loop_index = loop
	point_index = point
	step = 1 if rand.randf() < 0.5 else -1
	brave = rand.randf() < 0.2
	look = CharacterKit.random_look(rand)
	max_health = 40.0
	walk_speed = rand.randf_range(1.3, 1.9)
	run_speed = 5.2
	punch_damage = 7.0


const HOSTILE := Color(1.0, 0.3, 0.25, 0.6)


func flee_from(who) -> void:
	threat = who
	_set_state(State.FLEE)
	state_time = 8.0


## Peds who fight the player show through buildings in red while they do.
func _set_state(value: State) -> void:
	state = value
	_detour = 0.0
	_detour_side = 1.0
	_stuck = 0.0
	set_xray(HOSTILE if state == State.FIGHT else Color(0, 0, 0, 0))


func _think(delta: float) -> void:
	state_time -= delta
	if state != State.WANDER and (state_time <= 0.0 or not is_instance_valid(threat) or threat.dead):
		_set_state(State.WANDER)
		var near: Array = city.nearest_sidewalk(global_position)
		loop_index = near[0]
		point_index = near[1]
	match state:
		State.WANDER:
			var loop: PackedVector3Array = city.sidewalk_loops[loop_index]
			var target := loop[point_index]
			if global_position.distance_to(target) < 0.8:
				point_index = posmod(point_index + step, loop.size())
				_detour_side = 1.0
			var dir := target - global_position
			dir.y = 0.0
			dir = dir.normalized()
			# Walking straight at street furniture they would stand against it
			# for good: when held up, step sideways (and a little back, out of
			# pockets) round it. They try the building side first (loops run
			# anticlockwise, so dir x UP times `step` points into the block),
			# then the street side, but never more than 0.6 m off their line
			# toward the curb, which is 1.2 m away.
			var prev := loop[posmod(point_index - step, loop.size())]
			var line := Vector3(target.x - prev.x, 0.0, target.z - prev.z).normalized()
			var off := (global_position - prev).dot(line.cross(Vector3.UP) * float(step))
			var sideways := dir.cross(Vector3.UP) * _detour_side * float(step)
			var pushing := is_on_wall() and get_real_velocity().length() < walk_speed * 0.3
			if _detour > 0.0:
				_detour -= delta
				if _detour_side < 0.0 and off < -0.6:
					_detour_side = 1.0
				elif _detour < 0.6 and is_on_wall() and get_real_velocity().dot(sideways) < walk_speed * 0.3:
					_detour_side = -_detour_side
					_detour = 0.8
				dir = (dir.cross(Vector3.UP) * _detour_side * float(step) * 1.5 - dir * 0.5).normalized()
			elif pushing:
				_stuck += delta
				if _stuck > 0.3:
					_stuck = 0.0
					_detour = 0.8
			else:
				_stuck = 0.0
			walk(dir, walk_speed, delta)
		State.FLEE:
			walk((global_position - threat.global_position).normalized(), run_speed, delta)
		State.FIGHT:
			var to: Vector3 = threat.global_position - global_position
			to.y = 0.0
			if not threat.visible:
				flee_from(threat)
			elif to.length() > 1.2:
				walk(to.normalized(), run_speed, delta)
			else:
				walk(Vector3.ZERO, 0.0, delta)
				face(to, delta)
				punch()


func _on_hit(attacker) -> void:
	if attacker == null:
		return
	if attacker.is_in_group("player"):
		Wanted.report_crime(1)
	threat = attacker
	_set_state(State.FIGHT if brave and health > 15.0 else State.FLEE)
	state_time = 8.0
