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
	"boom": [0.05, -4.0, 0.1, "fx"],
	"big_boom": [0.18, 0.0, 0.06, "fx"],
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
}

# Sounds big enough to push the music down for a moment (dB).
const DUCK := {"big_boom": 4.0, "synergy": 7.0, "evolve": 9.0, "level": 3.0, "fanfare": 5.0, "alarm": 4.0}

# Banner text (start of it) -> announcer line.
const BANNER_VOICES := [
	["SYNERGY", "synergy"], ["EVOLUTION", "evolution"], ["BOSS:", "boss"], ["COLOSSUS DESTROYED", "boss_down"],
	["JUGGERNAUT", "juggernaut"], ["AMBUSH", "ambush"], ["SHIELD WALL", "shield_wall"], ["TANK COLUMN", "tank_column"],
	["AIR RAID", "air_raid"], ["NUKE", "nuke"], ["FREEZE", "freeze"], ["VACUUM", "vacuum"], ["MEDKIT", "medkit"],
	["SECOND WIND", "second_wind"], ["KILLING SPREE", "killing_spree"], ["RAMPAGE", "rampage"], ["MASSACRE", "massacre"],
	["UNSTOPPABLE", "unstoppable"], ["GODLIKE", "godlike"], ["APOCALYPSE", "apocalypse"], ["FINAL WAVE", "final_wave"],
]

var variants := {}
var last_played := {}
var pools := {"fx": [], "ui": []}
var next_voice := {"fx": 0, "ui": 0}
var voices := {}
var voice_player: AudioStreamPlayer
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
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), -2.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), 1.0)
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
	last_played[sound] = now
	var pool: String = spec[3]
	var players: Array = pools[pool]
	var p: AudioStreamPlayer = players[next_voice[pool]]
	next_voice[pool] = (next_voice[pool] + 1) % players.size()
	p.stream = list[randi() % list.size()]
	var jitter: float = spec[2]
	p.pitch_scale = pitch * randf_range(1.0 - jitter, 1.0 + jitter)
	p.volume_db = float(spec[1]) + volume_db
	p.play()
	if DUCK.has(sound) and music:
		music.duck(DUCK[sound])


## Plays an announcer line (res://audio/voice/<id>.ogg) over the action.
func announce(id: String) -> void:
	if muted:
		return
	if not voices.has(id):
		var path := VOICE_DIR + id + ".ogg"
		voices[id] = load(path) if ResourceLoader.exists(path) else null
	if voices[id] == null:
		return
	voice_player.stream = voices[id]
	voice_player.play()
	if music:
		music.duck(8.0)


## Called by the HUD for every banner: big callouts get a voice line.
func announce_banner(text: String) -> void:
	var upper := text.to_upper()
	for pair in BANNER_VOICES:
		if upper.begins_with(pair[0]):
			announce(pair[1])
			return
	if upper.contains("LIMIT BREAK"):
		announce("limit_break")
