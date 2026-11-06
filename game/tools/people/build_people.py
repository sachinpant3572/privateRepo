"""Build the crowd body data from MakeHuman (CC0) for CharacterKit.

    MH_DATA=/tmp/mh/mh/makehuman/data python3 game/tools/people/build_people.py

Writes game/assets/people/body.json (layout and per-shape joints) and
body.bin (float32 / int32 blocks). One topology for every shape: the
shapes are MakeHuman macro settings per gender (base, fat, thin, muscle,
old, young, tall, short), each posed into our rest pose with MakeHuman's own proportions; its
joints (our 17 bones) are written per shape, and the game blends shapes and
joints per look. Two meshes simplified from it, each with its own vertex
blocks under a prefix: `crowd/` and a denser `hero/`. Indices per mesh: the
near mesh, plus a far LOD that uses a subset of the same vertices. See
HANDOFF-people-v2.md.
"""
import json
import os
import sys

import meshoptimizer
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mh  # noqa: E402
import pose  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../assets/people")
# Triangles (near, far LOD) per mesh: the crowd's, and a denser one for the
# hero (Sachin, 10-29: "Ensure that our hero has much better structure and
# looks than the NPCs"); there is only one hero on screen.
MESHES = {"crowd": (3000, 1000), "hero": (10000, 3000)}
# Importance by scale: the simplifier keeps more of what is bigger.
HEAD_SCALE = 2.6
HAND_SCALE = 1.5
# Toes sit under shoes: fewer triangles there.
FOOT_SCALE = 0.6
# Fat (Sachin, 10-29: "a bit chubby, then fatty, and then super fat, in all
# different heights and both genders"). MakeHuman's weight macro alone adds
# under 10% to the waist, so the "fat" shape adds its detail targets for the
# belly, waist, hips, thighs, arms, neck and cheeks, pushed past their own
# range: the shape is super fat, and looks use about 0.25 for chubby and 0.55
# for fatty.
FAT_SCALE = 1.7
FAT = {
	"stomach/stomach-pregnant-incr.target": 0.45,
	"measure/measure-waist-circ-incr.target": 1.2,
	"measure/measure-hips-circ-incr.target": 0.6,
	"measure/measure-bust-circ-incr.target": 0.5,
	"measure/measure-underbust-circ-incr.target": 0.7,
	"measure/measure-thigh-circ-incr.target": 0.9,
	"measure/measure-neck-circ-incr.target": 0.8,
	"measure/measure-upperarm-circ-incr.target": 0.8,
	"measure/measure-calf-circ-incr.target": 0.5,
	"buttocks/buttocks-volume-incr.target": 0.7,
	"torso/torso-scale-depth-incr.target": 0.4,
}
for _s in "lr":
	for _n, _w in [("upperarm-fat-incr", 1.0), ("lowerarm-fat-incr", 0.6), ("upperleg-fat-incr", 0.8), ("lowerleg-fat-incr", 0.5)]:
		FAT["armslegs/%s-%s.target" % (_s, _n)] = _w
	FAT["cheek/%s-cheek-volume-incr.target" % _s] = 0.8
	FAT["cheek/%s-cheek-inner-incr.target" % _s] = 0.4
# The face fills out with the body (Sachin, 10-29: "Fat should be visible on
# some of their faces too, based on how much bodyfat do they have"): rounder
# head, wider jaw, double chin.
FAT["head/head-fat-incr.target"] = 0.8
FAT["neck/neck-double-incr.target"] = 0.9
FAT["chin/chin-width-incr.target"] = 0.3
FAT = {k: w * FAT_SCALE for k, w in FAT.items()}
# Gap (m) the arms keep from the body at rest: wider bodies turn them out.
ARM_GAP = 0.012
SHAPES = [
	# name, macro settings. The game blends base + sum w * (shape - base) per
	# look, so these are the extremes of each body-type axis (Sachin, 10-29:
	# short, skinny, muscular, very tall, fat, normal, young, old, mid-aged,
	# just past 18). Mid-aged is about 0.3 of "old" (MakeHuman's own age
	# blend is linear from 25 to 90 years).
	("base", {}),
	("fat", {"weight": 1.0, "details": FAT}),
	("thin", {"weight": 0.0}),
	("muscle", {"muscle": 1.0}),
	("old", {"age": 1.0}),
	# About 18 years (MakeHuman age 0.344); see SAME_HEIGHT.
	("young", {"age": 0.344}),
	# MakeHuman's height macro: longer legs and torso, not a uniform scale.
	# Full weight is 2.5 m (tall) or 1.4 m (short); looks use part of it.
	("tall", {"height": 1.0}),
	("short", {"height": 0.0}),
]
# MakeHuman's age 0.344 blends child and young targets, which leaves an
# 18-year-old 0.19 m shorter than the adult; they stand at adult height.
SAME_HEIGHT = {"young"}
GENDERS = [("male", 1.0), ("female", 0.0)]
# Standing height (m) of each gender's base shape; looks scale it further.
HEIGHT = {"male": 1.76, "female": 1.65}
# Feature parts per vertex (our bone with the most weight).
PARTS = pose.NAMES


