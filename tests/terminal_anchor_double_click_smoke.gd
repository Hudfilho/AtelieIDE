extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _left_click(position: Vector2, pressed: bool, double_click := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	event.double_click = double_click
	return event


func _motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	return event


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var canvas := load("res://scenes/Main.tscn").instantiate() as Control
	root.add_child(canvas)
	await process_frame
	canvas.call("_add_connection", Vector2.ZERO, Vector2(48.0, 0.0))
	canvas.call("_set_connection_symbol", 0, "ORB")
	var first_point: Vector2 = canvas.call("_world_to_screen", Vector2.ZERO)
	var terminal: Vector2 = canvas.call("_world_to_screen", Vector2(48.0, 0.0))
	var target: Vector2 = canvas.call("_world_to_screen", Vector2(96.0, 0.0))
	var next_target: Vector2 = canvas.call("_world_to_screen", Vector2(144.0, 0.0))
	assert(canvas.call("_is_canvas_position", terminal))
	assert(canvas.call("_is_canvas_position", target))

	# Arraste normal cria novas células ao cruzar os pontos, sem soltar.
	canvas.call("_gui_input", _left_click(terminal, true))
	canvas.call("_gui_input", _motion(target))
	assert((canvas.get("connections") as Array).size() == 2)
	canvas.call("_gui_input", _motion(next_target))
	assert((canvas.get("connections") as Array).size() == 3)
	canvas.call("_gui_input", _motion(next_target))
	assert((canvas.get("connections") as Array).size() == 3)
	# Voltar ao ponto imediatamente anterior apaga a última célula.
	canvas.call("_gui_input", _motion(target))
	assert((canvas.get("connections") as Array).size() == 2)
	canvas.call("_gui_input", _motion(terminal))
	assert((canvas.get("connections") as Array).size() == 1)
	canvas.call("_gui_input", _motion(first_point))
	assert((canvas.get("connections") as Array).is_empty())
	canvas.call("_gui_input", _left_click(first_point, false))

	# Duplo clique arma o modo de mover, que permanece após soltar.
	(canvas.get("diagram") as AtelierRuneDiagram).restore([{
		"from": Vector2.ZERO, "to": Vector2(48.0, 0.0), "symbol": "", "intensity": 128,
	}])
	canvas.call("_invalidate_sequence_side_multiplier_cache")
	canvas.call("_gui_input", _left_click(terminal, true, true))
	assert(canvas.get("drag_mode") == "move_anchor")
	canvas.call("_gui_input", _left_click(terminal, false))
	assert(canvas.get("terminal_move_connection_index") == 0)
	canvas.queue_redraw()
	await process_frame
	canvas.call("_gui_input", _left_click(terminal, true))
	canvas.call("_gui_input", _motion(target))
	canvas.call("_process", 0.2)
	assert((canvas.get("connections") as Array).size() == 1)
	canvas.call("_gui_input", _left_click(target, false))
	var connections: Array = canvas.get("connections")
	assert(connections.size() == 1)
	assert(Vector2(connections[0]["to"]).is_equal_approx(Vector2(96.0, 0.0)))
	assert(Vector2(canvas.get("terminal_move_point")).is_equal_approx(Vector2(96.0, 0.0)))

	# Duplo clique de novo desarma; a ponta volta a criar uma célula por arraste.
	canvas.call("_gui_input", _left_click(target, true, true))
	canvas.call("_gui_input", _left_click(target, false))
	assert(canvas.get("terminal_move_connection_index") == -1)
	canvas.call("_gui_input", _left_click(target, true))
	canvas.call("_gui_input", _motion(next_target))
	assert((canvas.get("connections") as Array).size() == 2)
	canvas.call("_gui_input", _left_click(next_target, false))
	assert((canvas.get("connections") as Array).size() == 2)
	print("TERMINAL_ANCHOR_DOUBLE_CLICK_SMOKE_OK")
	quit()
