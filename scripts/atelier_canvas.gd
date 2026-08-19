extends Control

## Protótipo visual da Atelier IDE.
## - Arraste com o botão do meio para navegar pela grade.
## - Arraste de um ponto até outro para criar uma ligação.
## - Arraste um selo da paleta para uma ligação já criada.
## - Arraste uma área vazia para selecionar várias ligações.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneDiagram = preload("res://scripts/core/rune_diagram.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")

const PANEL_TAB_SIZE := 42.0
const DEFAULT_LEFT_PANEL_WIDTH := 304.0
const DEFAULT_TOP_PANEL_HEIGHT := 196.0
const DEFAULT_BOTTOM_PANEL_HEIGHT := 224.0
const MIN_LEFT_PANEL_WIDTH := 190.0
const MIN_TOP_PANEL_HEIGHT := 106.0
const MIN_BOTTOM_PANEL_HEIGHT := 120.0
const LEFT_COMMAND_ROW_HEIGHT := 66.0
const LEFT_COMMAND_LIST_TOP := 82.0
const LEFT_COMMAND_SCROLL_STEP := 28.0
const LEFT_SCROLL_DRAG_THRESHOLD := 4.0
const LEFT_SCROLL_SMOOTHNESS := 15.0
const GRID_SPACING := 48.0
const DOT_RADIUS := 3.4
const DOT_HIT_RADIUS := 14.0
const LINE_HIT_RADIUS := 30.0
const SYMBOL_DRAG_THRESHOLD := 8.0
const RECT_SELECT_DRAG_THRESHOLD := 6.0
const ANCHOR_SNAP_DURATION := 0.13
const SYMBOL_SETTLE_DURATION := 0.20
const HOVER_DELAY := 0.07
const HOVER_FADE_DURATION := 0.14
const SYMBOL_HOVER_DELAY := 0.12
const SYMBOL_HOVER_FADE_DURATION := 0.20

const BACKGROUND := Color("050506")
const CANVAS_BACKGROUND := Color("07070a")
const PANEL_BACKGROUND := Color("09090c")
const PANEL_INNER := Color("111017")
const PANEL_BORDER := Color("706e75")
const PANEL_ACCENT := Color("9f9ca5")
const GRID_DOT := Color("ff2034")
const RUNE_LINE_COLOR := Color("cdbb8c")
const CELL_BORDER := Color("a29fa8")
const TEXT_PRIMARY := Color("d0cdd4")
const TEXT_MUTED := Color("797780")

const PALETTE_SYMBOLS = RuneCatalog.SYMBOLS

var pan := Vector2(340.0, 230.0)
var zoom := 1.0
var diagram: AtelierRuneDiagram = RuneDiagram.new()
var compiler: AtelierRuneCompiler = RuneCompiler.new()
var vm: AtelierRuneVM = RuneVM.new()
var execution_output: Array[String] = []
var execution_errors: Array[String] = []
var execution_warnings: Array[String] = []
var last_bytecode := PackedByteArray()
var connections: Array[Dictionary]:
	get:
		return diagram.connections

var pointer_screen := Vector2.ZERO
var hover_point_valid := false
var hover_world := Vector2.ZERO
var hovered_connection := -1
var hovered_symbol := -1
var hovered_palette_index := -1

var left_panel_open := false
var top_panel_open := false
var bottom_panel_open := false
var left_panel_size := DEFAULT_LEFT_PANEL_WIDTH
var top_panel_size := DEFAULT_TOP_PANEL_HEIGHT
var bottom_panel_size := DEFAULT_BOTTOM_PANEL_HEIGHT
var left_command_scroll := 0.0
var left_command_scroll_target := 0.0
var selected_connection := -1
var selected_connections: Array[int] = []
var ritual_running := false

var drag_mode := ""
var line_start_world := Vector2.ZERO
var pan_drag_start := Vector2.ZERO
var pan_at_drag_start := Vector2.ZERO
var selection_rect_start := Vector2.ZERO
var selection_rect := Rect2()
var selection_rect_additive := false
var left_scroll_drag_start_mouse := Vector2.ZERO
var left_scroll_drag_start_offset := 0.0
var left_scroll_pressed_connection := -1
var left_scroll_additive := false
var active_symbol := ""
var dragged_symbol_source := -1
var symbol_drag_start_snapshot: Array = []
var symbol_press_screen := Vector2.ZERO
var animation_clock := 0.0
var anchor_snap_active := false
var anchor_snap_from := Vector2.ZERO
var anchor_snap_target := Vector2.ZERO
var anchor_snap_started_at := 0.0
var symbol_settle_active := false
var symbol_settle_kind := ""
var symbol_settle_from := Vector2.ZERO
var symbol_settle_to := Vector2.ZERO
var symbol_settle_started_at := 0.0
var symbol_settle_connection := -1
var symbol_settle_intensity := 128
var animated_hover_point_valid := false
var animated_hover_world := Vector2.ZERO
var animated_hover_connection := -1
var animated_hover_symbol := -1
var animated_hover_palette_index := -1
var point_hover_started_at := 0.0
var connection_hover_started_at := 0.0
var symbol_hover_started_at := 0.0
var palette_hover_started_at := 0.0
var intensity_drag_start_snapshot: Array = []
var intensity_drag_changed := false
var editing_intensity_text := false
var intensity_text := ""
var intensity_text_replace_on_next_digit := false
var resize_start_mouse := Vector2.ZERO
var resize_start_size := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	queue_redraw()


