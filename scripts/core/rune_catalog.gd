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


static func symbol_data(kind: String) -> Dictionary:
	for raw_symbol in SYMBOLS:
		var symbol: Dictionary = raw_symbol
		if str(symbol["kind"]) == kind:
			return symbol.duplicate(true)
	return {"kind": kind, "label": kind, "description": "Unknown rune.", "extra": "", "opcode": -1, "takes_operand": false, "result_type": ""}


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
