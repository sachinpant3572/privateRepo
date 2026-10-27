extends RefCounted
## Cartoon people on a humanoid skeleton, built at the feet (y = 0), facing -Z.
## Proportions are a little chunky (big head, broad shoulders) so people read
## from above. Every body part is bound rigidly to one bone, so a whole person
## is one skinned mesh (one draw call) that animates by turning bones
## (see rig.gd). Bone names follow Godot's SkeletonProfileHumanoid, so a
## modelled character with a standard rig can replace the code-built one
## later without touching the animation code.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SKIN := [Color(0.98, 0.82, 0.68), Color(0.85, 0.64, 0.45), Color(0.6, 0.42, 0.28), Color(0.38, 0.25, 0.17)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.1), Color(0.6, 0.4, 0.2), Color(0.85, 0.7, 0.4), Color(0.55, 0.55, 0.55), Color(0.7, 0.2, 0.15)]
const STYLES := ["short", "short", "long", "bun", "afro", "bald", "cap", "ponytail", "buzz"]
const SHIRTS := [Color(0.95, 0.85, 0.3), Color(0.3, 0.6, 0.85), Color(0.9, 0.5, 0.2), Color(0.55, 0.8, 0.45), Color(0.95, 0.95, 0.95), Color(0.6, 0.35, 0.65), Color(0.85, 0.3, 0.35), Color(0.25, 0.65, 0.6)]
const PANTS := [Color(0.15, 0.15, 0.2), Color(0.35, 0.3, 0.25), Color(0.2, 0.3, 0.5), Color(0.8, 0.75, 0.65), Color(0.3, 0.32, 0.3)]
const JACKETS := [Color(0.2, 0.22, 0.25), Color(0.45, 0.3, 0.2), Color(0.25, 0.35, 0.3), Color(0.55, 0.15, 0.2), Color(0.3, 0.3, 0.5)]
const SHOES := [Color(0.12, 0.1, 0.1), Color(0.95, 0.95, 0.95), Color(0.45, 0.3, 0.2), Color(0.8, 0.2, 0.2)]
## Outfits for random civilians, weighted by repetition.
const OUTFITS := ["tee", "tee", "tee", "jacket", "hoodie", "dress", "tank", "suit"]

## name, parent, joint position at rest (model space). Rest bases are all
## identity, so a bone's rotation reads the same as the model's axes:
## +X turns a hanging limb forward, Z swings it sideways.
const BONES := [
	["Hips", "", Vector3(0, 0.92, 0)],
	["Spine", "Hips", Vector3(0, 1.02, 0)],
	["Chest", "Spine", Vector3(0, 1.18, 0)],
	["Neck", "Chest", Vector3(0, 1.45, 0)],
	["Head", "Neck", Vector3(0, 1.53, 0)],
	["LeftUpperArm", "Chest", Vector3(-0.25, 1.41, 0)],
	["LeftLowerArm", "LeftUpperArm", Vector3(-0.28, 1.13, 0)],
	["LeftHand", "LeftLowerArm", Vector3(-0.29, 0.88, 0)],
	["RightUpperArm", "Chest", Vector3(0.25, 1.41, 0)],
	["RightLowerArm", "RightUpperArm", Vector3(0.28, 1.13, 0)],
	["RightHand", "RightLowerArm", Vector3(0.29, 0.88, 0)],
	["LeftUpperLeg", "Hips", Vector3(-0.11, 0.9, 0)],
	["LeftLowerLeg", "LeftUpperLeg", Vector3(-0.11, 0.5, 0)],
	["LeftFoot", "LeftLowerLeg", Vector3(-0.11, 0.1, 0)],
	["RightUpperLeg", "Hips", Vector3(0.11, 0.9, 0)],
	["RightLowerLeg", "RightUpperLeg", Vector3(0.11, 0.5, 0)],
	["RightFoot", "RightLowerLeg", Vector3(0.11, 0.1, 0)],
]


static func bone_index(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1


## A random civilian look.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"outfit": OUTFITS[rng.randi() % OUTFITS.size()],
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()],
		"jacket": JACKETS[rng.randi() % JACKETS.size()],
		"pants": PANTS[rng.randi() % PANTS.size()],
		"shoes": SHOES[rng.randi() % SHOES.size()],
		"skin": SKIN[rng.randi() % SKIN.size()],
		"hair": STYLES[rng.randi() % STYLES.size()],
		"hair_color": HAIR[rng.randi() % HAIR.size()],
		"hat": Color(0.2, 0.25, 0.5).lerp(SHIRTS[rng.randi() % SHIRTS.size()], 0.5),
		"build": rng.randf_range(0.9, 1.15),
		"height": rng.randf_range(0.93, 1.05),
		"glasses": rng.randf() < 0.15,
		"beard": rng.randf() < 0.15,
	}