func _process(delta: float) -> void:
	if not anchor_snap_active and not symbol_settle_active and not _hover_transition_active() and not _left_scroll_is_moving():
		return
	animation_clock += delta
	_update_left_command_scroll(delta)
	if anchor_snap_active and animation_clock - anchor_snap_started_at >= ANCHOR_SNAP_DURATION:
		_complete_anchor_snap()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if editing_intensity_text:
		_handle_intensity_text_key(event)
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
		_delete_selected_connections()
		get_viewport().set_input_as_handled()
		return
	if not event.ctrl_pressed:
		return
	if event.keycode == KEY_Z:
		_undo()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Y:
		_redo()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_screen = event.position
		_update_hover()
		if drag_mode == "pan":
			pan = pan_at_drag_start + (pointer_screen - pan_drag_start)
		elif drag_mode == "connect":
			if not anchor_snap_active:
				var candidate := _grid_point_at(pointer_screen)
				if candidate.has("point"):
					var target: Vector2 = candidate["point"]
					if not target.is_equal_approx(line_start_world):
						_begin_anchor_snap(target)
		elif drag_mode == "selection_pending":
			if pointer_screen.distance_to(selection_rect_start) >= RECT_SELECT_DRAG_THRESHOLD:
				drag_mode = "selection"
				selection_rect = _selection_rect_from_points(selection_rect_start, pointer_screen)
		elif drag_mode == "selection":
			selection_rect = _selection_rect_from_points(selection_rect_start, pointer_screen)
		elif drag_mode == "left_scroll_pending":
			if pointer_screen.distance_to(left_scroll_drag_start_mouse) >= LEFT_SCROLL_DRAG_THRESHOLD:
				drag_mode = "left_scroll"
				_update_left_scroll_drag()
		elif drag_mode == "left_scroll":
			_update_left_scroll_drag()
		elif drag_mode == "symbol_pending":
			# Um clique simples só seleciona o selo. O arraste começa depois de
			# uma pequena distância, para o selo não sumir ao ser configurado.
			if pointer_screen.distance_to(symbol_press_screen) >= SYMBOL_DRAG_THRESHOLD:
				drag_mode = "symbol"
				symbol_drag_start_snapshot = _connections_snapshot()
				_set_connection_symbol(dragged_symbol_source, "", false)
		elif drag_mode == "intensity":
			_update_selected_intensity(pointer_screen)
		elif drag_mode.begins_with("resize_"):
			_resize_panel(pointer_screen)
		queue_redraw()
		accept_event()
		return

	if not (event is InputEventMouseButton):
		return

	pointer_screen = event.position
	_update_hover()

	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _left_command_list_rect().has_point(pointer_screen):
		_scroll_left_commands(-1)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _left_command_list_rect().has_point(pointer_screen):
		_scroll_left_commands(1)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _is_canvas_position(pointer_screen):
		_zoom_at_pointer(1.12)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _is_canvas_position(pointer_screen):
		_zoom_at_pointer(1.0 / 1.12)
		accept_event()
		return

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_drag()
		queue_redraw()
		accept_event()
		return

	if event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed and _is_canvas_position(pointer_screen):
			_begin_pan()
		elif not event.pressed and drag_mode == "pan":
			_reset_drag()
		queue_redraw()
		accept_event()
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		if editing_intensity_text and not _intensity_value_rect().has_point(pointer_screen):
			_commit_intensity_text()
		var panel_toggle := _panel_toggle_at(pointer_screen)
		if not panel_toggle.is_empty():
			_toggle_panel(panel_toggle)
			queue_redraw()
			accept_event()
			return
		if _play_button_rect().has_point(pointer_screen):
			_run_ritual()
			queue_redraw()
			accept_event()
			return
		var resize_handle := _resize_handle_at(pointer_screen)
		if not resize_handle.is_empty():
			_begin_resize(resize_handle)
			accept_event()
			return
		if _intensity_value_rect().has_point(pointer_screen):
			_begin_intensity_text_edit()
			queue_redraw()
			accept_event()
			return
		if _intensity_slider_rect().has_point(pointer_screen):
			_begin_intensity_drag()
			_update_selected_intensity(pointer_screen)
			queue_redraw()
			accept_event()
			return
		if _left_command_list_rect().has_point(pointer_screen):
			_begin_left_scroll_gesture(event.ctrl_pressed)
			queue_redraw()
			accept_event()
			return
		var palette_symbol := _palette_symbol_at(pointer_screen)
		if not palette_symbol.is_empty():
			drag_mode = "symbol"
			active_symbol = palette_symbol
			dragged_symbol_source = -1
		elif _is_canvas_position(pointer_screen):
			var current_symbol := _symbol_at(pointer_screen)
			if current_symbol >= 0:
				_select_connection(current_symbol, event.ctrl_pressed)
				if not event.ctrl_pressed and _is_connection_selected(current_symbol):
					drag_mode = "symbol_pending"
					dragged_symbol_source = current_symbol
					active_symbol = str(connections[current_symbol].get("symbol", ""))
					symbol_press_screen = pointer_screen
			else:
				var start_candidate := _grid_point_at(pointer_screen)
				if start_candidate.has("point"):
					_deselect_connection()
					drag_mode = "connect"
					line_start_world = start_candidate["point"]
					hovered_connection = -1
				else:
					var line_connection := _connection_near(pointer_screen)
					if line_connection >= 0:
						_select_connection(line_connection, event.ctrl_pressed)
					else:
						_begin_rectangle_selection(event.ctrl_pressed)
	else:
		if drag_mode == "connect":
			if anchor_snap_active:
				_complete_anchor_snap()
			else:
				var end_candidate := _grid_point_at(pointer_screen)
				if end_candidate.has("point"):
					var end_point: Vector2 = end_candidate["point"]
					if not end_point.is_equal_approx(line_start_world):
						_add_connection(line_start_world, end_point)
		elif drag_mode == "symbol":
			_place_active_symbol()
		elif drag_mode == "intensity":
			_finish_intensity_drag()
		elif drag_mode == "selection":
			_select_connections_in_rect(selection_rect, selection_rect_additive)
		elif drag_mode == "selection_pending" and not selection_rect_additive:
			_deselect_connection()
		elif drag_mode == "left_scroll_pending" and left_scroll_pressed_connection >= 0:
			_select_connection(left_scroll_pressed_connection, left_scroll_additive)
		_reset_drag()

	queue_redraw()
	accept_event()


func _run_ritual() -> void:
	ritual_running = true
	execution_output.clear()
	execution_errors.clear()
	execution_warnings.clear()
	var compilation := compiler.compile(connections)
	for warning in compilation.get("warnings", []):
		execution_warnings.append(str(warning))
	if not compilation["ok"]:
		for error in compilation.get("errors", []):
			execution_errors.append(str(error))
		bottom_panel_open = true
		ritual_running = false
		return

	last_bytecode = compilation["bytecode"]
	var execution := vm.run(last_bytecode)
	for line in execution.get("output", []):
		execution_output.append(str(line))
	for error in execution.get("errors", []):
		execution_errors.append(str(error))
	bottom_panel_open = true
	ritual_running = false


func export_current_ritual(path: String) -> Dictionary:
	var result := compiler.export_binary(connections, path)
	if result["ok"]:
		last_bytecode = result["bytecode"]
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var canvas_rect := _canvas_rect()
	draw_rect(canvas_rect, CANVAS_BACKGROUND, true)
	_draw_grid(canvas_rect)
	_draw_connections()
	_draw_connection_preview()
	_draw_selection_rectangle()
	_draw_dragged_symbol()
	_draw_settling_symbol()
	_draw_intensity_inspector()
	_draw_interface_panels()


func _draw_grid(canvas_rect: Rect2) -> void:
	var top_left_world := _screen_to_world(canvas_rect.position)
	var bottom_right_world := _screen_to_world(canvas_rect.end)
	var first_x := int(floor(top_left_world.x / GRID_SPACING)) - 1
	var last_x := int(ceil(bottom_right_world.x / GRID_SPACING)) + 1
	var first_y := int(floor(top_left_world.y / GRID_SPACING)) - 1
	var last_y := int(ceil(bottom_right_world.y / GRID_SPACING)) + 1

	for x in range(first_x, last_x + 1):
		for y in range(first_y, last_y + 1):
			var world_point := Vector2(x * GRID_SPACING, y * GRID_SPACING)
			# Pontos que já sustentam uma ligação não aparecem por baixo da linha.
			if _is_anchor_point(world_point):
				continue
			var screen_point := _world_to_screen(world_point)
			var is_hovered := animated_hover_point_valid and world_point.is_equal_approx(animated_hover_world)
			var radius := DOT_RADIUS * zoom
			var color := GRID_DOT
			if is_hovered:
				var highlight_alpha := _hover_alpha(point_hover_started_at)
				radius = lerpf(radius, 5.0 * zoom, highlight_alpha)
				color = color.lerp(Color("db5250"), highlight_alpha)
			draw_circle(screen_point, radius, color)


func _is_anchor_point(world_point: Vector2) -> bool:
	return _connection_point_uses(world_point) > 1


func _is_terminal_point(world_point: Vector2) -> bool:
	return _connection_point_uses(world_point) == 1


func _connection_point_uses(world_point: Vector2) -> int:
	var connection_uses := 0
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		if from_point.is_equal_approx(world_point) or to_point.is_equal_approx(world_point):
			connection_uses += 1
	return connection_uses


func _draw_connections() -> void:
	# A estrutura inteira usa a mesma tinta-base. Cada ligação ainda existe no
	# diagrama, mas só é revelada como uma célula individual pelo hover.
	var line_shadow := RUNE_LINE_COLOR.darkened(0.72)
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		draw_line(_world_to_screen(from_point), _world_to_screen(to_point), line_shadow, 4.2 * zoom, true)
	_draw_line_joins_and_caps(line_shadow, 2.1 * zoom)

	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		draw_line(_world_to_screen(from_point), _world_to_screen(to_point), RUNE_LINE_COLOR, 2.0 * zoom, true)
	_draw_line_joins_and_caps(RUNE_LINE_COLOR, 1.0 * zoom)
	_draw_terminal_markers(line_shadow)

	# A seção sob o cursor recebe apenas uma névoa leve; a linha-base continua
	# uniforme e não vira uma sequência de retângulos.
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var from_screen := _world_to_screen(from_point)
		var to_screen := _world_to_screen(to_point)
		var has_symbol := not str(connection.get("symbol", "")).is_empty()
		var intensity := _connection_intensity(connection)
		if _is_connection_selected(index):
			var selection_glow := RUNE_LINE_COLOR.lightened(0.45)
			selection_glow.a = 0.20
			draw_line(from_screen, to_screen, selection_glow, 3.2 * zoom, true)
			_draw_rounded_segment_caps(from_screen, to_screen, selection_glow, 1.6 * zoom)
		if index == animated_hover_connection:
			var highlight_alpha := _hover_alpha(connection_hover_started_at)
			var soft_glow := RUNE_LINE_COLOR.lightened(0.35)
			soft_glow.a = 0.10 * highlight_alpha
			draw_line(from_screen, to_screen, soft_glow, 6.0 * zoom, true)
			_draw_rounded_segment_caps(from_screen, to_screen, soft_glow, 3.0 * zoom)
			var bright_glow := RUNE_LINE_COLOR.lightened(0.55)
			bright_glow.a = 0.26 * highlight_alpha
			draw_line(from_screen, to_screen, bright_glow, 2.2 * zoom, true)
			_draw_rounded_segment_caps(from_screen, to_screen, bright_glow, 1.1 * zoom)

		# Não há slot visível: a própria linha funciona como o sublinhado do selo.
		var symbol_is_settling := symbol_settle_active and symbol_settle_connection == index
		if has_symbol and not symbol_is_settling:
			var symbol_position := _symbol_position(connection, index)
			var kind := str(connection["symbol"])
			var rune_color := _intensity_color(intensity)
			if index == animated_hover_symbol:
				_draw_symbol_hover_glow(kind, symbol_position, rune_color, _symbol_hover_alpha())
			if _is_connection_selected(index):
				_draw_symbol_selection_glow(kind, symbol_position, rune_color)
			_draw_rune(kind, symbol_position, zoom, rune_color)


