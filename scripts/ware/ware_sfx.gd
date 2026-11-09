extends Node

## Sons do Atelier Ware gerados em código (nada de arquivo de áudio): onda
## quadrada, triângulo, seno e ruído com envelope, no clima 8 bits.
## Qualquer script toca com `WareSfx.play("moeda")`; quem toca é o nó deste
## script que estiver na cena (o runner e o menu criam um). Sem nó, como nos
## testes, a chamada não faz nada.

const RATE := 22050
const VOICES := 12
const BASE_DB := -9.0
const MUSIC_DB := -16.0
const MUSIC_RATE := 16000
## Notas dos sinos (dó maior, do dó ao ré da oitava de cima).
const BELL_NOTES := [523.25, 587.33, 659.25, 698.46, 783.99, 880.0, 987.77]

static var _cache: Dictionary = {}
static var _music: AudioStreamWAV
## Tecla M liga/desliga a música (vale para o menu e para os jogos).
static var music_muted := false
## Velocidade pedida por último (vale ao desmutar no meio de um jogo).
static var _wanted_pitch := 1.0

var _players: Array = []
var _next := 0
var _music_player: AudioStreamPlayer


func _ready() -> void:
	add_to_group("ware_sfx")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _index in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.volume_db = BASE_DB
		add_child(player)
		_players.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_DB
	add_child(_music_player)


