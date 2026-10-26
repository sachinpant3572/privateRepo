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
static var _xray_materials := {}
static var _cutaway_material: ShaderMaterial

## City shader: the same toon look as material(), plus a dissolving hole in
## anything standing between the camera and the player, so buildings never
## hide what happens around them. The camera updates the uniforms each frame.
const CUTAWAY_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 focus = vec3(0.0);
uniform vec3 cam_right = vec3(1.0, 0.0, 0.0);
uniform vec3 cam_up = vec3(0.0, 1.0, 0.0);
uniform vec3 cam_back = vec3(0.0, 0.0, 1.0);
uniform float cut_radius = 7.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	vec3 rel = world_pos - focus;
	if (world_pos.y > 0.4 && dot(rel, cam_back) > 1.0) {
		float d = length(vec2(dot(rel, cam_right), dot(rel, cam_up))) / cut_radius;
		if (d < 1.0) {
			float noise = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
			if (noise > smoothstep(0.7, 1.0, d)) {
				discard;
			}
		}
	}
}
"""

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()


## The toon material every baked mesh uses; colour comes from the vertices.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_material.roughness = 1.0
	return _material


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


static func cutaway_material() -> ShaderMaterial:
	if _cutaway_material == null:
		var shader := Shader.new()
		shader.code = CUTAWAY_SHADER
		_cutaway_material = ShaderMaterial.new()
		_cutaway_material.shader = shader
	return _cutaway_material


func box(center: Vector3, size: Vector3, color: Color) -> void:
	var half := size * 0.5
	for face in FACES:
		var n: Vector3 = face[0]
		var u: Vector3 = face[1] * half.dot(face[1].abs())
		var v: Vector3 = face[2] * half.dot(face[2].abs())
		var c: Vector3 = center + n * half.dot(n.abs())
		var base := verts.size()
		verts.append_array([c - u - v, c + u - v, c + u + v, c - u + v])
		for i in 4:
			normals.append(n)
			colors.append(color)
		# Godot treats clockwise triangles as front-facing.
		indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])


func primitive(mesh: PrimitiveMesh, xform: Transform3D, color: Color) -> void:
	var arrays := mesh.get_mesh_arrays()
	var base := verts.size()
	var src_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in src_verts.size():
		verts.append(xform * src_verts[i])
		normals.append((xform.basis * src_normals[i]).normalized())
		colors.append(color)
	for index in arrays[Mesh.ARRAY_INDEX]:
		indices.append(base + index)


func commit() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func make_instance() -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = commit()
	inst.material_override = material()
	return inst
