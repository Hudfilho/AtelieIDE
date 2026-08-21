class_name AtelierInterface
extends Control

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const UITheme = preload("res://scripts/ui/atelier_ui_theme.gd")
const CommandPanel = preload("res://scripts/ui/command_panel.gd")
const PalettePanel = preload("res://scripts/ui/palette_panel.gd")
const StackPanel = preload("res://scripts/ui/stack_panel.gd")
const IntensityPanel = preload("res://scripts/ui/intensity_panel.gd")
const PerformanceOverlay = preload("res://scripts/ui/performance_overlay.gd")
const ExecutionPanelScene = preload("res://scenes/ui/ExecutionPanel.tscn")
const ExecutionLog = preload("res://scripts/ui/execution_log.gd")

signal panel_toggle_requested(panel: String)
signal connection_selected(connection_index: int, additive: bool)
signal play_requested
signal pause_requested
signal step_requested
signal stop_requested
signal theme_requested
signal speed_changed(value: float)
signal intensity_drag_started
signal intensity_previewed(value: int)
signal intensity_drag_finished(value: int, changed: bool)
signal intensity_committed(value: int)
signal bottom_resize_started(pointer_y: float)
signal bottom_resize_dragged(pointer_y: float)
signal bottom_resize_finished

var command_panel: AtelierCommandPanel
var palette_panel: AtelierPalettePanel
var execution_panel: AtelierExecutionPanel
var stack_panel: AtelierStackPanel
var intensity_panel: AtelierIntensityPanel
var performance_overlay: AtelierPerformanceOverlay
var execution_log: AtelierExecutionLog = ExecutionLog.new()
var ui_theme: Theme
var palette: Dictionary = {}
var active_theme := "dark"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	accessibility_name = tr("UI_APP_NAME")
	_build_panels()
	_connect_signals()
	execution_panel.bind_log(execution_log)


func _build_panels() -> void:
	command_panel = CommandPanel.new()
	command_panel.name = "CommandPanel"
	add_child(command_panel)
	palette_panel = PalettePanel.new()
	palette_panel.name = "PalettePanel"
	add_child(palette_panel)
	execution_panel = ExecutionPanelScene.instantiate()
	execution_panel.name = "ExecutionPanel"
	add_child(execution_panel)
	stack_panel = StackPanel.new()
	stack_panel.name = "StackPanel"
	add_child(stack_panel)
	intensity_panel = IntensityPanel.new()
	intensity_panel.name = "IntensityPanel"
	add_child(intensity_panel)
	performance_overlay = PerformanceOverlay.new()
	performance_overlay.name = "PerformanceOverlay"
	performance_overlay.visible = false
	add_child(performance_overlay)


func _connect_signals() -> void:
	command_panel.collapse_requested.connect(panel_toggle_requested.emit.bind("left"))
	command_panel.connection_selected.connect(connection_selected.emit)
	palette_panel.collapse_requested.connect(panel_toggle_requested.emit.bind("top"))
	palette_panel.play_requested.connect(play_requested.emit)
	palette_panel.pause_requested.connect(pause_requested.emit)
	palette_panel.step_requested.connect(step_requested.emit)
	palette_panel.stop_requested.connect(stop_requested.emit)
	palette_panel.theme_requested.connect(theme_requested.emit)
	palette_panel.speed_changed.connect(speed_changed.emit)
	execution_panel.collapse_requested.connect(panel_toggle_requested.emit.bind("bottom"))
	execution_panel.resize_started.connect(bottom_resize_started.emit)
	execution_panel.resize_dragged.connect(bottom_resize_dragged.emit)
	execution_panel.resize_finished.connect(bottom_resize_finished.emit)
	stack_panel.collapse_requested.connect(panel_toggle_requested.emit.bind("right"))
	intensity_panel.drag_started.connect(intensity_drag_started.emit)
	intensity_panel.value_previewed.connect(intensity_previewed.emit)
	intensity_panel.drag_finished.connect(intensity_drag_finished.emit)
	intensity_panel.value_committed.connect(intensity_committed.emit)


func apply_palette(theme_name: String, palette_table: Dictionary) -> void:
	active_theme = theme_name
	palette = palette_table.duplicate()
	ui_theme = UITheme.build(palette)
	command_panel.apply_ui_theme(ui_theme)
	command_panel.apply_palette(palette)
	palette_panel.apply_ui_theme(ui_theme)
	palette_panel.apply_palette(palette)
	palette_panel.set_theme_name(active_theme)
	execution_panel.apply_palette(palette)
	stack_panel.apply_ui_theme(ui_theme)
	intensity_panel.apply_ui_theme(ui_theme)
	intensity_panel.apply_palette(palette)
	performance_overlay.theme = ui_theme


func sync_layout(
		left_rect: Rect2,
		top_rect: Rect2,
		bottom_rect: Rect2,
		right_rect: Rect2,
		inspector_rect: Rect2,
		left_open: bool,
		top_open: bool,
		bottom_open: bool,
		right_open: bool
) -> void:
	command_panel.set_expanded(left_open, "◀", "▶")
	command_panel.set_panel_rect(left_rect)
	palette_panel.set_expanded(top_open, "▲", "▼")
	palette_panel.set_panel_rect(top_rect)
	execution_panel.set_panel_rect(bottom_rect, bottom_open)
	stack_panel.set_expanded(right_open, "▶", "◀")
	stack_panel.set_panel_rect(right_rect)
	intensity_panel.set_panel_rect(inspector_rect)
	var overlay_width := minf(350.0, maxf(top_rect.size.x - 24.0, 220.0))
	performance_overlay.set_overlay_rect(Rect2(
			Vector2(top_rect.position.x + 12.0, top_rect.end.y + 12.0),
			Vector2(overlay_width, 126.0)))


func sync_diagram(
		connections: Array[Dictionary],
		selected_indices: Array[int],
		intensity_overrides: Dictionary,
		selected_connection: int
) -> void:
	command_panel.set_entries(connections, selected_indices, intensity_overrides)
	var has_selection := selected_connection >= 0 and selected_connection < connections.size()
	if has_selection:
		var connection: Dictionary = connections[selected_connection]
		var kind := str(connection.get("symbol", ""))
		has_selection = not kind.is_empty()
		if has_selection:
			var data: Dictionary = RuneCatalog.symbol_data(kind)
			var intensity := clampi(int(connection.get("intensity", 128)), 0, 255)
			intensity_panel.set_selection(kind, str(data.get("label", kind)), intensity, true)
	if not has_selection:
		intensity_panel.set_selection("", "", 0, false)


func sync_execution(
		execution_state: Dictionary,
		running: bool,
		paused: bool,
		can_step: bool,
		speed_rps: float
) -> void:
	var stack: Array = execution_state.get("stack", [])
	stack_panel.set_stack(stack)
	palette_panel.set_execution_state(running, paused, can_step)
	palette_panel.set_speed(speed_rps)


func clear_execution_log() -> void:
	execution_log.clear()


func append_output(text: String) -> void:
	execution_log.append_output(text)


func append_warning(text: String) -> void:
	execution_log.append_warning(text)


func append_error(text: String) -> void:
	execution_log.append_error(text)


func set_performance_visible(value: bool) -> void:
	performance_overlay.set_enabled(value)


func record_performance_sample(metrics: Dictionary) -> void:
	performance_overlay.record_sample(metrics)


func text_control_has_focus() -> bool:
	var focus_owner := get_viewport().gui_get_focus_owner()
	return focus_owner is RichTextLabel or focus_owner is LineEdit or focus_owner is TextEdit or focus_owner is SpinBox
