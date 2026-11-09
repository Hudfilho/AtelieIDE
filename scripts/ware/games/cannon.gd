extends "res://scripts/ware/microgame.gd"

## CANHÃO: acerte o alvo. Mirar define o ângulo (0 = reto para a frente,
## 90 = para cima); Atirar dispara com a força da intensidade. O rastro do
## último tiro fica na tela para corrigir a mira.

const GRAVITY := 500.0
const FORCE_SPEED := 9.0
const DT := 1.0 / 120.0
const BALL_RADIUS := 6.0
const CANNON_BODY := [
	"..kkkkkk..",
	".kmmmmmmk.",
	"kmmmmmmmmk",
	"kmmkkkkmmk",
	"kmk.ww.kmk",
	"kmk.ww.kmk",
	".k......k.",
]

var ground := 0.0
var muzzle := Vector2.ZERO
var target := Vector2.ZERO
var target_radius := 24.0
var wall := Rect2()
var _angle := 0.0
var _ball := Vector2.ZERO
var _ball_visible := false
var _ghost: Array = []
var _hit := false
var _solution: Array = []
var _burst := 0.0
var _recoil := 0.0
## Nível 5: vento (aceleração horizontal, px/s²). Negativo sopra para a esquerda.
var wind := 0.0
var _trail: Array = []


func _init() -> void:
	title = "CANHÃO"
	instruction = "ACERTE O ALVO!"
	objective = "Mirar: ângulo (0 é reto, 90 é para cima). Atirar: a intensidade é a força. O rastro mostra o último tiro."
	runes = ["AIM", "SHOOT"]
	default_intensity = {"AIM": 45, "SHOOT": 50}
	max_intensity = {"AIM": 90, "SHOOT": 99}
	names = {
		"AIM": "Mirar: gira o canhão, a intensidade é o ângulo (0 a 90)",
		"SHOOT": "Atirar: dispara a bala, a intensidade é a força (até 99)",
	}


