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

const BINARY_OPCODES := [
	OPCODE_ADD, OPCODE_SUB, OPCODE_MUL, OPCODE_DIV, OPCODE_MOD,
	OPCODE_EQ, OPCODE_NEQ, OPCODE_LT, OPCODE_GT, OPCODE_LTE, OPCODE_GTE,
	OPCODE_AND, OPCODE_OR,
]
const INTENSITY_OPERATIONS := [
	OPCODE_ADD, OPCODE_SUB, OPCODE_MUL, OPCODE_DIV, OPCODE_MOD, OPCODE_NEG,
]
const STACK_READ_OPCODES := [
	OPCODE_DROP, OPCODE_DUP, OPCODE_NEG, OPCODE_NOT, OPCODE_PRINT,
	OPCODE_STORE, OPCODE_JUMP_IF_TRUE,
]
const STACK_PUSH_OPCODES := [OPCODE_PUSH, OPCODE_DUP, OPCODE_LOAD, OPCODE_READ]

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
	{"kind": "READ", "label": "READ", "description": "Empilha a memória no endereço indicado pela intensidade.", "extra": "memória", "opcode": OPCODE_READ, "takes_operand": true, "result_type": "int"}
]

static var _symbols_by_kind: Dictionary = {}
static var _symbols_by_opcode: Dictionary = {}


static func _ensure_indexes() -> void:
	if not _symbols_by_opcode.is_empty():
		return
	for symbol in SYMBOLS:
		_symbols_by_kind[str(symbol["kind"])] = symbol
		_symbols_by_opcode[int(symbol["opcode"])] = symbol


static func symbol_data(kind: String) -> Dictionary:
	_ensure_indexes()
	if _symbols_by_kind.has(kind):
		return (_symbols_by_kind[kind] as Dictionary).duplicate(true)
	return {"kind": kind, "label": kind, "description": "Símbolo desconhecido.", "extra": "", "opcode": -1, "takes_operand": false, "result_type": ""}


static func symbol_for_opcode(opcode: int) -> Dictionary:
	return _opcode_metadata(opcode).duplicate(true)


static func _opcode_metadata(opcode: int) -> Dictionary:
	_ensure_indexes()
	return _symbols_by_opcode.get(opcode, {})


static func opcode_for_kind(kind: String) -> int:
	_ensure_indexes()
	return int((_symbols_by_kind.get(kind, {}) as Dictionary).get("opcode", -1))


static func takes_operand(opcode: int) -> bool:
	return bool(_opcode_metadata(opcode).get("takes_operand", false))


## Metadado extensível: runas futuras só precisam declarar result_type: "int".
static func produces_value_type(opcode: int, value_type: String) -> bool:
	return str(_opcode_metadata(opcode).get("result_type", "")) == value_type


static func name_for_opcode(opcode: int) -> String:
	return str(_opcode_metadata(opcode).get("label", "UNKNOWN"))


static func is_known_opcode(opcode: int) -> bool:
	_ensure_indexes()
	return _symbols_by_opcode.has(opcode)


static func required_stack_depth(opcode: int) -> int:
	if opcode == OPCODE_SWAP or opcode in BINARY_OPCODES:
		return 2
	return 1 if opcode in STACK_READ_OPCODES else 0


static func stack_delta(opcode: int) -> int:
	if opcode in STACK_PUSH_OPCODES:
		return 1
	if opcode in [OPCODE_DROP, OPCODE_STORE] or opcode in BINARY_OPCODES:
		return -1
	return 0
