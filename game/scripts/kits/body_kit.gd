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
const BONE_NAMES := ["Hips", "Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg",
	"RightLowerLeg", "RightFoot"]

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
	# The hero is athletic unless the look says otherwise.
	var hero: bool = look.get("hero", false)
	var muscle: float = look.get("muscle", 0.5 if hero else 0.0)
	if muscle > 0.0:
		w[g + "_muscle"] = muscle
	var age: float = look.get("age", 0.0)
	if age > 0.0:
		w[g + "_old"] = age
	elif age < 0.0:
		w[g + "_young"] = -age
	var stature: float = look.get("stature", 0.15 if hero else 0.0)
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


## The region of a point of the body: its bone `part`, place along the bone,
## canonical position `c` (base shape), face code; `cj` the base joints.
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
			if part == SPINE and _below_waist(c, cj, d):
				return LEGS if d.bottoms == "dress" else BOTTOMS
			var neck: Vector3 = cj.Neck
			if d.scoop > 0.0 and c.y > neck.y - d.scoop - 0.03 and c.z < neck.z - 0.02:
				return SKIN
			if d.bare_shoulders and c.y > neck.y - 0.08 and absf(c.x) > 0.085:
				return SKIN
			return TOP
		HIPS:
			if not _below_waist(c, cj, d):
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
				# The skirt's own colour high on the thighs, where full thighs
				# reach out past its shell.
				if along < 0.3:
					return TOP if d.bottoms == "dress" else BOTTOMS
				return LEGS
			if d.bottoms == "shorts":
				return BOTTOMS if along < 0.74 else LEGS
			return BOTTOMS
		12, 15:  # shins
			if not d.shorts:
				return BOTTOMS
			if d.socks and along > 0.75:
				return SOCKS
			return LEGS
	# Feet: inside the shoes, except in slides.
	return SKIN if d.feet else HIDDEN


