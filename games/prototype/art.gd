extends RefCounted
## Placeholder art drawn in code, top-down, with units facing +x (the game
## rotates them). Real sprites can replace the atlas later as long as the cell
## layout stays the same.

const CELL := 128
const COLS := 4
const ROWS := 2

# Atlas cells. The first four match the enemy types in data.gd.
const TROOPER := 0
const SHIELD := 1
const GRENADIER := 2
const ELITE := 3
const TANK := 4
const TURRET := 5
const HELI := 6
const ROTOR := 7

const DARK := Color(0.12, 0.12, 0.13)
const ARMOR := Color(0.24, 0.26, 0.29)
const CRIMSON := Color(0.66, 0.1, 0.12)
const STEEL := Color(0.58, 0.63, 0.7)
const OLIVE := Color(0.28, 0.31, 0.23)
const OLIVE_LIGHT := Color(0.34, 0.37, 0.28)


static func atlas() -> ImageTexture:
	var img := Image.create_empty(CELL * COLS, CELL * ROWS, false, Image.FORMAT_RGBA8)
	for cell in COLS * ROWS:
		var o := Vector2(float((cell % COLS) * CELL), float(int(cell / COLS) * CELL))
		match cell:
			TROOPER:
				_infantry(img, o, CRIMSON)
			SHIELD:
				_infantry(img, o, CRIMSON)
				_box(img, o, Vector2(90, 20), Vector2(104, 108), STEEL)
				_box(img, o, Vector2(102, 20), Vector2(106, 108), Color(0.82, 0.86, 0.9))
			GRENADIER:
				_box(img, o, Vector2(16, 44), Vector2(40, 84), Color(0.45, 0.32, 0.12))
				_infantry(img, o, Color(0.85, 0.45, 0.1))
			ELITE:
				_juggernaut(img, o)
			TANK:
				_tank_body(img, o)
			TURRET:
				_turret(img, o)
			HELI:
				_heli(img, o)
			ROTOR:
				_box(img, o, Vector2(4, 61), Vector2(124, 67), Color(0.85, 0.88, 0.92, 0.55))
				_box(img, o, Vector2(61, 4), Vector2(67, 124), Color(0.85, 0.88, 0.92, 0.55))
				_disc(img, o + Vector2(64, 64), 7.0, Color(0.3, 0.32, 0.35))
	return ImageTexture.create_from_image(img)


## An atlas cell as (u, v, width, height), stored in a Color for MultiMesh
## custom data.
static func cell_rect(cell: int) -> Color:
	return Color(float(cell % COLS) / COLS, float(int(cell / COLS)) / ROWS, 1.0 / COLS, 1.0 / ROWS)


static func boss() -> ImageTexture:
	var img := Image.create_empty(256, 192, false, Image.FORMAT_RGBA8)
	var o := Vector2.ZERO
	_box(img, o, Vector2(8, 10), Vector2(248, 44), DARK)
	_box(img, o, Vector2(8, 148), Vector2(248, 182), DARK)
	for x in range(10, 244, 14):
		_box(img, o, Vector2(x, 10), Vector2(x + 4, 44), Color(0.22, 0.22, 0.22))
		_box(img, o, Vector2(x, 148), Vector2(x + 4, 182), Color(0.22, 0.22, 0.22))
	_box(img, o, Vector2(16, 36), Vector2(240, 156), Color(0.3, 0.12, 0.12))
	_box(img, o, Vector2(28, 50), Vector2(228, 142), Color(0.42, 0.14, 0.14))
	_box(img, o, Vector2(212, 40), Vector2(244, 152), Color(0.5, 0.5, 0.53))
	_box(img, o, Vector2(40, 90), Vector2(200, 102), Color(0.95, 0.6, 0.1))
	return ImageTexture.create_from_image(img)


static func turret_texture() -> ImageTexture:
	var img := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	_turret(img, Vector2.ZERO)
	return ImageTexture.create_from_image(img)


