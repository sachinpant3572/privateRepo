extends RefCounted
## World 1 tables: enemies, weapons, powers, evolutions, card rarities and the
## wave plan. All numbers are first guesses for tuning (docs/game-design.md).

const MAX_LEVEL := 8

# Enemy types. The first four match their cells in the unit atlas (art.gd).
# Late game: bomber jets fly across and bomb, gunships hover and shell, and
# Siege Colossi are slow mini-bosses that come in pairs.
enum { TROOPER, SHIELD, GRENADIER, ELITE, TANK, HELI, JET, GUNSHIP, SIEGE }

const ENEMY_NAMES := ["Trooper", "Shield Trooper", "Grenadier", "Juggernaut", "Battle Tank", "Attack Helicopter", "Bomber Jet", "Gunship", "Siege Colossus"]
const ENEMY_HP := [10.0, 24.0, 14.0, 700.0, 170.0, 70.0, 60.0, 900.0, 4200.0]
const ENEMY_SPEED := [72.0, 56.0, 62.0, 52.0, 34.0, 125.0, 430.0, 70.0, 26.0]
const ENEMY_RADIUS := [14.0, 16.0, 14.0, 28.0, 30.0, 26.0, 26.0, 40.0, 64.0]
const ENEMY_SIZE := [42.0, 46.0, 42.0, 76.0, 84.0, 76.0, 92.0, 124.0, 176.0]  # On-screen size of the sprite.
const ENEMY_XP := [1, 2, 2, 30, 10, 6, 8, 60, 200]
const ENEMY_TOUCH := [6.0, 8.0, 6.0, 22.0, 18.0, 10.0, 0.0, 20.0, 30.0]  # Contact damage.
const ENEMY_FIRE := [2.6, 0.0, 3.6, 3.0, 4.2, 3.2, 0.22, 2.4, 3.0]  # Seconds between attacks; 0 = none.
const ENEMY_RANGE := [460.0, 0.0, 420.0, 420.0, 640.0, 520.0, 99999.0, 560.0, 720.0]
const ENEMY_CAP := [0, 0, 0, 4, 8, 6, 8, 3, 2]  # Most alive at once; 0 = no limit.

const WEAPON_IDS := ["rifle", "scatter", "rail", "rockets", "grenade", "halo", "drones", "tesla", "flame", "mines", "sentry", "airstrike"]
const POWER_IDS := [
	"overclock", "titan", "magnet", "adrenaline", "explosive", "crit",
	"might", "area", "duration", "multishot", "velocity", "pierce", "ricochet", "knockback",
	"regen", "lifesteal", "dodge", "shield", "thorns", "revival", "laststand",
	"barrier", "emp", "repair", "fortify",
	"burn", "cryo", "shock", "toxin",
	"dash", "stomp", "bullettime",
	"luck", "growth", "greed", "curse",
]

const NAMES := {
	"rifle": "Pulse Rifle",
	"scatter": "Scatter Cannon",
	"rail": "Rail Lance",
	"rockets": "Rocket Swarm",
	"grenade": "Grenade Rain",
	"halo": "Razor Halo",
	"drones": "Combat Drones",
	"tesla": "Tesla Coil",
	"flame": "Flame Burst",
	"mines": "Mine Layer",
	"sentry": "Sentry Turret",
	"airstrike": "Airstrike Beacon",
	"overclock": "Overclock",
	"titan": "Titan Skin",
	"magnet": "Magnet Field",
	"adrenaline": "Adrenaline",
	"explosive": "Explosive Rounds",
	"crit": "Critical Targeting",
	"might": "Firepower",
	"area": "Blast Radius",
	"duration": "Long Fuse",
	"multishot": "Multishot",
	"velocity": "Velocity Rounds",
	"pierce": "Armor Piercer",
	"ricochet": "Ricochet Matrix",
	"knockback": "Concussive Rounds",
	"regen": "Nanite Regeneration",
	"lifesteal": "Vampiric Rounds",
	"dodge": "Evasion Matrix",
	"shield": "Kinetic Shield",
	"thorns": "Reactive Plating",
	"revival": "Second Wind",
	"laststand": "Last Stand",
	"barrier": "Barrier Dome",
	"emp": "EMP Burst",
	"repair": "Repair Drone",
	"fortify": "Fortify",
	"burn": "Incendiary Rounds",
	"cryo": "Cryo Rounds",
	"shock": "Shock Rounds",
	"toxin": "Toxin Rounds",
	"dash": "Phase Dash",
	"stomp": "Shockwave Stomp",
	"bullettime": "Bullet Time",
	"luck": "Lucky Charm",
	"growth": "Battle Instinct",
	"greed": "Scavenger",
	"curse": "Blood Oath",
}

