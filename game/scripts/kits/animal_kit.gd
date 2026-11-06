extends RefCounted
## Wild animals of the hills as built meshes (scripts/wildlife.gd draws them):
## a doe, a buck with antlers, a rabbit, a coyote and a mountain lion. Low
## poly (about 450-650 triangles each) but readable from the game's top-down
## camera at 20-40 m: a tan deer with a white rump and tail, a grey-tan
## coyote with a dark saddle and a bushy tail, a tawny lion with a long
## tail, a grey-brown rabbit with long ears and a white scut.
##
## Every model is one mesh in local space, head toward -z, feet on y 0. Its
## parts are tagged in UV2.x for the gait shader (SHADER): 0 the body,
## 1-4 the legs (front left, front right, hind left, hind right; UV2.y 1 on
## the part below the knee), 5 the neck, head, ears and antlers (UV2.y 2 on
## the eyes, which glow at night), 6 the tail. The shader swings the legs
## about their hips (walk, trot, gallop or hop, by the instance's `amp`),
## bends the knees, lowers the head to graze and lifts or swishes the tail,
## all per instance from the MultiMesh's custom data, so a herd costs one
## draw call per model and no CPU work per leg.
##
## Static and free of the scene tree. Meshes and materials are built once
## and shared.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

## Every model.
const MODELS := ["doe", "buck", "rabbit", "coyote", "lion"]

## Part ids in UV2.x.
const BODY := 0.0
const HEAD := 5.0
const TAIL := 6.0

const HOOF := Color(0.13, 0.11, 0.1)
const WHITE := Color(0.93, 0.91, 0.86)
const NOSE := Color(0.08, 0.07, 0.07)
const BONE := Color(0.8, 0.73, 0.58)

## Per-model facts the behaviour needs, filled by build(): "hips" (Vector3 x4),
## "knee" (drop from hip to knee, x4), "neck" (head pivot), "tail" (tail
## pivot), "swish" (tail swing, radians), "swing" (leg swing scale), "hop"
## (bounds like a rabbit), plus the fixed ones in FACTS.
const FACTS := {
	# length / height: nose to tail root and shoulder height (m, unscaled);
	# scale: how much bigger it is drawn than life (readable from above);
	# body_y / half_w: where a carcass lies; radius: for car hits.
	"doe": {"length": 1.5, "height": 0.97, "scale": 1.1, "body_y": 0.75, "half_w": 0.18, "radius": 0.4, "bob": 0.035},
	"buck": {"length": 1.6, "height": 1.05, "scale": 1.12, "body_y": 0.78, "half_w": 0.2, "radius": 0.45, "bob": 0.04},
	"rabbit": {"length": 0.4, "height": 0.24, "scale": 1.5, "body_y": 0.13, "half_w": 0.085, "radius": 0.18, "bob": 0.0},
	"coyote": {"length": 1.0, "height": 0.66, "scale": 1.15, "body_y": 0.52, "half_w": 0.11, "radius": 0.3, "bob": 0.025},
	"lion": {"length": 1.5, "height": 0.88, "scale": 1.1, "body_y": 0.68, "half_w": 0.17, "radius": 0.38, "bob": 0.03},
}

static var _meshes := {}
static var _specs := {}
static var _materials := {}

const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

global uniform float night;

// Per model: legs 0-3 (hip xyz, knee drop m), 4 the neck base, 5 the tail
// base (w: swish, radians).
uniform vec4 pivot[6];
uniform float swing_scale = 1.0;
uniform float hop = 0.0;

// Instance custom data: x gait phase (cycles), y amp (0 standing .. 1
// gallop), z head down (-0.3 up .. 1 grazing), w tail raised (0 .. 1).
varying vec3 tint;
varying float eye;

const float WALK[4] = float[4](0.25, 0.75, 0.0, 0.5);
const float TROT[4] = float[4](0.0, 0.5, 0.5, 0.0);
const float GALLOP[4] = float[4](0.0, 0.1, 0.5, 0.6);
const float HOP[4] = float[4](0.0, 0.04, 0.5, 0.52);

