"""Pose a MakeHuman body into our rest pose and fit it to our 17 bones.

Steps: MakeHuman units to metres in our axes (forward -Z, the body's left at
-X), arms turned down from MakeHuman's A-pose and straightened, palms to the
thighs, fingers relaxed, legs straight (linear blend skinning with the
MakeHuman weights). The body keeps its own proportions: `mh_points` gives
where our joints sit on it.
"""
import numpy as np

# Our bone hierarchy (CharacterKit.BONES). The heights here are only the old
# kit's; the body's own joints come from mh_points.
BONES = [
	["Hips", "", (0, 0.92, 0)],
	["Spine", "Hips", (0, 1.02, 0)],
	["Chest", "Spine", (0, 1.18, 0)],
	["Neck", "Chest", (0, 1.45, 0)],
	["Head", "Neck", (0, 1.53, 0)],
	["LeftUpperArm", "Chest", (-0.25, 1.41, 0)],
	["LeftLowerArm", "LeftUpperArm", (-0.28, 1.13, 0)],
	["LeftHand", "LeftLowerArm", (-0.29, 0.88, 0)],
	["RightUpperArm", "Chest", (0.25, 1.41, 0)],
	["RightLowerArm", "RightUpperArm", (0.28, 1.13, 0)],
	["RightHand", "RightLowerArm", (0.29, 0.88, 0)],
	["LeftUpperLeg", "Hips", (-0.11, 0.9, 0)],
	["LeftLowerLeg", "LeftUpperLeg", (-0.11, 0.5, 0)],
	["LeftFoot", "LeftLowerLeg", (-0.11, 0.1, 0)],
	["RightUpperLeg", "Hips", (0.11, 0.9, 0)],
	["RightLowerLeg", "RightUpperLeg", (0.11, 0.5, 0)],
	["RightFoot", "RightLowerLeg", (0.11, 0.1, 0)],
]
NAMES = [b[0] for b in BONES]
TAIL = {"Hips": "Spine", "Spine": "Chest", "Chest": "Neck", "Neck": "Head"}
for _s in ["Left", "Right"]:
	TAIL[_s + "UpperArm"] = _s + "LowerArm"
	TAIL[_s + "LowerArm"] = _s + "Hand"
	TAIL[_s + "UpperLeg"] = _s + "LowerLeg"
	TAIL[_s + "LowerLeg"] = _s + "Foot"


def our_bone(mh_bone):
	"""Which of our bones a MakeHuman bone's weights go to."""
	b = mh_bone
	side = ""
	if b.endswith(".L"):
		side = "Left"
	elif b.endswith(".R"):
		side = "Right"
	core = b[:-2] if side else b
	if core in ("root", "spine05", "pelvis"):
		return "Hips"
	if core in ("spine04", "spine03"):
		return "Spine"
	if core in ("spine02", "spine01", "clavicle", "breast"):
		return "Chest"
	if core.startswith("neck"):
		return "Neck"
	if core in ("shoulder01", "upperarm01", "upperarm02"):
		return side + "UpperArm"
	if core.startswith("lowerarm"):
		return side + "LowerArm"
	if core in ("wrist",) or core.startswith("metacarpal") or core.startswith("finger"):
		return side + "Hand"
	if core.startswith("upperleg"):
		return side + "UpperLeg"
	if core.startswith("lowerleg"):
		return side + "LowerLeg"
	if core == "foot" or core.startswith("toe"):
		return side + "Foot"
	return "Head"  # head, jaw, eyes, tongue and the face bones


# Points on the posed MakeHuman body that stand for our joints.
def mh_points(J):
	def h(b):
		return J[b + "____head"]
	pts = {
		"Hips": (h("upperleg01.L") + h("upperleg01.R")) * 0.5,
		"Spine": h("spine04"),
		"Chest": h("spine02"),
		"Neck": h("neck01"),
		"Head": h("head"),
	}
	for s, m in [("Left", ".L"), ("Right", ".R")]:
		pts[s + "UpperArm"] = h("upperarm01" + m)
		pts[s + "LowerArm"] = h("lowerarm01" + m)
		pts[s + "Hand"] = h("wrist" + m)
		pts[s + "UpperLeg"] = h("upperleg01" + m)
		pts[s + "LowerLeg"] = h("lowerleg01" + m)
		pts[s + "Foot"] = h("foot" + m)
	return pts


def to_ours(p):
	"""MakeHuman decimetres (+Z forward, left at +X) to our metres."""
	p = np.asarray(p, dtype=np.float64) * 0.1
	return p * np.array([-1.0, 1.0, -1.0])


def rot_between(a, b):
	a = a / np.linalg.norm(a)
	b = b / np.linalg.norm(b)
	v = np.cross(a, b)
	c = float(np.dot(a, b))
	if c < -0.999999:
		axis = np.cross(a, [1, 0, 0])
		if np.linalg.norm(axis) < 1e-6:
			axis = np.cross(a, [0, 1, 0])
		return axis_angle(axis, np.pi)
	vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
	return np.eye(3) + vx + vx @ vx / (1.0 + c)


