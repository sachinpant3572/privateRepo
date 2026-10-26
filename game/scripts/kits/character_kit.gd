extends RefCounted
## Cartoon people, built at the feet (y = 0), facing -Z. Proportions are a
## little chunky (big head, broad shoulders) so people read from above.

const SKIN := [Color(0.98, 0.82, 0.68), Color(0.85, 0.64, 0.45), Color(0.6, 0.42, 0.28), Color(0.38, 0.25, 0.17)]
const HAIR := [Color(0.08, 0.06, 0.05), Color(0.3, 0.18, 0.1), Color(0.6, 0.4, 0.2), Color(0.85, 0.7, 0.4), Color(0.55, 0.55, 0.55), Color(0.7, 0.2, 0.15)]
const STYLES := ["short", "short", "long", "bun", "afro", "bald", "cap"]
const SHIRTS := [Color(0.95, 0.85, 0.3), Color(0.3, 0.6, 0.85), Color(0.9, 0.5, 0.2), Color(0.55, 0.8, 0.45), Color(0.95, 0.95, 0.95), Color(0.6, 0.35, 0.65), Color(0.85, 0.3, 0.35), Color(0.25, 0.65, 0.6)]
const PANTS := [Color(0.15, 0.15, 0.2), Color(0.35, 0.3, 0.25), Color(0.2, 0.3, 0.5), Color(0.8, 0.75, 0.65), Color(0.3, 0.32, 0.3)]


## A random civilian look.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()],
		"pants": PANTS[rng.randi() % PANTS.size()],
		"skin": SKIN[rng.randi() % SKIN.size()],
		"hair": STYLES[rng.randi() % STYLES.size()],
		"hair_color": HAIR[rng.randi() % HAIR.size()],
		"hat": Color(0.2, 0.25, 0.5).lerp(SHIRTS[rng.randi() % SHIRTS.size()], 0.5),
	}


## look keys: shirt, pants, skin, hair (style name), hair_color, hat (colour,
## used by the "cap" style and by uniforms).
static func build(mb, look: Dictionary) -> void:
	var shirt: Color = look.get("shirt", Color.GRAY)
	var pants: Color = look.get("pants", Color(0.2, 0.22, 0.3))
	var skin: Color = look.get("skin", SKIN[0])
	var style: String = look.get("hair", "short")
	var hair: Color = look.get("hair_color", HAIR[0])
	var hat: Color = look.get("hat", Color(0.1, 0.14, 0.3))
	# Legs and shoes.
	for x in [-0.14, 0.14]:
		mb.box(Vector3(x, 0.42, 0), Vector3(0.2, 0.78, 0.24), pants)
		mb.box(Vector3(x, 0.06, -0.04), Vector3(0.22, 0.12, 0.32), Color(0.12, 0.1, 0.1))
	# Torso and arms.
	mb.box(Vector3(0, 1.12, 0), Vector3(0.6, 0.66, 0.34), shirt)
	for x in [-0.38, 0.38]:
		mb.box(Vector3(x, 1.08, 0), Vector3(0.15, 0.58, 0.18), shirt.darkened(0.08))
		mb.box(Vector3(x, 0.74, 0), Vector3(0.13, 0.14, 0.15), skin)
	# Head, a little oversized for readability.
	mb.ball(Vector3(0, 1.72, 0), Vector3(0.25, 0.25, 0.25), skin, 7, 4)
	mb.box(Vector3(0, 1.7, -0.24), Vector3(0.08, 0.08, 0.06), skin.darkened(0.25))
	match style:
		"short":
			mb.ball(Vector3(0, 1.84, 0.03), Vector3(0.26, 0.15, 0.25), hair, 7, 2)
		"long":
			mb.ball(Vector3(0, 1.84, 0.03), Vector3(0.27, 0.16, 0.26), hair, 7, 2)
			mb.box(Vector3(0, 1.55, 0.16), Vector3(0.46, 0.5, 0.14), hair)
		"bun":
			mb.ball(Vector3(0, 1.84, 0.03), Vector3(0.26, 0.15, 0.25), hair, 7, 2)
			mb.ball(Vector3(0, 2.0, 0.12), Vector3(0.12, 0.12, 0.12), hair, 5, 2)
		"afro":
			mb.ball(Vector3(0, 1.9, 0.02), Vector3(0.36, 0.28, 0.34), hair, 7, 3)
		"cap":
			mb.ball(Vector3(0, 1.84, 0.03), Vector3(0.26, 0.15, 0.25), hat, 7, 2)
			mb.box(Vector3(0, 1.85, -0.24), Vector3(0.36, 0.05, 0.22), hat.darkened(0.2))
		"police":
			mb.box(Vector3(0, 1.95, 0), Vector3(0.5, 0.14, 0.5), hat)
			mb.box(Vector3(0, 1.9, -0.28), Vector3(0.42, 0.04, 0.16), hat.darkened(0.3))
			mb.box(Vector3(0, 1.97, -0.25), Vector3(0.1, 0.08, 0.02), Color(0.95, 0.8, 0.25))
		_:
			pass
