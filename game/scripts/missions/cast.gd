extends RefCounted
## Looks for the act 1 cast and extras (see WORLD_BIBLE.md and
## ACT1_MISSIONS.md), in CharacterKit's look format.

const NIA := {
	"outfit": "jacket", "jacket": Color(0.3, 0.36, 0.22), "shirt": Color(0.95, 0.8, 0.3),
	"pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.95, 0.95, 0.95), "skin": Color(0.38, 0.25, 0.17),
	"hair": "ponytail", "hair_color": Color(0.08, 0.06, 0.05), "build": 0.95,
}
const CELESTE := {
	"outfit": "dress", "shirt": Color(0.62, 0.08, 0.16), "shoes": Color(0.75, 0.12, 0.15),
	"skin": Color(0.6, 0.42, 0.28), "hair": "bun", "hair_color": Color(0.6, 0.6, 0.6), "build": 0.95,
}
const MARCEL := {
	"outfit": "suit", "jacket": Color(0.3, 0.2, 0.4), "shirt": Color(0.95, 0.95, 0.93), "tie": Color(0.9, 0.72, 0.25),
	"pants": Color(0.3, 0.2, 0.4), "shoes": Color(0.12, 0.1, 0.1), "skin": Color(0.38, 0.25, 0.17),
	"hair": "short", "hair_color": Color(0.55, 0.55, 0.55), "beard": true, "build": 1.1,
}
const REYES := {
	"outfit": "uniform", "shirt": Color(0.9, 0.9, 0.92), "pants": Color(0.1, 0.12, 0.22),
	"skin": Color(0.85, 0.64, 0.45), "hair": "bun", "hair_color": Color(0.08, 0.06, 0.05), "build": 1.0,
}
const REMY := {
	"outfit": "tee", "shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.2, 0.3, 0.5),
	"skin": Color(0.6, 0.42, 0.28), "hair": "buzz", "hair_color": Color(0.08, 0.06, 0.05), "height": 0.94,
}
const THIEF := {
	"outfit": "hoodie", "jacket": Color(0.2, 0.6, 0.35), "shirt": Color(0.9, 0.9, 0.9),
	"pants": Color(0.3, 0.3, 0.32), "shoes": Color(0.8, 0.2, 0.2), "skin": Color(0.85, 0.64, 0.45),
	"hair": "cap", "hat": Color(0.8, 0.2, 0.2), "height": 0.92,
}
## The thief's crew: green and black, bandanas and tank tops.
const CREW := [
	{"outfit": "tank", "shirt": Color(0.2, 0.55, 0.3), "pants": Color(0.12, 0.12, 0.14), "skin": Color(0.38, 0.25, 0.17),
		"hair": "beanie", "hat": Color(0.2, 0.55, 0.3), "build": 1.15},
	{"outfit": "hoodie", "jacket": Color(0.12, 0.12, 0.14), "shirt": Color(0.2, 0.55, 0.3), "pants": Color(0.2, 0.3, 0.5),
		"skin": Color(0.98, 0.82, 0.68), "hair": "buzz", "hair_color": Color(0.3, 0.18, 0.1), "build": 1.05},
]
## Aurum security: black suits, gold ties, sunglasses.
const AURUM := {
	"outfit": "suit", "jacket": Color(0.08, 0.08, 0.1), "shirt": Color(0.95, 0.95, 0.93), "tie": Color(0.9, 0.72, 0.25),
	"pants": Color(0.08, 0.08, 0.1), "skin": Color(0.85, 0.64, 0.45), "hair": "buzz",
	"hair_color": Color(0.08, 0.06, 0.05), "glasses": true, "build": 1.15,
}
