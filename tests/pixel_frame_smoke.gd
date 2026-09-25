extends SceneTree

## Grade de apresentação do balcão: sempre a maior escala INTEIRA de 640x360
## que cabe na janela, centralizada, com tarjas no resto. Nunca fracionária.
## A bancada de runas não passa por essa restrição.

const BASE := Vector2i(640, 360)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# As preferências salvas do jogador (idioma, estilo do balcão) não entram
	# no teste: um arquivo que nunca é gravado deixa tudo no padrão.
	AtelierSettings.path = "user://smoke_defaults.cfg"
	# Escalas esperadas nas resoluções comuns.
	var expected := {
		Vector2i(1280, 720): [2, Rect2i(0, 0, 1280, 720)],
		Vector2i(1920, 1080): [3, Rect2i(0, 0, 1920, 1080)],
		Vector2i(2560, 1440): [4, Rect2i(0, 0, 2560, 1440)],
		Vector2i(1366, 768): [2, Rect2i(43, 24, 1280, 720)],
	}
	for window: Vector2i in expected:
		var result := AtelierPixelFrame.fit(window)
		assert(result["scale"] == expected[window][0], "%s -> scale %d" % [window, result["scale"]])
		assert(result["rect"] == expected[window][1], "%s -> %s" % [window, result["rect"]])

	# Qualquer janela: escala inteira, a maior que cabe, centralizada.
	var sizes: Array[Vector2i] = [
		Vector2i(640, 360), Vector2i(800, 600), Vector2i(1024, 768), Vector2i(1280, 800), Vector2i(1281, 721),
		Vector2i(1360, 765), Vector2i(1366, 768), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1680, 1050),
		Vector2i(1920, 1200), Vector2i(2560, 1080), Vector2i(3440, 1440), Vector2i(3840, 2160),
	]
	for window in sizes:
		var result := AtelierPixelFrame.fit(window)
		var scale: int = result["scale"]
		var rect: Rect2i = result["rect"]
		assert(typeof(scale) == TYPE_INT and scale >= 1)
		assert(rect.size == BASE * scale, "%s: %s is not %d x base" % [window, rect.size, scale])
		assert(Rect2i(Vector2i.ZERO, window).encloses(rect), "%s: desk %s leaves the window" % [window, rect])
		var next := BASE * (scale + 1)
		assert(next.x > window.x or next.y > window.y, "%s: scale %d is not the largest that fits" % [window, scale])
		var leftover_before := rect.position
		var leftover_after := window - rect.end
		assert(absi(leftover_before.x - leftover_after.x) <= 1 and absi(leftover_before.y - leftover_after.y) <= 1, "%s: not centered" % window)

	# Aplicado ao balcão real: escala física exatamente inteira nos dois eixos.
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	(desk.get_node("%Feedback") as AtelierDeskFeedback).mute = true
	root.add_child(desk)
	await process_frame
	var frame := desk.get_node("%PixelLayer") as AtelierPixelFrame
	var viewport := desk.get_node("%PixelViewport") as SubViewport
	assert(frame != null and not frame.view.stretch, "The desk frame scales itself; SubViewport stretch stays off")
	assert(frame.view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(frame.view.scale == Vector2.ONE and frame.view.position == Vector2.ZERO, "Only the layer transform scales and places the desk")
	assert(frame.desk_scale == 2, "The default 1280x720 window shows the desk at 2x")
	var windows := {
		Vector2i(1280, 720): Vector2(1.0, 1.0),
		Vector2i(1366, 768): Vector2(1366.0 / 1280.0, 768.0 / 720.0),
		Vector2i(1920, 1080): Vector2(1.5, 1.5),
		Vector2i(2560, 1440): Vector2(2.0, 2.0),
	}
	for window: Vector2i in windows:
		var logical_to_physical: Vector2 = windows[window]
		frame.apply_fit(window, logical_to_physical)
		var fit := AtelierPixelFrame.fit(window)
		var physical_scale := frame.transform.get_scale() * logical_to_physical
		var physical_origin := frame.transform.origin * logical_to_physical
		assert(frame.desk_scale == fit["scale"])
		assert(is_equal_approx(physical_scale.x, float(fit["scale"])) and is_equal_approx(physical_scale.y, float(fit["scale"])), "%s: physical scale %s is fractional" % [window, physical_scale])
		var rect: Rect2i = fit["rect"]
		# Origem física dentro do pixel certo, longe da borda: truncar ou
		# arredondar dá o mesmo pixel inteiro.
		assert(Vector2i(physical_origin.floor()) == rect.position and Vector2i(physical_origin.round()) == rect.position, "%s: desk drawn at %s, expected %s" % [window, physical_origin, rect.position])
		assert(viewport.size == BASE, "The desk stays authored at 640x360")
	var workbench := desk.get_node("%Workbench") as Control
	assert(workbench.scale == Vector2.ONE and not frame.is_ancestor_of(workbench), "The workbench is not bound to the pixel grid")
	assert(frame.layer < 0 and (desk as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE, "The desk layer sits below the full-res UI and receives clicks through it")

	desk.queue_free()
	await process_frame
	print("PIXEL_FRAME_SMOKE_OK")
	quit(0)
