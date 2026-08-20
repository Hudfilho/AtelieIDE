extends Control

## Protótipo visual da Atelier IDE.
## - Arraste com o botão do meio para navegar pela grade.
## - Arraste de um ponto até outro para criar uma ligação.
## - Arraste um selo da paleta para uma ligação já criada.
## - Arraste uma área vazia para selecionar várias ligações.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneDiagram = preload("res://scripts/core/rune_diagram.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")

const PANEL_TAB_SIZE := 42.0
const DEFAULT_LEFT_PANEL_WIDTH := 304.0
const DEFAULT_RIGHT_PANEL_WIDTH := 236.0
const DEFAULT_TOP_PANEL_HEIGHT := 196.0
const DEFAULT_BOTTOM_PANEL_HEIGHT := 224.0
const MIN_LEFT_PANEL_WIDTH := 190.0
const MIN_RIGHT_PANEL_WIDTH := 170.0
const MIN_TOP_PANEL_HEIGHT := 112.0
const MIN_BOTTOM_PANEL_HEIGHT := 120.0
const LEFT_COMMAND_ROW_HEIGHT := 66.0
const LEFT_COMMAND_LIST_TOP := 82.0
const LEFT_COMMAND_SCROLL_STEP := 28.0
const LEFT_SCROLL_DRAG_THRESHOLD := 4.0
const LEFT_SCROLL_SMOOTHNESS := 30.0
const PALETTE_TOP_Y := 38.0
const PALETTE_MAX_TILE_SIZE := 58.0
const PALETTE_MIN_TILE_SIZE := 34.0
const PALETTE_TILE_GAP := 8.0
const PALETTE_BOTTOM_PADDING := 16.0
const PALETTE_COMPACT_COLUMNS := 4
const PALETTE_SCROLL_STEP := 120.0
const PALETTE_SCROLL_SMOOTHNESS := 30.0
const DEFAULT_RUNE_INTENSITY := 128
const GRID_SPACING := 48.0
const DOT_RADIUS := 3.4
const DOT_HIT_RADIUS := 14.0
const GRID_DOT_MIN_SCREEN_SPACING := 30.0
const MAX_VISIBLE_GRID_DOTS := 1400
const GRID_TEXTURE_TILE_SIZE := 64
const CIRCLE_TEXTURE_SIZE := 64
const LINE_HIT_RADIUS := 30.0
const CONNECTION_DRAW_MARGIN := 38.0
const CONNECTION_HIT_BUCKET_SIZE := 144.0
const SYMBOL_DRAG_THRESHOLD := 8.0
const ANCHOR_MOVE_DRAG_THRESHOLD := 6.0
const RECT_SELECT_DRAG_THRESHOLD := 6.0
const SELECTION_MOVE_DRAG_THRESHOLD := 6.0
const ANCHOR_SNAP_DURATION := 0.13
const SYMBOL_SETTLE_DURATION := 0.20
const HOVER_DELAY := 0.07
const HOVER_FADE_DURATION := 0.14
const SYMBOL_HOVER_DELAY := 0.12
const SYMBOL_HOVER_FADE_DURATION := 0.20
const EXECUTION_MIN_RPS := 0.1
const EXECUTION_MAX_RPS := 100.0
const EXECUTION_HIGHLIGHT_FADE_DURATION := 0.22
const CLIPBOARD_RITUAL_PREFIX := "ATELIER_IDE_CELLS_V1"

const BACKGROUND := Color("17100b")
const CANVAS_BACKGROUND := Color("0f1420")
const PANEL_BACKGROUND := Color("241a12")
const PANEL_INNER := Color("2c2116")
const PANEL_BORDER := Color("8a6d3b")
const PANEL_ACCENT := Color("b48a3c")
const GOLD_BRIGHT := Color("d9b45c")
const GOLD_GLOW := Color("e6c56a")
const LEATHER_LIGHT := Color("3a2f1c")
const PARCHMENT := Color("d9c9a4")
const PARCHMENT_DEEP := Color("c7b487")
const PARCHMENT_BORDER := Color("7a6540")
const PARCHMENT_INK := Color("2a2013")
const PARCHMENT_MUTED := Color("6a5533")
const GRID_DOT := Color(0.59, 0.67, 0.82, 0.18)
const GRID_DOT_HOVER := Color(0.78, 0.70, 0.43, 0.58)
const RUNE_LINE_COLOR := Color("d9b45c")
const CELL_BORDER := Color("b48a3c")
const TEXT_PRIMARY := Color("c9b590")
const TEXT_MUTED := Color("8a7c5f")

const PALETTE_SYMBOLS = RuneCatalog.SYMBOLS

var pan := Vector2(340.0, 230.0)
var zoom := 1.0
var diagram: AtelierRuneDiagram = RuneDiagram.new()
var compiler: AtelierRuneCompiler = RuneCompiler.new()
var vm: AtelierRuneVM = RuneVM.new()
var execution_output: String = ""
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
var right_panel_open := false
var top_panel_open := false
var bottom_panel_open := false
var left_panel_size := DEFAULT_LEFT_PANEL_WIDTH
var right_panel_size := DEFAULT_RIGHT_PANEL_WIDTH
var top_panel_size := DEFAULT_TOP_PANEL_HEIGHT
var bottom_panel_size := DEFAULT_BOTTOM_PANEL_HEIGHT
var left_command_scroll := 0.0
var left_command_scroll_target := 0.0
var palette_scroll := 0.0
var palette_scroll_target := 0.0
var selected_connection := -1
var selected_connections: Array[int] = []
var selected_symbol_connection := -1
var ritual_running := false
var execution_speed_rps := EXECUTION_MIN_RPS
var execution_instructions: Array[Dictionary] = []
var execution_state: Dictionary = {}
var execution_instruction_cursor := 0
var execution_step_elapsed := 0.0
var execution_connection := -1
var execution_highlight_ends_at := 0.0
var execution_intensity_overrides: Dictionary = {}

var drag_mode := ""
var line_start_world := Vector2.ZERO
var pan_drag_start := Vector2.ZERO
var pan_at_drag_start := Vector2.ZERO
var selection_rect_start := Vector2.ZERO
var selection_rect := Rect2()
var selection_rect_additive := false
var selection_move_press_screen := Vector2.ZERO
var selection_move_origin_world := Vector2.ZERO
var selection_move_offset := Vector2.ZERO
var left_scroll_drag_start_mouse := Vector2.ZERO
var left_scroll_drag_start_offset := 0.0
var left_scroll_pressed_connection := -1
var left_scroll_additive := false
var palette_scroll_drag_start_mouse := Vector2.ZERO
var palette_scroll_drag_start_offset := 0.0
var active_symbol := ""
var dragged_symbol_source := -1
var dragged_symbol_intensity := DEFAULT_RUNE_INTENSITY
var symbol_drag_start_snapshot: Array = []
var symbol_press_screen := Vector2.ZERO
var animation_clock := 0.0
var anchor_snap_active := false
var anchor_snap_from := Vector2.ZERO
var anchor_snap_target := Vector2.ZERO
var anchor_snap_started_at := 0.0
var anchor_move_source := Vector2.ZERO
var anchor_move_target := Vector2.ZERO
var anchor_move_snap_target := Vector2.ZERO
var anchor_move_snap_target_valid := false
var anchor_move_is_terminal := false
var anchor_move_snap_started_at := 0.0
var anchor_move_press_screen := Vector2.ZERO
var anchor_move_settle_active := false
var anchor_move_settle_from := Vector2.ZERO
var anchor_move_settle_to := Vector2.ZERO
var anchor_move_settle_started_at := 0.0
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
var performance_overlay_visible := false
var performance_draw_ms := 0.0
var performance_grid_ms := 0.0
var performance_connections_ms := 0.0
var performance_panels_ms := 0.0
var performance_visible_connections := 0
var performance_grid_dots := 0
var grid_dot_textures := {}
var filled_circle_texture: Texture2D
var ring_textures := {}
var symbol_connection_indices_cache: Array[int] = []
var symbol_connection_indices_dirty := true
var sequence_side_multiplier_cache: Array[float] = []
var sequence_side_multiplier_dirty := true
var connection_hit_buckets := {}
var connection_hit_buckets_dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	filled_circle_texture = _create_filled_circle_texture()
	grab_focus()
	queue_redraw()


func _process(delta: float) -> void:
	if not performance_overlay_visible and not anchor_snap_active and drag_mode != "move_anchor" and not anchor_move_settle_active and not symbol_settle_active and not _hover_transition_active() and not _left_scroll_is_moving() and not _palette_scroll_is_moving() and not ritual_running and not _execution_highlight_active():
		return
	animation_clock += delta
	_update_left_command_scroll(delta)
	_update_palette_scroll(delta)
	if anchor_snap_active and animation_clock - anchor_snap_started_at >= ANCHOR_SNAP_DURATION:
		_complete_anchor_snap()
	if drag_mode == "move_anchor" and anchor_move_is_terminal and anchor_move_snap_target_valid and animation_clock - anchor_move_snap_started_at >= ANCHOR_SNAP_DURATION:
		_continue_terminal_anchor_move()
	if anchor_move_settle_active and animation_clock - anchor_move_settle_started_at >= ANCHOR_SNAP_DURATION:
		_complete_anchor_move_settle()
	if ritual_running:
		_advance_ritual(delta)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		performance_overlay_visible = not performance_overlay_visible
		queue_redraw()
		get_viewport().set_input_as_handled()
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
	if event.keycode == KEY_C:
		_copy_selected_connections_to_clipboard()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_V:
		_paste_connections_from_clipboard()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Z:
		_undo()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Y:
		_redo()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_screen = event.position
		var hover_changed := _update_hover()
		if drag_mode == "pan":
			pan = pan_at_drag_start + (pointer_screen - pan_drag_start)
		elif drag_mode == "connect":
			if not anchor_snap_active:
				var candidate := _grid_point_at(pointer_screen)
				if candidate.has("point"):
					var target: Vector2 = candidate["point"]
					if not target.is_equal_approx(line_start_world):
						_begin_anchor_snap(target)
		elif drag_mode == "move_anchor":
			_update_anchor_move_target()
		elif drag_mode == "selection_pending":
			if pointer_screen.distance_to(selection_rect_start) >= RECT_SELECT_DRAG_THRESHOLD:
				drag_mode = "selection"
				selection_rect = _selection_rect_from_points(selection_rect_start, pointer_screen)
		elif drag_mode == "selection":
			selection_rect = _selection_rect_from_points(selection_rect_start, pointer_screen)
		elif drag_mode == "selection_move_pending":
			if pointer_screen.distance_to(selection_move_press_screen) >= SELECTION_MOVE_DRAG_THRESHOLD:
				drag_mode = "selection_move"
				_update_selection_move()
		elif drag_mode == "selection_move":
			_update_selection_move()
		elif drag_mode == "left_scroll_pending":
			if pointer_screen.distance_to(left_scroll_drag_start_mouse) >= LEFT_SCROLL_DRAG_THRESHOLD:
				drag_mode = "left_scroll"
				_update_left_scroll_drag()
		elif drag_mode == "left_scroll":
			_update_left_scroll_drag()
		elif drag_mode == "palette_scroll":
			_update_palette_scroll_drag()
		elif drag_mode == "symbol_pending":
			# Um clique simples só seleciona o selo. O arraste começa depois de
			# uma pequena distância, para o selo não sumir ao ser configurado.
			if pointer_screen.distance_to(symbol_press_screen) >= SYMBOL_DRAG_THRESHOLD:
				drag_mode = "symbol"
				symbol_drag_start_snapshot = _connections_snapshot()
				_set_connection_symbol(dragged_symbol_source, "", false)
				_set_connection_intensity(dragged_symbol_source, DEFAULT_RUNE_INTENSITY, false)
		elif drag_mode == "intensity":
			_update_selected_intensity(pointer_screen)
		elif drag_mode == "execution_speed":
			_update_execution_speed(pointer_screen)
		elif drag_mode.begins_with("resize_"):
			_resize_panel(pointer_screen)
		var redraw_for_drag := drag_mode == "pan" or drag_mode == "connect" or drag_mode == "move_anchor" or drag_mode == "selection" or drag_mode == "selection_move" or drag_mode == "left_scroll" or drag_mode == "palette_scroll" or drag_mode == "symbol" or drag_mode == "intensity" or drag_mode == "execution_speed" or drag_mode.begins_with("resize_")
		if hover_changed or redraw_for_drag:
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
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _palette_viewport_rect().has_point(pointer_screen):
		_scroll_palette(-1)
		accept_event()
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _palette_viewport_rect().has_point(pointer_screen):
		_scroll_palette(1)
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
			if not ritual_running:
				_run_ritual()
			queue_redraw()
			accept_event()
			return
		if _stop_button_rect().has_point(pointer_screen):
			if ritual_running:
				_stop_ritual()
			queue_redraw()
			accept_event()
			return
		if _execution_speed_slider_rect().grow(6.0).has_point(pointer_screen):
			drag_mode = "execution_speed"
			_update_execution_speed(pointer_screen)
			queue_redraw()
			accept_event()
			return
		var resize_handle := _resize_handle_at(pointer_screen)
		if not resize_handle.is_empty():
			_begin_resize(resize_handle)
			accept_event()
			return
		if ritual_running:
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
		if _palette_scrollbar_rect().grow(2.0).has_point(pointer_screen):
			_begin_palette_scroll_gesture()
			queue_redraw()
			accept_event()
			return
		var palette_symbol := _palette_symbol_at(pointer_screen)
		if not palette_symbol.is_empty():
			drag_mode = "symbol"
			active_symbol = palette_symbol
			dragged_symbol_source = -1
			dragged_symbol_intensity = DEFAULT_RUNE_INTENSITY
		elif _is_canvas_position(pointer_screen):
			var current_symbol := _symbol_at(pointer_screen)
			if current_symbol >= 0:
				if selected_connections.size() > 1 and _is_connection_selected(current_symbol) and not event.ctrl_pressed:
					_begin_selection_move()
				else:
					_select_connection(current_symbol, event.ctrl_pressed, true)
					if not event.ctrl_pressed and _is_connection_selected(current_symbol):
						drag_mode = "symbol_pending"
						dragged_symbol_source = current_symbol
						active_symbol = str(connections[current_symbol].get("symbol", ""))
						dragged_symbol_intensity = _connection_intensity(connections[current_symbol])
						symbol_press_screen = pointer_screen
			else:
				var start_candidate := _grid_point_at(pointer_screen)
				if start_candidate.has("point"):
					var start_point: Vector2 = start_candidate["point"]
					if selected_connections.size() > 1 and _selected_connection_uses_anchor(start_point) and not event.ctrl_pressed:
						_begin_selection_move()
					elif _connection_point_uses(start_point) > 0:
						_begin_anchor_move(start_point)
					else:
						_deselect_connection()
						drag_mode = "connect"
						line_start_world = start_point
						hovered_connection = -1
				else:
					var line_connection := _connection_near(pointer_screen)
					if line_connection >= 0:
						if _is_connection_selected(line_connection) and not event.ctrl_pressed:
							_begin_selection_move()
						else:
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
		elif drag_mode == "move_anchor":
			_complete_anchor_move()
		elif drag_mode == "symbol":
			_place_active_symbol()
		elif drag_mode == "intensity":
			_finish_intensity_drag()
		elif drag_mode == "selection":
			_select_connections_in_rect(selection_rect, selection_rect_additive)
		elif drag_mode == "selection_move":
			_complete_selection_move()
		elif drag_mode == "selection_pending" and not selection_rect_additive:
			_deselect_connection()
		elif drag_mode == "left_scroll_pending" and left_scroll_pressed_connection >= 0:
			_select_connection(left_scroll_pressed_connection, left_scroll_additive, true)
		if not anchor_move_settle_active:
			_reset_drag()

	queue_redraw()
	accept_event()


