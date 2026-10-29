extends RefCounted
## Cartoon people on a humanoid skeleton, built at the feet (y = 0), facing -Z.
## Proportions are a little chunky (big head, broad shoulders) so people read
## from above. Every body part is bound rigidly to one bone, so a whole person
## is one skinned mesh (one draw call) that animates by turning bones
## (see rig.gd). Bone names follow Godot's SkeletonProfileHumanoid, so a
## modelled character with a standard rig can replace the code-built one
## later without touching the animation code.
##
## Clothes are present-day and built for the high camera: the head, shoulders
## and back show most, so hats, hair, hoods, bags, collars and back prints
## carry the variety, with hems, cuffs and soles as clear colour breaks.

const MeshBuilder = preload("res://scripts/mesh_builder.gd")

const SKIN := [Color(0.98, 0.82, 0.68), Color(0.92, 0.72, 0.56), Color(0.85, 0.64, 0.45), Color(0.6, 0.42, 0.28),
	Color(0.48, 0.32, 0.21), Color(0.38, 0.25, 0.17)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.1), Color(0.6, 0.4, 0.2),
	Color(0.85, 0.7, 0.4), Color(0.55, 0.55, 0.55), Color(0.7, 0.2, 0.15), Color(0.93, 0.88, 0.76)]
## Hair styles for random civilians, by how often each look is picked:
## [style, weight for one half of the crowd, weight for the other].
const STYLES := [["short", 20, 4], ["fade", 18, 2], ["buzz", 10, 1], ["bald", 6, 0], ["curly", 8, 8],
	["afro", 5, 6], ["locs", 6, 6], ["long", 2, 20], ["ponytail", 1, 16], ["bun", 2, 14], ["bob", 0, 10]]

## Modern palette: muted neutrals (most of the street), a few brights.
const NEUTRALS := [Color(0.09, 0.09, 0.1), Color(0.09, 0.09, 0.1), Color(0.22, 0.23, 0.25), Color(0.58, 0.58, 0.6),
	Color(0.92, 0.91, 0.88), Color(0.92, 0.91, 0.88), Color(0.86, 0.82, 0.72), Color(0.76, 0.68, 0.55),
	Color(0.64, 0.48, 0.32), Color(0.36, 0.25, 0.18), Color(0.36, 0.38, 0.24), Color(0.55, 0.6, 0.48),
	Color(0.13, 0.17, 0.28), Color(0.38, 0.46, 0.56), Color(0.42, 0.13, 0.17), Color(0.17, 0.29, 0.22)]
const ACCENTS := [Color(0.93, 0.47, 0.16), Color(0.86, 0.66, 0.2), Color(0.18, 0.36, 0.82), Color(0.8, 0.17, 0.16),
	Color(0.92, 0.6, 0.66), Color(0.68, 0.6, 0.84), Color(0.12, 0.55, 0.56), Color(0.72, 0.86, 0.3), Color(0.55, 0.75, 0.92)]
const DENIM := [Color(0.16, 0.22, 0.36), Color(0.16, 0.22, 0.36), Color(0.3, 0.4, 0.55), Color(0.52, 0.6, 0.7),
	Color(0.12, 0.12, 0.14), Color(0.4, 0.41, 0.44)]
## Trousers, joggers, cargos and shorts.
const PANTS := [Color(0.09, 0.09, 0.1), Color(0.22, 0.23, 0.25), Color(0.13, 0.17, 0.28), Color(0.66, 0.6, 0.46),
	Color(0.36, 0.38, 0.24), Color(0.76, 0.68, 0.55), Color(0.5, 0.5, 0.52), Color(0.36, 0.25, 0.18)]
## Outer layers: bombers, blazers, suits, zip jackets.
const JACKETS := [Color(0.09, 0.09, 0.1), Color(0.36, 0.38, 0.24), Color(0.13, 0.17, 0.28), Color(0.76, 0.68, 0.55),
	Color(0.22, 0.23, 0.25), Color(0.42, 0.13, 0.17), Color(0.64, 0.48, 0.32)]
## Sneaker uppers: white most of all.
const SHOES := [Color(0.94, 0.94, 0.92), Color(0.94, 0.94, 0.92), Color(0.94, 0.94, 0.92), Color(0.09, 0.09, 0.1),
	Color(0.58, 0.58, 0.6), Color(0.86, 0.82, 0.72)]
const BOOTS := [Color(0.6, 0.42, 0.24), Color(0.36, 0.25, 0.18), Color(0.09, 0.09, 0.1)]
const SCRUBS := [Color(0.2, 0.5, 0.55), Color(0.16, 0.22, 0.4), Color(0.45, 0.62, 0.8), Color(0.45, 0.16, 0.24),
	Color(0.36, 0.5, 0.36)]
const HIVIS := [Color(0.84, 0.95, 0.16), Color(0.84, 0.95, 0.16), Color(1.0, 0.5, 0.12)]
## Food-delivery brands (fictional): jacket, bag and helmet colour.
const DELIVERY := [Color(0.1, 0.62, 0.36), Color(0.95, 0.45, 0.1), Color(0.1, 0.58, 0.62), Color(0.95, 0.78, 0.15),
	Color(0.88, 0.22, 0.36)]
const REFLECTIVE := Color(0.8, 0.82, 0.82)

## Outfits for random civilians: [outfit, weight for one half of the crowd,
## weight for the other]. Halves only bias hair, dresses and skirts.
const OUTFITS := [["tee", 22, 18], ["hoodie", 13, 10], ["polo", 7, 3], ["jersey", 5, 2], ["bomber", 6, 5],
	["denim", 4, 5], ["puffer", 4, 5], ["puffer_vest", 4, 3], ["blazer", 5, 6], ["suit", 4, 1], ["jacket", 3, 3],
	["tank", 6, 7], ["dress", 0, 14], ["scrubs", 3, 4], ["hivis", 4, 1], ["delivery", 4, 2]]
const BOTTOMS := [["jeans", 34, 26], ["joggers", 18, 12], ["cargo", 12, 6], ["trousers", 14, 10], ["shorts", 16, 12],
	["leggings", 0, 14], ["skirt", 0, 12]]
## Headwear for random civilians (most go bare-headed).
const HEADWEAR := [["", 72], ["cap", 12], ["cap_back", 6], ["beanie", 9], ["bucket", 6]]
const BAGS := [["", 50, 42], ["backpack", 22, 15], ["crossbody", 18, 18], ["tote", 4, 22]]

## Kinds of people on the street (pedestrian.gd picks one, senses.gd decides
## how each reacts); category_look() dresses each so it reads from above.
const CATEGORIES := ["general", "office", "worker", "tourist", "gang", "elderly", "athlete", "shopkeeper", "medic"]
const GREYS := [Color(0.5, 0.5, 0.5), Color(0.68, 0.68, 0.66), Color(0.82, 0.81, 0.78), Color(0.93, 0.92, 0.88)]
## Knitwear for cardigans.
const KNITS := [Color(0.86, 0.82, 0.72), Color(0.76, 0.68, 0.55), Color(0.64, 0.48, 0.32), Color(0.42, 0.13, 0.17),
	Color(0.36, 0.38, 0.24), Color(0.58, 0.58, 0.6), Color(0.38, 0.46, 0.56), Color(0.17, 0.29, 0.22)]
const APRONS := [Color(0.13, 0.17, 0.28), Color(0.36, 0.25, 0.18), Color(0.17, 0.29, 0.22), Color(0.42, 0.13, 0.17),
	Color(0.92, 0.91, 0.88), Color(0.09, 0.09, 0.1)]

## Tops worn over another layer: the jacket colour is the outside, the shirt
## shows at the neck or the open front.
const OUTERWEAR := ["jacket", "hoodie", "bomber", "denim", "puffer", "blazer", "suit", "delivery", "cardigan"]
## How much a top stands off the body (puffers are fat).
const BULK := {"puffer": 1.12, "puffer_vest": 1.1, "bomber": 1.05, "hoodie": 1.04, "delivery": 1.06, "denim": 1.03,
	"hivis": 1.05}
## Leg radii per cut: thigh, knee, calf, ankle.
const LEG_FIT := {"trousers": [0.1, 0.08, 0.075, 0.066], "jeans": [0.1, 0.08, 0.074, 0.063],
	"joggers": [0.104, 0.084, 0.074, 0.056], "cargo": [0.11, 0.09, 0.08, 0.07], "leggings": [0.09, 0.07, 0.064, 0.05],
	"scrubs": [0.106, 0.092, 0.082, 0.077], "bare": [0.09, 0.072, 0.066, 0.052]}
## Seven-segment digits for jersey numbers.
const DIGITS := ["abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc", "abc", "abcdefg", "abcdfg"]
## Torso shape used to hug straps, panels and prints to the body.
const TORSO_C := Vector3(0, 1.25, 0)
const TORSO_R := Vector3(0.22, 0.2, 0.14)

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


## A random civilian look; `outfit` forces the top (the rest still fits it).
static func random_look(rng: RandomNumberGenerator, outfit := "") -> Dictionary:
	var col := 1 if rng.randf() < 0.5 else 2
	var style := _weighted(rng, STYLES, col)
	if outfit == "":
		outfit = _weighted(rng, OUTFITS, col)
	var bottoms := _weighted(rng, BOTTOMS, col)
	var look := {
		"outfit": outfit,
		"shirt": _cloth(rng, 0.2),
		"jacket": _pick(rng, JACKETS),
		"accent": _pick(rng, ACCENTS) if rng.randf() < 0.6 else NEUTRALS[4],
		"bottoms": bottoms,
		"skin": _pick(rng, SKIN),
		"hair": style,
		"hair_color": _pick(rng, HAIR) if rng.randf() < 0.95 else _pick(rng, ACCENTS),
		"headwear": _weighted(rng, HEADWEAR, 1),
		"hat": _cloth(rng, 0.3),
		"shoe_style": "sneakers",
		"shoes": _pick(rng, SHOES) if rng.randf() < 0.8 else _pick(rng, ACCENTS),
		"build": rng.randf_range(1.0, 1.15) if col == 1 else rng.randf_range(0.9, 1.02),
		"height": rng.randf_range(0.95, 1.05) if col == 1 else rng.randf_range(0.93, 1.02),
		"beard": col == 1 and rng.randf() < 0.25,
	}
	look["pants"] = _pants_color(rng, bottoms)
	look["sole"] = NEUTRALS[0] if look.shoes == NEUTRALS[0] and rng.randf() < 0.6 else (Color(0.7, 0.5, 0.3) if rng.randf() < 0.1 else Color(0.95, 0.95, 0.93))
	look["shoe_accent"] = look.accent if rng.randf() < 0.5 else look.shoes.darkened(0.25)
	if rng.randf() < 0.4:
		look["print"] = _pick(rng, ACCENTS) if rng.randf() < 0.5 else _cloth(rng, 0.0)
		look["back_print"] = rng.randf() < 0.5
	if rng.randf() < 0.3:
		look["socks"] = NEUTRALS[4] if rng.randf() < 0.7 else NEUTRALS[0]
	if rng.randf() < 0.16:
		look["sunglasses"] = true
	elif rng.randf() < 0.13:
		look["glasses"] = true
	if rng.randf() < 0.09:
		look["headphones"] = _pick(rng, [NEUTRALS[0], NEUTRALS[4], NEUTRALS[7], look.accent])
	var bag := _weighted(rng, BAGS, col)
	if bag != "":
		look["bag"] = bag
		look["bag_color"] = _cloth(rng, 0.25)
	if rng.randf() < 0.16:
		look["phone"] = _pick(rng, [NEUTRALS[0], NEUTRALS[0], NEUTRALS[4], ACCENTS[4], ACCENTS[8]])
	if col == 2 and rng.randf() < 0.3:
		look["necklace"] = Color(0.9, 0.75, 0.35) if rng.randf() < 0.6 else Color(0.8, 0.8, 0.82)
	_fit_outfit(rng, look, col)
	return look


