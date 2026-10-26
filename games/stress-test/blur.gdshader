// One pass of a separable Gaussian blur (9 taps using linear sampling).
// The glow runs it twice: horizontal into a small viewport, then vertical
// while adding the result over the scene. Output alpha is always 1, so
// additive blending adds exactly the blurred color.
shader_type canvas_item;
render_mode blend_add;

uniform vec2 direction = vec2(1.0, 0.0);
uniform float spread = 1.6;
uniform float strength = 1.0;

void fragment() {
	vec2 step = TEXTURE_PIXEL_SIZE * direction * spread;
	vec3 c = texture(TEXTURE, UV).rgb * 0.2270270;
	c += (texture(TEXTURE, UV + step * 1.3846154).rgb + texture(TEXTURE, UV - step * 1.3846154).rgb) * 0.3162162;
	c += (texture(TEXTURE, UV + step * 3.2307692).rgb + texture(TEXTURE, UV - step * 3.2307692).rgb) * 0.0702703;
	COLOR = vec4(c * strength, 1.0);
}
