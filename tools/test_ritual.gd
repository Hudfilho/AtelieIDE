extends SceneTree

const RitualFile = preload("res://scripts/core/atelier_ritual_file.gd")
const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")
const RuneNasmExporter = preload("res://scripts/core/rune_nasm_exporter.gd")


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() < 1 or arguments.size() > 2:
		printerr("Uso: godot --headless --path <projeto> --script res://tools/test_ritual.gd -- <arquivo.atelier> [saida.asm]")
		quit(2)
		return
	var loaded: Dictionary = RitualFile.load_file(arguments[0])
	if not bool(loaded.get("ok", false)):
		printerr("Arquivo: ", loaded.get("error", "erro desconhecido"))
		quit(1)
		return
	var connections: Array[Dictionary] = loaded["connections"]
	print("Conexoes: ", connections.size())
	var compilation: Dictionary = RuneCompiler.new().compile(connections)
	if not bool(compilation.get("ok", false)):
		printerr("Compilacao VM: ", JSON.stringify(compilation.get("errors", [])))
		quit(1)
		return
	print("Instrucoes: ", (compilation["instructions"] as Array).size())
	var execution: Dictionary = RuneVM.new().run(compilation["bytecode"])
	print("VM OK: ", execution.get("ok", false))
	print("VM saida: ", JSON.stringify(execution.get("output", [])))
	print("VM pilha final: ", JSON.stringify(execution.get("stack", [])))
	if not bool(execution.get("ok", false)):
		printerr("VM erros: ", JSON.stringify(execution.get("errors", [])))
	var exporter := RuneNasmExporter.new()
	var assembly: Dictionary = exporter.export_file(connections, arguments[1]) if arguments.size() == 2 else exporter.generate(connections)
	print("NASM exportavel: ", assembly.get("ok", false))
	if not bool(assembly.get("ok", false)):
		printerr("NASM erros: ", JSON.stringify(assembly.get("errors", [])))
	elif arguments.size() == 2:
		print("NASM arquivo: ", assembly["path"])
	quit(0 if bool(execution.get("ok", false)) and bool(assembly.get("ok", false)) else 1)
