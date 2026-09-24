class_name AtelierRuneCompiler
extends RefCounted

## Compilador do grafo visual para bytecode binário da máquina virtual Atelier.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")


func compile(connections: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var diagnostics: Array[Dictionary] = []
	if connections.is_empty():
		return {"ok": false, "errors": [tr("COMPILER_NO_CONNECTIONS")], "warnings": warnings, "diagnostics": diagnostics}

	var sequences := _linearize_sequences(connections, errors, warnings)
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "warnings": warnings, "diagnostics": diagnostics}

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
				var diagnostic := _rune_diagnostic(connection_index, "COMPILER_UNKNOWN_RUNE")
				diagnostics.append(diagnostic)
				errors.append(str(diagnostic["message"]))
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
		return {"ok": false, "errors": errors, "warnings": warnings, "diagnostics": diagnostics}
	if instructions.is_empty():
		return {"ok": false, "errors": [tr("COMPILER_NO_RUNES")], "warnings": warnings, "diagnostics": diagnostics}
	diagnostics = _validate_rune_dependencies(instructions)
	if not diagnostics.is_empty():
		for diagnostic in diagnostics:
			errors.append(str(diagnostic["message"]))
		return {"ok": false, "errors": errors, "warnings": warnings, "diagnostics": diagnostics}
	if inserted_halts > 0:
		warnings.append(tr("COMPILER_IMPLICIT_HALT") % [inserted_halts])

	return {"ok": true, "instructions": instructions, "bytecode": RuneBytecode.encode(instructions), "errors": errors, "warnings": warnings, "diagnostics": diagnostics}


## code é a chave de tradução do problema: testes e ferramentas comparam o
## código; "message" é o texto já traduzido para o Oráculo.
func _rune_diagnostic(connection_index: int, code: String, args: Array = []) -> Dictionary:
	var detail := tr(code) % args if not args.is_empty() else tr(code)
	return {"connection_index": connection_index, "code": code, "message": tr("COMPILER_CELL") % [connection_index + 1, detail]}


func _validate_rune_dependencies(instructions: Array[Dictionary]) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var warps := {}
	var endpoints := {}
	var mutable_runes := _potential_intensity_targets(instructions)
	var mutable_portal := false
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		if opcode != RuneCatalog.OPCODE_WARP and opcode != RuneCatalog.OPCODE_WARP_ENDPOINT:
			continue
		if mutable_runes.has(index):
			mutable_portal = true
		var groups: Dictionary = warps if opcode == RuneCatalog.OPCODE_WARP else endpoints
		var intensity := int(instruction.get("intensity", 0))
		var members: Array = groups.get(intensity, [])
		members.append(index)
		groups[intensity] = members
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		if not instruction.has("connection_index"):
			continue
		var opcode := int(instruction["opcode"])
		var connection_index := int(instruction["connection_index"])
		var intensity := int(instruction.get("intensity", 0))
		var endpoint_count := (endpoints.get(intensity, []) as Array).size()
		match opcode:
			RuneCatalog.OPCODE_WARP:
				if endpoint_count > 1 and not mutable_portal:
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_WARP_MANY_ENDS", [intensity]))
				elif endpoint_count == 0 and (warps.get(intensity, []) as Array).size() < 2 and not mutable_portal:
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_WARP_NO_TARGET", [intensity]))
			RuneCatalog.OPCODE_WARP_ENDPOINT:
				if endpoint_count > 1 and not mutable_portal:
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_WARP_END_DUPLICATE", [intensity]))
			RuneCatalog.OPCODE_JUMP_IF_TRUE:
				if endpoint_count > 1 and not mutable_portal and not mutable_runes.has(index):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_JUMP_MANY_ENDS", [intensity]))
				elif endpoint_count == 0 and not warps.has(intensity) and not mutable_portal and not mutable_runes.has(index):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_JUMP_NO_TARGET", [intensity]))
			RuneCatalog.OPCODE_INT_MOD:
				var operation_index := index + 1
				if not _same_sequence_rune(instructions, index, operation_index):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_MOD_NEEDS_TWO"))
					continue
				var operation: Dictionary = instructions[operation_index]
				var operation_opcode := int(operation["opcode"])
				if operation_opcode not in [RuneCatalog.OPCODE_ADD, RuneCatalog.OPCODE_SUB, RuneCatalog.OPCODE_MUL, RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD, RuneCatalog.OPCODE_NEG]:
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_MOD_NEEDS_OP"))
					continue
				if not _same_sequence_rune(instructions, index, index + 2):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_MOD_NO_TARGET"))
				elif operation_opcode in [RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD] and int(operation.get("intensity", 0)) == 0 and not mutable_runes.has(operation_index):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_MOD_ZERO"))
			RuneCatalog.OPCODE_INT_SET:
				var value_index := index + 1
				var has_control_flow := false
				while _same_sequence_rune(instructions, index, value_index):
					var candidate: Dictionary = instructions[value_index]
					var candidate_opcode := int(candidate["opcode"])
					if candidate_opcode in [RuneCatalog.OPCODE_WARP, RuneCatalog.OPCODE_JUMP_IF_TRUE]:
						has_control_flow = true
					if candidate_opcode == RuneCatalog.OPCODE_INT_SET:
						break
					if RuneCatalog.produces_value_type(candidate_opcode, "int"):
						break
					value_index += 1
				if has_control_flow:
					continue # O valor pode vir de outra sequência após um salto.
				if not _same_sequence_rune(instructions, index, value_index):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_SET_NO_VALUE"))
				elif int(instructions[value_index]["opcode"]) == RuneCatalog.OPCODE_INT_SET:
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_SET_NESTED"))
				elif not _same_sequence_rune(instructions, index, value_index + 1):
					diagnostics.append(_rune_diagnostic(connection_index, "COMPILER_INT_SET_NO_TARGET"))
	return diagnostics


