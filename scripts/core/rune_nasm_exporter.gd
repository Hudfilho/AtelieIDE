class_name AtelierRuneNasmExporter
extends RefCounted

## Fonte NASM para Windows x86-64, com traducao nativa das 30 runas.
## Intensidades mutaveis usam pilha protegida e saltos indiretos, nao um interpretador.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const MutableNasm = preload("res://scripts/core/rune_nasm_mutable.gd")
const RunePortals = preload("res://scripts/core/rune_portals.gd")
const NasmCommon = preload("res://scripts/core/rune_nasm_common.gd")
const MAX_STACK_DEPTH := NasmCommon.MAX_STACK_DEPTH

const SUPPORTED_OPCODES := [
	RuneCatalog.OPCODE_PUSH,
	RuneCatalog.OPCODE_DROP,
	RuneCatalog.OPCODE_DUP,
	RuneCatalog.OPCODE_SWAP,
	RuneCatalog.OPCODE_ADD,
	RuneCatalog.OPCODE_SUB,
	RuneCatalog.OPCODE_MUL,
	RuneCatalog.OPCODE_DIV,
	RuneCatalog.OPCODE_MOD,
	RuneCatalog.OPCODE_NEG,
	RuneCatalog.OPCODE_EQ,
	RuneCatalog.OPCODE_NEQ,
	RuneCatalog.OPCODE_LT,
	RuneCatalog.OPCODE_GT,
	RuneCatalog.OPCODE_GTE,
	RuneCatalog.OPCODE_NOT,
	RuneCatalog.OPCODE_AND,
	RuneCatalog.OPCODE_OR,
	RuneCatalog.OPCODE_INT_SET,
	RuneCatalog.OPCODE_INT_MOD,
	RuneCatalog.OPCODE_PRINT,
	RuneCatalog.OPCODE_PRINTLETTER,
	RuneCatalog.OPCODE_STORE,
	RuneCatalog.OPCODE_LOAD,
	RuneCatalog.OPCODE_READ,
	RuneCatalog.OPCODE_LTE,
	RuneCatalog.OPCODE_WARP,
	RuneCatalog.OPCODE_WARP_ENDPOINT,
	RuneCatalog.OPCODE_JUMP_IF_TRUE,
	RuneCatalog.OPCODE_HALT,
]


func generate(connections: Array) -> Dictionary:
	var compilation: Dictionary = RuneCompiler.new().compile(connections)
	if not bool(compilation.get("ok", false)):
		return compilation
	var instructions: Array = compilation["instructions"]
	var uses_mutable_intensity := false
	for instruction in instructions:
		var opcode := int(instruction["opcode"])
		if RuneCatalog.is_game_only(opcode):
			return {"ok": false, "errors": ["%s so existe no modo jogo e nao tem traducao NASM." % RuneCatalog.name_for_opcode(opcode)]}
		if opcode not in SUPPORTED_OPCODES:
			return {"ok": false, "errors": ["%s ainda nao tem traducao NASM." % RuneCatalog.name_for_opcode(opcode)]}
		uses_mutable_intensity = uses_mutable_intensity or opcode in [RuneCatalog.OPCODE_INT_SET, RuneCatalog.OPCODE_INT_MOD]
	if uses_mutable_intensity:
		return {
			"ok": true, "source": MutableNasm.new().build_source(instructions),
			"warnings": compilation.get("warnings", []), "mode": "mutable",
		}
	var targets := RunePortals.resolve(instructions)
	var analysis := _analyze_program(instructions, targets)
	if not bool(analysis.get("ok", false)):
		return analysis
	return {
		"ok": true,
		"source": _build_source(instructions, analysis["depths"], int(analysis["max_depth"]), targets),
		"warnings": compilation.get("warnings", []),
		"mode": "static",
	}


func export_file(connections: Array, path: String) -> Dictionary:
	var result := generate(connections)
	if not bool(result.get("ok", false)):
		return result
	var output_path := path if path.to_lower().ends_with(".asm") else path + ".asm"
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "errors": ["Nao foi possivel gravar %s (%s)." % [output_path, error_string(FileAccess.get_open_error())]]}
	file.store_string(str(result["source"]))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "errors": ["Falha ao terminar de gravar %s (%s)." % [output_path, error_string(write_error)]]}
	result["path"] = output_path
	return result


