extends "res://scripts/ware/microgame.gd"

## SAPO: atravesse o rio pulando de tronco em tronco. Cada pulo (seta, a
## intensidade é quantos pulos) dura um tique; a cada tique os troncos andam
## com a correnteza e levam o sapo junto. Cair na água ou ser levado para
## fora da tela perde. Chegou na margem de cima, ganhou.

const COLUMNS := 9
const FROG := [
	"..k...k..",
	".kgk.kgk.",
	".kwgggwk.",
	"kggggggk.",
	"kgyyyygk.",
	".kgggggk.",
	"kgk...kgk",
]

var rows := 4
## Cada fileira de rio: {"row": y, "dir": 1 ou -1, "speed": casas por tique, "logs": [{"x": início, "length": n}]}.
var lanes: Array = []
var start := Vector2i.ZERO
var _layout: Dictionary = {}
var _solution: Array = []
var _frog := Vector2i.ZERO
var _frog_draw := Vector2.ZERO
var _tick := 0
## Fração do tique que está sendo animado (troncos deslizando).
var _slide := 0.0
var _sinking := 0.0
var _hop := 0.0


func _init() -> void:
	title = "SAPO"
	instruction = "ATRAVESSE O RIO!"
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1}
	objective = "Cada pulo é um tique: os troncos andam e levam o sapo. A intensidade da seta é quantos pulos. Água ou sair da tela perde."


func build(new_level: int) -> void:
	var lane_count := clampi(new_level, 1, 4)
	rows = lane_count + 2
	for _attempt in range(200):
		_make_lanes(lane_count, new_level)
		_solution = _solve()
		if not _solution.is_empty() and _solution.size() <= 4 + new_level * 2:
			break
	_layout = grid_layout(COLUMNS, rows, 64.0)


func _make_lanes(lane_count: int, new_level: int) -> void:
	lanes.clear()
	start = Vector2i(rng.randi_range(2, COLUMNS - 3), rows - 1)
	for index in range(lane_count):
		var lane := {"row": rows - 2 - index, "dir": 1 if (index + rng.randi_range(0, 1)) % 2 == 0 else -1, "speed": 2 if new_level >= 5 and index == lane_count - 1 else 1, "logs": []}
		var x := rng.randi_range(0, 2)
		while x < COLUMNS:
			var length := rng.randi_range(2, 3)
			if x + length > COLUMNS:
				break
			lane["logs"].append({"x": x, "length": length})
			x += length + rng.randi_range(2, 3)
		lanes.append(lane)


func lane_at(row: int) -> Dictionary:
	for lane in lanes:
		if int(lane["row"]) == row:
			return lane
	return {}


## Tem tronco na casa (x, linha) no tique t? Margens sempre são chão.
func is_safe(x: int, row: int, tick: int) -> bool:
	if x < 0 or x >= COLUMNS:
		return false
	var lane := lane_at(row)
	if lane.is_empty():
		return true
	var shift := int(lane["dir"]) * int(lane["speed"]) * tick
	for piece in lane["logs"]:
		for part in range(int(piece["length"])):
			if posmod(int(piece["x"]) + part + shift, COLUMNS) == x:
				return true
	return false


## Um pulo: anda, confere a casa, e o tique passa (o tronco leva o sapo).
## Devolve {"ok", "pos", "reason"}.
func hop(pos: Vector2i, direction: Vector2i, tick: int) -> Dictionary:
	var next := pos + direction
	if next.y < 0 or next.y >= rows or next.x < 0 or next.x >= COLUMNS:
		return {"ok": false, "pos": pos, "reason": "Pulou para fora do mapa"}
	if not is_safe(next.x, next.y, tick):
		return {"ok": false, "pos": next, "reason": "Caiu na água"}
	var lane := lane_at(next.y)
	if not lane.is_empty():
		next.x += int(lane["dir"]) * int(lane["speed"])
		if next.x < 0 or next.x >= COLUMNS:
			return {"ok": false, "pos": next, "reason": "A correnteza levou o sapo"}
	return {"ok": true, "pos": next, "reason": ""}