def shape(v0, faces, skel, wts, W, gender, stature, details=None, **kw):
	"""One body shape posed into our rest pose, keeping MakeHuman's own proportions.

	Scaled as a whole so the gender's base shape stands `stature` tall (None:
	keep its size), with the sole on y = 0. Forcing the body onto fixed joint
	heights squashed the neck and lifted the shoulders to the chin. The arms
	turn out as far as a wide body needs to keep ARM_GAP from it.
	"""
	v = pose.to_ours(v0 + mh.macro_offsets(len(v0), gender=gender, **kw) + mh.detail_offsets(len(v0), details))
	body = np.unique(faces)
	body = body[body >= 0]
	J = mh.joint_positions(skel, v)
	spread = 0.0
	while True:
		P = pose.pose_rest(skel, J, spread=spread)
		vp = pose.skin_lbs(P, v, wts)
		if spread >= 0.6 or arm_clearance(vp, W, body) >= ARM_GAP:
			break
		spread += 0.02
	pts = pose.mh_points({k: P.apply(J[k], k.split("____")[0]) for k in J})
	eyes = [P.apply(J[e + "____head"], e) for e in ["eye.L", "eye.R"]]
	sole = vp[body, 1].min()
	k = 1.0 if stature is None else stature / (vp[body, 1].max() - sole)
	lift = np.array([0.0, sole, 0.0])
	vf = (vp - lift) * k
	joints = {n: (pts[n] - lift) * k for n in pose.NAMES}
	eyes = [(e - lift) * k for e in eyes]
	return vf, joints, eyes, k


def arm_clearance(v, W, body):
	"""Smallest side gap (m) between the forearm and the torso or thighs
	beside it, in 2 cm slices (the hands may touch the thighs). The upper arm
	of a fat body rests on its side, as people's do."""
	part = np.argmax(W, axis=1)
	trunk = [PARTS.index(n) for n in ["Hips", "Spine", "Chest", "LeftUpperLeg", "RightUpperLeg"]]
	gap = 1.0
	for s, sgn in [("Left", -1.0), ("Right", 1.0)]:
		arm = part == PARTS.index(s + "LowerArm")
		arm = np.intersect1d(np.nonzero(arm)[0], body)
		near = np.intersect1d(np.nonzero(np.isin(part, trunk))[0], body)
		a = v[arm]
		t = v[near]
		t = t[t[:, 0] * sgn > 0.0]
		top = a[:, 1].max()
		for y in np.arange(a[:, 1].min(), top, 0.02):
			sa = a[np.abs(a[:, 1] - y) < 0.01]
			if len(sa) == 0:
				continue
			z0, z1 = sa[:, 2].min(), sa[:, 2].max()
			st = t[(np.abs(t[:, 1] - y) < 0.01) & (t[:, 2] > z0) & (t[:, 2] < z1)]
			if len(st) == 0:
				continue
			gap = min(gap, np.abs(sa[:, 0]).min() - np.abs(st[:, 0]).max())
	return gap


# Face areas per vertex (the `face` block): skin, lips, brows, beard (chin,
# jaw, upper lip, sideburns), beard under the chin, scalp.
FACE_CODES = ["skin", "lips", "brow", "beard", "neck_beard", "scalp"]


