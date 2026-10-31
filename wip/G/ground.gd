extends RefCounted
## The walkable ground: the hills' height grid (Terrain) plus decks laid
## over it (stunt ramps now; bridges and tunnel floors in phase 4) and cuts
## where the grid stops counting (tunnels). Static, like Terrain: vehicles
## and people ask Ground instead of Terrain for the surface under them.
##
## Rules (all heights in metres, local x, z):
## - The terrain is solid: outside a cut it always counts, however far above
##   the asker it is (a car can never sink into a hill).
## - A deck counts only when it is at or below `y_hint + STEP`: found from
##   above (a car on a bridge stays on it), ignored from below (a car on the
##   road under the bridge stays on the road). STEP is how high a wheel or a
##   foot steps up onto a deck's edge.
## - In a cut the terrain counts only where it is at or above the cut's roof
##   and at or below `y_hint + STEP` (the hill over a tunnel); below the roof
##   it is the hole, so a floor deck under the hill wins there.
## - When nothing counts (an asker below every deck in a cut), the lowest
##   deck there is the answer.
## With no deck or cut in a point's grid cell the answer is exactly the
## caller's terrain value, after one dictionary look-up.
##
## API
##   Ground.height(x, z, y_hint := INF) -> float
##       The surface with Terrain.drop applied to the terrain (for one-off
##       look-ups: spawn spots, exits, landings). INF: the top surface.
##   Ground.surface(x, z, base, y_hint := INF) -> float
##       The same with the caller's own terrain value `base` (movers pass
##       Terrain.height - their eased drop). Afterwards `Ground.hit` holds the
##       deck that won (its Dictionary; null for the terrain) and
##       `Ground.hit_grad` that deck's slope (dy/dx, dy/dz).
##   Ground.normal(x, z, y_hint := INF) -> Vector3  up-facing normal there.
##   Ground.add_strip(id, pts, heights, width, kind := "strip")
##       A polyline deck: `pts` (PackedVector2Array, x z), one height per
##       point (the deck's top, linear between points), `width` across.
##       Joins between segments are round; the two ends are square.
##   Ground.add_ramp(id, start, yaw, length, width, profile)
##       A straight deck from `start` (x z; Vector2 or Vector3) heading `yaw`
##       (Godot yaw: forward is -z rotated by yaw) for `length` m; `profile`
##       holds the top heights at evenly spaced stations from start to end
##       (at least 2). kind "ramp".
##   Ground.add_cut(id, pts, roofs, width)
##       A polyline strip where the terrain does not count below `roofs` (one
##       per point, linear between).
##   Ground.remove(id)  removes a deck or a cut;  Ground.clear()  all of them.
##   Ground.deck(id) -> Dictionary (or {}): "id", "kind", "pts", "h", "w"
##       (half width), "len", "dir", and anything the caller stored in it.
##
## Phase 4 (bridges and tunnels): a bridge is add_strip(id, centreline,
## deck heights, carriageway width + kerbs); its piers and parapets are
## ordinary colliders. A tunnel is add_cut(id, centreline portal to portal,
## roof heights, bore width) plus add_strip for its floor (the road's
## heights). Spawners that put a car on a lane under a bridge must pass the
## lane's own height as y_hint (INF finds the bridge).

const Terrain = preload("res://scripts/terrain.gd")

## How high a deck's edge can be over the asker's feet and still be stepped
## onto (and how far a deck can sit over a mover and still be "under" it).
const STEP := 0.6
## Grid cell (m) for bucketing decks and cuts.
const CELL := 32.0

## The deck the last surface()/height() call stood on (null: the terrain).
static var hit = null
## That deck's slope at the point (dy/dx, dy/dz).
static var hit_grad := Vector2.ZERO

static var _items := {} # id -> item Dictionary (decks and cuts)
static var _grid := {} # Vector2i -> Array of [item, segment]


static func height(x: float, z: float, y_hint := INF) -> float:
	return surface(x, z, Terrain.height(x, z) - Terrain.drop(x, z), y_hint)


