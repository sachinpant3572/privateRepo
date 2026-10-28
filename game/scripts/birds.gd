extends Node3D
## Birds by day: pigeons, crows and starlings over the city and towns, gulls
## over the beach, harbour and river, egrets and herons in the bayou, hawks
## circling over the hills and farmland; a few bats at dusk, none at night,
## fewer in rain and none in a storm. Pigeons, crows, gulls and the wading
## birds land on roofs, plazas, sand and banks, and burst up when the player
## or a moving car comes near, or on a crash or another loud event
## (Birds.startle).
##
## Cheap: one MultiMesh of at most MAX_FLOCKS * PER_FLOCK birds in one draw
## call; the blob shadows under low birds are part of the same mesh. The CPU
## moves whole flocks; each bird's place in its flock, its wing beat and its
## perched pose come from the vertex shader (per-flock uniform arrays,
## per-bird custom data).
##
## Atmosphere owns it (`atmosphere.birds`) and sets `atmosphere`; the flocks
## live within RADIUS of the camera's focus.

const Terrain = preload("res://scripts/terrain.gd")
const L = preload("res://scripts/layers.gd")

const MAX_FLOCKS := 20
const PER_FLOCK := 16
## Flocks are spawned within RADIUS of the focus (new ones past NEAR, out of
## view) and dropped past DESPAWN.
const RADIUS := 220.0
const NEAR := 150.0
const DESPAWN := 320.0
## Day birds are out from FIRST to LAST o'clock; bats from BATS_FROM to BATS_TO.
const FIRST := 5.8
const LAST := 19.3
const BATS_FROM := 18.9
const BATS_TO := 20.6
## Flocks wanted by day, in rain, and bat flocks at dusk.
const DAY_FLOCKS := 12
const RAIN_FLOCKS := 5
const BAT_FLOCKS := 3
## Seconds between checks for people and cars near perched flocks.
const POLL := 0.25
## Top of a city lot's paving above the ground (city_cells.gd KERB + 0.04).
const LOT_TOP := 0.19
## How flocks fly (the shader's `mode`).
enum { SWIRL, CIRCLE, FLUTTER }

