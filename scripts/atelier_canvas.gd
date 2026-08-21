extends Control

## Protótipo visual da Atelier IDE.
## - Arraste com o botão do meio para navegar pela grade.
## - Arraste de um ponto até outro para criar uma ligação.
## - Arraste um selo da paleta para uma ligação já criada.
## - Arraste uma área vazia para selecionar várias ligações.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const Palette = preload("res://scripts/core/atelier_palette.gd")
const RuneDiagram = preload("res://scripts/core/rune_diagram.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
const RunePainter = preload("res://scripts/rendering/rune_painter.gd")
const StaticLayer = preload("res://scripts/rendering/atelier_static_layer.gd")

const PANEL_TAB_SIZE := 42.0
const DEFAULT_LEFT_PANEL_WIDTH := 304.0
const DEFAULT_RIGHT_PANEL_WIDTH := 236.0
const DEFAULT_TOP_PANEL_HEIGHT := 196.0
const DEFAULT_BOTTOM_PANEL_HEIGHT := 224.0
const MIN_LEFT_PANEL_WIDTH := 216.0
const MIN_RIGHT_PANEL_WIDTH := 170.0
const MIN_TOP_PANEL_HEIGHT := 174.0
const MIN_BOTTOM_PANEL_HEIGHT := 124.0
const LEFT_COMMAND_ROW_HEIGHT := 66.0
const LEFT_COMMAND_LIST_TOP := 82.0
const LEFT_COMMAND_SCROLL_STEP := 28.0
const LEFT_SCROLL_DRAG_THRESHOLD := 4.0
const PALETTE_TOP_Y := 56.0
const PALETTE_MAX_TILE_SIZE := 58.0
const PALETTE_MIN_TILE_SIZE := 34.0
const PALETTE_TILE_GAP := 8.0
const PALETTE_BOTTOM_PADDING := 16.0
const PALETTE_COMPACT_COLUMNS := 4
const PALETTE_SCROLL_STEP := 120.0
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
const THEME_SETTINGS_PATH := "user://atelier_theme.cfg"

const PANEL_GAP := 12.0

## Cores usadas pelo diagrama dinamico. O restante da paleta pertence aos
## componentes de interface e as camadas estaticas.
var active_theme := "dark"
var col_gold_bright: Color
var col_gold_glow: Color
var col_rune_line: Color
var col_leather_light: Color
var col_ember: Color
var col_ember_soft: Color
var col_sky: Color
var col_sky_high: Color
var col_dot: Color
var col_dot_hover: Color

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
var ritual_paused := false
var execution_speed_rps := EXECUTION_MIN_RPS
var execution_instructions: Array[Dictionary] = []
var execution_state: Dictionary = {}
var execution_instruction_cursor := 0
var execution_step_elapsed := 0.0
var execution_connection := -1
var execution_highlight_started_at := 0.0
var execution_highlight_ends_at := 0.0
var execution_highlight_needs_clear := false
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
var performance_visible_connections := 0
var performance_grid_dots := 0
var grid_dot_textures := {}
var filled_circle_texture: Texture2D
var ring_textures := {}
var edge_mask_texture: GradientTexture2D
var symbol_connection_indices_cache: Array[int] = []
var symbol_connection_indices_dirty := true
var sequence_side_multiplier_cache: Array[float] = []
var sequence_side_multiplier_dirty := true
var connection_hit_buckets := {}
var connection_hit_buckets_dirty := true
var anchor_point_counts_cache: Dictionary = {}
var anchor_point_counts_dirty := true
var selected_connections_lookup: Dictionary = {}
var execution_timer: Timer
var static_backdrop: StaticLayer
var static_chrome: StaticLayer

@onready var interface: AtelierInterface = $Interface


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	filled_circle_texture = _create_filled_circle_texture()
	edge_mask_texture = _create_radial_texture(true)
	_create_static_layers()
	execution_timer = Timer.new()
	execution_timer.name = "ExecutionTimer"
	execution_timer.one_shot = true
	execution_timer.timeout.connect(_on_execution_timer_timeout)
	add_child(execution_timer)
	_connect_interface()
	resized.connect(_on_root_resized)
	_apply_theme(_load_saved_theme())
	_sync_interface_all()
	grab_focus()
	queue_redraw()


func _create_static_layers() -> void:
	static_backdrop = StaticLayer.new()
	static_backdrop.name = "StaticBackdrop"
	static_backdrop.configure(StaticLayer.PASS_BACKDROP)
	static_backdrop.z_index = -10
	add_child(static_backdrop)
	static_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	static_chrome = StaticLayer.new()
	static_chrome.name = "StaticChrome"
	static_chrome.configure(StaticLayer.PASS_CHROME)
	static_chrome.z_index = 10
	add_child(static_chrome)
	static_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _connect_interface() -> void:
	interface.panel_toggle_requested.connect(_on_interface_panel_toggle)
	interface.connection_selected.connect(_on_interface_connection_selected)
	interface.play_requested.connect(_on_interface_play_requested)
	interface.pause_requested.connect(_on_interface_pause_requested)
	interface.step_requested.connect(_on_interface_step_requested)
	interface.stop_requested.connect(_on_interface_stop_requested)
	interface.theme_requested.connect(_toggle_theme)
	interface.speed_changed.connect(_on_interface_speed_changed)
	interface.intensity_drag_started.connect(_begin_intensity_drag)
	interface.intensity_previewed.connect(_on_interface_intensity_previewed)
	interface.intensity_drag_finished.connect(_on_interface_intensity_drag_finished)
	interface.intensity_committed.connect(_on_interface_intensity_committed)
	interface.bottom_resize_started.connect(_on_bottom_resize_started)
	interface.bottom_resize_dragged.connect(_on_bottom_resize_dragged)
	interface.bottom_resize_finished.connect(_on_bottom_resize_finished)


func _sync_interface_all() -> void:
	_sync_interface_layout()
	_sync_interface_diagram()
	_sync_interface_execution()


func _sync_interface_layout() -> void:
	_sync_static_layout()
	if not is_instance_valid(interface):
		return
	interface.sync_layout(
			_left_panel_rect(),
			_top_panel_rect(),
			_bottom_panel_rect(),
			_right_panel_rect(),
			_intensity_inspector_rect(),
			left_panel_open,
			top_panel_open,
			bottom_panel_open,
			right_panel_open)


func _sync_static_layout() -> void:
	if not is_instance_valid(static_backdrop) or not is_instance_valid(static_chrome):
		return
	var canvas_rect := _canvas_rect()
	var left_rect := _left_panel_rect()
	var top_rect := _top_panel_rect()
	var bottom_rect := _bottom_panel_rect()
	var right_rect := _right_panel_rect()
	for layer: StaticLayer in [static_backdrop, static_chrome]:
		layer.sync_layout(
				canvas_rect,
				left_rect,
				top_rect,
				bottom_rect,
				right_rect,
				left_panel_open,
				top_panel_open,
				bottom_panel_open,
				right_panel_open)


func _sync_interface_diagram() -> void:
	if not is_instance_valid(interface):
		return
	interface.sync_diagram(
			connections,
			selected_connections,
			execution_intensity_overrides,
			selected_connection)


func _sync_interface_execution() -> void:
	if not is_instance_valid(interface):
		return
	interface.sync_execution(
			execution_state,
			ritual_running,
			ritual_paused,
			_ritual_can_step(),
			execution_speed_rps)


func _on_interface_panel_toggle(panel: String) -> void:
	_toggle_panel(panel)
	_sync_interface_layout()
	queue_redraw()


func _on_interface_connection_selected(connection_index: int, additive: bool) -> void:
	_select_connection(connection_index, additive, true)
	queue_redraw()


func _on_interface_play_requested() -> void:
	if ritual_paused:
		_resume_ritual()
	elif not ritual_running:
		_run_ritual()
	_sync_interface_all()
	queue_redraw()


func _on_interface_pause_requested() -> void:
	_pause_ritual()
	_sync_interface_execution()
	queue_redraw()


func _on_interface_step_requested() -> void:
	_step_paused_ritual()
	_sync_interface_all()
	queue_redraw()


func _on_interface_stop_requested() -> void:
	if _ritual_is_active():
		_stop_ritual()
	_sync_interface_all()
	queue_redraw()


func _on_interface_speed_changed(value: float) -> void:
	execution_speed_rps = clampf(value, EXECUTION_MIN_RPS, EXECUTION_MAX_RPS)
	if ritual_running:
		_schedule_execution_step()


func _on_interface_intensity_previewed(value: int) -> void:
	if not _has_selected_connection():
		return
	var connection: Dictionary = connections[selected_connection]
	if _connection_intensity(connection) == value:
		return
	_set_connection_intensity(selected_connection, value, false)
	intensity_drag_changed = true
	queue_redraw()


func _on_interface_intensity_drag_finished(_value: int, changed: bool) -> void:
	if changed or intensity_drag_changed:
		_finish_intensity_drag()


func _on_interface_intensity_committed(value: int) -> void:
	if not _has_selected_connection():
		return
	_set_connection_intensity(selected_connection, value)
	queue_redraw()


func _on_bottom_resize_started(pointer_y: float) -> void:
	drag_mode = "resize_bottom"
	resize_start_mouse = Vector2(pointer_screen.x, pointer_y)
	resize_start_size = bottom_panel_size


func _on_bottom_resize_dragged(pointer_y: float) -> void:
	_resize_panel(Vector2(pointer_screen.x, pointer_y))
	_sync_interface_layout()
	queue_redraw()


func _on_bottom_resize_finished() -> void:
	if drag_mode == "resize_bottom":
		_reset_drag()


func _on_root_resized() -> void:
	_sync_interface_layout()
	queue_redraw()


## ======================== TEMA DO ATELIE ========================

func _apply_theme(theme_name: String) -> void:
	active_theme = "light" if theme_name == "light" else "dark"
	var table := Palette.table(active_theme)
	col_gold_bright = table["gold_bright"]
	col_gold_glow = table["gold_glow"]
	col_rune_line = table["rune_line"]
	col_leather_light = table["leather_light"]
	col_ember = table["ember"]
	col_ember_soft = table["ember_soft"]
	col_sky = table["sky"]
	col_sky_high = table["sky_high"]
	col_dot = table["dot"]
	col_dot_hover = table["dot_hover"]
	if is_instance_valid(static_backdrop):
		static_backdrop.apply_palette(table)
	if is_instance_valid(static_chrome):
		static_chrome.apply_palette(table)
	if is_instance_valid(interface):
		interface.apply_palette(active_theme, table)
	queue_redraw()


func _toggle_theme() -> void:
	_apply_theme("dark" if active_theme == "light" else "light")
	_save_theme()


func _load_saved_theme() -> String:
	var config := ConfigFile.new()
	if config.load(THEME_SETTINGS_PATH) != OK:
		return "dark"
	return str(config.get_value("atelier", "theme", "dark"))


func _save_theme() -> void:
	var config := ConfigFile.new()
	config.set_value("atelier", "theme", active_theme)
	config.save(THEME_SETTINGS_PATH)


## ==================== TEXTURAS DE APOIO ====================

## Disco branco opaco no centro, ou o inverso para mascarar as bordas.
func _create_radial_texture(inverted: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	var opaque := Color(1.0, 1.0, 1.0, 1.0)
	var clear := Color(1.0, 1.0, 1.0, 0.0)
	if inverted:
		gradient.offsets = PackedFloat32Array([0.55, 1.0])
		gradient.colors = PackedColorArray([clear, opaque])
	else:
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		gradient.colors = PackedColorArray([opaque, clear])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.4) if inverted else Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.4) if inverted else Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
func _process(delta: float) -> void:
	var highlight_needs_final_clear := execution_highlight_needs_clear and not _execution_highlight_active()
	if not anchor_snap_active and drag_mode != "move_anchor" and not anchor_move_settle_active and not symbol_settle_active and not _hover_transition_active() and not _execution_highlight_animating() and not highlight_needs_final_clear:
		return
	animation_clock += delta
	if anchor_snap_active and animation_clock - anchor_snap_started_at >= ANCHOR_SNAP_DURATION:
		_complete_anchor_snap()
	if drag_mode == "move_anchor" and anchor_move_is_terminal and anchor_move_snap_target_valid and animation_clock - anchor_move_snap_started_at >= ANCHOR_SNAP_DURATION:
		_continue_terminal_anchor_move()
	if anchor_move_settle_active and animation_clock - anchor_move_settle_started_at >= ANCHOR_SNAP_DURATION:
		_complete_anchor_move_settle()
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F3:
		performance_overlay_visible = not performance_overlay_visible
		interface.set_performance_visible(performance_overlay_visible)
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(interface) and interface.text_control_has_focus():
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
	if event.keycode == KEY_A:
		_select_all_connections()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_C:
		_copy_selected_connections_to_clipboard()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_X:
		_cut_selected_connections()
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
		if _theme_button_rect().has_point(pointer_screen):
			_toggle_theme()
			accept_event()
			return
		if _play_button_rect().has_point(pointer_screen):
			if ritual_paused:
				_resume_ritual()
			elif not ritual_running:
				_run_ritual()
			queue_redraw()
			accept_event()
			return
		if _pause_button_rect().has_point(pointer_screen):
			_pause_ritual()
			queue_redraw()
			accept_event()
			return
		if _step_button_rect().has_point(pointer_screen):
			_step_paused_ritual()
			queue_redraw()
			accept_event()
			return
		if _stop_button_rect().has_point(pointer_screen):
			if _ritual_is_active():
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
		if _ritual_is_active():
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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if _ritual_is_active() or not (data is Dictionary):
		return false
	var payload: Dictionary = data
	if str(payload.get("type", "")) != "atelier_rune" or not _is_canvas_position(at_position):
		return false
	return _connection_near(at_position) >= 0


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var payload: Dictionary = data
	var target := _connection_near(at_position)
	if target < 0:
		return
	var kind := str(payload.get("kind", ""))
	var intensity := clampi(int(payload.get("intensity", DEFAULT_RUNE_INTENSITY)), 0, 255)
	var target_connection: Dictionary = connections[target]
	if str(target_connection.get("symbol", "")) != kind or _connection_intensity(target_connection) != intensity:
		_record_current_state()
		_set_connection_symbol(target, kind, false)
		_set_connection_intensity(target, intensity, false)
	pointer_screen = at_position
	_select_connection(target, false, true)
	_start_symbol_settle(target)
	_sync_interface_diagram()
	queue_redraw()


