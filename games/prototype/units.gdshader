// All units share one MultiMesh and one texture atlas. Each instance's
// custom data holds its atlas cell as (u, v, width, height).
shader_type canvas_item;

varying vec4 cell;

void vertex() {
	cell = INSTANCE_CUSTOM;
}

void fragment() {
	COLOR = texture(TEXTURE, cell.xy + UV * cell.zw) * COLOR;
}