## tint, tip (how dark the wing tips are), span (m), n (birds), alt (m above
## what is below), flap (beats a second), speed (m/s), spread (flock radius,
## m), perch ("roof": roofs, else open ground; "ground": open ground; "":
## never lands), wary (m: how close a person may come; cars 1.4 times that).
const KINDS := {
	"pigeon": {"tint": Color(0.47, 0.49, 0.55), "tip": 0.55, "span": 0.9, "n": [7, 16], "alt": [8.0, 22.0], "mode": SWIRL, "flap": 6.5, "speed": 9.0, "spread": 9.0, "perch": "roof", "wary": 6.0},
	"crow": {"tint": Color(0.07, 0.07, 0.08), "tip": 0.0, "span": 1.1, "n": [3, 7], "alt": [14.0, 32.0], "mode": SWIRL, "flap": 4.2, "speed": 9.0, "spread": 12.0, "perch": "roof", "wary": 10.0},
	"starling": {"tint": Color(0.11, 0.1, 0.12), "tip": 0.0, "span": 0.6, "n": [14, 16], "alt": [22.0, 45.0], "mode": SWIRL, "flap": 9.0, "speed": 12.0, "spread": 14.0, "perch": "", "wary": 0.0},
	"gull": {"tint": Color(0.93, 0.93, 0.92), "tip": 0.85, "span": 1.4, "n": [4, 10], "alt": [10.0, 28.0], "mode": CIRCLE, "flap": 3.0, "speed": 8.0, "spread": 16.0, "perch": "ground", "wary": 8.0},
	"egret": {"tint": Color(0.97, 0.97, 0.95), "tip": 0.0, "span": 1.5, "n": [2, 5], "alt": [6.0, 14.0], "mode": SWIRL, "flap": 2.6, "speed": 6.0, "spread": 7.0, "perch": "ground", "wary": 12.0},
	"heron": {"tint": Color(0.44, 0.49, 0.55), "tip": 0.6, "span": 1.8, "n": [1, 2], "alt": [7.0, 16.0], "mode": SWIRL, "flap": 2.2, "speed": 6.0, "spread": 5.0, "perch": "ground", "wary": 14.0},
	"hawk": {"tint": Color(0.4, 0.29, 0.19), "tip": 0.5, "span": 1.6, "n": [1, 2], "alt": [45.0, 75.0], "mode": CIRCLE, "flap": 2.4, "speed": 7.0, "spread": 22.0, "perch": "", "wary": 0.0},
	"bat": {"tint": Color(0.06, 0.05, 0.05), "tip": 0.0, "span": 0.45, "n": [4, 9], "alt": [5.0, 14.0], "mode": FLUTTER, "flap": 13.0, "speed": 3.0, "spread": 9.0, "perch": "", "wary": 0.0},
}
## Kinds by habitat, [kind, weight].
const HABITATS := {
	"city": [["pigeon", 5], ["crow", 2], ["starling", 1]],
	"harbour": [["gull", 4], ["pigeon", 2]],
	"river": [["gull", 2], ["pigeon", 1], ["egret", 1]],
	"beach": [["gull", 1]],
	"bayou": [["egret", 3], ["heron", 2], ["crow", 1]],
	"hills": [["hawk", 2], ["crow", 2], ["starling", 1]],
	"farm": [["starling", 3], ["crow", 2], ["hawk", 2]],
	"town": [["pigeon", 2], ["crow", 2], ["starling", 1]],
	"country": [["crow", 2], ["starling", 2], ["hawk", 1]],
}
## Country ground zones (country.json "zones") to habitats; the rest is "country".
const ZONE_HABITAT := {
	"shore": "beach", "sand": "beach", "beach_town": "harbour",
	"bayou": "bayou", "bayou_town": "bayou", "canal": "bayou", "canal_bank": "bayou",
	"hills": "hills", "mountain": "hills", "far_mountains": "hills",
	"farmland": "farm", "pivot_track": "farm", "pivot_green": "farm", "pivot_gold": "farm",
	"pivot_bare": "farm", "field_green_row": "farm", "field_green": "farm", "field_gold": "farm",
	"field_bare_row": "farm", "field_bare": "farm",
	"town": "town", "heights": "town", "fringe": "town", "eastside": "town",
}
## City district styles by the water.
const HARBOUR_STYLES := ["waterfront", "docks", "beach"]

