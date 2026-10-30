extends RefCounted
## Shared pieces of the fire and explosion effects (car_fire.gd, explosion.gd):
## the procedural textures (made once, on first use, from noise: a flame
## tongue, cloud puffs, a glow dot, a shockwave ring and a scorch mark), the
## unshaded billboard quads that use them, colour ramps, and the particle
## counts and light use of each graphics quality.
##
## Costs: every emitter is a CPUParticles3D drawing one MultiMesh of quads, all
## unshaded, so a fire or a blast costs a handful of draw calls and no extra
## real light but the few allowed here (see `LEVELS`, "lights").

## What each graphics quality spends. The fire keys are per burning car, the
## blast keys per explosion. "lights" is how many burning cars at once get a
## real flickering light (a real light makes the Compatibility renderer draw
## everything it reaches once more, so Low gets none); "flash" is the short
## OmniLight burst of a blast (0.45 s; none on Low).
const LEVELS := {
	"low": {"core": 6, "body": 8, "wide": 0, "ember": 0, "smoke": 6,
		"ball": 10, "ball2": 0, "column": 8, "cap": 0, "dust": 6, "chunks": 8, "bits": 0, "sparks": 10,
		"lights": 0, "flash": false},
	"medium": {"core": 8, "body": 12, "wide": 8, "ember": 6, "smoke": 10,
		"ball": 16, "ball2": 8, "column": 16, "cap": 8, "dust": 10, "chunks": 12, "bits": 8, "sparks": 16,
		"lights": 1, "flash": true},
	"high": {"core": 10, "body": 16, "wide": 12, "ember": 10, "smoke": 14,
		"ball": 24, "ball2": 12, "column": 16, "cap": 10, "dust": 16, "chunks": 18, "bits": 12, "sparks": 24,
		"lights": 2, "flash": true},
}

## Set by Fx.set_quality.
static var level := "high"
## Settings > Graphics > Real lights: off, no fire or blast gets one.
static var real_lights := true
## Burning cars now holding a real light (CarFire takes and gives back).
static var lights_used := 0

static var _tex := {}
static var _mats := {}
static var _flame_shader: Shader


static func cfg() -> Dictionary:
	return LEVELS.get(level, LEVELS["high"])


static func set_level(q: String, real := true) -> void:
	level = q if LEVELS.has(q) else "high"
	real_lights = real


## Makes every texture now (about 100k pixels in GDScript), so the first
## fire or blast in play does not stall a frame to make them.
static func warm() -> void:
	flame()
	flame_noise()
	flame_material(2)
	flame_material(3)
	cloud()
	cloud(true)
	dot()
	ring()
	scorch()


## 0 by day .. 1 at night.
static func night() -> float:
	return clampf(Fx.night, 0.0, 1.0)


## Tint for smoke and dust that nothing lights: darker at night.
static func dim() -> Color:
	var k := 1.0 - 0.6 * night()
	return Color(k, k, k, 1.0)


# --- textures -----------------------------------------------------------

