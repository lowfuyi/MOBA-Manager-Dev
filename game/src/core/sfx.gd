class_name Sfx
extends Node
## Placeholder sound effects, made in code at start-up (Alpha 0.8.2): no audio file, no outside asset, nothing to license
## (IP-RISK-LOG H, audio rows). Seven short sounds: tap, confirm, hit, kill, objective, victory, defeat; 16-bit mono at
## 22,050 Hz, peaks at or under 0.5 of full scale. The game is built to be played silently (many phones are muted): no sound
## carries information that is not also on screen. Sound is a device setting (settings.cfg [audio] sound, default on).
## App owns the one Sfx node (never a static var: nodes in static vars crash at exit).

const RATE := 22050
const NAMES := ["tap", "confirm", "hit", "kill", "objective", "victory", "defeat"]
const PLAYERS := 4
const VOLUME_DB := -10.0

var on := true
var streams: Dictionary = {}
var played: Array = []          # the names played while on (last 200), for tests
var _players: Array = []
var _next := 0


func _ready() -> void:
	for n in NAMES:
		streams[n] = Sfx.make(n)
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


func play(sound_name: String) -> bool:
	if not on or not streams.has(sound_name) or _players.is_empty():
		return false
	played.append(sound_name)
	if played.size() > 200:
		played.pop_front()
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = streams[sound_name]
	p.play()
	return true


## The samples of one sound (floats in -1..1).
static func samples(sound_name: String) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	match sound_name:
		"tap":
			_tone(buf, 0.0, 0.035, 1400.0, 1400.0, 0.35, 90.0, "sine")
		"confirm":
			_tone(buf, 0.0, 0.07, 660.0, 660.0, 0.3, 30.0, "sine")
			_tone(buf, 0.06, 0.1, 990.0, 990.0, 0.3, 25.0, "sine")
		"hit":
			_noise(buf, 0.0, 0.06, 0.25, 60.0)
			_tone(buf, 0.0, 0.07, 190.0, 140.0, 0.22, 40.0, "sine")
		"kill":
			_noise(buf, 0.0, 0.025, 0.18, 120.0)
			_tone(buf, 0.0, 0.2, 720.0, 240.0, 0.3, 12.0, "tri")
		"objective":
			for f in [392.0, 494.0, 587.0]:
				_tone(buf, 0.0, 0.5, f, f, 0.14, 5.0, "sine")
		"victory":
			var notes := [523.0, 659.0, 784.0, 1047.0]
			for i in notes.size():
				_tone(buf, 0.11 * float(i), 0.3 if i == 3 else 0.12, notes[i], notes[i], 0.28, 8.0, "tri")
		"defeat":
			var low := [392.0, 330.0, 262.0]
			for j in low.size():
				_tone(buf, 0.18 * float(j), 0.4 if j == 2 else 0.19, low[j], low[j], 0.26, 6.0, "tri")
	return buf


static func _grow(buf: PackedFloat32Array, n: int) -> void:
	if buf.size() < n:
		var old := buf.size()
		buf.resize(n)
		for i in range(old, n):
			buf[i] = 0.0


## A tone from t0 for dur seconds, sliding from f0 to f1 Hz, amplitude amp with an exponential decay (per second) and a 3 ms ramp in.
static func _tone(buf: PackedFloat32Array, t0: float, dur: float, f0: float, f1: float, amp: float, decay: float, wave: String) -> void:
	var a := int(t0 * RATE)
	var n := int(dur * RATE)
	_grow(buf, a + n)
	var ph := 0.0
	for i in n:
		var x := float(i) / float(RATE)
		var f := lerpf(f0, f1, float(i) / float(n))
		ph += f / float(RATE)
		var v := sin(TAU * ph) if wave == "sine" else (2.0 * absf(2.0 * (ph - floorf(ph + 0.5))) - 1.0)
		var env := amp * exp(-decay * x) * minf(1.0, x / 0.003) * minf(1.0, (dur - x) / 0.004)
		buf[a + i] += v * env


## Noise (a fixed linear congruential sequence, so the sound is the same every start) with a fast decay.
static func _noise(buf: PackedFloat32Array, t0: float, dur: float, amp: float, decay: float) -> void:
	var a := int(t0 * RATE)
	var n := int(dur * RATE)
	_grow(buf, a + n)
	var s := 12345
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var v := float(s) / float(0x7fffffff) * 2.0 - 1.0
		buf[a + i] += v * amp * exp(-decay * float(i) / float(RATE))


static func make(sound_name: String) -> AudioStreamWAV:
	var f := samples(sound_name)
	var bytes := PackedByteArray()
	bytes.resize(f.size() * 2)
	for i in f.size():
		bytes.encode_s16(i * 2, int(clampf(f[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
