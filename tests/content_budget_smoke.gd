extends SceneTree

## Orçamento de texto do balcão (AtelierContentBudget): as contagens de linha
## batem com o que a cena desenha, todo o conteúdo atual cabe em todos os
## idiomas carregados e conteúdo grande demais é reprovado.

const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres", "res://data/days/day_03.tres"]


func _initialize() -> void:
	call_deferred("_run")


func _frames(count := 3) -> void:
	for frame in count:
		await process_frame


func _run() -> void:
	# 1. A medição do orçamento é a mesma do desenho do balcão.
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	(desk.get_node("%Feedback") as AtelierDeskFeedback).mute = true
	root.add_child(desk)
	await _frames()
	var item_field := desk.get_node("%ItemField") as Button
	var details_field := desk.get_node("%DetailsField") as Button
	var spec_label := desk.get_node("%SpecLabel") as Label
	var speech_label := desk.get_node("%Speech") as Label
	var pages: Array[Control] = [desk.get_node("%LeftPage"), desk.get_node("%RightPage")]
	var form_room: float = (desk.get_node("%RequestForm") as Control).size.x - 22.0
	assert(is_equal_approx(AtelierContentBudget.TITLE_WIDTH + 4.0, form_room), "Title width %s does not match the request (%s)" % [AtelierContentBudget.TITLE_WIDTH, form_room])
	var compared := 0
	for day_index in DAYS.size():
		game_state.day_index = day_index
		var day: AtelierShopDay = game_state.current_day()
		desk._build_rulebook(day)
		await _frames()
		var split := AtelierContentBudget.rule_pages(day.rules)
		for rule in day.rules:
			var rule_button: Button = desk.rule_button(rule.id)
			var rule_lines := int(rule_button.get_combined_minimum_size().y) / AtelierContentBudget.LINE_HEIGHT
			assert(rule_lines == AtelierContentBudget.rendered_lines(rule_button.text, AtelierContentBudget.RULE_WIDTH), "%s: rule lines differ" % rule_button.name)
			var page_index := 0 if split[0].has(rule) else 1
			assert(pages[page_index].is_ancestor_of(rule_button), "%s is on the wrong page" % rule.id)
		for index in pages.size():
			var drawn := pages[index].get_combined_minimum_size().y
			var measured := AtelierContentBudget.page_height(split[index], "")
			assert(is_equal_approx(drawn, measured), "%s page %d: height differs: %s vs %s" % [day.title, index + 1, drawn, measured])
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				desk.current_order = order
				desk._show_client(order)
				await _frames()
				var fits_title := AtelierContentBudget.rendered_lines(order.item, AtelierContentBudget.TITLE_WIDTH, AtelierContentBudget.TITLE_FONT_PATH, AtelierContentBudget.TITLE_FONT_SIZE) == 1
				assert(fits_title == (item_field.get_combined_minimum_size().x <= form_room), "%s: title verdict differs from the drawn width %s" % [order.id, item_field.get_combined_minimum_size().x])
				var shown_details := int(details_field.get_combined_minimum_size().y) / AtelierContentBudget.LINE_HEIGHT
				assert(shown_details == AtelierContentBudget.rendered_lines(details_field.text, AtelierContentBudget.DETAILS_WIDTH), "%s: details lines differ (%d shown)" % [order.id, shown_details])
				assert(spec_label.get_line_count() == AtelierContentBudget.rendered_lines(spec_label.text, AtelierContentBudget.SPEC_WIDTH), "%s: spec lines differ" % order.id)
				speech_label.text = "\"%s\"" % order.greeting
				await _frames(2)
				assert(speech_label.get_line_count() == AtelierContentBudget.rendered_lines(speech_label.text, AtelierContentBudget.SPEECH_WIDTH), "%s: speech lines differ" % order.id)
				compared += 1
	desk.queue_free()
	await process_frame

	# 2. Todo o conteúdo atual cabe no orçamento, em todos os idiomas carregados.
	var problems: PackedStringArray = []
	for day_path in DAYS:
		problems.append_array(AtelierContentBudget.check_day(load(day_path) as AtelierShopDay))
	if not problems.is_empty():
		print("CONTENT OVER BUDGET (%d):\n- %s" % [problems.size(), "\n- ".join(problems)])
	assert(problems.is_empty(), "%d content problems, see above" % problems.size())

	# 3. Conteúdo grande demais é reprovado (e nada tenta encolher para caber).
	var long_sentence := "The villagers keep arguing about the well, the mill, the bridge and the price of bread every single night. "
	var oversized := AtelierScrollOrder.new()
	oversized.id = "oversized"
	oversized.item = "Scroll of the Exceedingly Long and Wordy Title"
	oversized.details = long_sentence + long_sentence
	oversized.spec = long_sentence
	oversized.greeting = long_sentence + long_sentence
	var order_problems := "\n".join(AtelierContentBudget.check_order(oversized))
	assert("title takes" in order_problems, order_problems)
	assert("details has" in order_problems and "characters" in order_problems, order_problems)
	assert("details takes" in order_problems, order_problems)
	assert("scroll requirement takes" in order_problems, order_problems)
	assert("speech takes" in order_problems, order_problems)
	var tidy := AtelierScrollOrder.new()
	tidy.id = "tidy"
	tidy.item = "Scroll of Light"
	tidy.details = "A short request."
	tidy.spec = "Print 3."
	tidy.greeting = "Hello!"
	assert(AtelierContentBudget.check_order(tidy).is_empty(), "\n".join(AtelierContentBudget.check_order(tidy)))

	var four_rules := AtelierShopDay.new()
	four_rules.title = "Too many rules"
	for index in 4:
		var rule := AtelierShopRule.new()
		rule.text = "Rule %d." % index
		four_rules.rules.append(rule)
	assert("at most 3" in "\n".join(AtelierContentBudget.check_day(four_rules)), "\n".join(AtelierContentBudget.check_day(four_rules)))

	var wordy_rules := AtelierShopDay.new()
	wordy_rules.title = "Wordy rules"
	for index in 3:
		var rule := AtelierShopRule.new()
		rule.text = long_sentence + long_sentence
		wordy_rules.rules.append(rule)
	var wordy := "\n".join(AtelierContentBudget.check_day(wordy_rules))
	assert("rulebook page 1" in wordy and "rulebook page 2" in wordy and not "at most 3" in wordy, wordy)

	# Uma regra comprida só na página direita também é pega.
	var heavy_right := AtelierShopDay.new()
	heavy_right.title = "Heavy right page"
	for text in ["Short rule.", long_sentence + long_sentence + long_sentence]:
		var rule := AtelierShopRule.new()
		rule.text = text
		heavy_right.rules.append(rule)
	var heavy := "\n".join(AtelierContentBudget.check_day(heavy_right))
	assert("rulebook page 2" in heavy and not "rulebook page 1" in heavy, heavy)

	print("CONTENT_BUDGET_SMOKE_OK (%d customer versions measured)" % compared)
	quit(0)
