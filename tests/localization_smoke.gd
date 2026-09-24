extends SceneTree

## Localização: inglês é o idioma inicial; toda chave usada pelas cenas do demo
## e pelo código existe e resolve em inglês; a tabela não mistura idiomas.

const CSV_PATH := "res://localization/strings.csv"
const SCENES: Array[String] = ["res://scenes/game/Title.tscn", "res://scenes/game/Desk.tscn", "res://scenes/game/Workbench.tscn"]
const KEY_PATTERN := "^[A-Z][A-Z0-9_]+$"
## Prefixos das chaves; um literal com um deles no código tem de existir na tabela.
const CODE_KEY_PATTERN := "\"((?:TITLE|DESK|BENCH|IDE|COMPILER|VM|BYTECODE|FILE|JUDGE|INSPECT|LEDGER|FIELD|RUNE)_[A-Z0-9_]+)\""
const PORTUGUESE_LETTERS := "[ãõçáéíóúâêôÃÕÇÁÉÍÓÚÂÊÔ]"
## Chamadas que mostram texto ao jogador. Um literal nelas só pode ter formato
## (%s, BBCode, pontuação) ou siglas; palavras precisam vir de uma chave.
const DISPLAY_CALL := "(_say\\(|_say_feedback\\(|_client_leaves\\(|_show_overlay\\(|\\.text \\+?= |\\brecord\\(|draw_string\\(|draw_multiline_string\\(|_draw_panel_title\\(|add_item\\(|errors\\.append\\(|warnings\\.append\\(|\\.title = |\\.dialog_text = |\\bbody \\+?= |\\bline = |_leave_message = |\"error\": (\"|AtelierText))"
const FORMAT_NOISE := "\\[/?[a-z]+(=[^\\]]*)?\\]|%[-+0-9.]*[a-zA-Z]|\\\\[nt\"]"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(TranslationServer.get_locale().begins_with("en"), "English must be the initial locale, got %s" % TranslationServer.get_locale())
	var table := _read_table()
	assert(table.size() > 200)
	var portuguese := RegEx.create_from_string(PORTUGUESE_LETTERS)
	var placeholder := RegEx.create_from_string("%[0-9.]*[sdfX]")

	# Tabela: toda chave tem inglês e português, resolve em inglês e os dois
	# idiomas usam os mesmos marcadores de formatação, na mesma ordem.
	for key in table:
		var row: Dictionary = table[key]
		assert(not str(row["en"]).is_empty() and not str(row["pt_BR"]).is_empty(), "%s is missing a translation" % key)
		assert(AtelierText.t(key) != key, "%s does not resolve" % key)
		assert(portuguese.search(str(row["en"])) == null, "%s has Portuguese in the English column: %s" % [key, row["en"]])
		assert(_placeholders(placeholder, row["en"]) == _placeholders(placeholder, row["pt_BR"]), "%s: placeholders differ between en and pt_BR" % key)

	# Cenas do demo: todo texto estático é uma chave da tabela.
	var key_regex := RegEx.create_from_string(KEY_PATTERN)
	var scene_keys := 0
	for scene_path in SCENES:
		var state := (load(scene_path) as PackedScene).get_state()
		for node_index in state.get_node_count():
			for property_index in state.get_node_property_count(node_index):
				if state.get_node_property_name(node_index, property_index) != &"text":
					continue
				var text := str(state.get_node_property_value(node_index, property_index))
				if text.is_empty():
					continue
				var where := "%s:%s" % [scene_path.get_file(), state.get_node_name(node_index)]
				assert(key_regex.search(text) != null, "%s shows a literal instead of a key: %s" % [where, text])
				assert(table.has(text), "%s uses unknown key %s" % [where, text])
				scene_keys += 1
	assert(scene_keys >= 15, "Expected the demo scenes to reference keys, found %d" % scene_keys)

	# Código: toda chave citada nos scripts existe; nenhum literal acentuado
	# (texto em português) sobrou fora de comentários e grupos do Inspector.
	var code_key := RegEx.create_from_string(CODE_KEY_PATTERN)
	var display_call := RegEx.create_from_string(DISPLAY_CALL)
	var format_noise := RegEx.create_from_string(FORMAT_NOISE)
	var lowercase_word := RegEx.create_from_string("[a-z]{2,}")
	var code_keys := {}
	for script_path in _scripts("res://scripts"):
		var lines := FileAccess.get_file_as_string(script_path).split("\n")
		for line_number in lines.size():
			var line := lines[line_number]
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("@export_group"):
				continue
			for found in code_key.search_all(line):
				code_keys[found.get_string(1)] = true
				assert(table.has(found.get_string(1)), "%s:%d uses unknown key %s" % [script_path, line_number + 1, found.get_string(1)])
			var is_display := display_call.search(line) != null
			for literal in RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"").search_all(line):
				var text := literal.get_string()
				assert(portuguese.search(text) == null, "%s:%d still has a Portuguese literal: %s" % [script_path, line_number + 1, text])
				# Chaves de dicionário (data["label"], x.get("error"), {"error": ...})
				# e caminhos de recurso não são texto na tela.
				var before := line.substr(0, literal.get_start())
				var after := line.substr(literal.get_end())
				var not_text := before.ends_with("[") or before.ends_with(".get(") or after.begins_with(":") \
						or text.begins_with("\"res://") or text.begins_with("\"user://")
				if is_display and not not_text and key_regex.search(text.trim_prefix("\"").trim_suffix("\"")) == null:
					var bare := format_noise.sub(text, "", true)
					assert(lowercase_word.search(bare) == null, "%s:%d shows a hard-coded text instead of a key: %s" % [script_path, line_number + 1, text])
	assert(code_keys.size() > 150, "Only %d keys referenced from code" % code_keys.size())

	# O português original continua disponível para quem trocar o idioma.
	TranslationServer.set_locale("pt_BR")
	assert(AtelierText.t("BENCH_ORACLE_TITLE") == "ORÁCULO")
	assert(AtelierText.t("VM_NEEDS_VALUE", ["DROP"]) == "DROP precisa de um valor na pilha.")
	TranslationServer.set_locale(AtelierText.DEFAULT_LOCALE)
	assert(AtelierText.t("BENCH_ORACLE_TITLE") == "ORACLE")

	print("LOCALIZATION_SMOKE_OK (%d keys, %d in scenes, %d in code)" % [table.size(), scene_keys, code_keys.size()])
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
