class_name AtelierRuneBytecode
extends RefCounted

## Formato binário do Atelier: "RUNE" + versão + quantidade + instruções.
## Cada instrução carrega opcode e intensidade. Quando a instrução recebe
## operando, a intensidade também é o seu valor numérico.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")

const MAGIC := [0x52, 0x55, 0x4e, 0x45] # RUNE
const VERSION := 2
const HEADER_SIZE := 7
const MAX_INSTRUCTIONS := 65535


static func encode(instructions: Array) -> PackedByteArray:
	# A contagem ocupa 16 bits. Nunca emitir um cabecalho truncado com corpo maior.
	if instructions.size() > MAX_INSTRUCTIONS:
		return PackedByteArray()
	var bytes := PackedByteArray()
	for value in MAGIC:
		bytes.append(value)
	bytes.append(VERSION)
	var count := instructions.size()
	bytes.append(count & 0xff)
	bytes.append((count >> 8) & 0xff)
	for instruction in instructions:
		var opcode := int(instruction.get("opcode", 0))
		bytes.append(opcode & 0xff)
		var intensity := clampi(int(instruction.get("intensity", instruction.get("operand", 0))), 0, 255)
		bytes.append(intensity)
	return bytes


static func decode(bytes: PackedByteArray) -> Dictionary:
	var errors: Array[String] = []
	if bytes.size() < HEADER_SIZE:
		return {"ok": false, "errors": ["Binary is shorter than the RUNE header."]}  # dev-only
	for index in range(MAGIC.size()):
		if bytes[index] != MAGIC[index]:
			return {"ok": false, "errors": ["Invalid RUNE signature."]}  # dev-only
	if bytes[4] != VERSION:
		return {"ok": false, "errors": ["Unsupported bytecode version."]}  # dev-only
	var instruction_count := bytes[5] | (bytes[6] << 8)
	var cursor := HEADER_SIZE
	var instructions: Array[Dictionary] = []
	for _index in range(instruction_count):
		if cursor >= bytes.size():
			errors.append("The bytecode ended before the last instruction.")  # dev-only
			break
		var opcode := bytes[cursor]
		cursor += 1
		if not RuneCatalog.is_known_opcode(opcode):
			errors.append("Unknown opcode: 0x%02X." % opcode)  # dev-only
			break
		if cursor >= bytes.size():
			errors.append("Missing intensity for %s." % RuneCatalog.name_for_opcode(opcode))  # dev-only
			break
		var intensity := bytes[cursor]
		cursor += 1
		var instruction := {"opcode": opcode, "intensity": intensity}
		if RuneCatalog.takes_operand(opcode):
			instruction["operand"] = intensity
		instructions.append(instruction)
	if errors.is_empty() and cursor != bytes.size():
		errors.append("Trailing bytes after the declared instructions.")  # dev-only
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {"ok": true, "instructions": instructions}
