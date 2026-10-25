extends Node
## Sound effects synthesized in code (no audio files): shots, hits, explosions,
## pickups, level-ups, the chest roulette and alarms. A small player pool and
## a per-sound minimum gap keep hundreds of hits per second from turning into
## noise.

const RATE := 22050
const VOICES := 14

var sounds := {}
var gaps := {}
var last_played := {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var muted := false


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	_add("shot", _tone(0.05, 1300.0, 500.0, "square", 0.12, 0.0), 0.05)
	_add("hit", _tone(0.03, 300.0, 200.0, "noise", 0.18, 1.0), 0.03)
	_add("boom", _tone(0.35, 120.0, 40.0, "noise", 0.5, 0.85), 0.06)
	_add("big_boom", _tone(0.9, 90.0, 25.0, "noise", 0.7, 0.8), 0.2)
	_add("gem", _tone(0.07, 1500.0, 1900.0, "sine", 0.18, 0.0), 0.025)
	_add("coin", _chord([1320.0, 1760.0], 0.06, 0.2), 0.05)
	_add("level", _chord([523.0, 659.0, 784.0, 1047.0], 0.08, 0.3), 0.2)
	_add("fanfare", _chord([392.0, 523.0, 659.0, 784.0, 1047.0, 1319.0], 0.1, 0.35), 0.3)
	_add("tick", _tone(0.02, 2400.0, 2000.0, "square", 0.12, 0.0), 0.03)
	_add("hurt", _tone(0.18, 220.0, 90.0, "square", 0.35, 0.2), 0.15)
	_add("alarm", _siren(0.9), 0.8)
	_add("zap", _tone(0.12, 2000.0, 300.0, "saw", 0.18, 0.3), 0.06)
	_add("freeze", _tone(0.5, 2600.0, 3200.0, "sine", 0.25, 0.15), 0.3)
	_add("powerup", _tone(0.35, 300.0, 1200.0, "square", 0.25, 0.0), 0.2)


## Plays a sound unless it played less than its minimum gap ago.
func play(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if muted or not sounds.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_played.get(name, -10.0)) < float(gaps[name]):
		return
	last_played[name] = now
	var p := players[next_player]
	next_player = (next_player + 1) % VOICES
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _add(name: String, stream: AudioStreamWAV, gap: float) -> void:
	sounds[name] = stream
	gaps[name] = gap


## A sweep from f0 to f1 Hz. noise_mix blends in noise (1 = pure noise).
func _tone(duration: float, f0: float, f1: float, wave: String, volume: float, noise_mix: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var smooth := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		match wave:
			"sine":
				v = sin(phase * TAU)
			"square":
				v = 1.0 if phase < 0.5 else -1.0
			"saw":
				v = phase * 2.0 - 1.0
		if noise_mix > 0.0:
			# Low-passed noise: rumbly for explosions, crisp for hits.
			smooth = lerpf(smooth, randf() * 2.0 - 1.0, clampf(f / 2000.0, 0.02, 1.0))
			v = lerpf(v, smooth * 2.0, noise_mix)
		var env := minf(1.0, k * 40.0) * pow(1.0 - k, 1.6)
		data.encode_s16(i * 2, int(clampf(v * env * volume, -1.0, 1.0) * 32767.0))
	return _stream(data)


## Notes played one after another (an arpeggio).
func _chord(freqs: Array, note: float, volume: float) -> AudioStreamWAV:
	var per := int(note * RATE)
	var tail := int(0.15 * RATE)
	var n := per * freqs.size() + tail
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := 0.0
		for j in freqs.size():
			var start := j * per
			if i >= start:
				var t := float(i - start) / RATE
				v += sin(t * float(freqs[j]) * TAU) * exp(-t * 6.0)
		data.encode_s16(i * 2, int(clampf(v * volume * 0.5, -1.0, 1.0) * 32767.0))
	return _stream(data)


func _siren(duration: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 600.0 + 300.0 * sin(t * TAU * 2.5)
		phase = fmod(phase + f / RATE, 1.0)
		var env := minf(1.0, t * 20.0) * minf(1.0, (duration - t) * 8.0)
		data.encode_s16(i * 2, int((phase * 2.0 - 1.0) * env * 0.22 * 32767.0))
	return _stream(data)


func _stream(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s
