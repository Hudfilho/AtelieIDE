class_name AtelierRuneVM
extends RefCounted

## Máquina virtual mínima para executar o bytecode RUNE dentro da IDE.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")
const RunePortals = preload("res://scripts/core/rune_portals.gd")
const MAX_RUN_STEPS := 10000
## Saltos do PORTAL FRÁGIL antes de quebrar, por raridade (comum..lendária).
const FRAGILE_WARP_USES := [2, 3, 5, 8]


## initial_memory semeia a memória antes da execução: é assim que uma
## encomenda entrega seus parâmetros para READ/LOAD.
func run(bytecode: PackedByteArray, initial_memory: Dictionary = {}, max_steps := MAX_RUN_STEPS) -> Dictionary:
	var decoded := RuneBytecode.decode(bytecode)
	if not decoded["ok"]:
		return {"ok": false, "errors": decoded["errors"], "output": []}

	return run_program(decoded["instructions"], initial_memory, max_steps)


## Executa instruções já compiladas (sem passar pelo bytecode). O modo jogo
## usa isto para manter connection_index e raridade de cada instrução.
func run_program(instructions: Array, initial_memory: Dictionary = {}, max_steps := MAX_RUN_STEPS) -> Dictionary:
	var state := create_state()
	state["memory"] = initial_memory.duplicate()
	configure_program(state, instructions)
	if bool(state["halted"]):
		return result_from_state(state)
	var steps := 0
	var pc := 0
	while pc < instructions.size() and steps < max_steps:
		steps += 1
		var instruction: Dictionary = instructions[pc]
		step(instruction, state, pc)
		if bool(state["halted"]):
			break
		var jump_target := int(state["jump_target"])
		pc = jump_target if jump_target >= 0 else pc + 1
	var timed_out := steps >= max_steps and not bool(state["halted"])
	if timed_out:
		var errors: Array = state["errors"]
		errors.append(tr("VM_STEP_LIMIT"))
		state["halted"] = true
	var result := result_from_state(state)
	result["steps"] = steps
	result["timed_out"] = timed_out
	return result


func create_state() -> Dictionary:
	return {
		"stack": [], "memory": {}, "output": [], "errors": [],
		"halted": false, "jump_target": -1,
		"warp_targets": {}, "jump_if_true_targets": {}, "warp_endpoint_counts": {},
		"program": [], "pending_int_set": -1,
		# Pilha mágica: propriedades na ordem em que as runas mágicas executaram.
		"magic": [],
		# DUPLICAR: quantas repetições extras a próxima instrução ainda deve ter.
		"repeat_next": 0,
		# PORTAL FRÁGIL: índice da instrução -> saltos já feitos.
		"warp_uses": {},
	}


