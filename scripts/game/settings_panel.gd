class_name AtelierSettingsPanel
extends Control

## Janela de configurações (na tela de título e no balcão): idioma e estilo de
## arte do balcão. As escolhas valem na hora e ficam salvas (AtelierSettings).
## Esc ou "Fechar" fecham. Quem mostra o balcão ouve desk_style_changed.

signal desk_style_changed(style: AtelierDeskStyle)
signal closed
signal menu_requested

@onready var language_option: OptionButton = %LanguageOption
@onready var style_option: OptionButton = %StyleOption
@onready var close_button: Button = %CloseButton
@onready var menu_button: Button = %MenuButton

## Código de idioma de cada item da lista (na ordem de AtelierSettings.LANGUAGES).
var _languages: Array[String] = []


func _ready() -> void:
	hide()
	menu_button.hide()
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	language_option.item_selected.connect(_on_language_selected)
	style_option.item_selected.connect(_on_style_selected)
	close_button.pressed.connect(close)
	_fill_options()


func open() -> void:
	_fill_options()
	show()
	language_option.grab_focus()


func enable_menu_return(enabled: bool) -> void:
	menu_button.visible = enabled


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Os nomes nas listas vêm de tr(): refaz quando o idioma muda (depois do
	# sinal da lista que causou a troca terminar).
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fill_options.call_deferred()


## Preenche as listas com os nomes no idioma atual e marca as escolhas salvas.
func _fill_options() -> void:
	_languages.assign(AtelierSettings.LANGUAGES.keys())
	language_option.clear()
	for code in _languages:
		language_option.add_item(tr(AtelierSettings.LANGUAGES[code]))
	language_option.select(_languages.find(AtelierSettings.language()))
	var preferred := AtelierDeskStyles.preferred()
	style_option.clear()
	for style in AtelierDeskStyles.all():
		style_option.add_item(tr(style.title_key))
		if style.id == preferred.id:
			style_option.select(style_option.item_count - 1)


func _on_language_selected(index: int) -> void:
	AtelierSettings.set_language(_languages[index])


func _on_style_selected(index: int) -> void:
	var style := AtelierDeskStyles.all()[index]
	AtelierDeskStyles.remember(style)
	desk_style_changed.emit(style)