func _analyze_program(instructions: Array, targets: Dictionary) -> Dictionary:
	var depths := {0: 0}
	var pending: Array[int] = [0]
	var max_depth := 0
	while not pending.is_empty():
		var index: int = pending.pop_back()
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		var cell := int(instruction.get("connection_index", -1)) + 1
		var depth := int(depths[index])
		if opcode not in SUPPORTED_OPCODES:
			return {"ok": false, "errors": ["%s na celula %d ainda nao tem traducao NASM neste prototipo." % [RuneCatalog.name_for_opcode(opcode), cell]]}
		if depth < RuneCatalog.required_stack_depth(opcode):
			return {"ok": false, "errors": ["%s na celula %d precisa de mais valores na pilha." % [RuneCatalog.name_for_opcode(opcode), cell]]}
		var next_depth := depth + RuneCatalog.stack_delta(opcode)
		max_depth = maxi(max_depth, next_depth)
		if max_depth > MAX_STACK_DEPTH:
			return {"ok": false, "errors": ["A pilha ultrapassa %d valores na celula %d." % [MAX_STACK_DEPTH, cell]]}
		var successors: Array[int] = []
		if opcode == RuneCatalog.OPCODE_WARP:
			if not targets["warp"].has(index):
				return {"ok": false, "errors": ["WARP na celula %d nao tem destino estatico." % cell]}
			successors.append(int(targets["warp"][index]))
		elif opcode == RuneCatalog.OPCODE_JUMP_IF_TRUE:
			if not targets["conditional"].has(index):
				return {"ok": false, "errors": ["JUMP_IF_TRUE na celula %d nao tem destino estatico." % cell]}
			successors.append(index + 1)
			successors.append(int(targets["conditional"][index]))
		elif opcode != RuneCatalog.OPCODE_HALT:
			successors.append(index + 1)
		for successor in successors:
			if successor < 0 or successor >= instructions.size():
				return {"ok": false, "errors": ["Salto na celula %d aponta para fora do ritual." % cell]}
			if depths.has(successor):
				if int(depths[successor]) != next_depth:
					var target_cell := int(instructions[successor].get("connection_index", -1)) + 1
					return {"ok": false, "errors": ["Caminhos chegam a celula %d com alturas de pilha diferentes (%d e %d)." % [target_cell, int(depths[successor]), next_depth]]}
			else:
				depths[successor] = next_depth
				pending.append(successor)
	return {"ok": true, "depths": depths, "max_depth": max_depth}


func _stack_address(slot: int) -> String:
	return "[rsp + %d]" % (32 + slot * 8)


func _build_source(instructions: Array, depths: Dictionary, max_stack_depth: int, targets: Dictionary) -> String:
	var frame_size := 32 + max_stack_depth * 8
	if frame_size % 16 != 8:
		frame_size += 8
	var memory_slots := {}
	var uses_character := false
	var uses_division := false
	var uses_boolean := false
	for index in depths:
		var instruction: Dictionary = instructions[int(index)]
		var opcode := int(instruction["opcode"])
		if opcode in [RuneCatalog.OPCODE_STORE, RuneCatalog.OPCODE_LOAD, RuneCatalog.OPCODE_READ]:
			memory_slots[int(instruction["operand"])] = true
		elif opcode == RuneCatalog.OPCODE_PRINTLETTER:
			uses_character = true
		uses_division = uses_division or opcode in [RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD]
		uses_boolean = uses_boolean or opcode in [RuneCatalog.OPCODE_NOT, RuneCatalog.OPCODE_AND, RuneCatalog.OPCODE_OR]
	var lines: Array[String] = [
		"; Atelier IDE - NASM x86-64 para Windows.",
		"default rel",
		"extern printf",
		"global main",
		"",
		"section .data",
		"format_integer: db \"%lld\", 0",
	]
	if uses_character:
		lines.append("format_character: db \"%c\", 0")
		lines.append("format_utf8: db \"%c%c\", 0")
		lines.append("format_replacement: db 239, 191, 189, 0 ; U+FFFD, como String.chr(0) na VM")
	if uses_division:
		lines.append("format_division_error: db \"Atelier: divisao por zero.\", 10, 0")
	if uses_boolean:
		lines.append("format_boolean_error: db \"Atelier: booleanos aceitam apenas 0 ou 1.\", 10, 0")
	if not memory_slots.is_empty():
		lines.append("format_memory_error: db \"Atelier: leitura de memoria vazia.\", 10, 0")
		lines.append("")
		lines.append("section .bss")
		var sorted_slots: Array = memory_slots.keys()
		sorted_slots.sort()
		for slot in sorted_slots:
			lines.append("memory_%d: resq 1" % int(slot))
			lines.append("memory_%d_valid: resb 1" % int(slot))
	lines.append_array([
		"",
		"section .text",
		"main:",
		"    sub rsp, %d ; 32 bytes de shadow space + pilha das runas" % frame_size,
	])
	var labels := {}
	for source_index in depths:
		if targets["warp"].has(source_index):
			labels[int(targets["warp"][source_index])] = true
		if targets["conditional"].has(source_index):
			labels[int(targets["conditional"][source_index])] = true
	for index in range(instructions.size()):
		if not depths.has(index):
			continue
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		if labels.has(index):
			lines.append("rune_%d:" % index)
		if instruction.has("connection_index"):
			lines.append("    ; Celula %d: %s" % [int(instruction["connection_index"]) + 1, RuneCatalog.name_for_opcode(opcode)])
		_emit_instruction(lines, instruction, int(depths[index]), frame_size, index, targets)
	if not memory_slots.is_empty():
		lines.append_array([
			"memory_error:",
			"    lea rcx, [rel format_memory_error]",
			"    call printf",
			"    add rsp, %d" % frame_size,
			"    mov eax, 1",
			"    ret",
		])
	for error in (["division"] if uses_division else []) + (["boolean"] if uses_boolean else []):
		lines.append_array(["%s_error:" % error, "    lea rcx, [rel format_%s_error]" % error, "    call printf", "    add rsp, %d" % frame_size, "    mov eax, 1", "    ret"])
	lines.append("")
	return "\n".join(lines)


