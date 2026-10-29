extends RefCounted
## MakeHuman (CC0) bodies on our 17-bone skeleton: one topology for everyone,
## blended per look from shapes (base, fat, thin, muscle, old, young, tall,
## short per gender) and skinned with four bones per vertex. Two meshes of
## the same body: the crowd's and a denser one for the hero.
##
## Clothes are regions of the body itself: each triangle takes a region from
## its bone, its place along the bone and the face map (lips, beard, scalp);
## the region gives its colour, and every vertex is pushed out along its
## normal by the thickest cloth that touches it. A vertex on a region border
## is split (one per region, same position), so colours break cleanly.
## CharacterKit adds the rest (collars, prints, hair styles, shoes, bags) on
## top and fits it to the body.
##
## Data: assets/people/body.json and body.bin, from
## tools/people/build_people.py. See HANDOFF-people-v2.md.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")
const JSON_PATH := "res://assets/people/body.json"
const BIN_PATH := "res://assets/people/body.bin"

## Regions a body triangle can be in.
enum { SKIN, LIPS, SCALP, BEARD, TOP, SLEEVE, BOTTOMS, SOCKS, LEGS, HIDDEN }
const REGIONS := 10
## The face map's codes (body.json face_codes).
const FACE_LIPS := 1
const FACE_BEARD := 3
const FACE_NECK_BEARD := 4
const FACE_SCALP := 5
## Bone indices (CharacterKit.BONES order).
const HIPS := 0
const SPINE := 1
const CHEST := 2
const NECK := 3
const HEAD := 4

## Cloth thickness (m) by top, pushed out from the skin.
const TOP_THICK := {"tee": 0.004, "tank": 0.003, "polo": 0.005, "jersey": 0.005, "hoodie": 0.012, "jacket": 0.014,
	"bomber": 0.016, "denim": 0.012, "puffer": 0.036, "puffer_vest": 0.03, "blazer": 0.012, "suit": 0.012,
	"dress": 0.004, "scrubs": 0.006, "hivis": 0.008, "delivery": 0.016, "cardigan": 0.01, "uniform": 0.01}
const BOTTOM_THICK := {"trousers": 0.005, "jeans": 0.005, "joggers": 0.009, "cargo": 0.009, "shorts": 0.006,
	"leggings": 0.0015, "skirt": 0.004, "scrubs": 0.007, "dress": 0.004}
## Hair over the scalp (m) by style; long styles add their own pieces on top.
const HAIR_THICK := {"bald": 0.0, "buzz": 0.0015, "fade": 0.004, "short": 0.008, "curly": 0.012, "afro": 0.012,
	"locs": 0.01, "long": 0.009, "bob": 0.009, "ponytail": 0.006, "bun": 0.006}

static var _meta := {}
static var _raw := PackedByteArray()
static var _blocks := {}
## Blended bodies by look, newest last.
static var _cache := {}
const CACHE_MAX := 48


## body.json, loaded once (the binary blocks with it).
static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
		_raw = FileAccess.get_file_as_bytes(BIN_PATH)
	return _meta


## One block of body.bin: float32 or int32 values.
static func block(name: String):
	if not _blocks.has(name):
		var l: Dictionary = meta().layout[name]
		var bytes := _raw.slice(int(l.offset), int(l.offset) + int(l.count) * 4)
		_blocks[name] = bytes.to_float32_array() if l.kind == "f" else bytes.to_int32_array()
	return _blocks[name]


## A shape's vertex positions in mesh `mesh` ("crowd" or "hero").
static func positions(mesh: String, shape: String) -> PackedVector3Array:
	var key := "v:%s/%s" % [mesh, shape]
	if not _blocks.has(key):
		var f: PackedFloat32Array = block(mesh + "/pos_" + shape)
		var out := PackedVector3Array()
		out.resize(f.size() / 3)
		for i in out.size():
			out[i] = Vector3(f[i * 3], f[i * 3 + 1], f[i * 3 + 2])
		_blocks[key] = out
	return _blocks[key]


static func gender(look: Dictionary) -> String:
	return "female" if look.get("body", "male") == "female" else "male"


