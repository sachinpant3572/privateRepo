extends RefCounted
## The run report behind COPY RESULTS: what dealt and took the damage, hits
## blocked, healing, downs, kills, pickups, a minute-by-minute timeline and
## every pick, so balance problems show up in a pasted report. game.gd feeds
## it while playing (count(), track_minute() and the tables below) and asks
## for text() at the end of a run.

const Data := preload("res://data.gd")
const NAMES := {
	"other": "Other", "burn": "Burning", "toxin": "Toxin clouds", "shock": "Shock arcs", "static": "Static Dash",
	"explosive": "Explosive Rounds blasts", "stomp": "Shockwave Stomp", "dash": "Phase Dash", "thorns": "Reactive Plating",
	"evolution": "Evolution blasts", "revive": "Revive blasts", "nuke": "Nuke", "bombs": "Bombs", "slam": "Meteor Slam",
}
const HEAL_NAMES := {
	"regen": "Nanite Regeneration", "lifesteal": "Vampiric Rounds", "repair": "Repair Drone",
	"medkit": "Medkit pickups", "medkit card": "Medkit cards", "skip": "Skipped cards", "level-up": "Level-ups",
}

var dmg_by := {}  # Source -> damage dealt (overkill not counted).
var boss_dmg_by := {}
var taken_by := {}  # Enemy -> [hits, damage taken].
var healed_by := {}
var blocks := {}  # "dodge", "shield", "barrier" -> hits; "armor", "fortify" -> damage.
var wiped := {}  # Enemy bullets destroyed: "emp", "dome", "bulwark".
var kills_by := PackedInt32Array()
var pickups_got := PackedInt32Array()
var picks: Array = []
var timeline: Array = []  # One row per minute (see track_minute).
var tl_row := {}
var hp_low := 1.0
var low_hp_time := 0.0
var deaths: Array = []  # "m:ss by <enemy>"
var phases: Array = []  # "m:ss domination" / "m:ss escalation n"
var last_hit := ""
var boss_spawn_t := -1.0
var chests_opened := 0
var skips := 0


func reset() -> void:
	dmg_by = {}
	boss_dmg_by = {}
	taken_by = {}
	healed_by = {}
	blocks = {}
	wiped = {}
	kills_by = PackedInt32Array()
	kills_by.resize(Data.ENEMY_NAMES.size())
	pickups_got = PackedInt32Array()
	pickups_got.resize(Data.PICKUP_LABELS.size())
	picks = []
	timeline = []
	tl_row = {}
	hp_low = 1.0
	low_hp_time = 0.0
	deaths = []
	phases = []
	last_hit = ""
	boss_spawn_t = -1.0
	chests_opened = 0
	skips = 0


func count(d: Dictionary, key: String, n: float) -> void:
	if n > 0.0:
		d[key] = float(d.get(key, 0.0)) + n


static func clock(at: float) -> String:
	return "%d:%02d" % [floori(at / 60.0), int(at) % 60]


## One timeline row per minute of play: what the fight looked like then.
## Called every frame while playing.
func track_minute(g: Node, dt: float, delta: float) -> void:
	var hp: float = g.hp
	var max_hp: float = g.max_hp
	var now: float = g.t
	var kills: int = g.kills
	var sim_ms: float = g.sim_ms
	var smoke: bool = g.smoke
	var frac := hp / max_hp
	hp_low = minf(hp_low, frac)
	if frac < 0.25:
		low_hp_time += dt
	var minute := int(now / 60.0)
	if int(tl_row.get("min", -1)) != minute:
		if not tl_row.is_empty():
			timeline.append(tl_row)
		tl_row = {"min": minute, "frames": 0, "alive": 0, "hp_low": 1.0, "taken": 0.0, "ms": 0.0, "logic": 0.0, "logic_max": 0.0, "kills0": kills}
	tl_row["frames"] = int(tl_row["frames"]) + 1
	tl_row["alive"] = int(tl_row["alive"]) + int(g.e_count)
	tl_row["hp_low"] = minf(float(tl_row["hp_low"]), frac)
	tl_row["ms"] = float(tl_row["ms"]) + (dt if smoke else delta) * 1000.0
	tl_row["logic"] = float(tl_row["logic"]) + sim_ms
	tl_row["logic_max"] = maxf(float(tl_row["logic_max"]), sim_ms)
	tl_row["level"] = int(g.level)
	tl_row["kills"] = kills


