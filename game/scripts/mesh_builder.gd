extends RefCounted
## Collects vertex-coloured geometry and bakes it into one ArrayMesh, so a whole
## district (or a whole car) draws in a single call with one shared material.

## Face normal, then two in-plane axes with u x v == normal.
const FACES := [
	[Vector3.RIGHT, Vector3.UP, Vector3.BACK],
	[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	[Vector3.UP, Vector3.BACK, Vector3.RIGHT],
	[Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP, Vector3.RIGHT],
]

static var _material: StandardMaterial3D
static var _gloss_material: StandardMaterial3D
static var _xray_materials := {}
static var _cutaway_material: ShaderMaterial
static var _water_material: ShaderMaterial

## Vertex alpha is a surface code, in sixteenths (the city has no real
## lights; lamps, windows and signs light themselves in the shader):
## GLOW_WINDOW windows lit at night, GLOW_LAMP lamp heads, GLOW_NEON signs that
## glow a little by day and fully at night. The rest set the material:
## GLASS reflects the sky and glints (some panels lit at night), GLOSS is
## painted metal or plastic, METAL bare metal, ASPHALT and CONCRETE get
## their grain, cracks and stains (asphalt ages with its shade: near-black
## fresh asphalt is smooth, grey has some patches and cracks, pale washed-out
## asphalt many). Anything else (alpha 1) is matte.
const GLOW_WINDOW := 0.25
const GLOW_LAMP := 0.5
const GLOW_NEON := 0.75
const GLASS := 0.125
const GLOSS := 0.875
const METAL := 0.9375
const ASPHALT := 0.0625
const CONCRETE := 0.1875
## Patterned surfaces, drawn along the mesh's pattern coordinates (uvs):
## PAVING plaza pavers, ROOF membrane with seams, GRASS mown lawn, SOLAR
## panels, SIDING lap boards, SEAM_ROOF standing-seam metal, BRICK.
const PAVING := 0.3125
const ROOF := 0.375
const GRASS := 0.4375
const SOLAR := 0.5625
const SIDING := 0.625
const SEAM_ROOF := 0.6875
const BRICK := 0.8125

## Shared shader code: grain noise, wet ground and the glow codes. The
## globals `night`, `wet` and `sky_tint` are set by Atmosphere.
const SURFACE_COMMON := """
global uniform float night;
global uniform float wet;
global uniform vec4 sky_tint;
global uniform float detail;
global uniform vec4 sky_zenith;

// Sine-free hash: cheap on mobile GPUs.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Grain so flat colours read as stone, asphalt and plaster; wet ground with
// puddles that mirror the sky; emission for the glow codes; roughness and
// sheen for the material codes (alpha in sixteenths, see MeshBuilder).
// Anti-aliasing (HANDOFF-shimmer.md): there are no textures to mipmap, so
// every pattern below is filtered by the pixel's footprint (fwidth, metres
// per pixel). Detail `size` metres across keeps its full contrast while it
// spans a few pixels and fades to its average as it nears one, so fine grain,
// bricks and joints don't crawl and sparkle as the camera moves.
float fine(float fw, float size) {
	return 1.0 - smoothstep(0.3, 0.8, fw / size);
}

// Lines `w` wide, `period` apart along x, box-filtered over the footprint
// `fw`: a line thinner than a pixel is drawn a pixel wide at the share of
// it that it covers, and once the lines are about a pixel apart they blend
// to their average. 0..1.
float aa_line(float x, float period, float w, float fw) {
	float f = abs(fract(x / period + 0.5) - 0.5) * period;
	fw = max(fw, 0.0001);
	float edge = max(fw, w * 0.33);
	float half_w = max(w, fw) * 0.5;
	float l = min(w / fw, 1.0) * (1.0 - smoothstep(half_w - edge * 0.5, half_w + edge * 0.5, f));
	return mix(l, w / period, smoothstep(period * 0.25, period * 0.5, fw));
}

// Dark joint lines on a grid of `cell` (about 1.5 `w` wide); `fw` is the
// footprint of p (fwidth).
float joints(vec2 p, vec2 cell, float w, vec2 fw) {
	float x = aa_line(p.x, cell.x, w * 1.5, fw.x);
	float y = aa_line(p.y, cell.y, w * 1.5, fw.y);
	return 1.0 - (1.0 - x) * (1.0 - y);
}

// Patterns along the pattern coordinates uv (see MeshBuilder.uvs); fwu is
// the footprint of uv and fwp of wpos (metres per pixel).
vec3 pattern(int c, vec3 col, vec2 uv, vec3 wpos, vec3 wnormal, vec2 fwu, float fwp, inout float rough, inout float spec) {
	if (c == 3) {
		col *= 1.0 - 0.28 * joints(uv, vec2(1.5), 0.05, fwu);
	} else if (c == 5) {
		vec2 b = uv / vec2(0.6, 0.3);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		col *= mix(0.98, 0.88 + 0.2 * hash(floor(b) + 7.0), fine(max(fwu.x / 0.6, fwu.y / 0.3), 1.0));
		col *= 1.0 - 0.3 * joints(b * vec2(0.6, 0.3), vec2(0.6, 0.3), 0.025, fwu);
	} else if (c == 6) {
		col *= 0.95 + 0.07 * hash(vec2(floor(uv.x / 1.0), 3.0));
		col *= 1.0 - 0.18 * (1.0 - aa_line(uv.x, 1.0, 0.04, fwu.x));
		col *= mix(0.88, 1.0, vnoise(uv * 0.7));
	} else if (c == 7 && wpos.y > 0.7) {
		// Foliage off the ground: leaf clusters with dark gaps and sunlit
		// tips on the upper side.
		float leaf = vnoise(wpos.xz * 2.6 + wpos.y * 2.1) * 0.55 + mix(0.5, vnoise(wpos.xz * 6.5 - wpos.y * 4.3), fine(fwp, 0.15)) * 0.45;
		col *= 0.5 + 0.7 * leaf;
		col += col * 0.4 * smoothstep(0.66, 0.86, leaf) * clamp(wnormal.y, 0.0, 1.0);
		rough = 0.95;
		spec = 0.12;
	} else if (c == 7) {
		col *= 0.93 + 0.12 * step(0.5, fract(uv.x / 4.0));
		col *= 0.85 + 0.25 * vnoise(wpos.xz * 1.7);
	} else if (c == 9) {
		// Cells 16 cm square (dark 2.6 cm gaps).
		col *= 1.0 - 0.25 * joints(uv, vec2(0.16), 0.017, fwu);
		// Module frames every metre along the row; rows end at the geometry.
		col = mix(col, vec3(0.75, 0.77, 0.8), aa_line(uv.x, 1.0, 0.05, fwu.x));
		rough = 0.3;
		spec = 0.5;
	} else if (c == 10) {
		float lap = fract(uv.y / 0.22);
		col *= 0.86 + 0.14 * mix(0.575, smoothstep(0.0, 0.85, lap), fine(fwu.y, 0.22));
	} else if (c == 11) {
		col *= 1.0 - 0.22 * (1.0 - aa_line(uv.x, 0.5, 0.045, fwu.x));
		rough = 0.35;
		spec = 0.6;
	} else if (c == 13) {
		vec2 b = uv / vec2(0.24, 0.08);
		b.x += step(1.0, mod(floor(b.y), 2.0)) * 0.5;
		col *= mix(0.975, 0.85 + 0.25 * hash(floor(b) + 3.0), fine(max(fwu.x / 0.24, fwu.y / 0.08), 1.0));
		col = mix(col, vec3(0.78, 0.76, 0.72), joints(b * vec2(0.24, 0.08), vec2(0.24, 0.08), 0.014, fwu) * 0.6);
	}
	return col;
}

void surface(vec3 base, float code, vec3 wpos, vec3 wnormal, vec3 view_dir, vec2 uv, float time, out vec3 albedo, out vec3 emission, out float rough, out float spec, out float metal) {
	int c = int(code * 16.0 + 0.5);
	vec3 col = base;
	rough = 0.9;
	spec = 0.25;
	metal = 0.0;
	// Footprints for the filtering (taken here, outside any branch).
	vec2 fwu = fwidth(uv);
	vec3 fw3 = fwidth(wpos);
	float fwp = max(max(fw3.x, fw3.y), fw3.z);
	if (detail > 0.5) {
		col = pattern(c, col, uv, wpos, wnormal, fwu, fwp, rough, spec);
	} else if (c == 9) {
		rough = 0.3;
		spec = 0.5;
	}
	if (detail > 0.5) {
		float grain = vnoise(wpos.xz * 2.1 + wpos.y * 1.7) * 0.7 + vnoise(wpos.xz * 0.3 + wpos.y * 0.2) * 0.3;
		col *= 0.94 + 0.08 * grain;
		if (c == 1) {
			// Asphalt: fine aggregate, darker patched squares, sealed cracks.
			// Its age is its shade (see MeshBuilder.ASPHALT): fresh black
			// asphalt (wear 0) has no patches or cracks, the usual grey
			// (wear 1) some, washed-out pale asphalt (2) many, and deep.
			float wear = clamp((dot(base, vec3(0.3333)) - 0.17) * 9.375, 0.0, 2.2);
			col *= mix(1.0, 0.9 + 0.2 * hash(floor(wpos.xz * 9.0)), fine(fwp, 0.111));
			vec2 pc = floor(wpos.xz / 3.5);
			float patch = step(1.0 - 0.04 * wear, hash(pc + 17.0));
			col = mix(col, col * 0.86, patch);
			// Sealed cracks: hairlines along the noise's zero line, drawn at
			// least a pixel wide and as faint as the share they cover
			// (the crack value climbs about 1.6 per metre across one).
			float crack = abs(vnoise(wpos.xz * 0.55) * 2.0 - 1.0);
			float lw = max(0.012 * wear, 0.0001);
			float edge = max(lw, fwp * 1.6);
			float line = (1.0 - smoothstep(0.0, edge, crack)) * lw / edge;
			// Where the coarse mask is on, the cracks show as lines of the
			// plain colour on asphalt a fifth brighter.
			bool masked = vnoise(wpos.xz * 0.09 + 3.0) >= 0.22 * wear;
			col *= masked ? 1.2 - 0.2 * line : 1.0 - 0.2 * line * min(wear, 1.6);
		} else if (c == 3) {
			// Concrete: speckle and the odd stain.
			col *= mix(0.99, 0.94 + 0.1 * hash(floor(wpos.xz * 14.0)), fine(fwp, 0.071));
			col *= mix(0.93, 1.0, smoothstep(0.6, 0.8, 1.0 - vnoise(wpos.xz * 0.45 + 9.0)));
		}
	}
	if (c == 1) {
		rough = 0.85;
		spec = 0.3;
	} else if (c == 2 || c == 4) {
		// Glass, and windows by day: dark tint mirroring the sky above the
		// horizon and the street below it, brighter at grazing angles.
		vec3 r = reflect(-view_dir, wnormal);
		vec3 sky = mix(sky_tint.rgb * 1.05, vec3(0.75, 0.82, 0.9), 0.35) * mix(1.0, 0.18, night);
		vec3 street = mix(base, vec3(0.42, 0.42, 0.44), 0.7) * mix(1.0, 0.3, night);
		vec3 refl = mix(street, sky, smoothstep(-0.15, 0.35, r.y));
		float fres = pow(1.0 - clamp(dot(view_dir, wnormal), 0.0, 1.0), 3.0);
		col = mix(base * 0.55, refl, 0.55 + 0.4 * fres);
		rough = 0.08;
		spec = 0.9;
		metal = 0.25;
	} else if (c == 14) {
		// Pools, ponds and glossy tops mirror the sky overhead.
		float sky_k = smoothstep(0.85, 1.0, wnormal.y) * (0.2 + 0.4 * pow(1.0 - clamp(dot(view_dir, wnormal), 0.0, 1.0), 2.0));
		col = mix(col, mix(sky_tint.rgb, sky_zenith.rgb, 0.6) * mix(1.0, 0.3, night), sky_k);
		rough = 0.28;
		spec = 0.6;
	} else if (c == 15) {
		// Brushed steel: there are no reflection probes, so fake a soft
		// sky-and-street reflection, or metal reads near black.
		vec3 r = reflect(-view_dir, wnormal);
		vec3 env = mix(vec3(0.42, 0.42, 0.44), mix(sky_tint.rgb, vec3(0.8, 0.84, 0.9), 0.4), smoothstep(-0.2, 0.5, r.y)) * mix(1.0, 0.25, night);
		col = mix(col, env, 0.4);
		rough = 0.4;
		spec = 0.7;
		metal = 0.3;
	}
	if (wet > 0.01 && wnormal.y > 0.9 && wpos.y < 0.35 && detail < 0.5) {
		col *= mix(1.0, 0.7, wet);
	} else if (wet > 0.01 && wnormal.y > 0.9 && wpos.y < 0.35) {
		float puddle = smoothstep(0.62, 0.74, vnoise(wpos.xz * 0.16) * 0.7 + vnoise(wpos.xz * 0.8) * 0.3);
		col *= mix(1.0, 0.6, wet);
		vec2 cell = floor(wpos.xz * 0.7);
		vec2 local = fract(wpos.xz * 0.7) - 0.5;
		float t = fract(time * 1.3 + hash(cell));
		float ring = smoothstep(0.03, 0.0, abs(length(local) - t * 0.45)) * (1.0 - t) * step(0.7, hash(cell + floor(time * 1.3 + hash(cell))));
		col = mix(col, mix(sky_tint.rgb, sky_zenith.rgb, 0.5) * mix(0.9, 0.35, night), puddle * wet * 0.5);
		col += vec3(ring * puddle * wet * 0.25);
		rough = mix(rough, 0.15, wet * (0.4 + 0.6 * puddle));
		spec = mix(spec, 0.8, wet);
	}
	emission = vec3(0.0);
	if (c == 4) {
		col = mix(col, col * 0.5, night);
		emission = mix(col, vec3(1.0, 0.78, 0.45), 0.7) * night * 1.3;
	} else if (c == 8) {
		emission = base * night * 1.2;
	} else if (c == 12) {
		emission = base * mix(0.35, 2.0, night);
	} else if (c == 2) {
		// Offices and flats behind the glass: a few panels lit after dark.
		// Only upper-storey walls: not shelters, skylights or screens.
		vec2 pane = floor(vec2(wpos.x + wpos.z, wpos.y) / vec2(2.2, 3.4));
		float lit = step(0.62, hash(pane + 5.0)) * step(abs(wnormal.y), 0.3) * step(3.0, wpos.y);
		emission = mix(vec3(1.0, 0.86, 0.62), vec3(0.75, 0.88, 1.0), hash(pane)) * lit * night * 0.9;
	}
	albedo = col;
}
"""

## City shader: the same toon look as material(), plus a dissolving hole in
## anything standing between the camera and the player, so buildings never
## hide what happens around them. The camera updates the uniforms each frame.
const CUTAWAY_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include_common

uniform vec3 focus = vec3(0.0);
uniform vec3 cam_back = vec3(0.0, 0.0, 1.0);
// The perspective camera's position; with cone 1 the hole narrows toward
// it, so it stays the same size on screen at every depth.
uniform vec3 eye = vec3(0.0, 100.0, 60.0);
uniform float cone = 0.0;
uniform float cut_radius = 7.0;
// Always open, whatever the colliders say: anything drawn with this
// material that stands right in front of the player (an awning, a parasol,
// a porch roof) turns to a ghost over them, so the hero is never hidden.
uniform float body_radius = 0.0;
// Perspective only: anything nearer the camera than this dissolves, so a
// tower the low camera passes through fades out instead of popping.
uniform float near_fade = 0.0;
// The ground the player needs to see: a band `view_radius` wide round the
// player (focus, 1 m up) and out along `ahead` (where they are heading).
// Any part of a building that hides more than HIDE_MIN metres of that ground
// turns to a see-through ghost (GHOST), so tall buildings there keep their
// shape while the street shows through (HANDOFF-perspective-camera.md). 0 turns it off. Ground
// (terrain and roads, marked by UV2.x 1, see mark_ground) is never cut, so a
// hill ahead stays whole. No cut reaches the shadow pass: buildings keep
// their whole shadows.
uniform float view_radius = 0.0;
uniform vec3 ahead = vec3(0.0);
const float HIDE_MIN = 4.0;
// What the band and the player hole leave of a building: a pale see-through
// ghost of this share of its pixels, so its shape stays and the street
// shows through (E-4). The near fade still cuts fully.
const float GHOST = 0.3;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	float rough;
	float spec;
	float metal;
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	surface(COLOR.rgb, COLOR.a, world_pos, world_normal, view_dir, UV, TIME, albedo, emission, rough, spec, metal);
	ALBEDO = albedo;
	EMISSION = emission;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = metal;
	vec3 rel = world_pos - focus;
	vec3 to_eye = eye - focus;
	float reach = length(to_eye);
	vec3 axis = normalize(mix(cam_back, to_eye / reach, cone));
	float t = dot(rel, axis);
	float keep = 1.0;
	if (world_pos.y > 0.4 && t > 1.0) {
		float shrink = mix(1.0, max((reach - t) / reach, 0.05), cone);
		float d = length(rel - axis * t) / (max(cut_radius, body_radius) * shrink);
		keep = smoothstep(0.7, 1.0, d);
	}
	if (view_radius > 0.0 && world_pos.y > focus.y && UV2.x < 0.5) {
		vec3 ray = cone > 0.5 ? normalize(world_pos - eye) : -cam_back;
		if (ray.y < -0.05) {
			// Where this point's line of sight meets the player's ground.
			float s = (focus.y - 1.0 - world_pos.y) / ray.y;
			vec3 hidden = world_pos + ray * s;
			float hides = length(hidden.xz - world_pos.xz);
			vec2 pa = hidden.xz - focus.xz;
			float h = clamp(dot(pa, ahead.xz) / max(dot(ahead.xz, ahead.xz), 0.0001), 0.0, 1.0);
			float dc = length(pa - ahead.xz * h) / view_radius;
			keep = min(keep, max(smoothstep(0.9, 1.0, dc), 1.0 - smoothstep(HIDE_MIN, HIDE_MIN + 1.0, hides)));
		}
	}
	float see_through = 1.0 - keep;
	keep = mix(GHOST, 1.0, keep);
	if (see_through > 0.0) {
		ALBEDO = mix(ALBEDO, vec3(0.82, 0.86, 0.92), see_through * 0.45);
		EMISSION *= 1.0 - see_through * 0.6;
	}
	if (near_fade > 0.0) {
		keep = min(keep, smoothstep(near_fade * 0.35, near_fade, distance(world_pos, eye)));
	}
	if (keep < 1.0 && !IN_SHADOW_PASS) {
		// An ordered 4x4 dither: an even screen-door edge, not speckle.
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int i = p.x + p.y * 4;
		float bayer = float((i == 0 ? 0 : i == 1 ? 8 : i == 2 ? 2 : i == 3 ? 10 : i == 4 ? 12 : i == 5 ? 4 : i == 6 ? 14 : i == 7 ? 6 : i == 8 ? 3 : i == 9 ? 11 : i == 10 ? 1 : i == 11 ? 9 : i == 12 ? 15 : i == 13 ? 7 : i == 14 ? 13 : 5)) / 16.0 + 0.03125;
		if (bayer > keep) {
			discard;
		}
	}
}
"""

## River and harbour water: the vertex colour with drifting light glints, the
## classic top-down way of showing a current. Rain roughens it; at night the
## glints fade and lamp light streaks across it.
const WATER_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

global uniform float night;
global uniform float wet;
global uniform vec4 sky_tint;
global uniform vec4 sky_zenith;
global uniform float stars;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// River water: rolling ripples tilt the normal, the sky shows in it more at
// grazing angles, and the sun and lamps glint off the crests.
void fragment() {
	vec2 p = world_pos.xz;
	float a = sin(p.x * 0.35 + TIME * 1.2 + sin(p.y * 0.21 + TIME * 0.7) * 2.0);
	float b = sin(p.y * 0.5 - TIME * 0.9 + sin(p.x * 0.17) * 1.5);
	float c = sin(p.x * 1.7 + p.y * 0.6 + TIME * 2.3) * sin(p.y * 1.9 - p.x * 0.4 - TIME * 1.8);
	float glint = smoothstep(0.6, 0.95, a * b) * smoothstep(0.55, 0.9, c);
	float drops = smoothstep(0.92, 1.0, sin(p.x * 3.1 + TIME * 7.0) * sin(p.y * 2.7 - TIME * 6.0)) * wet;
	vec3 wn = normalize(vec3(a * 0.06 + c * 0.04, 1.0, b * 0.06 - c * 0.03));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fres = pow(1.0 - clamp(dot(view_dir, wn), 0.0, 1.0), 4.0);
	// The sky it mirrors: the zenith overhead (Sky), paler toward the horizon;
	// at night the stars the sky shows, broken up by the ripples.
	vec3 rd = reflect(-view_dir, wn);
	vec3 sky = mix(sky_tint.rgb * mix(1.0, 0.25, night), sky_zenith.rgb, smoothstep(0.3, 1.0, rd.y) * 0.5);
	vec2 sc = rd.xz / max(rd.y, 0.25) * 70.0;
	float st = step(0.985, fract(sin(dot(floor(sc), vec2(127.1, 311.7))) * 43758.55)) * smoothstep(0.32, 0.0, length(fract(sc) - 0.5)) * stars;
	ALBEDO = mix(COLOR.rgb * 0.85, sky, 0.25 + 0.5 * fres) + vec3(0.22, 0.28, 0.28) * glint * (1.0 - night * 0.6) + vec3(0.2) * drops;
	EMISSION = vec3(1.0, 0.8, 0.45) * glint * night * 0.25 + vec3(0.85, 0.9, 1.0) * st * (1.0 - wet) * 0.9;
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
}
"""

