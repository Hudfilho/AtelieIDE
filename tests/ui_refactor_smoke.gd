extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://scenes/Main.tscn") as PackedScene
	_check(packed_scene != null, "Main.tscn precisa carregar")
	if packed_scene == null:
		_finish()
		return
	var main: Node = packed_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var ui := main.get_node_or_null("Interface") as AtelierInterface
	_check(ui != null, "AtelierInterface precisa existir")
	if ui == null:
		_finish()
		return
	_check(ui.command_panel is PanelContainer, "Comandos precisam usar um PanelContainer nativo")
	_check(ui.palette_panel is PanelContainer, "Paleta precisa usar um PanelContainer nativo")
	_check(ui.stack_panel is PanelContainer, "Pilha precisa usar um PanelContainer nativo")
	_check(ui.command_panel.size.x <= 43.0, "Aba lateral recolhida precisa respeitar 42 px")
	_check(ui.stack_panel.size.x <= 43.0, "Aba da pilha recolhida precisa respeitar 42 px")
	_check(ui.palette_panel.size.y <= 43.0, "Paleta recolhida precisa respeitar 42 px")
	_check(ui.execution_panel.size.y <= 43.0, "Execucao recolhida precisa respeitar 42 px")
	_check(ui.command_panel.compact_title_label.visible, "Aba recolhida precisa manter o titulo visivel")
	main.set("left_panel_open", true)
	main.set("right_panel_open", true)
	main.set("top_panel_open", true)
	main.set("bottom_panel_open", true)
	main.set("left_panel_size", 216.0)
	main.set("right_panel_size", 170.0)
	main.set("top_panel_size", 174.0)
	main.set("bottom_panel_size", 124.0)
	main.call("_sync_interface_all")
	await process_frame
	_check(ui.command_panel.size.x <= 217.0, "Grimorio aberto nao pode forcar largura alem do resize")
	_check(ui.stack_panel.size.x <= 171.0, "Pilha aberta nao pode forcar largura alem do resize")
	_check(ui.palette_panel.size.y <= 175.0, "Paleta aberta nao pode forcar altura alem do resize")
	_check(ui.execution_panel.size.y <= 125.0, "Execucao aberta nao pode forcar altura alem do resize")

	var output_log := ui.execution_panel.get_node_or_null("%OutputLog") as RichTextLabel
	var diagnostics_log := ui.execution_panel.get_node_or_null("%DiagnosticsLog") as RichTextLabel
	_check(output_log != null, "Painel de saida precisa de RichTextLabel")
	_check(diagnostics_log != null, "Painel de diagnosticos precisa de RichTextLabel")
	if output_log != null:
		_check(output_log.selection_enabled, "Saida precisa permitir selecao")
		_check(output_log.context_menu_enabled, "Saida precisa permitir copiar pelo menu")
		_check(output_log.scroll_active, "Saida precisa ter scroll")
	if diagnostics_log != null:
		_check(diagnostics_log.selection_enabled, "Diagnosticos precisam permitir selecao")
		_check(diagnostics_log.scroll_active, "Diagnosticos precisam ter scroll")

	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	await process_frame
	_check(ui.palette_panel.title_label.text == "SEALS AND RUNES", "Paleta precisa reagir a troca de idioma")
	var first_rune_tile: AtelierRuneTileButton = null
	for child in ui.palette_panel.rune_strip.get_children():
		if child is AtelierRuneTileButton:
			first_rune_tile = child
			break
	_check(first_rune_tile != null and first_rune_tile.rune_description.begins_with("Pushes"),
			"Tooltips das runas precisam ser localizaveis")
	TranslationServer.set_locale(original_locale)
	await process_frame

	var diagram := main.get("diagram") as AtelierRuneDiagram
	var program: Array[Dictionary] = [
		_cell(Vector2(0.0, 0.0), Vector2(48.0, 0.0), "ORB", 2),
		_cell(Vector2(48.0, 0.0), Vector2(96.0, 0.0), "ORB", 2),
		_cell(Vector2(96.0, 0.0), Vector2(144.0, 0.0), "DIAMOND", 128),
		_cell(Vector2(144.0, 0.0), Vector2(192.0, 0.0), "TRIANGLE", 128),
		_cell(Vector2(192.0, 0.0), Vector2(240.0, 0.0), "CROSS", 128),
	]
	var inserted := diagram.append_connections(program)
	_check(inserted.size() == program.size(), "Programa de teste precisa entrar inteiro")
	main.call("_invalidate_sequence_side_multiplier_cache")
	main.call("_invalidate_symbol_connection_indices")
	main.call("_sync_interface_all")
	main.set("execution_speed_rps", 100.0)
	main.call("_run_ritual")
	await create_timer(0.20).timeout

	var execution_errors: Variant = main.get("execution_errors")
	var execution_output := str(main.get("execution_output"))
	_check(execution_errors.is_empty(), "2 + 2 nao pode gerar erro de execucao")
	_check(execution_output == "4", "2 + 2 precisa imprimir 4")
	_check(ui.execution_log.get_output() == "4", "Modelo do painel precisa receber a saida incremental")
	_check(ui.command_panel.entries.size() == 5, "Painel de comandos precisa refletir as cinco runas")
	_check(ui.stack_panel.stack_list != null, "Painel da pilha precisa usar ItemList nativa")

	var stress_log := AtelierExecutionLog.new()
	var output_chunk := "x".repeat(1024)
	for _chunk_index in range(150):
		stress_log.append_output(output_chunk)
	_check(stress_log.get_output().length() <= AtelierExecutionLog.MAX_OUTPUT_CHARACTERS,
			"Log de output precisa ter limite para loops infinitos")

	main.queue_free()
	await process_frame
	_finish()


func _cell(from: Vector2, to: Vector2, symbol: String, intensity: int) -> Dictionary:
	return {
		"from": from,
		"to": to,
		"symbol": symbol,
		"intensity": intensity,
	}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("UI_REFACTOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
