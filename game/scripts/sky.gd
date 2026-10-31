extends RefCounted
## The sky behind the world (Atmosphere's background): a gradient by hour
## and weather, the sun's disc and halo where the sun light comes from, the
## moon with its phase where the moonlight comes from, drifting clouds, and
## stars that come out at night as far as the light pollution where the
## camera is lets them: a handful of faint ones downtown, more in the
## suburbs, thousands and the Milky Way on the hills, the far beaches and
## the desert. At night the cities and towns glow orange on the horizon
## (all round inside the city, toward the lights outside it) and light the
## undersides of clouds.
##
## One sky shader; it has no TIME, so the reflection cubemap (32 px) only
## redraws when the uniforms change, a few times a second unless the camera
## looks at the sky. Shader globals for other materials: `stars` (star
## visibility at the camera, 0..1), `sky_zenith` (colour high up) and
## `sun_dir` (xyz toward the sun or moon disc, w its brightness); water and
## wet ground mirror them (mesh_builder.gd).
##
## Light pollution (pollution_at) comes from data/world_map.json: every
## city district by how brightly its kind is lit, each city's whole area a
## little, and the towns and villages; sky glow falls off over FALLOFF
## metres past their edges.

const MAP_PATH := "res://data/world_map.json"
## Local metres are the world map's minus this city's demo-window origin
## (city.gd map_origin).
const CITY_ID := "bellerive"
## How brightly a district of each style is lit at night (0..1).
const STYLE_LIGHT := {
	"downtown": 1.0, "midtown": 1.0, "financial": 1.0, "strip": 1.0,
	"quarter": 0.85, "civic": 0.8, "waterfront": 0.8, "docks": 0.75,
	"market": 0.7, "oldtown": 0.7, "chinatown": 0.85, "havana": 0.65, "painted": 0.5, "brownstone": 0.6, "rowhouse": 0.6,
	"industrial": 0.6, "wards": 0.55, "beach": 0.55, "revival": 0.5,
	"heights": 0.4, "hills": 0.4, "suburb": 0.4, "enclave": 0.4,
	"park": 0.3, "bayou": 0.2, "prairie": 0.15,
}
## Town kinds: [light 0..1, radius m]. Ghost towns are dark.
const TOWN_LIGHT := {"town": [0.35, 220.0], "village": [0.2, 140.0], "truck_stop": [0.25, 90.0]}
## A whole city's area, between and round its districts.
const CITY_LIGHT := 0.25
## Cities not built yet (later phases) glow on the horizon a little less.
const FAR_CITY := 0.8
## Sky glow overhead falls off this fast past a lit area's edge (m).
const FALLOFF := 230.0
## A lunar month in game days (a day is 24 real minutes).
const LUNAR_DAYS := 8.0
## Phase on day 0 (0 new, 0.5 full): a waxing crescent, so the first night
## out of town shows the Milky Way; the moon is nearest full on the third
## night, the night of day 2 (calendar.gd full_moon_night: day % 8 == 2).
const PHASE0 := 0.08
## Fewest stars, in the brightest city centre (0..1 of a dark sky's).
const CITY_STARS := 0.08
## Reflection cubemap and global updates per second while the sky is off
## screen (every frame while it is on screen).
const IDLE_HZ := 4.0
## Celestial pole: 30 degrees up toward north (-z), the Gulf's latitude.
const POLE := Vector3(0.0, 0.5, -0.8660254)

## Gradient by hour: [hour, zenith, horizon].
const KEYS := [
	[0.0, Color(0.006, 0.009, 0.022), Color(0.025, 0.032, 0.06)],
	[4.8, Color(0.006, 0.009, 0.022), Color(0.025, 0.032, 0.06)],
	[5.6, Color(0.04, 0.06, 0.13), Color(0.26, 0.2, 0.28)],
	[6.2, Color(0.15, 0.25, 0.47), Color(0.86, 0.57, 0.42)],
	[7.5, Color(0.18, 0.36, 0.68), Color(0.62, 0.72, 0.84)],
	[16.5, Color(0.18, 0.36, 0.68), Color(0.62, 0.72, 0.84)],
	[17.6, Color(0.16, 0.3, 0.58), Color(0.8, 0.64, 0.5)],
	[18.2, Color(0.12, 0.18, 0.38), Color(0.95, 0.52, 0.33)],
	[19.0, Color(0.05, 0.07, 0.16), Color(0.38, 0.22, 0.26)],
	[20.0, Color(0.015, 0.02, 0.05), Color(0.07, 0.065, 0.1)],
	[21.0, Color(0.006, 0.009, 0.022), Color(0.025, 0.032, 0.06)],
	[24.0, Color(0.006, 0.009, 0.022), Color(0.025, 0.032, 0.06)],
]
## Sodium and LED street light scattered by the air.
const GLOW_COLOR := Color(1.0, 0.56, 0.3)
## Lit places (or clusters on one bearing) drawn as domes on the horizon.
const GLOW_LOBES := 4
## Most glow the sky shows in any one place (downtown, all round).
const GLOW_MAX := 1.4

