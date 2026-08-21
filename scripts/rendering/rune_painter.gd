@tool
class_name AtelierRunePainter
extends RefCounted

## Desenho compartilhado dos glifos do Atelier.
##
## O alvo precisa estar dentro do próprio `_draw()`. Manter a geometria aqui
## permite que o canvas, a paleta e os componentes de UI usem exatamente as
## mesmas runas sem copiar centenas de linhas de desenho.

const CIRCLE_TEXTURE_SIZE := 64
const COMMON_RING_RATIO_KEYS := [11, 14, 22, 23, 27, 28, 39, 47]

static var _filled_circle_texture: Texture2D
static var _ring_textures: Dictionary = {}


static func prepare() -> void:
	_filled_circle_texture_for_draw()
	for ratio_key: int in COMMON_RING_RATIO_KEYS:
		_ring_texture_for_key(ratio_key)


static func draw_filled_circle(target: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0 or color.a <= 0.0:
		return
	var diameter := radius * 2.0
	target.draw_texture_rect(
			_filled_circle_texture_for_draw(),
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
			false,
			color)


static func draw_ring(target: CanvasItem, center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0 or width <= 0.0 or color.a <= 0.0:
		return
	var diameter := radius * 2.0
	var ratio_key := clampi(roundi(width / radius * 100.0), 2, 95)
	target.draw_texture_rect(
			_ring_texture_for_key(ratio_key),
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
			false,
			color)


static func draw_rune(target: CanvasItem, kind: String, center: Vector2, rune_scale: float, color: Color) -> void:
	if kind.is_empty() or rune_scale <= 0.0 or color.a <= 0.0:
		return
	var r := 11.0 * rune_scale
	var main_stroke := 2.5 * rune_scale
	var fine_stroke := 1.2 * rune_scale
	match kind:
		"ORB":
			draw_ring(target, center, r, color, main_stroke)
			draw_filled_circle(target, center, r * 0.28, color)
		"DIAMOND":
			var top := center + Vector2(0.0, -r)
			var right := center + Vector2(r, 0.0)
			var bottom := center + Vector2(0.0, r)
			var left := center + Vector2(-r, 0.0)
			target.draw_line(top, right, color, main_stroke, true)
			target.draw_line(right, bottom, color, main_stroke, true)
			target.draw_line(bottom, left, color, main_stroke, true)
			target.draw_line(left, top, color, main_stroke, true)
		"TRIANGLE":
			var a := center + Vector2(0.0, -r)
			var b := center + Vector2(r * 0.9, r * 0.75)
			var c := center + Vector2(-r * 0.9, r * 0.75)
			target.draw_line(a, b, color, main_stroke, true)
			target.draw_line(b, c, color, main_stroke, true)
			target.draw_line(c, a, color, main_stroke, true)
		"CROSS":
			target.draw_line(center + Vector2(-r, -r), center + Vector2(r, r), color, 2.8 * rune_scale, true)
			target.draw_line(center + Vector2(r, -r), center + Vector2(-r, r), color, 2.8 * rune_scale, true)
		"MOON":
			target.draw_arc(center + Vector2(r * 0.18, 0.0), r, PI * 0.55, PI * 1.45, 18, color, main_stroke, true)
			target.draw_arc(center + Vector2(-r * 0.22, 0.0), r * 0.76, PI * 1.55, PI * 0.45, 18, color, main_stroke, true)
		"PLUS":
			target.draw_line(center + Vector2(-r, 0.0), center + Vector2(r, 0.0), color, 2.6 * rune_scale, true)
			target.draw_line(center + Vector2(0.0, -r), center + Vector2(0.0, r), color, 2.6 * rune_scale, true)
			draw_ring(target, center, r * 0.28, color, fine_stroke)
		"SQUARE":
			var square := Rect2(center - Vector2(r * 0.75, r * 0.75), Vector2(r * 1.5, r * 1.5))
			target.draw_rect(square, color, false, 2.4 * rune_scale, true)
			target.draw_rect(square.grow(-r * 0.28), color, false, fine_stroke, true)
		"FORK":
			target.draw_line(center + Vector2(-r * 0.75, -r), center + Vector2(-r * 0.75, r), color, 2.4 * rune_scale, true)
			target.draw_line(center + Vector2(-r * 0.75, -r * 0.15), center + Vector2(r * 0.75, -r * 0.15), color, 2.4 * rune_scale, true)
			target.draw_line(center + Vector2(-r * 0.75, r * 0.42), center + Vector2(r * 0.35, r * 0.42), color, 2.4 * rune_scale, true)
			draw_filled_circle(target, center + Vector2(r * 0.55, -r * 0.15), r * 0.16, color)
		"READ":
			var read_left := center + Vector2(-r * 0.78, 0.0)
			var read_right := center + Vector2(r * 0.78, 0.0)
			var read_tip := center + Vector2(r * 0.20, 0.0)
			target.draw_line(read_left, read_tip, color, main_stroke, true)
			target.draw_line(read_tip, read_tip + Vector2(-r * 0.30, -r * 0.27), color, main_stroke, true)
			target.draw_line(read_tip, read_tip + Vector2(-r * 0.30, r * 0.27), color, main_stroke, true)
			target.draw_arc(read_right, r * 0.42, PI * 0.5, TAU * 1.5, 16, color, fine_stroke, true)
			target.draw_arc(read_right, r * 0.22, PI * 0.5, TAU * 1.5, 14, color, fine_stroke, true)
		"CUP":
			target.draw_line(center + Vector2(-r * 0.82, -r * 0.62), center + Vector2(0.0, r * 0.72), color, main_stroke, true)
			target.draw_line(center + Vector2(0.0, r * 0.72), center + Vector2(r * 0.82, -r * 0.62), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.96, -r * 0.62), center + Vector2(r * 0.96, -r * 0.62), color, fine_stroke, true)
		"TWIN":
			var twin_left := center + Vector2(-r * 0.34, 0.0)
			var twin_right := center + Vector2(r * 0.34, 0.0)
			draw_ring(target, twin_left, r * 0.48, color, main_stroke)
			draw_ring(target, twin_right, r * 0.48, color, main_stroke)
		"KNOT":
			target.draw_line(center + Vector2(-r * 0.9, -r * 0.5), center + Vector2(r * 0.9, r * 0.5), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.9, r * 0.5), center + Vector2(r * 0.9, -r * 0.5), color, main_stroke, true)
			draw_filled_circle(target, center + Vector2(-r * 0.62, -r * 0.34), r * 0.16, color)
			draw_filled_circle(target, center + Vector2(r * 0.62, r * 0.34), r * 0.16, color)
		"SLASH":
			target.draw_line(center + Vector2(-r * 0.62, r * 0.9), center + Vector2(r * 0.62, -r * 0.9), color, main_stroke, true)
			draw_filled_circle(target, center + Vector2(-r * 0.58, -r * 0.62), r * 0.15, color)
			draw_filled_circle(target, center + Vector2(r * 0.58, r * 0.62), r * 0.15, color)
		"SPIRAL":
			target.draw_arc(center, r * 0.82, PI * 0.18, TAU * 0.92, 20, color, main_stroke, true)
			target.draw_arc(center + Vector2(r * 0.13, 0.0), r * 0.42, PI * 1.08, TAU * 1.82, 16, color, main_stroke, true)
			draw_filled_circle(target, center + Vector2(-r * 0.28, -r * 0.12), r * 0.11, color)
		"DASH":
			target.draw_line(center + Vector2(-r * 0.92, 0.0), center + Vector2(r * 0.92, 0.0), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.38, -r * 0.42), center + Vector2(r * 0.38, -r * 0.42), color, fine_stroke, true)
		"EQ":
			target.draw_line(center + Vector2(-r * 0.86, -r * 0.32), center + Vector2(r * 0.86, -r * 0.32), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.86, r * 0.32), center + Vector2(r * 0.86, r * 0.32), color, main_stroke, true)
			draw_filled_circle(target, center + Vector2(0.0, -r * 0.32), r * 0.14, color)
			draw_filled_circle(target, center + Vector2(0.0, r * 0.32), r * 0.14, color)
		"NEQ":
			target.draw_line(center + Vector2(-r * 0.86, -r * 0.32), center + Vector2(r * 0.86, -r * 0.32), color, fine_stroke, true)
			target.draw_line(center + Vector2(-r * 0.86, r * 0.32), center + Vector2(r * 0.86, r * 0.32), color, fine_stroke, true)
			target.draw_line(center + Vector2(-r * 0.48, r * 0.90), center + Vector2(r * 0.48, -r * 0.90), color, main_stroke, true)
		"LT":
			target.draw_line(center + Vector2(r * 0.64, -r * 0.78), center + Vector2(-r * 0.64, 0.0), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.64, 0.0), center + Vector2(r * 0.64, r * 0.78), color, main_stroke, true)
		"GT":
			target.draw_line(center + Vector2(-r * 0.64, -r * 0.78), center + Vector2(r * 0.64, 0.0), color, main_stroke, true)
			target.draw_line(center + Vector2(r * 0.64, 0.0), center + Vector2(-r * 0.64, r * 0.78), color, main_stroke, true)
		"LTE":
			target.draw_line(center + Vector2(r * 0.60, -r * 0.80), center + Vector2(-r * 0.60, -r * 0.06), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.60, -r * 0.06), center + Vector2(r * 0.60, r * 0.68), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.72, r * 0.86), center + Vector2(r * 0.72, r * 0.86), color, fine_stroke, true)
		"GTE":
			target.draw_line(center + Vector2(-r * 0.60, -r * 0.80), center + Vector2(r * 0.60, -r * 0.06), color, main_stroke, true)
			target.draw_line(center + Vector2(r * 0.60, -r * 0.06), center + Vector2(-r * 0.60, r * 0.68), color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.72, r * 0.86), center + Vector2(r * 0.72, r * 0.86), color, fine_stroke, true)
		"NOT":
			draw_ring(target, center, r * 0.76, color, fine_stroke)
			target.draw_line(center + Vector2(-r * 0.66, r * 0.66), center + Vector2(r * 0.66, -r * 0.66), color, main_stroke, true)
			draw_filled_circle(target, center + Vector2(r * 0.58, r * 0.58), r * 0.12, color)
		"AND":
			var and_left := center + Vector2(-r * 0.84, 0.0)
			var and_right := center + Vector2(r * 0.84, 0.0)
			target.draw_line(and_left, and_right, color, main_stroke, true)
			target.draw_line(and_left, and_left + Vector2(r * 0.34, -r * 0.34), color, main_stroke, true)
			target.draw_line(and_left, and_left + Vector2(r * 0.34, r * 0.34), color, main_stroke, true)
			target.draw_line(and_right, and_right + Vector2(-r * 0.34, -r * 0.34), color, main_stroke, true)
			target.draw_line(and_right, and_right + Vector2(-r * 0.34, r * 0.34), color, main_stroke, true)
		"OR":
			var or_left_tip := center + Vector2(-r * 0.86, -r * 0.34)
			var or_right_tip := center + Vector2(r * 0.86, r * 0.34)
			var or_left_tail := center + Vector2(r * 0.20, -r * 0.34)
			var or_right_tail := center + Vector2(-r * 0.20, r * 0.34)
			target.draw_line(or_left_tail, or_left_tip, color, main_stroke, true)
			target.draw_line(or_left_tip, or_left_tip + Vector2(r * 0.34, -r * 0.30), color, main_stroke, true)
			target.draw_line(or_left_tip, or_left_tip + Vector2(r * 0.34, r * 0.30), color, main_stroke, true)
			target.draw_line(or_right_tail, or_right_tip, color, main_stroke, true)
			target.draw_line(or_right_tip, or_right_tip + Vector2(-r * 0.34, -r * 0.30), color, main_stroke, true)
			target.draw_line(or_right_tip, or_right_tip + Vector2(-r * 0.34, r * 0.30), color, main_stroke, true)
		"PRINTLETTER":
			var letter_top := center + Vector2(0.0, -r * 0.86)
			var letter_left := center + Vector2(-r * 0.67, r * 0.78)
			var letter_right := center + Vector2(r * 0.67, r * 0.78)
			target.draw_line(letter_left, letter_top, color, main_stroke, true)
			target.draw_line(letter_top, letter_right, color, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.36, r * 0.12), center + Vector2(r * 0.36, r * 0.12), color, fine_stroke, true)
			draw_filled_circle(target, center + Vector2(0.0, r * 0.52), r * 0.10, color)
		"JUMP_IF_TRUE":
			var jump_start := center + Vector2(-r * 0.82, r * 0.62)
			var jump_branch := center + Vector2(-r * 0.12, r * 0.08)
			var jump_tip := center + Vector2(r * 0.82, -r * 0.62)
			target.draw_line(jump_start, jump_branch, color, main_stroke, true)
			target.draw_line(jump_branch, jump_tip, color, main_stroke, true)
			target.draw_line(jump_tip, jump_tip + Vector2(-r * 0.34, -r * 0.06), color, main_stroke, true)
			target.draw_line(jump_tip, jump_tip + Vector2(-r * 0.06, r * 0.34), color, main_stroke, true)
			draw_filled_circle(target, jump_branch, r * 0.16, color)
		"WARP":
			target.draw_arc(center, r * 0.84, PI * 0.14, TAU * 0.86, 20, color, main_stroke, true)
			target.draw_arc(center, r * 0.48, PI * 1.14, TAU * 1.86, 16, color, fine_stroke, true)
			target.draw_line(center + Vector2(-r * 0.46, 0.0), center + Vector2(r * 0.28, 0.0), color, fine_stroke, true)
			target.draw_line(center + Vector2(r * 0.28, 0.0), center + Vector2(r * 0.03, -r * 0.23), color, fine_stroke, true)
			target.draw_line(center + Vector2(r * 0.28, 0.0), center + Vector2(r * 0.03, r * 0.23), color, fine_stroke, true)
		"WARP_ENDPOINT":
			draw_ring(target, center, r * 0.84, color, main_stroke)
			draw_ring(target, center, r * 0.50, color, fine_stroke)
			draw_filled_circle(target, center, r * 0.18, color)
			target.draw_line(center + Vector2(0.0, -r * 1.02), center + Vector2(0.0, -r * 0.62), color, fine_stroke, true)
			target.draw_line(center + Vector2(0.0, r * 0.62), center + Vector2(0.0, r * 1.02), color, fine_stroke, true)
		"INT_MOD":
			draw_ring(target, center, r * 0.82, color, main_stroke)
			target.draw_line(center + Vector2(-r * 0.42, 0.0), center + Vector2(r * 0.42, 0.0), color, fine_stroke, true)
			target.draw_line(center + Vector2(0.0, -r * 0.42), center + Vector2(0.0, r * 0.42), color, fine_stroke, true)
			draw_filled_circle(target, center, r * 0.14, color)
		"INT_SET":
			var set_rect := Rect2(center - Vector2(r * 0.64, r * 0.64), Vector2(r * 1.28, r * 1.28))
			target.draw_rect(set_rect, color, false, main_stroke, true)
			target.draw_line(center + Vector2(-r * 0.33, 0.0), center + Vector2(r * 0.33, 0.0), color, fine_stroke, true)
			draw_filled_circle(target, center + Vector2(r * 0.46, 0.0), r * 0.12, color)


