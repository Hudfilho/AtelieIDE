extends SceneTree

const RuneNasmExporter = preload("res://scripts/core/rune_nasm_exporter.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _program(kinds: Array, intensities: Array) -> Array[Dictionary]:
	var connections: Array[Dictionary] = []
	for index in range(kinds.size()):
		connections.append({
			"from": Vector2(index * 48.0, 0.0),
			"to": Vector2((index + 1) * 48.0, 0.0),
			"symbol": kinds[index],
			"intensity": intensities[index],
		})
	return connections


func _verify_with_nasm(exporter: AtelierRuneNasmExporter, connections: Array[Dictionary]) -> void:
	var nasm_path := OS.get_environment("ATELIER_NASM_PATH")
	if nasm_path.is_empty():
		return
	var path := "user://atelier_nasm_smoke_%d.asm" % Time.get_ticks_usec()
	var exported: Dictionary = exporter.export_file(connections, path)
	assert(exported.get("ok", false))
	var absolute_path := ProjectSettings.globalize_path(str(exported["path"]))
	var object_path := absolute_path.get_basename() + ".obj"
	var assembler_output: Array = []
	var exit_code := OS.execute(nasm_path, ["-f", "win64", absolute_path, "-o", object_path], assembler_output, true)
	if exit_code != 0:
		failures += 1
		printerr("NASM rejeitou o arquivo: ", assembler_output)
		return
	assert(FileAccess.file_exists(object_path))
	DirAccess.remove_absolute(absolute_path)
	DirAccess.remove_absolute(object_path)


func _verify_native_output(exporter: AtelierRuneNasmExporter, connections: Array[Dictionary], expected: String, expected_exit_code := 0) -> void:
	var nasm_path := OS.get_environment("ATELIER_NASM_PATH")
	var gcc_path := OS.get_environment("ATELIER_GCC_PATH")
	if nasm_path.is_empty() or gcc_path.is_empty():
		return
	var path := "user://atelier_native_smoke_%d.asm" % Time.get_ticks_usec()
	var exported: Dictionary = exporter.export_file(connections, path)
	if not bool(exported.get("ok", false)):
		failures += 1
		printerr(exported.get("errors", []))
		return
	var absolute_path := ProjectSettings.globalize_path(str(exported["path"]))
	var object_path := absolute_path.get_basename() + ".obj"
	var executable_path := absolute_path.get_basename() + ".exe"
	var tool_output: Array = []
	var assembled := OS.execute(nasm_path, ["-f", "win64", absolute_path, "-o", object_path], tool_output, true)
	if assembled != 0:
		failures += 1
		printerr("NASM: ", tool_output)
		return
	tool_output.clear()
	var linked := OS.execute(gcc_path, [object_path, "-o", executable_path], tool_output, true)
	if linked != 0:
		failures += 1
		printerr("GCC: ", tool_output)
		return
	var program_output: Array = []
	var stdout_path := absolute_path.get_basename() + ".stdout"
	var capture := ProjectSettings.globalize_path("res://tests/capture_native_output.ps1")
	var exit_code := OS.execute("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", capture, "-ExecutablePath", executable_path, "-OutputPath", stdout_path], program_output, true)
	var actual := FileAccess.get_file_as_string(stdout_path).replace("\r\n", "\n")
	if exit_code != expected_exit_code or actual != expected:
		failures += 1
		printerr("Esperado saida=", expected, " exit=", expected_exit_code, "; recebido saida=", actual, " exit=", exit_code, " ferramentas=", program_output)
	DirAccess.remove_absolute(absolute_path)
	DirAccess.remove_absolute(object_path)
	DirAccess.remove_absolute(executable_path)
	DirAccess.remove_absolute(stdout_path)


func _assert_vm_output(connections: Array[Dictionary], expected: Array) -> void:
	var compilation: Dictionary = RuneCompiler.new().compile(connections)
	assert(compilation.get("ok", false), str(compilation.get("errors", [])))
	var execution: Dictionary = RuneVM.new().run(compilation["bytecode"])
	assert(execution.get("ok", false), str(execution.get("errors", [])))
	assert(execution["output"] == expected)


