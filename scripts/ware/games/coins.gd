extends "res://scripts/ware/microgame.gd"

## MOEDAS: pegue todas as moedas. Os desenhos de moedas se repetem e, a partir
## do nível 2, as setas são poucas: o jeito é repetir o caminho com um Portal
## (Fim de portal no começo, Portal no fim). Pegou a última, ganhou na hora,
## mesmo que o laço continue.

const COLUMNS := 11
const ROWS := 7
const COIN := [
	"..kkkk..",
	".kyyyyk.",
	"kyywwyyk",
	"kyywyyyk",
	"kyywyyyk",
	"kyyyyyyk",
	".kyyyyk.",
	"..kkkk..",
]

var start := Vector2i.ZERO
var coins: Array = []
## Trecho que se repete (para a solução com laço): [{kind, intensity}].
var _pattern: Array = []
var _repeats := 1
var _taken := {}
var _cell := Vector2i.ZERO
var _actor := Vector2.ZERO
var _layout: Dictionary = {}
var _spin := 0.0
var _walking := false
var _facing_left := false
var _popup := 0.0


func _init() -> void:
	title = "MOEDAS"
	instruction = "PEGUE AS MOEDAS!"
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1}


func build(new_level: int) -> void:
	limits = {}
	_layout = grid_layout(COLUMNS, ROWS, 64.0)
	match clampi(new_level, 1, 5):
		1:
			var row := rng.randi_range(1, ROWS - 2)
			start = Vector2i(0, row)
			_pattern = [action("MOVE_RIGHT", rng.randi_range(5, COLUMNS - 1))]
			_repeats = 1
			objective = "Passe por todas as moedas. A intensidade da seta é quantas casas ela anda."
		2:
			start = Vector2i(0, 0)
			_pattern = [action("MOVE_RIGHT", 1), action("MOVE_DOWN", 1)]
			_repeats = ROWS - 1
			limits = {"MOVE_RIGHT": 1, "MOVE_DOWN": 1}
			objective = "Só 1 seta de cada. Repita o caminho: Fim de portal no começo e Portal no fim."
		3:
			start = Vector2i(0, ROWS - 1)
			_pattern = [action("MOVE_RIGHT", 2), action("MOVE_UP", 1)]
			_repeats = 5
			limits = {"MOVE_RIGHT": 1, "MOVE_UP": 1}
			objective = "Só 1 seta de cada. Use o Portal para repetir o degrau."
		4:
			start = Vector2i(0, 0)
			var width := rng.randi_range(5, COLUMNS - 2)
			_pattern = [action("MOVE_RIGHT", width), action("MOVE_DOWN", 1), action("MOVE_LEFT", width), action("MOVE_DOWN", 1)]
			_repeats = 3
			limits = {"MOVE_RIGHT": 1, "MOVE_DOWN": 2, "MOVE_LEFT": 1}
			objective = "Zigue-zague! Poucas setas: monte uma volta e repita com o Portal."
		_:
			start = Vector2i(0, 0)
			_pattern = [action("MOVE_RIGHT", 1), action("MOVE_RIGHT", 1), action("MOVE_DOWN", 1)]
			_repeats = 5
			limits = {"MOVE_RIGHT": 1, "MOVE_DOWN": 1}
			objective = "Duas casas para o lado, uma na vertical, e de novo. Uma seta de cada: Duplicar e Portal ajudam."
	# Espelha o desenho ao acaso (mesmo desafio, outra cara).
	if rng.randf() < 0.5:
		start.x = COLUMNS - 1 - start.x
		_mirror({"MOVE_RIGHT": "MOVE_LEFT", "MOVE_LEFT": "MOVE_RIGHT"})
	if rng.randf() < 0.5:
		start.y = ROWS - 1 - start.y
		_mirror({"MOVE_UP": "MOVE_DOWN", "MOVE_DOWN": "MOVE_UP"})
	# As moedas ficam no caminho do padrão repetido (sem a casa inicial).
	coins.clear()
	var cell := start
	for _round in range(_repeats):
		for entry in _pattern:
			var direction := direction_of(str(entry["kind"]))
			for _step in range(int(entry["intensity"])):
				cell += direction
				if cell.x < 0 or cell.y < 0 or cell.x >= COLUMNS or cell.y >= ROWS:
					break
				if not coins.has(cell):
					coins.append(cell)


func content_rect() -> Rect2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return Rect2(origin, Vector2(COLUMNS, ROWS) * tile).grow(24.0)


func _mirror(swap: Dictionary) -> void:
	for entry in _pattern:
		entry["kind"] = swap.get(entry["kind"], entry["kind"])
	var mirrored := {}
	for kind in limits:
		mirrored[swap.get(kind, kind)] = limits[kind]
	limits = mirrored


func reset_world() -> void:
	_walking = false
	_facing_left = false
	_cell = start
	_actor = Vector2(start)
	_taken.clear()
	fail_reason = ""
	queue_redraw()


