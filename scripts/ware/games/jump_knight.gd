extends "res://scripts/ware/microgame.gd"

## CAVALEIRO SALTADOR: leve o cavaleiro até a bandeira pulando de plataforma
## em plataforma. Setas andam (8 px por ponto de intensidade); Pular usa a
## intensidade como ângulo (90 = reto para cima, menos que 90 vai para a
## direita). As plataformas são geradas a partir de pulos simulados, então o
## desafio sempre tem solução.

const GRAVITY := 1100.0
const JUMP_SPEED := 520.0
const WALK_SPEED := 160.0
const STEP := 8.0
const DT := 1.0 / 120.0
const HALF_WIDTH := 10.0
const LEDGE := 20.0
const KNIGHT := [
	"....rr......",
	"...kkkk.....",
	"..kssssk....",
	".kssssssk...",
	".kskkkksk...",
	".kssssssk...",
	"..kssssk....",
	".kkbbbbkk...",
	"kbbbbbbbbk..",
	"kbkbbbbkbk..",
	"kbkbbbbkbks.",
	".kkbbbbkk.s.",
	"..kbbbbk..s.",
]
## Pernas: parado, passo A, passo B, encolhido no pulo.
const LEGS := [
	["..kbkkbk....", "..kbk.kbk...", ".kkk...kkk.."],
	["..kbkkbk....", ".kbk...kbk..", "kkk.....kkk."],
	["..kbkbk.....", "...kbbk.....", "...kkkk....."],
	["..kbbbbk....", "..kkbbkk....", "...kk.kk...."],
]
const KNIGHT_PALETTE := {
	"k": Color("1b1724"), "s": Color("c9d3e0"), "b": Color("4a78c8"), "r": Color("e8452c"),
}

var platforms: Array = []
var goal := 0
var start_feet := Vector2.ZERO
var _solution: Array = []
var _feet := Vector2.ZERO
var _on := 0
var _ghost: Array = []
var _facing_left := false
var _pose := 0
var _spin := 0.0
var _busy := false
var _flag_up := 0.0


func _init() -> void:
	title = "CAVALEIRO SALTADOR"
	instruction = "PULE ATÉ A BANDEIRA!"
	objective = "Andar: setas (8 px por ponto). Pular: a intensidade é o ângulo, 90 é reto para cima."
	runes = ["MOVE_RIGHT", "MOVE_LEFT", "JUMP", "DUPLICATE", "WARP", "WARP_ENDPOINT"]
	default_intensity = {"MOVE_RIGHT": 4, "MOVE_LEFT": 4, "JUMP": 60}
	max_intensity = {"JUMP": 180}


func build(new_level: int) -> void:
	var jumps := clampi(new_level, 1, 4)
	for _attempt in range(40):
		if _try_build(jumps) and _solves(_solution):
			return
		jumps = maxi(1, jumps - 1) if _attempt > 20 else jumps
	# Muito improvável: cai para um pulo só, que sempre acha lugar.
	for _attempt in range(400):
		if _try_build(1) and _solves(_solution):
			return
	push_error("Cavaleiro: não consegui gerar o nível")


