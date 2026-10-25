extends RefCounted
## World 1 tables: enemies, weapons, powers, evolutions, card rarities and the
## wave plan. All numbers are first guesses for tuning (docs/game-design.md).

# Enemy types. The first four match their cells in the unit atlas (art.gd).
enum { TROOPER, SHIELD, GRENADIER, ELITE, TANK, HELI }

const ENEMY_NAMES := ["Trooper", "Shield Trooper", "Grenadier", "Juggernaut", "Battle Tank", "Attack Helicopter"]
const ENEMY_HP := [10.0, 24.0, 14.0, 700.0, 170.0, 70.0]
const ENEMY_SPEED := [72.0, 56.0, 62.0, 52.0, 34.0, 125.0]
const ENEMY_RADIUS := [14.0, 16.0, 14.0, 28.0, 30.0, 26.0]
const ENEMY_SIZE := [42.0, 46.0, 42.0, 76.0, 84.0, 76.0]  # On-screen size of the sprite.
const ENEMY_XP := [1, 2, 2, 30, 10, 6]
const ENEMY_TOUCH := [6.0, 8.0, 6.0, 22.0, 18.0, 10.0]  # Contact damage.
const ENEMY_FIRE := [2.6, 0.0, 3.6, 3.0, 4.2, 3.2]  # Seconds between attacks; 0 = none.
const ENEMY_RANGE := [460.0, 0.0, 420.0, 420.0, 640.0, 520.0]
const ENEMY_CAP := [0, 0, 0, 4, 8, 6]  # Most alive at once; 0 = no limit.

const WEAPON_IDS := ["rifle", "scatter", "rockets", "halo", "tesla", "airstrike"]
const POWER_IDS := ["overclock", "titan", "magnet", "adrenaline", "explosive", "crit"]

const NAMES := {
	"rifle": "Pulse Rifle",
	"scatter": "Scatter Cannon",
	"rockets": "Rocket Swarm",
	"halo": "Razor Halo",
	"tesla": "Tesla Coil",
	"airstrike": "Airstrike Beacon",
	"overclock": "Overclock",
	"titan": "Titan Skin",
	"magnet": "Magnet Field",
	"adrenaline": "Adrenaline",
	"explosive": "Explosive Rounds",
	"crit": "Critical Targeting",
}

const DESCS := {
	"rifle": "Fires at the nearest enemy. More shots and damage each level; pierces from level 6.",
	"scatter": "Close-range spread of pellets. More pellets, wider and stronger each level.",
	"rockets": "Homing missiles that explode. More missiles and bigger blasts each level.",
	"halo": "Blades orbit you and shred anything they touch. More blades, wider and faster.",
	"tesla": "Lightning jumps between enemies. One more jump and more damage each level.",
	"airstrike": "Calls bombing runs across the battlefield. More bombs, more often.",
	"overclock": "+8% fire rate for every weapon, per level.",
	"titan": "+20 max HP and +1 armor per level.",
	"magnet": "+30% pickup range per level. Pulls in all XP at level 8.",
	"adrenaline": "+7% move speed per level.",
	"explosive": "Kills explode, damaging enemies nearby. Bigger blasts each level.",
	"crit": "+5% crit chance and +10% crit damage per level.",
}

# Two items that both reach SYNERGY_LEVEL unlock a new behavior. With 4 of 6
# slots per kind, which synergies a run can reach depends on the build.
const SYNERGY_LEVEL := 4
const SYNERGIES := {
	"arc": {"a": "rifle", "b": "tesla", "name": "Arc Rounds", "desc": "Pulse Rifle hits can fork lightning."},
	"frag": {"a": "scatter", "b": "explosive", "name": "Frag Shells", "desc": "Scatter pellets burst on impact."},
	"gravity": {"a": "rockets", "b": "magnet", "name": "Gravity Warheads", "desc": "Rocket blasts drag enemies into the crater."},
	"bulwark": {"a": "halo", "b": "titan", "name": "Bulwark", "desc": "Razor blades shred enemy bullets."},
	"precision": {"a": "airstrike", "b": "crit", "name": "Precision Payload", "desc": "Every bomb crits, with a wider blast."},
	"static": {"a": "tesla", "b": "adrenaline", "name": "Static Dash", "desc": "Running charges a lightning nova."},
}

# After level 8 an item keeps coming back as a Limit Break, with no cap.
const LIMIT_WEAPON_DESC := "+12% damage and +4% fire rate per stack. Every 4th stack adds a projectile."
const LIMIT_DESCS := {
	"halo": "+12% damage per stack. Every 4th stack adds a blade.",
	"overclock": "+3% fire rate for every weapon.",
	"titan": "+10 max HP, and +1 armor every 2nd stack.",
	"magnet": "+10% pickup range.",
	"adrenaline": "+2% move speed (up to 15 stacks).",
	"explosive": "Bigger, stronger kill explosions every 2nd stack.",
	"crit": "+2% crit chance and +10% crit damage.",
}