func _run() -> void:
	var exporter := RuneNasmExporter.new()
	var sample := _program(["ORB", "ORB", "DIAMOND", "TRIANGLE", "CROSS"], [2, 3, 128, 128, 128])
	var result: Dictionary = exporter.generate(sample)
	assert(result.get("ok", false))
	var source := str(result["source"])
	assert("global main" in source)
	assert("mov qword [rsp + 32], 2" in source)
	assert("mov qword [rsp + 40], 3" in source)
	assert("add rax, [rsp + 40]" in source)
	assert("call printf" in source)
	assert("rune_stack" not in source)
	var small: Dictionary = exporter.generate(_program(["ORB", "TRIANGLE"], [128, 128]))
	assert(small.get("ok", false))
	var small_source := str(small["source"])
	assert("mov qword [rsp + 32], 128" in small_source)
	assert("mov rdx, [rsp + 32]" in small_source)
	assert("sub rsp, 40" in small_source)
	assert(small_source.split("\n").size() <= 23)
	_verify_with_nasm(exporter, _program(["ORB", "TRIANGLE"], [128, 128]))
	_verify_native_output(exporter, _program(["ORB", "TRIANGLE"], [128, 128]), "128")
	_verify_with_nasm(exporter, _program(
		["ORB", "TWIN", "ORB", "KNOT", "DIAMOND", "DASH", "ORB", "MOON", "PLUS", "TRIANGLE", "CUP", "CROSS"],
		[5, 128, 3, 128, 128, 128, 2, 128, 128, 128, 128, 128]))
	var warp_endpoint := _program(["ORB", "WARP", "ORB", "WARP_ENDPOINT", "TRIANGLE", "CROSS"], [7, 5, 99, 5, 128, 128])
	var endpoint_result: Dictionary = exporter.generate(warp_endpoint)
	assert(endpoint_result.get("ok", false), str(endpoint_result.get("errors", [])))
	assert("jmp rune_4" in str(endpoint_result["source"]))
	assert("rune_4:" in str(endpoint_result["source"]))
	assert(" 99" not in str(endpoint_result["source"])) # Celula inalcançavel nao e emitida.
	_assert_vm_output(warp_endpoint, ["7"])
	_verify_with_nasm(exporter, warp_endpoint)
	_verify_native_output(exporter, warp_endpoint, "7")
	var warp_ring := _program(["ORB", "WARP", "ORB", "WARP", "TRIANGLE", "CROSS"], [9, 5, 99, 5, 128, 128])
	var ring_result: Dictionary = exporter.generate(warp_ring)
	assert(ring_result.get("ok", false), str(ring_result.get("errors", [])))
	assert("jmp rune_4" in str(ring_result["source"]))
	_assert_vm_output(warp_ring, ["9"])
	_verify_with_nasm(exporter, warp_ring)
	for condition in [0, 1, 2]:
		var conditional := _program(["ORB", "JUMP_IF_TRUE", "CUP", "ORB", "WARP_ENDPOINT", "TRIANGLE", "CROSS"], [condition, 5, 128, 99, 5, 128, 128])
		var conditional_result: Dictionary = exporter.generate(conditional)
		assert(conditional_result.get("ok", false), str(conditional_result.get("errors", [])))
		assert("cmp qword [rsp + 32], 1" in str(conditional_result["source"]))
		assert("je rune_5" in str(conditional_result["source"]))
		_assert_vm_output(conditional, ["1"] if condition == 1 else ["99"])
		_verify_with_nasm(exporter, conditional)
		_verify_native_output(exporter, conditional, "1" if condition == 1 else "99")
	var conditional_warp := _program(["ORB", "JUMP_IF_TRUE", "CROSS", "WARP", "TRIANGLE", "CROSS", "WARP", "CROSS"], [1, 5, 128, 5, 128, 128, 5, 128])
	var conditional_warp_result: Dictionary = exporter.generate(conditional_warp)
	assert(conditional_warp_result.get("ok", false), str(conditional_warp_result.get("errors", [])))
	assert("je rune_4" in str(conditional_warp_result["source"]))
	_assert_vm_output(conditional_warp, ["1"])
	_verify_with_nasm(exporter, conditional_warp)
	var loop := _program(["ORB", "WARP_ENDPOINT", "ORB", "MOON", "JUMP_IF_TRUE", "WARP", "WARP_ENDPOINT", "TRIANGLE", "CROSS"], [3, 5, 1, 128, 6, 5, 6, 128, 128])
	var loop_result: Dictionary = exporter.generate(loop)
	assert(loop_result.get("ok", false), str(loop_result.get("errors", [])))
	assert("jmp rune_2" in str(loop_result["source"]))
	assert("je rune_7" in str(loop_result["source"]))
	_assert_vm_output(loop, ["1"])
	_verify_with_nasm(exporter, loop)
	_verify_native_output(exporter, loop, "1")
	var memory_sample := _program(
		["ORB", "SQUARE", "FORK", "ORB", "LTE", "TRIANGLE", "PRINTLETTER", "CUP", "READ", "TRIANGLE", "CROSS"],
		[3, 1, 1, 3, 128, 128, 101, 128, 1, 128, 128])
	var memory_result: Dictionary = exporter.generate(memory_sample)
	assert(memory_result.get("ok", false), str(memory_result.get("errors", [])))
	assert("memory_1: resq 1" in str(memory_result["source"]))
	assert("setle al" in str(memory_result["source"]))
	assert("format_character" in str(memory_result["source"]))
	_assert_vm_output(memory_sample, ["1", "e", "3"])
	_verify_with_nasm(exporter, memory_sample)
	_verify_native_output(exporter, memory_sample, "1e3")
	var missing_memory := _program(["READ"], [1])
	var missing_memory_result: Dictionary = exporter.generate(missing_memory)
	assert(missing_memory_result.get("ok", false))
	_verify_native_output(exporter, missing_memory, "Atelier: leitura de memoria vazia.\n", 1)
	var non_ascii: Dictionary = exporter.generate(_program(["PRINTLETTER"], [200]))
	assert(non_ascii.get("ok", false))
	_verify_native_output(exporter, _program(["PRINTLETTER"], [200]), String.chr(200))
	var unbalanced := _program(["ORB", "JUMP_IF_TRUE", "ORB", "WARP_ENDPOINT", "TRIANGLE"], [1, 5, 99, 5, 128])
	var unbalanced_result: Dictionary = exporter.generate(unbalanced)
	assert(not unbalanced_result.get("ok", false))
	assert("alturas de pilha diferentes" in str(unbalanced_result.get("errors", [])))
	var underflow: Dictionary = exporter.generate(_program(["TRIANGLE"], [128]))
	assert(not underflow.get("ok", false))
	assert("pilha" in str(underflow.get("errors", [])))
	_verify_native_output(exporter, _program(["ORB", "ORB", "SLASH", "TRIANGLE"], [4, 2, 128, 128]), "2")
	var rejected_path := "user://atelier_nasm_rejected_%d.asm" % Time.get_ticks_usec()
	var rejected: Dictionary = exporter.export_file(_program(["TRIANGLE"], [128]), rejected_path)
	assert(not rejected.get("ok", false))
	assert(not FileAccess.file_exists(rejected_path))
	if failures == 0:
		print("NASM_EXPORT_SMOKE_OK")
	quit(0 if failures == 0 else 1)
