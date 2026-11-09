extends RefCounted

## Regra unica de destinos para a VM e a analise estatica do NASM.
## A procura nao executa runas nem altera o programa. Destinos invalidos sao
## diagnosticados pelo compilador ou pela execucao, nao por este resolvedor.

const RuneCatalog = preload("res://scripts/core/rune_catalog.gd")


static func resolve(instructions: Array) -> Dictionary:
	var warp_groups := {}
	var endpoint_groups := {}
	var conditional_groups := {}
	for index in range(instructions.size()):
		var instruction: Dictionary = instructions[index]
		var opcode := int(instruction["opcode"])
		var groups: Dictionary
		match opcode:
			RuneCatalog.OPCODE_WARP, RuneCatalog.OPCODE_WARP_FRAGILE:
				groups = warp_groups
			RuneCatalog.OPCODE_WARP_ENDPOINT:
				groups = endpoint_groups
			RuneCatalog.OPCODE_JUMP_IF_TRUE:
				groups = conditional_groups
			_:
				continue
		var intensity := int(instruction.get("operand", instruction.get("intensity", 0)))
		var members: Array = groups.get(intensity, [])
		members.append(index)
		groups[intensity] = members
	var warp_targets := {}
	var conditional_targets := {}
	var endpoint_counts := {}
	for intensity in endpoint_groups:
		endpoint_counts[intensity] = (endpoint_groups[intensity] as Array).size()
	for intensity in warp_groups:
		var warps: Array = warp_groups[intensity]
		var endpoints: Array = endpoint_groups.get(intensity, [])
		if endpoints.size() == 1:
			for source in warps:
				warp_targets[int(source)] = int(endpoints[0]) + 1
		elif warps.size() >= 2:
			for group_index in range(warps.size()):
				warp_targets[int(warps[group_index])] = int(warps[(group_index + 1) % warps.size()]) + 1
	for intensity in conditional_groups:
		var conditionals: Array = conditional_groups[intensity]
		var endpoints: Array = endpoint_groups.get(intensity, [])
		var warps: Array = warp_groups.get(intensity, [])
		for source in conditionals:
			if endpoints.size() == 1:
				conditional_targets[int(source)] = int(endpoints[0]) + 1
			elif not warps.is_empty():
				conditional_targets[int(source)] = _next_warp(int(source), warps) + 1
	return {
		"warp": warp_targets,
		"conditional": conditional_targets,
		"endpoint_counts": endpoint_counts,
	}


static func _next_warp(source_index: int, warps: Array) -> int:
	for destination in warps:
		if int(destination) > source_index:
			return int(destination)
	return int(warps[0])