func _run_ritual() -> void:
	if ritual_running:
		_stop_ritual()
		return
	execution_output = ""
	execution_errors.clear()
	execution_warnings.clear()
	execution_instructions.clear()
	execution_state = {}
	execution_instruction_cursor = 0
	execution_step_elapsed = 0.0
	execution_connection = -1
	execution_intensity_overrides.clear()
	var compilation := compiler.compile(connections)
	for warning in compilation.get("warnings", []):
		execution_warnings.append(str(warning))
	if not compilation["ok"]:
		for error in compilation.get("errors", []):
			execution_errors.append(str(error))
		bottom_panel_open = true
		return

	last_bytecode = compilation["bytecode"]
	var decoded: Dictionary = RuneBytecode.decode(last_bytecode)
	if not bool(decoded["ok"]):
		for error in decoded["errors"]:
			execution_errors.append(str(error))
		bottom_panel_open = true
		return
	var bytecode_instructions: Array = decoded["instructions"]
	var compiled_instructions: Array = compilation["instructions"]
	for instruction_index in range(bytecode_instructions.size()):
		var bytecode_instruction: Dictionary = bytecode_instructions[instruction_index]
		var source_instruction: Dictionary = compiled_instructions[instruction_index]
		var animated_instruction: Dictionary = bytecode_instruction.duplicate(true)
		if source_instruction.has("connection_index"):
			var connection_index := int(source_instruction["connection_index"])
			var instruction_intensity := clampi(int(source_instruction.get("intensity", animated_instruction.get("intensity", 128))), 0, 255)
			animated_instruction["connection_index"] = connection_index
			animated_instruction["intensity"] = instruction_intensity
		execution_instructions.append(animated_instruction)
	_refresh_execution_intensity_overrides()
	execution_state = vm.create_state()
	vm.configure_program(execution_state, execution_instructions)
	if bool(execution_state["halted"]):
		for error in execution_state["errors"]:
			execution_errors.append(str(error))
		bottom_panel_open = true
		return
	bottom_panel_open = true
	right_panel_open = true
	ritual_running = true
	_execute_next_ritual_step()


func _advance_ritual(delta: float) -> void:
	execution_step_elapsed += delta
	var step_duration := _execution_step_duration()
	while ritual_running and execution_step_elapsed >= step_duration:
		execution_step_elapsed -= step_duration
		_execute_next_ritual_step()
		step_duration = _execution_step_duration()


func _execute_next_ritual_step() -> void:
	if execution_instruction_cursor >= execution_instructions.size():
		ritual_running = false
		return
	var instruction_index := execution_instruction_cursor
	var instruction: Dictionary = execution_instructions[instruction_index]
	execution_instruction_cursor += 1
	execution_connection = int(instruction.get("connection_index", -1))
	execution_highlight_ends_at = animation_clock + _execution_step_duration()
	var output: Array = execution_state["output"]
	var errors: Array = execution_state["errors"]
	var output_count := output.size()
	var error_count := errors.size()
	vm.step(instruction, execution_state, instruction_index)
	_refresh_execution_intensity_overrides()
	for output_index in range(output_count, output.size()):
		execution_output += str(output[output_index])
	for error_index in range(error_count, errors.size()):
		execution_errors.append(str(errors[error_index]))
	var jump_target := int(execution_state["jump_target"])
	if jump_target >= 0:
		execution_instruction_cursor = jump_target
	if not errors.is_empty() or bool(execution_state["halted"]):
		ritual_running = false
		execution_highlight_ends_at = animation_clock + _execution_step_duration()


func _stop_ritual() -> void:
	ritual_running = false
	execution_instructions.clear()
	execution_connection = -1
	execution_highlight_ends_at = animation_clock
	execution_warnings.append("Execução interrompida.")


func _execution_step_duration() -> float:
	return 1.0 / maxf(execution_speed_rps, EXECUTION_MIN_RPS)


func _execution_highlight_active() -> bool:
	return execution_connection >= 0 and animation_clock < execution_highlight_ends_at


func _execution_highlight_alpha() -> float:
	if execution_connection < 0:
		return 0.0
	if ritual_running:
		return 1.0
	var fade_duration := minf(EXECUTION_HIGHLIGHT_FADE_DURATION, _execution_step_duration())
	return clampf((execution_highlight_ends_at - animation_clock) / maxf(fade_duration, 0.001), 0.0, 1.0)


func _refresh_execution_intensity_overrides() -> void:
	execution_intensity_overrides.clear()
	for raw_instruction in execution_instructions:
		var instruction: Dictionary = raw_instruction
		if not instruction.has("connection_index"):
			continue
		var connection_index := int(instruction["connection_index"])
		execution_intensity_overrides[connection_index] = clampi(int(instruction.get("intensity", instruction.get("operand", 128))), 0, 255)


func export_current_ritual(path: String) -> Dictionary:
	var result := compiler.export_binary(connections, path)
	if result["ok"]:
		last_bytecode = result["bytecode"]
	return result


func _draw() -> void:
	var draw_started_us: int = Time.get_ticks_usec()
	performance_visible_connections = 0
	performance_grid_dots = 0
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND, true)
	var canvas_rect := _canvas_rect()
	draw_rect(canvas_rect, CANVAS_BACKGROUND, true)
	_draw_canvas_frame(canvas_rect)
	var point_counts := _anchor_point_counts()
	var stage_started_us: int = Time.get_ticks_usec()
	_draw_grid(canvas_rect, point_counts)
	performance_grid_ms = float(Time.get_ticks_usec() - stage_started_us) / 1000.0
	stage_started_us = Time.get_ticks_usec()
	_draw_connections(canvas_rect, point_counts)
	_draw_selection_move_preview()
	_draw_connection_preview()
	_draw_selection_rectangle()
	_draw_dragged_symbol()
	_draw_settling_symbol()
	performance_connections_ms = float(Time.get_ticks_usec() - stage_started_us) / 1000.0
	stage_started_us = Time.get_ticks_usec()
	_draw_intensity_inspector()
	_draw_interface_panels()
	performance_panels_ms = float(Time.get_ticks_usec() - stage_started_us) / 1000.0
	if performance_overlay_visible:
		_draw_performance_overlay()
	performance_draw_ms = float(Time.get_ticks_usec() - draw_started_us) / 1000.0


func _draw_room_candlelight() -> void:
	_draw_soft_glow(Vector2(size.x * 0.12, size.y * 0.88), minf(size.x, size.y) * 0.72, Color(1.0, 0.52, 0.16, 0.055))
	_draw_soft_glow(Vector2(size.x * 0.92, size.y * 0.10), minf(size.x, size.y) * 0.62, Color(0.90, 0.72, 0.30, 0.035))


func _draw_soft_glow(center: Vector2, radius: float, color: Color) -> void:
	for ring in range(5, 0, -1):
		var amount := float(ring) / 5.0
		var glow := color
		glow.a *= 1.0 - amount * 0.78
		draw_circle(center, radius * amount, glow)

