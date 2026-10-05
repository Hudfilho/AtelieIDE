extends SceneTree

const Exporter = preload("res://scripts/core/rune_nasm_exporter.gd")
const Compiler = preload("res://scripts/core/rune_compiler.gd")
const VM = preload("res://scripts/core/rune_vm.gd")
const Catalog = preload("res://scripts/core/rune_catalog.gd")
const RitualFile = preload("res://scripts/core/atelier_ritual_file.gd")
var failures := 0
var native_cases := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> bool:
	if not condition:
		failures += 1
		printerr(message)
	return condition


func _program(kinds: Array, values: Array) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	for index in range(kinds.size()):
		connections.append({"from": Vector2(index * 48, 0), "to": Vector2((index + 1) * 48, 0), "symbol": kinds[index], "intensity": values[index]})
	return connections


func _mutable(program: Array[Dictionary]) -> Array[Dictionary]:
	# A no-op intensity modification enables the mutable backend, leaving an empty stack.
	var prefix := _program(["INT_MOD", "DIAMOND", "ORB", "CUP"], [128, 0, 0, 128])
	for connection in program:
		var shifted: Dictionary = connection.duplicate(true)
		shifted["from"] += Vector2(192, 0)
		shifted["to"] += Vector2(192, 0)
		prefix.append(shifted)
	return prefix


func _native(name: String, program: Array[Dictionary], expected: String, runtime_error: String) -> void:
	var base := ProjectSettings.globalize_path("user://atelier_all_runes_%d" % Time.get_ticks_usec())
	var paths := [base + ".asm", base + ".obj", base + ".exe", base + ".stdout"]
	var exported: Dictionary = Exporter.new().export_file(program, paths[0])
	if not _check(bool(exported.get("ok", false)), "%s export: %s" % [name, exported.get("errors", [])]):
		return
	var tool_output: Array = []
	var exit_code := OS.execute(OS.get_environment("ATELIER_NASM_PATH"), ["-f", "win64", paths[0], "-o", paths[1]], tool_output, true)
	if _check(exit_code == 0, "%s NASM: %s" % [name, tool_output]):
		tool_output.clear()
		exit_code = OS.execute(OS.get_environment("ATELIER_GCC_PATH"), [paths[1], "-o", paths[2]], tool_output, true)
		if _check(exit_code == 0, "%s GCC: %s" % [name, tool_output]):
			tool_output.clear()
			var capture := ProjectSettings.globalize_path("res://tests/capture_native_output.ps1")
			exit_code = OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", capture, "-ExecutablePath", paths[2], "-OutputPath", paths[3]], tool_output, true)
			var output := FileAccess.get_file_as_string(paths[3]).replace("\r\n", "\n")
			_check(exit_code == (0 if runtime_error.is_empty() else 1), "%s exit=%d: %s" % [name, exit_code, tool_output])
			if runtime_error.is_empty():
				_check(output == expected, "%s: esperado %s, recebido %s" % [name, JSON.stringify(expected), JSON.stringify(output)])
			else:
				_check(output == expected + "Atelier: " + runtime_error + "\n", "%s: erro/saida divergente: %s" % [name, output])
			native_cases += 1
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _case(name: String, kinds: Array, values: Array, runtime_error := "", force_mutable := false) -> void:
	var program := _program(kinds, values)
	if force_mutable:
		program = _mutable(program)
	var compilation: Dictionary = Compiler.new().compile(program)
	if not _check(bool(compilation.get("ok", false)), "%s compiler: %s" % [name, compilation.get("errors", [])]):
		return
	var execution: Dictionary = VM.new().run(compilation["bytecode"])
	if not _check(bool(execution["ok"]) == runtime_error.is_empty(), "%s VM: %s" % [name, execution]):
		return
	var expected := "".join(execution["output"])
	_native(name, program, expected, runtime_error)


func _append_push(kinds: Array, values: Array, value: int) -> void:
	kinds.append("ORB")
	values.append(absi(value))
	if value < 0:
		kinds.append("DASH")
		values.append(128)


