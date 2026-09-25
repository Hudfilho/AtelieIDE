extends SceneTree

## Estilos de arte do balcão (AtelierDeskStyle): todo estilo traz todas as
## texturas, nos tamanhos que o layout espera (os papéis e as peças são do
## mesmo tamanho em todos os estilos, então o orçamento de texto e os testes
## de layout valem para todos); aplicar um estilo troca a arte sem mexer no
## layout; o retrato e a vela ficam na janela do fundo; e a escolha feita na
## tela de título fica salva.

const STAGE := Rect2(0, 0, 640, 360)
## Tamanho de cada textura que precisa ser exato (o resto só precisa existir).
const EXACT_SIZES := {
	"backdrop": Vector2(640, 360), "rulebook": Vector2(202, 212), "request": Vector2(244, 212),
	"note": Vector2(188, 122), "day_card": Vector2(88, 123), "stamp_tray": Vector2(139, 60),
}
const TEXTURES: Array[String] = ["backdrop", "candle", "rulebook", "request", "note", "day_card", "bell", "bell_lift",
		"stamp_approve", "stamp_approve_lift", "stamp_approve_head", "stamp_reject", "stamp_reject_lift", "stamp_reject_head", "stamp_tray"]
const TEST_SETTINGS := "user://desk_style_smoke_settings.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	AtelierDeskStyles.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	var styles := AtelierDeskStyles.all()
	assert(styles.size() >= 2, "Expected at least two desk styles")
	var ids := {}

	# 1. Cada estilo tem todas as texturas, nos tamanhos do layout.
	for style in styles:
		assert(not style.id.is_empty() and not ids.has(style.id), "Style ids must be unique: %s" % style.id)
		ids[style.id] = true
		assert(TranslationServer.translate(style.title_key) != style.title_key, "%s has no translated name" % style.id)
		for field in TEXTURES:
			var texture := style.get(field) as Texture2D
			assert(texture != null, "%s is missing %s" % [style.id, field])
			if EXACT_SIZES.has(field):
				assert(texture.get_size() == EXACT_SIZES[field], "%s %s is %s, expected %s" % [style.id, field, texture.get_size(), EXACT_SIZES[field]])
		for kind in ["approve", "reject"]:
			var rest := style.get("stamp_%s" % kind) as Texture2D
			var lift := style.get("stamp_%s_lift" % kind) as Texture2D
			var head := style.get("stamp_%s_head" % kind) as Texture2D
			assert(rest.get_size() == lift.get_size(), "%s %s stamp: rest and lifted sprites differ in size" % [style.id, kind])
			assert(rest.get_height() == head.get_height() + AtelierDeskStamp.HEAD_TOP, "%s %s stamp: the head does not match the resting sprite" % [style.id, kind])

	# 2. Sem escolha salva, vale o primeiro; a escolha salva vale depois.
	assert(AtelierDeskStyles.preferred() == styles[0], "Without a saved choice the first style is used")
	AtelierDeskStyles.remember(styles[1])
	assert(AtelierDeskStyles.preferred().id == styles[1].id, "The chosen style is remembered")

	# 3. A tela de título lista os estilos e salva a escolha.
	var title = load("res://scenes/game/Title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	var option := title.get_node("%StyleOption") as OptionButton
	assert(option.item_count == styles.size())
	assert(option.selected == 1, "The title shows the remembered style")
	option.select(0)
	option.item_selected.emit(0)
	assert(AtelierDeskStyles.preferred().id == styles[0].id, "Picking a style on the title saves it")
	title.queue_free()
	await process_frame

	# 4. O balcão abre no estilo salvo, e aplicar outro troca só a arte.
	AtelierDeskStyles.remember(styles[1])
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	(desk.get_node("%Feedback") as AtelierDeskFeedback).mute = true
	root.add_child(desk)
	await _frames()
	assert(desk.desk_style.id == styles[1].id, "The desk opens in the remembered style")
	var watched: Array[String] = ["%RequestForm", "%Rulebook", "%InspectionNote", "%ApproveButton", "%RejectButton", "%BellButton", "%DayCard", "%StampTray"]
	var layout := {}
	for style in styles:
		desk.apply_style(style)
		await _frames()
		for path in watched:
			var rect := (desk.get_node(path) as Control).get_global_rect()
			if layout.has(path):
				assert(rect == layout[path], "%s moves between styles (%s vs %s)" % [path, rect, layout[path]])
			layout[path] = rect
		assert((desk.get_node("%Backdrop") as TextureRect).texture == style.backdrop)
		assert((desk.get_node("%DayCard") as TextureRect).texture == style.day_card)
		assert((desk.get_node("%StampTray") as TextureRect).texture == style.stamp_tray)
		assert((desk.get_node("%ApproveButton") as AtelierDeskStamp).rest_texture == style.stamp_approve)
		assert((desk.get_node("%RejectButton") as AtelierDeskStamp).lifted_texture == style.stamp_reject_lift)
		assert((desk.get_node("%BellButton") as AtelierDeskStamp).rest_texture == style.bell)
		var feedback := desk.get_node("%Feedback") as AtelierDeskFeedback
		assert(feedback.stamp_sprites[AtelierDeskFeedback.APPROVE] == style.stamp_approve_head)
		var papers := {"%Rulebook": style.rulebook, "%RequestForm": style.request, "%InspectionNote": style.note}
		for paper_path: String in papers:
			var paper := desk.get_node(paper_path) as Control
			var box := paper.get_theme_stylebox(&"panel") as StyleBoxTexture
			assert(box.texture == papers[paper_path], "%s %s does not show the style's paper" % [style.id, paper_path])
			assert(box.texture.get_size() == paper.size, "%s %s texture %s does not match the paper %s" % [style.id, paper_path, box.texture.get_size(), paper.size])
		# O papel troca de textura, mas o texto fica no mesmo lugar.
		var margins := (desk.get_node("%RequestForm") as Control).get_theme_stylebox(&"panel").get_margin(SIDE_LEFT)
		assert(margins == (load("res://art/pixel/pixel_theme.tres") as Theme).get_stylebox(&"panel", &"Paper").get_margin(SIDE_LEFT))
		# Retrato e vela na janela pintada, dentro da tela e sem cobrir o sino.
		var portrait := desk.get_node("%Portrait") as Control
		var candle := desk.get_node("%Candle") as Control
		var bell := desk.get_node("%BellButton") as Control
		assert(portrait.get_global_rect().position == style.portrait_position, "%s portrait at %s" % [style.id, portrait.get_global_rect().position])
		assert(candle.position == style.candle_position)
		for piece in [portrait, candle]:
			assert(STAGE.encloses(piece.get_global_rect()), "%s: %s leaves the screen" % [style.id, piece.name])
		assert(not candle.get_global_rect().intersects(bell.get_global_rect()), "%s: the candle covers the bell" % style.id)
		assert(not candle.get_global_rect().intersects(portrait.get_global_rect()), "%s: the candle covers the customer" % style.id)
	desk.queue_free()
	await process_frame

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("DESK_STYLE_SMOKE_OK (%d styles)" % styles.size())
	quit(0)