const SHADER := """
shader_type spatial;
render_mode skip_vertex_transform, unshaded, cull_disabled, depth_draw_opaque, blend_mix;

global uniform float night;
global uniform vec4 sun_dir;
// Per flock: a (centre xyz, heading), b (lift 0 perched..1 flying, spread m,
// mode, wing beats a second), c (velocity x z, ground below y, perch spread m).
uniform vec4 flock_a[20];
uniform vec4 flock_b[20];
uniform vec4 flock_c[20];

varying vec3 tint;
varying float fade;
varying vec2 blob;

// Where a bird is in its flock (flock frame, m).
vec3 fly_offset(float ph, float mode, float spread, float t) {
	float h1 = fract(ph * 7.31);
	float h2 = fract(ph * 3.73);
	float h3 = fract(ph * 5.17);
	if (mode < 0.5) {
		float r = spread * (0.3 + 0.7 * h1);
		float a = ph * 6.2832 + t * (0.3 + 0.35 * h2);
		return vec3(cos(a) * r, (sin(t * 0.6 + ph * 17.0) * 0.12 + (h3 - 0.5) * 0.3) * spread, sin(a) * r * 0.55);
	} else if (mode < 1.5) {
		float r = spread * (0.55 + 0.45 * h1);
		float a = ph * 6.2832 + t * 6.0 / r;
		return vec3(cos(a) * r, (h3 - 0.5) * spread * 0.3 + sin(t * 0.3 + ph * 9.0) * 1.5, sin(a) * r);
	}
	return vec3(sin(t * 1.3 + ph * 31.0) + sin(t * 2.9 + ph * 11.0) * 0.5,
		sin(t * 1.9 + ph * 7.0) * 0.25,
		cos(t * 1.7 + ph * 23.0) + cos(t * 3.3 + ph * 5.0) * 0.5) * spread * 0.6;
}

vec3 turned(vec3 o, float yaw) {
	float c = cos(yaw);
	float s = sin(yaw);
	return vec3(o.x * c - o.z * s, o.y, o.x * s + o.z * c);
}

void vertex() {
	int f = int(INSTANCE_CUSTOM.x + 0.5);
	vec4 A = flock_a[f];
	vec4 B = flock_b[f];
	vec4 C = flock_c[f];
	float ph = INSTANCE_CUSTOM.y;
	float lift = clamp(B.x, 0.0, 1.0);
	float size = length(MODEL_MATRIX[0].xyz);
	float t = TIME;
	vec3 fly0 = turned(fly_offset(ph, B.z, B.y, t), A.w);
	vec3 fly1 = turned(fly_offset(ph, B.z, B.y, t + 0.08), A.w);
	vec3 vel = (fly1 - fly0) / 0.08 + vec3(C.x, 0.0, C.y);
	vec3 perch = turned(vec3(INSTANCE_CUSTOM.z, 0.0, INSTANCE_CUSTOM.w) * C.w, A.w);
	float out_k = smoothstep(0.0, 1.0, lift);
	vec3 off = mix(perch, fly0, out_k);
	off.y += sin(lift * 3.1416) * 2.0 + (1.0 - out_k) * 0.12 * size;
	vec3 p = A.xyz + off;
	// Heading: along the flight path, or each its own way when perched.
	vec2 path = vel.xz + vec2(0.0001, 0.0);
	vec2 own = vec2(sin(ph * 40.0), -cos(ph * 40.0));
	vec2 fw = normalize(mix(own, normalize(path), smoothstep(0.05, 0.3, lift)) + vec2(0.0, 0.0001));
	vec3 world;
	if (UV2.x > 0.5) {
		// Blob shadow on the ground below, cast along the sun; only low birds.
		float h = max(p.y - C.z, 0.0);
		vec2 sh = sun_dir.y > 0.15 ? -sun_dir.xz / sun_dir.y * h : vec2(0.0);
		sh = sh * min(1.0, 20.0 / max(length(sh), 0.001));
		fade = 0.32 * (1.0 - smoothstep(2.5, 12.0, h)) * clamp(sun_dir.w * 1.5, 0.0, 1.0);
		blob = UV * 2.0 - 1.0;
		world = vec3(p.x + sh.x + VERTEX.x * size * 0.7, C.z + 0.06, p.z + sh.y + VERTEX.z * size * 0.7);
		if (fade < 0.01) {
			world = p;
		}
		tint = vec3(0.0);
	} else {
		vec3 v = VERTEX;
		float s = UV.x;
		if (s > 0.0) {
			float side = sign(v.x);
			float ax = abs(v.x) - 0.04;
			// Wing beat (soaring kinds glide between bursts), folded when perched.
			float glide = B.z > 0.5 && B.z < 1.5 ? mix(0.12, 1.0, smoothstep(0.55, 0.75, sin(t * 0.35 + ph * 13.0))) : 1.0;
			float fold = smoothstep(0.0, 0.4, lift);
			float a = (0.75 * sin(t * B.w * 6.2832 + ph * 6.2832) * glide + 0.15) * fold * (0.8 + 0.4 * s);
			ax *= mix(0.18, 1.0, fold);
			v.x = side * (0.04 + ax * cos(a));
			v.y = ax * sin(a) + (1.0 - fold) * 0.02;
			v.z += (1.0 - fold) * 0.1 * s;
		}
		v *= size;
		world = p + vec3(-v.x * fw.y - v.z * fw.x, v.y, v.x * fw.x - v.z * fw.y);
		vec3 base = mix(COLOR.rgb, COLOR.rgb * 0.25, COLOR.a * smoothstep(0.55, 0.95, s));
		tint = base * (0.55 + 0.45 * clamp(sun_dir.w, 0.0, 1.0)) * (1.0 - 0.6 * night);
		fade = 1.0;
		blob = vec2(0.0);
	}
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	ALBEDO = tint;
	ALPHA = fade * (1.0 - smoothstep(0.35, 1.0, length(blob)));
}
"""

