class_name AtelierScrollOrder
extends Resource

## Uma encomenda de pergaminho: quem pede, o que pede e o que o feitiço precisa
## fazer para ser aceito. Edite pelo Inspector do Godot.

@export_group("Cliente")
@export var client_name := ""
@export var age := ""
@export var race := ""
## Como o cliente assinou o pedido. Compare com o nome.
@export var signature := ""
@export var portrait_color := Color(0.45, 0.55, 0.35)
@export_multiline var greeting := ""

@export_group("Pedido")
@export var item := ""
@export_multiline var details := ""
## Ids das regras do dia que este pedido viola. Vazio = pedido legítimo.
@export var violations: PackedStringArray = []

@export_group("Feitiço")
## O que o pergaminho precisa fazer, em linguagem de jogador.
@export_multiline var spec := ""
## Cada caso: {"memory": {0: 5}, "output": ["15"]}. A memória semeia READ/LOAD.
@export var test_cases: Array[Dictionary] = []
## Quantidade de runas para ganhar o bônus de trabalho elegante (0 = sem bônus).
@export var par_runes := 0
@export var reward := 10

@export_group("Consequências")
## Manchete do jornal do dia seguinte se o pedido ilegal for entregue.
@export_multiline var consequence_news := ""
@export var consequence_reputation := 0
@export var consequence_money := 0


func is_legal() -> bool:
	return violations.is_empty()