## A posable person: a Skeleton3D with the body as its one skinned child
## mesh ("Body"). Scale it by look.height.
static func build_rig(look: Dictionary) -> Skeleton3D:
	var skel := Skeleton3D.new()
	var skin := Skin.new()
	for i in BONES.size():
		var b: Array = BONES[i]
		skel.add_bone(b[0])
		var parent := bone_index(b[1])
		var offset: Vector3 = b[2]
		if parent >= 0:
			skel.set_bone_parent(i, parent)
			offset -= BONES[parent][2]
		skel.set_bone_rest(i, Transform3D(Basis(), offset))
		skin.add_bind(i, Transform3D(Basis(), -b[2]))
	skel.reset_bone_poses()
	var mb := MeshBuilder.new()
	build(mb, look)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = mb.commit()
	body.skin = skin
	skel.add_child(body)
	body.skeleton = NodePath("..")
	var h: float = look.get("height", 1.0)
	skel.scale = Vector3(h, h, h)
	return skel


## look keys: outfit (tee, jacket, hoodie, dress, tank, suit, uniform, vest),
## shirt, jacket, pants, shoes, skin, hair (style name), hair_color, hat
## (colour, used by "cap" and uniforms), build (shoulder width), glasses,
## beard. Missing keys fall back to plain defaults.
static func build(mb, look: Dictionary) -> void:
	var outfit: String = look.get("outfit", "tee")
	var shirt: Color = look.get("shirt", Color.GRAY)
	var jacket: Color = look.get("jacket", shirt.darkened(0.3))
	var pants: Color = look.get("pants", Color(0.2, 0.22, 0.3))
	var shoes: Color = look.get("shoes", Color(0.12, 0.1, 0.1))
	var skin: Color = look.get("skin", SKIN[0])
	var w: float = look.get("build", 1.0)
	var top := jacket if outfit in ["jacket", "hoodie", "suit", "vest"] else shirt
	var sleeve := top if outfit != "vest" else shirt
	var long_sleeves: bool = outfit in ["jacket", "hoodie", "suit", "uniform"]
	if outfit == "tank":
		sleeve = skin

	# Hips: pelvis, belt, and the skirt of a dress.
	mb.set_bone(bone_index("Hips"))
	if outfit == "dress":
		mb.limb(Vector3(0, 1.02, 0), Vector3(0, 0.56, 0), 0.17 * w, 0.27 * w, shirt, 8)
	else:
		mb.ball(Vector3(0, 0.95, 0), Vector3(0.19 * w, 0.13, 0.13), pants, 8, 3)
		mb.box(Vector3(0, 1.0, -0.128), Vector3(0.06, 0.05, 0.02), Color(0.85, 0.75, 0.4))

	# Torso.
	mb.set_bone(bone_index("Spine"))
	mb.ball(Vector3(0, 1.12, 0), Vector3(0.19 * w, 0.14, 0.13), shirt if outfit != "suit" else jacket, 8, 3)
	mb.set_bone(bone_index("Chest"))
	mb.ball(Vector3(0, 1.3, 0), Vector3(0.25 * w, 0.2, 0.15), top, 8, 4)
	for side in [-1.0, 1.0]:
		mb.ball(Vector3(side * 0.24 * w, 1.39, 0), Vector3(0.09, 0.08, 0.09), sleeve, 6, 3)
	match outfit:
		"jacket", "suit":
			# Open front showing the shirt, plus lapels.
			mb.box(Vector3(0, 1.3, -0.148), Vector3(0.1, 0.32, 0.02), shirt if outfit == "jacket" else Color(0.95, 0.95, 0.95))
			if outfit == "suit":
				mb.box(Vector3(0, 1.28, -0.155), Vector3(0.04, 0.24, 0.02), look.get("tie", Color(0.7, 0.12, 0.15)))
		"hoodie":
			mb.ball(Vector3(0, 1.45, 0.11), Vector3(0.15, 0.1, 0.09), jacket.darkened(0.1), 6, 3)
			mb.box(Vector3(0, 1.2, -0.15), Vector3(0.22, 0.1, 0.02), jacket.darkened(0.15))
		"vest":
			mb.ball(Vector3(0, 1.3, 0), Vector3(0.255 * w, 0.17, 0.155), jacket, 8, 3)
			mb.box(Vector3(0.1, 1.36, -0.16), Vector3(0.08, 0.05, 0.02), Color(0.95, 0.85, 0.3))
		"uniform":
			mb.box(Vector3(-0.1, 1.36, -0.152), Vector3(0.06, 0.07, 0.02), Color(0.95, 0.8, 0.25))
			mb.box(Vector3(0, 1.22, -0.15), Vector3(0.02, 0.3, 0.02), shirt.darkened(0.3))

	# Neck and head.
	mb.set_bone(bone_index("Neck"))
	mb.limb(Vector3(0, 1.42, 0), Vector3(0, 1.58, 0), 0.07, 0.065, skin)
	mb.set_bone(bone_index("Head"))
	_head(mb, look, skin)

	# Arms.
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		mb.set_bone(bone_index(prefix + "UpperArm"))
		mb.limb(Vector3(side * 0.25 * w, 1.41, 0), Vector3(side * 0.28, 1.13, 0), 0.075, 0.065, sleeve)
		mb.set_bone(bone_index(prefix + "LowerArm"))
		mb.ball(Vector3(side * 0.28, 1.13, 0), Vector3(0.062, 0.062, 0.062), sleeve if long_sleeves else skin, 5, 3)
		mb.limb(Vector3(side * 0.28, 1.13, 0), Vector3(side * 0.29, 0.9, 0), 0.06, 0.05, sleeve if long_sleeves else skin)
		if long_sleeves:
			mb.limb(Vector3(side * 0.29, 0.93, 0), Vector3(side * 0.29, 0.9, 0), 0.063, 0.063, sleeve.darkened(0.2))
		mb.set_bone(bone_index(prefix + "Hand"))
		mb.ball(Vector3(side * 0.29, 0.84, -0.01), Vector3(0.06, 0.07, 0.06), skin, 6, 3)

	# Legs.
	var leg := skin if outfit == "dress" else pants
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		mb.set_bone(bone_index(prefix + "UpperLeg"))
		mb.limb(Vector3(side * 0.11, 0.92, 0), Vector3(side * 0.11, 0.5, 0), 0.1, 0.08, leg)
		mb.set_bone(bone_index(prefix + "LowerLeg"))
		mb.ball(Vector3(side * 0.11, 0.5, 0), Vector3(0.078, 0.07, 0.078), leg, 5, 3)
		mb.limb(Vector3(side * 0.11, 0.5, 0), Vector3(side * 0.11, 0.1, 0), 0.075, 0.06, leg)
		mb.set_bone(bone_index(prefix + "Foot"))
		mb.box(Vector3(side * 0.11, 0.06, -0.05), Vector3(0.13, 0.12, 0.28), shoes)
		mb.box(Vector3(side * 0.11, 0.015, -0.05), Vector3(0.135, 0.03, 0.29), shoes.darkened(0.4) if shoes.v > 0.5 else Color(0.85, 0.85, 0.82))


