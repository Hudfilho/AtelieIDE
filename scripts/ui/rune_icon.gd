@tool
class_name AtelierRuneIcon
extends Control

const RunePainter = preload("res://scripts/rendering/rune_painter.gd")
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")

const DEFAULT_MINIMUM_SIZE := Vector2(24.0, 24.0)
const GLYPH_SIZE_RATIO := 50.0

var _kind := ""
var _intensity := 128
var _icon_color := Color.WHITE

@export var kind: String:
	get:
		return _kind
	set(value):
		if _kind == value:
			return
		_kind = value
		_sync_accessible_text()
		queue_redraw()

@export_range(0, 255, 1) var intensity: int:
	get:
		return _intensity
	set(value):
		var sanitized := clampi(value, 0, 255)
		if _intensity == sanitized:
			return
		_intensity = sanitized
		_sync_accessible_text()
		queue_redraw()

@export var icon_color: Color:
	get:
		return _icon_color
	set(value):
		if _icon_color == value:
			return
		_icon_color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _ready() -> void:
	RunePainter.prepare()
	resized.connect(_on_resized)
	_sync_accessible_text()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_sync_accessible_text()


func set_rune(new_kind: String, new_intensity: int = 128, new_icon_color: Color = Color.WHITE) -> void:
	var sanitized_intensity := clampi(new_intensity, 0, 255)
	if _kind == new_kind and _intensity == sanitized_intensity and _icon_color == new_icon_color:
		return
	_kind = new_kind
	_intensity = sanitized_intensity
	_icon_color = new_icon_color
	_sync_accessible_text()
	queue_redraw()


func set_intensity(new_intensity: int) -> void:
	intensity = new_intensity


func _get_minimum_size() -> Vector2:
	return DEFAULT_MINIMUM_SIZE


func _draw() -> void:
	if _kind.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var rune_scale := minf(size.x, size.y) / GLYPH_SIZE_RATIO
	RunePainter.draw_rune(self, _kind, size * 0.5, rune_scale, _icon_color)


func _on_resized() -> void:
	queue_redraw()


func _sync_accessible_text() -> void:
	if _kind.is_empty():
		tooltip_text = ""
		accessibility_name = ""
		accessibility_description = ""
		return
	var data: Dictionary = RuneCatalog.symbol_data(_kind)
	var rune_label := str(data.get("label", _kind))
	var description := rune_label
	if bool(data.get("takes_operand", false)):
		var template := tr("UI_RUNE_WITH_INTENSITY")
		if template == "UI_RUNE_WITH_INTENSITY":
			template = "%s · intensidade %03d"
		description = template % [rune_label, _intensity]
	tooltip_text = description
	accessibility_name = rune_label
	accessibility_description = description
