extends SceneTree

## Contra tentativa e erro na inspeção: contagem de erros por cliente, reação
## crescente e uma única penalidade por cliente. Primeiro a lógica (sem UI),
## depois pelo balcão em modo instant.

const Result = AtelierInspection.Result
const Patience = AtelierInspection.Patience


func _initialize() -> void:
	call_deferred("_run")


func _order(order_id: String) -> AtelierScrollOrder:
	return load("res://data/orders/%s.tres" % order_id) as AtelierScrollOrder


func _rule(rule_id: String) -> AtelierShopRule:
	return load("res://data/rules/%s.tres" % rule_id) as AtelierShopRule


func _run() -> void:
	var day_1 := load("res://data/days/day_01.tres") as AtelierShopDay
	var signature := _rule("signature")
	var offensive := _rule("offensive_license")
	var embargo := _rule("elf_embargo")
	var fireball := _order("anderdingus_fireball")

	# Ligações certas e repetidas não contam como erro.
	var inspection := AtelierInspection.new(fireball, day_1.rules)
	assert(inspection.mistake_threshold == 3)
	for link in [inspection.link("signature", signature), inspection.link("item", offensive), inspection.link("signature", signature)]:
		assert(not link["mistake"] and not link["penalty_due"])
	assert(inspection.mistakes == 0 and inspection.patience() == Patience.CALM)

	# Erros crescem: 1º sem nada, 2º inquieto, 3º (limite) penaliza, depois só reclama.
	var penalties := 0
	var patience_seen: Array = []
	for attempt in 10:
		var link: Dictionary = inspection.link("race", signature) if attempt % 2 == 0 else inspection.link("age", offensive)
		assert(link["mistake"])
		assert(link["mistakes"] == attempt + 1)
		if link["penalty_due"]:
			penalties += 1
			assert(link["mistakes"] == 3, "The penalty lands exactly at the threshold")
		patience_seen.append(link["patience"])
	assert(penalties == 1, "One customer can only be penalized once, got %d" % penalties)
	assert(patience_seen.slice(0, 4) == [Patience.CALM, Patience.UNEASY, Patience.UPSET, Patience.EXASPERATED], str(patience_seen))
	assert(inspection.evidence.size() == 2, "Mistakes never touch the evidence")

	# Independente de regra e pedido: um pedido legal e uma regra fora de vigor contam igual.
	var mira := AtelierInspection.new(_order("mira_warm_light"), day_1.rules)
	assert(mira.link("signature", signature)["result"] == Result.NOT_VIOLATED)
	assert(mira.link("race", embargo)["result"] == Result.NOT_IN_FORCE)
	var third: Dictionary = mira.link("name", offensive)
	assert(third["penalty_due"] and mira.mistakes == 3)

	# Limite configurável, com piso de 2: o primeiro erro nunca é penalizado.
	var strict := AtelierInspection.new(fireball, day_1.rules, 1)
	assert(strict.mistake_threshold == 2)
	assert(not strict.link("race", signature)["penalty_due"])
	assert(strict.link("race", signature)["penalty_due"])
	var patient := AtelierInspection.new(fireball, day_1.rules, 5)
	for attempt in 4:
		assert(not patient.link("race", signature)["penalty_due"])
	assert(patient.link("race", signature)["penalty_due"])

	# Pelo balcão: penalidade única, reação na janela e contagem zerada no próximo cliente.
	root.size = Vector2i(1280, 720)
	var game_state: Node = root.get_node("GameState")
	game_state.new_game()
	var desk = load("res://scenes/game/Desk.tscn").instantiate()
	(desk.get_node("%Feedback") as AtelierDeskFeedback).instant = true
	root.add_child(desk)
	await process_frame
	desk.get_node("%OverlayButton").pressed.emit()
	var bell := desk.get_node("%BellButton") as Button
	var speech := desk.get_node("%Speech") as Label
	var evidence_label := desk.get_node("%EvidenceLabel") as Label
	var rules = desk.get_node("%RulesList")

	bell.pressed.emit() # Mira
	var reputation: int = game_state.reputation
	desk.get_node("%RaceField").pressed.emit()
	rules.get_node("Rule_signature").pressed.emit()
	assert(desk.inspection.mistakes == 1 and game_state.reputation == reputation)
	assert(not "Hm?" in speech.text, "The first wrong link gets no reaction")
	desk.get_node("%AgeField").pressed.emit()
	rules.get_node("Rule_signature").pressed.emit()
	assert("Is something wrong with my form?" in speech.text, speech.text)
	assert("Wrong links: 2/3" in evidence_label.text, evidence_label.text)
	assert(game_state.reputation == reputation)
	# Tentativa e erro em massa: uma penalidade só.
	for attempt in 10:
		desk.get_node("%NameField").pressed.emit()
		rules.get_node("Rule_offensive_license").pressed.emit()
	assert(game_state.reputation == reputation - 1, "Penalized %d times" % (reputation - game_state.reputation))
	var penalty_lines := 0
	for entry in game_state.ledger:
		if "fussy inspection" in str(entry["text"]):
			penalty_lines += 1
	assert(penalty_lines == 1)
	assert("*sigh*" in speech.text, speech.text)
	assert("Wrong links: 12/3" in evidence_label.text, evidence_label.text)
	# O próximo cliente começa do zero.
	desk.get_node("%RejectButton").pressed.emit()
	bell.pressed.emit() # Anderdingus
	assert(desk.inspection.mistakes == 0 and not desk.inspection.penalty_triggered)
	assert(not "Wrong links" in evidence_label.text, evidence_label.text)
	desk.get_node("%RaceField").pressed.emit()
	rules.get_node("Rule_signature").pressed.emit()
	assert(desk.inspection.mistakes == 1)
	desk.queue_free()
	await process_frame

	print("INSPECTION_PATIENCE_SMOKE_OK")
	quit(0)
