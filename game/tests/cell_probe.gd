extends Node
## Times the open-land cells (parks, cemeteries, golf, yards): the worker
## build (Cells.build) and the main-thread add (_add_cell: mesh instance and
## collision shapes), the part a phone feels as a hitch. Headless is fine:
##   godot --headless res://tests/cell_probe.tscn

const MainScene = preload("res://main.tscn")
const Cells = preload("res://scripts/city_cells.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = MainScene.instantiate()
	game.save_enabled = false
	game.missions_enabled = false
	add_child(game)
	for i in 5:
		await get_tree().process_frame
	var city = game.city
	var rows: Array = []
	for c in city.cells.size():
		var cell: Dictionary = city.cells[c]
		if city._loaded.has(c):
			city._unload(c)
		var t0 := Time.get_ticks_usec()
		var built: Dictionary = Cells.build(city, c)
		var t1 := Time.get_ticks_usec()
		city._add_cell(c, built)
		var t2 := Time.get_ticks_usec()
		var shapes := 0
		for b in city._loaded[c].get_children():
			if b is StaticBody3D:
				shapes += b.get_child_count()
		rows.append([t2 - t1, t1 - t0, c, (city.block_style(cell.id) if cell.kind == "face" else "edge"), shapes, built.mesh.triangle_count() if built.mesh.has_method("triangle_count") else 0])
		city._unload(c)
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for i in rows.size():
		var r: Array = rows[i]
		if i >= 12 and not (r[3] in Cells.OPEN_LAND):
			continue
		print("CELL add_ms=%.2f build_ms=%.1f cell=%d style=%s shapes=%d tris=%d" % [r[0] / 1000.0, r[1] / 1000.0, r[2], r[3], r[4], r[5]])
	print("PROBE DONE %d cells, median add_ms=%.2f p90=%.2f" % [rows.size(), rows[rows.size() / 2][0] / 1000.0, rows[rows.size() / 10][0] / 1000.0])
	get_tree().quit()
