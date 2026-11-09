extends "res://scripts/ware/microgame.gd"

## FOGUEIRAS: acenda todas as tochas. O esqueleto anda com as setas (tocha é
## obstáculo) e Fogo acende as tochas em cruz em volta dele, até a distância
## da intensidade (1 a 3). Tem a runa mágica de verdade do jogo: Fogo.

const SIZES := [Vector2i(7, 5), Vector2i(8, 5), Vector2i(9, 5), Vector2i(9, 6), Vector2i(9, 6)]
const TORCH_OFF := [
	"..kk..",
	".kssk.",
	".kssk.",
	"..ww..",
	"..ww..",
	"..ww..",
	"..ww..",
	".kwwk.",
]

var columns := 7
var rows := 5
var start := Vector2i.ZERO
## Vector2i -> true (tochas).
var torches: Dictionary = {}
var _lit: Dictionary = {}
var _cell := Vector2i.ZERO
var _actor := Vector2.ZERO
var _layout: Dictionary = {}
var _solution: Array = []
var _program: Array = []
var _walking := false
var _facing_left := false
var _flash := 0.0
var _flash_range := 1


func _init() -> void:
	title = "FOGUEIRAS"
	instruction = "ACENDA AS TOCHAS!"
	runes = ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT", "FIRE", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"MOVE_UP": 1, "MOVE_DOWN": 1, "MOVE_LEFT": 1, "MOVE_RIGHT": 1, "FIRE": 1}
	max_intensity = {"FIRE": 3}
	names = {"FIRE": "Fogo: acende as tochas em cruz em volta do esqueleto, até a distância da intensidade (1 a 3)"}


func build(new_level: int) -> void:
	var dims: Vector2i = SIZES[clampi(new_level - 1, 0, SIZES.size() - 1)]
	columns = dims.x
	rows = dims.y
	limits = {}
	_program = []
	# Nos níveis de laço o Fogo só alcança 1 casa: senão um Fogo 3 no meio da
	# fileira acenderia tudo e o Portal sobraria.
	max_intensity["FIRE"] = 1 if new_level == 3 or new_level == 4 else 3
	for _attempt in range(80):
		if _try_build(clampi(new_level, 1, 5)):
			break
	_layout = grid_layout(columns, rows, 64.0)


func _try_build(level_kind: int) -> bool:
	torches.clear()
	_solution.clear()
	_program.clear()
	limits = {}
	start = Vector2i(0, rows - 1)
	match level_kind:
		1, 2:
			# Tochas soltas: andar até perto de cada uma e soltar Fogo 1.
			var count := 2 if level_kind == 1 else 3
			while torches.size() < count:
				var cell := Vector2i(rng.randi_range(1, columns - 1), rng.randi_range(0, rows - 1))
				if cell != start and not _near_torch(cell):
					torches[cell] = true
			objective = "Ande até perto de cada tocha e use Fogo. Tocha é obstáculo: não dá para pisar nela."
		3:
			# Fileira com tochas a cada 2 casas: o mesmo passo repetido.
			var row := rng.randi_range(0, rows - 2)
			start = Vector2i(0, row + 1)
			var x := 1
			while x < columns:
				torches[Vector2i(x, row)] = true
				x += 2
			limits = {"FIRE": 1, "MOVE_RIGHT": 1}
			# Começa embaixo da primeira tocha: Fogo, anda 2, repete.
			_program = [action("WARP_ENDPOINT", 1), action("FIRE", 1), action("DUPLICATE", 0), action("MOVE_RIGHT", 1), action("WARP", 1)]
			start = Vector2i(1, row + 1)
			objective = "Só 1 Fogo e 1 seta para a direita: repita com o Portal (Duplicar ajuda a andar 2)."
		4:
			# Duas fileiras com um corredor no meio: Fogo 1 pega as duas.
			var middle := rng.randi_range(1, rows - 2)
			start = Vector2i(1, middle)
			var x := 1
			while x < columns:
				torches[Vector2i(x, middle - 1)] = true
				torches[Vector2i(x, middle + 1)] = true
				x += 2
			limits = {"FIRE": 1, "MOVE_RIGHT": 1}
			_program = [action("WARP_ENDPOINT", 1), action("FIRE", 1), action("DUPLICATE", 0), action("MOVE_RIGHT", 1), action("WARP", 1)]
			objective = "Duas fileiras: no corredor do meio, um Fogo acende em cima e embaixo. Só 1 Fogo e 1 seta para a direita."
		_:
			# Pares de tochas com uma casa livre no meio: um Fogo por par.
			var pairs := 3
			var guard := 0
			while torches.size() < pairs * 2 and guard < 200:
				guard += 1
				var center := Vector2i(rng.randi_range(1, columns - 2), rng.randi_range(1, rows - 2))
				var spread := rng.randi_range(1, 2)
				var horizontal := rng.randf() < 0.5
				var a := center + (Vector2i(spread, 0) if horizontal else Vector2i(0, spread))
				var b := center - (Vector2i(spread, 0) if horizontal else Vector2i(0, spread))
				if a.x < 0 or a.y < 0 or a.x >= columns or a.y >= rows or b.x < 0 or b.y < 0 or b.x >= columns or b.y >= rows:
					continue
				if torches.has(a) or torches.has(b) or torches.has(center) or center == start or a == start or b == start:
					continue
				torches[a] = true
				torches[b] = true
			if torches.size() < pairs * 2:
				return false
			limits = {"FIRE": pairs}
			objective = "Só %d Fogos para %d tochas: ache o ponto entre duas tochas e use o alcance (intensidade 1 a 3)." % [pairs, pairs * 2]
	return _plan()