static func _head(mb, look: Dictionary, skin: Color) -> void:
	var style: String = look.get("hair", "short")
	var hair: Color = look.get("hair_color", HAIR[0])
	var hat: Color = look.get("hat", Color(0.1, 0.14, 0.3))
	var c := Vector3(0, 1.69, 0)
	mb.ball(c, Vector3(0.17, 0.19, 0.17), skin, 8, 5)
	for side in [-1.0, 1.0]:
		mb.ball(c + Vector3(side * 0.165, -0.01, 0.01), Vector3(0.03, 0.05, 0.03), skin.darkened(0.08), 4, 2)
		mb.box(c + Vector3(side * 0.065, 0.015, -0.16), Vector3(0.035, 0.045, 0.02), Color(0.08, 0.07, 0.07))
	mb.box(c + Vector3(0, -0.035, -0.175), Vector3(0.045, 0.06, 0.04), skin.darkened(0.15))
	mb.box(c + Vector3(0, -0.1, -0.155), Vector3(0.08, 0.018, 0.02), skin.darkened(0.4))
	if look.get("glasses", false):
		mb.box(c + Vector3(0, 0.02, -0.172), Vector3(0.24, 0.06, 0.02), Color(0.06, 0.06, 0.08))
	if look.get("beard", false):
		mb.ball(c + Vector3(0, -0.11, -0.04), Vector3(0.14, 0.09, 0.13), hair, 6, 3)
	match style:
		"short":
			mb.ball(c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 8, 3)
		"buzz":
			mb.ball(c + Vector3(0, 0.05, 0.015), Vector3(0.175, 0.15, 0.175), hair.lerp(skin, 0.35), 8, 3)
		"long":
			mb.ball(c + Vector3(0, 0.07, 0.02), Vector3(0.185, 0.145, 0.185), hair, 8, 3)
			mb.box(c + Vector3(0, -0.13, 0.1), Vector3(0.34, 0.36, 0.1), hair)
		"ponytail":
			mb.ball(c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 8, 3)
			mb.limb(c + Vector3(0, 0.06, 0.17), c + Vector3(0, -0.22, 0.22), 0.05, 0.035, hair, 5)
		"bun":
			mb.ball(c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 8, 3)
			mb.ball(c + Vector3(0, 0.2, 0.09), Vector3(0.08, 0.08, 0.08), hair, 6, 3)
		"afro":
			mb.ball(c + Vector3(0, 0.1, 0.03), Vector3(0.25, 0.21, 0.24), hair, 8, 4)
		"cap":
			mb.ball(c + Vector3(0, 0.08, 0.02), Vector3(0.18, 0.13, 0.18), hat, 8, 3)
			mb.box(c + Vector3(0, 0.08, -0.2), Vector3(0.22, 0.03, 0.14), hat.darkened(0.2))
		"police":
			mb.limb(c + Vector3(0, 0.08, 0), c + Vector3(0, 0.2, 0), 0.19, 0.21, hat, 8)
			mb.box(c + Vector3(0, 0.09, -0.21), Vector3(0.26, 0.03, 0.12), hat.darkened(0.3))
			mb.box(c + Vector3(0, 0.15, -0.2), Vector3(0.06, 0.06, 0.02), Color(0.95, 0.8, 0.25))
		"beanie":
			mb.ball(c + Vector3(0, 0.08, 0.01), Vector3(0.185, 0.16, 0.185), hat, 8, 3)
		_:
			pass
