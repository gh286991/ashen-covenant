class_name AshenBootScreen
extends Control

## Keeps a visible UI on screen while the large 3D dungeon loads. This avoids
## an opaque black window during startup and gives players a useful failure
## message if a release resource cannot be read.

const DUNGEON_SCENE_PATH := "res://levels/dungeon_3d.tscn"

@onready var status_label: Label = %Status

var _loading := false


func _ready() -> void:
	call_deferred("_begin_loading")


func _begin_loading() -> void:
	var error := ResourceLoader.load_threaded_request(DUNGEON_SCENE_PATH, "PackedScene", false)
	if error != OK:
		_show_load_error(error)
		return
	_loading = true
	status_label.text = "正在載入地下城…"


func _process(_delta: float) -> void:
	if not _loading:
		return
	var progress: Array = []
	var state := ResourceLoader.load_threaded_get_status(DUNGEON_SCENE_PATH, progress)
	if state == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():
			status_label.text = "正在載入地下城… %d%%" % roundi(float(progress[0]) * 100.0)
		return
	if state != ResourceLoader.THREAD_LOAD_LOADED:
		_show_load_error(ERR_CANT_ACQUIRE_RESOURCE)
		return
	_loading = false
	var dungeon_scene := ResourceLoader.load_threaded_get(DUNGEON_SCENE_PATH) as PackedScene
	if dungeon_scene == null:
		_show_load_error(ERR_FILE_CORRUPT)
		return
	get_tree().change_scene_to_packed(dungeon_scene)


func _show_load_error(error: Error) -> void:
	_loading = false
	status_label.text = "無法載入遊戲（錯誤 %d）。請重新解壓完整發行包後再試。" % error
	push_error("Failed to load dungeon scene: %s" % error_string(error))
