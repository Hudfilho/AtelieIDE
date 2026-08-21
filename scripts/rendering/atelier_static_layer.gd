class_name AtelierStaticLayer
extends Control

## Camada de desenho retido para a parte imutavel da mesa do atelie.
##
## O canvas principal redesenha enquanto o usuario arrasta, anima ou executa
## runas. Separar o ambiente e a moldura evita reconstruir esses comandos de
## desenho em todos esses quadros. Esta camada so invalida seu cache quando a
## paleta, o tamanho da janela ou o layout dos paineis muda.

const PASS_BACKDROP := 0
const PASS_CHROME := 1

const PANEL_GAP := 12.0
const FRAME_RADIUS := 10.0
const VIGNETTE_SPREAD := 190.0
const GRAIN_TILE := 96
const CIRCLE_TEXTURE_SIZE := 64

var _render_pass := PASS_BACKDROP
var _palette_ready := false
var _layout_ready := false

var _canvas_rect := Rect2()
var _left_panel_rect := Rect2()
var _top_panel_rect := Rect2()
var _bottom_panel_rect := Rect2()
var _right_panel_rect := Rect2()
var _left_panel_open := false
var _top_panel_open := false
var _bottom_panel_open := false
var _right_panel_open := false

var _col_body_top: Color
var _col_body_mid: Color
var _col_body_bottom: Color
var _col_candle_warm: Color
var _col_candle_gold: Color
var _col_grain: Color
var _col_vignette_outer: Color
var _col_vignette_warm: Color
var _col_frame_inner: Color
var _col_frame_shadow: Color
var _col_brass: Color
var _col_gold: Color
var _col_gold_glow: Color
var _col_sky: Color
var _col_sky_high: Color
var _col_compass: Color

var _glow_texture: GradientTexture2D
var _grain_texture: Texture2D
var _body_gradient_texture: GradientTexture2D
var _canvas_gradient_texture: GradientTexture2D
var _frame_inner_stylebox: StyleBoxFlat
var _canvas_stylebox: StyleBoxFlat
var _corner_mask_texture: Texture2D
var _edge_stylebox: StyleBoxFlat
var _filled_circle_texture: Texture2D
var _ring_textures := {}
var _vignette_mask_texture: Texture2D
var _vignette_mask_size := Vector2i.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow_texture = _create_radial_texture()
	_grain_texture = _create_grain_texture()
	_corner_mask_texture = _create_corner_mask_texture()
	_filled_circle_texture = _create_filled_circle_texture()
	queue_redraw()


func _notification(what: int) -> void:
	if what != NOTIFICATION_RESIZED:
		return
	_vignette_mask_texture = null
	_vignette_mask_size = Vector2i.ZERO
	queue_redraw()


func configure(render_pass: int) -> void:
	_render_pass = PASS_CHROME if render_pass == PASS_CHROME else PASS_BACKDROP
	queue_redraw()


func apply_palette(table: Dictionary) -> void:
	_col_body_top = table["body_top"]
	_col_body_mid = table["body_mid"]
	_col_body_bottom = table["body_bottom"]
	_col_candle_warm = table["candle_warm"]
	_col_candle_gold = table["candle_gold"]
	_col_grain = table["grain"]
	_col_vignette_outer = table["vignette_outer"]
	_col_vignette_warm = table["vignette_warm"]
	_col_frame_inner = table["frame_inner"]
	_col_frame_shadow = table["frame_shadow"]
	_col_brass = table["brass"]
	_col_gold = table["gold"]
	_col_gold_glow = table["gold_glow"]
	_col_sky = table["sky"]
	_col_sky_high = table["sky_high"]
	_col_compass = table["compass"]
	_build_theme_resources()
	_palette_ready = true
	queue_redraw()


func sync_layout(
		canvas_rect: Rect2,
		left_panel_rect: Rect2,
		top_panel_rect: Rect2,
		bottom_panel_rect: Rect2,
		right_panel_rect: Rect2,
		left_panel_open: bool,
		top_panel_open: bool,
		bottom_panel_open: bool,
		right_panel_open: bool) -> void:
	var unchanged := (
			_layout_ready
			and _canvas_rect == canvas_rect
			and _left_panel_rect == left_panel_rect
			and _top_panel_rect == top_panel_rect
			and _bottom_panel_rect == bottom_panel_rect
			and _right_panel_rect == right_panel_rect
			and _left_panel_open == left_panel_open
			and _top_panel_open == top_panel_open
			and _bottom_panel_open == bottom_panel_open
			and _right_panel_open == right_panel_open)
	if unchanged:
		return
	_canvas_rect = canvas_rect
	_left_panel_rect = left_panel_rect
	_top_panel_rect = top_panel_rect
	_bottom_panel_rect = bottom_panel_rect
	_right_panel_rect = right_panel_rect
	_left_panel_open = left_panel_open
	_top_panel_open = top_panel_open
	_bottom_panel_open = bottom_panel_open
	_right_panel_open = right_panel_open
	_layout_ready = true
	queue_redraw()