func _draw_line_joins_and_caps(color: Color, radius: float) -> void:
	# O círculo tem exatamente metade da largura do traço. Nas junções ele cria
	# uma curva contínua; nas extremidades, uma ponta arredondada.
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		draw_circle(_world_to_screen(from_point), radius, color, true, -1.0, true)
		draw_circle(_world_to_screen(to_point), radius, color, true, -1.0, true)


func _draw_terminal_markers(line_shadow: Color) -> void:
	# Primeiro e último ponto de cada sequência substituem o pontinho vermelho
	# por uma âncora dourada mais evidente.
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		if _is_terminal_point(from_point):
			_draw_terminal_marker(_world_to_screen(from_point), line_shadow)
		if _is_terminal_point(to_point):
			_draw_terminal_marker(_world_to_screen(to_point), line_shadow)


func _draw_terminal_marker(screen_position: Vector2, line_shadow: Color) -> void:
	draw_circle(screen_position, 4.4 * zoom, line_shadow, true, -1.0, true)
	draw_circle(screen_position, 3.0 * zoom, RUNE_LINE_COLOR, true, -1.0, true)


func _draw_rounded_segment_caps(from_screen: Vector2, to_screen: Vector2, color: Color, radius: float) -> void:
	draw_circle(from_screen, radius, color, true, -1.0, true)
	draw_circle(to_screen, radius, color, true, -1.0, true)


func _settle_ease(progress: float) -> float:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_progress, 3.0)


func _symbol_position(connection: Dictionary, connection_index := -1) -> Vector2:
	var from_point: Vector2 = connection["from"]
	var to_point: Vector2 = connection["to"]
	var from_screen := _world_to_screen(from_point)
	var to_screen := _world_to_screen(to_point)
	var middle := (from_screen + to_screen) * 0.5
	var direction := to_screen - from_screen
	if direction.length_squared() < 0.001:
		return middle
	var normal := Vector2(-direction.y, direction.x).normalized()
	# Uma sequência inteira preserva o mesmo lado (direita/esquerda) do seu traço.
	# Isso evita que cada segmento de um zigue-zague escolha um lado isoladamente.
	if connection_index >= 0:
		normal *= _sequence_side_multiplier(connection_index)
	else:
		normal = _preferred_screen_side(normal)
	return middle + normal * (20.0 * zoom)


func _sequence_side_multiplier(connection_index: int) -> float:
	var start_index := _sequence_start_index(connection_index)
	var start_connection: Dictionary = connections[start_index]
	var start_from: Vector2 = start_connection["from"]
	var start_to: Vector2 = start_connection["to"]
	var initial_direction := _world_to_screen(start_to) - _world_to_screen(start_from)
	if initial_direction.length_squared() < 0.001:
		return 1.0
	var initial_right_side := Vector2(-initial_direction.y, initial_direction.x).normalized()
	var preferred_side := _preferred_screen_side(initial_right_side)
	return 1.0 if initial_right_side.dot(preferred_side) >= 0.0 else -1.0


func _sequence_start_index(connection_index: int) -> int:
	var current_index := connection_index
	var visited := {}
	while not visited.has(current_index):
		visited[current_index] = true
		var current: Dictionary = connections[current_index]
		var current_from: Vector2 = current["from"]
		var previous_index := -1
		for candidate_index in range(connections.size()):
			if candidate_index == current_index:
				continue
			var candidate: Dictionary = connections[candidate_index]
			var candidate_to: Vector2 = candidate["to"]
			if candidate_to.is_equal_approx(current_from):
				if previous_index >= 0:
					# Em uma junção ambígua, este segmento passa a ser o início visual.
					return current_index
				previous_index = candidate_index
		if previous_index < 0 or visited.has(previous_index):
			break
		current_index = previous_index
	return current_index


func _preferred_screen_side(normal: Vector2) -> Vector2:
	# A sequência inicial nasce no lado mais alto; em empate, no lado direito.
	if normal.y > 0.0 or (is_zero_approx(normal.y) and normal.x < 0.0):
		return -normal
	return normal


func _draw_connection_preview() -> void:
	if drag_mode != "connect":
		return
	var start_screen := _world_to_screen(line_start_world)
	draw_line(start_screen, _anchor_snap_endpoint(), Color("73dcff"), 3.0 * zoom, true)


func _draw_selection_rectangle() -> void:
	if drag_mode != "selection":
		return
	var fill_color := Color("cdbb8c")
	fill_color.a = 0.08
	var border_color := Color("f4df9d")
	border_color.a = 0.72
	draw_rect(selection_rect, fill_color, true)
	draw_rect(selection_rect, border_color, false, 1.0, true)


func _anchor_snap_endpoint() -> Vector2:
	if not anchor_snap_active:
		return pointer_screen
	var target_screen := _world_to_screen(anchor_snap_target)
	var progress := clampf((animation_clock - anchor_snap_started_at) / ANCHOR_SNAP_DURATION, 0.0, 1.0)
	return anchor_snap_from.lerp(target_screen, _settle_ease(progress))


func _begin_anchor_snap(target: Vector2) -> void:
	anchor_snap_active = true
	anchor_snap_from = pointer_screen
	anchor_snap_target = target
	anchor_snap_started_at = animation_clock
	hovered_connection = -1


func _complete_anchor_snap() -> void:
	if not anchor_snap_active:
		return
	var target := anchor_snap_target
	anchor_snap_active = false
	if not target.is_equal_approx(line_start_world):
		_add_connection(line_start_world, target)
		line_start_world = target
	hovered_connection = -1


func _draw_dragged_symbol() -> void:
	if drag_mode == "symbol" and not active_symbol.is_empty():
		_draw_rune(active_symbol, pointer_screen, zoom, Color("ffe0a3"))


func _draw_settling_symbol() -> void:
	if not symbol_settle_active:
		return
	var progress := clampf((animation_clock - symbol_settle_started_at) / SYMBOL_SETTLE_DURATION, 0.0, 1.0)
	var position := symbol_settle_from.lerp(symbol_settle_to, _settle_ease(progress))
	if progress >= 1.0:
		if _is_connection_selected(symbol_settle_connection):
			_draw_symbol_selection_glow(symbol_settle_kind, position, _intensity_color(symbol_settle_intensity))
		symbol_settle_active = false
	_draw_rune(symbol_settle_kind, position, zoom, _intensity_color(symbol_settle_intensity))


func _draw_symbol_selection_glow(kind: String, symbol_position: Vector2, rune_color: Color) -> void:
	# A seleção acompanha o formato da runa, em vez de usar uma bolha circular.
	var outer_color := rune_color.lightened(0.35)
	var inner_color := rune_color.lightened(0.20)
	_draw_rune_aura(kind, symbol_position, outer_color, 5.0 * zoom, 0.014)
	_draw_rune_aura(kind, symbol_position, inner_color, 2.35 * zoom, 0.035)


func _draw_symbol_hover_glow(kind: String, symbol_position: Vector2, rune_color: Color, highlight_alpha: float) -> void:
	if highlight_alpha <= 0.0:
		return
	var glow_color := rune_color.lightened(0.30)
	_draw_rune_aura(kind, symbol_position, glow_color, 3.6 * zoom, 0.016 * highlight_alpha)


