extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hud_scene := load("res://ui/jrpg/dungeon_jrpg_hud.tscn") as PackedScene
	assert(hud_scene != null, "JRPG HUD scene must load")
	var hud := hud_scene.instantiate() as DungeonJrpgHud
	assert(hud != null, "JRPG HUD root must use DungeonJrpgHud")
	var progression := DungeonProgression.new()
	progression.name = "ProgressionUnderTest"
	root.add_child(progression)
	root.add_child(hud)
	await process_frame
	hud.setup(progression)

	assert(hud.get_node_or_null("%ExpBar") != null, "HUD must expose the bottom EXP bar")
	assert(hud.get_node("%ExpBar").anchor_bottom == 1.0, "EXP must remain anchored to the screen bottom")
	assert(hud.get_node_or_null("ActionBar") != null, "HUD must expose the skill ribbon")
	assert(hud.get_node_or_null("QuickItems") != null, "HUD must expose quick items")
	assert(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Empty HUD space must not block world input")

	hud.get_node("%MenuToggle").button_pressed = true
	assert(hud.get_node("%MenuDropdown").visible, "The single menu icon must expand the page shortcuts")
	hud.get_node("%MenuToggle").button_pressed = false
	assert(not hud.get_node("%MenuDropdown").visible, "The menu icon must collapse the shortcuts")
	assert(progression.level == 1 and progression.attribute_points == 5, "Progression must start with real allocation points")
	assert(progression.skill_points == 1, "Progression must start with one spendable skill point")

	var c_key := InputEventKey.new()
	c_key.pressed = true
	c_key.keycode = KEY_C
	hud._unhandled_input(c_key)
	assert(hud.get_node("%CharacterPage").visible and paused, "C must open the character page")
	var escape_key := InputEventKey.new()
	escape_key.pressed = true
	escape_key.keycode = KEY_ESCAPE
	hud._unhandled_input(escape_key)
	assert(not hud.get_node("%Modal").visible and not paused, "Esc must close the modal and restore pause")

	hud.open_character_page()
	var strength_before := progression.strength
	hud.get_node("%CharacterPage").get_node("%StrengthAdd").pressed.emit()
	assert(progression.strength == strength_before + 1, "Character page must spend a real Strength point")
	assert(progression.attribute_points == 4, "Attribute allocation must consume exactly one point")
	hud.close_menu()

	hud.open_inventory_page()
	assert(paused, "Opening the menu must pause the game world")
	assert(hud.get_node("%Modal").visible, "Opening the menu must show the modal layer")
	assert(hud.get_node("%InventoryPage").visible, "Inventory shortcut must open inventory")

	hud.open_skills_page()
	assert(hud.get_node("%SkillsPage").visible, "Skills shortcut must switch pages in place")
	assert(not hud.get_node("%InventoryPage").visible, "Only one menu page may be visible")
	var skills_page := hud.get_node("%SkillsPage")
	skills_page.get_node("%ShadowStep").pressed.emit()
	skills_page.get_node("%LearnButton").pressed.emit()
	assert("shadow_step" in progression.get_snapshot().unlocked_skills, "Skill tree must spend a real point to unlock a skill")
	assert(progression.skill_points == 0, "Unlocking a skill must consume exactly one skill point")
	skills_page.get_node("%Equipped4").pressed.emit()
	assert(hud.get_node("%Skill4").icon == skills_page.get_node("%ShadowStep").icon, "Equipping from the skill tree must update the HUD icon")
	assert("影步" in hud.get_node("%Skill4").tooltip_text, "Equipping from the skill tree must update the HUD tooltip")
	assert(not hud.get_node("%Skill4").disabled, "An equipped HUD skill slot must become available")

	hud.close_menu()
	assert(not paused, "Closing the menu must restore the previous pause state")
	assert(not hud.get_node("%Modal").visible, "Closing the menu must hide the modal layer")

	var levels_gained := progression.add_experience(100)
	assert(levels_gained == 1 and progression.level == 2, "Required EXP must cause a real level-up")
	assert(progression.attribute_points == 9, "Each level must award exactly five attribute points")
	assert(progression.skill_points == 1, "Each level must award exactly one skill point")
	assert(hud.get_node("%LevelLabel").text == "LV. 02", "HUD level must react to progression signals")

	for page_path in [
		"res://ui/jrpg/character_page.tscn",
		"res://ui/jrpg/inventory_page.tscn",
		"res://ui/jrpg/skills_page.tscn",
	]:
		var page_scene := load(page_path) as PackedScene
		assert(page_scene != null, "%s must load independently" % page_path)
		var page := page_scene.instantiate() as Control
		assert(page != null and page.visible, "%s must be editor-previewable" % page_path)
		assert(page.custom_minimum_size.x >= 1000.0, "%s must fit the 1280-wide UI frame" % page_path)
		page.free()

	print("JRPG UI validation passed: HUD, Character, Inventory, Skills")
	hud.queue_free()
	progression.queue_free()
	await process_frame
	quit()
