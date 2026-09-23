class_name AtelierRitualFile
extends RefCounted

## Formato editável do ateliê. O bytecode exportado para execução é separado.

const EXTENSION := ".atelier"
const FORMAT := "atelier-rune"
const VERSION := 1
const MAX_FILE_BYTES := 8_000_000
const MAX_CONNECTIONS := 20_000
const MAX_COORDINATE := 10_000_000.0
const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")


static func save_file(path: String, connections: Array[Dictionary], pan: Vector2, zoom: float) -> Dictionary:
	if connections.size() > MAX_CONNECTIONS:
		return {"ok": false, "error": "O ritual tem conexões demais para este formato."}
	var final_path := path if path.to_lower().ends_with(EXTENSION) else path + EXTENSION
	var entries: Array[Dictionary] = []
	for connection in connections:
		var from: Vector2 = connection["from"]
		var to: Vector2 = connection["to"]
		entries.append({
			"from": [from.x, from.y],
			"to": [to.x, to.y],
			"symbol": str(connection.get("symbol", "")),
			"intensity": int(connection.get("intensity", 128)),
		})
	var document := {
		"format": FORMAT,
		"version": VERSION,
		"view": {"pan": [pan.x, pan.y], "zoom": zoom},
		"connections": entries,
	}
	var file := FileAccess.open(final_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "Não foi possível criar o arquivo (%s)." % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(document, "  ") + "\n")
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "error": "Não foi possível terminar de salvar o arquivo (%s)." % error_string(write_error)}
	return {"ok": true, "path": final_path}


static func load_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "Não foi possível abrir o arquivo (%s)." % error_string(FileAccess.get_open_error())}
	if file.get_length() > MAX_FILE_BYTES:
		file.close()
		return {"ok": false, "error": "O arquivo é grande demais para uma runa do Ateliê."}
	var contents := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(contents) != OK:
		return {"ok": false, "error": "O arquivo não contém um JSON válido."}
	var raw_document: Variant = parser.data
	if not (raw_document is Dictionary):
		return {"ok": false, "error": "O arquivo não contém uma runa válida."}
	var document: Dictionary = raw_document
	if document.get("format", "") != FORMAT or document.get("version", 0) != VERSION:
		return {"ok": false, "error": "Formato ou versão de runa incompatível."}
	var raw_entries: Variant = document.get("connections")
	if not (raw_entries is Array) or raw_entries.size() > MAX_CONNECTIONS:
		return {"ok": false, "error": "A lista de conexões é inválida ou grande demais."}
	var restored: Array[Dictionary] = []
	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			return {"ok": false, "error": "Uma conexão do arquivo é inválida."}
		var entry: Dictionary = raw_entry
		var from_result := _read_point(entry.get("from"))
		var to_result := _read_point(entry.get("to"))
		if not from_result.get("ok", false) or not to_result.get("ok", false):
			return {"ok": false, "error": "Uma conexão contém coordenadas inválidas."}
		var from: Vector2 = from_result["point"]
		var to: Vector2 = to_result["point"]
		if from.is_equal_approx(to):
			return {"ok": false, "error": "Uma conexão do arquivo não tem comprimento."}
		var raw_symbol: Variant = entry.get("symbol", "")
		if not (raw_symbol is String):
			return {"ok": false, "error": "Uma conexão contém uma runa inválida."}
		var symbol: String = raw_symbol
		if not symbol.is_empty() and RuneCatalog.opcode_for_kind(symbol) < 0:
			return {"ok": false, "error": "O arquivo contém uma runa desconhecida: %s." % symbol}
		var raw_intensity: Variant = entry.get("intensity", 128)
		if not _is_finite_number(raw_intensity):
			return {"ok": false, "error": "Uma conexão contém intensidade fora de 0 a 255."}
		var intensity := float(raw_intensity)
		if intensity < 0.0 or intensity > 255.0 or intensity != roundf(intensity):
			return {"ok": false, "error": "Uma conexão contém intensidade fora de 0 a 255."}
		restored.append({"from": from, "to": to, "symbol": symbol, "intensity": int(intensity)})
	var raw_view: Variant = document.get("view", {})
	if not (raw_view is Dictionary):
		return {"ok": false, "error": "A posição de visualização do arquivo é inválida."}
	var view: Dictionary = raw_view
	var pan_result := _read_point(view.get("pan", [340.0, 230.0]))
	var raw_zoom: Variant = view.get("zoom", 1.0)
	if not pan_result.get("ok", false) or not _is_finite_number(raw_zoom):
		return {"ok": false, "error": "A posição de visualização do arquivo é inválida."}
	var zoom := float(raw_zoom)
	if zoom < 0.55 or zoom > 2.5:
		return {"ok": false, "error": "O zoom salvo está fora dos limites permitidos."}
	return {"ok": true, "connections": restored, "pan": pan_result["point"], "zoom": zoom, "path": path}


static func _read_point(value: Variant) -> Dictionary:
	if not (value is Array) or value.size() != 2:
		return {"ok": false}
	if not _is_finite_number(value[0]) or not _is_finite_number(value[1]):
		return {"ok": false}
	return {"ok": true, "point": Vector2(float(value[0]), float(value[1]))}


static func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return not is_nan(number) and not is_inf(number) and absf(number) <= MAX_COORDINATE