## Whether a torso point (base shape) is under the waistband: a level line
## (bones' own borders are ragged), none when the top covers the hips.
static func _below_waist(c: Vector3, cj: Dictionary, d: Dictionary) -> bool:
	return d.waist >= 0.0 and c.y < lerpf(cj.Hips.y, cj.Spine.y, d.waist)


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
	# Regions per vertex; a triangle whose corners differ is cut where the
	# region changes along its edges, so hems and the face's paint run as
	# lines rather than following the triangles' sawtooth.
	# Regions that look the same (a shaven chin, sleeves in the shirt's
	# colour) count as one, so only edges that show cost triangles.
	var same := PackedByteArray()
	same.resize(REGIONS)
	for r in REGIONS:
		same[r] = r
		for e in r:
			if r != HIDDEN and e != HIDDEN and colors[e] == colors[r] and thick[e] == thick[r]:
				same[r] = e
				break
	var rv := PackedByteArray()
	rv.resize(pos.size())
	for v in pos.size():
		rv[v] = same[_region(part[v], along[v], canon[v], face[v], cj, d)]
	var push := PackedFloat32Array()
	push.resize(pos.size())
	for idx: PackedInt32Array in lists:
		for t in range(0, idx.size(), 3):
			var th := 0.0
			for k in 3:
				if rv[idx[t + k]] != HIDDEN:
					th = maxf(th, thick[rv[idx[t + k]]])
			for k in 3:
				push[idx[t + k]] = maxf(push[idx[t + k]], th)
	var first: int = mb.verts.size()
	# Arrays, not packed ones: the lambdas below share them by reference.
	var slot := []
	slot.resize(pos.size() * REGIONS)
	slot.fill(-1)
	var cuts := {}
	var sb := []
	var sw := []
	var put := func(v: int, reg: int) -> int:
		var s := v * REGIONS + reg
		if slot[s] < 0:
			slot[s] = mb.verts.size()
			mb._vert(pos[v] + nrm[v] * push[v], nrm[v], colors[reg])
			for q in 4:
				sb.append(bones[v * 4 + q])
				sw.append(weights[v * 4 + q])
		return slot[s]
	# The point on edge e0-e1 where the region turns (found from the lower
	# index, so both triangles on the edge agree), one vertex per region.
	var cut := func(e0: int, e1: int, reg: int) -> int:
		var a := mini(e0, e1)
		var bb := maxi(e0, e1)
		var key := (a * pos.size() + bb) * REGIONS + reg
		if cuts.has(key):
			return cuts[key]
		var t := 0.5
		if face[a] == face[bb] and (part[a] == part[bb] or (part[a] <= SPINE and part[bb] <= SPINE)):
			var lo := 0.0
			var hi := 1.0
			for it in 6:
				t = (lo + hi) * 0.5
				var r := same[_region(part[a], lerpf(along[a], along[bb], t), canon[a].lerp(canon[bb], t), face[a], cj, d)]
				if r == rv[a]:
					lo = t
				else:
					hi = t
			t = (lo + hi) * 0.5
		elif part[a] != part[bb]:
			# Across two bones' parts (part is the bone weighing most): where
			# their weights are equal, which runs smoothly round the joint.
			var f0 := 0.0
			var f1 := 0.0
			for q in 4:
				var ba := bones[a * 4 + q]
				var bz := bones[bb * 4 + q]
				f0 += weights[a * 4 + q] * (1.0 if ba == part[a] else (-1.0 if ba == part[bb] else 0.0))
				f1 += weights[bb * 4 + q] * (1.0 if bz == part[a] else (-1.0 if bz == part[bb] else 0.0))
			if f0 - f1 > 1e-5:
				t = clampf(f0 / (f0 - f1), 0.05, 0.95)
		var n := nrm[a].lerp(nrm[bb], t).normalized()
		var at := pos[a].lerp(pos[bb], t) + n * lerpf(push[a], push[bb], t)
		cuts[key] = mb.verts.size()
		mb._vert(at, n, colors[reg])
		var mix := {}
		for q in 4:
			mix[bones[a * 4 + q]] = mix.get(bones[a * 4 + q], 0.0) + weights[a * 4 + q] * (1.0 - t)
			mix[bones[bb * 4 + q]] = mix.get(bones[bb * 4 + q], 0.0) + weights[bb * 4 + q] * t
		var ks: Array = mix.keys()
		ks.sort_custom(func(x, y): return mix[x] > mix[y])
		var sum := 0.0
		for q in 4:
			sum += mix[ks[q]] if q < ks.size() else 0.0
		for q in 4:
			sb.append(ks[q] if q < ks.size() else 0)
			sw.append(mix[ks[q]] / sum if q < ks.size() else 0.0)
		return cuts[key]
	for l in 2:
		mb.set_lod(MeshBuilder.LOD_NEAR if l == 0 else MeshBuilder.LOD_FAR)
		var idx: PackedInt32Array = lists[l]
		for t in range(0, idx.size(), 3):
			var c := [idx[t], idx[t + 1], idx[t + 2]]
			var r := [rv[c[0]], rv[c[1]], rv[c[2]]]
			if r[0] == r[1] and r[1] == r[2]:
				if r[0] != HIDDEN:
					mb._tri_idx(put.call(c[0], r[0]), put.call(c[1], r[0]), put.call(c[2], r[0]))
				continue
			# The corner alone in its region goes first. The far level, the
			# shoes' hidden feet and three regions keep the whole triangle in
			# one region (the corners' majority, or the first).
			var k := 0
			if r[0] == r[1]:
				k = 2
			elif r[0] == r[2]:
				k = 1
			if l == 1 or HIDDEN in r or (k == 0 and r[1] != r[2]):
				var reg: int = r[0] if k == 0 and r[1] != r[2] else r[(k + 1) % 3]
				if reg != HIDDEN:
					mb._tri_idx(put.call(c[0], reg), put.call(c[1], reg), put.call(c[2], reg))
				continue
			var a: int = c[k]
			var m: int = c[(k + 1) % 3]
			var nn: int = c[(k + 2) % 3]
			var ra: int = r[k]
			var rb: int = r[(k + 1) % 3]
			if ra != HIDDEN:
				mb._tri_idx(put.call(a, ra), cut.call(a, m, ra), cut.call(a, nn, ra))
			if rb != HIDDEN:
				var pm: int = cut.call(a, m, rb)
				var pn: int = cut.call(a, nn, rb)
				mb._tri_idx(pm, put.call(m, rb), put.call(nn, rb))
				mb._tri_idx(pm, put.call(nn, rb), pn)
	mb.skin(first, PackedInt32Array(sb), PackedFloat32Array(sw))
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


# --- Fit tables (CharacterKit fits its collars, hems, hats and shoes with them)

## Height step and angle bins of the torso and neck slices.
const SLICE_STEP := 0.02
const SLICE_BINS := 16
## Limb radius table: bins along the bone and round it.
const LIMB_ALONG := 6
const LIMB_BINS := 8
## Limb parts and the joint each runs to (CharacterKit.BONES order).
const LIMBS := {5: 6, 6: 7, 8: 9, 9: 10, 11: 12, 12: 13, 14: 15, 15: 16}


