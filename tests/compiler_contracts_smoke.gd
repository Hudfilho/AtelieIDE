extends SceneTree

const Catalog = preload("res://scripts/core/rune_catalog.gd")
const Bytecode = preload("res://scripts/core/rune_bytecode.gd")
const Compiler = preload("res://scripts/core/rune_compiler.gd")
const Portals = preload("res://scripts/core/rune_portals.gd")
const Exporter = preload("res://scripts/core/rune_nasm_exporter.gd")
const RitualFile = preload("res://scripts/core/atelier_ritual_file.gd")
const VM = preload("res://scripts/core/rune_vm.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func _instruction(opcode: int, intensity := 128) -> Dictionary:
	var instruction := {"opcode": opcode, "intensity": intensity}
	if Catalog.takes_operand(opcode):
		instruction["operand"] = intensity
	return instruction


func _invalid_bytecode(bytes: PackedByteArray, detail: String) -> void:
	var decoded := Bytecode.decode(bytes)
	_check(not bool(decoded["ok"]) and detail in str(decoded.get("errors", [])), "Bytecode invalido aceito ou diagnostico perdido: " + detail)


func _run() -> void:
	var copied := Catalog.symbol_data("ORB")
	copied["label"] = "mutated"
	_check(Catalog.name_for_opcode(Catalog.OPCODE_PUSH) == "PUSH", "O catalogo publico deve devolver copias isoladas.")
	_check(Catalog.opcode_for_kind("unknown") == -1, "Simbolo desconhecido deve retornar -1.")
	_check(not Catalog.is_known_opcode(255), "Opcode desconhecido deve ser rejeitado.")
	var all_instructions: Array[Dictionary] = []
	for symbol in Catalog.SYMBOLS:
		var opcode := int(symbol["opcode"])
		all_instructions.append(_instruction(opcode, 255))
		_check(Catalog.name_for_opcode(opcode) == symbol["label"], "Indice de opcode inconsistente.")
		_check(Catalog.opcode_for_kind(symbol["kind"]) == opcode, "Indice de simbolo inconsistente.")
		# Check stack metadata against actual VM operations, independently of NASM.
		if opcode in [Catalog.OPCODE_INT_MOD, Catalog.OPCODE_WARP]:
			continue
		var state := VM.new().create_state()
		var depth := Catalog.required_stack_depth(opcode)
		for _index in range(depth):
			state["stack"].append(1)
		state["memory"][1] = 1
		state["jump_if_true_targets"][0] = 1
		VM.new().step(_instruction(opcode, 1), state, 0)
		_check((state["errors"] as Array).is_empty(), "VM/meta: " + Catalog.name_for_opcode(opcode))
		_check((state["stack"] as Array).size() == depth + Catalog.stack_delta(opcode), "Efeito de pilha: " + Catalog.name_for_opcode(opcode))
	var encoded := Bytecode.encode(all_instructions)
	var decoded := Bytecode.decode(encoded)
	_check(bool(decoded["ok"]) and decoded["instructions"] == all_instructions, "As 30 instrucoes devem sobreviver ao round-trip RUNE v2.")
	_invalid_bytecode(encoded.slice(0, 6), "RUNE header")
	var malformed := encoded.duplicate()
	malformed[0] = 0
	_invalid_bytecode(malformed, "signature")
	malformed = encoded.duplicate()
	malformed[4] = 1
	_invalid_bytecode(malformed, "version")
	malformed = encoded.duplicate()
	malformed[7] = 255
	_invalid_bytecode(malformed, "opcode")
	_invalid_bytecode(encoded.slice(0, encoded.size() - 1), "Missing intensity")
	malformed = encoded.duplicate()
	malformed.append(0)
	_invalid_bytecode(malformed, "Trailing bytes")
	var too_many: Array = []
	too_many.resize(Bytecode.MAX_INSTRUCTIONS + 1)
	_check(Bytecode.encode(too_many).is_empty(), "Nao pode haver truncamento silencioso da contagem de instrucoes.")
	var ring := Portals.resolve([
		_instruction(Catalog.OPCODE_WARP, 8), _instruction(Catalog.OPCODE_JUMP_IF_TRUE, 8),
		_instruction(Catalog.OPCODE_WARP, 8), _instruction(Catalog.OPCODE_JUMP_IF_TRUE, 8),
	])
	_check(ring["warp"] == {0: 3, 2: 1} and ring["conditional"] == {1: 3, 3: 1}, "WARP/JIT devem dar a volta no grupo.")
	var endpoint := Portals.resolve([
		_instruction(Catalog.OPCODE_WARP, 8), _instruction(Catalog.OPCODE_WARP_ENDPOINT, 8),
		_instruction(Catalog.OPCODE_WARP, 8), _instruction(Catalog.OPCODE_JUMP_IF_TRUE, 8),
	])
	_check(endpoint["warp"] == {0: 2, 2: 2} and endpoint["conditional"] == {3: 2}, "O destino unico deve ter prioridade sobre o grupo WARP.")
	var connections: Array[Dictionary] = [
		{"from": Vector2(144, 0), "to": Vector2(192, 0), "symbol": "TRIANGLE"},
		{"from": Vector2(48, 0), "to": Vector2(96, 0), "symbol": "ORB", "intensity": 3},
		{"from": Vector2(96, 0), "to": Vector2(144, 0), "symbol": "DIAMOND"},
		{"from": Vector2.ZERO, "to": Vector2(48, 0), "symbol": "ORB", "intensity": 2},
	]
	var compilation := Compiler.new().compile(connections)
	_check(bool(compilation["ok"]), "A ordem de insercao das celulas nao deve afetar a compilacao.")
	if bool(compilation["ok"]):
		_check(compilation["instructions"][0]["connection_index"] == 3, "A IR deve preservar a origem da celula.")
		_check((compilation["instructions"] as Array).back().get("implicit", false), "HALT deve ser inserido no fim da sequencia.")
		var execution := VM.new().run(compilation["bytecode"])
		_check(execution["output"] == ["5"] and execution["stack"] == [5], "PRINT deve manter o topo da pilha.")
	var missing_directory := "user://atelier_missing_%d/" % Time.get_ticks_usec()
	_check(not bool(Compiler.new().export_binary(connections, missing_directory + "test.rune")["ok"]), "Falha de gravacao RUNE deve retornar erro.")
	_check(not bool(Exporter.new().export_file(connections, missing_directory + "test.asm")["ok"]), "Falha de gravacao NASM deve retornar erro.")
	_check(not bool(RitualFile.save_file(missing_directory + "test.atelier", connections, Vector2.ZERO, 1.0)["ok"]), "Falha de gravacao .atelier deve retornar erro.")
	if failures == 0:
		print("COMPILER_CONTRACTS_SMOKE_OK")
	quit(0 if failures == 0 else 1)