func _draw_rune_aura(kind: String, center: Vector2, aura_color: Color, spread: float, alpha: float) -> void:
	var color := aura_color
	color.a = alpha
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var offset := Vector2(cos(angle), sin(angle)) * spread
		_draw_rune(kind, center + offset, zoom, color)


func _draw_intensity_inspector() -> void:
	if not _has_selected_connection():
		return
	var inspector := _intensity_inspector_rect()
	if inspector.size.x <= 0.0 or inspector.size.y <= 0.0:
		return
	var connection: Dictionary = connections[selected_connection]
	var kind := str(connection.get("symbol", ""))
	var data := _symbol_data(kind)
	var intensity := _connection_intensity(connection)
	_draw_arcane_frame(inspector)
	_draw_rune(kind, inspector.position + Vector2(23.0, 25.0), 0.72, _intensity_color(intensity))
	draw_string(ThemeDB.fallback_font, inspector.position + Vector2(42.0, 21.0), "INTENSIDADE", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
	draw_string(ThemeDB.fallback_font, inspector.position + Vector2(42.0, 40.0), str(data["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, TEXT_PRIMARY)
	var value_rect := _intensity_value_rect()
	draw_rect(value_rect, Color("29242e") if editing_intensity_text else Color("17151d"), true)
	draw_rect(value_rect, Color("ffe0a3") if editing_intensity_text else PANEL_BORDER, false, 1.0)
	var displayed_intensity := intensity_text if editing_intensity_text else "%03d" % intensity
	draw_string(ThemeDB.fallback_font, value_rect.position + Vector2(8.0, 19.0), displayed_intensity, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("fff0ad") if editing_intensity_text else TEXT_PRIMARY)

	var slider := _intensity_slider_rect()
	for segment in range(24):
		var start_t := float(segment) / 24.0
		var end_t := float(segment + 1) / 24.0
		var start := Vector2(slider.position.x + slider.size.x * start_t, slider.get_center().y)
		var end := Vector2(slider.position.x + slider.size.x * end_t, slider.get_center().y)
		draw_line(start, end, _intensity_color(int(start_t * 255.0)), 5.0, true)
	draw_line(Vector2(slider.position.x, slider.get_center().y), Vector2(slider.end.x, slider.get_center().y), PANEL_BORDER, 1.0, true)
	var marker_x := slider.position.x + slider.size.x * (float(intensity) / 255.0)
	draw_circle(Vector2(marker_x, slider.get_center().y), 7.0, Color("0a0a0c"))
	draw_arc(Vector2(marker_x, slider.get_center().y), 7.0, 0.0, TAU, 16, Color("f5df9a"), 1.5, true)


func _draw_interface_panels() -> void:
	_draw_left_panel()
	_draw_top_panel()
	_draw_bottom_panel()
	_draw_resize_handles()
	_draw_palette_tooltip()


func _draw_left_panel() -> void:
	var panel := Rect2(0.0, 0.0, _left_panel_width(), size.y)
	_draw_arcane_frame(panel)
	_draw_toggle_button(_left_toggle_rect(), "left" if left_panel_open else "right")
	if not left_panel_open:
		return

	var list_rect := _left_command_list_rect()
	var command_scroll := minf(left_command_scroll, _left_command_max_scroll())
	var row_y := LEFT_COMMAND_LIST_TOP + 6.0 - command_scroll
	var command_count := _symbol_connection_count()
	for connection_index in range(connections.size()):
		var connection: Dictionary = connections[connection_index]
		var kind := str(connection.get("symbol", ""))
		if kind.is_empty():
			continue
		var data := _symbol_data(kind)
		var row := Rect2(14.0, row_y, panel.size.x - 28.0, 58.0)
		if row.end.y > list_rect.position.y and row.position.y < list_rect.end.y:
			draw_rect(row, PANEL_INNER, true)
			draw_rect(row, Color("83d9ee") if _is_connection_selected(connection_index) else PANEL_BORDER, false, 1.0)
			var intensity := _connection_intensity(connection)
			_draw_rune(kind, row.position + Vector2(28.0, 29.0), 0.82, _intensity_color(intensity))
			draw_string(ThemeDB.fallback_font, row.position + Vector2(56.0, 25.0), str(data["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, TEXT_PRIMARY)
			var extra := ""
			if kind == "ORB":
				extra = "valor: %d" % intensity
			else:
				extra = "%s · %03d" % [str(data["extra"]), intensity]
			draw_string(ThemeDB.fallback_font, row.position + Vector2(56.0, 45.0), extra, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
			draw_line(row.position + Vector2(8.0, 49.0), row.position + Vector2(row.size.x - 8.0, 49.0), Color("3d3b42"), 1.0, true)
		row_y += LEFT_COMMAND_ROW_HEIGHT
		if row.position.y > list_rect.end.y:
			break

	_draw_left_scroll_masks(panel, list_rect)
	_draw_left_panel_header(panel)
	_draw_left_command_scrollbar(list_rect, command_scroll)
	_draw_toggle_button(_left_toggle_rect(), "left")

	if command_count == 0:
		draw_arc(Vector2(panel.size.x * 0.5, 132.0), 30.0, 0.0, TAU, 32, Color("3e3c43"), 1.0, true)
		draw_line(Vector2(panel.size.x * 0.5 - 48.0, 132.0), Vector2(panel.size.x * 0.5 + 48.0, 132.0), Color("3e3c43"), 1.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(29.0, 192.0), "Ainda não há símbolos no ritual.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)


func _command_row_at(screen_position: Vector2) -> int:
	if not left_panel_open or not _left_command_list_rect().has_point(screen_position):
		return -1
	var list_rect := _left_command_list_rect()
	var row_y := LEFT_COMMAND_LIST_TOP + 6.0 - minf(left_command_scroll, _left_command_max_scroll())
	for connection_index in range(connections.size()):
		var connection: Dictionary = connections[connection_index]
		if str(connection.get("symbol", "")).is_empty():
			continue
		var row := Rect2(14.0, row_y, _left_panel_width() - 28.0, 58.0)
		if row.end.y > list_rect.position.y and row.position.y < list_rect.end.y and row.has_point(screen_position):
			return connection_index
		row_y += LEFT_COMMAND_ROW_HEIGHT
		if row.position.y > list_rect.end.y:
			break
	return -1


func _left_command_list_rect() -> Rect2:
	if not left_panel_open:
		return Rect2()
	return Rect2(12.0, LEFT_COMMAND_LIST_TOP, _left_panel_width() - 24.0, maxf(size.y - LEFT_COMMAND_LIST_TOP - 18.0, 0.0))


func _draw_left_scroll_masks(panel: Rect2, list_rect: Rect2) -> void:
	# As máscaras fazem o recorte da lista sem impedir o scroll contínuo de
	# mostrar entradas parcialmente na borda da janela.
	draw_rect(Rect2(0.0, 0.0, panel.size.x, list_rect.position.y), PANEL_BACKGROUND, true)
	draw_rect(Rect2(0.0, list_rect.end.y, panel.size.x, panel.end.y - list_rect.end.y), PANEL_BACKGROUND, true)
	# As máscaras cobrem também a moldura; restauramos os traços por cima.
	draw_rect(panel, PANEL_BORDER, false, 2.0)
	var inner := panel.grow(-6.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(inner, Color("3b3940"), false, 1.0)
	draw_rect(list_rect, Color("3b3940"), false, 1.0)


func _draw_left_panel_header(panel: Rect2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 32.0), "GRIMÓRIO ATIVO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, TEXT_PRIMARY)
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 54.0), "Símbolos ligados ao ritual", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	draw_line(Vector2(20.0, 70.0), Vector2(panel.size.x - 20.0, 70.0), PANEL_BORDER, 1.0, true)


func _draw_left_command_scrollbar(list_rect: Rect2, scroll: float) -> void:
	var max_scroll := _left_command_max_scroll()
	if max_scroll <= 0.0:
		return
	var track_x := list_rect.end.x - 7.0
	var track_height := list_rect.size.y - 12.0
	var thumb_height := maxf(28.0, track_height * list_rect.size.y / (list_rect.size.y + max_scroll))
	var travel := maxf(track_height - thumb_height, 0.0)
	var thumb_y := list_rect.position.y + 6.0 + travel * (scroll / max_scroll)
	draw_line(Vector2(track_x, list_rect.position.y + 6.0), Vector2(track_x, list_rect.end.y - 6.0), Color("302e35"), 2.0, true)
	draw_line(Vector2(track_x, thumb_y), Vector2(track_x, thumb_y + thumb_height), Color("a59b7a"), 2.0, true)


func _symbol_connection_count() -> int:
	var count := 0
	for connection in connections:
		if not str(connection.get("symbol", "")).is_empty():
			count += 1
	return count


func _left_command_max_scroll() -> float:
	var content_height := float(_symbol_connection_count()) * LEFT_COMMAND_ROW_HEIGHT - 8.0
	return maxf(content_height - _left_command_list_rect().size.y, 0.0)


func _scroll_left_commands(direction: int) -> void:
	if not left_panel_open:
		return
	left_command_scroll_target = clampf(left_command_scroll_target + float(direction) * LEFT_COMMAND_SCROLL_STEP, 0.0, _left_command_max_scroll())
	queue_redraw()


func _begin_left_scroll_gesture(additive: bool) -> void:
	drag_mode = "left_scroll_pending"
	left_scroll_drag_start_mouse = pointer_screen
	left_scroll_drag_start_offset = left_command_scroll_target
	left_scroll_pressed_connection = _command_row_at(pointer_screen)
	left_scroll_additive = additive


func _update_left_scroll_drag() -> void:
	var offset := left_scroll_drag_start_offset - (pointer_screen.y - left_scroll_drag_start_mouse.y)
	left_command_scroll_target = clampf(offset, 0.0, _left_command_max_scroll())


func _left_scroll_is_moving() -> bool:
	return absf(left_command_scroll_target - left_command_scroll) > 0.1


func _update_left_command_scroll(delta: float) -> void:
	var max_scroll := _left_command_max_scroll()
	left_command_scroll_target = clampf(left_command_scroll_target, 0.0, max_scroll)
	left_command_scroll = clampf(left_command_scroll, 0.0, max_scroll)
	var amount := clampf(delta * LEFT_SCROLL_SMOOTHNESS, 0.0, 1.0)
	left_command_scroll = lerpf(left_command_scroll, left_command_scroll_target, amount)
	if absf(left_command_scroll_target - left_command_scroll) <= 0.1:
		left_command_scroll = left_command_scroll_target
	queue_redraw()


func _draw_top_panel() -> void:
	var panel := _top_panel_rect()
	_draw_arcane_frame(panel)
	_draw_toggle_button(_top_toggle_rect(), "up" if top_panel_open else "down")
	_draw_play_button(_play_button_rect())
	if not top_panel_open:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 16.0, 27.0), "SELOS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 30.0), "SELOS DO ATELIÊ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, TEXT_PRIMARY)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 50.0), "Arraste um símbolo até a linha de um feitiço.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)

	for index in range(PALETTE_SYMBOLS.size()):
		var item: Dictionary = PALETTE_SYMBOLS[index]
		var tile := _palette_rect(index)
		var highlight_alpha := _hover_alpha(palette_hover_started_at) if index == animated_hover_palette_index else 0.0
		var tile_color := PANEL_INNER.lerp(Color("24212c"), highlight_alpha)
		draw_rect(tile, tile_color, true)
		draw_rect(tile, PANEL_BORDER.lerp(PANEL_ACCENT, highlight_alpha), false, 2.0)
		_draw_arcane_tile_mark(tile)
		_draw_rune(str(item["kind"]), tile.get_center(), 1.05, Color("b5b1bb").lerp(Color("ffe0a3"), highlight_alpha))


func _draw_bottom_panel() -> void:
	var panel := _bottom_panel_rect()
	_draw_arcane_frame(panel)
	_draw_toggle_button(_bottom_toggle_rect(), "down" if bottom_panel_open else "up")
	if not bottom_panel_open:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 16.0, panel.position.y + 27.0), "ORÁCULO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 30.0), "ORÁCULO DE EXECUÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, TEXT_PRIMARY)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 51.0), "A saída e os erros do programa aparecerão aqui.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	var divider_x := panel.position.x + panel.size.x * 0.7
	draw_line(Vector2(divider_x, panel.position.y + 68.0), Vector2(divider_x, panel.end.y - 16.0), PANEL_BORDER, 1.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 20.0, panel.position.y + 91.0), "SAÍDA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PANEL_ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(divider_x + 20.0, panel.position.y + 91.0), "ERROS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PANEL_ACCENT)
	var output_y := panel.position.y + 116.0
	for line in execution_output:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 24.0, output_y), "> " + line, HORIZONTAL_ALIGNMENT_LEFT, divider_x - panel.position.x - 42.0, 14, Color("b9ecdc"))
		output_y += 20.0
	var warning_y := output_y
	for warning in execution_warnings:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 24.0, warning_y), "~ " + warning, HORIZONTAL_ALIGNMENT_LEFT, divider_x - panel.position.x - 42.0, 12, Color("d8c783"))
		warning_y += 18.0
	var error_y := panel.position.y + 116.0
	for error in execution_errors:
		draw_string(ThemeDB.fallback_font, Vector2(divider_x + 20.0, error_y), "! " + error, HORIZONTAL_ALIGNMENT_LEFT, panel.end.x - divider_x - 40.0, 13, Color("ff8791"))
		error_y += 20.0
	if execution_output.is_empty() and execution_errors.is_empty() and execution_warnings.is_empty():
		_draw_rune("ORB", Vector2(panel.position.x + panel.size.x * 0.35, panel.position.y + 145.0), 1.6, Color("36343a"))


