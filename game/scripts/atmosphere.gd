extends Node3D

## Dusk has started (true) or dawn has finished (false).
signal night_changed(on: bool)
## Time of day and weather. One game minute passes per real second (a day
## is 24 minutes). The sun crosses the sky and its shadows swing round;
## after dusk the moon takes over, the city's windows, lamps and neon light up
## (the `night` shader global) and lamp pools glow on the pavement. Weather
## drifts between clear, cloudy, rain and storm: rain falls around the camera,
## the ground gets wet with puddles (`wet`), storms flash with lightning.

const SkyDome = preload("res://scripts/sky.gd")
const Birds = preload("res://scripts/birds.gd")
## The nearest the perspective shadows reach (m); a parked camera frames
## about 30 m of ground.
const SHADOW_MIN := 40.0

## Sky colour, ambient colour and energy, sun colour and energy, by hour.
const KEYS := [
	[0.0, Color(0.06, 0.08, 0.15), Color(0.5, 0.52, 0.72), 0.62, Color(0.6, 0.68, 1.0), 0.28],
	[5.0, Color(0.08, 0.1, 0.18), Color(0.5, 0.52, 0.7), 0.62, Color(0.62, 0.68, 0.95), 0.28],
	[6.5, Color(0.85, 0.6, 0.5), Color(0.75, 0.62, 0.6), 0.42, Color(1.0, 0.7, 0.5), 0.45],
	[8.5, Color(0.55, 0.7, 0.85), Color(0.78, 0.8, 0.88), 0.35, Color(1.0, 0.97, 0.9), 0.7],
	[16.5, Color(0.55, 0.7, 0.85), Color(0.78, 0.8, 0.88), 0.35, Color(1.0, 0.97, 0.9), 0.7],
	[18.5, Color(0.9, 0.55, 0.42), Color(0.8, 0.6, 0.6), 0.4, Color(1.0, 0.6, 0.4), 0.5],
	[20.0, Color(0.25, 0.2, 0.38), Color(0.55, 0.5, 0.7), 0.58, Color(0.7, 0.55, 0.85), 0.32],
	[21.5, Color(0.06, 0.08, 0.15), Color(0.5, 0.52, 0.72), 0.62, Color(0.6, 0.68, 1.0), 0.28],
	[24.0, Color(0.06, 0.08, 0.15), Color(0.5, 0.52, 0.72), 0.62, Color(0.6, 0.68, 1.0), 0.28],
]
const WEATHERS := {
	"clear": {"clouds": 0.0, "rain": 0.0},
	"cloudy": {"clouds": 0.6, "rain": 0.0},
	"rain": {"clouds": 0.85, "rain": 0.6},
	"storm": {"clouds": 1.0, "rain": 1.0},
}

## Inside a place (interiors.gd): fixed warm room light from above, no
## rain, dry floors and no night glow; the clock keeps running.
var indoors := false

## Hour of the day, 0..24.
var hour := 17.0
## Game minutes per real second.
var minutes_per_second := 1.0
var weather := "clear"
## Set to false to hold the weather (missions, tests, screenshots).
var weather_changes := true
## What the camera looks at; rain follows it.
var focus: Node3D
## Lighter rain, no splashes (phone > Settings > Detail).
var low_detail := false

var sun: DirectionalLight3D
var env: Environment
var clouds := 0.0
var rain := 0.0
var wetness := 0.0
var _weather_time := 240.0
var _flash := 0.0
var _next_flash := 6.0
var _night_on := false
var _perspective := true
var _rain: CPUParticles3D
## The sky shader (sky.gd): gradient, sun, moon, stars by light pollution,
## city glow; outdoors it is the background and what water reflects.
var sky: SkyDome
## Flocks by day, bats at dusk (birds.gd).
var birds: Birds
var _splash: CPUParticles3D
var rng := RandomNumberGenerator.new()