func configure_program(state: Dictionary, instructions: Array) -> void:
	state["program"] = instructions
	var targets := RunePortals.resolve(instructions)
	state["warp_targets"] = targets["warp"]
	state["jump_if_true_targets"] = targets["conditional"]
	state["warp_endpoint_counts"] = targets["endpoint_counts"]
	state["halted"] = not (state["errors"] as Array).is_empty()


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
				errors.append(tr("VM_NEEDS_VALUE") % ["DROP"])
			else:
				stack.pop_back()
		RuneCatalog.OPCODE_DUP:
			if stack.is_empty():
				errors.append(tr("VM_NEEDS_VALUE") % ["DUP"])
			else:
				stack.append(int(stack.back()))
		RuneCatalog.OPCODE_SWAP:
			if stack.size() < 2:
				errors.append(tr("VM_NEEDS_TWO_VALUES") % ["SWAP"])
			else:
				var swap_right := int(stack.pop_back())
				var swap_left := int(stack.pop_back())
				stack.append(swap_right)
				stack.append(swap_left)
		RuneCatalog.OPCODE_NEG:
			if stack.is_empty():
				errors.append(tr("VM_NEEDS_VALUE") % ["NEG"])
			else:
				stack.append(-int(stack.pop_back()))
		RuneCatalog.OPCODE_ADD, RuneCatalog.OPCODE_SUB, RuneCatalog.OPCODE_MUL, RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD:
			if stack.size() < 2:
				errors.append(tr("VM_NEEDS_TWO_VALUES") % [RuneCatalog.name_for_opcode(opcode)])
			else:
				var right := int(stack.pop_back())
				var left := int(stack.pop_back())
				if (opcode == RuneCatalog.OPCODE_DIV or opcode == RuneCatalog.OPCODE_MOD) and right == 0:
					errors.append(tr("VM_DIVISION_BY_ZERO") % [RuneCatalog.name_for_opcode(opcode)])
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
				errors.append(tr("VM_NEEDS_TWO_VALUES") % [RuneCatalog.name_for_opcode(opcode)])
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
				errors.append(tr("VM_NEEDS_BOOLEAN") % ["NOT"])
			else:
				var boolean_value := int(stack.pop_back())
				if not _is_boolean(boolean_value):
					errors.append(tr("VM_NOT_BOOLEAN_GOT") % [boolean_value])
				else:
					stack.append(0 if boolean_value == 1 else 1)
		RuneCatalog.OPCODE_AND, RuneCatalog.OPCODE_OR:
			if stack.size() < 2:
				errors.append(tr("VM_NEEDS_TWO_BOOLEANS") % [RuneCatalog.name_for_opcode(opcode)])
			else:
				var boolean_right := int(stack.pop_back())
				var boolean_left := int(stack.pop_back())
				if not _is_boolean(boolean_left) or not _is_boolean(boolean_right):
					errors.append(tr("VM_ONLY_BOOLEANS") % [RuneCatalog.name_for_opcode(opcode)])
				elif opcode == RuneCatalog.OPCODE_AND:
					stack.append(1 if boolean_left == 1 and boolean_right == 1 else 0)
				else:
					stack.append(1 if boolean_left == 1 or boolean_right == 1 else 0)
		RuneCatalog.OPCODE_PRINT:
			if stack.is_empty():
				errors.append(tr("VM_NEEDS_VALUE") % ["PRINT"])
			else:
				output.append(str(stack.back()))
		RuneCatalog.OPCODE_PRINTLETTER:
			var unicode_codepoint := int(instruction.get("operand", instruction.get("intensity", 0)))
			output.append(String.chr(unicode_codepoint))
		RuneCatalog.OPCODE_STORE:
			if stack.is_empty():
				errors.append(tr("VM_NEEDS_VALUE") % ["STORE"])
			else:
				memory[int(instruction["operand"])] = stack.pop_back()
		RuneCatalog.OPCODE_LOAD:
			var slot := int(instruction["operand"])
			if not memory.has(slot):
				errors.append(tr("VM_EMPTY_SLOT") % ["LOAD", slot])
			else:
				stack.append(int(memory[slot]))
		RuneCatalog.OPCODE_READ:
			var read_slot := int(instruction.get("operand", instruction.get("intensity", 0)))
			if not memory.has(read_slot):
				errors.append(tr("VM_EMPTY_SLOT") % ["READ", read_slot])
			else:
				stack.append(int(memory[read_slot]))
		RuneCatalog.OPCODE_WARP_FRAGILE:
			var uses: Dictionary = state["warp_uses"]
			var rarity := clampi(int(instruction.get("rarity", 0)), 0, FRAGILE_WARP_USES.size() - 1)
			if int(uses.get(instruction_index, 0)) < int(FRAGILE_WARP_USES[rarity]):
				uses[instruction_index] = int(uses.get(instruction_index, 0)) + 1
				_execute_warp(state, instruction, instruction_index)
			# Quebrado: vira passagem, a execução segue em frente.
		RuneCatalog.OPCODE_WARP:
			_execute_warp(state, instruction, instruction_index)
		RuneCatalog.OPCODE_WARP_ENDPOINT:
			pass
		RuneCatalog.OPCODE_JUMP_IF_TRUE:
			_execute_jump_if_true(state, instruction, instruction_index)
		RuneCatalog.OPCODE_INT_MOD:
			_resolve_intensity_modifier(state, instruction_index)
		RuneCatalog.OPCODE_INT_SET:
			_begin_intensity_set(state, instruction_index)
		RuneCatalog.OPCODE_INT_APPLY:
			_apply_top_intensity(state, stack, instruction_index)
		RuneCatalog.OPCODE_HALT:
			should_halt = true
		RuneCatalog.OPCODE_DUPLICATE:
			state["repeat_next"] = int(state.get("repeat_next", 0)) + 1
		_:
			if RuneCatalog.is_magic(opcode):
				# Mágicas e ações: usam a intensidade efetiva (após APLICAR,
				# INT_SET, INT_MOD) e não tocam na pilha numérica.
				var magic: Array = state["magic"]
				magic.append({
					"kind": str(RuneCatalog.symbol_for_opcode(opcode).get("kind", "")),
					"intensity": _instruction_intensity(instruction),
					"connection_index": int(instruction.get("connection_index", -1)),
				})
			else:
				errors.append("Opcode not implemented: %d." % opcode)  # dev-only
	if opcode != RuneCatalog.OPCODE_INT_SET:
		_try_finish_intensity_set(state, instruction_index, opcode, stack)
	# DUPLICAR: a instrução que acabou de executar roda de novo, salvo se saltou.
	if opcode != RuneCatalog.OPCODE_DUPLICATE and int(state.get("repeat_next", 0)) > 0 and instruction_index >= 0 and int(state["jump_target"]) < 0 and errors.is_empty() and not should_halt:
		state["repeat_next"] = int(state["repeat_next"]) - 1
		state["jump_target"] = instruction_index
	state["halted"] = should_halt or not errors.is_empty()
	return state


