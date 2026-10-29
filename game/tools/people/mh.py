"""MakeHuman (CC0) source data: base mesh, macro targets, rig joints, weights.

MH_DATA points at makehuman/data from github.com/makehumancommunity/makehuman
(see HANDOFF-people-v2.md for the sparse checkout). Units: MakeHuman
decimetres, +Y up, the body faces +Z.
"""
import json
import os

import numpy as np

MH_DATA = os.environ.get("MH_DATA", "/tmp/mh/mh/makehuman/data")


def load_base():
	"""Vertices (all 19158) and the body group's faces as quads (-1 padded)."""
	verts = []
	faces = []
	group = None
	with open(os.path.join(MH_DATA, "3dobjs/base.obj")) as f:
		for line in f:
			if line.startswith("v "):
				verts.append([float(x) for x in line.split()[1:4]])
			elif line.startswith("g "):
				group = line.split()[1]
			elif line.startswith("f ") and group == "body":
				idx = [int(t.split("/")[0]) - 1 for t in line.split()[1:]]
				if len(idx) == 3:
					idx.append(-1)
				faces.append(idx)
	return np.array(verts, dtype=np.float64), np.array(faces, dtype=np.int64)


_target_cache = {}


def load_target(rel):
	if rel in _target_cache:
		return _target_cache[rel]
	idx = []
	off = []
	with open(os.path.join(MH_DATA, "targets", rel)) as f:
		for line in f:
			if not line.strip() or line.startswith("#"):
				continue
			p = line.split()
			idx.append(int(p[0]))
			off.append([float(p[1]), float(p[2]), float(p[3])])
	t = (np.array(idx, dtype=np.int64), np.array(off, dtype=np.float64).reshape(-1, 3))
	_target_cache[rel] = t
	return t


def _tri(v, names):
	"""MakeHuman's three-point macro weights: v in 0..1 over min, average, max."""
	if v < 0.5:
		return {names[0]: 1.0 - 2.0 * v, names[1]: 2.0 * v}
	return {names[1]: 2.0 - 2.0 * v, names[2]: 2.0 * v - 1.0}


def _age(a):
	# MakeHuman: baby 0, child 0.1875, young 0.5, old 1.
	if a < 0.1875:
		return {"baby": 1.0 - a / 0.1875, "child": a / 0.1875}
	if a < 0.5:
		t = (a - 0.1875) / (0.5 - 0.1875)
		return {"child": 1.0 - t, "young": t}
	t = (a - 0.5) / 0.5
	return {"young": 1.0 - t, "old": t}


def macro_offsets(n_verts, gender=0.5, age=0.5, muscle=0.5, weight=0.5, height=0.5,
		proportions=0.5, ethnic=(1 / 3, 1 / 3, 1 / 3)):
	"""Sum of the macro targets MakeHuman applies for these slider values."""
	out = np.zeros((n_verts, 3))
	genders = {"female": 1.0 - gender, "male": gender}
	ages = _age(age)
	muscles = _tri(muscle, ["minmuscle", "averagemuscle", "maxmuscle"])
	weights = _tri(weight, ["minweight", "averageweight", "maxweight"])
	heights = {"minheight": max(0.0, 1.0 - 2.0 * height), "maxheight": max(0.0, 2.0 * height - 1.0)}
	props = {"uncommonproportions": max(0.0, 1.0 - 2.0 * proportions),
		"idealproportions": max(0.0, 2.0 * proportions - 1.0)}

	def add(rel, w):
		if w <= 1e-6:
			return
		i, o = load_target(rel)
		out[i] += o * w

	for eth, ew in zip(["african", "asian", "caucasian"], ethnic):
		for g, gw in genders.items():
			for a, aw in ages.items():
				add("macrodetails/%s-%s-%s.target" % (eth, g, a), ew * gw * aw)
	for g, gw in genders.items():
		for a, aw in ages.items():
			for m, mw in muscles.items():
				for wt, ww in weights.items():
					base = gw * aw * mw * ww
					add("macrodetails/universal-%s-%s-%s-%s.target" % (g, a, m, wt), base)
					for h, hw in heights.items():
						add("macrodetails/height/%s-%s-%s-%s-%s.target" % (g, a, m, wt, h), base * hw)
					if a != "baby":
						for p, pw in props.items():
							add("macrodetails/proportions/%s-%s-%s-%s-%s.target" % (g, a, m, wt, p), base * pw)
	return out


def load_skeleton():
	with open(os.path.join(MH_DATA, "rigs/default.mhskel")) as f:
		return json.load(f)


def joint_positions(skel, verts):
	return {k: verts[v].mean(axis=0) for k, v in skel["joints"].items()}


def load_weights():
	"""{bone: (vertex indices, weights)} of the default rig."""
	with open(os.path.join(MH_DATA, "rigs/default_weights.mhw")) as f:
		w = json.load(f)["weights"]
	return {b: (np.array([p[0] for p in l], dtype=np.int64), np.array([p[1] for p in l]))
		for b, l in w.items()}