const SHADER := """
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float sun_amount = 1.0;
uniform float moon_amount = 0.0;
uniform float moon_phase = 0.5;
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 zenith_color : source_color = vec3(0.18, 0.36, 0.68);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.72, 0.84);
uniform vec3 dusk_color : source_color = vec3(1.0, 0.5, 0.25);
uniform vec3 dusk_dir = vec3(1.0, 0.0, 0.0);
uniform float dusk = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.56, 0.3);
// The lit places' glow (glow_at): all of it, the part all round, and a dome
// per place farther off (bearing x z, strength, half width rad).
uniform float glow_amount = 0.0;
uniform float glow_around = 0.0;
uniform vec4 glow_lobe[4];
uniform float stars = 0.0;
uniform float milky = 0.0;
uniform float clouds = 0.0;
uniform vec3 cloud_lit : source_color = vec3(0.95, 0.95, 0.96);
uniform vec3 cloud_dark : source_color = vec3(0.55, 0.58, 0.63);
uniform vec2 cloud_shift = vec2(0.0);
uniform float star_turn = 0.0;

const vec3 POLE = vec3(0.0, 0.5, -0.8660254);
// The Milky Way's plane, in the stars' frame.
const vec3 GALAXY = vec3(0.42, 0.3, 0.857);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 hash32(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.103, 0.0973));
	p3 += dot(p3, p3.yxz + 33.33);
	return fract((p3.xxy + p3.yzz) * p3.zyx);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 11.0) * 0.3 + vnoise(p * 4.11 + 23.0) * 0.15;
}

// Rodrigues: v turned by angle a round the unit axis k.
vec3 turn(vec3 v, vec3 k, float a) {
	return v * cos(a) + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - cos(a));
}

// Stars on a cube-face grid: one candidate per cell, at most one cell
// looked up per pixel. `lim` is how many come through the sky glow (0..1,
// brightest first); the Milky Way's band holds more of them.
vec3 star_field(vec3 d, float band) {
	vec3 a = abs(d);
	vec2 uv;
	float face;
	if (a.x >= a.y && a.x >= a.z) {
		uv = d.yz / a.x;
		face = d.x > 0.0 ? 1.0 : 2.0;
	} else if (a.y >= a.z) {
		uv = d.xz / a.y;
		face = d.y > 0.0 ? 3.0 : 4.0;
	} else {
		uv = d.xy / a.z;
		face = d.z > 0.0 ? 5.0 : 6.0;
	}
	vec2 g = uv * 60.0;
	vec2 cell = floor(g);
	vec3 h = hash32(cell + face * 131.0);
	float present = step(h.z, 0.07 + 0.12 * band);
	float m = hash12(cell * 1.7 + face * 59.0);
	float vis = present * clamp((stars - m) / max(stars * 0.35, 0.001), 0.0, 1.0);
	float bright = exp2(-5.0 * m) * 3.2 * (0.35 + 0.65 * stars);
	vec2 c = cell + 0.25 + 0.5 * h.xy;
	vec2 off = g - c;
	float core = exp(-dot(off, off) * 95.0);
	vec3 tint = mix(vec3(0.72, 0.82, 1.0), vec3(1.0, 0.84, 0.64), h.y * h.y);
	// A fine dust of faint stars that only a dark sky shows, thickest in the band.
	vec2 g2 = uv * 150.0;
	vec2 cell2 = floor(g2);
	vec3 h2 = hash32(cell2 + face * 71.0);
	vec2 off2 = g2 - (cell2 + 0.25 + 0.5 * h2.xy);
	float faint = step(h2.z, 0.09 + 0.3 * band) * smoothstep(0.5, 0.9, stars) * exp(-dot(off2, off2) * 18.0) * (0.3 + 0.5 * h2.y);
	return tint * core * bright * vis + vec3(0.82, 0.86, 1.0) * faint;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = max(d.y, 0.0);
	vec3 col = mix(horizon_color, zenith_color, pow(up, 0.55));
	// Below the horizon: hazy distance.
	col = mix(col, horizon_color * 0.55, smoothstep(0.0, -0.25, d.y));
	vec2 hd = normalize(d.xz + vec2(1e-5));
	// Sunrise and sunset: warm light low round the sun's side.
	float side = max(dot(hd, normalize(dusk_dir.xz + vec2(1e-5))), 0.0);
	col += dusk_color * dusk * exp(-up * 5.0) * (0.25 + 0.75 * side * side);
	// City glow: low on the horizon, all round in town, a dome over each
	// lit place outside it (wider than the place: the haze scatters it).
	float glow = glow_around;
	for (int i = 0; i < 4; i++) {
		vec4 lobe = glow_lobe[i];
		float a = acos(clamp(dot(hd, lobe.xy), -1.0, 1.0));
		float spread = lobe.w + 0.25;
		glow += lobe.z * exp(-a * a / (2.0 * spread * spread));
	}
	glow = min(glow, 1.6);
	col += glow_color * (glow * exp(-up * 6.0) * 0.32 + glow_amount * 0.025);
	float sd = dot(d, sun_dir);
	float halo = pow(max(sd, 0.0), 6.0) * 0.1 + pow(max(sd, 0.0), 60.0) * 0.3 + pow(max(sd, 0.0), 900.0) * 1.1;
	float md = dot(d, moon_dir);
	float illum = 0.5 - 0.5 * cos(moon_phase * 6.2831853);
	float moon_halo = pow(max(md, 0.0), 260.0) * 0.18 * illum * moon_amount;
	if (AT_CUBEMAP_PASS) {
		// Reflections: the gradient, the halos and the cloud cover's tone only.
		vec3 overcast = mix(cloud_dark, cloud_lit, 0.5);
		col = mix(col, overcast, smoothstep(0.3, 0.95, clouds) * smoothstep(-0.1, 0.1, d.y));
		COLOR = col + sun_color * halo * sun_amount * (1.0 - clouds * 0.7) + vec3(0.8, 0.85, 1.0) * moon_halo;
	} else {
		// Clouds on a plane overhead, thinning to haze toward the horizon.
		float cover = 0.12 + 0.88 * clouds;
		vec2 cuv = d.xz / (d.y + 0.16) * 1.4 + cloud_shift;
		float n = fbm(cuv);
		float cloud = smoothstep(1.0 - cover, 1.0 - cover + 0.32, n) * smoothstep(-0.02, 0.2, d.y);
		cloud = max(cloud, smoothstep(0.55, 1.0, clouds) * smoothstep(-0.1, 0.1, d.y));
		// The stars turn round the pole with the hour.
		vec3 s = turn(d, POLE, -star_turn);
		float gal = dot(s, GALAXY);
		float band = exp(-gal * gal / 0.03);
		vec3 night_sky = star_field(s, band * milky);
		float dl = (gal + 0.015) / 0.035;
		float dust = 1.0 - 0.65 * exp(-dl * dl) * vnoise(s.xy * 9.0 + s.z * 5.0);
		night_sky += vec3(0.62, 0.68, 0.85) * band * milky * 0.09 * (0.5 + 0.8 * fbm(s.xz * 7.0 + s.y * 3.0)) * dust;
		col += night_sky * smoothstep(0.0, 0.22, d.y) * (1.0 - cloud);
		// The moon: a lit sphere, its phase the angle of the sunlight on it.
		if (md > 0.9995 && moon_amount > 0.0) {
			vec3 right = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
			vec3 mup = cross(right, moon_dir);
			vec2 q = vec2(dot(d, right), dot(d, mup)) / 0.0165;
			float rr = dot(q, q);
			if (rr < 1.0) {
				vec3 n3 = vec3(q, sqrt(1.0 - rr));
				float ph = moon_phase * 6.2831853;
				float lit = smoothstep(-0.04, 0.06, dot(n3, vec3(sin(ph), 0.0, -cos(ph))));
				float mare = 0.8 + 0.2 * vnoise(q * 2.6 + 7.0);
				vec3 moon = vec3(0.96, 0.94, 0.88) * (lit * mare * 1.7 + 0.035);
				col = mix(col, moon, smoothstep(1.0, 0.9, rr) * moon_amount * (1.0 - cloud * 0.85));
			}
		}
		col += vec3(0.8, 0.85, 1.0) * moon_halo * (1.0 - cloud * 0.5);
		// Sun: a soft halo and a hot disc (bigger than life so it reads).
		float disc = smoothstep(0.99985, 0.99991, sd);
		col += sun_color * sun_amount * (halo * (1.0 - cloud * 0.6) + disc * 14.0 * (1.0 - cloud));
		vec3 ccol = mix(cloud_dark, cloud_lit, smoothstep(0.35, 0.95, n));
		ccol += sun_color * sun_amount * pow(max(sd, 0.0), 12.0) * 0.4;
		ccol += glow_color * glow_amount * 0.12;
		col = mix(col, ccol, cloud * 0.96);
		COLOR = col;
	}
}
"""

