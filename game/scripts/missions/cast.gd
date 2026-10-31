extends RefCounted
## Looks for the act 1 cast and extras (see WORLD_BIBLE.md and
## ACT1_MISSIONS.md), in CharacterKit's look format.

## Nia: olive jacket open over a mustard tee, black joggers, white sneakers,
## a black crossbody bag.
const NIA := {
	"outfit": "jacket", "jacket": Color(0.3, 0.36, 0.22), "shirt": Color(0.95, 0.8, 0.3),
	"bottoms": "joggers", "pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.95, 0.95, 0.95),
	"skin": Color(0.38, 0.25, 0.17), "hair": "ponytail", "hair_color": Color(0.08, 0.06, 0.05), "build": 0.95,
	"body": "female", "age": -0.5, "muscle": 0.2,
	"bag": "crossbody", "bag_color": Color(0.1, 0.1, 0.11),
}
## Celeste: red midi dress with a gold belt and necklace, red heels.
const CELESTE := {
	"outfit": "dress", "shirt": Color(0.62, 0.08, 0.16), "shoes": Color(0.75, 0.12, 0.15), "shoe_style": "heels",
	"belt": Color(0.85, 0.68, 0.3), "necklace": Color(0.9, 0.75, 0.35), "skin": Color(0.6, 0.42, 0.28),
	"hair": "bun", "hair_color": Color(0.6, 0.6, 0.6), "build": 0.95,
	"body": "female", "age": 0.5, "stature": 0.15,
}
const MARCEL := {
	"outfit": "suit", "jacket": Color(0.3, 0.2, 0.4), "shirt": Color(0.95, 0.95, 0.93), "tie": Color(0.9, 0.72, 0.25),
	"accent": Color(0.9, 0.72, 0.25), "pants": Color(0.3, 0.2, 0.4), "shoes": Color(0.12, 0.1, 0.1), "skin": Color(0.38, 0.25, 0.17),
	"hair": "short", "hair_color": Color(0.55, 0.55, 0.55), "beard": true, "build": 1.1,
	"age": 0.45, "weight": 0.3,
}
const REYES := {
	"outfit": "uniform", "duty_vest": false, "shirt": Color(0.9, 0.9, 0.92), "pants": Color(0.1, 0.12, 0.22),
	"shoes": Color(0.08, 0.08, 0.09), "skin": Color(0.85, 0.64, 0.45), "hair": "bun", "hair_color": Color(0.08, 0.06, 0.05),
	"build": 1.0, "body": "female", "muscle": 0.4,
}
const REMY := {
	"outfit": "tee", "shirt": Color(0.95, 0.95, 0.95), "bottoms": "jeans", "pants": Color(0.2, 0.3, 0.5),
	"shoes": Color(0.12, 0.12, 0.14), "bag": "backpack", "bag_color": Color(0.16, 0.22, 0.36),
	"skin": Color(0.6, 0.42, 0.28), "hair": "buzz", "hair_color": Color(0.08, 0.06, 0.05),
	"stature": -0.2, "age": -0.8, "weight": -0.4,
}
const THIEF := {
	"outfit": "hoodie", "jacket": Color(0.2, 0.6, 0.35), "shirt": Color(0.9, 0.9, 0.9),
	"bottoms": "joggers", "pants": Color(0.3, 0.3, 0.32), "shoes": Color(0.8, 0.2, 0.2), "skin": Color(0.85, 0.64, 0.45),
	"hair": "short", "headwear": "cap", "hat": Color(0.8, 0.2, 0.2),
	"stature": -0.3, "weight": -0.6, "age": -0.6,
}
## The thief's crew: green and black, bandanas and tank tops.
const CREW := [
	{"outfit": "tank", "shirt": Color(0.2, 0.55, 0.3), "bottoms": "cargo", "pants": Color(0.12, 0.12, 0.14),
		"shoes": Color(0.1, 0.1, 0.11), "skin": Color(0.38, 0.25, 0.17), "necklace": Color(0.8, 0.8, 0.82),
		"hair": "short", "headwear": "beanie", "hat": Color(0.2, 0.55, 0.3), "build": 1.15,
		"muscle": 0.7},
	{"outfit": "hoodie", "jacket": Color(0.12, 0.12, 0.14), "shirt": Color(0.2, 0.55, 0.3), "print": Color(0.2, 0.55, 0.3),
		"back_print": true, "bottoms": "jeans", "pants": Color(0.2, 0.3, 0.5), "skin": Color(0.98, 0.82, 0.68),
		"hair": "buzz", "hair_color": Color(0.3, 0.18, 0.1), "build": 1.05,
		"weight": 0.4},
]
## Aurum security: black suits, gold ties, sunglasses.
const AURUM := {
	"outfit": "suit", "jacket": Color(0.08, 0.08, 0.1), "shirt": Color(0.95, 0.95, 0.93), "tie": Color(0.9, 0.72, 0.25),
	"accent": Color(0.9, 0.72, 0.25), "pants": Color(0.08, 0.08, 0.1), "skin": Color(0.85, 0.64, 0.45), "hair": "buzz",
	"hair_color": Color(0.08, 0.06, 0.05), "sunglasses": true, "build": 1.15,
	"muscle": 0.8, "stature": 0.3,
}