func _draw() -> void:
	if not _palette_ready or not _layout_ready:
		return
	if _render_pass == PASS_BACKDROP:
		_draw_room(Rect2(Vector2.ZERO, size))
		_draw_canvas_backdrop()
		_draw_compass()
		return
	# O anel de sala recorta qualquer segmento que tenha escapado do canvas.
	# As molduras e os grips sao desenhados depois, como no passe monolitico.
	_draw_room(_canvas_rect.grow(PANEL_GAP), _canvas_rect)
	_draw_canvas_corners()
	_draw_canvas_edge()
	_draw_resize_handles()
	_draw_vignette()


func _build_theme_resources() -> void:
	_body_gradient_texture = _create_linear_texture(
			PackedFloat32Array([0.0, 0.6, 1.0]),
			PackedColorArray([_col_body_top, _col_body_mid, _col_body_bottom]),
			Vector2(0.329, 0.030), Vector2(0.671, 0.970))
	_canvas_gradient_texture = _create_linear_texture(
			PackedFloat32Array([0.0, 1.0]),
			PackedColorArray([_col_sky_high, _col_sky]),
			Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	_canvas_stylebox = _create_frame_stylebox(_col_sky)

	_edge_stylebox = StyleBoxFlat.new()
	_edge_stylebox.draw_center = false
	_edge_stylebox.border_color = _col_brass
	_edge_stylebox.set_border_width_all(1)
	_edge_stylebox.set_corner_radius_all(int(FRAME_RADIUS))
	_edge_stylebox.anti_aliasing = true

	_frame_inner_stylebox = StyleBoxFlat.new()
	_frame_inner_stylebox.draw_center = false
	_frame_inner_stylebox.border_color = _col_frame_inner
	_frame_inner_stylebox.set_border_width_all(1)
	_frame_inner_stylebox.set_corner_radius_all(int(FRAME_RADIUS) - 4)
	_frame_inner_stylebox.anti_aliasing = true


func _create_frame_stylebox(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = _col_brass
	box.set_border_width_all(1)
	box.set_corner_radius_all(int(FRAME_RADIUS))
	box.shadow_color = _col_frame_shadow
	box.shadow_size = 13
	box.shadow_offset = Vector2(0.0, 7.0)
	box.anti_aliasing = true
	return box


func _create_radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture


func _create_linear_texture(
		offsets: PackedFloat32Array,
		colors: PackedColorArray,
		from: Vector2,
		to: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 64
	texture.height = 64
	return texture


func _create_corner_mask_texture() -> Texture2D:
	var extent := int(FRAME_RADIUS)
	var image := Image.create(extent, extent, false, Image.FORMAT_RGBA8)
	for y in range(extent):
		for x in range(extent):
			var distance := Vector2(float(extent) - 0.5 - float(x), float(extent) - 0.5 - float(y)).length()
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(distance - float(extent) + 1.0, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _create_grain_texture() -> Texture2D:
	var image := Image.create(GRAIN_TILE, GRAIN_TILE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4154454C
	for y in range(GRAIN_TILE):
		for x in range(GRAIN_TILE):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, rng.randf()))
	return ImageTexture.create_from_image(image)


func _create_filled_circle_texture() -> Texture2D:
	var image := Image.create(CIRCLE_TEXTURE_SIZE, CIRCLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (float(CIRCLE_TEXTURE_SIZE) * 0.5)
	var outer_radius := float(CIRCLE_TEXTURE_SIZE) * 0.5 - 1.0
	for pixel_x in range(CIRCLE_TEXTURE_SIZE):
		for pixel_y in range(CIRCLE_TEXTURE_SIZE):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var alpha := clampf(outer_radius + 0.75 - pixel_center.distance_to(center), 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(pixel_x, pixel_y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _ring_texture(width_ratio: float) -> Texture2D:
	var ratio_key := clampi(roundi(width_ratio * 100.0), 2, 95)
	if _ring_textures.has(ratio_key):
		return _ring_textures[ratio_key]
	var image := Image.create(CIRCLE_TEXTURE_SIZE, CIRCLE_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (float(CIRCLE_TEXTURE_SIZE) * 0.5)
	var outer_radius := float(CIRCLE_TEXTURE_SIZE) * 0.5 - 1.0
	var inner_radius := outer_radius * (1.0 - float(ratio_key) / 100.0)
	for pixel_x in range(CIRCLE_TEXTURE_SIZE):
		for pixel_y in range(CIRCLE_TEXTURE_SIZE):
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


func _draw_filled_circle(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var diameter := radius * 2.0
	draw_texture_rect(
			_filled_circle_texture,
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
			false,
			color)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0 or width <= 0.0:
		return
	var diameter := radius * 2.0
	draw_texture_rect(
			_ring_texture(width / radius),
			Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
			false,
			color)


func _draw_room(region: Rect2, hole: Rect2 = Rect2()) -> void:
	if hole.size.x <= 0.0 or hole.size.y <= 0.0:
		_draw_room_region(region)
		return
	_draw_room_region(Rect2(region.position, Vector2(region.size.x, hole.position.y - region.position.y)))
	_draw_room_region(Rect2(Vector2(region.position.x, hole.end.y), Vector2(region.size.x, region.end.y - hole.end.y)))
	_draw_room_region(Rect2(Vector2(region.position.x, hole.position.y), Vector2(hole.position.x - region.position.x, hole.size.y)))
	_draw_room_region(Rect2(Vector2(hole.end.x, hole.position.y), Vector2(region.end.x - hole.end.x, hole.size.y)))


func _draw_room_region(region: Rect2) -> void:
	if region.size.x <= 0.5 or region.size.y <= 0.5:
		return
	var full := Rect2(Vector2.ZERO, size)
	_draw_texture_slice(_body_gradient_texture, full, region, Color.WHITE)
	_draw_texture_slice(_glow_texture, _candle_rect(true), region, _col_candle_warm)
	_draw_texture_slice(_glow_texture, _candle_rect(false), region, _col_candle_gold)
	draw_texture_rect(_grain_texture, region, true, _col_grain)


func _candle_rect(warm: bool) -> Rect2:
	var reach := minf(size.x, size.y)
	if warm:
		var warm_radius := reach * 1.55
		return Rect2(
				Vector2(size.x * 0.12, size.y * 0.88) - Vector2.ONE * warm_radius,
				Vector2.ONE * warm_radius * 2.0)
	var gold_radius := reach * 1.35
	return Rect2(
			Vector2(size.x * 0.92, size.y * 0.10) - Vector2.ONE * gold_radius,
			Vector2.ONE * gold_radius * 2.0)


func _draw_texture_slice(texture: Texture2D, target: Rect2, region: Rect2, tint: Color) -> void:
	var visible := target.intersection(region)
	if visible.size.x <= 0.0 or visible.size.y <= 0.0:
		return
	var ratio := texture.get_size() / target.size
	var source := Rect2((visible.position - target.position) * ratio, visible.size * ratio)
	draw_texture_rect_region(texture, visible, source, tint)


func _room_tint_at(point: Vector2) -> Color:
	var uv := Vector2(point.x / maxf(size.x, 1.0), point.y / maxf(size.y, 1.0))
	var from := Vector2(0.329, 0.030)
	var axis := Vector2(0.671, 0.970) - from
	var amount := clampf((uv - from).dot(axis) / axis.length_squared(), 0.0, 1.0)
	if amount <= 0.6:
		return _col_body_top.lerp(_col_body_mid, amount / 0.6)
	return _col_body_mid.lerp(_col_body_bottom, (amount - 0.6) / 0.4)


func _draw_vignette() -> void:
	var mask := _vignette_mask()
	if mask == null:
		return
	var full := Rect2(Vector2.ZERO, size)
	draw_texture_rect(mask, full, false, _col_vignette_outer)
	draw_texture_rect(mask, full, false, _col_vignette_warm)


func _vignette_mask() -> Texture2D:
	var wanted := Vector2i(maxi(int(size.x / 10.0), 8), maxi(int(size.y / 10.0), 8))
	if _vignette_mask_texture != null and _vignette_mask_size == wanted:
		return _vignette_mask_texture
	var spread := maxf(VIGNETTE_SPREAD * float(wanted.x) / maxf(size.x, 1.0), 1.0)
	var image := Image.create(wanted.x, wanted.y, false, Image.FORMAT_RGBA8)
	for y in range(wanted.y):
		var vertical := clampf(1.0 - minf(float(y), float(wanted.y - 1 - y)) / spread, 0.0, 1.0)
		for x in range(wanted.x):
			var horizontal := clampf(1.0 - minf(float(x), float(wanted.x - 1 - x)) / spread, 0.0, 1.0)
			var amount := 1.0 - (1.0 - horizontal) * (1.0 - vertical)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pow(amount, 2.2)))
	_vignette_mask_texture = ImageTexture.create_from_image(image)
	_vignette_mask_size = wanted
	return _vignette_mask_texture


func _draw_canvas_backdrop() -> void:
	if _canvas_rect.size.x <= 0.0 or _canvas_rect.size.y <= 0.0:
		return
	draw_style_box(_canvas_stylebox, _canvas_rect)
	draw_texture_rect(_canvas_gradient_texture, _canvas_rect.grow(-1.0), false, Color.WHITE)


func _draw_compass() -> void:
	var reach := minf(_canvas_rect.size.x, _canvas_rect.size.y)
	if reach < 220.0:
		return
	var radius := 44.0
	var center := Vector2(_canvas_rect.position.x + 22.0 + radius, _canvas_rect.end.y - 20.0 - radius)
	_draw_ring(center, radius, _col_compass, 1.0)
	_draw_ring(center, radius * 0.74, _col_compass, 0.6)
	var long_arm := radius * 0.96
	var short_arm := radius * 0.15
	var needle := _col_compass
	needle.a *= 0.6
	draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -long_arm), center + Vector2(short_arm, 0.0),
			center + Vector2(0.0, long_arm), center + Vector2(-short_arm, 0.0)]), needle)
	draw_colored_polygon(PackedVector2Array([
			center + Vector2(-long_arm, 0.0), center + Vector2(0.0, -short_arm),
			center + Vector2(long_arm, 0.0), center + Vector2(0.0, short_arm)]), needle)
	var diagonal := radius * 0.61
	var hairline := _col_compass
	hairline.a *= 0.5
	for corner: Vector2 in [
			Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
		draw_line(center, center + corner * diagonal, hairline, 0.8, true)


func _draw_canvas_corners() -> void:
	var extent := FRAME_RADIUS
	if _canvas_rect.size.x <= extent * 2.0 or _canvas_rect.size.y <= extent * 2.0:
		return
	var patch := Rect2(Vector2.ZERO, Vector2.ONE * extent)
	for corner: Vector2 in [
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var origin := _canvas_rect.position + _canvas_rect.size * corner
		draw_set_transform(origin, 0.0, Vector2.ONE - corner * 2.0)
		draw_texture_rect(_corner_mask_texture, patch, false, _room_tint_at(origin))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_canvas_edge() -> void:
	_draw_frame_chrome(_canvas_rect)


func _draw_frame_chrome(rect: Rect2) -> void:
	draw_style_box(_edge_stylebox, rect)
	var inner := rect.grow(-5.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_style_box(_frame_inner_stylebox, inner)
	_draw_frame_corners(rect)


func _draw_frame_corners(rect: Rect2) -> void:
	var arm := 13.0
	if rect.size.x < arm * 3.0 or rect.size.y < arm * 3.0:
		return
	var tint := _col_gold
	tint.a *= 0.70
	for corner: Vector2 in [
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(0.0, 1.0), Vector2(1.0, 1.0)]:
		var step := Vector2.ONE - corner * 2.0
		var origin := rect.position + rect.size * corner + step * 9.0
		draw_line(origin, origin + Vector2(arm * step.x, 0.0), tint, 1.4, true)
		draw_line(origin, origin + Vector2(0.0, arm * step.y), tint, 1.4, true)


func _draw_resize_handles() -> void:
	if _left_panel_open:
		_draw_resize_grip(Vector2(_left_panel_rect.end.x + PANEL_GAP * 0.5, size.y * 0.5), true)
	if _right_panel_open:
		_draw_resize_grip(Vector2(_right_panel_rect.position.x - PANEL_GAP * 0.5, size.y * 0.5), true)
	if _top_panel_open:
		_draw_resize_grip(Vector2(_top_panel_rect.get_center().x, _top_panel_rect.end.y + PANEL_GAP * 0.5), false)
	if _bottom_panel_open:
		_draw_resize_grip(Vector2(_top_panel_rect.get_center().x, _bottom_panel_rect.position.y - PANEL_GAP * 0.5), false)


func _draw_resize_grip(center: Vector2, vertical: bool) -> void:
	var step := Vector2(0.0, 6.0) if vertical else Vector2(6.0, 0.0)
	for offset: float in [-1.0, 0.0, 1.0]:
		_draw_filled_circle(center + step * offset, 1.6, _col_gold_glow)