## Every live Birds node (Birds.startle reaches them all).
static var _all: Array = []

## Atmosphere (hour, weather, focus, indoors).
var atmosphere: Node
var mm: MultiMesh
var view: MultiMeshInstance3D
var material: ShaderMaterial
## Live flocks: {kind, slot, n, pos, vel, yaw, alt, surface, ground, lift,
## state ("fly", "land", "perch", "flee", "leave"), timer, target, spread,
## perch_spread, mode, flap, age, seed, ray_t}.
var flocks: Array = []
var rng := RandomNumberGenerator.new()
var _free: Array = []
var _poll := 0.0
var _spawn_wait := 0.0
var _last_hour := -1.0
var _last_focus := Vector3.INF
var _game: Node


## Startles every flock within `radius` of `pos` (a gunshot, a crash, an
## explosion): perched birds burst up and fly off, flying ones scatter.
## Returns how many flocks took fright.
static func startle(pos: Vector3, radius: float) -> int:
	var n := 0
	for b in _all:
		if is_instance_valid(b):
			n += b.scare(pos, radius)
	return n


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


func _ready() -> void:
	rng.randomize()
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _bird_mesh()
	mm.instance_count = MAX_FLOCKS * PER_FLOCK
	mm.visible_instance_count = 0
	for i in mm.instance_count:
		_hide_instance(i)
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	view = MultiMeshInstance3D.new()
	view.name = "Flocks"
	view.multimesh = mm
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.custom_aabb = AABB(Vector3(-1e5, -1e3, -1e5), Vector3(2e5, 4e3, 2e5))
	view.visible = false
	add_child(view)
	for s in MAX_FLOCKS:
		_free.append(MAX_FLOCKS - 1 - s)


## Indoors last frame (the view was hidden for it).
var _inside := false


func _process(delta: float) -> void:
	if atmosphere == null:
		return
	if atmosphere.indoors:
		view.visible = false
		_inside = true
		return
	if _inside:
		# Back outside: the flocks show again (they stayed where they were).
		_inside = false
		_fit_visible()
	var hour: float = atmosphere.hour
	var focus := _focus()
	var jump := _last_hour < 0.0 or absf(wrapf(hour - _last_hour, -12.0, 12.0)) > 0.5 \
		or Vector2(focus.x - _last_focus.x, focus.z - _last_focus.z).length() > NEAR
	_last_hour = hour
	_last_focus = focus
	if jump:
		refresh()
		return
	var day := is_day(hour)
	var bats := is_dusk(hour)
	var storm: bool = atmosphere.weather == "storm"
	for f in flocks:
		_step(f, delta, focus, day and not storm, bats and not storm)
	for i in range(flocks.size() - 1, -1, -1):
		if flocks[i].get("dead", false):
			_drop(i)
	_spawn_wait -= delta
	if _spawn_wait <= 0.0:
		_spawn_wait = 1.5
		_populate(focus, false)
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL
		_check_threats()
	_push()


## Clears the sky and fills it again for the hour, weather and place (a
## clock jump, a teleport, a test).
func refresh() -> void:
	for i in range(flocks.size() - 1, -1, -1):
		_drop(i)
	if atmosphere == null:
		return
	_last_hour = atmosphere.hour
	_last_focus = _focus()
	_populate(_last_focus, true)
	_push()


static func is_day(hour: float) -> bool:
	return hour >= FIRST and hour < LAST


static func is_dusk(hour: float) -> bool:
	return hour >= BATS_FROM and hour < BATS_TO


## Birds in the sky (and perched) now.
func bird_count() -> int:
	var n := 0
	for f in flocks:
		n += int(f.n)
	return n


