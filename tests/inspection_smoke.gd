extends SceneTree

## Inspeção sem UI: ligações campo → regra, legalidade derivada das regras do
## dia e recusa justificada pelo GameState.

const Result = AtelierInspection.Result


func _initialize() -> void:
	call_deferred("_run")


func _order(order_id: String) -> AtelierScrollOrder:
	return load("res://data/orders/%s.tres" % order_id) as AtelierScrollOrder


func _rule(rule_id: String) -> AtelierShopRule:
	return load("res://data/rules/%s.tres" % rule_id) as AtelierShopRule


func _day(number: int) -> AtelierShopDay:
	return load("res://data/days/day_%02d.tres" % number) as AtelierShopDay


func _run() -> void:
	var signature := _rule("signature")
	var offensive := _rule("offensive_license")
	var embargo := _rule("elf_embargo")
	var forbidden := _rule("forbidden_mind")
	var fireball := _order("anderdingus_fireball")
	var mira := _order("mira_warm_light")
	var day_1 := _day(1)

	# Ligação correta: vira prova, sem repetir regras citadas.
	var inspection := AtelierInspection.new(fireball, day_1.rules)
	assert(not inspection.has_evidence())
	var link: Dictionary = inspection.link("signature", signature)
	assert(link["result"] == Result.VALID, str(link))
	assert("GoOBLiN" in link["message"] and "Signature" in link["message"], link["message"])
	assert(inspection.has_evidence() and inspection.cited_rules() == [signature])
	assert(inspection.link("item", offensive)["result"] == Result.VALID)
	assert(inspection.link("details", offensive)["result"] == Result.VALID)
	assert(inspection.link("name", signature)["result"] == Result.VALID, "A name/signature mismatch can be proven from either field")
	assert(inspection.cited_rules() == [signature, offensive])
	assert(inspection.link("signature", signature)["result"] == Result.DUPLICATE)
	assert(inspection.evidence.size() == 4)

	# Ligações erradas: não viram prova e explicam a contradição.
	var wrong := AtelierInspection.new(fireball, day_1.rules)
	var wrong_field: Dictionary = wrong.link("race", signature)
	assert(wrong_field["result"] == Result.WRONG_FIELD)
	assert(wrong.link("age", offensive)["result"] == Result.WRONG_FIELD)
	var honest: Dictionary = AtelierInspection.new(mira, day_1.rules).link("signature", signature)
	assert(honest["result"] == Result.NOT_VIOLATED)
	# O jogador recebe a mesma frase nos dois casos: nada vaza sobre a regra.
	assert(wrong_field["message"].begins_with("No contradiction") and honest["message"].begins_with("No contradiction"))
	assert(not "broken" in wrong_field["message"], wrong_field["message"])
	assert(wrong.link("race", embargo)["result"] == Result.NOT_IN_FORCE, "The embargo is not in force on day 1")
	assert(not wrong.has_evidence() and wrong.cited_rules().is_empty())

	# Pedido legal não tem nenhuma discrepância válida, em nenhum dia.
	for number in [1, 2, 3]:
		var day := _day(number)
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				var found := AtelierInspection.discrepancies(order, day.rules)
				assert(found.is_empty() == day.is_legal(order), "%s: discrepancies disagree with legality" % order.id)
	for legal_id in ["mira_warm_light", "tomas_warming_charm", "pip_party_sparks", "oona_vesper_bell", "anderdingus_hush", "ketterly_fair_shares", "guild_inspector_routine", "guild_inspector_audit"]:
		for number in [1, 2, 3]:
			assert(AtelierInspection.discrepancies(_order(legal_id), _day(number).rules).is_empty(), "%s should be legal on day %d" % [legal_id, number])

	# Uma regra avalia várias encomendas sem UI.
	var expectations := {
		signature: {"anderdingus_fireball": true, "brom_doubled_ore": true, "anderdingus_bigger_fireball": true, "mira_warm_light": false, "anderdingus_hush": false, "guild_inspector_routine": false},
		embargo: {"faelar_quiet_growth": true, "pip_party_sparks": false, "brom_doubled_ore": false},
		forbidden: {"osric_gentle_forgetting": true, "ketterly_fair_shares": false, "anderdingus_fireball": false},
		offensive: {"anderdingus_fireball": true, "anderdingus_bigger_fireball": true, "anderdingus_hush": false},
	}
	for rule in expectations:
		var cases: Dictionary = expectations[rule]
		for order_id in cases:
			assert(rule.violated_by(_order(order_id)) == cases[order_id], "%s on %s" % [rule.id, order_id])

	# A legalidade vem das regras do dia: o embargo élfico cai no dia 3.
	var faelar := _order("faelar_quiet_growth")
	assert(not _day(2).is_legal(faelar) and _day(3).is_legal(faelar))

	# Recusa: só é correta com prova válida; sem prova custa reputação mesmo com pedido ilegal.
	var game_state: Node = root.get_node("GameState")
	var cite_signature: Array[AtelierShopRule] = [signature]
	var cite_embargo: Array[AtelierShopRule] = [embargo]
	game_state.new_game()
	var reputation: int = game_state.reputation
	assert(game_state.reject(fireball, cite_signature))
	assert(game_state.reputation == reputation + 1)
	assert("Matching signature" in str(game_state.ledger.back()["text"]))
	game_state.new_game()
	assert(not game_state.reject(fireball), "Refusing without evidence is not a correct rejection")
	assert(game_state.reputation == reputation - 1)
	assert(game_state.flag("goblin_refused") == 1, "The goblin was still turned away")
	game_state.new_game()
	assert(not game_state.reject(fireball, cite_embargo), "A rule not in force is not evidence")
	assert(not game_state.reject(mira, cite_signature), "A rule the order does not break is not evidence")

	print("INSPECTION_SMOKE_OK")
	quit(0)
