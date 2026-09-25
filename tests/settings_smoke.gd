extends SceneTree

## Configurações (AtelierSettings e o painel AtelierSettingsPanel): o idioma
## escolhido fica salvo e vale na hora, "automático" volta ao idioma com que o
## jogo abriu, e no balcão (engrenagem ou Esc) trocar o idioma reescreve o
## que já está na tela: cartão do dia, cartão da manhã, nota da inspeção,
## fala do cliente, marca do carimbo, bancada e livro-caixa. Trocar o estilo
## de arte muda o balcão na hora.

const TEST_SETTINGS := "user://settings_smoke.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


## Mensagem de uma chave num idioma, sem mexer no idioma atual.
static func _in(locale: String, key: String) -> String:
	return String(TranslationServer.get_translation_object(locale).get_message(key))


func _press_escape() -> void:
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	root.push_input(escape)


func _run() -> void:
	AtelierSettings.path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	var boot_locale := TranslationServer.get_locale()

	# 1. Preferência de idioma: automático sem arquivo; salva e aplica na hora.
	assert(AtelierSettings.language() == "")
	AtelierSettings.apply_language()
	assert(TranslationServer.get_locale() == boot_locale, "Automatic keeps the language the game opened with")
	AtelierSettings.set_language("pt_BR")
	assert(TranslationServer.get_locale() == "pt_BR" and AtelierSettings.language() == "pt_BR")
	AtelierSettings.set_language("en")
	assert(TranslationServer.get_locale() == "en" and AtelierSettings.language() == "en")
	AtelierSettings.set_language("")
	assert(TranslationServer.get_locale() == boot_locale, "Back to automatic, back to the boot language")
	AtelierSettings.set_value("game", "language", "xx")
	assert(AtelierSettings.language() == "", "An unknown language counts as automatic")
	AtelierSettings.set_language("en")

	# 2. No balcão: Esc abre as configurações até sobre o cartão da manhã.
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	var feedback := desk.get_node("%Feedback") as AtelierDeskFeedback
	feedback.instant = true
	feedback.mute = true
	root.add_child(desk)
	await _frames()
	var settings := desk.get_node("%Settings") as AtelierSettingsPanel
	var language_option := settings.get_node("%LanguageOption") as OptionButton
	var style_option := settings.get_node("%StyleOption") as OptionButton
	assert(not settings.visible)
	_press_escape()
	await _frames()
	assert(settings.visible, "Esc opens the settings on the morning card")
	assert(language_option.item_count == AtelierSettings.LANGUAGES.size())
	assert(language_option.get_item_text(language_option.selected) == _in("en", "SETTINGS_LANGUAGE_EN"))

	# Trocar para português reescreve o que está na tela.
	var overlay_button := desk.get_node("%OverlayButton") as Button
	assert(overlay_button.text == _in("en", "DESK_OPEN_SHOP"))
	var pt_index: int = AtelierSettings.LANGUAGES.keys().find("pt_BR")
	language_option.select(pt_index)
	language_option.item_selected.emit(pt_index)
	await _frames()
	assert(TranslationServer.get_locale() == "pt_BR" and AtelierSettings.language() == "pt_BR")
	assert(overlay_button.text == _in("pt_BR", "DESK_OPEN_SHOP"), "The morning card follows the new language: %s" % overlay_button.text)
	assert((desk.get_node("%DayLabel") as Label).text == _in("pt_BR", "DESK_HUD_DAY") % [1])
	assert(language_option.get_item_text(pt_index) == _in("pt_BR", "SETTINGS_LANGUAGE_PT_BR"), "The settings list follows the new language")
	_press_escape()
	await _frames()
	assert(not settings.visible, "Esc closes the settings")

	# 3. Atendendo: a engrenagem abre as configurações; nota, fala e provas
	# mudam de idioma junto.
	overlay_button.pressed.emit()
	desk.get_node("%BellButton").pressed.emit()
	var order: AtelierScrollOrder = desk.current_order
	desk.get_node("%RaceField").pressed.emit()
	desk.rule_button("signature").pressed.emit()
	desk.get_node("%AgeField").pressed.emit()
	desk.rule_button("signature").pressed.emit()
	var note := desk.get_node("%FeedbackLabel") as Label
	var speech := desk.get_node("%Speech") as Label
	var evidence := desk.get_node("%EvidenceLabel") as Label
	var age_label := _in("pt_BR", "FIELD_AGE")
	assert(age_label in note.text, "The inspection note starts in Portuguese: %s" % note.text)
	assert(speech.text == "\"%s\"" % _in("pt_BR", "DESK_PATIENCE_UNEASY"), speech.text)
	(desk.get_node("%SettingsButton") as BaseButton).pressed.emit()
	assert(settings.visible, "The gear opens the settings")
	var en_index: int = AtelierSettings.LANGUAGES.keys().find("en")
	language_option.select(en_index)
	language_option.item_selected.emit(en_index)
	await _frames()
	assert(_in("en", "FIELD_AGE") in note.text and not age_label in note.text, "The note is rewritten in English: %s" % note.text)
	assert(speech.text == "\"%s\"" % _in("en", "DESK_PATIENCE_UNEASY"), "The speech is rewritten: %s" % speech.text)
	assert(_in("en", "DESK_WRONG_LINKS") % [2, 3] in evidence.text, evidence.text)
	assert((desk.get_node("%NameField") as Button).text.begins_with(_in("en", "FIELD_NAME")))

	# 4. Estilo de arte: troca o balcão na hora e fica salvo.
	var other_index := 1 - style_option.selected
	var other_style := AtelierDeskStyles.all()[other_index]
	style_option.select(other_index)
	style_option.item_selected.emit(other_index)
	assert(desk.desk_style == other_style and (desk.get_node("%Backdrop") as TextureRect).texture == other_style.backdrop)
	assert(AtelierDeskStyles.preferred() == other_style)
	settings.close()

	# 5. Marca do carimbo e bancada também trocam de idioma.
	desk.get_node("%ApproveButton").pressed.emit()
	var ink := desk.get_node("%InkMark") as Label
	var workbench := desk.get_node("%Workbench") as Control
	assert(workbench.visible and ink.text == _in("en", "DESK_INK_APPROVED"))
	AtelierSettings.set_language("pt_BR")
	await _frames()
	assert(ink.text == _in("pt_BR", "DESK_INK_APPROVED"), ink.text)
	var bench_title := workbench.get_node("%OrderTitle") as Label
	assert(bench_title.text == _in("pt_BR", "BENCH_ORDER_TITLE") % [order.item, order.client_name], bench_title.text)
	var bench_result := workbench.get_node("%ResultLabel") as Label
	assert(bench_result.text == _in("pt_BR", "BENCH_START_HINT"), bench_result.text)

	# 6. Livro-caixa: as linhas vêm de chaves e aparecem no idioma da vez.
	workbench.get_node("%AbandonButton").pressed.emit()
	var entry: Dictionary = game_state.ledger.back()
	assert(game_state.entry_text(entry) == _in("pt_BR", "LEDGER_ABANDONED") % [order.item, order.client_name])
	AtelierSettings.set_language("en")
	assert(game_state.entry_text(entry) == _in("en", "LEDGER_ABANDONED") % [order.item, order.client_name])

	desk.queue_free()
	await process_frame
	AtelierSettings.set_language("")
	assert(TranslationServer.get_locale() == boot_locale)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("SETTINGS_SMOKE_OK")
	quit(0)
