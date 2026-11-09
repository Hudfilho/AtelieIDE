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
# Runas mágicas (modo jogo): empilham propriedades na pilha mágica ao executar.
const OPCODE_FIRE := 0x1f
const OPCODE_PROJECTILE := 0x20
const OPCODE_EXPLOSION := 0x21
# APLICAR (modo jogo): tira o topo da pilha e o usa como intensidade da próxima runa.
const OPCODE_INT_APPLY := 0x22
# DUPLICAR (modo jogo): a próxima instrução executa mais uma vez.
const OPCODE_DUPLICATE := 0x23
const OPCODE_ICE := 0x24
const OPCODE_LIGHTNING := 0x25
# PORTAL FRÁGIL (modo jogo): um WARP que quebra depois de alguns saltos.
const OPCODE_WARP_FRAGILE := 0x26
const WARP_OPCODES := [OPCODE_WARP, OPCODE_WARP_FRAGILE]
# Runas de ação dos microjogos (Atelier Ware): como as mágicas, vão para a
# pilha mágica ao executar; cada microjogo decide o que fazem.
const OPCODE_MOVE_UP := 0x30
const OPCODE_MOVE_DOWN := 0x31
const OPCODE_MOVE_LEFT := 0x32
const OPCODE_MOVE_RIGHT := 0x33
const OPCODE_JUMP := 0x34
const OPCODE_PAINT := 0x35
const OPCODE_BELL := 0x36
const OPCODE_TURN := 0x37
const OPCODE_SHOOT := 0x38
const OPCODE_AIM := 0x39
const ACTION_OPCODES := [
	OPCODE_MOVE_UP, OPCODE_MOVE_DOWN, OPCODE_MOVE_LEFT, OPCODE_MOVE_RIGHT, OPCODE_JUMP,
	OPCODE_PAINT, OPCODE_BELL, OPCODE_TURN, OPCODE_SHOOT, OPCODE_AIM,
]
const MAGIC_OPCODES := [OPCODE_FIRE, OPCODE_PROJECTILE, OPCODE_EXPLOSION, OPCODE_ICE, OPCODE_LIGHTNING]
const GAME_ONLY_OPCODES := [OPCODE_FIRE, OPCODE_PROJECTILE, OPCODE_EXPLOSION, OPCODE_ICE, OPCODE_LIGHTNING, OPCODE_INT_APPLY, OPCODE_DUPLICATE, OPCODE_WARP_FRAGILE]

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
	OPCODE_STORE, OPCODE_JUMP_IF_TRUE, OPCODE_INT_APPLY,
]
const STACK_PUSH_OPCODES := [OPCODE_PUSH, OPCODE_DUP, OPCODE_LOAD, OPCODE_READ]

