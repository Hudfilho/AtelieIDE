class_name AtelierExecutionPanel
extends Control

const Palette = preload("res://scripts/core/atelier_palette.gd")
const UITheme = preload("res://scripts/ui/atelier_ui_theme.gd")
const ExecutionLog = preload("res://scripts/ui/execution_log.gd")
const Strings = preload("res://scripts/ui/atelier_strings.gd")

signal collapse_requested
signal resize_started(pointer_y: float)
signal resize_dragged(pointer_y: float)
signal resize_finished

var _log: AtelierExecutionLog
var _expanded := true
var _resize_dragging := false
var _has_output := false
var _has_diagnostics := false
var _palette: Dictionary = {}
var _output_color := Color("e3cea2")
var _warning_color := Color("d8c783")
var _error_color := Color("ff8791")
var _faint_color := Color("8a7c5f")

@onready var _resize_handle: Control = %ResizeHandle
@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _collapse_button: Button = %CollapseButton
@onready var _header_separator: HSeparator = %HeaderSeparator
@onready var _content_split: HSplitContainer = %ContentSplit
@onready var _output_title: Label = %OutputTitle
@onready var _diagnostics_title: Label = %DiagnosticsTitle
@onready var _output_log: RichTextLabel = %OutputLog
@onready var _diagnostics_log: RichTextLabel = %DiagnosticsLog


func _ready() -> void:
	_collapse_button.pressed.connect(_on_collapse_pressed)
	_resize_handle.gui_input.connect(_on_resize_handle_gui_input)
	resized.connect(_update_responsive_layout)
	_configure_text_controls()
	_apply_accessibility_relationships()
	apply_palette(Palette.table("dark"))
	_refresh_strings()
	set_expanded(_expanded)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_strings()


func bind_log(log: AtelierExecutionLog) -> void:
	if _log == log:
		return
	_unbind_log()
	_log = log
	if _log != null:
		_log.cleared.connect(_on_log_cleared)
		_log.entry_added.connect(_on_log_entry_added)
		_log.compacted.connect(_rebuild_from_log)
	_rebuild_from_log()


func set_panel_rect(panel_rect: Rect2, expanded: bool) -> void:
	set_expanded(expanded)
	position = panel_rect.position
	size = panel_rect.size


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	if not is_node_ready():
		return
	_content_split.visible = expanded
	_header_separator.visible = expanded
	_resize_handle.visible = expanded
	_update_responsive_layout()
	_refresh_collapse_button()
	if not expanded:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner != null and is_ancestor_of(focus_owner):
			_collapse_button.grab_focus()


func is_expanded() -> bool:
	return _expanded


func apply_palette(palette: Dictionary) -> void:
	_palette = palette.duplicate()
	theme = UITheme.build(_palette)
	_output_color = _palette.get("output", Color("e3cea2"))
	_warning_color = _palette.get("warning", Color("d8c783"))
	_error_color = _palette.get("error", Color("ff8791"))
	_faint_color = _palette.get("text_faint", Color("8a7c5f"))
	# As cores das entradas sao gravadas na pilha do RichTextLabel. Trocar o
	# Theme nao altera trechos antigos, portanto uma troca de tema refaz apenas
	# os dois logs (uma operacao rara), sem envolver o desenho do canvas.
	_rebuild_from_log()


func focus_output() -> void:
	if _expanded:
		_output_log.grab_focus()


func _exit_tree() -> void:
	_unbind_log()


func _unbind_log() -> void:
	if _log == null:
		return
	if _log.cleared.is_connected(_on_log_cleared):
		_log.cleared.disconnect(_on_log_cleared)
	if _log.entry_added.is_connected(_on_log_entry_added):
		_log.entry_added.disconnect(_on_log_entry_added)
	if _log.compacted.is_connected(_rebuild_from_log):
		_log.compacted.disconnect(_rebuild_from_log)
	_log = null


func _configure_text_controls() -> void:
	for log_control: RichTextLabel in [_output_log, _diagnostics_log]:
		log_control.selection_enabled = true
		log_control.context_menu_enabled = true
		log_control.shortcut_keys_enabled = true
		log_control.scroll_active = true
		log_control.scroll_following = true
		log_control.fit_content = false
		log_control.focus_mode = Control.FOCUS_ALL
		# O texto produzido pelo programa e pelos diagnosticos e dado, nao uma
		# chave de traducao. Desativar isto evita traduzir stdout por acidente.
		log_control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _apply_accessibility_relationships() -> void:
	accessibility_name = _localized(Strings.EXECUTION_TITLE, "Execução")
	accessibility_description = _localized(
			Strings.EXECUTION_PANEL_ACCESSIBLE,
			"Painel com a saída e os diagnósticos da execução.")
	_output_log.accessibility_labeled_by_nodes = [_output_log.get_path_to(_output_title)]
	_diagnostics_log.accessibility_labeled_by_nodes = [
		_diagnostics_log.get_path_to(_diagnostics_title),
	]
	_output_log.accessibility_live = AccessibilityServer.LIVE_POLITE
	_diagnostics_log.accessibility_live = AccessibilityServer.LIVE_ASSERTIVE
	_collapse_button.focus_next = _collapse_button.get_path_to(_output_log)
	_output_log.focus_previous = _output_log.get_path_to(_collapse_button)
	_output_log.focus_next = _output_log.get_path_to(_diagnostics_log)
	_diagnostics_log.focus_previous = _diagnostics_log.get_path_to(_output_log)
	_diagnostics_log.focus_next = _diagnostics_log.get_path_to(_collapse_button)
	_collapse_button.focus_previous = _collapse_button.get_path_to(_diagnostics_log)