## Shape weights for a look: weight (-1 thin .. 1 fat; about 0.25 chubby,
## 0.55 fatty, 1 super fat), muscle (0..1), age (-1 just past 18 .. 1 old;
## 0.25-0.45 mid-aged), stature (-1 short .. 1 tall; looks use up to 0.4).
static func shape_weights(look: Dictionary) -> Dictionary:
	var g := gender(look)
	var w := {}
	var weight: float = look.get("weight", 0.0)
	if weight > 0.0:
		w[g + "_fat"] = weight
	elif weight < 0.0:
		w[g + "_thin"] = -weight
	var muscle: float = look.get("muscle", 0.0)
	if muscle > 0.0:
		w[g + "_muscle"] = muscle
	var age: float = look.get("age", 0.0)
	if age > 0.0:
		w[g + "_old"] = age
	elif age < 0.0:
		w[g + "_young"] = -age
	var stature: float = look.get("stature", 0.0)
	if stature > 0.0:
		w[g + "_tall"] = stature
	elif stature < 0.0:
		w[g + "_short"] = -stature
	return w


## The look's body: positions, smooth normals, joints (by bone name), eye
## centres and the head's box, blended from the shapes. Cached by look.
static func blend(look: Dictionary, mesh := "crowd") -> Dictionary:
	var g := gender(look)
	var w := shape_weights(look)
	var key := mesh + "|" + g
	var names := w.keys()
	names.sort()
	for s in names:
		key += "|%s=%.3f" % [s, w[s]]
	if _cache.has(key):
		var hit: Dictionary = _cache[key]
		_cache.erase(key)
		_cache[key] = hit
		return hit
	var m := meta()
	var base := positions(mesh, g + "_base")
	var pos := base.duplicate()
	var bj: Dictionary = m.joints[g + "_base"]
	var be: Array = m.eyes[g + "_base"]
	var joints := {}
	for bone in bj:
		joints[bone] = _v(bj[bone])
	var eyes := [_v(be[0]), _v(be[1])]
	for s in names:
		var k: float = w[s]
		var sp := positions(mesh, s)
		for i in pos.size():
			pos[i] += (sp[i] - base[i]) * k
		var sj: Dictionary = m.joints[s]
		for bone in sj:
			joints[bone] += (_v(sj[bone]) - _v(bj[bone])) * k
		for e in 2:
			eyes[e] += (_v(m.eyes[s][e]) - _v(be[e])) * k
	var near: PackedInt32Array = block(mesh + "/near")
	var part: PackedInt32Array = block(mesh + "/part")
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for i in pos.size():
		if part[i] == HEAD:
			lo = lo.min(pos[i])
			hi = hi.max(pos[i])
	var out := {"mesh": mesh, "gender": g, "pos": pos, "normals": normals(pos, near), "joints": joints,
		"eyes": eyes, "head": AABB(lo, hi - lo)}
	if _cache.size() >= CACHE_MAX:
		_cache.erase(_cache.keys()[0])
	_cache[key] = out
	return out


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Smooth (area-weighted) vertex normals over triangles `idx`.
static func normals(pos: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var n := PackedVector3Array()
	n.resize(pos.size())
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var f := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		n[a] += f
		n[b] += f
		n[c] += f
	for i in n.size():
		n[i] = n[i].normalized()
	return n


## Region rules and colours from the look and CharacterKit's spec `o`.
static func _dress(look: Dictionary, o: Dictionary) -> Dictionary:
	var outfit: String = o.outfit
	var bottoms: String = o.bottoms
	var style: String = look.get("hair", "short")
	if style in ["cap", "beanie", "police"]:
		style = "short"
	var hair: Color = look.get("hair_color", Color(0.08, 0.06, 0.05))
	var skin: Color = o.skin
	var colors := []
	colors.resize(REGIONS)
	var thick := PackedFloat32Array()
	thick.resize(REGIONS)
	colors[SKIN] = skin
	colors[LIPS] = skin.lerp(Color(0.6, 0.28, 0.28), 0.3).darkened(0.1)
	colors[SCALP] = skin if style == "bald" else (hair.lerp(skin, 0.35) if style == "buzz" else hair)
	thick[SCALP] = HAIR_THICK.get(style, 0.008)
	# Beard: false, true (full) or a length 0..1 (stubble to full).
	var beard = look.get("beard", false)
	var length: float = (1.0 if beard else 0.0) if beard is bool else float(beard)
	var beard_color: Color = look.get("beard_color", hair)
	colors[BEARD] = skin.lerp(beard_color, clampf(length * 4.0, 0.0, 1.0) * (0.45 + 0.55 * clampf(length * 2.0, 0.0, 1.0)))
	thick[BEARD] = 0.012 * clampf((length - 0.15) / 0.85, 0.0, 1.0)
	colors[TOP] = o.top
	thick[TOP] = TOP_THICK.get(outfit, 0.006)
	colors[SLEEVE] = o.sleeve
	thick[SLEEVE] = thick[TOP]
	colors[BOTTOMS] = o.pants if bottoms != "dress" else o.top
	thick[BOTTOMS] = BOTTOM_THICK.get(bottoms, 0.005)
	colors[SOCKS] = look.get("socks", Color(0.92, 0.91, 0.88))
	thick[SOCKS] = 0.002
	colors[LEGS] = look.get("tights", skin)
	thick[LEGS] = 0.0008 if look.has("tights") else 0.0
	colors[HIDDEN] = skin
	# Where the top ends on the hips (0 at the hip joint, 1 at the spine
	# joint): jackets and long tops lower, tucked shirts at the belt.
	var waist := 0.55
	if outfit in ["jacket", "bomber", "puffer", "hoodie", "blazer", "suit", "denim", "cardigan", "delivery"]:
		waist = 0.15
	elif outfit in ["uniform", "polo"]:
		waist = 0.6
	if outfit == "dress" or bottoms == "dress":
		waist = -1.0
	return {"colors": colors, "thick": thick, "waist": waist, "sleeves": o.sleeves, "bottoms": bottoms,
		"shorts": bottoms in ["shorts", "skirt", "dress"], "socks": o.shoe_style in ["sneakers", "dress"],
		"feet": o.shoe_style == "slides", "scoop": 0.06 if outfit in ["tank", "dress"] else 0.0,
		"bare_shoulders": o.sleeves == "none"}


## The region of one triangle: its bone `part`, mean place along the bone,
## canonical centroid `c` (base shape), face code; `cj` the base joints.
static func _region(part: int, along: float, c: Vector3, code: int, cj: Dictionary, d: Dictionary) -> int:
	match part:
		HEAD:
			if code == FACE_LIPS:
				return LIPS
			if code == FACE_SCALP:
				return SCALP
			if code == FACE_BEARD or code == FACE_NECK_BEARD:
				return BEARD
			return SKIN
		NECK:
			return BEARD if code == FACE_NECK_BEARD or code == FACE_BEARD else SKIN
		CHEST, SPINE:
			var neck: Vector3 = cj.Neck
			if d.scoop > 0.0 and c.y > neck.y - d.scoop - 0.03 and c.z < neck.z - 0.02:
				return SKIN
			if d.bare_shoulders and c.y > neck.y - 0.08 and absf(c.x) > 0.085:
				return SKIN
			return TOP
		HIPS:
			if along > d.waist:
				return TOP
			return LEGS if d.bottoms == "dress" else BOTTOMS
		5, 8:  # upper arms
			if d.sleeves == "long" or (d.sleeves == "short" and along < 0.42):
				return SLEEVE
			return SKIN
		6, 9:  # forearms
			return SLEEVE if d.sleeves == "long" and along < 0.93 else SKIN
		7, 10:  # hands
			return SKIN
		11, 14:  # thighs
			if d.bottoms in ["skirt", "dress"]:
				return LEGS
			if d.bottoms == "shorts":
				return BOTTOMS if along < 0.55 else LEGS
			return BOTTOMS
		12, 15:  # shins
			if not d.shorts:
				return BOTTOMS
			if d.socks and along > 0.86:
				return SOCKS
			return LEGS
	# Feet: inside the shoes, except in slides.
	return SKIN if d.feet else HIDDEN


## Adds the look's body to `mb` (near and far detail levels, skinned) and
## returns the blended body (see blend()). `o` is CharacterKit's spec.
static func add_body(mb, look: Dictionary, o: Dictionary, mesh := "crowd") -> Dictionary:
	var b := blend(look, mesh)
	var g: String = b.gender
	var pos: PackedVector3Array = b.pos
	var nrm: PackedVector3Array = b.normals
	var part: PackedInt32Array = block(mesh + "/part")
	var along: PackedFloat32Array = block(mesh + "/along")
	var face: PackedInt32Array = block(mesh + "/face")
	var bones: PackedInt32Array = block(mesh + "/bones")
	var weights: PackedFloat32Array = block(mesh + "/weights")
	var canon := positions(mesh, g + "_base")
	var cj := {}
	var mj: Dictionary = meta().joints[g + "_base"]
	for bone in mj:
		cj[bone] = _v(mj[bone])
	var d := _dress(look, o)
	var colors: Array = d.colors
	var thick: PackedFloat32Array = d.thick
	var lists: Array = [block(mesh + "/near"), block(mesh + "/far")]
	var regs := []
	var push := PackedFloat32Array()
	push.resize(pos.size())
	for idx: PackedInt32Array in lists:
		var r := PackedByteArray()
		r.resize(idx.size() / 3)
		for t in r.size():
			var a := idx[t * 3]
			var bb := idx[t * 3 + 1]
			var cc := idx[t * 3 + 2]
			var p := part[a] if part[a] == part[bb] or part[a] == part[cc] else part[bb]
			var code := face[a] if face[a] == face[bb] or face[a] == face[cc] else face[bb]
			if face[bb] != face[cc] and face[a] != face[bb] and face[a] != face[cc]:
				code = 0
			var reg := _region(p, (along[a] + along[bb] + along[cc]) / 3.0, (canon[a] + canon[bb] + canon[cc]) / 3.0,
				code, cj, d)
			r[t] = reg
			if reg != HIDDEN:
				for v in [a, bb, cc]:
					push[v] = maxf(push[v], thick[reg])
		regs.append(r)
	var first: int = mb.verts.size()
	var slot := PackedInt32Array()
	slot.resize(pos.size() * REGIONS)
	slot.fill(-1)
	var sb := PackedInt32Array()
	var sw := PackedFloat32Array()
	for l in 2:
		mb.set_lod(MeshBuilder.LOD_NEAR if l == 0 else MeshBuilder.LOD_FAR)
		var idx: PackedInt32Array = lists[l]
		var r: PackedByteArray = regs[l]
		for t in r.size():
			var reg: int = r[t]
			if reg == HIDDEN:
				continue
			var ids := PackedInt32Array([0, 0, 0])
			for k in 3:
				var v := idx[t * 3 + k]
				var s := v * REGIONS + reg
				if slot[s] < 0:
					slot[s] = mb.verts.size()
					mb._vert(pos[v] + nrm[v] * push[v], nrm[v], colors[reg])
					for q in 4:
						sb.append(bones[v * 4 + q])
						sw.append(weights[v * 4 + q])
				ids[k] = slot[s]
			mb._tri_idx(ids[0], ids[1], ids[2])
	mb.skin(first, sb, sw)
	mb.set_lod(MeshBuilder.LOD_BOTH)
	return b


## Eyeballs with irises and brows at the body's eye centres (head bone).
static func add_eyes(mb, look: Dictionary, b: Dictionary, fine: bool) -> void:
	var iris: Color = look.get("eyes", Color(0.2, 0.13, 0.08))
	var brow: Color = look.get("hair_color", Color(0.08, 0.06, 0.05)).darkened(0.3)
	var sides := 10 if fine else 6
	for e in 2:
		var c: Vector3 = b.eyes[e]
		var out := signf(c.x)
		mb.smooth_ball(c, Vector3(0.0118, 0.0118, 0.0118), Color(0.93, 0.92, 0.89), sides, 4)
		mb.smooth_ball(c + Vector3(0, 0, -0.0095), Vector3(0.0058, 0.0062, 0.003), iris, sides, 3)
		mb.smooth_ball(c + Vector3(out * 0.003, 0.0185, -0.0075), Vector3(0.0165, 0.0034, 0.0045), brow, sides, 3)