## Additive light on the ground after dark: lamp pools and headlight beams.
## Vertex colour is the light; it fades to black at the rim.
const GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

global uniform float night;
global uniform float wet;

void fragment() {
	ALBEDO = COLOR.rgb * night * (0.75 + 0.5 * wet);
}
"""

static var _glow_material: ShaderMaterial

## GLOW_SHADER laid on the ground: each vertex drops (or rises) to the
## ground's height under it plus GROUND_LIFT, read from the hills' height
## grid (terrain.gd sets terrain_dm and terrain_grid). A flat beam on a car
## that climbs a hill would otherwise sink under the road ahead (4% up is
## enough to hide a 13 m beam 5 cm off the ground). Roads on the hills cut
## 4 m chords a few centimetres under the curve and their markings sit
## 5 cm up, so 10 cm clears both.
const GROUND_GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

global uniform float night;
global uniform float wet;
global uniform sampler2D terrain_dm : filter_nearest;
global uniform vec4 terrain_grid;

const float GROUND_LIFT = 0.1;

float height_at(ivec2 i) {
	vec2 t = texelFetch(terrain_dm, i, 0).rg;
	return (t.r * 255.0 + t.g * 65280.0) * 0.1;
}

float ground(vec2 p) {
	if (terrain_grid.z <= 0.0) {
		return 0.0;
	}
	ivec2 n = textureSize(terrain_dm, 0);
	vec2 uv = (p - terrain_grid.xy) / terrain_grid.z;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= float(n.x - 1) || uv.y >= float(n.y - 1)) {
		return 0.0;
	}
	ivec2 i = ivec2(floor(uv));
	vec2 f = uv - vec2(i);
	float a = mix(height_at(i), height_at(i + ivec2(1, 0)), f.x);
	float b = mix(height_at(i + ivec2(0, 1)), height_at(i + ivec2(1, 1)), f.x);
	return mix(a, b, f.y);
}

void vertex() {
	VERTEX.y = ground(VERTEX.xz) + GROUND_LIFT;
}

void fragment() {
	ALBEDO = COLOR.rgb * night * (0.75 + 0.5 * wet);
}
"""

