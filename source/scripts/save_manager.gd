class_name GameSaveManager
extends RefCounted

const SAVE_PATH := "user://infinite_legion_save.json"
const LEGACY_PROJECT_NAME := "無盡軍勢：荒原遠征"
const _VECTOR2_KEY := "__vector2__"
const _VECTOR2I_KEY := "__vector2i__"


static func save_game(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var safe_data: Variant = _sanitize_json_safe(data)
	if typeof(safe_data) != TYPE_DICTIONARY:
		return false

	var json_text := JSON.stringify(safe_data)
	var temp_path := path + ".tmp"
	if !_write_file(temp_path, json_text):
		return false

	if _rename_atomic(temp_path, path):
		return true

	# Some platforms do not replace an existing target during rename. Preserve the
	# last valid save until the fully written temporary file is in place.
	var backup_path := path + ".bak"
	_delete_file(backup_path)
	var had_previous := FileAccess.file_exists(path)
	if had_previous and not _rename_atomic(path, backup_path):
		_delete_file(temp_path)
		return false
	if _rename_atomic(temp_path, path):
		_delete_file(backup_path)
		return true
	if had_previous:
		_rename_atomic(backup_path, path)
	_delete_file(temp_path)
	return false


static func load_game(path: String = SAVE_PATH) -> Dictionary:
	var resolved_path := _resolve_existing_save_path(path)
	if resolved_path.is_empty():
		return {}

	var file := FileAccess.open(resolved_path, FileAccess.READ)
	if file == null:
		return {}

	var json_text := file.get_as_text()
	file.close()
	if json_text.is_empty():
		return {}

	var parser := JSON.new()
	if parser.parse(json_text) != OK:
		return {}

	var parsed_data: Variant = parser.data
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return {}

	var decoded_data: Variant = _decode_json_data(parsed_data)
	if typeof(decoded_data) != TYPE_DICTIONARY:
		return {}

	return decoded_data


static func has_save(path: String = SAVE_PATH) -> bool:
	return not _resolve_existing_save_path(path).is_empty()


static func delete_save(path: String = SAVE_PATH) -> bool:
	var success := true
	if FileAccess.file_exists(path):
		success = _delete_file(path)
	if path == SAVE_PATH:
		var legacy_path := _legacy_save_path()
		if not legacy_path.is_empty() and FileAccess.file_exists(legacy_path):
			success = _delete_file(legacy_path) and success
	return success


static func _resolve_existing_save_path(path: String) -> String:
	if FileAccess.file_exists(path):
		return path
	if path == SAVE_PATH:
		var legacy_path := _legacy_save_path()
		if not legacy_path.is_empty() and FileAccess.file_exists(legacy_path):
			return legacy_path
	return ""


static func _legacy_save_path() -> String:
	if OS.has_feature("web"):
		return ""
	return OS.get_data_dir().path_join("Godot").path_join("app_userdata").path_join(LEGACY_PROJECT_NAME).path_join("infinite_legion_save.json")


static func _sanitize_json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_VECTOR2:
			return _encode_vector2(value)
		TYPE_VECTOR2I:
			return _encode_vector2i(value)
		TYPE_DICTIONARY:
			var sanitized := {}
			var source := value as Dictionary
			for key in source.keys():
				sanitized[str(key)] = _sanitize_json_safe(source[key])
			return sanitized
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY:
			var sanitized_array := []
			for item in value:
				sanitized_array.append(_sanitize_json_safe(item))
			return sanitized_array
		_:
			return str(value)


static func _decode_json_data(value: Variant) -> Variant:
	var value_type := typeof(value)
	if value_type == TYPE_DICTIONARY:
		var source := value as Dictionary
		if source.has(_VECTOR2_KEY) and source.get(_VECTOR2_KEY) == "v2" and source.has("x") and source.has("y"):
			return _decode_vector2(source)
		if source.has(_VECTOR2I_KEY) and source.get(_VECTOR2I_KEY) == "v2i" and source.has("x") and source.has("y"):
			return _decode_vector2i(source)

		var decoded := {}
		for key in source.keys():
			decoded[str(key)] = _decode_json_data(source[key])
		return decoded

	if (
		value_type == TYPE_ARRAY or
		value_type == TYPE_PACKED_BYTE_ARRAY or
		value_type == TYPE_PACKED_INT32_ARRAY or
		value_type == TYPE_PACKED_INT64_ARRAY or
		value_type == TYPE_PACKED_FLOAT32_ARRAY or
		value_type == TYPE_PACKED_FLOAT64_ARRAY or
		value_type == TYPE_PACKED_STRING_ARRAY or
		value_type == TYPE_PACKED_VECTOR2_ARRAY
	):
		var decoded_array := []
		for item in value:
			decoded_array.append(_decode_json_data(item))
		return decoded_array

	return value


static func _encode_vector2(value: Vector2) -> Dictionary:
	return {
		_VECTOR2_KEY: "v2",
		"x": value.x,
		"y": value.y
	}


static func _encode_vector2i(value: Vector2i) -> Dictionary:
	return {
		_VECTOR2I_KEY: "v2i",
		"x": value.x,
		"y": value.y
	}


static func _decode_vector2(data: Dictionary) -> Vector2:
	return Vector2(
		float(data.get("x", 0.0)),
		float(data.get("y", 0.0))
	)


static func _decode_vector2i(data: Dictionary) -> Vector2i:
	return Vector2i(
		int(data.get("x", 0)),
		int(data.get("y", 0))
	)


static func _write_file(path: String, content: String) -> bool:
	if !_prepare_directory(path):
		return false

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error == OK


static func _rename_atomic(temp_path: String, final_path: String) -> bool:
	var result := DirAccess.rename_absolute(temp_path, final_path)
	if typeof(result) == TYPE_INT:
		return result == OK
	return bool(result)


static func _delete_file(path: String) -> bool:
	var result := DirAccess.remove_absolute(path)
	if typeof(result) == TYPE_INT:
		return result == OK || result == ERR_FILE_NOT_FOUND
	return bool(result)


static func _prepare_directory(path: String) -> bool:
	var dir_path := path.get_base_dir()
	if dir_path.is_empty():
		return true
	if dir_path == "user://":
		return true
	var error := DirAccess.make_dir_recursive_absolute(dir_path)
	return error == OK || error == ERR_ALREADY_EXISTS
