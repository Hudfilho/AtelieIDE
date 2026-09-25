extends SceneTree

## Retratos dos clientes (AtelierPortrait): os PNGs são pixel art de verdade
## (92x92, alfa binário, paleta curta, busto encostado embaixo), todas as
## versões de um cliente usam o mesmo retrato, e o balcão troca a expressão
## conforme o que acontece: neutra ao chegar, feliz na aprovação, contrariada
## na recusa e na impaciência. Clientes sem retrato ficam na silhueta tingida.

const PORTRAITS_DIR := "res://data/portraits"
const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres", "res://data/days/day_03.tres"]
const SIZE := Vector2i(92, 92)
## Paleta do personagem mais o contorno.
const MAX_COLORS := 33
const MOODS: Array[AtelierPortrait.Mood] = [AtelierPortrait.Mood.NEUTRAL, AtelierPortrait.Mood.HAPPY, AtelierPortrait.Mood.UNEASY, AtelierPortrait.Mood.UPSET]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# As preferências salvas do jogador (idioma, estilo do balcão) não entram
	# no teste: um arquivo que nunca é gravado deixa tudo no padrão.
	AtelierSettings.path = "user://smoke_defaults.cfg"
	# 1. Os arquivos.
	var checked := 0
	for file_name in DirAccess.get_files_at(PORTRAITS_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var face := load(PORTRAITS_DIR.path_join(file_name)) as AtelierPortrait
		assert(face != null and not face.character.is_empty(), "%s is not a named AtelierPortrait" % file_name)
		assert(face.neutral != null, "%s has no neutral expression" % file_name)
		for mood in MOODS:
			_check_pixel_art(face.texture_for(mood), "%s/%s" % [face.character, AtelierPortrait.Mood.keys()[mood]])
		checked += 1
	assert(checked >= 9, "Expected the nine character portraits, found %d" % checked)
	var hooded := load("res://art/pixel/portrait_hooded.png") as Texture2D
	assert(hooded.get_size() == Vector2(SIZE), "The generic silhouette uses the same canvas as the portraits")

	# 2. Um cliente, um retrato, em todas as versões.
	var faces_by_client := {}
	for day_path in DAYS:
		for slot in (load(day_path) as AtelierShopDay).orders:
			for order in AtelierShopDay.versions_of(slot):
				if order.portrait != null:
					faces_by_client.get_or_add(order.client_name, {})[order.portrait.resource_path] = true
	for client in faces_by_client:
		assert(faces_by_client[client].size() == 1, "%s uses different portraits: %s" % [client, faces_by_client[client].keys()])
	for client in ["Anderdingus", "Mira Holloway", "Sleego", "Chrono Genesis", "Yuval", "Nemo", "Rango", "Elenia Valehart", "Kothar"]:
		assert(faces_by_client.has(client), "%s should appear with a portrait (%s)" % [client, faces_by_client.keys()])

	# 3. O balcão troca a expressão.
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	var feedback := desk.get_node("%Feedback") as AtelierDeskFeedback
	feedback.instant = true
	feedback.mute = true
	root.add_child(desk)
	await process_frame
	var window := desk.get_node("%Portrait") as TextureRect
	assert(window.size == Vector2(SIZE), "The portrait frame is %s" % window.size)

	# De ponta a ponta: o primeiro cliente do dia chega neutro e sorri no carimbo.
	desk.get_node("%OverlayButton").pressed.emit()
	desk.get_node("%BellButton").pressed.emit()
	var first: AtelierScrollOrder = desk.current_order
	assert(first.portrait != null, "Day 1 should open with a portrait customer (%s)" % first.client_name)
	assert(window.texture == first.portrait.neutral)
	desk.get_node("%ApproveButton").pressed.emit()
	assert(window.texture == first.portrait.texture_for(AtelierPortrait.Mood.HAPPY), "Approval should show the happy face")
	desk.get_node("%Workbench").get_node("%AbandonButton").pressed.emit()

	# Cada cliente com retrato, em cada humor; e a silhueta para quem não tem.
	var silhouettes := 0
	for day_path in DAYS:
		for slot in (load(day_path) as AtelierShopDay).orders:
			for order in AtelierShopDay.versions_of(slot):
				desk.current_order = order
				desk._show_client(order)
				if order.portrait == null:
					assert(window.texture == desk.generic_portrait and window.self_modulate == order.portrait_color, order.id)
					desk._say_reaction(order, false)
					assert(window.texture == desk.generic_portrait, "%s: the silhouette has no expressions" % order.id)
					silhouettes += 1
					continue
				var face := order.portrait
				assert(window.texture == face.neutral and window.self_modulate == Color.WHITE, order.id)
				desk._react_to_mistake({"patience": AtelierInspection.Patience.UNEASY, "penalty_due": false}, desk._verbatim(""))
				assert(window.texture == face.texture_for(AtelierPortrait.Mood.UNEASY), "%s: uneasy" % order.id)
				desk._react_to_mistake({"patience": AtelierInspection.Patience.EXASPERATED, "penalty_due": false}, desk._verbatim(""))
				assert(window.texture == face.texture_for(AtelierPortrait.Mood.UPSET), "%s: exasperated" % order.id)
				desk._say_reaction(order, true)
				assert(window.texture == face.texture_for(AtelierPortrait.Mood.HAPPY), "%s: approved" % order.id)
				desk._say_reaction(order, false)
				assert(window.texture == face.texture_for(AtelierPortrait.Mood.UPSET), "%s: refused" % order.id)
	assert(silhouettes > 0, "Some customers still use the generic silhouette")

	desk.queue_free()
	await process_frame
	print("PORTRAIT_SMOKE_OK (%d portraits)" % checked)
	quit(0)


func _check_pixel_art(texture: Texture2D, what: String) -> void:
	assert(texture != null, "%s is missing" % what)
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	assert(image.get_size() == SIZE, "%s is %s, not %s" % [what, image.get_size(), SIZE])
	var colors := {}
	var transparent := 0
	var bottom := 0
	for y in SIZE.y:
		for x in SIZE.x:
			var c := image.get_pixel(x, y)
			assert(c.a == 0.0 or c.a == 1.0, "%s has soft alpha at %d,%d" % [what, x, y])
			if c.a == 0.0:
				transparent += 1
				continue
			colors[c.to_rgba32()] = true
			if y == SIZE.y - 1:
				bottom += 1
	assert(colors.size() <= MAX_COLORS, "%s has %d colors (max %d)" % [what, colors.size(), MAX_COLORS])
	assert(transparent > SIZE.x * SIZE.y / 10, "%s has no background cut out" % what)
	assert(bottom >= 10, "%s does not rest on the counter (bottom row)" % what)