## "description" e "extra" são chaves de tradução (localization/strings.csv).
const SYMBOLS := [
	{"kind": "ORB", "label": "PUSH", "description": "RUNE_ORB_DESC", "extra": "RUNE_ORB_EXTRA", "opcode": OPCODE_PUSH, "takes_operand": true, "result_type": "int"},
	{"kind": "CUP", "label": "DROP", "description": "RUNE_CUP_DESC", "extra": "RUNE_CUP_EXTRA", "opcode": OPCODE_DROP, "takes_operand": false},
	{"kind": "TWIN", "label": "DUP", "description": "RUNE_TWIN_DESC", "extra": "RUNE_TWIN_EXTRA", "opcode": OPCODE_DUP, "takes_operand": false, "result_type": "int"},
	{"kind": "KNOT", "label": "SWAP", "description": "RUNE_KNOT_DESC", "extra": "RUNE_KNOT_EXTRA", "opcode": OPCODE_SWAP, "takes_operand": false},
	{"kind": "DIAMOND", "label": "ADD", "description": "RUNE_DIAMOND_DESC", "extra": "RUNE_DIAMOND_EXTRA", "opcode": OPCODE_ADD, "takes_operand": false, "result_type": "int"},
	{"kind": "MOON", "label": "SUB", "description": "RUNE_MOON_DESC", "extra": "RUNE_MOON_EXTRA", "opcode": OPCODE_SUB, "takes_operand": false, "result_type": "int"},
	{"kind": "PLUS", "label": "MUL", "description": "RUNE_PLUS_DESC", "extra": "RUNE_PLUS_EXTRA", "opcode": OPCODE_MUL, "takes_operand": false, "result_type": "int"},
	{"kind": "SLASH", "label": "DIV", "description": "RUNE_SLASH_DESC", "extra": "RUNE_SLASH_EXTRA", "opcode": OPCODE_DIV, "takes_operand": false, "result_type": "int"},
	{"kind": "SPIRAL", "label": "MOD", "description": "RUNE_SPIRAL_DESC", "extra": "RUNE_SPIRAL_EXTRA", "opcode": OPCODE_MOD, "takes_operand": false, "result_type": "int"},
	{"kind": "DASH", "label": "NEG", "description": "RUNE_DASH_DESC", "extra": "RUNE_DASH_EXTRA", "opcode": OPCODE_NEG, "takes_operand": false, "result_type": "int"},
	{"kind": "EQ", "label": "EQ", "description": "RUNE_EQ_DESC", "extra": "RUNE_EQ_EXTRA", "opcode": OPCODE_EQ, "takes_operand": false, "result_type": "int"},
	{"kind": "NEQ", "label": "NEQ", "description": "RUNE_NEQ_DESC", "extra": "RUNE_NEQ_EXTRA", "opcode": OPCODE_NEQ, "takes_operand": false, "result_type": "int"},
	{"kind": "LT", "label": "LT", "description": "RUNE_LT_DESC", "extra": "RUNE_LT_EXTRA", "opcode": OPCODE_LT, "takes_operand": false, "result_type": "int"},
	{"kind": "GT", "label": "GT", "description": "RUNE_GT_DESC", "extra": "RUNE_GT_EXTRA", "opcode": OPCODE_GT, "takes_operand": false, "result_type": "int"},
	{"kind": "LTE", "label": "LTE", "description": "RUNE_LTE_DESC", "extra": "RUNE_LTE_EXTRA", "opcode": OPCODE_LTE, "takes_operand": false, "result_type": "int"},
	{"kind": "GTE", "label": "GTE", "description": "RUNE_GTE_DESC", "extra": "RUNE_GTE_EXTRA", "opcode": OPCODE_GTE, "takes_operand": false, "result_type": "int"},
	{"kind": "NOT", "label": "NOT", "description": "RUNE_NOT_DESC", "extra": "RUNE_NOT_EXTRA", "opcode": OPCODE_NOT, "takes_operand": false, "result_type": "int"},
	{"kind": "AND", "label": "AND", "description": "RUNE_AND_DESC", "extra": "RUNE_AND_EXTRA", "opcode": OPCODE_AND, "takes_operand": false, "result_type": "int"},
	{"kind": "OR", "label": "OR", "description": "RUNE_OR_DESC", "extra": "RUNE_OR_EXTRA", "opcode": OPCODE_OR, "takes_operand": false, "result_type": "int"},
	{"kind": "WARP", "label": "WARP", "description": "RUNE_WARP_DESC", "extra": "RUNE_WARP_EXTRA", "opcode": OPCODE_WARP, "takes_operand": true},
	{"kind": "WARP_ENDPOINT", "label": "WARP END", "description": "RUNE_WARP_ENDPOINT_DESC", "extra": "RUNE_WARP_ENDPOINT_EXTRA", "opcode": OPCODE_WARP_ENDPOINT, "takes_operand": true},
	{"kind": "JUMP_IF_TRUE", "label": "JUMP_IF_TRUE", "description": "RUNE_JUMP_IF_TRUE_DESC", "extra": "RUNE_JUMP_IF_TRUE_EXTRA", "opcode": OPCODE_JUMP_IF_TRUE, "takes_operand": true},
	{"kind": "INT_MOD", "label": "INT_MOD", "description": "RUNE_INT_MOD_DESC", "extra": "RUNE_INT_MOD_EXTRA", "opcode": OPCODE_INT_MOD, "takes_operand": false},
	{"kind": "INT_SET", "label": "INT_SET", "description": "RUNE_INT_SET_DESC", "extra": "RUNE_INT_SET_EXTRA", "opcode": OPCODE_INT_SET, "takes_operand": false},
	{"kind": "TRIANGLE", "label": "PRINT", "description": "RUNE_TRIANGLE_DESC", "extra": "RUNE_TRIANGLE_EXTRA", "opcode": OPCODE_PRINT, "takes_operand": false},
	{"kind": "PRINTLETTER", "label": "PRINTLETTER", "description": "RUNE_PRINTLETTER_DESC", "extra": "RUNE_PRINTLETTER_EXTRA", "opcode": OPCODE_PRINTLETTER, "takes_operand": true},
	{"kind": "CROSS", "label": "HALT", "description": "RUNE_CROSS_DESC", "extra": "RUNE_CROSS_EXTRA", "opcode": OPCODE_HALT, "takes_operand": false},
	{"kind": "SQUARE", "label": "STORE", "description": "RUNE_SQUARE_DESC", "extra": "RUNE_SQUARE_EXTRA", "opcode": OPCODE_STORE, "takes_operand": true},
	{"kind": "FORK", "label": "LOAD", "description": "RUNE_FORK_DESC", "extra": "RUNE_FORK_EXTRA", "opcode": OPCODE_LOAD, "takes_operand": true, "result_type": "int"},
	{"kind": "READ", "label": "READ", "description": "RUNE_READ_DESC", "extra": "RUNE_READ_EXTRA", "opcode": OPCODE_READ, "takes_operand": true, "result_type": "int"}
]

