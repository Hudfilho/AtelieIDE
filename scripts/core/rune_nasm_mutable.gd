extends RefCounted

## Backend nativo para rituais que alteram intensidades durante a execucao.
## Cada runa continua sendo um bloco de instrucoes x86-64; a tabela apenas
## permite saltar para blocos cujo destino depende de um portal mutavel.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const NasmCommon = preload("res://scripts/core/rune_nasm_common.gd")
const STACK_LIMIT := NasmCommon.MAX_STACK_DEPTH
const STEP_LIMIT := NasmCommon.MAX_RUN_STEPS
const ERRORS := NasmCommon.RUNTIME_ERRORS

func build_source(instructions: Array) -> String:
	var intensities: Array[String] = []
	var destinations: Array[String] = []
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		intensities.append(str(int(instruction.get("intensity", instruction.get("operand", 128)))))
		destinations.append("rune_%d" % index)
	destinations.append("native_done")
	var lines: Array[String] = [
		"; Atelier IDE - NASM x86-64 para Windows, intensidades mutaveis.",
		"; Blocos nativos; r12 = profundidade, r13 = intensidades, r14 = pilha, r15 = INT_SET pendente.",
		"default rel", "extern printf", "global main", "",
		"section .data",
		"format_integer: db \"%lld\", 0",
		"format_character: db \"%c\", 0",
		"format_utf8: db \"%c%c\", 0",
		"format_replacement: db 239, 191, 189, 0 ; U+FFFD, como String.chr(0) na VM",
		"intensities: db " + ", ".join(intensities),
	]
	for error in ERRORS:
		lines.append("format_%s_error: db \"Atelier: %s\", 10, 0" % [error, ERRORS[error]])
	lines.append_array([
		"", "section .rdata", "align 8",
		"rune_targets: dq " + ", ".join(destinations),
		"", "section .bss", "align 8",
		"rune_stack: resq %d" % STACK_LIMIT,
		"memory: resq 256", "memory_valid: resb 256", "steps: resd 1",
		"", "section .text", "main:",
		# Entry RSP % 16 == 8. Four saved registers + 40 bytes align every call.
		"    push r12", "    push r13", "    push r14", "    push r15",
		"    sub rsp, 40 ; shadow space + alinhamento Win64",
		"    xor r12d, r12d", "    lea r13, [rel intensities]", "    lea r14, [rel rune_stack]", "    mov r15d, -1",
	])
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		lines.append("rune_%d:" % index)
		lines.append("    ; Celula %d: %s" % [int(instruction.get("connection_index", -1)) + 1, RuneCatalog.name_for_opcode(opcode)])
		lines.append_array(["    inc dword [rel steps]", "    cmp dword [rel steps], %d" % STEP_LIMIT, "    ja steps_error"])
		var required := RuneCatalog.required_stack_depth(opcode)
		if required > 0:
			lines.append_array(["    cmp r12d, %d" % required, "    jb underflow_error"])
		if RuneCatalog.stack_delta(opcode) > 0:
			lines.append_array(["    cmp r12d, %d" % STACK_LIMIT, "    jae overflow_error"])
		_emit_instruction(lines, instructions, index)
		if RuneCatalog.produces_value_type(opcode, "int"):
			_emit_finish_set(lines, instructions, index)
	lines.append_array(["native_done:", "    xor eax, eax", "    jmp native_return"])
	for error in ERRORS:
		lines.append_array(["%s_error:" % error, "    lea rcx, [rel format_%s_error]" % error, "    jmp native_error"])
	lines.append_array([
		"native_error:", "    call printf", "    mov eax, 1",
		"native_return:", "    add rsp, 40", "    pop r15", "    pop r14", "    pop r13", "    pop r12", "    ret",
	])
	_emit_portal_resolver(lines, instructions)
	lines.append("")
	return "\n".join(lines)