vec3 rotx(vec3 p, vec3 c, float a) {
	float s = sin(a);
	float k = cos(a);
	vec3 d = p - c;
	return c + vec3(d.x, d.y * k - d.z * s, d.y * s + d.z * k);
}

vec3 roty(vec3 p, vec3 c, float a) {
	float s = sin(a);
	float k = cos(a);
	vec3 d = p - c;
	return c + vec3(d.x * k + d.z * s, d.y, -d.x * s + d.z * k);
}

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	float id = UV2.x;
	float phase = INSTANCE_CUSTOM.x;
	float amp = INSTANCE_CUSTOM.y;
	if (id > 0.5 && id < 4.5) {
		int i = int(id - 0.5);
		float s1 = smoothstep(0.4, 0.5, amp);
		float s2 = smoothstep(0.75, 0.85, amp);
		float off = mix(mix(WALK[i], TROT[i], s1), GALLOP[i], s2);
		if (hop > 0.5) {
			off = HOP[i];
		}
		float cyc = 6.2832 * (phase + off);
		float swing = mix(0.35, 0.95, amp) * smoothstep(0.02, 0.12, amp) * swing_scale;
		vec4 hp = pivot[i];
		if (UV2.y > 0.5) {
			// Below the knee: folds back while the leg swings forward.
			float flex = swing * 1.15 * max(0.0, cos(cyc));
			vec3 knee = hp.xyz - vec3(0.0, hp.w, 0.0);
			p = rotx(p, knee, -flex);
			n = rotx(n, vec3(0.0), -flex);
		}
		float a = swing * sin(cyc);
		p = rotx(p, hp.xyz, a);
		n = rotx(n, vec3(0.0), a);
	} else if (id > 4.5 && id < 5.5) {
		// Neck and head about the neck base: down to graze, a small nod
		// with each stride.
		float a = -INSTANCE_CUSTOM.z * 0.95 + 0.05 * amp * sin(12.566 * phase);
		vec3 c = pivot[4].xyz;
		p = rotx(p, c, a);
		n = rotx(n, vec3(0.0), a);
	} else if (id > 5.5) {
		vec4 tp = pivot[5];
		float lift = -INSTANCE_CUSTOM.w * 1.1;
		p = rotx(p, tp.xyz, lift);
		n = rotx(n, vec3(0.0), lift);
		float sw = sin(TIME * 2.6 + float(INSTANCE_ID) * 2.3 + phase * 6.2832) * tp.w * (1.0 - 0.6 * INSTANCE_CUSTOM.w);
		p = roty(p, tp.xyz, sw);
		n = roty(n, vec3(0.0), sw);
	}
	VERTEX = p;
	NORMAL = n;
	tint = COLOR.rgb;
	eye = UV2.y > 1.5 ? 1.0 : 0.0;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.92;
	if (eye > 0.5) {
		EMISSION = vec3(1.0, 0.85, 0.35) * night * 1.6;
	}
}
"""


## The models, for the kit test.
static func kinds() -> Array:
	return MODELS.duplicate()


## The mesh of `model` (built once).
static func mesh(model: String) -> ArrayMesh:
	_ensure(model)
	return _meshes[model]


## The pivots and gait facts of `model` (see build()).
static func spec(model: String) -> Dictionary:
	_ensure(model)
	return _specs[model]


## The gait shader's material for `model` (built once).
static func material(model: String) -> ShaderMaterial:
	_ensure(model)
	return _materials[model]


## Triangles in `model`'s mesh.
static func triangle_count(model: String) -> int:
	var m := mesh(model)
	var arrays := m.surface_get_arrays(0)
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	if idx != null:
		return (idx as PackedInt32Array).size() / 3
	return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3


static func _ensure(model: String) -> void:
	if _meshes.has(model):
		return
	var mb := MeshBuilder.new()
	var s := build(model, mb)
	var surf := mb.surface()
	var arrays: Array = surf[0]
	arrays[Mesh.ARRAY_TEX_UV2] = _parts(mb)
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[model] = m
	_specs[model] = s
	var shader := Shader.new()
	shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var pv := PackedVector4Array()
	pv.resize(6)
	for i in 4:
		var h: Vector3 = s.hips[i]
		pv[i] = Vector4(h.x, h.y, h.z, s.knee[i])
	var nk: Vector3 = s.neck
	var tl: Vector3 = s.tail
	pv[4] = Vector4(nk.x, nk.y, nk.z, 0.0)
	pv[5] = Vector4(tl.x, tl.y, tl.z, s.swish)
	mat.set_shader_parameter("pivot", pv)
	mat.set_shader_parameter("swing_scale", s.swing)
	mat.set_shader_parameter("hop", 1.0 if s.hop else 0.0)
	_materials[model] = mat


## UV2 per vertex from the builder's tags: x the part id, y 1 below the
## knee, 2 on the eyes.
static func _parts(mb: MeshBuilder) -> PackedVector2Array:
	var uv2 := PackedVector2Array()
	uv2.resize(mb.verts.size())
	var set_range := func(tag: String, id: float, flag: float) -> void:
		var r := mb.tag_ranges(tag)
		for k in range(0, r.size(), 2):
			for v in range(r[k], r[k + 1]):
				uv2[v] = Vector2(id, flag)
	for i in 4:
		set_range.call("leg%d" % i, float(i + 1), 0.0)
		set_range.call("low%d" % i, float(i + 1), 1.0)
	set_range.call("head", HEAD, 0.0)
	set_range.call("eye", HEAD, 2.0)
	set_range.call("tail", TAIL, 0.0)
	return uv2


## Builds `model` into `mb` (local space, nose toward -z, feet on y 0) with
## its parts tagged; returns its spec (pivots, see FACTS).
static func build(model: String, mb: MeshBuilder) -> Dictionary:
	var s: Dictionary
	match model:
		"doe":
			s = _deer(mb, false)
		"buck":
			s = _deer(mb, true)
		"rabbit":
			s = _rabbit(mb)
		"coyote":
			s = _coyote(mb)
		"lion":
			s = _lion(mb)
		_:
			push_error("AnimalKit: no model " + model)
			return {}
	mb.set_tag("")
	for key in FACTS[model]:
		s[key] = FACTS[model][key]
	return s


# --- Parts ----------------------------------------------------------------------

## One leg: `hip` down to `knee` down to `foot` (the top of the hoof), radii
## at the hip, knee and foot; the lower leg and its hoof are tagged apart so
## the shader can fold them at the knee.
static func _leg(mb: MeshBuilder, id: int, hip: Vector3, knee: Vector3, foot: Vector3, radii: Vector3, color: Color, low_color: Color, hoof: Vector3) -> void:
	mb.set_tag("leg%d" % id)
	mb.smooth_limb(hip, knee, radii.x, radii.y, color, 5)
	mb.set_tag("low%d" % id)
	mb.smooth_ball(knee, Vector3.ONE * radii.y * 1.2, color, 5, 3)
	mb.smooth_limb(knee, foot, radii.y, radii.z, low_color, 5)
	mb.smooth_ball(foot + Vector3(0.0, -hoof.y * 0.3, hoof.z * -0.15), hoof, HOOF, 5, 3)


## A pair of eyes at +-x of `at`.
static func _eyes(mb: MeshBuilder, at: Vector3, r: float) -> void:
	mb.set_tag("eye")
	for side in [-1.0, 1.0]:
		mb.smooth_ball(Vector3(side * at.x, at.y, at.z), Vector3.ONE * r, NOSE, 4, 2)


static func _legs(mb: MeshBuilder, s: Dictionary, front: Array, rear: Array, radii_f: Vector3, radii_r: Vector3, color: Color, low: Color, hoof: Vector3) -> void:
	# Order: front left, front right, hind left, hind right. `front` and
	# `rear` are [x, hip y, knee y, foot y, z hip, z knee, z foot].
	s.hips = []
	s.knee = []
	var i := 0
	for group in [[front, radii_f], [rear, radii_r]]:
		var g: Array = group[0]
		for side in [-1.0, 1.0]:
			var x: float = side * g[0]
			var hip := Vector3(x, g[1], g[4])
			var knee := Vector3(x, g[2], g[5])
			var foot := Vector3(x, g[3], g[6])
			_leg(mb, i, hip, knee, foot, group[1], color, low, hoof)
			s.hips.append(hip)
			s.knee.append(g[1] - g[2])
			i += 1


# --- Deer -----------------------------------------------------------------------

static func _deer(mb: MeshBuilder, buck: bool) -> Dictionary:
	var s := {"swish": 0.08, "swing": 1.0, "hop": false}
	var hide := Color(0.62, 0.44, 0.27) if not buck else Color(0.52, 0.36, 0.22)
	var low := Color(0.56, 0.42, 0.3) if not buck else Color(0.47, 0.34, 0.24)
	var grey := Color(0.56, 0.45, 0.34) if not buck else Color(0.46, 0.37, 0.28)
	var k := 1.0 if not buck else 1.08
	mb.set_tag("")
	mb.smooth_ball(Vector3(0.0, 0.74, 0.0) * k, Vector3(0.16, 0.19, 0.5) * k, hide, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.76, -0.3 * k) * 1.0, Vector3(0.15, 0.21, 0.26) * k, hide, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.75, 0.32 * k), Vector3(0.17, 0.21, 0.26) * k, hide, 8, 4)
	# The pale belly and the cream rump patch.
	mb.smooth_ball(Vector3(0.0, 0.62 * k, 0.02), Vector3(0.12, 0.09, 0.36) * k, Color(0.82, 0.72, 0.56), 6, 3)
	mb.smooth_ball(Vector3(0.0, 0.76 * k, 0.55 * k), Vector3(0.1, 0.12, 0.085), Color(0.94, 0.9, 0.82), 6, 3)
	var neck := Vector3(0.0, 0.88 * k, -0.4 * k)
	mb.set_tag("head")
	mb.smooth_limb(neck, Vector3(0.0, 1.24 * k, -0.62 * k), 0.1 * k, 0.06, grey, 6)
	mb.smooth_ball(Vector3(0.0, 1.3 * k, -0.72 * k), Vector3(0.06, 0.07, 0.11), grey, 7, 4)
	mb.smooth_ball(Vector3(0.0, 1.25 * k, -0.84 * k), Vector3(0.04, 0.04, 0.07), Color(0.82, 0.74, 0.62), 6, 3)
	mb.smooth_ball(Vector3(0.0, 1.25 * k, -0.9 * k), Vector3(0.022, 0.022, 0.02), NOSE, 4, 2)
	for side in [-1.0, 1.0]:
		mb.smooth_limb(Vector3(side * 0.05, 1.35 * k, -0.69 * k), Vector3(side * 0.15, 1.45 * k, -0.7 * k), 0.035, 0.012, grey, 4)
	if buck:
		for side in [-1.0, 1.0]:
			var a := Vector3(side * 0.04, 1.37 * k, -0.7 * k)
			var b := Vector3(side * 0.1, 1.62 * k, -0.73 * k)
			var c := Vector3(side * 0.13, 1.86 * k, -0.82 * k)
			mb.limb(a, b, 0.017, 0.014, BONE, 4)
			mb.limb(b, c, 0.014, 0.01, BONE, 4)
			mb.limb(b, Vector3(side * 0.05, 1.74 * k, -0.93 * k), 0.012, 0.007, BONE, 4)
			mb.limb(Vector3(side * 0.118, 1.76 * k, -0.78 * k), Vector3(side * 0.25, 1.92 * k, -0.8 * k), 0.011, 0.006, BONE, 4)
			mb.limb(Vector3(side * 0.075, 1.5 * k, -0.71 * k), Vector3(side * 0.07, 1.62 * k, -0.58 * k), 0.01, 0.006, BONE, 4)
	_eyes(mb, Vector3(0.055, 1.32 * k, -0.76 * k), 0.016)
	var tail := Vector3(0.0, 0.85 * k, 0.57 * k)
	mb.set_tag("tail")
	mb.smooth_limb(tail, Vector3(0.0, 0.8 * k, 0.76 * k), 0.05, 0.034, WHITE, 5)
	mb.smooth_ball(Vector3(0.0, 0.79 * k, 0.77 * k), Vector3(0.036, 0.04, 0.04), WHITE, 5, 3)
	_legs(mb, s,
		[0.1 * k, 0.62 * k, 0.32 * k, 0.07, -0.32 * k, -0.32 * k, -0.32 * k],
		[0.11 * k, 0.64 * k, 0.34 * k, 0.07, 0.34 * k, 0.4 * k, 0.34 * k],
		Vector3(0.05, 0.034, 0.021) * k, Vector3(0.06, 0.04, 0.021) * k, hide, low, Vector3(0.03, 0.035, 0.045))
	s.neck = neck
	s.tail = tail
	return s


# --- Rabbit ---------------------------------------------------------------------

static func _rabbit(mb: MeshBuilder) -> Dictionary:
	var s := {"swish": 0.0, "swing": 1.25, "hop": true}
	var fur := Color(0.5, 0.42, 0.34)
	var dark := Color(0.38, 0.32, 0.26)
	mb.set_tag("")
	mb.smooth_ball(Vector3(0.0, 0.13, 0.03), Vector3(0.075, 0.09, 0.14), fur, 7, 4)
	mb.smooth_ball(Vector3(0.0, 0.15, 0.1), Vector3(0.09, 0.11, 0.1), fur, 7, 4)
	mb.smooth_ball(Vector3(0.0, 0.13, -0.06), Vector3(0.065, 0.08, 0.09), fur, 6, 3)
	mb.smooth_ball(Vector3(0.0, 0.07, 0.03), Vector3(0.06, 0.04, 0.12), Color(0.8, 0.74, 0.66), 5, 3)
	var neck := Vector3(0.0, 0.14, -0.1)
	mb.set_tag("head")
	mb.smooth_ball(Vector3(0.0, 0.19, -0.17), Vector3(0.05, 0.055, 0.075), fur, 7, 4)
	mb.smooth_ball(Vector3(0.0, 0.18, -0.235), Vector3(0.018, 0.018, 0.012), Color(0.75, 0.5, 0.5), 4, 2)
	for side in [-1.0, 1.0]:
		mb.smooth_limb(Vector3(side * 0.025, 0.23, -0.16), Vector3(side * 0.045, 0.4, -0.2), 0.022, 0.012, dark, 5)
	_eyes(mb, Vector3(0.04, 0.2, -0.2), 0.012)
	var tail := Vector3(0.0, 0.16, 0.19)
	mb.set_tag("tail")
	mb.smooth_ball(Vector3(0.0, 0.165, 0.215), Vector3.ONE * 0.04, WHITE, 5, 3)
	_legs(mb, s,
		[0.04, 0.1, 0.055, 0.012, -0.08, -0.1, -0.1],
		[0.06, 0.12, 0.07, 0.012, 0.1, 0.17, 0.02],
		Vector3(0.02, 0.015, 0.012), Vector3(0.03, 0.02, 0.014), fur, dark, Vector3(0.016, 0.012, 0.03))
	s.neck = neck
	s.tail = tail
	return s


# --- Coyote ---------------------------------------------------------------------

static func _coyote(mb: MeshBuilder) -> Dictionary:
	var s := {"swish": 0.12, "swing": 1.0, "hop": false}
	var fur := Color(0.66, 0.57, 0.43)
	var saddle := Color(0.42, 0.37, 0.31)
	var tan := Color(0.78, 0.68, 0.52)
	mb.set_tag("")
	mb.smooth_ball(Vector3(0.0, 0.5, 0.0), Vector3(0.1, 0.13, 0.33), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.52, -0.24), Vector3(0.11, 0.15, 0.2), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.5, 0.24), Vector3(0.1, 0.13, 0.2), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.575, -0.02), Vector3(0.085, 0.085, 0.34), saddle, 7, 3)
	mb.smooth_ball(Vector3(0.0, 0.4, -0.05), Vector3(0.07, 0.06, 0.3), tan, 6, 3)
	var neck := Vector3(0.0, 0.57, -0.34)
	mb.set_tag("head")
	mb.smooth_limb(neck, Vector3(0.0, 0.66, -0.52), 0.085, 0.06, fur, 6)
	mb.smooth_ball(Vector3(0.0, 0.68, -0.58), Vector3(0.055, 0.06, 0.09), fur, 7, 4)
	mb.smooth_limb(Vector3(0.0, 0.665, -0.62), Vector3(0.0, 0.63, -0.78), 0.042, 0.026, tan, 6)
	mb.smooth_ball(Vector3(0.0, 0.63, -0.79), Vector3(0.02, 0.02, 0.018), NOSE, 4, 2)
	for side in [-1.0, 1.0]:
		mb.smooth_limb(Vector3(side * 0.04, 0.72, -0.55), Vector3(side * 0.065, 0.87, -0.56), 0.036, 0.006, fur, 4)
	_eyes(mb, Vector3(0.045, 0.7, -0.63), 0.013)
	var tail := Vector3(0.0, 0.5, 0.38)
	mb.set_tag("tail")
	mb.smooth_limb(tail, Vector3(0.0, 0.36, 0.64), 0.05, 0.058, fur, 6)
	mb.smooth_ball(Vector3(0.0, 0.31, 0.7), Vector3(0.05, 0.055, 0.07), saddle, 5, 3)
	_legs(mb, s,
		[0.075, 0.45, 0.24, 0.035, -0.22, -0.22, -0.22],
		[0.08, 0.45, 0.25, 0.035, 0.24, 0.3, 0.25],
		Vector3(0.036, 0.026, 0.018), Vector3(0.045, 0.028, 0.018), fur, tan, Vector3(0.022, 0.02, 0.032))
	s.neck = neck
	s.tail = tail
	return s


# --- Mountain lion --------------------------------------------------------------

static func _lion(mb: MeshBuilder) -> Dictionary:
	var s := {"swish": 0.38, "swing": 0.95, "hop": false}
	var fur := Color(0.74, 0.56, 0.34)
	var pale := Color(0.86, 0.77, 0.6)
	var dark := Color(0.3, 0.22, 0.16)
	mb.set_tag("")
	mb.smooth_ball(Vector3(0.0, 0.67, 0.0), Vector3(0.15, 0.17, 0.4), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.7, -0.32), Vector3(0.17, 0.21, 0.25), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.7, 0.34), Vector3(0.17, 0.2, 0.25), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.54, -0.02), Vector3(0.12, 0.09, 0.4), pale, 6, 3)
	var neck := Vector3(0.0, 0.76, -0.44)
	mb.set_tag("head")
	mb.smooth_limb(neck, Vector3(0.0, 0.8, -0.66), 0.125, 0.1, fur, 6)
	mb.smooth_ball(Vector3(0.0, 0.8, -0.76), Vector3(0.1, 0.095, 0.11), fur, 8, 4)
	mb.smooth_ball(Vector3(0.0, 0.75, -0.87), Vector3(0.055, 0.05, 0.06), pale, 6, 3)
	mb.smooth_ball(Vector3(0.0, 0.76, -0.925), Vector3(0.022, 0.018, 0.015), Color(0.35, 0.2, 0.2), 4, 2)
	for side in [-1.0, 1.0]:
		mb.smooth_ball(Vector3(side * 0.075, 0.89, -0.72), Vector3(0.03, 0.036, 0.022), dark, 5, 3)
	_eyes(mb, Vector3(0.06, 0.82, -0.82), 0.015)
	var tail := Vector3(0.0, 0.68, 0.5)
	mb.set_tag("tail")
	mb.smooth_limb(tail, Vector3(0.0, 0.6, 0.82), 0.048, 0.04, fur, 5)
	mb.smooth_limb(Vector3(0.0, 0.6, 0.82), Vector3(0.0, 0.38, 1.04), 0.04, 0.036, fur, 5)
	mb.smooth_ball(Vector3(0.0, 0.34, 1.07), Vector3(0.055, 0.06, 0.07), dark, 5, 3)
	_legs(mb, s,
		[0.11, 0.55, 0.28, 0.05, -0.32, -0.32, -0.32],
		[0.12, 0.55, 0.3, 0.05, 0.36, 0.44, 0.38],
		Vector3(0.065, 0.05, 0.04), Vector3(0.075, 0.05, 0.04), fur, pale, Vector3(0.05, 0.035, 0.065))
	s.neck = neck
	s.tail = tail
	return s
