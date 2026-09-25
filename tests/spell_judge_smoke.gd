extends SceneTree

## Cada encomenda do demo precisa ter solução com as runas liberadas no dia e
## dentro do número de runas do bônus (par). Ao criar um cliente novo, adicione
## a solução de referência aqui.

const SpellJudge = preload("res://scripts/game/spell_judge.gd")
const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres", "res://data/days/day_03.tres"]

## Soluções de referência por id da encomenda (inclusive variantes).
const SOLUTIONS := {
	"mira_warm_light": [["ORB", 3], ["TRIANGLE", 128]],
	"anderdingus_fireball": [["ORB", 9], ["TRIANGLE", 128]],
	"tomas_warming_charm": [["READ", 0], ["ORB", 10], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"rango_snack_time": [["READ", 0], ["READ", 1], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"kothar_doorbell_charm": [["READ", 0], ["ORB", 5], ["DIAMOND", 128], ["TRIANGLE", 128]],
	# Média dos três canteiros, arredondada para baixo: soma e divide por 3.
	"elenia_even_bloom": [
		["READ", 0], ["READ", 1], ["DIAMOND", 128], ["READ", 2], ["DIAMOND", 128],
		["ORB", 3], ["SLASH", 128], ["TRIANGLE", 128],
	],
	"reed_endless_feast": [["READ", 0], ["READ", 1], ["DIAMOND", 128], ["ORB", 1], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"pip_party_sparks": [["READ", 0], ["TWIN", 128], ["PLUS", 128], ["TRIANGLE", 128]],
	"faelar_quiet_growth": [["READ", 0], ["TWIN", 128], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"brom_doubled_ore": [["READ", 0], ["TWIN", 128], ["DIAMOND", 128], ["TRIANGLE", 128]],
	# Contagem regressiva: o PUSH 1 inicial é descartado pelo DROP logo após o
	# WARP END, assim como o booleano que JUMP_IF_TRUE deixa na pilha.
	"oona_vesper_bell": [
		["READ", 0], ["ORB", 1], ["WARP_ENDPOINT", 7], ["CUP", 128], ["TRIANGLE", 128],
		["ORB", 1], ["MOON", 128], ["TWIN", 128], ["ORB", 0], ["GT", 128], ["JUMP_IF_TRUE", 7],
	],
	# Sede do solo menos a chuva que já caiu (SUB estreia no dia 2).
	"sleego_gentle_rain": [["READ", 0], ["READ", 1], ["MOON", 128], ["TRIANGLE", 128]],
	"nemo_stinging_tide": [["READ", 0], ["ORB", 3], ["PLUS", 128], ["TRIANGLE", 128]],
	"anderdingus_hush": [["READ", 0], ["ORB", 3], ["SLASH", 128], ["TRIANGLE", 128]],
	"anderdingus_bigger_fireball": [["READ", 0], ["TWIN", 128], ["PLUS", 128], ["TRIANGLE", 128]],
	"ketterly_fair_shares": [
		["READ", 0], ["READ", 1], ["SLASH", 128], ["TRIANGLE", 128],
		["READ", 0], ["READ", 1], ["SPIRAL", 128], ["TRIANGLE", 128],
	],
	# Divisão arredondada para cima: (força + cada rito - 1) / cada rito.
	"yuval_cleansing_rites": [
		["READ", 0], ["READ", 1], ["DIAMOND", 128], ["ORB", 1],
		["MOON", 128], ["READ", 1], ["SLASH", 128], ["TRIANGLE", 128],
	],
	"osric_gentle_forgetting": [["READ", 0], ["ORB", 10], ["SLASH", 128], ["TRIANGLE", 128]],
	# Relógio de 24 horas: o MOD dá a volta, mesmo depois de dias de meditação.
	"chrono_waking_hour": [["READ", 0], ["READ", 1], ["DIAMOND", 128], ["ORB", 24], ["SPIRAL", 128], ["TRIANGLE", 128]],
	"guild_inspector_routine": [["READ", 0], ["READ", 1], ["PLUS", 128], ["TRIANGLE", 128]],
	# n * (n + 1) / 2: a fórmula que alcança o bônus de elegância.
	"guild_inspector_audit": [
		["READ", 0], ["TWIN", 128], ["ORB", 1], ["DIAMOND", 128],
		["PLUS", 128], ["ORB", 2], ["SLASH", 128], ["TRIANGLE", 128],
	],
}

## Regras que cada encomenda deve violar no seu dia (as demais são legais). A
## legalidade é derivada das regras; isto fixa a intenção do conteúdo, para um
## erro de digitação numa assinatura não tornar um cliente honesto ilegal.
const EXPECTED_BROKEN_RULES := {
	"anderdingus_fireball": ["offensive_license", "signature"],
	"faelar_quiet_growth": ["elf_embargo"],
	"brom_doubled_ore": ["signature"],
	"anderdingus_bigger_fireball": ["offensive_license", "signature"],
	"osric_gentle_forgetting": ["forbidden_mind"],
	"nemo_stinging_tide": ["offensive_license"],
	# "Doorbell Charm" soa inofensivo; os detalhes pedem um choque na maçaneta.
	"kothar_doorbell_charm": ["offensive_license"],
	# Pedido honesto, mas assinado com o apelido.
	"reed_endless_feast": ["signature"],
}

## A auditoria também aceita o laço (soma com STORE), só não ganha o bônus.
const AUDIT_LOOP := [
	["ORB", 0], ["ORB", 1], ["WARP_ENDPOINT", 5], ["CUP", 128], ["READ", 0], ["DIAMOND", 128],
	["READ", 0], ["ORB", 1], ["MOON", 128], ["TWIN", 128], ["SQUARE", 0], ["ORB", 0], ["GT", 128],
	["JUMP_IF_TRUE", 5], ["CUP", 128], ["TRIANGLE", 128],
]


func _initialize() -> void:
	call_deferred("_run")


static func _uses_inputs(order: AtelierScrollOrder) -> bool:
	for test_case in order.all_tests():
		if not Dictionary(test_case.get("memory", {})).is_empty():
			return true
	return false


static func _program(runes: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(runes.size()):
		result.append({
			"from": Vector2(index * 48.0, 0.0),
			"to": Vector2((index + 1) * 48.0, 0.0),
			"symbol": runes[index][0],
			"intensity": runes[index][1],
		})
	return result


func _check_order(judge: AtelierSpellJudge, day: AtelierShopDay, order: AtelierScrollOrder) -> void:
	assert(not order.id.is_empty(), "%s has no id" % order.item)
	assert(SOLUTIONS.has(order.id), "Missing reference solution for %s" % order.id)
	assert(not order.examples.is_empty(), "%s has no visible example" % order.id)
	if _uses_inputs(order):
		assert(not order.hidden_tests.is_empty(), "%s reads inputs but has no hidden test; the examples could be hardcoded" % order.id)
	if not order.starting_ritual.is_empty():
		for cell in order.starting_ritual:
			assert(str(cell["symbol"]).is_empty() or day.runes.has(cell["symbol"]), "%s draft uses a locked rune" % order.id)
		assert(not judge.judge(order.starting_ritual, order)["passed"], "%s draft already solves the order" % order.id)
	var broken := PackedStringArray(day.violated_rules(order).map(func(rule: AtelierShopRule) -> String: return rule.id))
	var expected := PackedStringArray(EXPECTED_BROKEN_RULES.get(order.id, []))
	broken.sort()
	expected.sort()
	assert(broken == expected, "%s breaks %s on %s, expected %s" % [order.id, broken, day.title, expected])
	if not day.is_legal(order):
		assert(not order.on_delivered.is_empty(), "%s is illegal but delivering it has no consequence" % order.id)
		assert(not AtelierInspection.discrepancies(order, day.rules).is_empty(), "%s is illegal but nothing on the form proves it" % order.id)
	var runes: Array = SOLUTIONS[order.id]
	for rune in runes:
		assert(day.runes.has(rune[0]), "%s needs %s, which is locked on %s" % [order.id, rune[0], day.title])
	var result := judge.judge(_program(runes), order)
	assert(result["passed"], "%s failed: %s" % [order.id, judge.describe_failure(result)])
	assert(result["elegant"], "%s solution uses %d runes, par is %d" % [order.id, result["rune_count"], order.par_runes])


func _run() -> void:
	var judge := SpellJudge.new()
	var checked := 0
	var ids := {}
	var produced_flags := {}
	var required_flags := {}
	for day_path in DAYS:
		var day := load(day_path) as AtelierShopDay
		assert(day != null, "Could not load %s" % day_path)
		assert(not day.orders.is_empty())
		for slot in day.orders:
			for order in AtelierShopDay.versions_of(slot):
				_check_order(judge, day, order)
				assert(not ids.has(order.id), "Duplicate order id %s" % order.id)
				ids[order.id] = true
				for consequence in order.on_delivered + order.on_rejected + order.on_abandoned:
					for flag_name in consequence.flag_changes:
						produced_flags[flag_name] = true
				for condition in order.conditions:
					required_flags[condition.flag] = order.id
				checked += 1
	# Uma condição sobre uma flag que nada produz é quase sempre erro de digitação.
	for flag_name in required_flags:
		assert(produced_flags.has(flag_name), "%s depends on flag '%s', which no consequence sets" % [required_flags[flag_name], flag_name])

	var audit := load("res://data/orders/guild_inspector_audit.tres") as AtelierScrollOrder
	var audit_loop := judge.judge(_program(AUDIT_LOOP), audit)
	assert(audit_loop["passed"], judge.describe_failure(audit_loop))
	assert(not audit_loop["elegant"], "The loop should pass the audit but miss the elegance bonus")

	# Decorar a resposta do exemplo passa na bancada, mas não nos testes ocultos.
	var warming := load("res://data/orders/tomas_warming_charm.tres") as AtelierScrollOrder
	var hardcoded := judge.judge(_program([["ORB", 15], ["TRIANGLE", 128]]), warming)
	assert(not hardcoded["passed"])
	assert(hardcoded["cases"][0]["passed"] and not hardcoded["cases"][0]["hidden"])
	assert(hardcoded["cases"][1]["hidden"] and not hardcoded["cases"][1]["passed"])
	assert(hardcoded["cases"][1]["memory"] == {0: 20} and hardcoded["cases"][1]["actual"] == ["15"])
	var hardcoded_message := judge.describe_failure(hardcoded)
	var hidden_prefix := (tr("JUDGE_HIDDEN_FAILED") % [""]).strip_edges()
	assert(hardcoded_message.begins_with(hidden_prefix), hardcoded_message)
	assert(judge.describe_memory({0: 20}) in hardcoded_message and tr("JUDGE_MISMATCH") % ["30", "15"] in hardcoded_message, hardcoded_message)

	# Um erro no exemplo visível não se apresenta como oculto.
	var wrong := judge.judge(_program([["READ", 0], ["TRIANGLE", 128]]), warming)
	assert(not wrong["cases"][0]["hidden"] and wrong["cases"][0]["actual"] == ["5"])
	assert(not judge.describe_failure(wrong).begins_with(hidden_prefix))
	assert(tr("JUDGE_MISMATCH") % ["15", "5"] in judge.describe_failure(wrong), judge.describe_failure(wrong))

	# Laço infinito: estoura o limite de passos da encomenda e vira timeout.
	var looping_order := AtelierScrollOrder.new()
	looping_order.examples = [{"memory": {}, "output": ["1"]}]
	looping_order.max_steps = 50
	var looping := judge.judge(_program([["ORB", 1], ["WARP_ENDPOINT", 1], ["JUMP_IF_TRUE", 1]]), looping_order)
	assert(not looping["passed"])
	assert(looping["cases"][0]["timed_out"] and int(looping["cases"][0]["steps"]) == 50)
	assert(tr("JUDGE_TIMEOUT") % [50] in judge.describe_failure(looping), judge.describe_failure(looping))
	assert(int(judge.judge(_program(SOLUTIONS["tomas_warming_charm"]), warming)["max_steps_used"]) > 0)

	# A memória inicial semeia a VM sem ser alterada pelo STORE.
	var vm := AtelierRuneVM.new()
	var memory := {0: 7}
	var compiled: Dictionary = AtelierRuneCompiler.new().compile(_program([["READ", 0], ["ORB", 1], ["DIAMOND", 128], ["SQUARE", 0], ["READ", 0], ["TRIANGLE", 128]]))
	var run: Dictionary = vm.run(compiled["bytecode"], memory)
	assert(run["output"] == ["8"] and not run["timed_out"], str(run))
	assert(memory == {0: 7})
	var broken := judge.judge(_program([["TRIANGLE", 128]]), warming)
	assert(not broken["passed"])
	assert(tr("VM_NEEDS_VALUE") % ["PRINT"] in judge.describe_failure(broken), judge.describe_failure(broken))
	var empty := judge.judge([], warming)
	assert(not empty["compiled"])

	print("spell_judge_smoke: %d orders solvable" % checked)
	quit(0)
