extends RefCounted
## Ground height outside the flat city: the Bellerive Hills, a height grid
## from data/country.json ("terrain", built by tools/mountain.py). Zero
## everywhere off the grid, so the city and the rest of the country stay
## flat. Static: vehicles, people and the country tiles share one grid
## (preload this script and call Terrain.height(x, z)).

## Decimetres per stored step.
const SCALE := 0.1

static var origin := Vector2.ZERO
static var cell := 8.0
static var nx := 0
static var ny := 0
static var heights := PackedFloat32Array()
static var bounds := Rect2()


## Reads the "terrain" entry of country.json ({} or null clears it).
static func load_data(d) -> void:
	heights = PackedFloat32Array()
	nx = 0
	ny = 0
	bounds = Rect2()
	if not d is Dictionary or d.is_empty():
		return
	origin = Vector2(d.origin[0], d.origin[1])
	cell = float(d.cell)
	nx = int(d.size[0])
	ny = int(d.size[1])
	var raw: PackedByteArray = Marshalls.base64_to_raw(d.dm)
	heights.resize(nx * ny)
	for i in nx * ny:
		heights[i] = raw.decode_u16(i * 2) * SCALE
	bounds = Rect2(origin, Vector2(nx - 1, ny - 1) * cell)


## Height (m) of the ground at local x, z.
static func height(x: float, z: float) -> float:
	if nx == 0:
		return 0.0
	var u := (x - origin.x) / cell
	var v := (z - origin.y) / cell
	if u < 0.0 or v < 0.0 or u >= nx - 1 or v >= ny - 1:
		return 0.0
	var i := int(u)
	var j := int(v)
	var fu := u - i
	var fv := v - j
	var k := j * nx + i
	var a := heights[k] + (heights[k + 1] - heights[k]) * fu
	var b := heights[k + nx] + (heights[k + nx + 1] - heights[k + nx]) * fu
	return a + (b - a) * fv


static func height_at(p: Vector3) -> float:
	return height(p.x, p.z)


## Up-facing normal of the ground at local x, z.
static func normal(x: float, z: float) -> Vector3:
	if nx == 0 or not bounds.has_point(Vector2(x, z)):
		return Vector3.UP
	var e := cell * 0.5
	var dx := height(x + e, z) - height(x - e, z)
	var dz := height(x, z + e) - height(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()


## Whether any ground in `rect` (local x, z) may be raised.
static func touches(rect: Rect2) -> bool:
	return nx > 0 and bounds.intersects(rect)
