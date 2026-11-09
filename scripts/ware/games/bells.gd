extends "res://scripts/ware/microgame.gd"

## SINOS: toque a melodia. Tocar Sino usa a intensidade como o número do sino.
## Nota errada estraga a música; completou a melodia, ganhou. Notas iguais
## seguidas pedem Duplicar; trechos que se repetem pedem Portal.

const BELL := [
	"....kk....",
	"...kyyk...",
	"..kyyyyk..",
	"..kywyyk..",
	".kyywyyyk.",
	".kyywyyyk.",
	".kyyyyyyk.",
	"kyyyyyyyyk",
	"kkkkkkkkkk",
	"....kk....",
]

const NOTE := [
	"..kk",
	"..kw",
	"..k.",
	"..k.",
	"kkk.",
	"kkk.",
]

var bell_count := 5
var melody: Array = []
## Para a solução: trecho que se repete e quantas vezes (laço com Portal).
var _phrase: Array = []
var _phrase_repeats := 1
var _progress := 0
var _swing: Array = []
var _wrong := -1
## Notinhas que sobem do sino tocado: {pos, age, color}.
var _floating: Array = []
## Demonstração da melodia no começo (nota que está tocando; -1 = nenhuma).
var _demo := -1
var _demo_run := 0


func _init() -> void:
	title = "SINOS"
	instruction = "TOQUE A MELODIA!"
	runes = ["BELL", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"BELL": 1}
	names = {"BELL": "Tocar sino: toca o sino com o número da intensidade"}


func build(new_level: int) -> void:
	bell_count = 5 if new_level <= 2 else 7
	max_intensity = {"BELL": bell_count}
	limits = {}
	_phrase_repeats = 1
	match clampi(new_level, 1, 5):
		1:
			_phrase = _random_notes(3)
			objective = "Toque os sinos na ordem da partitura. A intensidade é o número do sino."
		2:
			_phrase = _random_notes(5)
			objective = "Toque os sinos na ordem da partitura. A intensidade é o número do sino."
		3:
			_phrase = []
			for _run in range(3):
				var note := rng.randi_range(1, bell_count)
				while not _phrase.is_empty() and _phrase[-1] == note:
					note = rng.randi_range(1, bell_count)
				for _repeat in range(rng.randi_range(2, 3)):
					_phrase.append(note)
			limits = {"BELL": 3}
			objective = "Só 3 sinos no ritual! Duplicar faz a próxima runa tocar de novo."
		4:
			_phrase = _random_notes(2)
			_phrase_repeats = 4
			limits = {"BELL": 2}
			objective = "Só 2 sinos! O trecho se repete: Fim de portal no começo, Portal no fim."
		_:
			_phrase = _random_notes(3)
			_phrase_repeats = 3
			limits = {"BELL": 3}
			objective = "Só 3 sinos! Descubra o trecho que se repete e use o Portal."
	melody.clear()
	for _round in range(_phrase_repeats):
		melody.append_array(_phrase)
	_swing.resize(bell_count + 1)


func _random_notes(count: int) -> Array:
	var notes: Array = []
	while notes.size() < count:
		var note := rng.randi_range(1, bell_count)
		if notes.is_empty() or notes[-1] != note:
			notes.append(note)
	return notes


func reset_world() -> void:
	_progress = 0
	_wrong = -1
	_floating.clear()
	for index in range(_swing.size()):
		_swing[index] = 0.0
	fail_reason = ""
	queue_redraw()


## Toca a melodia uma vez para o jogador ouvir (para se ele começar a tocar).
func start_round() -> void:
	_demo_run += 1
	var run := _demo_run
	await wait(0.2)
	for index in range(melody.size()):
		if run != _demo_run or not is_inside_tree():
			return
		_demo = index
		var note := int(melody[index])
		sfx("bell%d" % note, 1.0, -4.0)
		_floating.append({"pos": _bell_hang(note) + Vector2(randf_range(-10.0, 10.0), 40.0), "age": 0.0, "color": ArenaPixelArt.tint(0.6)})
		var tween := create_tween()
		tween.tween_method(_ring.bind(note), 0.0, 1.0, 0.3)
		await get_tree().create_timer(0.38).timeout
	if run == _demo_run:
		_demo = -1


func execute(actions: Array, _output: Array) -> bool:
	_demo_run += 1
	_demo = -1
	for entry in actions:
		if str(entry["kind"]) != "BELL":
			continue
		var note := int(entry["intensity"])
		if note < 1 or note > bell_count:
			fail_reason = "Não existe o sino %d" % note
			return false
		sfx("bell%d" % note)
		var right := note == int(melody[_progress])
		_floating.append({"pos": _bell_hang(note) + Vector2(randf_range(-10.0, 10.0), 40.0), "age": 0.0, "color": GOLD if right else BAD})
		await animate(_ring.bind(note), 0.0, 1.0, 0.28)
		if not right:
			_wrong = note
			sfx("bump")
			kick(5.0)
			queue_redraw()
			await wait(0.25)
			fail_reason = "Nota errada: tocou %d, era %d" % [note, int(melody[_progress])]
			return false
		_progress += 1
		if _progress == melody.size():
			await wait(0.35)
			burst(Vector2(area.get_center().x, area.position.y + 42.0), GOOD, 20, 200.0, 0.7)
			return true
	fail_reason = "A melodia ficou pela metade"
	return false


func _process(delta: float) -> void:
	for note in _floating:
		note["age"] = float(note["age"]) + delta
		note["pos"] = (note["pos"] as Vector2) + Vector2(sin(float(note["age"]) * 8.0) * 30.0 * delta, -70.0 * delta)
	_floating = _floating.filter(func(note: Dictionary) -> bool: return float(note["age"]) < 1.2)


