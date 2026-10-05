extends Node
## Procedural sound effects and music, so the game ships with no audio files.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name := ""
const SONGS := {
	"world": [[62, 58, 60, 57], 2.6, false],
	"battle": [[57, 53, 55, 52], 1.6, true],
	"menu": [[50, 46, 48, 45], 3.2, false],
}

var volume := 0.8
var music_volume := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_build()


func play(name: String, pitch: float = 1.0) -> void:
	if not _sounds.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.volume_db = linear_to_db(volume)
			p.play()
			return


func music(name: String) -> void:
	if name == _music_name:
		return
	_music_name = name
	if name == "":
		_music.stop()
		return
	if not _sounds.has("music_" + name):
		var spec: Array = SONGS[name]
		_sounds["music_" + name] = _wav(_song(spec[0], spec[1], spec[2]), true)
	_music.stream = _sounds["music_" + name]
	_music.volume_db = linear_to_db(music_volume * 0.6)
	_music.play()


func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _noise_hit(sec: float, decay: float, lp: float, gain: float) -> PackedFloat32Array:
	var b := _buf(sec)
	var y := 0.0
	for i in b.size():
		var t := float(i) / RATE
		y += (randf_range(-1, 1) - y) * lp
		b[i] = y * exp(-t * decay) * gain
	return b


func _tone(freq: float, sec: float, decay: float, wave: String = "sin", gain: float = 0.5) -> PackedFloat32Array:
	var b := _buf(sec)
	for i in b.size():
		var t := float(i) / RATE
		var ph := fmod(t * freq, 1.0)
		var s := sin(TAU * ph)
		if wave == "sq":
			s = 1.0 if ph < 0.5 else -1.0
		elif wave == "tri":
			s = 4.0 * absf(ph - 0.5) - 1.0
		b[i] = s * exp(-t * decay) * gain * minf(1.0, t * 400.0)
	return b


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float = 0.0) -> PackedFloat32Array:
	var off := int(offset * RATE)
	var out := a.duplicate()
	if out.size() < b.size() + off:
		out.resize(b.size() + off)
	for i in b.size():
		out[i + off] += b[i]
	return out


func _build() -> void:
	_sounds["hit"] = _wav(_mix(_noise_hit(0.18, 22, 0.5, 0.9), _tone(110, 0.15, 25, "sin", 0.6)))
	_sounds["clang"] = _wav(_mix(_noise_hit(0.12, 30, 0.9, 0.5), _mix(_tone(820, 0.3, 12, "sin", 0.25), _tone(1230, 0.3, 14, "sin", 0.15))))
	var sw := _buf(0.22)
	var y := 0.0
	for i in sw.size():
		var t := float(i) / RATE
		y += (randf_range(-1, 1) - y) * (0.05 + t * 1.2)
		sw[i] = y * sin(PI * t / 0.22) * 0.9
	_sounds["swing"] = _wav(sw)
	_sounds["bow"] = _wav(_mix(_tone(260, 0.2, 18, "tri", 0.5), _noise_hit(0.05, 60, 0.6, 0.3)))
	_sounds["thud"] = _wav(_mix(_noise_hit(0.3, 12, 0.08, 1.2), _tone(60, 0.3, 10, "sin", 0.6)))
	var bite := _mix(_noise_hit(0.1, 30, 0.7, 0.6), _tone(300, 0.1, 30, "sq", 0.15))
	_sounds["bite"] = _wav(bite)
	_sounds["step"] = _wav(_noise_hit(0.05, 70, 0.3, 0.35))
	_sounds["click"] = _wav(_tone(880, 0.05, 60, "sq", 0.18))
	_sounds["coin"] = _wav(_mix(_tone(988, 0.1, 25, "sq", 0.15), _tone(1319, 0.25, 12, "sq", 0.15), 0.07))
	var horn := PackedFloat32Array()
	for n in [[392, 0.0], [523, 0.18], [659, 0.36], [784, 0.54]]:
		horn = _mix(horn, _tone(n[0], 0.7, 4, "sq", 0.12), n[1])
	_sounds["victory"] = _wav(horn)
	var sad := PackedFloat32Array()
	for n in [[392, 0.0], [349, 0.3], [311, 0.6], [262, 0.9]]:
		sad = _mix(sad, _tone(n[0], 0.8, 3, "tri", 0.25), n[1])
	_sounds["defeat"] = _wav(sad)
	_sounds["buff"] = _wav(_mix(_tone(523, 0.4, 6, "sq", 0.1), _mix(_tone(659, 0.4, 6, "sq", 0.1), _tone(784, 0.5, 5, "sq", 0.1), 0.08), 0.04))


func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


## A short dark loop: bass drone per chord + arpeggio, optional drum pulse.
func _song(roots: Array, bar: float, drums: bool) -> PackedFloat32Array:
	var total := bar * roots.size()
	var b := _buf(total)
	var minor := [0, 3, 7, 12, 7, 3, 0, -5]
	var step := bar / 8.0
	for i in b.size():
		var t := float(i) / RATE
		var ci := int(t / bar) % roots.size()
		var tb := fmod(t, bar)
		var root: float = roots[ci]
		var bass_f := _midi(root - 24)
		var v := sin(TAU * bass_f * t) * 0.22 + sin(TAU * bass_f * 2.0 * t) * 0.06
		var si := int(tb / step)
		var ts := fmod(tb, step)
		var nf := _midi(root + minor[si % 8])
		var ph := fmod(t * nf, 1.0)
		v += (4.0 * absf(ph - 0.5) - 1.0) * 0.10 * exp(-ts * 5.0)
		if drums:
			var beat := fmod(t, bar / 4.0)
			v += sin(TAU * 55.0 * beat * (1.0 - beat)) * exp(-beat * 18.0) * 0.35
		v *= minf(1.0, t * 40.0) * minf(1.0, (total - t) * 40.0)
		b[i] = v
	return b