func _draw_canvas_frame(canvas_rect: Rect2) -> void:
	draw_rect(canvas_rect, PANEL_BORDER, false, 1.0)
	var inner := canvas_rect.grow(-7.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		var inner_color := PANEL_ACCENT
		inner_color.a = 0.35
		draw_rect(inner, inner_color, false, 1.0)


func _draw_grid(canvas_rect: Rect2, point_counts: Dictionary) -> void:
	var top_left_world := _screen_to_world(canvas_rect.position)
	var bottom_right_world := _screen_to_world(canvas_rect.end)
	var first_x := int(floor(top_left_world.x / GRID_SPACING)) - 1
	var last_x := int(ceil(bottom_right_world.x / GRID_SPACING)) + 1
	var first_y := int(floor(top_left_world.y / GRID_SPACING)) - 1
	var last_y := int(ceil(bottom_right_world.y / GRID_SPACING)) + 1
	var grid_step := _grid_draw_step(last_x - first_x + 1, last_y - first_y + 1)
	var density_alpha := 1.0 / float(grid_step)
	var screen_spacing := GRID_SPACING * zoom * float(grid_step)
	var source_scale := float(GRID_TEXTURE_TILE_SIZE) / maxf(screen_spacing, 0.001)
	var source_origin := (canvas_rect.position - pan) * source_scale + Vector2.ONE * (float(GRID_TEXTURE_TILE_SIZE) * 0.5)
	var source_rect := Rect2(source_origin, canvas_rect.size * source_scale)
	var grid_color := GRID_DOT
	grid_color.a *= density_alpha
	draw_texture_rect_region(_grid_dot_texture(grid_step), canvas_rect, source_rect, grid_color)

	# Apaga apenas os pontos internos usados como âncora. Assim a grade inteira
	# custa um único quad, sem reintroduzir os pixels que apareciam sob as junções.
	for raw_point in point_counts:
		if int(point_counts[raw_point]) <= 1:
			continue
		var used_point: Vector2 = raw_point
		var used_screen := _world_to_screen(used_point)
		if canvas_rect.grow(DOT_RADIUS * zoom + 1.0).has_point(used_screen):
			_draw_filled_circle(used_screen, DOT_RADIUS * zoom + 0.9, CANVAS_BACKGROUND)

	# O ponto embaixo do mouse é desenhado à parte para preservar o highlight.
	if animated_hover_point_valid and int(point_counts.get(animated_hover_world, 0)) <= 1:
		var hover_radius := lerpf(DOT_RADIUS * zoom, 5.0 * zoom, _hover_alpha(point_hover_started_at))
		var hover_color := GRID_DOT.lerp(GRID_DOT_HOVER, _hover_alpha(point_hover_started_at))
		_draw_filled_circle(_world_to_screen(animated_hover_world), hover_radius, hover_color)
	if performance_overlay_visible:
		performance_grid_dots = int(ceil(canvas_rect.size.x / maxf(screen_spacing, 1.0))) * int(ceil(canvas_rect.size.y / maxf(screen_spacing, 1.0)))


func _grid_dot_texture(grid_step: int) -> Texture2D:
	if grid_dot_textures.has(grid_step):
		return grid_dot_textures[grid_step]
	var image := Image.create(GRID_TEXTURE_TILE_SIZE, GRID_TEXTURE_TILE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (float(GRID_TEXTURE_TILE_SIZE) * 0.5)
	var pixel_radius := DOT_RADIUS * float(GRID_TEXTURE_TILE_SIZE) / (GRID_SPACING * float(grid_step))
	for pixel_x in range(GRID_TEXTURE_TILE_SIZE):
		for pixel_y in range(GRID_TEXTURE_TILE_SIZE):
			var pixel_center := Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5)
			var alpha := clampf(pixel_radius + 0.75 - pixel_center.distance_to(center), 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(pixel_x, pixel_y, Color(1.0, 1.0, 1.0, alpha))
	var texture := ImageTexture.create_from_image(image)
	grid_dot_textures[grid_step] = texture
	return texture


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
	if ring_textures.has(ratio_key):
		return ring_textures[ratio_key]
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
	ring_textures[ratio_key] = texture
	return texture


func _draw_filled_circle(center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	var diameter := radius * 2.0
	draw_texture_rect(filled_circle_texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter), false, color)


func _draw_ring(center: Vector2, radius: float, color: Color, width: float) -> void:
	if radius <= 0.0 or width <= 0.0:
		return
	var diameter := radius * 2.0
	draw_texture_rect(_ring_texture(width / radius), Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter), false, color)


func _grid_draw_step(columns: int, rows: int) -> int:
	var screen_spacing := GRID_SPACING * zoom
	var spacing_step := maxi(1, int(ceil(GRID_DOT_MIN_SCREEN_SPACING / maxf(screen_spacing, 0.001))))
	var raw_dot_count := maxi(columns * rows, 1)
	var budget_step := maxi(1, int(ceil(sqrt(float(raw_dot_count) / float(MAX_VISIBLE_GRID_DOTS)))))
	return maxi(spacing_step, budget_step)


func _anchor_point_counts() -> Dictionary:
	var counts := {}
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		counts[from_point] = int(counts.get(from_point, 0)) + 1
		counts[to_point] = int(counts.get(to_point, 0)) + 1
	return counts


func _visible_connection_indices(canvas_rect: Rect2) -> Array[int]:
	var indices: Array[int] = []
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		if _is_connection_hidden_during_move(connection, index):
			continue
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var from_screen := _world_to_screen(from_point)
		var to_screen := _world_to_screen(to_point)
		if _segment_intersects_canvas(from_screen, to_screen, canvas_rect):
			indices.append(index)
	return indices


func _visible_connection_points(indices: Array[int]) -> Dictionary:
	var points := {}
	for index in indices:
		var connection: Dictionary = connections[index]
		points[connection["from"]] = true
		points[connection["to"]] = true
	return points


func _segment_intersects_canvas(from_screen: Vector2, to_screen: Vector2, canvas_rect: Rect2) -> bool:
	var min_x := minf(from_screen.x, to_screen.x)
	var max_x := maxf(from_screen.x, to_screen.x)
	var min_y := minf(from_screen.y, to_screen.y)
	var max_y := maxf(from_screen.y, to_screen.y)
	return max_x >= canvas_rect.position.x - CONNECTION_DRAW_MARGIN and min_x <= canvas_rect.end.x + CONNECTION_DRAW_MARGIN and max_y >= canvas_rect.position.y - CONNECTION_DRAW_MARGIN and min_y <= canvas_rect.end.y + CONNECTION_DRAW_MARGIN


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


func _draw_connections(canvas_rect: Rect2, point_counts: Dictionary) -> void:
	# A estrutura inteira usa a mesma tinta-base. Cada ligação ainda existe no
	# diagrama, mas só é revelada como uma célula individual pelo hover.
	var visible_indices := _visible_connection_indices(canvas_rect)
	performance_visible_connections = visible_indices.size()
	var visible_points := _visible_connection_points(visible_indices)
	var line_shadow := RUNE_LINE_COLOR.darkened(0.72)
	var shadow_segments := PackedVector2Array()
	for index in visible_indices:
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		shadow_segments.append(_world_to_screen(from_point))
		shadow_segments.append(_world_to_screen(to_point))
	if not shadow_segments.is_empty():
		draw_multiline(shadow_segments, line_shadow, 4.2 * zoom, true)
	_draw_line_joins_and_caps(visible_points, line_shadow, 2.1 * zoom)

	var main_segments := PackedVector2Array()
	for index in visible_indices:
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		main_segments.append(_world_to_screen(from_point))
		main_segments.append(_world_to_screen(to_point))
	if not main_segments.is_empty():
		draw_multiline(main_segments, RUNE_LINE_COLOR, 2.0 * zoom, true)
	_draw_line_joins_and_caps(visible_points, RUNE_LINE_COLOR, 1.0 * zoom)
	_draw_terminal_markers(visible_indices, point_counts, line_shadow)

	var selection_segments := PackedVector2Array()
	var selection_points := {}
	for index in visible_indices:
		if not _is_connection_selected(index):
			continue
		var selected_connection_data: Dictionary = connections[index]
		var selected_from: Vector2 = selected_connection_data["from"]
		var selected_to: Vector2 = selected_connection_data["to"]
		selection_segments.append(_world_to_screen(selected_from))
		selection_segments.append(_world_to_screen(selected_to))
		selection_points[selected_from] = true
		selection_points[selected_to] = true
	if not selection_segments.is_empty():
		var selection_glow := RUNE_LINE_COLOR.lightened(0.45)
		selection_glow.a = 0.20
		draw_multiline(selection_segments, selection_glow, 3.2 * zoom, true)
		_draw_line_joins_and_caps(selection_points, selection_glow, 1.6 * zoom)

	# A seção sob o cursor recebe apenas uma névoa leve; a linha-base continua
	# uniforme e não vira uma sequência de retângulos.
	for index in visible_indices:
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var from_screen := _world_to_screen(from_point)
		var to_screen := _world_to_screen(to_point)
		var has_symbol := not str(connection.get("symbol", "")).is_empty()
		var intensity := _display_connection_intensity(index, connection)
		var execution_alpha := _execution_highlight_alpha() if index == execution_connection else 0.0
		if execution_alpha > 0.0:
			_draw_execution_connection_glow(from_screen, to_screen, execution_alpha)
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
			if execution_alpha > 0.0:
				_draw_execution_symbol_glow(kind, symbol_position, rune_color, execution_alpha)
				rune_color = rune_color.lerp(Color("fff2b2"), 0.72 * execution_alpha)
			_draw_rune(kind, symbol_position, zoom, rune_color)


func _draw_line_joins_and_caps(points: Dictionary, color: Color, radius: float) -> void:
	# O círculo tem exatamente metade da largura do traço. Nas junções ele cria
	# uma curva contínua; nas extremidades, uma ponta arredondada.
	for raw_point in points:
		var point: Vector2 = raw_point
		_draw_filled_circle(_world_to_screen(point), radius, color)


func _draw_terminal_markers(indices: Array[int], point_counts: Dictionary, line_shadow: Color) -> void:
	# Primeiro e último ponto de cada sequência substituem o pontinho vermelho
	# por uma âncora dourada mais evidente.
	for index in indices:
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		if int(point_counts.get(from_point, 0)) == 1:
			_draw_terminal_marker(_world_to_screen(from_point), line_shadow)
		if int(point_counts.get(to_point, 0)) == 1:
			_draw_terminal_marker(_world_to_screen(to_point), line_shadow)


func _draw_terminal_marker(screen_position: Vector2, line_shadow: Color) -> void:
	_draw_filled_circle(screen_position, 4.4 * zoom, line_shadow)
	_draw_filled_circle(screen_position, 3.0 * zoom, RUNE_LINE_COLOR)


func _draw_performance_overlay() -> void:
	var canvas_rect := _canvas_rect()
	var overlay_width := minf(340.0, maxf(canvas_rect.size.x - 24.0, 120.0))
	var overlay := Rect2(canvas_rect.position + Vector2(12.0, 12.0), Vector2(overlay_width, 110.0))
	draw_rect(overlay, Color(0.03, 0.05, 0.09, 0.90), true)
	draw_rect(overlay, GOLD_GLOW, false, 1.0)
	var fps := Engine.get_frames_per_second()
	draw_string(ThemeDB.fallback_font, overlay.position + Vector2(10.0, 19.0), "DIAGNÓSTICO  •  F3", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, GOLD_GLOW)
	draw_string(ThemeDB.fallback_font, overlay.position + Vector2(10.0, 39.0), "%.0f FPS  |  desenho %.2f ms" % [fps, performance_draw_ms], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_PRIMARY)
	draw_string(ThemeDB.fallback_font, overlay.position + Vector2(10.0, 58.0), "grade %.2f  |  código %.2f  |  abas %.2f ms" % [performance_grid_ms, performance_connections_ms, performance_panels_ms], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	draw_string(ThemeDB.fallback_font, overlay.position + Vector2(10.0, 77.0), "%d células  |  %d visíveis" % [connections.size(), performance_visible_connections], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	draw_string(ThemeDB.fallback_font, overlay.position + Vector2(10.0, 96.0), "%d pontos da grade  |  %d draw calls" % [performance_grid_dots, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)


func _is_connection_hidden_during_move(connection: Dictionary, connection_index := -1) -> bool:
	if drag_mode == "selection_move":
		if connection_index < 0:
			connection_index = connections.find(connection)
		return selected_connections.has(connection_index)
	if drag_mode != "move_anchor" and not anchor_move_settle_active:
		return false
	var from_point: Vector2 = connection["from"]
	var to_point: Vector2 = connection["to"]
	return from_point.is_equal_approx(anchor_move_source) or to_point.is_equal_approx(anchor_move_source)


func _draw_rounded_segment_caps(from_screen: Vector2, to_screen: Vector2, color: Color, radius: float) -> void:
	_draw_filled_circle(from_screen, radius, color)
	_draw_filled_circle(to_screen, radius, color)


func _settle_ease(progress: float) -> float:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	return 1.0 - pow(1.0 - clamped_progress, 3.0)


func _elastic_settle_ease(progress: float) -> float:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var tension := 1.45
	var overshoot := tension + 1.0
	var shifted := clamped_progress - 1.0
	return 1.0 + overshoot * shifted * shifted * shifted + tension * shifted * shifted


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
		normal *= _cached_sequence_side_multiplier(connection_index)
	else:
		normal = _preferred_screen_side(normal)
	return middle + normal * (20.0 * zoom)


func _cached_sequence_side_multiplier(connection_index: int) -> float:
	_ensure_sequence_side_multiplier_cache()
	if connection_index < 0 or connection_index >= sequence_side_multiplier_cache.size():
		return 1.0
	return sequence_side_multiplier_cache[connection_index]


func _ensure_sequence_side_multiplier_cache() -> void:
	if not sequence_side_multiplier_dirty:
		return
	sequence_side_multiplier_cache.clear()
	var previous_indices: Array[int] = []
	var connections_ending_at := {}
	for index in range(connections.size()):
		sequence_side_multiplier_cache.append(1.0)
		previous_indices.append(-1)
		var connection: Dictionary = connections[index]
		var to_point: Vector2 = connection["to"]
		var point_key := _world_point_key(to_point)
		var ending_indices: Array = connections_ending_at.get(point_key, [])
		ending_indices.append(index)
		connections_ending_at[point_key] = ending_indices
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var candidates: Array = connections_ending_at.get(_world_point_key(from_point), [])
		if candidates.size() == 1 and int(candidates[0]) != index:
			previous_indices[index] = int(candidates[0])

	var sequence_starts: Array[int] = []
	for _index in range(connections.size()):
		sequence_starts.append(-1)
	for index in range(connections.size()):
		if sequence_starts[index] >= 0:
			continue
		var path: Array[int] = []
		var path_members := {}
		var current_index := index
		var start_index := -1
		while true:
			if sequence_starts[current_index] >= 0:
				start_index = sequence_starts[current_index]
				break
			if path_members.has(current_index):
				start_index = current_index
				break
			path_members[current_index] = true
			path.append(current_index)
			var previous_index := previous_indices[current_index]
			if previous_index < 0:
				start_index = current_index
				break
			current_index = previous_index
		for path_index in path:
			sequence_starts[path_index] = start_index

	for index in range(connections.size()):
		var start_index := sequence_starts[index]
		if start_index < 0:
			continue
		var start_connection: Dictionary = connections[start_index]
		var start_from: Vector2 = start_connection["from"]
		var start_to: Vector2 = start_connection["to"]
		var initial_direction := start_to - start_from
		if initial_direction.length_squared() < 0.001:
			continue
		var initial_right_side := Vector2(-initial_direction.y, initial_direction.x).normalized()
		var preferred_side := _preferred_screen_side(initial_right_side)
		sequence_side_multiplier_cache[index] = 1.0 if initial_right_side.dot(preferred_side) >= 0.0 else -1.0
	sequence_side_multiplier_dirty = false


func _invalidate_sequence_side_multiplier_cache() -> void:
	sequence_side_multiplier_dirty = true
	connection_hit_buckets_dirty = true


func _world_point_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x), roundi(point.y)]


func _preferred_screen_side(normal: Vector2) -> Vector2:
	# A sequência inicial nasce no lado mais alto; em empate, no lado direito.
	if normal.y > 0.0 or (is_zero_approx(normal.y) and normal.x < 0.0):
		return -normal
	return normal


func _draw_connection_preview() -> void:
	if drag_mode == "connect":
		var start_screen := _world_to_screen(line_start_world)
		draw_line(start_screen, _anchor_snap_endpoint(), GOLD_GLOW, 3.0 * zoom, true)
	elif drag_mode == "move_anchor" or anchor_move_settle_active:
		_draw_anchor_move_preview()


func _draw_selection_move_preview() -> void:
	if drag_mode != "selection_move":
		return
	var preview_color := GOLD_GLOW
	preview_color.a = 0.72
	var preview_glow := GOLD_GLOW
	preview_glow.a = 0.16
	for connection_index in selected_connections:
		if connection_index < 0 or connection_index >= connections.size():
			continue
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var from_screen := _world_to_screen(from_point + selection_move_offset)
		var to_screen := _world_to_screen(to_point + selection_move_offset)
		draw_line(from_screen, to_screen, preview_glow, 8.0 * zoom, true)
		_draw_rounded_segment_caps(from_screen, to_screen, preview_glow, 4.0 * zoom)
		draw_line(from_screen, to_screen, preview_color, 2.0 * zoom, true)
		_draw_rounded_segment_caps(from_screen, to_screen, preview_color, 1.0 * zoom)
		var symbol := str(connection.get("symbol", ""))
		if not symbol.is_empty():
			var symbol_position := _symbol_position(connection, connection_index) + selection_move_offset * zoom
			_draw_rune(symbol, symbol_position, zoom, preview_color)


func _draw_anchor_move_preview() -> void:
	var preview_target := anchor_move_target
	if anchor_move_settle_active:
		var settle_progress := clampf((animation_clock - anchor_move_settle_started_at) / ANCHOR_SNAP_DURATION, 0.0, 1.0)
		preview_target = anchor_move_settle_from.lerp(anchor_move_settle_to, _elastic_settle_ease(settle_progress))
	var preview_color := GOLD_GLOW
	preview_color.a = 0.88 if anchor_move_snap_target_valid else 0.64
	var glow_color := preview_color
	glow_color.a = 0.18 if anchor_move_snap_target_valid else 0.10
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		if not from_point.is_equal_approx(anchor_move_source) and not to_point.is_equal_approx(anchor_move_source):
			continue
		var preview_from := preview_target if from_point.is_equal_approx(anchor_move_source) else from_point
		var preview_to := preview_target if to_point.is_equal_approx(anchor_move_source) else to_point
		var from_screen := _world_to_screen(preview_from)
		var to_screen := _world_to_screen(preview_to)
		var original_middle := (_world_to_screen(from_point) + _world_to_screen(to_point)) * 0.5
		var preview_middle := (from_screen + to_screen) * 0.5
		draw_line(from_screen, to_screen, glow_color, 8.0 * zoom, true)
		_draw_rounded_segment_caps(from_screen, to_screen, glow_color, 4.0 * zoom)
		draw_line(from_screen, to_screen, preview_color, 2.5 * zoom, true)
		_draw_rounded_segment_caps(from_screen, to_screen, preview_color, 1.25 * zoom)
		var symbol := str(connection.get("symbol", ""))
		if not symbol.is_empty():
			var symbol_position := _symbol_position(connection) + (preview_middle - original_middle)
			_draw_rune(symbol, symbol_position, zoom, _intensity_color(_connection_intensity(connection)))
	_draw_filled_circle(_world_to_screen(preview_target), 4.2 * zoom, preview_color)
	if anchor_move_snap_target_valid and not anchor_move_settle_active:
		var snap_color := GOLD_GLOW
		snap_color.a = 0.42
		_draw_ring(_world_to_screen(anchor_move_snap_target), 9.0 * zoom, snap_color, 1.1 * zoom)


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


func _begin_anchor_move(source: Vector2) -> void:
	_deselect_connection()
	drag_mode = "move_anchor"
	anchor_move_source = source
	anchor_move_target = source
	anchor_move_snap_target = source
	anchor_move_snap_target_valid = false
	anchor_move_is_terminal = _is_terminal_point(source)
	anchor_move_snap_started_at = 0.0
	anchor_move_press_screen = pointer_screen
	hovered_connection = -1


func _update_anchor_move_target() -> void:
	var canvas := _canvas_rect()
	var constrained_screen := Vector2(
		clampf(pointer_screen.x, canvas.position.x, canvas.end.x),
		clampf(pointer_screen.y, canvas.position.y, canvas.end.y)
	)
	anchor_move_target = _screen_to_world(constrained_screen)
	var had_snap_target := anchor_move_snap_target
	var had_valid_snap := anchor_move_snap_target_valid
	anchor_move_snap_target_valid = false
	var candidate := _grid_point_at(pointer_screen)
	if not candidate.has("point"):
		return
	var target: Vector2 = candidate["point"]
	if target.is_equal_approx(anchor_move_source):
		return
	anchor_move_snap_target = target
	anchor_move_snap_target_valid = true
	if not had_valid_snap or not target.is_equal_approx(had_snap_target):
		anchor_move_snap_started_at = animation_clock


func _continue_terminal_anchor_move() -> void:
	if not anchor_move_is_terminal or not anchor_move_snap_target_valid:
		return
	var source := anchor_move_source
	var target := anchor_move_snap_target
	if source.is_equal_approx(target) or not diagram.move_anchor(source, target):
		return
	_invalidate_sequence_side_multiplier_cache()
	_clear_diagram_animations()
	anchor_move_source = Vector2.ZERO
	anchor_move_target = Vector2.ZERO
	anchor_move_snap_target = Vector2.ZERO
	anchor_move_snap_target_valid = false
	anchor_move_is_terminal = false
	anchor_move_snap_started_at = 0.0
	anchor_move_press_screen = Vector2.ZERO
	drag_mode = "connect"
	line_start_world = target
	hovered_connection = -1
	_update_hover()


func _complete_anchor_move() -> void:
	var settle_target := anchor_move_snap_target if anchor_move_snap_target_valid else anchor_move_source
	if anchor_move_target.is_equal_approx(settle_target):
		anchor_move_settle_from = settle_target
		anchor_move_settle_to = settle_target
		_complete_anchor_move_settle()
		return
	anchor_move_settle_active = true
	anchor_move_settle_from = anchor_move_target
	anchor_move_settle_to = settle_target
	anchor_move_settle_started_at = animation_clock
	drag_mode = ""


func _complete_anchor_move_settle() -> void:
	var should_move := not anchor_move_source.is_equal_approx(anchor_move_settle_to)
	anchor_move_settle_active = false
	if should_move and diagram.move_anchor(anchor_move_source, anchor_move_settle_to):
		_invalidate_sequence_side_multiplier_cache()
		_clear_diagram_animations()
	anchor_move_source = Vector2.ZERO
	anchor_move_target = Vector2.ZERO
	anchor_move_snap_target = Vector2.ZERO
	anchor_move_snap_target_valid = false
	anchor_move_is_terminal = false
	anchor_move_snap_started_at = 0.0
	anchor_move_press_screen = Vector2.ZERO
	_update_hover()


func _draw_dragged_symbol() -> void:
	if drag_mode == "symbol" and not active_symbol.is_empty():
		_draw_rune(active_symbol, pointer_screen, zoom, GOLD_GLOW)


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


func _draw_execution_connection_glow(from_screen: Vector2, to_screen: Vector2, highlight_alpha: float) -> void:
	var outer_glow := Color("ffe8a8")
	outer_glow.a = 0.17 * highlight_alpha
	draw_line(from_screen, to_screen, outer_glow, 9.0 * zoom, true)
	_draw_rounded_segment_caps(from_screen, to_screen, outer_glow, 4.5 * zoom)
	var inner_glow := Color("fff4cd")
	inner_glow.a = 0.80 * highlight_alpha
	draw_line(from_screen, to_screen, inner_glow, 3.1 * zoom, true)
	_draw_rounded_segment_caps(from_screen, to_screen, inner_glow, 1.55 * zoom)


func _draw_execution_symbol_glow(kind: String, symbol_position: Vector2, rune_color: Color, highlight_alpha: float) -> void:
	var glow_color := rune_color.lerp(Color("fff2b2"), 0.72)
	_draw_rune_aura(kind, symbol_position, glow_color, 6.2 * zoom, 0.048 * highlight_alpha)
	_draw_rune_aura(kind, symbol_position, glow_color, 2.8 * zoom, 0.085 * highlight_alpha)


func _draw_rune_aura(kind: String, center: Vector2, aura_color: Color, spread: float, alpha: float) -> void:
	var color := aura_color
	# Quatro cópias suaves preservam o contorno mágico da runa. O desenho
	# anterior usava oito por camada e multiplicava brutalmente os draw calls.
	color.a = alpha * 1.75
	for index in range(4):
		var angle := TAU * (float(index) + 0.5) / 4.0
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
	draw_rect(value_rect, Color("3a2f1c") if editing_intensity_text else Color("1a140e"), true)
	draw_rect(value_rect, GOLD_GLOW if editing_intensity_text else PANEL_BORDER, false, 1.0)
	var displayed_intensity := intensity_text if editing_intensity_text else "%03d" % intensity
	draw_string(ThemeDB.fallback_font, value_rect.position + Vector2(8.0, 19.0), displayed_intensity, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, GOLD_GLOW if editing_intensity_text else TEXT_PRIMARY)

	var slider := _intensity_slider_rect()
	for segment in range(24):
		var start_t := float(segment) / 24.0
		var end_t := float(segment + 1) / 24.0
		var start := Vector2(slider.position.x + slider.size.x * start_t, slider.get_center().y)
		var end := Vector2(slider.position.x + slider.size.x * end_t, slider.get_center().y)
		draw_line(start, end, _intensity_color(int(start_t * 255.0)), 5.0, true)
	draw_line(Vector2(slider.position.x, slider.get_center().y), Vector2(slider.end.x, slider.get_center().y), PANEL_BORDER, 1.0, true)
	var marker_x := slider.position.x + slider.size.x * (float(intensity) / 255.0)
	_draw_filled_circle(Vector2(marker_x, slider.get_center().y), 7.0, Color("1a140e"))
	_draw_ring(Vector2(marker_x, slider.get_center().y), 7.0, GOLD_GLOW, 1.5)


func _draw_interface_panels() -> void:
	_draw_left_panel()
	_draw_top_panel()
	_draw_bottom_panel()
	_draw_right_panel()
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
	for connection_index in _symbol_connection_indices():
		var connection: Dictionary = connections[connection_index]
		var kind := str(connection["symbol"])
		var data := _symbol_data(kind)
		var row := Rect2(14.0, row_y, panel.size.x - 28.0, 58.0)
		if row.end.y > list_rect.position.y and row.position.y < list_rect.end.y:
			var row_fill := PARCHMENT_DEEP if _is_connection_selected(connection_index) else PARCHMENT
			var row_border := GOLD_BRIGHT if _is_connection_selected(connection_index) else PARCHMENT_BORDER
			draw_rect(row, row_fill, true)
			draw_rect(row, row_border, false, 1.0)
			draw_rect(row.grow(-3.0), Color(0.24, 0.17, 0.08, 0.32), false, 1.0)
			var intensity := _display_connection_intensity(connection_index, connection)
			var sigil_center := row.position + Vector2(28.0, 29.0)
			_draw_filled_circle(sigil_center, 18.0, Color("cdb782"))
			_draw_ring(sigil_center, 18.0, PANEL_BORDER, 1.4)
			_draw_filled_circle(sigil_center + Vector2(-4.0, -5.0), 3.0, Color(1.0, 0.95, 0.78, 0.28))
			_draw_rune(kind, sigil_center, 0.76, PARCHMENT_INK.lerp(PANEL_BORDER, float(intensity) / 255.0))
			draw_string(ThemeDB.fallback_font, row.position + Vector2(56.0, 25.0), str(data["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, PARCHMENT_INK)
			var extra := str(data["extra"])
			# Só mostramos o número quando a intensidade participa da instrução
			# como operando; nos outros selos ele é apenas visual.
			if RuneCatalog.takes_operand(int(data.get("opcode", -1))):
				extra = "%s: %03d" % [extra, intensity]
			draw_string(ThemeDB.fallback_font, row.position + Vector2(56.0, 45.0), extra, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, PARCHMENT_MUTED)
			draw_line(row.position + Vector2(8.0, 49.0), row.position + Vector2(row.size.x - 8.0, 49.0), Color(0.24, 0.17, 0.08, 0.38), 1.0, true)
		row_y += LEFT_COMMAND_ROW_HEIGHT
		if row.position.y > list_rect.end.y:
			break

	_draw_left_scroll_masks(panel, list_rect)
	_draw_left_panel_header(panel)
	_draw_left_command_scrollbar(list_rect, command_scroll)
	_draw_toggle_button(_left_toggle_rect(), "left")

	if command_count == 0:
		_draw_ring(Vector2(panel.size.x * 0.5, 132.0), 30.0, PANEL_BORDER, 1.0)
		draw_line(Vector2(panel.size.x * 0.5 - 48.0, 132.0), Vector2(panel.size.x * 0.5 + 48.0, 132.0), PANEL_BORDER, 1.0, true)
		draw_string(ThemeDB.fallback_font, Vector2(29.0, 192.0), "Ainda não há símbolos no ritual.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)


func _command_row_at(screen_position: Vector2) -> int:
	if not left_panel_open or not _left_command_list_rect().has_point(screen_position):
		return -1
	var list_rect := _left_command_list_rect()
	var row_y := LEFT_COMMAND_LIST_TOP + 6.0 - minf(left_command_scroll, _left_command_max_scroll())
	for connection_index in _symbol_connection_indices():
		var connection: Dictionary = connections[connection_index]
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
		draw_rect(inner, LEATHER_LIGHT, false, 1.0)
	draw_rect(list_rect, LEATHER_LIGHT, false, 1.0)


func _draw_left_panel_header(panel: Rect2) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(20.0, 32.0), "GRIMÓRIO ATIVO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, GOLD_BRIGHT)
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
	draw_line(Vector2(track_x, list_rect.position.y + 6.0), Vector2(track_x, list_rect.end.y - 6.0), Color("1a140e"), 2.0, true)
	draw_line(Vector2(track_x, thumb_y), Vector2(track_x, thumb_y + thumb_height), PANEL_ACCENT, 2.0, true)


func _symbol_connection_count() -> int:
	return _symbol_connection_indices().size()


func _symbol_connection_indices() -> Array[int]:
	if not symbol_connection_indices_dirty:
		return symbol_connection_indices_cache
	symbol_connection_indices_cache.clear()
	for index in range(connections.size()):
		if not str(connections[index].get("symbol", "")).is_empty():
			symbol_connection_indices_cache.append(index)
	symbol_connection_indices_dirty = false
	return symbol_connection_indices_cache


func _invalidate_symbol_connection_indices() -> void:
	symbol_connection_indices_dirty = true


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
	left_command_scroll = left_command_scroll_target


func _left_scroll_is_moving() -> bool:
	return absf(left_command_scroll_target - left_command_scroll) > 0.1


func _update_left_command_scroll(delta: float) -> void:
	var max_scroll := _left_command_max_scroll()
	left_command_scroll_target = clampf(left_command_scroll_target, 0.0, max_scroll)
	left_command_scroll = clampf(left_command_scroll, 0.0, max_scroll)
	var amount := 1.0 - exp(-delta * LEFT_SCROLL_SMOOTHNESS)
	left_command_scroll = lerpf(left_command_scroll, left_command_scroll_target, amount)
	if absf(left_command_scroll_target - left_command_scroll) <= 0.1:
		left_command_scroll = left_command_scroll_target
	queue_redraw()


func _draw_top_panel() -> void:
	var panel := _top_panel_rect()
	_draw_arcane_frame(panel)
	_draw_toggle_button(_top_toggle_rect(), "up" if top_panel_open else "down")
	_draw_execution_speed_control()
	_draw_play_button(_play_button_rect())
	_draw_stop_button(_stop_button_rect())
	if not top_panel_open:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 16.0, 27.0), "SELOS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 24.0), "SELOS E RUNAS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)

	var palette_viewport := _palette_viewport_rect()
	for index in range(PALETTE_SYMBOLS.size()):
		var item: Dictionary = PALETTE_SYMBOLS[index]
		var tile := _palette_rect(index)
		if not _palette_tile_is_visible(tile, palette_viewport):
			continue
		var highlight_alpha := _hover_alpha(palette_hover_started_at) if index == animated_hover_palette_index else 0.0
		_draw_arcane_tile_mark(tile, highlight_alpha)
		var tile_scale := 1.05 * tile.size.x / PALETTE_MAX_TILE_SIZE
		_draw_rune(str(item["kind"]), tile.get_center(), tile_scale, GOLD_BRIGHT.lerp(Color("fff0bd"), highlight_alpha))
	_draw_palette_scroll_masks(palette_viewport)
	_draw_palette_scrollbar()


func _draw_bottom_panel() -> void:
	var panel := _bottom_panel_rect()
	_draw_arcane_frame(panel)
	_draw_toggle_button(_bottom_toggle_rect(), "down" if bottom_panel_open else "up")
	if not bottom_panel_open:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 16.0, panel.position.y + 27.0), "ORÁCULO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 30.0), "EXECUÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, TEXT_PRIMARY)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 51.0), "A saída e os erros do programa aparecerão aqui.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	var divider_x := panel.position.x + panel.size.x * 0.7
	draw_line(Vector2(divider_x, panel.position.y + 68.0), Vector2(divider_x, panel.end.y - 16.0), PANEL_BORDER, 1.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 20.0, panel.position.y + 91.0), "SAÍDA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PANEL_ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(divider_x + 20.0, panel.position.y + 91.0), "ERROS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PANEL_ACCENT)
	var output_position := Vector2(panel.position.x + 24.0, panel.position.y + 116.0)
	var output_width := divider_x - panel.position.x - 42.0
	if not execution_output.is_empty():
		draw_multiline_string(ThemeDB.fallback_font, output_position, "> " + execution_output, HORIZONTAL_ALIGNMENT_LEFT, output_width, 14, -1, Color("e3cea2"))
	var warning_y := panel.position.y + 116.0
	for warning in execution_warnings:
		draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 24.0, warning_y), "~ " + warning, HORIZONTAL_ALIGNMENT_LEFT, divider_x - panel.position.x - 42.0, 12, Color("d8c783"))
		warning_y += 18.0
	var error_y := panel.position.y + 116.0
	for error in execution_errors:
		draw_string(ThemeDB.fallback_font, Vector2(divider_x + 20.0, error_y), "! " + error, HORIZONTAL_ALIGNMENT_LEFT, panel.end.x - divider_x - 40.0, 13, Color("ff8791"))
		error_y += 20.0
	if execution_output.is_empty() and execution_errors.is_empty() and execution_warnings.is_empty():
		_draw_rune("ORB", Vector2(panel.position.x + panel.size.x * 0.35, panel.position.y + 145.0), 1.6, LEATHER_LIGHT)


