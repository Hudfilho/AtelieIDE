extends SceneTree

## Balcão em pixel art: renderiza num SubViewport de 640x360 com filtro
## nearest, as fontes bitmap cobrem todo texto que o balcão pode mostrar e, para
## todo cliente de todos os dias, nada transborda nem fica coberto: pergaminho,
## livro aberto (cada regra na sua página, longe do vinco), balão de fala e a
## nota da inspeção cabem na tela; a marca de tinta cai inteira dentro da área
## do carimbo, sem cobrir nenhum campo; e as coisas clicáveis (campos, regras,
## carimbos, sino) não se sobrepõem, mesmo com os papéis encostados.
## Coleta todos os problemas e mostra de uma vez antes de falhar.

const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres", "res://data/days/day_03.tres"]
const STAGE := Rect2(0, 0, 640, 360)
## Livro aberto (book_spread.png): vinco no x 101 do sprite, sombra do vinco
## até 6 px de cada lado, e a moldura de baixo das páginas no y 186.
const BOOK_SEAM_X := 101.0
const BOOK_GUTTER := 6.0
const BOOK_PAGE_BOTTOM := 186.0

var problems: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		problems.append(message)


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	var feedback := desk.get_node("%Feedback") as AtelierDeskFeedback
	feedback.instant = true
	feedback.mute = true
	root.add_child(desk)
	await _frames()

	# Apresentação: viewport baixo, escala inteira (AtelierPixelFrame, ver
	# pixel_frame_smoke), filtro nearest; a bancada e os cartões do dia ficam
	# fora dele, em resolução cheia.
	var container := (desk.get_node("%PixelLayer") as AtelierPixelFrame).view
	var viewport := desk.get_node("%PixelViewport") as SubViewport
	assert(container != null and not container.stretch)
	assert(viewport.size == Vector2i(640, 360), str(viewport.size))
	assert(container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert(viewport.snap_2d_transforms_to_pixel)
	for name in ["%RequestForm", "%Rulebook", "%ApproveButton", "%RejectButton", "%BellButton", "%EvidenceLabel", "%InkMark", "%Portrait"]:
		assert(viewport.is_ancestor_of(desk.get_node(name)), "%s should live in the pixel viewport" % name)
	for name in ["%Workbench", "%Overlay"]:
		assert(not viewport.is_ancestor_of(desk.get_node(name)), "%s should stay at full resolution" % name)

	# Contraste dos rótulos dos carimbos (plaquinha de latão) e do sino (achado
	# do M6): legíveis ligados e desligados, e o desligado visivelmente mais apagado.
	var theme := load("res://art/pixel/pixel_theme.tres") as Theme
	var desk_wood := Color8(107, 69, 48)
	var wall := Color8(61, 38, 32)
	var plates := {"PixelStamp": ["plate", "plate_disabled"], "PixelBell": ["plate", "plate_disabled"]}
	for variation: String in plates:
		var under := desk_wood if variation == "PixelStamp" else wall
		var enabled_plate := theme.get_stylebox(plates[variation][0], variation) as StyleBoxFlat
		var disabled_plate := theme.get_stylebox(plates[variation][1], variation) as StyleBoxFlat
		var enabled := _contrast(theme.get_color("font_color", variation), under.blend(enabled_plate.bg_color))
		var disabled := _contrast(theme.get_color("font_disabled_color", variation), under.blend(disabled_plate.bg_color))
		_check(enabled >= 4.5, "%s enabled label contrast %.2f < 4.5" % [variation, enabled])
		_check(disabled >= 4.5, "%s disabled label contrast %.2f < 4.5" % [variation, disabled])
		_check(enabled >= disabled * 1.5, "%s disabled label is not distinguishable from enabled (%.2f vs %.2f)" % [variation, disabled, enabled])

	# Fontes: todo caractere que o balcão pode mostrar existe na fonte bitmap
	# que o mostra (normal, grande da marca, título e versaletes miúdos).
	var small_font := load("res://art/pixel/pixel_font.fnt") as FontFile
	var big_font := load("res://art/pixel/pixel_font_big.fnt") as FontFile
	var title_font := load("res://art/pixel/pixel_font_title.fnt") as FontFile
	var tiny_font := load("res://art/pixel/pixel_font_tiny.fnt") as FontFile
	var small_text := PackedStringArray()
	var big_text := PackedStringArray()
	var title_text := PackedStringArray()
	var tiny_text := PackedStringArray(["0123456789"])
	for row in _table_rows():
		if row[0].begins_with("DESK_") or row[0].begins_with("FIELD_") or row[0].begins_with("INSPECT_"):
			small_text.append_array([row[1], row[2]])
		if row[0].begins_with("DESK_INK_"):
			big_text.append_array([row[1], row[2]])
		if row[0] in ["DESK_REQUIRED_EFFECT", "DESK_RULEBOOK_TITLE", "FIELD_DETAILS", "DESK_WINDOW_EMPTY"]:
			tiny_text.append_array([row[1], row[2]])
		if row[0] == "DESK_WINDOW_EMPTY":
			title_text.append_array([row[1], row[2]])
	for day_path in DAYS:
		var day := load(day_path) as AtelierShopDay
		small_text.append(day.title)
		for rule in day.rules:
			small_text.append_array([rule.text, rule.title])
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				small_text.append_array([order.client_name, order.age, order.race, order.signature, order.item, order.details,
						order.spec, order.greeting, order.reaction_approved, order.reaction_refused])
				title_text.append_array([order.item, order.client_name])
	_check_font(small_font, small_text, "pixel_font")
	_check_font(big_font, big_text, "pixel_font_big")
	_check_font(title_font, title_text, "pixel_font_title")
	_check_font(tiny_font, tiny_text, "pixel_font_tiny")

	# Layout de cada cliente, em cada dia.
	var form := desk.get_node("%RequestForm") as Control
	var stamp_box := desk.get_node("%StampBox") as Control
	var ink := desk.get_node("%InkMark") as Control
	var text_rows: Array[Control] = [desk.get_node("%ItemField"), desk.get_node("%NameField"), desk.get_node("%AgeField"),
			desk.get_node("%RaceField"), desk.get_node("%SignatureField"), desk.get_node("%DetailsField"), desk.get_node("%SpecLabel")]
	var bubble := desk.get_node("%Speech").get_parent().get_parent() as Control
	var bell := desk.get_node("%BellButton") as Control
	var rulebook := desk.get_node("%Rulebook") as Control
	var pages: Array[Control] = [desk.get_node("%LeftPage"), desk.get_node("%RightPage")]
	var stamps: Array[Control] = [desk.get_node("%ApproveButton"), desk.get_node("%RejectButton")]
	var feedback_card := desk.get_node("%InspectionNote") as Control
	var feedback_label := desk.get_node("%FeedbackLabel") as Control
	var checked := 0
	for day_index in DAYS.size():
		game_state.day_index = day_index
		var day: AtelierShopDay = game_state.current_day()
		desk._build_rulebook(day)
		await _frames()
		# Livro aberto: cada página fica do seu lado do vinco e acima do pé da
		# página; nenhuma regra fica embaixo do pedido (que encosta no livro).
		var book := rulebook.get_global_rect()
		var seam_x := book.position.x + BOOK_SEAM_X
		_check(pages[0].get_global_rect().end.x <= seam_x - BOOK_GUTTER, "day %d: left page runs into the seam" % (day_index + 1))
		_check(pages[1].get_global_rect().position.x >= seam_x + BOOK_GUTTER, "day %d: right page runs into the seam" % (day_index + 1))
		for page in pages:
			_check(page.get_global_rect().end.y <= book.position.y + BOOK_PAGE_BOTTOM, "day %d: %s runs past the page (%s)" % [day_index + 1, page.name, page.get_global_rect()])
		for rule in day.rules:
			_check(not desk.rule_button(rule.id).get_global_rect().intersects(form.get_global_rect()), "day %d: the request covers rule %s" % [day_index + 1, rule.id])
		desk.phase = desk.Phase.SERVING
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				var where := "%s (day %d)" % [order.id, day_index + 1]
				desk.current_order = order
				desk._show_client(order)
				await _frames()
				_check(STAGE.encloses(form.get_global_rect()), "%s: request form leaves the screen %s" % [where, form.get_global_rect()])
				_check(STAGE.encloses(rulebook.get_global_rect()), "%s: rulebook leaves the screen" % where)
				# Coisas clicáveis não se sobrepõem: pedido, carimbos, sino e a nota.
				var solids: Dictionary[String, Rect2] = {"request": form.get_global_rect(), "bell": bell.get_global_rect(),
						"note": feedback_card.get_global_rect(), "approve": stamps[0].get_global_rect(), "reject": stamps[1].get_global_rect()}
				var names := solids.keys()
				for i in names.size():
					for j in range(i + 1, names.size()):
						_check(not solids[names[i]].intersects(solids[names[j]]), "%s: %s overlaps %s" % [where, names[i], names[j]])
				for kind in [AtelierDeskFeedback.APPROVE, AtelierDeskFeedback.REJECT]:
					feedback.show_ink(kind)
					await _frames(2)
					var ink_rect := ink.get_global_rect()
					_check(stamp_box.get_global_rect().grow(1).encloses(ink_rect), "%s: %s mark %s spills out of the stamp box %s" % [where, kind, ink_rect, stamp_box.get_global_rect()])
					for row in text_rows:
						_check(not row.get_global_rect().intersects(ink_rect), "%s: %s mark covers %s" % [where, kind, row.name])
				for line in [order.greeting, order.reaction_approved, order.reaction_refused, desk.tr("DESK_PATIENCE_UPSET")]:
					desk.speech_label.text = "\"%s\"" % line
					await _frames(2)
					_check(bubble.get_global_rect().end.y <= bell.get_global_rect().position.y, "%s: speech bubble covers the bell with: %s" % [where, line])
				checked += 1

	# Notas nos dois estados reais. Atendendo: o máximo de provas mais a mensagem
	# de inspeção mais longa (com penalidade). Depois que o cliente sai: sem
	# provas e a mensagem de saída mais longa com o aviso do sino.
	var worst_order: AtelierScrollOrder
	var worst_day := 0
	var worst_count := -1
	for day_index in DAYS.size():
		var day := load(DAYS[day_index]) as AtelierShopDay
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				if day.violated_rules(order).size() > worst_count:
					worst_count = day.violated_rules(order).size()
					worst_order = order
					worst_day = day_index
	game_state.day_index = worst_day
	desk._build_rulebook(game_state.current_day())
	desk.current_order = worst_order
	desk._show_client(worst_order)
	for found in AtelierInspection.discrepancies(worst_order, game_state.current_day().rules):
		desk.inspection.link(found["field"], found["rule"])
	desk.inspection.link("age", game_state.current_day().rules[0])
	var worst_link: Dictionary = desk.inspection.link("details", game_state.current_day().rules[0])
	desk._refresh_inspection_marks()
	desk._say_feedback(str(worst_link["message"]) + "\n" + desk.tr("DESK_PATIENCE_PENALTY") % [1])
	await _frames()
	_check(STAGE.encloses(feedback_card.get_global_rect()), "serving: notes leave the screen %s" % feedback_card.get_global_rect())
	_check(feedback_card.get_global_rect().encloses(feedback_label.get_global_rect()), "serving: feedback text does not fit its note")
	desk._clear_counter()
	var longest := ""
	for key in ["DESK_REFUSED_NO_CAUSE", "DESK_REFUSED_HONEST", "DESK_DELIVERED_ILLEGAL", "DESK_ABANDONED"]:
		var message: String = desk.tr(key)
		if message.length() > longest.length():
			longest = message
	desk._say_feedback(longest.replace("%s", "Anderdingus").replace("%d", "1") + "\n" + desk.tr("DESK_RING_CLOSE"))
	await _frames()
	_check(STAGE.encloses(feedback_card.get_global_rect()), "after leaving: notes leave the screen %s" % feedback_card.get_global_rect())
	_check(feedback_card.get_global_rect().encloses(feedback_label.get_global_rect()), "after leaving: feedback text does not fit its note")

	# Dicas de uso somem da nota sozinhas; resultados e avisos ficam.
	desk.hint_fade_delay = 0.05
	var note_text := desk.get_node("%FeedbackLabel") as Label
	desk._say_hint(desk.tr("DESK_PICK_RULE"))
	await create_timer(0.1 + desk.HINT_FADE_TIME).timeout
	_check(note_text.modulate.a == 0.0, "A usage hint should fade out of the note (alpha %.2f)" % note_text.modulate.a)
	desk._say_hint(desk.tr("DESK_PICK_FIELD"))
	desk._say_feedback(desk.tr("DESK_PATIENCE_PENALTY") % [1])
	await create_timer(0.1 + desk.HINT_FADE_TIME).timeout
	_check(note_text.modulate.a == 1.0, "A warning must stay in the note (alpha %.2f)" % note_text.modulate.a)

	desk.queue_free()
	await process_frame
	if not problems.is_empty():
		print("PIXEL DESK LAYOUT PROBLEMS (%d):\n- %s" % [problems.size(), "\n- ".join(problems)])
	assert(problems.is_empty(), "%d layout problems, see above" % problems.size())
	print("PIXEL_DESK_SMOKE_OK (%d customer versions, locale %s)" % [checked, TranslationServer.get_locale()])
	quit(0)


## Razão de contraste WCAG 2.x entre duas cores opacas.
static func _contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance()
	var lb := b.srgb_to_linear().get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _check_font(font: FontFile, texts: PackedStringArray, font_name: String) -> void:
	var missing := {}
	for text in texts:
		for index in text.length():
			var code := text.unicode_at(index)
			if code >= 32 and not font.has_char(code):
				missing[String.chr(code)] = true
	_check(missing.is_empty(), "%s is missing glyphs: %s" % [font_name, " ".join(PackedStringArray(missing.keys()))])


func _table_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			rows.append(row)
	return rows
