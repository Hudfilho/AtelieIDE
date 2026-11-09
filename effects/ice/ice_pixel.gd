extends Node2D
signal finished

@export_range(0.1, 5.0, 0.05) var burst_duration: float = 0.9
@export_range(0.0, 15.0, 0.1) var frozen_duration: float = 2.5
@export_range(0.1, 10.0, 0.1) var melt_duration: float = 1.6
@export_range(16.0, 1024.0, 1.0) var diameter: float = 256.0
@export_range(16, 128, 1) var pixel_resolution: int = 64
@export_range(0.0, 1.0, 0.01) var ground_opacity: float = 0.22
@export var play_on_ready: bool = true
@export var free_when_finished: bool = true

var _materials: Array[ShaderMaterial] = []
var _elapsed: float = 0.0

func _ready() -> void:
	for quad: ColorRect in [$Ground, $Wind]:
		var mat := quad.material.duplicate() as ShaderMaterial
		quad.material = mat
		mat.set_shader_parameter("age", 0.0)
		_materials.append(mat)
	set_process(false)
	if play_on_ready:
		play()

func play() -> void:
	if not is_node_ready():
		await ready
	var seed_value := randf_range(0.0, 1000.0)
	for quad: ColorRect in [$Ground, $Wind]:
		quad.position = -Vector2.ONE * diameter * 0.5
		quad.size = Vector2.ONE * diameter
	for mat in _materials:
		mat.set_shader_parameter("variation", seed_value)
		mat.set_shader_parameter("pixel_resolution", float(pixel_resolution))
		mat.set_shader_parameter("ground_opacity", ground_opacity)
		mat.set_shader_parameter("burst_duration", burst_duration)
		mat.set_shader_parameter("frozen_duration", frozen_duration)
		mat.set_shader_parameter("melt_duration", melt_duration)
		mat.set_shader_parameter("age", 0.0)
	_elapsed = 0.0
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	for mat in _materials:
		mat.set_shader_parameter("age", _elapsed)
	if _elapsed >= burst_duration + frozen_duration + melt_duration:
		set_process(false)
		visible = false
		finished.emit()
		if free_when_finished:
			queue_free()