static var _sources: Array = [] # [Rect2 local, light 0..1]
static var _loaded := false

var env: Environment
var sky: Sky
var material: ShaderMaterial
## Toward the sun's disc and the moon's (unit, world).
var sun_dir := Vector3.UP
var moon_dir := Vector3.DOWN
## How much of each disc shows (cloud, the hour).
var sun_amount := 0.0
var moon_amount := 0.0
## 0 new, 0.25 first quarter, 0.5 full, 0.75 last quarter.
var moon_phase := PHASE0
## Light pollution and star visibility (0..1) at the camera's ground.
var pollution := 0.0
var stars := 0.0
var milky := 0.0
var glow_amount := 0.0
var zenith := Color()
var horizon := Color()
## Whole game days since the start (moon phase, stars' turn): the
## calendar's when the atmosphere has one, else counted here.
var day := 0
var _last_hour := -1.0
var _wait := 0.0
var _set := {}
## glow_at for the last place it was worked out (it changes over metres).
var _glow := {}
var _glow_from := Vector2.INF


func _init(environment: Environment) -> void:
	env = environment
	var shader := Shader.new()
	shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	sky = Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.background_mode = Environment.BG_SKY


## Recomputes the sky for `atm` (Atmosphere) seen from `ground` (the
## camera's focus); `cam` decides how often the shader is updated.
func update(atm, delta: float, ground: Vector3, cam: Camera3D) -> void:
	var hour: float = atm.hour
	var cal = atm.get("calendar")
	if cal != null:
		# The calendar is the day count (it ticks indoors too); feeding it
		# the clock here keeps a frame where the hour was set straight.
		cal.tick(hour)
		day = cal.day()
	elif _last_hour >= 0.0 and hour < _last_hour - 12.0:
		day += 1
	_last_hour = hour
	var on_screen := cam != null and looks_at_sky(cam)
	_wait -= delta
	if _wait > 0.0 and not on_screen and delta > 0.0:
		return
	_wait = 1.0 / IDLE_HZ
	var night: float = atm.night_amount()
	var clouds: float = atm.clouds
	var light: Vector3 = atm.sun.transform.basis.z.normalized()
	var day_arc := hour >= 6.0 and hour < 18.0
	var disc := disc_direction(light, hour)
	sun_dir = disc if day_arc else _below(disc, hour)
	moon_dir = disc if not day_arc else -disc
	moon_phase = fposmod(PHASE0 + (day + hour / 24.0) / LUNAR_DAYS, 1.0)
	var illum := 0.5 - 0.5 * cos(moon_phase * TAU)
	var clear := 1.0 - smoothstep(0.45, 0.95, clouds)
	sun_amount = smoothstep(5.9, 6.1, hour) * (1.0 - smoothstep(17.9, 18.1, hour)) * clear
	moon_amount = (smoothstep(18.0, 18.4, hour) + 1.0 - smoothstep(5.6, 6.0, hour)) * clear if not day_arc else 0.0
	moon_amount = clampf(moon_amount, 0.0, 1.0)
	var p2 := Vector2(ground.x, ground.z)
	pollution = pollution_at(p2)
	stars = star_visibility(pollution, clouds, night, moon_amount * illum * clampf(moon_dir.y * 3.0, 0.0, 1.0))
	milky = smoothstep(0.62, 0.95, stars)
	var lights_on := smoothstep(0.1, 0.6, night)
	if _glow_from.distance_to(p2) > 10.0:
		_glow_from = p2
		_glow = glow_at(p2)
	var g := _glow
	glow_amount = minf(g.total, GLOW_MAX) * lights_on
	var lobes := PackedVector4Array()
	lobes.resize(GLOW_LOBES)
	for i in mini(g.lobes.size(), GLOW_LOBES):
		var l: Vector4 = g.lobes[i]
		lobes[i] = Vector4(l.x, l.y, minf(l.z, GLOW_MAX) * lights_on, l.w)
	var key := _sample(hour)
	zenith = key[0]
	horizon = key[1]
	# Moonlight lifts the night sky a little; the city's glow a lot.
	var moon_lift := moon_amount * illum * night
	zenith += Color(0.012, 0.018, 0.035) * moon_lift + GLOW_COLOR * 0.09 * pollution * lights_on
	horizon += Color(0.02, 0.025, 0.04) * moon_lift
	# Overcast: grey by day, near black in the country at night, orange over towns.
	var cover := smoothstep(0.3, 0.95, clouds)
	var overcast := Color(0.56, 0.59, 0.63).lerp(Color(0.03, 0.032, 0.036), night) + GLOW_COLOR * 0.3 * minf(g.total, 1.0) * lights_on
	zenith = zenith.lerp(overcast, cover)
	horizon = horizon.lerp(overcast * 1.08, cover)
	var dusk := (smoothstep(4.9, 6.0, hour) * (1.0 - smoothstep(6.2, 7.3, hour)) + smoothstep(16.8, 18.1, hour) * (1.0 - smoothstep(18.3, 19.6, hour))) * (1.0 - cover)
	var sun_low := 1.0 - smoothstep(0.02, 0.3, sun_dir.y)
	var sun_color := Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.55, 0.3), sun_low)
	var cloud_lit := Color(0.95, 0.95, 0.96).lerp(Color(1.0, 0.72, 0.55), dusk).lerp(Color(0.1, 0.11, 0.13), night)
	var cloud_dark := Color(0.55, 0.58, 0.63).lerp(Color(0.5, 0.4, 0.45), dusk).lerp(Color(0.035, 0.038, 0.045), night)
	cloud_lit = cloud_lit.lerp(cloud_lit * 0.62, cover)
	cloud_dark = cloud_dark.lerp(cloud_dark * 0.62, cover)
	var dusk_dir := Vector3(-0.94, 0.0, 0.34) if hour > 12.0 else Vector3(0.94, 0.0, 0.34)
	if env.fog_enabled:
		env.fog_light_color = horizon # the Look up haze (horizon_haze) keeps to the sky
	_param("sun_dir", sun_dir)
	_param("moon_dir", moon_dir)
	_param("sun_amount", sun_amount)
	_param("moon_amount", moon_amount)
	_param("moon_phase", moon_phase)
	_param("sun_color", sun_color)
	_param("zenith_color", zenith)
	_param("horizon_color", horizon)
	_param("dusk", dusk)
	_param("dusk_dir", dusk_dir)
	_param("glow_color", GLOW_COLOR)
	_param("glow_amount", glow_amount)
	_param("glow_around", minf(g.around, GLOW_MAX) * lights_on)
	_param("glow_lobe", lobes)
	_param("stars", stars)
	_param("milky", milky)
	_param("clouds", clouds)
	_param("cloud_lit", cloud_lit)
	_param("cloud_dark", cloud_dark)
	# Clouds drift west to east; the stars turn once a day.
	_param("cloud_shift", Vector2(-(day * 24.0 + hour) * 0.9, (day * 24.0 + hour) * 0.25))
	_param("star_turn", fposmod((day + hour / 24.0) * TAU, TAU))
	RenderingServer.global_shader_parameter_set("stars", stars)
	RenderingServer.global_shader_parameter_set("sky_zenith", zenith)
	var shown := Vector3.ZERO
	var bright := 0.0
	if sun_amount > 0.0:
		shown = sun_dir
		bright = sun_amount
	elif moon_amount > 0.0:
		shown = moon_dir
		bright = moon_amount * illum * 0.35
	RenderingServer.global_shader_parameter_set("sun_dir", Vector4(shown.x, shown.y, shown.z, bright))


