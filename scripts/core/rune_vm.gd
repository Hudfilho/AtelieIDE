class_name AtelierRuneVM
extends RefCounted

## Máquina virtual mínima para executar o bytecode RUNE dentro da IDE.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")


func run(bytecode: PackedByteArray) -> Dictionary:
	var decoded := RuneBytecode.decode(bytecode)
	if not decoded["ok"]:
		return {"ok": false, "errors": decoded["errors"], "output": []}

	var state := create_state()
	var instructions: Array = decoded["instructions"]
	configure_program(state, instructions)
	if bool(state["halted"]):
		return result_from_state(state)
	var steps := 0
	var pc := 0
	while pc < instructions.size() and steps < 10000:
		steps += 1
		var instruction: Dictionary = instructions[pc]
		step(instruction, state, pc)
		if bool(state["halted"]):
			break
		var jump_target := int(state["jump_target"])
		pc = jump_target if jump_target >= 0 else pc + 1
	if steps >= 10000 and not bool(state["halted"]):
		var errors: Array = state["errors"]
		errors.append("Limite de passos excedido.")
		state["halted"] = true
	return result_from_state(state)


func create_state() -> Dictionary:
	return {"stack": [], "memory": {}, "output": [], "errors": [], "halted": false, "jump_target": -1, "warp_targets": {}, "jump_if_true_targets": {}, "warp_endpoint_counts": {}, "program": [], "pending_int_set": -1}


func configure_program(state: Dictionary, instructions: Array) -> void:
	state["program"] = instructions
	var warp_groups := {}
	var endpoint_groups := {}
	var jump_if_true_groups := {}
	for instruction_index in range(instructions.size()):
		var instruction: Dictionary = instructions[instruction_index]
		var opcode := int(instruction["opcode"])
		var intensity := int(instruction.get("operand", instruction.get("intensity", 0)))
		if opcode == RuneCatalog.OPCODE_WARP:
			if not warp_groups.has(intensity):
				warp_groups[intensity] = []
			var group: Array = warp_groups[intensity]
			group.append(instruction_index)
		elif opcode == RuneCatalog.OPCODE_WARP_ENDPOINT:
			if not endpoint_groups.has(intensity):
				endpoint_groups[intensity] = []
			var endpoint_indices: Array = endpoint_groups[intensity]
			endpoint_indices.append(instruction_index)
		elif opcode == RuneCatalog.OPCODE_JUMP_IF_TRUE:
			if not jump_if_true_groups.has(intensity):
				jump_if_true_groups[intensity] = []
			var jump_indices: Array = jump_if_true_groups[intensity]
			jump_indices.append(instruction_index)
	var targets := {}
	var jump_if_true_targets := {}
	var endpoint_counts := {}
	var errors: Array = state["errors"]
	for intensity in endpoint_groups:
		var counted_endpoint_indices: Array = endpoint_groups[intensity]
		endpoint_counts[intensity] = counted_endpoint_indices.size()
	for intensity in warp_groups:
		var group: Array = warp_groups[intensity]
		var endpoint_count := int(endpoint_counts.get(intensity, 0))
		if endpoint_count == 1:
			var matching_endpoint_indices: Array = endpoint_groups[intensity]
			var target_index := int(matching_endpoint_indices[0]) + 1
			for source_index in group:
				targets[int(source_index)] = target_index
		elif group.size() >= 2:
			for group_index in range(group.size()):
				var source_index := int(group[group_index])
				var target_index := int(group[(group_index + 1) % group.size()]) + 1
				targets[source_index] = target_index
	for intensity in jump_if_true_groups:
		var jump_indices: Array = jump_if_true_groups[intensity]
		var endpoint_count := int(endpoint_counts.get(intensity, 0))
		if endpoint_count == 1:
			var matching_endpoint_indices: Array = endpoint_groups[intensity]
			var endpoint_target_index := int(matching_endpoint_indices[0]) + 1
			for source_index in jump_indices:
				jump_if_true_targets[int(source_index)] = endpoint_target_index
		elif warp_groups.has(intensity):
			var matching_warp_indices: Array = warp_groups[intensity]
			for source_index in jump_indices:
				jump_if_true_targets[int(source_index)] = _jump_target_from_warp_group(int(source_index), matching_warp_indices)
	state["warp_targets"] = targets
	state["jump_if_true_targets"] = jump_if_true_targets
	state["warp_endpoint_counts"] = endpoint_counts
	state["halted"] = not errors.is_empty()