func _emit_instruction(lines: Array[String], instruction: Dictionary, stack_depth: int, frame_size: int, index: int, targets: Dictionary) -> void:
	var opcode := int(instruction["opcode"])
	if opcode in RuneCatalog.BINARY_OPCODES:
		NasmCommon.emit_binary(lines, opcode, _stack_address(stack_depth - 2), _stack_address(stack_depth - 1), index)
		return
	match opcode:
		RuneCatalog.OPCODE_PUSH:
			lines.append("    mov qword %s, %d" % [_stack_address(stack_depth), int(instruction["operand"])])
		RuneCatalog.OPCODE_DROP:
			lines.append("    ; valor descartado")
		RuneCatalog.OPCODE_DUP:
			lines.append_array(["    mov rax, %s" % _stack_address(stack_depth - 1), "    mov %s, rax" % _stack_address(stack_depth)])
		RuneCatalog.OPCODE_SWAP:
			lines.append_array([
				"    mov rax, %s" % _stack_address(stack_depth - 1),
				"    mov rdx, %s" % _stack_address(stack_depth - 2),
				"    mov %s, rdx" % _stack_address(stack_depth - 1),
				"    mov %s, rax" % _stack_address(stack_depth - 2),
			])
		RuneCatalog.OPCODE_NEG:
			lines.append("    neg qword %s" % _stack_address(stack_depth - 1))
		RuneCatalog.OPCODE_NOT:
			lines.append_array(["    cmp qword %s, 1" % _stack_address(stack_depth - 1), "    ja boolean_error", "    xor qword %s, 1" % _stack_address(stack_depth - 1)])
		RuneCatalog.OPCODE_STORE:
			var store_slot := int(instruction["operand"])
			lines.append_array([
				"    mov rax, %s" % _stack_address(stack_depth - 1),
				"    mov [rel memory_%d], rax" % store_slot,
				"    mov byte [rel memory_%d_valid], 1" % store_slot,
			])
		RuneCatalog.OPCODE_LOAD, RuneCatalog.OPCODE_READ:
			var load_slot := int(instruction["operand"])
			lines.append_array([
				"    cmp byte [rel memory_%d_valid], 1" % load_slot,
				"    jne memory_error",
				"    mov rax, [rel memory_%d]" % load_slot,
				"    mov %s, rax" % _stack_address(stack_depth),
			])
		RuneCatalog.OPCODE_PRINT:
			lines.append_array([
				"    mov rdx, %s" % _stack_address(stack_depth - 1),
				"    lea rcx, [rel format_integer]",
				"    call printf",
			])
		RuneCatalog.OPCODE_PRINTLETTER:
			var character := int(instruction["operand"])
			if character == 0:
				lines.append("    lea rcx, [rel format_replacement]")
			elif character > 127:
				lines.append_array(["    mov edx, %d" % (0xc0 | (character >> 6)), "    mov r8d, %d" % (0x80 | (character & 0x3f)), "    lea rcx, [rel format_utf8]"])
			else:
				lines.append_array(["    mov edx, %d" % character, "    lea rcx, [rel format_character]"])
			lines.append("    call printf")
		RuneCatalog.OPCODE_WARP:
			lines.append("    jmp rune_%d" % int(targets["warp"][index]))
		RuneCatalog.OPCODE_JUMP_IF_TRUE:
			lines.append_array([
				"    cmp qword %s, 1" % _stack_address(stack_depth - 1),
				"    je rune_%d" % int(targets["conditional"][index]),
			])
		RuneCatalog.OPCODE_HALT:
			lines.append_array(["    add rsp, %d" % frame_size, "    xor eax, eax", "    ret"])
