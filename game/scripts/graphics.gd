extends Node3D
## Graphics quality: four presets (Low, Medium, High, Ultra) and the effects
## each one sets, which Settings > Graphics can then switch one by one
## (bloom, anti-aliasing, vivid colour, shadows, detail, real lights).
##
## Real lights: the Compatibility renderer draws every object once more for
## each positional light that reaches it, so only a few may be live. Every
## RESCAN seconds after dark this hands them to what matters most: the
## player's own headlights first, then the nearest cars with their lights on,
## then the nearest standing street lamps. Everything further off keeps the
## cheap painted pools of light on the ground (ground_glow_material).

const QUALITIES := ["low", "medium", "high", "ultra"]
## What each preset sets. cars and lamps are how many real lights each
## gets; car_shadow gives the player's headlights a shadow; scale is the 3D
## render scale (the HUD stays sharp).
## 0.21's Ultra fell to 20 fps on a Galaxy S25 Ultra once more than two cars
## were about (Sachin, 2026-10-29): that is when its third car light came
## on, and the Compatibility renderer draws everything a light reaches
## once more per light, and the whole scene again into the headlight
## shadow map. So since 0.22 Ultra keeps High's two car lights and no
## headlight shadow, and adds only anti-aliasing (cheap on phone GPUs).
const PRESETS := {
	"low": {"detail": "low", "shadows": false, "bloom": false, "aa": false, "vivid": false, "real_lights": true, "cars": 1, "lamps": 0, "bars": false, "car_shadow": false, "scale": 0.8},
	"medium": {"detail": "high", "shadows": true, "bloom": false, "aa": false, "vivid": false, "real_lights": true, "cars": 1, "lamps": 2, "bars": false, "car_shadow": false, "scale": 1.0},
	"high": {"detail": "high", "shadows": true, "bloom": true, "aa": false, "vivid": true, "real_lights": true, "cars": 2, "lamps": 4, "bars": true, "car_shadow": false, "scale": 1.0},
	"ultra": {"detail": "high", "shadows": true, "bloom": true, "aa": true, "vivid": true, "real_lights": true, "cars": 2, "lamps": 4, "bars": true, "car_shadow": false, "scale": 1.0},
}
## The settings keys a preset sets (and the effect toggles on the page).
const KEYS := ["detail", "shadows", "bloom", "aa", "vivid", "real_lights"]
const RESCAN := 0.2
## Real lights reach this far from the player (m); the camera never shows
## much more than this round the car.
const REACH := 70.0
const HEAD_ENERGY := 14.0
const LAMP_ENERGY := 2.6
const LAMP_RANGE := {"street_light": 13.0, "gas_lamp": 8.5}
const LAMP_COLOR := {"street_light": Color(0.88, 0.92, 1.0), "gas_lamp": Color(1.0, 0.72, 0.42)}

var game
var quality := "high"
var cars := 2
var lamps := 4
var car_shadow := false
## A lit police car's light bar also lights the road (High and Ultra only:
## on Low and Medium it would go past the preset's light budget).
var bars := true
## Cars holding a real light now, and the pooled lamp lights with the lamp
## collider each one hangs under.
var lit_cars: Array = []
var _lamp_lights: Array[OmniLight3D] = []
var _lamp_of: Array = []
var _time := 0.0


## Copies preset `level` into `settings` (every key in KEYS plus quality).
static func pick(settings: Dictionary, level: String) -> void:
	if not PRESETS.has(level):
		level = "high"
	settings["quality"] = level
	for k in KEYS:
		settings[k] = PRESETS[level][k]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the settings preview runs paused
	top_level = true


## Applies `settings`: the screen effects at once, the light budget on the
## next rescan.
func apply(settings: Dictionary) -> void:
	quality = str(settings.get("quality", "high"))
	if not PRESETS.has(quality):
		quality = "high"
	var p: Dictionary = PRESETS[quality]
	var real: bool = settings.get("real_lights", true)
	cars = p.cars if real else 0
	lamps = p.lamps if real else 0
	car_shadow = p.car_shadow and bool(settings.get("shadows", true))
	bars = p.bars and real
	var env: Environment = game.atmosphere.env
	# Bloom: only what is brighter than white spills over (lamps, neon,
	# headlights, the sun on glass), so daylight colours stay as they are.
	env.glow_enabled = settings.get("bloom", true)
	env.glow_intensity = 0.45
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.9
	env.glow_hdr_scale = 2.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Vivid: a touch more colour and contrast.
	var vivid: bool = settings.get("vivid", true)
	env.adjustment_enabled = vivid
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X if settings.get("aa", false) else Viewport.MSAA_DISABLED
	vp.scaling_3d_scale = p.scale
	_time = RESCAN # rescan now


func _process(delta: float) -> void:
	_time += delta
	if _time < RESCAN:
		return
	_time = 0.0
	rescan()


## Hands the real lights out again (also called by tests).
func rescan() -> void:
	if game == null or game.player == null:
		return
	var night: float = game.atmosphere.night_amount()
	var at: Vector3 = game.player.global_position
	_light_cars(at, night)
	_light_lamps(at, night)


func _light_cars(at: Vector3, night: float) -> void:
	var mine = game.player.vehicle
	var want: Array = []
	if cars > 0 and night > 0.05:
		var near: Array = []
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v.headlights_on() and v.is_inside_tree():
				var d: float = v.global_position.distance_squared_to(at)
				if v == mine:
					d = -1.0
				if d < REACH * REACH:
					near.append([d, v])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(cars, near.size()):
			want.append(near[i][1])
	for v in lit_cars:
		if is_instance_valid(v) and not want.has(v):
			v.set_real_light(false)
	for v in want:
		v.set_real_light(true, HEAD_ENERGY * night, car_shadow and v == mine, bars)
	lit_cars = want


func _light_lamps(at: Vector3, night: float) -> void:
	var want: Array = []
	if lamps > 0 and night > 0.05:
		var near: Array = []
		for shape in get_tree().get_nodes_in_group("lamps"):
			var info: Dictionary = shape.get_meta("brk")
			if info.get("down", false):
				continue
			var d: float = shape.global_position.distance_squared_to(at)
			if d < REACH * REACH:
				near.append([d, shape])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(lamps, near.size()):
			want.append(near[i][1])
	while _lamp_lights.size() < want.size():
		var light := OmniLight3D.new()
		light.omni_attenuation = 1.2
		light.light_specular = 0.3
		add_child(light)
		_lamp_lights.append(light)
		_lamp_of.append(null)
	for i in _lamp_lights.size():
		var light := _lamp_lights[i]
		if i >= want.size():
			light.visible = false
			_lamp_of[i] = null
			continue
		var shape: Node3D = want[i]
		var info: Dictionary = shape.get_meta("brk")
		var kind: String = info.kind
		light.global_position = shape.global_position + info.light
		light.omni_range = LAMP_RANGE.get(kind, 10.0)
		light.light_color = LAMP_COLOR.get(kind, Color.WHITE)
		light.light_energy = LAMP_ENERGY * night * (0.8 if kind == "gas_lamp" else 1.0)
		light.visible = true
		_lamp_of[i] = shape


## The lamp colliders that have a real light now (tests).
func lit_lamps() -> Array:
	var out: Array = []
	for i in _lamp_lights.size():
		if _lamp_lights[i].visible and _lamp_of[i] != null and is_instance_valid(_lamp_of[i]):
			out.append(_lamp_of[i])
	return out