func _potential_intensity_targets(instructions: Array[Dictionary]) -> Dictionary:
	var targets := {}
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		if opcode == RuneCatalog.OPCODE_INT_MOD and _same_sequence_rune(instructions, index, index + 2):
			targets[index + 2] = true
		elif opcode == RuneCatalog.OPCODE_INT_SET:
			var value_index := index + 1
			while _same_sequence_rune(instructions, index, value_index):
				if RuneCatalog.produces_value_type(int(instructions[value_index]["opcode"]), "int"):
					if _same_sequence_rune(instructions, index, value_index + 1):
						targets[value_index + 1] = true
					break
				value_index += 1
	return targets


func _same_sequence_rune(instructions: Array[Dictionary], source_index: int, candidate_index: int) -> bool:
	if candidate_index >= instructions.size():
		return false
	var candidate: Dictionary = instructions[candidate_index]
	return candidate.has("connection_index") and int(candidate.get("sequence_index", -1)) == int(instructions[source_index].get("sequence_index", -2)) and int(candidate["opcode"]) != RuneCatalog.OPCODE_HALT


func export_binary(connections: Array, path: String) -> Dictionary:
	var result := compile(connections)
	if not result["ok"]:
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["ok"] = false
		result["errors"] = ["Could not write the binary to %s." % path]  # dev-only
		return result
	file.store_buffer(result["bytecode"])
	file.close()
	result["path"] = path
	return result


func _linearize_sequences(connections: Array, errors: Array[String], warnings: Array[String]) -> Array:
	var point_connections := _build_point_connections(connections)
	var remaining_connections := {}
	for index in range(connections.size()):
		remaining_connections[index] = true
	var sequence_entries: Array[Dictionary] = []
	while not remaining_connections.is_empty():
		var component_start_index := -1
		for raw_index in remaining_connections:
			component_start_index = int(raw_index)
			break
		var component := _collect_component(connections, component_start_index, point_connections)
		for connection_index in component:
			remaining_connections.erase(connection_index)
		var endpoints := _component_endpoints(connections, component, point_connections, errors)
		if not errors.is_empty():
			return []
		if endpoints.size() != 2:
			errors.append(tr("COMPILER_SEQUENCE_ENDS") % [component_start_index + 1])
			return []
		var start_point: Vector2 = endpoints[0]
		if _is_point_before(endpoints[1], start_point):
			start_point = endpoints[1]
		var sequence := _linearize_component(connections, component, start_point, point_connections, errors)
		if not errors.is_empty():
			return []
		sequence_entries.append({
			"connections": sequence,
			"start_point": start_point,
		})

	if sequence_entries.size() > 1:
		warnings.append(tr("COMPILER_MANY_SEQUENCES") % [sequence_entries.size()])
	var sequences: Array = []
	while not sequence_entries.is_empty():
		var entry_index := _leftmost_sequence_entry(sequence_entries)
		var entry: Dictionary = sequence_entries[entry_index]
		sequences.append(entry["connections"])
		sequence_entries.remove_at(entry_index)
	return sequences


func _build_point_connections(connections: Array) -> Dictionary:
	var point_connections := {}
	for connection_index in range(connections.size()):
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		_add_connection_at_point(point_connections, from_point, connection_index)
		_add_connection_at_point(point_connections, to_point, connection_index)
	return point_connections