## A random look for a kind of person (CATEGORIES), dressed so the kind reads
## from the street camera: office workers in suits with lanyards and
## briefcases, workers in hi-vis and boots, tourists with cameras, sun hats and
## shopping, gang members in hoodies with bandanas and chains, the elderly in
## cardigans with grey hair, glasses and canes, athletes in running kit,
## shopkeepers in aprons, medics in scrubs. look.category says which; a
## general look that came out as scrubs, hi-vis or a suit takes that category.
static func category_look(rng: RandomNumberGenerator, cat := "general") -> Dictionary:
	var look: Dictionary
	match cat:
		"office":
			look = random_look(rng, _pick(rng, ["suit", "suit", "blazer", "blazer", "polo"]))
			if look.bottoms in ["joggers", "cargo", "shorts", "leggings"]:
				look.bottoms = "trousers"
				look.pants = _pick(rng, [NEUTRALS[0], NEUTRALS[2], NEUTRALS[12]])
			if rng.randf() < 0.55:
				look["lanyard"] = _pick(rng, [ACCENTS[2], ACCENTS[3], ACCENTS[6], NEUTRALS[0]])
			if rng.randf() < 0.5:
				look["bag"] = "briefcase"
				look["bag_color"] = _pick(rng, [NEUTRALS[0], NEUTRALS[9], NEUTRALS[8]])
			look.headwear = ""
			look.erase("headphones")
		"worker":
			look = random_look(rng, "hivis" if rng.randf() < 0.6 else _pick(rng, ["tee", "tee", "jacket", "hoodie"]))
			if look.outfit != "hivis":
				look.shoe_style = "boots"
				look.shoes = _pick(rng, BOOTS)
				look.bottoms = _pick(rng, ["cargo", "cargo", "jeans"])
				look.pants = _pants_color(rng, look.bottoms)
				if look.headwear == "" and rng.randf() < 0.4:
					look.headwear = "cap"
		"tourist":
			look = random_look(rng, _pick(rng, ["tee", "tee", "polo", "tank", "jacket"]))
			if look.outfit != "jacket" and look.bottoms != "skirt" and rng.randf() < 0.6:
				look.bottoms = "shorts"
				look.pants = _pants_color(rng, "shorts")
			if rng.randf() < 0.6:
				look["camera"] = _pick(rng, [NEUTRALS[0], NEUTRALS[0], NEUTRALS[3]])
			if look.headwear == "" and rng.randf() < 0.5:
				look.headwear = _pick(rng, ["bucket", "bucket", "cap"])
				look.hat = _cloth(rng, 0.4)
			if rng.randf() < 0.5:
				look["sunglasses"] = true
				look.erase("glasses")
			var r := rng.randf()
			if r < 0.3:
				look["bag"] = "shopping"
				look["bag_color"] = _pick(rng, ACCENTS)
				look.erase("phone")
			elif r < 0.7:
				look["bag"] = "backpack"
				look["bag_color"] = _cloth(rng, 0.4)
		"gang":
			look = random_look(rng, _pick(rng, ["hoodie", "hoodie", "bomber", "tank", "jersey", "tee"]))
			var crew: Color = _pick(rng, [ACCENTS[3], ACCENTS[2], ACCENTS[1], NEUTRALS[0]])
			look.bottoms = _pick(rng, ["joggers", "joggers", "jeans", "cargo"])
			look.pants = _pants_color(rng, look.bottoms)
			look.shoe_style = "sneakers"
			look.hat = crew if rng.randf() < 0.6 else NEUTRALS[0]
			look.headwear = "bandana" if rng.randf() < 0.45 else _pick(rng, ["cap_back", "beanie", "cap", ""])
			if rng.randf() < 0.55:
				look["chain"] = Color(0.92, 0.76, 0.3) if rng.randf() < 0.7 else Color(0.82, 0.82, 0.85)
				look.erase("necklace")
			if look.get("bag", "") not in ["", "crossbody"]:
				look.erase("bag")
			look.erase("glasses")
		"elderly":
			look = random_look(rng, _pick(rng, ["cardigan", "cardigan", "cardigan", "polo", "jacket", "blazer"]))
			look.hair_color = _pick(rng, GREYS)
			if look.hair in ["fade", "afro", "locs", "curly", "ponytail"]:
				look.hair = _pick(rng, ["short", "bald", "bob", "bun"])
			if look.bottoms != "skirt":
				look.bottoms = "trousers"
				look.pants = _pick(rng, [NEUTRALS[2], NEUTRALS[3], NEUTRALS[6], NEUTRALS[9], NEUTRALS[12]])
			look.shoe_style = "dress" if rng.randf() < 0.5 else "sneakers"
			look.shoes = _pick(rng, [NEUTRALS[0], NEUTRALS[9], NEUTRALS[4], NEUTRALS[6]])
			look.height = look.height * 0.96
			if look.headwear in ["cap_back", "beanie"]:
				look.headwear = ""
			if rng.randf() < 0.5:
				look["glasses"] = true
				look.erase("sunglasses")
			if rng.randf() < 0.35:
				look["cane"] = _pick(rng, [Color(0.36, 0.25, 0.18), NEUTRALS[0], Color(0.55, 0.4, 0.25)])
			if look.get("bag", "") == "backpack":
				look.bag = "tote"
			for k in ["headphones", "print", "phone", "socks"]:
				look.erase(k)
		"athlete":
			look = random_look(rng, _pick(rng, ["tank", "tank", "tee", "jersey"]))
			look.bottoms = _pick(rng, ["shorts", "shorts", "leggings", "joggers"])
			look.pants = _pants_color(rng, look.bottoms)
			look.shoe_style = "sneakers"
			look.shoes = _pick(rng, ACCENTS) if rng.randf() < 0.6 else NEUTRALS[4]
			look.sole = NEUTRALS[4]
			look.headwear = ""
			if rng.randf() < 0.5:
				look["headband"] = _pick(rng, [ACCENTS[0], ACCENTS[2], ACCENTS[3], ACCENTS[7], NEUTRALS[4]])
			elif rng.randf() < 0.4:
				look.headwear = "cap"
			if look.hair in ["long", "locs"] and rng.randf() < 0.7:
				look.hair = "ponytail"
			look["socks"] = NEUTRALS[4]
			for k in ["bag", "phone", "necklace", "glasses"]:
				look.erase(k)
			if rng.randf() < 0.35:
				look["headphones"] = _pick(rng, [NEUTRALS[0], NEUTRALS[4], look.shoes])
		"shopkeeper":
			look = random_look(rng, _pick(rng, ["polo", "tee", "tee", "polo"]))
			look["apron"] = _pick(rng, APRONS)
			look.headwear = ""
			for k in ["bag", "print", "phone", "headphones"]:
				look.erase(k)
		"medic":
			look = random_look(rng, "scrubs")
			if rng.randf() < 0.7:
				look["lanyard"] = _pick(rng, [ACCENTS[2], ACCENTS[6], NEUTRALS[4]])
			look.shoe_style = "sneakers"
			look.shoes = _pick(rng, [NEUTRALS[4], NEUTRALS[4], NEUTRALS[0]])
		_:
			look = random_look(rng)
			match look.outfit:
				"scrubs":
					cat = "medic"
				"hivis", "delivery":
					cat = "worker"
				"suit":
					cat = "office"
	look["category"] = cat
	return look


## Makes the rest of a random look suit its top: work clothes, suits, summer
## and winter wear.
static func _fit_outfit(rng: RandomNumberGenerator, look: Dictionary, col: int) -> void:
	match look.outfit:
		"suit":
			look.jacket = _pick(rng, [NEUTRALS[2], NEUTRALS[12], NEUTRALS[0], NEUTRALS[13], NEUTRALS[7]])
			look.pants = look.jacket
			look.shirt = NEUTRALS[4] if rng.randf() < 0.7 else Color(0.7, 0.8, 0.92)
			look.bottoms = "trousers"
			look.shoe_style = "dress"
			look.shoes = _pick(rng, [NEUTRALS[0], NEUTRALS[9]])
			if rng.randf() < 0.65:
				look["tie"] = _pick(rng, [NEUTRALS[12], NEUTRALS[14], NEUTRALS[0], ACCENTS[2], ACCENTS[1]])
			look.headwear = ""
			look.erase("socks")
		"blazer":
			look.jacket = _pick(rng, [NEUTRALS[12], NEUTRALS[2], NEUTRALS[8], NEUTRALS[0], NEUTRALS[7], NEUTRALS[10]])
			look.shirt = _pick(rng, [NEUTRALS[4], NEUTRALS[0], NEUTRALS[3], NEUTRALS[6]])
			if look.bottoms in ["joggers", "cargo", "shorts"]:
				look.bottoms = "trousers" if rng.randf() < 0.6 else "jeans"
				look.pants = _pants_color(rng, look.bottoms)
			if rng.randf() < 0.4:
				look.shoe_style = "dress"
				look.shoes = _pick(rng, [NEUTRALS[0], NEUTRALS[9]])
			look.headwear = ""
		"scrubs":
			look.shirt = _pick(rng, SCRUBS)
			look.pants = look.shirt
			look.bottoms = "scrubs"
			look.erase("print")
			look.erase("bag")
			look.headwear = ""
		"hivis":
			look.jacket = _pick(rng, HIVIS)
			look.shirt = _pick(rng, [NEUTRALS[0], NEUTRALS[2], NEUTRALS[3], NEUTRALS[12], NEUTRALS[4]])
			look.bottoms = "cargo" if rng.randf() < 0.6 else "jeans"
			look.pants = _pants_color(rng, look.bottoms)
			look.shoe_style = "boots"
			look.shoes = _pick(rng, BOOTS)
			look.headwear = "hardhat" if rng.randf() < 0.7 else look.headwear
			look.hat = _pick(rng, [NEUTRALS[4], HIVIS[0], HIVIS[2], ACCENTS[2]])
			look.erase("bag")
			look.erase("phone")
		"delivery":
			var brand: Color = _pick(rng, DELIVERY)
			look.jacket = brand
			look.bag = "cube"
			look.bag_color = brand
			look.headwear = "helmet" if rng.randf() < 0.8 else "cap"
			look.hat = brand if rng.randf() < 0.5 else NEUTRALS[0]
			look.bottoms = _pick(rng, ["joggers", "joggers", "cargo", "jeans"])
			look.pants = _pants_color(rng, look.bottoms)
			look.erase("headphones")
		"dress":
			look.shirt = _cloth(rng, 0.35)
			look["length"] = 0.56 if rng.randf() < 0.55 else 0.7
			look.shoe_style = _pick(rng, ["sneakers", "sneakers", "heels", "slides"])
		"tank", "jersey":
			if rng.randf() < 0.5:
				look.bottoms = "shorts" if look.outfit == "jersey" or col == 1 else _pick(rng, ["shorts", "skirt"])
				look.pants = _pants_color(rng, look.bottoms)
			if look.outfit == "jersey":
				look.shirt = _pick(rng, [NEUTRALS[12], NEUTRALS[4], NEUTRALS[14], NEUTRALS[0], ACCENTS[0], ACCENTS[2], ACCENTS[6], ACCENTS[3]])
				look.accent = NEUTRALS[4] if look.shirt.v < 0.6 else NEUTRALS[12]
				look["number"] = rng.randi_range(0, 99)
				look.erase("print")
		"puffer", "puffer_vest":
			look.jacket = _cloth(rng, 0.3)
			if look.bottoms in ["shorts", "skirt"]:
				look.bottoms = "jeans"
				look.pants = _pants_color(rng, look.bottoms)
			if look.headwear == "" and rng.randf() < 0.3:
				look.headwear = "beanie"
		"bomber":
			look.accent = look.jacket.darkened(0.35) if rng.randf() < 0.6 else _pick(rng, ACCENTS)
		"denim":
			look.jacket = _pick(rng, [DENIM[1], DENIM[2], DENIM[3], DENIM[4]])
			if look.bottoms == "jeans":
				look.pants = NEUTRALS[0] if rng.randf() < 0.5 else _pick(rng, PANTS)
				look.bottoms = "trousers" if rng.randf() < 0.5 else "jeans"
		"hoodie":
			look.jacket = _cloth(rng, 0.25)
		"cardigan":
			look.jacket = _pick(rng, KNITS)
			look.shirt = _pick(rng, [NEUTRALS[4], NEUTRALS[6], Color(0.7, 0.8, 0.92), NEUTRALS[3]])
			if look.bottoms in ["shorts", "leggings", "joggers", "cargo"]:
				look.bottoms = "trousers"
				look.pants = _pants_color(rng, look.bottoms)
			look.erase("print")
	if look.outfit not in ["dress", "tank", "jersey", "suit", "blazer", "scrubs", "hivis"] and look.bottoms == "shorts" and rng.randf() < 0.5:
		look.shoe_style = "slides" if rng.randf() < 0.3 else "sneakers"
	if look.shoe_style == "sneakers" and look.outfit not in ["delivery", "jersey"] and rng.randf() < 0.12:
		look.shoe_style = "boots"
		look.shoes = _pick(rng, BOOTS)
	if look.shoe_style in ["heels", "slides"]:
		look.shoes = _cloth(rng, 0.3)