func _draw_palette_tooltip() -> void:
	if not top_panel_open or hovered_palette_index < 0:
		return
	var item: Dictionary = PALETTE_SYMBOLS[hovered_palette_index]
	var tile := _palette_rect(hovered_palette_index)
	var tooltip_width := 260.0
	var tooltip_x := minf(tile.position.x, size.x - tooltip_width - 12.0)
	var tooltip := Rect2(tooltip_x, tile.end.y + 10.0, tooltip_width, 56.0)
	draw_rect(tooltip, Color("0b0a0e"), true)
	draw_rect(tooltip, Color("b5b1bb"), false, 1.0)
	draw_string(ThemeDB.fallback_font, tooltip.position + Vector2(12.0, 21.0), str(item["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("ffe0a3"))
	draw_string(ThemeDB.fallback_font, tooltip.position + Vector2(12.0, 42.0), str(item["description"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_PRIMARY)


func _draw_arcane_frame(rect: Rect2) -> void:
	draw_rect(rect, PANEL_BACKGROUND, true)
	draw_rect(rect, PANEL_BORDER, false, 2.0)
	var inner := rect.grow(-6.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		draw_rect(inner, Color("3b3940"), false, 1.0)
	var corner := 13.0
	var top_left := rect.position + Vector2(9.0, 9.0)
	var top_right := Vector2(rect.end.x - 9.0, rect.position.y + 9.0)
	var bottom_left := Vector2(rect.position.x + 9.0, rect.end.y - 9.0)
	var bottom_right := rect.end - Vector2(9.0, 9.0)
	draw_line(top_left, top_left + Vector2(corner, 0.0), PANEL_ACCENT, 1.0, true)
	draw_line(top_left, top_left + Vector2(0.0, corner), PANEL_ACCENT, 1.0, true)
	draw_line(top_right, top_right + Vector2(-corner, 0.0), PANEL_ACCENT, 1.0, true)
	draw_line(top_right, top_right + Vector2(0.0, corner), PANEL_ACCENT, 1.0, true)
	draw_line(bottom_left, bottom_left + Vector2(corner, 0.0), PANEL_ACCENT, 1.0, true)
	draw_line(bottom_left, bottom_left + Vector2(0.0, -corner), PANEL_ACCENT, 1.0, true)
	draw_line(bottom_right, bottom_right + Vector2(-corner, 0.0), PANEL_ACCENT, 1.0, true)
	draw_line(bottom_right, bottom_right + Vector2(0.0, -corner), PANEL_ACCENT, 1.0, true)


func _draw_arcane_tile_mark(tile: Rect2) -> void:
	var center := tile.get_center()
	draw_arc(center, tile.size.x * 0.37, 0.0, TAU, 20, Color("36333c"), 1.0, true)
	draw_circle(center, 2.0, Color("494650"))


func _draw_toggle_button(rect: Rect2, direction: String) -> void:
	var center := rect.get_center()
	draw_rect(rect, Color("17151d"), true)
	draw_rect(rect, PANEL_ACCENT, false, 1.0)
	draw_arc(center, 11.0, 0.0, TAU, 16, Color("4c4953"), 1.0, true)
	var a := center
	var b := center
	var c := center
	match direction:
		"left":
			a += Vector2(3.0, -6.0)
			b += Vector2(-4.0, 0.0)
			c += Vector2(3.0, 6.0)
		"right":
			a += Vector2(-3.0, -6.0)
			b += Vector2(4.0, 0.0)
			c += Vector2(-3.0, 6.0)
		"up":
			a += Vector2(-6.0, 3.0)
			b += Vector2(0.0, -4.0)
			c += Vector2(6.0, 3.0)
		"down":
			a += Vector2(-6.0, -3.0)
			b += Vector2(0.0, 4.0)
			c += Vector2(6.0, -3.0)
	draw_line(a, b, Color("e1dbe6"), 2.0, true)
	draw_line(b, c, Color("e1dbe6"), 2.0, true)


func _draw_play_button(rect: Rect2) -> void:
	var center := rect.get_center()
	var accent := Color("8be5fc") if ritual_running else Color("b8b4be")
	draw_rect(rect, Color("111720") if ritual_running else Color("17151d"), true)
	draw_rect(rect, accent, false, 1.0)
	draw_arc(center, 11.0, 0.0, TAU, 16, accent.darkened(0.45), 1.0, true)
	if ritual_running:
		draw_rect(Rect2(center - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), accent, true)
	else:
		var a := center + Vector2(-3.0, -6.0)
		var b := center + Vector2(6.0, 0.0)
		var c := center + Vector2(-3.0, 6.0)
		draw_colored_polygon(PackedVector2Array([a, b, c]), accent)


func _draw_resize_handles() -> void:
	if left_panel_open:
		var x := left_panel_size
		draw_line(Vector2(x, 44.0), Vector2(x, size.y - 44.0), Color("aaa7b0"), 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			draw_circle(Vector2(x, size.y * 0.5 + offset), 1.4, Color("e0dce4"))
	if top_panel_open:
		var y := top_panel_size
		draw_line(Vector2(_left_panel_width() + 44.0, y), Vector2(size.x - 44.0, y), Color("aaa7b0"), 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			draw_circle(Vector2(size.x * 0.5 + offset, y), 1.4, Color("e0dce4"))
	if bottom_panel_open:
		var y := size.y - bottom_panel_size
		draw_line(Vector2(_left_panel_width() + 44.0, y), Vector2(size.x - 44.0, y), Color("aaa7b0"), 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			draw_circle(Vector2(size.x * 0.5 + offset, y), 1.4, Color("e0dce4"))


func _draw_rune(kind: String, center: Vector2, rune_scale: float, color: Color) -> void:
	var r := 11.0 * rune_scale
	var main_stroke := 2.5 * rune_scale
	var fine_stroke := 1.2 * rune_scale
	match kind:
		"ORB":
			draw_arc(center, r, 0.0, TAU, 24, color, main_stroke, true)
			draw_circle(center, r * 0.28, color)
		"DIAMOND":
			var top := center + Vector2(0.0, -r)
			var right := center + Vector2(r, 0.0)
			var bottom := center + Vector2(0.0, r)
			var left := center + Vector2(-r, 0.0)
			draw_line(top, right, color, main_stroke, true)
			draw_line(right, bottom, color, main_stroke, true)
			draw_line(bottom, left, color, main_stroke, true)
			draw_line(left, top, color, main_stroke, true)
		"TRIANGLE":
			var a := center + Vector2(0.0, -r)
			var b := center + Vector2(r * 0.9, r * 0.75)
			var c := center + Vector2(-r * 0.9, r * 0.75)
			draw_line(a, b, color, main_stroke, true)
			draw_line(b, c, color, main_stroke, true)
			draw_line(c, a, color, main_stroke, true)
		"CROSS":
			draw_line(center + Vector2(-r, -r), center + Vector2(r, r), color, 2.8 * rune_scale, true)
			draw_line(center + Vector2(r, -r), center + Vector2(-r, r), color, 2.8 * rune_scale, true)
		"MOON":
			draw_arc(center + Vector2(r * 0.18, 0.0), r, PI * 0.55, PI * 1.45, 18, color, main_stroke, true)
			draw_arc(center + Vector2(-r * 0.22, 0.0), r * 0.76, PI * 1.55, PI * 0.45, 18, color, main_stroke, true)
		"PLUS":
			draw_line(center + Vector2(-r, 0.0), center + Vector2(r, 0.0), color, 2.6 * rune_scale, true)
			draw_line(center + Vector2(0.0, -r), center + Vector2(0.0, r), color, 2.6 * rune_scale, true)
			draw_circle(center, r * 0.28, color, false, fine_stroke, true)
		"SQUARE":
			var square := Rect2(center - Vector2(r * 0.75, r * 0.75), Vector2(r * 1.5, r * 1.5))
			draw_rect(square, color, false, 2.4 * rune_scale, true)
			draw_rect(square.grow(-r * 0.28), color, false, fine_stroke, true)
		"FORK":
			draw_line(center + Vector2(-r * 0.75, -r), center + Vector2(-r * 0.75, r), color, 2.4 * rune_scale, true)
			draw_line(center + Vector2(-r * 0.75, -r * 0.15), center + Vector2(r * 0.75, -r * 0.15), color, 2.4 * rune_scale, true)
			draw_line(center + Vector2(-r * 0.75, r * 0.42), center + Vector2(r * 0.35, r * 0.42), color, 2.4 * rune_scale, true)
			draw_circle(center + Vector2(r * 0.55, -r * 0.15), r * 0.16, color)


func _is_canvas_position(screen_position: Vector2) -> bool:
	return _canvas_rect().has_point(screen_position)


func _canvas_rect() -> Rect2:
	var left := _left_panel_width()
	var top := _top_panel_height()
	var bottom := _bottom_panel_height()
	return Rect2(left, top, maxf(size.x - left, 0.0), maxf(size.y - top - bottom, 0.0))


func _left_panel_width() -> float:
	return left_panel_size if left_panel_open else PANEL_TAB_SIZE


func _top_panel_height() -> float:
	return top_panel_size if top_panel_open else PANEL_TAB_SIZE


func _bottom_panel_height() -> float:
	return bottom_panel_size if bottom_panel_open else PANEL_TAB_SIZE


func _top_panel_rect() -> Rect2:
	var left := _left_panel_width()
	return Rect2(left, 0.0, maxf(size.x - left, 0.0), _top_panel_height())


func _bottom_panel_rect() -> Rect2:
	var left := _left_panel_width()
	var panel_height := _bottom_panel_height()
	return Rect2(left, size.y - panel_height, maxf(size.x - left, 0.0), panel_height)


func _left_toggle_rect() -> Rect2:
	if left_panel_open:
		return Rect2(left_panel_size - 38.0, 8.0, 30.0, 30.0)
	return Rect2(6.0, size.y * 0.5 - 15.0, 30.0, 30.0)


func _top_toggle_rect() -> Rect2:
	return Rect2(size.x - 38.0, 6.0, 30.0, 30.0)


func _bottom_toggle_rect() -> Rect2:
	var panel := _bottom_panel_rect()
	return Rect2(size.x - 38.0, panel.position.y + 6.0, 30.0, 30.0)


func _panel_toggle_at(screen_position: Vector2) -> String:
	if _left_toggle_rect().has_point(screen_position):
		return "left"
	if _top_toggle_rect().has_point(screen_position):
		return "top"
	if _bottom_toggle_rect().has_point(screen_position):
		return "bottom"
	return ""


func _toggle_panel(panel: String) -> void:
	match panel:
		"left":
			left_panel_open = not left_panel_open
		"top":
			top_panel_open = not top_panel_open
		"bottom":
			bottom_panel_open = not bottom_panel_open
	_update_hover()


func _play_button_rect() -> Rect2:
	return Rect2(size.x - 74.0, 6.0, 30.0, 30.0)


func _resize_handle_at(screen_position: Vector2) -> String:
	if left_panel_open and absf(screen_position.x - left_panel_size) <= 6.0:
		return "left"
	if top_panel_open and screen_position.x >= _left_panel_width() and absf(screen_position.y - top_panel_size) <= 6.0:
		return "top"
	var bottom_edge := size.y - bottom_panel_size
	if bottom_panel_open and screen_position.x >= _left_panel_width() and absf(screen_position.y - bottom_edge) <= 6.0:
		return "bottom"
	return ""


func _begin_resize(panel: String) -> void:
	drag_mode = "resize_%s" % panel
	resize_start_mouse = pointer_screen
	match panel:
		"left":
			resize_start_size = left_panel_size
		"top":
			resize_start_size = top_panel_size
		"bottom":
			resize_start_size = bottom_panel_size


func _resize_panel(screen_position: Vector2) -> void:
	match drag_mode:
		"resize_left":
			var max_width := maxf(MIN_LEFT_PANEL_WIDTH, size.x - 190.0)
			left_panel_size = clampf(resize_start_size + (screen_position.x - resize_start_mouse.x), MIN_LEFT_PANEL_WIDTH, max_width)
		"resize_top":
			var max_top_height := maxf(MIN_TOP_PANEL_HEIGHT, size.y - _bottom_panel_height() - 120.0)
			top_panel_size = clampf(resize_start_size + (screen_position.y - resize_start_mouse.y), MIN_TOP_PANEL_HEIGHT, max_top_height)
		"resize_bottom":
			var max_bottom_height := maxf(MIN_BOTTOM_PANEL_HEIGHT, size.y - _top_panel_height() - 120.0)
			bottom_panel_size = clampf(resize_start_size - (screen_position.y - resize_start_mouse.y), MIN_BOTTOM_PANEL_HEIGHT, max_bottom_height)
	_update_hover()


func _has_selected_connection() -> bool:
	if selected_connections.size() != 1 or selected_connection < 0 or selected_connection >= connections.size():
		return false
	return not str(connections[selected_connection].get("symbol", "")).is_empty()


func _intensity_inspector_rect() -> Rect2:
	if not _has_selected_connection():
		return Rect2()
	var canvas := _canvas_rect()
	var panel_width := minf(272.0, maxf(canvas.size.x - 20.0, 0.0))
	return Rect2(canvas.end.x - panel_width - 12.0, canvas.end.y - 88.0, panel_width, 76.0)


func _intensity_slider_rect() -> Rect2:
	var inspector := _intensity_inspector_rect()
	if inspector.size.x <= 0.0:
		return Rect2()
	return Rect2(inspector.position.x + 16.0, inspector.position.y + 53.0, inspector.size.x - 32.0, 10.0)


func _intensity_value_rect() -> Rect2:
	var inspector := _intensity_inspector_rect()
	if inspector.size.x <= 0.0:
		return Rect2()
	return Rect2(inspector.end.x - 62.0, inspector.position.y + 12.0, 50.0, 26.0)


func _connection_intensity(connection: Dictionary) -> int:
	return clampi(int(connection.get("intensity", 128)), 0, 255)


func _intensity_color(intensity: int) -> Color:
	var amount := float(clampi(intensity, 0, 255)) / 255.0
	return Color("211d29").lerp(Color("fff0ad"), amount)


func _begin_intensity_drag() -> void:
	if not _has_selected_connection():
		return
	drag_mode = "intensity"
	intensity_drag_start_snapshot = _connections_snapshot()
	intensity_drag_changed = false


func _update_selected_intensity(screen_position: Vector2) -> void:
	if not _has_selected_connection():
		return
	var slider := _intensity_slider_rect()
	var amount := clampf((screen_position.x - slider.position.x) / maxf(slider.size.x, 1.0), 0.0, 1.0)
	var new_intensity := int(round(amount * 255.0))
	var connection: Dictionary = connections[selected_connection]
	if _connection_intensity(connection) != new_intensity:
		_set_connection_intensity(selected_connection, new_intensity, false)
		intensity_drag_changed = true


func _finish_intensity_drag() -> void:
	if intensity_drag_changed:
		_record_undo_snapshot(intensity_drag_start_snapshot)


func _begin_intensity_text_edit() -> void:
	if not _has_selected_connection():
		return
	editing_intensity_text = true
	intensity_text = str(_connection_intensity(connections[selected_connection]))
	intensity_text_replace_on_next_digit = true
	grab_focus()


func _handle_intensity_text_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_commit_intensity_text()
	elif event.keycode == KEY_ESCAPE:
		_cancel_intensity_text_edit()
	elif event.keycode == KEY_BACKSPACE:
		if intensity_text_replace_on_next_digit:
			intensity_text = ""
			intensity_text_replace_on_next_digit = false
		elif not intensity_text.is_empty():
			intensity_text = intensity_text.left(intensity_text.length() - 1)
	elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
		if intensity_text_replace_on_next_digit:
			intensity_text = ""
			intensity_text_replace_on_next_digit = false
		if intensity_text.length() < 3:
			intensity_text += str(event.keycode - KEY_0)
	queue_redraw()


func _commit_intensity_text() -> void:
	if _has_selected_connection() and not intensity_text.is_empty():
		_set_connection_intensity(selected_connection, clampi(int(intensity_text), 0, 255))
	_cancel_intensity_text_edit()
	queue_redraw()


func _cancel_intensity_text_edit() -> void:
	editing_intensity_text = false
	intensity_text = ""
	intensity_text_replace_on_next_digit = false


func _deselect_connection() -> void:
	selected_connection = -1
	selected_connections.clear()
	_cancel_intensity_text_edit()


func _select_connection(index: int, additive := false) -> void:
	if index < 0 or index >= connections.size():
		return
	if additive:
		if selected_connections.has(index):
			selected_connections.erase(index)
		else:
			selected_connections.append(index)
	else:
		selected_connections.clear()
		selected_connections.append(index)
	_update_primary_selection()


func _is_connection_selected(index: int) -> bool:
	return selected_connections.has(index)


func _update_primary_selection() -> void:
	selected_connection = selected_connections[0] if selected_connections.size() == 1 else -1
	_cancel_intensity_text_edit()


func _begin_rectangle_selection(additive: bool) -> void:
	if not additive:
		_deselect_connection()
	drag_mode = "selection_pending"
	selection_rect_start = pointer_screen
	selection_rect = Rect2(pointer_screen, Vector2.ZERO)
	selection_rect_additive = additive


func _selection_rect_from_points(start: Vector2, end: Vector2) -> Rect2:
	var position := Vector2(minf(start.x, end.x), minf(start.y, end.y))
	var rect_size := Vector2(absf(end.x - start.x), absf(end.y - start.y))
	return Rect2(position, rect_size)


func _select_connections_in_rect(rect: Rect2, additive: bool) -> void:
	if not additive:
		selected_connections.clear()
	for index in range(connections.size()):
		if _connection_intersects_selection_rect(index, rect) and not selected_connections.has(index):
			selected_connections.append(index)
	_update_primary_selection()


func _connection_intersects_selection_rect(index: int, rect: Rect2) -> bool:
	var connection: Dictionary = connections[index]
	var from_screen := _world_to_screen(connection["from"])
	var to_screen := _world_to_screen(connection["to"])
	var expanded_rect := rect.grow(2.0)
	var sample_count := maxi(2, int(ceil(from_screen.distance_to(to_screen) / 4.0)))
	for sample_index in range(sample_count + 1):
		var progress := float(sample_index) / float(sample_count)
		if expanded_rect.has_point(from_screen.lerp(to_screen, progress)):
			return true
	return false


func _delete_selected_connections() -> void:
	if selected_connections.is_empty():
		return
	if diagram.remove_connections(selected_connections):
		_deselect_connection()
		_clear_diagram_animations()
		queue_redraw()


func _world_to_screen(world_position: Vector2) -> Vector2:
	return pan + world_position * zoom


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - pan) / zoom


func _grid_point_at(screen_position: Vector2) -> Dictionary:
	if not _is_canvas_position(screen_position):
		return {}
	var world_position := _screen_to_world(screen_position)
	var snapped := Vector2(
		round(world_position.x / GRID_SPACING) * GRID_SPACING,
		round(world_position.y / GRID_SPACING) * GRID_SPACING
	)
	if screen_position.distance_to(_world_to_screen(snapped)) <= DOT_HIT_RADIUS:
		return {"point": snapped}
	return {}


func _update_hover() -> void:
	var candidate := _grid_point_at(pointer_screen)
	hover_point_valid = candidate.has("point")
	if hover_point_valid:
		hover_world = candidate["point"]
	var is_rectangle_selecting := drag_mode == "selection" or drag_mode == "selection_pending"
	if _is_canvas_position(pointer_screen) and drag_mode != "connect" and not is_rectangle_selecting:
		hovered_symbol = _symbol_at(pointer_screen)
	else:
		hovered_symbol = -1
	# Durante a criação, a linha embaixo do cursor não deve competir com o
	# feedback magnético da âncora.
	if drag_mode == "connect" or is_rectangle_selecting or not _is_canvas_position(pointer_screen) or hovered_symbol >= 0:
		hovered_connection = -1
	else:
		hovered_connection = _connection_near(pointer_screen)
	hovered_palette_index = _palette_index_at(pointer_screen)
	_sync_hover_animation()


func _sync_hover_animation() -> void:
	if animated_hover_point_valid != hover_point_valid or (hover_point_valid and not animated_hover_world.is_equal_approx(hover_world)):
		animated_hover_point_valid = hover_point_valid
		animated_hover_world = hover_world
		point_hover_started_at = animation_clock
	if animated_hover_connection != hovered_connection:
		animated_hover_connection = hovered_connection
		connection_hover_started_at = animation_clock
	if animated_hover_symbol != hovered_symbol:
		animated_hover_symbol = hovered_symbol
		symbol_hover_started_at = animation_clock
	if animated_hover_palette_index != hovered_palette_index:
		animated_hover_palette_index = hovered_palette_index
		palette_hover_started_at = animation_clock


func _hover_alpha(started_at: float) -> float:
	var elapsed := animation_clock - started_at - HOVER_DELAY
	return clampf(elapsed / HOVER_FADE_DURATION, 0.0, 1.0)


func _symbol_hover_alpha() -> float:
	var elapsed := animation_clock - symbol_hover_started_at - SYMBOL_HOVER_DELAY
	return clampf(elapsed / SYMBOL_HOVER_FADE_DURATION, 0.0, 1.0)


func _hover_transition_active() -> bool:
	if animated_hover_point_valid and _hover_alpha(point_hover_started_at) < 1.0:
		return true
	if animated_hover_connection >= 0 and _hover_alpha(connection_hover_started_at) < 1.0:
		return true
	if animated_hover_symbol >= 0 and _symbol_hover_alpha() < 1.0:
		return true
	if animated_hover_palette_index >= 0 and _hover_alpha(palette_hover_started_at) < 1.0:
		return true
	return false


func _palette_rect(index: int) -> Rect2:
	var columns := _palette_columns()
	var column := index % columns
	var row := int(index / columns)
	return Rect2(_left_panel_width() + 20.0 + column * 70.0, 62.0 + row * 70.0, 58.0, 58.0)


func _palette_columns() -> int:
	var available_width := maxf(size.x - _left_panel_width() - 64.0, 70.0)
	return maxi(1, int(floor(available_width / 70.0)))


func _palette_index_at(screen_position: Vector2) -> int:
	if not top_panel_open:
		return -1
	for index in range(PALETTE_SYMBOLS.size()):
		if _palette_rect(index).has_point(screen_position):
			return index
	return -1


func _palette_symbol_at(screen_position: Vector2) -> String:
	var index := _palette_index_at(screen_position)
	if index >= 0:
		return str(PALETTE_SYMBOLS[index]["kind"])
	return ""


func _symbol_data(kind: String) -> Dictionary:
	return RuneCatalog.symbol_data(kind)


func _symbol_at(screen_position: Vector2) -> int:
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		if str(connection.get("symbol", "")).is_empty():
			continue
		if screen_position.distance_to(_symbol_position(connection, index)) <= maxf(12.0, 24.0 * zoom):
			return index
	return -1


func _connection_near(screen_position: Vector2) -> int:
	var closest_index := -1
	var closest_distance := INF
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var a := _world_to_screen(from_point)
		var b := _world_to_screen(to_point)
		var ab := b - a
		var denominator := maxf(ab.length_squared(), 0.001)
		var t := clampf((screen_position - a).dot(ab) / denominator, 0.0, 1.0)
		var nearest := a + ab * t
		var distance := screen_position.distance_to(nearest)
		if distance < LINE_HIT_RADIUS and distance < closest_distance:
			closest_distance = distance
			closest_index = index
	return closest_index


func _place_active_symbol() -> void:
	var target := _connection_near(pointer_screen)
	if target >= 0:
		_select_connection(target)
		if dragged_symbol_source >= 0:
			if target == dragged_symbol_source:
				_set_connection_symbol(target, active_symbol, false)
			else:
				_record_undo_snapshot(symbol_drag_start_snapshot)
				_set_connection_symbol(target, active_symbol, false)
		else:
			_set_connection_symbol(target, active_symbol)
		_start_symbol_settle(target)
	elif dragged_symbol_source >= 0:
		_set_connection_symbol(dragged_symbol_source, active_symbol, false)


func _start_symbol_settle(target: int) -> void:
	if target < 0 or target >= connections.size():
		return
	var connection: Dictionary = connections[target]
	symbol_settle_active = true
	symbol_settle_kind = str(connection.get("symbol", ""))
	symbol_settle_from = pointer_screen
	symbol_settle_to = _symbol_position(connection, target)
	symbol_settle_started_at = animation_clock
	symbol_settle_connection = target
	symbol_settle_intensity = _connection_intensity(connection)


func _set_connection_symbol(index: int, symbol: String, record_history := true) -> void:
	diagram.set_symbol(index, symbol, record_history)


func _set_connection_intensity(index: int, intensity: int, record_history := true) -> void:
	diagram.set_intensity(index, intensity, record_history)


func _add_connection(from: Vector2, to: Vector2) -> void:
	diagram.add_connection(from, to)


func _begin_pan() -> void:
	drag_mode = "pan"
	pan_drag_start = pointer_screen
	pan_at_drag_start = pan


func _zoom_at_pointer(multiplier: float) -> void:
	var world_before_zoom := _screen_to_world(pointer_screen)
	zoom = clampf(zoom * multiplier, 0.55, 2.5)
	pan = pointer_screen - world_before_zoom * zoom
	queue_redraw()


func _cancel_drag() -> void:
	if drag_mode == "symbol" and dragged_symbol_source >= 0:
		_set_connection_symbol(dragged_symbol_source, active_symbol, false)
	elif drag_mode == "intensity" and not intensity_drag_start_snapshot.is_empty():
		_restore_connections(intensity_drag_start_snapshot)
	_reset_drag()


func _reset_drag() -> void:
	drag_mode = ""
	active_symbol = ""
	dragged_symbol_source = -1
	symbol_drag_start_snapshot = []
	symbol_press_screen = Vector2.ZERO
	anchor_snap_active = false
	selection_rect = Rect2()
	selection_rect_additive = false
	left_scroll_pressed_connection = -1
	left_scroll_additive = false
	intensity_drag_start_snapshot = []
	intensity_drag_changed = false


func _connections_snapshot() -> Array:
	return diagram.snapshot()


func _record_current_state() -> void:
	diagram.record_current_state()


func _record_undo_snapshot(snapshot: Array) -> void:
	diagram.record_undo_snapshot(snapshot)


func _restore_connections(snapshot: Array) -> void:
	diagram.restore(snapshot)


func _clear_diagram_animations() -> void:
	anchor_snap_active = false
	symbol_settle_active = false
	symbol_settle_kind = ""
	symbol_settle_connection = -1


func _undo() -> void:
	if not diagram.undo():
		return
	_clear_diagram_animations()
	_deselect_connection()
	_reset_drag()
	queue_redraw()


func _redo() -> void:
	if not diagram.redo():
		return
	_clear_diagram_animations()
	_deselect_connection()
	_reset_drag()
	queue_redraw()
