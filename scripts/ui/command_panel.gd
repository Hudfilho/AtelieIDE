class_name AtelierCommandPanel
extends AtelierCollapsiblePanel

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneIcon = preload("res://scripts/ui/rune_icon.gd")

signal connection_selected(connection_index: int, additive: bool)

const ROW_HEIGHT := 64.0
const EXTRA_POOL_ROWS := 3

var scroll := ScrollContainer.new()
var content := Control.new()
var row_pool: Array[Button] = []
var entries: Array[Dictionary] = []
var catalog_by_kind: Dictionary = {}
var rune_color := Color.WHITE
var focused_entry_index := -1
var scroll_drag_pending := false
var scroll_dragging := false
var scroll_drag_start_pointer := Vector2.ZERO
var scroll_drag_start_value := 0.0
var suppress_next_row_press := false


func _ready() -> void:
	super._ready()
	configure("UI_GRIMOIRE_TITLE", "UI_GRIMOIRE_SUBTITLE", "UI_GRIMOIRE_ACCESSIBLE_DESCRIPTION")
	set_expanded(true, "◀", "▶")
	_build_catalog_index()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.scroll_deadzone = 5
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.clip_contents = true
	scroll.accessibility_name = tr("UI_GRIMOIRE_LIST")
	body.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	scroll.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	scroll.resized.connect(_ensure_row_pool)
	scroll.gui_input.connect(_on_scroll_gui_input)
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_ALL


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		scroll.accessibility_name = tr("UI_GRIMOIRE_LIST")
		_localize_entries()
		_refresh_visible_rows()


func _localize_entries() -> void:
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var kind := str(entry.get("kind", ""))
		var data: Dictionary = catalog_by_kind.get(kind, {})
		var extra := RuneCatalog.localized_extra(kind)
		if bool(data.get("takes_operand", false)):
			extra = "%s: %03d" % [extra, int(entry.get("intensity", 128))]
		entry["extra"] = extra
		entries[entry_index] = entry


func set_expanded(value: bool, direction_when_open: String = "◀", direction_when_closed: String = "▶") -> void:
	super.set_expanded(value, direction_when_open, direction_when_closed)


func set_entries(
		connections: Array[Dictionary],
		selected_indices: Array[int],
		intensity_overrides: Dictionary
) -> void:
	var selected_lookup: Dictionary = {}
	for selected_index in selected_indices:
		selected_lookup[int(selected_index)] = true
	var next_entries: Array[Dictionary] = []
	for connection_index in range(connections.size()):
		var connection: Dictionary = connections[connection_index]
		var kind := str(connection.get("symbol", ""))
		if kind.is_empty():
			continue
		var data: Dictionary = catalog_by_kind.get(kind, {})
		var intensity := clampi(int(intensity_overrides.get(connection_index, connection.get("intensity", 128))), 0, 255)
		var extra := RuneCatalog.localized_extra(kind)
		if bool(data.get("takes_operand", false)):
			extra = "%s: %03d" % [extra, intensity]
		next_entries.append({
			"connection_index": connection_index,
			"kind": kind,
			"label": str(data.get("label", kind)),
			"extra": extra,
			"intensity": intensity,
			"selected": selected_lookup.has(connection_index),
		})
	if entries == next_entries:
		return
	entries = next_entries
	content.custom_minimum_size = Vector2(0.0, maxf(float(entries.size()) * ROW_HEIGHT, scroll.size.y))
	_ensure_row_pool()
	_refresh_visible_rows()


func apply_palette(palette: Dictionary) -> void:
	rune_color = palette.get("parch_ink", Color.WHITE)
	_refresh_visible_rows()


func _build_catalog_index() -> void:
	for raw_symbol: Dictionary in RuneCatalog.SYMBOLS:
		catalog_by_kind[str(raw_symbol["kind"])] = raw_symbol


func _ensure_row_pool() -> void:
	var wanted := maxi(int(ceil(scroll.size.y / ROW_HEIGHT)) + EXTRA_POOL_ROWS, 1)
	while row_pool.size() < wanted:
		var row := _create_row()
		row_pool.append(row)
		content.add_child(row)
	while row_pool.size() > wanted:
		var removed: Button = row_pool.pop_back()
		content.remove_child(removed)
		removed.queue_free()
	_refresh_visible_rows()


