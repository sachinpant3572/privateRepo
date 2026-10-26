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
static var _xray_material: StandardMaterial3D

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


## The same material plus a pass that draws a flat silhouette wherever the
## mesh is hidden behind buildings, so the player never gets lost.
static func xray_material() -> StandardMaterial3D:
	if _xray_material == null:
		_xray_material = material().duplicate()
		var silhouette := StandardMaterial3D.new()
		silhouette.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		silhouette.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		silhouette.albedo_color = Color(1.0, 0.85, 0.25, 0.6)
		silhouette.depth_test = BaseMaterial3D.DEPTH_TEST_INVERTED
		silhouette.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_xray_material.next_pass = silhouette
	return _xray_material


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