func _try_build(jumps: int) -> bool:
	platforms.clear()
	_solution.clear()
	var top := area.end.y - 70.0 - rng.randf_range(0.0, 90.0)
	platforms.append(Rect2(area.position.x + 40.0, top, 150.0, LEDGE))
	start_feet = Vector2(area.position.x + 70.0, top)
	var feet := start_feet
	for _jump in range(jumps):
		var current: Rect2 = platforms[-1]
		var steps := maxi(0, int(floor((current.end.x - 16.0 - feet.x) / STEP)) - rng.randi_range(0, 2))
		if steps > 0:
			_solution.append(action("MOVE_RIGHT", steps))
		var takeoff := feet + Vector2(steps * STEP, 0.0)
		var placed := false
		for _try in range(30):
			var angle := rng.randi_range(45, 78)
			var flight := simulate_flight(takeoff, Vector2.from_angle(deg_to_rad(-angle)) * JUMP_SPEED)
			var candidates: Array = []
			var points: Array = flight["points"]
			for index in range(points.size()):
				var point: Vector2 = points[index]
				var falling: bool = index > 0 and point.y > (points[index - 1] as Vector2).y
				if falling and point.x > takeoff.x + 110.0 and point.x < area.end.x - 80.0 and point.y > area.position.y + 70.0 and point.y < area.end.y - 30.0:
					candidates.append(point)
			if candidates.is_empty():
				continue
			var landing: Vector2 = candidates[rng.randi_range(0, candidates.size() - 1)]
			var width := rng.randf_range(90.0, 140.0)
			var ledge := Rect2(landing.x - rng.randf_range(20.0, width - 24.0), landing.y, width, LEDGE)
			if _overlaps(ledge):
				continue
			platforms.append(ledge)
			var check := simulate_flight(takeoff, Vector2.from_angle(deg_to_rad(-angle)) * JUMP_SPEED)
			var too_high := false
			for point in check["points"]:
				if (point as Vector2).y < area.position.y + 12.0:
					too_high = true
			if int(check["landed"]) != platforms.size() - 1 or too_high:
				platforms.pop_back()
				continue
			_solution.append(action("JUMP", angle))
			feet = check["end"]
			placed = true
			break
		if not placed:
			return false
	goal = platforms.size() - 1
	return true


## Simulação sem animação (prova que a solução gerada funciona).
func _solves(actions: Array) -> bool:
	var feet := start_feet
	var on := 0
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := int(entry["intensity"])
		var flight: Dictionary = {}
		if kind == "MOVE_RIGHT" or kind == "MOVE_LEFT":
			var sign := 1.0 if kind == "MOVE_RIGHT" else -1.0
			var ledge: Rect2 = platforms[on]
			var edge := ledge.end.x + HALF_WIDTH * 0.5 if sign > 0.0 else ledge.position.x - HALF_WIDTH * 0.5
			var target := feet.x + sign * amount * STEP
			if (sign > 0.0 and target <= edge) or (sign < 0.0 and target >= edge):
				feet.x = target
				continue
			flight = simulate_flight(Vector2(edge, feet.y), Vector2(sign * WALK_SPEED, 0.0))
		elif kind == "JUMP":
			flight = simulate_flight(feet, Vector2.from_angle(deg_to_rad(-amount)) * JUMP_SPEED)
		else:
			continue
		if int(flight["landed"]) < 0:
			return false
		on = int(flight["landed"])
		feet = flight["end"]
		if on == goal:
			return true
	return false


func _overlaps(ledge: Rect2) -> bool:
	for existing in platforms:
		if (existing as Rect2).grow(36.0).intersects(ledge):
			return true
	return ledge.end.x > area.end.x - 10.0 or ledge.position.x < area.position.x + 10.0


func reset_world() -> void:
	_feet = start_feet
	_on = 0
	_pose = 0
	_spin = 0.0
	_busy = false
	_flag_up = 0.0
	_facing_left = false
	fail_reason = ""
	queue_redraw()


## Voo balístico (pulo ou queda) até pousar numa plataforma ou sair da tela.
func simulate_flight(from: Vector2, velocity: Vector2) -> Dictionary:
	var position := from
	var points: Array = [from]
	var time := 0.0
	while time < 6.0:
		time += DT
		var previous := position
		velocity.y += GRAVITY * DT
		position += velocity * DT
		points.append(position)
		if velocity.y > 0.0:
			for index in range(platforms.size()):
				var ledge: Rect2 = platforms[index]
				if previous.y <= ledge.position.y and position.y >= ledge.position.y and position.x >= ledge.position.x - HALF_WIDTH * 0.5 and position.x <= ledge.end.x + HALF_WIDTH * 0.5:
					position.y = ledge.position.y
					points[-1] = position
					return {"points": points, "landed": index, "end": position}
		if position.y > area.end.y + 60.0 or position.x < area.position.x - 60.0 or position.x > area.end.x + 60.0:
			return {"points": points, "landed": -1, "end": position}
	return {"points": points, "landed": -1, "end": position}


func execute(actions: Array, _output: Array) -> bool:
	_ghost.clear()
	_busy = true
	var result := await _run(actions)
	_busy = false
	_pose = 0
	return result


