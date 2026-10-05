extends SceneTree

const RuneDiagram = preload("res://scripts/core/rune_diagram.gd")


func _initialize() -> void:
	call_deferred("_run")


func _click(position: Vector2, pressed: bool, double_click := false) -> InputEventMouseButton:
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
	var diagram := RuneDiagram.new()
	assert(diagram.add_connection(Vector2.ZERO, Vector2(48.0, 0.0)))
	assert(diagram.add_connection(Vector2(48.0, 0.0), Vector2(96.0, 0.0)))
	assert(not diagram.add_connection(Vector2(48.0, 0.0), Vector2(144.0, 0.0))) # Junção ocupada.
	assert(not diagram.add_connection(Vector2(96.0, 0.0), Vector2.ZERO)) # Círculo.
	assert(not diagram.add_connection(Vector2(144.0, 0.0), Vector2.ZERO)) # Destino ocupado.
	assert(not diagram.move_anchor(Vector2(96.0, 0.0), Vector2.ZERO))
	assert(diagram.connections.size() == 2)
	assert(diagram.add_connection(Vector2(96.0, 0.0), Vector2(144.0, 0.0)))

	root.size = Vector2i(1280, 720)
	var canvas := load("res://scenes/Main.tscn").instantiate() as Control
	root.add_child(canvas)
	await process_frame
	canvas.call("_add_connection", Vector2.ZERO, Vector2(48.0, 0.0))
	canvas.call("_add_connection", Vector2(48.0, 0.0), Vector2(96.0, 0.0))
	var first: Vector2 = canvas.call("_world_to_screen", Vector2.ZERO)
	var junction: Vector2 = canvas.call("_world_to_screen", Vector2(48.0, 0.0))
	var terminal: Vector2 = canvas.call("_world_to_screen", Vector2(96.0, 0.0))
	var free_point: Vector2 = canvas.call("_world_to_screen", Vector2(144.0, 0.0))

	canvas.call("_gui_input", _click(junction, true))
	assert(canvas.get("drag_mode") == "move_anchor")
	canvas.call("_gui_input", _motion(free_point))
	assert(Vector2(canvas.get("anchor_move_target")).is_equal_approx(Vector2(144.0, 0.0)))
	canvas.call("_cancel_drag")
	assert((canvas.get("connections") as Array).size() == 2)

	canvas.call("_gui_input", _click(terminal, true))
	canvas.call("_gui_input", _motion(first))
	assert((canvas.get("connections") as Array).size() == 2)
	canvas.call("_gui_input", _motion(free_point))
	assert((canvas.get("connections") as Array).size() == 3)
	canvas.call("_gui_input", _motion(first))
	assert((canvas.get("connections") as Array).size() == 3)
	canvas.call("_gui_input", _click(first, false))

	# A única exceção é voltar à célula imediatamente anterior para apagá-la.
	canvas.call("_gui_input", _click(free_point, true))
	canvas.call("_gui_input", _motion(terminal))
	assert((canvas.get("connections") as Array).size() == 2)
	canvas.call("_gui_input", _click(terminal, false))

	canvas.call("_gui_input", _click(terminal, true, true))
	canvas.call("_gui_input", _click(terminal, false))
	assert(canvas.get("terminal_move_connection_index") >= 0)
	canvas.call("_gui_input", _click(terminal, true))
	canvas.call("_gui_input", _motion(first))
	canvas.call("_gui_input", _click(first, false))
	canvas.call("_process", 0.2)
	assert(Vector2((canvas.get("connections") as Array)[1]["to"]).is_equal_approx(Vector2(96.0, 0.0)))

	# A junção segue o mouse e pode ser movida a um ponto ainda livre.
	var moved_junction: Vector2 = canvas.call("_world_to_screen", Vector2(48.0, 48.0))
	canvas.call("_gui_input", _click(junction, true))
	canvas.call("_gui_input", _motion(moved_junction))
	canvas.call("_gui_input", _click(moved_junction, false))
	var moved_connections: Array = canvas.get("connections")
	assert(Vector2(moved_connections[0]["to"]).is_equal_approx(Vector2(48.0, 48.0)))
	assert(Vector2(moved_connections[1]["from"]).is_equal_approx(Vector2(48.0, 48.0)))
	print("OCCUPIED_NODE_SMOKE_OK")
	quit()
