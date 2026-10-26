extends Node
## Sound effects, announcer and the music player (music.gd).
## - Sounds are pre-rendered files, res://audio/sfx/<id>_<n>.ogg, made by
##   tools/audio/sfx.py. Each has several variations; one is picked at random
##   and its pitch nudged, so a sound heard 500 times never repeats exactly.
## - A per-sound minimum gap and two voice pools (busy combat sounds can't
##   steal voices from rewards and UI) keep hundreds of hits per second clean.
## - Big moments duck the music; announcer lines (res://audio/voice/) duck it
##   further. The announcer follows HUD banners (see announce_banner), so game
##   code needs no extra calls.

const SFX_DIR := "res://audio/sfx/"
const VOICE_DIR := "res://audio/voice/"
const COMBAT_VOICES := 20
const UI_VOICES := 6

# id: [minimum gap (s), volume (dB), pitch jitter, pool]. Pool "ui" is for
# rewards and interface sounds that must never be cut off.
const SOUNDS := {
	"shot": [0.045, -9.0, 0.06, "fx"],
	"scatter": [0.08, -6.0, 0.05, "fx"],
	"rocket": [0.06, -10.0, 0.08, "fx"],
	"rail": [0.12, -5.0, 0.04, "fx"],
	"flame": [0.1, -7.0, 0.06, "fx"],
	"grenade": [0.08, -7.0, 0.06, "fx"],
	"mine": [0.15, -10.0, 0.03, "fx"],
	"drone": [0.06, -12.0, 0.08, "fx"],
	"zap": [0.06, -8.0, 0.08, "fx"],
	"hit": [0.025, -14.0, 0.12, "fx"],
	"boom": [0.09, -7.0, 0.1, "fx"],
	"big_boom": [0.25, -4.0, 0.06, "fx"],
	"hurt": [0.15, -2.0, 0.05, "ui"],
	"gem": [0.02, -13.0, 0.0, "fx"],
	"coin": [0.04, -11.0, 0.03, "fx"],
	"level": [0.2, -3.0, 0.0, "ui"],
	"fanfare": [0.3, -2.0, 0.0, "ui"],
	"tick": [0.03, -6.0, 0.05, "ui"],
	"powerup": [0.2, -3.0, 0.03, "ui"],
	"freeze": [0.3, -3.0, 0.0, "ui"],
	"alarm": [0.8, -6.0, 0.0, "ui"],
	"synergy": [0.5, 0.0, 0.0, "ui"],
	"evolve": [0.5, 0.0, 0.0, "ui"],
	"limit_break": [0.3, -2.0, 0.03, "ui"],
	"card_show": [0.15, -8.0, 0.05, "ui"],
	"card_pick": [0.1, -4.0, 0.03, "ui"],
	"ui_tap": [0.05, -6.0, 0.04, "ui"],
	"heal": [0.3, -4.0, 0.0, "ui"],
	"shield": [0.2, -6.0, 0.05, "ui"],
	"jet": [0.6, -3.0, 0.05, "fx"],
	"barrier": [1.0, -4.0, 0.02, "ui"],
	"slam_ready": [1.0, -3.0, 0.0, "ui"],
	"slam_launch": [0.5, -2.0, 0.03, "ui"],
	"slam_impact": [0.5, 2.0, 0.03, "ui"],
	"emp": [0.5, -10.0, 0.08, "fx"],
	"repair": [2.5, -16.0, 0.05, "fx"],
	"gunship": [0.15, -7.0, 0.06, "fx"],
	"siege": [0.4, -4.0, 0.05, "fx"],
}

# Most copies of a sound that may play at once. A screen of explosions is
# still 3 booms, not 20 stacked into a distorted wall.
const MAX_AT_ONCE := {"jet": 2, "gunship": 2, "siege": 2, "boom": 3, "big_boom": 2, "grenade": 3, "scatter": 2, "flame": 2, "rocket": 3, "rail": 2, "hit": 4, "shot": 4, "zap": 3}

# Sounds big enough to push the music down for a moment (dB).
const DUCK := {"slam_impact": 12.0, "slam_launch": 4.0, "big_boom": 4.0, "synergy": 7.0, "evolve": 9.0, "level": 3.0, "fanfare": 5.0, "alarm": 4.0}

# Kills within one second -> callout. Each step up is louder.
const KILL_BURSTS := [[25, "multi_kill"], [50, "mega_kill"], [100, "ultra_kill"], [200, "monster_kill"]]

