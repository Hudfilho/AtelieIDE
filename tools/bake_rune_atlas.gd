extends SceneTree

const ATLAS_COLUMNS := 8
const ATLAS_ROWS := 4
const ATLAS_TILE_SIZE := 128
const ATLAS_SIZE := Vector2i(ATLAS_COLUMNS * ATLAS_TILE_SIZE, ATLAS_ROWS * ATLAS_TILE_SIZE)
const OUTPUT_DIRECTORY := "res://art/generated"
const OUTPUT_PATH := OUTPUT_DIRECTORY + "/rune_atlas.png"


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 0.0))
	# Não usamos a janela raiz: ela aplica o stretch 1280x720 do projeto e
	# desloca as células do atlas. Um SubViewport tem exatamente 1024x512.
	var viewport := SubViewport.new()
	viewport.size = ATLAS_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var packed_scene := load("res://scenes/Main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Nao foi possivel carregar a cena principal para gerar o atlas.")
		quit(1)
		return
	var canvas := packed_scene.instantiate() as Control
	if canvas == null:
		push_error("A cena principal nao produziu um canvas valido.")
		quit(1)
		return

	canvas.set("atlas_baking_mode", true)
	viewport.add_child(canvas)
	await process_frame
	# A cena principal vem ancorada para preencher uma janela normal. No
	# SubViewport, removemos essas âncoras antes de definir o tamanho exato.
	canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	canvas.position = Vector2.ZERO
	canvas.size = Vector2(ATLAS_SIZE)
	var panel_skins: Dictionary = canvas.get("panel_skin_nodes")
	for raw_skin in panel_skins.values():
		var skin := raw_skin as CanvasItem
		if skin != null:
			skin.visible = false
	await process_frame
	canvas.queue_redraw()
	await process_frame

	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIRECTORY))
	if directory_error != OK:
		push_error("Nao foi possivel criar a pasta de atlas: %s" % OUTPUT_DIRECTORY)
		canvas.queue_free()
		quit(1)
		return
	var image := viewport.get_texture().get_image()
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error("Nao foi possivel gravar o atlas: %s" % OUTPUT_PATH)
		canvas.queue_free()
		quit(1)
		return

	print("RUNE_ATLAS_WRITTEN %s %dx%d" % [OUTPUT_PATH, image.get_width(), image.get_height()])
	canvas.queue_free()
	await process_frame
	quit()
