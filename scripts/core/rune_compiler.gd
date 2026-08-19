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

	var sequences := _linearize_sequences(connections, errors, warnings)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}

	var instructions: Array[Dictionary] = []
	var inserted_halts := 0
	for sequence_index in range(sequences.size()):
		var sequence: Array = sequences[sequence_index]
		var instruction_start := instructions.size()
		for connection_index in sequence:
			var connection: Dictionary = connections[connection_index]
			var kind := str(connection.get("symbol", ""))
			if kind.is_empty():
				continue
			var symbol := RuneCatalog.symbol_data(kind)
			var opcode := int(symbol.get("opcode", -1))
			if opcode < 0:
				errors.append("Selo desconhecido na ligação %d." % (connection_index + 1))
				continue
			var intensity := clampi(int(connection.get("intensity", 128)), 0, 255)
			var instruction := {"opcode": opcode, "connection_index": connection_index, "sequence_index": sequence_index, "intensity": intensity}
			if bool(symbol.get("takes_operand", false)):
				instruction["operand"] = intensity
			instructions.append(instruction)
		if instructions.size() > instruction_start and int(instructions.back()["opcode"]) != RuneCatalog.OPCODE_HALT:
			instructions.append({"opcode": RuneCatalog.OPCODE_HALT, "implicit": true, "sequence_index": sequence_index})
			inserted_halts += 1

	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings}
	if instructions.is_empty():
		return {"ok": false, "errors": ["Não há selos para compilar."], "warnings": warnings}
	if inserted_halts > 0:
		warnings.append("HALT foi inserido automaticamente no fim de %d sequência(s)." % inserted_halts)

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


func _linearize_sequences(connections: Array, errors: Array[String], warnings: Array[String]) -> Array:
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
	var sequences: Array = []
	var remaining_starts: Array[int] = starts.duplicate()
	if starts.size() > 1:
		warnings.append("Foram encontradas %d sequências; o ritual começou pela sequência mais à esquerda." % starts.size())
	while not remaining_starts.is_empty():
		var start_index := _leftmost_start(connections, remaining_starts)
		remaining_starts.erase(start_index)
		var sequence := _linearize_from_start(connections, start_index, errors)
		if not errors.is_empty():
			return []
		sequences.append(sequence)
	return sequences


func _linearize_from_start(connections: Array, start_index: int, errors: Array[String]) -> Array[int]:
	var ordered: Array[int] = []
	var current_index := start_index
	var visited := {}
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

	return ordered


func _leftmost_start(connections: Array, starts: Array[int]) -> int:
	var chosen_index := starts[0]
	var chosen_connection: Dictionary = connections[chosen_index]
	var chosen_point: Vector2 = chosen_connection["from"]
	for candidate_index in starts:
		var candidate_connection: Dictionary = connections[candidate_index]
		var candidate_point: Vector2 = candidate_connection["from"]
		if candidate_point.x < chosen_point.x or (is_equal_approx(candidate_point.x, chosen_point.x) and candidate_point.y < chosen_point.y):
			chosen_index = candidate_index
			chosen_point = candidate_point
	return chosen_index


func _point_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x), roundi(point.y)]