func _near_torch(cell: Vector2i) -> bool:
	for other in torches:
		if absi((other as Vector2i).x - cell.x) + absi((other as Vector2i).y - cell.y) <= 1:
			return true
	return false


## Solução: ir até o ponto que acende mais tochas apagadas e soltar Fogo com
## o alcance certo; repetir. Confere com a simulação no fim.
func _plan() -> bool:
	var lit := {}
	var cursor := start
	var actions: Array = []
	var fires := 0
	while lit.size() < torches.size():
		var best := Vector2i(-1, -1)
		var best_range := 1
		var best_gain := 0
		var best_path: Array = []
		for y in range(rows):
			for x in range(columns):
				var cell := Vector2i(x, y)
				if torches.has(cell):
					continue
				var path := _walk(cursor, cell)
				if path.is_empty() and cell != cursor:
					continue
				for reach in range(1, int(max_intensity.get("FIRE", 3)) + 1):
					var gain := 0
					for torch in _lit_from(cell, reach):
						if not lit.has(torch):
							gain += 1
					if gain > best_gain or (gain == best_gain and gain > 0 and path.size() < best_path.size()):
						best = cell
						best_range = reach
						best_gain = gain
						best_path = path
		if best_gain == 0:
			return false
		actions.append_array(compress_path(best_path))
		actions.append(action("FIRE", best_range))
		fires += 1
		for torch in _lit_from(best, best_range):
			lit[torch] = true
		cursor = best
	if limits.has("FIRE") and _program.is_empty() and fires > int(limits["FIRE"]):
		return false
	_solution = actions
	return true