## Starts a flock of `kind` at local `pos` (its height is found); `perched`
## sets it down on a roof or open ground near there if there is one.
## Returns the flock, or {} when every slot is taken.
func spawn(kind: String, pos: Vector3, perched := false) -> Dictionary:
	if _free.is_empty() or not KINDS.has(kind):
		return {}
	var k: Dictionary = KINDS[kind]
	var slot: int = _free.pop_back()
	var n := rng.randi_range(k.n[0], k.n[1])
	var surface := _surface(pos)
	var f := {
		"kind": kind, "slot": slot, "n": n, "pos": pos, "vel": Vector3.ZERO,
		"yaw": rng.randf() * TAU, "alt": rng.randf_range(k.alt[0], k.alt[1]),
		"surface": surface, "ground": surface, "lift": 1.0, "state": "fly",
		"timer": rng.randf_range(15.0, 45.0), "target": pos, "spread": k.spread,
		"perch_spread": clampf(n * 0.35, 1.5, 6.0), "mode": k.mode, "flap": k.flap,
		"age": 0.0, "seed": rng.randf() * 100.0, "ray_t": rng.randf() * 0.5,
		"home": Vector2(pos.x, pos.z), # where it was started (its habitat)
	}
	f.pos.y = surface + f.alt
	if perched and k.perch != "":
		var spot = _landing_spot(f, pos, 12.0)
		if spot != null:
			_set_down(f, spot)
	var tint: Color = k.tint
	for j in PER_FLOCK:
		var i := slot * PER_FLOCK + j
		if j >= n:
			_hide_instance(i)
			continue
		var shade := rng.randf_range(0.88, 1.08)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * k.span * rng.randf_range(0.9, 1.1)), Vector3.ZERO))
		var r := sqrt(rng.randf())
		var a := rng.randf() * TAU
		mm.set_instance_custom_data(i, Color(slot, rng.randf(), cos(a) * r, sin(a) * r))
		mm.set_instance_color(i, Color(tint.r * shade, tint.g * shade, tint.b * shade, k.tip))
	flocks.append(f)
	_fit_visible()
	return f


## Startles flocks within `radius` of `pos` (see Birds.startle).
func scare(pos: Vector3, radius: float) -> int:
	var n := 0
	for f in flocks:
		if f.state == "leave":
			continue
		if (f.pos as Vector3).distance_to(pos) > radius + float(f.spread):
			continue
		_take_off(f, true, pos)
		n += 1
	return n


# --- Flocks -----------------------------------------------------------------

func _step(f: Dictionary, delta: float, focus: Vector3, day: bool, bats: bool) -> void:
	f.age += delta
	var k: Dictionary = KINDS[f.kind]
	var out_of_hours: bool = not bats if f.kind == "bat" else not day
	if out_of_hours and f.state != "leave":
		f.state = "leave"
		f.timer = 30.0
		var away := Vector2(f.pos.x - focus.x, f.pos.z - focus.z)
		f.yaw = atan2(away.x, -away.y) if away.length() > 1.0 else rng.randf() * TAU
	match f.state:
		"perch":
			f.lift = move_toward(f.lift, 0.0, delta * 0.8)
			f.vel = Vector3.ZERO
			f.timer -= delta
			if f.timer <= 0.0:
				_take_off(f, false, f.pos)
		"land":
			_approach(f, k, delta)
		_:
			_fly(f, k, delta)
	var dist := Vector2(f.pos.x - focus.x, f.pos.z - focus.z).length()
	if dist > DESPAWN or (f.state == "leave" and (f.timer <= 0.0 or dist > 260.0)):
		f.dead = true


func _fly(f: Dictionary, k: Dictionary, delta: float) -> void:
	var speed: float = k.speed
	match f.state:
		"flee":
			speed *= 1.8
		"leave":
			speed *= 1.4
		_:
			if f.mode == CIRCLE:
				speed *= 0.15 # soaring birds ride one thermal, drifting
	f.yaw += sin(f.age * 0.23 + f.seed) * 0.35 * delta
	var dir := Vector3(sin(f.yaw), 0.0, -cos(f.yaw))
	f.vel = dir * speed
	f.pos += f.vel * delta
	f.ray_t -= delta
	if f.ray_t <= 0.0:
		f.ray_t = 0.5
		f.surface = _surface(f.pos)
	f.ground = f.surface
	var want: float = f.surface + f.alt + (10.0 if f.state == "flee" else 0.0) + (25.0 if f.state == "leave" else 0.0)
	f.pos.y = move_toward(f.pos.y, want, delta * (6.0 if f.state == "flee" else 2.5))
	f.lift = move_toward(f.lift, 1.0, delta * (1.6 if f.state == "flee" else 0.7))
	f.timer -= delta
	if f.state == "flee":
		if f.timer <= 0.0:
			f.state = "fly"
			f.timer = rng.randf_range(20.0, 45.0)
	elif f.state == "fly" and k.perch != "" and f.timer <= 0.0:
		var spot = _landing_spot(f, f.pos + dir * 40.0, 30.0)
		if spot != null:
			f.state = "land"
			f.target = spot
		else:
			f.timer = 8.0