func _emit_instruction(lines: Array[String], instructions: Array, index: int) -> void:
	var opcode := int(instructions[index]["opcode"])
	if opcode in RuneCatalog.BINARY_OPCODES:
		lines.append("    dec r12d")
		NasmCommon.emit_binary(lines, opcode, "[r14 + r12*8 - 8]", "[r14 + r12*8]", index)
		return
	match opcode:
		RuneCatalog.OPCODE_PUSH:
			lines.append_array(["    movzx eax, byte [r13 + %d]" % index, "    mov [r14 + r12*8], rax", "    inc r12d"])
		RuneCatalog.OPCODE_DROP:
			lines.append("    dec r12d")
		RuneCatalog.OPCODE_DUP:
			lines.append_array(["    mov rax, [r14 + r12*8 - 8]", "    mov [r14 + r12*8], rax", "    inc r12d"])
		RuneCatalog.OPCODE_SWAP:
			lines.append_array(["    mov rax, [r14 + r12*8 - 8]", "    mov rdx, [r14 + r12*8 - 16]", "    mov [r14 + r12*8 - 8], rdx", "    mov [r14 + r12*8 - 16], rax"])
		RuneCatalog.OPCODE_NEG:
			lines.append("    neg qword [r14 + r12*8 - 8]")
		RuneCatalog.OPCODE_NOT:
			lines.append_array(["    cmp qword [r14 + r12*8 - 8], 1", "    ja boolean_error", "    xor qword [r14 + r12*8 - 8], 1"])
		RuneCatalog.OPCODE_PRINT:
			lines.append_array(["    mov rdx, [r14 + r12*8 - 8]", "    lea rcx, [rel format_integer]", "    call printf"])
		RuneCatalog.OPCODE_PRINTLETTER:
			lines.append_array([
				"    movzx edx, byte [r13 + %d]" % index,
				"    test edx, edx", "    jz character_zero_%d" % index,
				"    cmp edx, 127", "    jbe character_ascii_%d" % index,
				"    mov r8d, edx", "    and r8d, 63", "    or r8d, 128",
				"    shr edx, 6", "    or edx, 192", "    lea rcx, [rel format_utf8]", "    jmp character_print_%d" % index,
				"character_zero_%d:" % index, "    lea rcx, [rel format_replacement]", "    jmp character_print_%d" % index,
				"character_ascii_%d:" % index, "    lea rcx, [rel format_character]",
				"character_print_%d:" % index, "    call printf",
			])
		RuneCatalog.OPCODE_STORE:
			lines.append_array([
				"    dec r12d", "    mov rax, [r14 + r12*8]", "    movzx ecx, byte [r13 + %d]" % index,
				"    lea rdx, [rel memory]", "    mov [rdx + rcx*8], rax", "    lea rdx, [rel memory_valid]", "    mov byte [rdx + rcx], 1",
			])
		RuneCatalog.OPCODE_LOAD, RuneCatalog.OPCODE_READ:
			lines.append_array([
				"    movzx ecx, byte [r13 + %d]" % index, "    lea rdx, [rel memory_valid]", "    cmp byte [rdx + rcx], 1", "    jne memory_error",
				"    lea rdx, [rel memory]", "    mov rax, [rdx + rcx*8]", "    mov [r14 + r12*8], rax", "    inc r12d",
			])
		RuneCatalog.OPCODE_INT_SET:
			lines.append_array(["    test r15d, r15d", "    jns set_pending_error", "    mov r15d, %d" % index])
		RuneCatalog.OPCODE_INT_MOD:
			_emit_modifier(lines, instructions, index)
		RuneCatalog.OPCODE_WARP, RuneCatalog.OPCODE_JUMP_IF_TRUE:
			if opcode == RuneCatalog.OPCODE_JUMP_IF_TRUE:
				lines.append_array(["    cmp qword [r14 + r12*8 - 8], 1", "    jne portal_continue_%d" % index])
			lines.append_array([
				"    movzx ecx, byte [r13 + %d]" % index, "    mov edx, %d" % index,
				"    mov r8d, %d" % (2 if opcode == RuneCatalog.OPCODE_WARP else 1),
				"    call resolve_portal", "    cmp eax, -2", "    je duplicate_portal_error", "    test eax, eax", "    js portal_error",
				"    lea rdx, [rel rune_targets]", "    jmp [rdx + rax*8]",
			])
			if opcode == RuneCatalog.OPCODE_JUMP_IF_TRUE:
				lines.append("portal_continue_%d:" % index)
		RuneCatalog.OPCODE_WARP_ENDPOINT:
			pass
		RuneCatalog.OPCODE_HALT:
			# A backward jump to a HALT before the pending setter also halts in the VM.
			lines.append_array(["    test r15d, r15d", "    js native_done", "    cmp r15d, %d" % index, "    jl set_value_error", "    jmp native_done"])


