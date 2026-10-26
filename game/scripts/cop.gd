extends "res://scripts/humanoid.gd"
## Police officer on foot. While the player is wanted, chases them and makes
## an arrest after staying close for ARREST_TIME; fights back if punched.

const ARREST_RANGE := 1.5
const ARREST_TIME := 1.6

var active := true
var arrest_time := 0.0
var aggro_time := 0.0


func _init() -> void:
	shirt = Color(0.2, 0.3, 0.6)
	pants = Color(0.1, 0.12, 0.2)
	hat = Color(0.1, 0.14, 0.3)
	xray_color = Color(0.3, 0.55, 1.0, 0.6)
	run_speed = 6.0
	walk_speed = 1.8
	punch_damage = 10.0


func _think(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	if not active:
		walk(-to.normalized(), walk_speed, delta)
		return
	aggro_time -= delta
	if d > ARREST_RANGE:
		arrest_time = maxf(arrest_time - delta, 0.0)
		walk(to / d, run_speed, delta)
		return
	walk(Vector3.ZERO, 0.0, delta)
	face(to, delta)
	if aggro_time > 0.0:
		punch()
	elif player.vehicle == null and not player.dead and player.knocked_time <= 0.0:
		arrest_time += delta
		if arrest_time >= ARREST_TIME:
			arrest_time = 0.0
			get_tree().call_group("game", "on_busted")


func _on_hit(attacker) -> void:
	if attacker != null and attacker.is_in_group("player"):
		Wanted.report_crime(2)
		aggro_time = 4.0
