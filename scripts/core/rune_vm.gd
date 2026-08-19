class_name AtelierRuneVM
extends RefCounted

## Máquina virtual mínima para executar o bytecode RUNE dentro da IDE.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")
const RuneBytecode = preload("res://scripts/core/rune_bytecode.gd")


func run(bytecode: PackedByteArray) -> Dictionary:
	var decoded := RuneBytecode.decode(bytecode)
	if not decoded["ok"]:
		return {"ok": false, "errors": decoded["errors"], "output": []}

	var stack: Array[int] = []
	var memory := {}
	var output: Array[String] = []
	var errors: Array[String] = []
	var instructions: Array = decoded["instructions"]
	var pc := 0
	var steps := 0
	while pc < instructions.size() and steps < 10000:
		steps += 1
		var instruction: Dictionary = instructions[pc]
		var opcode := int(instruction["opcode"])
		match opcode:
			RuneCatalog.OPCODE_PUSH:
				stack.append(int(instruction["operand"]))
			RuneCatalog.OPCODE_DROP:
				if stack.is_empty():
					errors.append("DROP precisa de um valor na pilha.")
					break
				stack.pop_back()
			RuneCatalog.OPCODE_DUP:
				if stack.is_empty():
					errors.append("DUP precisa de um valor na pilha.")
					break
				stack.append(int(stack.back()))
			RuneCatalog.OPCODE_SWAP:
				if stack.size() < 2:
					errors.append("SWAP precisa de dois valores na pilha.")
					break
				var swap_right := int(stack.pop_back())
				var swap_left := int(stack.pop_back())
				stack.append(swap_right)
				stack.append(swap_left)
			RuneCatalog.OPCODE_NEG:
				if stack.is_empty():
					errors.append("NEG precisa de um valor na pilha.")
					break
				stack.append(-int(stack.pop_back()))
			RuneCatalog.OPCODE_ADD, RuneCatalog.OPCODE_SUB, RuneCatalog.OPCODE_MUL, RuneCatalog.OPCODE_DIV, RuneCatalog.OPCODE_MOD:
				if stack.size() < 2:
					errors.append("%s precisa de dois valores na pilha." % RuneCatalog.name_for_opcode(opcode))
					break
				var right := int(stack.pop_back())
				var left := int(stack.pop_back())
				if (opcode == RuneCatalog.OPCODE_DIV or opcode == RuneCatalog.OPCODE_MOD) and right == 0:
					errors.append("%s não aceita divisão por zero." % RuneCatalog.name_for_opcode(opcode))
					break
				if opcode == RuneCatalog.OPCODE_ADD:
					stack.append(left + right)
				elif opcode == RuneCatalog.OPCODE_SUB:
					stack.append(left - right)
				elif opcode == RuneCatalog.OPCODE_MUL:
					stack.append(left * right)
				elif opcode == RuneCatalog.OPCODE_DIV:
					stack.append(int(left / right))
				else:
					stack.append(left % right)
			RuneCatalog.OPCODE_PRINT:
				if stack.is_empty():
					errors.append("PRINT precisa de um valor na pilha.")
					break
				output.append(str(stack.back()))
			RuneCatalog.OPCODE_STORE:
				if stack.is_empty():
					errors.append("STORE precisa de um valor na pilha.")
					break
				memory[int(instruction["operand"])] = stack.pop_back()
			RuneCatalog.OPCODE_LOAD:
				var slot := int(instruction["operand"])
				if not memory.has(slot):
					errors.append("LOAD tentou ler a posição %d, que está vazia." % slot)
					break
				stack.append(int(memory[slot]))
			RuneCatalog.OPCODE_HALT:
				return {"ok": errors.is_empty(), "errors": errors, "output": output, "stack": stack}
			_:
				errors.append("Opcode não implementado: %d." % opcode)
				break
		if not errors.is_empty():
			break
		pc += 1
	if steps >= 10000:
		errors.append("Limite de passos excedido.")
	return {"ok": errors.is_empty(), "errors": errors, "output": output, "stack": stack}
