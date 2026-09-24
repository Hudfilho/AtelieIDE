class_name AtelierInspection
extends RefCounted

## Inspeção de um pedido no balcão, sem UI: o jogador liga um campo do
## formulário a uma regra do livro. Ligações válidas viram provas; as inválidas
## voltam com uma explicação da contradição. As provas justificam a recusa.
##
## Contra tentativa e erro: cada ligação inválida é um erro, qualquer que seja
## a regra ou o pedido. O cliente fica inquieto a partir do segundo erro, e ao
## chegar em mistake_threshold há uma única penalidade (penalty_due), nunca
## repetida com o mesmo cliente. Cada cliente começa com uma inspeção nova.

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

## Paciência do cliente, derivada só do número de erros.
enum Patience {
	## Nenhum ou um erro: a primeira ligação errada não custa nada.
	CALM,
	## Do segundo erro até antes do limite.
	UNEASY,
	## Chegou ao limite: é aqui que a penalidade acontece, uma vez.
	UPSET,
	## Passou do limite: só reclamação, sem nova penalidade.
	EXASPERATED,
}

const DEFAULT_MISTAKE_THRESHOLD := 3
## O limite nunca fica abaixo de 2, para o primeiro erro não ser penalizado.
const MIN_MISTAKE_THRESHOLD := 2

var order: AtelierScrollOrder
var rules: Array[AtelierShopRule] = []
## Provas aceitas, na ordem em que foram citadas: {"field": String, "rule": AtelierShopRule}.
var evidence: Array[Dictionary] = []
var mistake_threshold := DEFAULT_MISTAKE_THRESHOLD
## Ligações inválidas feitas com este cliente.
var mistakes := 0
var penalty_triggered := false


func _init(inspected_order: AtelierScrollOrder, rules_in_force: Array[AtelierShopRule], threshold := DEFAULT_MISTAKE_THRESHOLD) -> void:
	order = inspected_order
	rules = rules_in_force
	mistake_threshold = maxi(threshold, MIN_MISTAKE_THRESHOLD)


## Tenta ligar um campo a uma regra. Devolve {"result": Result, "message":
## String, "mistake": bool, "mistakes": int, "patience": Patience,
## "penalty_due": bool}. penalty_due é verdadeiro uma única vez por inspeção.
func link(field_name: String, rule: AtelierShopRule) -> Dictionary:
	var result := evaluate(order, rules, field_name, rule)
	if result == Result.VALID:
		if is_cited(field_name, rule):
			result = Result.DUPLICATE
		else:
			evidence.append({"field": field_name, "rule": rule})
	var mistake := result != Result.VALID and result != Result.DUPLICATE
	var penalty_due := false
	if mistake:
		mistakes += 1
		if mistakes >= mistake_threshold and not penalty_triggered:
			penalty_triggered = true
			penalty_due = true
	return {
		"result": result, "message": describe(result, order, field_name, rule),
		"mistake": mistake, "mistakes": mistakes, "patience": patience(), "penalty_due": penalty_due,
	}


func patience() -> Patience:
	if mistakes <= 1:
		return Patience.CALM
	if mistakes < mistake_threshold:
		return Patience.UNEASY
	if mistakes == mistake_threshold:
		return Patience.UPSET
	return Patience.EXASPERATED


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
	var label := AtelierScrollOrder.field_label(field_name)
	var value := _short(inspected_order.field_value(field_name))
	match result:
		Result.VALID:
			return AtelierText.t("INSPECT_CONFIRMED", [label, value, rule.title])
		Result.DUPLICATE:
			return AtelierText.t("INSPECT_DUPLICATE", [label, rule.title])
		# Mesma frase para os dois casos de propósito: dizer "a regra é violada,
		# mas não por este campo" revelaria a resposta sem dedução.
		Result.WRONG_FIELD, Result.NOT_VIOLATED:
			return AtelierText.t("INSPECT_NO_CONTRADICTION", [label, value, rule.title])
		_:
			return AtelierText.t("INSPECT_NOT_IN_FORCE", [rule.title])


static func _short(text: String) -> String:
	var single_line := text.replace("\n", " ")
	return single_line if single_line.length() <= 36 else single_line.left(33) + "..."