static func _filled_circle_texture_for_draw() -> Texture2D:
	if _filled_circle_texture != null:
		return _filled_circle_texture
	var image := Image.create(CIRCLE_TEXTURE_SIZE, CIRCLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (float(CIRCLE_TEXTURE_SIZE) * 0.5)
	var outer_radius := float(CIRCLE_TEXTURE_SIZE) * 0.5 - 1.0
	for pixel_y in range(CIRCLE_TEXTURE_SIZE):
		for pixel_x in range(CIRCLE_TEXTURE_SIZE):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var alpha := clampf(outer_radius + 0.75 - pixel_center.distance_to(center), 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(pixel_x, pixel_y, Color(1.0, 1.0, 1.0, alpha))
	_filled_circle_texture = ImageTexture.create_from_image(image)
	return _filled_circle_texture


static func _ring_texture_for_key(ratio_key: int) -> Texture2D:
	ratio_key = clampi(ratio_key, 2, 95)
	if _ring_textures.has(ratio_key):
		return _ring_textures[ratio_key] as Texture2D
	var image := Image.create(CIRCLE_TEXTURE_SIZE, CIRCLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (float(CIRCLE_TEXTURE_SIZE) * 0.5)
	var outer_radius := float(CIRCLE_TEXTURE_SIZE) * 0.5 - 1.0
	var inner_radius := outer_radius * (1.0 - float(ratio_key) / 100.0)
	for pixel_y in range(CIRCLE_TEXTURE_SIZE):
		for pixel_x in range(CIRCLE_TEXTURE_SIZE):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var distance := pixel_center.distance_to(center)
			var outer_alpha := clampf(outer_radius + 0.75 - distance, 0.0, 1.0)
			var inner_alpha := clampf(distance - inner_radius + 0.75, 0.0, 1.0)
			var alpha := minf(outer_alpha, inner_alpha)
			if alpha > 0.0:
				image.set_pixel(pixel_x, pixel_y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	_ring_textures[ratio_key] = texture
	return texture