func _run_ritual() -> void:
	if _ritual_is_active():
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
	ritual_paused = false
	interface.clear_execution_log()
	var compilation := compiler.compile(connections)
	for warning in compilation.get("warnings", []):
		var warning_text := str(warning)
		execution_warnings.append(warning_text)
		interface.append_warning(warning_text)
	if not compilation["ok"]:
		for error in compilation.get("errors", []):
			var error_text := str(error)
			execution_errors.append(error_text)
			interface.append_error(error_text)
		bottom_panel_open = true
		_sync_interface_all()
		return

	last_bytecode = compilation["bytecode"]
	var decoded: Dictionary = RuneBytecode.decode(last_bytecode)
	if not bool(decoded["ok"]):
		for error in decoded["errors"]:
			var decode_error_text := str(error)
			execution_errors.append(decode_error_text)
			interface.append_error(decode_error_text)
		bottom_panel_open = true
		_sync_interface_all()
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
			var configure_error_text := str(error)
			execution_errors.append(configure_error_text)
			interface.append_error(configure_error_text)
		bottom_panel_open = true
		_sync_interface_all()
		return
	bottom_panel_open = true
	right_panel_open = true
	ritual_running = true
	_execute_next_ritual_step()


func _execute_next_ritual_step() -> void:
	if execution_instruction_cursor >= execution_instructions.size():
		_finish_ritual()
		return
	var instruction_index := execution_instruction_cursor
	var instruction: Dictionary = execution_instructions[instruction_index]
	execution_instruction_cursor += 1
	execution_connection = int(instruction.get("connection_index", -1))
	var highlight_now := _execution_clock()
	execution_highlight_started_at = highlight_now
	execution_highlight_ends_at = highlight_now + maxf(_execution_step_duration(), EXECUTION_HIGHLIGHT_FADE_DURATION)
	execution_highlight_needs_clear = true
	var output: Array = execution_state["output"]
	var errors: Array = execution_state["errors"]
	var output_count := output.size()
	var error_count := errors.size()
	vm.step(instruction, execution_state, instruction_index)
	var overrides_changed := _refresh_execution_intensity_overrides()
	for output_index in range(output_count, output.size()):
		var output_text := str(output[output_index])
		interface.append_output(output_text)
	for error_index in range(error_count, errors.size()):
		var runtime_error_text := str(errors[error_index])
		execution_errors.append(runtime_error_text)
		interface.append_error(runtime_error_text)
	var jump_target := int(execution_state["jump_target"])
	if jump_target >= 0:
		execution_instruction_cursor = jump_target
	if not errors.is_empty() or bool(execution_state["halted"]):
		_finish_ritual()
		execution_highlight_ends_at = maxf(execution_highlight_ends_at, _execution_clock() + EXECUTION_HIGHLIGHT_FADE_DURATION)
	elif ritual_running:
		_schedule_execution_step()
	if overrides_changed:
		_sync_interface_diagram()
	_sync_interface_execution()
	queue_redraw()