static func _pants_color(rng: RandomNumberGenerator, bottoms: String) -> Color:
	match bottoms:
		"jeans":
			return _pick(rng, DENIM)
		"leggings":
			return _pick(rng, [NEUTRALS[0], NEUTRALS[0], NEUTRALS[2], NEUTRALS[12], NEUTRALS[10]])
		"skirt":
			return _cloth(rng, 0.3) if rng.randf() < 0.7 else _pick(rng, DENIM)
		"shorts":
			return _pick(rng, PANTS) if rng.randf() < 0.7 else _pick(rng, DENIM)
	return _pick(rng, PANTS)


## A clothing colour: a neutral, or a bright with chance `bright`.
static func _cloth(rng: RandomNumberGenerator, bright: float) -> Color:
	return _pick(rng, ACCENTS) if rng.randf() < bright else _pick(rng, NEUTRALS)


static func _pick(rng: RandomNumberGenerator, from: Array):
	return from[rng.randi() % from.size()]


## The name in a [name, weight, weight...] table, picked by column `col`.
static func _weighted(rng: RandomNumberGenerator, table: Array, col: int) -> String:
	var total := 0.0
	for row in table:
		total += row[col]
	var r := rng.randf() * total
	for row in table:
		r -= row[col]
		if r < 0.0:
			return row[0]
	return table[0][0]


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


## look keys, all optional (missing keys fall back to plain defaults):
## - outfit, the top: tee, tank, polo, jersey, hoodie, jacket (open zip
##   jacket), bomber, denim (denim jacket), puffer, puffer_vest (or vest),
##   blazer (over a tee), suit, dress, scrubs, hivis (vest over a tee),
##   delivery (rider jacket and cube bag), cardigan (open knit over a shirt),
##   uniform (police; duty_vest false leaves off the vest).
## - shirt: the top's colour, or the layer under a jacket; jacket: the outer
##   layer; accent: trim, stripes and numbers; print: a logo block on the
##   chest (back_print adds one on the back); number: jersey number; tie;
##   sleeves: long, short or none (each outfit has its own default); length:
##   dress hem height.
## - bottoms: trousers, jeans, joggers, cargo, shorts, leggings, skirt,
##   scrubs; pants: their colour; tights: legs under a dress or skirt
##   (default bare skin); socks: sock colour.
## - shoe_style: sneakers, boots, slides, dress, heels; shoes: upper colour;
##   sole; shoe_accent: the side stripe.
## - skin, hair (style), hair_color, beard, headwear (cap, cap_back, beanie,
##   bucket, helmet, hardhat, police, bandana) and hat (its colour); the old
##   hair styles cap, beanie and police still work; headband (colour).
## - glasses, sunglasses, headphones (colour), necklace (colour), chain (a
##   heavy chain, colour), lanyard (colour, with an ID card), camera (colour,
##   on a neck strap), apron (colour), cane (colour, in the right hand), bag
##   (backpack, crossbody, tote, cube, briefcase, shopping: a bag in each
##   hand) and bag_color, phone (colour; held in the right hand), build
##   (shoulder width), height.
## - hero: finer limbs and head for the player; stripes (colour): racing
##   stripes over the shoulders and down the sleeves and a band across the
##   back, so the hero reads from above.
static func build(mb, look: Dictionary) -> void:
	var o := _spec(look)
	_hips(mb, look, o)
	_torso(mb, look, o)
	_extras(mb, look, o)
	mb.set_bone(bone_index("Neck"))
	_tube(mb, Vector3(0, 1.42, 0), Vector3(0, 1.58, 0), 0.07, 0.065, o.skin)
	if look.has("necklace"):
		_tube(mb, Vector3(0, 1.455, 0), Vector3(0, 1.47, 0), 0.079, 0.077, look.necklace)
	mb.set_bone(bone_index("Head"))
	_head(mb, look, o)
	_arms(mb, look, o)
	_legs(mb, look, o)


## Colours and cut shared by the body parts.
static func _spec(look: Dictionary) -> Dictionary:
	var outfit: String = look.get("outfit", "tee")
	if outfit == "vest":
		outfit = "puffer_vest"
	var shirt: Color = look.get("shirt", Color.GRAY)
	var jacket: Color = look.get("jacket", shirt.darkened(0.3))
	var outer := outfit in OUTERWEAR
	var sleeves := "short"
	if outer or outfit in ["uniform", "puffer_vest"]:
		sleeves = "long"
	elif outfit in ["tank", "dress"]:
		sleeves = "none"
	var bottoms: String = look.get("bottoms", "trousers")
	if outfit == "dress":
		bottoms = "dress"
	elif outfit == "scrubs" and not look.has("bottoms"):
		bottoms = "scrubs"
	var bulk: float = BULK.get(outfit, 1.0)
	if outfit == "uniform" and look.get("duty_vest", true):
		bulk = 1.06
	return {
		"outfit": outfit, "shirt": shirt, "jacket": jacket, "skin": look.get("skin", SKIN[0]),
		"top": jacket if outer or outfit in ["puffer_vest", "hivis"] else shirt,
		"sleeve": jacket if outer else shirt,
		"sleeves": look.get("sleeves", sleeves),
		"pants": look.get("pants", Color(0.2, 0.22, 0.3)),
		"bottoms": bottoms,
		"accent": look.get("accent", Color(0.92, 0.91, 0.88)),
		"w": look.get("build", 1.0),
		"bulk": bulk,
		"shoe_style": look.get("shoe_style", "dress" if outfit == "suit" else ("boots" if outfit == "uniform" else "sneakers")),
		"sides": 12 if look.get("hero", false) else 8,
	}


## Pelvis, belts, the skirt of a dress or skirt.
static func _hips(mb, look: Dictionary, o: Dictionary) -> void:
	var w: float = o.w
	var pants: Color = o.pants
	mb.set_bone(bone_index("Hips"))
	if o.outfit == "dress":
		var hem: float = look.get("length", 0.56)
		var flare := lerpf(0.22, 0.27, clampf((0.72 - hem) / 0.16, 0.0, 1.0)) * w
		mb.limb(Vector3(0, 1.04, 0), Vector3(0, hem, 0), 0.17 * w, flare, o.shirt, 8)
		_tube(mb, Vector3(0, hem + 0.035, 0), Vector3(0, hem - 0.002, 0), flare * 0.96, flare * 1.01, o.shirt.darkened(0.2), 8)
		return
	_ball(mb, Vector3(0, 0.95, 0), Vector3(0.19 * w, 0.13, 0.13), pants, 8, 3)
	if o.bottoms == "skirt":
		mb.limb(Vector3(0, 1.02, 0), Vector3(0, 0.64, 0), 0.18 * w, 0.24 * w, pants, 8)
		_tube(mb, Vector3(0, 0.67, 0), Vector3(0, 0.638, 0), 0.232 * w, 0.242 * w, pants.darkened(0.2), 8)
	elif o.bottoms == "jeans":
		for side in [-1.0, 1.0]:
			mb.box(Vector3(side * 0.08 * w, 0.96, 0.128), Vector3(0.085, 0.085, 0.02), pants.darkened(0.18))
	if o.outfit in ["suit", "polo", "uniform"] or (o.outfit == "blazer" and o.bottoms != "jeans"):
		# Tucked in: belt and buckle.
		var belt := Color(0.09, 0.09, 0.1) if o.outfit == "uniform" else Color(0.22, 0.15, 0.1)
		_band(mb, 1.01, 0.188 * w, 0.132, 0.035, belt)
		mb.box(Vector3(0, 1.01, -0.135), Vector3(0.05, 0.04, 0.02), Color(0.78, 0.72, 0.5))
	if o.outfit == "uniform":
		# Duty belt: holster on the right, pouches, radio at the back.
		var black := Color(0.08, 0.08, 0.09)
		_block(mb, Vector3(0.2 * w, 0.93, 0.01), Vector3(0.06, 0.17, 0.11), black)
		_block(mb, Vector3(0.2 * w, 1.02, 0.03), Vector3(0.05, 0.05, 0.04), Color(0.25, 0.25, 0.27))
		_block(mb, Vector3(-0.12 * w, 0.99, -0.13), Vector3(0.07, 0.07, 0.04), black)
		_block(mb, Vector3(-0.19 * w, 0.99, -0.05), Vector3(0.04, 0.07, 0.07), black)
		_block(mb, Vector3(0.08 * w, 0.99, 0.135), Vector3(0.07, 0.09, 0.04), black)


