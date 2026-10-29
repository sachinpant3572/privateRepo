extends Node3D
## Blood (0.23; the Fx autoload's child, `Fx.bloodwork`): a spurt when
## someone is hurt, and marks on the ground: spatter from blows, smears
## where a body slid after a car hit it, and a pool that spreads under the
## dead. Settings > Game > Blood turns all of it off (and clears the marks).
##
## Cost: every mark is one instance of ONE MultiMesh, so one draw call for
## all of them; it is a ring buffer of CAP marks and the oldest goes first.
## Marks grow and fade in the shader from their own custom data, so nothing
## is written per frame but the shader's clock. Spurts come from a few
## one-shot particle emitters. Both are unshaded, so the compatibility
## renderer draws them once whatever lights are near, and darkened at night
## by the `night` global as birds are.

const Terrain = preload("res://scripts/terrain.gd")

## Marks at once (the oldest goes first).
const CAP := 200
## One-shot spurt emitters.
const SPURTS := 4
## Seconds a spatter or smear lasts, and a pool (random within).
const LIFE := Vector2(60.0, 90.0)
const POOL_LIFE := Vector2(100.0, 120.0)
## Marks start fading at this share of their life.
const FADE_FROM := 0.6
## The shader's clock starts again from zero this often (s): the renderer
## keeps per-mark data as half floats, good to a few hundredths up to a
## minute or two.
const REBASE := 60.0
## Above the surface (m), clear of the ground and the skid marks (0.03).
const LIFT := 0.035
## Tops of raised paving (m): a city block (sidewalk and lot; city_cells.gd
## KERB 0.15, lot paving up to 0.17) and the pavements beside country roads
## (country_tiles.gd KERB 0.15, SIDEWALK 2.5 m beyond the road edge).
const BLOCK_TOP := 0.17
const PAVEMENT_TOP := 0.15
const PAVEMENT_WIDTH := 2.7
## The most a single spurt counts for (see bleed() in humanoid.gd).
const MAX_AMOUNT := 2.0
## Kinds of mark (the shader draws each its own way).
enum { DROP, POOL, SMEAR }

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float night;
global uniform vec4 sun_dir;
// Seconds since blood.gd's epoch (moved every minute).
uniform float now = 0.0;
// Fresh and dried blood before the day/night shading. The ACES tonemap
// crushes dark reds: 0.45 comes out about sRGB (125, 0, 0) by day, a pool's
// darker middle about (85, 0, 0); the old 0.16 came out nearly black.
uniform vec3 fresh_color = vec3(0.45, 0.025, 0.03);
uniform vec3 dry_color = vec3(0.28, 0.03, 0.025);

varying float v_alpha;
varying float v_dry;
varying float v_kind;
varying float v_seed;

float h1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