## Caminho (passos) entre duas casas sem pisar em tocha.
func _walk(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return []
	var previous := {from: from}
	var queue: Array = [from]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		if current == to:
			break
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= columns or next.y >= rows or torches.has(next) or previous.has(next):
				continue
			previous[next] = current
			queue.append(next)
	if not previous.has(to):
		return []
	var path: Array = []
	var cursor := to
	while cursor != from:
		var before: Vector2i = previous[cursor]
		path.push_front(cursor - before)
		cursor = before
	return path


## Tochas que um Fogo em `cell` com alcance `reach` acende.
func _lit_from(cell: Vector2i, reach: int) -> Array:
	var result: Array = []
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for step in range(1, reach + 1):
			var target: Vector2i = cell + direction * step
			if torches.has(target):
				result.append(target)
	return result


func content_rect() -> Rect2:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	return Rect2(origin, Vector2(columns, rows) * tile).grow(24.0)


func reset_world() -> void:
	_cell = start
	_actor = Vector2(start)
	_lit.clear()
	_walking = false
	_facing_left = false
	_flash = 0.0
	fail_reason = ""
	queue_redraw()


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := int(entry["intensity"])
		if kind == "FIRE":
			if amount <= 0:
				continue # Fogo 0 não acende nada (como seta 0 não anda)
			_walking = false
			_flash_range = clampi(amount, 1, 3)
			sfx("boom", 1.6, -6.0)
			await animate(func(value: float) -> void: _flash = value, 1.0, 0.0, 0.3)
			for torch in _lit_from(_cell, _flash_range):
				if not _lit.has(torch):
					_lit[torch] = true
					sfx("coin", 0.8 + 0.05 * _lit.size())
					burst(_center(torch) - Vector2(0.0, 10.0), Color("ff9a3d"), 10, 90.0, 0.5, -60.0)
			if _lit.size() == torches.size():
				await wait(0.3)
				return true
			continue
		var direction := direction_of(kind)
		if direction == Vector2i.ZERO:
			continue
		if direction.x != 0:
			_facing_left = direction.x < 0
		for _step in range(maxi(amount, 0)):
			var next := _cell + direction
			if next.x < 0 or next.y < 0 or next.x >= columns or next.y >= rows or torches.has(next):
				_walking = false
				sfx("bump")
				kick(4.0)
				var from_edge := Vector2(_cell)
				await animate(func(value: Vector2) -> void: _actor = value, from_edge, from_edge + Vector2(direction) * 0.3, 0.06)
				await animate(func(value: Vector2) -> void: _actor = value, from_edge + Vector2(direction) * 0.3, from_edge, 0.08)
				fail_reason = "Bateu numa tocha" if torches.has(next) else "Saiu do mapa"
				return false
			_walking = true
			sfx("step", 0.9 + randf() * 0.2, -3.0)
			var from := Vector2(_cell)
			_cell = next
			await animate(func(value: Vector2) -> void: _actor = value, from, Vector2(_cell), 0.1)
	_walking = false
	fail_reason = "Faltou acender %d %s" % [torches.size() - _lit.size(), "tocha" if torches.size() - _lit.size() == 1 else "tochas"]
	return false


func _center(cell: Vector2i) -> Vector2:
	return cell_rect(_layout["origin"], _layout["tile"], cell).get_center()


## Ações que resolvem sem laço (plano guloso). Nos níveis 3 e 4 elas passam
## dos limites de runas: lá o ritual esperado é `_program`, com Portal.
func solution() -> Dictionary:
	return {"actions": _solution.duplicate(true), "output": []}


func solution_program() -> Array:
	if not _program.is_empty():
		return _program.duplicate(true)
	return super.solution_program()


func preview_text(actions: Array, _output: Array) -> String:
	var fires := 0
	var steps := 0
	for entry in actions:
		if entry["kind"] == "FIRE":
			fires += 1
		else:
			steps += int(entry["intensity"])
	return "%d %s, %d passos" % [fires, "fogo" if fires == 1 else "fogos", steps]


func _draw() -> void:
	var origin: Vector2 = _layout["origin"]
	var tile: float = _layout["tile"]
	draw_rect(Rect2(origin, Vector2(columns, rows) * tile).grow(PX * 3.0), Color(0.03, 0.04, 0.09, 0.9))
	for y in range(rows):
		for x in range(columns):
			draw_rect(cell_rect(origin, tile, Vector2i(x, y)), FLOOR if (x + y) % 2 == 0 else FLOOR_ALT)
	# Clarão do Fogo: a cruz do alcance.
	if _flash > 0.0:
		for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for step in range(1, _flash_range + 1):
				var cell: Vector2i = _cell + direction * step
				if cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows:
					draw_rect(cell_rect(origin, tile, cell).grow(-PX), Color(1.0, 0.6, 0.2, 0.35 * _flash))
	var pixel := maxf(floorf(tile / 12.0), 2.0)
	for torch in torches:
		var base := _center(torch) + Vector2(0.0, tile * 0.3)
		if _lit.has(torch):
			draw_circle(base - Vector2(0.0, tile * 0.3), tile * 0.6, Color(1.0, 0.7, 0.3, 0.08))
			draw_rect(Rect2(base + Vector2(-pixel, -pixel * 5.0), Vector2(pixel * 2.0, pixel * 5.0)), Color("6b4a2a"))
			draw_torch(base - Vector2(0.0, pixel * 5.0), pixel)
		else:
			stamp(TORCH_OFF, {"k": Color("1b1724"), "s": Color("4a4f5c"), "w": Color("6b4a2a")}, (base - Vector2(3.0, 8.0) * pixel).snapped(Vector2(2.0, 2.0)), pixel)
	var feet := origin + (_actor + Vector2(0.5, 0.85)) * tile
	draw_skeleton(feet, maxf(floorf(tile / 24.0), 1.0), int(clock * (10.0 if _walking else 3.0)), _facing_left, _walking)
	draw_particles()
	text(origin + Vector2(0.0, -12.0), "%d de %d tochas" % [_lit.size(), torches.size()], Color("ff9a3d") if _lit.size() > 0 else ArenaPixelArt.tint(0.7), true)
