class_name AtelierSpellJudge
extends RefCounted

## Confere um pergaminho contra os exemplos e os testes ocultos de uma
## encomenda: compila o diagrama uma vez e roda a VM com a memória de cada caso.

const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")
const RuneVM = preload("res://scripts/core/rune_vm.gd")

var compiler: AtelierRuneCompiler = RuneCompiler.new()
var vm: AtelierRuneVM = RuneVM.new()


## Devolve {compiled, passed, errors, cases, rune_count, max_steps_used, elegant}.
## Cada caso: {memory, expected, actual, errors, passed, hidden, steps, timed_out}.
func judge(connections: Array, order: AtelierScrollOrder) -> Dictionary:
	var rune_count := count_runes(connections)
	var compilation := compiler.compile(connections)
	if not compilation["ok"]:
		return {"compiled": false, "passed": false, "errors": compilation.get("errors", []), "cases": [], "rune_count": rune_count, "max_steps_used": 0, "elegant": false}

	var tests := order.all_tests()
	var cases: Array[Dictionary] = []
	var passed := not tests.is_empty()
	var max_steps_used := 0
	for test_case in tests:
		var memory: Dictionary = test_case.get("memory", {})
		var expected := _as_strings(test_case.get("output", []))
		var run := vm.run(compilation["bytecode"], memory, order.max_steps)
		var actual := _as_strings(run.get("output", []))
		var errors: Array = run.get("errors", [])
		var steps := int(run.get("steps", 0))
		max_steps_used = maxi(max_steps_used, steps)
		var case_passed := errors.is_empty() and actual == expected
		passed = passed and case_passed
		cases.append({
			"memory": memory, "expected": expected, "actual": actual, "errors": errors, "passed": case_passed,
			"hidden": bool(test_case.get("hidden", false)), "steps": steps, "timed_out": bool(run.get("timed_out", false)),
		})
	var elegant := passed and order.par_runes > 0 and rune_count <= order.par_runes
	return {"compiled": true, "passed": passed, "errors": [], "cases": cases, "rune_count": rune_count, "max_steps_used": max_steps_used, "elegant": elegant}


static func count_runes(connections: Array) -> int:
	var count := 0
	for connection in connections:
		if not str(connection.get("symbol", "")).is_empty():
			count += 1
	return count


## Explica a primeira falha em uma linha, para o jogador. Um teste oculto que
## falha revela suas entradas: é a pista para depurar, e com vários ocultos
## decorar as respostas continua sem compensar.
static func describe_failure(result: Dictionary) -> String:
	if not result["compiled"]:
		var compile_errors: Array = result["errors"]
		return AtelierText.t("JUDGE_WONT_HOLD", [str(compile_errors[0]) if not compile_errors.is_empty() else AtelierText.t("JUDGE_INVALID_RITUAL")])
	for test_case in result["cases"]:
		if test_case["passed"]:
			continue
		var errors: Array = test_case["errors"]
		var clause: String
		if test_case["timed_out"]:
			clause = AtelierText.t("JUDGE_TIMEOUT", [int(test_case["steps"])])
		elif not errors.is_empty():
			clause = AtelierText.t("JUDGE_BROKE", [str(errors[0])])
		else:
			clause = AtelierText.t("JUDGE_MISMATCH", [describe_output(test_case["expected"]), describe_output(test_case["actual"])])
		var inputs := describe_memory(test_case["memory"])
		if not inputs.is_empty():
			clause = AtelierText.t("JUDGE_WITH_INPUTS", [inputs, clause])
		if test_case["hidden"]:
			clause = AtelierText.t("JUDGE_HIDDEN_FAILED", [clause])
		return clause
	return ""


## "slot 000 = 5, slot 001 = 7"; vazio quando não há entradas.
static func describe_memory(memory: Dictionary) -> String:
	var parts: PackedStringArray = []
	for slot in memory:
		parts.append(AtelierText.t("JUDGE_SLOT", [int(slot), str(memory[slot])]))
	return ", ".join(parts)


static func describe_output(output: Array) -> String:
	if output.is_empty():
		return AtelierText.t("JUDGE_NOTHING")
	return " ".join(PackedStringArray(output))


static func _as_strings(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