## Runas mágicas ficam fora de SYMBOLS: o Sandbox, o atlas e o NASM continuam
## vendo só as 30 computacionais. Usam a intensidade, mas não produzem inteiro
## na pilha numérica (sem result_type), então nunca alimentam um INT_SET.
const MAGIC_SYMBOLS := [
	{"kind": "FIRE", "label": "FIRE", "description": "RUNE_FIRE_DESC", "extra": "", "opcode": OPCODE_FIRE, "takes_operand": false, "magic": true},
	{"kind": "PROJECTILE", "label": "PROJECTILE", "description": "RUNE_PROJECTILE_DESC", "extra": "", "opcode": OPCODE_PROJECTILE, "takes_operand": false, "magic": true},
	{"kind": "EXPLOSION", "label": "EXPLOSION", "description": "RUNE_EXPLOSION_DESC", "extra": "", "opcode": OPCODE_EXPLOSION, "takes_operand": false, "magic": true},
	{"kind": "ICE", "label": "ICE", "description": "RUNE_ICE_DESC", "extra": "", "opcode": OPCODE_ICE, "takes_operand": false, "magic": true},
	{"kind": "LIGHTNING", "label": "LIGHTNING", "description": "RUNE_LIGHTNING_DESC", "extra": "", "opcode": OPCODE_LIGHTNING, "takes_operand": false, "magic": true},
]
## Runas computacionais só do modo jogo (fora do Sandbox, do atlas e do NASM).
const ACTION_SYMBOLS := [
	{"kind": "MOVE_UP", "label": "UP", "description": "", "extra": "", "opcode": OPCODE_MOVE_UP, "takes_operand": false, "magic": true},
	{"kind": "MOVE_DOWN", "label": "DOWN", "description": "", "extra": "", "opcode": OPCODE_MOVE_DOWN, "takes_operand": false, "magic": true},
	{"kind": "MOVE_LEFT", "label": "LEFT", "description": "", "extra": "", "opcode": OPCODE_MOVE_LEFT, "takes_operand": false, "magic": true},
	{"kind": "MOVE_RIGHT", "label": "RIGHT", "description": "", "extra": "", "opcode": OPCODE_MOVE_RIGHT, "takes_operand": false, "magic": true},
	{"kind": "JUMP", "label": "JUMP", "description": "", "extra": "", "opcode": OPCODE_JUMP, "takes_operand": false, "magic": true},
	{"kind": "PAINT", "label": "PAINT", "description": "", "extra": "", "opcode": OPCODE_PAINT, "takes_operand": false, "magic": true},
	{"kind": "BELL", "label": "BELL", "description": "", "extra": "", "opcode": OPCODE_BELL, "takes_operand": false, "magic": true},
	{"kind": "TURN", "label": "TURN", "description": "", "extra": "", "opcode": OPCODE_TURN, "takes_operand": false, "magic": true},
	{"kind": "SHOOT", "label": "SHOOT", "description": "", "extra": "", "opcode": OPCODE_SHOOT, "takes_operand": false, "magic": true},
	{"kind": "AIM", "label": "AIM", "description": "", "extra": "", "opcode": OPCODE_AIM, "takes_operand": false, "magic": true},
]
const GAME_SYMBOLS := [
	{"kind": "INT_APPLY", "label": "APPLY", "description": "RUNE_INT_APPLY_DESC", "extra": "", "opcode": OPCODE_INT_APPLY, "takes_operand": false},
	{"kind": "DUPLICATE", "label": "DUPLICATE", "description": "RUNE_DUPLICATE_DESC", "extra": "", "opcode": OPCODE_DUPLICATE, "takes_operand": false},
	{"kind": "WARP_FRAGILE", "label": "FRAGILE WARP", "description": "RUNE_WARP_FRAGILE_DESC", "extra": "", "opcode": OPCODE_WARP_FRAGILE, "takes_operand": true},
]

static var _symbols_by_kind: Dictionary = {}
static var _symbols_by_opcode: Dictionary = {}


static func _ensure_indexes() -> void:
	if not _symbols_by_opcode.is_empty():
		return
	for symbol in SYMBOLS + MAGIC_SYMBOLS + GAME_SYMBOLS + ACTION_SYMBOLS:
		_symbols_by_kind[str(symbol["kind"])] = symbol
		_symbols_by_opcode[int(symbol["opcode"])] = symbol


static func symbol_data(kind: String) -> Dictionary:
	_ensure_indexes()
	if _symbols_by_kind.has(kind):
		return (_symbols_by_kind[kind] as Dictionary).duplicate(true)
	return {"kind": kind, "label": kind, "description": "Unknown rune.", "extra": "", "opcode": -1, "takes_operand": false, "result_type": ""}


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


## Mágicas e ações: executar empilha uma entrada na pilha mágica.
static func is_magic(opcode: int) -> bool:
	return opcode in MAGIC_OPCODES or opcode in ACTION_OPCODES


## WARP e PORTAL FRÁGIL seguem a mesma regra de destinos.
static func is_warp(opcode: int) -> bool:
	return opcode in WARP_OPCODES


static func is_game_only(opcode: int) -> bool:
	return opcode in GAME_ONLY_OPCODES or opcode in ACTION_OPCODES


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
	if opcode in [OPCODE_DROP, OPCODE_STORE, OPCODE_INT_APPLY] or opcode in BINARY_OPCODES:
		return -1
	return 0