## Fits the shadow cascades to the camera (TopDownCamera). In perspective the
## camera frames ground about 30-65 m deep (more when it backs out over a
## tower); _fit_shadows keeps the shadows just past the top of the screen in
## two cascades: each cascade draws every caster in it once more, and the
## old 160 m reach in four drew about three times the city's triangles for
## shadows nobody saw (0.25.1 log: 250-300k triangles a frame at speed). The
## classic camera sits 220 m back (TopDownCamera.DISTANCE), so the ground is
## 205-235 m away; the splits put the sharpest cascade that holds all of it
## there, and the nearer ones only hold tower tops.
func set_view(perspective: bool) -> void:
	_perspective = perspective
	if perspective:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.4
		_fit_shadows(true)
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 300.0
		sun.directional_shadow_split_1 = 0.45
		sun.directional_shadow_split_2 = 0.62
		sun.directional_shadow_split_3 = 0.8


func _ready() -> void:
	rng.randomize()
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	set_view(true)
	sun.shadow_blur = 1.5
	add_child(sun)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# ACES: deeper shadows and a soft roll-off on bright glass and paint.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.85
	sky = SkyDome.new(env)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	birds = Birds.new()
	birds.atmosphere = self
	add_child(birds)
	_rain = _make_rain()
	_splash = _make_splashes()
	_apply(0.0)


func _process(delta: float) -> void:
	hour = fmod(hour + delta * minutes_per_second / 60.0, 24.0)
	if weather_changes:
		_weather_time -= delta
		if _weather_time <= 0.0:
			_pick_weather()
	_apply(delta)
	_fit_shadows()


## In perspective the shadows reach past the ground at the top of the screen,
## which is about 1.4 times the camera's depth (TopDownCamera.view_depth). They
## grow at once (with 10% to spare, so a camera backing out steadily doesn't
## refit every frame) and shrink only once 25% too far, so the cascades
## don't shimmer.
func _fit_shadows(force := false) -> void:
	if not _perspective:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var depth = cam.get("view_depth") if cam != null else null
	if not depth is float or depth <= 0.0:
		if force:
			sun.directional_shadow_max_distance = 90.0
		return
	var want := maxf(SHADOW_MIN, depth * 1.4)
	var now := sun.directional_shadow_max_distance
	if force or want > now or want * 1.25 < now:
		sun.directional_shadow_max_distance = want * 1.1


## Changes the weather; `instant` skips the fade (tests and mission starts).
func set_weather(kind: String, instant := false) -> void:
	weather = kind
	_weather_time = rng.randf_range(180.0, 420.0)
	if instant:
		clouds = WEATHERS[kind].clouds
		rain = WEATHERS[kind].rain
		wetness = 1.0 if rain > 0.0 else 0.0
		_apply(0.0)


func is_night() -> bool:
	return night_amount() > 0.5


## 0 in daylight, 1 at full night.
func night_amount() -> float:
	if hour >= 18.5 and hour < 21.0:
		return smoothstep(18.5, 20.5, hour)
	if hour >= 21.0 or hour < 5.0:
		return 1.0
	if hour < 7.0:
		return 1.0 - smoothstep(5.0, 6.8, hour)
	return 0.0