func _draw_right_panel() -> void:
	var panel := _right_panel_rect()
	_draw_arcane_frame(panel)
	_draw_toggle_button(_right_toggle_rect(), "right" if right_panel_open else "left")
	if not right_panel_open:
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(5.0, 58.0), "PILHA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, TEXT_MUTED)
		return

	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 64.0), "PILHA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, GOLD_BRIGHT)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 85.0), "Estado da máquina", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_MUTED)
	draw_line(panel.position + Vector2(20.0, 101.0), Vector2(panel.end.x - 20.0, panel.position.y + 101.0), PANEL_BORDER, 1.0, true)
	if execution_state.is_empty() or not execution_state.has("stack"):
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 136.0), "A pilha desperta", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 155.0), "quando o ritual começa.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	var stack: Array = execution_state["stack"]
	var text_width := panel.size.x - 40.0
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 124.0), "TOPO", HORIZONTAL_ALIGNMENT_LEFT, text_width, 11, PANEL_ACCENT)
	draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 124.0), "%d SELOS" % stack.size(), HORIZONTAL_ALIGNMENT_RIGHT, text_width, 10, TEXT_MUTED)
	if stack.is_empty():
		_draw_ring(panel.position + Vector2(panel.size.x * 0.5, 169.0), 24.0, LEATHER_LIGHT, 1.0)
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, 215.0), "A pilha está vazia.", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, TEXT_MUTED)
		return

	var row_height := 42.0
	var first_y := panel.position.y + 137.0
	var available_height := maxf(panel.end.y - first_y - 18.0, row_height)
	var visible_rows := maxi(int(floor(available_height / row_height)), 1)
	var first_visible := maxi(stack.size() - visible_rows, 0)
	var row_y := first_y
	if first_visible > 0:
		draw_string(ThemeDB.fallback_font, panel.position + Vector2(20.0, row_y + 11.0), "+%d abaixo" % first_visible, HORIZONTAL_ALIGNMENT_RIGHT, text_width, 10, TEXT_MUTED)
		row_y += 16.0
	for stack_index in range(stack.size() - 1, first_visible - 1, -1):
		var row := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 34.0)
		var is_top := stack_index == stack.size() - 1
		draw_rect(row, PARCHMENT_DEEP if is_top else PARCHMENT, true)
		draw_rect(row, GOLD_BRIGHT if is_top else PARCHMENT_BORDER, false, 1.0)
		var stack_value := int(stack[stack_index])
		draw_string(ThemeDB.fallback_font, row.position + Vector2(12.0, 22.0), "%03d" % stack_value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, PARCHMENT_INK)
		if is_top:
			draw_string(ThemeDB.fallback_font, row.position + Vector2(12.0, 21.0), "TOPO", HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - 24.0, 10, PARCHMENT_MUTED)
		row_y += row_height