func _emit_clamp(lines: Array[String]) -> void:
	lines.append_array(["    xor edx, edx", "    test rax, rax", "    cmovs rax, rdx", "    mov edx, 255", "    cmp rax, rdx", "    cmovg rax, rdx"])


func _emit_finish_set(lines: Array[String], instructions: Array, index: int) -> void:
	lines.append_array(["    test r15d, r15d", "    js set_continue_%d" % index, "    cmp r15d, %d" % index, "    jge set_continue_%d" % index])
	if index + 1 >= instructions.size() or int(instructions[index + 1]["opcode"]) == RuneCatalog.OPCODE_HALT:
		lines.append("    jmp set_target_error")
	else:
		lines.append_array(["    dec r12d", "    mov rax, [r14 + r12*8]"])
		_emit_clamp(lines)
		lines.append_array(["    mov [r13 + %d], al" % (index + 1), "    mov r15d, -1"])
	lines.append("set_continue_%d:" % index)


func _emit_modifier(lines: Array[String], instructions: Array, index: int) -> void:
	var operation := int(instructions[index + 1]["opcode"])
	lines.append_array(["    movzx eax, byte [r13 + %d]" % (index + 2), "    movzx ecx, byte [r13 + %d]" % (index + 1)])
	match operation:
		RuneCatalog.OPCODE_ADD:
			lines.append("    add rax, rcx")
		RuneCatalog.OPCODE_SUB:
			lines.append("    sub rax, rcx")
		RuneCatalog.OPCODE_MUL:
			lines.append("    imul rax, rcx")
		RuneCatalog.OPCODE_NEG:
			lines.append("    neg rax")
		RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD:
			lines.append_array(["    test rcx, rcx", "    jz division_error", "    xor edx, edx", "    div rcx"])
			if operation == RuneCatalog.OPCODE_MOD:
				lines.append("    mov rax, rdx")
	_emit_clamp(lines)
	lines.append_array(["    mov [r13 + %d], al" % (index + 2), "    jmp rune_%d" % (index + 2)])


func _emit_portal_resolver(lines: Array[String], instructions: Array) -> void:
	# Leaf helper: ECX=intensity, EDX=source, R8D=min warp count (WARP=2, JIT=1).
	# Endpoints have precedence. Fallback is the next matching WARP, wrapping around.
	# Return -2 for duplicate endpoints, -1 for missing destination, else native block index.
	lines.append_array(["resolve_portal:", "    xor r9d, r9d"])
	for index in range(instructions.size()):
		if int(instructions[index]["opcode"]) != RuneCatalog.OPCODE_WARP_ENDPOINT:
			continue
		lines.append_array([
			"    cmp byte [r13 + %d], cl" % index, "    jne .endpoint_%d" % index,
			"    inc r9d", "    cmp r9d, 1", "    ja .duplicate", "    mov r10d, %d" % (index + 1), ".endpoint_%d:" % index,
		])
	lines.append_array(["    test r9d, r9d", "    jnz .endpoint_found", "    mov r9d, -1", "    mov r10d, -1", "    xor r11d, r11d"])
	for index in range(instructions.size()):
		if int(instructions[index]["opcode"]) != RuneCatalog.OPCODE_WARP:
			continue
		lines.append_array([
			"    cmp byte [r13 + %d], cl" % index, "    jne .warp_%d" % index, "    inc r11d",
			"    cmp r9d, -1", "    jne .first_%d" % index, "    mov r9d, %d" % (index + 1), ".first_%d:" % index,
			"    cmp r10d, -1", "    jne .warp_%d" % index, "    cmp edx, %d" % index, "    jge .warp_%d" % index,
			"    mov r10d, %d" % (index + 1), ".warp_%d:" % index,
		])
	lines.append_array([
		"    cmp r11d, r8d", "    jl .missing", "    mov eax, r10d", "    test eax, eax", "    cmovs eax, r9d", "    ret",
		".endpoint_found:", "    mov eax, r10d", "    ret", ".duplicate:", "    mov eax, -2", "    ret", ".missing:", "    mov eax, -1", "    ret",
	])