const DESCS := {
	"rifle": "Fires at the nearest enemy. More shots and damage each level; pierces from level 6.",
	"scatter": "Close-range spread of pellets. More pellets, wider and stronger each level.",
	"rail": "A piercing lance that cuts through every enemy in a line. More damage; a second lance at 5.",
	"rockets": "Homing missiles that explode. More missiles and bigger blasts each level.",
	"grenade": "Lobs grenades onto groups of enemies. More grenades and bigger blasts each level.",
	"halo": "Blades orbit you and shred anything they touch. More blades, wider and faster.",
	"drones": "Drones fly with you and shoot on their own. More drones and faster fire each level.",
	"tesla": "Lightning jumps between enemies. One more jump and more damage each level.",
	"flame": "Sprays a cone of fire at nearby enemies. Longer range and more burn; all around you at 8.",
	"mines": "Drops mines behind you that blow up when enemies step on them. More and bigger mines.",
	"sentry": "Deploys turrets that shoot nearby enemies. More turrets that last longer each level.",
	"airstrike": "Calls bombing runs across the battlefield. More bombs, more often.",
	"overclock": "+8% fire rate for every weapon, per level.",
	"titan": "+20 max HP and +1 armor per level.",
	"magnet": "+30% pickup range per level. Pulls in all XP at level 8.",
	"adrenaline": "+7% move speed per level.",
	"explosive": "Kills explode, damaging enemies nearby. Bigger blasts each level.",
	"crit": "+5% crit chance and +10% crit damage per level.",
	"might": "+8% damage for every weapon, per level.",
	"area": "+8% blast, blade, flame and aura size per level.",
	"duration": "+10% range of shots and longer turrets, mines, burns and slows, per level.",
	"multishot": "+1 projectile, blade, bomb or jump for every weapon at levels 1, 4 and 7.",
	"velocity": "+10% projectile speed per level.",
	"pierce": "Shots pass through +1 more enemy at levels 1, 3, 5 and 7.",
	"ricochet": "Shots bounce to another enemy: +1 bounce at levels 1, 3, 5 and 7.",
	"knockback": "Hits shove enemies back harder, vehicles too at level 5.",
	"regen": "Heal 0.4 HP a second per level. Kills heal 1 HP from level 6.",
	"lifesteal": "Heal for 0.5% of the damage you deal per level (up to 6 HP a second).",
	"dodge": "4% chance per level to dodge a hit completely.",
	"shield": "A shield blocks one hit, then recharges. More charges and faster recharge with level.",
	"thorns": "Getting hit blasts nearby enemies with your armor. Bigger blast each level.",
	"revival": "One free revive. A second one at level 5.",
	"laststand": "Below 35% HP: +10% damage and +6% fire rate per level.",
	"barrier": "When you're hit, a dome blocks all damage and enemy bullets for 2 s (+0.2 s per level). Recharges in 30 s (-2 s per level).",
	"emp": "Every 9 s (-0.5 s per level), an EMP wipes enemy bullets near you and stuns enemies for a moment. Wider and longer each level.",
	"repair": "A drone repairs 1% of your max HP every 2 s per level; twice as much below 40% HP.",
	"fortify": "Take 4% less damage per level, 8% while standing still.",
	"burn": "Hits set enemies on fire. Stronger burn each level.",
	"cryo": "Hits chill enemies, slowing them. At level 5 a chilled enemy can freeze solid.",
	"shock": "Hits can arc lightning to 2 nearby enemies. More chance and damage each level.",
	"toxin": "Kills leave a toxic cloud that hurts enemies inside. Bigger clouds each level.",
	"dash": "Blitz Dash (DASH button, charged by kills) charges 8% faster per level and cuts a longer, wider path.",
	"stomp": "Every few seconds, a shockwave knocks back and damages enemies around you.",
	"bullettime": "Every 20 seconds, enemies slow down for a moment. Longer with level.",
	"luck": "Better card rarities and more drops, per level.",
	"growth": "+8% XP per level.",
	"greed": "+15% gold per level.",
	"curse": "Enemies come faster and in bigger numbers, but drop 15% more XP and gold per level.",
}