func _draw_palette_tooltip() -> void:
	if not top_panel_open or hovered_palette_index < 0:
		return
	var item: Dictionary = PALETTE_SYMBOLS[hovered_palette_index]
	var tile := _palette_rect(hovered_palette_index)
	var panel := _top_panel_rect()
	var font: Font = ThemeDB.fallback_font
	var title := str(item["label"])
	var description := str(item["description"])
	var max_width := minf(330.0, maxf(panel.size.x - 24.0, 1.0))
	if max_width < 80.0:
		return
	var min_width := minf(160.0, max_width)
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x + 24.0
	var description_width := font.get_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x + 24.0
	var tooltip_width := clampf(maxf(title_width, description_width), min_width, max_width)
	var description_size := font.get_multiline_string_size(description, HORIZONTAL_ALIGNMENT_LEFT, tooltip_width - 24.0, 12)
	var tooltip_height := 34.0 + description_size.y + 12.0
	var tooltip_x := clampf(tile.position.x, panel.position.x + 12.0, maxf(panel.end.x - tooltip_width - 12.0, panel.position.x + 12.0))
	var tooltip_y := tile.end.y + 10.0
	if tooltip_y + tooltip_height > size.y - 12.0:
		tooltip_y = maxf(12.0, tile.position.y - tooltip_height - 10.0)
	var tooltip := Rect2(tooltip_x, tooltip_y, tooltip_width, tooltip_height)
	draw_rect(tooltip, Color("171a22"), true)
	draw_rect(tooltip, PANEL_BORDER, false, 1.0)
	draw_rect(tooltip.grow(-4.0), Color(0.71, 0.54, 0.24, 0.24), false, 1.0)
	draw_string(font, tooltip.position + Vector2(12.0, 21.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, GOLD_GLOW)
	draw_multiline_string(font, tooltip.position + Vector2(12.0, 42.0), description, HORIZONTAL_ALIGNMENT_LEFT, tooltip_width - 24.0, 12, -1, TEXT_PRIMARY)


func _draw_arcane_frame(rect: Rect2) -> void:
	draw_rect(rect, Color("1a140e"), true)
	draw_rect(rect.grow(-2.0), PANEL_BACKGROUND, true)
	draw_rect(rect, PANEL_BORDER, false, 2.0)
	var inner := rect.grow(-6.0)
	if inner.size.x > 0.0 and inner.size.y > 0.0:
		var inner_border := PANEL_ACCENT
		inner_border.a = 0.28
		draw_rect(inner, inner_border, false, 1.0)
	var corner := 13.0
	var top_left := rect.position + Vector2(9.0, 9.0)
	var top_right := Vector2(rect.end.x - 9.0, rect.position.y + 9.0)
	var bottom_left := Vector2(rect.position.x + 9.0, rect.end.y - 9.0)
	var bottom_right := rect.end - Vector2(9.0, 9.0)
	draw_line(top_left, top_left + Vector2(corner, 0.0), GOLD_BRIGHT, 1.2, true)
	draw_line(top_left, top_left + Vector2(0.0, corner), GOLD_BRIGHT, 1.2, true)
	draw_line(top_right, top_right + Vector2(-corner, 0.0), GOLD_BRIGHT, 1.2, true)
	draw_line(top_right, top_right + Vector2(0.0, corner), GOLD_BRIGHT, 1.2, true)
	draw_line(bottom_left, bottom_left + Vector2(corner, 0.0), GOLD_BRIGHT, 1.2, true)
	draw_line(bottom_left, bottom_left + Vector2(0.0, -corner), GOLD_BRIGHT, 1.2, true)
	draw_line(bottom_right, bottom_right + Vector2(-corner, 0.0), GOLD_BRIGHT, 1.2, true)
	draw_line(bottom_right, bottom_right + Vector2(0.0, -corner), GOLD_BRIGHT, 1.2, true)
	_draw_filled_circle(top_left, 1.6, GOLD_GLOW)
	_draw_filled_circle(top_right, 1.6, GOLD_GLOW)
	_draw_filled_circle(bottom_left, 1.6, GOLD_GLOW)
	_draw_filled_circle(bottom_right, 1.6, GOLD_GLOW)


func _draw_arcane_tile_mark(tile: Rect2, highlight_alpha: float = 0.0) -> void:
	var center := tile.get_center()
	var radius := tile.size.x * 0.40
	var outer_glow := GOLD_GLOW
	outer_glow.a = 0.08 + 0.16 * highlight_alpha
	_draw_filled_circle(center, radius + 5.0, outer_glow)
	_draw_filled_circle(center, radius, Color("211812").lerp(LEATHER_LIGHT, highlight_alpha))
	_draw_ring(center, radius, PANEL_BORDER.lerp(GOLD_BRIGHT, highlight_alpha), 2.0)
	_draw_ring(center, radius + 3.0, Color(0.71, 0.54, 0.24, 0.38 + 0.26 * highlight_alpha), 1.0)


func _draw_toggle_button(rect: Rect2, direction: String) -> void:
	var center := rect.get_center()
	draw_rect(rect, Color("1a140e"), true)
	draw_rect(rect, PANEL_BORDER, false, 1.0)
	_draw_ring(center, 11.0, PANEL_ACCENT, 1.0)
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
	draw_line(a, b, GOLD_GLOW, 2.0, true)
	draw_line(b, c, GOLD_GLOW, 2.0, true)


func _draw_play_button(rect: Rect2) -> void:
	var center := rect.get_center()
	var accent := Color("6b5130") if ritual_running else GOLD_GLOW
	draw_rect(rect, Color("1a140e"), true)
	draw_rect(rect, accent, false, 1.0)
	_draw_ring(center, 11.0, accent.darkened(0.45), 1.0)
	var a := center + Vector2(-3.0, -6.0)
	var b := center + Vector2(6.0, 0.0)
	var c := center + Vector2(-3.0, 6.0)
	draw_colored_polygon(PackedVector2Array([a, b, c]), accent)


func _draw_stop_button(rect: Rect2) -> void:
	var center := rect.get_center()
	var accent := Color("d46c4d") if ritual_running else Color("6b5130")
	draw_rect(rect, Color("1a140e"), true)
	draw_rect(rect, accent, false, 1.0)
	_draw_ring(center, 11.0, accent.darkened(0.45), 1.0)
	draw_rect(Rect2(center - Vector2(4.0, 4.0), Vector2(8.0, 8.0)), accent, true)


func _draw_execution_speed_control() -> void:
	var slider := _execution_speed_slider_rect()
	if slider.size.x <= 0.0:
		return
	draw_string(ThemeDB.fallback_font, slider.position + Vector2(0.0, -7.0), "%.1f RPS" % execution_speed_rps, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, TEXT_MUTED)
	draw_line(slider.position, Vector2(slider.end.x, slider.position.y), Color("1a140e"), 3.0, true)
	var amount := (execution_speed_rps - EXECUTION_MIN_RPS) / (EXECUTION_MAX_RPS - EXECUTION_MIN_RPS)
	var marker_position := Vector2(slider.position.x + slider.size.x * amount, slider.position.y)
	draw_line(slider.position, marker_position, GOLD_BRIGHT, 3.0, true)
	_draw_filled_circle(marker_position, 5.0, Color("1a140e"))
	_draw_ring(marker_position, 5.0, GOLD_GLOW, 1.3)


func _draw_resize_handles() -> void:
	if left_panel_open:
		var x := left_panel_size
		draw_line(Vector2(x, 44.0), Vector2(x, size.y - 44.0), PANEL_BORDER, 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			_draw_filled_circle(Vector2(x, size.y * 0.5 + offset), 1.5, GOLD_GLOW)
	if right_panel_open:
		var right_x := size.x - right_panel_size
		draw_line(Vector2(right_x, 44.0), Vector2(right_x, size.y - 44.0), PANEL_BORDER, 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			_draw_filled_circle(Vector2(right_x, size.y * 0.5 + offset), 1.5, GOLD_GLOW)
	if top_panel_open:
		var y := top_panel_size
		draw_line(Vector2(_left_panel_width() + 44.0, y), Vector2(size.x - _right_panel_width() - 44.0, y), PANEL_BORDER, 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			_draw_filled_circle(Vector2(size.x * 0.5 + offset, y), 1.5, GOLD_GLOW)
	if bottom_panel_open:
		var y := size.y - bottom_panel_size
		draw_line(Vector2(_left_panel_width() + 44.0, y), Vector2(size.x - _right_panel_width() - 44.0, y), PANEL_BORDER, 2.0, true)
		for offset in [-6.0, 0.0, 6.0]:
			_draw_filled_circle(Vector2(size.x * 0.5 + offset, y), 1.5, GOLD_GLOW)


func _draw_rune(kind: String, center: Vector2, rune_scale: float, color: Color) -> void:
	var r := 11.0 * rune_scale
	var main_stroke := 2.5 * rune_scale
	var fine_stroke := 1.2 * rune_scale
	match kind:
		"ORB":
			_draw_ring(center, r, color, main_stroke)
			_draw_filled_circle(center, r * 0.28, color)
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
			_draw_ring(center, r * 0.28, color, fine_stroke)
		"SQUARE":
			var square := Rect2(center - Vector2(r * 0.75, r * 0.75), Vector2(r * 1.5, r * 1.5))
			draw_rect(square, color, false, 2.4 * rune_scale, true)
			draw_rect(square.grow(-r * 0.28), color, false, fine_stroke, true)
		"FORK":
			draw_line(center + Vector2(-r * 0.75, -r), center + Vector2(-r * 0.75, r), color, 2.4 * rune_scale, true)
			draw_line(center + Vector2(-r * 0.75, -r * 0.15), center + Vector2(r * 0.75, -r * 0.15), color, 2.4 * rune_scale, true)
			draw_line(center + Vector2(-r * 0.75, r * 0.42), center + Vector2(r * 0.35, r * 0.42), color, 2.4 * rune_scale, true)
			_draw_filled_circle(center + Vector2(r * 0.55, -r * 0.15), r * 0.16, color)
		"READ":
			var read_left := center + Vector2(-r * 0.78, 0.0)
			var read_right := center + Vector2(r * 0.78, 0.0)
			var read_tip := center + Vector2(r * 0.20, 0.0)
			draw_line(read_left, read_tip, color, main_stroke, true)
			draw_line(read_tip, read_tip + Vector2(-r * 0.30, -r * 0.27), color, main_stroke, true)
			draw_line(read_tip, read_tip + Vector2(-r * 0.30, r * 0.27), color, main_stroke, true)
			draw_arc(read_right, r * 0.42, PI * 0.5, TAU * 1.5, 16, color, fine_stroke, true)
			draw_arc(read_right, r * 0.22, PI * 0.5, TAU * 1.5, 14, color, fine_stroke, true)
		"CUP":
			draw_line(center + Vector2(-r * 0.82, -r * 0.62), center + Vector2(0.0, r * 0.72), color, main_stroke, true)
			draw_line(center + Vector2(0.0, r * 0.72), center + Vector2(r * 0.82, -r * 0.62), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.96, -r * 0.62), center + Vector2(r * 0.96, -r * 0.62), color, fine_stroke, true)
		"TWIN":
			var twin_left := center + Vector2(-r * 0.34, 0.0)
			var twin_right := center + Vector2(r * 0.34, 0.0)
			_draw_ring(twin_left, r * 0.48, color, main_stroke)
			_draw_ring(twin_right, r * 0.48, color, main_stroke)
		"KNOT":
			draw_line(center + Vector2(-r * 0.9, -r * 0.5), center + Vector2(r * 0.9, r * 0.5), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.9, r * 0.5), center + Vector2(r * 0.9, -r * 0.5), color, main_stroke, true)
			_draw_filled_circle(center + Vector2(-r * 0.62, -r * 0.34), r * 0.16, color)
			_draw_filled_circle(center + Vector2(r * 0.62, r * 0.34), r * 0.16, color)
		"SLASH":
			draw_line(center + Vector2(-r * 0.62, r * 0.9), center + Vector2(r * 0.62, -r * 0.9), color, main_stroke, true)
			_draw_filled_circle(center + Vector2(-r * 0.58, -r * 0.62), r * 0.15, color)
			_draw_filled_circle(center + Vector2(r * 0.58, r * 0.62), r * 0.15, color)
		"SPIRAL":
			draw_arc(center, r * 0.82, PI * 0.18, TAU * 0.92, 20, color, main_stroke, true)
			draw_arc(center + Vector2(r * 0.13, 0.0), r * 0.42, PI * 1.08, TAU * 1.82, 16, color, main_stroke, true)
			_draw_filled_circle(center + Vector2(-r * 0.28, -r * 0.12), r * 0.11, color)
		"DASH":
			draw_line(center + Vector2(-r * 0.92, 0.0), center + Vector2(r * 0.92, 0.0), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.38, -r * 0.42), center + Vector2(r * 0.38, -r * 0.42), color, fine_stroke, true)
		"EQ":
			draw_line(center + Vector2(-r * 0.86, -r * 0.32), center + Vector2(r * 0.86, -r * 0.32), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.86, r * 0.32), center + Vector2(r * 0.86, r * 0.32), color, main_stroke, true)
			_draw_filled_circle(center + Vector2(0.0, -r * 0.32), r * 0.14, color)
			_draw_filled_circle(center + Vector2(0.0, r * 0.32), r * 0.14, color)
		"NEQ":
			draw_line(center + Vector2(-r * 0.86, -r * 0.32), center + Vector2(r * 0.86, -r * 0.32), color, fine_stroke, true)
			draw_line(center + Vector2(-r * 0.86, r * 0.32), center + Vector2(r * 0.86, r * 0.32), color, fine_stroke, true)
			draw_line(center + Vector2(-r * 0.48, r * 0.90), center + Vector2(r * 0.48, -r * 0.90), color, main_stroke, true)
		"LT":
			draw_line(center + Vector2(r * 0.64, -r * 0.78), center + Vector2(-r * 0.64, 0.0), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.64, 0.0), center + Vector2(r * 0.64, r * 0.78), color, main_stroke, true)
		"GT":
			draw_line(center + Vector2(-r * 0.64, -r * 0.78), center + Vector2(r * 0.64, 0.0), color, main_stroke, true)
			draw_line(center + Vector2(r * 0.64, 0.0), center + Vector2(-r * 0.64, r * 0.78), color, main_stroke, true)
		"LTE":
			draw_line(center + Vector2(r * 0.60, -r * 0.80), center + Vector2(-r * 0.60, -r * 0.06), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.60, -r * 0.06), center + Vector2(r * 0.60, r * 0.68), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.72, r * 0.86), center + Vector2(r * 0.72, r * 0.86), color, fine_stroke, true)
		"GTE":
			draw_line(center + Vector2(-r * 0.60, -r * 0.80), center + Vector2(r * 0.60, -r * 0.06), color, main_stroke, true)
			draw_line(center + Vector2(r * 0.60, -r * 0.06), center + Vector2(-r * 0.60, r * 0.68), color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.72, r * 0.86), center + Vector2(r * 0.72, r * 0.86), color, fine_stroke, true)
		"NOT":
			_draw_ring(center, r * 0.76, color, fine_stroke)
			draw_line(center + Vector2(-r * 0.66, r * 0.66), center + Vector2(r * 0.66, -r * 0.66), color, main_stroke, true)
			_draw_filled_circle(center + Vector2(r * 0.58, r * 0.58), r * 0.12, color)
		"AND":
			var and_left := center + Vector2(-r * 0.84, 0.0)
			var and_right := center + Vector2(r * 0.84, 0.0)
			draw_line(and_left, and_right, color, main_stroke, true)
			draw_line(and_left, and_left + Vector2(r * 0.34, -r * 0.34), color, main_stroke, true)
			draw_line(and_left, and_left + Vector2(r * 0.34, r * 0.34), color, main_stroke, true)
			draw_line(and_right, and_right + Vector2(-r * 0.34, -r * 0.34), color, main_stroke, true)
			draw_line(and_right, and_right + Vector2(-r * 0.34, r * 0.34), color, main_stroke, true)
		"OR":
			var or_left_tip := center + Vector2(-r * 0.86, -r * 0.34)
			var or_right_tip := center + Vector2(r * 0.86, r * 0.34)
			var or_left_tail := center + Vector2(r * 0.20, -r * 0.34)
			var or_right_tail := center + Vector2(-r * 0.20, r * 0.34)
			draw_line(or_left_tail, or_left_tip, color, main_stroke, true)
			draw_line(or_left_tip, or_left_tip + Vector2(r * 0.34, -r * 0.30), color, main_stroke, true)
			draw_line(or_left_tip, or_left_tip + Vector2(r * 0.34, r * 0.30), color, main_stroke, true)
			draw_line(or_right_tail, or_right_tip, color, main_stroke, true)
			draw_line(or_right_tip, or_right_tip + Vector2(-r * 0.34, -r * 0.30), color, main_stroke, true)
			draw_line(or_right_tip, or_right_tip + Vector2(-r * 0.34, r * 0.30), color, main_stroke, true)
		"PRINTLETTER":
			var letter_top := center + Vector2(0.0, -r * 0.86)
			var letter_left := center + Vector2(-r * 0.67, r * 0.78)
			var letter_right := center + Vector2(r * 0.67, r * 0.78)
			draw_line(letter_left, letter_top, color, main_stroke, true)
			draw_line(letter_top, letter_right, color, main_stroke, true)
			draw_line(center + Vector2(-r * 0.36, r * 0.12), center + Vector2(r * 0.36, r * 0.12), color, fine_stroke, true)
			_draw_filled_circle(center + Vector2(0.0, r * 0.52), r * 0.10, color)
		"JUMP_IF_TRUE":
			var jump_start := center + Vector2(-r * 0.82, r * 0.62)
			var jump_branch := center + Vector2(-r * 0.12, r * 0.08)
			var jump_tip := center + Vector2(r * 0.82, -r * 0.62)
			draw_line(jump_start, jump_branch, color, main_stroke, true)
			draw_line(jump_branch, jump_tip, color, main_stroke, true)
			draw_line(jump_tip, jump_tip + Vector2(-r * 0.34, -r * 0.06), color, main_stroke, true)
			draw_line(jump_tip, jump_tip + Vector2(-r * 0.06, r * 0.34), color, main_stroke, true)
			_draw_filled_circle(jump_branch, r * 0.16, color)
		"WARP":
			draw_arc(center, r * 0.84, PI * 0.14, TAU * 0.86, 20, color, main_stroke, true)
			draw_arc(center, r * 0.48, PI * 1.14, TAU * 1.86, 16, color, fine_stroke, true)
			draw_line(center + Vector2(-r * 0.46, 0.0), center + Vector2(r * 0.28, 0.0), color, fine_stroke, true)
			draw_line(center + Vector2(r * 0.28, 0.0), center + Vector2(r * 0.03, -r * 0.23), color, fine_stroke, true)
			draw_line(center + Vector2(r * 0.28, 0.0), center + Vector2(r * 0.03, r * 0.23), color, fine_stroke, true)
		"WARP_ENDPOINT":
			_draw_ring(center, r * 0.84, color, main_stroke)
			_draw_ring(center, r * 0.50, color, fine_stroke)
			_draw_filled_circle(center, r * 0.18, color)
			draw_line(center + Vector2(0.0, -r * 1.02), center + Vector2(0.0, -r * 0.62), color, fine_stroke, true)
			draw_line(center + Vector2(0.0, r * 0.62), center + Vector2(0.0, r * 1.02), color, fine_stroke, true)
		"INT_MOD":
			_draw_ring(center, r * 0.82, color, main_stroke)
			draw_line(center + Vector2(-r * 0.42, 0.0), center + Vector2(r * 0.42, 0.0), color, fine_stroke, true)
			draw_line(center + Vector2(0.0, -r * 0.42), center + Vector2(0.0, r * 0.42), color, fine_stroke, true)
			_draw_filled_circle(center, r * 0.14, color)
		"INT_SET":
			var set_rect := Rect2(center - Vector2(r * 0.64, r * 0.64), Vector2(r * 1.28, r * 1.28))
			draw_rect(set_rect, color, false, main_stroke, true)
			draw_line(center + Vector2(-r * 0.33, 0.0), center + Vector2(r * 0.33, 0.0), color, fine_stroke, true)
			_draw_filled_circle(center + Vector2(r * 0.46, 0.0), r * 0.12, color)


