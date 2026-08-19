class_name AtelierRuneBytecode
extends RefCounted

## Formato binário do Atelier: "RUNE" + versão + quantidade + instruções.
## Cada instrução carrega opcode e intensidade. Quando a instrução recebe
## operando, a intensidade também é o seu valor numérico.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")

const MAGIC := [0x52, 0x55, 0x4e, 0x45] # RUNE
const VERSION := 2
const HEADER_SIZE := 7


static func encode(instructions: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	for value in MAGIC:
		bytes.append(value)
	bytes.append(VERSION)
	var count := mini(instructions.size(), 65535)
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
		return {"ok": false, "errors": ["Binário menor que o cabeçalho RUNE."]}
	for index in range(MAGIC.size()):
		if bytes[index] != MAGIC[index]:
			return {"ok": false, "errors": ["Assinatura RUNE inválida."]}
	if bytes[4] != VERSION:
		return {"ok": false, "errors": ["Versão de bytecode não suportada."]}
	var instruction_count := bytes[5] | (bytes[6] << 8)
	var cursor := HEADER_SIZE
	var instructions: Array[Dictionary] = []
	for _index in range(instruction_count):
		if cursor >= bytes.size():
			errors.append("O bytecode terminou antes da última instrução.")
			break
		var opcode := bytes[cursor]
		cursor += 1
		if RuneCatalog.symbol_for_opcode(opcode).is_empty():
			errors.append("Opcode desconhecido: 0x%02X." % opcode)
			break
		if cursor >= bytes.size():
			errors.append("Intensidade ausente para %s." % RuneCatalog.name_for_opcode(opcode))
			break
		var intensity := bytes[cursor]
		cursor += 1
		var instruction := {"opcode": opcode, "intensity": intensity}
		if RuneCatalog.takes_operand(opcode):
			instruction["operand"] = intensity
		instructions.append(instruction)
	if not errors.is_empty():
		return {"ok": false, "errors": errors}
	return {"ok": true, "instructions": instructions}
