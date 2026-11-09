extends Node2D
## Call play() to replay; play_on_ready starts automatically when instantiated.
signal finished

@export_range(0.1, 5.0, 0.05) var duration: float = 0.85
@export_range(16.0, 1024.0, 1.0) var diameter: float = 192.0
@export_range(16, 128, 1) var pixel_resolution: int = 64
@export var play_on_ready: bool = true
@export var free_when_finished: bool = true

@onready var _quad: ColorRect = $Visual
var _material: ShaderMaterial
var _elapsed: float = 0.0
var _playing: bool = false

func _ready() -> void:
	_material = _quad.material.duplicate() as ShaderMaterial
	_quad.material = _material
	_material.set_shader_parameter("progress", 0.0)
	set_process(false)
	if play_on_ready:
		play()

func play() -> void:
	if not is_node_ready():
		await ready
	_quad.position = Vector2.ONE * (-diameter * 0.5)
	_quad.size = Vector2.ONE * diameter
	_material.set_shader_parameter("pixel_resolution", float(pixel_resolution))
	_material.set_shader_parameter("variation", randf_range(0.0, 1000.0))
	_material.set_shader_parameter("progress", 0.0)
	_elapsed = 0.0
	_playing = true
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	var t: float = minf(_elapsed / maxf(duration, 0.01), 1.0)
	_material.set_shader_parameter("progress", t)
	if t >= 1.0:
		_playing = false
		set_process(false)
		visible = false
		finished.emit()
		if free_when_finished:
			queue_free()
