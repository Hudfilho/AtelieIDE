extends SceneTree

## Balcão em pixel art: renderiza num SubViewport de 640x360 com filtro
## nearest, a fonte bitmap cobre todo texto que o balcão pode mostrar e, para
## todo cliente de todos os dias, nada transborda nem fica coberto: pergaminho,
## livro de regras, balão de fala e notas cabem na tela, e a marca de tinta cai
## inteira dentro da área do carimbo, sem cobrir nenhum campo.
## Coleta todos os problemas e mostra de uma vez antes de falhar.

const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres", "res://data/days/day_03.tres"]
const STAGE := Rect2(0, 0, 640, 360)

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

	# Apresentação: viewport baixo, escala inteira, filtro nearest; a bancada e
	# os cartões do dia ficam fora dele, em resolução cheia.
	var container := desk.get_node("PixelView") as SubViewportContainer
	var viewport := desk.get_node("%PixelViewport") as SubViewport
	assert(container.stretch and container.stretch_shrink == 2)
	assert(viewport.size == Vector2i(640, 360), str(viewport.size))
	assert(container.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
	assert(viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert(viewport.snap_2d_transforms_to_pixel)
	for name in ["%RequestForm", "%Rulebook", "%ApproveButton", "%RejectButton", "%BellButton", "%EvidenceLabel", "%InkMark", "%Portrait"]:
		assert(viewport.is_ancestor_of(desk.get_node(name)), "%s should live in the pixel viewport" % name)
	for name in ["%Workbench", "%Overlay"]:
		assert(not viewport.is_ancestor_of(desk.get_node(name)), "%s should stay at full resolution" % name)

	# Fonte: todo caractere que o balcão pode mostrar existe na fonte bitmap.
	var small_font := load("res://art/pixel/pixel_font.fnt") as FontFile
	var big_font := load("res://art/pixel/pixel_font_big.fnt") as FontFile
	var small_text := PackedStringArray()
	var big_text := PackedStringArray()
	for row in _table_rows():
		if row[0].begins_with("DESK_") or row[0].begins_with("FIELD_") or row[0].begins_with("INSPECT_"):
			small_text.append_array([row[1], row[2]])
		if row[0].begins_with("DESK_INK_"):
			big_text.append_array([row[1], row[2]])
	for day_path in DAYS:
		var day := load(day_path) as AtelierShopDay
		small_text.append(day.title)
		for rule in day.rules:
			small_text.append_array([rule.text, rule.title])
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				small_text.append_array([order.client_name, order.age, order.race, order.signature, order.item, order.details,
						order.spec, order.greeting, order.reaction_approved, order.reaction_refused])
				big_text.append(order.item)
	_check_font(small_font, small_text, "pixel_font")
	_check_font(big_font, big_text, "pixel_font_big")

	# Layout de cada cliente, em cada dia.
	var form := desk.get_node("%RequestForm") as Control
	var stamp_box := desk.get_node("%StampBox") as Control
	var ink := desk.get_node("%InkMark") as Control
	var text_rows: Array[Control] = [desk.get_node("%ItemField"), desk.get_node("%NameField"), desk.get_node("%AgeField"),
			desk.get_node("%RaceField"), desk.get_node("%SignatureField"), desk.get_node("%DetailsField"), desk.get_node("%SpecLabel")]
	var bubble := desk.get_node("%Speech").get_parent().get_parent() as Control
	var bell := desk.get_node("%BellButton") as Control
	var feedback_card := desk.get_node("%FeedbackCard") as Control
	var feedback_label := desk.get_node("%FeedbackLabel") as Control
	var checked := 0
	for day_index in DAYS.size():
		game_state.day_index = day_index
		var day: AtelierShopDay = game_state.current_day()
		desk._build_rulebook(day)
		desk.phase = desk.Phase.SERVING
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				var where := "%s (day %d)" % [order.id, day_index + 1]
				desk.current_order = order
				desk._show_client(order)
				await _frames()
				_check(STAGE.encloses(form.get_global_rect()), "%s: request form leaves the screen %s" % [where, form.get_global_rect()])
				_check(STAGE.encloses(desk.get_node("%Rulebook").get_global_rect()), "%s: rulebook leaves the screen" % where)
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

	desk.queue_free()
	await process_frame
	if not problems.is_empty():
		print("PIXEL DESK LAYOUT PROBLEMS (%d):\n- %s" % [problems.size(), "\n- ".join(problems)])
	assert(problems.is_empty(), "%d layout problems, see above" % problems.size())
	print("PIXEL_DESK_SMOKE_OK (%d customer versions, locale %s)" % [checked, TranslationServer.get_locale()])
	quit(0)


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
