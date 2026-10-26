// Battlefield ground in world space: a tiled ground texture (sprites/ground.png)
// or, without one, asphalt patches; plus a fine grid and big sector lines.
// "origin" is the world position of the rect's top-left.
shader_type canvas_item;

uniform vec2 origin = vec2(0.0);
uniform float detail = 1.0;
uniform float pulse = 0.0;
uniform bool use_tex = false;
uniform sampler2D ground_tex : repeat_enable, filter_linear;
uniform float tile = 512.0;  // World pixels per texture repeat.

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 w = origin + local;
	vec3 col;
	float lines = 1.0;
	if (use_tex) {
		col = texture(ground_tex, w / tile).rgb;
		// Big, slow light and dark patches hide the repeat.
		float n = sin(w.x * 0.0011 + sin(w.y * 0.0009) * 2.0) * sin(w.y * 0.0013 + 1.7);
		col *= 0.9 + 0.1 * n * detail;
		lines = 0.35;
	} else {
		col = vec3(0.075, 0.08, 0.078);
		float n = sin(w.x * 0.004 + sin(w.y * 0.003) * 2.0) * sin(w.y * 0.0045 + 1.7);
		col += vec3(0.03, 0.025, 0.012) * n * detail;
	}
	vec2 g = abs(fract(w / 80.0) - 0.5);
	col += vec3(0.05, 0.055, 0.06) * smoothstep(0.47, 0.5, max(g.x, g.y)) * (0.6 + 0.4 * detail) * (1.0 + pulse) * lines;
	vec2 g2 = abs(fract(w / 640.0) - 0.5);
	col += vec3(0.12, 0.03, 0.03) * smoothstep(0.496, 0.5, max(g2.x, g2.y)) * detail * lines;
	COLOR = vec4(col, 1.0);
}