static func surface(x: float, z: float, base: float, y_hint := INF) -> float:
	hit = null
	if _grid.is_empty():
		return base
	var list = _grid.get(Vector2i(floori(x / CELL), floori(z / CELL)))
	if list == null:
		return base
	var reach := y_hint + STEP
	var p := Vector2(x, z)
	var terrain_counts := true
	var best := -INF
	var best_item = null
	var best_grad := Vector2.ZERO
	var low := INF
	var low_item = null
	var low_grad := Vector2.ZERO
	# Cuts first: they decide whether the terrain counts.
	for e: Array in list:
		var it: Dictionary = e[0]
		if not it.cut:
			continue
		var roof := _on_segment(it, int(e[1]), p)
		if is_nan(roof):
			continue
		if base < roof or base > reach:
			terrain_counts = false
	if terrain_counts:
		best = base
	for e: Array in list:
		var it: Dictionary = e[0]
		if it.cut:
			continue
		var i := int(e[1])
		var h := _on_segment(it, i, p)
		if is_nan(h):
			continue
		if h <= reach and h > best:
			best = h
			best_item = it
			best_grad = it.dir[i] * it.slope[i]
		if h < low:
			low = h
			low_item = it
			low_grad = it.dir[i] * it.slope[i]
	if best == -INF:
		if low_item == null:
			return base
		best = low
		best_item = low_item
		best_grad = low_grad
	hit = best_item
	if hit != null:
		hit_grad = best_grad
	return best


## Up-facing normal of the surface at x, z for an asker at y_hint.
static func normal(x: float, z: float, y_hint := INF) -> Vector3:
	surface(x, z, Terrain.height(x, z), y_hint)
	if hit == null:
		return Terrain.normal(x, z)
	return Vector3(-hit_grad.x, 1.0, -hit_grad.y).normalized()


static func add_strip(id: String, pts: PackedVector2Array, heights: PackedFloat32Array, width: float, kind := "strip") -> Dictionary:
	return _add(id, pts, heights, width, kind, false)


static func add_ramp(id: String, start, yaw: float, length: float, width: float, profile: PackedFloat32Array) -> Dictionary:
	var a := Vector2(start.x, start.z) if start is Vector3 else Vector2(start)
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var n := maxi(profile.size(), 2)
	var pts := PackedVector2Array()
	var hs := PackedFloat32Array()
	for k in n:
		pts.append(a + fwd * length * k / (n - 1))
		hs.append(profile[mini(k, profile.size() - 1)])
	var it := _add(id, pts, hs, width, "ramp", false)
	it["yaw"] = yaw
	it["length"] = length
	return it


static func add_cut(id: String, pts: PackedVector2Array, roofs: PackedFloat32Array, width: float) -> Dictionary:
	return _add(id, pts, roofs, width, "cut", true)


static func remove(id: String) -> void:
	var it = _items.get(id)
	if it == null:
		return
	_items.erase(id)
	for key: Vector2i in it.cells:
		var list: Array = _grid.get(key, [])
		for k in range(list.size() - 1, -1, -1):
			if list[k][0] == it:
				list.remove_at(k)
		if list.is_empty():
			_grid.erase(key)


static func clear() -> void:
	_items.clear()
	_grid.clear()
	hit = null


static func deck(id: String) -> Dictionary:
	return _items.get(id, {})


static func ids() -> Array:
	return _items.keys()


static func _add(id: String, pts: PackedVector2Array, heights: PackedFloat32Array, width: float, kind: String, cut: bool) -> Dictionary:
	remove(id)
	assert(pts.size() >= 2 and heights.size() == pts.size(), "Ground: a strip needs 2+ points and a height per point")
	var it := {"id": id, "kind": kind, "cut": cut, "pts": pts, "h": heights, "w": width * 0.5,
		"dir": PackedVector2Array(), "len": PackedFloat32Array(), "slope": PackedFloat32Array(), "cells": []}
	for i in pts.size() - 1:
		var d := pts[i + 1] - pts[i]
		var l := maxf(d.length(), 0.001)
		it.dir.append(d / l)
		it.len.append(l)
		it.slope.append((heights[i + 1] - heights[i]) / l)
	_items[id] = it
	var cells := {}
	for i in pts.size() - 1:
		var lo := pts[i].min(pts[i + 1]) - Vector2.ONE * it.w
		var hi := pts[i].max(pts[i + 1]) + Vector2.ONE * it.w
		for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
			for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
				var key := Vector2i(cx, cz)
				if not _grid.has(key):
					_grid[key] = []
				_grid[key].append([it, i])
				cells[key] = true
	it.cells = cells.keys()
	return it


## The strip's height (or roof) over p on segment i, NAN when p is off it.
## Interior joins are round (clamped to the shared point); the strip's two
## ends are square.
static func _on_segment(it: Dictionary, i: int, p: Vector2) -> float:
	var a: Vector2 = it.pts[i]
	var d: Vector2 = it.dir[i]
	var l: float = it.len[i]
	var r := p - a
	var t := r.dot(d)
	if (t < 0.0 and i == 0) or (t > l and i == it.len.size() - 1):
		return NAN
	var tc := clampf(t, 0.0, l)
	if (r - d * tc).length_squared() > it.w * it.w:
		return NAN
	return it.h[i] + it.slope[i] * tc
