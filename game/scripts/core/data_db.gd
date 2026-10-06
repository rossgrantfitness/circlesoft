extends Node
## Loads every JSON and CSV file under res://data/ at startup and serves it by id.
##
## An id is the file's path under the data folder, without the extension and with "/" as the
## separator, so res://data/world/field_tuning.json is "world/field_tuning".
## JSON files keep whatever shape they have. CSV files become a table: an Array of row
## Dictionaries keyed by the header row. Cells that read as whole numbers or decimals become
## int or float; anything else stays a String (so never use all-digit text as an id in a CSV).
##
## A file that fails to read or parse is skipped and reported by its full path in get_errors().
## The other files still load. The autoload logs every error at boot; tests call load_all() on
## their own instance with a fixture folder, so test data never mixes with the real data.

const DATA_ROOT: String = "res://data"
const EXT_JSON: String = "json"
const EXT_CSV: String = "csv"
const ID_SEPARATOR: String = "/"
const VALUE_PATH_SEPARATOR: String = "."
const HIDDEN_PREFIX: String = "."
const UTF8_BOM: String = "﻿"
const SINGLE_EMPTY_CELL_COUNT: int = 1

var _documents: Dictionary[String, Variant] = {}
var _tables: Dictionary[String, Array] = {}
var _errors: Dictionary[String, String] = {}
var _root_dir: String = ""


func _ready() -> void:
	load_all(DATA_ROOT)
	for path: String in _errors:
		push_error("DataDB: %s: %s" % [path, _errors[path]])


## Clears everything and loads every JSON/CSV file under dir_path.
## Returns true when every file loaded cleanly.
func load_all(dir_path: String = DATA_ROOT) -> bool:
	_documents.clear()
	_tables.clear()
	_errors.clear()
	_root_dir = dir_path.trim_suffix(ID_SEPARATOR)
	if DirAccess.open(_root_dir) == null:
		_errors[_root_dir] = "data folder cannot be opened (error %d)" % DirAccess.get_open_error()
		return false
	_scan(_root_dir)
	return _errors.is_empty()


func has_errors() -> bool:
	return not _errors.is_empty()


## Maps the full path of each bad file to a short reason.
func get_errors() -> Dictionary[String, String]:
	return _errors.duplicate()


func has_json(id: String) -> bool:
	return _documents.has(id)


func has_table(id: String) -> bool:
	return _tables.has(id)


func json_ids() -> Array[String]:
	return _documents.keys()


func table_ids() -> Array[String]:
	return _tables.keys()


## The parsed JSON of a file (a Dictionary, Array or plain value), or null if the id is unknown.
func get_json(id: String) -> Variant:
	return _documents.get(id, null)


## A JSON file whose top level is an object. Empty if the id is unknown or it is not an object.
func get_dict(id: String) -> Dictionary:
	var doc: Variant = _documents.get(id, null)
	if doc is Dictionary:
		return doc
	return {}


## The rows of a CSV file (each row a Dictionary). Empty if the id is unknown.
func get_table(id: String) -> Array:
	return _tables.get(id, [])


## Looks inside a JSON file with a dotted path, e.g. get_value("world/field_tuning", "camera.smoothing").
## Path parts index Dictionaries by key and Arrays by number. Returns fallback when anything is missing.
func get_value(id: String, path: String, fallback: Variant = null) -> Variant:
	var node: Variant = _documents.get(id, null)
	if node == null:
		return fallback
	for part: String in path.split(VALUE_PATH_SEPARATOR, false):
		if node is Dictionary:
			var dict: Dictionary = node
			if not dict.has(part):
				return fallback
			node = dict[part]
		elif node is Array and part.is_valid_int():
			var list: Array = node
			var index: int = part.to_int()
			if index < 0 or index >= list.size():
				return fallback
			node = list[index]
		else:
			return fallback
	return node


func has_value(id: String, path: String) -> bool:
	var missing: RefCounted = RefCounted.new()
	return not is_same(get_value(id, path, missing), missing)


func _scan(dir_path: String) -> void:
	var files: PackedStringArray = DirAccess.get_files_at(dir_path)
	files.sort()
	for file_name: String in files:
		if file_name.begins_with(HIDDEN_PREFIX):
			continue
		var ext: String = file_name.get_extension().to_lower()
		if ext != EXT_JSON and ext != EXT_CSV:
			continue
		var path: String = dir_path.path_join(file_name)
		var id: String = _id_for(path)
		if _documents.has(id) or _tables.has(id):
			_errors[path] = "duplicate id '%s' (a .json and a .csv share a name)" % id
			continue
		if ext == EXT_JSON:
			_load_json(path, id)
		else:
			_load_csv(path, id)
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir_path)
	dirs.sort()
	for dir_name: String in dirs:
		if not dir_name.begins_with(HIDDEN_PREFIX):
			_scan(dir_path.path_join(dir_name))


func _id_for(path: String) -> String:
	var relative: String = path.trim_prefix(_root_dir).trim_prefix(ID_SEPARATOR)
	return relative.trim_suffix("." + relative.get_extension())


func _load_json(path: String, id: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		_errors[path] = "file is empty or cannot be read (error %d)" % FileAccess.get_open_error()
		return
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		_errors[path] = "JSON error at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return
	_documents[id] = parser.data


func _load_csv(path: String, id: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors[path] = "file cannot be opened (error %d)" % FileAccess.get_open_error()
		return
	var header: PackedStringArray = file.get_csv_line()
	if header.size() > 0:
		header[0] = header[0].trim_prefix(UTF8_BOM)
	if header.size() == 0 or (header.size() == SINGLE_EMPTY_CELL_COUNT and header[0].is_empty()):
		_errors[path] = "CSV has no header row"
		return
	var seen: Dictionary[String, bool] = {}
	for column: String in header:
		if column.is_empty() or seen.has(column):
			_errors[path] = "CSV header has an empty or repeated column name ('%s')" % column
			return
		seen[column] = true
	var rows: Array[Dictionary] = []
	var line_number: int = 1
	while not file.eof_reached():
		var cells: PackedStringArray = file.get_csv_line()
		line_number += 1
		if cells.size() == SINGLE_EMPTY_CELL_COUNT and cells[0].is_empty():
			continue # blank line
		if cells.size() != header.size():
			_errors[path] = "CSV line %d has %d columns, the header has %d" % [line_number, cells.size(), header.size()]
			return
		var row: Dictionary = {}
		for i: int in header.size():
			row[header[i]] = _coerce_cell(cells[i])
		rows.append(row)
	_tables[id] = rows


func _coerce_cell(cell: String) -> Variant:
	if cell.is_valid_int():
		return cell.to_int()
	if cell.is_valid_float():
		return cell.to_float()
	return cell
