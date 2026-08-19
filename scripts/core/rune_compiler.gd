class_name AtelierRuneCompiler
extends RefCounted

## Compilador do grafo visual para bytecode binário da máquina virtual Atelier.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")


func compile(connections: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	if connections.is_empty():
		return {"ok": false, "errors": ["Não há conexões para compilar."], "warnings": warnings}

	var ordered_indices := _linearize(connections, errors)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}

	var instructions: Array[Dictionary] = []
	for connection_index in ordered_indices:
		var connection: Dictionary = connections[connection_index]
		var kind := str(connection.get("symbol", ""))
		if kind.is_empty():
			errors.append("A ligação %d não possui um selo." % (connection_index + 1))
			continue
		var symbol := RuneCatalog.symbol_data(kind)
		var opcode := int(symbol.get("opcode", -1))
		if opcode < 0:
			errors.append("Selo desconhecido na ligação %d." % (connection_index + 1))
			continue
		var instruction := {"opcode": opcode, "connection_index": connection_index}
		if bool(symbol.get("takes_operand", false)):
			instruction["operand"] = clampi(int(connection.get("intensity", 128)), 0, 255)
		instructions.append(instruction)

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}
	if instructions.is_empty():
		return {"ok": false, "errors": ["Não há selos para compilar."], "warnings": warnings}
	if int(instructions.back()["opcode"]) != RuneCatalog.OPCODE_HALT:
		instructions.append({"opcode": RuneCatalog.OPCODE_HALT, "implicit": true})
		warnings.append("HALT foi inserido automaticamente no fim do ritual.")

	return {"ok": true, "instructions": instructions, "bytecode": RuneBytecode.encode(instructions), "errors": errors, "warnings": warnings}


func export_binary(connections: Array, path: String) -> Dictionary:
	var result := compile(connections)
	if not result["ok"]:
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["ok"] = false
		result["errors"] = ["Não foi possível gravar o binário em %s." % path]
		return result
	file.store_buffer(result["bytecode"])
	file.close()
	result["path"] = path
	return result


func _linearize(connections: Array, errors: Array[String]) -> Array[int]:
	var incoming_points := {}
	for raw_connection in connections:
		var connection: Dictionary = raw_connection
		incoming_points[_point_key(connection["to"])] = true

	var starts: Array[int] = []
	for index in range(connections.size()):
		var indexed_connection: Dictionary = connections[index]
		var from_point: Vector2 = indexed_connection["from"]
		if not incoming_points.has(_point_key(from_point)):
			starts.append(index)
	if starts.is_empty():
		errors.append("Não foi encontrado um ponto inicial: o ritual contém um ciclo.")
		return []
	if starts.size() > 1:
		errors.append("Existem %d sequências desconectadas; conecte-as antes de compilar." % starts.size())
		return []

	var ordered: Array[int] = []
	var visited := {}
	var current_index := starts[0]
	while true:
		if visited.has(current_index):
			errors.append("Ciclo encontrado na ligação %d." % (current_index + 1))
			break
		visited[current_index] = true
		ordered.append(current_index)
		var current: Dictionary = connections[current_index]
		var current_to: Vector2 = current["to"]
		var next_indices: Array[int] = []
		for candidate_index in range(connections.size()):
			var candidate: Dictionary = connections[candidate_index]
			var candidate_from: Vector2 = candidate["from"]
			if candidate_from.is_equal_approx(current_to):
				next_indices.append(candidate_index)
		if next_indices.size() > 1:
			errors.append("Ramificação na ligação %d: saltos ainda não foram implementados." % (current_index + 1))
			break
		if next_indices.is_empty():
			break
		current_index = next_indices[0]

	if ordered.size() != connections.size() and errors.is_empty():
		errors.append("Há ligações fora da sequência principal do ritual.")
	return ordered


func _point_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x), roundi(point.y)]
