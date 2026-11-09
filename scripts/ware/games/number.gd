extends "res://scripts/ware/microgame.gd"

## NÚMERO MÁGICO: entregue o número pedido ao caldeirão. As runas Número só
## vão até 9 e são poucas: é preciso somar, multiplicar ou subtrair na pilha
## e terminar com Entregar.

const CAULDRON := [
	"..kkkkkkkkkkkk..",
	".kggggggggggggk.",
	"kggwggggggggwggk",
	"kkkkkkkkkkkkkkkk",
	".kmmmmmmmmmmmmk.",
	"kmmmmmmmmmmmmmmk",
	"kmmmmmmmmmmmmmmk",
	"kmmmmmmmmmmmmmmk",
	".kmmmmmmmmmmmmk.",
	"..kmmmmmmmmmmk..",
	"...kkkkkkkkkk...",
	"...kk......kk...",
]

var target := 0
var _program: Array = []
var _shown := ""
var _drop := -1.0
var _result := 0
var _bubble := 0.0


func _init() -> void:
	title = "NÚMERO MÁGICO"
	instruction = "ENTREGUE O NÚMERO!"
	runes = ["ORB", "TWIN", "DIAMOND", "MOON", "PLUS", "TRIANGLE"]
	default_intensity = {"ORB": 1}
	max_intensity = {"ORB": 9}


func build(new_level: int) -> void:
	var a := rng.randi_range(2, 9)
	var b := rng.randi_range(2, 9)
	var c := rng.randi_range(1, 9)
	match clampi(new_level, 1, 5):
		1:
			a = rng.randi_range(4, 9)
			b = rng.randi_range(4, 9)
			target = a + b
			_program = [action("ORB", a), action("ORB", b), action("DIAMOND", 0), action("TRIANGLE", 0)]
			limits = {"ORB": 2}
		2:
			a = rng.randi_range(3, 9)
			b = rng.randi_range(3, 9)
			target = a * b
			_program = [action("ORB", a), action("ORB", b), action("PLUS", 0), action("TRIANGLE", 0)]
			limits = {"ORB": 2}
		3:
			target = a * b + c
			_program = [action("ORB", a), action("ORB", b), action("PLUS", 0), action("ORB", c), action("DIAMOND", 0), action("TRIANGLE", 0)]
			limits = {"ORB": 3}
		4:
			a = rng.randi_range(5, 9)
			b = rng.randi_range(5, 9)
			target = a * b - c
			_program = [action("ORB", a), action("ORB", b), action("PLUS", 0), action("ORB", c), action("MOON", 0), action("TRIANGLE", 0)]
			limits = {"ORB": 3}
		_:
			if rng.randf() < 0.5:
				a = rng.randi_range(3, 9)
				b = rng.randi_range(3, 9)
				c = rng.randi_range(2, 5)
				target = a * b * c
				_program = [action("ORB", a), action("ORB", b), action("PLUS", 0), action("ORB", c), action("PLUS", 0), action("TRIANGLE", 0)]
				limits = {"ORB": 3}
			else:
				# Quadrado mais um: com só 2 Números, Copiar faz o resto.
				a = rng.randi_range(6, 9)
				b = rng.randi_range(1, 9)
				target = a * a + b
				_program = [action("ORB", a), action("TWIN", 0), action("PLUS", 0), action("ORB", b), action("DIAMOND", 0), action("TRIANGLE", 0)]
				limits = {"ORB": 2}
	objective = "Monte o número na pilha. Número empilha até 9 (só %d). Copiar duplica o topo. Somar, Subtrair e Multiplicar juntam os dois do topo. Termine com Entregar." % int(limits["ORB"])


func reset_world() -> void:
	_shown = ""
	_drop = -1.0
	_result = 0
	fail_reason = ""
	queue_redraw()


func _process(delta: float) -> void:
	_bubble += delta
	queue_redraw()


