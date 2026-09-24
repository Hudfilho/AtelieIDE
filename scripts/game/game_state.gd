extends Node

## Estado da partida (autoload GameState): dinheiro, reputação, dia atual e o
## que o jornal vai contar amanhã.

signal changed

const DAYS: Array[AtelierShopDay] = [
	preload("res://data/days/day_01.tres"),
	preload("res://data/days/day_02.tres"),
]
const STARTING_MONEY := 20
const STARTING_REPUTATION := 5

var money := STARTING_MONEY
var reputation := STARTING_REPUTATION
var day_index := 0
## Linhas do livro-caixa do dia: {"text": String, "money": int, "reputation": int}.
var ledger: Array[Dictionary] = []
## Encomendas ilegais entregues hoje; viram notícia e cobrança amanhã.
var pending_consequences: Array[AtelierScrollOrder] = []


func new_game() -> void:
	money = STARTING_MONEY
	reputation = STARTING_REPUTATION
	day_index = 0
	ledger.clear()
	pending_consequences.clear()
	changed.emit()


func current_day() -> AtelierShopDay:
	return DAYS[day_index]


func has_next_day() -> bool:
	return day_index + 1 < DAYS.size()


func begin_next_day() -> void:
	day_index += 1
	ledger.clear()
	changed.emit()


func record(text: String, money_delta := 0, reputation_delta := 0) -> void:
	money += money_delta
	reputation += reputation_delta
	ledger.append({"text": text, "money": money_delta, "reputation": reputation_delta})
	changed.emit()


## Aplica as consequências pendentes e devolve as manchetes do jornal.
func publish_news() -> PackedStringArray:
	var headlines: PackedStringArray = []
	for order in pending_consequences:
		headlines.append(order.consequence_news)
		record("Consequence: %s's %s" % [order.client_name, order.item], order.consequence_money, order.consequence_reputation)
	pending_consequences.clear()
	return headlines
