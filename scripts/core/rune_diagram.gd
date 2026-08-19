class_name AtelierRuneDiagram
extends RefCounted

## Estado puro do diagrama: conexões, intensidade e histórico.
## Não conhece UI, desenhos ou entrada do mouse.

var connections: Array[Dictionary] = []
var undo_history: Array = []
var redo_history: Array = []


func snapshot() -> Array:
	return connections.duplicate(true)


func restore(snapshot_data: Array) -> void:
	connections.clear()
	for raw_connection in snapshot_data:
		connections.append(raw_connection.duplicate(true))


func record_current_state() -> void:
	record_undo_snapshot(snapshot())


func record_undo_snapshot(snapshot_data: Array) -> void:
	undo_history.append(snapshot_data.duplicate(true))
	redo_history.clear()


func add_connection(from: Vector2, to: Vector2) -> bool:
	if from.is_equal_approx(to):
		return false
	for connection in connections:
		var connection_from: Vector2 = connection["from"]
		var connection_to: Vector2 = connection["to"]
		var same_direction := connection_from.is_equal_approx(from) and connection_to.is_equal_approx(to)
		var opposite_direction := connection_from.is_equal_approx(to) and connection_to.is_equal_approx(from)
		if same_direction or opposite_direction:
			return false
	record_current_state()
	connections.append({"from": from, "to": to, "symbol": "", "intensity": 128})
	return true


func remove_connections(indices: Array[int]) -> bool:
	var valid_indices: Array[int] = []
	for raw_index in indices:
		var index := int(raw_index)
		if _has_connection(index) and not valid_indices.has(index):
			valid_indices.append(index)
	if valid_indices.is_empty():
		return false
	valid_indices.sort()
	record_current_state()
	for position in range(valid_indices.size() - 1, -1, -1):
		connections.remove_at(valid_indices[position])
	return true


func set_symbol(index: int, symbol: String, record_history := true) -> bool:
	if not _has_connection(index):
		return false
	var connection: Dictionary = connections[index]
	if str(connection.get("symbol", "")) == symbol:
		return false
	if record_history:
		record_current_state()
	connection["symbol"] = symbol
	connections[index] = connection
	return true


func set_intensity(index: int, intensity: int, record_history := true) -> bool:
	if not _has_connection(index):
		return false
	var connection: Dictionary = connections[index]
	var clamped_intensity := clampi(intensity, 0, 255)
	if int(connection.get("intensity", 128)) == clamped_intensity:
		return false
	if record_history:
		record_current_state()
	connection["intensity"] = clamped_intensity
	connections[index] = connection
	return true


func undo() -> bool:
	if undo_history.is_empty():
		return false
	redo_history.append(snapshot())
	restore(undo_history.pop_back())
	return true


func redo() -> bool:
	if redo_history.is_empty():
		return false
	undo_history.append(snapshot())
	restore(redo_history.pop_back())
	return true


func _has_connection(index: int) -> bool:
	return index >= 0 and index < connections.size()
