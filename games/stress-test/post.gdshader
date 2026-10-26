// Ultra screen effects: slight chromatic aberration (stronger during screen
// shake) and a vignette.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 0.004;
uniform float vignette = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r = texture(screen_tex, uv + d * aberration).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - d * aberration).b;
	float v = 1.0 - vignette * dot(d, d) * 2.0;
	COLOR = vec4(vec3(r, g, b) * v, 1.0);
}
