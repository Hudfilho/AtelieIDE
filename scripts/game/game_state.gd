extends Node

## Estado da partida (autoload GameState): dinheiro, reputação, dia atual,
## flags do mundo e as consequências agendadas para as próximas manhãs.
## As decisões do balcão passam por deliver/reject/abandon, que aplicam a regra
## geral da loja e disparam as consequências declaradas em cada encomenda.

signal changed

const DAYS: Array[AtelierShopDay] = [
	preload("res://data/days/day_01.tres"),
	preload("res://data/days/day_02.tres"),
	preload("res://data/days/day_03.tres"),
]
const STARTING_MONEY := 20
const STARTING_REPUTATION := 5
const ELEGANT_BONUS := 5

var money := STARTING_MONEY
var reputation := STARTING_REPUTATION
var day_index := 0
## Linhas do livro-caixa do dia: {"text": String, "money": int, "reputation": int}.
var ledger: Array[Dictionary] = []
## Estado do mundo que as condições dos clientes consultam. Ausente = 0.
var flags: Dictionary[String, int] = {}
## Decisão tomada em cada encomenda: id -> "delivered" | "rejected" | "abandoned".
var outcomes: Dictionary[String, String] = {}
## Consequências futuras: {"due_day": int, "consequence": AtelierConsequence, "source_id": String}.
var scheduled: Array[Dictionary] = []


func new_game() -> void:
	money = STARTING_MONEY
	reputation = STARTING_REPUTATION
	day_index = 0
	ledger.clear()
	flags.clear()
	outcomes.clear()
	scheduled.clear()
	changed.emit()


func current_day() -> AtelierShopDay:
	return DAYS[day_index]


func has_next_day() -> bool:
	return day_index + 1 < DAYS.size()


## Avança o dia e aplica o que estava agendado; devolve as manchetes da manhã.
func begin_next_day() -> PackedStringArray:
	day_index += 1
	ledger.clear()
	changed.emit()
	return apply_due_consequences()


func record(text: String, money_delta := 0, reputation_delta := 0) -> void:
	money += money_delta
	reputation += reputation_delta
	ledger.append({"text": text, "money": money_delta, "reputation": reputation_delta})
	changed.emit()


func flag(flag_name: String) -> int:
	return flags.get(flag_name, 0)


func change_flag(flag_name: String, delta: int) -> void:
	flags[flag_name] = flag(flag_name) + delta
	changed.emit()


## A versão de um cliente da fila que aparece hoje, ou null se ele não vem.
func resolve_customer(slot: AtelierScrollOrder) -> AtelierScrollOrder:
	return AtelierShopDay.resolve_customer(slot, flags)


## ======================== DECISÕES ========================

## Entrega um pergaminho aprovado e aceito pelo juiz; devolve quanto foi pago.
func deliver(order: AtelierScrollOrder, elegant: bool) -> int:
	var paid := order.reward + (ELEGANT_BONUS if elegant else 0)
	record(tr("LEDGER_SOLD_ELEGANT" if elegant else "LEDGER_SOLD") % [order.item, order.client_name], paid, 1 if current_day().is_legal(order) else 0)
	_decide(order, "delivered", order.on_delivered)
	return paid


## Recusa o pedido. Só é uma recusa correta se cita ao menos uma regra que o
## pedido de fato viola (as provas da AtelierInspection); sem prova válida é
## recusa sem motivo, mesmo que o pedido seja ilegal. Em ambos os casos o
## cliente vai embora e as consequências on_rejected acontecem.
func reject(order: AtelierScrollOrder, cited_rules: Array[AtelierShopRule] = []) -> bool:
	var justified: Array[AtelierShopRule] = []
	for rule in cited_rules:
		if current_day().rules.has(rule) and rule.violated_by(order) and not justified.has(rule):
			justified.append(rule)
	if justified.is_empty():
		record(tr("LEDGER_REFUSED_NO_CAUSE") % [order.client_name], 0, -1)
	else:
		var titles := PackedStringArray(justified.map(func(rule: AtelierShopRule) -> String: return rule.title))
		record(tr("LEDGER_REFUSED") % [order.client_name, order.item, ", ".join(titles)], 0, 1)
	_decide(order, "rejected", order.on_rejected)
	return not justified.is_empty()


## Penalidade por inspeção confusa (ligações erradas demais com um cliente).
## Quem garante que acontece uma vez por cliente é a AtelierInspection.
func penalize_inspection(order: AtelierScrollOrder, amount: int) -> void:
	record(tr("LEDGER_INSPECTION_PENALTY") % [order.client_name], 0, -amount)


func abandon(order: AtelierScrollOrder) -> void:
	record(tr("LEDGER_ABANDONED") % [order.item, order.client_name], 0, -1)
	_decide(order, "abandoned", order.on_abandoned)


func _decide(order: AtelierScrollOrder, outcome: String, consequences: Array[AtelierConsequence]) -> void:
	outcomes[order.id] = outcome
	for consequence in consequences:
		trigger(consequence, order.id)


## ======================== CONSEQUÊNCIAS ========================

## Aplica na hora (delay_days 0) ou agenda para uma manhã futura.
func trigger(consequence: AtelierConsequence, source_id := "") -> void:
	if consequence.delay_days <= 0:
		_apply(consequence)
		return
	scheduled.append({"due_day": day_index + consequence.delay_days, "consequence": consequence, "source_id": source_id})


## Aplica tudo que vence até hoje e devolve as manchetes, na ordem agendada.
func apply_due_consequences() -> PackedStringArray:
	var headlines: PackedStringArray = []
	var still_pending: Array[Dictionary] = []
	for entry in scheduled:
		if int(entry["due_day"]) > day_index:
			still_pending.append(entry)
			continue
		var consequence: AtelierConsequence = entry["consequence"]
		_apply(consequence)
		if not consequence.headline.is_empty():
			headlines.append(consequence.headline)
	scheduled = still_pending
	return headlines


## Manchetes ainda agendadas; o fim do demo mostra o que viria depois.
func upcoming_headlines() -> PackedStringArray:
	var headlines: PackedStringArray = []
	for entry in scheduled:
		var consequence: AtelierConsequence = entry["consequence"]
		if not consequence.headline.is_empty():
			headlines.append(consequence.headline)
	return headlines


func _apply(consequence: AtelierConsequence) -> void:
	for flag_name in consequence.flag_changes:
		flags[flag_name] = flag(flag_name) + consequence.flag_changes[flag_name]
	if consequence.money != 0 or consequence.reputation != 0 or not consequence.ledger_text.is_empty():
		record(consequence.ledger_text if not consequence.ledger_text.is_empty() else tr("LEDGER_CONSEQUENCE"), consequence.money, consequence.reputation)
	else:
		changed.emit()