// Custom data: start (s since the epoch), life (s), grow (s), kind + seed.
void vertex() {
	float age = now - INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	v_kind = floor(INSTANCE_CUSTOM.w);
	v_seed = clamp((INSTANCE_CUSTOM.w - v_kind - 0.05) / 0.9, 0.0, 1.0);
	v_alpha = 0.0;
	if (age < 0.0 || age > life) {
		VERTEX = vec3(0.0);
	} else {
		float grow = INSTANCE_CUSTOM.z;
		float g = grow > 0.0 ? sqrt(clamp(age / grow, 0.0, 1.0)) : 1.0;
		VERTEX.xz *= mix(0.25, 1.0, g);
		v_alpha = 1.0 - smoothstep(FADE_FROM * life, life, age);
	}
	v_dry = smoothstep(4.0, 45.0, age);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = v_seed * 6.2831;
	float m = 0.0;
	float shade = 1.0;
	if (v_kind < 0.5) {
		// Spatter: a ragged blob and a few drops thrown past it.
		float edge = 0.48 + 0.08 * sin(a * 3.0 + s) + 0.06 * sin(a * 5.0 + s * 2.3) + 0.04 * sin(a * 11.0 + s * 4.1);
		m = 1.0 - smoothstep(edge - 0.06, edge, r);
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float ang = s + fi * 1.35 + h1(v_seed * 17.0 + fi) * 1.1;
			vec2 c = vec2(cos(ang), sin(ang)) * (0.58 + 0.32 * h1(v_seed * 31.0 + fi));
			float rad = 0.04 + 0.08 * h1(v_seed * 7.0 + fi);
			m = max(m, 1.0 - smoothstep(rad - 0.03, rad, length(p - c)));
		}
		shade = 0.85 + 0.15 * smoothstep(0.0, edge, r);
	} else if (v_kind < 1.5) {
		// Pool: rounder, lobed, darkest in the middle.
		float edge = 0.84 + 0.07 * sin(a * 2.0 + s) + 0.05 * sin(a * 3.0 + s * 1.7) + 0.03 * sin(a * 7.0 + s * 3.1);
		m = 1.0 - smoothstep(edge - 0.05, edge, r);
		shade = 0.7 + 0.3 * smoothstep(0.2, edge, r);
	} else {
		// Smear: a streak along its length (y) with ragged sides, thinning
		// and breaking up towards one end, faintly streaked lengthways.
		float t = p.y * 0.5 + 0.5;
		float half_w = (0.85 - 0.4 * t) * (0.82 + 0.12 * sin(p.y * 5.0 + s) + 0.08 * sin(p.y * 13.0 + s * 3.0));
		float ends = 1.0 - smoothstep(0.62 + 0.2 * sin(p.x * 4.0 + s), 0.98, abs(p.y));
		m = (1.0 - smoothstep(half_w - 0.18, half_w, abs(p.x))) * ends;
		m *= 0.86 + 0.14 * sin(p.x * 9.0 + 2.0 * sin(p.y * 3.0 + s) + s * 5.0);
		m *= 1.0 - 0.45 * smoothstep(0.3, 1.0, t) * (0.5 + 0.5 * sin(p.y * 11.0 + p.x * 3.0 + s * 2.0));
	}
	ALBEDO = mix(fresh_color, dry_color, v_dry) * shade * (0.7 + 0.3 * clamp(sun_dir.w, 0.0, 1.0)) * (1.0 - 0.45 * night);
	ALPHA = clamp(m, 0.0, 1.0) * 0.93 * v_alpha;
}
"""

## The spurt's droplets: round, facing the camera, darkened at night.
const SPRAY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float night;
global uniform vec4 sun_dir;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	ALBEDO = COLOR.rgb * (0.7 + 0.3 * clamp(sun_dir.w, 0.0, 1.0)) * (1.0 - 0.45 * night);
	ALPHA = COLOR.a * (1.0 - smoothstep(0.45, 1.0, dot(p, p)));
}
"""

## False: no blood at all (Settings > Game > Blood).
var on := true
## Seconds of play (stops while the game is paused).
var clock := 0.0
## Spurts and marks made since the start (tests read these).
var spurts := 0
var laid := 0
var mm: MultiMesh
var emitters: Array[CPUParticles3D] = []

