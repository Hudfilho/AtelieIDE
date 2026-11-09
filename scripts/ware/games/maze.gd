extends "res://scripts/ware/microgame.gd"

## LABIRINTO: leve o esqueleto até a saída andando pelas casas.
## Labirinto perfeito gerado (backtracking); maior a cada nível. Do nível 4
## em diante a porta está trancada: antes, pegue a chave (num beco).

const SIZES := [Vector2i(5, 4), Vector2i(6, 4), Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 6)]
const STRAIGHT_BIAS := 0.7
const KEY := [
	"..kkk...",
	".kyyyk..",
	".ky.yk..",
	".kyyyk..",
	"..kyk...",
	"..kyk...",
	"..kyyk..",
	"..kyk...",
	"..kyyk..",
	"...k....",
]

var columns := 5
var rows := 4
## Paredes abertas: "x,y>x2,y2" -> true.
var _open: Dictionary = {}
var start := Vector2i.ZERO
var exit := Vector2i.ZERO
## Chave (nível 4+); Vector2i(-1, -1) = porta aberta.
var key_cell := Vector2i(-1, -1)
var _has_key := false
var _actor := Vector2.ZERO
var _cell := Vector2i.ZERO
var _layout: Dictionary = {}
## Casas por onde o esqueleto já passou (pegadas) e se está andando.
var _trail: Array = []
var _walking := false
var _facing_left := false
var _door_open := 0.0


func _init() -> void:
	title = "LABIRINTO"
	instruction = "CHEGUE NA SAÍDA!"
	objective = "Leve o esqueleto até a porta dourada. Setas andam casas, a intensidade é quantas."
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1}


func build(new_level: int) -> void:
	# Labirintos que pedem runas demais para o tempo são sorteados de novo.
	for _attempt in range(25):
		_build_once(new_level)
		if solution()["actions"].size() <= 5 + new_level * 2:
			return


func _build_once(new_level: int) -> void:
	var dims: Vector2i = SIZES[clampi(new_level - 1, 0, SIZES.size() - 1)]
	columns = dims.x
	rows = dims.y
	_open.clear()
	var visited := {}
	var stack: Array = [Vector2i.ZERO]
	visited[Vector2i.ZERO] = true
	while not stack.is_empty():
		var current: Vector2i = stack[-1]
		var options: Array = []
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + direction
			if next.x >= 0 and next.y >= 0 and next.x < columns and next.y < rows and not visited.has(next):
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		# Viés para seguir reto: corredores longos, menos curvas, menos runas.
		var chosen: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		if stack.size() >= 2:
			var straight: Vector2i = current + (current - (stack[-2] as Vector2i))
			if options.has(straight) and rng.randf() < STRAIGHT_BIAS:
				chosen = straight
		_open[_edge(current, chosen)] = true
		visited[chosen] = true
		stack.append(chosen)
	start = Vector2i.ZERO
	exit = Vector2i(columns - 1, rows - 1)
	_layout = grid_layout(columns, rows, 64.0)
	key_cell = Vector2i(-1, -1)
	if new_level >= 4:
		# A chave fica num desvio de 2 a 4 casas do caminho certo.
		var away := {}
		var queue: Array = [start]
		away[start] = 0
		var cursor := start
		for step in _path(start, exit):
			cursor += step
			away[cursor] = 0
			queue.append(cursor)
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			if current == exit:
				continue # chave atrás da porta obrigaria a passar por ela
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = current + direction
				if can_move(current, direction) and not away.has(next):
					away[next] = int(away[current]) + 1
					queue.append(next)
		var candidates: Array = []
		var farthest := Vector2i(-1, -1)
		for cell in away:
			if int(away[cell]) >= 2 and int(away[cell]) <= 4:
				candidates.append(cell)
			if farthest.x < 0 or int(away[cell]) > int(away[farthest]):
				farthest = cell
		candidates.sort()
		key_cell = candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else farthest
		if int(away.get(key_cell, 0)) == 0:
			key_cell = Vector2i(-1, -1)
	objective = "Leve o esqueleto até a porta dourada. Setas andam casas, a intensidade é quantas." if key_cell.x < 0 else "A porta está trancada: pegue a chave antes. Setas andam casas, a intensidade é quantas."


