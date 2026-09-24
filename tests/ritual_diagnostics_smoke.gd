extends SceneTree

const RuneCompiler = preload("res://scripts/core/rune_compiler.gd")


func _initialize() -> void:
	call_deferred("_run")


func _program(kinds: Array, intensities: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(kinds.size()):
		result.append({
			"from": Vector2(index * 48.0, 0.0),
			"to": Vector2((index + 1) * 48.0, 0.0),
			"symbol": kinds[index],
			"intensity": intensities[index] if index < intensities.size() else 128,
		})
	return result


func _expect_error(compiler: AtelierRuneCompiler, kinds: Array, code: String, marked_index := 0, intensities: Array = []) -> void:
	var result: Dictionary = compiler.compile(_program(kinds, intensities))
	assert(not result["ok"], "Expected preflight error for %s" % str(kinds))
	assert(not result["diagnostics"].is_empty())
	var found := false
	for diagnostic in result["diagnostics"]:
		if int(diagnostic["connection_index"]) == marked_index and diagnostic["code"] == code:
			found = true
	assert(found, "Missing '%s' on cell %d: %s" % [code, marked_index, str(result["diagnostics"])])


func _run() -> void:
	var compiler := RuneCompiler.new()
	_expect_error(compiler, ["WARP"], "COMPILER_WARP_NO_TARGET")
	assert(compiler.compile(_program(["WARP", "WARP"]))["ok"])
	assert(compiler.compile(_program(["WARP", "WARP_ENDPOINT"]))["ok"])
	# INT_SET pode tornar um destino compatível antes de WARP executar.
	assert(compiler.compile(_program(["INT_SET", "ORB", "WARP_ENDPOINT", "WARP"], [128, 200, 100, 200]))["ok"])
	_expect_error(compiler, ["WARP_ENDPOINT", "WARP_ENDPOINT"], "COMPILER_WARP_END_DUPLICATE")
	_expect_error(compiler, ["JUMP_IF_TRUE"], "COMPILER_JUMP_NO_TARGET")
	_expect_error(compiler, ["INT_MOD"], "COMPILER_INT_MOD_NEEDS_TWO")
	_expect_error(compiler, ["INT_MOD", "ORB", "ORB"], "COMPILER_INT_MOD_NEEDS_OP")
	_expect_error(compiler, ["INT_MOD", "DIAMOND"], "COMPILER_INT_MOD_NO_TARGET")
	_expect_error(compiler, ["INT_MOD", "SLASH", "ORB"], "COMPILER_INT_MOD_ZERO", 0, [128, 0, 128])
	assert(compiler.compile(_program(["INT_MOD", "DIAMOND", "ORB"]))["ok"])
	_expect_error(compiler, ["INT_SET"], "COMPILER_INT_SET_NO_VALUE")
	_expect_error(compiler, ["INT_SET", "ORB"], "COMPILER_INT_SET_NO_TARGET")
	assert(compiler.compile(_program(["INT_SET", "ORB", "TRIANGLE"]))["ok"])
	var multiple: Dictionary = compiler.compile(_program(["WARP", "INT_MOD"]))
	assert(not multiple["ok"])
	assert(multiple["diagnostics"].size() == 2)
	assert(multiple["diagnostics"][0]["connection_index"] == 0)
	assert(multiple["diagnostics"][1]["connection_index"] == 1)

	root.size = Vector2i(1280, 720)
	var canvas := load("res://scenes/Main.tscn").instantiate() as Control
	root.add_child(canvas)
	await process_frame
	canvas.call("_add_connection", Vector2.ZERO, Vector2(48.0, 0.0))
	canvas.call("_set_connection_symbol", 0, "WARP")
	canvas.call("_run_ritual")
	assert(canvas.get("bottom_panel_open"))
	assert(not (canvas.get("execution_errors") as Array).is_empty())
	assert((canvas.get("invalid_connection_indices") as Dictionary).has(0))
	canvas.call("_set_connection_symbol", 0, "ORB")
	assert((canvas.get("invalid_connection_indices") as Dictionary).is_empty())
	assert((canvas.get("execution_errors") as Array).is_empty())
	canvas.call("_run_ritual")
	assert((canvas.get("invalid_connection_indices") as Dictionary).is_empty())
	canvas.call("_stop_ritual")
	canvas.call("_set_connection_symbol", 0, "CUP")
	canvas.call("_run_ritual")
	assert((canvas.get("invalid_connection_indices") as Dictionary).has(0))
	assert(str((canvas.get("execution_errors") as Array)[0]) == tr("VM_NEEDS_VALUE") % ["DROP"])
	print("RITUAL_DIAGNOSTICS_SMOKE_OK")
	quit()