func _refresh_strings() -> void:
	_title.text = _localized(Strings.EXECUTION_TITLE, "EXECUÇÃO")
	_description.text = _localized(
			Strings.EXECUTION_DESCRIPTION,
			"A saída, os avisos e os erros do ritual aparecem aqui.")
	_output_title.text = _localized(Strings.EXECUTION_OUTPUT, "SAÍDA")
	_diagnostics_title.text = _localized(Strings.EXECUTION_DIAGNOSTICS, "DIAGNÓSTICOS")
	accessibility_name = _localized(Strings.EXECUTION_TITLE, "Execução")
	accessibility_description = _localized(
			Strings.EXECUTION_PANEL_ACCESSIBLE,
			"Painel com a saída e os diagnósticos da execução.")
	_output_log.accessibility_name = _localized(Strings.EXECUTION_OUTPUT, "Saída da execução")
	_output_log.accessibility_description = _localized(
			Strings.EXECUTION_OUTPUT_ACCESSIBLE,
			"Saída selecionável da execução; use Control C para copiar.")
	_diagnostics_log.accessibility_name = _localized(
			Strings.EXECUTION_DIAGNOSTICS,
			"Avisos e erros da execução")
	_diagnostics_log.accessibility_description = _localized(
			Strings.EXECUTION_DIAGNOSTICS_ACCESSIBLE,
			"Diagnósticos selecionáveis; erros novos têm prioridade de anúncio.")
	_refresh_collapse_button()
	_rebuild_from_log()


func _refresh_collapse_button() -> void:
	if not is_node_ready():
		return
	var action_text := _localized(Strings.EXECUTION_COLLAPSE, "Recolher execução")
	if not _expanded:
		action_text = _localized(Strings.EXECUTION_EXPAND, "Abrir execução")
	_collapse_button.text = "⌄" if _expanded else "⌃"
	_collapse_button.tooltip_text = action_text
	_collapse_button.accessibility_name = action_text


func _localized(key: StringName, fallback: String) -> String:
	var translated: String = tr(key)
	return fallback if translated == String(key) else translated


func _rebuild_from_log() -> void:
	if not is_node_ready():
		return
	_on_log_cleared()
	if _log == null:
		return
	for raw_entry: Dictionary in _log.get_entries():
		var kind: int = int(raw_entry.get("kind", ExecutionLog.Kind.OUTPUT))
		var text: String = str(raw_entry.get("text", ""))
		_append_entry(kind, text)


func _on_log_cleared() -> void:
	if not is_node_ready():
		return
	_has_output = false
	_has_diagnostics = false
	_output_log.clear()
	_output_log.push_color(_faint_color)
	_output_log.push_italics()
	_output_log.add_text(_localized(
			Strings.EXECUTION_OUTPUT_EMPTY,
			"A saída do ritual aparecerá aqui."))
	_output_log.pop()
	_output_log.pop()
	_diagnostics_log.clear()
	_diagnostics_log.push_color(_faint_color)
	_diagnostics_log.push_italics()
	_diagnostics_log.add_text(_localized(
			Strings.EXECUTION_DIAGNOSTICS_EMPTY,
			"Nenhum aviso ou erro."))
	_diagnostics_log.pop()
	_diagnostics_log.pop()


func _on_log_entry_added(kind: int, text: String) -> void:
	_append_entry(kind, text)


func _append_entry(kind: int, text: String) -> void:
	if text.is_empty() or not is_node_ready():
		return
	match kind:
		ExecutionLog.Kind.WARNING:
			_append_diagnostic("~ ", text, _warning_color)
		ExecutionLog.Kind.ERROR:
			_append_diagnostic("! ", text, _error_color)
		_:
			_append_output(text)


func _append_output(text: String) -> void:
	if not _has_output:
		_output_log.clear()
		_output_log.push_color(_output_color)
		_output_log.add_text("> ")
		_output_log.pop()
		_has_output = true
	_output_log.push_color(_output_color)
	# add_text trata o conteudo como literal. Assim colchetes impressos pelo
	# programa nunca viram BBCode nem conseguem injetar formatacao no painel.
	_output_log.add_text(text)
	_output_log.pop()


func _append_diagnostic(prefix: String, text: String, color: Color) -> void:
	if not _has_diagnostics:
		_diagnostics_log.clear()
		_has_diagnostics = true
	elif _diagnostics_log.get_total_character_count() > 0:
		_diagnostics_log.newline()
	_diagnostics_log.push_color(color)
	_diagnostics_log.add_text(prefix)
	_diagnostics_log.add_text(text)
	_diagnostics_log.pop()


func _on_collapse_pressed() -> void:
	collapse_requested.emit()


func _on_resize_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		_resize_dragging = event.pressed
		if _resize_dragging:
			resize_started.emit(_pointer_y())
		else:
			resize_finished.emit()
		accept_event()
	elif event is InputEventMouseMotion and _resize_dragging:
		resize_dragged.emit(_pointer_y())
		accept_event()


func _pointer_y() -> float:
	return get_viewport().get_mouse_position().y


func _update_responsive_layout() -> void:
	if not is_node_ready():
		return
	_description.visible = _expanded and size.y >= 158.0 and size.x >= 420.0
	if not _expanded:
		return
	var content_width := maxf(_content_split.size.x, 0.0)
	if content_width < 260.0:
		_content_split.split_offset = int(content_width * 0.56)
	else:
		_content_split.split_offset = int(clampf(
				content_width * 0.68,
				130.0,
				content_width - 112.0))
