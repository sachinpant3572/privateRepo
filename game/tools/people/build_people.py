"""Build the crowd body data from MakeHuman (CC0) for CharacterKit.

    MH_DATA=/tmp/mh/mh/makehuman/data python3 game/tools/people/build_people.py

Writes game/assets/people/body.json (layout and per-shape joints) and
body.bin (float32 / int32 blocks). One topology for every shape: the
shapes are MakeHuman macro settings per gender (base, heavy, thin, muscle,
old, young, tall, short), each posed into our rest pose with MakeHuman's own proportions; its
joints (our 17 bones) are written per shape, and the game blends shapes and
joints per look. Indices: the near mesh, plus a far LOD that uses a subset
of the same vertices. See HANDOFF-people-v2.md.
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
NEAR_TRIS = 3000
FAR_TRIS = 1000
# Importance by scale: the simplifier keeps more of what is bigger.
HEAD_SCALE = 2.6
HAND_SCALE = 1.5
# Toes sit under shoes: fewer triangles there.
FOOT_SCALE = 0.6
SHAPES = [
	# name, macro settings. The game blends base + sum w * (shape - base) per
	# look, so these are the extremes of each body-type axis (Sachin, 10-29:
	# short, skinny, muscular, very tall, fat, normal, young, old, mid-aged,
	# just past 18). Mid-aged is about 0.3 of "old" (MakeHuman's own age
	# blend is linear from 25 to 90 years).
	("base", {}),
	("heavy", {"weight": 1.0}),
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


def shape(v0, faces, skel, wts, gender, stature, **kw):
	"""One body shape posed into our rest pose, keeping MakeHuman's own proportions.

	Scaled as a whole so the gender's base shape stands `stature` tall (None:
	keep its size), with the sole on y = 0. Forcing the body onto fixed joint
	heights squashed the neck and lifted the shoulders to the chin.
	"""
	v = pose.to_ours(v0 + mh.macro_offsets(len(v0), gender=gender, **kw))
	body = np.unique(faces)
	J = mh.joint_positions(skel, v)
	P = pose.pose_rest(skel, J)
	vp = pose.skin_lbs(P, v, wts)
	pts = pose.mh_points({k: P.apply(J[k], k.split("____")[0]) for k in J})
	eyes = [P.apply(J[e + "____head"], e) for e in ["eye.L", "eye.R"]]
	sole = vp[body, 1].min()
	k = 1.0 if stature is None else stature / (vp[body, 1].max() - sole)
	lift = np.array([0.0, sole, 0.0])
	vf = (vp - lift) * k
	joints = {n: (pts[n] - lift) * k for n in pose.NAMES}
	eyes = [(e - lift) * k for e in eyes]
	return vf, joints, eyes, k


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

	shapes = {}
	for gname, g in GENDERS:
		# One scale per gender (from its base shape), so the shape deltas stay MakeHuman's.
		k = shape(v0, faces, skel, wts, g, HEIGHT[gname])[3]
		for sname, kw in SHAPES:
			vf, joints, eyes, ks = shape(v0, faces, skel, wts, g, HEIGHT[gname] if sname in SAME_HEIGHT else None, **kw)
			ks = 1.0 if sname in SAME_HEIGHT else k
			shapes[gname + "_" + sname] = (vf * ks, {n: j * ks for n, j in joints.items()}, [e * ks for e in eyes])
			print("shape", gname, sname, flush=True)
	ref, ref_j, _ = shapes["male_base"]

	near = simplify(tris.reshape(-1), importance(ref, W, ref_j), NEAR_TRIS)
	far = simplify(near, importance(ref, W, ref_j), FAR_TRIS)
	used = np.unique(near)
	remap = -np.ones(len(v0), dtype=np.int64)
	remap[used] = np.arange(len(used))
	near_i = remap[near]
	far_i = remap[far]
	n = len(used)
	print("verts", n, "near tris", len(near_i) // 3, "far tris", len(far_i) // 3)

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

	blocks = []
	layout = {}

	def put(name, arr, kind):
		arr = np.ascontiguousarray(arr, dtype=np.float32 if kind == "f" else np.int32)
		layout[name] = {"offset": sum(b.nbytes for b in blocks), "count": int(arr.size), "kind": kind}
		blocks.append(arr)

	meta = {"verts": n, "shapes": [], "joints": {}, "eyes": {}, "bones": pose.NAMES,
		"source": "MakeHuman 1.x base mesh, macro targets and default rig (CC0)"}
	for key, (vf, joints, eyes) in shapes.items():
		meta["shapes"].append(key)
		put("pos_" + key, vf[used], "f")
		meta["joints"][key] = {k: [round(float(x), 5) for x in j] for k, j in joints.items()}
		meta["eyes"][key] = [[round(float(x), 5) for x in e] for e in eyes]
	put("near", near_i, "i")
	put("far", far_i, "i")
	put("bones", bones, "i")
	put("weights", bw, "f")
	put("part", part, "i")
	put("along", along, "f")
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