func _process(delta: float) -> void:
	_spin += delta
	_popup = maxf(_popup - delta * 3.0, 0.0)


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var direction := direction_of(str(entry["kind"]))
		if direction == Vector2i.ZERO:
			continue
		if direction.x != 0:
			_facing_left = direction.x < 0
		for _step in range(maxi(int(entry["intensity"]), 0)):
			var next := _cell + direction
			if next.x < 0 or next.y < 0 or next.x >= COLUMNS or next.y >= ROWS:
				_walking = false
				var from_edge := Vector2(_cell)
				sfx("bump")
				kick(4.0)
				await animate(func(value: Vector2) -> void: _actor = value, from_edge, from_edge + Vector2(direction) * 0.4, 0.08)
				fail_reason = "Saiu do mapa"
				return false
			_walking = true
			var from := Vector2(_cell)
			_cell = next
			await animate(func(value: Vector2) -> void: _actor = value, from, Vector2(_cell), 0.09)
			if coins.has(_cell) and not _taken.has(_cell):
				_taken[_cell] = true
				# Cada moeda soa um pouco mais aguda: a sequência vira melodia.
				sfx("coin", 1.0 + 0.04 * mini(_taken.size(), 25))
				_popup = 1.0
				var origin: Vector2 = _layout["origin"]
				var tile: float = _layout["tile"]
				burst(cell_rect(origin, tile, _cell).get_center(), GOLD, 8, 90.0, 0.35)
				if _taken.size() == coins.size():
					_walking = false
					await wait(0.2)
					return true
			else:
				sfx("step", 0.9 + randf() * 0.2, -4.0)
	_walking = false
	fail_reason = "Faltaram %d moedas" % (coins.size() - _taken.size())
	return false


func solution() -> Dictionary:
	var actions: Array = []
	for _round in range(_repeats):
		for entry in _pattern:
			actions.append(action(str(entry["kind"]), int(entry["intensity"])))
	return {"actions": actions, "output": []}


func solution_program() -> Array:
	if limits.is_empty():
		return super.solution_program()
	# Laço: Fim de portal, o padrão (setas iguais seguidas viram Duplicar) e Portal.
	var program: Array = [action("WARP_ENDPOINT", 1)]
	var index := 0
	while index < _pattern.size():
		var entry: Dictionary = _pattern[index]
		if index + 1 < _pattern.size() and _pattern[index + 1]["kind"] == entry["kind"] and _pattern[index + 1]["intensity"] == entry["intensity"]:
			program.append(action("DUPLICATE", 0))
			index += 1
		program.append(action(str(entry["kind"]), int(entry["intensity"])))
		index += 1
	program.append(action("WARP", 1))
	return program


func preview_text(actions: Array, _output: Array) -> String:
	return "%d passos" % actions.reduce(func(total: int, entry: Dictionary) -> int: return total + int(entry["intensity"]), 0)


func _draw() -> void:
	_draw_backdrop()
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	for y in range(ROWS):
		for x in range(COLUMNS):
			draw_rect(cell_rect(origin, tile, Vector2i(x, y)), FLOOR if (x + y) % 2 == 0 else FLOOR_ALT)
	frame_rect(Rect2(origin - Vector2(PX, PX), Vector2(COLUMNS, ROWS) * tile + Vector2(PX, PX) * 2.0), WALL_DARK)
	var pixel := floorf(tile / 16.0)
	for index in range(coins.size()):
		var coin: Vector2i = coins[index]
		if _taken.has(coin):
			continue
		var bob := floorf(sin(_spin * 4.0 + index * 0.7) * 1.5) * pixel
		var top_left := origin + Vector2(coin) * tile + Vector2(tile - pixel * 8.0, tile - pixel * 8.0) * 0.5 + Vector2(0.0, bob)
		stamp(COIN, {"k": Color("8a5a10"), "y": GOLD, "w": Color("fff2b0")}, top_left.snapped(Vector2(pixel, pixel)), pixel)
	var feet := origin + (_actor + Vector2(0.5, 0.85)) * tile
	draw_skeleton(feet, maxf(floorf(tile / 24.0), 1.0), int(clock * (10.0 if _walking else 3.0)), _facing_left, _walking)
	draw_particles()
	var counter := "%d de %d moedas" % [_taken.size(), coins.size()]
	text(origin + Vector2(0.0, -12.0 - _popup * 4.0), counter, GOLD if _popup > 0.0 else ArenaPixelArt.tint(0.7), true)


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Brilhos de tesouro flutuando.
	for index in range(24):
		var drift := fmod(clock * (8.0 + index % 5 * 3.0) + index * 47.0, area.size.y)
		var at := Vector2(area.position.x + fmod(index * 173.0, area.size.x), area.end.y - drift)
		var twinkle := absf(sin(clock * 2.0 + index))
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX)), Color(GOLD, 0.15 * twinkle))
