extends Node2D

## Ossos de um esqueleto que morreu: cada pedaço voa com altura própria (falso
## 3D), quica, desliza e fica no chão um tempo antes de sumir. A posição do nó
## é o chão onde o esqueleto estava (serve para o y-sort).

const PX := 4.0
const GRAVITY := 900.0
const LIFETIME := 1.8
const FADE := 0.5
const BONE := Color("eee8d8")
const BONE_SHADE := Color("c7bfa9")
const OUTLINE := Color("1b1724")

## Direção do golpe (os ossos voam mais para esse lado).
var direction := Vector2.RIGHT
## Crânio desenhado com as linhas do esqueleto (para não duplicar o desenho).
var skull_rows: Array = []
var skull_palette: Dictionary = {}

var _bits: Array = []
var _t := 0.0


func _ready() -> void:
	var sizes := [Vector2i(3, 1), Vector2i(1, 3), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 1)]
	for size in sizes:
		_bits.append(_launch(size, 1.0))
	if not skull_rows.is_empty():
		var skull := _launch(Vector2i(8, 7), 0.8)
		skull["skull"] = true
		_bits.append(skull)


func _launch(size: Vector2i, strength: float) -> Dictionary:
	var angle := direction.angle() + randf_range(-1.3, 1.3)
	return {
		"pos": Vector2.ZERO, "z": 8.0 * PX, "size": size, "skull": false,
		"vel": Vector2.from_angle(angle) * randf_range(40.0, 150.0) * strength,
		"vz": randf_range(140.0, 300.0) * strength,
		"color": BONE if randf() < 0.6 else BONE_SHADE,
	}


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFETIME + FADE:
		queue_free()
		return
	for bit in _bits:
		if bit["z"] > 0.0 or bit["vz"] > 0.0:
			bit["vz"] -= GRAVITY * delta
			bit["z"] += bit["vz"] * delta
			bit["pos"] += bit["vel"] * delta
			if bit["z"] <= 0.0:
				bit["z"] = 0.0
				if bit["vz"] < -80.0:
					bit["vz"] = -bit["vz"] * 0.35
					bit["vel"] *= 0.55
				else:
					bit["vz"] = 0.0
		else:
			bit["vel"] *= exp(-8.0 * delta)
			bit["pos"] += bit["vel"] * delta
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf((_t - LIFETIME) / FADE, 0.0, 1.0)
	for bit in _bits:
		var size: Vector2i = bit["size"]
		var ground := Vector2(snappedf(bit["pos"].x, PX), snappedf(bit["pos"].y, PX))
		var lift := snappedf(bit["z"], PX)
		var shadow_width := float(size.x) * PX
		draw_rect(Rect2(ground + Vector2(-shadow_width * 0.5, 0.0), Vector2(shadow_width, PX)), Color(0.0, 0.0, 0.0, 0.3 * alpha))
		var top_left := ground - Vector2(float(size.x) * PX * 0.5, float(size.y) * PX + lift)
		if bit["skull"]:
			for y in range(skull_rows.size()):
				var row: String = skull_rows[y]
				for x in range(row.length()):
					if skull_palette.has(row[x]):
						var c: Color = skull_palette[row[x]]
						draw_rect(Rect2(top_left + Vector2(x, y) * PX, Vector2(PX, PX)), Color(c, c.a * alpha))
		else:
			draw_rect(Rect2(top_left - Vector2(PX, PX), Vector2(size) * PX + Vector2(PX, PX) * 2.0), Color(OUTLINE, alpha))
			draw_rect(Rect2(top_left, Vector2(size) * PX), Color(bit["color"], alpha))