# Weapon at level 8 + its paired power = evolution (at the next Power Chest).
const EVOLUTIONS := {
	"rifle": {"power": "overclock", "name": "Storm Rifle", "desc": "A constant stream that pierces everything."},
	"rockets": {"power": "crit", "name": "Hellfire Barrage", "desc": "Twice the missiles, and every one crits."},
	"halo": {"power": "adrenaline", "name": "Buzzsaw Halo", "desc": "Three more blades that spin faster the faster you move."},
	"airstrike": {"power": "explosive", "name": "Carpet Bomber", "desc": "Near-constant bombing runs."},
}

const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.75, 0.78, 0.82), Color(0.3, 0.6, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.72, 0.2)]
const RARITY_LEVELS := [1, 1, 2, 3]
const RARE_BONUS := 0.04  # Rare cards also give +4% damage to everything.

# Screen-clear pickups.
enum { NUKE, FREEZE, VACUUM, MEDKIT }
const PICKUP_LABELS := ["NUKE!", "FREEZE!", "VACUUM!", "MEDKIT"]

# Kill-combo milestones: count, banner, gold reward.
const COMBO_MILESTONES := [
	[50, "KILLING SPREE", 10],
	[100, "RAMPAGE", 20],
	[250, "MASSACRE", 50],
	[500, "UNSTOPPABLE", 100],
	[1000, "GODLIKE", 200],
	[2000, "APOCALYPSE", 400],
]

# Timed events: time, banner, enemy type, count, formation.
const EVENTS := [
	[90.0, "AMBUSH!", TROOPER, 30, "ring"],
	[150.0, "SHIELD WALL!", SHIELD, 24, "line"],
	[195.0, "TANK COLUMN!", TANK, 5, "line"],
	[270.0, "AIR RAID!", HELI, 6, "ring"],
]

# Treasure chests give 1, 3 or 5 rewards.
const CHEST_SIZES := [1, 3, 5]
const CHEST_ODDS := [70.0, 25.0, 5.0]


## Card rarity odds shift from mostly Common toward Epic and Legendary.
static func rarity_weights(t: float) -> PackedFloat32Array:
	var k := clampf(t / 240.0, 0.0, 1.0)
	return PackedFloat32Array([lerpf(80.0, 40.0, k), lerpf(18.0, 40.0, k), lerpf(2.0, 17.0, k), lerpf(0.0, 3.0, k)])


## Spawn weights per enemy type over the stage. Elites come from timed events.
static func spawn_weights(t: float) -> PackedFloat32Array:
	if t < 60.0:
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if t < 120.0:
		return PackedFloat32Array([0.6, 0.2, 0.2, 0.0, 0.0, 0.0])
	if t < 210.0:
		return PackedFloat32Array([0.5, 0.15, 0.15, 0.0, 0.1, 0.1])
	return PackedFloat32Array([0.4, 0.15, 0.15, 0.0, 0.15, 0.15])


## Limit Break stacks on top of a weapon's level-8 (or evolved) stats.
static func limit_break(st: Dictionary, n: int) -> void:
	if n <= 0:
		return
	st["dmg"] = float(st["dmg"]) * (1.0 + 0.12 * n)
	if st.has("cd"):
		st["cd"] = maxf(0.06, float(st["cd"]) / (1.0 + 0.04 * n))
	var extra := int(n / 4.0)
	for key in ["count", "chains", "bombs"]:
		if st.has(key):
			st[key] = int(st[key]) + extra


static func weapon_stats(id: String, l: int, evolved: bool) -> Dictionary:
	match id:
		"rifle":
			if evolved:
				return {"cd": 0.09, "count": 2, "dmg": 16.0, "pierce": 99, "speed": 820.0, "spread": 0.05, "life": 1.1}
			return {"cd": 0.55 - 0.03 * l, "count": 1 + int((l - 1) / 2.0), "dmg": 9.0 + 3.0 * l, "pierce": 2 if l >= 6 else 0, "speed": 760.0, "spread": 0.1, "life": 1.1}
		"scatter":
			return {"cd": 1.15 - 0.05 * l, "count": 5 + l, "dmg": 6.0 + 2.0 * l, "pierce": 1 if l >= 5 else 0, "speed": 620.0, "spread": deg_to_rad(40.0 + 4.0 * l), "life": 0.42}
		"rockets":
			var r := {"cd": 1.7 - 0.08 * l, "count": 2 + int(l / 2.0), "dmg": 14.0 + 5.0 * l, "radius": 42.0 + 6.0 * l, "crit": false}
			if evolved:
				r["count"] = int(r["count"]) * 2
				r["cd"] = 0.9
				r["crit"] = true
			return r
		"halo":
			var h := {"count": 2 + int(l / 2.0), "radius": 70.0 + 7.0 * l, "speed": 3.0 + 0.25 * l, "dmg": 8.0 + 3.0 * l, "evolved": evolved}
			if evolved:
				h["count"] = int(h["count"]) + 3
				h["dmg"] = float(h["dmg"]) * 1.5
			return h
		"tesla":
			return {"cd": 1.5 - 0.07 * l, "chains": 2 + l, "dmg": 14.0 + 4.0 * l, "range": 380.0, "jump": 170.0}
		"airstrike":
			var a := {"cd": 8.0 - 0.45 * l, "bombs": 6 + l, "radius": 64.0 + 5.0 * l, "dmg": 35.0 + 10.0 * l}
			if evolved:
				a["cd"] = 1.8
				a["bombs"] = int(int(a["bombs"]) * 1.5)
			return a
	return {}