static var _ground_glow_material: ShaderMaterial

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
## Pattern coordinates: the point in the space it was built in (before
## xform), on the ground plane for flat faces and (along, up) on walls, so
## paving, joints, seams and siding line up with what they are drawn on.
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
## Vertex ranges [start, end) of ground (terrain, roads): commit marks them
## with UV2.x 1, so the cutaway's view band leaves them whole.
var ground_ranges := PackedInt32Array()
## Placement applied to everything added; asset kits build in local space and
## the caller sets this to position and rotate them (rotation and translation
## only, so winding and normals stay valid).
var xform := Transform3D.IDENTITY
## [first vertex, bone] marks set by set_bone(): every vertex from the mark on
## is bound fully to that bone (rigid skinning, for code-built characters).
var _bone_marks: Array = []
## [first vertex, bones, weights] from skin(): vertices from the first on take
## 4 bones and 4 weights each from the arrays, over the rigid marks.
var _skins: Array = []
## [first index, LOD] marks set by set_lod(): which detail levels the
## triangles from the mark on are in (LOD_BOTH, LOD_NEAR or LOD_FAR).
var _lod_marks: Array = []
## The far detail level's key in the mesh's LOD table (commit()); Godot uses
## it from about 30 m for a person.
var far_lod := 0.2
## [first vertex, tag] marks set by set_tag(): kits name what they add
## (tag_ranges() gives the vertex ranges back), so a later pass can move it.
var _tag_marks: Array = []
const LOD_BOTH := 0
const LOD_NEAR := 1
const LOD_FAR := 2


