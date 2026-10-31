extends "res://scripts/humanoid.gd"
## Police officer on foot. While the player is wanted, chases them and makes
## an arrest after staying close for ARREST_TIME; fights back if punched.
## Off duty (wanted cleared) it walks its beat away from the player, and
## trouble it sees or hears (a fight, a crash, a scream) draws it over to
## investigate: a point toward it, a brisk walk, then a word on the radio.

const ARREST_RANGE := 1.5
const ARREST_TIME := 1.6
## How close an investigating officer walks to the scene.
const SCENE_RANGE := 3.0

var active := true
var arrest_time := 0.0
var aggro_time := 0.0


func _init() -> void:
	look = {
		"outfit": "uniform", "shirt": Color(0.16, 0.24, 0.48), "pants": Color(0.1, 0.12, 0.2), "hair": "police",
		"hat": Color(0.1, 0.14, 0.3), "skin": CharacterKit.SKIN[randi() % CharacterKit.SKIN.size()],
		"build": 1.08, "shoes": Color(0.08, 0.08, 0.09),
	}
	xray_color = Color(0.3, 0.55, 1.0, 0.6)
	run_speed = 6.0
	walk_speed = 1.8
	punch_damage = 10.0
	category = "cop"
	personality = "brave"


func _ready() -> void:
	super()
	listen()


## On a chase nothing else matters; on the beat everything does.
func can_perceive() -> bool:
	return super() and not active


func _think(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not active:
		style = "patrol"
		if reaction == "investigate":
			_investigate(delta)
		elif player != null:
			var away: Vector3 = global_position - player.global_position
			away.y = 0.0
			walk(away.normalized(), walk_speed, delta)
		else:
			walk(Vector3.ZERO, 0.0, delta)
		return
	if player == null:
		return
	var to: Vector3 = player.global_position - global_position
	to.y = 0.0
	var d := to.length()
	style = ""
	if reaction != "" or pending_in() >= 0.0:
		_drop_reactions()
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
		if player.velocity.length() < 1.0:
			player.act_gesture("hands_up", 0.25) # caught: hands up until cuffed
		if arrest_time >= ARREST_TIME:
			arrest_time = 0.0
			get_tree().call_group("game", "on_busted")


func _on_hit(attacker) -> void:
	if attacker != null and attacker.is_in_group("player"):
		Wanted.report_crime(2)
		aggro_time = 4.0


func _on_reaction(_p: Dictionary) -> void:
	if reaction == "investigate":
		act_gesture("point", 0.9)


## Walks briskly to the scene, then stands looking at it on the radio.
func _investigate(delta: float) -> void:
	style = ""
	var to := reaction_pos - global_position
	to.y = 0.0
	if to.length() > SCENE_RANGE:
		walk(to.normalized(), walk_speed * 1.5, delta)
		return
	walk(Vector3.ZERO, 0.0, delta)
	face(to, delta)
	look_toward(reaction_pos, 0.5)
	if _act_gesture == "":
		act_gesture("call", reaction_time)
