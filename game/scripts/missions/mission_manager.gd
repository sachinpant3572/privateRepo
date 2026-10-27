extends Node
## Runs the story: which missions are done (saved to disk with cash and
## unlocks), the start marker of the next mission, the active mission's
## objective and markers, and the pass / fail / retry flow.

const MISSIONS := [
	{"id": "m01_homecoming", "name": "Homecoming", "giver": "", "start": "union_station",
		"script": preload("res://scripts/missions/m01_homecoming.gd")},
	{"id": "m02_empty_rooms", "name": "Empty Rooms", "giver": "Nia Batiste", "start": "moreau_house",
		"script": preload("res://scripts/missions/m02_empty_rooms.gd")},
	{"id": "m03_lantern_lights", "name": "Lantern Lights", "giver": "Celeste Durand", "start": "blue_lantern",
		"script": preload("res://scripts/missions/m03_lantern_lights.gd")},
]
## The rest of act 1, listed in the phone but not in this demo.
const LATER := ["Wharf Rats", "Krewe Business", "Gilded Invitation", "Street Business", "Hoops",
	"Floodwater", "Magnolia", "Crescent Bridge", "Cargo", "Two Crowns"]

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.2, 0.6);

void fragment() {
	ALBEDO = color.rgb;
	ALPHA = color.a * pow(1.0 - UV.y, 1.5) * (0.8 + 0.2 * sin(TIME * 4.0));
}
"""

signal changed

## Save format: 1 had progress, cash, phone and settings; 2 adds the bag.
const SAVE_VERSION := 2

var game
var hud
var save_path := "user://solvera_save.json"
var save_enabled := true
## Completed mission ids, in order.
var done: Array = []
var phone_unlocked := false
var active = null
var objective_text := ""
var markers: Array = []
## Set by the phone and by tests: start missions automatically.
var auto_start := true

var _start_marker := {}
var _start_armed := false
var _retry_info = null
var _ring_shader: Shader


func _ready() -> void:
	_ring_shader = Shader.new()
	_ring_shader.code = RING_SHADER
	load_game()


func _physics_process(_delta: float) -> void:
	for m in markers:
		if m.has("follow") and is_instance_valid(m.follow):
			m.pos = m.follow.global_position
	if active != null:
		active.check_fail()
		return
	var next := next_mission()
	if next.is_empty():
		_clear_start_marker()
		return
	if _start_marker.get("id") != next.id:
		_clear_start_marker()
		var pos: Vector3 = game.city.landmark_front(next.start)
		_start_marker = add_marker(pos, next.name, Color(1.0, 0.78, 0.2), true)
		_start_marker["id"] = next.id
		_start_armed = false
	if not auto_start or game.respawning:
		return
	var p: Vector3 = game.player.global_position
	var m: Vector3 = _start_marker.pos
	var d := Vector2(p.x - m.x, p.z - m.z).length()
	# Armed only once the player has stepped away, so finishing one mission
	# on the next one's marker doesn't start it straight away.
	if d > 6.0:
		_start_armed = true
	if _start_armed and game.player.vehicle == null and d < 2.5:
		start(next.id)


## The first mission not yet done, or {} when the demo's story is finished.
func next_mission() -> Dictionary:
	for m in MISSIONS:
		if not done.has(m.id):
			return m
	return {}


func info(id: String) -> Dictionary:
	for m in MISSIONS:
		if m.id == id:
			return m
	return {}


func is_new_game() -> bool:
	return done.is_empty()


## Where the player wakes up: Union Station on a new game, home after.
func spawn_point() -> Vector3:
	if is_new_game():
		return game.city.spawn_point
	return game.city.landmark_front("moreau_house")


func start(id: String, teleport := false) -> void:
	if active != null:
		abandon()
	_clear_start_marker()
	set_objective("")
	var def := info(id)
	var m = def.script.new()
	m.id = id
	m.title = def.name
	m.game = game
	m.manager = self
	add_child(m)
	active = m
	if teleport:
		var p: Vector3 = m.start_point()
		game.city.stream_now(p)
		if game.player.vehicle != null:
			game.player.exit_vehicle()
		game.player.global_position = p
		game.player.reset_physics_interpolation()
		game.camera.snap()
	if m.start_hour() >= 0.0:
		game.atmosphere.hour = m.start_hour()
	changed.emit()
	_run(m)


func _run(m) -> void:
	await m.run()
	if active == m and not m.ended:
		_pass(m)


func _pass(m) -> void:
	m.ended = true
	clear_markers()
	set_objective("")
	hud.hide_dialogue()
	var sub := "+$%d" % m.reward
	if m.unlocks != "":
		sub += "   ·   Unlocked: " + m.unlocks
	hud.show_card("MISSION PASSED", m.title.to_upper() + "\n" + sub, 4.0, Color(1.0, 0.8, 0.25))
	game.cash += m.reward
	if not done.has(m.id):
		done.append(m.id)
	if m.id == "m02_empty_rooms":
		phone_unlocked = true
	_finish(m)
	save_game()
	var next := next_mission()
	if not next.is_empty():
		set_objective("Next: %s. Follow the yellow marker." % next.name)
	else:
		set_objective("That's the demo's story so far. Explore Bellerive!")


func fail(m, reason: String) -> void:
	if m != active or m.ended:
		return
	m.ended = true
	clear_markers()
	set_objective("")
	hud.hide_dialogue()
	game.player.controllable = true
	_finish(m)
	_retry_info = {"id": m.id}
	hud.show_card("MISSION FAILED", reason, 3.0, Color(1.0, 0.35, 0.3))
	await get_tree().create_timer(2.0).timeout
	while game.respawning:
		await get_tree().process_frame
	if _retry_info != null:
		hud.ask_retry(retry, func(): _retry_info = null)


func retry() -> void:
	if _retry_info == null:
		return
	var id: String = _retry_info.id
	_retry_info = null
	start(id, true)


## Stops the active mission without passing or failing (replays, tests).
func abandon() -> void:
	if active == null:
		return
	active.ended = true
	clear_markers()
	set_objective("")
	hud.hide_dialogue()
	game.player.controllable = true
	_finish(active)


func _finish(m) -> void:
	m.cleanup()
	m.queue_free()
	if active == m:
		active = null
	changed.emit()


## Called by main when the player is wasted or busted.
func on_player_down(text: String) -> void:
	if active != null:
		fail(active, text)


func set_objective(text: String) -> void:
	objective_text = text
	if hud:
		hud.set_objective(text)


# --- Markers -------------------------------------------------------------------

func add_marker(pos: Vector3, label: String, color: Color, ring: bool) -> Dictionary:
	var m := {"pos": pos, "label": label, "color": color, "gps": true}
	if ring:
		m["node"] = _make_ring(pos, color)
	markers.append(m)
	return m


func remove_marker(m: Dictionary) -> void:
	markers.erase(m)
	if m.has("node") and is_instance_valid(m.node):
		m.node.queue_free()


func clear_markers() -> void:
	for m in markers.duplicate():
		if m == _start_marker:
			continue
		remove_marker(m)


func _clear_start_marker() -> void:
	if not _start_marker.is_empty():
		remove_marker(_start_marker)
	_start_marker = {}


## A glowing column of light on the ground, the classic mission marker.
func _make_ring(pos: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	var col := CylinderMesh.new()
	col.top_radius = 1.5
	col.bottom_radius = 1.5
	col.height = 3.0
	col.cap_top = false
	col.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = _ring_shader
	mat.set_shader_parameter("color", Color(color, 0.55))
	var inst := MeshInstance3D.new()
	inst.mesh = col
	inst.material_override = mat
	inst.position.y = 1.5
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.5
	disc.bottom_radius = 1.5
	disc.height = 0.02
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.albedo_color = Color(color, 0.35)
	var dinst := MeshInstance3D.new()
	dinst.mesh = disc
	dinst.material_override = dmat
	dinst.position.y = 0.2
	dinst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(dinst)
	game.add_child(root)
	return root


# --- Saving --------------------------------------------------------------------

func save_game() -> void:
	if not save_enabled:
		return
	var data := {"version": SAVE_VERSION, "done": done, "cash": game.cash, "phone": phone_unlocked,
		"settings": game.settings, "inventory": game.inventory.to_save()}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not save_enabled or not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	done = data.get("done", [])
	game.cash = int(data.get("cash", 0))
	phone_unlocked = data.get("phone", false)
	game.settings.merge(data.get("settings", {}), true)
	# Version 1 saves (no "version") had no bag: it starts empty.
	var inv = data.get("inventory") if int(data.get("version", 1)) >= 2 else null
	game.inventory.load_save(inv if typeof(inv) == TYPE_DICTIONARY else {})


## Wipes progress (phone > Settings > New game).
func reset_progress() -> void:
	abandon()
	done.clear()
	phone_unlocked = false
	game.cash = 0
	game.inventory.bag.clear()
	save_game()
	changed.emit()
