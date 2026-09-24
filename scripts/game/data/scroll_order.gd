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
## Manchete do jornal do dia seguinte se o pedido ilegal for entregue.
@export_multiline var consequence_news := ""
@export var consequence_reputation := 0
@export var consequence_money := 0


func is_legal() -> bool:
	return violations.is_empty()


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