func _schedule_execution_step() -> void:
	if execution_timer == null or not ritual_running:
		return
	execution_timer.start(_execution_step_duration())


func _on_execution_timer_timeout() -> void:
	if ritual_running:
		_execute_next_ritual_step()


func _ritual_is_active() -> bool:
	return ritual_running or ritual_paused


func _ritual_can_step() -> bool:
	return ritual_paused and not execution_instructions.is_empty() and not execution_state.is_empty() and not bool(execution_state.get("halted", false)) and execution_instruction_cursor < execution_instructions.size()


func _pause_ritual() -> void:
	if not ritual_running:
		return
	ritual_running = false
	ritual_paused = true
	execution_step_elapsed = 0.0
	if execution_timer != null:
		execution_timer.stop()


func _resume_ritual() -> void:
	if not ritual_paused:
		return
	ritual_paused = false
	ritual_running = true
	execution_step_elapsed = 0.0
	_schedule_execution_step()


func _step_paused_ritual() -> void:
	if not _ritual_can_step():
		return
	execution_step_elapsed = 0.0
	_execute_next_ritual_step()


func _finish_ritual() -> void:
	ritual_running = false
	ritual_paused = false
	execution_step_elapsed = 0.0
	if execution_timer != null:
		execution_timer.stop()
	execution_output = interface.execution_log.get_output()
	_sync_interface_execution()