## Torso layers: base shape, hem, collar and the outfit's details, then the bag.
static func _torso(mb, look: Dictionary, o: Dictionary) -> void:
	var outfit: String = o.outfit
	var w: float = o.w
	var bulk: float = o.bulk
	var shirt: Color = o.shirt
	var jacket: Color = o.jacket
	var top: Color = o.top
	var skin: Color = o.skin
	var accent: Color = o.accent
	var quilted := outfit in ["puffer", "puffer_vest"]
	# Under a vest the shirt keeps the body's own size; the vest stands off.
	var shape := 1.0 if outfit in ["hivis", "uniform"] else bulk
	var open := outfit in ["jacket", "denim", "blazer", "suit"]
	var tucked: bool = outfit in ["suit", "polo", "uniform", "dress"] or (outfit == "blazer" and o.bottoms != "jeans")

	mb.set_bone(bone_index("Spine"))
	if quilted:
		_quilt(mb, [[1.08, 0.215, 0.15], [0.98, 0.2, 0.145]], w, top)
	else:
		# One lofted body from the waist up to the shoulders (0.24: two
		# overlapping balls creased where they met), the rings above 1.2
		# bound to the chest.
		var rings := []
		for y in [1.0, 1.05, 1.1, 1.15, 1.2, 1.25, 1.3, 1.35, 1.4, 1.44, 1.47, 1.49]:
			var g := _profile(y, w, shape)
			var ring := [y, g.x, g.y, (shirt if outfit in ["hivis", "uniform"] else top) if y >= 1.19 else (shirt if outfit in ["uniform", "dress"] else top)]
			if rings.size() == 4:
				ring.append(bone_index("Chest"))
			rings.append(ring)
		mb.loft(rings, 12 if o.sides > 8 else 10, 0.012)
		mb.set_bone(bone_index("Spine"))
	if outfit in ["blazer", "suit"]:
		# Tailored jackets come down over the hips.
		_band(mb, 0.95, 0.205 * w, 0.148, 0.07, jacket)
	elif not tucked and not quilted:
		var hem := top
		if outfit in ["jacket", "bomber", "hoodie", "delivery", "cardigan"]:
			hem = accent if outfit == "bomber" else jacket.darkened(0.18)
		_band(mb, 1.0, 0.198 * w * maxf(bulk, 1.02), 0.138 * bulk, 0.045, hem)
		if outfit == "hivis":
			_band(mb, 0.99, 0.196 * w, 0.137, 0.035, shirt)

	mb.set_bone(bone_index("Chest"))
	if quilted:
		_quilt(mb, [[1.44, 0.23, 0.14], [1.32, 0.27, 0.17], [1.2, 0.255, 0.165]], w, top)
	var sleeve: Color = o.sleeve if o.sleeves != "none" else skin
	for side in [-1.0, 1.0]:
		_ball(mb, Vector3(side * 0.24 * w, 1.39, 0), Vector3(0.09, 0.08, 0.09) * (1.08 if quilted and outfit == "puffer" else 1.0), sleeve, 8, 4)

	match outfit:
		"tee", "jersey", "scrubs", "hivis":
			var rib := shirt.darkened(0.15) if outfit != "jersey" else accent
			if outfit == "scrubs":
				# V-neck, chest pocket and an ID badge.
				var vn := [_surf(-0.075, 1.46, -1.0, w, bulk), _surf(0.075, 1.46, -1.0, w, bulk), _surf(0.0, 1.35, -1.0, w, bulk)]
				mb.tri(vn[0], vn[1], vn[2], Vector3(0, 0.4, -1).normalized(), skin)
				_panel(mb, -0.11, 1.34, 1.27, 0.045, 0.045, -1.0, shirt.darkened(0.12), w, bulk, 1)
				_panel(mb, -0.11, 1.33, 1.28, 0.022, 0.022, -1.0, Color(0.95, 0.95, 0.95), w, bulk, 1, 0.016)
			else:
				_tube(mb, Vector3(0, 1.455, 0), Vector3(0, 1.505, 0), 0.088, 0.082, rib)
			if outfit == "jersey":
				_number(mb, look.get("number", 23), 0.0, 1.31, 0.07, 0.14, 1.0, accent, w, bulk)
				_number(mb, look.get("number", 23), 0.1, 1.36, 0.035, 0.07, -1.0, accent, w, bulk)
			elif look.has("print") and outfit != "hivis":
				_print(mb, look, w, bulk)
			if outfit == "hivis":
				_hivis(mb, w, jacket)
		"tank":
			# Scoop neck front and back, and the straps.
			_ball(mb, Vector3(0, 1.43, 0), Vector3(0.12 * w, 0.075, 0.125), skin, 8, 2)
			for side in [-1.0, 1.0]:
				_strip(mb, [_surf(side * 0.13, 1.4, -1.0, w, bulk), Vector3(side * 0.13 * w, 1.5, 0), _surf(side * 0.13, 1.4, 1.0, w, bulk)], 0.025, shirt)
			if look.has("print"):
				_print(mb, look, w, bulk)
		"polo":
			_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.52, 0), 0.092, 0.096, shirt.darkened(0.06))
			_panel(mb, 0.0, 1.46, 1.36, 0.022, 0.022, -1.0, shirt.darkened(0.15), w, bulk, 1)
			_panel(mb, -0.12, 1.36, 1.32, 0.025, 0.025, -1.0, accent, w, bulk, 1)
		"dress":
			_ball(mb, Vector3(0, 1.43, 0), Vector3(0.12 * w, 0.07, 0.12), skin, 8, 2)
			_band(mb, 1.06, 0.175 * w, 0.125, 0.03, look.get("belt", shirt.darkened(0.25)))
		"hoodie":
			# Hood bunched on the back, drawstrings, kangaroo pocket.
			_ball(mb, Vector3(0, 1.47, 0.11), Vector3(0.16, 0.1, 0.1), jacket.darkened(0.06), 8, 3)
			_ball(mb, Vector3(0, 1.53, 0.1), Vector3(0.1, 0.035, 0.06), jacket.darkened(0.45), 6, 2)
			_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.5, 0), 0.09, 0.088, jacket.darkened(0.1))
			for side in [-1.0, 1.0]:
				_surf_strip(mb, [Vector2(side * 0.035, 1.47), Vector2(side * 0.045, 1.34)], -1.0, 0.012, w, bulk, 0.009, NEUTRALS[4] if jacket.v < 0.7 else NEUTRALS[0])
			_panel(mb, 0.0, 1.22, 1.1, 0.1, 0.125, -1.0, jacket.darkened(0.12), w, bulk, 1, 0.016, 3)
			if look.has("print"):
				_print(mb, look, w, bulk, 1.33)
		"jacket", "denim", "blazer", "suit", "cardigan":
			# Open front showing the layer under it.
			var inner := shirt
			var vee := outfit in ["blazer", "suit", "cardigan"]
			_panel(mb, 0.0, 1.47, 1.03, 0.075 if vee else 0.06, 0.03 if vee else 0.055, -1.0, inner, w, bulk, 3)
			if outfit == "cardigan":
				# Button band and buttons down the left front, shirt collar.
				_surf_strip(mb, [Vector2(-0.07, 1.46), Vector2(-0.033, 1.25), Vector2(-0.03, 1.03)], -1.0, 0.016, w, bulk, 0.009, jacket.darkened(0.15))
				for y in [1.24, 1.15, 1.06]:
					_panel(mb, -0.034, y + 0.012, y - 0.012, 0.012, 0.012, -1.0, jacket.lightened(0.45), w, bulk, 1, 0.02)
				_tube(mb, Vector3(0, 1.455, 0), Vector3(0, 1.5, 0), 0.085, 0.082, shirt)
			if outfit in ["blazer", "suit"]:
				for side in [-1.0, 1.0]:
					_surf_strip(mb, [Vector2(side * 0.09, 1.47), Vector2(side * 0.04, 1.2)], -1.0, 0.02, w, bulk, 0.02, jacket.darkened(0.2))
				_panel(mb, -0.15, 1.37, 1.35, 0.035, 0.035, -1.0, accent if look.has("accent") else jacket.lightened(0.15), w, bulk, 1)
				if look.has("tie"):
					_panel(mb, 0.0, 1.45, 1.18, 0.018, 0.026, -1.0, look.tie, w, bulk, 2, 0.02)
				if outfit == "blazer":
					_tube(mb, Vector3(0, 1.455, 0), Vector3(0, 1.495, 0), 0.085, 0.08, shirt.darkened(0.15))
				else:
					_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.51, 0), 0.088, 0.086, shirt)
			elif outfit == "denim":
				for side in [-1.0, 1.0]:
					mb.tri(Vector3(side * 0.06, 1.5, -0.04), _surf(side * 0.19, 1.43, -1.0, w, bulk, 0.02), _surf(side * 0.08, 1.37, -1.0, w, bulk, 0.02), Vector3(0, 0.6, -1).normalized(), jacket.darkened(0.15))
					_panel(mb, side * 0.13, 1.35, 1.31, 0.045, 0.045, -1.0, jacket.darkened(0.15), w, bulk, 1, 0.017)
				_surf_strip(mb, [Vector2(-0.2, 1.38), Vector2(0.0, 1.4), Vector2(0.2, 1.38)], 1.0, 0.012, w, bulk, 0.008, jacket.lightened(0.3))
				_tube(mb, Vector3(0, 1.455, 0), Vector3(0, 1.5, 0), 0.085, 0.082, shirt.darkened(0.15))
			elif outfit == "jacket":
				# Zip jacket: stand collar and zip edges.
				_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.53, 0), 0.096, 0.092, jacket.darkened(0.08))
				for side in [-1.0, 1.0]:
					_surf_strip(mb, [Vector2(side * 0.06, 1.46), Vector2(side * 0.058, 1.25), Vector2(side * 0.056, 1.04)], -1.0, 0.016, w, bulk, 0.007, jacket.lightened(0.3))
				if look.has("print"):
					_print(mb, look, w, bulk, 1.32, false)
		"bomber", "delivery":
			# Closed zip, rib collar (bomber) or high collar and a reflective band.
			_surf_strip(mb, [Vector2(0.0, 1.48), Vector2(0.0, 1.25), Vector2(0.0, 1.02)], -1.0, 0.016, w, bulk, 0.008, Color(0.6, 0.6, 0.62))
			if outfit == "bomber":
				_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.51, 0), 0.094, 0.09, accent)
			else:
				_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.55, 0), 0.1, 0.095, jacket.darkened(0.15))
				var g := _girth(1.33, w, bulk)
				_band(mb, 1.33, g.x + 0.01, g.y + 0.01, 0.025, REFLECTIVE)
		"puffer", "puffer_vest":
			_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.56, 0), 0.1, 0.097, jacket.darkened(0.08))
			_surf_strip(mb, [Vector2(0.0, 1.5), Vector2(0.0, 1.25), Vector2(0.0, 1.0)], -1.0, 0.03, w, bulk, 0.007, jacket.darkened(0.4))
		"uniform":
			_uniform(mb, look, o)
	_bag(mb, look, o)


