class_name AtelierConsequence
extends Resource

## Efeito de uma decisão do jogador, descrito como dado. As encomendas listam
## consequências em on_delivered / on_rejected / on_abandoned, e o GameState
## as aplica na hora ou as agenda para uma manhã futura.

## 0 = aplica na hora da decisão; 1 = na manhã seguinte; 2 = dois dias depois...
@export var delay_days := 1
## Manchete do jornal da manhã em que a consequência chega. Ignorada quando
## delay_days é 0, pois não há jornal no meio do expediente.
@export_multiline var headline := ""
## Linha do livro-caixa. Pode ficar vazia se não mexer em dinheiro/reputação.
@export var ledger_text := ""
@export var money := 0
@export var reputation := 0
## Somado às flags do GameState, ex.: {"guild_suspicion": 2}.
@export var flag_changes: Dictionary[String, int] = {}