func execute(_actions: Array, output: Array) -> bool:
	if output.is_empty():
		fail_reason = "Nada foi entregue (use Entregar)"
		return false
	var middle := area.get_center()
	var mouth := Vector2(middle.x, area.end.y - 12.0 * 12.0 - 12.0)
	for value in output:
		_shown = str(value)
		_result = 0
		sfx("deliver")
		await animate(func(progress: float) -> void: _drop = progress, 0.0, 1.0, 0.5)
		_drop = -1.0
		sfx("bubble")
		if int(value) == target:
			_result = 1
			sfx("coin")
			burst(mouth, GOLD, 20, 180.0, 0.8, 120.0, PX * 1.5)
			queue_redraw()
			await wait(0.4)
			return true
		_result = -1
		sfx("bump")
		kick(5.0)
		burst(mouth, Color("8a8f99", 0.8), 14, 70.0, 0.9, -60.0, PX * 2.0)
		queue_redraw()
		await wait(0.4)
		fail_reason = "Entregou %s, era %d" % [str(value), target]
		return false
	return false


func solution() -> Dictionary:
	return {"actions": [], "output": [target]}


func solution_program() -> Array:
	return _program.duplicate(true)


func preview_text(_actions: Array, output: Array) -> String:
	if output.is_empty():
		return "Nada entregue ainda"
	return "Entrega: %s" % str(output[0])


func _draw() -> void:
	_draw_backdrop()
	var middle := area.get_center()
	text(Vector2(area.position.x, area.position.y + 36.0), "O CALDEIRÃO QUER", ArenaPixelArt.tint(0.6), true, HORIZONTAL_ALIGNMENT_CENTER, area.size.x)
	# Número pedido, grande (fonte em escala 4x).
	draw_string(ArenaPixelArt.FONT, Vector2(area.position.x, area.position.y + 110.0), str(target), HORIZONTAL_ALIGNMENT_CENTER, area.size.x, ArenaPixelArt.FONT_SIZE * 3, GOLD)
	var pixel := 12.0
	var pot := Vector2(middle.x - 8.0 * pixel, area.end.y - 12.0 * pixel - 12.0)
	var liquid := Color("7be08a") if _result >= 0 else BAD
	if _result > 0:
		liquid = GOLD
	stamp(CAULDRON, {"k": Color("1b1724"), "g": liquid, "w": Color(1, 1, 1, 0.8), "m": Color("3b4a66")}, pot.snapped(Vector2(PX, PX)), pixel)
	for bubble in range(4):
		var rise := fmod(_bubble * 0.8 + bubble * 0.25, 1.0)
		var at := pot + Vector2(40.0 + bubble * 36.0, -rise * 70.0)
		draw_rect(Rect2(at.snapped(Vector2(PX, PX)), Vector2(PX, PX) * 3.0), Color(liquid, 1.0 - rise))
	if _drop >= 0.0 and not _shown.is_empty():
		var from := Vector2(middle.x, area.position.y + 150.0)
		var to := pot + Vector2(8.0 * pixel, 0.0)
		var at := from.lerp(to, _drop * _drop)
		draw_string(ArenaPixelArt.FONT, at + Vector2(-100.0, 0.0), _shown, HORIZONTAL_ALIGNMENT_CENTER, 200.0, ArenaPixelArt.FONT_SIZE * 2, ArenaPixelArt.tint(1.0))
	draw_particles()
	if _drop >= 0.0:
		pass
	elif not _shown.is_empty():
		var color := GOOD if _result > 0 else BAD
		draw_string(ArenaPixelArt.FONT, Vector2(middle.x - 200.0, pot.y - 60.0), "entregou " + _shown, HORIZONTAL_ALIGNMENT_CENTER, 400.0, ArenaPixelArt.FONT_SIZE, color)


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Prateleiras com frascos dos dois lados.
	var colors := [Color("7be08a"), Color("b48cff"), Color("ff7a6a"), Color("7fd7ff")]
	for side in [0, 1]:
		var shelf_x := area.position.x + 40.0 if side == 0 else area.end.x - 260.0
		for shelf in range(3):
			var y := area.position.y + 150.0 + shelf * 110.0
			draw_rect(Rect2(Vector2(shelf_x, y), Vector2(220.0, PX * 2.0)), Color("4a3220"))
			for bottle in range(4):
				var at := Vector2(shelf_x + 16.0 + bottle * 52.0, y)
				var color: Color = colors[(bottle + shelf + side) % colors.size()]
				draw_rect(Rect2(at + Vector2(6.0, -36.0), Vector2(8.0, 8.0)), Color("8a9ab8", 0.5))
				draw_rect(Rect2(at + Vector2(0.0, -28.0), Vector2(20.0, 28.0)), Color(color, 0.25))
				draw_rect(Rect2(at + Vector2(0.0, -14.0), Vector2(20.0, 14.0)), Color(color, 0.45))
