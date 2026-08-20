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
const OPCODE_DROP := 0x09
const OPCODE_DUP := 0x0a
const OPCODE_SWAP := 0x0b
const OPCODE_DIV := 0x0c
const OPCODE_MOD := 0x0d
const OPCODE_NEG := 0x0e
const OPCODE_WARP := 0x0f
const OPCODE_INT_MOD := 0x10
const OPCODE_INT_SET := 0x11
const OPCODE_EQ := 0x12
const OPCODE_NEQ := 0x13
const OPCODE_LT := 0x14
const OPCODE_GT := 0x15
const OPCODE_LTE := 0x16
const OPCODE_GTE := 0x17
const OPCODE_NOT := 0x18
const OPCODE_AND := 0x19
const OPCODE_OR := 0x1a
const OPCODE_WARP_ENDPOINT := 0x1b
const OPCODE_PRINTLETTER := 0x1c
const OPCODE_JUMP_IF_TRUE := 0x1d
const OPCODE_READ := 0x1e

const SYMBOLS := [
	{"kind": "ORB", "label": "PUSH", "description": "Coloca a intensidade na pilha.", "extra": "valor", "opcode": OPCODE_PUSH, "takes_operand": true, "result_type": "int"},
	{"kind": "CUP", "label": "DROP", "description": "Descarta o valor no topo da pilha.", "extra": "pilha: −1", "opcode": OPCODE_DROP, "takes_operand": false},
	{"kind": "TWIN", "label": "DUP", "description": "Duplica o valor no topo da pilha.", "extra": "pilha: +1", "opcode": OPCODE_DUP, "takes_operand": false, "result_type": "int"},
	{"kind": "KNOT", "label": "SWAP", "description": "Troca os dois valores no topo da pilha.", "extra": "pilha: ↔", "opcode": OPCODE_SWAP, "takes_operand": false},
	{"kind": "DIAMOND", "label": "ADD", "description": "Soma os dois valores do topo.", "extra": "operação: +", "opcode": OPCODE_ADD, "takes_operand": false, "result_type": "int"},
	{"kind": "MOON", "label": "SUB", "description": "Subtrai o valor do topo do penúltimo valor.", "extra": "operação: −", "opcode": OPCODE_SUB, "takes_operand": false, "result_type": "int"},
	{"kind": "PLUS", "label": "MUL", "description": "Multiplica os dois valores do topo.", "extra": "operação: ×", "opcode": OPCODE_MUL, "takes_operand": false, "result_type": "int"},
	{"kind": "SLASH", "label": "DIV", "description": "Divide o penúltimo valor pelo valor no topo da pilha.", "extra": "operação: ÷", "opcode": OPCODE_DIV, "takes_operand": false, "result_type": "int"},
	{"kind": "SPIRAL", "label": "MOD", "description": "Calcula o resto da divisão entre os dois valores do topo.", "extra": "operação: %", "opcode": OPCODE_MOD, "takes_operand": false, "result_type": "int"},
	{"kind": "DASH", "label": "NEG", "description": "Inverte o sinal do valor no topo da pilha.", "extra": "operação: −x", "opcode": OPCODE_NEG, "takes_operand": false, "result_type": "int"},
	{"kind": "EQ", "label": "EQ", "description": "Compara igualdade e coloca 1 ou 0 na pilha.", "extra": "operação: ==", "opcode": OPCODE_EQ, "takes_operand": false, "result_type": "int"},
	{"kind": "NEQ", "label": "NEQ", "description": "Compara diferença e coloca 1 ou 0 na pilha.", "extra": "operação: !=", "opcode": OPCODE_NEQ, "takes_operand": false, "result_type": "int"},
	{"kind": "LT", "label": "LT", "description": "Verifica se o penúltimo valor é menor que o topo.", "extra": "operação: <", "opcode": OPCODE_LT, "takes_operand": false, "result_type": "int"},
	{"kind": "GT", "label": "GT", "description": "Verifica se o penúltimo valor é maior que o topo.", "extra": "operação: >", "opcode": OPCODE_GT, "takes_operand": false, "result_type": "int"},
	{"kind": "LTE", "label": "LTE", "description": "Verifica se o penúltimo valor é menor ou igual ao topo.", "extra": "operação: <=", "opcode": OPCODE_LTE, "takes_operand": false, "result_type": "int"},
	{"kind": "GTE", "label": "GTE", "description": "Verifica se o penúltimo valor é maior ou igual ao topo.", "extra": "operação: >=", "opcode": OPCODE_GTE, "takes_operand": false, "result_type": "int"},
	{"kind": "NOT", "label": "NOT", "description": "Inverte um booleano: 1 vira 0 e 0 vira 1.", "extra": "lógica: não", "opcode": OPCODE_NOT, "takes_operand": false, "result_type": "int"},
	{"kind": "AND", "label": "AND", "description": "Combina dois booleanos com E.", "extra": "lógica: e", "opcode": OPCODE_AND, "takes_operand": false, "result_type": "int"},
	{"kind": "OR", "label": "OR", "description": "Combina dois booleanos com OU.", "extra": "lógica: ou", "opcode": OPCODE_OR, "takes_operand": false, "result_type": "int"},
	{"kind": "WARP", "label": "WARP", "description": "Salta para outro WARP com a mesma intensidade.", "extra": "portal", "opcode": OPCODE_WARP, "takes_operand": true},
	{"kind": "WARP_ENDPOINT", "label": "WARP END", "description": "Destino de todos os WARP com a mesma intensidade.", "extra": "portal destino", "opcode": OPCODE_WARP_ENDPOINT, "takes_operand": true},
	{"kind": "JUMP_IF_TRUE", "label": "JUMP_IF_TRUE", "description": "Se o topo da pilha for 001, salta pelo WARP da mesma intensidade.", "extra": "salto condicional", "opcode": OPCODE_JUMP_IF_TRUE, "takes_operand": true},
	{"kind": "INT_MOD", "label": "INT_MOD", "description": "Modifica a intensidade do selo seguinte com uma operação matemática.", "extra": "controle", "opcode": OPCODE_INT_MOD, "takes_operand": false},
	{"kind": "INT_SET", "label": "INT_SET", "description": "Espera o próximo inteiro e aplica-o ao selo seguinte.", "extra": "controle", "opcode": OPCODE_INT_SET, "takes_operand": false},
	{"kind": "TRIANGLE", "label": "PRINT", "description": "Mostra o valor do topo no oráculo.", "extra": "saída", "opcode": OPCODE_PRINT, "takes_operand": false},
	{"kind": "PRINTLETTER", "label": "PRINTLETTER", "description": "Mostra o caractere Unicode da intensidade (032 = espaço).", "extra": "caractere", "opcode": OPCODE_PRINTLETTER, "takes_operand": true},
	{"kind": "CROSS", "label": "HALT", "description": "Encerra a execução do ritual.", "extra": "fim", "opcode": OPCODE_HALT, "takes_operand": false},
	{"kind": "SQUARE", "label": "STORE", "description": "Guarda o topo em uma posição de memória.", "extra": "memória", "opcode": OPCODE_STORE, "takes_operand": true},
	{"kind": "FORK", "label": "LOAD", "description": "Lê uma posição de memória indicada pela intensidade para a pilha.", "extra": "memória", "opcode": OPCODE_LOAD, "takes_operand": true, "result_type": "int"},
	{"kind": "READ", "label": "READ", "description": "Usa o topo como endereço e empilha a memória sem remover o endereço.", "extra": "leitura indireta", "opcode": OPCODE_READ, "takes_operand": false, "result_type": "int"}
]


static func symbol_data(kind: String) -> Dictionary:
	for raw_symbol in SYMBOLS:
		var symbol: Dictionary = raw_symbol
		if str(symbol["kind"]) == kind:
			return symbol.duplicate(true)
	return {"kind": kind, "label": kind, "description": "Símbolo desconhecido.", "extra": "", "opcode": -1, "takes_operand": false, "result_type": ""}


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


## Metadado extensível: runas futuras só precisam declarar result_type: "int".
static func produces_value_type(opcode: int, value_type: String) -> bool:
	return str(symbol_for_opcode(opcode).get("result_type", "")) == value_type


static func name_for_opcode(opcode: int) -> String:
	return str(symbol_for_opcode(opcode).get("label", "UNKNOWN"))