## The full report: the summary (as on the results screen), then the details.
## `cards` is the card-use line, from the game.
func text(g: Node, summary: String, cards: String) -> String:
	var lines := PackedStringArray([summary, "", "--- DETAILS ---"])
	var names := NAMES.duplicate()
	for id in Data.NAMES:
		names[id] = Data.NAMES[id]
	var now: float = g.t
	var boss_dead_t: float = g.boss_dead_t
	var boss_max: float = g.boss_max
	var boss_hp: float = g.boss_hp
	var final_clear_t: float = g.final_clear_t
	var wave_n: int = g.wave_n
	var max_tier: int = g.max_tier
	lines.append("Stage: %d escalations, enemy tier %d of 3%s" % [wave_n, max_tier, "" if boss_spawn_t < 0.0 else ", boss at %s" % clock(boss_spawn_t)])
	if not phases.is_empty():
		lines.append("Phases: 0:00 domination, " + ", ".join(PackedStringArray(phases)))
	if boss_spawn_t >= 0.0:
		var fight := (boss_dead_t if boss_dead_t >= 0.0 else now) - boss_spawn_t
		var state := "destroyed" if boss_dead_t >= 0.0 else "%d%% HP left" % roundi(100.0 * boss_hp / maxf(boss_max, 1.0))
		lines.append("Boss: %s HP, %s, fight %s%s" % [_big(boss_max), state, clock(fight), "" if final_clear_t < 0.0 else ", final push %s" % clock(final_clear_t - boss_dead_t)])
	lines.append("Damage dealt (to enemies):")
	lines.append_array(_share_lines(dmg_by, names, 14))
	if not boss_dmg_by.is_empty():
		lines.append("Damage to the boss:")
		lines.append_array(_share_lines(boss_dmg_by, names, 6))
	var taken := {}
	var hits := 0
	for k in taken_by:
		taken[k] = float(taken_by[k][1])
		hits += int(taken_by[k][0])
	lines.append("Damage taken: %s in %d hits; lowest HP %d%%, %ds below 25%% HP" % [_big(_sum(taken)), hits, roundi(maxf(hp_low, 0.0) * 100.0), roundi(low_hp_time)])
	lines.append_array(_share_lines(taken, {}, 10))
	lines.append("Blocked: dodged %d, shield %d, barrier %d hits; armor soaked %s, Fortify %s" % [int(blocks.get("dodge", 0.0)), int(blocks.get("shield", 0.0)), int(blocks.get("barrier", 0.0)), _big(float(blocks.get("armor", 0.0))), _big(float(blocks.get("fortify", 0.0)))])
	if not wiped.is_empty():
		lines.append("Enemy bullets destroyed: EMP %d, dome %d, Bulwark %d" % [int(wiped.get("emp", 0.0)), int(wiped.get("dome", 0.0)), int(wiped.get("bulwark", 0.0))])
	if not healed_by.is_empty():
		lines.append("Healing: %s" % _big(_sum(healed_by)))
		lines.append_array(_share_lines(healed_by, HEAL_NAMES, 8))
	if not deaths.is_empty():
		lines.append("Downed: " + ", ".join(PackedStringArray(deaths)))
	var kl := PackedStringArray()
	for ty in kills_by.size():
		if kills_by[ty] > 0:
			kl.append("%s %d" % [Data.ENEMY_NAMES[ty], kills_by[ty]])
	lines.append("Kills: " + ", ".join(kl))
	var pk := PackedStringArray()
	for k in pickups_got.size():
		if pickups_got[k] > 0:
			pk.append("%s %d" % [String(Data.PICKUP_LABELS[k]).trim_suffix("!").capitalize(), pickups_got[k]])
	lines.append("Pickups: %s; chests %d" % [", ".join(pk) if not pk.is_empty() else "none", chests_opened])
	lines.append(cards)
	lines.append("Timeline (minute: level, kills, enemies avg, lowest HP, damage taken, FPS, logic avg/worst ms):")
	var rows := timeline.duplicate()
	if not tl_row.is_empty():
		rows.append(tl_row)
	for r in rows:
		var f := maxi(int(r["frames"]), 1)
		lines.append("  %d: L%d, +%d kills, %d enemies, HP %d%%, -%s, %.0f FPS, %.1f/%.1f" % [int(r["min"]) + 1, int(r["level"]), int(r["kills"]) - int(r["kills0"]), roundi(float(r["alive"]) / f), roundi(maxf(float(r["hp_low"]), 0.0) * 100.0), _big(float(r["taken"])), f * 1000.0 / maxf(float(r["ms"]), 0.001), float(r["logic"]) / f, float(r["logic_max"])])
	lines.append("Picks (%d):" % picks.size())
	for n in range(0, picks.size(), 3):
		lines.append("  " + " | ".join(PackedStringArray(picks.slice(n, n + 3))))
	return "\n".join(lines)


## Name: value (share%) lines, biggest first.
static func _share_lines(d: Dictionary, names: Dictionary, max_lines: int) -> PackedStringArray:
	var keys := d.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(d[a]) > float(d[b]))
	var total := _sum(d)
	var out := PackedStringArray()
	for n in mini(keys.size(), max_lines):
		var k: String = keys[n]
		out.append("  %s: %s (%d%%)" % [names.get(k, k), _big(float(d[k])), roundi(100.0 * float(d[k]) / maxf(total, 0.001))])
	return out


static func _big(v: float) -> String:
	if v >= 1.0e6:
		return "%.1fM" % (v / 1.0e6)
	if v >= 1.0e4:
		return "%.0fk" % (v / 1.0e3)
	return "%d" % roundi(v)


static func _sum(d: Dictionary) -> float:
	var total := 0.0
	for k in d:
		total += float(d[k])
	return total