func _create_row() -> Button:
	var row := Button.new()
	row.toggle_mode = true
	row.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	row.focus_mode = Control.FOCUS_ALL
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.pressed.connect(_on_row_pressed.bind(row))
	row.focus_entered.connect(_on_row_focus_entered.bind(row))
	row.gui_input.connect(_on_row_gui_input.bind(row))
	var rune := RuneIcon.new()
	rune.name = "RuneIcon"
	rune.position = Vector2(10.0, 10.0)
	rune.size = Vector2(38.0, 38.0)
	row.add_child(rune)
	var label := Label.new()
	label.name = "Label"
	label.position = Vector2(58.0, 8.0)
	label.size = Vector2(150.0, 22.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	var extra := Label.new()
	extra.name = "Extra"
	extra.position = Vector2(58.0, 31.0)
	extra.size = Vector2(160.0, 18.0)
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra.add_theme_font_size_override("font_size", 11)
	row.add_child(extra)
	return row


func _on_scroll_changed(_value: float) -> void:
	_refresh_visible_rows()


func _refresh_visible_rows() -> void:
	if row_pool.is_empty():
		return
	var first := maxi(int(floor(float(scroll.scroll_vertical) / ROW_HEIGHT)), 0)
	for pool_index in range(row_pool.size()):
		var row := row_pool[pool_index]
		var entry_index := first + pool_index
		if entry_index >= entries.size():
			row.visible = false
			continue
		var entry: Dictionary = entries[entry_index]
		row.visible = true
		row.position = Vector2(4.0, float(entry_index) * ROW_HEIGHT + 3.0)
		row.size = Vector2(maxf(scroll.size.x - 14.0, 40.0), ROW_HEIGHT - 6.0)
		row.set_meta("connection_index", int(entry["connection_index"]))
		row.set_meta("entry_index", entry_index)
		row.button_pressed = bool(entry["selected"])
		row.accessibility_name = "%s, %s" % [entry["label"], entry["extra"]]
		row.tooltip_text = row.accessibility_name
		var rune: Control = row.get_node("RuneIcon")
		rune.call("set_rune", str(entry["kind"]), int(entry["intensity"]), rune_color)
		var label: Label = row.get_node("Label")
		label.text = str(entry["label"])
		label.size.x = maxf(row.size.x - 68.0, 20.0)
		var extra: Label = row.get_node("Extra")
		extra.text = str(entry["extra"])
		extra.size.x = maxf(row.size.x - 68.0, 20.0)


func _on_row_pressed(row: Button) -> void:
	if scroll_dragging or suppress_next_row_press:
		_refresh_visible_rows()
		return
	var connection_index := int(row.get_meta("connection_index", -1))
	if connection_index >= 0:
		connection_selected.emit(connection_index, Input.is_key_pressed(KEY_CTRL))


func _on_row_focus_entered(row: Button) -> void:
	focused_entry_index = int(row.get_meta("entry_index", -1))


func _on_row_gui_input(event: InputEvent, row: Button) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var offset := 0
		match event.keycode:
			KEY_UP:
				offset = -1
			KEY_DOWN:
				offset = 1
			KEY_PAGEUP:
				offset = -maxi(row_pool.size() - 2, 1)
			KEY_PAGEDOWN:
				offset = maxi(row_pool.size() - 2, 1)
			KEY_HOME:
				_focus_entry(0)
				row.accept_event()
				return
			KEY_END:
				_focus_entry(entries.size() - 1)
				row.accept_event()
				return
		if offset != 0:
			_focus_entry(int(row.get_meta("entry_index", 0)) + offset)
			row.accept_event()
			return
	_handle_drag_scroll_input(event, row)


func _on_scroll_gui_input(event: InputEvent) -> void:
	_handle_drag_scroll_input(event, scroll)


func _handle_drag_scroll_input(event: InputEvent, source: Control) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			scroll_drag_pending = true
			scroll_dragging = false
			scroll_drag_start_pointer = get_viewport().get_mouse_position()
			scroll_drag_start_value = float(scroll.scroll_vertical)
		else:
			if scroll_dragging:
				suppress_next_row_press = true
				_reset_suppressed_press.call_deferred()
			scroll_drag_pending = false
			scroll_dragging = false
	elif event is InputEventMouseMotion and scroll_drag_pending and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		var movement := get_viewport().get_mouse_position() - scroll_drag_start_pointer
		if not scroll_dragging and absf(movement.y) >= 4.0:
			scroll_dragging = true
		if scroll_dragging:
			scroll.scroll_vertical = int(round(scroll_drag_start_value - movement.y))
			source.accept_event()


func _reset_suppressed_press() -> void:
	suppress_next_row_press = false


func _focus_entry(entry_index: int) -> void:
	if entries.is_empty():
		return
	focused_entry_index = clampi(entry_index, 0, entries.size() - 1)
	var row_top := float(focused_entry_index) * ROW_HEIGHT
	var row_bottom := row_top + ROW_HEIGHT
	if row_top < float(scroll.scroll_vertical):
		scroll.scroll_vertical = int(row_top)
	elif row_bottom > float(scroll.scroll_vertical) + scroll.size.y:
		scroll.scroll_vertical = int(ceil(row_bottom - scroll.size.y))
	_refresh_visible_rows()
	for row: Button in row_pool:
		if row.visible and int(row.get_meta("entry_index", -1)) == focused_entry_index:
			row.call_deferred("grab_focus")
			break
