extends SceneTree

## Exercita os botões reais e a separação entre loja e compilador livre.
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr(message)


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	AtelierSettings.path = "user://mode_selection_smoke_%d.cfg" % Time.get_ticks_usec()
	root.size = Vector2i(1280, 720)
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/game/Title.tscn", "Project must start at the mode menu.")
	change_scene_to_file("res://scenes/game/Title.tscn")
	await _frames()
	current_scene.get_node("%SandboxButton").pressed.emit()
	await _frames()
	var canvas = current_scene
	_check(canvas.scene_file_path == "res://scenes/Main.tscn", "Sandbox button must open the standalone IDE.")
	_check(not canvas.game_mode and canvas.palette_symbols.size() == 30, "Sandbox must have the complete unrestricted catalog.")
	var toggle := canvas.get_node("FileToolbar/AssemblyToggle") as CheckButton
	var menu := (canvas.get_node("FileToolbar/FileMenu") as MenuButton).get_popup()
	var export_index := menu.get_item_index(canvas.FILE_MENU_ASSEMBLY)
	_check(not canvas.assembly_enabled and menu.is_item_disabled(export_index), "Assembly starts disabled in the Sandbox.")
	canvas.call("_add_connection", Vector2.ZERO, Vector2(48, 0))
	canvas.call("_set_connection_symbol", 0, "ORB")
	canvas.call("_set_connection_intensity", 0, 128)
	canvas.call("_add_connection", Vector2(48, 0), Vector2(96, 0))
	canvas.call("_set_connection_symbol", 1, "TRIANGLE")
	var assembly_path := "user://mode_selection_smoke_%d.asm" % Time.get_ticks_usec()
	canvas.call("_on_assembly_file_selected", assembly_path)
	_check(not FileAccess.file_exists(assembly_path), "Disabled assembly must not export, even through its callback.")
	toggle.button_pressed = true
	_check(canvas.assembly_enabled and not menu.is_item_disabled(export_index), "Assembly toggle must enable export.")
	canvas.call("_on_assembly_file_selected", assembly_path)
	_check(FileAccess.file_exists(assembly_path), "Enabled Sandbox must export NASM.")
	if FileAccess.file_exists(assembly_path):
		_check("global main" in FileAccess.get_file_as_string(assembly_path), "Export must contain native NASM.")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(assembly_path))
	canvas.assembly_result_dialog.hide()
	toggle.button_pressed = false
	_check(not canvas.assembly_enabled and menu.is_item_disabled(export_index), "Toggle must disable assembly again.")
	menu.id_pressed.emit(canvas.FILE_MENU_HOME)
	await _frames()
	_check(current_scene == canvas and canvas.menu_confirmation.visible, "Unsaved ritual must prompt before returning.")
	canvas.menu_confirmation.hide()
	_check(current_scene == canvas, "Cancelling return must keep the ritual.")
	menu.id_pressed.emit(canvas.FILE_MENU_HOME)
	canvas.menu_confirmation.confirmed.emit()
	await _frames()
	_check(current_scene.scene_file_path == "res://scenes/game/Title.tscn", "Confirmed return must open the mode menu.")

	var game_state: Node = root.get_node("GameState")
	game_state.money = -999
	current_scene.get_node("%PlayButton").pressed.emit()
	await _frames()
	var desk = current_scene
	_check(desk.scene_file_path == "res://scenes/game/Desk.tscn" and game_state.money == 20, "Shop button must start a new shop game.")
	var workbench = desk.get_node("%Workbench")
	var shop_canvas = workbench.get_node("%Canvas")
	_check(shop_canvas.game_mode and shop_canvas.get_node_or_null("FileToolbar") == null, "Shop must not expose the Sandbox file/assembly bar.")
	shop_canvas.set_assembly_enabled(true)
	_check(not shop_canvas.assembly_enabled, "Shop cannot activate the native compiler mode.")
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	desk.get_node("%OverlayButton").pressed.emit()
	desk.get_node("%BellButton").pressed.emit()
	desk.get_node("%ApproveButton").pressed.emit()
	await _frames()
	_check(workbench.visible and shop_canvas.palette_symbols.size() == 5, "Shop must retain day-specific rune restrictions.")
	desk.get_node("%SettingsButton").pressed.emit()
	var settings := desk.get_node("%Settings") as AtelierSettingsPanel
	_check(settings.visible and settings.menu_button.visible, "Shop settings must offer return to menu.")
	_check(shop_canvas.panel_cache_capture_blocked, "Settings must not be captured into the workbench panels.")
	settings.close()
	_check(not shop_canvas.panel_cache_capture_blocked, "Closing settings must restore clean panel capture.")
	settings.open()
	settings.menu_button.pressed.emit()
	var confirmation := desk.get_node("ReturnToMenuDialog") as ConfirmationDialog
	_check(confirmation.visible, "Leaving the shop must warn about restarting the day.")
	_check(shop_canvas.panel_cache_capture_blocked, "Return confirmation must not contaminate the panel cache.")
	confirmation.confirmed.emit()
	await _frames()
	_check(current_scene.scene_file_path == "res://scenes/game/Title.tscn", "Shop return must open the mode menu.")
	current_scene.get_node("%SandboxButton").pressed.emit()
	await _frames()
	_check(current_scene.palette_symbols.size() == 30 and not current_scene.assembly_enabled, "Shop restrictions must not leak into a fresh Sandbox.")
	if failures == 0:
		print("MODE_SELECTION_SMOKE_OK")
	quit(0 if failures == 0 else 1)