func step(instruction: Dictionary, state: Dictionary, instruction_index := -1) -> Dictionary:
	if bool(state.get("halted", false)):
		return state
	var stack: Array = state["stack"]
	var memory: Dictionary = state["memory"]
	var output: Array = state["output"]
	var errors: Array = state["errors"]
	var opcode := int(instruction["opcode"])
	var should_halt := false
	state["jump_target"] = -1
	match opcode:
		RuneCatalog.OPCODE_PUSH:
			stack.append(int(instruction["operand"]))
		RuneCatalog.OPCODE_DROP:
			if stack.is_empty():
				errors.append("DROP precisa de um valor na pilha.")
			else:
				stack.pop_back()
		RuneCatalog.OPCODE_DUP:
			if stack.is_empty():
				errors.append("DUP precisa de um valor na pilha.")
			else:
				stack.append(int(stack.back()))
		RuneCatalog.OPCODE_SWAP:
			if stack.size() < 2:
				errors.append("SWAP precisa de dois valores na pilha.")
			else:
				var swap_right := int(stack.pop_back())
				var swap_left := int(stack.pop_back())
				stack.append(swap_right)
				stack.append(swap_left)
		RuneCatalog.OPCODE_NEG:
			if stack.is_empty():
				errors.append("NEG precisa de um valor na pilha.")
			else:
				stack.append(-int(stack.pop_back()))
		RuneCatalog.OPCODE_ADD, RuneCatalog.OPCODE_SUB, RuneCatalog.OPCODE_MUL, RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD:
			if stack.size() < 2:
				errors.append("%s precisa de dois valores na pilha." % RuneCatalog.name_for_opcode(opcode))
			else:
				var right := int(stack.pop_back())
				var left := int(stack.pop_back())
				if (opcode == RuneCatalog.OPCODE_DIV or opcode == RuneCatalog.OPCODE_MOD) and right == 0:
					errors.append("%s não aceita divisão por zero." % RuneCatalog.name_for_opcode(opcode))
				elif opcode == RuneCatalog.OPCODE_ADD:
					stack.append(left + right)
				elif opcode == RuneCatalog.OPCODE_SUB:
					stack.append(left - right)
				elif opcode == RuneCatalog.OPCODE_MUL:
					stack.append(left * right)
				elif opcode == RuneCatalog.OPCODE_DIV:
					stack.append(int(left / right))
				else:
					stack.append(left % right)
		RuneCatalog.OPCODE_EQ, RuneCatalog.OPCODE_NEQ, RuneCatalog.OPCODE_LT, RuneCatalog.OPCODE_GT, RuneCatalog.OPCODE_LTE, RuneCatalog.OPCODE_GTE:
			if stack.size() < 2:
				errors.append("%s precisa de dois valores na pilha." % RuneCatalog.name_for_opcode(opcode))
			else:
				var comparison_right := int(stack.pop_back())
				var comparison_left := int(stack.pop_back())
				var comparison_result: bool = false
				match opcode:
					RuneCatalog.OPCODE_EQ:
						comparison_result = comparison_left == comparison_right
					RuneCatalog.OPCODE_NEQ:
						comparison_result = comparison_left != comparison_right
					RuneCatalog.OPCODE_LT:
						comparison_result = comparison_left < comparison_right
					RuneCatalog.OPCODE_GT:
						comparison_result = comparison_left > comparison_right
					RuneCatalog.OPCODE_LTE:
						comparison_result = comparison_left <= comparison_right
					RuneCatalog.OPCODE_GTE:
						comparison_result = comparison_left >= comparison_right
				stack.append(1 if comparison_result else 0)
		RuneCatalog.OPCODE_NOT:
			if stack.is_empty():
				errors.append("NOT precisa de um booleano na pilha.")
			else:
				var boolean_value := int(stack.pop_back())
				if not _is_boolean(boolean_value):
					errors.append("NOT aceita apenas 0 ou 1, recebeu %d." % boolean_value)
				else:
					stack.append(0 if boolean_value == 1 else 1)
		RuneCatalog.OPCODE_AND, RuneCatalog.OPCODE_OR:
			if stack.size() < 2:
				errors.append("%s precisa de dois booleanos na pilha." % RuneCatalog.name_for_opcode(opcode))
			else:
				var boolean_right := int(stack.pop_back())
				var boolean_left := int(stack.pop_back())
				if not _is_boolean(boolean_left) or not _is_boolean(boolean_right):
					errors.append("%s aceita apenas 0 ou 1." % RuneCatalog.name_for_opcode(opcode))
				elif opcode == RuneCatalog.OPCODE_AND:
					stack.append(1 if boolean_left == 1 and boolean_right == 1 else 0)
				else:
					stack.append(1 if boolean_left == 1 or boolean_right == 1 else 0)
		RuneCatalog.OPCODE_PRINT:
			if stack.is_empty():
				errors.append("PRINT precisa de um valor na pilha.")
			else:
				output.append(str(stack.back()))
		RuneCatalog.OPCODE_PRINTLETTER:
			var unicode_codepoint := int(instruction.get("operand", instruction.get("intensity", 0)))
			output.append(String.chr(unicode_codepoint))
		RuneCatalog.OPCODE_STORE:
			if stack.is_empty():
				errors.append("STORE precisa de um valor na pilha.")
			else:
				memory[int(instruction["operand"])] = stack.pop_back()
		RuneCatalog.OPCODE_LOAD:
			var slot := int(instruction["operand"])
			if not memory.has(slot):
				errors.append("LOAD tentou ler a posição %d, que está vazia." % slot)
			else:
				stack.append(int(memory[slot]))
		RuneCatalog.OPCODE_WARP:
			var warp_targets: Dictionary = state["warp_targets"]
			var warp_intensity := int(instruction.get("intensity", instruction.get("operand", 0)))
			var endpoint_counts: Dictionary = state["warp_endpoint_counts"]
			if int(endpoint_counts.get(warp_intensity, 0)) > 1:
				errors.append("WARP %03d encontrou mais de um WARP END com a mesma intensidade." % warp_intensity)
			elif instruction_index < 0 or not warp_targets.has(instruction_index):
				errors.append("WARP %03d não encontrou outro portal ou WARP END compatível." % warp_intensity)
			else:
				state["jump_target"] = int(warp_targets[instruction_index])
		RuneCatalog.OPCODE_WARP_ENDPOINT:
			pass
		RuneCatalog.OPCODE_JUMP_IF_TRUE:
			_execute_jump_if_true(state, instruction, instruction_index)
		RuneCatalog.OPCODE_INT_MOD:
			_resolve_intensity_modifier(state, instruction_index)
		RuneCatalog.OPCODE_INT_SET:
			_begin_intensity_set(state, instruction_index)
		RuneCatalog.OPCODE_HALT:
			should_halt = true
		_:
			errors.append("Opcode não implementado: %d." % opcode)
	if opcode != RuneCatalog.OPCODE_INT_SET:
		_try_finish_intensity_set(state, instruction_index, opcode, stack)
	state["halted"] = should_halt or not errors.is_empty()
	return state


