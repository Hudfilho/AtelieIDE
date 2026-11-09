extends "res://scripts/ware/microgame.gd"

## CAIXAS: empurre as caixas até as marcas douradas (sokoban curtinho).
## Metade dos desafios vem de mapas feitos à mão, metade é gerada "de trás
## para a frente": as caixas começam nas marcas e o esqueleto as PUXA ao
## acaso (o inverso de empurrar), então todo mapa gerado tem solução. A
## solução final sai de uma busca em largura no estado (esqueleto + caixas).

## # parede, @ esqueleto, $ caixa, o marca, * caixa já na marca, . chão.
const MAPS := [
	[
		"#########",
		"#.......#",
		"#.@.$..o#",
		"#.......#",
		"#########",
	],
	[
		"#######",
		"#..o..#",
		"#.....#",
		"#..$..#",
		"#..@..#",
		"#######",
	],
	[
		"#########",
		"#...#...#",
		"#.$.#.o.#",
		"#.@.....#",
		"#.......#",
		"#########",
	],
	[
		"########",
		"#..o...#",
		"#.##...#",
		"#..$.#.#",
		"#.@....#",
		"########",
	],
	[
		"#######",
		"#o...o#",
		"#.$.$.#",
		"#..@..#",
		"#.....#",
		"#######",
	],
	[
		"#########",
		"#..#....#",
		"#.$#.$..#",
		"#.......#",
		"#.o#.@o.#",
		"#########",
	],
	[
		"##########",
		"#....#...#",
		"#.$$.#.o.#",
		"#.@......#",
		"#......o.#",
		"##########",
	],
]
## Mapas por nível (índices em MAPS).
const BY_LEVEL := [[0, 1], [2, 3], [4, 3], [4, 5], [5, 6]]
const CRATE := [
	"kkkkkkkkkk",
	"kwwwwwwwwk",
	"kwkwwwwkwk",
	"kwwkwwkwwk",
	"kwwwkkwwwk",
	"kwwwkkwwwk",
	"kwwkwwkwwk",
	"kwkwwwwkwk",
	"kwwwwwwwwk",
	"kkkkkkkkkk",
]

var columns := 0
var rows := 0
var walls := {}
var targets: Array = []
var start := Vector2i.ZERO
var start_crates: Array = []
var _crates: Array = []
var _cell := Vector2i.ZERO
var _actor := Vector2.ZERO
var _moving_crate := -1
var _crate_offset := Vector2.ZERO
var _layout: Dictionary = {}
var _solution: Array = []
var _walking := false
var _facing_left := false


func _init() -> void:
	title = "CAIXAS"
	instruction = "EMPURRE AS CAIXAS!"
	objective = "Empurre cada caixa até uma marca dourada. Setas andam casas, e andar contra a caixa empurra."
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "DUPLICATE"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1}


func build(new_level: int) -> void:
	if new_level >= 2 and rng.randf() < 0.5:
		var generated := generate_map(1 if new_level <= 3 else 2, 6 if new_level <= 3 else 7, 4 if new_level <= 3 else 5, 6 + new_level * 2)
		if not generated.is_empty():
			load_map(generated)
			if not _solution.is_empty():
				return
	var options: Array = BY_LEVEL[clampi(new_level - 1, 0, BY_LEVEL.size() - 1)]
	load_map(MAPS[options[rng.randi_range(0, options.size() - 1)]])