# Card icon border color by kind of item.
const KIND_COLORS := {
	"weapon": Color(1.0, 0.6, 0.2),
	"attack": Color(1.0, 0.3, 0.3),
	"defense": Color(0.35, 0.65, 1.0),
	"utility": Color(0.35, 0.9, 0.5),
	"active": Color(0.75, 0.45, 1.0),
	"element": Color(1.0, 0.85, 0.35),
}
const POWER_KIND := {
	"overclock": "attack", "explosive": "attack", "crit": "attack", "might": "attack", "area": "attack",
	"multishot": "attack", "velocity": "attack", "pierce": "attack", "ricochet": "attack", "knockback": "attack",
	"lifesteal": "attack",
	"titan": "defense", "regen": "defense", "dodge": "defense", "shield": "defense", "thorns": "defense",
	"revival": "defense", "barrier": "defense", "emp": "defense", "repair": "defense", "fortify": "defense",
	"magnet": "utility", "adrenaline": "utility", "duration": "utility", "luck": "utility", "growth": "utility",
	"greed": "utility",
	"dash": "active", "stomp": "active", "bullettime": "active", "laststand": "active", "curse": "active",
	"burn": "element", "cryo": "element", "shock": "element", "toxin": "element",
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
const LIMIT_POWER_DESC := "+3% damage to everything per stack."
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
	"scatter": {"power": "regen", "name": "Leech Cannon", "desc": "Huge blasts of pellets that heal you as they hit."},
	"rail": {"power": "bullettime", "name": "Chrono Lance", "desc": "Three lances that freeze everything they pass through."},
	"rockets": {"power": "crit", "name": "Hellfire Barrage", "desc": "Twice the missiles, and every one crits."},
	"grenade": {"power": "luck", "name": "Cluster Jackpot", "desc": "Every blast splits into a ring of smaller blasts."},
	"halo": {"power": "adrenaline", "name": "Buzzsaw Halo", "desc": "Three more blades that spin faster the faster you move."},
	"drones": {"power": "magnet", "name": "Drone Hive", "desc": "Double the drones, firing twice as fast."},
	"tesla": {"power": "ricochet", "name": "Storm Network", "desc": "Lightning forks to every enemy it touches."},
	"flame": {"power": "titan", "name": "Inferno Walker", "desc": "A permanent ring of fire burns everything near you."},
	"mines": {"power": "stomp", "name": "Seismic Field", "desc": "Mines trigger quakes that rip through the ground."},
	"sentry": {"power": "shield", "name": "Fortress", "desc": "Turrets fire rockets and stay twice as long."},
	"airstrike": {"power": "explosive", "name": "Carpet Bomber", "desc": "Near-constant bombing runs."},
}

# Gear the hero wears during a run: it grows with the build (see hero.gd).
const HELMET_POWERS := ["titan", "shield", "dodge", "regen", "thorns", "revival", "barrier", "emp", "repair"]
const SHOULDER_POWERS := ["titan", "thorns", "might", "laststand", "fortify"]
const HELMET_TIERS := [3, 8, 14]  # Total levels of HELMET_POWERS for tiers 1, 2, 3.
const SHOULDER_TIERS := [1, 5, 10]
# Back item: the build family with the most levels wins.
const BACK_FAMILIES := {
	"jetpack": ["adrenaline", "dash", "stomp", "bullettime"],
	"missiles": ["rockets", "grenade", "airstrike", "mines", "explosive"],
	"dronepack": ["drones", "sentry", "tesla", "magnet"],
	"wings": ["burn", "cryo", "shock", "toxin", "halo", "flame"],
}
const ELEMENT_COLORS := {
	"burn": Color(1.0, 0.45, 0.15),
	"cryo": Color(0.55, 0.85, 1.0),
	"shock": Color(1.0, 0.95, 0.35),
	"toxin": Color(0.5, 1.0, 0.3),
}

