extends "res://scripts/ware/microgame.gd"

## ESQUELETOS: defenda a muralha. Os esqueletos andam pelas fileiras quando o
## ritual começa; cada Projétil atira na fileira da intensidade (1 é a de cima)
## e acerta o primeiro esqueleto dela. Cada tiro leva um tempinho: a ordem
## importa, os mais perto primeiro.

const BoneDebris = preload("res://scripts/arena/bone_debris.gd")
const LANES := 5
const HELMET := [
	"..kkkk..",
	".kmmmmk.",
	"kmmwmmmk",
	"kmmmmmmk",
]
const SHOT_TIME := 0.45
const MAGE := [
	"....kkk.....",
	"...kpppk....",
	"..kpppppk...",
	".kpppyppk...",
	"kkkkkkkkkkk.",
	"..kssssk....",
	"..ksksk.....",
	"..kssssk....",
	".kpppppk..w.",
	"kpppppppk.w.",
	"kppyppppkkw.",
	"kpppppppk.w.",
	".kpppppk..w.",
	".kkkkkkk..w.",
]

var wall_x := 0.0
var walk_speed := 40.0
## Cada esqueleto: {"lane": 1..5, "start": x inicial, "hp": golpes, "alive": bool}.
## Do nível 3 em diante alguns usam elmo e aguentam 2 tiros (Duplicar ajuda).
var skeletons: Array = []
var _time := 0.0
var _bolt := Vector2(-1.0, -1.0)
var _clock := 0.0
var _cracked := false


func _init() -> void:
	title = "ESQUELETOS"
	instruction = "DEFENDA A MURALHA!"
	runes = ["PROJECTILE", "DUPLICATE"]
	default_intensity = {"PROJECTILE": 1}
	max_intensity = {"PROJECTILE": LANES}
	names = {"PROJECTILE": "Projétil: atira na fileira da intensidade (1 é a de cima) e acerta o primeiro esqueleto"}
	objective = "Projétil atira na fileira da intensidade (1 é a de cima). Os esqueletos andam quando o ritual começa: derrube os mais perto primeiro."


func build(new_level: int) -> void:
	wall_x = area.position.x + 150.0
	walk_speed = 35.0 + 10.0 * new_level
	var count: int = [3, 4, 4, 5, 6][clampi(new_level, 1, 5) - 1]
	skeletons.clear()
	var shots := 0
	for index in range(count):
		var hp := 2 if new_level >= 3 and rng.randf() < 0.15 * new_level else 1
		shots += hp
		var arrival := 2.0 + (shots - 1) * SHOT_TIME * 1.6 + rng.randf_range(0.0, 0.6)
		skeletons.append({"lane": rng.randi_range(1, LANES), "start": wall_x + 30.0 + arrival * walk_speed, "hp": hp, "max_hp": hp, "alive": true})
	if skeletons.any(func(skeleton: Dictionary) -> bool: return int(skeleton["max_hp"]) > 1):
		objective = "Projétil atira na fileira da intensidade (1 é a de cima). Esqueleto de elmo aguenta 2 tiros: Duplicar repete o tiro."
	else:
		objective = "Projétil atira na fileira da intensidade (1 é a de cima). Os esqueletos andam quando o ritual começa: derrube os mais perto primeiro."


func reset_world() -> void:
	_time = 0.0
	_cracked = false
	_bolt = Vector2(-1.0, -1.0)
	for skeleton in skeletons:
		skeleton["alive"] = true
		skeleton["hp"] = skeleton["max_hp"]
	fail_reason = ""
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func lane_y(lane: int) -> float:
	return area.position.y + (lane - 0.5) * area.size.y / LANES + 26.0


func skeleton_x(skeleton: Dictionary) -> float:
	return float(skeleton["start"]) - walk_speed * _time


func _reached_wall() -> bool:
	for skeleton in skeletons:
		if skeleton["alive"] and skeleton_x(skeleton) <= wall_x + 30.0:
			return true
	return false