## Worn over the top: apron, lanyard, chain, camera and the hero's stripes.
static func _extras(mb, look: Dictionary, o: Dictionary) -> void:
	var w: float = o.w
	var bulk: float = o.bulk
	mb.set_bone(bone_index("Chest"))
	if look.has("apron"):
		var col: Color = look.apron
		# Bib with a pocket, and the strap round the neck.
		_panel(mb, 0.0, 1.4, 1.06, 0.1, 0.15, -1.0, col, w, bulk, 2, 0.022)
		_panel(mb, 0.0, 1.31, 1.23, 0.06, 0.06, -1.0, col.darkened(0.15), w, bulk, 1, 0.027)
		for side in [-1.0, 1.0]:
			_strip(mb, [_surf(side * 0.09, 1.4, -1.0, w, bulk, 0.022), Vector3(side * 0.085, 1.5, -0.03), Vector3(side * 0.075, 1.53, 0.05)], 0.012, col.darkened(0.2))
	if look.has("lanyard"):
		var card := _surf(0.0, 1.27, -1.0, w, bulk, 0.026)
		for side in [-1.0, 1.0]:
			_strip(mb, [_surf(side * 0.075, 1.46, -1.0, w, bulk, 0.024), _surf(side * 0.03, 1.34, -1.0, w, bulk, 0.024), card + Vector3(side * 0.008, 0.03, 0)], 0.008, look.lanyard)
		_panel(mb, 0.0, 1.29, 1.21, 0.032, 0.032, -1.0, Color(0.95, 0.95, 0.95), w, bulk, 1, 0.03)
	if look.has("chain"):
		var pts := []
		for k in 7:
			var a := PI * k / 6.0
			pts.append(_surf(-cos(a) * 0.085, 1.47 - sin(a) * 0.12, -1.0, w, bulk, 0.026))
		_strip(mb, pts, 0.011, look.chain)
		_panel(mb, 0.0, 1.36, 1.31, 0.022, 0.022, -1.0, look.chain.lightened(0.25), w, bulk, 1, 0.031)
	if look.has("camera"):
		var col: Color = look.camera
		var p := _surf(0.0, 1.24, -1.0, w, bulk, 0.0)
		for side in [-1.0, 1.0]:
			_surf_strip(mb, [Vector2(side * 0.08, 1.46), Vector2(side * 0.065, 1.29)], -1.0, 0.024, w, bulk, 0.008, Color(0.1, 0.1, 0.11))
		_block(mb, p + Vector3(0, 0, -0.04), Vector3(0.14, 0.085, 0.06), col)
		_block(mb, p + Vector3(0, -0.005, -0.085), Vector3(0.055, 0.055, 0.04), Color(0.15, 0.15, 0.16))
		mb.box(p + Vector3(0, -0.005, -0.106), Vector3(0.036, 0.036, 0.004), Color(0.3, 0.42, 0.6))
		mb.box(p + Vector3(0.045, 0.046, -0.04), Vector3(0.03, 0.008, 0.025), Color(0.85, 0.85, 0.85))
	if look.has("stripes"):
		# Two stripes over each shoulder and a band across the back.
		var col: Color = look.stripes
		for side in [-1.0, 1.0]:
			for z in [-0.024, 0.024]:
				_strip(mb, [Vector3(side * 0.1 * w, 1.49, z), Vector3(side * 0.18 * w, 1.453, z), Vector3(side * 0.24 * w, 1.477, z),
					Vector3(side * (0.24 * w + 0.068), 1.452, z)], 0.009, col)
		_panel(mb, 0.0, 1.42, 1.37, 0.19, 0.2, 1.0, col, w, bulk, 1, 0.016, 4)
	if look.has("apron"):
		# The apron's skirt hangs from the waist tie.
		var col: Color = look.apron
		mb.set_bone(bone_index("Hips"))
		var a := Vector3(-0.16 * w, 1.06, -0.15)
		var b := Vector3(0.16 * w, 1.06, -0.15)
		var c := Vector3(0.19 * w, 0.6, -0.19)
		var d := Vector3(-0.19 * w, 0.6, -0.19)
		var n := Vector3(0, 0.09, -1).normalized()
		mb.quad(a, b, c, d, n, col)
		mb.quad(Vector3(-0.08, 0.86, -0.176), Vector3(0.08, 0.86, -0.176), Vector3(0.08, 0.77, -0.184), Vector3(-0.08, 0.77, -0.184), n, col.darkened(0.15))
		_band(mb, 1.05, 0.195 * w, 0.14, 0.022, col.darkened(0.25))


## Quilted puffer bands: [height, half width, half depth] each.
static func _quilt(mb, bands: Array, w: float, color: Color) -> void:
	for b in bands:
		_ball(mb, Vector3(0, b[0], 0), Vector3(b[1] * w, 0.068, b[2]), color, 8, 3)


## A logo block on the chest, and on the back for some.
static func _print(mb, look: Dictionary, w: float, bulk: float, y := 1.32, front := true) -> void:
	var c: Color = look.print
	if front:
		_panel(mb, 0.0, y + 0.05, y - 0.04, 0.065, 0.065, -1.0, c, w, bulk, 1, 0.016, 2)
	if look.get("back_print", false):
		_panel(mb, 0.0, 1.4, 1.25, 0.1, 0.1, 1.0, c, w, bulk, 2, 0.016, 2)


## Hi-vis vest over a tee: reflective bands round the body and braces over
## the shoulders.
static func _hivis(mb, w: float, vest: Color) -> void:
	var bulk := 1.05
	_ball(mb, Vector3(0, 1.29, 0), Vector3(0.262 * w, 0.18, 0.162), vest, 8, 4)
	_ball(mb, Vector3(0, 1.11, 0), Vector3(0.205 * w, 0.13, 0.145), vest, 8, 3)
	for y in [1.15, 1.27]:
		var g := _girth(y, w, bulk)
		_band(mb, y, g.x + 0.012, g.y + 0.012, 0.022, REFLECTIVE)
	for side in [-1.0, 1.0]:
		_strip(mb, [_surf(side * 0.1, 1.28, -1.0, w, bulk, 0.02), _surf(side * 0.11, 1.43, -1.0, w, bulk, 0.02), Vector3(side * 0.12 * w, 1.485, 0), _surf(side * 0.11, 1.43, 1.0, w, bulk, 0.02), _surf(side * 0.1, 1.28, 1.0, w, bulk, 0.02)], 0.022, REFLECTIVE)


## Police: shirt with badge and shoulder patches, a carrier vest with a light
## back panel, a radio on the shoulder.
static func _uniform(mb, look: Dictionary, o: Dictionary) -> void:
	var w: float = o.w
	var bulk: float = o.bulk
	var gold := Color(0.95, 0.8, 0.25)
	var black := Color(0.08, 0.08, 0.09)
	_tube(mb, Vector3(0, 1.45, 0), Vector3(0, 1.515, 0), 0.092, 0.097, o.shirt.darkened(0.08))
	if look.get("duty_vest", true):
		var vest: Color = look.get("vest_color", Color(0.11, 0.12, 0.15))
		_ball(mb, Vector3(0, 1.29, 0), Vector3(0.262 * w, 0.175, 0.162), vest, 8, 4)
		_ball(mb, Vector3(0, 1.12, 0), Vector3(0.205 * w, 0.12, 0.148), vest, 8, 3)
		_panel(mb, 0.0, 1.4, 1.32, 0.13, 0.13, 1.0, Color(0.88, 0.88, 0.84), w, bulk, 1, 0.015, 3)
		_panel(mb, 0.0, 1.27, 1.12, 0.12, 0.12, -1.0, vest.lightened(0.08), w, bulk, 1, 0.014, 3)
		_panel(mb, -0.1, 1.38, 1.33, 0.025, 0.025, -1.0, gold, w, bulk, 1, 0.016)
		_block(mb, Vector3(0.13 * w, 1.45, -0.09), Vector3(0.05, 0.08, 0.04), black)
		mb.box(Vector3(0.145 * w, 1.52, -0.09), Vector3(0.012, 0.06, 0.012), black)
	else:
		_panel(mb, -0.1, 1.38, 1.33, 0.025, 0.025, -1.0, gold, w, 1.0, 1, 0.014)
		_panel(mb, 0.0, 1.46, 1.06, 0.012, 0.012, -1.0, o.shirt.darkened(0.12), w, 1.0, 2, 0.012)
		for side in [-1.0, 1.0]:
			_panel(mb, side * 0.13, 1.36, 1.3, 0.04, 0.04, -1.0, o.shirt.darkened(0.06), w, 1.0, 1, 0.014)


## The bag on the back, across the body or in the left hand.
static func _bag(mb, look: Dictionary, o: Dictionary) -> void:
	var bag: String = look.get("bag", "")
	var col: Color = look.get("bag_color", Color(0.12, 0.12, 0.13))
	var w: float = o.w
	var bulk: float = o.bulk
	var back := _surf(0.0, 1.28, 1.0, w, bulk, 0.0).z
	match bag:
		"backpack", "cube":
			var cube := bag == "cube"
			var size := Vector3(0.44, 0.44, 0.38) if cube else Vector3(0.3, 0.36, 0.14)
			var c := Vector3(0, 1.31 if cube else 1.26, back + size.z * 0.5 + 0.01)
			mb.box(c, size, col)
			var strap := col.darkened(0.3) if not cube else Color(0.12, 0.12, 0.13)
			for side in [-1.0, 1.0]:
				var x: float = side * 0.12 * w
				_strip(mb, [_surf(x, 1.16, -1.0, w, bulk), _surf(x, 1.41, -1.0, w, bulk), Vector3(x, _shoulder_top(x, w, bulk), 0), Vector3(x, 1.42, back + 0.02)], 0.022, strap)
			if cube:
				# Lid seam, and the brand's logo on top and back.
				mb.box(c + Vector3(0, size.y * 0.5 + 0.004, 0), Vector3(size.x + 0.02, 0.008, size.z + 0.02), col.darkened(0.2))
				mb.box(c + Vector3(0, size.y * 0.5 + 0.01, 0.02), Vector3(0.2, 0.008, 0.16), col.lightened(0.55))
				mb.box(c + Vector3(0, 0.03, size.z * 0.5 + 0.005), Vector3(0.22, 0.16, 0.01), col.lightened(0.55))
			else:
				mb.box(c + Vector3(0, -0.07, size.z * 0.5 + 0.015), Vector3(0.22, 0.15, 0.03), col.darkened(0.15))
				mb.box(c + Vector3(0, size.y * 0.5 + 0.015, 0), Vector3(0.08, 0.02, 0.03), col.darkened(0.3))
		"crossbody":
			var strap := col.darkened(0.35)
			var top := Vector3(-0.13 * w, _shoulder_top(-0.13 * w, w, bulk), 0)
			_strip(mb, [_surf(0.14, 1.11, -1.0, w, bulk), _surf(0.02, 1.27, -1.0, w, bulk), _surf(-0.11, 1.41, -1.0, w, bulk), top], 0.018, strap)
			_strip(mb, [top, _surf(-0.11, 1.41, 1.0, w, bulk), _surf(0.04, 1.24, 1.0, w, bulk), _surf(0.17, 1.08, 1.0, w, bulk)], 0.018, strap)
			var p := _surf(0.13, 1.08, -1.0, w, bulk, 0.0)
			_block(mb, p + Vector3(0, 0, -0.035), Vector3(0.2, 0.12, 0.07), col)
			mb.box(p + Vector3(0, 0.035, -0.072), Vector3(0.19, 0.035, 0.01), col.darkened(0.2))
		"briefcase":
			mb.set_bone(bone_index("LeftHand"))
			_block(mb, Vector3(-0.3, 0.6, 0.0), Vector3(0.08, 0.27, 0.38), col)
			mb.box(Vector3(-0.3, 0.75, 0.0), Vector3(0.025, 0.06, 0.11), col.darkened(0.35))
			mb.box(Vector3(-0.342, 0.69, 0.0), Vector3(0.004, 0.025, 0.22), Color(0.75, 0.68, 0.45))
		"shopping":
			# A paper bag in each hand (walk style "carry" holds them clear).
			for side in [-1.0, 1.0]:
				mb.set_bone(bone_index("LeftHand" if side < 0 else "RightHand"))
				var bc: Color = col if side < 0 else Color(0.78, 0.66, 0.48)
				_block(mb, Vector3(side * 0.31, 0.6, 0.0), Vector3(0.1, 0.27, 0.24), bc)
				for z in [-0.06, 0.06]:
					_strip(mb, [Vector3(side * 0.31, 0.735, z), Vector3(side * 0.3, 0.84, z * 0.2)], 0.008, bc.darkened(0.3), Vector3(side * -0.69, 0.78, 0), Vector3.ONE)
		"tote":
			mb.set_bone(bone_index("LeftHand"))
			var hand := Vector3(-0.3, 0.83, 0)
			mb.box(Vector3(-0.32, 0.58, 0), Vector3(0.11, 0.3, 0.3), col)
			for z in [-0.07, 0.07]:
				_strip(mb, [Vector3(-0.32, 0.73, z), hand + Vector3(-0.02, 0, z * 0.2)], 0.012, col.darkened(0.25), hand + Vector3(1, 0, 0), Vector3.ONE)
			if look.has("print"):
				mb.box(Vector3(-0.379, 0.6, 0), Vector3(0.008, 0.12, 0.12), look.print)


