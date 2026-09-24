class_name AtelierInspection
extends RefCounted

## Inspeção de um pedido no balcão, sem UI: o jogador liga um campo do
## formulário a uma regra do livro. Ligações válidas viram provas; as inválidas
## voltam com uma explicação da contradição. As provas justificam a recusa.

enum Result {
	## Campo e regra formam uma discrepância real; entrou nas provas.
	VALID,
	## Discrepância real, mas já estava nas provas.
	DUPLICATE,
	## A regra é violada, mas este campo não é a prova. Para o jogador, a
	## mensagem é igual à de NOT_VIOLATED (veja describe).
	WRONG_FIELD,
	## O pedido não viola esta regra.
	NOT_VIOLATED,
	## Regra que não está em vigor neste dia.
	NOT_IN_FORCE,
}

var order: AtelierScrollOrder
var rules: Array[AtelierShopRule] = []
## Provas aceitas, na ordem em que foram citadas: {"field": String, "rule": AtelierShopRule}.
var evidence: Array[Dictionary] = []


func _init(inspected_order: AtelierScrollOrder, rules_in_force: Array[AtelierShopRule]) -> void:
	order = inspected_order
	rules = rules_in_force


## Tenta ligar um campo a uma regra. Devolve {"result": Result, "message": String}.
func link(field_name: String, rule: AtelierShopRule) -> Dictionary:
	var result := evaluate(order, rules, field_name, rule)
	if result == Result.VALID:
		if is_cited(field_name, rule):
			result = Result.DUPLICATE
		else:
			evidence.append({"field": field_name, "rule": rule})
	return {"result": result, "message": describe(result, order, field_name, rule)}


func has_evidence() -> bool:
	return not evidence.is_empty()


func is_cited(field_name: String, rule: AtelierShopRule) -> bool:
	for entry in evidence:
		if entry["field"] == field_name and entry["rule"] == rule:
			return true
	return false


## Regras citadas, sem repetição, na ordem da primeira citação.
func cited_rules() -> Array[AtelierShopRule]:
	var cited: Array[AtelierShopRule] = []
	for entry in evidence:
		var rule: AtelierShopRule = entry["rule"]
		if not cited.has(rule):
			cited.append(rule)
	return cited


static func evaluate(inspected_order: AtelierScrollOrder, rules_in_force: Array[AtelierShopRule], field_name: String, rule: AtelierShopRule) -> Result:
	if not rules_in_force.has(rule):
		return Result.NOT_IN_FORCE
	if not rule.violated_by(inspected_order):
		return Result.NOT_VIOLATED
	if not rule.evidence_fields.has(field_name):
		return Result.WRONG_FIELD
	return Result.VALID


## Todas as ligações válidas possíveis; vazio para um pedido legal.
static func discrepancies(inspected_order: AtelierScrollOrder, rules_in_force: Array[AtelierShopRule]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for rule in rules_in_force:
		for field_name in AtelierScrollOrder.INSPECTABLE_FIELDS:
			if evaluate(inspected_order, rules_in_force, field_name, rule) == Result.VALID:
				found.append({"field": field_name, "rule": rule})
	return found


static func describe(result: Result, inspected_order: AtelierScrollOrder, field_name: String, rule: AtelierShopRule) -> String:
	var label: String = AtelierScrollOrder.FIELD_LABELS.get(field_name, field_name)
	var value := _short(inspected_order.field_value(field_name))
	match result:
		Result.VALID:
			return "Discrepancy confirmed: %s \"%s\" breaks the %s rule." % [label, value, rule.title]
		Result.DUPLICATE:
			return "You already cited %s against the %s rule." % [label, rule.title]
		# Mesma frase para os dois casos de propósito: dizer "a regra é violada,
		# mas não por este campo" revelaria a resposta sem dedução.
		Result.WRONG_FIELD, Result.NOT_VIOLATED:
			return "No contradiction: %s \"%s\" does not break the %s rule." % [label, value, rule.title]
		_:
			return "The %s rule is not in force today." % rule.title


static func _short(text: String) -> String:
	var single_line := text.replace("\n", " ")
	return single_line if single_line.length() <= 36 else single_line.left(33) + "..."
