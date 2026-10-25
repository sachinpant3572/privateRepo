extends Node2D
## Draws the game's danger zones (under the units) or its lightning bolts
## (above them). Reads the lists straight from the game node.

var game
var top := false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null:
		return
	if top:
		for bolt in game.bolts:
			var a: float = clampf(float(bolt[1]) / 0.15, 0.0, 1.0)
			draw_polyline(bolt[0], Color(0.55, 0.85, 1.0, a), 5.0)
			draw_polyline(bolt[0], Color(1, 1, 1, a), 2.0)
		return
	# Telegraph entries: [kind, start, end (or radius in x), time left, total time, damage].
	for tg in game.telegraphs:
		var k: float = 1.0 - float(tg[3]) / float(tg[4])
		var start: Vector2 = tg[1]
		var end: Vector2 = tg[2]
		match int(tg[0]):
			0:
				draw_circle(start, end.x, Color(1.0, 0.15, 0.1, 0.1 + 0.15 * k))
				draw_circle(start, end.x * k, Color(1.0, 0.25, 0.15, 0.25))
				draw_arc(start, end.x, 0.0, TAU, 40, Color(1.0, 0.35, 0.25, 0.8), 2.0)
			1:
				draw_line(start, end, Color(1.0, 0.2, 0.1, 0.2 + 0.6 * k), 3.0)
			2:
				draw_line(start, end, Color(0.4, 0.9, 1.0, 0.35), 4.0)
			3:
				draw_line(start, end, Color(1.0, 0.2, 0.1, 0.15 + 0.3 * k), 110.0)