var _material: ShaderMaterial
var _epoch := 0.0
var _next := 0
## Slots in use: 0 .. _count - 1.
var _count := 0
## When the last mark is gone (clock s); then nothing is drawn.
var _ends := 0.0
## Each slot's custom data with the start as clock seconds (the GPU copy
## holds it relative to the epoch).
var _data := PackedColorArray()
## And its placement (the renderer keeps no copy to read back headless).
var _xforms: Array[Transform3D] = []
var _emit_next := 0
var _rng := RandomNumberGenerator.new()
var _game: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_rng.randomize()
	_data.resize(CAP)
	_xforms.resize(CAP)
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = SHADER.replace("FADE_FROM", str(FADE_FROM))
	_material.render_priority = 1
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = _material
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	var marks := MultiMeshInstance3D.new()
	marks.name = "Marks"
	marks.multimesh = mm
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)
	var spray := ShaderMaterial.new()
	spray.shader = Shader.new()
	spray.shader.code = SPRAY_SHADER
	var drop := QuadMesh.new()
	drop.size = Vector2(0.075, 0.075)
	drop.material = spray
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.55, 0.03, 0.035, 1.0))
	ramp.set_color(1, Color(0.4, 0.025, 0.03, 0.0))
	ramp.add_point(0.7, Color(0.48, 0.028, 0.032, 0.9))
	for i in SPURTS:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.local_coords = false
		p.amount = 18
		p.lifetime = 0.6
		p.explosiveness = 0.9
		p.randomness = 0.5
		p.spread = 24.0
		p.gravity = Vector3(0, -14, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.06
		p.mesh = drop
		p.color_ramp = ramp
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		emitters.append(p)


func _process(delta: float) -> void:
	clock += delta
	if _count == 0:
		return
	if clock >= _ends:
		clear()
		return
	if clock - _epoch > REBASE:
		_rebase()
	_material.set_shader_parameter(&"now", clock - _epoch)


## Blood from a wound at `pos` (world) spraying along `dir` (flattened;
## zero picks any way), and the drops it leaves on the ground ahead.
## `amount`: about 0.4 a punch, 0.8 a kick, up to MAX_AMOUNT (a hard crash).
func spurt(pos: Vector3, dir: Vector3, amount: float) -> void:
	if not on or amount <= 0.0:
		return
	amount = minf(amount, MAX_AMOUNT)
	var flat := _flat(dir)
	var p := emitters[_emit_next]
	_emit_next = (_emit_next + 1) % SPURTS
	p.global_position = pos
	p.direction = (flat + Vector3(0, 0.55, 0)).normalized()
	p.initial_velocity_min = 1.2 + 1.0 * amount
	p.initial_velocity_max = 2.4 + 1.8 * amount
	p.scale_amount_min = 0.6 + 0.2 * amount
	p.scale_amount_max = 1.2 + 0.4 * amount
	p.restart()
	spurts += 1
	var side := flat.cross(Vector3.UP)
	var yaw := atan2(flat.x, flat.z)
	var n := clampi(1 + int(amount * 2.5), 1, 5)
	var reach := 0.5 + 0.8 * amount
	for i in n:
		var d := _rng.randf_range(0.2, reach)
		var at := pos + flat * d + side * _rng.randf_range(-0.2, 0.2) * (0.5 + d)
		var size := minf((0.3 + 0.28 * amount) * _rng.randf_range(0.65, 1.15), 0.85)
		_mark(DROP, at, yaw + _rng.randf_range(-0.5, 0.5), Vector2(size, size * _rng.randf_range(1.0, 1.45)), 0.12 + d * 0.1, LIFE, 0.12)
	# What runs down to the feet.
	var drip := minf(0.24 + 0.1 * amount, 0.45)
	_mark(DROP, pos + side * _rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, Vector2(drip, drip), 0.3, LIFE, 0.3)


## A smear on the ground at `pos` along `dir` (a body sliding), `width` m.
func smear(pos: Vector3, dir: Vector3, width: float) -> void:
	if not on:
		return
	var flat := _flat(dir)
	var w := width * _rng.randf_range(0.8, 1.0)
	# Uneven lengths and a little slip along the way, so a trail of them
	# does not read as a dashed line.
	_mark(SMEAR, pos + flat * _rng.randf_range(-0.3, 0.3), atan2(flat.x, flat.z) + _rng.randf_range(-0.12, 0.12), Vector2(w, width * _rng.randf_range(1.4, 2.8)), 0.0, LIFE, 0.15)


## A pool spreading from `pos` over `grow` seconds to about `size` m across.
func pool(pos: Vector3, size: float, grow := 5.0) -> void:
	if not on:
		return
	var s := clampf(size, 0.3, 2.8) * _rng.randf_range(0.9, 1.1)
	_mark(POOL, pos, _rng.randf() * TAU, Vector2(s, s * _rng.randf_range(1.0, 1.3)), 0.0, POOL_LIFE, grow)


## Settings > Game > Blood. Off hides the spurts and clears every mark.
func set_on(value: bool) -> void:
	on = value
	visible = value
	if not value:
		clear()


## Removes every mark.
func clear() -> void:
	_count = 0
	_next = 0
	_ends = 0.0
	mm.visible_instance_count = 0


## Marks still to show or showing.
func live() -> int:
	var n := 0
	for i in _count:
		if clock < _data[i].r + _data[i].g:
			n += 1
	return n


## How opaque slot i is now (0 gone or not yet down .. 1), as the shader
## fades it (before the shape).
func alpha(i: int) -> float:
	if i < 0 or i >= _count:
		return 0.0
	var age := clock - _data[i].r
	if age < 0.0 or age > _data[i].g:
		return 0.0
	return 1.0 - smoothstep(FADE_FROM * _data[i].g, _data[i].g, age)


## Slot i's kind (DROP, POOL, SMEAR) and placement (tests).
func kind(i: int) -> int:
	return int(_data[i].a)


func mark_transform(i: int) -> Transform3D:
	return _xforms[i]


func used() -> int:
	return _count


func _mark(what: int, at: Vector3, yaw: float, size: Vector2, delay: float, life: Vector2, grow: float) -> void:
	var lift := _paving(Vector2(at.x, at.z))
	if lift < 0.0:
		return # water
	var up := Terrain.normal(at.x, at.z)
	var b := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size.x, 1.0, size.y))
	var i := _next
	_next = (_next + 1) % CAP
	_count = mini(_count + 1, CAP)
	var start := clock + delay
	var span := _rng.randf_range(life.x, life.y)
	_data[i] = Color(start, span, grow, what + 0.05 + 0.9 * _rng.randf())
	_xforms[i] = Transform3D(b, Vector3(at.x, Terrain.height(at.x, at.z) - Terrain.drop(at.x, at.z) + lift + LIFT, at.z))
	mm.set_instance_transform(i, _xforms[i])
	mm.set_instance_custom_data(i, Color(start - _epoch, span, grow, _data[i].a))
	mm.visible_instance_count = _count
	_ends = maxf(_ends, start + span)
	_material.set_shader_parameter(&"now", clock - _epoch)
	laid += 1


