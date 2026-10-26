extends Node
## Adaptive soundtrack. It watches the game instead of being told what to do,
## so game.gd needs no music calls:
## - Menu: menu.ogg.
## - Stage: stage_calm.ogg and stage_combat.ogg play in sync; the combat
##   stem fades in with the fight's intensity (enemies on screen, combo).
## - Boss: crossfades to boss.ogg.
## - Run over: the loops fade out under victory.ogg or defeat.ogg.
## - Level-up cards, chests and the revive screen muffle the music.
## Any track can be replaced by dropping a file with the same name into
## res://audio/music/. A single stage.ogg (no stems) is used as-is if present.

const DIR := "res://audio/music/"
const FADE := 1.2
const SILENT := -60.0

var game: Node
var players := {}
var mode := ""
var intensity := 0.0
var duck_db := 0.0
var lowpass: AudioEffectLowPassFilter
var bus := 0
var states := {}
var last_state := -1


func _ready() -> void:
	bus = AudioServer.get_bus_index("Music")
	for slot in ["menu", "calm", "combat", "boss", "sting"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = SILENT
		add_child(p)
		players[slot] = p
	var single := _track("stage")
	players["menu"].stream = _track("menu")
	players["calm"].stream = single if single else _track("stage_calm")
	players["combat"].stream = null if single else _track("stage_combat")
	players["boss"].stream = _track("boss")
	for i in AudioServer.get_bus_effect_count(bus):
		var fx := AudioServer.get_bus_effect(bus, i)
		if fx is AudioEffectLowPassFilter:
			lowpass = fx as AudioEffectLowPassFilter
	if game:
		states = game.get_script().get_script_constant_map().get("State", {})


func _track(track_name: String) -> AudioStream:
	var path := DIR + track_name + ".ogg"
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = track_name != "victory" and track_name != "defeat"
	return s


func _process(delta: float) -> void:
	if game == null or states.is_empty():
		return
	var st: int = game.get("state")
	var target := "menu"
	if st == int(states.get("OVER", -1)):
		target = "over"
	elif st != int(states.get("MENU", -1)):
		# The boss track also drives the final push after the boss dies,
		# until the last Siege Colossus falls.
		var pushing := float(game.get("boss_dead_t")) >= 0.0 and float(_prop("final_clear_t", -1.0)) < 0.0
		target = "boss" if game.get("boss_on") or pushing else "stage"
	if target != mode:
		_switch(target)
	if last_state == int(states.get("DEAD", -1)) and st == int(states.get("PLAYING", -1)):
		_announce("revive")
	last_state = st
	_update_intensity(delta)
	var muffled := st == int(states.get("CARDS", -1)) or st == int(states.get("CHEST", -1)) or st == int(states.get("DEAD", -1))
	if lowpass:
		var want := 900.0 if muffled else 20000.0
		lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz, want, minf(1.0, delta * 6.0))
	duck_db = minf(duck_db + delta * 12.0, 0.0)
	AudioServer.set_bus_volume_db(bus, -4.0 + duck_db + (-3.0 if muffled else 0.0))


## Briefly lowers the music under a big sound or voice line.
func duck(db: float) -> void:
	duck_db = minf(duck_db, -absf(db))


func _switch(target: String) -> void:
	var old := mode
	mode = target
	match target:
		"menu":
			_fade_all_except(["menu"])
			_start("menu", 0.0)
		"stage":
			_fade_all_except(["calm", "combat"])
			if old != "boss":
				intensity = 0.0
				_announce("start", 0.8)
				_start("calm", 0.0)
				# The combat stem starts with calm so they stay in sync;
				# _update_intensity sets its volume from then on.
				var c: AudioStreamPlayer = players["combat"]
				if c.stream:
					c.stop()
					c.volume_db = SILENT
					c.play()
			else:
				_fade("calm", 0.0)
		"boss":
			_fade_all_except(["boss"])
			_start("boss", 0.0)
		"over":
			_fade_all_except([], 0.6)
			var won := _won()
			var p: AudioStreamPlayer = players["sting"]
			p.stream = _track("victory" if won else "defeat")
			p.volume_db = 0.0
			if p.stream:
				p.play()
			# A win already got its "THE IRON DOMINION FALLS" callout.
			if not won:
				_announce("defeat", 1.4)


func _start(slot: String, db: float) -> void:
	var p: AudioStreamPlayer = players[slot]
	if p.stream == null:
		return
	if not p.playing or slot == "calm":
		p.stop()
		p.volume_db = SILENT
		p.play()
	_fade(slot, db)


func _fade(slot: String, db: float, time: float = FADE) -> void:
	var p: AudioStreamPlayer = players[slot]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, time)
	if db <= SILENT + 1.0:
		tw.tween_callback(p.stop)


func _fade_all_except(keep: Array, time: float = FADE) -> void:
	for slot in players:
		if slot != "sting" and not keep.has(slot) and players[slot].playing:
			_fade(slot, SILENT, time)


## The combat stem follows the fight: quick to rise, slow to fall, so a
## brief lull doesn't drop the drums.
func _update_intensity(delta: float) -> void:
	if mode != "stage":
		return
	var enemies := float(game.get("e_count"))
	var combo := float(game.get("combo"))
	var t := float(game.get("t"))
	var target := clampf(enemies / 160.0, 0.0, 1.0) * 0.75 + clampf(combo / 120.0, 0.0, 1.0) * 0.25
	if t < 15.0:
		target = minf(target, 0.3)
	var rate := 1.2 if target > intensity else 0.12
	intensity = move_toward(intensity, target, rate * delta)
	var p: AudioStreamPlayer = players["combat"]
	if p.playing and p.stream:
		p.volume_db = linear_to_db(maxf(intensity, 0.001))



func _announce(id: String, delay: float = 0.0) -> void:
	var sfx = get_parent()
	if sfx == null or not sfx.has_method("announce"):
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(sfx.announce.bind(id))
	else:
		sfx.announce(id)


## A run is won when the final push is cleared (older builds: the boss died).
func _won() -> bool:
	var clear = _prop("final_clear_t", null)
	if clear == null:
		return float(game.get("boss_dead_t")) >= 0.0
	return float(clear) >= 0.0


func _prop(prop: String, fallback: Variant) -> Variant:
	var v = game.get(prop)
	return fallback if v == null else v