## The body's measures for fitting the kit's parts to it, cached in `b`:
## torso and neck slices (outline per height), the neckline, limb radii, the shoulder-top
## line, hand centres, foot boxes and the head's front, back, crown and
## forehead width. Measured on the bare body (cloth is added on top).
static func fit(b: Dictionary) -> Dictionary:
	if b.has("fit"):
		return b.fit
	var pos: PackedVector3Array = b.pos
	var part: PackedInt32Array = block(b.mesh + "/part")
	var near: PackedInt32Array = block(b.mesh + "/near")
	var j: Dictionary = b.joints
	# The torso takes in the shoulder caps (things cross the shoulders onto
	# them) and the thighs (skirts and aprons hang over them).
	var arm_y: float = j.LeftUpperArm.y - 0.04
	var torso := PackedByteArray()
	var neck := PackedByteArray()
	torso.resize(pos.size())
	neck.resize(pos.size())
	var top := PackedFloat32Array()
	top.resize(32)
	top.fill(-1.0)
	var shoulder := 0.0
	var boxes := {}
	var nj: Vector3 = j.Neck
	for i in pos.size():
		var p := part[i]
		var v := pos[i]
		var cap := (p == 5 or p == 8) and v.y > arm_y
		torso[i] = 1 if p <= CHEST or p == 11 or p == 14 or cap else 0
		# The neck, with the chest round its foot (collars sit there).
		neck[i] = 1 if p == NECK or ((p == CHEST or p == SPINE) and v.y > nj.y - 0.12
			and Vector2(v.x, v.z - nj.z).length() < 0.14) else 0
		if p == SPINE or p == CHEST or cap:
			var k := mini(int(absf(v.x) / 0.01), top.size() - 1)
			top[k] = maxf(top[k], v.y)
		if cap:
			shoulder = maxf(shoulder, absf(v.x))
		if p in [7, 10, 13, 16]:
			if not boxes.has(p):
				boxes[p] = AABB(v, Vector3.ZERO)
			boxes[p] = boxes[p].expand(v)
	_fill(top, 1)
	var head: AABB = b.head
	var eye: Vector3 = (b.eyes[0] + b.eyes[1]) * 0.5
	var brow := 0.0
	for i in pos.size():
		if part[i] == HEAD and pos[i].y > eye.y + 0.03 and pos[i].y < eye.y + 0.05:
			brow = maxf(brow, absf(pos[i].x))
	var limbs := {}
	for p in LIMBS:
		limbs[p] = _limb_table(pos, part, p, j[BONE_NAMES[p]], j[BONE_NAMES[LIMBS[p]]])
	var ns := _slices(pos, near, neck)
	var f := {"torso": _slices(pos, near, torso), "neck": ns, "neckline": _neckline(ns, nj.y), "top": top, "shoulder": shoulder,
		"limbs": limbs, "hands": [boxes[7].get_center(), boxes[10].get_center()], "feet": [boxes[13], boxes[16]],
		"eye": eye, "crown": head.end.y, "back": head.end.z, "brow": brow}
	b["fit"] = f
	return f


## Where the neck rises out of the chest and shoulders, per slice angle bin:
## the lowest height from which the neck slices stay within 1.5 cm of the
## neck's own radius (2 cm over the neck joint), at the back no lower than
## 3 cm under the joint.
static func _neckline(ns: Dictionary, neck_y: float) -> PackedFloat32Array:
	var line := PackedFloat32Array()
	line.resize(SLICE_BINS)
	for bin in SLICE_BINS:
		var phi := (bin + 0.5) / SLICE_BINS * TAU - PI
		var rn := slice_r(ns, neck_y + 0.02, phi) + 0.015
		var y := neck_y + 0.02
		while y > neck_y - 0.11 and slice_r(ns, y - 0.005, phi) <= rn:
			y -= 0.005
		# A flat upper back (women's) would let it slide down the back.
		line[bin] = maxf(y, neck_y - 0.03) if sin(phi) > 0.0 else y
	return line


## The neckline's height at angle phi (atan2(z - cz, x)).
static func neckline_y(line: PackedFloat32Array, phi: float) -> float:
	var fa := (phi + PI) / TAU * SLICE_BINS - 0.5
	var b0 := int(floorf(fa))
	return lerpf(line[posmod(b0, SLICE_BINS)], line[posmod(b0 + 1, SLICE_BINS)], fa - b0)


