class_name AtelierStackPanel
extends AtelierCollapsiblePanel

var count_label := Label.new()
var stack_list := ItemList.new()
var current_values: Array = []


func _ready() -> void:
	super._ready()
	configure("UI_STACK_TITLE", "UI_STACK_SUBTITLE", "UI_STACK_ACCESSIBLE_DESCRIPTION")
	set_expanded(true, "▶", "◀")
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.add_theme_font_size_override("font_size", 11)
	body.add_child(count_label)
	stack_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack_list.auto_height = false
	stack_list.allow_reselect = true
	stack_list.focus_mode = Control.FOCUS_ALL
	stack_list.accessibility_name = tr("UI_STACK_LIST")
	body.add_child(stack_list)
	_refresh_stack()


func set_expanded(value: bool, direction_when_open: String = "▶", direction_when_closed: String = "◀") -> void:
	super.set_expanded(value, direction_when_open, direction_when_closed)


func set_stack(values: Array) -> void:
	if current_values == values:
		return
	current_values = values.duplicate()
	_refresh_stack()


func _refresh_stack() -> void:
	stack_list.clear()
	count_label.text = tr("UI_STACK_COUNT") % current_values.size()
	if current_values.is_empty():
		stack_list.add_item(tr("UI_STACK_EMPTY"))
		stack_list.set_item_disabled(0, true)
		stack_list.accessibility_description = tr("UI_STACK_EMPTY")
		return
	for reverse_index in range(current_values.size() - 1, -1, -1):
		var prefix := tr("UI_STACK_TOP_PREFIX") if reverse_index == current_values.size() - 1 else ""
		stack_list.add_item("%s%03d" % [prefix, int(current_values[reverse_index])])
	stack_list.accessibility_description = tr("UI_STACK_ACCESSIBLE_CONTENT") % current_values.size()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		stack_list.accessibility_name = tr("UI_STACK_LIST")
		_refresh_stack()