## The next update recomputes everything (a clock skip, a teleport).
func refresh() -> void:
	_wait = 0.0


func _param(key: String, value) -> void:
	if _set.get(key) == value:
		return
	_set[key] = value
	material.set_shader_parameter(key, value)


## Where the disc of the body lighting the scene is drawn: the light's
## bearing, and its height, except in the first and last 1.7 hours of its
## 12-hour arc, when the disc sinks to the horizon. (The light itself stays
## 25 degrees up so shadows stay readable; a rising sun on the horizon
## reads as morning.)
static func disc_direction(light: Vector3, hour: float) -> Vector3:
	var t := fmod(hour + 18.0, 12.0) / 12.0
	var k := smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.86, 1.0, t))
	var flat := Vector2(light.x, light.z)
	if flat.length() < 0.001:
		return light
	flat = flat.normalized()
	var elev := lerpf(deg_to_rad(-1.0), asin(clampf(light.y, -1.0, 1.0)), k)
	return Vector3(flat.x * cos(elev), sin(elev), flat.y * cos(elev))


## The sun below the horizon at night, for the twilight glow and the moon's
## lit side: under the western horizon after dusk, the eastern before dawn.
static func _below(moon: Vector3, hour: float) -> Vector3:
	var since := fposmod(hour - 18.0, 24.0) # 0 at dusk, 12 at dawn
	var elev := -deg_to_rad(15.0) * minf(since, 12.0 - since)
	var west := since < 6.0
	var bearing := Vector2(-0.94, 0.34) if west else Vector2(0.94, 0.34)
	return Vector3(bearing.x * cos(elev), sin(elev), bearing.y * cos(elev))