func _run(actions: Array) -> bool:
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := int(entry["intensity"])
		var flight: Dictionary = {}
		if kind == "MOVE_RIGHT" or kind == "MOVE_LEFT":
			var sign := 1.0 if kind == "MOVE_RIGHT" else -1.0
			_facing_left = sign < 0.0
			var ledge: Rect2 = platforms[_on]
			var target := _feet.x + sign * amount * STEP
			var edge := ledge.end.x + HALF_WIDTH * 0.5 if sign > 0.0 else ledge.position.x - HALF_WIDTH * 0.5
			var walks_off := (sign > 0.0 and target > edge) or (sign < 0.0 and target < edge)
			var stop_x := edge if walks_off else target
			var from := _feet
			sfx("step")
			await animate(_walk_to.bind(from.x), from.x, stop_x, absf(stop_x - from.x) / WALK_SPEED)
			_pose = 0
			if not walks_off:
				continue
			flight = simulate_flight(_feet, Vector2(sign * WALK_SPEED, 0.0))
		elif kind == "JUMP":
			_facing_left = amount > 90
			sfx("jump")
			burst(_feet, Color(WALL, 0.7), 6, 60.0, 0.3)
			flight = simulate_flight(_feet, Vector2.from_angle(deg_to_rad(-amount)) * JUMP_SPEED)
		else:
			continue
		_ghost = flight["points"]
		_pose = 3
		if int(flight["landed"]) < 0:
			sfx("fall")
			var reason := _fall_reason(flight["points"])
			await _fly(flight["points"], true)
			fail_reason = reason
			return false
		await _fly(flight["points"], false)
		_pose = 0
		_on = int(flight["landed"])
		_feet = flight["end"]
		sfx("land")
		burst(_feet, Color(WALL, 0.8), 8, 70.0, 0.35)
		if _on == goal:
			sfx("coin")
			await animate(func(value: float) -> void: _flag_up = value, 0.0, 1.0, 0.35)
			var pole := Vector2(platforms[goal].end.x - 20.0, platforms[goal].position.y - 50.0)
			burst(pole, GOLD, 16, 140.0, 0.7, 120.0)
			return true
	fail_reason = "Não chegou na bandeira"
	return false


## Compara a queda com a próxima plataforma: curto, longo ou alto demais.
func _fall_reason(points: Array) -> String:
	var next := mini(_on + 1, platforms.size() - 1)
	if next == _on:
		return "Caiu"
	var ledge: Rect2 = platforms[next]
	for index in range(1, points.size()):
		var point: Vector2 = points[index]
		if point.y >= ledge.position.y and point.y > (points[index - 1] as Vector2).y:
			if point.x < ledge.position.x:
				return "Caiu: pulo curto (ande mais ou mire mais reto)"
			if point.x > ledge.end.x:
				return "Caiu: pulo longo demais"
			return "Caiu"
	return "Caiu: a plataforma está mais alta"


func _walk_to(x: float, from_x: float) -> void:
	_feet.x = x
	_pose = 1 + int(absf(x - from_x) / 12.0) % 2


func _fly(points: Array, falling: bool) -> void:
	var count := points.size()
	await animate(_fly_step.bind(points, falling), 0.0, float(count - 1), count * DT)


func _fly_step(value: float, points: Array, falling: bool) -> void:
	_feet = points[clampi(int(value), 0, points.size() - 1)]
	if falling:
		_spin = value * 0.08 * (-1.0 if _facing_left else 1.0)


func solution() -> Dictionary:
	return {"actions": _solution.duplicate(true), "output": []}


func preview_text(actions: Array, _output: Array) -> String:
	var jumps := 0
	var walk := 0
	for entry in actions:
		if entry["kind"] == "JUMP":
			jumps += 1
		else:
			walk += int(entry["intensity"])
	return "%d %s, anda %d" % [jumps, "pulo" if jumps == 1 else "pulos", walk]