def face_codes(v0, quads, wts, skel, W):
	"""Face area of each source vertex, from the MakeHuman face bones' weights
	(lips: oris; brows: oculi; beard: jaw, risorius, levator) and a hairline
	measured from the eyes."""
	n = len(v0)

	def wsum(prefixes):
		s = np.zeros(n)
		for b, (idx, w) in wts.items():
			if b.startswith(prefixes):
				s[idx] += w
		return s
	lips = wsum(("oris",))
	brow = wsum(("oculi",))
	jaw = wsum(("jaw",))
	cheek = wsum(("risorius", "levator", "special0"))
	neck = wsum(("neck",))
	V = pose.to_ours(v0)
	J = mh.joint_positions(skel, v0)
	eye = (pose.to_ours(J["eye.L____head"]) + pose.to_ours(J["eye.R____head"])) * 0.5
	rel = V - eye
	front = -rel[:, 2]  # metres in front of the eyes
	head = np.argmax(W, axis=1) == PARTS.index("Head")
	code = np.zeros(n, dtype=np.int32)
	# Hairline: high on the forehead, down the sides to the nape; not the ears.
	hair_y = np.interp(front, [-0.16, -0.10, -0.03, 0.0, 0.03], [-0.085, -0.05, -0.02, 0.045, 0.05])
	# Ears: what stands out past the skull (about 0.075 m from the middle)
	# beside the eyes' level, grown two edges over the rest of the ear.
	box = (rel[:, 1] > -0.075) & (rel[:, 1] < 0.035) & (front > -0.16) & (front < -0.03) & (np.abs(rel[:, 0]) > 0.064)
	ear = box & (np.abs(rel[:, 0]) > 0.078)
	edges = np.concatenate([quads[:, [0, 1]], quads[:, [1, 2]], quads[:, [2, 3]], quads[:, [3, 0]]])
	for _ in range(2):
		grow = ear.copy()
		hit = ear[edges[:, 0]] | ear[edges[:, 1]]
		grow[edges[hit].reshape(-1)] = True
		ear = grow & box
	code[head & (rel[:, 1] > hair_y) & ~ear] = 5
	beard_y = np.interp(front, [-0.09, -0.06, -0.02, 0.02], [0.0, -0.02, -0.04, -0.045])
	code[head & (jaw + cheek > 0.3) & (rel[:, 1] < beard_y)] = 3
	side = (front > -0.075) & (front < -0.045) & (rel[:, 1] < 0.0) & (rel[:, 1] > -0.06) & (np.abs(rel[:, 0]) > 0.055)
	code[head & (code == 0) & side] = 3
	code[(code == 0) & (neck + jaw > 0.3) & (front > -0.075) & (rel[:, 1] > -0.12)] = 4
	code[head & (brow > 0.3) & (rel[:, 1] > 0.02) & (rel[:, 1] < 0.04) & (np.abs(rel[:, 0]) > 0.015)] = 2
	code[lips > 0.5] = 1
	# Smooth margins, positive inside each area, so the game can cut the
	# border between two areas where it really runs (weights scaled by 0.05
	# to sit near the distances' size). The signs give the codes above.
	parts = np.delete(W, PARTS.index("Head"), axis=1)
	m_head = (W[:, PARTS.index("Head")] - parts.max(axis=1)) * 0.05
	m_lips = (lips - 0.5) * 0.05
	m_scalp = np.minimum(rel[:, 1] - hair_y, m_head)
	m_scalp[ear] = np.minimum(m_scalp[ear], -0.002)
	m_side = np.minimum.reduce([front + 0.075, -0.045 - front, -rel[:, 1], rel[:, 1] + 0.06, np.abs(rel[:, 0]) - 0.055])
	m_beard = np.maximum(np.minimum.reduce([(jaw + cheek - 0.3) * 0.05, beard_y - rel[:, 1], m_head]),
		np.minimum.reduce([m_side, -m_scalp, m_head]))
	m_neck = np.minimum.reduce([(neck + jaw - 0.3) * 0.05, front + 0.075, rel[:, 1] + 0.12, -m_scalp, -m_beard])
	margin = np.stack([m_lips, m_beard, m_neck, m_scalp], axis=1)
	return code, margin


def importance(v, W, joints):
	"""Positions scaled up around the head and hands so they keep more detail."""
	out = v.copy()
	head = W[:, PARTS.index("Head")] + W[:, PARTS.index("Neck")] * 0.5
	c = joints["Head"] + np.array([0.0, 0.09, 0.0])
	out += (v - c) * (HEAD_SCALE - 1.0) * head[:, None]
	for s in ["Left", "Right"]:
		h = W[:, PARTS.index(s + "Hand")]
		c = joints[s + "Hand"]
		out += (v - c) * (HAND_SCALE - 1.0) * h[:, None]
		f = W[:, PARTS.index(s + "Foot")]
		c = joints[s + "Foot"]
		out += (v - c) * (FOOT_SCALE - 1.0) * f[:, None]
	return out


def simplify(idx, pos, tris):
	dst = np.zeros(len(idx), dtype=np.uint32)
	n = meshoptimizer.simplify(dst, idx.astype(np.uint32), pos.astype(np.float32),
		target_index_count=tris * 3, target_error=1.0)
	return dst[:n].astype(np.int64)


