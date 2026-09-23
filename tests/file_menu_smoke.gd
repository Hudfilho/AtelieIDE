extends SceneTree

const RitualFile = preload("res://scripts/core/atelier_ritual_file.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var canvas := load("res://scenes/Main.tscn").instantiate() as Control
	root.add_child(canvas)
	await process_frame
	var file_menu := canvas.get_node("FileToolbar/FileMenu") as MenuButton
	assert(file_menu != null)
	assert(file_menu.get_popup().get_item_text(0) == "Salvar runa...")
	assert(file_menu.get_popup().get_item_text(1) == "Abrir runa...")
	assert(file_menu.get_popup().is_item_disabled(3))
	assert(canvas.call("_top_panel_rect").position.y >= 40.0)

	canvas.call("_add_connection", Vector2.ZERO, Vector2(48.0, 0.0))
	canvas.call("_set_connection_symbol", 0, "ORB")
	canvas.call("_set_connection_intensity", 0, 200)
	canvas.set("pan", Vector2(123.0, 234.0))
	canvas.set("left_panel_open", true)
	canvas.set("top_panel_open", true)
	canvas.set("bottom_panel_open", true)
	canvas.set("right_panel_open", true)
	canvas.queue_redraw()
	var file_path := "user://atelier_file_smoke_%d.atelier" % Time.get_ticks_usec()
	canvas.call("_on_save_file_selected", file_path)
	assert(FileAccess.file_exists(file_path))
	var loaded: Dictionary = RitualFile.load_file(file_path)
	assert(loaded.get("ok", false))
	assert(loaded["connections"].size() == 1)
	assert(loaded["connections"][0]["symbol"] == "ORB")
	assert(loaded["connections"][0]["intensity"] == 200)
	assert(loaded["pan"] == Vector2(123.0, 234.0))

	canvas.call("_add_connection", Vector2(48.0, 0.0), Vector2(96.0, 0.0))
	assert(canvas.get("connections").size() == 2)
	assert(hash(canvas.get("connections")) != canvas.get("saved_connections_signature"))
	canvas.call("_on_file_menu_item_pressed", 2)
	assert((canvas.get("open_confirmation") as ConfirmationDialog).visible)
	(canvas.get("open_confirmation") as ConfirmationDialog).hide()
	canvas.call("_on_open_file_selected", file_path)
	assert(canvas.get("connections").size() == 1)
	assert((canvas.get("diagram") as AtelierRuneDiagram).undo_history.is_empty())
	assert(canvas.get("current_ritual_path") == file_path)
	assert("atelier_file_smoke" in (canvas.get_node("FileToolbar/FileTitle") as Label).text)

	var invalid_path := file_path + ".bad"
	var invalid_file := FileAccess.open(invalid_path, FileAccess.WRITE)
	invalid_file.store_string("{invalid")
	invalid_file.close()
	assert(not RitualFile.load_file(invalid_path).get("ok", false))
	var no_extension_path := file_path.trim_suffix(".atelier") + "_sem_extensao"
	var extension_result: Dictionary = RitualFile.save_file(no_extension_path, canvas.get("connections"), Vector2.ZERO, 1.0)
	assert(extension_result.get("ok", false))
	assert(str(extension_result["path"]).ends_with(".atelier"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(invalid_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(extension_result["path"])))
	print("FILE_MENU_SMOKE_OK")
	quit()
