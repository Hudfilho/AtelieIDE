class_name AtelierRuneCatalog
extends RefCounted

## Catálogo único dos selos. A interface, o compilador e a VM usam esta tabela.

const OPCODE_PUSH := 0x01
const OPCODE_ADD := 0x02
const OPCODE_SUB := 0x03
const OPCODE_MUL := 0x04
const OPCODE_PRINT := 0x05
const OPCODE_HALT := 0x06
const OPCODE_STORE := 0x07
const OPCODE_LOAD := 0x08

const SYMBOLS := [
	{"kind": "ORB", "label": "PUSH", "description": "Coloca a intensidade na pilha.", "extra": "valor", "opcode": OPCODE_PUSH, "takes_operand": true},
	{"kind": "DIAMOND", "label": "ADD", "description": "Soma os dois valores do topo.", "extra": "operação: +", "opcode": OPCODE_ADD, "takes_operand": false},
	{"kind": "TRIANGLE", "label": "PRINT", "description": "Mostra o valor do topo no oráculo.", "extra": "saída", "opcode": OPCODE_PRINT, "takes_operand": false},
	{"kind": "CROSS", "label": "HALT", "description": "Encerra a execução do ritual.", "extra": "fim", "opcode": OPCODE_HALT, "takes_operand": false},
	{"kind": "MOON", "label": "SUB", "description": "Subtrai o segundo valor do primeiro.", "extra": "operação: −", "opcode": OPCODE_SUB, "takes_operand": false},
	{"kind": "PLUS", "label": "MUL", "description": "Multiplica os dois valores do topo.", "extra": "operação: ×", "opcode": OPCODE_MUL, "takes_operand": false},
	{"kind": "SQUARE", "label": "STORE", "description": "Guarda o topo em uma posição de memória.", "extra": "memória", "opcode": OPCODE_STORE, "takes_operand": true},
	{"kind": "FORK", "label": "LOAD", "description": "Lê uma posição de memória para a pilha.", "extra": "memória", "opcode": OPCODE_LOAD, "takes_operand": true}
]


static func symbol_data(kind: String) -> Dictionary:
	for raw_symbol in SYMBOLS:
		var symbol: Dictionary = raw_symbol
		if str(symbol["kind"]) == kind:
			return symbol.duplicate(true)
	return {"kind": kind, "label": kind, "description": "Símbolo desconhecido.", "extra": "", "opcode": -1, "takes_operand": false}


static func symbol_for_opcode(opcode: int) -> Dictionary:
	for raw_symbol in SYMBOLS:
		var symbol: Dictionary = raw_symbol
		if int(symbol["opcode"]) == opcode:
			return symbol.duplicate(true)
	return {}


static func opcode_for_kind(kind: String) -> int:
	return int(symbol_data(kind).get("opcode", -1))


static func takes_operand(opcode: int) -> bool:
	return bool(symbol_for_opcode(opcode).get("takes_operand", false))


static func name_for_opcode(opcode: int) -> String:
	return str(symbol_for_opcode(opcode).get("label", "UNKNOWN"))