def axis_angle(axis, ang):
	axis = np.asarray(axis, dtype=np.float64)
	axis = axis / np.linalg.norm(axis)
	x, y, z = axis
	c, s = np.cos(ang), np.sin(ang)
	C = 1 - c
	return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
		[y * x * C + z * s, c + y * y * C, y * z * C - x * s],
		[z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


class Posed:
	"""World-space rigid transforms per MakeHuman bone (rotation about a point)."""

	def __init__(self, skel, J):
		self.skel = skel
		self.J = J
		self.M = {b: (np.eye(3), np.zeros(3)) for b in skel["bones"]}

	def apply(self, p, bone):
		R, t = self.M[bone]
		return R @ p + t

	def head(self, bone):
		return self.apply(self.J[bone + "____head"], bone)

	def tail(self, bone):
		return self.apply(self.J[bone + "____tail"], bone)

	def rotate(self, bone, R):
		"""Turn `bone` and everything below it by world rotation R about its posed head."""
		pivot = self.head(bone)
		for b in self.subtree(bone):
			Rb, tb = self.M[b]
			self.M[b] = (R @ Rb, R @ (tb - pivot) + pivot)

	def subtree(self, bone):
		out = [bone]
		i = 0
		while i < len(out):
			for b, d in self.skel["bones"].items():
				if d["parent"] == out[i]:
					out.append(b)
			i += 1
		return out


def pose_rest(skel, J, curl=0.35):
	"""Arms down and straight with palms in, fingers curled a little, legs straight.

	J in our axes (metres). Returns the Posed transforms.
	"""
	P = Posed(skel, J)
	for m, sgn in [(".L", -1.0), (".R", 1.0)]:
		# Upper arm: elbow straight under the shoulder, a touch out (our rig: 0.03 m over 0.28).
		sh = P.head("upperarm01" + m)
		el = P.head("lowerarm01" + m)
		want = np.array([sgn * 0.03, -0.28, 0.0])
		P.rotate("upperarm01" + m, rot_between(el - sh, want))
		el = P.head("lowerarm01" + m)
		wr = P.head("wrist" + m)
		want = np.array([sgn * 0.01, -0.25, 0.0])
		P.rotate("lowerarm01" + m, rot_between(wr - el, want))
		# Hand: in line with the forearm.
		wr = P.head("wrist" + m)
		mid = P.head("finger3-1" + m)
		P.rotate("wrist" + m, rot_between(mid - wr, want))
		# Twist the forearm so the palm faces the thigh.
		wr = P.head("wrist" + m)
		a = P.head("finger2-1" + m)
		b = P.head("finger5-1" + m)
		across = b - a  # index to little finger knuckles
		axis = want / np.linalg.norm(want)
		across -= axis * np.dot(across, axis)
		# Palm in: knuckles line runs front to back, index finger forward (-Z).
		target = np.array([0.0, 0.0, 1.0])
		target -= axis * np.dot(target, axis)
		ang = np.arctan2(np.dot(np.cross(across, target), axis), np.dot(across, target))
		P.rotate("lowerarm02" + m, axis_angle(axis, ang))
		# Relaxed fingers: bend each knuckle toward the palm.
		wr = P.head("wrist" + m)
		mid = P.head("finger3-1" + m)
		a = P.head("finger2-1" + m)
		b = P.head("finger5-1" + m)
		down = mid - wr
		bend_axis = np.cross(b - a, down)
		bend_axis /= np.linalg.norm(bend_axis)
		# Curl toward the palm (the side facing the body, x toward 0).
		test = axis_angle(bend_axis, 0.3) @ down
		palm_dir = np.array([-sgn, 0.0, 0.0])
		if np.dot(test - down, palm_dir) < 0:
			bend_axis = -bend_axis
		for f in ["2", "3", "4", "5"]:
			for k, c in [("1", curl), ("2", curl * 1.3), ("3", curl)]:
				P.rotate("finger%s-%s%s" % (f, k, m), axis_angle(bend_axis, c))
		# Thumb toward the index finger.
		P.rotate("finger1-2" + m, axis_angle(bend_axis, curl * 0.6))
	for m, sgn in [(".L", -1.0), (".R", 1.0)]:
		hip = P.head("upperleg01" + m)
		kn = P.head("lowerleg01" + m)
		P.rotate("upperleg01" + m, rot_between(kn - hip, np.array([0.0, -0.4, 0.0])))
		kn = P.head("lowerleg01" + m)
		an = P.head("foot" + m)
		P.rotate("lowerleg01" + m, rot_between(an - kn, np.array([0.0, -0.4, 0.0])))
		# Toes forward.
		an = P.head("foot" + m)
		toe = P.head("toe3-1" + m)
		d = toe - an
		d[1] = 0.0
		P.rotate("foot" + m, rot_between(d, np.array([sgn * 0.0, 0.0, -1.0])))
	return P


def skin_lbs(P, verts, weights):
	"""Linear blend skinning of `verts` (our axes) by the MakeHuman weights."""
	out = np.zeros_like(verts)
	total = np.zeros(len(verts))
	for b, (idx, w) in weights.items():
		R, t = P.M[b]
		out[idx] += (verts[idx] @ R.T + t) * w[:, None]
		total[idx] += w
	missing = total < 1e-6
	out[missing] = verts[missing]
	out[~missing] /= total[~missing, None]
	return out


def our_weights(n, weights):
	"""(n, 17) weights on our bones, summed over the MakeHuman bones mapped to them."""
	W = np.zeros((n, len(NAMES)))
	for b, (idx, w) in weights.items():
		W[idx, NAMES.index(our_bone(b))] += w
	s = W.sum(axis=1)
	W[s > 0] /= s[s > 0, None]
	return W
