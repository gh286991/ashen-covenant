class_name AshenMainMenu
extends Control

@export_file("*.tscn") var start_scene_path := "res://levels/boot.tscn"

@onready var start_button: Button = %StartButton
@onready var controls_button: Button = %ControlsButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var details_title: Label = %DetailsTitle
@onready var controls_content: RichTextLabel = %ControlsContent
@onready var settings_content: VBoxContainer = %SettingsContent
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var volume_slider: HSlider = %VolumeSlider
@onready var back_button: Button = %BackButton
@onready var fade_overlay: ColorRect = %FadeOverlay

var _details_tween: Tween
var _transitioning := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_button.pressed.connect(_on_start_pressed)
	controls_button.pressed.connect(_show_controls)
	settings_button.pressed.connect(_show_settings)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_close_details)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() in [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	]
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus >= 0:
		volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0
	fade_overlay.modulate = Color.WHITE
	var intro := create_tween().bind_node(self)
	intro.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	intro.tween_property(fade_overlay, "modulate:a", 0.0, 0.45)
	start_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and details_panel.visible:
		_close_details()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	if _transitioning:
		return
	_transitioning = true
	_set_menu_enabled(false)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var transition := create_tween().bind_node(self)
	transition.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	transition.tween_property(fade_overlay, "modulate:a", 1.0, 0.32)
	await transition.finished
	var error := get_tree().change_scene_to_file(start_scene_path)
	if error != OK:
		_transitioning = false
		_set_menu_enabled(true)
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_overlay.modulate.a = 0.0
		push_error("Could not open start scene: %s" % error_string(error))


func _show_controls() -> void:
	details_title.text = "操作說明"
	controls_content.show()
	settings_content.hide()
	_show_details_panel()


func _show_settings() -> void:
	details_title.text = "遊戲設定"
	controls_content.hide()
	settings_content.show()
	_show_details_panel()


func _show_details_panel() -> void:
	if _details_tween != null and _details_tween.is_valid():
		_details_tween.kill()
	details_panel.show()
	details_panel.modulate.a = 0.0
	_details_tween = create_tween().bind_node(self)
	_details_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_details_tween.tween_property(details_panel, "modulate:a", 1.0, 0.2)
	back_button.grab_focus()


func _close_details() -> void:
	if not details_panel.visible:
		return
	if _details_tween != null and _details_tween.is_valid():
		_details_tween.kill()
	_details_tween = create_tween().bind_node(self)
	_details_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_details_tween.tween_property(details_panel, "modulate:a", 0.0, 0.14)
	await _details_tween.finished
	details_panel.hide()
	start_button.grab_focus()


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	if master_bus < 0:
		return
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value / 100.0, 0.0001)))


func _on_quit_pressed() -> void:
	get_tree().quit()


func _set_menu_enabled(enabled: bool) -> void:
	for button: Button in [start_button, controls_button, settings_button, quit_button, back_button]:
		button.disabled = not enabled
