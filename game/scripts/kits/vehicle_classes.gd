## Vehicle classes: how a family of vehicles rides, crumples and throws its
## rider (Sachin, 0.23: "the physics same for all vehicle in specified
## varieties"). The class owns the ride and the damage; the kind (VehicleKit)
## keeps its engine, grip and mass, so a hatchback and an EV share a
## suspension but not a top speed.
##
## hz, zeta: spring frequency (Hz) and damping ratio of the body on its
##   suspension, per axis (roll, pitch, heave); below zeta 1 it overshoots.
## roll_max, pitch_max: how far the body leans on its springs (radians).
## crumple: dent depth (m) per m/s of impact; dent_cap: deepest dent (m).
## damage: multiplier on the damage the car takes.
## throw: speed (m/s) of a crash that throws the rider off (0: none).
## kick: how hard impacts and bumps bounce the body.

const CLASSES := {
	"hatchback": {"hz": 1.5, "zeta": 0.32, "roll_max": 0.07, "pitch_max": 0.06, "crumple": 0.03, "dent_cap": 0.35, "damage": 1.2, "throw": 0.0, "kick": 1.2},
	"sedan": {"hz": 1.3, "zeta": 0.35, "roll_max": 0.09, "pitch_max": 0.06, "crumple": 0.025, "dent_cap": 0.3, "damage": 1.0, "throw": 0.0, "kick": 1.0},
	"suv": {"hz": 1.1, "zeta": 0.3, "roll_max": 0.12, "pitch_max": 0.07, "crumple": 0.02, "dent_cap": 0.3, "damage": 0.85, "throw": 0.0, "kick": 1.0},
	"muv": {"hz": 1.1, "zeta": 0.33, "roll_max": 0.11, "pitch_max": 0.07, "crumple": 0.022, "dent_cap": 0.3, "damage": 0.95, "throw": 0.0, "kick": 1.0},
	"truck": {"hz": 1.2, "zeta": 0.5, "roll_max": 0.06, "pitch_max": 0.04, "crumple": 0.008, "dent_cap": 0.15, "damage": 0.5, "throw": 0.0, "kick": 0.5},
	"performance": {"hz": 2.0, "zeta": 0.55, "roll_max": 0.035, "pitch_max": 0.035, "crumple": 0.028, "dent_cap": 0.3, "damage": 1.1, "throw": 0.0, "kick": 0.7},
	"three_wheeler": {"hz": 1.8, "zeta": 0.3, "roll_max": 0.14, "pitch_max": 0.07, "crumple": 0.04, "dent_cap": 0.4, "damage": 1.4, "throw": 0.0, "kick": 1.4},
	"two_wheeler": {"hz": 2.2, "zeta": 0.5, "roll_max": 0.0, "pitch_max": 0.05, "crumple": 0.0, "dent_cap": 0.0, "damage": 1.3, "throw": 7.0, "kick": 0.8},
	"cycle": {"hz": 2.5, "zeta": 0.6, "roll_max": 0.0, "pitch_max": 0.04, "crumple": 0.0, "dent_cap": 0.0, "damage": 1.5, "throw": 5.0, "kick": 0.8},
	# Reserved for water and air (not in the game yet): the shape of their
	# physics is set here so they slot in. Boats pitch and roll on waves,
	# big ships barely; aircraft bank instead of rolling on springs.
	"boat": {"hz": 0.6, "zeta": 0.2, "roll_max": 0.15, "pitch_max": 0.12, "crumple": 0.015, "dent_cap": 0.25, "damage": 0.9, "throw": 0.0, "kick": 1.0},
	"ship": {"hz": 0.15, "zeta": 0.3, "roll_max": 0.05, "pitch_max": 0.03, "crumple": 0.004, "dent_cap": 0.4, "damage": 0.2, "throw": 0.0, "kick": 0.2},
	"plane": {"hz": 1.0, "zeta": 0.7, "roll_max": 1.2, "pitch_max": 0.4, "crumple": 0.02, "dent_cap": 0.3, "damage": 1.2, "throw": 0.0, "kick": 0.5},
	"heli": {"hz": 1.2, "zeta": 0.6, "roll_max": 0.5, "pitch_max": 0.35, "crumple": 0.025, "dent_cap": 0.3, "damage": 1.3, "throw": 0.0, "kick": 0.6},
	"airship": {"hz": 0.2, "zeta": 0.4, "roll_max": 0.08, "pitch_max": 0.1, "crumple": 0.01, "dent_cap": 0.5, "damage": 0.6, "throw": 0.0, "kick": 0.3},
}

## Each kind's class. Kinds not listed ride as sedans.
const OF_KIND := {
	"compact": "hatchback", "ev": "hatchback",
	"sedan": "sedan", "taxi": "sedan", "police": "sedan",
	"suv": "suv", "crossover": "suv", "pickup": "suv",
	"van": "muv", "muv": "muv",
	"box_truck": "truck", "tipper": "truck", "semi": "truck",
	"sports": "performance", "muscle": "performance", "super": "performance", "luxury": "performance",
	"roadster": "performance", "cabriolet": "performance",
	"tuk_tuk": "three_wheeler", "cargo_trike": "three_wheeler",
	"motorbike": "two_wheeler", "scooter": "two_wheeler",
	"bicycle": "cycle",
}


static func class_of(kind: String) -> String:
	return OF_KIND.get(kind, "sedan")


## The class row of `kind`, with its name under "class".
static func of(kind: String) -> Dictionary:
	var name := class_of(kind)
	var row: Dictionary = CLASSES[name].duplicate()
	row["class"] = name
	return row