func _bell_hang(note: int) -> Vector2:
	var beam_y := area.position.y + 150.0
	var spacing := minf(150.0, (area.size.x - 120.0) / bell_count)
	var first_x := area.get_center().x - spacing * (bell_count - 1) * 0.5
	return Vector2(first_x + (note - 1) * spacing, beam_y)


func _ring(value: float, note: int) -> void:
	_swing[note] = sin(value * TAU * 1.5) * (1.0 - value)


func solution() -> Dictionary:
	var actions: Array = []
	for note in melody:
		actions.append(action("BELL", int(note)))
	return {"actions": actions, "output": []}


func solution_program() -> Array:
	var program: Array = []
	if _phrase_repeats > 1:
		program.append(action("WARP_ENDPOINT", 1))
	var index := 0
	while index < _phrase.size():
		var run := 1
		while index + run < _phrase.size() and _phrase[index + run] == _phrase[index]:
			run += 1
		for _extra in range(run - 1):
			program.append(action("DUPLICATE", 0))
		program.append(action("BELL", int(_phrase[index])))
		index += run
	if _phrase_repeats > 1:
		program.append(action("WARP", 1))
	return program


func preview_text(actions: Array, _output: Array) -> String:
	var notes: Array = []
	for entry in actions.slice(0, 12):
		notes.append(str(entry["intensity"]))
	return "Notas: " + " ".join(notes) + (" ..." if actions.size() > 12 else "")


func _draw() -> void:
	_draw_backdrop()
	# Partitura no alto: uma caixinha por nota.
	var box := 44.0
	var gap := 8.0
	var row_width := melody.size() * (box + gap) - gap
	var start_x := snappedf(area.get_center().x - row_width * 0.5, PX)
	var top := area.position.y + 20.0
	for index in range(melody.size()):
		var rect := Rect2(Vector2(start_x + index * (box + gap), top), Vector2(box, box))
		var color := ArenaPixelArt.tint(0.45)
		if index < _progress:
			color = GOOD
		elif index == _progress and _wrong >= 0:
			color = BAD
		elif index == _progress:
			color = ArenaPixelArt.tint(1.0)
		if index == _demo:
			color = GOLD
			draw_rect(rect.grow(-PX * 2.0), Color(GOLD, 0.25))
		frame_rect(rect, color)
		text(rect.position + Vector2(0.0, 31.0), str(melody[index]), color, true, HORIZONTAL_ALIGNMENT_CENTER, box)
	# Viga e sinos.
	var beam_y := area.position.y + 150.0
	var spacing := minf(150.0, (area.size.x - 120.0) / bell_count)
	var first_x := area.get_center().x - spacing * (bell_count - 1) * 0.5
	draw_rect(Rect2(Vector2(first_x - spacing * 0.6, beam_y - PX * 3.0), Vector2(spacing * (bell_count - 1) + spacing * 1.2, PX * 3.0)), Color("6b4a2a"))
	var pixel := 6.0
	for note in range(1, bell_count + 1):
		var hang := Vector2(first_x + (note - 1) * spacing, beam_y)
		var swing: float = _swing[note] if note < _swing.size() and _swing[note] != null else 0.0
		var offset := Vector2(swing * 18.0, absf(swing) * -4.0)
		draw_rect(Rect2(hang - Vector2(PX * 0.5, 0.0), Vector2(PX, 24.0)), WALL)
		var tint := Color("ffcf4a") if note != _wrong else BAD
		stamp(BELL, {"k": Color("6b4a10"), "y": tint, "w": Color("fff2b0")}, (hang + Vector2(-pixel * 5.0, 24.0) + offset).snapped(Vector2(PX, PX)), pixel)
		if absf(swing) > 0.05:
			for wave in range(3):
				var at := hang + Vector2(-60.0 + wave * 6.0, 70.0 - wave * 10.0)
				draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX)), Color(GOLD, absf(swing)))
				draw_rect(Rect2((hang + Vector2(56.0 - wave * 6.0, 70.0 - wave * 10.0)).snapped(Vector2(PX, PX)), Vector2(PX, PX)), Color(GOLD, absf(swing)))
		text(hang + Vector2(-20.0, 110.0), str(note), ArenaPixelArt.tint(0.9), true, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	for note in _floating:
		var fade := 1.0 - float(note["age"]) / 1.2
		stamp(NOTE, {"k": Color(note["color"], fade), "w": Color(1, 1, 1, fade)}, (note["pos"] as Vector2).snapped(Vector2(3.0, 3.0)), 3.0)
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Torre do sino: janelas em arco com vitral.
	var colors := [Color("e8452c"), Color("4a8ae8"), Color("ffcf4a"), Color("7be08a")]
	for index in range(3):
		var window := Rect2(Vector2(area.position.x + area.size.x * (0.2 + index * 0.3) - 40.0, area.position.y + 300.0), Vector2(80.0, 150.0))
		draw_rect(window, Color(0.03, 0.05, 0.11, 0.9))
		for pane in range(8):
			var cell := Rect2(window.position + Vector2((pane % 2) * 40.0, 30.0 + (pane / 2) * 30.0), Vector2(36.0, 26.0))
			draw_rect(cell, Color(colors[(pane + index) % colors.size()], 0.12 + 0.04 * sin(clock + pane)))
		# Arco: degraus de pixel no alto da janela.
		for step in range(5):
			var inset := float(step + 1) * PX * 2.0
			draw_rect(Rect2(window.position + Vector2(inset, -PX * 2.0 * (step + 1)), Vector2(80.0 - inset * 2.0, PX * 2.0)), Color(0.03, 0.05, 0.11, 0.9))