func _stop_ritual() -> void:
	_finish_ritual()
	execution_instructions.clear()
	execution_connection = -1
	execution_highlight_ends_at = _execution_clock()
	execution_highlight_needs_clear = true
	var interruption_text := tr("UI_EXECUTION_INTERRUPTED")
	execution_warnings.append(interruption_text)
	interface.append_warning(interruption_text)


func _execution_step_duration() -> float:
	return 1.0 / maxf(execution_speed_rps, EXECUTION_MIN_RPS)


func _execution_highlight_active() -> bool:
	return execution_connection >= 0 and _execution_clock() < execution_highlight_ends_at


func _execution_highlight_alpha() -> float:
	if not _execution_highlight_active():
		return 0.0
	var now := _execution_clock()
	var duration := maxf(execution_highlight_ends_at - execution_highlight_started_at, 0.001)
	var fade_in := minf(0.12, duration * 0.35)
	var fade_out := minf(EXECUTION_HIGHLIGHT_FADE_DURATION, duration * 0.35)
	var entering := clampf((now - execution_highlight_started_at) / maxf(fade_in, 0.001), 0.0, 1.0)
	var leaving := clampf((execution_highlight_ends_at - now) / maxf(fade_out, 0.001), 0.0, 1.0)
	return smoothstep(0.0, 1.0, minf(entering, leaving))


func _execution_highlight_animating() -> bool:
	if not _execution_highlight_active():
		return false
	var now := _execution_clock()
	var duration := maxf(execution_highlight_ends_at - execution_highlight_started_at, 0.001)
	var fade_in := minf(0.12, duration * 0.35)
	var fade_out := minf(EXECUTION_HIGHLIGHT_FADE_DURATION, duration * 0.35)
	return now - execution_highlight_started_at < fade_in or execution_highlight_ends_at - now < fade_out


func _execution_clock() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0


func _refresh_execution_intensity_overrides() -> bool:
	var next_overrides: Dictionary = {}
	for raw_instruction in execution_instructions:
		var instruction: Dictionary = raw_instruction
		if not instruction.has("connection_index"):
			continue
		var connection_index := int(instruction["connection_index"])
		next_overrides[connection_index] = clampi(int(instruction.get("intensity", instruction.get("operand", 128))), 0, 255)
	if execution_intensity_overrides == next_overrides:
		return false
	execution_intensity_overrides = next_overrides
	return true


func export_current_ritual(path: String) -> Dictionary:
	var result := compiler.export_binary(connections, path)
	if result["ok"]:
		last_bytecode = result["bytecode"]
	return result


