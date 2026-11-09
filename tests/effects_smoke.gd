extends SceneTree

## Os três efeitos do Codex carregam, tocam e se removem; a explosão do jogo
## escolhe resolução para pixels de 4 px e recolore sem elemento.

const Explosion = preload("res://scripts/arena/explosion.gd")
var failures := 0


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		printerr("FALHOU: ", label)


func _initialize() -> void:
	for path in ["res://effects/fire/fireball_pixel.tscn", "res://effects/electric/electric_pixel.tscn", "res://effects/ice/ice_pixel.tscn"]:
		var scene: PackedScene = load(path)
		check(scene != null, "carrega " + path)
		if scene == null:
			continue
		var effect := scene.instantiate()
		root.add_child(effect)
		check(effect.has_signal("finished"), "finished em " + path)
	var fire := Explosion.new()
	fire.radius = 64.0
	fire.element = "fire"
	root.add_child(fire)
	var arcane := Explosion.new()
	arcane.radius = 64.0
	root.add_child(arcane)
	await process_frame
	var visual: ColorRect = fire.get_child(0).get_node("Visual")
	check(is_equal_approx(visual.size.x / float(fire.get_child(0).pixel_resolution), 4.0), "pixel do shader = 4 px")
	check(visual.size.x * 0.5 * 0.84 >= 64.0, "efeito cobre o raio de dano")
	var arcane_material: ShaderMaterial = arcane.get_child(0)._material
	check(arcane_material.get_shader_parameter("orange_color") != fire.get_child(0)._material.get_shader_parameter("orange_color"), "arcana recolorida")
	await create_timer(1.1).timeout
	check(not is_instance_valid(fire) and not is_instance_valid(arcane), "explosões se removem ao terminar")
	if failures == 0:
		print("EFFECTS_SMOKE_OK")
	quit(1 if failures > 0 else 0)
