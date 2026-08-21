class_name AtelierPalettePanel
extends AtelierCollapsiblePanel

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneTileButton = preload("res://scripts/ui/rune_tile_button.gd")

signal play_requested
signal pause_requested
signal step_requested
signal stop_requested
signal theme_requested
signal speed_changed(value: float)

const MIN_RPS := 0.1
const MAX_RPS := 100.0

var play_button := Button.new()
var pause_button := Button.new()
var step_button := Button.new()
var stop_button := Button.new()
var theme_button := Button.new()
var more_button := MenuButton.new()
var speed_label := Label.new()
var speed_slider := HSlider.new()
var compact_speed_row := HBoxContainer.new()
var rune_scroll := ScrollContainer.new()
var rune_strip := HBoxContainer.new()
var left_spacer := Control.new()
var right_spacer := Control.new()
var rune_color := Color.WHITE


func _ready() -> void:
	super._ready()
	configure("UI_PALETTE_TITLE", "UI_PALETTE_SUBTITLE", "UI_PALETTE_ACCESSIBLE_DESCRIPTION")
	set_expanded(true, "▲", "▼")
	_build_toolbar()
	_build_rune_strip()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	_refresh_control_strings()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_control_strings()


func _build_toolbar() -> void:
	_configure_toolbar_button(play_button, "▶", "UI_PLAY", play_requested.emit)
	_configure_toolbar_button(pause_button, "Ⅱ", "UI_PAUSE", pause_requested.emit)
	_configure_toolbar_button(step_button, "▷│", "UI_STEP", step_requested.emit)
	_configure_toolbar_button(stop_button, "■", "UI_STOP", stop_requested.emit)
	_configure_toolbar_button(theme_button, "☾", "UI_THEME_TOGGLE", theme_requested.emit)

	var insert_at := maxi(header.get_child_count() - 1, 0)
	for control: Control in [play_button, pause_button, step_button, stop_button, theme_button, more_button]:
		header.add_child(control)
		header.move_child(control, insert_at)
		insert_at += 1

	more_button.text = "⋯"
	more_button.custom_minimum_size = Vector2(34.0, 30.0)
	var popup := more_button.get_popup()
	popup.id_pressed.connect(_on_more_control_pressed)

	speed_label.text = _speed_text(speed_slider.value)
	speed_label.custom_minimum_size.x = 72.0
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	compact_speed_row.add_child(speed_label)
	speed_slider.min_value = MIN_RPS
	speed_slider.max_value = MAX_RPS
	speed_slider.step = 0.1
	speed_slider.value = MIN_RPS
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.custom_minimum_size.x = 90.0
	speed_slider.focus_mode = Control.FOCUS_ALL
	speed_slider.accessibility_name = tr("UI_EXECUTION_SPEED")
	speed_slider.value_changed.connect(_on_speed_changed)
	compact_speed_row.add_child(speed_slider)
	body.add_child(compact_speed_row)


func _configure_toolbar_button(button: Button, glyph: String, text_key: String, callback: Callable) -> void:
	button.text = glyph
	button.custom_minimum_size = Vector2(34.0, 30.0)
	button.focus_mode = Control.FOCUS_ALL
	button.accessibility_name = tr(text_key)
	button.tooltip_text = tr(text_key)
	button.pressed.connect(callback)


func _build_rune_strip() -> void:
	rune_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	rune_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rune_scroll.scroll_deadzone = 5
	rune_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rune_scroll.accessibility_name = tr("UI_PALETTE_LIST")
	body.add_child(rune_scroll)
	rune_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_strip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rune_scroll.add_child(rune_strip)
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rune_strip.add_child(left_spacer)
	for raw_symbol: Dictionary in RuneCatalog.SYMBOLS:
		var tile: Button = RuneTileButton.new()
		tile.call_deferred("set_symbol_data", raw_symbol)
		rune_strip.add_child(tile)
	rune_strip.add_child(right_spacer)
	rune_scroll.resized.connect(_center_rune_strip)
	_center_rune_strip()