# Banner text (start of it) -> announcer line.
const BANNER_VOICES := [
	["SYNERGY", "synergy"], ["EVOLUTION", "evolution"], ["BOSS:", "boss"], ["COLOSSUS DESTROYED", "boss_down"],
	["JUGGERNAUT", "juggernaut"], ["AMBUSH", "ambush"], ["SHIELD WALL", "shield_wall"], ["TANK COLUMN", "tank_column"],
	["AIR RAID", "air_raid"], ["NUKE", "nuke"], ["FREEZE", "freeze"], ["VACUUM", "vacuum"], ["MEDKIT", "medkit"],
	["SECOND WIND", "second_wind"], ["BOMBING RUN", "bombing_run"], ["GUNSHIPS", "gunships"],
	["ARMORED ASSAULT", "armored_assault"], ["SIEGE COLOSSUS", "siege"], ["THE DOMINION STRIKES BACK", "strikes_back"],
	["THE IRON DOMINION FALLS", "dominion_falls"], ["METEOR SLAM", "meteor_slam"],
	["DOMINATION", "domination"], ["THE DOMINION ESCALATES", "escalates"], ["VETERANS", "veterans"],
	["ELITE GUARD", "elite_guard"], ["SHIELD CELL", "shield_cell"], ["KILLING SPREE", "killing_spree"], ["RAMPAGE", "rampage"], ["MASSACRE", "massacre"],
	["UNSTOPPABLE", "unstoppable"], ["GODLIKE", "godlike"], ["APOCALYPSE", "apocalypse"], ["FINAL WAVE", "final_wave"],
]

var variants := {}
var last_played := {}
var pools := {"fx": [], "ui": []}
var next_voice := {"fx": 0, "ui": 0}
var playing_id := {}  # AudioStreamPlayer -> sound id it last played
var voices := {}
var voice_player: AudioStreamPlayer
var voice_queue: Array = []  # [line id, volume dB, pitch] still to say
var voice_priority := 0
var game_ref: Node
var kill_hist: Array = []  # [time, kills] over the last second
var kill_tier := -1
var kill_cd := 0.0
var slug_re := RegEx.create_from_string("[^a-z0-9]+")
var music  # music.gd
var muted := false


func _ready() -> void:
	_setup_buses()
	for pool in pools:
		for i in COMBAT_VOICES if pool == "fx" else UI_VOICES:
			var p := AudioStreamPlayer.new()
			p.bus = "SFX"
			add_child(p)
			pools[pool].append(p)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	for id in SOUNDS:
		var list := []
		for k in 8:
			var path := "%s%s_%d.ogg" % [SFX_DIR, id, k]
			if not ResourceLoader.exists(path):
				break
			list.append(load(path))
		variants[id] = list


## Starts the music, which reads the game's state from then on.
func attach(game: Node) -> void:
	game_ref = game
	music = preload("res://music.gd").new()
	music.game = game
	add_child(music)
	_link_hud.call_deferred(game)


func _link_hud(game: Node) -> void:
	var hud = game.get("hud")
	if hud and "sfx" in hud:
		hud.sfx = self


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") >= 0:
		return
	for bus_name in ["Music", "SFX", "Voice"]:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	var music_bus := AudioServer.get_bus_index("Music")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(music_bus, lp)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -4.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), -2.0)
	# A limiter on the master bus so a screen of explosions never clips.
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, limiter)


## Plays a sound unless it played less than its minimum gap ago.
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted or not SOUNDS.has(sound):
		return
	var list: Array = variants.get(sound, [])
	if list.is_empty():
		return
	var spec: Array = SOUNDS[sound]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(sound, -10.0)) < float(spec[0]):
		return
	var pool: String = spec[3]
	var players: Array = pools[pool]
	if MAX_AT_ONCE.has(sound):
		var busy := 0
		for q in players:
			if q.playing and playing_id.get(q, "") == sound:
				busy += 1
		if busy >= int(MAX_AT_ONCE[sound]):
			return
	last_played[sound] = now
	var p: AudioStreamPlayer = players[next_voice[pool]]
	next_voice[pool] = (next_voice[pool] + 1) % players.size()
	p.stream = list[randi() % list.size()]
	playing_id[p] = sound
	var jitter: float = spec[2]
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.volume_db = float(spec[1]) + volume_db
	p.play()
	if DUCK.has(sound) and music:
		music.duck(DUCK[sound])


