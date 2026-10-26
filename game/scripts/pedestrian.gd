extends "res://scripts/humanoid.gd"
## Civilian who strolls the sidewalks, flees when attacked and, if brave,
## fights back.

enum State { WANDER, FLEE, FIGHT }

const SHIRTS := [Color(0.95, 0.85, 0.3), Color(0.3, 0.6, 0.85), Color(0.9, 0.5, 0.2), Color(0.55, 0.8, 0.45), Color(0.95, 0.95, 0.95), Color(0.6, 0.35, 0.65)]
const PANTS := [Color(0.15, 0.15, 0.2), Color(0.35, 0.3, 0.25), Color(0.2, 0.3, 0.5), Color(0.8, 0.75, 0.65)]

var city
var state := State.WANDER
var state_time := 0.0
var threat = null
var brave := false
var loop_index := 0
var point_index := 0
var step := 1


func setup(c, rand: RandomNumberGenerator, loop: int, point: int) -> void:
	city = c
	loop_index = loop
	point_index = point
	step = 1 if rand.randf() < 0.5 else -1
	brave = rand.randf() < 0.2
	shirt = SHIRTS[rand.randi() % SHIRTS.size()]
	pants = PANTS[rand.randi() % PANTS.size()]
	skin = SKIN_TONES[rand.randi() % SKIN_TONES.size()]
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
			walk((target - global_position).normalized(), walk_speed, delta)
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
