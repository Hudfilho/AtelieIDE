extends Node2D

## Base dos microjogos do Atelier Ware. Um microjogo é um desafio curto
## resolvido com um programa de runas: o jogador desenha o ritual, a VM roda e
## a pilha mágica vira uma lista de ações {kind, intensity}; o microjogo
## anima essas ações no seu mundo e diz se o objetivo foi cumprido.
##
## Para criar um microjogo: estenda este script, preencha os textos e a paleta
## em `_init`, monte o desafio em `build(level)` (use `rng`), devolva o mundo ao
## começo em `reset_world()`, anime em `execute()` e devolva uma solução em
## `solution()` (os testes usam para provar que todo desafio tem saída).

const PX := ArenaPixelArt.PIXEL
const Skeleton = preload("res://scripts/arena/skeleton.gd")
const WareSfx = preload("res://scripts/ware/ware_sfx.gd")

## Nome curto ("LABIRINTO") e a ordem do WarioWare ("CHEGUE NA SAÍDA!").
var title := ""
var instruction := ""
## Explicação curta que aparece no editor.
var objective := ""
## Runas da paleta (kinds) e limites (kind -> quantidade; ausente = infinita).
var runes: Array = []
var limits: Dictionary = {}
## kind -> "Nome: descrição" próprio do jogo (sobrepõe os nomes do editor).
var names: Dictionary = {}
var default_intensity: Dictionary = {}
var max_intensity: Dictionary = {}
## Área do mundo na tela (o runner define antes de build).
var area := Rect2(0.0, 100.0, 1280.0, 520.0)
## Multiplicador de velocidade das animações (sobe com o nível).
var speed := 1.0
var level := 1
var rng := RandomNumberGenerator.new()
## Por que a última tentativa falhou ("Bateu na parede").
var fail_reason := ""
## Relógio para animações paradas (respirar, piscar, balançar).
var clock := 0.0
## Partículas simples: {pos, vel, color, life, age, size, gravity}.
var particles: Array = []
var _shake := 0.0


## Monta o desafio do nível. Virtual.
func build(_new_level: int) -> void:
	pass


## O cartão da ordem saiu da tela e o jogador já pode programar. Virtual
## (os Sinos tocam a melodia aqui).
func start_round() -> void:
	pass


## Volta o mundo para o começo do desafio (para tentar de novo). Virtual.
func reset_world() -> void:
	pass


## Anima as ações no mundo; devolve true se o objetivo foi cumprido. Virtual.
func execute(_actions: Array, _output: Array) -> bool:
	return false


## Uma solução do desafio atual: {"actions": [...], "output": [...]}. Virtual.
func solution() -> Dictionary:
	return {"actions": [], "output": []}


## Programa de runas que resolve o desafio: [{kind, intensity}] na ordem em
## que as runas ficam no ritual. Por padrão, uma runa por ação da solução;
## jogos com laço (Portal) ou com pilha (Número) sobrescrevem.
func solution_program() -> Array:
	var program: Array = []
	for entry in solution()["actions"]:
		program.append(action(str(entry["kind"]), int(entry["intensity"])))
	return program


## Texto da prévia no editor. Pode ser sobrescrito.
func preview_text(actions: Array, _output: Array) -> String:
	return "%d %s" % [actions.size(), "ação" if actions.size() == 1 else "ações"]


## Parte do mundo que importa (o mapa do editor recorta nela).
func content_rect() -> Rect2:
	return area


## Setas sem máximo próprio vão até este valor: a barra de intensidade fica
## usável (0 a 20 em vez de 0 a 255).
const ARROW_MAX := 20


func setup(new_level: int, seed_value: int) -> void:
	level = new_level
	rng.seed = seed_value
	build(new_level)
	for kind in ["MOVE_UP", "MOVE_DOWN", "MOVE_LEFT", "MOVE_RIGHT"]:
		if runes.has(kind) and not max_intensity.has(kind):
			max_intensity[kind] = ARROW_MAX
	reset_world()
	queue_redraw()


## ======================== AJUDANTES ========================

func _physics_process(delta: float) -> void:
	clock += delta
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 30.0, 0.0)
		position = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	elif position != Vector2.ZERO:
		position = Vector2.ZERO
	for particle in particles:
		particle["age"] = float(particle["age"]) + delta
		particle["vel"] = (particle["vel"] as Vector2) + Vector2(0.0, float(particle["gravity"])) * delta
		particle["pos"] = (particle["pos"] as Vector2) + (particle["vel"] as Vector2) * delta
	if not particles.is_empty():
		particles = particles.filter(func(particle: Dictionary) -> bool: return float(particle["age"]) < float(particle["life"]))
	queue_redraw()