func _is_canvas_position(screen_position: Vector2) -> bool:
	return _canvas_rect().has_point(screen_position)


func _canvas_rect() -> Rect2:
	var left := _left_panel_width()
	var right := _right_panel_width()
	var top := _top_panel_height()
	var bottom := _bottom_panel_height()
	return Rect2(left, top, maxf(size.x - left - right, 0.0), maxf(size.y - top - bottom, 0.0))


func _left_panel_width() -> float:
	return left_panel_size if left_panel_open else PANEL_TAB_SIZE


func _right_panel_width() -> float:
	return right_panel_size if right_panel_open else PANEL_TAB_SIZE


func _top_panel_height() -> float:
	return top_panel_size if top_panel_open else PANEL_TAB_SIZE


func _bottom_panel_height() -> float:
	return bottom_panel_size if bottom_panel_open else PANEL_TAB_SIZE


func _top_panel_rect() -> Rect2:
	var left := _left_panel_width()
	return Rect2(left, 0.0, maxf(size.x - left - _right_panel_width(), 0.0), _top_panel_height())


func _bottom_panel_rect() -> Rect2:
	var left := _left_panel_width()
	var panel_height := _bottom_panel_height()
	return Rect2(left, size.y - panel_height, maxf(size.x - left - _right_panel_width(), 0.0), panel_height)


func _right_panel_rect() -> Rect2:
	var panel_width := _right_panel_width()
	return Rect2(size.x - panel_width, 0.0, panel_width, size.y)


func _left_toggle_rect() -> Rect2:
	if left_panel_open:
		return Rect2(left_panel_size - 38.0, 8.0, 30.0, 30.0)
	return Rect2(6.0, size.y * 0.5 - 15.0, 30.0, 30.0)


func _top_toggle_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 38.0, 6.0, 30.0, 30.0)


func _bottom_toggle_rect() -> Rect2:
	var panel := _bottom_panel_rect()
	return Rect2(panel.end.x - 38.0, panel.position.y + 6.0, 30.0, 30.0)


func _right_toggle_rect() -> Rect2:
	var panel := _right_panel_rect()
	if right_panel_open:
		return Rect2(panel.position.x + 8.0, 8.0, 30.0, 30.0)
	return Rect2(panel.position.x + 6.0, size.y * 0.5 - 15.0, 30.0, 30.0)


func _panel_toggle_at(screen_position: Vector2) -> String:
	if _left_toggle_rect().has_point(screen_position):
		return "left"
	if _top_toggle_rect().has_point(screen_position):
		return "top"
	if _bottom_toggle_rect().has_point(screen_position):
		return "bottom"
	if _right_toggle_rect().has_point(screen_position):
		return "right"
	return ""


func _toggle_panel(panel: String) -> void:
	match panel:
		"left":
			left_panel_open = not left_panel_open
		"right":
			right_panel_open = not right_panel_open
		"top":
			top_panel_open = not top_panel_open
		"bottom":
			bottom_panel_open = not bottom_panel_open
	_clamp_palette_scroll()
	_update_hover()


func _play_button_rect() -> Rect2:
	return Rect2(_top_panel_rect().end.x - 110.0, 6.0, 30.0, 30.0)


