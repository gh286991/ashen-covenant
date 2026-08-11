extends Node

signal save_completed
signal save_failed(message: String)

const SAVE_PATH := "user://ashen_covenant_save.json"
const SAVE_VERSION := "1.0.0"

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(payload: Dictionary) -> bool:
	var data := payload.duplicate(true)
	data["version"] = SAVE_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(true)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		var message := "Could not open save file: %s" % error_string(FileAccess.get_open_error())
		save_failed.emit(message)
		push_error(message)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit()
	return true

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		save_failed.emit("Save file could not be opened")
		return {}
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not json.data is Dictionary:
		save_failed.emit("Save data is invalid")
		return {}
	var data: Dictionary = json.data
	if str(data.get("version", "")) != SAVE_VERSION:
		push_warning("Save version differs; safe defaults will be used")
	return data

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

