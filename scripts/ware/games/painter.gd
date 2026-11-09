extends "res://scripts/ware/microgame.gd"

## PINTOR: copie o desenho do modelo, como uma tartaruga do Logo. Pintar
## molha o pincel na cor da intensidade (1 vermelho, 2 azul, 3 ouro) e pinta a
## casa onde ele está; com o pincel molhado, cada casa por onde ele anda
## também é pintada. Pintar 0 levanta o pincel (andar sem pintar). Pintar uma
## casa que no modelo é de outra cor (ou vazia) estraga o quadro.
## Os desenhos são feitos de traços (linhas retas emendadas).

const PAINTS := [Color("e8452c"), Color("4a8ae8"), Color("ffcf4a")]
const COLOR_NAMES := ["vermelho", "azul", "ouro"]

var size_cells := 5
## Vector2i -> cor (1..3) do desenho alvo.
var target: Dictionary = {}
## Traços do modelo: [{"color": c, "start": Vector2i, "moves": [Vector2i passo a passo]}].
var strokes: Array = []
var _painted: Dictionary = {}
var _cell := Vector2i.ZERO
var _brush := Vector2.ZERO
var _layout: Dictionary = {}
var _model_layout: Dictionary = {}
var _wrong := Vector2i(-1, -1)
var _dab := 0.0
## Cor no pincel (0 = levantado).
var _ink := 0


func _init() -> void:
	title = "PINTOR"
	instruction = "COPIE O DESENHO!"
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "PAINT", "DUPLICATE"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1, "PAINT": 1}
	max_intensity = {"PAINT": 3}
	names = {"PAINT": "Pintar: molha o pincel na cor da intensidade (1 vermelho, 2 azul, 3 ouro) e pinta onde andar. 0 levanta o pincel"}
	objective = "Pintar molha o pincel (1 vermelho, 2 azul, 3 ouro): ele pinta a casa e tudo por onde andar. Pintar 0 levanta o pincel."


func build(new_level: int) -> void:
	size_cells = 5 if new_level <= 2 else 6
	var colors := 1 if new_level <= 2 else (2 if new_level <= 4 else 3)
	var stroke_count := 1 if new_level <= 1 else (2 if new_level <= 4 else 3)
	var segments := 2 if new_level <= 2 or new_level >= 5 else 3
	for _attempt in range(200):
		if _try_strokes(stroke_count, segments, colors):
			break
	var canvas_area := Rect2(area.position, Vector2(area.size.x * 0.62, area.size.y))
	var model_area := Rect2(area.position + Vector2(area.size.x * 0.66, area.size.y * 0.2), Vector2(area.size.x * 0.3, area.size.y * 0.6))
	_layout = _fit(canvas_area, 72.0)
	_model_layout = _fit(model_area, 40.0)


## Traços aleatórios que não pisam em casa de outra cor nem no canto de
## partida do pincel com cor diferente.
func _try_strokes(stroke_count: int, segments: int, colors: int) -> bool:
	target.clear()
	strokes.clear()
	var last_color := 0
	for _stroke in range(stroke_count):
		var color := rng.randi_range(1, colors)
		if colors > 1 and color == last_color:
			color = (color % colors) + 1
		last_color = color
		var start := Vector2i(rng.randi_range(0, size_cells - 1), rng.randi_range(0, size_cells - 1))
		var cells: Array = [start]
		var moves: Array = []
		var cursor := start
		var previous := Vector2i.ZERO
		for _segment in range(segments):
			var options: Array = []
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if direction != previous and direction != -previous:
					options.append(direction)
			var direction: Vector2i = options[rng.randi_range(0, options.size() - 1)]
			var length := rng.randi_range(1, 3)
			for _step in range(length):
				var next: Vector2i = cursor + direction
				if next.x < 0 or next.y < 0 or next.x >= size_cells or next.y >= size_cells:
					break
				cursor = next
				cells.append(cursor)
				moves.append(direction)
			previous = direction
		if moves.size() < 2:
			return false
		for cell in cells:
			if target.has(cell) and int(target[cell]) != color:
				return false
		for cell in cells:
			target[cell] = color
		strokes.append({"color": color, "start": start, "moves": moves})
	return target.size() >= 3