## Arms: sleeves by length, cuffs, hands, and the phone.
static func _arms(mb, look: Dictionary, o: Dictionary) -> void:
	var w: float = o.w
	var skin: Color = o.skin
	var sleeve: Color = o.sleeve
	var sleeves: String = o.sleeves
	var outfit: String = o.outfit
	var puff := 1.22 if outfit == "puffer" else (1.08 if outfit in ["hoodie", "bomber", "delivery"] else 1.0)
	var cuff: Color = sleeve.darkened(0.2)
	var sides: int = o.sides
	if outfit == "bomber":
		cuff = o.accent
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var sh := Vector3(side * 0.25 * w, 1.41, 0)
		var el := Vector3(side * 0.28, 1.13, 0)
		var wr := Vector3(side * 0.29, 0.9, 0)
		mb.set_bone(bone_index(prefix + "UpperArm"))
		if sleeves == "long":
			_tube(mb, sh, el, 0.075 * puff, 0.065 * puff, sleeve, sides)
			if look.has("stripes"):
				for z in [-0.022, 0.022]:
					_strip(mb, [sh + Vector3(side * 0.08 * puff, -0.03, z), el + Vector3(side * 0.07 * puff, 0, z)], 0.009, look.stripes, sh.lerp(el, 0.5) + Vector3(0, 0, z), Vector3.ONE)
			if outfit == "puffer":
				_ball(mb, sh.lerp(el, 0.5), Vector3(0.095, 0.05, 0.095), sleeve, 6, 2)
		else:
			_tube(mb, sh, el, 0.068, 0.058, skin, sides)
			if sleeves == "short":
				var hem := sh.lerp(el, 0.45)
				_tube(mb, sh, hem, 0.086, 0.08, sleeve)
				_tube(mb, hem + (sh - el) * 0.08, hem, 0.083, 0.082, o.accent if outfit == "jersey" else sleeve.darkened(0.12))
		if outfit == "bomber" and side < 0:
			mb.box(Vector3(side * (0.255 * w + 0.075), 1.33, 0), Vector3(0.01, 0.06, 0.05), Color(0.6, 0.6, 0.62))
		if outfit == "uniform":
			mb.box(Vector3(side * (0.255 * w + 0.072), 1.32, 0), Vector3(0.01, 0.08, 0.07), Color(0.95, 0.8, 0.25) if look.get("duty_vest", true) else o.shirt.darkened(0.3))
		if outfit == "delivery":
			_tube(mb, sh.lerp(el, 0.55), sh.lerp(el, 0.7), 0.079 * puff, 0.077 * puff, REFLECTIVE)

		mb.set_bone(bone_index(prefix + "LowerArm"))
		var fore := sleeve if sleeves == "long" else skin
		_ball(mb, el, Vector3(0.062, 0.062, 0.062) * (puff if sleeves == "long" else 1.0), fore, 5, 3)
		_tube(mb, el, wr, 0.06 * (puff if sleeves == "long" else 1.0), 0.05, fore, sides)
		if sleeves == "long":
			if look.has("stripes"):
				for z in [-0.02, 0.02]:
					_strip(mb, [el + Vector3(side * 0.066 * puff, 0, z), Vector3(side * 0.29, 0.95, 0) + Vector3(side * 0.06, 0, z)], 0.008, look.stripes, el.lerp(wr, 0.5) + Vector3(0, 0, z), Vector3.ONE)
			if outfit == "puffer":
				_ball(mb, el.lerp(wr, 0.5), Vector3(0.08, 0.045, 0.08), sleeve, 6, 2)
			_tube(mb, Vector3(side * 0.29, 0.94, 0), wr, 0.063, 0.063, cuff)

		mb.set_bone(bone_index(prefix + "Hand"))
		_hand(mb, side, skin, o.sides > 8)
		if side > 0 and look.has("cane"):
			_tube(mb, Vector3(0.296, 0.82, -0.03), Vector3(0.32, 0.0, -0.13), 0.013, 0.012, look.cane, 4)
			_tube(mb, Vector3(0.296, 0.875, 0.025), Vector3(0.296, 0.865, -0.06), 0.015, 0.015, look.cane, 4)
		if side > 0 and look.has("phone"):
			# Screen faces the palm side (forward), so it faces up when texting.
			mb.box(Vector3(0.29, 0.8, -0.065), Vector3(0.075, 0.15, 0.016), look.phone)
			mb.box(Vector3(0.29, 0.8, -0.075), Vector3(0.062, 0.13, 0.004), Color(0.1, 0.13, 0.2))


## A relaxed hand, palm to the thigh: palm, four fingers curling in towards
## it and the thumb forward (0.24: was a mitten). Finer on the hero.
static func _hand(mb, side: float, skin: Color, fine: bool) -> void:
	var x := side * 0.292
	var segs := 6 if fine else 4
	mb.smooth_ball(Vector3(x, 0.848, -0.004), Vector3(0.024, 0.05, 0.043), skin, 10 if fine else 8, 5)
	# Index to little finger, front to back: knuckle height and length.
	var fingers := [[-0.027, 0.068], [-0.009, 0.075], [0.009, 0.07], [0.026, 0.056]]
	for f in fingers:
		var root := Vector3(x, 0.81, f[0])
		var tip := Vector3(x - side * 0.016, 0.81 - f[1], f[0] * 1.1)
		var r := 0.0095 if f[1] > 0.06 else 0.0085
		mb.smooth_limb(root, tip, r, r * 0.85, skin, segs)
		mb.smooth_ball(tip, Vector3.ONE * r * 0.85, skin, segs, 3 if fine else 2)
	var thumb := Vector3(side * 0.278, 0.81, -0.058)
	mb.smooth_limb(Vector3(side * 0.288, 0.865, -0.032), thumb, 0.014, 0.011, skin, segs)
	mb.smooth_ball(thumb, Vector3.ONE * 0.011, skin, segs, 3 if fine else 2)


## Legs by cut: hems, cuffs, pockets, socks, then the shoes.
static func _legs(mb, look: Dictionary, o: Dictionary) -> void:
	var bottoms: String = o.bottoms
	var skin: Color = o.skin
	var pants: Color = o.pants
	var bare := bottoms in ["dress", "skirt"]
	var leg: Color = look.get("tights", skin) if bare else pants
	var fit: Array = LEG_FIT.get("bare" if bare or bottoms == "shorts" else bottoms, LEG_FIT.trousers)
	var socks: Color = look.get("socks", Color(0, 0, 0, 0))
	var sides: int = o.sides
	for side in [-1.0, 1.0]:
		var prefix := "Left" if side < 0 else "Right"
		var x: float = side * 0.11
		var hip := Vector3(x, 0.92, 0)
		var knee := Vector3(x, 0.5, 0)
		var ankle := Vector3(x, 0.1, 0)
		mb.set_bone(bone_index(prefix + "UpperLeg"))
		if bottoms == "shorts":
			_tube(mb, hip, knee, fit[0], fit[1], skin, sides)
			_tube(mb, hip, Vector3(x, 0.6, 0), 0.108, 0.1, pants, sides)
			_tube(mb, Vector3(x, 0.63, 0), Vector3(x, 0.6, 0), 0.101, 0.101, pants.darkened(0.15))
		else:
			_tube(mb, hip, knee, fit[0], fit[1], leg, sides)
		if bottoms == "cargo":
			mb.box(Vector3(side * 0.205, 0.68, 0.0), Vector3(0.03, 0.14, 0.12), pants.darkened(0.12))
		if bottoms == "joggers" and look.has("stripe"):
			_strip(mb, [Vector3(side * 0.212, 0.9, 0), Vector3(side * 0.193, 0.5, 0)], 0.014, look.stripe, Vector3(x, 0.7, 0), Vector3.ONE)

		mb.set_bone(bone_index(prefix + "LowerLeg"))
		var lower := skin if bottoms == "shorts" else leg
		_ball(mb, knee, Vector3(fit[1], 0.07, fit[1]) * 0.98, lower, 5, 3)
		_tube(mb, knee, ankle, fit[2], fit[3], lower, sides)
		match bottoms:
			"jeans":
				# Turn-ups showing the lighter inside of the denim.
				_tube(mb, Vector3(x, 0.165, 0), Vector3(x, 0.115, 0), 0.073, 0.074, pants.lightened(0.22))
			"joggers":
				_tube(mb, Vector3(x, 0.2, 0), Vector3(x, 0.24, 0), 0.07, 0.074, pants)
				_tube(mb, Vector3(x, 0.115, 0), Vector3(x, 0.2, 0), 0.062, 0.07, pants.darkened(0.2))
			"cargo":
				_tube(mb, Vector3(x, 0.13, 0), Vector3(x, 0.2, 0), 0.074, 0.076, pants.darkened(0.06))
		if socks.a > 0.0 and (bare or bottoms == "shorts"):
			_tube(mb, Vector3(x, 0.1, 0), Vector3(x, 0.2, 0), 0.058, 0.06, socks)

		mb.set_bone(bone_index(prefix + "Foot"))
		_shoe(mb, look, o, side)