static func hero(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	_disc(img, c, size * 0.48, Color(0.3, 0.8, 1.0, 0.3))
	_disc(img, c, size * 0.38, Color(0.85, 0.97, 1.0))
	_disc(img, c, size * 0.26, Color(0.3, 0.7, 1.0))
	_disc(img, c + Vector2(size * 0.3, 0.0), size * 0.09, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


## A soft disc. "core" is the solid fraction of the radius.
static func soft_disc(size: int, core: float) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / (size * 0.5)
			var a: float = 0.0
			if d < core:
				a = 1.0
			elif d < 1.0:
				a = (1.0 - d) / maxf(1.0 - core, 0.001)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func ring(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / (size * 0.5)
			var a: float = clampf(1.0 - absf(d - 0.8) / 0.12, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


static func gem(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d: float = (absf(x - c) + absf(y - c)) / (size * 0.5)
			var a: float = clampf((1.0 - d) * 4.0, 0.0, 1.0)
			var core: float = clampf(1.0 - d * 1.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.35 + 0.6 * core, 1.0, 0.6 + 0.4 * core, a))
	return ImageTexture.create_from_image(img)


static func chest(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var o := Vector2.ZERO
	var s := float(size)
	_box(img, o, Vector2(s * 0.08, s * 0.2), Vector2(s * 0.92, s * 0.85), Color(0.55, 0.35, 0.08))
	_box(img, o, Vector2(s * 0.14, s * 0.26), Vector2(s * 0.86, s * 0.79), Color(1.0, 0.78, 0.2))
	_box(img, o, Vector2(s * 0.08, s * 0.44), Vector2(s * 0.92, s * 0.52), Color(0.55, 0.35, 0.08))
	_disc(img, Vector2(s * 0.5, s * 0.48), s * 0.08, Color(1.0, 1.0, 0.85))
	return ImageTexture.create_from_image(img)


## A three-pointed spinning blade.
static func blade(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var v := Vector2(x - c, y - c)
			var d: float = v.length() / (size * 0.5)
			var edge: float = 0.3 + 0.65 * pow(maxf(0.0, cos(3.0 * v.angle())), 6.0)
			var a: float = clampf((edge - d) * 8.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


static func enemy_bullet(size: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var c := Vector2(size, size) * 0.5
	_disc(img, c, size * 0.46, Color(1.0, 0.25, 0.12, 0.85))
	_disc(img, c, size * 0.24, Color(1.0, 0.92, 0.8))
	return ImageTexture.create_from_image(img)


static func _infantry(img: Image, o: Vector2, helmet: Color) -> void:
	_disc(img, o + Vector2(60, 64), 32.0, ARMOR)
	_box(img, o, Vector2(64, 57), Vector2(120, 69), DARK)
	_disc(img, o + Vector2(58, 64), 20.0, helmet)
	_box(img, o, Vector2(70, 57), Vector2(80, 71), Color(1.0, 0.45, 0.35))


static func _juggernaut(img: Image, o: Vector2) -> void:
	_disc(img, o + Vector2(50, 26), 18.0, CRIMSON)
	_disc(img, o + Vector2(50, 102), 18.0, CRIMSON)
	_disc(img, o + Vector2(58, 64), 46.0, Color(0.3, 0.09, 0.09))
	_disc(img, o + Vector2(58, 64), 36.0, Color(0.48, 0.12, 0.12))
	_box(img, o, Vector2(60, 80), Vector2(124, 94), DARK)
	_disc(img, o + Vector2(64, 64), 22.0, Color(0.18, 0.18, 0.2))
	_box(img, o, Vector2(76, 56), Vector2(90, 72), Color(1.0, 0.25, 0.1))


static func _tank_body(img: Image, o: Vector2) -> void:
	_box(img, o, Vector2(8, 16), Vector2(120, 34), DARK)
	_box(img, o, Vector2(8, 94), Vector2(120, 112), DARK)
	for x in range(12, 118, 10):
		_box(img, o, Vector2(x, 16), Vector2(x + 3, 34), Color(0.22, 0.22, 0.22))
		_box(img, o, Vector2(x, 94), Vector2(x + 3, 112), Color(0.22, 0.22, 0.22))
	_box(img, o, Vector2(12, 30), Vector2(116, 98), OLIVE)
	_box(img, o, Vector2(100, 34), Vector2(116, 94), OLIVE_LIGHT)
	_box(img, o, Vector2(20, 58), Vector2(96, 70), CRIMSON)


static func _turret(img: Image, o: Vector2) -> void:
	_disc(img, o + Vector2(58, 64), 24.0, OLIVE_LIGHT)
	_box(img, o, Vector2(64, 59), Vector2(124, 69), Color(0.2, 0.22, 0.17))
	_disc(img, o + Vector2(52, 64), 9.0, Color(0.2, 0.22, 0.17))


static func _heli(img: Image, o: Vector2) -> void:
	_box(img, o, Vector2(4, 60), Vector2(60, 68), ARMOR)
	_box(img, o, Vector2(4, 46), Vector2(14, 82), ARMOR)
	_box(img, o, Vector2(58, 34), Vector2(74, 94), DARK)
	_disc(img, o + Vector2(66, 34), 7.0, CRIMSON)
	_disc(img, o + Vector2(66, 94), 7.0, CRIMSON)
	_disc(img, o + Vector2(72, 64), 26.0, Color(0.27, 0.29, 0.33))
	_disc(img, o + Vector2(90, 64), 12.0, Color(0.45, 0.75, 0.95, 0.9))


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(c.y - r - 1.0)), mini(h, int(c.y + r + 2.0))):
		for x in range(maxi(0, int(c.x - r - 1.0)), mini(w, int(c.x + r + 2.0))):
			var d: float = Vector2(x + 0.5, y + 0.5).distance_to(c)
			var a: float = clampf(r - d + 0.5, 0.0, 1.0) * col.a
			if a > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).blend(Color(col.r, col.g, col.b, a)))


static func _box(img: Image, o: Vector2, from: Vector2, to: Vector2, col: Color) -> void:
	for y in range(int(o.y + from.y), int(o.y + to.y)):
		for x in range(int(o.x + from.x), int(o.x + to.x)):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(col))