func _begin_intensity_set(state: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	if int(state["pending_int_set"]) >= 0:
		errors.append("INT_SET anterior ainda está esperando um valor.")
		return
	state["pending_int_set"] = instruction_index


func _is_boolean(value: int) -> bool:
	return value == 0 or value == 1


func _jump_target_from_warp_group(jump_index: int, warp_indices: Array) -> int:
	for raw_warp_index in warp_indices:
		var warp_index := int(raw_warp_index)
		if warp_index > jump_index:
			return warp_index + 1
	return int(warp_indices[0]) + 1


func _execute_jump_if_true(state: Dictionary, instruction: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	var program: Array = state["program"]
	if instruction_index < 0 or instruction_index + 1 >= program.size() or int(program[instruction_index + 1]["opcode"]) == RuneCatalog.OPCODE_HALT:
		errors.append("JUMP_IF_TRUE precisa de um selo depois dele para verificar.")
		return
	var condition_instruction: Dictionary = program[instruction_index + 1]
	if _instruction_intensity(condition_instruction) != 1:
		return
	var jump_intensity := _instruction_intensity(instruction)
	var endpoint_counts: Dictionary = state["warp_endpoint_counts"]
	if int(endpoint_counts.get(jump_intensity, 0)) > 1:
		errors.append("JUMP_IF_TRUE %03d encontrou mais de um WARP END compatível." % jump_intensity)
		return
	var jump_targets: Dictionary = state["jump_if_true_targets"]
	if not jump_targets.has(instruction_index):
		errors.append("JUMP_IF_TRUE %03d não encontrou WARP ou WARP END compatível." % jump_intensity)
		return
	state["jump_target"] = int(jump_targets[instruction_index])


func _try_finish_intensity_set(state: Dictionary, instruction_index: int, opcode: int, stack: Array) -> void:
	var pending_index := int(state["pending_int_set"])
	if pending_index < 0 or instruction_index <= pending_index:
		return
	var errors: Array = state["errors"]
	if not errors.is_empty():
		return
	if opcode == RuneCatalog.OPCODE_HALT:
		errors.append("INT_SET terminou sem encontrar um valor inteiro.")
		return
	if not RuneCatalog.produces_value_type(opcode, "int") or stack.is_empty():
		return
	var program: Array = state["program"]
	var target_index := instruction_index + 1
	if target_index >= program.size() or int(program[target_index]["opcode"]) == RuneCatalog.OPCODE_HALT:
		errors.append("INT_SET encontrou um valor, mas não encontrou um selo-alvo.")
		return
	var new_intensity := clampi(int(stack.pop_back()), 0, 255)
	_set_instruction_intensity(program, target_index, new_intensity)
	state["pending_int_set"] = -1
	configure_program(state, program)
	if errors.is_empty():
		state["jump_target"] = target_index


func _resolve_intensity_modifier(state: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	var program: Array = state["program"]
	if instruction_index < 0 or instruction_index + 2 >= program.size():
		errors.append("INT_MOD espera dois selos depois dele.")
		return
	var argument_instruction: Dictionary = program[instruction_index + 1]
	var target_instruction: Dictionary = program[instruction_index + 2]
	var operation_opcode := int(argument_instruction["opcode"])
	if operation_opcode not in [RuneCatalog.OPCODE_ADD, RuneCatalog.OPCODE_SUB, RuneCatalog.OPCODE_MUL, RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD, RuneCatalog.OPCODE_NEG]:
		errors.append("INT_MOD espera ADD, SUB, MUL, DIV, MOD ou NEG logo depois dele.")
		return
	var current_intensity := _instruction_intensity(target_instruction)
	var operand := _instruction_intensity(argument_instruction)
	var modified_intensity := current_intensity
	match operation_opcode:
		RuneCatalog.OPCODE_ADD:
			modified_intensity = current_intensity + operand
		RuneCatalog.OPCODE_SUB:
			modified_intensity = current_intensity - operand
		RuneCatalog.OPCODE_MUL:
			modified_intensity = current_intensity * operand
		RuneCatalog.OPCODE_DIV:
			if operand == 0:
				errors.append("INT_MOD DIV não aceita intensidade 000.")
				return
			modified_intensity = int(current_intensity / operand)
		RuneCatalog.OPCODE_MOD:
			if operand == 0:
				errors.append("INT_MOD MOD não aceita intensidade 000.")
				return
			modified_intensity = current_intensity % operand
		RuneCatalog.OPCODE_NEG:
			modified_intensity = -current_intensity
	_set_instruction_intensity(program, instruction_index + 2, clampi(modified_intensity, 0, 255))
	configure_program(state, program)
	if errors.is_empty():
		state["jump_target"] = instruction_index + 2


func _instruction_intensity(instruction: Dictionary) -> int:
	return clampi(int(instruction.get("intensity", instruction.get("operand", 128))), 0, 255)


func _set_instruction_intensity(program: Array, instruction_index: int, intensity: int) -> void:
	var instruction: Dictionary = program[instruction_index]
	var modified_intensity := clampi(intensity, 0, 255)
	instruction["intensity"] = modified_intensity
	if RuneCatalog.takes_operand(int(instruction["opcode"])):
		instruction["operand"] = modified_intensity
	program[instruction_index] = instruction


func result_from_state(state: Dictionary) -> Dictionary:
	var errors: Array = state["errors"]
	return {"ok": errors.is_empty(), "errors": errors, "output": state["output"], "stack": state["stack"]}