## Busca em largura em (x, linha, tique mod período).
func _solve() -> Array:
	var period := COLUMNS
	var key := func(p: Vector2i, t: int) -> int: return (p.y * COLUMNS + p.x) * period + posmod(t, period)
	var start_key: int = key.call(start, 0)
	var previous := {start_key: [-1, Vector2i.ZERO]}
	var states := {start_key: [start, 0]}
	var queue: Array = [start_key]
	var head := 0
	var found := -1
	while head < queue.size():
		var current: int = queue[head]
		head += 1
		var state: Array = states[current]
		var pos: Vector2i = state[0]
		var tick: int = state[1]
		if pos.y == 0:
			found = current
			break
		for direction in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
			var result := hop(pos, direction, tick)
			if not bool(result["ok"]):
				continue
			var next_key: int = key.call(result["pos"], tick + 1)
			if previous.has(next_key):
				continue
			previous[next_key] = [current, direction]
			states[next_key] = [result["pos"], tick + 1]
			queue.append(next_key)
	if found < 0:
		return []
	var path: Array = []
	var cursor := found
	while int(previous[cursor][0]) >= 0:
		path.push_front(previous[cursor][1])
		cursor = int(previous[cursor][0])
	return compress_path(path)


func content_rect() -> Rect2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	# Folga maior dos lados: as setas da correnteza ficam fora do tabuleiro.
	return Rect2(origin, Vector2(COLUMNS, rows) * tile).grow_individual(56.0, 24.0, 56.0, 24.0)


func reset_world() -> void:
	_frog = start
	_frog_draw = Vector2(start)
	_tick = 0
	_slide = 0.0
	_sinking = 0.0
	_hop = 0.0
	fail_reason = ""
	queue_redraw()


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var direction := direction_of(str(entry["kind"]))
		if direction == Vector2i.ZERO:
			continue
		for _step in range(maxi(int(entry["intensity"]), 0)):
			var result := hop(_frog, direction, _tick)
			var landing: Vector2i = _frog + direction
			sfx("jump", 1.4)
			var from := Vector2(_frog)
			await animate(_hop_step.bind(from, Vector2(landing)), 0.0, 1.0, 0.16)
			if not bool(result["ok"]) and str(result["reason"]) != "A correnteza levou o sapo":
				fail_reason = str(result["reason"])
				if fail_reason == "Caiu na água":
					sfx("bubble", 0.6)
					burst(_cell_center(Vector2(landing)), Color("7fd7ff"), 12, 90.0, 0.5, 120.0)
					await animate(func(value: float) -> void: _sinking = value, 0.0, 1.0, 0.3)
				else:
					sfx("bump")
					kick(4.0)
				return false
			_frog = landing
			# Tique: troncos andam e levam o sapo.
			var carried := not lane_at(_frog.y).is_empty()
			var lane := lane_at(_frog.y)
			var shift := float(int(lane["dir"]) * int(lane["speed"])) if carried else 0.0
			await animate(_slide_step.bind(Vector2(_frog), shift), 0.0, 1.0, 0.14)
			_slide = 0.0
			_tick += 1
			_frog = result["pos"]
			_frog_draw = Vector2(_frog)
			if not bool(result["ok"]):
				fail_reason = str(result["reason"])
				sfx("fall")
				return false
			if carried:
				sfx("land", 1.3, -4.0)
			if _frog.y == 0:
				sfx("coin")
				burst(_cell_center(_frog_draw), GOOD, 14, 120.0, 0.6)
				await wait(0.3)
				return true
	fail_reason = "Não chegou na outra margem"
	return false


func _hop_step(value: float, from: Vector2, to: Vector2) -> void:
	_frog_draw = from.lerp(to, value)
	_hop = sin(value * PI)


func _slide_step(value: float, at: Vector2, shift: float) -> void:
	_slide = value
	_frog_draw = at + Vector2(shift * value, 0.0)
	_hop = 0.0


func _cell_center(cell: Vector2) -> Vector2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return origin + (cell + Vector2(0.5, 0.5)) * tile