func _fit(rect: Rect2, max_tile: float) -> Dictionary:
	var tile := floorf(minf(minf(rect.size.x, rect.size.y) / size_cells, max_tile) / PX) * PX
	var origin := (rect.position + (rect.size - Vector2(size_cells, size_cells) * tile) * 0.5).snapped(Vector2(PX, PX))
	return {"origin": origin, "tile": tile}


func content_rect() -> Rect2:
	var a: Rect2 = Rect2(_layout["origin"], Vector2(size_cells, size_cells) * float(_layout["tile"]))
	var b: Rect2 = Rect2(_model_layout["origin"], Vector2(size_cells, size_cells) * float(_model_layout["tile"]))
	return a.merge(b).grow(40.0)


func reset_world() -> void:
	_cell = Vector2i.ZERO
	_brush = Vector2.ZERO
	_painted.clear()
	_wrong = Vector2i(-1, -1)
	_ink = 0
	fail_reason = ""
	queue_redraw()


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := int(entry["intensity"])
		if kind == "PAINT":
			_ink = clampi(amount, 0, 3)
			await animate(func(value: float) -> void: _dab = value, 0.0, 1.0, 0.15)
			_dab = 0.0
			if _ink == 0:
				sfx("click", 0.8)
				continue
			if not await _paint_here():
				return false
			if _done():
				return await _celebrate()
			continue
		var direction := direction_of(kind)
		if direction == Vector2i.ZERO:
			continue
		for _step in range(maxi(amount, 0)):
			var next := _cell + direction
			if next.x < 0 or next.y < 0 or next.x >= size_cells or next.y >= size_cells:
				sfx("bump")
				kick(4.0)
				fail_reason = "O pincel saiu do quadro"
				return false
			var from := Vector2(_cell)
			_cell = next
			if _ink == 0:
				sfx("click", 1.0 + randf() * 0.2, -6.0)
			await animate(func(value: Vector2) -> void: _brush = value, from, Vector2(_cell), 0.08)
			if _ink > 0:
				if not await _paint_here():
					return false
				if _done():
					return await _celebrate()
	fail_reason = "Faltou pintar %d casas" % (target.size() - _painted.size())
	return false


func _paint_here() -> bool:
	sfx("paint", 0.9 + 0.1 * _ink)
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	burst(cell_rect(origin, tile, _cell).get_center(), PAINTS[_ink - 1], 8, 90.0, 0.3, 0.0, PX * 1.5)
	_painted[_cell] = _ink
	if not target.has(_cell) or int(target[_cell]) != _ink:
		_wrong = _cell
		sfx("bump")
		kick(4.0)
		queue_redraw()
		var expected: String = "vazio" if not target.has(_cell) else COLOR_NAMES[int(target[_cell]) - 1]
		fail_reason = "Pintou errado (ali era %s)" % expected
		await wait(0.2)
		return false
	return true


func _done() -> bool:
	for cell in target:
		if int(_painted.get(cell, 0)) != int(target[cell]):
			return false
	return true


func _celebrate() -> bool:
	sfx("coin")
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	burst(origin + Vector2(size_cells, size_cells) * tile * 0.5, GOLD, 20, 220.0, 0.7)
	await wait(0.3)
	return true


func solution() -> Dictionary:
	var actions: Array = []
	var cursor := Vector2i.ZERO
	var ink := 0
	for stroke in strokes:
		var start: Vector2i = stroke["start"]
		if start != cursor and ink != 0:
			actions.append(action("PAINT", 0))
			ink = 0
		var delta := start - cursor
		if delta.x != 0:
			actions.append(action("MOVE_RIGHT" if delta.x > 0 else "MOVE_LEFT", absi(delta.x)))
		if delta.y != 0:
			actions.append(action("MOVE_DOWN" if delta.y > 0 else "MOVE_UP", absi(delta.y)))
		actions.append(action("PAINT", int(stroke["color"])))
		ink = int(stroke["color"])
		actions.append_array(compress_path(stroke["moves"]))
		cursor = start
		for move in stroke["moves"]:
			cursor += move
	return {"actions": actions, "output": []}


func preview_text(actions: Array, _output: Array) -> String:
	var dips := 0
	for entry in actions:
		if entry["kind"] == "PAINT" and int(entry["intensity"]) > 0:
			dips += 1
	return "%d %s" % [dips, "pincelada" if dips == 1 else "pinceladas"]