func _draw() -> void:
	var draw_started_us: int = Time.get_ticks_usec()
	performance_visible_connections = 0
	performance_grid_dots = 0
	var canvas_rect := _canvas_rect()
	var point_counts := _anchor_point_counts()
	var visible_indices := _visible_connection_indices(canvas_rect)
	performance_visible_connections = visible_indices.size()
	var stage_started_us: int = Time.get_ticks_usec()
	_draw_grid(canvas_rect, point_counts, visible_indices)
	_draw_grid_edge_mask(canvas_rect)
	performance_grid_ms = float(Time.get_ticks_usec() - stage_started_us) / 1000.0
	stage_started_us = Time.get_ticks_usec()
	_draw_connections(canvas_rect, point_counts, visible_indices)
	_draw_selection_move_preview()
	_draw_connection_preview()
	_draw_selection_rectangle()
	_draw_dragged_symbol()
	_draw_settling_symbol()
	performance_connections_ms = float(Time.get_ticks_usec() - stage_started_us) / 1000.0
	performance_draw_ms = float(Time.get_ticks_usec() - draw_started_us) / 1000.0
	if not _execution_highlight_active():
		execution_highlight_needs_clear = false
	if performance_overlay_visible:
		interface.record_performance_sample({
			"draw_ms": performance_draw_ms,
			"grid_ms": performance_grid_ms,
			"connections_ms": performance_connections_ms,
			"connections": connections.size(),
			"visible_connections": performance_visible_connections,
			"grid_dots": performance_grid_dots,
			"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		})


## Recria a mascara radial do desenho: a grade some ao chegar nas bordas.
func _draw_grid_edge_mask(canvas_rect: Rect2) -> void:
	if canvas_rect.size.x <= 0.0 or canvas_rect.size.y <= 0.0:
		return
	draw_texture_rect(edge_mask_texture, canvas_rect, false, _sky_at(canvas_rect.get_center().y, canvas_rect))


## Cor do ceu na altura pedida, acompanhando o gradiente vertical da mesa.
func _sky_at(y: float, canvas_rect: Rect2) -> Color:
	return col_sky_high.lerp(col_sky, clampf((y - canvas_rect.position.y) / maxf(canvas_rect.size.y, 1.0), 0.0, 1.0))


func _draw_grid(canvas_rect: Rect2, point_counts: Dictionary, visible_indices: Array[int]) -> void:
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
	var grid_color := col_dot
	grid_color.a *= density_alpha
	draw_texture_rect_region(_grid_dot_texture(grid_step), canvas_rect, source_rect, grid_color)

	# Apaga apenas os pontos internos usados como âncora. Assim a grade inteira
	# custa um único quad, sem reintroduzir os pixels que apareciam sob as junções.
	for raw_point in _visible_connection_points(visible_indices):
		if int(point_counts[raw_point]) <= 1:
			continue
		var used_point: Vector2 = raw_point
		var used_screen := _world_to_screen(used_point)
		if canvas_rect.grow(DOT_RADIUS * zoom + 1.0).has_point(used_screen):
			_draw_filled_circle(used_screen, DOT_RADIUS * zoom + 0.9, _sky_at(used_screen.y, canvas_rect))

	# O ponto embaixo do mouse é desenhado à parte para preservar o highlight.
	if animated_hover_point_valid and int(point_counts.get(animated_hover_world, 0)) <= 1:
		var hover_radius := lerpf(DOT_RADIUS * zoom, 5.0 * zoom, _hover_alpha(point_hover_started_at))
		var hover_color := col_dot.lerp(col_dot_hover, _hover_alpha(point_hover_started_at))
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
	if not anchor_point_counts_dirty:
		return anchor_point_counts_cache
	anchor_point_counts_cache.clear()
	for connection in connections:
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		anchor_point_counts_cache[from_point] = int(anchor_point_counts_cache.get(from_point, 0)) + 1
		anchor_point_counts_cache[to_point] = int(anchor_point_counts_cache.get(to_point, 0)) + 1
	anchor_point_counts_dirty = false
	return anchor_point_counts_cache


func _visible_connection_indices(canvas_rect: Rect2) -> Array[int]:
	_ensure_connection_hit_buckets()
	var indices: Array[int] = []
	var seen: Dictionary = {}
	var margin_world := CONNECTION_DRAW_MARGIN / maxf(zoom, 0.001)
	var world_rect := Rect2(_screen_to_world(canvas_rect.position), canvas_rect.size / zoom).grow(margin_world)
	var first_x := int(floor(world_rect.position.x / CONNECTION_HIT_BUCKET_SIZE))
	var last_x := int(floor(world_rect.end.x / CONNECTION_HIT_BUCKET_SIZE))
	var first_y := int(floor(world_rect.position.y / CONNECTION_HIT_BUCKET_SIZE))
	var last_y := int(floor(world_rect.end.y / CONNECTION_HIT_BUCKET_SIZE))
	for bucket_x in range(first_x, last_x + 1):
		for bucket_y in range(first_y, last_y + 1):
			var bucket_key := Vector2i(bucket_x, bucket_y)
			var bucket_connections: Array = connection_hit_buckets.get(bucket_key, [])
			for raw_index in bucket_connections:
				seen[int(raw_index)] = true
	for raw_index in seen:
		var index := int(raw_index)
		var connection: Dictionary = connections[index]
		if _is_connection_hidden_during_move(connection, index):
			continue
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		var from_screen := _world_to_screen(from_point)
		var to_screen := _world_to_screen(to_point)
		if _segment_intersects_canvas(from_screen, to_screen, canvas_rect):
			indices.append(index)
	indices.sort()
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


func _is_terminal_point(world_point: Vector2) -> bool:
	return _connection_point_uses(world_point) == 1


func _connection_point_uses(world_point: Vector2) -> int:
	return int(_anchor_point_counts().get(world_point, 0))


func _draw_connections(canvas_rect: Rect2, point_counts: Dictionary, visible_indices: Array[int]) -> void:
	# A estrutura inteira usa a mesma tinta-base. Cada ligação ainda existe no
	# diagrama, mas só é revelada como uma célula individual pelo hover.
	var visible_points := _visible_connection_points(visible_indices)
	var line_shadow := col_rune_line.darkened(0.72)
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
		draw_multiline(main_segments, col_rune_line, 2.0 * zoom, true)
	_draw_line_joins_and_caps(visible_points, col_rune_line, 1.0 * zoom)
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
		var selection_glow := col_rune_line.lightened(0.45)
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
			var soft_glow := col_rune_line.lightened(0.35)
			soft_glow.a = 0.10 * highlight_alpha
			draw_line(from_screen, to_screen, soft_glow, 6.0 * zoom, true)
			_draw_rounded_segment_caps(from_screen, to_screen, soft_glow, 3.0 * zoom)
			var bright_glow := col_rune_line.lightened(0.55)
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
				rune_color = rune_color.lerp(col_ember, 0.72 * execution_alpha)
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
	_draw_filled_circle(screen_position, 3.0 * zoom, col_rune_line)


func _is_connection_hidden_during_move(connection: Dictionary, connection_index := -1) -> bool:
	if drag_mode == "selection_move":
		if connection_index < 0:
			connection_index = connections.find(connection)
		return selected_connections_lookup.has(connection_index)
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
	anchor_point_counts_dirty = true


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
		draw_line(start_screen, _anchor_snap_endpoint(), col_gold_glow, 3.0 * zoom, true)
	elif drag_mode == "move_anchor" or anchor_move_settle_active:
		_draw_anchor_move_preview()


func _draw_selection_move_preview() -> void:
	if drag_mode != "selection_move":
		return
	var preview_color := col_gold_glow
	preview_color.a = 0.72
	var preview_glow := col_gold_glow
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
	var preview_color := col_gold_glow
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
		var snap_color := col_gold_glow
		snap_color.a = 0.42
		_draw_ring(_world_to_screen(anchor_move_snap_target), 9.0 * zoom, snap_color, 1.1 * zoom)


func _draw_selection_rectangle() -> void:
	if drag_mode != "selection":
		return
	var fill_color := col_gold_bright
	fill_color.a = 0.08
	var border_color := col_gold_glow
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
	if source.is_equal_approx(target):
		return
	# Segurar o terminal sobre outro ponto inicia uma nova célula a partir do
	# terminal original. Antes o ponto era movido para frente, esticando a célula
	# anterior e deixando um "buraco" na sequência reta.
	_add_connection(source, target)
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
		_draw_rune(active_symbol, pointer_screen, zoom, col_gold_glow)


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
	var outer_glow := col_ember_soft
	outer_glow.a = 0.17 * highlight_alpha
	draw_line(from_screen, to_screen, outer_glow, 9.0 * zoom, true)
	_draw_rounded_segment_caps(from_screen, to_screen, outer_glow, 4.5 * zoom)
	var inner_glow := col_ember.lightened(0.35)
	inner_glow.a = 0.80 * highlight_alpha
	draw_line(from_screen, to_screen, inner_glow, 3.1 * zoom, true)
	_draw_rounded_segment_caps(from_screen, to_screen, inner_glow, 1.55 * zoom)


func _draw_execution_symbol_glow(kind: String, symbol_position: Vector2, rune_color: Color, highlight_alpha: float) -> void:
	var glow_color := rune_color.lerp(col_ember, 0.72)
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


func _command_row_at(screen_position: Vector2) -> int:
	var list_rect := _left_command_list_rect()
	if not left_panel_open or not list_rect.has_point(screen_position):
		return -1
	var panel := _left_panel_rect()
	var row_y := list_rect.position.y + 6.0 - minf(left_command_scroll, _left_command_max_scroll())
	for connection_index in _symbol_connection_indices():
		var row := Rect2(panel.position.x + 14.0, row_y, panel.size.x - 28.0, 58.0)
		if row.end.y > list_rect.position.y and row.position.y < list_rect.end.y and row.has_point(screen_position):
			return connection_index
		row_y += LEFT_COMMAND_ROW_HEIGHT
		if row.position.y > list_rect.end.y:
			break
	return -1


func _left_command_list_rect() -> Rect2:
	if not left_panel_open:
		return Rect2()
	var panel := _left_panel_rect()
	return Rect2(panel.position.x + 12.0, panel.position.y + LEFT_COMMAND_LIST_TOP, panel.size.x - 24.0, maxf(panel.size.y - LEFT_COMMAND_LIST_TOP - 18.0, 0.0))


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


func _draw_rune(kind: String, center: Vector2, rune_scale: float, color: Color) -> void:
	RunePainter.draw_rune(self, kind, center, rune_scale, color)


func _is_canvas_position(screen_position: Vector2) -> bool:
	return _canvas_rect().has_point(screen_position)


func _canvas_rect() -> Rect2:
	var top := PANEL_GAP * 2.0 + _top_panel_height()
	var bottom := size.y - PANEL_GAP * 2.0 - _bottom_panel_height()
	return Rect2(_middle_left(), top, _middle_width(), maxf(bottom - top, 0.0))


## Coluna do meio: comeca depois da folga externa e do grimorio.
func _middle_left() -> float:
	return PANEL_GAP * 2.0 + _left_panel_width()


func _middle_width() -> float:
	return maxf(size.x - _middle_left() - _right_panel_width() - PANEL_GAP * 2.0, 0.0)


func _left_panel_rect() -> Rect2:
	return Rect2(PANEL_GAP, PANEL_GAP, _left_panel_width(), maxf(size.y - PANEL_GAP * 2.0, 0.0))


func _left_panel_width() -> float:
	return left_panel_size if left_panel_open else PANEL_TAB_SIZE


func _right_panel_width() -> float:
	return right_panel_size if right_panel_open else PANEL_TAB_SIZE


func _top_panel_height() -> float:
	return top_panel_size if top_panel_open else PANEL_TAB_SIZE


func _bottom_panel_height() -> float:
	return bottom_panel_size if bottom_panel_open else PANEL_TAB_SIZE


func _top_panel_rect() -> Rect2:
	return Rect2(_middle_left(), PANEL_GAP, _middle_width(), _top_panel_height())


func _bottom_panel_rect() -> Rect2:
	var panel_height := _bottom_panel_height()
	return Rect2(_middle_left(), size.y - PANEL_GAP - panel_height, _middle_width(), panel_height)


func _right_panel_rect() -> Rect2:
	var panel_width := _right_panel_width()
	return Rect2(size.x - PANEL_GAP - panel_width, PANEL_GAP, panel_width, maxf(size.y - PANEL_GAP * 2.0, 0.0))


func _left_toggle_rect() -> Rect2:
	var panel := _left_panel_rect()
	if left_panel_open:
		return Rect2(panel.end.x - 38.0, panel.position.y + 8.0, 30.0, 30.0)
	return Rect2(panel.position.x + 6.0, size.y * 0.5 - 15.0, 30.0, 30.0)


func _top_toggle_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 38.0, panel.position.y + 6.0, 30.0, 30.0)


func _bottom_toggle_rect() -> Rect2:
	var panel := _bottom_panel_rect()
	return Rect2(panel.end.x - 38.0, panel.position.y + 6.0, 30.0, 30.0)


func _right_toggle_rect() -> Rect2:
	var panel := _right_panel_rect()
	if right_panel_open:
		return Rect2(panel.position.x + 8.0, panel.position.y + 8.0, 30.0, 30.0)
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
	_sync_interface_layout()


func _play_button_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 254.0, panel.position.y + 6.0, 30.0, 30.0)