## Shoes from rounded parts (0.24: were boxes): a sole with rounded corners,
## a toe box and a heel, toes forward (-z).
static func _shoe(mb, look: Dictionary, o: Dictionary, side: float) -> void:
	var x := side * 0.11
	var col: Color = look.get("shoes", Color(0.12, 0.1, 0.1))
	match o.shoe_style:
		"boots":
			mb.rounded_slab(Vector3(x, 0.018, -0.05), Vector3(0.13, 0.036, 0.31), Color(0.12, 0.1, 0.09))
			mb.smooth_ball(Vector3(x, 0.05, -0.1), Vector3(0.062, 0.05, 0.11), col, 8, 4)
			_tube(mb, Vector3(x, 0.035, 0.0), Vector3(x, 0.2, 0.0), 0.07, 0.068, col)
			_tube(mb, Vector3(x, 0.19, 0.0), Vector3(x, 0.215, 0.0), 0.073, 0.072, col.darkened(0.25))
			mb.smooth_ball(Vector3(x, 0.07, 0.03), Vector3(0.068, 0.06, 0.07), col, 8, 4)
		"slides":
			var socks: Color = look.get("socks", Color(0, 0, 0, 0))
			mb.rounded_slab(Vector3(x, 0.016, -0.05), Vector3(0.12, 0.032, 0.28), col.darkened(0.2))
			mb.smooth_ball(Vector3(x, 0.045, -0.05), Vector3(0.05, 0.035, 0.12), socks if socks.a > 0.0 else o.skin, 8, 4)
			mb.smooth_ball(Vector3(x, 0.06, -0.075), Vector3(0.062, 0.03, 0.05), col, 8, 3)
		"dress":
			mb.rounded_slab(Vector3(x, 0.011, -0.055), Vector3(0.11, 0.022, 0.29), col.darkened(0.5))
			mb.smooth_ball(Vector3(x, 0.035, -0.105), Vector3(0.052, 0.04, 0.1), col, 8, 4)
			mb.smooth_ball(Vector3(x, 0.05, 0.0), Vector3(0.054, 0.068, 0.09), col, 8, 4)
		"heels":
			mb.smooth_ball(Vector3(x, 0.05, -0.1), Vector3(0.045, 0.035, 0.09), col, 8, 4)
			mb.smooth_ball(Vector3(x, 0.095, 0.0), Vector3(0.048, 0.05, 0.06), col, 8, 4)
			_tube(mb, Vector3(x, 0.08, 0.035), Vector3(x, 0.0, 0.04), 0.014, 0.01, col.darkened(0.3), 6)
		_:
			# Sneakers: a thick sole, toe box and heel in the upper's colour,
			# laces, a side flash and a heel tab seen as people walk away.
			var sole: Color = look.get("sole", Color(0.95, 0.95, 0.93))
			var accent: Color = look.get("shoe_accent", col.darkened(0.25))
			mb.rounded_slab(Vector3(x, 0.022, -0.05), Vector3(0.126, 0.044, 0.3), sole, 0.97)
			mb.smooth_ball(Vector3(x, 0.045, -0.1), Vector3(0.058, 0.045, 0.1), col, 8, 4)
			mb.smooth_ball(Vector3(x, 0.05, 0.0), Vector3(0.058, 0.08, 0.1), col, 8, 4)
			mb.box(Vector3(x, 0.088, -0.085), Vector3(0.04, 0.008, 0.07), col.lightened(0.5) if col.v < 0.8 else col.darkened(0.12))
			mb.smooth_ball(Vector3(x + side * 0.05, 0.058, -0.04), Vector3(0.012, 0.02, 0.07), accent, 6, 3)
			mb.smooth_ball(Vector3(x, 0.1, 0.062), Vector3(0.024, 0.035, 0.02), accent, 6, 3)


static func _head(mb, look: Dictionary, o: Dictionary) -> void:
	var skin: Color = o.skin
	var style: String = look.get("hair", "short")
	var hair: Color = look.get("hair_color", HAIR[0])
	var hat: Color = look.get("hat", Color(0.1, 0.14, 0.3))
	var headwear: String = look.get("headwear", "")
	if style in ["cap", "beanie", "police"]:
		# Older looks name the hat as the hair style.
		if headwear == "":
			headwear = style
		style = "short"
	var c := Vector3(0, 1.69, 0)
	var fine: bool = look.get("hero", false)
	# Skull, longer front to back than across, running into a narrower jaw
	# as one loft (_head_rings), plus a soft chin. Two crossing balls left a
	# jagged seam over the cheeks (0.24 review).
	var keep: Transform3D = mb.xform
	mb.xform = keep * Transform3D(Basis.IDENTITY, c + Vector3(0, 0, 0.008))
	mb.loft(_head_rings(skin), 16 if fine else 12, 0.007)
	mb.xform = keep
	mb.smooth_ball(c + Vector3(0, -0.14, -0.082), Vector3(0.055, 0.04, 0.04), skin, 8 if fine else 6, 4)
	# Face (0.24: was box eyes, nose and mouth): eye whites with dark irises,
	# brows, a nose with a bridge and a rounded tip, upper and lower lip.
	var segs := 8 if fine else 6
	var iris: Color = look.get("eyes", Color(0.2, 0.13, 0.08))
	var mouth_z := -0.012 if look.get("beard", false) else 0.0
	for side in [-1.0, 1.0]:
		_ball(mb, c + Vector3(side * 0.165, -0.01, 0.01), Vector3(0.026, 0.05, 0.034), skin.darkened(0.08), 6, 3)
		mb.smooth_ball(c + Vector3(side * 0.062, 0.012, -0.148), Vector3(0.03, 0.019, 0.02), Color(0.93, 0.92, 0.89), segs, 4)
		mb.smooth_ball(c + Vector3(side * 0.062, 0.011, -0.162), Vector3(0.0135, 0.0145, 0.01), iris, segs, 3)
		mb.smooth_ball(c + Vector3(side * 0.064, 0.052, -0.158), Vector3(0.037, 0.009, 0.012), hair.darkened(0.3), segs, 3)
	mb.smooth_limb(c + Vector3(0, 0.025, -0.163), c + Vector3(0, -0.03, -0.186), 0.012, 0.016, skin.darkened(0.04), segs)
	mb.smooth_ball(c + Vector3(0, -0.035, -0.184), Vector3(0.022, 0.017, 0.016), skin.darkened(0.06), segs, 4)
	var lip := skin.lerp(Color(0.6, 0.28, 0.28), 0.3).darkened(0.1)
	mb.smooth_ball(c + Vector3(0, -0.092, -0.148 + mouth_z), Vector3(0.034, 0.009, 0.012), lip.darkened(0.12), segs, 3)
	mb.smooth_ball(c + Vector3(0, -0.106, -0.146 + mouth_z), Vector3(0.03, 0.011, 0.012), lip, segs, 3)
	if look.get("sunglasses", false):
		mb.box(c + Vector3(0, 0.02, -0.174), Vector3(0.25, 0.06, 0.02), Color(0.04, 0.04, 0.05))
	elif look.get("glasses", false):
		mb.box(c + Vector3(0, 0.02, -0.172), Vector3(0.24, 0.05, 0.02), Color(0.06, 0.06, 0.08))
		for side in [-1.0, 1.0]:
			mb.box(c + Vector3(side * 0.06, 0.02, -0.178), Vector3(0.07, 0.03, 0.01), Color(0.62, 0.68, 0.72))
	if look.get("sunglasses", false) or look.get("glasses", false):
		for side in [-1.0, 1.0]:
			mb.box(c + Vector3(side * 0.172, 0.025, -0.085), Vector3(0.01, 0.015, 0.17), Color(0.06, 0.06, 0.08))
	if look.get("beard", false):
		_ball(mb, c + Vector3(0, -0.11, -0.04), Vector3(0.14, 0.09, 0.13), hair, 6, 3)
	if headwear == "":
		_hair(mb, style, c, hair, skin)
	else:
		# Only hair that shows below a hat.
		if style in ["long", "ponytail", "locs", "bob"]:
			_hair(mb, style, c, hair, skin, true)
		_hat(mb, headwear, c, hat)
	if look.has("headband") and headwear == "":
		var r := 0.27 if style == "afro" else (0.215 if style in ["curly", "bob", "long"] else 0.205)
		_tube(mb, c + Vector3(0, 0.03, 0.015), c + Vector3(0, 0.085, 0.015), r, r * 0.985, look.headband, 8)
	if look.has("headphones"):
		var hp: Color = look.headphones
		var top := 0.27 if headwear in ["beanie", "helmet", "hardhat", "bucket", "bandana"] or style == "afro" else 0.235
		for side in [-1.0, 1.0]:
			mb.limb(c + Vector3(side * 0.165, 0.0, 0.0), c + Vector3(side * 0.215, 0.0, 0.0), 0.06, 0.058, hp, 6)
			var arc := []
			for k in 4:
				var t := k / 3.0 * PI * 0.5
				arc.append(c + Vector3(side * sin(PI * 0.5 - t) * 0.205, 0.04 + sin(t) * (top - 0.04), 0.0))
			_strip(mb, arc, 0.02, hp.darkened(0.2), c + Vector3(0, -0.05, 0), Vector3.ONE)


static func _hair(mb, style: String, c: Vector3, hair: Color, skin: Color, under_hat := false) -> void:
	match style:
		"short":
			_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 10, 5)
		"fade":
			_ball(mb, c + Vector3(0, 0.1, 0.015), Vector3(0.165, 0.12, 0.17), hair, 10, 5)
			_ball(mb, c + Vector3(0, 0.04, 0.015), Vector3(0.176, 0.14, 0.176), hair.lerp(skin, 0.5), 10, 5)
		"buzz":
			_ball(mb, c + Vector3(0, 0.05, 0.015), Vector3(0.175, 0.15, 0.175), hair.lerp(skin, 0.35), 10, 5)
		"curly":
			_ball(mb, c + Vector3(0, 0.08, 0.02), Vector3(0.19, 0.15, 0.19), hair, 10, 5)
			for k in 5:
				var a := TAU * k / 5.0 + 0.3
				_ball(mb, c + Vector3(cos(a) * 0.1, 0.19, 0.02 + sin(a) * 0.1), Vector3(0.07, 0.06, 0.07), hair.lightened(0.06), 5, 2)
		"long":
			if not under_hat:
				_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.185, 0.145, 0.185), hair, 10, 5)
			_ball(mb, c + Vector3(0, -0.1, 0.085), Vector3(0.175, 0.24, 0.09), hair, 10, 5)
		"bob":
			if not under_hat:
				_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.19, 0.145, 0.19), hair, 10, 5)
			_ball(mb, c + Vector3(0, -0.02, 0.06), Vector3(0.195, 0.13, 0.15), hair, 10, 5)
			for side in [-1.0, 1.0]:
				_ball(mb, c + Vector3(side * 0.165, -0.04, -0.035), Vector3(0.035, 0.11, 0.09), hair, 6, 3)
		"ponytail":
			if not under_hat:
				_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 10, 5)
			mb.limb(c + Vector3(0, 0.06, 0.17), c + Vector3(0, -0.22, 0.22), 0.05, 0.035, hair, 5)
		"bun":
			_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 10, 5)
			_ball(mb, c + Vector3(0, 0.2, 0.09), Vector3(0.08, 0.08, 0.08), hair, 6, 3)
		"afro":
			_ball(mb, c + Vector3(0, 0.1, 0.03), Vector3(0.25, 0.21, 0.24), hair, 10, 5)
		"locs":
			if not under_hat:
				_ball(mb, c + Vector3(0, 0.07, 0.02), Vector3(0.18, 0.14, 0.18), hair, 10, 5)
			for k in 5:
				var x := (k - 2) * 0.065
				_tube(mb, c + Vector3(x, 0.08, 0.13 - absf(x) * 0.3), c + Vector3(x * 1.35, -0.24, 0.19 - absf(x) * 0.4), 0.032, 0.026, hair.darkened(0.08 * (k % 2)), 4)