## Star visibility 0..1: none by day or under cloud, CITY_STARS in the
## brightest city centre, all of them under a dark sky; a bright moon high
## up washes out the faintest.
static func star_visibility(p: float, clouds: float, night: float, moonlight := 0.0) -> float:
	var dark := smoothstep(0.55, 0.95, night)
	var clear := 1.0 - smoothstep(0.15, 0.55, clouds)
	var through := lerpf(CITY_STARS, 1.0, pow(1.0 - clampf(p, 0.0, 1.0), 1.5))
	return dark * clear * through * (1.0 - 0.3 * moonlight)


## Light pollution overhead at a local point, 0 (dark sky) .. 1 (downtown).
static func pollution_at(p: Vector2) -> float:
	_load()
	var dark := 1.0
	for s in _sources:
		var r: Rect2 = s[0]
		var d := _rect_distance(r, p)
		if d > FALLOFF * 6.0:
			continue
		dark *= 1.0 - float(s[1]) * exp(-d / FALLOFF)
	return 1.0 - dark


## The glow of the lit places round a local point on its horizon:
## "total" (all of it), "around" (from the places the point is in or right
## next to, all round the horizon) and "lobes" (up to GLOW_LOBES Vector4s,
## brightest first: unit bearing x, z, strength, half width in radians), a
## dome over each lit place or cluster of them farther off.
static func glow_at(p: Vector2) -> Dictionary:
	_load()
	var total := 0.0
	var around := 0.0
	var parts: Array = []
	for s in _sources:
		var r: Rect2 = s[0]
		var d := _rect_distance(r, p)
		var radius := sqrt(r.get_area() / PI)
		var g: float = float(s[1]) * pow(radius / (radius + d), 1.5)
		if g < 0.002:
			continue
		total += g
		# In a place, or so near it fills half the horizon: all round.
		var inside := clampf(1.0 - d / maxf(radius * 0.5, 1.0), 0.0, 1.0)
		around += g * inside
		var to := r.get_center() - p
		if inside < 1.0 and to.length() > 1.0:
			parts.append([g * (1.0 - inside), to.normalized(), atan2(radius, maxf(d, 1.0))])
	parts.sort_custom(func(a, b): return a[0] > b[0])
	# Places on nearly the same bearing make one dome.
	var lobes: Array = [] # [strength, weighted bearing, half width]
	for part in parts:
		var best := -1
		var best_a := INF
		for i in lobes.size():
			var a := absf((lobes[i][1] as Vector2).angle_to(part[1]))
			if a < best_a:
				best_a = a
				best = i
		if best >= 0 and (best_a < maxf(lobes[best][2], 0.3) or lobes.size() >= GLOW_LOBES):
			lobes[best][0] += part[0]
			if best_a < maxf(lobes[best][2], 0.3):
				lobes[best][1] += part[1] * part[0]
				lobes[best][2] = maxf(lobes[best][2], minf(part[2], best_a + part[2]))
		else:
			lobes.append([part[0], part[1] * part[0], part[2]])
	var out: Array = []
	for l in lobes:
		var dir: Vector2 = (l[1] as Vector2).normalized()
		out.append(Vector4(dir.x, dir.y, l[0], l[2]))
	out.sort_custom(func(a, b): return a.z > b.z)
	return {"total": total, "around": around, "lobes": out}


