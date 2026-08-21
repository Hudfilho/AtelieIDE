class_name AtelierExecutionLog
extends RefCounted

## Modelo observavel da saida de uma execucao.
##
## A VM e o compilador escrevem aqui; os paineis apenas observam os sinais.
## Isso evita acoplar o estado da execucao a uma implementacao visual e impede
## que o texto inteiro seja medido e redesenhado a cada frame.

enum Kind {
	OUTPUT,
	WARNING,
	ERROR,
}

signal cleared
signal entry_added(kind: int, text: String)
signal compacted

const OUTPUT_CHUNK_SIZE := 1024
const MAX_OUTPUT_CHARACTERS := 131072
const OUTPUT_TRIM_BATCH := 8192
const MAX_DIAGNOSTICS_PER_KIND := 2048
const MAX_ENTRY_COUNT := 4096
const ENTRY_TRIM_BATCH := 512

var _entries: Array[Dictionary] = []
var _output_length := 0
var _output_cache := ""
var _output_cache_dirty := false
var _warnings: Array[String] = []
var _errors: Array[String] = []


func clear() -> void:
	_entries.clear()
	_output_length = 0
	_output_cache = ""
	_output_cache_dirty = false
	_warnings.clear()
	_errors.clear()
	cleared.emit()


func append_output(text: String) -> void:
	if text.is_empty():
		return
	_append_output_chunks(text)
	entry_added.emit(Kind.OUTPUT, text)
	if _trim_output_if_needed() or _trim_entries_if_needed():
		compacted.emit()


func append_warning(text: String) -> void:
	if text.is_empty():
		return
	_warnings.append(text)
	if _warnings.size() > MAX_DIAGNOSTICS_PER_KIND:
		_warnings.pop_front()
	_entries.append(_make_entry(Kind.WARNING, text))
	entry_added.emit(Kind.WARNING, text)
	if _trim_entries_if_needed():
		compacted.emit()


func append_error(text: String) -> void:
	if text.is_empty():
		return
	_errors.append(text)
	if _errors.size() > MAX_DIAGNOSTICS_PER_KIND:
		_errors.pop_front()
	_entries.append(_make_entry(Kind.ERROR, text))
	entry_added.emit(Kind.ERROR, text)
	if _trim_entries_if_needed():
		compacted.emit()


func is_empty() -> bool:
	return _entries.is_empty()


func get_output() -> String:
	if _output_cache_dirty:
		var chunks: PackedStringArray = []
		for entry: Dictionary in _entries:
			if int(entry.get("kind", Kind.OUTPUT)) == Kind.OUTPUT:
				chunks.append(str(entry.get("text", "")))
		_output_cache = "".join(chunks)
		_output_cache_dirty = false
	return _output_cache


func get_warnings() -> Array[String]:
	return _warnings.duplicate()


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func _make_entry(kind: int, text: String) -> Dictionary:
	return {
		"kind": kind,
		"text": text,
	}


func _append_output_chunks(text: String) -> void:
	var cursor := 0
	while cursor < text.length():
		var available := 0
		if not _entries.is_empty() and int(_entries[-1].get("kind", Kind.ERROR)) == Kind.OUTPUT:
			available = OUTPUT_CHUNK_SIZE - str(_entries[-1].get("text", "")).length()
		if available <= 0:
			_entries.append(_make_entry(Kind.OUTPUT, ""))
			available = OUTPUT_CHUNK_SIZE
		var take := mini(available, text.length() - cursor)
		_entries[-1]["text"] = str(_entries[-1]["text"]) + text.substr(cursor, take)
		cursor += take
		_output_length += take
	_output_cache_dirty = true


func _trim_output_if_needed() -> bool:
	if _output_length <= MAX_OUTPUT_CHARACTERS:
		return false
	var remove_count := _output_length - (MAX_OUTPUT_CHARACTERS - OUTPUT_TRIM_BATCH)
	var removed := 0
	var entry_index := 0
	while entry_index < _entries.size() and removed < remove_count:
		var entry: Dictionary = _entries[entry_index]
		if int(entry.get("kind", Kind.ERROR)) != Kind.OUTPUT:
			entry_index += 1
			continue
		var entry_text := str(entry.get("text", ""))
		var remaining := remove_count - removed
		if entry_text.length() <= remaining:
			removed += entry_text.length()
			_entries.remove_at(entry_index)
		else:
			entry["text"] = entry_text.substr(remaining)
			_entries[entry_index] = entry
			removed += remaining
	_output_length -= removed
	_output_cache_dirty = true
	return removed > 0


func _trim_entries_if_needed() -> bool:
	if _entries.size() <= MAX_ENTRY_COUNT:
		return false
	var trim_count := mini(ENTRY_TRIM_BATCH, _entries.size())
	for trim_index in range(trim_count):
		var entry: Dictionary = _entries[trim_index]
		if int(entry.get("kind", Kind.ERROR)) == Kind.OUTPUT:
			_output_length -= str(entry.get("text", "")).length()
	_entries = _entries.slice(trim_count)
	_output_length = maxi(_output_length, 0)
	_output_cache_dirty = true
	return true
