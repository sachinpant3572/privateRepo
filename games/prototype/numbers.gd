extends Node2D
## Floating damage numbers, drawn in one pass from a fixed ring buffer (the
## oldest number is replaced when it's full). Crits are bigger and golden.

const CAP := 90
const LIFE := 0.7

var pos := PackedVector2Array()
var value := PackedFloat32Array()
var life := PackedFloat32Array()
var crit := PackedInt32Array()
var next := 0
var font: Font


func _ready() -> void:
	pos.resize(CAP)
	value.resize(CAP)
	life.resize(CAP)
	crit.resize(CAP)
	font = ThemeDB.fallback_font


func add(at: Vector2, amount: float, is_crit: bool) -> void:
	pos[next] = at + Vector2(randf_range(-10.0, 10.0), -14.0)
	value[next] = amount
	life[next] = LIFE
	crit[next] = 1 if is_crit else 0
	next = (next + 1) % CAP


func clear() -> void:
	life.fill(0.0)


func step(dt: float) -> void:
	for i in CAP:
		if life[i] > 0.0:
			life[i] -= dt
			var p := pos[i]
			p.y -= 40.0 * dt
			pos[i] = p
	queue_redraw()


func _draw() -> void:
	for i in CAP:
		var l := life[i]
		if l <= 0.0:
			continue
		var a := clampf(l / (LIFE * 0.4), 0.0, 1.0)
		var big := crit[i] == 1
		var size := 30 if big else 19
		var text := str(int(round(value[i])))
		var col := Color(1.0, 0.85, 0.25, a) if big else Color(1.0, 1.0, 1.0, a)
		draw_string_outline(font, pos[i], text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, size, 5, Color(0.0, 0.0, 0.0, a))
		draw_string(font, pos[i], text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, size, col)