func _closest_in(lane: int) -> int:
	var best := -1
	for index in range(skeletons.size()):
		var skeleton: Dictionary = skeletons[index]
		if skeleton["alive"] and int(skeleton["lane"]) == lane and (best < 0 or float(skeleton["start"]) < float(skeletons[best]["start"])):
			best = index
	return best


func execute(actions: Array, _output: Array) -> bool:
	for entry in actions:
		if str(entry["kind"]) != "PROJECTILE":
			continue
		var lane := int(entry["intensity"])
		var hit := _closest_in(lane) if lane >= 1 and lane <= LANES else -1
		var from_time := _time
		sfx("shoot", 1.2)
		await animate(_fly.bind(lane, hit, from_time), 0.0, 1.0, SHOT_TIME)
		var bolt_end := _bolt
		_bolt = Vector2(-1.0, -1.0)
		if _reached_wall():
			await _breach()
			return false
		if hit < 0:
			burst(bolt_end, Color("ff9a3d", 0.7), 6, 60.0, 0.3)
		if hit >= 0 and int(skeletons[hit]["hp"]) > 1:
			# Elmo voa: o esqueleto continua andando.
			skeletons[hit]["hp"] = int(skeletons[hit]["hp"]) - 1
			sfx("hit", 1.6)
			burst(bolt_end + Vector2(0.0, -18.0), Color("8a9ab8"), 10, 140.0, 0.5, 300.0)
			continue
		if hit >= 0:
			skeletons[hit]["alive"] = false
			sfx("hit")
			sfx("bones")
			kick(3.0)
			burst(bolt_end, Color("ff9a3d"), 10, 120.0, 0.4)
			var debris := BoneDebris.new()
			debris.position = Vector2(skeleton_x(skeletons[hit]), lane_y(lane))
			debris.skull_rows = Skeleton.HEAD
			debris.skull_palette = Skeleton.PALETTE
			add_child(debris)
			if skeletons.all(func(skeleton: Dictionary) -> bool: return not skeleton["alive"]):
				await wait(0.4)
				return true
	# Sobrou esqueleto: eles seguem andando até a muralha.
	var reach := INF
	for skeleton in skeletons:
		if skeleton["alive"]:
			reach = minf(reach, (float(skeleton["start"]) - wall_x - 30.0) / walk_speed)
	var from := _time
	await animate(func(value: float) -> void: _time = value, from, maxf(reach, from), clampf(reach - from, 0.2, 1.5))
	await _breach()
	fail_reason = "Sobrou esqueleto"
	return false


## Esqueleto encostou na muralha: pedra voa e a tela treme.
func _breach() -> void:
	fail_reason = "Um esqueleto chegou na muralha"
	_cracked = true
	sfx("boom")
	kick(10.0)
	for skeleton in skeletons:
		if skeleton["alive"] and skeleton_x(skeleton) <= wall_x + 31.0:
			burst(Vector2(wall_x + 8.0, lane_y(int(skeleton["lane"])) - 24.0), WALL, 14, 150.0, 0.6, 300.0, PX * 1.5)
	await wait(0.4)


func _fly(progress: float, lane: int, hit: int, from_time: float) -> void:
	_time = from_time + progress * SHOT_TIME
	var to_x := area.end.x if hit < 0 else skeleton_x(skeletons[hit])
	_bolt = Vector2(lerpf(wall_x + 20.0, to_x, progress), lane_y(maxi(lane, 1)) - 26.0)


func solution() -> Dictionary:
	var order := range(skeletons.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(skeletons[a]["start"]) < float(skeletons[b]["start"]))
	var actions: Array = []
	for index in order:
		for _shot in range(int(skeletons[index]["max_hp"])):
			actions.append(action("PROJECTILE", int(skeletons[index]["lane"])))
	return {"actions": actions, "output": []}


