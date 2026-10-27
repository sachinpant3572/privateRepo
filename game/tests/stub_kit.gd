extends RefCounted
static func build(kind: String, mb, out: Array, size: Vector2, rng: RandomNumberGenerator) -> void:
	mb.box(Vector3(0, 3, size.y * 0.1), Vector3(size.x * 0.7, 6, size.y * 0.6), Color(0.8, 0.75, 0.7))
	out.append([Vector3(0, 3, size.y * 0.1), Vector3(size.x * 0.7, 6, size.y * 0.6)])
