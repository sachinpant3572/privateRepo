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
		"ball": 24, "ball2": 12, "column": 24, "cap": 14, "dust": 16, "chunks": 18, "bits": 12, "sparks": 24,
		"lights": 2, "flash": true},
}

## Set by Fx.set_quality.
static var level := "high"
## Burning cars now holding a real light (CarFire takes and gives back).
static var lights_used := 0

static var _tex := {}
static var _mats := {}


static func cfg() -> Dictionary:
	return LEVELS.get(level, LEVELS["high"])


static func set_level(q: String) -> void:
	level = q if LEVELS.has(q) else "high"


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


## Four flame tongues side by side (64 x 128 each): taller than wide, a
## rounded base, a flickering tip leaning one way or the other. White, the
## alpha is the shape; colour comes from the particles' ramp.
static func flame() -> ImageTexture:
	if _tex.has("flame"):
		return _tex["flame"]
	var w := 64
	var h := 128
	var img := Image.create(w * 4, h, true, Image.FORMAT_RGBA8)
	var edge := _noise(11, 0.06)
	var body := _noise(23, 0.035)
	for f in 4:
		var lean: float = [-0.1, 0.07, -0.04, 0.12][f]
		for y in h:
			var t := 1.0 - float(y) / float(h - 1) # 0 base .. 1 tip
			var cx: float = 0.5 + lean * pow(t, 1.6) + 0.05 * body.get_noise_2d(f * 97.0, y * 1.2) * t
			var hw := 0.40 * pow(1.0 - t, 0.75) * sqrt(smoothstep(0.0, 0.16, t))
			for x in w:
				var u := float(x) / float(w - 1)
				var n := edge.get_noise_2d(f * 131.0 + x * 1.0, y * 1.0)
				var d := absf(u - cx) / maxf(hw * (1.0 + 0.45 * n * (0.4 + t)), 0.001)
				var a := 1.0 - smoothstep(0.3, 1.0, d)
				a *= 0.8 + 0.2 * body.get_noise_2d(f * 57.0 + x * 2.0, y * 2.0)
				a *= 1.0 - 0.35 * smoothstep(0.75, 1.0, t)
				img.set_pixel(w * f + x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	_tex["flame"] = _make(img)
	return _tex["flame"]


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


## A plain flat dark chunk (no texture).
static func chunk_mesh(size: Vector2) -> QuadMesh:
	var key := "chunk"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
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