func _draw() -> void:
	_draw_backdrop()
	_draw_grid(_layout, _painted, true)
	_draw_grid(_model_layout, target, false)
	var model_origin: Vector2 = _model_layout["origin"]
	text(model_origin + Vector2(0.0, -12.0), "MODELO", ArenaPixelArt.tint(0.7))
	# Legenda das cores.
	for index in range(3):
		var at := model_origin + Vector2(index * 70.0, size_cells * float(_model_layout["tile"]) + 22.0)
		draw_rect(Rect2(at, Vector2(PX * 3.0, PX * 3.0)), PAINTS[index])
		text(at + Vector2(18.0, 11.0), str(index + 1), ArenaPixelArt.tint(0.7))
	# Pincel.
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	var cell := Rect2(origin + _brush * tile, Vector2(tile, tile))
	frame_rect(cell.grow(PX), Color("1b1724"), PX * 2.0)
	frame_rect(cell, GOLD, PX)
	# Pincel: molhado fica encostado e com a ponta da cor; levantado, flutua.
	var lift := 0.0 if _ink > 0 else tile * 0.12
	var tip := cell.get_center() + Vector2(tile * 0.18, -tile * 0.18 - lift + _dab * 6.0)
	var bristle: Color = PAINTS[_ink - 1] if _ink > 0 else Color("f3ead7")
	for step in range(6):
		var color: Color = Color("6b4a2a") if step > 2 else (bristle if step < 2 else Color("8a9ab8"))
		draw_rect(Rect2((tip + Vector2(step, -step) * PX).snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX) * 2.0), color)
	draw_particles()
	var status: String = "PINCEL: " + (str(COLOR_NAMES[_ink - 1]) if _ink > 0 else "levantado")
	text(origin + Vector2(0.0, size_cells * tile + 30.0), status, PAINTS[_ink - 1] if _ink > 0 else ArenaPixelArt.tint(0.6), true)


func _draw_grid(layout: Dictionary, cells: Dictionary, show_errors: bool) -> void:
	var origin: Vector2 = layout["origin"]
	var tile: float = layout["tile"]
	draw_rect(Rect2(origin - Vector2(PX, PX), Vector2(size_cells, size_cells) * tile + Vector2(PX, PX) * 2.0), WALL_DARK)
	for y in range(size_cells):
		for x in range(size_cells):
			var key := Vector2i(x, y)
			var rect := cell_rect(origin, tile, key).grow(-1.0)
			draw_rect(rect, Color("e9e1cf") if (x + y) % 2 == 0 else Color("ddd3bd"))
			if cells.has(key):
				draw_rect(rect, PAINTS[int(cells[key]) - 1])
			if show_errors and key == _wrong:
				frame_rect(rect, BAD, PX)
				for step in range(int(rect.size.x / PX) - 4):
					var offset := Vector2(step + 2, step + 2) * PX
					draw_rect(Rect2(rect.position + offset, Vector2(PX, PX)), BAD)
					draw_rect(Rect2(rect.position + Vector2(rect.size.x - offset.x - PX, offset.y), Vector2(PX, PX)), BAD)


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Cavalete: duas pernas e a trave sob a tela; potes de tinta perto do modelo.
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	var board := Rect2(origin, Vector2(size_cells, size_cells) * tile)
	var wood := Color("4a3220")
	for x in [board.position.x + 24.0, board.end.x - 24.0 - PX * 3.0]:
		draw_rect(Rect2(Vector2(x, board.end.y), Vector2(PX * 3.0, area.end.y - board.end.y)), wood)
	draw_rect(Rect2(Vector2(board.position.x - PX * 2.0, board.end.y), Vector2(board.size.x + PX * 4.0, PX * 3.0)), wood)
	var model_origin: Vector2 = _model_layout["origin"]
	var model_size: float = size_cells * float(_model_layout["tile"])
	for index in range(3):
		var pot := Vector2(model_origin.x + model_size - 3.0 * 34.0 + index * 34.0, area.end.y - 34.0)
		draw_rect(Rect2(pot, Vector2(26.0, 26.0)), Color("8a9ab8"))
		draw_rect(Rect2(pot + Vector2(PX, PX), Vector2(26.0 - PX * 2.0, PX * 2.0)), PAINTS[index])