# Costumes: id, name, price in gold. The first one is free.
const COSTUMES := [
	["vanguard", "Vanguard", 0],
	["shock", "Shock Trooper", 150],
	["stealth", "Stealth Ops", 250],
	["frost", "Frost Warden", 400],
	["ember", "Ember Vanguard", 400],
	["knight", "Lightning Knight", 600],
	["ninja", "Cyber Ninja", 600],
	["shadow", "Shadow Runner", 800],
	["titan", "Titan Heavy", 1000],
	["solar", "Solar Paladin", 1300],
	["void", "Void Walker", 1600],
	["gold", "Golden Champion", 2500],
]

const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.75, 0.78, 0.82), Color(0.3, 0.6, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.72, 0.2)]
const RARITY_LEVELS := [1, 1, 2, 3]
const RARE_BONUS := 0.04  # Rare cards also give +4% damage to everything.

# Screen-clear pickups.
enum { NUKE, FREEZE, VACUUM, MEDKIT, SHIELD_CELL }
const PICKUP_LABELS := ["NUKE!", "FREEZE!", "VACUUM!", "MEDKIT", "SHIELD CELL"]
const PICKUP_WEIGHTS := [1.0, 1.0, 1.0, 1.4, 1.4]  # Defensive pickups come up more.
# Items without their own card icon borrow one.
const ICON_ALIAS := {"barrier": "shield", "emp": "shock", "repair": "regen", "fortify": "titan", "heal": "regen", "gold": "might"}

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
# The last 90 seconds before the Colossus build up with air and armor.
const EVENTS := [
	[90.0, "AMBUSH!", TROOPER, 30, "ring"],
	[150.0, "SHIELD WALL!", SHIELD, 24, "line"],
	[195.0, "TANK COLUMN!", TANK, 5, "line"],
	[210.0, "BOMBING RUN!", JET, 3, "flyby"],
	[235.0, "GUNSHIPS INBOUND!", GUNSHIP, 2, "ring"],
	[255.0, "ARMORED ASSAULT!", TANK, 7, "line"],
	[270.0, "AIR RAID!", HELI, 6, "ring"],
	[285.0, "SIEGE COLOSSUS!", SIEGE, 1, "line"],
]
# After the Colossus falls: the Dominion's last push. Survive FINAL_TIME and
# destroy every Siege Colossus to win.
const FINAL_TIME := 25.0
const FINAL_WAVE := [[SIEGE, 2], [GUNSHIP, 3], [TANK, 6], [HELI, 4]]

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
		return PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if t < 120.0:
		return PackedFloat32Array([0.6, 0.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	if t < 210.0:
		return PackedFloat32Array([0.5, 0.15, 0.15, 0.0, 0.1, 0.1, 0.0, 0.0, 0.0])
	if t < 240.0:
		return PackedFloat32Array([0.4, 0.15, 0.15, 0.0, 0.15, 0.15, 0.0, 0.0, 0.0])
	# From 4:00 the horde mixes in gunships (Siege Colossi come from events).
	return PackedFloat32Array([0.36, 0.15, 0.15, 0.0, 0.16, 0.16, 0.0, 0.02, 0.0])


## Limit Break stacks on top of a weapon's level-8 (or evolved) stats.
static func limit_break(st: Dictionary, n: int) -> void:
	if n <= 0:
		return
	st["dmg"] = float(st["dmg"]) * (1.0 + 0.12 * n)
	if st.has("cd"):
		st["cd"] = maxf(0.06, float(st["cd"]) / (1.0 + 0.04 * n))
	var extra := int(n / 2.0)
	for key in ["count", "chains", "bombs", "arcs"]:
		if st.has(key):
			st[key] = int(st[key]) + extra


static func weapon_stats(id: String, l: int, evolved: bool) -> Dictionary:
	match id:
		"rifle":
			if evolved:
				return {"cd": 0.1, "count": 5, "dmg": 16.0, "pierce": 99, "speed": 820.0, "spread": 0.07, "life": 1.1}
			return {"cd": 0.55 - 0.03 * l, "count": 1 + int(l * 0.75), "dmg": 9.0 + 3.0 * l, "pierce": 2 if l >= 6 else 0, "speed": 760.0, "spread": 0.09, "life": 1.1}
		"scatter":
			var sc := {"cd": 1.15 - 0.05 * l, "count": 6 + 2 * l, "dmg": 6.0 + 2.0 * l, "pierce": 1 if l >= 5 else 0, "speed": 620.0, "spread": deg_to_rad(40.0 + 4.0 * l), "life": 0.42, "leech": false}
			if evolved:
				sc["count"] = int(sc["count"]) * 2
				sc["cd"] = 0.6
				sc["leech"] = true
			return sc
		"rail":
			var rl := {"cd": 2.2 - 0.12 * l, "count": 1 + int(l / 3.0), "dmg": 40.0 + 14.0 * l, "speed": 1500.0, "life": 0.7, "freeze": false}
			if evolved:
				rl["count"] = 5
				rl["cd"] = 0.9
				rl["freeze"] = true
			return rl
		"rockets":
			var r := {"cd": 1.7 - 0.08 * l, "count": 2 + l, "dmg": 14.0 + 5.0 * l, "radius": 42.0 + 6.0 * l, "crit": false}
			if evolved:
				r["count"] = int(r["count"]) * 2
				r["cd"] = 0.9
				r["crit"] = true
			return r
		"grenade":
			return {"cd": 2.4 - 0.12 * l, "count": 1 + l, "dmg": 22.0 + 7.0 * l, "radius": 55.0 + 5.0 * l, "cluster": evolved}
		"halo":
			var h := {"count": 2 + int(l * 0.75), "radius": 70.0 + 7.0 * l, "speed": 3.0 + 0.25 * l, "dmg": 8.0 + 3.0 * l, "evolved": evolved}
			if evolved:
				h["count"] = int(h["count"]) + 4
				h["dmg"] = float(h["dmg"]) * 1.5
			return h
		"drones":
			var dr := {"count": 1 + int(l / 2.0), "cd": 0.9 - 0.05 * l, "dmg": 8.0 + 3.0 * l, "homing": l >= 6}
			if evolved:
				dr["count"] = int(dr["count"]) * 2
				dr["cd"] = float(dr["cd"]) * 0.5
			return dr
		"tesla":
			return {"cd": 1.5 - 0.07 * l, "chains": 3 + l, "arcs": 1 + int(l / 3.0) + (1 if evolved else 0), "dmg": 14.0 + 4.0 * l, "range": 380.0, "jump": 170.0, "fork": evolved}
		"flame":
			var fl := {"cd": 0.12, "range": 120.0 + 12.0 * l, "cone": deg_to_rad(50.0 + 5.0 * l), "dmg": 3.0 + 1.2 * l, "ring": false}
			if l >= MAX_LEVEL:
				fl["cone"] = TAU
			if evolved:
				fl["ring"] = true
				fl["dmg"] = float(fl["dmg"]) * 1.6
			return fl
		"mines":
			return {"cd": 1.6 - 0.08 * l, "count": 1 + int(l / 3.0) + (1 if evolved else 0), "dmg": 30.0 + 10.0 * l, "radius": 60.0 + 6.0 * l, "life": 12.0, "quake": evolved}
		"sentry":
			var se := {"cd": 9.0 - 0.5 * l, "max": 1 + int(l / 2.0), "life": 8.0 + 1.0 * l, "fire": 0.5, "dmg": 10.0 + 3.5 * l, "rockets": l >= 6}
			if evolved:
				se["life"] = float(se["life"]) * 2.0
				se["max"] = int(se["max"]) + 1
			return se
		"airstrike":
			var a := {"cd": 8.0 - 0.45 * l, "bombs": 8 + 2 * l, "radius": 64.0 + 5.0 * l, "dmg": 35.0 + 10.0 * l}
			if evolved:
				a["cd"] = 1.8
				a["bombs"] = int(int(a["bombs"]) * 1.5)
			return a
	return {}
