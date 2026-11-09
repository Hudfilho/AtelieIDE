extends "res://scripts/ware/microgame.gd"

## TORRETA: derrube os cristais. Girar vira a torre no sentido do relógio pela
## intensidade em graus; Atirar dispara um raio reto que quebra o primeiro
## cristal no caminho. A munição é contada.

const CRYSTAL := [
	"...kk...",
	"..kwck..",
	".kwccck.",
	"kwcccdck",
	"kccccddk",
	".kccddk.",
	"..kcdk..",
	"...kk...",
]
const HIT_RADIUS := 24.0

var center := Vector2.ZERO
## Cada alvo: {"angle": graus (0 = cima, sentido do relógio), "distance": px, "alive": bool}.
var crystals: Array = []
var ammo := 0
var _heading := 0.0
var _beam := 0.0
var _beam_length := 0.0
var _shots := 0
var _bob := 0.0


func _init() -> void:
	title = "TORRETA"
	instruction = "QUEBRE OS CRISTAIS!"
	runes = ["TURN", "SHOOT", "DUPLICATE"]
	default_intensity = {"TURN": 90, "SHOOT": 1}
	# A linguagem guarda intensidade em 1 byte: 180 (meia volta) cabe com folga.
	max_intensity = {"TURN": 180}
	names = {
		"TURN": "Girar: gira a torre no sentido do relógio, a intensidade é em graus (até 180)",
		"SHOOT": "Atirar: dispara um raio reto (gasta 1 munição)",
	}


func build(new_level: int) -> void:
	center = area.get_center()
	var step := 45 if new_level <= 2 else (30 if new_level <= 3 else 15)
	var count: int = [2, 3, 3, 4, 4][clampi(new_level, 1, 5) - 1]
	ammo = count + (1 if new_level <= 3 else 0)
	objective = "Girar: graus no sentido do relógio, até 180 por runa (o 0 é para cima). Atirar quebra o primeiro cristal na linha. Munição: %d." % ammo
	crystals.clear()
	var used: Array = []
	while crystals.size() < count:
		var angle := rng.randi_range(0, 360 / step - 1) * step
		var too_close := false
		for other in used:
			var gap := absi(int(other) - angle) % 360
			if mini(gap, 360 - gap) < 40:
				too_close = true
		if too_close:
			continue
		used.append(angle)
		crystals.append({"angle": angle, "distance": rng.randf_range(130.0, minf(230.0, area.size.y * 0.5 - 30.0)), "alive": true})
	# Do nível 4 em diante, um cristal fica atrás de outro na mesma linha:
	# dois tiros na mesma direção (Duplicar ajuda).
	if new_level >= 4:
		var front: Dictionary = crystals[rng.randi_range(0, crystals.size() - 1)]
		front["distance"] = 140.0
		crystals.append({"angle": front["angle"], "distance": minf(230.0, area.size.y * 0.5 - 30.0), "alive": true})
		ammo += 1
		objective = "Girar: graus no sentido do relógio, até 180 por runa (o 0 é para cima). Atirar quebra só o primeiro cristal da linha. Munição: %d." % ammo


func content_rect() -> Rect2:
	return Rect2(center - Vector2(area.size.y, area.size.y) * 0.5, Vector2(area.size.y, area.size.y))


func reset_world() -> void:
	_heading = 0.0
	_beam = 0.0
	_shots = 0
	for crystal in crystals:
		crystal["alive"] = true
	fail_reason = ""
	queue_redraw()


func _process(delta: float) -> void:
	_bob += delta * 2.0
	queue_redraw()


static func direction_for(angle: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle - 90.0))


func crystal_position(crystal: Dictionary) -> Vector2:
	return center + direction_for(float(crystal["angle"])) * float(crystal["distance"])


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		var kind := str(entry["kind"])
		var amount := int(entry["intensity"])
		if kind == "TURN":
			var from := _heading
			await animate(_turn_step.bind(from), from, from + amount, clampf(amount / 360.0, 0.12, 0.6))
			_heading = fmod(_heading, 360.0)
		elif kind == "SHOOT":
			if _shots >= ammo:
				sfx("bump")
				fail_reason = "Acabou a munição"
				return false
			_shots += 1
			var hit := _first_hit()
			_beam_length = float(crystals[hit]["distance"]) if hit >= 0 else 900.0
			sfx("beam")
			kick(3.0)
			await animate(func(value: float) -> void: _beam = value, 1.0, 0.0, 0.2)
			if hit >= 0:
				crystals[hit]["alive"] = false
				sfx("crystal")
				kick(6.0)
				var at := crystal_position(crystals[hit])
				burst(at, Color("7fd7ff"), 14, 160.0, 0.6, 0.0, PX * 1.5)
				burst(at, Color("e8f6ff"), 8, 90.0, 0.4)
				if crystals.all(func(crystal: Dictionary) -> bool: return not crystal["alive"]):
					await wait(0.3)
					return true
	fail_reason = "Sobrou cristal"
	return false


## Um clique a cada 15 graus girados.
func _turn_step(value: float, from: float) -> void:
	if int((value - from) / 15.0) != int((_heading - from) / 15.0):
		sfx("turn", 1.0 + fmod(value, 360.0) / 720.0, -4.0)
	_heading = value


