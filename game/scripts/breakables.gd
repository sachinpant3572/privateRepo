extends RefCounted
## Roadside props a car knocks down: lamp posts, traffic signals, small
## street trees (the country's too), hydrants, water-filled roadworks
## barriers, bins, benches, signs, crates. The prop kit tags
## their colliders with their slice of the cell's (or country tile's) one
## mesh (Props._breaks). A hit turns the colliders off, collapses that slice
## so the prop is gone, throws debris (a hydrant gushes water) and lays a
## plain copy of it down where it fell; the car loses a little speed, not
## all of it. Everything comes back when the cell is built again.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

## Below this (m/s), a prop stands up to the car like any other wall.
const MIN_SPEED := 2.5
## Share of its speed a car keeps knocking down each kind (the rest 0.92).
const KEEP := {
	"street_light": 0.86, "traffic_light": 0.82, "gas_lamp": 0.88, "street_tree": 0.86, "crepe_myrtle": 0.86,
	"hydrant": 0.88, "bench": 0.9, "ev_charger": 0.88, "bins": 0.9, "roadworks": 0.85,
}
## How tall the fallen copy of each tall kind is (the colliders are cut
## short), and its colour.
const POLES := {
	"street_light": [6.3, Color(0.55, 0.57, 0.6)], "gas_lamp": [4.0, Color(0.13, 0.15, 0.14)],
	"traffic_light": [5.6, Color(0.2, 0.21, 0.22)], "wayfinding": [2.4, Color(0.2, 0.3, 0.42)],
}
const TREES := ["street_tree", "crepe_myrtle"]
const BARK := Color(0.38, 0.27, 0.19)
const LEAF := Color(0.3, 0.42, 0.22)


## The prop behind this collision, or {} if it is not one a car breaks.
static func prop_of(col: KinematicCollision3D) -> Dictionary:
	var shape = col.get_collider_shape()
	if shape is CollisionShape3D and shape.has_meta("brk"):
		var info: Dictionary = shape.get_meta("brk")
		if not info.get("down", false):
			return info
	return {}


## Knocks the prop hit in `col` down, by a car moving at `velocity`.
## Returns the share of its speed the car keeps.
static func smash(col: KinematicCollision3D, velocity: Vector3, by_player: bool) -> float:
	var shape: CollisionShape3D = col.get_collider_shape()
	var body: Node = col.get_collider()
	var info: Dictionary = shape.get_meta("brk")
	info["down"] = true
	var base := shape.global_position - Vector3(0, (shape.shape as BoxShape3D).size.y * 0.5, 0)
	# Every collider of the prop (a signal has two).
	for c in body.get_children():
		if c is CollisionShape3D and c.has_meta("brk") and c.get_meta("brk").get("down", false):
			c.set_deferred("disabled", true)
	collapse(body.get_meta("mesh", null), info.v)
	collapse(body.get_meta("glow", null), info.g)
	var dir := Vector3(velocity.x, 0, velocity.z).normalized()
	_topple(body.get_parent(), info.kind, base, dir)
	var fx = body.get_tree().root.get_node_or_null("Fx")
	if fx != null:
		fx.knock(base + Vector3(0, 0.6, 0), info.kind, by_player)
	return float(KEEP.get(info.kind, 0.92))


## Collapses vertices [r.x, r.y) of the instance's mesh to one point, so the
## triangles between them vanish (the mesh is one surface; see MeshBuilder).
static func collapse(inst, r: Vector2i) -> void:
	if inst == null or not is_instance_valid(inst) or r.y <= r.x:
		return
	var mesh: ArrayMesh = inst.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var count := mesh.surface_get_array_len(0)
	if r.y > count:
		return
	var fmt := mesh.surface_get_format(0)
	var stride := RenderingServer.mesh_surface_get_format_vertex_stride(fmt, count)
	var bytes := PackedByteArray()
	bytes.resize((r.y - r.x) * stride)
	RenderingServer.mesh_surface_update_vertex_region(mesh.get_rid(), 0, r.x * stride, bytes)


## A plain copy of the prop lying where it fell: a pole tipped over along
## the car's path, a tree on its side.
static func _topple(parent: Node, kind: String, base: Vector3, dir: Vector3) -> void:
	if parent == null or dir == Vector3.ZERO:
		return
	var mb := MeshBuilder.new()
	var rest_angle := PI * 0.5
	if POLES.has(kind):
		var h: float = POLES[kind][0]
		mb.cylinder(Vector3.ZERO, 0.1, h, POLES[kind][1], 5)
		mb.box(Vector3(0, h - 0.1, 0.6), Vector3(0.3, 0.15, 1.3), POLES[kind][1].darkened(0.2))
		rest_angle = PI * 0.5 - 0.05
	elif kind in TREES:
		mb.cylinder(Vector3.ZERO, 0.12, 2.4, BARK, 5)
		mb.clump(Vector3(0, 3.0, 0), Vector3(1.3, 1.1, 1.3), LEAF, int(base.length()), 6, 3)
		rest_angle = PI * 0.5 - 0.25
	else:
		return # small props just scatter (Fx.knock)
	var inst := mb.make_instance()
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	inst.global_position = base
	# Fall away from the car: rotate about the axis across its path.
	var axis := Vector3.UP.cross(dir).normalized()
	var tween := inst.create_tween()
	tween.tween_method(func(t: float): inst.global_basis = Basis(axis, rest_angle * t * t), 0.0, 1.0, 0.45)