func reset_world() -> void:
	_cell = start
	_actor = Vector2(start)
	_trail = [start]
	_has_key = key_cell.x < 0
	_walking = false
	_facing_left = false
	_door_open = 0.0
	fail_reason = ""
	queue_redraw()


func content_rect() -> Rect2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return Rect2(origin, Vector2(columns, rows) * tile).grow(24.0)


static func _edge(a: Vector2i, b: Vector2i) -> String:
	var low := a if a.x * 1000 + a.y < b.x * 1000 + b.y else b
	var high := b if low == a else a
	return "%d,%d>%d,%d" % [low.x, low.y, high.x, high.y]


func can_move(from: Vector2i, direction: Vector2i) -> bool:
	var to := from + direction
	if to.x < 0 or to.y < 0 or to.x >= columns or to.y >= rows:
		return false
	return _open.has(_edge(from, to))


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var direction := direction_of(str(entry["kind"]))
		if direction == Vector2i.ZERO:
			continue
		if direction.x != 0:
			_facing_left = direction.x < 0
		for _step in range(maxi(int(entry["intensity"]), 0)):
			if not can_move(_cell, direction):
				_walking = false
				await _bump(direction)
				fail_reason = "Bateu na parede"
				return false
			var from := Vector2(_cell)
			_cell += direction
			_walking = true
			sfx("step", 0.9 + 0.2 * randf())
			await animate(func(value: Vector2) -> void: _actor = value, from, Vector2(_cell), 0.12)
			_trail.append(_cell)
			burst(_feet() + Vector2(0.0, -2.0), Color(WALL, 0.6), 4, 30.0, 0.3)
			if _cell == key_cell and not _has_key:
				_has_key = true
				sfx("coin", 1.3)
				burst(_feet() - Vector2(0.0, 20.0), GOLD, 10, 100.0, 0.5)
			if _cell == exit and not _has_key:
				_walking = false
				sfx("bump")
				kick(4.0)
				fail_reason = "A porta está trancada: falta a chave"
				return false
			if _cell == exit:
				_walking = false
				sfx("coin")
				await animate(func(value: float) -> void: _door_open = value, 0.0, 1.0, 0.3)
				burst(_feet() - Vector2(0.0, 20.0), GOLD, 14, 120.0, 0.6)
				return true
	_walking = false
	fail_reason = "Não chegou na saída"
	return false


func _feet() -> Vector2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return origin + (_actor + Vector2(0.5, 0.85)) * tile


func _bump(direction: Vector2i) -> void:
	sfx("bump")
	kick(5.0)
	var from := Vector2(_cell)
	await animate(func(value: Vector2) -> void: _actor = value, from, from + Vector2(direction) * 0.3, 0.06)
	await animate(func(value: Vector2) -> void: _actor = value, from + Vector2(direction) * 0.3, from, 0.08)


## Passos (direções) do caminho mais curto entre duas casas (BFS).
func _path(from: Vector2i, to: Vector2i) -> Array:
	var previous := {from: from}
	var queue: Array = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			break
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + direction
			if can_move(current, direction) and not previous.has(next):
				previous[next] = current
				queue.append(next)
	var path: Array = []
	var cursor := to
	while cursor != from:
		var before: Vector2i = previous[cursor]
		path.push_front(cursor - before)
		cursor = before
	return path


func solution() -> Dictionary:
	if key_cell.x < 0:
		return {"actions": compress_path(_path(start, exit)), "output": []}
	return {"actions": compress_path(_path(start, key_cell) + _path(key_cell, exit)), "output": []}


func preview_text(actions: Array, _output: Array) -> String:
	var steps := 0
	for entry in actions:
		steps += int(entry["intensity"])
	return "%d passos" % steps


