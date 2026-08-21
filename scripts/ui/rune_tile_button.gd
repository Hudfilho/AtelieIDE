class_name AtelierRuneTileButton
extends Button

const RuneIcon = preload("res://scripts/ui/rune_icon.gd")
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")

var kind := ""
var rune_label := ""
var rune_description := ""
var default_intensity := 128
var rune_color := Color.WHITE
var rune_icon: Control
var symbol_data: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(52.0, 52.0)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rune_icon = RuneIcon.new()
	rune_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rune_icon)
	resized.connect(_layout_icon)
	_layout_icon()


func set_symbol_data(data: Dictionary) -> void:
	symbol_data = data
	kind = str(data.get("kind", ""))
	_refresh_strings()
	if rune_icon != null:
		rune_icon.call("set_rune", kind, default_intensity, rune_color)


func _refresh_strings() -> void:
	if symbol_data.is_empty():
		return
	rune_label = str(symbol_data.get("label", kind))
	rune_description = RuneCatalog.localized_description(kind)
	tooltip_text = "%s — %s" % [rune_label, rune_description]
	accessibility_name = rune_label
	accessibility_description = rune_description


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


func set_icon_color(color: Color) -> void:
	rune_color = color
	if rune_icon != null:
		rune_icon.call("set_rune", kind, default_intensity, rune_color)


func _layout_icon() -> void:
	if rune_icon == null:
		return
	rune_icon.position = Vector2(7.0, 7.0)
	rune_icon.size = Vector2(maxf(size.x - 14.0, 8.0), maxf(size.y - 14.0, 8.0))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if kind.is_empty():
		return null
	var preview: Control = RuneIcon.new()
	preview.custom_minimum_size = Vector2(42.0, 42.0)
	preview.size = Vector2(42.0, 42.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.call("set_rune", kind, default_intensity, rune_color)
	set_drag_preview(preview)
	return {
		"type": "atelier_rune",
		"kind": kind,
		"intensity": default_intensity,
	}


func _make_custom_tooltip(for_text: String) -> Object:
	var card := PanelContainer.new()
	card.theme = theme
	var viewport_width := get_viewport_rect().size.x
	var card_width := minf(320.0, maxf(viewport_width - 32.0, 180.0))
	card.custom_minimum_size.x = card_width
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var description := Label.new()
	description.text = for_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = card_width - 20.0
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(description)
	return card