## Estouro de partículas quadradas (poeira, faíscas, respingos).
func burst(at: Vector2, color: Color, count := 8, speed_px := 90.0, life := 0.45, gravity := 0.0, size := PX) -> void:
	for index in range(count):
		var direction := Vector2.from_angle(TAU * index / count + randf_range(-0.4, 0.4))
		particles.append({"pos": at, "vel": direction * speed_px * randf_range(0.5, 1.0), "color": color, "life": life * randf_range(0.7, 1.0), "age": 0.0, "size": size, "gravity": gravity})


## Tremida da tela (o mundo inteiro), em pixels.
func kick(amount := 6.0) -> void:
	_shake = maxf(_shake, amount)


func draw_particles() -> void:
	for particle in particles:
		var fade := 1.0 - float(particle["age"]) / float(particle["life"])
		var size: float = particle["size"]
		draw_rect(Rect2((particle["pos"] as Vector2).snapped(Vector2(2.0, 2.0)) - Vector2(size, size) * 0.5, Vector2(size, size)), Color(particle["color"], (particle["color"] as Color).a * fade))


func sfx(sound_name: String, pitch := 1.0, volume_db := 0.0) -> void:
	WareSfx.play(sound_name, pitch, volume_db)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / maxf(speed, 0.1)).timeout


## Anima um valor de `from` até `to` chamando `setter`, e redesenha.
func animate(setter: Callable, from: Variant, to: Variant, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_method(_animate_step.bind(setter), from, to, seconds / maxf(speed, 0.1))
	await tween.finished


func _animate_step(value: Variant, setter: Callable) -> void:
	setter.call(value)
	queue_redraw()


static func action(kind: String, intensity: int) -> Dictionary:
	return {"kind": kind, "intensity": intensity}


static func direction_of(kind: String) -> Vector2i:
	match kind:
		"MOVE_UP":
			return Vector2i(0, -1)
		"MOVE_DOWN":
			return Vector2i(0, 1)
		"MOVE_LEFT":
			return Vector2i(-1, 0)
		"MOVE_RIGHT":
			return Vector2i(1, 0)
	return Vector2i.ZERO


static func kind_of_direction(direction: Vector2i) -> String:
	match direction:
		Vector2i(0, -1):
			return "MOVE_UP"
		Vector2i(0, 1):
			return "MOVE_DOWN"
		Vector2i(-1, 0):
			return "MOVE_LEFT"
	return "MOVE_RIGHT"


## Junta passos unitários em ações com intensidade (→→→↓ vira →3 ↓1).
static func compress_path(directions: Array) -> Array:
	var actions: Array = []
	for raw in directions:
		var direction: Vector2i = raw
		var kind := kind_of_direction(direction)
		if not actions.is_empty() and actions[-1]["kind"] == kind:
			actions[-1]["intensity"] += 1
		else:
			actions.append(action(kind, 1))
	return actions


## Grade centralizada na área: origem e tamanho da casa.
func grid_layout(columns: int, rows: int, max_tile := 56.0) -> Dictionary:
	var tile := floorf(minf(minf(area.size.x / columns, area.size.y / rows), max_tile) / PX) * PX
	var size := Vector2(columns, rows) * tile
	var origin := (area.position + (area.size - size) * 0.5).snapped(Vector2(PX, PX))
	return {"origin": origin, "tile": tile}


func cell_rect(origin: Vector2, tile: float, cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * tile, Vector2(tile, tile))


## Moldura pixel de 1 unidade (PX) na cor dada.
func frame_rect(rect: Rect2, color: Color, thickness := PX) -> void:
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, thickness)), color)
	draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - thickness), Vector2(rect.size.x, thickness)), color)
	draw_rect(Rect2(rect.position, Vector2(thickness, rect.size.y)), color)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - thickness, 0.0), Vector2(thickness, rect.size.y)), color)


## Mapa de caracteres desenhado com retângulos (cada caractere = `pixel` px).
func stamp(rows: Array, palette: Dictionary, top_left: Vector2, pixel := PX, flip := false) -> void:
	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var key := row[row.length() - 1 - x] if flip else row[x]
			if palette.has(key):
				draw_rect(Rect2(top_left + Vector2(x, y) * pixel, Vector2(pixel, pixel)), palette[key])