## Sala com paredes soltas; caixas nascem nas marcas e o esqueleto as puxa
## ao acaso. Devolve o mapa em texto (ou [] se não saiu nada bom).
func generate_map(crate_count: int, inner_w: int, inner_h: int, min_steps: int) -> Array:
	for _attempt in range(30):
		var grid: Array = []
		for y in range(inner_h + 2):
			var line := ""
			for x in range(inner_w + 2):
				var border := x == 0 or y == 0 or x == inner_w + 1 or y == inner_h + 1
				line += "#" if border or (rng.randf() < 0.12) else "."
			grid.append(line)
		var floor_cells: Array = []
		for y in range(grid.size()):
			for x in range(str(grid[y]).length()):
				if str(grid[y])[x] == ".":
					floor_cells.append(Vector2i(x, y))
		if floor_cells.size() < inner_w * inner_h * 0.7 or not _connected(grid, floor_cells):
			continue
		for index in range(floor_cells.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var swap: Vector2i = floor_cells[index]
			floor_cells[index] = floor_cells[other]
			floor_cells[other] = swap
		var goal_cells: Array = floor_cells.slice(0, crate_count)
		var boxes: Array = goal_cells.duplicate()
		var player: Vector2i = floor_cells[crate_count]
		var walls_here := {}
		for y in range(grid.size()):
			for x in range(str(grid[y]).length()):
				if str(grid[y])[x] == "#":
					walls_here[Vector2i(x, y)] = true
		for _pull in range(60 + crate_count * 40):
			var move: Vector2i = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)][rng.randi_range(0, 3)]
			var next: Vector2i = player + move
			if walls_here.has(next) or boxes.has(next):
				continue
			var behind: Vector2i = player - move
			var index := boxes.find(behind)
			if index >= 0 and rng.randf() < 0.7:
				boxes[index] = player
			player = next
		var off_target := boxes.filter(func(box: Vector2i) -> bool: return not goal_cells.has(box))
		if off_target.size() < crate_count:
			continue
		var rows_out: Array = []
		for y in range(grid.size()):
			var line := ""
			for x in range(str(grid[y]).length()):
				var cell := Vector2i(x, y)
				if walls_here.has(cell):
					line += "#"
				elif cell == player:
					line += "@"
				elif boxes.has(cell) and goal_cells.has(cell):
					line += "*"
				elif boxes.has(cell):
					line += "$"
				elif goal_cells.has(cell):
					line += "o"
				else:
					line += "."
			rows_out.append(line)
		load_map(rows_out)
		var steps := 0
		for entry in _solution:
			steps += int(entry["intensity"])
		if not _solution.is_empty() and steps >= min_steps and steps <= min_steps + 30 and _solution.size() <= 7 + crate_count * 3:
			return rows_out
	return []


func _connected(grid: Array, floor_cells: Array) -> bool:
	var seen := {floor_cells[0]: true}
	var queue: Array = [floor_cells[0]]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + direction
			if not seen.has(next) and next.y >= 0 and next.y < grid.size() and next.x >= 0 and next.x < str(grid[next.y]).length() and str(grid[next.y])[next.x] == ".":
				seen[next] = true
				queue.append(next)
	return seen.size() == floor_cells.size()


func load_map(map: Array) -> void:
	rows = map.size()
	columns = str(map[0]).length()
	walls.clear()
	targets.clear()
	start_crates.clear()
	for y in range(rows):
		var line: String = map[y]
		for x in range(columns):
			var cell := Vector2i(x, y)
			match line[x]:
				"#":
					walls[cell] = true
				"@":
					start = cell
				"$":
					start_crates.append(cell)
				"o":
					targets.append(cell)
				"*":
					start_crates.append(cell)
					targets.append(cell)
	_layout = grid_layout(columns, rows, 64.0)
	_solution = _solve()


func content_rect() -> Rect2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return Rect2(origin, Vector2(columns, rows) * tile).grow(16.0)


func reset_world() -> void:
	_walking = false
	_facing_left = false
	_cell = start
	_actor = Vector2(start)
	_crates = start_crates.duplicate()
	_moving_crate = -1
	fail_reason = ""
	queue_redraw()


func _all_on_target(crates: Array) -> bool:
	for crate in crates:
		if not targets.has(crate):
			return false
	return true


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var direction := direction_of(str(entry["kind"]))
		if direction == Vector2i.ZERO:
			continue
		if direction.x != 0:
			_facing_left = direction.x < 0
		for _step in range(maxi(int(entry["intensity"]), 0)):
			var next := _cell + direction
			if walls.has(next):
				_walking = false
				await _bump(direction)
				fail_reason = "Bateu na parede"
				return false
			var pushed := _crates.find(next)
			if pushed >= 0:
				var beyond := next + direction
				if walls.has(beyond) or _crates.has(beyond):
					_walking = false
					await _bump(direction)
					fail_reason = "A caixa travou"
					return false
				_moving_crate = pushed
				sfx("push", 0.9 + randf() * 0.2)
			else:
				sfx("step", 0.9 + randf() * 0.2)
			_walking = true
			var from := Vector2(_cell)
			_cell = next
			await animate(_step_to.bind(from, Vector2(direction)), 0.0, 1.0, 0.12 if _moving_crate < 0 else 0.18)
			if _moving_crate >= 0:
				var landed: Vector2i = next + direction
				_crates[_moving_crate] = landed
				_moving_crate = -1
				_crate_offset = Vector2.ZERO
				var origin: Vector2 = _layout["origin"]
				var tile: float = _layout["tile"]
				var center := cell_rect(origin, tile, landed).get_center()
				burst(center + Vector2(0.0, tile * 0.35), Color(WALL, 0.7), 6, 50.0, 0.3)
				if targets.has(landed):
					sfx("coin", 0.9)
					burst(center, GOOD, 12, 110.0, 0.5)
				queue_redraw()
				if _all_on_target(_crates):
					_walking = false
					await wait(0.25)
					return true
	_walking = false
	fail_reason = "Faltou caixa na marca"
	return false