static func _hat(mb, headwear: String, c: Vector3, hat: Color) -> void:
	match headwear:
		"cap", "cap_back":
			var back := -1.0 if headwear == "cap_back" else 1.0
			_ball(mb, c + Vector3(0, 0.08, 0.02), Vector3(0.185, 0.135, 0.185), hat, 8, 3)
			mb.rounded_slab(c + Vector3(0, 0.075 if back > 0 else 0.07, -0.2 * back), Vector3(0.21, 0.018, 0.15), hat.darkened(0.25))
			mb.box(c + Vector3(0, 0.15, -0.155 * back), Vector3(0.07, 0.05, 0.01), hat.lightened(0.45) if hat.v < 0.6 else hat.darkened(0.45))
		"beanie":
			_ball(mb, c + Vector3(0, 0.08, 0.01), Vector3(0.19, 0.17, 0.19), hat, 8, 3)
			_tube(mb, c + Vector3(0, -0.005, 0.01), c + Vector3(0, 0.07, 0.01), 0.197, 0.192, hat.darkened(0.15), 8)
		"bucket":
			mb.limb(c + Vector3(0, 0.05, 0.01), c + Vector3(0, 0.2, 0.01), 0.185, 0.16, hat, 8)
			_tube(mb, c + Vector3(0, 0.07, 0.01), c + Vector3(0, 0.0, 0.01), 0.19, 0.28, hat.darkened(0.12), 8)
		"helmet":
			_ball(mb, c + Vector3(0, 0.08, 0.015), Vector3(0.205, 0.165, 0.22), hat, 8, 3)
			for side in [-1.0, 1.0]:
				_strip(mb, [c + Vector3(side * 0.07, 0.19, -0.15), c + Vector3(side * 0.07, 0.24, 0.0), c + Vector3(side * 0.07, 0.2, 0.15)], 0.017, Color(0.1, 0.1, 0.11), c + Vector3(0, 0.08, 0), Vector3.ONE)
			mb.box(c + Vector3(0, 0.1, -0.215), Vector3(0.2, 0.03, 0.04), hat.darkened(0.35))
		"hardhat":
			_ball(mb, c + Vector3(0, 0.1, 0.01), Vector3(0.19, 0.15, 0.2), hat, 8, 3)
			var brim := PackedVector2Array()
			for k in 8:
				var a := TAU * (k + 0.5) / 8.0
				brim.append(Vector2(cos(a) * 0.25, 0.01 + sin(a) * 0.27))
			mb.flat(brim, c.y + 0.07, hat.darkened(0.1))
			_strip(mb, [c + Vector3(0, 0.215, -0.16), c + Vector3(0, 0.258, 0.0), c + Vector3(0, 0.215, 0.17)], 0.022, hat.lightened(0.2), c + Vector3(0, 0.1, 0), Vector3.ONE)
		"bandana":
			# A do-rag knotted at the back: the colour reads from above.
			_ball(mb, c + Vector3(0, 0.085, 0.02), Vector3(0.184, 0.135, 0.186), hat, 8, 3)
			_tube(mb, c + Vector3(0, 0.075, 0.02), c + Vector3(0, 0.105, 0.02), 0.202, 0.2, hat.darkened(0.15), 8)
			_ball(mb, c + Vector3(0, 0.09, 0.22), Vector3(0.035, 0.03, 0.03), hat.darkened(0.1), 4, 2)
			for side in [-1.0, 1.0]:
				_strip(mb, [c + Vector3(side * 0.015, 0.08, 0.235), c + Vector3(side * 0.05, -0.04, 0.24)], 0.017, hat.darkened(0.1), c, Vector3.ONE)
		"police":
			mb.limb(c + Vector3(0, 0.08, 0), c + Vector3(0, 0.2, 0), 0.19, 0.21, hat, 8)
			mb.rounded_slab(c + Vector3(0, 0.09, -0.21), Vector3(0.26, 0.022, 0.12), hat.darkened(0.3))
			mb.box(c + Vector3(0, 0.15, -0.2), Vector3(0.06, 0.06, 0.02), Color(0.95, 0.8, 0.25))


# --- Shapes -------------------------------------------------------------------

## An open tube from a to b, with no end caps: sleeves, cuffs, collars and
## limbs whose ends hide inside joints.
## Smooth-shaded (0.24: flat facets read as "outdated and primitive").
static func _tube(mb, a: Vector3, b: Vector3, ra: float, rb: float, color: Color, sides := 8) -> void:
	mb.smooth_limb(a, b, ra, rb, color, sides)


## A smooth-shaded ellipsoid. `sides` and `rings` are the counts the kit was
## tuned with as flat facets; each gets one more step so the outline reads
## round as well as the shading.
static func _ball(mb, center: Vector3, radius: Vector3, color: Color, sides := 6, rings := 3) -> void:
	mb.smooth_ball(center, radius, color, sides + 2, rings + 1)


## A solid box with all five faces seen from above, however small (MeshBuilder
## draws boxes thinner than THIN as flat panels): shoes, pouches, holsters.
static func _block(mb, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	for n in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var u := Vector3(n.y, n.z, n.x) if n.y == 0.0 else Vector3.RIGHT
		var v: Vector3 = n.cross(u)
		var c: Vector3 = center + n * h
		u *= absf(u.dot(h))
		v *= absf(v.dot(h))
		mb.quad(c - u - v, c + u - v, c + u + v, c - u + v, n, color)


## A thin ring round the body at height y: hems, belts, reflective bands.
static func _band(mb, y: float, rx: float, rz: float, h: float, color: Color) -> void:
	_ball(mb, Vector3(0, y, 0), Vector3(rx, h, rz), color, 8, 2)


## A flat strip along `pts` (2 tris per segment), facing away from `center`
## measured on an ellipsoid of `radii`: straps, zips, seams, stripes.
static func _strip(mb, pts: Array, half_w: float, color: Color, center := TORSO_C, radii := TORSO_R) -> void:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n := (((a + b) * 0.5 - center) / (radii * radii)).normalized()
		var s := (b - a).cross(n).normalized() * half_w
		mb.quad(a - s, b - s, b + s, a + s, n, color)


## A patch on the front (side -1) or back (+1) of the torso hugging its
## surface: centred on x, from y0 down to y1, half widths hw0 and hw1, in
## `rows` x `cols` quads.
static func _panel(mb, x: float, y0: float, y1: float, hw0: float, hw1: float, side: float, color: Color, w: float, bulk: float,
		rows := 1, lift := 0.012, cols := 1) -> void:
	# At least a row every 5 cm, so long panels follow the torso's curve.
	rows = maxi(rows, ceili(absf(y0 - y1) / 0.05))
	for r in rows:
		var ya := lerpf(y0, y1, float(r) / rows)
		var yb := lerpf(y0, y1, float(r + 1) / rows)
		var ha := lerpf(hw0, hw1, float(r) / rows)
		var hb := lerpf(hw0, hw1, float(r + 1) / rows)
		for k in cols:
			var u0 := lerpf(-1.0, 1.0, float(k) / cols)
			var u1 := lerpf(-1.0, 1.0, float(k + 1) / cols)
			var p := [_surf(x + ha * u0, ya, side, w, bulk, lift), _surf(x + ha * u1, ya, side, w, bulk, lift),
				_surf(x + hb * u1, yb, side, w, bulk, lift), _surf(x + hb * u0, yb, side, w, bulk, lift)]
			var mid: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
			mb.quad(p[0], p[1], p[2], p[3], ((mid - TORSO_C) / (TORSO_R * TORSO_R)).normalized(), color)


## A jersey number in seven-segment digits on the torso surface, centred at
## (x, y), each digit `dw` wide and `dh` tall.
static func _number(mb, number: int, x: float, y: float, dw: float, dh: float, side: float, color: Color, w: float, bulk: float) -> void:
	var text := str(clampi(number, 0, 99))
	var gap := dw * 1.5
	for i in text.length():
		# Read from where it is seen: left to right is +x on the back, -x on the front.
		var cx := x + (i - (text.length() - 1) * 0.5) * gap * side
		var l := cx - dw * 0.5 * side
		var r := cx + dw * 0.5 * side
		var t := y + dh * 0.5
		var b := y - dh * 0.5
		var segs := {"a": [l, t, r, t], "b": [r, t, r, y], "c": [r, y, r, b], "d": [l, b, r, b], "e": [l, y, l, b], "f": [l, t, l, y], "g": [l, y, r, y]}
		for s in DIGITS[int(text[i])]:
			var q: Array = segs[s]
			_strip(mb, [_surf(q[0], q[1], side, w, bulk, 0.018), _surf(q[2], q[3], side, w, bulk, 0.018)], dw * 0.14, color)


## The point on the front (side -1) or back (+1) of the torso at (x, y),
## lifted `lift` off the cloth.
static func _surf(x: float, y: float, side: float, w: float, bulk: float, lift := 0.012) -> Vector3:
	var g := _profile(y, w, bulk)
	var d := g.y * sqrt(maxf(0.0, 1.0 - pow(x / g.x, 2.0)))
	return Vector3(x, y, side * (d + lift))


## A strip along the torso surface through `pts` (x, y), re-sampled every
## 4 cm so it follows the curve instead of cutting under it as chords.
static func _surf_strip(mb, pts: Array, side: float, lift: float, w: float, bulk: float, half_w: float, color: Color) -> void:
	var path := [_surf(pts[0].x, pts[0].y, side, w, bulk, lift)]
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := maxi(1, ceili(a.distance_to(b) / 0.04))
		for k in range(1, n + 1):
			var q := a.lerp(b, float(k) / n)
			path.append(_surf(q.x, q.y, side, w, bulk, lift))
	_strip(mb, path, half_w, color)


## The head's loft rings, chin to crown, about an axis 8 mm behind the head
## centre: the skull ellipsoid (0.162 x 0.18 x 0.178, centred 0.015 up) and
## the jaw ellipsoid (0.12 x 0.105 x 0.125, centred 0.075 down and 0.022
## forward of the axis) joined by a smooth max, so the face has no seam.
static func _head_rings(skin: Color) -> Array:
	var rings := []
	for y in [-0.18, -0.16, -0.13, -0.095, -0.06, -0.025, 0.015, 0.065, 0.115, 0.16, 0.188]:
		var fs := sqrt(maxf(0.0, 1.0 - pow((y - 0.015) / 0.18, 2.0)))
		var fj := sqrt(maxf(0.0, 1.0 - pow((y + 0.075) / 0.105, 2.0)))
		var rx := _smax(0.162 * fs, 0.12 * fj, 0.015)
		var rz := _smax(0.178 * fs, 0.125 * fj + 0.022 * signf(fj), 0.015)
		rings.append([y, maxf(rx, 0.004), maxf(rz, 0.004), skin])
	return rings


## Half width and half depth of the lofted torso at height y (0.24): the
## chest and waist ellipsoids joined by a smooth max, the waist eased below
## its middle so it tucks into the hips instead of closing.
static func _profile(y: float, w: float, bulk: float) -> Vector2:
	var t := clampf((y - 1.3) / 0.2, -1.0, 1.0)
	var chest := Vector2(0.25 * w, 0.15) * bulk * sqrt(1.0 - t * t)
	var u := (y - 1.12) / 0.14
	var waist := Vector2(0.19 * w, 0.13) * bulk * sqrt(maxf(0.0, 1.0 - (u * u if u > 0.0 else 0.5 * u * u)))
	return Vector2(_smax(chest.x, waist.x), _smax(chest.y, waist.y))


static func _smax(a: float, b: float, k := 0.02) -> float:
	return 0.5 * (a + b + sqrt((a - b) * (a - b) + k * k))


## Half width and half depth of the torso at height y.
static func _girth(y: float, w: float, bulk: float) -> Vector2:
	var g := Vector2.ZERO
	for e in [[1.3, 0.25, 0.2, 0.15], [1.12, 0.19, 0.14, 0.13]]:
		var k: float = 1.0 - pow((y - e[0]) / e[2], 2.0)
		if k > 0.0:
			g = Vector2(maxf(g.x, e[1] * w * bulk * sqrt(k)), maxf(g.y, e[3] * bulk * sqrt(k)))
	return g


## Height of the top of the shoulders at x (where straps cross them).
static func _shoulder_top(x: float, w: float, bulk: float) -> float:
	return 1.3 + 0.2 * sqrt(maxf(0.0, 1.0 - pow(x / (0.25 * w * bulk), 2.0))) + 0.02
