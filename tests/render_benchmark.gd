extends SceneTree

const CASES := [
	{"cells": 50, "runes": 15, "zoom": 1.0},
	{"cells": 500, "runes": 150, "zoom": 0.45},
	{"cells": 5000, "runes": 1500, "zoom": 1.0},
]

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed_scene := load("res://scenes/Main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Nao foi possivel carregar Main.tscn")
		quit(1)
		return
	var main := packed_scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	main.set("left_panel_open", true)
	main.set("right_panel_open", true)
	main.set("top_panel_open", true)
	main.set("bottom_panel_open", true)
	main.call("_sync_interface_all")

	for benchmark_case: Dictionary in CASES:
		await _measure_case(main, int(benchmark_case["cells"]), int(benchmark_case["runes"]), float(benchmark_case["zoom"]))

	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("RENDER_BENCHMARK_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _measure_case(main: Control, cell_count: int, rune_count: int, case_zoom: float) -> void:
	var diagram := main.get("diagram") as AtelierRuneDiagram
	diagram.connections = _horizontal_chain(cell_count, rune_count)
	main.set("zoom", case_zoom)
	main.set("pan", Vector2(370.0, 300.0))
	main.call("_invalidate_sequence_side_multiplier_cache")
	main.call("_invalidate_symbol_connection_indices")
	main.call("_sync_interface_all")
	# Duas passadas aquecem os buckets espaciais, a contagem de ancoras e os
	# atlases de glifos. O benchmark mede o custo sustentado, nao a importacao.
	for warmup in range(2):
		main.set("pan", Vector2(370.0 - float(warmup) * 96.0, 300.0))
		main.queue_redraw()
		await process_frame
		await process_frame
	var samples: Array[float] = []
	var visible_samples: Array[int] = []
	for sweep in range(8):
		main.set("pan", Vector2(370.0 - float(sweep) * 96.0, 300.0))
		main.queue_redraw()
		await process_frame
		await process_frame
		samples.append(float(main.get("performance_draw_ms")))
		visible_samples.append(int(main.get("performance_visible_connections")))
	samples.sort()
	visible_samples.sort()
	var p50: float = _percentile(samples, 0.50)
	var p95: float = _percentile(samples, 0.95)
	var visible_max: int = visible_samples[-1] if not visible_samples.is_empty() else 0
	print("BENCH cells=%d runes=%d zoom=%.2f visible_max=%d draw_p50=%.3fms draw_p95=%.3fms" % [
		cell_count, rune_count, case_zoom, visible_max, p50, p95,
	])
	if cell_count >= 5000 and visible_max >= cell_count / 4:
		failures.append("Culling espacial deixou conexoes demais visiveis no caso de 5000 celulas")
	if p95 > 50.0:
		failures.append("Desenho ultrapassou 50 ms no caso de %d celulas (p95 %.2f ms)" % [cell_count, p95])


func _horizontal_chain(cell_count: int, rune_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(cell_count)
	for index in range(cell_count):
		var from := Vector2(float(index) * 48.0, 0.0)
		result[index] = {
			"from": from,
			"to": from + Vector2(48.0, 0.0),
			"symbol": "ORB" if index < rune_count else "",
			"intensity": index % 256,
		}
	return result


func _percentile(ordered: Array[float], percentile: float) -> float:
	if ordered.is_empty():
		return 0.0
	var index := clampi(int(ceil(percentile * float(ordered.size()))) - 1, 0, ordered.size() - 1)
	return ordered[index]
