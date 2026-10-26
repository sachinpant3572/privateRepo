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
static var _water_material: ShaderMaterial

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

## River and harbour water: the vertex colour with drifting light glints, the
## classic top-down way of showing a current.
const WATER_SHADER := """
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float a = sin(p.x * 0.35 + TIME * 1.2 + sin(p.y * 0.21 + TIME * 0.7) * 2.0);
	float b = sin(p.y * 0.5 - TIME * 0.9 + sin(p.x * 0.17) * 1.5);
	float glint = smoothstep(0.8, 0.95, a * b);
	ALBEDO = COLOR.rgb + vec3(0.22, 0.28, 0.28) * glint;
	ROUGHNESS = 1.0;
}
"""

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var indices := PackedInt32Array()
## Placement applied to everything added; asset kits build in local space and
## the caller sets this to position and rotate them (rotation and translation
## only, so winding and normals stay valid).
var xform := Transform3D.IDENTITY


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


static func water_material() -> ShaderMaterial:
	if _water_material == null:
		var shader := Shader.new()
		shader.code = WATER_SHADER
		_water_material = ShaderMaterial.new()
		_water_material.shader = shader
	return _water_material


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
	indices.append_array([base, base + 1, base + 2])


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
	var front_n := Vector3(0, h.z, -h.y).normalized()
	var back_n := Vector3(0, h.z, h.y).normalized()
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


static func _sphere_pt(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))


## Number of triangles collected so far (for budgets and tests).
func triangle_count() -> int:
	return indices.size() / 3


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
