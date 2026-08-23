extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_validate")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[MENU PASS] ", message)
	else:
		_failures.append(message)
		push_error("[MENU FAIL] " + message)


func _validate() -> void:
	var menu_scene := load("res://levels/main_menu.tscn") as PackedScene
	_check(menu_scene != null, "Main-menu scene loads")
	if menu_scene == null:
		quit(1)
		return
	var menu := menu_scene.instantiate() as AshenMainMenu
	root.add_child(menu)
	current_scene = menu
	await process_frame

	var start_button := menu.get_node_or_null("%StartButton") as Button
	var controls_button := menu.get_node_or_null("%ControlsButton") as Button
	var settings_button := menu.get_node_or_null("%SettingsButton") as Button
	var details_panel := menu.get_node_or_null("%DetailsPanel") as PanelContainer
	var controls_content := menu.get_node_or_null("%ControlsContent") as RichTextLabel
	var settings_content := menu.get_node_or_null("%SettingsContent") as VBoxContainer
	var back_button := menu.get_node_or_null("%BackButton") as Button
	_check(start_button != null and start_button.pressed.get_connections().size() == 1, "Start button is wired")
	_check(controls_button != null and settings_button != null and back_button != null, "Menu actions are present")
	_check(details_panel != null and not details_panel.visible, "Detail panel starts hidden")

	controls_button.pressed.emit()
	await process_frame
	_check(details_panel.visible and controls_content.visible and not settings_content.visible, "Controls panel opens")
	back_button.pressed.emit()
	await create_timer(0.2).timeout
	_check(not details_panel.visible, "Detail panel closes")
	settings_button.pressed.emit()
	await process_frame
	_check(details_panel.visible and settings_content.visible and not controls_content.visible, "Settings panel opens")

	var loading_scene := load(menu.start_scene_path) as PackedScene
	_check(loading_scene != null, "Loading scene is reachable from the menu")
	if loading_scene != null:
		var loading := loading_scene.instantiate() as AshenBootScreen
		_check(loading.target_scene_path == "res://levels/dungeon_3d.tscn", "Loading screen targets the 3D dungeon")
		_check(loading.get_node_or_null("%ProgressBar") != null, "Loading screen owns a progress bar")
		var dungeon_scene := load(loading.target_scene_path) as PackedScene
		_check(dungeon_scene != null, "Dungeon scene loads after the loading screen")
		if dungeon_scene != null:
			var dungeon := dungeon_scene.instantiate()
			var prologue := dungeon.get_node_or_null("PrologueDialogue") as AshenPrologueDialogue
			_check(prologue != null, "Japanese RPG dialogue overlay appears in the game scene")
			if prologue != null:
				var character_art := prologue.get_node_or_null("%CharacterArt") as TextureRect
				_check(character_art != null, "Prologue displays the protagonist cutout")
				if character_art != null:
					_check(character_art.anchor_bottom > 1.2, "Protagonist is framed from the thighs upward")
				_check(prologue.get_node_or_null("%CharacterArtNext") != null, "Expression changes use an overlapping art layer")
				_check(prologue.get_node_or_null("%DialogueText") != null, "Prologue owns dialogue text")
				_check(prologue.get_node_or_null("%SkipButton") != null, "Prologue can be skipped")
				_check(prologue.DIALOGUE_LINES.size() == 3, "Prologue contains three short dialogue lines")
				_check(prologue.EXPRESSION_TEXTURES.size() == 3, "Each dialogue line has a matching expression")
			dungeon.free()
		loading.free()

	menu.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MENU_FLOW_VALIDATE_OK")
		quit(0)
	else:
		push_error("MENU_FLOW_VALIDATE_FAIL count=%d" % _failures.size())
		quit(1)