## Música de fundo em laço (gerada uma vez). `pitch` acelera a música, como o
## WarioWare faz a cada nível.
static func music(pitch := 1.0, volume_db := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var node := tree.get_first_node_in_group("ware_sfx")
	if node != null:
		node._start_music(pitch, volume_db)


static func stop_music() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var node := tree.get_first_node_in_group("ware_sfx")
	if node != null and node._music_player != null:
		node._music_player.stop()


static func toggle_music() -> void:
	music_muted = not music_muted
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var node := tree.get_first_node_in_group("ware_sfx")
	if node != null and node._music_player != null:
		node._music_player.stream_paused = music_muted
		if not music_muted:
			node._music_player.pitch_scale = clampf(_wanted_pitch, 0.5, 2.0)
			if not node._music_player.playing:
				node._start_music(_wanted_pitch, 0.0)


func _start_music(pitch: float, volume_db: float) -> void:
	_wanted_pitch = pitch
	if music_muted:
		return
	if _music == null:
		_music = _build_music()
	_music_player.volume_db = MUSIC_DB + volume_db
	_music_player.pitch_scale = clampf(pitch, 0.5, 2.0)
	if _music_player.stream != _music or not _music_player.playing:
		_music_player.stream = _music
		_music_player.play()


## Quatro compassos em dó maior (C, Am, F, G) a 132 bpm: baixo em colcheias
## (quadrada), arpejo em semicolcheias (triângulo) e chimbal de ruído.
static func _build_music() -> AudioStreamWAV:
	var bpm := 132.0
	var sixteenth := 60.0 / bpm / 4.0
	var chords := [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
	var arp := [0, 1, 2, 1, 0, 2, 1, 2, 0, 1, 2, 1, 2, 1, 0, -1]
	var steps := 16 * chords.size()
	var step_samples := int(sixteenth * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(steps * step_samples)
	var lead_phase := 0.0
	var bass_phase := 0.0
	for step in range(steps):
		var chord: Array = chords[step / 16]
		var note: int = arp[step % 16]
		var lead := 0.0 if note < 0 else float(chord[note]) * 2.0
		var bass := float(chord[0]) * 0.5
		for sample in range(step_samples):
			var index := step * step_samples + sample
			var t := float(sample) / step_samples
			var value := 0.0
			if lead > 0.0:
				lead_phase += lead / MUSIC_RATE
				var cycle := fmod(lead_phase, 1.0)
				value += (4.0 * absf(cycle - 0.5) - 1.0) * 0.16 * (1.0 - t * 0.7)
			if step % 2 == 0 or sample < step_samples / 2:
				bass_phase += bass / MUSIC_RATE
				value += (1.0 if fmod(bass_phase, 1.0) < 0.5 else -1.0) * 0.05 * (1.0 - t * 0.4)
			if step % 4 == 2 and t < 0.25:
				value += (randf() * 2.0 - 1.0) * 0.05 * (1.0 - t * 4.0)
			if step % 4 == 0 and t < 0.4:
				value += sin(TAU * (90.0 - t * 120.0) * t * sixteenth) * 0.18 * (1.0 - t * 2.5)
			out[index] = value
	var data := PackedByteArray()
	data.resize(out.size() * 2)
	for index in range(out.size()):
		data.encode_s16(index * 2, int(clampf(out[index], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUSIC_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = out.size()
	return wav


static func play(sound_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var node := tree.get_first_node_in_group("ware_sfx")
	if node != null:
		node._play(sound_name, pitch, volume_db)


func _play(sound_name: String, pitch: float, volume_db: float) -> void:
	var stream := sound(sound_name)
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.volume_db = BASE_DB + volume_db
	player.play()


static func sound(sound_name: String) -> AudioStreamWAV:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var samples := _build(sound_name)
	if samples.is_empty():
		return null
	var stream := _to_wav(samples)
	_cache[sound_name] = stream
	return stream


static func _build(sound_name: String) -> PackedFloat32Array:
	if sound_name.begins_with("bell"):
		var note := clampi(int(sound_name.substr(4)), 1, BELL_NOTES.size())
		return _bell(BELL_NOTES[note - 1])
	match sound_name:
		"step":
			return _tone(520.0, 0.03, "square", 0.10)
		"bump":
			return _layer(_tone(0.0, 0.08, "noise", 0.25), _tone(110.0, 0.14, "square", 0.22, 60.0))
		"push":
			return _layer(_smooth(_tone(0.0, 0.09, "noise", 0.3), 6), _tone(140.0, 0.09, "triangle", 0.25, 100.0))
		"coin":
			return _join([_tone(988.0, 0.05, "square", 0.14), _tone(1319.0, 0.18, "square", 0.14)])
		"jump":
			return _tone(260.0, 0.17, "square", 0.13, 760.0)
		"land":
			return _smooth(_tone(0.0, 0.06, "noise", 0.3), 4)
		"fall":
			return _tone(700.0, 0.55, "square", 0.12, 70.0)
		"shoot":
			return _layer(_tone(0.0, 0.12, "noise", 0.22), _tone(900.0, 0.13, "square", 0.12, 170.0))
		"boom":
			return _layer(_smooth(_tone(0.0, 0.5, "noise", 0.32), 3), _tone(90.0, 0.45, "sine", 0.32, 35.0))
		"paint":
			return _smooth(_tone(0.0, 0.11, "noise", 0.32), 10)
		"turn":
			return _tone(320.0, 0.025, "square", 0.08)
		"beam":
			return _layer(_tone(1500.0, 0.2, "square", 0.10, 380.0), _tone(0.0, 0.1, "noise", 0.12))
		"crystal":
			return _join([_tone(1568.0, 0.05, "triangle", 0.22), _tone(2093.0, 0.22, "triangle", 0.2)])
		"bubble":
			return _tone(280.0, 0.12, "sine", 0.3, 950.0)
		"deliver":
			return _join([_tone(523.0, 0.07, "sine", 0.3), _tone(784.0, 0.2, "sine", 0.3)])
		"hit":
			return _layer(_tone(0.0, 0.07, "noise", 0.3), _tone(220.0, 0.09, "square", 0.16, 90.0))
		"bones":
			return _join([_tone(0.0, 0.02, "noise", 0.25), _silence(0.03), _tone(0.0, 0.02, "noise", 0.2), _silence(0.04), _tone(0.0, 0.03, "noise", 0.15)])
		"win":
			return _join([_tone(523.0, 0.07, "square", 0.13), _tone(659.0, 0.07, "square", 0.13), _tone(784.0, 0.07, "square", 0.13), _tone(1047.0, 0.28, "square", 0.13)])
		"fail":
			return _join([_tone(392.0, 0.11, "square", 0.13), _tone(330.0, 0.11, "square", 0.13), _tone(262.0, 0.34, "square", 0.13, 190.0)])
		"life":
			return _join([_tone(330.0, 0.14, "triangle", 0.3), _tone(220.0, 0.32, "triangle", 0.3, 160.0)])
		"levelup":
			return _join([_tone(523.0, 0.06, "square", 0.12), _tone(659.0, 0.06, "square", 0.12), _tone(784.0, 0.06, "square", 0.12), _tone(1047.0, 0.06, "square", 0.12), _tone(1319.0, 0.3, "square", 0.12)])
		"tick":
			return _tone(1200.0, 0.02, "square", 0.09)
		"tock":
			return _tone(900.0, 0.02, "square", 0.09)
		"intro":
			return _join([_tone(784.0, 0.07, "square", 0.12), _tone(1047.0, 0.14, "square", 0.12)])
		"open":
			return _tone(380.0, 0.22, "sine", 0.25, 950.0)
		"close":
			return _tone(950.0, 0.22, "sine", 0.25, 380.0)
		"click":
			return _tone(700.0, 0.02, "square", 0.08)
		"over":
			return _join([_tone(392.0, 0.2, "triangle", 0.3), _tone(370.0, 0.2, "triangle", 0.3), _tone(349.0, 0.2, "triangle", 0.3), _tone(330.0, 0.6, "triangle", 0.3, 300.0)])
	return PackedFloat32Array()


## Uma nota com envelope: ataque curto e decaimento linear até o fim.
static func _tone(frequency: float, seconds: float, wave: String, volume: float, to_frequency := -1.0) -> PackedFloat32Array:
	var count := maxi(int(seconds * RATE), 1)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	var attack := 0.004 * RATE
	for index in range(count):
		var progress := float(index) / count
		var current := frequency if to_frequency < 0.0 else lerpf(frequency, to_frequency, progress)
		phase += current / RATE
		var cycle := fmod(phase, 1.0)
		var value := 0.0
		match wave:
			"square":
				value = 1.0 if cycle < 0.5 else -1.0
			"triangle":
				value = 4.0 * absf(cycle - 0.5) - 1.0
			"noise":
				value = randf() * 2.0 - 1.0
			_:
				value = sin(phase * TAU)
		var envelope := minf(1.0, index / attack) * (1.0 - progress)
		out[index] = value * envelope * volume
	return out


## Sino: fundamental + parciais inarmônicos com decaimento exponencial.
static func _bell(frequency: float) -> PackedFloat32Array:
	var seconds := 1.1
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var partials := [[1.0, 0.55], [2.0, 0.22], [2.76, 0.14], [5.4, 0.06]]
	for index in range(count):
		var time := float(index) / RATE
		var value := 0.0
		for partial in partials:
			value += sin(TAU * frequency * float(partial[0]) * time) * float(partial[1]) * exp(-time * (2.5 + float(partial[0])))
		out[index] = value * minf(1.0, index / (0.002 * RATE)) * 0.45
	return out


static func _silence(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	return out


static func _join(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for part in parts:
		out.append_array(part)
	return out


static func _layer(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for index in range(other.size()):
		out[index] += other[index]
	return out


## Média móvel: tira o chiado agudo do ruído (vira "tum", "chuá").
static func _smooth(samples: PackedFloat32Array, width: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(samples.size())
	var sum := 0.0
	for index in range(samples.size()):
		sum += samples[index]
		if index >= width:
			sum -= samples[index - width]
		out[index] = sum / width * 1.6
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for index in range(samples.size()):
		data.encode_s16(index * 2, int(clampf(samples[index], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