func build(new_level: int) -> void:
	ground = area.end.y - 40.0
	muzzle = Vector2(area.position.x + 90.0, ground - 34.0)  # pé do canhão no chão (corpo 7 x 6 px)
	target_radius = 26.0 if new_level <= 2 else (22.0 if new_level <= 4 else 18.0)
	limits = {} if new_level <= 1 else {"SHOOT": 1}
	wind = 0.0
	if new_level >= 5:
		wind = rng.randf_range(40.0, 110.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	objective = "Mirar: ângulo (0 é reto, 90 é para cima). Atirar: a intensidade é a força. O rastro mostra o último tiro."
	if wind != 0.0:
		objective += " Tem vento: a biruta mostra para onde ele sopra."
	for _attempt in range(200):
		var angle := rng.randi_range(5, 14) * 5
		var force := rng.randi_range(40, 90)
		var points := _trajectory(angle, force, false)
		var candidates: Array = []
		for index in range(1, points.size()):
			var point: Vector2 = points[index]
			if point.y > (points[index - 1] as Vector2).y and point.x > muzzle.x + 280.0 and point.x < area.end.x - 50.0 and point.y < ground - 40.0 and point.y > area.position.y + 40.0:
				candidates.append(point)
		if candidates.is_empty():
			continue
		target = candidates[rng.randi_range(0, candidates.size() - 1)]
		wall = Rect2()
		if new_level >= 3:
			# Muro entre o canhão e o alvo, logo abaixo do tiro certo.
			var wall_x := rng.randf_range(muzzle.x + 140.0, target.x - 120.0)
			var clearance := 1.0e9
			for point in points:
				if absf((point as Vector2).x - wall_x) < 20.0:
					clearance = minf(clearance, (point as Vector2).y)
			var top := clearance + 36.0
			if top > ground - 60.0:
				continue
			wall = Rect2(wall_x - 12.0, top, 24.0, ground - top)
		_solution = [action("AIM", angle), action("SHOOT", force)]
		if _shot_hits(angle, force) and _stays_on_screen(angle, force):
			return
	push_error("Canhão: não consegui gerar o alvo")


## O tiro certo não pode sumir por cima da tela.
func _stays_on_screen(angle: int, force: int) -> bool:
	for point in _trajectory(angle, force, true):
		if (point as Vector2).y < area.position.y + 16.0:
			return false
	return true


func _shot_hits(angle: int, force: int) -> bool:
	var points := _trajectory(angle, force, true)
	return (points[-1] as Vector2).distance_to(target) <= target_radius + BALL_RADIUS


func reset_world() -> void:
	_angle = 30.0
	_ball_visible = false
	_hit = false
	_burst = 0.0
	_recoil = 0.0
	_trail.clear()
	fail_reason = ""
	queue_redraw()


## Pontos do voo; com `stop`, para no alvo, no muro ou no chão.
func _trajectory(angle: float, force: float, stop: bool) -> Array:
	var direction := Vector2.from_angle(deg_to_rad(-angle))
	var position := muzzle + direction * 30.0
	var velocity := direction * force * FORCE_SPEED
	var points: Array = [position]
	var time := 0.0
	while time < 8.0:
		time += DT
		velocity.y += GRAVITY * DT
		velocity.x += wind * DT
		position += velocity * DT
		points.append(position)
		if position.y >= ground or position.x > area.end.x + 40.0:
			break
		if stop and (position.distance_to(target) <= target_radius + BALL_RADIUS or (wall.size.x > 0.0 and wall.grow(BALL_RADIUS).has_point(position))):
			break
	return points


func execute(actions: Array, _output: Array) -> bool:
	var missed := ""
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := clampi(int(entry["intensity"]), 0, 255)
		if kind == "AIM":
			sfx("turn")
			await animate(func(value: float) -> void: _angle = value, _angle, float(clampi(amount, 0, 90)), 0.25)
		elif kind == "SHOOT":
			var points := _trajectory(_angle, amount, true)
			_ghost = points
			_trail.clear()
			_ball_visible = true
			var count := points.size()
			var barrel := Vector2.from_angle(deg_to_rad(-_angle))
			sfx("shoot")
			kick(4.0)
			burst(muzzle + barrel * 40.0, Color("c9d3e0", 0.8), 10, 70.0, 0.6, -40.0, PX * 2.0)
			var tween := create_tween()
			tween.tween_method(func(value: float) -> void: _recoil = value, 1.0, 0.0, 0.3)
			await animate(_ball_step.bind(points), 0.0, float(count - 1), count * DT)
			_ball_visible = false
			var end: Vector2 = points[-1]
			if end.distance_to(target) <= target_radius + BALL_RADIUS:
				_hit = true
				sfx("boom")
				kick(10.0)
				burst(target, Color("ff9a3d"), 18, 180.0, 0.6, 200.0, PX * 2.0)
				burst(target, Color("f3ead7"), 10, 120.0, 0.8, 300.0)
				await animate(func(value: float) -> void: _burst = value, 0.0, 1.0, 0.45)
				return true
			# Errou: poeira onde caiu (ou faísca no muro) e o motivo do erro.
			sfx("land")
			burst(end, Color(WALL, 0.8), 10, 90.0, 0.45, 150.0)
			missed = _miss_reason(points)
	fail_reason = missed if not missed.is_empty() else "Não atirou"
	return false


## "Faltou força", "Passou do alvo"... para corrigir no próximo ritual.
func _miss_reason(points: Array) -> String:
	var end: Vector2 = points[-1]
	if wall.size.x > 0.0 and wall.grow(BALL_RADIUS).has_point(end):
		return "Bateu no muro: mire mais alto"
	for point in points:
		if absf((point as Vector2).x - target.x) < 6.0:
			return "Passou por cima do alvo" if (point as Vector2).y < target.y else "Passou por baixo do alvo"
	return "Faltou força: caiu antes do alvo" if end.x < target.x else "Passou do alvo"


func _ball_step(value: float, points: Array) -> void:
	_ball = points[clampi(int(value), 0, points.size() - 1)]
	if _trail.is_empty() or (_trail[-1] as Vector2).distance_to(_ball) > 14.0:
		_trail.append(_ball)
		if _trail.size() > 12:
			_trail.pop_front()


func solution() -> Dictionary:
	return {"actions": _solution.duplicate(true), "output": []}


func preview_text(actions: Array, _output: Array) -> String:
	var aim := 30
	var shots: Array = []
	for entry in actions:
		if entry["kind"] == "AIM":
			aim = int(entry["intensity"])
		elif entry["kind"] == "SHOOT":
			shots.append("mira %d força %d" % [aim, int(entry["intensity"])])
	return "Nenhum tiro" if shots.is_empty() else ", ".join(shots.slice(0, 2))


func _draw() -> void:
	_draw_backdrop()
	draw_rect(Rect2(Vector2(area.position.x, ground), Vector2(area.size.x, area.end.y - ground)), WALL_DARK)
	draw_rect(Rect2(Vector2(area.position.x, ground), Vector2(area.size.x, PX)), WALL)
	# Régua no chão: uma marca a cada 100 px a partir do canhão.
	var mark := 1
	while muzzle.x + mark * 100.0 < area.end.x:
		var x := muzzle.x + mark * 100.0
		draw_rect(Rect2(Vector2(x, ground + PX), Vector2(PX, PX * 2.0)), ArenaPixelArt.tint(0.35))
		text(Vector2(x + 6.0, ground + 24.0), str(mark), ArenaPixelArt.tint(0.35))
		mark += 1
	if wall.size.x > 0.0:
		draw_rect(wall, WALL)
		var brick := wall.position.y
		while brick < wall.end.y:
			draw_rect(Rect2(Vector2(wall.position.x, brick), Vector2(wall.size.x, PX)), WALL_DARK)
			brick += 16.0
	# Alvo.
	if not _hit:
		# Estaca do alvo até o chão.
		draw_rect(Rect2(Vector2(target.x - PX * 0.5, target.y), Vector2(PX, ground - target.y)), Color("6b4a2a"))
		for ring in range(3):
			var radius := target_radius * (1.0 - ring * 0.33)
			ArenaPixelArt.draw_pixel_disc(self, target, radius, BAD if ring % 2 == 0 else Color("f3ead7"))
	else:
		for spark in range(10):
			var direction := Vector2.from_angle(spark * TAU / 10.0)
			var at := target + direction * _burst * 60.0
			draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX) * 2.0), Color(GOLD, 1.0 - _burst))
	# Rastro.
	for index in range(0, _ghost.size(), 5):
		var point: Vector2 = _ghost[index]
		draw_rect(Rect2(point.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color(GOLD, 0.4))
	# Transferidor.
	for angle in [0, 15, 30, 45, 60, 75, 90]:
		var tip := muzzle + Vector2.from_angle(deg_to_rad(-angle)) * 64.0
		draw_rect(Rect2(tip.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), ArenaPixelArt.tint(0.3))
		if angle % 30 == 0:
			text(muzzle + Vector2.from_angle(deg_to_rad(-angle)) * 84.0 - Vector2(8.0, -6.0), str(angle), ArenaPixelArt.tint(0.4))
	# Cano (gira e recua no tiro) e base.
	var barrel := Vector2.from_angle(deg_to_rad(-_angle))
	for step in range(0, 40, int(PX)):
		var at := muzzle + barrel * (float(step) - _recoil * 8.0)
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 2.0, Vector2(PX, PX) * 4.0), Color("1b1724"))
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 1.5, Vector2(PX, PX) * 3.0), Color("5a6a88"))
	stamp(CANNON_BODY, {"k": Color("1b1724"), "m": Color("5a6a88"), "w": Color("b07a3c")}, (muzzle + Vector2(-30.0, -8.0)).snapped(Vector2(2.0, 2.0)), 6.0)
	for index in range(_trail.size()):
		var puff: Vector2 = _trail[index]
		draw_rect(Rect2(puff.snapped(Vector2(PX, PX)) - Vector2(PX, PX), Vector2(PX, PX) * 2.0), Color("c9d3e0", 0.08 * index))
	if _ball_visible:
		ArenaPixelArt.draw_pixel_disc(self, _ball, BALL_RADIUS + 2.0, ArenaPixelArt.tint(0.6))
		ArenaPixelArt.draw_pixel_disc(self, _ball, BALL_RADIUS, Color("1b1724"))
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	draw_stars()
	if wind != 0.0:
		# Biruta: aponta para onde o vento sopra; mais gomos, mais forte.
		var pole := Vector2(area.position.x + area.size.x * 0.5, ground)
		draw_rect(Rect2(pole - Vector2(0.0, 110.0), Vector2(PX, 110.0)), WALL)
		var strength := clampi(int(absf(wind) / 25.0), 1, 4)
		var direction := 1.0 if wind > 0.0 else -1.0
		for segment in range(strength):
			var wave := sin(clock * 8.0 + segment) * 2.0
			var at := pole + Vector2(PX + direction * segment * 16.0 + (0.0 if direction > 0.0 else -16.0), -110.0 + wave)
			draw_rect(Rect2(at, Vector2(16.0, 12.0 - segment * 2.0)), BAD if segment % 2 == 0 else Color("f3ead7"))
		text(pole + Vector2(-120.0, -122.0), "VENTO %d %s" % [strength, "para a direita" if wind > 0.0 else "para a esquerda"], ArenaPixelArt.tint(0.6), false, HORIZONTAL_ALIGNMENT_CENTER, 240.0)
	draw_moon(Vector2(area.position.x + area.size.x * 0.45, area.position.y + 60.0), 22.0)
	draw_hills(ground, 90.0, Color("0d1428"), 0.4)
	draw_hills(ground, 50.0, Color("111a33"), 2.1)