func _first_hit() -> int:
	var direction := direction_for(_heading)
	var best := -1
	var best_along := 1.0e9
	for index in range(crystals.size()):
		var crystal: Dictionary = crystals[index]
		if not crystal["alive"]:
			continue
		var offset := crystal_position(crystal) - center
		var along := offset.dot(direction)
		if along <= 0.0:
			continue
		var side := absf(offset.cross(direction))
		if side <= HIT_RADIUS and along < best_along:
			best = index
			best_along = along
	return best


func solution() -> Dictionary:
	var order := crystals.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["angle"]) < int(b["angle"]) or (int(a["angle"]) == int(b["angle"]) and float(a["distance"]) < float(b["distance"])))
	var actions: Array = []
	var heading := 0
	for crystal in order:
		var delta := (int(crystal["angle"]) - heading + 360) % 360
		while delta > 0:
			actions.append(action("TURN", mini(delta, 180)))
			delta -= mini(delta, 180)
		actions.append(action("SHOOT", 1))
		heading = int(crystal["angle"])
	return {"actions": actions, "output": []}


func solution_program() -> Array:
	# Dois tiros seguidos na mesma direção viram Duplicar + Atirar.
	var program: Array = []
	var actions: Array = solution()["actions"]
	var index := 0
	while index < actions.size():
		if actions[index]["kind"] == "SHOOT" and index + 1 < actions.size() and actions[index + 1]["kind"] == "SHOOT":
			program.append(action("DUPLICATE", 0))
			index += 1
		program.append((actions[index] as Dictionary).duplicate())
		index += 1
	return program


func preview_text(actions: Array, _output: Array) -> String:
	var shots := 0
	for entry in actions:
		if entry["kind"] == "SHOOT":
			shots += 1
	return "%d %s (munição %d)" % [shots, "tiro" if shots == 1 else "tiros", ammo]


func _draw() -> void:
	_draw_backdrop()
	# Anel com marcas a cada 15 graus.
	for angle in range(0, 360, 15):
		var tip := center + direction_for(angle) * 72.0
		var size := PX * (2.0 if angle % 45 == 0 else 1.0)
		draw_rect(Rect2(tip.snapped(Vector2(PX, PX)) - Vector2(size, size) * 0.5, Vector2(size, size)), ArenaPixelArt.tint(0.35))
		if angle % 45 == 0:
			text(center + direction_for(angle) * 98.0 + Vector2(-20.0, 6.0), str(angle), ArenaPixelArt.tint(0.45), false, HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	# Cristais.
	var pixel := 6.0
	for crystal in crystals:
		if not crystal["alive"]:
			continue
		var at := crystal_position(crystal) + Vector2(0.0, sin(_bob + float(crystal["angle"])) * 3.0)
		stamp(CRYSTAL, {"k": Color("1b1724"), "w": Color("e8f6ff"), "c": Color("7fd7ff"), "d": Color("3a8fd0")}, (at - Vector2(24.0, 24.0)).snapped(Vector2(2.0, 2.0)), pixel)
	# Raio.
	var direction := direction_for(_heading)
	if _beam > 0.0:
		for step in range(0, int(_beam_length), int(PX)):
			var at := center + direction * float(step)
			draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 2.0, Vector2(PX, PX) * 4.0), Color(GOLD, _beam * 0.3))
			draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX), Vector2(PX, PX) * 2.0), Color(1.0, 0.95, 0.7, _beam))
	else:
		# Mira tracejada: para onde o próximo tiro vai.
		for step in range(60, 260, int(PX) * 4):
			var at := center + direction * float(step)
			draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), Color(GOLD, 0.25))
	# Torre: base e cano.
	ArenaPixelArt.draw_pixel_disc(self, center, 32.0, Color("3b4a66"))
	ArenaPixelArt.draw_pixel_disc(self, center, 32.0, ArenaPixelArt.tint(0.8), PX)
	for step in range(0, 52, int(PX)):
		var at := center + direction * float(step)
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 2.0, Vector2(PX, PX) * 4.0), Color("1b1724"))
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)) - Vector2(PX, PX) * 1.5, Vector2(PX, PX) * 3.0), Color("8a9ab8"))
	ArenaPixelArt.draw_pixel_disc(self, center, 12.0, GOLD)
	draw_particles()
	# Munição: um tiquinho por tiro.
	var ammo_left := ammo - _shots
	var corner := Vector2(area.position.x + 24.0, area.end.y - 16.0)
	text(corner, "MUNIÇÃO", ArenaPixelArt.tint(0.6), false, HORIZONTAL_ALIGNMENT_LEFT)
	for index in range(ammo):
		var slot := Rect2(corner + Vector2(96.0 + index * 16.0, -14.0), Vector2(PX * 2.0, PX * 4.0))
		draw_rect(slot, GOLD if index < ammo_left else WALL_DARK)


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	draw_stars(80)
	# Radar: anéis que pulsam a partir da torre.
	for ring in range(3):
		var radius := fmod(clock * 40.0 + ring * 90.0, 270.0)
		var alpha := 0.08 * (1.0 - radius / 270.0)
		var steps := 64
		for index in range(steps):
			var at := center + Vector2.from_angle(TAU * index / steps) * radius
			draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX)), ArenaPixelArt.tint(alpha))
