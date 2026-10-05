extends RefCounted

## Emissao compartilhada pelos backends NASM estatico e mutavel.
## Os enderecos recebidos sao posicoes da pilha nativa, nao opcodes interpretados.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const MAX_STACK_DEPTH := 256
const MAX_RUN_STEPS := 10000
const OPERATIONS := {
	RuneCatalog.OPCODE_ADD: "add",
	RuneCatalog.OPCODE_SUB: "sub",
	RuneCatalog.OPCODE_MUL: "imul",
}
const COMPARISONS := {
	RuneCatalog.OPCODE_EQ: "e",
	RuneCatalog.OPCODE_NEQ: "ne",
	RuneCatalog.OPCODE_LT: "l",
	RuneCatalog.OPCODE_GT: "g",
	RuneCatalog.OPCODE_LTE: "le",
	RuneCatalog.OPCODE_GTE: "ge",
}
const RUNTIME_ERRORS := {
	"memory": "leitura de memoria vazia.",
	"division": "divisao por zero.",
	"boolean": "booleanos aceitam apenas 0 ou 1.",
	"underflow": "faltam valores na pilha.",
	"overflow": "pilha ultrapassou 256 valores.",
	"steps": "limite de passos excedido.",
	"portal": "portal sem destino compativel.",
	"duplicate_portal": "mais de um WARP END compativel.",
	"set_pending": "INT_SET anterior ainda espera um valor.",
	"set_value": "INT_SET terminou sem encontrar um inteiro.",
	"set_target": "INT_SET encontrou um inteiro, mas nao uma runa-alvo.",
}


static func emit_binary(lines: Array[String], opcode: int, left: String, right: String, index: int) -> void:
	lines.append("    mov rax, %s" % left)
	if OPERATIONS.has(opcode):
		lines.append("    %s rax, %s" % [OPERATIONS[opcode], right])
	elif COMPARISONS.has(opcode):
		lines.append_array(["    cmp rax, %s" % right, "    set%s al" % COMPARISONS[opcode], "    movzx rax, al"])
	elif opcode in [RuneCatalog.OPCODE_AND, RuneCatalog.OPCODE_OR]:
		lines.append_array(["    mov rcx, %s" % right, "    cmp rax, 1", "    ja boolean_error", "    cmp rcx, 1", "    ja boolean_error", "    %s rax, rcx" % ("and" if opcode == RuneCatalog.OPCODE_AND else "or")])
	else:
		# IDIV traps on INT64_MIN / -1; preserve wrapping integer semantics.
		lines.append_array([
			"    mov rcx, %s" % right,
			"    test rcx, rcx", "    jz division_error",
			"    cmp rcx, -1", "    jne division_%d" % index,
			"    mov rdx, 0x8000000000000000", "    cmp rax, rdx", "    jne division_%d" % index,
		])
		if opcode == RuneCatalog.OPCODE_MOD:
			lines.append("    xor eax, eax")
		lines.append_array(["    jmp division_done_%d" % index, "division_%d:" % index, "    cqo", "    idiv rcx"])
		if opcode == RuneCatalog.OPCODE_MOD:
			lines.append("    mov rax, rdx")
		lines.append("division_done_%d:" % index)
	lines.append("    mov %s, rax" % left)