func set_expanded(value: bool, direction_when_open: String = "▲", direction_when_closed: String = "▼") -> void:
	super.set_expanded(value, direction_when_open, direction_when_closed)
	_update_responsive_layout()


func set_execution_state(running: bool, paused: bool, can_step: bool) -> void:
	play_button.disabled = running and not paused
	pause_button.disabled = not running or paused
	step_button.disabled = not can_step
	stop_button.disabled = not running and not paused
	play_button.accessibility_description = tr("UI_RESUME_DESCRIPTION") if paused else tr("UI_PLAY_DESCRIPTION")


func set_speed(value: float) -> void:
	speed_slider.set_value_no_signal(clampf(value, MIN_RPS, MAX_RPS))
	speed_label.text = _speed_text(speed_slider.value)


func set_theme_name(theme_name: String) -> void:
	theme_button.text = "☀" if theme_name == "light" else "☾"


func apply_palette(palette: Dictionary) -> void:
	rune_color = palette.get("seal_glyph", Color.WHITE)
	for child in rune_strip.get_children():
		if child is AtelierRuneTileButton:
			child.set_icon_color(rune_color)


func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var compact := size.x < 430.0
	title_label.visible = expanded and not compact
	subtitle_label.visible = expanded and size.x >= 330.0
	pause_button.visible = not compact
	step_button.visible = not compact
	stop_button.visible = not compact
	theme_button.visible = not compact
	more_button.visible = compact
	compact_speed_row.visible = expanded
	_center_rune_strip()


func _center_rune_strip() -> void:
	if not is_inside_tree():
		return
	var tile_count := RuneCatalog.SYMBOLS.size()
	var content_width := float(tile_count) * 52.0 + float(maxi(tile_count - 1, 0)) * 6.0
	rune_strip.custom_minimum_size.x = maxf(content_width + 12.0, rune_scroll.size.x)


func _on_speed_changed(value: float) -> void:
	speed_label.text = _speed_text(value)
	speed_changed.emit(value)


func _speed_text(value: float) -> String:
	return tr("UI_EXECUTION_SPEED") % value


func _on_more_control_pressed(control_id: int) -> void:
	match control_id:
		0:
			pause_requested.emit()
		1:
			step_requested.emit()
		2:
			stop_requested.emit()
		3:
			theme_requested.emit()


func _refresh_control_strings() -> void:
	play_button.accessibility_name = tr("UI_PLAY")
	play_button.tooltip_text = tr("UI_TOOLTIP_PLAY")
	pause_button.accessibility_name = tr("UI_PAUSE")
	pause_button.tooltip_text = tr("UI_TOOLTIP_PAUSE")
	step_button.accessibility_name = tr("UI_STEP")
	step_button.tooltip_text = tr("UI_TOOLTIP_STEP")
	stop_button.accessibility_name = tr("UI_STOP")
	stop_button.tooltip_text = tr("UI_TOOLTIP_STOP")
	theme_button.accessibility_name = tr("UI_THEME_TOGGLE")
	theme_button.tooltip_text = tr("UI_THEME_TOGGLE")
	more_button.accessibility_name = tr("UI_MORE_CONTROLS")
	more_button.tooltip_text = tr("UI_MORE_CONTROLS")
	speed_slider.accessibility_name = tr("UI_TOOLTIP_EXECUTION_SPEED")
	speed_slider.tooltip_text = tr("UI_TOOLTIP_EXECUTION_SPEED")
	speed_label.text = _speed_text(speed_slider.value)
	rune_scroll.accessibility_name = tr("UI_PALETTE_LIST")
	var popup := more_button.get_popup()
	popup.clear()
	popup.add_item(tr("UI_PAUSE"), 0)
	popup.add_item(tr("UI_STEP"), 1)
	popup.add_item(tr("UI_STOP"), 2)
	popup.add_separator()
	popup.add_item(tr("UI_THEME_TOGGLE"), 3)