## "18:42"
func clock_text() -> String:
	var minutes := int(hour * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _pick_weather() -> void:
	var r := rng.randf()
	set_weather("clear" if r < 0.5 else ("cloudy" if r < 0.72 else ("rain" if r < 0.92 else "storm")))


func _apply(delta: float) -> void:
	if indoors:
		_apply_indoors()
		return
	var target: Dictionary = WEATHERS[weather]
	var k := 1.0 - exp(-0.08 * delta)
	clouds = lerpf(clouds, target.clouds, k)
	rain = lerpf(rain, target.rain, k)
	if rain > 0.15:
		wetness = minf(wetness + delta * 0.05, 1.0)
	else:
		wetness = maxf(wetness - delta * 0.01, 0.0)
	var night := night_amount()
	var key := _sample(hour)
	var grey := Color(0.42, 0.45, 0.5)
	var bg: Color = key[0].lerp(grey * (1.0 - night * 0.8), clouds * 0.6)
	env.background_color = bg
	env.ambient_light_color = key[1].lerp(Color(0.6, 0.63, 0.7), clouds * 0.4 * (1.0 - night))
	env.ambient_light_energy = key[2] + clouds * 0.12 + _flash * 1.5
	sun.light_color = key[3].lerp(Color(0.8, 0.82, 0.86), clouds * 0.5)
	sun.light_energy = key[4] * (1.0 - clouds * 0.55)
	sun.shadow_opacity = 1.0 - clouds * 0.6
	# Sun rises in the east (6:00), sets in the west (18:00); the moon follows
	# the same arc at night. Kept fairly high so shadows stay readable.
	var t := fmod(hour + 18.0, 12.0) / 12.0 # 0 at 6:00/18:00, 0.5 at noon/midnight
	var elevation := lerpf(25.0, 65.0, sin(t * PI))
	sun.rotation_degrees = Vector3(-elevation, lerpf(70.0, -70.0, t), 0.0)
	RenderingServer.global_shader_parameter_set("night", night)
	if (night > 0.02) != _night_on:
		_night_on = night > 0.02
		night_changed.emit(_night_on)
	RenderingServer.global_shader_parameter_set("wet", wetness)
	RenderingServer.global_shader_parameter_set("sky_tint", bg.lerp(Color(0.6, 0.7, 0.85), 0.4))
	if env.background_mode != Environment.BG_SKY:
		env.background_mode = Environment.BG_SKY
	sky.update(self, delta, _sky_ground(), get_viewport().get_camera_3d() if is_inside_tree() else null)
	_update_rain(delta)


func _apply_indoors() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.05)
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.3
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 0.55
	sun.shadow_opacity = 0.45
	sun.rotation_degrees = Vector3(-72.0, 25.0, 0.0)
	RenderingServer.global_shader_parameter_set("night", 0.0)
	RenderingServer.global_shader_parameter_set("wet", 0.0)
	RenderingServer.global_shader_parameter_set("sky_tint", Color(0.75, 0.75, 0.72))
	RenderingServer.global_shader_parameter_set("stars", 0.0)
	_rain.emitting = false
	_splash.emitting = false


## Where the sky is seen from: the focus (the player), else the camera.
func _sky_ground() -> Vector3:
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		return focus.global_position
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	return cam.global_position if cam != null else Vector3.ZERO


func _sample(h: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var f: float = (h - a[0]) / maxf(b[0] - a[0], 0.001)
			return [a[1].lerp(b[1], f), a[2].lerp(b[2], f), lerpf(a[3], b[3], f), a[4].lerp(b[4], f), lerpf(a[5], b[5], f)]
	return [KEYS[0][1], KEYS[0][2], KEYS[0][3], KEYS[0][4], KEYS[0][5]]


func _update_rain(delta: float) -> void:
	var on := rain > 0.05
	_rain.emitting = on
	var amount := 260 if low_detail else 520
	if _rain.amount != amount:
		_rain.amount = amount
	_splash.emitting = on and wetness > 0.2 and not low_detail
	if is_instance_valid(focus):
		var p: Vector3 = (focus.focus_node() if focus.has_method("focus_node") else focus).global_position
		_rain.global_position = Vector3(p.x, 16.0, p.z + 4.0)
		_splash.global_position = Vector3(p.x, 0.08, p.z)
	_rain.speed_scale = 1.0
	((_rain.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a = 0.25 + 0.3 * rain
	# Lightning in storms: a double flash every few seconds.
	_flash = maxf(_flash - delta * 6.0, 0.0)
	if weather == "storm" and rain > 0.7:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = rng.randf_range(5.0, 14.0)
			get_tree().create_timer(0.18).timeout.connect(func(): _flash = 0.8)


func _make_rain() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 520
	p.fixed_fps = 30
	p.lifetime = 0.7
	p.preprocess = 0.7
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(34.0, 0.5, 30.0)
	p.direction = Vector3(0.15, -1.0, 0.1)
	p.spread = 2.0
	p.initial_velocity_min = 26.0
	p.initial_velocity_max = 32.0
	p.gravity = Vector3.ZERO
	p.particle_flag_align_y = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 1.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.82, 0.95, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.mesh = quad
	p.emitting = false
	add_child(p)
	return p


func _make_splashes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 150
	p.fixed_fps = 30
	p.lifetime = 0.35
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(30.0, 0.0, 22.0)
	p.direction = Vector3.UP
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector3.ZERO
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.2))
	curve.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.9, 1.0, 0.7))
	ramp.set_color(1, Color(0.85, 0.9, 1.0, 0.0))
	p.color_ramp = ramp
	var ring := QuadMesh.new()
	ring.size = Vector2(0.35, 0.35)
	ring.orientation = PlaneMesh.FACE_Y
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	ring.material = mat
	p.mesh = ring
	p.emitting = false
	add_child(p)
	return p