func _pause_button_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 218.0, panel.position.y + 6.0, 30.0, 30.0)


func _step_button_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 182.0, panel.position.y + 6.0, 30.0, 30.0)


func _stop_button_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 146.0, panel.position.y + 6.0, 30.0, 30.0)


## Alterna entre o grimorio a luz de vela e o pergaminho iluminado.
func _theme_button_rect() -> Rect2:
	var panel := _top_panel_rect()
	return Rect2(panel.end.x - 110.0, panel.position.y + 6.0, 30.0, 30.0)


func _execution_speed_slider_rect() -> Rect2:
	var panel := _top_panel_rect()
	var right_edge := _play_button_rect().position.x - 12.0
	var left_edge := maxf(panel.position.x + 118.0, right_edge - 126.0)
	return Rect2(left_edge, panel.position.y + 28.0, maxf(right_edge - left_edge, 0.0), 6.0)


func _update_execution_speed(screen_position: Vector2) -> void:
	var slider := _execution_speed_slider_rect()
	if slider.size.x <= 0.0:
		return
	var amount := clampf((screen_position.x - slider.position.x) / slider.size.x, 0.0, 1.0)
	execution_speed_rps = clampf(round(lerpf(EXECUTION_MIN_RPS, EXECUTION_MAX_RPS, amount) * 10.0) / 10.0, EXECUTION_MIN_RPS, EXECUTION_MAX_RPS)


