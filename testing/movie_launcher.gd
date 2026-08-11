extends Node

const MOVIE_PATH := "res://recordings/ashen_covenant_raw.avi"
const PLAYTEST_SCENE := "res://testing/playtest_driver.tscn"
const FIXED_FPS := "20"

func _ready() -> void:
	var output_path := ProjectSettings.globalize_path(MOVIE_PATH)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(output_path)
	var arguments := PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"),
		"--write-movie", output_path,
		"--fixed-fps", FIXED_FPS,
		"--disable-vsync",
		PLAYTEST_SCENE,
	])
	var process_id := OS.create_process(OS.get_executable_path(), arguments)
	if process_id <= 0:
		push_error("Could not start Godot Movie Maker process")
		get_tree().quit(1)
		return
	print("GODOT_MOVIE_PROCESS_STARTED:%d:%s" % [process_id, output_path])
	get_tree().quit(0)