func solution_program() -> Array:
	# Tiros iguais seguidos viram Duplicar + Projétil.
	var program: Array = []
	var actions: Array = solution()["actions"]
	var index := 0
	while index < actions.size():
		if index + 1 < actions.size() and actions[index + 1]["intensity"] == actions[index]["intensity"]:
			program.append(action("DUPLICATE", 0))
			index += 1
		program.append(actions[index].duplicate())
		index += 1
	return program


func preview_text(actions: Array, _output: Array) -> String:
	var lanes: Array = []
	for entry in actions.slice(0, 12):
		lanes.append(str(entry["intensity"]))
	return "Fileiras: " + " ".join(lanes)


func _draw() -> void:
	for lane in range(1, LANES + 1):
		var top := area.position.y + (lane - 1) * area.size.y / LANES
		draw_rect(Rect2(Vector2(wall_x, top), Vector2(area.end.x - wall_x, area.size.y / LANES)), FLOOR if lane % 2 == 0 else FLOOR_ALT)
		text(Vector2(wall_x - 30.0, lane_y(lane) - 14.0), str(lane), ArenaPixelArt.tint(0.8), true)
	_draw_backdrop()
	# Muralha.
	draw_rect(Rect2(Vector2(wall_x, area.position.y), Vector2(16.0, area.size.y)), WALL)
	var brick := area.position.y
	while brick < area.end.y:
		draw_rect(Rect2(Vector2(wall_x, brick), Vector2(16.0, PX)), WALL_DARK)
		brick += 20.0
	stamp(MAGE, {"k": Color("1b1724"), "p": Color("5b3fa0"), "y": GOLD, "s": Color("eee8d8"), "w": Color("b07a3c")}, Vector2(area.position.x + 30.0, area.get_center().y - 28.0).snapped(Vector2(PX, PX)), PX)
	var frame := int(_clock * 8.0)
	for skeleton in skeletons:
		if not skeleton["alive"]:
			continue
		var x := maxf(skeleton_x(skeleton), wall_x + 30.0)
		var feet := Vector2(x, lane_y(int(skeleton["lane"])))
		draw_skeleton(feet, 3.0, frame, true, _time > 0.0)
		if int(skeleton["hp"]) > 1:
			stamp(HELMET, {"k": Color("1b1724"), "m": Color("8a9ab8"), "w": Color("e8f6ff")}, (feet + Vector2(-12.0, -60.0)).snapped(Vector2(3.0, 3.0)), 3.0)
	if _bolt.x >= 0.0:
		for trail in range(1, 5):
			draw_rect(Rect2((_bolt - Vector2(trail * 10.0, 0.0)).snapped(Vector2(PX, PX)) - Vector2(PX, PX), Vector2(PX, PX) * 2.0), Color("ff9a3d", 0.6 - trail * 0.12))
		ArenaPixelArt.draw_pixel_disc(self, _bolt, 8.0, Color("ff9a3d"))
		ArenaPixelArt.draw_pixel_disc(self, _bolt, 4.0, GOLD)
	if _cracked:
		for crack in range(6):
			var at := Vector2(wall_x + 4.0 + (crack % 2) * 6.0, area.position.y + 30.0 + crack * area.size.y / 6.0)
			draw_rect(Rect2(at, Vector2(PX, PX * 3.0)), Color("1b1724"))
	draw_particles()


## Cenário de fundo (discreto, atrás do desafio).
func _draw_backdrop() -> void:
	# Lápides no fundo do campo, de onde os esqueletos vêm.
	for index in range(5):
		var at := Vector2(area.end.x - 40.0 - (index % 2) * 30.0, area.position.y + 30.0 + index * area.size.y / 5.0)
		draw_rect(Rect2(at, Vector2(20.0, 26.0)), Color("2a3350"))
		draw_rect(Rect2(at + Vector2(PX, PX), Vector2(20.0 - PX * 2.0, PX)), Color("3b4a66"))
