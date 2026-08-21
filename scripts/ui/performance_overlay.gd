class_name AtelierPerformanceOverlay
extends PanelContainer

const MAX_SAMPLES := 240

var title := Label.new()
var summary := Label.new()
var stages := Label.new()
var scene_stats := Label.new()
var render_stats := Label.new()
var samples: Array[float] = []
var latest_metrics: Dictionary = {}
var redraws_since_refresh := 0
var refresh_started_us := 0
var refresh_timer := Timer.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	accessibility_name = tr("UI_DIAGNOSTICS_TITLE")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	title.text = tr("UI_DIAGNOSTICS_TITLE")
	title.add_theme_font_size_override("font_size", 13)
	column.add_child(title)
	for label: Label in [summary, stages, scene_stats, render_stats]:
		label.add_theme_font_size_override("font_size", 11)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
	refresh_timer.wait_time = 1.0
	refresh_timer.one_shot = false
	refresh_timer.timeout.connect(_refresh_text)
	add_child(refresh_timer)
	refresh_started_us = Time.get_ticks_usec()
	refresh_timer.stop()
	_refresh_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		title.text = tr("UI_DIAGNOSTICS_TITLE")
		accessibility_name = title.text
		_refresh_text()


func set_overlay_rect(overlay_rect: Rect2) -> void:
	position = overlay_rect.position
	size = overlay_rect.size


func set_enabled(enabled: bool) -> void:
	visible = enabled
	if enabled:
		redraws_since_refresh = 0
		refresh_started_us = Time.get_ticks_usec()
		refresh_timer.start()
		_refresh_text()
	else:
		refresh_timer.stop()


func record_sample(metrics: Dictionary) -> void:
	latest_metrics = metrics.duplicate()
	var draw_ms := float(metrics.get("draw_ms", 0.0))
	samples.append(draw_ms)
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()
	redraws_since_refresh += 1


func _refresh_text() -> void:
	if not visible:
		return
	var elapsed: float = maxf(float(Time.get_ticks_usec() - refresh_started_us) / 1000000.0, 0.001)
	var redraws_per_second: float = float(redraws_since_refresh) / elapsed
	redraws_since_refresh = 0
	refresh_started_us = Time.get_ticks_usec()
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var p50: float = _percentile(ordered, 0.50)
	var p95: float = _percentile(ordered, 0.95)
	var maximum: float = ordered[-1] if not ordered.is_empty() else 0.0
	var fps: float = Engine.get_frames_per_second()
	summary.text = tr("UI_PERF_SUMMARY") % [fps, redraws_per_second, p50]
	stages.text = tr("UI_PERF_TIMINGS") % [
		maximum if ordered.size() == 1 else p95,
		maximum,
		float(latest_metrics.get("grid_ms", 0.0)),
		float(latest_metrics.get("connections_ms", 0.0)),
	]
	scene_stats.text = tr("UI_PERF_SCENE") % [
		int(latest_metrics.get("connections", 0)),
		int(latest_metrics.get("visible_connections", 0)),
		int(latest_metrics.get("grid_dots", 0)),
	]
	render_stats.text = tr("UI_PERF_RENDER") % int(
		latest_metrics.get("draw_calls", 0))
	accessibility_description = "%s. %s. %s. %s" % [summary.text, stages.text, scene_stats.text, render_stats.text]


func _percentile(ordered: Array[float], percentile: float) -> float:
	if ordered.is_empty():
		return 0.0
	var index := clampi(int(ceil(percentile * float(ordered.size()))) - 1, 0, ordered.size() - 1)
	return ordered[index]
