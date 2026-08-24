class_name AshenBootScreen
extends Control

@export_file("*.tscn") var target_scene_path := ""

const MINIMUM_DISPLAY_SECONDS := 1.0
const DEFAULT_TARGET_SCENE_PATH := "res://levels/dungeon_3d.tscn"
const WEB_DUNGEON_PACK_URL := "dungeon.pck"
const WEB_DUNGEON_PACK_CACHE := "user://ashen_covenant_dungeon.pck"
const TIPS := [
	"小提示：點擊地面，就能讓勇者前往那個位置。",
	"小提示：點擊敵人，勇者會靠近並主動攻擊。",
	"小提示：靠近發光的門，再按 E 前往下一區。",
	"小提示：滾動滑鼠滾輪，可以調整冒險視野。"
]

@onready var status_label: Label = %Status
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var percent_label: Label = %Percent
@onready var tip_label: Label = %Tip
@onready var retry_button: Button = %RetryButton
@onready var fade_overlay: ColorRect = %FadeOverlay

var _loading := false
var _scene_loading := false
var _pack_loading := false
var _transitioning := false
var _loaded_scene: PackedScene
var _pack_request: HTTPRequest
var _target_progress := 0.0
var _displayed_progress := 0.0
var _elapsed := 0.0
var _tip_elapsed := 0.0
var _tip_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	retry_button.pressed.connect(_begin_loading)
	tip_label.text = TIPS[0]
	fade_overlay.modulate = Color.WHITE
	var intro := create_tween().bind_node(self)
	intro.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	intro.tween_property(fade_overlay, "modulate:a", 0.0, 0.35)
	call_deferred("_begin_loading")


func _begin_loading() -> void:
	if _loading or _transitioning:
		return
	retry_button.hide()
	_elapsed = 0.0
	_target_progress = 0.0
	_displayed_progress = 0.0
	progress_bar.value = 0.0
	percent_label.text = "0%"
	progress_bar.indeterminate = false
	_loading = true
	if OS.has_feature("web"):
		_begin_web_pack_loading()
		return
	_start_scene_loading()


func _begin_web_pack_loading() -> void:
	status_label.text = "正在連接冒險資料…"
	# Keep regular one-pack Web exports compatible; the split release omits this
	# scene so it falls through to the on-demand download below.
	var scene_path := DEFAULT_TARGET_SCENE_PATH if target_scene_path.is_empty() else target_scene_path
	if ResourceLoader.exists(scene_path):
		_start_scene_loading()
		return
	# Cache the optional pack so repeat visits only wait for scene import.
	if FileAccess.file_exists(WEB_DUNGEON_PACK_CACHE):
		if ProjectSettings.load_resource_pack(WEB_DUNGEON_PACK_CACHE, false):
			_start_scene_loading()
			return
		DirAccess.remove_absolute(ProjectSettings.globalize_path(WEB_DUNGEON_PACK_CACHE))
	_pack_loading = true
	progress_bar.indeterminate = true
	percent_label.text = "下載中"
	_pack_request = HTTPRequest.new()
	_pack_request.timeout = 180.0
	_pack_request.request_completed.connect(_on_web_pack_request_completed)
	add_child(_pack_request)
	var error := _pack_request.request(WEB_DUNGEON_PACK_URL)
	if error != OK:
		_show_load_error(error)


func _on_web_pack_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_pack_loading = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or body.is_empty():
		_show_load_error(ERR_CANT_ACQUIRE_RESOURCE)
		return
	var file := FileAccess.open(WEB_DUNGEON_PACK_CACHE, FileAccess.WRITE)
	if file == null:
		_show_load_error(FileAccess.get_open_error())
		return
	file.store_buffer(body)
	file.close()
	if not ProjectSettings.load_resource_pack(WEB_DUNGEON_PACK_CACHE, false):
		_show_load_error(ERR_FILE_CORRUPT)
		return
	_start_scene_loading()


func _start_scene_loading() -> void:
	_scene_loading = false
	var scene_path := DEFAULT_TARGET_SCENE_PATH if target_scene_path.is_empty() else target_scene_path
	var error := ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if error != OK:
		_show_load_error(error)
		return
	_scene_loading = true
	progress_bar.indeterminate = false
	status_label.text = "正在整理冒險行囊…"


func _process(delta: float) -> void:
	_elapsed += delta
	_tip_elapsed += delta
	if _tip_elapsed >= 3.4:
		_tip_elapsed = 0.0
		_tip_index = (_tip_index + 1) % TIPS.size()
		tip_label.text = TIPS[_tip_index]

	if _scene_loading:
		_poll_threaded_load()

	var speed := 1.35 if _loaded_scene != null else 0.52
	_displayed_progress = move_toward(_displayed_progress, _target_progress, delta * speed)
	if not _pack_loading:
		progress_bar.value = _displayed_progress * 100.0
		percent_label.text = "%d%%" % roundi(_displayed_progress * 100.0)
	_update_status_text()

	if _loaded_scene != null and _elapsed >= MINIMUM_DISPLAY_SECONDS and _displayed_progress >= 0.995:
		_enter_loaded_scene()


func _poll_threaded_load() -> void:
	var progress: Array = []
	var scene_path := DEFAULT_TARGET_SCENE_PATH if target_scene_path.is_empty() else target_scene_path
	var state := ResourceLoader.load_threaded_get_status(scene_path, progress)
	match state:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not progress.is_empty():
				_target_progress = clampf(float(progress[0]) * 0.96, _target_progress, 0.96)
		ResourceLoader.THREAD_LOAD_LOADED:
			_scene_loading = false
			_loading = false
			_loaded_scene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
			if _loaded_scene == null:
				_show_load_error(ERR_FILE_CORRUPT)
				return
			_target_progress = 1.0
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_scene_loading = false
			_show_load_error(ERR_CANT_ACQUIRE_RESOURCE)


func _update_status_text() -> void:
	if not _loading and _loaded_scene == null:
		return
	if _pack_loading:
		status_label.text = "正在下載地城資料…"
	elif _displayed_progress < 0.22:
		status_label.text = "正在整理冒險行囊…"
	elif _displayed_progress < 0.52:
		status_label.text = "正在點亮地下城燈火…"
	elif _displayed_progress < 0.86:
		status_label.text = "正在喚醒魔法通道…"
	elif _loaded_scene == null:
		status_label.text = "正在確認前方道路…"
	else:
		status_label.text = "冒險準備完成！"


func _enter_loaded_scene() -> void:
	if _transitioning:
		return
	_transitioning = true
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var transition := create_tween().bind_node(self)
	transition.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	transition.tween_property(fade_overlay, "modulate:a", 1.0, 0.32)
	await transition.finished
	var error := get_tree().change_scene_to_packed(_loaded_scene)
	if error != OK:
		_transitioning = false
		_show_load_error(error)


func _show_load_error(error: Error) -> void:
	_loading = false
	_scene_loading = false
	_pack_loading = false
	progress_bar.indeterminate = false
	_loaded_scene = null
	status_label.text = "哎呀，地下城大門暫時打不開。"
	tip_label.text = "請再試一次；若仍失敗，請確認遊戲檔案是否完整。"
	retry_button.show()
	retry_button.grab_focus()
	push_error("Failed to load scene: %s" % error_string(error))