## Fills the gaps (-1) in `a` from the nearest set entries, linearly
## between them. Past the ends, hold 1 keeps the end values and hold 0 wraps
## round (angle bins).
static func _fill(a: PackedFloat32Array, hold := 1) -> void:
	var n := a.size()
	var have := []
	for k in n:
		if a[k] >= 0.0:
			have.append(k)
	if have.is_empty():
		a.fill(0.0)
		return
	for k in n:
		if a[k] >= 0.0:
			continue
		var lo := -1
		var hi := -1
		for s in have:
			if s < k:
				lo = s
			elif hi < 0:
				hi = s
		if hold == 0:
			# Round the circle.
			if lo < 0:
				lo = have[-1] - n
			if hi < 0:
				hi = have[0] + n
			a[k] = lerpf(a[posmod(lo, n)], a[posmod(hi, n)], float(k - lo) / (hi - lo))
		elif lo < 0:
			a[k] = a[hi]
		elif hi < 0:
			a[k] = a[lo]
		else:
			a[k] = lerpf(a[lo], a[hi], float(k - lo) / (hi - lo))


## The outline of the vertices in `mask` at heights SLICE_STEP apart, from
## where triangle edges cross each height: per level the depth centre cz and
## the furthest point in each of SLICE_BINS angle bins round (0, cz), the
## angle being atan2(z - cz, x).
static func _slices(pos: PackedVector3Array, idx: PackedInt32Array, mask: PackedByteArray) -> Dictionary:
	var lo := INF
	var hi := -INF
	for i in pos.size():
		if mask[i]:
			lo = minf(lo, pos[i].y)
			hi = maxf(hi, pos[i].y)
	var y0 := ceilf(lo / SLICE_STEP) * SLICE_STEP
	var n := int(floorf((hi - y0) / SLICE_STEP)) + 1
	var pts := []
	for k in n:
		pts.append(PackedVector2Array())
	for t in range(0, idx.size(), 3):
		for e in 3:
			var a := idx[t + e]
			var c := idx[t + (e + 1) % 3]
			if mask[a] == 0 or mask[c] == 0:
				continue
			var pa := pos[a]
			var pc := pos[c]
			if pa.y > pc.y:
				var sw := pa
				pa = pc
				pc = sw
			if pc.y - pa.y < 1e-6:
				continue
			for k in range(maxi(ceili((pa.y - y0) / SLICE_STEP), 0), mini(floori((pc.y - y0) / SLICE_STEP), n - 1) + 1):
				var q := pa.lerp(pc, (y0 + k * SLICE_STEP - pa.y) / (pc.y - pa.y))
				pts[k].append(Vector2(q.x, q.z))
	var cz := PackedFloat32Array()
	cz.resize(n)
	cz.fill(-INF)
	var r := PackedFloat32Array()
	r.resize(n * SLICE_BINS)
	r.fill(-1.0)
	for k in n:
		var level: PackedVector2Array = pts[k]
		if level.is_empty():
			continue
		var z0 := INF
		var z1 := -INF
		for q in level:
			z0 = minf(z0, q.y)
			z1 = maxf(z1, q.y)
		cz[k] = (z0 + z1) * 0.5
		var bins := PackedFloat32Array()
		bins.resize(SLICE_BINS)
		bins.fill(-1.0)
		for q in level:
			var d := Vector2(q.x, q.y - cz[k])
			var bin := posmod(int(floorf((d.angle() + PI) / TAU * SLICE_BINS)), SLICE_BINS)
			bins[bin] = maxf(bins[bin], d.length())
		_fill(bins, 0)
		for bin in SLICE_BINS:
			r[k * SLICE_BINS + bin] = bins[bin]
	# Levels with nothing take the nearest level's outline.
	for k in n:
		if cz[k] > -INF:
			continue
		var near := -1
		for d in n:
			if k - d >= 0 and cz[k - d] > -INF:
				near = k - d
				break
			if k + d < n and cz[k + d] > -INF:
				near = k + d
				break
		cz[k] = cz[near]
		for bin in SLICE_BINS:
			r[k * SLICE_BINS + bin] = r[near * SLICE_BINS + bin]
	return {"y0": y0, "n": n, "cz": cz, "r": r}