func _execute_warp(state: Dictionary, instruction: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	var warp_targets: Dictionary = state["warp_targets"]
	var warp_intensity := int(instruction.get("intensity", instruction.get("operand", 0)))
	var endpoint_counts: Dictionary = state["warp_endpoint_counts"]
	if int(endpoint_counts.get(warp_intensity, 0)) > 1:
		errors.append(tr("VM_WARP_MANY_ENDS") % [warp_intensity])
	elif instruction_index < 0 or not warp_targets.has(instruction_index):
		errors.append(tr("VM_WARP_NO_TARGET") % [warp_intensity])
	else:
		state["jump_target"] = int(warp_targets[instruction_index])


func _begin_intensity_set(state: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	if int(state["pending_int_set"]) >= 0:
		errors.append(tr("VM_INT_SET_PENDING"))
		return
	state["pending_int_set"] = instruction_index


## APLICAR: o topo da pilha (removido, limitado a 0..255) vira a intensidade
## da instrução seguinte, que executa logo depois já com o valor novo.
func _apply_top_intensity(state: Dictionary, stack: Array, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	var program: Array = state["program"]
	if stack.is_empty():
		errors.append(tr("VM_NEEDS_VALUE") % ["APPLY"])
		return
	var target_index := instruction_index + 1
	if instruction_index < 0 or target_index >= program.size() or int(program[target_index]["opcode"]) == RuneCatalog.OPCODE_HALT:
		errors.append(tr("VM_INT_APPLY_NO_TARGET"))
		return
	_set_instruction_intensity(program, target_index, clampi(int(stack.pop_back()), 0, 255))
	configure_program(state, program)


func _is_boolean(value: int) -> bool:
	return value == 0 or value == 1


func _execute_jump_if_true(state: Dictionary, instruction: Dictionary, instruction_index: int) -> void:
	var errors: Array = state["errors"]
	var stack: Array = state["stack"]
	if stack.is_empty():
		errors.append(tr("VM_NEEDS_VALUE") % ["JUMP_IF_TRUE"])
		return
	if int(stack.back()) != 1:
		return
	var jump_intensity := _instruction_intensity(instruction)
	var endpoint_counts: Dictionary = state["warp_endpoint_counts"]
	if int(endpoint_counts.get(jump_intensity, 0)) > 1:
		errors.append(tr("VM_JUMP_MANY_ENDS") % [jump_intensity])
		return
	var jump_targets: Dictionary = state["jump_if_true_targets"]
	if not jump_targets.has(instruction_index):
		errors.append(tr("VM_JUMP_NO_TARGET") % [jump_intensity])
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
		errors.append(tr("VM_INT_SET_NO_VALUE"))
		return
	if not RuneCatalog.produces_value_type(opcode, "int") or stack.is_empty():
		return
	var program: Array = state["program"]
	var target_index := instruction_index + 1
	if target_index >= program.size() or int(program[target_index]["opcode"]) == RuneCatalog.OPCODE_HALT:
		errors.append(tr("VM_INT_SET_NO_TARGET"))
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
		errors.append(tr("VM_INT_MOD_NEEDS_TWO"))
		return
	var argument_instruction: Dictionary = program[instruction_index + 1]
	var target_instruction: Dictionary = program[instruction_index + 2]
	var operation_opcode := int(argument_instruction["opcode"])
	if operation_opcode not in RuneCatalog.INTENSITY_OPERATIONS:
		errors.append(tr("VM_INT_MOD_NEEDS_OP"))
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
				errors.append(tr("VM_INT_MOD_ZERO") % ["DIV"])
				return
			modified_intensity = int(current_intensity / operand)
		RuneCatalog.OPCODE_MOD:
			if operand == 0:
				errors.append(tr("VM_INT_MOD_ZERO") % ["MOD"])
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
	return {"ok": errors.is_empty(), "errors": errors, "output": state["output"], "stack": state["stack"], "magic": state.get("magic", [])}
