class_name AtelierCollapsiblePanel
extends PanelContainer

signal collapse_requested

var header := HBoxContainer.new()
var title_label := Label.new()
var subtitle_label := Label.new()
var collapse_button := Button.new()
var body := VBoxContainer.new()
var content_margin := MarginContainer.new()
var compact_layer := Control.new()
var compact_button := Button.new()
var compact_title_label := Label.new()
var expanded := true
var _title_key := ""
var _subtitle_key := ""
var _accessible_description_key := ""
var _requested_panel_rect := Rect2()
var _panel_rect_apply_pending := false


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	_build_tree()
	resized.connect(_layout_compact)


func _build_tree() -> void:
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(column)

	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(header)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 16)
	header.add_child(title_label)
	collapse_button.custom_minimum_size = Vector2(30.0, 30.0)
	collapse_button.focus_mode = Control.FOCUS_ALL
	collapse_button.pressed.connect(_on_collapse_pressed)
	header.add_child(collapse_button)

	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(subtitle_label)
	var separator := HSeparator.new()
	column.add_child(separator)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	compact_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_layer.visible = false
	add_child(compact_layer)
	compact_button.focus_mode = Control.FOCUS_ALL
	compact_button.pressed.connect(_on_collapse_pressed)
	compact_layer.add_child(compact_button)
	compact_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compact_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	compact_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	compact_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_layer.add_child(compact_title_label)


func configure(title_key: String, subtitle_key: String, accessible_description: String) -> void:
	_title_key = title_key
	_subtitle_key = subtitle_key
	_accessible_description_key = accessible_description
	_refresh_strings()


func set_expanded(value: bool, direction_when_open: String = "▼", direction_when_closed: String = "▲") -> void:
	expanded = value
	content_margin.visible = value
	compact_layer.visible = not value
	collapse_button.text = direction_when_open if value else direction_when_closed
	collapse_button.accessibility_name = tr("UI_PANEL_COLLAPSE") if value else tr("UI_PANEL_EXPAND")
	collapse_button.tooltip_text = collapse_button.accessibility_name
	compact_button.text = direction_when_closed
	compact_button.accessibility_name = collapse_button.accessibility_name
	compact_button.tooltip_text = compact_button.accessibility_name
	update_minimum_size()
	_layout_compact()


func set_panel_rect(panel_rect: Rect2) -> void:
	_requested_panel_rect = panel_rect
	_apply_requested_panel_rect()
	if not _panel_rect_apply_pending:
		_panel_rect_apply_pending = true
		_apply_requested_panel_rect_deferred.call_deferred()
	_layout_compact()


func _apply_requested_panel_rect_deferred() -> void:
	_panel_rect_apply_pending = false
	_apply_requested_panel_rect()


func _apply_requested_panel_rect() -> void:
	position = _requested_panel_rect.position
	size = _requested_panel_rect.size


func apply_ui_theme(ui_theme: Theme) -> void:
	theme = ui_theme
	update_minimum_size()


func _get_minimum_size() -> Vector2:
	if not expanded:
		return Vector2.ZERO
	return content_margin.get_combined_minimum_size() if content_margin != null else Vector2.ZERO


func _on_collapse_pressed() -> void:
	collapse_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


func _refresh_strings() -> void:
	if _title_key.is_empty():
		return
	var localized_title := tr(_title_key)
	title_label.text = localized_title
	compact_title_label.text = localized_title
	subtitle_label.text = tr(_subtitle_key)
	accessibility_name = localized_title
	accessibility_description = tr(_accessible_description_key)
	var action_text := tr("UI_PANEL_COLLAPSE") if expanded else tr("UI_PANEL_EXPAND")
	collapse_button.accessibility_name = action_text
	collapse_button.tooltip_text = action_text
	compact_button.accessibility_name = action_text
	compact_button.tooltip_text = action_text


func _layout_compact() -> void:
	if compact_layer == null or not compact_layer.visible:
		return
	var area := compact_layer.size
	if area.x < area.y:
		compact_button.position = Vector2(maxf((area.x - 30.0) * 0.5, 0.0), 2.0)
		compact_button.size = Vector2(minf(30.0, area.x), 30.0)
		compact_title_label.rotation = -PI * 0.5
		compact_title_label.position = Vector2(2.0, area.y - 4.0)
		compact_title_label.size = Vector2(maxf(area.y - 42.0, 0.0), maxf(area.x - 4.0, 0.0))
	else:
		compact_button.position = Vector2(maxf(area.x - 32.0, 0.0), maxf((area.y - 30.0) * 0.5, 0.0))
		compact_button.size = Vector2(minf(30.0, area.x), minf(30.0, area.y))
		compact_title_label.rotation = 0.0
		compact_title_label.position = Vector2(4.0, 0.0)
		compact_title_label.size = Vector2(maxf(area.x - 40.0, 0.0), area.y)