func _run() -> void:
	if not _check(not OS.get_environment("ATELIER_NASM_PATH").is_empty() and not OS.get_environment("ATELIER_GCC_PATH").is_empty(), "Defina ATELIER_NASM_PATH e ATELIER_GCC_PATH; esta suite exige testes nativos."):
		quit(1)
		return
	_check(Exporter.SUPPORTED_OPCODES.size() == 30, "O backend deve oferecer as 30 runas.")
	for symbol in Catalog.SYMBOLS:
		_check(int(symbol["opcode"]) in Exporter.SUPPORTED_OPCODES, "Opcode sem suporte: %s" % symbol["label"])
	var kinds: Array = []
	var values: Array = []
	# Signed arithmetic, all comparisons, and all boolean truth-table entries.
	for operation in ["DIAMOND", "MOON", "PLUS", "SLASH", "SPIRAL", "EQ", "NEQ", "LT", "GT", "LTE", "GTE", "AND", "OR"]:
		var pairs := [[7, 3], [-7, 3], [7, -3], [-7, -3], [3, 3]]
		if operation in ["AND", "OR"]:
			pairs = [[0, 0], [0, 1], [1, 0], [1, 1]]
		for pair in pairs:
			_append_push(kinds, values, pair[0])
			_append_push(kinds, values, pair[1])
			kinds.append_array([operation, "TRIANGLE", "PRINTLETTER", "CUP"])
			values.append_array([128, 128, 10, 128])
	for value in [0, 1]:
		kinds.append_array(["ORB", "NOT", "TRIANGLE", "CUP"])
		values.append_array([value, 128, 128, 128])
	kinds.append_array(["ORB", "TWIN", "ORB", "KNOT", "DIAMOND", "DASH", "PLUS", "TRIANGLE", "CUP", "PRINTLETTER", "PRINTLETTER", "PRINTLETTER"])
	values.append_array([5, 128, 3, 128, 128, 128, 128, 128, 128, 127, 128, 255])
	_case("all arithmetic/static", kinds, values)
	_case("all arithmetic/mutable", kinds, values, "", true)
	var wide_kinds: Array = ["ORB"]
	var wide_values: Array = [128]
	for _index in range(7):
		wide_kinds.append_array(["ORB", "PLUS"])
		wide_values.append_array([128, 128])
	wide_kinds.append_array(["TWIN", "ORB", "SLASH", "TRIANGLE", "CUP", "ORB", "SPIRAL", "TRIANGLE"])
	wide_values.append_array([128, 3, 128, 128, 128, 3, 128, 128])
	_case("64-bit integer division", wide_kinds, wide_values)
	_case("64-bit integer division/mutable", wide_kinds, wide_values, "", true)
	_case("character zero", ["PRINTLETTER", "PRINTLETTER"], [0, 65])
	_case("character zero/mutable", ["PRINTLETTER", "PRINTLETTER"], [0, 65], "", true)
	for mutable in [false, true]:
		for operation in ["SLASH", "SPIRAL"]:
			_case("zero/%s/%s" % [operation, mutable], ["ORB", "ORB", operation], [7, 0, 128], "divisao por zero.", mutable)
		for operation in ["AND", "OR"]:
			_case("invalid boolean/%s/%s" % [operation, mutable], ["ORB", "DASH", "ORB", operation], [1, 128, 0, 128], "booleanos aceitam apenas 0 ou 1.", mutable)
		_case("invalid NOT/%s" % mutable, ["ORB", "NOT"], [2, 128], "booleanos aceitam apenas 0 ou 1.", mutable)
		_case("memory boundaries/%s" % mutable, ["ORB", "SQUARE", "ORB", "SQUARE", "FORK", "READ", "DIAMOND", "TRIANGLE"], [7, 0, 9, 255, 0, 255, 128, 128], "", mutable)
	_case("set push", ["INT_SET", "ORB", "ORB", "TRIANGLE"], [128, 42, 1, 128])
	_case("set waits/UTF8", ["INT_SET", "PRINTLETTER", "ORB", "PRINTLETTER"], [128, 65, 200, 66])
	_case("set DUP", ["ORB", "INT_SET", "TWIN", "ORB", "PLUS", "TRIANGLE"], [33, 128, 128, 1, 128, 128])
	_case("set comparison", ["ORB", "ORB", "INT_SET", "EQ", "ORB", "TRIANGLE"], [3, 3, 128, 128, 99, 128])
	_case("set boolean", ["ORB", "INT_SET", "NOT", "PRINTLETTER"], [0, 128, 128, 99])
	_case("set negative clamp", ["ORB", "INT_SET", "DASH", "ORB", "TRIANGLE"], [9, 128, 128, 99, 128])
	_case("set high clamp", ["ORB", "ORB", "INT_SET", "PLUS", "ORB", "TRIANGLE"], [200, 2, 128, 128, 1, 128])
	_case("set memory value", ["ORB", "SQUARE", "INT_SET", "READ", "ORB", "TRIANGLE"], [9, 255, 128, 255, 1, 128])
	_case("set STORE address", ["ORB", "INT_SET", "ORB", "SQUARE", "READ", "TRIANGLE"], [77, 128, 255, 1, 255, 128])
	_case("mod LOAD address", ["ORB", "SQUARE", "INT_MOD", "DIAMOND", "FORK", "TRIANGLE"], [77, 255, 128, 254, 1, 128])
	_case("set WARP", ["INT_SET", "ORB", "WARP", "ORB", "WARP_ENDPOINT", "ORB", "TRIANGLE"], [128, 7, 3, 99, 7, 42, 128])
	_case("set endpoint/remap", ["ORB", "INT_SET", "ORB", "WARP_ENDPOINT", "JUMP_IF_TRUE", "CUP", "ORB", "WARP", "WARP_ENDPOINT", "PRINTLETTER", "CROSS"], [0, 128, 7, 3, 9, 128, 1, 7, 9, 101, 128])
	_case("set JIT", ["ORB", "INT_SET", "ORB", "JUMP_IF_TRUE", "ORB", "WARP_ENDPOINT", "TRIANGLE"], [1, 128, 7, 3, 99, 7, 128])
	for operation in ["DIAMOND", "MOON", "PLUS", "SLASH", "SPIRAL", "DASH"]:
		_case("mod/%s" % operation, ["INT_MOD", operation, "ORB", "TRIANGLE"], [128, 3, 17, 128])
	_case("mod high clamp", ["INT_MOD", "PLUS", "ORB", "TRIANGLE"], [128, 2, 200, 128])
	_case("mod low clamp", ["INT_MOD", "MOON", "ORB", "TRIANGLE"], [128, 7, 5, 128])
	_case("pending setter", ["ORB", "INT_SET", "JUMP_IF_TRUE", "INT_SET", "ORB", "ORB", "WARP_ENDPOINT", "ORB", "TRIANGLE"], [0, 128, 7, 128, 1, 2, 7, 4, 128], "INT_SET anterior ainda espera um valor.")
	_case("set missing value", ["ORB", "INT_SET", "JUMP_IF_TRUE", "ORB", "ORB", "WARP_ENDPOINT", "CROSS"], [1, 128, 7, 2, 3, 7, 128], "INT_SET terminou sem encontrar um inteiro.")
	_case("set missing target", ["ORB", "INT_SET", "JUMP_IF_TRUE", "ORB", "ORB", "WARP_ENDPOINT", "ORB", "CROSS"], [1, 128, 7, 2, 3, 7, 4, 128], "INT_SET encontrou um inteiro, mas nao uma runa-alvo.")
	_case("underflow", ["TRIANGLE"], [128], "faltam valores na pilha.", true)
	_case("empty memory", ["READ"], [255], "leitura de memoria vazia.", true)
	_case("missing mutable portal", ["INT_SET", "ORB", "WARP", "WARP_ENDPOINT", "ORB", "TRIANGLE"], [128, 9, 3, 3, 42, 128], "portal sem destino compativel.")
	_case("duplicate mutable portal", ["INT_SET", "ORB", "WARP_ENDPOINT", "WARP", "WARP_ENDPOINT", "ORB", "TRIANGLE"], [128, 7, 3, 7, 7, 42, 128], "mais de um WARP END compativel.")
	_case("false JIT ignores missing destination", ["ORB", "INT_SET", "ORB", "JUMP_IF_TRUE", "TRIANGLE", "WARP_ENDPOINT", "CROSS"], [2, 128, 9, 3, 128, 3, 128])
	_case("mutable warp ring", ["INT_SET", "ORB", "WARP", "ORB", "WARP", "PRINTLETTER", "CROSS"], [128, 7, 3, 99, 7, 101, 128])
	_case("warp ring wraps", ["ORB", "WARP", "WARP", "JUMP_IF_TRUE", "CROSS", "WARP_ENDPOINT", "WARP", "CROSS", "WARP_ENDPOINT", "PRINTLETTER", "CROSS"], [1, 8, 7, 9, 128, 8, 7, 128, 9, 101, 128], "", true)
	_case("conditional warp fallback", ["ORB", "JUMP_IF_TRUE", "CROSS", "WARP", "TRIANGLE", "CROSS", "WARP", "CROSS"], [1, 5, 128, 5, 128, 128, 5, 128], "", true)
	_case("repeated modifier", ["ORB", "WARP_ENDPOINT", "INT_MOD", "DIAMOND", "PRINTLETTER", "ORB", "MOON", "JUMP_IF_TRUE", "WARP", "WARP_ENDPOINT", "CROSS"], [4, 5, 128, 1, 64, 1, 128, 6, 5, 6, 128])
	_case("repeated setter", ["ORB", "WARP_ENDPOINT", "INT_SET", "TWIN", "ORB", "TRIANGLE", "CUP", "ORB", "MOON", "JUMP_IF_TRUE", "WARP", "WARP_ENDPOINT", "TRIANGLE", "CROSS"], [3, 5, 128, 128, 99, 128, 128, 1, 128, 6, 5, 6, 128, 128])
	_case("infinite loop", ["WARP_ENDPOINT", "WARP"], [5, 5], "limite de passos excedido.", true)
	_case("growing loop", ["WARP_ENDPOINT", "ORB", "WARP"], [5, 1, 5], "pilha ultrapassou 256 valores.", true)
	# Setter waiting across separate visual sequences.
	var cross_sequence := _program(["INT_SET", "WARP", "ORB", "ORB"], [128, 5, 1, 1])
	var second := _program(["WARP_ENDPOINT", "ORB", "ORB", "TRIANGLE"], [5, 7, 99, 128])
	for connection in second:
		connection["from"] += Vector2(0, 96)
		connection["to"] += Vector2(0, 96)
		cross_sequence.append(connection)
	var cross_compilation: Dictionary = Compiler.new().compile(cross_sequence)
	if _check(bool(cross_compilation.get("ok", false)), "cross-sequence compile"):
		var execution: Dictionary = VM.new().run(cross_compilation["bytecode"])
		_check(bool(execution["ok"]) and execution["output"] == ["7"], "cross-sequence VM")
		_native("cross-sequence setter", cross_sequence, "7", "")
	# Optional real-world ritual, e.g. -- C:/Users/Pichau/Downloads/fibby.atelier.
	for ritual_path in OS.get_cmdline_user_args():
		var loaded: Dictionary = RitualFile.load_file(ritual_path)
		if not _check(bool(loaded.get("ok", false)), "Ritual: %s" % loaded.get("error", "")):
			continue
		var ritual: Array[Dictionary] = loaded["connections"]
		var compiled: Dictionary = Compiler.new().compile(ritual)
		if not _check(bool(compiled.get("ok", false)), "Ritual compiler: %s" % [compiled.get("errors", [])]):
			continue
		var result: Dictionary = VM.new().run(compiled["bytecode"])
		if _check(bool(result["ok"]), "Ritual VM: %s" % [result.get("errors", [])]):
			_native(ritual_path.get_file(), ritual, "".join(result["output"]), "")
	if failures == 0:
		print("NASM_ALL_RUNES_OK: %d executaveis comparados com a VM" % native_cases)
	else:
		printerr("NASM_ALL_RUNES_FAILED: %d falhas" % failures)
	quit(0 if failures == 0 else 1)