func _stop_button_rect() -> Rect2:
	return Rect2(_top_panel_rect().end.x - 74.0, 6.0, 30.0, 30.0)


func _execution_speed_slider_rect() -> Rect2:
	var right_edge := _play_button_rect().position.x - 12.0
	var left_edge := maxf(_top_panel_rect().position.x + 118.0, right_edge - 126.0)
	return Rect2(left_edge, 28.0, maxf(right_edge - left_edge, 0.0), 6.0)


func _update_execution_speed(screen_position: Vector2) -> void:
	var slider := _execution_speed_slider_rect()
	if slider.size.x <= 0.0:
		return
	var amount := clampf((screen_position.x - slider.position.x) / slider.size.x, 0.0, 1.0)
	execution_speed_rps = clampf(round(lerpf(EXECUTION_MIN_RPS, EXECUTION_MAX_RPS, amount) * 10.0) / 10.0, EXECUTION_MIN_RPS, EXECUTION_MAX_RPS)


func _resize_handle_at(screen_position: Vector2) -> String:
	if left_panel_open and absf(screen_position.x - left_panel_size) <= 6.0:
		return "left"
	if right_panel_open and absf(screen_position.x - (size.x - right_panel_size)) <= 6.0:
		return "right"
	if top_panel_open and screen_position.x >= _top_panel_rect().position.x and screen_position.x <= _top_panel_rect().end.x and absf(screen_position.y - top_panel_size) <= 6.0:
		return "top"
	var bottom_edge := size.y - bottom_panel_size
	if bottom_panel_open and screen_position.x >= _bottom_panel_rect().position.x and screen_position.x <= _bottom_panel_rect().end.x and absf(screen_position.y - bottom_edge) <= 6.0:
		return "bottom"
	return ""


func _begin_resize(panel: String) -> void:
	drag_mode = "resize_%s" % panel
	resize_start_mouse = pointer_screen
	match panel:
		"left":
			resize_start_size = left_panel_size
		"right":
			resize_start_size = right_panel_size
		"top":
			resize_start_size = top_panel_size
		"bottom":
			resize_start_size = bottom_panel_size


func _resize_panel(screen_position: Vector2) -> void:
	match drag_mode:
		"resize_left":
			var max_width := maxf(MIN_LEFT_PANEL_WIDTH, size.x - _right_panel_width() - 190.0)
			left_panel_size = clampf(resize_start_size + (screen_position.x - resize_start_mouse.x), MIN_LEFT_PANEL_WIDTH, max_width)
		"resize_right":
			var max_right_width := maxf(MIN_RIGHT_PANEL_WIDTH, size.x - _left_panel_width() - 190.0)
			right_panel_size = clampf(resize_start_size - (screen_position.x - resize_start_mouse.x), MIN_RIGHT_PANEL_WIDTH, max_right_width)
		"resize_top":
			var max_top_height := maxf(MIN_TOP_PANEL_HEIGHT, size.y - _bottom_panel_height() - 120.0)
			top_panel_size = clampf(resize_start_size + (screen_position.y - resize_start_mouse.y), MIN_TOP_PANEL_HEIGHT, max_top_height)
		"resize_bottom":
			var max_bottom_height := maxf(MIN_BOTTOM_PANEL_HEIGHT, size.y - _top_panel_height() - 120.0)
			bottom_panel_size = clampf(resize_start_size - (screen_position.y - resize_start_mouse.y), MIN_BOTTOM_PANEL_HEIGHT, max_bottom_height)
	_clamp_palette_scroll()
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


func _display_connection_intensity(connection_index: int, connection: Dictionary) -> int:
	if execution_intensity_overrides.has(connection_index):
		return clampi(int(execution_intensity_overrides[connection_index]), 0, 255)
	return _connection_intensity(connection)


func _intensity_color(intensity: int) -> Color:
	var amount := float(clampi(intensity, 0, 255)) / 255.0
	return LEATHER_LIGHT.lerp(GOLD_GLOW, amount)


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
	selected_symbol_connection = -1
	_cancel_intensity_text_edit()


func _select_connection(index: int, additive := false, select_symbol := false) -> void:
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
	if select_symbol and selected_connections.size() == 1 and selected_connection == index:
		selected_symbol_connection = index
	else:
		selected_symbol_connection = -1


func _is_connection_selected(index: int) -> bool:
	return selected_connections.has(index)


func _update_primary_selection() -> void:
	selected_connection = selected_connections[0] if selected_connections.size() == 1 else -1
	if selected_symbol_connection != selected_connection:
		selected_symbol_connection = -1
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
	selected_symbol_connection = -1


func _begin_selection_move() -> void:
	if selected_connections.is_empty():
		return
	drag_mode = "selection_move_pending"
	selection_move_press_screen = pointer_screen
	selection_move_origin_world = _screen_to_world(pointer_screen)
	selection_move_offset = Vector2.ZERO


func _selected_connection_uses_anchor(world_point: Vector2) -> bool:
	for connection_index in selected_connections:
		if connection_index < 0 or connection_index >= connections.size():
			continue
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		if from_point.is_equal_approx(world_point) or to_point.is_equal_approx(world_point):
			return true
	return false


func _update_selection_move() -> void:
	var raw_offset := _screen_to_world(pointer_screen) - selection_move_origin_world
	selection_move_offset = _snap_world_to_grid(raw_offset)


func _complete_selection_move() -> void:
	if not selection_move_offset.is_zero_approx() and diagram.move_connections(selected_connections, selection_move_offset):
		_invalidate_sequence_side_multiplier_cache()
		selected_symbol_connection = -1
		_clear_diagram_animations()
	selection_move_offset = Vector2.ZERO


func _snap_world_to_grid(world_position: Vector2) -> Vector2:
	return Vector2(
		round(world_position.x / GRID_SPACING) * GRID_SPACING,
		round(world_position.y / GRID_SPACING) * GRID_SPACING
	)


func _copy_selected_connections_to_clipboard() -> void:
	if selected_connections.is_empty():
		return
	var copied_connections: Array = []
	for connection_index in selected_connections:
		if connection_index < 0 or connection_index >= connections.size():
			continue
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		copied_connections.append({
			"from": [from_point.x, from_point.y],
			"to": [to_point.x, to_point.y],
			"symbol": str(connection.get("symbol", "")),
			"intensity": clampi(int(connection.get("intensity", 128)), 0, 255)
		})
	if copied_connections.is_empty():
		return
	var payload := {"version": 1, "connections": copied_connections}
	DisplayServer.clipboard_set(CLIPBOARD_RITUAL_PREFIX + "\n" + JSON.stringify(payload))


func _paste_connections_from_clipboard() -> void:
	if ritual_running:
		return
	var clipboard_text: String = DisplayServer.clipboard_get()
	if not clipboard_text.begins_with(CLIPBOARD_RITUAL_PREFIX):
		return
	var clipboard_payload := clipboard_text.trim_prefix(CLIPBOARD_RITUAL_PREFIX).strip_edges()
	var parsed_payload: Variant = JSON.parse_string(clipboard_payload)
	if not (parsed_payload is Dictionary):
		return
	var payload: Dictionary = parsed_payload
	if int(payload.get("version", 0)) != 1:
		return
	var raw_connections: Variant = payload.get("connections", [])
	if not (raw_connections is Array):
		return

	var source_connections: Array[Dictionary] = []
	var minimum_point := Vector2(INF, INF)
	var maximum_point := Vector2(-INF, -INF)
	for raw_connection in raw_connections:
		if not (raw_connection is Dictionary):
			return
		var serialized_connection: Dictionary = raw_connection
		var from_data := _clipboard_point_from_json(serialized_connection.get("from"))
		var to_data := _clipboard_point_from_json(serialized_connection.get("to"))
		if from_data.is_empty() or to_data.is_empty():
			return
		var from_point: Vector2 = from_data["point"]
		var to_point: Vector2 = to_data["point"]
		var symbol: String = str(serialized_connection.get("symbol", ""))
		if not symbol.is_empty() and RuneCatalog.opcode_for_kind(symbol) < 0:
			return
		var intensity := clampi(int(serialized_connection.get("intensity", 128)), 0, 255)
		source_connections.append({"from": from_point, "to": to_point, "symbol": symbol, "intensity": intensity})
		minimum_point = Vector2(minf(minimum_point.x, minf(from_point.x, to_point.x)), minf(minimum_point.y, minf(from_point.y, to_point.y)))
		maximum_point = Vector2(maxf(maximum_point.x, maxf(from_point.x, to_point.x)), maxf(maximum_point.y, maxf(from_point.y, to_point.y)))
	if source_connections.is_empty():
		return

	var canvas := _canvas_rect()
	var target_screen := canvas.position + Vector2(maxf(canvas.size.x - GRID_SPACING * 1.5, 0.0), GRID_SPACING * 1.5)
	var target_top_right := _snap_world_to_grid(_screen_to_world(target_screen))
	var source_top_right := Vector2(maximum_point.x, minimum_point.y)
	var base_offset := target_top_right - source_top_right
	var pasted_indices: Array[int] = []
	for attempt in range(16):
		var offset := base_offset + Vector2(-GRID_SPACING * attempt, GRID_SPACING * attempt)
		var pasted_connections: Array = []
		for source_connection in source_connections:
			var from_point: Vector2 = source_connection["from"]
			var to_point: Vector2 = source_connection["to"]
			pasted_connections.append({
				"from": from_point + offset,
				"to": to_point + offset,
				"symbol": str(source_connection["symbol"]),
				"intensity": int(source_connection["intensity"])
			})
		pasted_indices = diagram.append_connections(pasted_connections)
		if not pasted_indices.is_empty():
			break
	if pasted_indices.is_empty():
		return
	_invalidate_symbol_connection_indices()
	_invalidate_sequence_side_multiplier_cache()
	selected_connections = pasted_indices
	_update_primary_selection()
	selected_symbol_connection = -1
	_clear_diagram_animations()
	queue_redraw()


func _clipboard_point_from_json(raw_value: Variant) -> Dictionary:
	if not (raw_value is Array):
		return {}
	var coordinates: Array = raw_value
	if coordinates.size() != 2:
		return {}
	return {"point": Vector2(float(coordinates[0]), float(coordinates[1]))}


func _connection_intersects_selection_rect(index: int, rect: Rect2) -> bool:
	var connection: Dictionary = connections[index]
	var from_screen := _world_to_screen(connection["from"])
	var to_screen := _world_to_screen(connection["to"])
	var expanded_rect := rect.grow(2.0)
	if expanded_rect.has_point(from_screen) or expanded_rect.has_point(to_screen):
		return true
	var top_left := expanded_rect.position
	var top_right := Vector2(expanded_rect.end.x, expanded_rect.position.y)
	var bottom_right := expanded_rect.end
	var bottom_left := Vector2(expanded_rect.position.x, expanded_rect.end.y)
	return _segments_intersect(from_screen, to_screen, top_left, top_right) or _segments_intersect(from_screen, to_screen, top_right, bottom_right) or _segments_intersect(from_screen, to_screen, bottom_right, bottom_left) or _segments_intersect(from_screen, to_screen, bottom_left, top_left)


func _segments_intersect(first_from: Vector2, first_to: Vector2, second_from: Vector2, second_to: Vector2) -> bool:
	var first_delta := first_to - first_from
	var second_delta := second_to - second_from
	var denominator := first_delta.cross(second_delta)
	if absf(denominator) < 0.0001:
		return false
	var between_starts := second_from - first_from
	var first_progress := between_starts.cross(second_delta) / denominator
	var second_progress := between_starts.cross(first_delta) / denominator
	return first_progress >= 0.0 and first_progress <= 1.0 and second_progress >= 0.0 and second_progress <= 1.0


func _delete_selected_connections() -> void:
	if selected_connections.is_empty():
		return
	if selected_connections.size() == 1 and selected_symbol_connection == selected_connection:
		if diagram.set_symbol(selected_symbol_connection, ""):
			_invalidate_symbol_connection_indices()
			_deselect_connection()
			_clear_diagram_animations()
			queue_redraw()
		return
	if diagram.remove_connections(selected_connections):
		_invalidate_symbol_connection_indices()
		_invalidate_sequence_side_multiplier_cache()
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


func _update_hover() -> bool:
	var candidate := _grid_point_at(pointer_screen)
	hover_point_valid = candidate.has("point")
	if hover_point_valid:
		hover_world = candidate["point"]
	var is_rectangle_selecting := drag_mode == "selection" or drag_mode == "selection_pending"
	var is_moving_anchor := drag_mode == "move_anchor" or anchor_move_settle_active
	if _is_canvas_position(pointer_screen) and drag_mode != "connect" and not is_moving_anchor and not is_rectangle_selecting:
		hovered_symbol = _symbol_at(pointer_screen)
	else:
		hovered_symbol = -1
	# Durante a criação, a linha embaixo do cursor não deve competir com o
	# feedback magnético da âncora.
	if drag_mode == "connect" or is_moving_anchor or is_rectangle_selecting or not _is_canvas_position(pointer_screen) or hovered_symbol >= 0:
		hovered_connection = -1
	else:
		hovered_connection = _connection_near(pointer_screen)
	hovered_palette_index = _palette_index_at(pointer_screen)
	return _sync_hover_animation()


func _sync_hover_animation() -> bool:
	var changed := false
	if animated_hover_point_valid != hover_point_valid or (hover_point_valid and not animated_hover_world.is_equal_approx(hover_world)):
		animated_hover_point_valid = hover_point_valid
		animated_hover_world = hover_world
		point_hover_started_at = animation_clock
		changed = true
	if animated_hover_connection != hovered_connection:
		animated_hover_connection = hovered_connection
		connection_hover_started_at = animation_clock
		changed = true
	if animated_hover_symbol != hovered_symbol:
		animated_hover_symbol = hovered_symbol
		symbol_hover_started_at = animation_clock
		changed = true
	if animated_hover_palette_index != hovered_palette_index:
		animated_hover_palette_index = hovered_palette_index
		palette_hover_started_at = animation_clock
		changed = true
	return changed


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
	var viewport := _palette_viewport_rect()
	if viewport.size.x <= 0.0 or viewport.size.y <= 0.0:
		return Rect2()
	var tile_size := _palette_tile_size()
	var columns := _palette_columns()
	var column := index % columns
	var row := int(index / columns)
	var scroll := clampf(palette_scroll, 0.0, _palette_max_scroll())
	var centered_offset := maxf((viewport.size.x - _palette_content_width()) * 0.5, 0.0)
	return Rect2(viewport.position.x + centered_offset + column * (tile_size + PALETTE_TILE_GAP) - scroll, viewport.position.y + row * (tile_size + PALETTE_TILE_GAP), tile_size, tile_size)


