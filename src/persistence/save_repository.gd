extends RefCounted

static func ensure_directory(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

static func slot_path(save_directory: String, slot: int) -> String:
	return "%s/slot_%d.json" % [save_directory, slot]

static func write_save(path: String, data: Dictionary, validator: Callable) -> Dictionary:
	var temp_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		return _failure("save_open_failed", "无法写入存档临时文件", {"path": temp_path, "error": FileAccess.get_open_error()})
	file.store_string(JSON.stringify(data))
	file.flush()
	file = null
	if not read_save_file(temp_path, validator).is_empty():
		var had_primary := FileAccess.file_exists(path)
		if had_primary:
			if FileAccess.file_exists(backup_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
			var backup_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path))
			if backup_error != OK:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
				return _failure("save_backup_failed", error_string(backup_error), {"path": path})
		var commit_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
		if commit_error == OK:
			return {"ok": true}
		if had_primary and FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path))
		return _failure("save_commit_failed", error_string(commit_error), {"path": path})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	return _failure("save_verify_failed", "存档临时文件校验失败", {"path": path})

static func read_save_file(path: String, validator: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary and bool(validator.call(json.data)) else {}

static func read_save(path: String, validator: Callable) -> Dictionary:
	var primary := read_save_file(path, validator)
	if not primary.is_empty():
		return {"data": primary, "recovered_backup": false, "invalid_primary": false}
	var backup := read_save_file(path + ".bak", validator)
	if not backup.is_empty():
		return {"data": backup, "recovered_backup": true, "invalid_primary": false}
	return {"data": {}, "recovered_backup": false, "invalid_primary": FileAccess.file_exists(path)}

static func delete_save(path: String) -> Dictionary:
	var found := false
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if not FileAccess.file_exists(candidate):
			continue
		found = true
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
		if error != OK:
			return {"ok": false, "found": true, "error": error, "path": candidate}
	return {"ok": found, "found": found}

static func _failure(event: String, message: String, context: Dictionary) -> Dictionary:
	return {"ok": false, "event": event, "message": message, "context": context}