## Where the arrays end now; rollback() cuts them back to it (undoing
## everything added since).
func mark() -> Array:
	return [verts.size(), indices.size()]


func rollback(m: Array) -> void:
	verts.resize(m[0])
	normals.resize(m[0])
	colors.resize(m[0])
	uvs.resize(m[0])
	indices.resize(m[1])


## Binds everything added from now on to skeleton bone `bone`.
func set_bone(bone: int) -> void:
	_bone_marks.append([verts.size(), bone])


## Skins the vertices from `first` on: four bones and four weights each.
func skin(first: int, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	_skins.append([first, bones, weights])


## Puts the triangles added from now on in detail level `lod` (LOD_BOTH,
## LOD_NEAR or LOD_FAR); the mesh switches to the far level at distance.
func set_lod(lod: int) -> void:
	_lod_marks.append([indices.size(), lod])


## Tags everything added from now on with `tag` ("" for none).
func set_tag(tag: String) -> void:
	_tag_marks.append([verts.size(), tag])


## Vertex ranges [start, end) tagged `tag`, flat.
func tag_ranges(tag: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in _tag_marks.size():
		if _tag_marks[k][1] == tag:
			out.append(_tag_marks[k][0])
			out.append(verts.size() if k == _tag_marks.size() - 1 else _tag_marks[k + 1][0])
	return out


## The near and far index lists from the LOD marks: [near, far]. Without
## marks both are the whole index list.
func lod_indices() -> Array:
	if _lod_marks.is_empty():
		return [indices, indices]
	var near := PackedInt32Array()
	var far := PackedInt32Array()
	var start := 0
	var lod := LOD_BOTH
	for k in _lod_marks.size() + 1:
		var end: int = indices.size() if k == _lod_marks.size() else _lod_marks[k][0]
		if end > start:
			var part := indices.slice(start, end)
			if lod != LOD_FAR:
				near.append_array(part)
			if lod != LOD_NEAR:
				far.append_array(part)
		if k < _lod_marks.size():
			start = end
			lod = _lod_marks[k][1]
	return [near, far]


## The toon material every baked mesh uses; colour comes from the vertices.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		_material.roughness = 0.62
		_material.metallic_specular = 0.35
	return _material


## Glossy material for car glass and paint shells: vertex colour, sharp
## highlights.
static func gloss_material() -> StandardMaterial3D:
	if _gloss_material == null:
		_gloss_material = StandardMaterial3D.new()
		_gloss_material.vertex_color_use_as_albedo = true
		_gloss_material.vertex_color_is_srgb = true
		_gloss_material.roughness = 0.16
		_gloss_material.metallic = 0.15
		_gloss_material.metallic_specular = 0.8
	return _gloss_material


## The same material, drawn as a flat silhouette in `color` wherever the mesh
## is hidden behind buildings: yellow for the player, blue for police, red for
## anyone attacking. Stencil x-ray marks the mesh's own pixels first, so parts
## hidden by other parts of the same mesh are not tinted.
static func xray_material(color := Color(1.0, 0.85, 0.25, 0.6)) -> StandardMaterial3D:
	if not _xray_materials.has(color):
		var mat: StandardMaterial3D = material().duplicate()
		mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		mat.stencil_color = color
		_xray_materials[color] = mat
	return _xray_materials[color]


static var _burnt: ShaderMaterial

## A burnt-out shell, as real ones look once the fire is out: the paint gone
## to bare steel, ash grey with rust-brown blooms, soot streaked over it and
## gathered low on the panels and in the arches; glass gone to a dark cabin;
## tyres, trim and seats charred. Patches follow the car (model space).
const BURNT_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
varying vec3 p;
varying vec3 n;
void vertex() {
	p = VERTEX;
	n = NORMAL;
}
float bhash(vec3 q) {
	q = fract(q * 0.3183099 + 0.1);
	q *= 17.0;
	return fract(q.x * q.y * q.z * (q.x + q.y + q.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(bhash(i), bhash(i + vec3(1, 0, 0)), f.x),
			mix(bhash(i + vec3(0, 1, 0)), bhash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(bhash(i + vec3(0, 0, 1)), bhash(i + vec3(1, 0, 1)), f.x),
			mix(bhash(i + vec3(0, 1, 1)), bhash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void fragment() {
	vec3 src = COLOR.rgb;
	float lum = dot(src, vec3(0.3, 0.59, 0.11));
	float big = vnoise(p * 1.6) * 0.65 + vnoise(p * 4.1) * 0.35;
	float fine = vnoise(p * 11.0);
	vec3 ash = vec3(0.56, 0.54, 0.5);
	vec3 rust = vec3(0.5, 0.29, 0.16);
	vec3 soot = vec3(0.13, 0.12, 0.11);
	vec3 c = mix(ash, rust, smoothstep(0.42, 0.68, big));
	c = mix(c, ash * 1.12, smoothstep(0.7, 0.9, fine) * 0.5);
	// Soot streaks, heavier low on the body and on the sides than the top.
	float low = 1.0 - smoothstep(0.25, 0.9, p.y);
	float side = 1.0 - abs(normalize(n).y);
	float streak = smoothstep(0.45, 0.75, vnoise(vec3(p.x * 3.0, p.y * 0.8, p.z * 3.0)));
	c = mix(c, soot, clamp(low * 0.4 + side * streak * 0.35, 0.0, 0.6));
	// Glass (VehicleKit.GLASS) is gone: the cabin shows dark and sooty.
	float glass = 1.0 - smoothstep(0.02, 0.06, distance(src, vec3(0.15, 0.19, 0.25)));
	// Black parts (tyres, trim, the dash) burn to char.
	float dark = 1.0 - smoothstep(0.06, 0.13, lum);
	c = mix(c, soot * (0.8 + fine * 0.6), max(glass * 0.9, dark * 0.75));
	ALBEDO = c;
	ROUGHNESS = 0.92;
	METALLIC = 0.15;
	SPECULAR = 0.3;
}
"""


static func burnt_material() -> ShaderMaterial:
	if _burnt == null:
		var shader := Shader.new()
		shader.code = BURNT_SHADER
		_burnt = ShaderMaterial.new()
		_burnt.shader = shader
	return _burnt


static func cutaway_material() -> ShaderMaterial:
	if _cutaway_material == null:
		var shader := Shader.new()
		shader.code = CUTAWAY_SHADER.replace("#include_common", SURFACE_COMMON)
		_cutaway_material = ShaderMaterial.new()
		_cutaway_material.shader = shader
	return _cutaway_material


static func water_material() -> ShaderMaterial:
	if _water_material == null:
		var shader := Shader.new()
		shader.code = WATER_SHADER
		_water_material = ShaderMaterial.new()
		_water_material.shader = shader
	return _water_material


static func glow_material() -> ShaderMaterial:
	if _glow_material == null:
		var shader := Shader.new()
		shader.code = GLOW_SHADER
		_glow_material = ShaderMaterial.new()
		_glow_material.shader = shader
	return _glow_material


## The glow for light cast on the ground by something that moves over the
## hills (headlight beams): each vertex sits on the ground under it.
static func ground_glow_material() -> ShaderMaterial:
	if _ground_glow_material == null:
		var shader := Shader.new()
		shader.code = GROUND_GLOW_SHADER
		_ground_glow_material = ShaderMaterial.new()
		_ground_glow_material.shader = shader
	return _ground_glow_material


## `color` marked with a surface code (see GLOW_WINDOW and friends).
static func glow(color: Color, code: float) -> Color:
	return Color(color.r, color.g, color.b, code)


## A soft disc of light on the ground (bright centre fading to nothing at
## the rim) for the additive glow material.
func light_pool(center: Vector3, radius: Vector2, color: Color, sides := 10) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var base := verts.size()
		for p in [center, center + Vector3(cos(a0) * radius.x, 0, sin(a0) * radius.y), center + Vector3(cos(a1) * radius.x, 0, sin(a1) * radius.y)]:
			verts.append(xform * p)
			normals.append(Vector3.UP)
			uvs.append(Vector2.ZERO)
		colors.append_array([color, Color.BLACK, Color.BLACK])
		indices.append_array([base, base + 2, base + 1])


## A beam of light on the ground from `from` along `dir` (headlights), in
## `pieces` lengths so that, drawn with ground_glow_material, it can bend
## over the hills.
func light_beam(from: Vector3, dir: Vector3, length: float, spread: float, color: Color, pieces := 1) -> void:
	var side := Vector3(-dir.z, 0, dir.x)
	var base := verts.size()
	for k in pieces + 1:
		var t := float(k) / pieces
		var half := lerpf(0.3, spread, t)
		var at := from + dir * length * t
		for p in [at - side * half, at + side * half]:
			verts.append(xform * p)
			normals.append(Vector3.UP)
			uvs.append(Vector2.ZERO)
		var c := color.lerp(Color.BLACK, t)
		colors.append_array([c, c])
	for k in pieces:
		var i := base + k * 2
		indices.append_array([i, i + 3, i + 1, i, i + 2, i + 3])


## Thinner than this, a box is drawn as its two broad faces only (one face if
## it lies flat), which keeps window, shutter and road-marking details cheap.
const THIN := 0.1


func box(center: Vector3, size: Vector3, color: Color, skip_bottom := true) -> void:
	var half := size * 0.5
	var thin_axis := -1
	var smallest := minf(size.x, minf(size.y, size.z))
	if smallest <= THIN:
		thin_axis = 1 if size.y == smallest else (0 if size.x == smallest else 2)
	for face in FACES:
		var n: Vector3 = face[0]
		if skip_bottom and n == Vector3.DOWN:
			continue # never seen from the top-down camera
		if thin_axis >= 0 and absf(n[thin_axis]) < 0.5:
			continue # edge of a thin panel
		if thin_axis == 1 and n == Vector3.DOWN:
			continue
		var u: Vector3 = face[1] * half.dot(face[1].abs())
		var v: Vector3 = face[2] * half.dot(face[2].abs())
		var c: Vector3 = center + n * half.dot(n.abs())
		var base := verts.size()
		for p in [c - u - v, c + u - v, c + u + v, c - u + v]:
			verts.append(xform * p)
			normals.append(xform.basis * n)
			colors.append(color)
			uvs.append(_uv(p, n))
		# Godot treats clockwise triangles as front-facing.
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


## One triangle facing `n` (local space); the winding is fixed up to match.
func tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	var base := verts.size()
	for p in [a, b, c]:
		verts.append(xform * p)
		normals.append((xform.basis * n).normalized())
		colors.append(color)
		uvs.append(_uv(p, n))
	indices.append_array([base, base + 1, base + 2])


static func _uv(p: Vector3, n: Vector3) -> Vector2:
	if absf(n.y) > 0.7:
		return Vector2(p.x, p.z)
	var t := Vector3(-n.z, 0.0, n.x).normalized()
	return Vector2(p.dot(t), p.y)


## A flat quad through four corners (in order around its edge) facing `n`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	tri(a, b, c, n, color)
	tri(a, c, d, n, color)


## A gable roof: a triangular prism whose ridge runs along local X.
func gable(center: Vector3, size: Vector3, color: Color, end_color: Color) -> void:
	var h := size * 0.5
	var y0 := center.y - h.y
	var y1 := center.y + h.y
	var x0 := center.x - h.x
	var x1 := center.x + h.x
	var zf := center.z - h.z
	var zb := center.z + h.z
	var zc := center.z
	var front_n := Vector3(0, h.z, -size.y).normalized()
	var back_n := Vector3(0, h.z, size.y).normalized()
	tri(Vector3(x0, y0, zf), Vector3(x1, y0, zf), Vector3(x1, y1, zc), front_n, color)
	tri(Vector3(x0, y0, zf), Vector3(x1, y1, zc), Vector3(x0, y1, zc), front_n, color)
	tri(Vector3(x0, y0, zb), Vector3(x1, y1, zc), Vector3(x1, y0, zb), back_n, color)
	tri(Vector3(x0, y0, zb), Vector3(x0, y1, zc), Vector3(x1, y1, zc), back_n, color)
	tri(Vector3(x0, y0, zf), Vector3(x0, y1, zc), Vector3(x0, y0, zb), Vector3.LEFT, end_color)
	tri(Vector3(x1, y0, zf), Vector3(x1, y0, zb), Vector3(x1, y1, zc), Vector3.RIGHT, end_color)


## A low-poly upright cylinder (posts, trunks, tanks), base at `base`.
func cylinder(base: Vector3, radius: float, height: float, color: Color, sides := 6) -> void:
	var top_c := base + Vector3(0, height, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var n := ((d0 + d1) * 0.5).normalized()
		var p0 := base + d0 * radius
		var p1 := base + d1 * radius
		tri(p0, p1, p1 + Vector3(0, height, 0), n, color)
		tri(p0, p1 + Vector3(0, height, 0), p0 + Vector3(0, height, 0), n, color)
		tri(top_c, top_c + d0 * radius, top_c + d1 * radius, Vector3.UP, color)


## A low-poly blob (tree crowns, heads): a faceted ball with `sides`
## segments around and `rings` from top to bottom.
func ball(center: Vector3, radius: Vector3, color: Color, sides := 6, rings := 3) -> void:
	for r in rings:
		var t0 := PI * r / rings
		var t1 := PI * (r + 1) / rings
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var p00 := center + _sphere_pt(t0, a0) * radius
			var p01 := center + _sphere_pt(t0, a1) * radius
			var p10 := center + _sphere_pt(t1, a0) * radius
			var p11 := center + _sphere_pt(t1, a1) * radius
			var n := (_sphere_pt(t0, a0) + _sphere_pt(t0, a1) + _sphere_pt(t1, a0) + _sphere_pt(t1, a1)).normalized()
			if r > 0:
				tri(p00, p01, p11, n, color)
			if r < rings - 1:
				tri(p00, p11, p10, n, color)


## A lumpy, smooth-shaded blob for foliage: `sides` around and `rings` from
## top to bottom, each vertex pushed in or out by up to `lump` of the radius
## (from `seed`, so a cell rebuilds the same). Shared vertices with smooth
## normals, shaded darker underneath so a crown of clumps reads as depth.
## Open at the bottom pole: the camera never looks up into it.
func clump(center: Vector3, radius: Vector3, color: Color, seed: int, sides := 7, rings := 4, lump := 0.18) -> void:
	var base := verts.size()
	for r in rings:
		var t := PI * r / rings
		var count := 1 if r == 0 else sides
		var shade := lerpf(1.0, 0.6, float(r) / rings)
		for i in count:
			var d := _sphere_pt(t, TAU * i / sides)
			var k := 1.0 if count == 1 else 1.0 + lump * (_hash(seed * 131 + r * 17 + i) * 2.0 - 1.0)
			var p := center + d * radius * k
			var n := (d / radius).normalized()
			verts.append(xform * p)
			normals.append((xform.basis * n).normalized())
			colors.append(Color(color.r * shade, color.g * shade, color.b * shade, color.a))
			uvs.append(_uv(p, n))
	for i in sides:
		var j := (i + 1) % sides
		_tri_idx(base, base + 1 + i, base + 1 + j)
		for r in rings - 2:
			var a := base + 1 + r * sides
			var b := a + sides
			_tri_idx(a + i, b + i, b + j)
			_tri_idx(a + i, b + j, a + j)


## A smooth-shaded ellipsoid (people: heads, bodies, hands): shared vertices
## with the surface's own normals, `sides` around and `rings` pole to pole,
## so it reads round instead of faceted.
func smooth_ball(center: Vector3, radius: Vector3, color: Color, sides := 10, rings := 6) -> void:
	var base := verts.size()
	_vert(center + Vector3(0.0, radius.y, 0.0), Vector3.UP, color)
	for r in range(1, rings):
		var t := PI * r / rings
		for i in sides:
			var d := _sphere_pt(t, TAU * i / sides)
			_vert(center + d * radius, (d / radius).normalized(), color)
	_vert(center - Vector3(0.0, radius.y, 0.0), Vector3.DOWN, color)
	var last := verts.size() - 1
	var low := base + 1 + (rings - 2) * sides
	for i in sides:
		var j := (i + 1) % sides
		_tri_idx(base, base + 1 + i, base + 1 + j)
		for r in rings - 2:
			var a := base + 1 + r * sides
			var b := a + sides
			_tri_idx(a + i, b + i, b + j)
			_tri_idx(a + i, b + j, a + j)
		_tri_idx(low + i, last, low + j)


## A smooth-shaded tapered tube from `a` (radius ra) to `b` (rb), open at
## both ends: limbs, necks, cuffs and hems on people. The normals lean with
## the taper, so a cone shades as a cone.
func smooth_limb(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, sides := 8) -> void:
	var axis := b - a
	var length := axis.length()
	if length < 0.0001:
		return
	axis /= length
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	var lean := (ra - rb) / length
	var base := verts.size()
	for end in 2:
		var c := a if end == 0 else b
		var r := ra if end == 0 else rb
		for i in sides:
			var t := TAU * i / sides
			var d := side * cos(t) + up * sin(t)
			_vert(c + d * r, (d + axis * lean).normalized(), color)
	for i in sides:
		var j := (i + 1) % sides
		_tri_idx(base + i, base + sides + i, base + sides + j)
		_tri_idx(base + i, base + sides + j, base + j)


## A slab with rounded corners in plan (a superellipse of `sides` points),
## smooth sides and a flat top, open underneath: soles, cap brims. The top is
## `taper` times the size of the bottom.
func rounded_slab(center: Vector3, size: Vector3, color: Color, taper := 1.0, sides := 12) -> void:
	var h := size * 0.5
	var ring := []
	for i in sides:
		var t := TAU * (i + 0.5) / sides
		var c := cos(t)
		var s := sin(t)
		# Exponent 0.5 squares the ellipse off into a rounded rectangle.
		var x := signf(c) * sqrt(absf(c)) * h.x
		var z := signf(s) * sqrt(absf(s)) * h.z
		ring.append([Vector3(x, 0, z), Vector3(signf(c) * absf(c) * sqrt(absf(c)) / h.x, 0, signf(s) * absf(s) * sqrt(absf(s)) / h.z).normalized()])
	var base := verts.size()
	for k in 2:
		var y := -h.y if k == 0 else h.y
		var scale := 1.0 if k == 0 else taper
		for r in ring:
			_vert(center + r[0] * scale + Vector3(0, y, 0), r[1], color)
	for i in sides:
		var j := (i + 1) % sides
		_tri_idx(base + i, base + sides + i, base + sides + j)
		_tri_idx(base + i, base + sides + j, base + j)
	var top := verts.size()
	_vert(center + Vector3(0, h.y, 0), Vector3.UP, color)
	for r in ring:
		_vert(center + r[0] * taper + Vector3(0, h.y, 0), Vector3.UP, color)
	for i in sides:
		_tri_idx(top, top + 1 + i, top + 1 + (i + 1) % sides)


## A smooth-shaded body over elliptic rings, bottom to top: each ring is
## [y, half width, half depth, color] and may add a bone that it and the
## rings after it bind to (a shared ring stretches when the bones bend, so no
## crack opens). A colour change starts a fresh ring at the same height so
## the colours meet on a hard line. Open at the bottom; closed by a pole
## `cap` above the last ring (left open when 0). Torsos on people.
func loft(rings: Array, sides := 12, cap := 0.0) -> void:
	var n := rings.size()
	var prev := -1
	var prev_color := Color()
	for k in n:
		var r: Array = rings[k]
		var lo: Array = rings[maxi(k - 1, 0)]
		var hi: Array = rings[mini(k + 1, n - 1)]
		var dy: float = hi[0] - lo[0]
		var slope := Vector2.ZERO if is_zero_approx(dy) else Vector2(hi[1] - lo[1], hi[2] - lo[2]) / dy
		var color: Color = r[3]
		# Both rings at a colour change share the bone, so the seam can't open.
		if r.size() > 4:
			set_bone(r[4])
		if prev >= 0 and color != prev_color:
			_loft_ring(r, slope, prev_color, sides, prev)
			prev_color = color
			prev = _loft_ring(r, slope, color, sides, -1)
			continue
		prev = _loft_ring(r, slope, color, sides, prev)
		prev_color = color
	if cap > 0.0:
		var top: Array = rings[n - 1]
		var pole := verts.size()
		_vert(Vector3(0.0, top[0] + cap, 0.0), Vector3.UP, prev_color)
		for i in sides:
			_tri_idx(pole, prev + i, prev + (i + 1) % sides)


## One ring of loft(), joined to the ring at vertex `prev` (none if -1).
## Returns where it starts.
func _loft_ring(r: Array, slope: Vector2, color: Color, sides: int, prev: int) -> int:
	var base := verts.size()
	var rx: float = r[1]
	var rz: float = r[2]
	for i in sides:
		var t := TAU * i / sides
		var c := cos(t)
		var s := sin(t)
		var nrm := Vector3(rz * c, -(rz * slope.x * c * c + rx * slope.y * s * s), rx * s)
		_vert(Vector3(rx * c, r[0], rz * s), nrm.normalized(), color)
	if prev >= 0:
		for i in sides:
			var j := (i + 1) % sides
			_tri_idx(prev + i, base + i, base + j)
			_tri_idx(prev + i, base + j, prev + j)
	return base


func _vert(p: Vector3, n: Vector3, color: Color) -> void:
	verts.append(xform * p)
	normals.append((xform.basis * n).normalized())
	colors.append(color)
	uvs.append(_uv(p, n))


## One triangle over existing vertices, wound to face along their normals.
func _tri_idx(a: int, b: int, c: int) -> void:
	var n := normals[a] + normals[b] + normals[c]
	if (verts[b] - verts[a]).cross(verts[c] - verts[a]).dot(n) > 0.0:
		indices.append_array([a, c, b])
	else:
		indices.append_array([a, b, c])


static func _hash(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898) * 43758.5453, 1.0)


static func _sphere_pt(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## A tapered limb from `a` to `b` (radius `ra` at a, `rb` at b) with flat
## ends: arms, legs and necks. Without `caps` the ends stay open (trunks and
## branches, whose ends are buried in the ground or the crown).
func limb(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, sides := 6, caps := true) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(axis)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var n := ((d0 + d1) * 0.5).normalized()
		quad(a + d0 * ra, a + d1 * ra, b + d1 * rb, b + d0 * rb, n, color)
		if caps:
			tri(b, b + d0 * rb, b + d1 * rb, axis, color)
			tri(a, a + d1 * ra, a + d0 * ra, -axis, color)


## A flat polygon, convex or not (x, z points, clockwise on screen) at height y,
## facing up.
func flat(poly: PackedVector2Array, y: float, color: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	if idx.is_empty(): # degenerate outline: fall back to a fan
		for k in range(1, poly.size() - 1):
			idx.append_array([0, k, k + 1])
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var b := poly[idx[k + 1]]
		var c := poly[idx[k + 2]]
		tri(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP, color)


## A polygon extruded from y0 up to y1 (top and sides, no bottom):
## block slabs, sidewalks, medians.
func prism(poly: PackedVector2Array, y0: float, y1: float, color: Color, side_color := Color(0, 0, 0, 0)) -> void:
	flat(poly, y1, color)
	var sc := side_color if side_color.a > 0.0 else color.darkened(0.15)
	var n := poly.size()
	for k in n:
		var a := poly[k]
		var b := poly[(k + 1) % n]
		var dir := (b - a).normalized()
		var out := Vector3(dir.y, 0, -dir.x) # left of the direction: outward for clockwise-on-screen polygons
		quad(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), out, sc)


## Number of triangles collected so far (for budgets and tests); with LOD
## marks, those of the near level.
func triangle_count() -> int:
	if _lod_marks.is_empty():
		return indices.size() / 3
	return lod_indices()[0].size() / 3


func primitive(mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var base := verts.size()
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var full := self.xform * xform
	for i in src_verts.size():
		verts.append(full * src_verts[i])
		normals.append((full.basis * src_normals[i]).normalized())
		colors.append(color)
		uvs.append(_uv(xform * src_verts[i], xform.basis * src_normals[i]))
	for index in arrays[Mesh.ARRAY_INDEX]:
		indices.append(base + index)


## Scales the pattern coordinates of the vertices added since `from`: road
## slabs, tiles and setts at their own size from the same patterns.
func scale_uvs(from: int, scale: Vector2) -> void:
	for i in range(from, uvs.size()):
		uvs[i] *= scale


## Fades the vertices added since `from` whose colour is one of `paints`
## (exactly, code and all) toward `toward` by `amount`: worn road paint.
func fade_colors(from: int, paints: Array, toward: Color, amount: float) -> void:
	if amount <= 0.0:
		return
	for i in range(from, colors.size()):
		if paints.has(colors[i]):
			var c := colors[i].lerp(toward, amount)
			c.a = colors[i].a
			colors[i] = c


## Marks the vertices added since `start` as ground (see ground_ranges).
func mark_ground(start: int) -> void:
	ground_ranges.append(start)
	ground_ranges.append(verts.size())


func commit() -> ArrayMesh:
	return mesh_from(surface())


## The mesh's arrays and LODs, [arrays, lods], for mesh_from(). Builds no
## resource, so it is safe on a worker thread.
func surface() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var lods := {}
	if _lod_marks.is_empty():
		arrays[Mesh.ARRAY_INDEX] = indices
	else:
		var split := lod_indices()
		arrays[Mesh.ARRAY_INDEX] = split[0]
		lods[far_lod] = split[1]
	if not ground_ranges.is_empty():
		var uv2 := PackedVector2Array()
		uv2.resize(verts.size())
		for k in range(0, ground_ranges.size(), 2):
			for v in range(ground_ranges[k], mini(ground_ranges[k + 1], verts.size())):
				uv2[v] = Vector2(1.0, 0.0)
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	if not _bone_marks.is_empty() or not _skins.is_empty():
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		bones.resize(verts.size() * 4)
		weights.resize(verts.size() * 4)
		for k in _bone_marks.size():
			var end: int = verts.size() if k == _bone_marks.size() - 1 else _bone_marks[k + 1][0]
			for v in range(_bone_marks[k][0], end):
				bones[v * 4] = _bone_marks[k][1]
				weights[v * 4] = 1.0
		for sk in _skins:
			var first: int = sk[0]
			var sb: PackedInt32Array = sk[1]
			var sw: PackedFloat32Array = sk[2]
			for k in mini(sb.size(), (verts.size() - first) * 4):
				bones[first * 4 + k] = sb[k]
				weights[first * 4 + k] = sw[k]
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	return [arrays, lods]


## An ArrayMesh from surface()'s result (main thread: it uploads the mesh).
static func mesh_from(s: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s[0], [], s[1])
	return mesh


func make_instance() -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = commit()
	inst.material_override = material()
	return inst
