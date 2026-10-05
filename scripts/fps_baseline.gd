extends Control

const REFRESH_INTERVAL := 0.25

@onready var fps_label: Label = $FPSLabel

var refresh_elapsed := REFRESH_INTERVAL


func _ready() -> void:
	_refresh_label()


func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < REFRESH_INTERVAL:
		return
	refresh_elapsed = 0.0
	_refresh_label()


func _refresh_label() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