## Moves the epoch to now and rewrites every slot's start against it.
func _rebase() -> void:
	_epoch = clock
	for i in _count:
		var c := _data[i]
		mm.set_instance_custom_data(i, Color(maxf(c.r - _epoch, -2000.0), c.g, c.b, c.a))


## How high the paving at `p` stands above Terrain.height (m), or -1 on
## open water.
func _paving(p: Vector2) -> float:
	var city = _city()
	if city == null:
		return 0.0
	var plan = city.get("plan")
	if plan != null and plan.in_city(p):
		if plan.is_water_point(p):
			return -1.0
		var face: int = plan.face_of(p)
		return BLOCK_TOP if face >= 0 and Geometry2D.is_point_in_polygon(p, plan.inner(face)) else 0.0
	var country = city.get("country")
	if country != null:
		var d: float = country.road_distance(p, 40.0)
		if d >= 0.0 and d < PAVEMENT_WIDTH:
			return PAVEMENT_TOP
	return 0.0


func _city():
	if _game == null or not is_instance_valid(_game) or not _game.is_inside_tree():
		_game = get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	return _game.get("city") if _game != null else null


func _flat(dir: Vector3) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		var a := _rng.randf() * TAU
		return Vector3(sin(a), 0.0, cos(a))
	return flat.normalized()