## The slice outline's radius at height y (held at the ends) and angle phi.
static func slice_r(s: Dictionary, y: float, phi: float) -> float:
	var r: PackedFloat32Array = s.r
	var fy := clampf((y - s.y0) / SLICE_STEP, 0.0, s.n - 1)
	var k0 := int(fy)
	var k1 := mini(k0 + 1, s.n - 1)
	var fa := (phi + PI) / TAU * SLICE_BINS - 0.5
	var b0 := int(floorf(fa))
	var u := fa - b0
	b0 = posmod(b0, SLICE_BINS)
	var b1 := (b0 + 1) % SLICE_BINS
	var r0 := lerpf(r[k0 * SLICE_BINS + b0], r[k0 * SLICE_BINS + b1], u)
	var r1 := lerpf(r[k1 * SLICE_BINS + b0], r[k1 * SLICE_BINS + b1], u)
	return lerpf(r0, r1, fy - k0)


## The slice's depth centre at height y.
static func slice_cz(s: Dictionary, y: float) -> float:
	var cz: PackedFloat32Array = s.cz
	var fy := clampf((y - s.y0) / SLICE_STEP, 0.0, s.n - 1)
	var k0 := int(fy)
	return lerpf(cz[k0], cz[mini(k0 + 1, s.n - 1)], fy - k0)


## A limb's frame from joint a to joint b: [direction, front-facing side
## axis, the third axis].
static func limb_frame(a: Vector3, b: Vector3) -> Array:
	var d := (b - a).normalized()
	var u := (Vector3(0, 0, -1) - d * d.z * -1.0).normalized()
	return [d, u, d.cross(u)]


## Part `p`'s furthest vertex from its bone a..b per bin along (LIMB_ALONG)
## and round it (LIMB_BINS, angle atan2(q.w, q.u) in limb_frame()).
static func _limb_table(pos: PackedVector3Array, part: PackedInt32Array, p: int, a: Vector3, b: Vector3) -> PackedFloat32Array:
	var fr := limb_frame(a, b)
	var d: Vector3 = fr[0]
	var length := a.distance_to(b)
	var r := PackedFloat32Array()
	r.resize(LIMB_ALONG * LIMB_BINS)
	r.fill(-1.0)
	for i in pos.size():
		if part[i] != p:
			continue
		var t := (pos[i] - a).dot(d) / length
		if t < 0.0 or t >= 1.0:
			continue
		var q := pos[i] - a - d * (t * length)
		var bin := posmod(int(floorf((atan2(q.dot(fr[2]), q.dot(fr[1])) + PI) / TAU * LIMB_BINS)), LIMB_BINS)
		var s := int(t * LIMB_ALONG) * LIMB_BINS + bin
		r[s] = maxf(r[s], q.length())
	# Gaps round each ring, then whole rings from their neighbours.
	var rings := PackedFloat32Array()
	rings.resize(LIMB_ALONG)
	rings.fill(-1.0)
	for k in LIMB_ALONG:
		var ring := r.slice(k * LIMB_BINS, (k + 1) * LIMB_BINS)
		var any := false
		for x in ring:
			any = any or x >= 0.0
		if not any:
			continue
		_fill(ring, 0)
		rings[k] = 1.0
		for bin in LIMB_BINS:
			r[k * LIMB_BINS + bin] = ring[bin]
	for k in LIMB_ALONG:
		if rings[k] >= 0.0:
			continue
		var near := k
		for dk in LIMB_ALONG:
			if k - dk >= 0 and rings[k - dk] >= 0.0:
				near = k - dk
				break
			if k + dk < LIMB_ALONG and rings[k + dk] >= 0.0:
				near = k + dk
				break
		for bin in LIMB_BINS:
			r[k * LIMB_BINS + bin] = r[near * LIMB_BINS + bin]
	return r


## The limb table's radius at t along (0..1, held at the ends) and angle a.
static func limb_r(r: PackedFloat32Array, t: float, a: float) -> float:
	var ft := clampf(t * LIMB_ALONG - 0.5, 0.0, LIMB_ALONG - 1)
	var k0 := int(ft)
	var k1 := mini(k0 + 1, LIMB_ALONG - 1)
	var fa := (a + PI) / TAU * LIMB_BINS - 0.5
	var b0 := int(floorf(fa))
	var u := fa - b0
	b0 = posmod(b0, LIMB_BINS)
	var b1 := (b0 + 1) % LIMB_BINS
	return lerpf(lerpf(r[k0 * LIMB_BINS + b0], r[k0 * LIMB_BINS + b1], u),
		lerpf(r[k1 * LIMB_BINS + b0], r[k1 * LIMB_BINS + b1], u), ft - k0)
