extends SceneTree

## Joga o demo inteiro pelo balcão: recusa e aprova pedidos, escreve pergaminhos
## na bancada e confere dinheiro, reputação e o jornal do dia seguinte.

const SpellJudgeSmoke = preload("res://tests/spell_judge_smoke.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk := load("res://scenes/game/Desk.tscn").instantiate() as Control
	# Carimbo, tremida e pausas acontecem na hora: o teste não depende de animação.
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	root.add_child(desk)
	await process_frame

	var overlay := desk.get_node("%Overlay") as Control
	var bell := desk.get_node("%BellButton") as Button
	var approve := desk.get_node("%ApproveButton") as Button
	var reject := desk.get_node("%RejectButton") as Button
	var workbench = desk.get_node("%Workbench")
	var feedback := desk.get_node("%FeedbackLabel") as Label
	assert(overlay.visible, "Day intro should open the day")
	assert(bell.disabled)
	desk.get_node("%OverlayButton").pressed.emit()
	assert(not overlay.visible)
	assert(not bell.disabled and approve.disabled)

	# Dia 1, cliente 1 (Mira): aprovar abre a bancada só com as runas do dia.
	bell.pressed.emit()
	assert(not approve.disabled)
	assert(_item(desk) == "Scroll of Warm Light")
	approve.pressed.emit()
	await process_frame
	assert(workbench.visible)
	var canvas = workbench.get_node("%Canvas")
	assert(canvas.palette_symbols.size() == 5, "Day 1 bench should show 5 runes")
	assert(canvas.get_node_or_null("FileToolbar") == null, "Game mode hides the IDE file bar")

	# Mira começa com o rascunho do mestre: forte demais.
	assert(canvas.connections.size() == 2, "Mira's order starts with a draft")
	var draft_center: Vector2 = canvas.call("_world_to_screen", Vector2(48.0, 0.0))
	var drawing_area: Rect2 = canvas.call("_canvas_rect")
	assert(drawing_area.grow(-60.0).has_point(draft_center), "The draft should be framed inside the drawing area")
	assert((workbench.get_node("%ResetButton") as Button).text == tr("BENCH_RESET_DRAFT"))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(workbench.visible)
	assert(tr("JUDGE_MISMATCH") % ["3", "128"] in (workbench.get_node("%ResultLabel") as Label).text)

	# Pergaminho errado: fica na bancada e explica a falha.
	canvas.load_connections(SpellJudgeSmoke._program([["ORB", 4], ["TRIANGLE", 128], ["CROSS", 128]]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(workbench.visible)
	assert(tr("JUDGE_MISMATCH") % ["3", "4"] in (workbench.get_node("%ResultLabel") as Label).text)

	# Reiniciar volta ao rascunho, e Ctrl+Z desfaz o reinício.
	workbench.get_node("%ResetButton").pressed.emit()
	assert(canvas.connections.size() == 2)
	canvas.call("_undo")
	assert(canvas.connections.size() == 3, "Reset should be undoable")
	canvas.load_connections(SpellJudgeSmoke._program(SpellJudgeSmoke.SOLUTIONS["mira_warm_light"]))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(not workbench.visible)
	assert(game_state.money == 20 + 8 + 5, "Reward plus elegant bonus")

	# Cliente 2 (goblin do Fireball): inspeção antes de recusar.
	bell.pressed.emit()
	assert(_item(desk) == "Fireball")
	var evidence_label := desk.get_node("%EvidenceLabel") as Label
	assert(evidence_label.text == tr("DESK_NO_EVIDENCE"))
	# Ligação errada: contradição, sem prova.
	desk.get_node("%RaceField").pressed.emit()
	_rule_button(desk, "signature").pressed.emit()
	assert(desk.inspection.evidence.is_empty() and desk.inspection.mistakes == 1)
	assert(feedback.text == tr("INSPECT_NO_CONTRADICTION") % [tr("FIELD_RACE"), "Goblin", "Matching signature"], feedback.text)
	# Regra primeiro, campo depois: também vale; vira prova marcada em tinta.
	_rule_button(desk, "signature").pressed.emit()
	assert(_rule_button(desk, "signature").button_pressed, "The chosen rule stays selected")
	desk.get_node("%SignatureField").pressed.emit()
	assert(desk.inspection.evidence.size() == 1 and desk.inspection.mistakes == 1, "A correct link adds evidence, not a mistake")
	assert((desk.get_node("%SignatureField") as Button).text.begins_with("»"))
	assert(_rule_button(desk, "signature").text.begins_with("»"))
	assert(not (desk.get_node("%SignatureField") as Button).button_pressed, "Selection clears after a link")
	assert("- %s: %s" % ["Matching signature", tr("FIELD_SIGNATURE")] in evidence_label.text, evidence_label.text)
	reject.pressed.emit()
	assert(game_state.reputation == 5 + 1 + 1, "A cited rejection is a correct rejection")
	assert(game_state.outcomes["anderdingus_fireball"] == "rejected")
	assert(feedback.text.begins_with(tr("DESK_REFUSED_EVIDENCE") % ["Matching signature"]), feedback.text)
	assert(evidence_label.text.is_empty())

	# Cliente 3 (Tomas): a bancada mostra só o exemplo; desistir custa reputação.
	bell.pressed.emit()
	approve.pressed.emit()
	assert(canvas.connections.is_empty())
	var cases_text := (workbench.get_node("%CasesLabel") as Label).text
	var bench_judge = workbench.judge
	assert(bench_judge.describe_memory({0: 5}) in cases_text and tr("BENCH_HIDDEN_MANY") % [2] in cases_text, cases_text)
	assert(not bench_judge.describe_memory({0: 20}) in cases_text, "Hidden inputs must not be shown")
	assert(canvas.run_memory == {0: 5})
	workbench.get_node("%AbandonButton").pressed.emit()
	assert(not workbench.visible)
	assert(game_state.reputation == 6)

	# Cliente 4 (Rango): duas entradas somadas; o pedido é honesto.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of Snack Time")
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["rango_snack_time"])
	assert(game_state.outcomes["rango_snack_time"] == "delivered")

	# Cliente 5 (Kothar): o nome parece inofensivo, mas os detalhes pedem um
	# choque na maçaneta do vizinho. A prova está nos detalhes.
	bell.pressed.emit()
	assert(_item(desk) == "Doorbell Charm")
	desk.get_node("%DetailsField").pressed.emit()
	_rule_button(desk, "offensive_license").pressed.emit()
	assert(desk.inspection.evidence.size() == 1 and desk.inspection.mistakes == 0, "The details prove the offensive intent")
	var reputation_before_kothar: int = game_state.reputation
	reject.pressed.emit()
	assert(game_state.outcomes["kothar_doorbell_charm"] == "rejected")
	assert(game_state.reputation == reputation_before_kothar + 1, "A cited rejection is a correct rejection")

	# Fim do dia 1 → livro-caixa → dia 2.
	bell.pressed.emit()
	assert(overlay.visible)
	assert(desk.phase == desk.Phase.DAY_END)
	desk.get_node("%OverlayButton").pressed.emit()
	assert(game_state.day_index == 1)
	assert("Embargo" in (desk.get_node("%OverlayTitle") as Label).text)
	desk.get_node("%OverlayButton").pressed.emit()

	# Dia 2: entregar o pedido élfico ilegal agenda a notícia de amanhã.
	bell.pressed.emit() # Pip
	reject.pressed.emit()
	bell.pressed.emit() # Faelar (embargo)
	approve.pressed.emit()
	assert(canvas.palette_symbols.size() == 12)
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["faelar_quiet_growth"])
	assert(game_state.scheduled.size() == 1)
	bell.pressed.emit() # Brom: assinatura "Bronn" não bate, mas recusado sem prova.
	var reputation_before_brom: int = game_state.reputation
	reject.pressed.emit()
	assert(game_state.reputation == reputation_before_brom - 1)
	assert(feedback.text.begins_with(tr("DESK_REFUSED_NO_CAUSE")), feedback.text)
	bell.pressed.emit() # Oona
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["oona_vesper_bell"])
	assert(not workbench.visible, "The countdown loop should pass on the real bench")
	# Sleego: a armadura assusta, mas o pedido é honesto; atender paga.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of Gentle Rain")
	assert(AtelierInspection.discrepancies(desk.current_order, desk._day().rules).is_empty(), "Sleego's form is clean")
	var money_before_sleego: int = game_state.money
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["sleego_gentle_rain"])
	assert(not workbench.visible and game_state.outcomes["sleego_gentle_rain"] == "delivered")
	assert(game_state.money > money_before_sleego, "Sleego pays for the rain")
	# Nemo: ferroar piratas é magia ofensiva; recusar com prova vale reputação.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of the Stinging Tide")
	desk.get_node("%ItemField").pressed.emit()
	_rule_button(desk, "offensive_license").pressed.emit()
	assert(desk.inspection.evidence.size() == 1)
	var reputation_before_nemo: int = game_state.reputation
	reject.pressed.emit()
	assert(game_state.outcomes["nemo_stinging_tide"] == "rejected")
	assert(game_state.reputation == reputation_before_nemo + 1, "A cited rejection is a correct rejection")

	# Fim do dia 2 → manhã do dia 3 traz o jornal, a multa e a suspeita.
	bell.pressed.emit()
	assert(desk.phase == desk.Phase.DAY_END)
	var money_before_morning: int = game_state.money
	desk.get_node("%OverlayButton").pressed.emit()
	assert("Inspection" in (desk.get_node("%OverlayTitle") as Label).text)
	assert("CROWN FINES" in (desk.get_node("%OverlayBody") as RichTextLabel).text)
	assert(game_state.money == money_before_morning - 25)
	assert(game_state.flag("guild_suspicion") == 1)
	desk.get_node("%OverlayButton").pressed.emit()
	var queue_label := desk.get_node("%QueueLabel") as Label
	assert(queue_label.text == "7" and queue_label.tooltip_text == tr("DESK_HUD_QUEUE") % [7], queue_label.text)

	# Dia 3: o goblin recusado volta com um pedido honesto.
	bell.pressed.emit()
	assert(_item(desk) == "Hush Charm")
	approve.pressed.emit()
	assert(canvas.palette_symbols.size() == 15)
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["anderdingus_hush"])
	# Elenia: élfica, mas o embargo caiu ontem à noite; o pedido é honesto.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of Even Bloom")
	assert(AtelierInspection.discrepancies(desk.current_order, desk._day().rules).is_empty(), "The embargo is over: Elenia's form is clean")
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["elenia_even_bloom"])
	assert(game_state.outcomes["elenia_even_bloom"] == "delivered")
	bell.pressed.emit() # Mother Ketterly
	reject.pressed.emit()
	# Yuval: arredondar para cima com as runas de divisão do dia 3.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of Cleansing Rites")
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["yuval_cleansing_rites"])
	assert(game_state.outcomes["yuval_cleansing_rites"] == "delivered")
	# Magia proibida entregue: a suspeita sobe na hora e o inspetor vira auditoria.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of Gentle Forgetting")
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["osric_gentle_forgetting"])
	assert(game_state.flag("guild_suspicion") == 3)
	# Chrono Genesis fala de meditação logo depois da magia proibida, mas o
	# pergaminho só diz a hora: o pedido é honesto e atender paga.
	bell.pressed.emit()
	assert(_item(desk) == "Scroll of the Waking Hour")
	assert(AtelierInspection.discrepancies(desk.current_order, desk._day().rules).is_empty(), "Chrono's form is clean")
	var money_before_chrono: int = game_state.money
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.SOLUTIONS["chrono_waking_hour"])
	assert(game_state.outcomes["chrono_waking_hour"] == "delivered")
	assert(game_state.money > money_before_chrono, "Chrono pays for the hour")
	bell.pressed.emit()
	assert(_item(desk) == "Audit Tally")
	approve.pressed.emit()
	_write(canvas, workbench, SpellJudgeSmoke.AUDIT_LOOP)
	assert(not workbench.visible, "The loop solution should pass the audit on the real bench")
	assert(game_state.flag("guild_suspicion") == 1)

	# Fim do demo: o jornal de amanhã mostra o que ainda está agendado.
	bell.pressed.emit()
	assert(overlay.visible)
	assert(desk.phase == desk.Phase.DEMO_END)
	var ending := (desk.get_node("%OverlayBody") as RichTextLabel).text
	assert("MERCHANT'S MEMORY STOLEN" in ending and "ATELIER CLEARED" in ending, ending)

	# Um jornal enorme rola dentro do cartão: o botão continua na tela.
	var long_news := "\n\n".join(PackedStringArray(range(14).map(func(index: int) -> String: return "HEADLINE %d: a very long story about the shop." % index)))
	desk.call("_show_overlay", "Stress test", long_news, "Continue", func() -> void: pass)
	for frame in 3:
		await process_frame
	var button_rect := (desk.get_node("%OverlayButton") as Button).get_global_rect()
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(button_rect), "Overlay button off-screen: %s" % button_rect)

	print("desk_day_flow_smoke: demo played through, %d coins, reputation %d" % [game_state.money, game_state.reputation])
	quit(0)


func _item(desk: Control) -> String:
	return (desk.get_node("%ItemField") as Button).text.trim_prefix("» ")


func _rule_button(desk: Control, rule_id: String) -> Button:
	return desk.rule_button(rule_id)


func _write(canvas, workbench: Control, runes: Array) -> void:
	canvas.load_connections(SpellJudgeSmoke._program(runes))
	workbench.get_node("%DeliverButton").pressed.emit()
	assert(not workbench.visible, "Delivery should pass: %s" % (workbench.get_node("%ResultLabel") as Label).text)
