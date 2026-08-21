class_name AtelierIntensityPanel
extends PanelContainer

const RuneIcon = preload("res://scripts/ui/rune_icon.gd")

signal drag_started
signal value_previewed(value: int)
signal drag_finished(value: int, changed: bool)
signal value_committed(value: int)

var rune_icon: Control
var title_label := Label.new()
var rune_name_label := Label.new()
var slider := HSlider.new()
var value_input := SpinBox.new()
var syncing := false
var rune_color := Color.WHITE


func _ready() -> void:
	clip_contents = true
	accessibility_name = tr("UI_INTENSITY_TITLE")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	rune_icon = RuneIcon.new()
	rune_icon.custom_minimum_size = Vector2(38.0, 38.0)
	header.add_child(rune_icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(names)
	title_label.text = tr("UI_INTENSITY_TITLE")
	title_label.add_theme_font_size_override("font_size", 11)
	names.add_child(title_label)
	rune_name_label.add_theme_font_size_override("font_size", 15)
	names.add_child(rune_name_label)
	_configure_value_input()
	header.add_child(value_input)
	_configure_slider()
	column.add_child(slider)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


func _refresh_strings() -> void:
	accessibility_name = tr("UI_INTENSITY_TITLE")
	title_label.text = tr("UI_INTENSITY_TITLE")
	slider.accessibility_name = tr("UI_INTENSITY_SLIDER_ACCESSIBLE")
	slider.tooltip_text = tr("UI_TOOLTIP_INTENSITY")
	value_input.accessibility_name = tr("UI_INTENSITY_VALUE_ACCESSIBLE")
	value_input.tooltip_text = tr("UI_TOOLTIP_INTENSITY")


func _configure_slider() -> void:
	slider.min_value = 0.0
	slider.max_value = 255.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.accessibility_name = tr("UI_INTENSITY_SLIDER_ACCESSIBLE")
	slider.tooltip_text = tr("UI_TOOLTIP_INTENSITY")
	slider.drag_started.connect(_on_drag_started)
	slider.drag_ended.connect(_on_drag_ended)
	slider.value_changed.connect(_on_slider_value_changed)


func _configure_value_input() -> void:
	value_input.min_value = 0.0
	value_input.max_value = 255.0
	value_input.step = 1.0
	value_input.allow_greater = false
	value_input.allow_lesser = false
	value_input.custom_minimum_size = Vector2(72.0, 30.0)
	value_input.focus_mode = Control.FOCUS_ALL
	value_input.accessibility_name = tr("UI_INTENSITY_VALUE_ACCESSIBLE")
	value_input.tooltip_text = tr("UI_TOOLTIP_INTENSITY")
	value_input.value_changed.connect(_on_input_value_changed)


func set_selection(kind: String, rune_label: String, intensity: int, has_selection: bool) -> void:
	visible = has_selection
	if not has_selection:
		return
	syncing = true
	rune_name_label.text = rune_label
	slider.value = clampi(intensity, 0, 255)
	value_input.value = slider.value
	rune_icon.call("set_rune", kind, int(slider.value), rune_color)
	accessibility_description = "%s, %d" % [rune_label, int(slider.value)]
	syncing = false


func set_panel_rect(panel_rect: Rect2) -> void:
	position = panel_rect.position
	size = panel_rect.size


func apply_ui_theme(ui_theme: Theme) -> void:
	theme = ui_theme


func apply_palette(palette: Dictionary) -> void:
	rune_color = palette.get("seal_glyph", Color.WHITE)
	if rune_icon != null:
		rune_icon.icon_color = rune_color


func _on_drag_started() -> void:
	drag_started.emit()


func _on_drag_ended(changed: bool) -> void:
	drag_finished.emit(int(slider.value), changed)


func _on_slider_value_changed(value: float) -> void:
	if syncing:
		return
	syncing = true
	value_input.value = value
	rune_icon.call("set_intensity", int(value))
	syncing = false
	value_previewed.emit(int(value))


func _on_input_value_changed(value: float) -> void:
	if syncing:
		return
	syncing = true
	slider.value = value
	rune_icon.call("set_intensity", int(value))
	syncing = false
	value_committed.emit(int(value))