## Plays an announcer line (res://audio/voice/<id>.ogg) over the action.
## A line only cuts off one of lower or equal priority (1 = a routine
## upgrade ... 4 = a monster kill), so big moments are never talked over.
func announce(id: String, priority: int = 3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	announce_seq([[id, volume_db, pitch]], priority)


## Says several lines back to back, e.g. "ROCKET SWARM!" + "MAXED OUT!".
func announce_seq(parts: Array, priority: int) -> void:
	if muted or voice_player == null:
		return
	if voice_player.playing and priority < voice_priority:
		return
	var queue := []
	for part in parts:
		if _voice(part[0]) != null:
			queue.append(part)
	if queue.is_empty():
		return
	voice_queue = queue
	voice_priority = priority
	voice_player.stop()
	_next_voice()


func _voice(id: String) -> AudioStream:
	if not voices.has(id):
		var path := VOICE_DIR + id + ".ogg"
		voices[id] = load(path) if ResourceLoader.exists(path) else null
	return voices[id]


func _next_voice() -> void:
	var part: Array = voice_queue.pop_front()
	voice_player.stream = _voice(part[0])
	voice_player.volume_db = float(part[1])
	voice_player.pitch_scale = float(part[2])
	voice_player.play()
	if music:
		music.duck(8.0)


func _process(delta: float) -> void:
	if voice_player and not voice_player.playing and not voice_queue.is_empty():
		_next_voice()
	_watch_kills(delta)


## Every upgrade picked gets a callout. How hard he shouts follows the pick:
## 1 = a common level-up, 2 = rare, epic, new or level 5+, 3 = legendary,
## maxed, an evolution or a Limit Break (the roaring takes, x_*).
func announce_upgrade(info: Dictionary) -> void:
	var title := String(info.get("title", ""))
	var tag := String(info.get("tag", ""))
	var kind := "level"
	var item := title
	if title.begins_with("EVOLVE: "):
		kind = "evolve"
		item = title.substr(8)
	elif title.begins_with("LIMIT BREAK: "):
		kind = "limit"
		item = title.substr(13)
	var rarity := tag.get_slice("·", 0).strip_edges()
	var to_level := 0
	if tag.contains("→"):
		to_level = int(tag.get_slice("→", 1).strip_edges())
	var is_new := tag.contains("NEW")
	var tier := 1
	if rarity in ["Rare", "Epic"] or is_new or to_level >= 5:
		tier = 2
	if kind != "level" or rarity == "Legendary" or to_level >= 8:
		tier = 3
	var slug := slug_re.sub(item.to_lower(), "_", true).strip_edges().trim_prefix("_").trim_suffix("_")
	if slug == "field_medkit":
		announce("medkit", 1)
		return
	var vol: float = [-4.0, 0.0, 2.0][tier - 1]
	var pitch: float = [0.97, 1.0, 1.03][tier - 1]
	var name_line := ("x_" if tier == 3 else "u_") + slug
	var parts := []
	match kind:
		"evolve":
			parts = [["evolution", vol, pitch], [name_line, vol, pitch]]
		"limit":
			parts = [[name_line, vol, pitch], ["limit_break", vol, pitch]]
		_:
			parts = [[name_line, vol, pitch]]
			if is_new:
				parts.append(["x_online" if tier == 3 else "online", vol, pitch])
			elif to_level >= 8:
				parts.append(["maxed_out", vol, pitch])
	announce_seq(parts, tier)


## Mass destruction: kills within the last second climb MULTI, MEGA, ULTRA
## and MONSTER KILL; each only fires once per streak of carnage.
func _watch_kills(delta: float) -> void:
	if game_ref == null:
		return
	var kills := int(game_ref.get("kills"))
	var now := Time.get_ticks_msec() / 1000.0
	if not kill_hist.is_empty() and kills < int(kill_hist[-1][1]):
		kill_hist.clear()  # A new run.
	kill_hist.append([now, kills])
	while kill_hist.size() > 1 and now - float(kill_hist[0][0]) > 1.0:
		kill_hist.pop_front()
	kill_cd = maxf(kill_cd - delta, 0.0)
	if kill_cd <= 0.0:
		kill_tier = -1
	var burst := kills - int(kill_hist[0][1])
	for k in range(KILL_BURSTS.size() - 1, -1, -1):
		if burst >= int(KILL_BURSTS[k][0]):
			if k > kill_tier:
				kill_tier = k
				kill_cd = 4.0
				announce(KILL_BURSTS[k][1], 3 if k < 2 else 4, 0.0 if k < 3 else 2.0)
			break


## Called by the HUD for every banner: big callouts get a voice line.
func announce_banner(text: String) -> void:
	var upper := text.to_upper()
	for pair in BANNER_VOICES:
		if upper.begins_with(pair[0]):
			announce(pair[1])
			return
	if upper.contains("LIMIT BREAK"):
		announce("limit_break")