def main():
	v0, quads = mh.load_base()
	faces = quads
	tris = np.concatenate([faces[:, [0, 1, 2]], faces[:, [0, 2, 3]]])
	skel = mh.load_skeleton()
	wts = mh.load_weights()
	W = pose.our_weights(len(v0), wts)
	face, face_m = face_codes(v0, quads, wts, skel, W)

	shapes = {}
	for gname, g in GENDERS:
		# One scale per gender (from its base shape), so the shape deltas stay MakeHuman's.
		k = shape(v0, faces, skel, wts, W, g, HEIGHT[gname])[3]
		for sname, kw in SHAPES:
			vf, joints, eyes, ks = shape(v0, faces, skel, wts, W, g, HEIGHT[gname] if sname in SAME_HEIGHT else None, **kw)
			ks = 1.0 if sname in SAME_HEIGHT else k
			shapes[gname + "_" + sname] = (vf * ks, {n: j * ks for n, j in joints.items()}, [e * ks for e in eyes])
			print("shape", gname, sname, flush=True)
	ref, ref_j, _ = shapes["male_base"]
	# Simplify on a body half way to fat, so the triangles follow the belly,
	# hips and back rolls too, not only the slim base.
	simp = importance((ref + shapes["male_fat"][0]) * 0.5, W, ref_j)

	blocks = []
	layout = {}

	def put(name, arr, kind):
		arr = np.ascontiguousarray(arr, dtype=np.float32 if kind == "f" else np.int32)
		layout[name] = {"offset": sum(b.nbytes for b in blocks), "count": int(arr.size), "kind": kind}
		blocks.append(arr)

	meta = {"shapes": list(shapes), "joints": {}, "eyes": {}, "bones": pose.NAMES, "meshes": {}, "face_codes": FACE_CODES,
		"face_margins": ["lips", "beard", "neck_beard", "scalp"],
		"source": "MakeHuman 1.x base mesh, macro targets and default rig (CC0)"}
	for key, (vf, joints, eyes) in shapes.items():
		meta["joints"][key] = {k: [round(float(x), 5) for x in j] for k, j in joints.items()}
		meta["eyes"][key] = [[round(float(x), 5) for x in e] for e in eyes]
	for mesh, (near_n, far_n) in MESHES.items():
		near = simplify(tris.reshape(-1), simp, near_n)
		far = simplify(near, simp, far_n)
		used = np.unique(near)
		remap = -np.ones(len(v0), dtype=np.int64)
		remap[used] = np.arange(len(used))
		near_i = remap[near]
		far_i = remap[far]
		n = len(used)
		print(mesh, "verts", n, "near tris", len(near_i) // 3, "far tris", len(far_i) // 3)
		meta["meshes"][mesh] = {"verts": n}

		# Four strongest bones per vertex.
		Wu = W[used]
		order = np.argsort(-Wu, axis=1)[:, :4]
		bw = np.take_along_axis(Wu, order, axis=1)
		bw /= bw.sum(axis=1, keepdims=True)
		bones = order.astype(np.int32)
		part = order[:, 0].astype(np.int32)

		# Position along the part's bone, 0 at the joint and 1 at the next joint;
		# leaves (head, hands, feet) measure in metres below their joint.
		base = ref[used]
		along = np.zeros(n)
		for i, name in enumerate(PARTS):
			sel = part == i
			j = ref_j[name]
			if name in pose.TAIL:
				t = ref_j[pose.TAIL[name]]
				d = t - j
				along[sel] = (base[sel] - j) @ d / np.dot(d, d)
			else:
				along[sel] = j[1] - base[sel, 1]

		for key, (vf, joints, eyes) in shapes.items():
			put(mesh + "/pos_" + key, vf[used], "f")
		put(mesh + "/near", near_i, "i")
		put(mesh + "/far", far_i, "i")
		put(mesh + "/bones", bones, "i")
		put(mesh + "/weights", bw, "f")
		put(mesh + "/part", part, "i")
		put(mesh + "/along", along, "f")
		put(mesh + "/face", face[used], "i")
		put(mesh + "/face_m", face_m[used], "f")
	meta["layout"] = layout
	os.makedirs(OUT, exist_ok=True)
	with open(os.path.join(OUT, "body.bin"), "wb") as f:
		for b in blocks:
			f.write(b.tobytes())
	with open(os.path.join(OUT, "body.json"), "w") as f:
		json.dump(meta, f, indent=1)
	print("wrote", sum(b.nbytes for b in blocks), "bytes")


if __name__ == "__main__":
	main()