func _palette_viewport_rect() -> Rect2:
	if not top_panel_open:
		return Rect2()
	var panel := _top_panel_rect()
	var tile_size := _palette_tile_size()
	var rows := _palette_rows()
	var content_height := tile_size * rows + PALETTE_TILE_GAP * (rows - 1)
	var preferred_y := panel.position.y + (panel.size.y - content_height) * 0.5
	var min_y := panel.position.y + PALETTE_TOP_Y
	var max_y := panel.end.y - PALETTE_BOTTOM_PADDING - content_height
	var content_y := clampf(preferred_y, min_y, maxf(max_y, min_y))
	return Rect2(panel.position.x + 20.0, content_y, maxf(panel.size.x - 40.0, 0.0), content_height)


func _palette_rows() -> int:
	if not top_panel_open:
		return 1
	var available_height := top_panel_size - PALETTE_TOP_Y - PALETTE_BOTTOM_PADDING
	var two_row_minimum := PALETTE_MIN_TILE_SIZE * 2.0 + PALETTE_TILE_GAP
	return 2 if available_height >= two_row_minimum else 1


func _palette_tile_size() -> float:
	if not top_panel_open:
		return PALETTE_MIN_TILE_SIZE
	var height_limited_size := PALETTE_MIN_TILE_SIZE
	if _palette_rows() == 1:
		height_limited_size = PALETTE_MIN_TILE_SIZE
	else:
		var available_height := top_panel_size - PALETTE_TOP_Y - PALETTE_BOTTOM_PADDING
		height_limited_size = clampf((available_height - PALETTE_TILE_GAP) * 0.5, PALETTE_MIN_TILE_SIZE, PALETTE_MAX_TILE_SIZE)
	var available_width := maxf(_top_panel_rect().size.x - 40.0, 0.0)
	var width_limited_size := (available_width - PALETTE_TILE_GAP * float(PALETTE_COMPACT_COLUMNS - 1)) / float(PALETTE_COMPACT_COLUMNS)
	return clampf(minf(height_limited_size, width_limited_size), PALETTE_MIN_TILE_SIZE, PALETTE_MAX_TILE_SIZE)


func _palette_columns() -> int:
	return maxi(1, int(ceil(float(PALETTE_SYMBOLS.size()) / float(_palette_rows()))))


func _palette_content_width() -> float:
	var columns := _palette_columns()
	return columns * _palette_tile_size() + maxf(float(columns - 1), 0.0) * PALETTE_TILE_GAP


func _palette_max_scroll() -> float:
	if not top_panel_open:
		return 0.0
	var viewport := _palette_viewport_rect()
	return maxf(_palette_content_width() - viewport.size.x, 0.0)


func _scroll_palette(direction: int) -> void:
	if not top_panel_open:
		return
	palette_scroll_target = clampf(palette_scroll_target + float(direction) * PALETTE_SCROLL_STEP, 0.0, _palette_max_scroll())
	queue_redraw()


func _begin_palette_scroll_gesture() -> void:
	if _palette_max_scroll() <= 0.0:
		return
	drag_mode = "palette_scroll"
	palette_scroll_drag_start_mouse = pointer_screen
	palette_scroll_drag_start_offset = palette_scroll_target


func _update_palette_scroll_drag() -> void:
	var offset := palette_scroll_drag_start_offset - (pointer_screen.x - palette_scroll_drag_start_mouse.x)
	palette_scroll_target = clampf(offset, 0.0, _palette_max_scroll())
	palette_scroll = palette_scroll_target


func _palette_scroll_is_moving() -> bool:
	return top_panel_open and absf(palette_scroll_target - palette_scroll) > 0.1


func _update_palette_scroll(delta: float) -> void:
	if not top_panel_open:
		palette_scroll = 0.0
		palette_scroll_target = 0.0
		return
	_clamp_palette_scroll()
	var amount := 1.0 - exp(-delta * PALETTE_SCROLL_SMOOTHNESS)
	palette_scroll = lerpf(palette_scroll, palette_scroll_target, amount)
	if absf(palette_scroll_target - palette_scroll) <= 0.1:
		palette_scroll = palette_scroll_target
	_update_hover()
	queue_redraw()


func _clamp_palette_scroll() -> void:
	var max_scroll := _palette_max_scroll()
	palette_scroll = clampf(palette_scroll, 0.0, max_scroll)
	palette_scroll_target = clampf(palette_scroll_target, 0.0, max_scroll)


func _palette_scrollbar_rect() -> Rect2:
	if not top_panel_open:
		return Rect2()
	var viewport := _palette_viewport_rect()
	var panel := _top_panel_rect()
	return Rect2(viewport.position.x, panel.end.y - 13.0, viewport.size.x, 4.0)


func _draw_palette_scrollbar() -> void:
	var max_scroll := _palette_max_scroll()
	if max_scroll <= 0.0:
		return
	var track := _palette_scrollbar_rect()
	var content_width := _palette_content_width()
	var thumb_width := maxf(28.0, track.size.x * track.size.x / content_width)
	var travel := maxf(track.size.x - thumb_width, 0.0)
	var thumb_x := track.position.x + travel * (clampf(palette_scroll, 0.0, max_scroll) / max_scroll)
	draw_line(track.position, Vector2(track.end.x, track.position.y), Color("1a140e"), 2.0, true)
	draw_line(Vector2(thumb_x, track.position.y), Vector2(thumb_x + thumb_width, track.position.y), PANEL_ACCENT, 2.0, true)


func _draw_palette_scroll_masks(viewport: Rect2) -> void:
	if viewport.size.x <= 0.0 or viewport.size.y <= 0.0:
		return
	var panel := _top_panel_rect()
	var left_mask_width := maxf(viewport.position.x - panel.position.x - 2.0, 0.0)
	var right_mask_width := maxf(panel.end.x - viewport.end.x - 2.0, 0.0)
	if left_mask_width > 0.0:
		draw_rect(Rect2(panel.position.x + 2.0, viewport.position.y, left_mask_width, viewport.size.y), PANEL_BACKGROUND, true)
	if right_mask_width > 0.0:
		draw_rect(Rect2(viewport.end.x, viewport.position.y, right_mask_width, viewport.size.y), PANEL_BACKGROUND, true)


func _palette_tile_is_visible(tile: Rect2, viewport: Rect2) -> bool:
	if tile.size.x <= 0.0 or tile.size.y <= 0.0 or viewport.size.x <= 0.0 or viewport.size.y <= 0.0:
		return false
	return tile.position.x >= viewport.position.x and tile.end.x <= viewport.end.x and tile.position.y >= viewport.position.y and tile.end.y <= viewport.end.y


func _palette_index_at(screen_position: Vector2) -> int:
	var viewport := _palette_viewport_rect()
	if not top_panel_open or not viewport.has_point(screen_position):
		return -1
	for index in range(PALETTE_SYMBOLS.size()):
		var tile := _palette_rect(index)
		if _palette_tile_is_visible(tile, viewport) and tile.has_point(screen_position):
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
	var radius := maxf(12.0, 24.0 * zoom)
	var radius_squared := radius * radius
	for index in _symbol_connection_indices():
		var connection: Dictionary = connections[index]
		if screen_position.distance_squared_to(_symbol_position(connection, index)) <= radius_squared:
			return index
	return -1


func _ensure_connection_hit_buckets() -> void:
	if not connection_hit_buckets_dirty:
		return
	connection_hit_buckets.clear()
	for connection_index in range(connections.size()):
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var first_x := int(floor(minf(from_point.x, to_point.x) / CONNECTION_HIT_BUCKET_SIZE))
		var last_x := int(floor(maxf(from_point.x, to_point.x) / CONNECTION_HIT_BUCKET_SIZE))
		var first_y := int(floor(minf(from_point.y, to_point.y) / CONNECTION_HIT_BUCKET_SIZE))
		var last_y := int(floor(maxf(from_point.y, to_point.y) / CONNECTION_HIT_BUCKET_SIZE))
		for bucket_x in range(first_x, last_x + 1):
			for bucket_y in range(first_y, last_y + 1):
				var bucket_key := "%d:%d" % [bucket_x, bucket_y]
				var bucket_connections: Array = connection_hit_buckets.get(bucket_key, [])
				bucket_connections.append(connection_index)
				connection_hit_buckets[bucket_key] = bucket_connections
	connection_hit_buckets_dirty = false


func _connection_hit_candidates(screen_position: Vector2) -> Array[int]:
	_ensure_connection_hit_buckets()
	var world_position := _screen_to_world(screen_position)
	var world_radius := LINE_HIT_RADIUS / maxf(zoom, 0.001)
	var first_x := int(floor((world_position.x - world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var last_x := int(floor((world_position.x + world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var first_y := int(floor((world_position.y - world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var last_y := int(floor((world_position.y + world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var candidates: Array[int] = []
	var seen := {}
	for bucket_x in range(first_x, last_x + 1):
		for bucket_y in range(first_y, last_y + 1):
			var bucket_key := "%d:%d" % [bucket_x, bucket_y]
			var bucket_connections: Array = connection_hit_buckets.get(bucket_key, [])
			for raw_connection_index in bucket_connections:
				var connection_index := int(raw_connection_index)
				if not seen.has(connection_index):
					seen[connection_index] = true
					candidates.append(connection_index)
	return candidates


func _connection_near(screen_position: Vector2) -> int:
	var closest_index := -1
	var closest_distance := INF
	for index in _connection_hit_candidates(screen_position):
		var connection: Dictionary = connections[index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var a := _world_to_screen(from_point)
		var b := _world_to_screen(to_point)
		if screen_position.x < minf(a.x, b.x) - LINE_HIT_RADIUS or screen_position.x > maxf(a.x, b.x) + LINE_HIT_RADIUS or screen_position.y < minf(a.y, b.y) - LINE_HIT_RADIUS or screen_position.y > maxf(a.y, b.y) + LINE_HIT_RADIUS:
			continue
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
		_select_connection(target, false, true)
		if dragged_symbol_source >= 0:
			if target == dragged_symbol_source:
				_set_connection_symbol(target, active_symbol, false)
				_set_connection_intensity(target, dragged_symbol_intensity, false)
			else:
				_record_undo_snapshot(symbol_drag_start_snapshot)
				_set_connection_symbol(target, active_symbol, false)
				_set_connection_intensity(target, dragged_symbol_intensity, false)
		else:
			var target_connection: Dictionary = connections[target]
			var target_symbol := str(target_connection.get("symbol", ""))
			var target_intensity := _connection_intensity(target_connection)
			if target_symbol != active_symbol or target_intensity != DEFAULT_RUNE_INTENSITY:
				_record_current_state()
				_set_connection_symbol(target, active_symbol, false)
				_set_connection_intensity(target, DEFAULT_RUNE_INTENSITY, false)
		_start_symbol_settle(target)
	elif dragged_symbol_source >= 0:
		_set_connection_symbol(dragged_symbol_source, active_symbol, false)
		_set_connection_intensity(dragged_symbol_source, dragged_symbol_intensity, false)


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
	if diagram.set_symbol(index, symbol, record_history):
		_invalidate_symbol_connection_indices()


func _set_connection_intensity(index: int, intensity: int, record_history := true) -> void:
	diagram.set_intensity(index, intensity, record_history)


func _add_connection(from: Vector2, to: Vector2) -> void:
	if diagram.add_connection(from, to):
		_invalidate_symbol_connection_indices()
		_invalidate_sequence_side_multiplier_cache()


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
		_set_connection_intensity(dragged_symbol_source, dragged_symbol_intensity, false)
	elif drag_mode == "intensity" and not intensity_drag_start_snapshot.is_empty():
		_restore_connections(intensity_drag_start_snapshot)
	_reset_drag()


func _reset_drag() -> void:
	drag_mode = ""
	active_symbol = ""
	dragged_symbol_source = -1
	dragged_symbol_intensity = DEFAULT_RUNE_INTENSITY
	symbol_drag_start_snapshot = []
	symbol_press_screen = Vector2.ZERO
	anchor_snap_active = false
	anchor_move_source = Vector2.ZERO
	anchor_move_target = Vector2.ZERO
	anchor_move_snap_target = Vector2.ZERO
	anchor_move_snap_target_valid = false
	anchor_move_is_terminal = false
	anchor_move_snap_started_at = 0.0
	anchor_move_press_screen = Vector2.ZERO
	anchor_move_settle_active = false
	anchor_move_settle_from = Vector2.ZERO
	anchor_move_settle_to = Vector2.ZERO
	anchor_move_settle_started_at = 0.0
	selection_rect = Rect2()
	selection_rect_additive = false
	selection_move_press_screen = Vector2.ZERO
	selection_move_origin_world = Vector2.ZERO
	selection_move_offset = Vector2.ZERO
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
	_invalidate_symbol_connection_indices()
	_invalidate_sequence_side_multiplier_cache()


func _clear_diagram_animations() -> void:
	anchor_snap_active = false
	symbol_settle_active = false
	symbol_settle_kind = ""
	symbol_settle_connection = -1


func _undo() -> void:
	if not diagram.undo():
		return
	_invalidate_symbol_connection_indices()
	_invalidate_sequence_side_multiplier_cache()
	_clear_diagram_animations()
	_deselect_connection()
	_reset_drag()
	queue_redraw()


func _redo() -> void:
	if not diagram.redo():
		return
	_invalidate_symbol_connection_indices()
	_invalidate_sequence_side_multiplier_cache()
	_clear_diagram_animations()
	_deselect_connection()
	_reset_drag()
	queue_redraw()