func _approach(f: Dictionary, k: Dictionary, delta: float) -> void:
	var to := Vector2(f.target.x - f.pos.x, f.target.z - f.pos.z)
	var d := to.length()
	if d > 0.01:
		f.yaw = lerp_angle(f.yaw, atan2(to.x, -to.y), minf(delta * 2.0, 1.0))
		var step := minf(d, float(k.speed) * 0.8 * delta)
		f.pos.x += to.x / d * step
		f.pos.z += to.y / d * step
		f.vel = Vector3(to.x / d, 0.0, to.y / d) * (step / maxf(delta, 0.0001))
	f.ground = f.target.y
	var want: float = f.target.y + minf(d * 0.6, f.alt)
	f.pos.y = move_toward(f.pos.y, want, delta * 4.0)
	f.lift = move_toward(f.lift, clampf(d / 12.0, 0.0, 1.0), delta * 1.2)
	if d < 0.4 and absf(f.pos.y - f.target.y) < 0.3:
		_set_down(f, f.target)


func _set_down(f: Dictionary, spot: Vector3) -> void:
	f.state = "perch"
	f.target = spot
	f.pos = spot
	f.ground = spot.y
	f.surface = spot.y
	f.lift = 0.0
	f.vel = Vector3.ZERO
	f.timer = rng.randf_range(25.0, 90.0)


func _take_off(f: Dictionary, scared: bool, from: Vector3) -> void:
	if scared:
		var away := Vector2(f.pos.x - from.x, f.pos.z - from.z)
		f.yaw = (atan2(away.x, -away.y) if away.length() > 0.5 else rng.randf() * TAU) + rng.randf_range(-0.5, 0.5)
		f.state = "flee"
		f.timer = 6.0
	elif f.state == "perch":
		f.state = "fly"
		f.timer = rng.randf_range(20.0, 50.0)


## People on foot and moving cars flush perched and landing flocks; a flock
## on a roof well above the street stays put.
func _check_threats() -> void:
	var threats: Array = []
	var player = get_tree().get_first_node_in_group("player")
	if player is Node3D and player.is_visible_in_tree():
		threats.append([player.global_position, 1.0])
	var landed := false
	for f in flocks:
		if f.state == "perch" or f.state == "land":
			landed = true
			break
	if not landed:
		return
	for car in get_tree().get_nodes_in_group("vehicles"):
		var v = car.get("speed")
		if car is Node3D and v is float and absf(v) > 1.5:
			threats.append([car.global_position, 1.4])
	for f in flocks:
		if f.state != "perch" and f.state != "land":
			continue
		var reach: float = float(KINDS[f.kind].wary)
		for t in threats:
			var r: float = reach * t[1] + f.perch_spread
			var p: Vector3 = t[0]
			if Vector2(p.x - f.pos.x, p.z - f.pos.z).length() < r and absf(p.y - f.pos.y) < r:
				_take_off(f, true, p)
				break


func _populate(focus: Vector3, initial: bool) -> void:
	var hour: float = atmosphere.hour
	var want := 0
	var kinds := "day"
	if atmosphere.weather != "storm":
		if is_day(hour):
			want = RAIN_FLOCKS if atmosphere.weather == "rain" else DAY_FLOCKS
		elif is_dusk(hour):
			want = BAT_FLOCKS
			kinds = "bats"
	var live := 0
	for f in flocks:
		if f.state != "leave":
			live += 1
	var tries := 0
	while live < want and not _free.is_empty() and tries < want * 3:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(20.0, RADIUS) if initial else rng.randf_range(NEAR, RADIUS)
		var p := focus + Vector3(cos(a) * d, 0.0, sin(a) * d)
		var kind := "bat" if kinds == "bats" else _pick_kind(Vector2(p.x, p.z))
		if kind == "":
			continue
		var perch: bool = initial and KINDS[kind].perch != "" and rng.randf() < 0.5
		if not spawn(kind, p, perch).is_empty():
			live += 1
		if not initial:
			break


