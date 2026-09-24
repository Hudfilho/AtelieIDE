extends SceneTree

## Cada encomenda do demo precisa ter solução com as runas liberadas no dia e
## dentro do número de runas do bônus (par). Ao criar um cliente novo, adicione
## a solução de referência aqui.

const SpellJudge = preload("res://scripts/game/spell_judge.gd")
const DAYS: Array[String] = ["res://data/days/day_01.tres", "res://data/days/day_02.tres"]

const SOLUTIONS := {
	"Scroll of Warm Light": [["ORB", 3], ["TRIANGLE", 128]],
	"Fireball": [["ORB", 9], ["TRIANGLE", 128]],
	"Warming Charm": [["READ", 0], ["ORB", 10], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"Party Sparks": [["READ", 0], ["TWIN", 128], ["PLUS", 128], ["TRIANGLE", 128]],
	"Scroll of Quiet Growth": [["READ", 0], ["TWIN", 128], ["DIAMOND", 128], ["TRIANGLE", 128]],
	"Scroll of Doubled Ore": [["READ", 0], ["TWIN", 128], ["DIAMOND", 128], ["TRIANGLE", 128]],
	# Contagem regressiva: o PUSH 1 inicial é descartado pelo DROP logo após o
	# WARP END, assim como o booleano que JUMP_IF_TRUE deixa na pilha.
	"Bell of Vespers": [
		["READ", 0], ["ORB", 1], ["WARP_ENDPOINT", 7], ["CUP", 128], ["TRIANGLE", 128],
		["ORB", 1], ["MOON", 128], ["TWIN", 128], ["ORB", 0], ["GT", 128], ["JUMP_IF_TRUE", 7],
	],
}


func _initialize() -> void:
	call_deferred("_run")


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


func _run() -> void:
	var judge := SpellJudge.new()
	var checked := 0
	for day_path in DAYS:
		var day := load(day_path) as AtelierShopDay
		assert(day != null, "Could not load %s" % day_path)
		assert(not day.orders.is_empty())
		for order in day.orders:
			assert(SOLUTIONS.has(order.item), "Missing reference solution for %s" % order.item)
			assert(not order.test_cases.is_empty(), "%s has no test cases" % order.item)
			for rule_id in order.violations:
				assert(day.rule_text(rule_id) != rule_id, "%s cites unknown rule %s" % [order.item, rule_id])
			if not order.is_legal():
				assert(not order.consequence_news.is_empty(), "%s is illegal but has no consequence" % order.item)
			var runes: Array = SOLUTIONS[order.item]
			for rune in runes:
				assert(day.runes.has(rune[0]), "%s needs %s, which is locked on %s" % [order.item, rune[0], day.title])
			var result := judge.judge(_program(runes), order)
			assert(result["passed"], "%s failed: %s" % [order.item, SpellJudge.describe_failure(result)])
			assert(result["elegant"], "%s solution uses %d runes, par is %d" % [order.item, result["rune_count"], order.par_runes])
			checked += 1

	# Uma solução errada explica o caso que falhou.
	var warming := load("res://data/orders/tomas_warming_charm.tres") as AtelierScrollOrder
	var wrong := judge.judge(_program([["ORB", 15], ["TRIANGLE", 128]]), warming)
	assert(not wrong["passed"])
	assert("expected 30, got 15" in SpellJudge.describe_failure(wrong), SpellJudge.describe_failure(wrong))
	var broken := judge.judge(_program([["TRIANGLE", 128]]), warming)
	assert(not broken["passed"])
	assert("PRINT" in SpellJudge.describe_failure(broken), SpellJudge.describe_failure(broken))
	var empty := judge.judge([], warming)
	assert(not empty["compiled"])

	print("spell_judge_smoke: %d orders solvable" % checked)
	quit(0)