func _step_to(value: float, from: Vector2, direction: Vector2) -> void:
	_actor = from + direction * value
	_crate_offset = direction * value


func _bump(direction: Vector2i) -> void:
	sfx("bump")
	kick(5.0)
	var from := Vector2(_cell)
	await animate(func(value: Vector2) -> void: _actor = value, from, from + Vector2(direction) * 0.3, 0.06)
	await animate(func(value: Vector2) -> void: _actor = value, from + Vector2(direction) * 0.3, from, 0.08)


## Busca em largura: estado = esqueleto + caixas (ordenadas).
func _solve() -> Array:
	var stride := columns * rows
	var start_state := _encode(start, start_crates, stride)
	var previous := {start_state: [-1, Vector2i.ZERO]}
	var states := {start_state: [start, start_crates]}
	var queue: Array = [start_state]
	var found := -1
	var head := 0
	while head < queue.size() and states.size() < 40000:
		var key: int = queue[head]
		head += 1
		var state: Array = states[key]
		var player: Vector2i = state[0]
		var crates: Array = state[1]
		if _all_on_target(crates):
			found = key
			break
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = player + direction
			if walls.has(next):
				continue
			var moved := crates.duplicate()
			var index := moved.find(next)
			if index >= 0:
				var beyond: Vector2i = next + direction
				if walls.has(beyond) or moved.has(beyond):
					continue
				moved[index] = beyond
			var next_key := _encode(next, moved, stride)
			if previous.has(next_key):
				continue
			previous[next_key] = [key, direction]
			states[next_key] = [next, moved]
			queue.append(next_key)
	if found < 0:
		return []
	var path: Array = []
	var cursor := found
	while int(previous[cursor][0]) >= 0:
		path.push_front(previous[cursor][1])
		cursor = int(previous[cursor][0])
	return compress_path(path)


func _encode(player: Vector2i, crates: Array, stride: int) -> int:
	var indices: Array = []
	for crate in crates:
		indices.append((crate as Vector2i).y * columns + (crate as Vector2i).x)
	indices.sort()
	var key := player.y * columns + player.x
	for index in indices:
		key = key * stride + int(index)
	return key


func solution() -> Dictionary:
	return {"actions": _solution.duplicate(true), "output": []}


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
			var cell := Vector2i(x, y)
			var rect := cell_rect(origin, tile, cell)
			if walls.has(cell):
				draw_rect(rect, WALL_DARK)
				draw_rect(Rect2(rect.position, Vector2(tile, PX)), WALL)
				draw_rect(Rect2(rect.position + Vector2(0.0, tile * 0.5), Vector2(tile, PX)), FLOOR)
				draw_rect(Rect2(rect.position + Vector2(tile * 0.5, 0.0), Vector2(PX, tile * 0.5)), FLOOR)
			else:
				draw_rect(rect, FLOOR if (x + y) % 2 == 0 else FLOOR_ALT)
	for target in targets:
		var mark := cell_rect(origin, tile, target).grow(-tile * (0.22 - 0.03 * sin(clock * 4.0)))
		frame_rect(mark, Color(GOLD, 0.8))
		draw_rect(Rect2(mark.get_center() - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), GOLD)
	var pixel := floorf(tile / 12.0)
	for index in range(_crates.size()):
		var crate: Vector2i = _crates[index]
		var top_left := origin + Vector2(crate) * tile + Vector2(tile - pixel * 10.0, tile - pixel * 10.0) * 0.5
		if index == _moving_crate:
			top_left += _crate_offset * tile
		var wood := Color("b07a3c") if not targets.has(crate) or index == _moving_crate else GOOD
		stamp(CRATE, {"k": Color("4a2c14"), "w": wood}, top_left.snapped(Vector2(pixel, pixel)), pixel)
	var feet := origin + (_actor + Vector2(0.5, 0.85)) * tile
	draw_skeleton(feet, maxf(floorf(tile / 24.0), 1.0), int(clock * (10.0 if _walking else 3.0)), _facing_left, _walking)
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Tábuas do depósito.
	var plank := area.position.y
	while plank < area.end.y:
		draw_rect(Rect2(Vector2(area.position.x, plank), Vector2(area.size.x, PX)), Color("3b2a1a", 0.35))
		plank += 24.0
	var x := area.position.x + 60.0
	while x < area.end.x:
		draw_rect(Rect2(Vector2(x, area.position.y), Vector2(PX, area.size.y)), Color("3b2a1a", 0.18))
		x += 160.0