func _pick_kind(p: Vector2) -> String:
	var list: Array = HABITATS.get(habitat_at(p), HABITATS.country)
	var hawks := 0
	for f in flocks:
		if f.kind == "hawk":
			hawks += 1
	var total := 0
	for e in list:
		if e[0] != "hawk" or hawks < 2:
			total += int(e[1])
	if total == 0:
		return ""
	var r := rng.randi_range(1, total)
	for e in list:
		if e[0] == "hawk" and hawks >= 2:
			continue
		r -= int(e[1])
		if r <= 0:
			return e[0]
	return ""


## "city", "harbour", "river", "beach", "bayou", "hills", "farm", "town" or
## "country" at a local point.
func habitat_at(p: Vector2) -> String:
	var city = _city()
	if city == null:
		return "country"
	if city.plan != null and city.plan.bounds.has_point(p):
		if city.plan.is_water_point(p):
			return "river"
		var d: Dictionary = city.district_at(Vector3(p.x, 0.0, p.y))
		return "harbour" if HARBOUR_STYLES.has(d.get("style", "")) else "city"
	var country = city.get("country")
	if country == null:
		return "country"
	var zone := _zone(country, p)
	if zone == "":
		return "beach" # open water off the coast
	return ZONE_HABITAT.get(zone, "country")


## The country ground zone at a local point ("" over water: a tile with no
## ground there, or no tile at all, which is the open sea round the map).
static func _zone(country, p: Vector2) -> String:
	var key := Vector2i(floori(p.x / country.tile_size), floori(p.y / country.tile_size))
	var tile = country.tiles.get(key)
	if tile == null:
		return ""
	for part in tile.g:
		var c: Array = part[1]
		for i in range(0, c.size() - 5, 6):
			if Geometry2D.point_is_inside_triangle(p, Vector2(c[i], c[i + 1]), Vector2(c[i + 2], c[i + 3]), Vector2(c[i + 4], c[i + 5])):
				return country.zones[int(part[0])]
	return ""


## A roof or open ground to land on near `near`: roofs first for roof
## perchers, open ground (off the roads and water) for the rest. null if
## none. The ground itself has no collider (people and cars follow
## Terrain.height), so a ray that hits nothing finds bare ground.
func _landing_spot(f: Dictionary, near: Vector3, reach: float):
	var k: Dictionary = KINDS[f.kind]
	var fallback = null
	for i in 6:
		var q := near + Vector3(rng.randf_range(-reach, reach), 0.0, rng.randf_range(-reach, reach))
		var hit := _ray(q)
		var ground := Terrain.height(q.x, q.z)
		var at := Vector3(q.x, ground, q.z)
		if not hit.is_empty() and (hit.position as Vector3).y > ground + 0.3:
			if (hit.normal as Vector3).y < 0.85:
				continue
			at = hit.position
		var roof := at.y > ground + 2.5
		if roof:
			if k.perch == "roof":
				return at
			continue
		var top := _open_ground(Vector2(q.x, q.z))
		if top < 0.0:
			continue
		at.y = maxf(at.y, ground + top)
		if k.perch == "ground":
			return at
		fallback = at
	return fallback


## How far above Terrain.height the open ground at `p` is (city lots, lawns
## and plazas are paved on the kerb), or -1 where there is none to land on
## (roads, water).
func _open_ground(p: Vector2) -> float:
	var city = _city()
	if city == null:
		return 0.0
	if city.plan != null and city.plan.bounds.has_point(p):
		if city.plan.is_water_point(p):
			return -1.0
		return LOT_TOP if _in_lot(city, p) else -1.0
	var country = city.get("country")
	return 0.0 if country == null or (_zone(country, p) != "" and country.road_distance(p, 30.0) > 6.0) else -1.0