func _resize_handle_at(screen_position: Vector2) -> String:
	if left_panel_open and absf(screen_position.x - _left_panel_rect().end.x) <= PANEL_GAP * 0.5:
		return "left"
	if right_panel_open and absf(screen_position.x - _right_panel_rect().position.x) <= PANEL_GAP * 0.5:
		return "right"
	var middle := _top_panel_rect()
	if top_panel_open and screen_position.x >= middle.position.x and screen_position.x <= middle.end.x and absf(screen_position.y - middle.end.y) <= PANEL_GAP * 0.5:
		return "top"
	var bottom_edge := _bottom_panel_rect().position.y
	if bottom_panel_open and screen_position.x >= middle.position.x and screen_position.x <= middle.end.x and absf(screen_position.y - bottom_edge) <= PANEL_GAP * 0.5:
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
			var max_width := maxf(MIN_LEFT_PANEL_WIDTH, size.x - _right_panel_width() - PANEL_GAP * 4.0 - 190.0)
			left_panel_size = clampf(resize_start_size + (screen_position.x - resize_start_mouse.x), MIN_LEFT_PANEL_WIDTH, max_width)
		"resize_right":
			var max_right_width := maxf(MIN_RIGHT_PANEL_WIDTH, size.x - _left_panel_width() - PANEL_GAP * 4.0 - 190.0)
			right_panel_size = clampf(resize_start_size - (screen_position.x - resize_start_mouse.x), MIN_RIGHT_PANEL_WIDTH, max_right_width)
		"resize_top":
			var max_top_height := maxf(MIN_TOP_PANEL_HEIGHT, size.y - _bottom_panel_height() - PANEL_GAP * 4.0 - 120.0)
			top_panel_size = clampf(resize_start_size + (screen_position.y - resize_start_mouse.y), MIN_TOP_PANEL_HEIGHT, max_top_height)
		"resize_bottom":
			var max_bottom_height := maxf(MIN_BOTTOM_PANEL_HEIGHT, size.y - _top_panel_height() - PANEL_GAP * 4.0 - 120.0)
			bottom_panel_size = clampf(resize_start_size - (screen_position.y - resize_start_mouse.y), MIN_BOTTOM_PANEL_HEIGHT, max_bottom_height)
	_clamp_palette_scroll()
	_update_hover()
	_sync_interface_layout()