func _draw() -> void:
	_draw_backdrop()
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	for y in range(rows):
		for x in range(columns):
			draw_rect(cell_rect(origin, tile, Vector2i(x, y)), FLOOR if (x + y) % 2 == 0 else FLOOR_ALT)
	# Pegadas (o caminho da tentativa).
	for index in range(_trail.size()):
		var center := cell_rect(origin, tile, _trail[index]).get_center()
		draw_rect(Rect2(center.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), ArenaPixelArt.tint(0.18))
	# Porta de saída (pulsa; abre ao chegar).
	var door := cell_rect(origin, tile, exit).grow(-tile * 0.2)
	var glow := 0.18 + 0.1 * sin(clock * 4.0)
	draw_rect(door.grow(PX * (1.0 + _door_open * 2.0)), Color(GOLD, glow * (1.0 + _door_open * 2.0)))
	draw_rect(door, Color(0.05, 0.05, 0.1))
	var leaf := Rect2(door.position, Vector2(door.size.x * (1.0 - _door_open * 0.8), door.size.y))
	draw_rect(leaf, Color("6b4a2a"))
	frame_rect(door, GOLD)
	draw_rect(Rect2(leaf.position + Vector2(leaf.size.x - PX * 2.0, leaf.size.y * 0.5), Vector2(PX, PX)), GOLD)
	if not _has_key:
		# Cadeado na porta e a chave flutuando no beco.
		var lock := door.get_center() - Vector2(PX * 2.0, PX)
		draw_rect(Rect2(lock + Vector2(PX * 0.5, -PX * 2.0), Vector2(PX * 3.0, PX * 2.0)), WALL)
		draw_rect(Rect2(lock, Vector2(PX * 4.0, PX * 3.0)), GOLD)
		var key_pixel := maxf(floorf(tile / 16.0), 2.0)
		var key_at := cell_rect(origin, tile, key_cell).get_center() - Vector2(4.0, 5.0 + sin(clock * 3.0) * 0.6) * key_pixel
		stamp(KEY, {"k": Color("6b4a10"), "y": GOLD}, key_at.snapped(Vector2(2.0, 2.0)), key_pixel)
	# Paredes: cada lado sem passagem vira uma barra.
	var wall := PX * 2.0
	for y in range(rows):
		for x in range(columns):
			var cell := Vector2i(x, y)
			var rect := cell_rect(origin, tile, cell)
			if not can_move(cell, Vector2i(1, 0)):
				draw_rect(Rect2(rect.position + Vector2(tile - wall * 0.5, -wall * 0.5), Vector2(wall, tile + wall)), WALL)
			if not can_move(cell, Vector2i(0, 1)):
				draw_rect(Rect2(rect.position + Vector2(-wall * 0.5, tile - wall * 0.5), Vector2(tile + wall, wall)), WALL)
			if x == 0:
				draw_rect(Rect2(rect.position + Vector2(-wall * 0.5, -wall * 0.5), Vector2(wall, tile + wall)), WALL)
			if y == 0:
				draw_rect(Rect2(rect.position + Vector2(-wall * 0.5, -wall * 0.5), Vector2(tile + wall, wall)), WALL)
	draw_skeleton(_feet(), maxf(floorf(tile / 24.0), 1.0), int(clock * (10.0 if _walking else 3.0)), _facing_left, _walking)
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	var board := Rect2(origin, Vector2(columns, rows) * tile)
	# Pedras do salão em volta do labirinto.
	var stone := area.position.y
	var row := 0
	while stone < area.end.y:
		var offset := 24.0 if row % 2 else 0.0
		var x := area.position.x - offset
		while x < area.end.x:
			draw_rect(Rect2(Vector2(x, stone), Vector2(PX, 32.0)), Color(WALL_DARK, 0.35))
			x += 48.0
		draw_rect(Rect2(Vector2(area.position.x, stone), Vector2(area.size.x, PX)), Color(WALL_DARK, 0.35))
		stone += 32.0
		row += 1
	draw_rect(board.grow(PX * 3.0), Color(0.03, 0.04, 0.09, 0.9))
	draw_torch(Vector2(board.position.x - 40.0, board.position.y + board.size.y * 0.35))
	draw_torch(Vector2(board.end.x + 40.0, board.position.y + board.size.y * 0.35))