func _draw() -> void:
	_draw_backdrop()
	# Plataformas de pedra.
	for index in range(platforms.size()):
		var ledge: Rect2 = platforms[index]
		draw_rect(ledge, WALL_DARK)
		draw_rect(Rect2(ledge.position, Vector2(ledge.size.x, PX)), WALL)
		var brick := 0.0
		while brick < ledge.size.x:
			draw_rect(Rect2(ledge.position + Vector2(brick, PX * 2.0), Vector2(PX, ledge.size.y - PX * 2.0)), FLOOR)
			brick += 24.0
	# Bandeira na plataforma final.
	var flag_ledge: Rect2 = platforms[goal]
	var pole := Vector2(flag_ledge.end.x - 20.0, flag_ledge.position.y)
	draw_rect(Rect2(pole - Vector2(0.0, 64.0), Vector2(PX, 64.0)), WALL)
	var wave := sin(clock * 6.0) * 3.0
	var top := pole - Vector2(0.0, 64.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(PX, 0.0), top + Vector2(34.0, 10.0 + wave), top + Vector2(PX, 20.0)]), GOLD if _flag_up < 0.5 else GOOD)
	# Régua na plataforma do cavaleiro: marcas a cada 4 pontos de Andar.
	if not _busy:
		var ledge: Rect2 = platforms[_on]
		for direction in [1.0, -1.0]:
			var mark := 1
			while true:
				var x: float = _feet.x + float(direction) * mark * 4.0 * STEP
				if x < ledge.position.x or x > ledge.end.x:
					break
				draw_rect(Rect2(Vector2(x - PX * 0.5, ledge.position.y - PX), Vector2(PX, PX)), Color(GOLD, 0.7))
				text(Vector2(x - 12.0, ledge.position.y + 16.0), str(mark * 4), Color(GOLD, 0.8), false, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
				mark += 1
	# Rastro do último pulo (para ajustar o ângulo).
	for index in range(0, _ghost.size(), 6):
		var point: Vector2 = _ghost[index]
		draw_rect(Rect2(point.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color(GOLD, 0.45))
	# Transferidor em volta do cavaleiro: um ponto a cada 15 graus, número a cada 30.
	var pivot := _feet - Vector2(0.0, 24.0)
	for angle in range(0, 181, 15):
		var direction := Vector2.from_angle(deg_to_rad(-angle))
		var tip := pivot + direction * 58.0
		draw_rect(Rect2(tip.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), ArenaPixelArt.tint(0.3 if angle % 30 else 0.55))
		if angle % 30 == 0 and angle > 0 and angle < 180:
			text(pivot + direction * 82.0 + Vector2(-20.0, 6.0), str(angle), ArenaPixelArt.tint(0.5), false, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	var rows: Array = KNIGHT + LEGS[_pose]
	if _spin != 0.0:
		draw_set_transform(_feet - Vector2(0.0, 24.0), _spin, Vector2.ONE)
		stamp(rows, KNIGHT_PALETTE, Vector2(-18.0, -24.0), 3.0, _facing_left)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		stamp(rows, KNIGHT_PALETTE, (_feet - Vector2(6.0 * 3.0, 16.0 * 3.0)).snapped(Vector2(3.0, 3.0)), 3.0, _facing_left)
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	draw_stars()
	draw_moon(Vector2(area.end.x - 120.0, area.position.y + 70.0))
	draw_hills(area.end.y, 70.0, Color("0d1428"), 1.3)
	# Castelo ao longe.
	var base := Vector2(area.position.x + area.size.x * 0.55, area.end.y - 40.0)
	var castle := Color("0b1122")
	draw_rect(Rect2(base + Vector2(0.0, -90.0), Vector2(180.0, 90.0)), castle)
	draw_rect(Rect2(base + Vector2(-30.0, -140.0), Vector2(44.0, 140.0)), castle)
	draw_rect(Rect2(base + Vector2(166.0, -150.0), Vector2(44.0, 150.0)), castle)
	for merlon in range(9):
		draw_rect(Rect2(base + Vector2(merlon * 20.0, -98.0), Vector2(12.0, 8.0)), castle)
	draw_rect(Rect2(base + Vector2(-14.0, -120.0), Vector2(8.0, 12.0)), Color(GOLD, 0.35))
	draw_rect(Rect2(base + Vector2(184.0, -126.0), Vector2(8.0, 12.0)), Color(GOLD, 0.35))
