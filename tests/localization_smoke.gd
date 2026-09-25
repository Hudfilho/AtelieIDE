extends SceneTree

## Localização nativa do Godot (tr() e auto-tradução de Control, tabela CSV em
## project.godot): inglês é o fallback, o idioma do sistema vale quando há
## tradução, e toda chave usada pelas cenas e pelo código resolve em inglês.
## Não depende do idioma ativo: roda igual num sistema en ou pt_BR.

const CSV_PATH := "res://localization/strings.csv"
const SCENES: Array[String] = ["res://scenes/game/Title.tscn", "res://scenes/game/Desk.tscn", "res://scenes/game/Workbench.tscn", "res://scenes/game/Settings.tscn"]
const KEY_PATTERN := "^[A-Z][A-Z0-9_]+$"
## Prefixos das chaves; um literal com um deles no código tem de existir na tabela.
const CODE_KEY_PATTERN := "\"((?:TITLE|DESK|BENCH|IDE|COMPILER|VM|FILE|JUDGE|INSPECT|LEDGER|FIELD|RUNE|SETTINGS)_[A-Z0-9_]+)\""
const PORTUGUESE_LETTERS := "[ãõçáéíóúâêôÃÕÇÁÉÍÓÚÂÊÔ]"
## Chamadas que mostram texto ao jogador. Um literal nelas só pode ter formato
## (%s, BBCode, pontuação) ou siglas; palavras precisam vir de uma chave.
## Linhas marcadas "# dev-only" (diagnóstico de desenvolvimento) ficam de fora.
const DISPLAY_CALL := "(_say\\(|_say_feedback\\(|_client_leaves\\(|_show_overlay\\(|\\.text \\+?= |\\brecord\\(|draw_string\\(|draw_multiline_string\\(|_draw_panel_title\\(|add_item\\(|errors\\.append\\(|warnings\\.append\\(|\\.title = |\\.dialog_text = |\\bbody \\+?= |\\bline = |_leave_text = |\"error\": \")"
const FORMAT_NOISE := "\\[/?[a-z]+(=[^\\]]*)?\\]|%[-+0-9.]*[a-zA-Z]|\\\\[nt\"]"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var boot_locale := TranslationServer.get_locale()

	# Inglês como fallback, português suportado, e nada força o idioma no boot:
	# sem locale/test, o idioma inicial é o do sistema.
	assert(ProjectSettings.get_setting("internationalization/locale/fallback") == "en")
	var loaded := TranslationServer.get_loaded_locales()
	assert(loaded.has("en") and loaded.has("pt_BR"), str(loaded))
	if str(ProjectSettings.get_setting("internationalization/locale/test", "")).is_empty():
		assert(boot_locale == OS.get_locale(), "Boot locale %s differs from the system locale %s" % [boot_locale, OS.get_locale()])

	var table := _read_table()
	var english := TranslationServer.get_translation_object("en")
	var portuguese_letters := RegEx.create_from_string(PORTUGUESE_LETTERS)
	var placeholder := RegEx.create_from_string("%[0-9.]*[sdfX]")

	# Tabela: toda chave tem os dois idiomas, resolve em inglês (seja qual for o
	# idioma ativo) e usa os mesmos marcadores de formatação nos dois.
	for key in table:
		var row: Dictionary = table[key]
		assert(not str(row["en"]).is_empty() and not str(row["pt_BR"]).is_empty(), "%s is missing a translation" % key)
		assert(str(english.get_message(key)) == str(row["en"]).c_unescape(), "%s does not resolve in English" % key)
		assert(portuguese_letters.search(str(row["en"])) == null, "%s has Portuguese in the English column: %s" % [key, row["en"]])
		assert(_placeholders(placeholder, row["en"]) == _placeholders(placeholder, row["pt_BR"]), "%s: placeholders differ between en and pt_BR" % key)

	# Idioma do sistema quando há tradução; inglês quando não há.
	TranslationServer.set_locale("pt_BR")
	assert(tr("BENCH_ORACLE_TITLE") == "ORÁCULO")
	assert(tr("VM_NEEDS_VALUE") % ["DROP"] == "DROP precisa de um valor na pilha.")
	TranslationServer.set_locale("fr_FR")
	assert(tr("BENCH_ORACLE_TITLE") == "ORACLE", "An unsupported locale falls back to English")
	TranslationServer.set_locale(boot_locale)

	# Cenas do demo: todo texto estático é uma chave da tabela.
	var key_regex := RegEx.create_from_string(KEY_PATTERN)
	var used_keys := {}
	var scene_keys := 0
	for scene_path in SCENES:
		var state := (load(scene_path) as PackedScene).get_state()
		for node_index in state.get_node_count():
			for property_index in state.get_node_property_count(node_index):
				if not state.get_node_property_name(node_index, property_index) in [&"text", &"tooltip_text"]:
					continue
				var text := str(state.get_node_property_value(node_index, property_index))
				if text.is_empty():
					continue
				var where := "%s:%s" % [scene_path.get_file(), state.get_node_name(node_index)]
				assert(key_regex.search(text) != null, "%s shows a literal instead of a key: %s" % [where, text])
				assert(table.has(text), "%s uses unknown key %s" % [where, text])
				used_keys[text] = true
				scene_keys += 1
	assert(scene_keys >= 12, "Expected the demo scenes to reference keys, found %d" % scene_keys)

	# Código: toda chave citada existe e nenhum texto fixo aparece para o jogador.
	var code_key := RegEx.create_from_string(CODE_KEY_PATTERN)
	var display_call := RegEx.create_from_string(DISPLAY_CALL)
	var format_noise := RegEx.create_from_string(FORMAT_NOISE)
	var lowercase_word := RegEx.create_from_string("[a-z]{2,}")
	var string_literal := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	for script_path in _scripts("res://scripts"):
		var lines := FileAccess.get_file_as_string(script_path).split("\n")
		for line_number in lines.size():
			var line := lines[line_number]
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("@export_group"):
				continue
			var where := "%s:%d" % [script_path, line_number + 1]
			for found in code_key.search_all(line):
				assert(table.has(found.get_string(1)), "%s uses unknown key %s" % [where, found.get_string(1)])
				used_keys[found.get_string(1)] = true
			var is_display := display_call.search(line) != null and not line.ends_with("# dev-only")
			for literal in string_literal.search_all(line):
				var text := literal.get_string()
				assert(portuguese_letters.search(text) == null, "%s still has a Portuguese literal: %s" % [where, text])
				# Chaves de dicionário e caminhos de recurso não são texto na tela.
				var before := line.substr(0, literal.get_start())
				var after := line.substr(literal.get_end())
				var not_text := before.ends_with("[") or before.ends_with(".get(") or after.begins_with(":") \
						or text.begins_with("\"res://") or text.begins_with("\"user://")
				if is_display and not not_text and key_regex.search(text.trim_prefix("\"").trim_suffix("\"")) == null:
					assert(lowercase_word.search(format_noise.sub(text, "", true)) == null, "%s shows a hard-coded text instead of a key: %s" % [where, text])

	# Recursos de dados que citam chaves: os nomes dos estilos do balcão.
	for style in AtelierDeskStyles.all():
		assert(table.has(style.title_key), "Desk style %s uses unknown key %s" % [style.id, style.title_key])
		used_keys[style.title_key] = true

	# Tabela enxuta: nenhuma chave sem uso.
	for key in table:
		assert(used_keys.has(key), "%s is in the table but nothing uses it" % key)

	print("LOCALIZATION_SMOKE_OK (%d keys, %d in scenes, locale %s)" % [table.size(), scene_keys, boot_locale])
	quit(0)


func _read_table() -> Dictionary:
	var table := {}
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert(file != null, "Missing %s" % CSV_PATH)
	var header := file.get_csv_line()
	assert(header == PackedStringArray(["keys", "en", "pt_BR"]), str(header))
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 3 or row[0].is_empty():
			continue
		assert(not table.has(row[0]), "Duplicate key %s" % row[0])
		table[row[0]] = {"en": row[1], "pt_BR": row[2]}
	return table


func _placeholders(regex: RegEx, text: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for match in regex.search_all(text.replace("%%", "")):
		found.append(match.get_string())
	return found


func _scripts(directory: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file_name in DirAccess.get_files_at(directory):
		if file_name.ends_with(".gd"):
			found.append(directory.path_join(file_name))
	for sub in DirAccess.get_directories_at(directory):
		found.append_array(_scripts(directory.path_join(sub)))
	return found