## Inside a city block (off the streets and kerbs).
static func _in_lot(city, p: Vector2) -> bool:
	if city == null or city.plan == null or not city.plan.bounds.has_point(p):
		return false
	var face: int = city.plan.face_of(p)
	return face >= 0 and Geometry2D.is_point_in_polygon(p, city.plan.inner(face))


func _ray(q: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x, 400.0, q.z), Vector3(q.x, -30.0, q.z), L.WORLD))


## Height of whatever is below (a roof, a city lot's paving, the ground, the
## hills): low birds' shadows lie on it.
func _surface(q: Vector3) -> float:
	var ground := Terrain.height(q.x, q.z)
	if _in_lot(_city(), Vector2(q.x, q.z)):
		ground += LOT_TOP
	var hit := _ray(q)
	return maxf(ground, (hit.position as Vector3).y) if not hit.is_empty() else ground


func _focus() -> Vector3:
	var focus = atmosphere.get("focus")
	if focus is Node3D and is_instance_valid(focus) and focus.is_inside_tree():
		return focus.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


func _city():
	if _game == null or not is_instance_valid(_game):
		_game = get_tree().get_first_node_in_group("game")
	return _game.get("city") if _game != null else null


func _drop(i: int) -> void:
	var f: Dictionary = flocks[i]
	for j in PER_FLOCK:
		_hide_instance(int(f.slot) * PER_FLOCK + j)
	_free.append(f.slot)
	_free.sort()
	_free.reverse()
	flocks.remove_at(i)
	_fit_visible()


func _hide_instance(i: int) -> void:
	mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _fit_visible() -> void:
	var top := -1
	for f in flocks:
		top = maxi(top, int(f.slot))
	mm.visible_instance_count = (top + 1) * PER_FLOCK
	view.visible = top >= 0


func _push() -> void:
	if flocks.is_empty():
		return
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	var c := PackedVector4Array()
	a.resize(MAX_FLOCKS)
	b.resize(MAX_FLOCKS)
	c.resize(MAX_FLOCKS)
	for f in flocks:
		var s: int = f.slot
		a[s] = Vector4(f.pos.x, f.pos.y, f.pos.z, f.yaw)
		b[s] = Vector4(f.lift, f.spread, f.mode, f.flap * (1.6 if f.state == "flee" else 1.0))
		c[s] = Vector4(f.vel.x, f.vel.z, f.ground, f.perch_spread)
	material.set_shader_parameter("flock_a", a)
	material.set_shader_parameter("flock_b", b)
	material.set_shader_parameter("flock_c", c)


## One bird (span 1, head toward -z): body, tail and two two-part wings
## (UV.x: 0 at the body, 1 at the wing tip), and a blob shadow quad (UV2.x 1).
static func _bird_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var tris := [
		# body and tail
		[Vector3(0, 0, -0.3), Vector3(0.06, 0, -0.02), Vector3(0, 0, 0.22)],
		[Vector3(0, 0, -0.3), Vector3(0, 0, 0.22), Vector3(-0.06, 0, -0.02)],
		[Vector3(0, 0, 0.16), Vector3(-0.09, 0, 0.32), Vector3(0.09, 0, 0.32)],
	]
	for side in [1.0, -1.0]:
		var i_f := Vector3(0.04 * side, 0, -0.1)
		var i_b := Vector3(0.04 * side, 0, 0.08)
		var m_f := Vector3(0.27 * side, 0, -0.07)
		var m_b := Vector3(0.27 * side, 0, 0.1)
		var tip := Vector3(0.5 * side, 0, 0.06)
		tris.append([i_f, i_b, m_f])
		tris.append([m_f, i_b, m_b])
		tris.append([m_f, m_b, tip])
	for n in tris.size():
		for p in tris[n]:
			v.append(p)
			uv.append(Vector2(absf(p.x) / 0.5 if n >= 3 else 0.0, 0.0))
			uv2.append(Vector2.ZERO)
	var quad := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for q in quad:
		v.append(Vector3(q.x - 0.5, 0.0, q.y - 0.5))
		uv.append(q)
		uv2.append(Vector2(1.0, 0.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
