class_name AtelierScrollOrder
extends Resource

## Uma encomenda de pergaminho: quem pede, o que pede e o que o feitiço precisa
## fazer para ser aceito. Edite pelo Inspector do Godot.

## Identificador estável (não muda com o texto); usado em outcomes e nos testes.
@export var id := ""

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
## Natureza do pedido (ex.: "offensive", "mind") para regras HAS_TAG. O jogador
## não vê as etiquetas: deduz pelo item e pelos detalhes. Se o pedido é legal
## ou não depende das regras do dia (AtelierShopDay.violated_rules).
@export var tags: PackedStringArray = []

@export_group("Feitiço")
## O que o pergaminho precisa fazer, em linguagem de jogador.
@export_multiline var spec := ""
## Casos mostrados ao jogador na bancada. Formato:
## {"memory": {0: 5}, "output": ["15"]}; a memória semeia READ/LOAD.
@export var examples: Array[Dictionary] = []
## Casos conferidos só na entrega, no mesmo formato. Pedidos com entradas devem
## ter pelo menos um, para que decorar a resposta dos exemplos não baste.
@export var hidden_tests: Array[Dictionary] = []
## Limite de passos da VM por caso; acima disso o feitiço é considerado em laço.
@export var max_steps := 2000
## Rascunho já desenhado na bancada ao abrir a encomenda (e ao reiniciar).
## Cada célula: {"from": Vector2, "to": Vector2, "symbol": "ORB", "intensity": 128}.
@export var starting_ritual: Array[Dictionary] = []
## Quantidade de runas para ganhar o bônus de trabalho elegante (0 = sem bônus).
@export var par_runes := 0
@export var reward := 10

@export_group("Consequências")
## Além da regra geral (pagamento, reputação), o que acontece em cada decisão.
@export var on_delivered: Array[AtelierConsequence] = []
@export var on_rejected: Array[AtelierConsequence] = []
## Aprovado, mas o jogador desistiu de escrever o pergaminho.
@export var on_abandoned: Array[AtelierConsequence] = []

@export_group("Variantes")
## Todas precisam valer para este cliente aparecer. Vazio = sempre aparece.
@export var conditions: Array[AtelierFlagCondition] = []
## Versões alternativas deste cliente (outros AtelierScrollOrder), testadas em
## ordem antes dele; a primeira cujas condições valem toma o seu lugar. As
## variantes das variantes são ignoradas. Veja AtelierShopDay.resolve_customer.
## Tipado como Resource de propósito: se este script citar a própria classe, o
## GDScript cria um ciclo de referência e o script vaza ao fechar o jogo.
@export var variants: Array[Resource] = []


## Campos que o jogador pode inspecionar no formulário, na ordem em que aparecem.
const INSPECTABLE_FIELDS: Array[String] = ["item", "name", "age", "race", "signature", "details"]
const FIELD_LABELS := {"item": "Item", "name": "Name", "age": "Age", "race": "Race", "signature": "Signature", "details": "Details"}


func field_value(field_name: String) -> String:
	match field_name:
		"item":
			return item
		"name":
			return client_name
		"age":
			return age
		"race":
			return race
		"signature":
			return signature
		"details":
			return details
		_:
			return ""


func conditions_met(flags: Dictionary) -> bool:
	for condition in conditions:
		if not condition.is_met(flags):
			return false
	return true


## Exemplos primeiro, depois os ocultos; cada caso marcado com "hidden".
func all_tests() -> Array[Dictionary]:
	var tests: Array[Dictionary] = []
	for example in examples:
		var visible_case := example.duplicate(true)
		visible_case["hidden"] = false
		tests.append(visible_case)
	for hidden_test in hidden_tests:
		var hidden_case := hidden_test.duplicate(true)
		hidden_case["hidden"] = true
		tests.append(hidden_case)
	return tests


## Memória do primeiro exemplo: é a que o ▶ da bancada usa na prévia.
func preview_memory() -> Dictionary:
	return examples[0].get("memory", {}) if not examples.is_empty() else {}