## Whether `cam` frames any sky (its top edge above the horizon).
static func looks_at_sky(cam: Camera3D) -> bool:
	var fwd := -cam.global_transform.basis.z
	return asin(clampf(fwd.y, -1.0, 1.0)) + deg_to_rad(cam.fov) * 0.5 > -0.02


## A camera eye high at local `at` (on the ground there, Terrain heights
## included), facing bearing `yaw_deg` (0 north, 90 east) and `pitch_deg`
## up from the horizon: for Look up views and sky screenshots.
static func look_up_transform(at: Vector3, yaw_deg: float, pitch_deg: float, eye := 1.7) -> Transform3D:
	var ground: float = at.y
	var yaw := deg_to_rad(yaw_deg)
	var fwd := Vector3(sin(yaw) * cos(deg_to_rad(pitch_deg)), sin(deg_to_rad(pitch_deg)), -cos(yaw) * cos(deg_to_rad(pitch_deg)))
	var eye_pos := Vector3(at.x, ground + eye, at.z)
	return Transform3D.IDENTITY.translated(eye_pos).looking_at(eye_pos + fwd, Vector3.UP if absf(fwd.y) < 0.999 else Vector3(0, 0, -1))


## Points `cam` up at the sky from `at` (see look_up_transform) with a wide
## far plane, and turns on depth haze in `env` that fades the ground into
## the horizon colour where the streamed world ends (fog_on false turns it
## off again). Returns the transform it set.
static func look_up(cam: Camera3D, env: Environment, at: Vector3, yaw_deg: float, pitch_deg: float, fov := 70.0, fog_on := true) -> Transform3D:
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = fov
	cam.near = 0.3
	cam.far = 4000.0
	cam.global_transform = look_up_transform(at, yaw_deg, pitch_deg)
	horizon_haze(env, fog_on)
	return cam.global_transform


