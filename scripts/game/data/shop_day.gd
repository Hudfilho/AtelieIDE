class_name AtelierShopDay
extends Resource

## Um dia de loja: regras em vigor, runas liberadas e a fila de clientes.

@export var title := ""
@export_multiline var intro := ""
@export var rules: Array[AtelierShopRule] = []
## Kinds do catálogo (ORB, TRIANGLE...) liberados na bancada neste dia.
@export var runes: PackedStringArray = []
@export var orders: Array[AtelierScrollOrder] = []


## A versão de um cliente da fila que aparece com estas flags, ou null se ele
## não vem: a primeira variante cujas condições valem, senão o próprio cliente.
static func resolve_customer(slot: AtelierScrollOrder, flags: Dictionary) -> AtelierScrollOrder:
	for raw_variant in slot.variants:
		var variant := raw_variant as AtelierScrollOrder
		if variant != null and variant.conditions_met(flags):
			return variant
	return slot if slot.conditions_met(flags) else null


## O cliente e todas as variantes, para testes e ferramentas de conteúdo.
static func versions_of(slot: AtelierScrollOrder) -> Array[AtelierScrollOrder]:
	var versions: Array[AtelierScrollOrder] = [slot]
	for raw_variant in slot.variants:
		var variant := raw_variant as AtelierScrollOrder
		assert(variant != null, "%s has a variant that is not an AtelierScrollOrder" % slot.id)
		versions.append(variant)
	return versions


## Regras em vigor hoje que a encomenda viola; vazio = pedido legal hoje.
func violated_rules(order: AtelierScrollOrder) -> Array[AtelierShopRule]:
	var violated: Array[AtelierShopRule] = []
	for rule in rules:
		if rule.violated_by(order):
			violated.append(rule)
	return violated


func is_legal(order: AtelierScrollOrder) -> bool:
	return violated_rules(order).is_empty()
