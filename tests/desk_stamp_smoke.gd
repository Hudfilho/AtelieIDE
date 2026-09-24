extends SceneTree

## Carimbos com a animação ligada (instant = false), sem esperar tempo real:
## finish_now/release_holds avançam o carimbo e a pausa. Confere que a decisão
## só vale no impacto e que cliques repetidos não decidem duas vezes.

const SpellJudgeSmoke = preload("res://tests/spell_judge_smoke.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	# Animação ligada, som desligado: as deixas ainda chegam por sfx_requested.
	(desk.get_node("%Feedback") as AtelierDeskFeedback).mute = true
	root.add_child(desk)
	await process_frame

	var feedback := desk.get_node("%Feedback") as AtelierDeskFeedback
	assert(not feedback.instant, "This test covers the animated path")
	var cues: Array[StringName] = []
	feedback.sfx_requested.connect(func(cue: StringName) -> void: cues.append(cue))
	var bell := desk.get_node("%BellButton") as Button
	var approve := desk.get_node("%ApproveButton") as Button
	var reject := desk.get_node("%RejectButton") as Button
	var ink := desk.get_node("%InkMark") as Label
	var speech := desk.get_node("%Speech") as Label
	var feedback_label := desk.get_node("%FeedbackLabel") as Label
	var workbench = desk.get_node("%Workbench")
	desk.get_node("%OverlayButton").pressed.emit()

	bell.pressed.emit()
	assert(cues.count(&"bell") == 1 and cues.count(&"paper") == 1, str(cues))

	# Aprovar com cliques repetidos: só um carimbo, nada decidido antes do impacto.
	for click in 5:
		approve.pressed.emit()
	reject.pressed.emit()
	assert(feedback.is_stamping())
	assert(desk.phase == desk.Phase.STAMPING)
	assert(not ink.visible, "No ink before impact")
	assert(not workbench.visible)
	assert(not approve.disabled, "The stamps keep their look while one is in the air")
	feedback.finish_now(false)
	assert(desk.phase == desk.Phase.CRAFTING)
	assert(ink.visible and ink.text == tr("DESK_INK_APPROVED"))
	assert("cat thanks you" in speech.text, speech.text)
	assert(cues.count(&"stamp_approve") == 1 and cues.count(&"stamp_reject") == 0, str(cues))
	assert(not workbench.visible, "The bench opens after the short pause")
	approve.pressed.emit()
	assert(not feedback.is_stamping(), "A decided request cannot be stamped again")
	feedback.release_holds()
	assert(workbench.visible)

	# Entregar duas vezes paga uma vez; sinais atrasados não pagam de novo.
	var canvas = workbench.get_node("%Canvas")
	canvas.load_connections(SpellJudgeSmoke._program(SpellJudgeSmoke.SOLUTIONS["mira_warm_light"]))
	workbench.get_node("%DeliverButton").pressed.emit()
	workbench.get_node("%DeliverButton").pressed.emit()
	desk._on_scroll_delivered({"elegant": true})
	desk._on_scroll_abandoned()
	assert(game_state.money == 20 + 8 + 5, "Paid exactly once: %d" % game_state.money)
	assert(game_state.ledger.size() == 1)
	assert(cues.count(&"coins") == 1)
	approve.pressed.emit()
	reject.pressed.emit()
	assert(not feedback.is_stamping() and game_state.ledger.size() == 1, "Stamps do nothing with an empty window")

	# Sinal atrasado da bancada com o próximo cliente no balcão: não pode pagar
	# nem registrar a entrega em nome dele.
	bell.pressed.emit()
	desk._on_scroll_delivered({"elegant": false})
	desk._on_scroll_abandoned()
	assert(game_state.money == 20 + 8 + 5 and game_state.ledger.size() == 1, "A stray delivery signal paid the next client")
	assert(not game_state.outcomes.has("anderdingus_fireball"))
	assert(desk.request_form.visible, "The next client is still being served")

	# Recusar o Fireball com prova e cliques repetidos: a decisão vale no impacto.
	desk.get_node("%SignatureField").pressed.emit()
	desk.rule_button("signature").pressed.emit()
	var reputation: int = game_state.reputation
	for click in 5:
		reject.pressed.emit()
	approve.pressed.emit()
	assert(game_state.reputation == reputation and game_state.flag("goblin_refused") == 0, "Nothing is decided before impact")
	assert(game_state.ledger.size() == 1)
	feedback.finish_now(false)
	assert(game_state.reputation == reputation + 1)
	assert(game_state.flag("goblin_refused") == 1)
	assert(game_state.ledger.size() == 2)
	assert(game_state.outcomes["anderdingus_fireball"] == "rejected")
	assert(ink.visible and ink.text == tr("DESK_INK_REFUSED"))
	assert("GoOBLiN will find another shop" in speech.text, speech.text)
	assert(desk.request_form.visible, "The refused request stays on the desk while the client reacts")
	assert(bell.disabled and reject.disabled and approve.disabled)
	assert(feedback_label.text == tr("DESK_REFUSED_EVIDENCE") % ["Matching signature"], feedback_label.text)
	assert(feedback.shake_target.position == Vector2.ZERO, "The shake is undone when the stamp finishes early")
	for click in 3:
		reject.pressed.emit()
	feedback.finish_now(false)
	assert(game_state.reputation == reputation + 1 and game_state.flag("goblin_refused") == 1)
	assert(game_state.ledger.size() == 2, "Repeated stamping cannot duplicate consequences")
	feedback.release_holds()
	assert(desk.phase == desk.Phase.WAITING)
	assert(not desk.request_form.visible and not ink.visible)
	assert(not bell.disabled)

	# Troca de cena com uma pausa pendente não quebra nada.
	bell.pressed.emit()
	approve.pressed.emit()
	feedback.finish_now(false)
	desk.queue_free()
	await process_frame
	await process_frame

	print("DESK_STAMP_SMOKE_OK")
	quit(0)