## Depth haze for low views: the ground fades to the sky's horizon colour
## from 140 to 420 m (the streamed world ends past that); the sky is left
## alone.
static func horizon_haze(env: Environment, on: bool) -> void:
	env.fog_enabled = on
	if not on:
		return
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_light_color = env.background_color
	env.fog_depth_begin = 140.0
	env.fog_depth_end = 420.0


func _sample(h: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var f: float = (h - a[0]) / maxf(b[0] - a[0], 0.001)
			return [(a[1] as Color).lerp(b[1], f), (a[2] as Color).lerp(b[2], f)]
	return [KEYS[0][1], KEYS[0][2]]


static func _rect_distance(r: Rect2, p: Vector2) -> float:
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return q.distance_to(p)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var world = JSON.parse_string(FileAccess.get_file_as_string(MAP_PATH))
	if not world is Dictionary:
		return
	var origin := Vector2.ZERO
	for c in world.cities:
		if c.id == CITY_ID and c.has("demo_window"):
			origin = Vector2(c.demo_window.origin[0], c.demo_window.origin[1])
	for c in world.cities:
		var scale := 1.0 if int(c.get("phase", 1)) <= 2 else FAR_CITY
		var cr: Array = c.rect
		_sources.append([Rect2(cr[0] - origin.x, cr[1] - origin.y, cr[2], cr[3]), CITY_LIGHT * scale])
		for d in c.districts:
			var dr: Array = d.rect
			var light: float = STYLE_LIGHT.get(d.style, 0.5)
			_sources.append([Rect2(dr[0] - origin.x, dr[1] - origin.y, dr[2], dr[3]), light * scale])
	for t in world.towns:
		if not TOWN_LIGHT.has(t.kind):
			continue
		var spec: Array = TOWN_LIGHT[t.kind]
		var r: float = spec[1]
		var c := Vector2(t.pos[0], t.pos[1]) - origin
		_sources.append([Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), float(spec[0])])
