extends Node2D

## Número de dano que sobe e some, na fonte pixel, com contorno escuro.

const DURATION := 0.75
const RISE_SPEED := 34.0

var text := ""
var color := Color("ffd38a")
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y -= RISE_SPEED * delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0 - clampf((_t - 0.35) / 0.4, 0.0, 1.0)
	var font := ArenaPixelArt.FONT
	var font_size := ArenaPixelArt.FONT_SIZE
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var at := Vector2(snappedf(-width * 0.5, 2.0), 0.0)
	for offset in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
		draw_string(font, at + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.08, 0.06, 0.1, alpha))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(color, alpha))