func solution() -> Dictionary:
	return {"actions": _solution.duplicate(true), "output": []}


func preview_text(actions: Array, _output: Array) -> String:
	var hops := 0
	for entry in actions:
		hops += int(entry["intensity"])
	return "%d %s" % [hops, "pulo" if hops == 1 else "pulos"]


func _draw() -> void:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	var board := Rect2(origin, Vector2(COLUMNS, rows) * tile)
	draw_rect(board.grow(PX * 3.0), Color(0.03, 0.04, 0.09, 0.9))
	for y in range(rows):
		var lane := lane_at(y)
		var row_rect := Rect2(origin + Vector2(0.0, y * tile), Vector2(COLUMNS * tile, tile))
		if lane.is_empty():
			# Margem com grama.
			draw_rect(row_rect, Color("1f3a2a"))
			for tuft in range(COLUMNS * 2):
				var at := row_rect.position + Vector2(tuft * tile * 0.5 + fmod(tuft * 13.0, tile * 0.3), tile * (0.3 + fmod(tuft * 0.37, 0.5)))
				draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX * 2.0)), Color("3b6b45"))
			continue
		draw_rect(row_rect, Color("173a66"))
		# Ondinhas andando com a correnteza.
		for wave in range(COLUMNS):
			var wx := fmod(wave * tile + clock * 20.0 * float(lane["dir"]) + 1000.0 * tile, COLUMNS * tile)
			draw_rect(Rect2(row_rect.position + Vector2(wx, tile * (0.3 + 0.4 * float(wave % 2))), Vector2(PX * 3.0, PX)).abs(), Color("2c5c96"))
		var offset := float(int(lane["dir"]) * int(lane["speed"])) * (_tick + _slide)
		for piece in lane["logs"]:
			for copy in [-1, 0, 1]:
				var x: float = float(piece["x"]) + offset + float(copy) * COLUMNS
				x = fposmod(x + COLUMNS, COLUMNS * 3.0) - COLUMNS
				var rect := Rect2(origin + Vector2(x * tile, y * tile) + Vector2(PX, tile * 0.18), Vector2(float(piece["length"]) * tile - PX * 2.0, tile * 0.64))
				var clipped := rect.intersection(row_rect)
				if clipped.size.x <= 0.0:
					continue
				draw_rect(clipped, Color("6b4a2a"))
				draw_rect(Rect2(clipped.position, Vector2(clipped.size.x, PX)), Color("8a6238"))
				draw_rect(Rect2(clipped.position + Vector2(0.0, clipped.size.y - PX), Vector2(clipped.size.x, PX)), Color("3b2a1a"))
	# Setas da correnteza nas laterais (duas setas = 2 casas por tique).
	for lane in lanes:
		var y := origin.y + (float(lane["row"]) + 0.5) * tile
		var direction := float(lane["dir"])
		for side in [board.position.x - 30.0, board.end.x + 14.0]:
			for count in range(int(lane["speed"])):
				var tip := Vector2(side + 8.0 + count * 14.0 * direction, y)
				for step in range(4):
					var column := tip + Vector2(-direction * step * PX, 0.0)
					draw_rect(Rect2(column - Vector2(0.0, step * PX), Vector2(PX, (step * 2 + 1) * PX)), Color("7fd7ff", 0.6))
	# Sapo.
	var pixel := maxf(floorf(tile / 14.0), 2.0)
	var center := _cell_center(_frog_draw) - Vector2(0.0, _hop * tile * 0.35)
	if _sinking < 1.0:
		var color := Color(1.0, 1.0, 1.0, 1.0 - _sinking)
		draw_rect(Rect2(_cell_center(_frog_draw) + Vector2(-4.0, 3.0) * pixel, Vector2(8.0, 2.0) * pixel), Color(0, 0, 0, 0.25))
		stamp(FROG, {"k": Color("1b1724", color.a), "g": Color("5cc46a", color.a), "w": Color("f3ead7", color.a), "y": Color("c9e88a", color.a)}, (center - Vector2(4.5, 4.0) * pixel).snapped(Vector2(2.0, 2.0)), pixel)
	draw_particles()