static func _noise(seed_: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	return n


static func _make(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Six flame pictures side by side (64 x 128 each): one, two or three
## tongues each (a broad one, a tall thin one, twins, a fork, a ragged low
## bed), taller than wide, rounded at the base, tips leaning. White, the
## alpha is the shape; colour comes from the particles' ramp and the flame
## shader (FLAME_SHADER), which also bends and tears them as they rise.
const FLAME_FRAMES := 6
const _TONGUES := [
	[[0.5, 0.42, 1.0, -0.1]],
	[[0.5, 0.3, 1.0, 0.12]],
	[[0.35, 0.27, 0.96, -0.14], [0.66, 0.24, 0.74, 0.1]],
	[[0.5, 0.4, 0.78, 0.05], [0.43, 0.17, 1.0, -0.16], [0.6, 0.13, 0.9, 0.18]],
	[[0.27, 0.21, 0.7, -0.12], [0.52, 0.27, 1.0, 0.03], [0.75, 0.19, 0.62, 0.15]],
	[[0.5, 0.45, 0.66, 0.0], [0.62, 0.17, 1.0, 0.12]],
]


static func flame() -> ImageTexture:
	if _tex.has("flame"):
		return _tex["flame"]
	var w := 64
	var h := 128
	var img := Image.create(w * FLAME_FRAMES, h, true, Image.FORMAT_RGBA8)
	var edge := _noise(11, 0.06)
	var body := _noise(23, 0.035)
	for f in FLAME_FRAMES:
		for y in h:
			var tt := 1.0 - float(y) / float(h - 1) # 0 base .. 1 top
			for x in w:
				var u := float(x) / float(w - 1)
				var n := edge.get_noise_2d(f * 131.0 + x * 1.0, y * 1.0)
				var a := 0.0
				for tg in _TONGUES[f]:
					var t: float = tt / tg[2]
					if t >= 1.0:
						continue
					var cx: float = tg[0] + tg[3] * pow(t, 1.6) + 0.05 * body.get_noise_2d(f * 97.0 + tg[0] * 50.0, y * 1.2) * t
					var hw: float = tg[1] * pow(1.0 - t, 0.75) * sqrt(smoothstep(0.0, 0.16, t))
					var d := absf(u - cx) / maxf(hw * (1.0 + 0.45 * n * (0.4 + t)), 0.001)
					a = maxf(a, (1.0 - smoothstep(0.3, 1.0, d)) * (1.0 - 0.35 * smoothstep(0.75, 1.0, t)))
				a *= 0.8 + 0.2 * body.get_noise_2d(f * 57.0 + x * 2.0, y * 2.0)
				img.set_pixel(w * f + x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_tex["flame"] = _make(img)
	return _tex["flame"]


## Tiling noise (64 x 64, grey) that the flame shader scrolls up through the
## tongues to bend and tear them.
static func flame_noise() -> ImageTexture:
	if _tex.has("flame_noise"):
		return _tex["flame_noise"]
	var n := _noise(57, 1.0 / 16.0)
	var img := n.get_seamless_image(64, 64)
	img.convert(Image.FORMAT_L8)
	_tex["flame_noise"] = _make(img)
	return _tex["flame_noise"]


## Four cloud puffs (64 x 64 each): a ragged round edge, lighter and darker
## patches. `hard` keeps the middle opaque (a fireball), otherwise it is
## wispy (smoke, dust).
static func cloud(hard := false) -> ImageTexture:
	var key := "cloud_hard" if hard else "cloud"
	if _tex.has(key):
		return _tex[key]
	var s := 64
	var img := Image.create(s * 4, s, true, Image.FORMAT_RGBA8)
	var n1 := _noise(5 if not hard else 9, 0.05)
	var n2 := _noise(41, 0.11)
	for f in 4:
		for y in s:
			for x in s:
				var p := Vector2(float(x) / (s - 1) * 2.0 - 1.0, float(y) / (s - 1) * 2.0 - 1.0)
				var r := p.length()
				var n := n1.get_noise_2d(f * 83.0 + x, y)
				var m := n2.get_noise_2d(f * 29.0 + x, y)
				var a := 1.0 - smoothstep(0.2 if not hard else 0.35, 0.95, r + 0.3 * n)
				a *= 0.82 + 0.18 * m
				var shade := clampf(0.82 + 0.5 * m - 0.15 * p.y, 0.0, 1.0)
				img.set_pixel(s * f + x, y, Color(shade, shade, shade, clampf(a, 0.0, 1.0)))
	_tex[key] = _make(img)
	return _tex[key]


## A soft glowing dot, bright in the middle (embers, sparks, the flash).
static func dot() -> ImageTexture:
	if _tex.has("dot"):
		return _tex["dot"]
	var s := 64
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var r := Vector2(float(x) / (s - 1) * 2.0 - 1.0, float(y) / (s - 1) * 2.0 - 1.0).length()
			var a := pow(clampf(1.0 - r, 0.0, 1.0), 1.7)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex["dot"] = _make(img)
	return _tex["dot"]


## A shockwave: a ragged bright band near the rim and a faint dusty middle.
static func ring() -> ImageTexture:
	if _tex.has("ring"):
		return _tex["ring"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var n := _noise(77, 0.08)
	for y in s:
		for x in s:
			var p := Vector2(float(x) / (s - 1) * 2.0 - 1.0, float(y) / (s - 1) * 2.0 - 1.0)
			var r := p.length()
			var wob := 0.05 * n.get_noise_2d(x, y)
			var band := smoothstep(0.5, 0.86, r + wob) * (1.0 - smoothstep(0.86, 1.0, r + wob))
			var fill := 0.16 * (1.0 - smoothstep(0.0, 0.85, r))
			var a := clampf(band * (0.85 + 0.3 * n.get_noise_2d(x * 3.0, y * 3.0)) + fill, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_tex["ring"] = _make(img)
	return _tex["ring"]


## A burnt patch of ground: a ragged dark blob with soot rays, darkest in the
## middle.
static func scorch() -> ImageTexture:
	if _tex.has("scorch"):
		return _tex["scorch"]
	var s := 128
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	var n := _noise(91, 0.045)
	var rays := _noise(133, 0.12)
	for y in s:
		for x in s:
			var p := Vector2(float(x) / (s - 1) * 2.0 - 1.0, float(y) / (s - 1) * 2.0 - 1.0)
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var e := 0.74 + 0.2 * n.get_noise_2d(x, y) + 0.1 * rays.get_noise_2d(cos(ang) * 40.0 + 64.0, sin(ang) * 40.0 + 64.0)
			var a := 1.0 - smoothstep(e - 0.4, e, r)
			a *= 0.78 + 0.22 * rays.get_noise_2d(x * 1.7, y * 1.7)
			a *= lerpf(0.75, 1.0, smoothstep(0.0, 0.5, r))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_tex["scorch"] = _make(img)
	return _tex["scorch"]


# --- materials and meshes ----------------------------------------------

## An unshaded material for particles that face the camera. `frames`: the
## texture holds that many pictures side by side (each particle picks one).
## `prio`: higher draws later (glow over smoke).
static func material(tex: Texture2D, frames := 1, additive := false, prio := 0) -> StandardMaterial3D:
	var key := "%d_%d_%s_%d" % [tex.get_instance_id(), frames, additive, prio]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this a particle billboard drops the particle's scale (Godot
	# normalises it away), so scale_amount and its curve would do nothing.
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.render_priority = prio
	if frames > 1:
		m.particles_anim_h_frames = frames
		m.particles_anim_v_frames = 1
		m.particles_anim_loop = false
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


## A quad of `size` m. `base`: its bottom sits on the particle (flames rise
## from where they start).
static func quad(size: Vector2, tex: Texture2D, frames := 1, additive := false, prio := 0, base := false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	if base:
		q.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	q.material = material(tex, frames, additive, prio)
	return q


## Flame tongues as they really move: the picture (one of `flame()`'s,
## picked per particle) is bent by noise scrolling up through it, little at
## the base and a lot at the tip, and torn by a second noise, so the top
## breaks into separate licks that come and go; the older the particle, the
## more it tears. Dense low parts burn yellow-white, thin edges take the
## particle's ramp colour. Additive, billboard, keeps the particle's scale.
const FLAME_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform sampler2D shape : filter_linear_mipmap;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float frames = 6.0;
varying vec2 cell;
varying float frame;
varying float seed;
varying float age;
void vertex() {
	mat4 w = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	w = w * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * w * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	frame = clamp(floor(INSTANCE_CUSTOM.z * frames), 0.0, frames - 1.0);
	seed = fract(INSTANCE_CUSTOM.z * frames * 7.13);
	age = INSTANCE_CUSTOM.y;
	cell = UV;
}
void fragment() {
	float up = 1.0 - cell.y;
	float t = TIME;
	float n1 = texture(noise, vec2(cell.x * 0.8 + seed * 5.0, cell.y * 0.7 + t * 1.3)).r - 0.5;
	float n2 = texture(noise, vec2(cell.x * 1.9 - seed * 3.0, cell.y * 1.6 + t * 2.4)).r - 0.5;
	float bend = (n1 * 0.36 + n2 * 0.16) * (0.08 + up * up * 1.2);
	vec2 s = clamp(vec2(cell.x + bend, cell.y + n2 * 0.08 * up), vec2(0.004), vec2(0.996));
	float a = texture(shape, vec2((frame + s.x) / frames, s.y)).a;
	float e = texture(noise, vec2(cell.x * 1.4 + seed * 9.0, cell.y * 1.1 + t * 2.0)).r;
	float cut = mix(0.0, 0.62, up * up) + 0.18 * age;
	a *= smoothstep(cut - 0.1, cut + 0.1, e + a * 0.35);
	float heat = clamp(a * 1.5 - up * 0.7, 0.0, 1.0);
	vec3 col = COLOR.rgb * (0.7 + 0.5 * a);
	ALBEDO = mix(col, vec3(1.0, 0.94, 0.72), heat * heat * 0.55);
	ALPHA = clamp(a * COLOR.a, 0.0, 1.0);
}
"""


## The flame shader's material; `prio` as in `material`.
static func flame_material(prio := 2) -> ShaderMaterial:
	var key := "flame_%d" % prio
	if _mats.has(key):
		return _mats[key]
	if _flame_shader == null:
		_flame_shader = Shader.new()
		_flame_shader.code = FLAME_SHADER
	var m := ShaderMaterial.new()
	m.shader = _flame_shader
	m.render_priority = prio
	m.set_shader_parameter("shape", flame())
	m.set_shader_parameter("noise", flame_noise())
	m.set_shader_parameter("frames", float(FLAME_FRAMES))
	_mats[key] = m
	return m


## A flame quad of `size` m whose bottom sits on the particle.
static func flame_quad(size: Vector2, prio := 2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0.0, size.y * 0.5, 0.0)
	q.material = flame_material(prio)
	return q


## A plain flat dark chunk (no texture).
static func chunk_mesh(size: Vector2) -> QuadMesh:
	var key := "chunk"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.billboard_keep_scale = true
		m.vertex_color_use_as_albedo = true
		_mats[key] = m
	var q := QuadMesh.new()
	q.size = size
	q.material = _mats[key]
	return q


static func ramp(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func curve(points: Array) -> Curve:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	return c


## A one-shot or looping emitter with the settings every layer shares.
static func emitter(amount: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.mesh = mesh
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.direction = Vector3.UP
	p.gravity = Vector3.ZERO
	return p


## Picks a random picture of the atlas for each particle.
static func random_frame(p: CPUParticles3D) -> void:
	p.anim_speed_min = 0.0
	p.anim_speed_max = 0.0
	p.anim_offset_min = 0.0
	p.anim_offset_max = 0.99