## O esqueleto do jogo como personagem de grade (quadro parado), com os pés em `feet`.
## `walk` usa os quadros de caminhada; `flip` vira para a esquerda.
func draw_skeleton(feet: Vector2, pixel := 2.0, frame := 0, flip := false, walk := false) -> void:
	Skeleton._ensure_frames()
	var frames: Array = Skeleton._walk_frames if walk else Skeleton._idle_frames
	var texture: Texture2D = frames[frame % frames.size()]
	var size := Vector2(Skeleton.W, Skeleton.H) * pixel
	var top_left := Vector2(feet.x - size.x * 0.5, feet.y - Skeleton.FEET_ROW * pixel).snapped(Vector2(pixel, pixel))
	draw_rect(Rect2(feet + Vector2(-5.0 * pixel, -pixel), Vector2(10.0 * pixel, 2.0 * pixel)), Color(0.0, 0.0, 0.0, 0.35))
	if flip:
		# Tamanho negativo espelha a textura sem mudar o canto de partida.
		draw_texture_rect(texture, Rect2(top_left, Vector2(-size.x, size.y)), false, Color.WHITE)
	else:
		draw_texture_rect(texture, Rect2(top_left, size), false, Color.WHITE)


## Céu com estrelas fixas (para os jogos vistos de lado).
func draw_stars(count := 60) -> void:
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 1234
	for index in range(count):
		var at := Vector2(seed_rng.randf_range(area.position.x, area.end.x), seed_rng.randf_range(area.position.y, area.end.y - 60.0))
		var bright := seed_rng.randf_range(0.08, 0.3)
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX) * (2.0 if index % 9 == 0 else 1.0)), ArenaPixelArt.tint(bright))


## Tocha de parede com chama que tremula (pés da chama em `at`).
func draw_torch(at: Vector2, pixel := 3.0) -> void:
	draw_rect(Rect2(at + Vector2(-pixel, 0.0), Vector2(pixel * 2.0, pixel * 6.0)), Color("6b4a2a"))
	draw_rect(Rect2(at + Vector2(-pixel * 2.0, 0.0), Vector2(pixel * 4.0, pixel)), Color("3b2a1a"))
	var flick := int(clock * 10.0 + at.x) % 3
	var heights := [4, 5, 3]
	var height: int = heights[flick]
	for row in range(height):
		var width := maxf(1.0, 3.0 - absf(row - 1.0)) * pixel
		var color := Color("ffcf4a") if row < 2 else Color("ff7a3d")
		draw_rect(Rect2(at + Vector2(-width * 0.5, -pixel * (row + 1)), Vector2(width, pixel)), color)
	draw_circle(at + Vector2(0.0, -pixel * 2.0), pixel * 9.0, Color(1.0, 0.7, 0.3, 0.05 + 0.02 * flick))


## Lua cheia pixel no céu.
func draw_moon(center: Vector2, radius := 28.0) -> void:
	ArenaPixelArt.draw_pixel_disc(self, center, radius + PX * 2.0, Color(1.0, 0.95, 0.8, 0.06))
	ArenaPixelArt.draw_pixel_disc(self, center, radius, Color("e8e2cc"))
	ArenaPixelArt.draw_pixel_disc(self, center + Vector2(radius * 0.3, -radius * 0.2), radius * 0.22, Color("cfc7ad"))
	ArenaPixelArt.draw_pixel_disc(self, center + Vector2(-radius * 0.35, radius * 0.3), radius * 0.16, Color("cfc7ad"))


## Morros escuros no horizonte (colunas pixel de alturas suaves).
func draw_hills(base_y: float, height: float, color: Color, phase := 0.0) -> void:
	var x := area.position.x
	while x < area.end.x:
		var h := (sin(x * 0.006 + phase) * 0.5 + 0.5) * height + (sin(x * 0.017 + phase * 2.0) * 0.5 + 0.5) * height * 0.35
		h = snappedf(h, PX)
		draw_rect(Rect2(Vector2(x, base_y - h), Vector2(PX * 2.0, h)), color)
		x += PX * 2.0


func text(at: Vector2, content: String, color := ArenaPixelArt.tint(0.9), big := false, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ArenaPixelArt.FONT if big else ArenaPixelArt.FONT_TINY
	var font_size := ArenaPixelArt.FONT_SIZE if big else ArenaPixelArt.FONT_TINY_SIZE
	draw_string(font, at, content, align, width, font_size, color)


## Cores comuns dos mundos.
const FLOOR := Color("121a33")
const FLOOR_ALT := Color("16203d")
const WALL := Color("6f7f99")
const WALL_DARK := Color("2a3350")
const GOLD := Color("ffcf4a")
const GOOD := Color("7be08a")
const BAD := Color("ff7a6a")
