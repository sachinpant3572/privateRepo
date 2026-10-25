// Animated backdrop: a dark gradient, a slowly scrolling grid and a soft
// nebula. "detail" scales the grid and nebula (0 = gradient only).
shader_type canvas_item;

uniform float detail = 1.0;
uniform float grid_size = 96.0;
uniform float pulse = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	vec3 col = mix(vec3(0.015, 0.015, 0.05), vec3(0.05, 0.015, 0.09), uv.y);
	vec2 g = abs(fract((FRAGCOORD.xy + vec2(0.0, t * 24.0)) / grid_size) - 0.5);
	float line = smoothstep(0.46, 0.5, max(g.x, g.y));
	col += vec3(0.04, 0.07, 0.14) * line * detail * (1.0 + pulse * 2.0);
	float n = sin(uv.x * 5.0 + t * 0.25) * sin(uv.y * 4.0 - t * 0.17) + 0.5 * sin((uv.x + uv.y) * 9.0 + t * 0.4);
	col += vec3(0.07, 0.02, 0.11) * clamp(n, 0.0, 1.0) * detail;
	COLOR = vec4(col, 1.0);
}
