extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func _click(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	return event


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var canvas := load("res://scenes/Main.tscn").instantiate() as Control
	root.add_child(canvas)
	await process_frame
	for panel_name in ["left", "right", "top", "bottom"]:
		canvas.set(panel_name + "_panel_open", true)
	canvas.queue_redraw()
	await process_frame
	for theme in ["dark", "light"]:
		canvas.call("_apply_theme", theme)
		var skin := canvas.get("panel_skin_texture") as Texture2D
		var image := skin.get_image()
		for corner in [Vector2i(0, 0), Vector2i(63, 0), Vector2i(0, 63), Vector2i(63, 63)]:
			_check(image.get_pixelv(corner).a > 0.99, "%s: a moldura nao deve cortar o canto %s" % [theme, corner])
		var card: Texture2D = canvas.call("_spell_card_texture", 58)
		var card_image := card.get_image()
		for corner in [Vector2i(6, 6), Vector2i(249, 6), Vector2i(6, 63), Vector2i(249, 63)]:
			_check(card_image.get_pixelv(corner).a > 0.99, "%s: o cartao nao deve cortar o canto %s" % [theme, corner])
		for style_name in ["frame_stylebox", "canvas_stylebox", "edge_stylebox", "frame_inner_stylebox", "card_stylebox", "mask_top_stylebox", "mask_bottom_stylebox"]:
			var style := canvas.get(style_name) as StyleBoxFlat
			_check(style.corner_radius_top_left == 0 and style.corner_radius_top_right == 0 and style.corner_radius_bottom_left == 0 and style.corner_radius_bottom_right == 0, "Cantos retos: " + style_name)
		_check(canvas.get("corner_mask_texture") == null, "Nao deve haver mascara de recorte nos cantos do canvas.")
	var left: Rect2 = canvas.call("_left_panel_rect")
	var right: Rect2 = canvas.call("_right_panel_rect")
	for offset in [-180.0, -60.0, 0.0, 60.0, 180.0]:
		_check(canvas.call("_resize_handle_at", Vector2(left.end.x + 8, left.get_center().y + offset)) == "left", "Toda a lateral do Grimorio deve aceitar arraste.")
		_check(canvas.call("_resize_handle_at", Vector2(right.position.x - 8, right.get_center().y + offset)) == "right", "A Pilha deve continuar aceitando arraste pela lateral.")
	_check(canvas.call("_resize_handle_at", left.get_center()) == "", "A hitbox nao deve cobrir o conteudo do Grimorio.")
	var start := Vector2(left.end.x + 8, left.get_center().y + 120)
	canvas.call("_gui_input", _click(start, true))
	_check(canvas.get("drag_mode") == "resize_left", "Arraste longe dos pontinhos deve iniciar resize_left.")
	var motion := InputEventMouseMotion.new()
	motion.position = start + Vector2(40, 0)
	canvas.call("_gui_input", motion)
	canvas.call("_gui_input", _click(motion.position, false))
	_check(is_equal_approx(float(canvas.get("left_panel_size")), left.size.x + 40), "O arraste deve redimensionar o Grimorio.")
	_check(canvas.get("drag_mode") == "", "Soltar deve encerrar o arraste.")
	canvas.set("left_panel_open", false)
	_check((canvas.call("_resize_handle_rect", "left") as Rect2).size == Vector2.ZERO, "Painel fechado nao deve ter hitbox de resize.")
	canvas.queue_redraw()
	await process_frame
	canvas.queue_free()
	await process_frame
	if failures == 0:
		print("PANEL_GEOMETRY_SMOKE_OK")
	quit(0 if failures == 0 else 1)
