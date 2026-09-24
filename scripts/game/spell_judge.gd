class_name AtelierSpellJudge
extends RefCounted

## Confere um pergaminho contra os casos de teste de uma encomenda: compila o
## diagrama uma vez e roda a VM com a memória de cada caso.

const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")

var compiler: AtelierRuneCompiler = RuneCompiler.new()
var vm: AtelierRuneVM = RuneVM.new()


func judge(connections: Array, order: AtelierScrollOrder) -> Dictionary:
	var rune_count := count_runes(connections)
	var compilation := compiler.compile(connections)
	if not compilation["ok"]:
		return {"compiled": false, "passed": false, "errors": compilation.get("errors", []), "cases": [], "rune_count": rune_count, "elegant": false}

	var cases: Array[Dictionary] = []
	var passed := not order.test_cases.is_empty()
	for test_case in order.test_cases:
		var memory: Dictionary = test_case.get("memory", {})
		var expected := _as_strings(test_case.get("output", []))
		var run := vm.run(compilation["bytecode"], memory)
		var actual := _as_strings(run.get("output", []))
		var errors: Array = run.get("errors", [])
		var case_passed := errors.is_empty() and actual == expected
		passed = passed and case_passed
		cases.append({"memory": memory, "expected": expected, "actual": actual, "errors": errors, "passed": case_passed})
	var elegant := passed and order.par_runes > 0 and rune_count <= order.par_runes
	return {"compiled": true, "passed": passed, "errors": [], "cases": cases, "rune_count": rune_count, "elegant": elegant}


static func count_runes(connections: Array) -> int:
	var count := 0
	for connection in connections:
		if not str(connection.get("symbol", "")).is_empty():
			count += 1
	return count


## Explica a primeira falha em uma linha, para o jogador.
static func describe_failure(result: Dictionary) -> String:
	if not result["compiled"]:
		var errors: Array = result["errors"]
		return "The scroll won't hold: %s" % (str(errors[0]) if not errors.is_empty() else "invalid ritual.")
	for test_case in result["cases"]:
		if test_case["passed"]:
			continue
		var inputs := describe_memory(test_case["memory"])
		var errors: Array = test_case["errors"]
		if not errors.is_empty():
			return "%sthe spell broke: %s" % [inputs, str(errors[0])]
		return "%sexpected %s, got %s." % [inputs, describe_output(test_case["expected"]), describe_output(test_case["actual"])]
	return ""


static func describe_memory(memory: Dictionary) -> String:
	if memory.is_empty():
		return ""
	var parts: PackedStringArray = []
	for slot in memory:
		parts.append("slot %03d = %s" % [int(slot), str(memory[slot])])
	return "With %s, " % ", ".join(parts)


static func describe_output(output: Array) -> String:
	if output.is_empty():
		return "nothing"
	return " ".join(PackedStringArray(output))


static func _as_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