func _has_selected_connection() -> bool:
	if selected_connections.size() != 1 or selected_connection < 0 or selected_connection >= connections.size():
		return false
	return not str(connections[selected_connection].get("symbol", "")).is_empty()


func _intensity_inspector_rect() -> Rect2:
	if not _has_selected_connection():
		return Rect2()
	var canvas := _canvas_rect()
	var panel_width := minf(272.0, maxf(canvas.size.x - 20.0, 0.0))
	return Rect2(canvas.end.x - panel_width - 12.0, canvas.end.y - 108.0, panel_width, 96.0)


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
	var low := col_leather_light.darkened(0.58) if active_theme == "light" else col_leather_light
	var high := col_gold_glow.lightened(0.38) if active_theme == "light" else col_gold_glow
	return low.lerp(high, amount)


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
	selected_connections_lookup.clear()
	selected_symbol_connection = -1
	_cancel_intensity_text_edit()
	_sync_interface_diagram()
	_sync_interface_layout()


func _select_connection(index: int, additive := false, select_symbol := false) -> void:
	if index < 0 or index >= connections.size():
		return
	if additive:
		if selected_connections_lookup.has(index):
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


func _select_all_connections() -> void:
	if connections.is_empty():
		return
	selected_connections.clear()
	for index in range(connections.size()):
		selected_connections.append(index)
	_update_primary_selection()
	selected_symbol_connection = -1
	queue_redraw()


func _is_connection_selected(index: int) -> bool:
	return selected_connections_lookup.has(index)


func _update_primary_selection() -> void:
	selected_connections_lookup.clear()
	for selected_index in selected_connections:
		selected_connections_lookup[int(selected_index)] = true
	selected_connection = selected_connections[0] if selected_connections.size() == 1 else -1
	if selected_symbol_connection != selected_connection:
		selected_symbol_connection = -1
	_cancel_intensity_text_edit()
	_sync_interface_diagram()
	_sync_interface_layout()


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
		selected_connections_lookup.clear()
	for index in range(connections.size()):
		if _connection_intersects_selection_rect(index, rect) and not selected_connections_lookup.has(index):
			selected_connections.append(index)
			selected_connections_lookup[index] = true
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


func _cut_selected_connections() -> void:
	if _ritual_is_active() or selected_connections.is_empty():
		return
	_copy_selected_connections_to_clipboard()
	# Cortar sempre remove as células completas. Diferente de Delete em uma
	# runa isolada, não deixa a linha para trás depois de copiar o bloco.
	if diagram.remove_connections(selected_connections):
		_invalidate_symbol_connection_indices()
		_invalidate_sequence_side_multiplier_cache()
		_deselect_connection()
		_clear_diagram_animations()
		queue_redraw()


func _paste_connections_from_clipboard() -> void:
	if _ritual_is_active():
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


func _symbol_at(screen_position: Vector2) -> int:
	var radius := maxf(12.0, 24.0 * zoom)
	var radius_squared := radius * radius
	# A runa fica 20 unidades de mundo acima da linha. Consultar apenas os
	# buckets ao redor do cursor evita varrer milhares de runas fora da tela.
	for index in _connection_hit_candidates(screen_position, 44.0 * zoom):
		var connection: Dictionary = connections[index]
		if str(connection.get("symbol", "")).is_empty():
			continue
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
				var bucket_key := Vector2i(bucket_x, bucket_y)
				var bucket_connections: Array = connection_hit_buckets.get(bucket_key, [])
				bucket_connections.append(connection_index)
				connection_hit_buckets[bucket_key] = bucket_connections
	connection_hit_buckets_dirty = false


func _connection_hit_candidates(screen_position: Vector2, screen_radius := LINE_HIT_RADIUS) -> Array[int]:
	_ensure_connection_hit_buckets()
	var world_position := _screen_to_world(screen_position)
	var world_radius := screen_radius / maxf(zoom, 0.001)
	var first_x := int(floor((world_position.x - world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var last_x := int(floor((world_position.x + world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var first_y := int(floor((world_position.y - world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var last_y := int(floor((world_position.y + world_radius) / CONNECTION_HIT_BUCKET_SIZE))
	var candidates: Array[int] = []
	var seen := {}
	for bucket_x in range(first_x, last_x + 1):
		for bucket_y in range(first_y, last_y + 1):
			var bucket_key := Vector2i(bucket_x, bucket_y)
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
		_sync_interface_diagram()


func _set_connection_intensity(index: int, intensity: int, record_history := true) -> void:
	if diagram.set_intensity(index, intensity, record_history):
		_sync_interface_diagram()


func _add_connection(from: Vector2, to: Vector2) -> void:
	if diagram.add_connection(from, to):
		_invalidate_symbol_connection_indices()
		_invalidate_sequence_side_multiplier_cache()
		_sync_interface_diagram()


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
	_sync_interface_diagram()


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
