class_name AtelierShopRule
extends Resource

## Uma regra do livro do dia, verificável a partir dos campos do pedido. A
## legalidade de uma encomenda é derivada das regras em vigor (veja
## AtelierShopDay.violated_rules), e a inspeção usa evidence_fields para saber
## quais campos o jogador pode citar como prova.

enum Check {
	## Regra só de ambientação: nunca é violada.
	NONE,
	## field == value (sem diferenciar maiúsculas), ex.: race == "Elf".
	FIELD_IS,
	## field != other_field, ex.: signature != name.
	FIELDS_DIFFER,
	## A encomenda tem a etiqueta value em tags, ex.: "offensive".
	HAS_TAG,
}

@export var id := ""
## Nome curto para o livro-caixa e a lista de provas.
@export var title := ""
@export_multiline var text := ""

@export_group("Verificação")
@export var check := Check.NONE
@export var field := ""
@export var other_field := ""
@export var value := ""
## Campos do pedido que o jogador pode ligar a esta regra como prova.
@export var evidence_fields: PackedStringArray = []


func violated_by(order: AtelierScrollOrder) -> bool:
	match check:
		Check.FIELD_IS:
			return order.field_value(field).strip_edges().nocasecmp_to(value) == 0
		Check.FIELDS_DIFFER:
			return order.field_value(field).strip_edges() != order.field_value(other_field).strip_edges()
		Check.HAS_TAG:
			return order.tags.has(value)
		_:
			return false


## O campo prova a violação: a regra é violada e o campo é um dos citáveis.
func is_evidence(order: AtelierScrollOrder, field_name: String) -> bool:
	return evidence_fields.has(field_name) and violated_by(order)