func _add_connection_at_point(point_connections: Dictionary, point: Vector2, connection_index: int) -> void:
	var point_key := _point_key(point)
	var linked_connections: Array = point_connections.get(point_key, [])
	linked_connections.append(connection_index)
	point_connections[point_key] = linked_connections


func _collect_component(connections: Array, start_index: int, point_connections: Dictionary) -> Array[int]:
	var component: Array[int] = []
	var pending: Array[int] = [start_index]
	var visited := {}
	while not pending.is_empty():
		var connection_index: int = pending.pop_back()
		if visited.has(connection_index):
			continue
		visited[connection_index] = true
		component.append(connection_index)
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		_append_unvisited_connections(point_connections, from_point, visited, pending)
		_append_unvisited_connections(point_connections, to_point, visited, pending)
	return component


func _append_unvisited_connections(point_connections: Dictionary, point: Vector2, visited: Dictionary, pending: Array[int]) -> void:
	var linked_connections: Array = point_connections[_point_key(point)]
	for raw_linked_index in linked_connections:
		var linked_index := int(raw_linked_index)
		if not visited.has(linked_index):
			pending.append(linked_index)


func _component_endpoints(connections: Array, component: Array[int], point_connections: Dictionary, errors: Array[String]) -> Array[Vector2]:
	var component_members := {}
	for connection_index in component:
		component_members[connection_index] = true
	var endpoints: Array[Vector2] = []
	var checked_points := {}
	for connection_index in component:
		var connection: Dictionary = connections[connection_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		_inspect_component_point(from_point, component_members, point_connections, checked_points, endpoints, errors)
		if not errors.is_empty():
			return []
		_inspect_component_point(to_point, component_members, point_connections, checked_points, endpoints, errors)
		if not errors.is_empty():
			return []
	return endpoints


func _inspect_component_point(point: Vector2, component_members: Dictionary, point_connections: Dictionary, checked_points: Dictionary, endpoints: Array[Vector2], errors: Array[String]) -> void:
	var point_key := _point_key(point)
	if checked_points.has(point_key):
		return
	checked_points[point_key] = true
	var degree := 0
	var linked_connections: Array = point_connections[point_key]
	for raw_linked_index in linked_connections:
		if component_members.has(int(raw_linked_index)):
			degree += 1
	if degree > 2:
		errors.append(tr("COMPILER_BRANCH") % [point_key])
	elif degree == 1:
		endpoints.append(point)


func _linearize_component(connections: Array, component: Array[int], start_point: Vector2, point_connections: Dictionary, errors: Array[String]) -> Array[int]:
	var component_members := {}
	for connection_index in component:
		component_members[connection_index] = true
	var ordered: Array[int] = []
	var current_point := start_point
	var previous_index := -1
	while ordered.size() < component.size():
		var next_index := -1
		var linked_connections: Array = point_connections[_point_key(current_point)]
		for raw_linked_index in linked_connections:
			var candidate_index := int(raw_linked_index)
			if candidate_index == previous_index or not component_members.has(candidate_index):
				continue
			if next_index >= 0:
				errors.append(tr("COMPILER_BRANCH") % [_point_key(current_point)])
				return []
			next_index = candidate_index
		if next_index < 0:
			errors.append(tr("COMPILER_SEQUENCE_BROKEN"))
			return []
		ordered.append(next_index)
		var connection: Dictionary = connections[next_index]
		var from_point: Vector2 = connection["from"]
		var to_point: Vector2 = connection["to"]
		current_point = to_point if from_point.is_equal_approx(current_point) else from_point
		previous_index = next_index

	return ordered


func _leftmost_sequence_entry(entries: Array[Dictionary]) -> int:
	var chosen_index := 0
	var chosen_entry: Dictionary = entries[chosen_index]
	var chosen_point: Vector2 = chosen_entry["start_point"]
	for entry_index in range(1, entries.size()):
		var candidate_entry: Dictionary = entries[entry_index]
		var candidate_point: Vector2 = candidate_entry["start_point"]
		if _is_point_before(candidate_point, chosen_point):
			chosen_index = entry_index
			chosen_point = candidate_point
	return chosen_index


func _is_point_before(candidate: Vector2, reference: Vector2) -> bool:
	return candidate.x < reference.x or (is_equal_approx(candidate.x, reference.x) and candidate.y < reference.y)


func _point_key(point: Vector2) -> String:
	return "%d:%d" % [roundi(point.x), roundi(point.y)]
