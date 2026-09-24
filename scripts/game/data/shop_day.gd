class_name AtelierShopDay
extends Resource

## Um dia de loja: regras em vigor, runas liberadas e a fila de clientes.

@export var title := ""
@export_multiline var intro := ""
@export var rules: Array[AtelierShopRule] = []
## Kinds do catálogo (ORB, TRIANGLE...) liberados na bancada neste dia.
@export var runes: PackedStringArray = []
@export var orders: Array[AtelierScrollOrder] = []


func rule_text(rule_id: String) -> String:
	for rule in rules:
		if rule.id == rule_id:
			return rule.text
	return rule_id
