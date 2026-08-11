extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred(&"_run_suite")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("[TEST PASS] ", message)
	else:
		failures.append(message)
		push_error("[TEST FAIL] " + message)

func _tap_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.action_press(action)
	Input.parse_input_event(press)
	await physics_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.action_release(action)
	Input.parse_input_event(release)
	await physics_frame

func _run_suite() -> void:
	var packed := load("res://levels/main.tscn") as PackedScene
	_check(packed != null, "Main scene loads")
	if packed == null:
		quit(1)
		return
	var game := packed.instantiate() as AshenCovenantGame
	root.add_child(game)
	await process_frame
	await process_frame
	var save_manager := root.get_node_or_null("SaveManager")
	_check(save_manager != null, "Save manager autoload is available")
	_check(game.phase == AshenCovenantGame.GamePhase.TITLE, "Title phase appears")
	await _tap_action(&"confirm")
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.PLAYING, "Confirm starts the hunt")
	_check(game.enemies.size() >= 9, "Enemy encounters populate all anchors")
	_check(ResourceLoader.exists("res://assets/ui/gothic_hud/gothic-hud-frame.png"), "Gothic angel and demon HUD art is available")
	var left_mouse_still_attacks := false
	for input_event in InputMap.action_get_events(&"attack"):
		if input_event is InputEventMouseButton and input_event.button_index == MOUSE_BUTTON_LEFT:
			left_mouse_still_attacks = true
	_check(not left_mouse_still_attacks, "Left click is reserved for contextual move and attack commands")
	_check(game.hud.blocks_world_pointer(Vector2(300, 650)), "Gothic HUD prevents accidental world commands")

	var start_position := game.player.global_position
	_check(game.issue_pointer_command(start_position + Vector2(100, 0)), "Ground click accepts a navigation command")
	for i in 30:
		await physics_frame
	_check(game.player.global_position.x > start_position.x + 45.0, "Ground click moves the player through CharacterBody2D physics")
	var player_art := game.player.get_node_or_null("VisualRoot/ArtSprite") as Sprite2D
	var grounded_art_y := player_art.position.y if player_art else INF
	for i in 10:
		await physics_frame
	_check(player_art != null and is_equal_approx(player_art.position.y, grounded_art_y), "Player art keeps a fixed foot anchor instead of vertical hovering")

	var target_enemy := game.enemies[0] as CovenantEnemy
	target_enemy.global_position = game.player.global_position + Vector2(55, 0)
	game.player.facing = Vector2.RIGHT
	game.player.last_move_direction = Vector2.RIGHT
	var health_before := target_enemy.health
	await _tap_action(&"attack")
	_check(target_enemy.health == health_before, "Cleave does not deal damage before its active frame")
	_check(game.player.get_node_or_null("VisualRoot") != null, "Player owns a state-driven visual root")
	for i in 8:
		await physics_frame
	_check(target_enemy.health < health_before, "Attack input damages a nearby enemy")
	_check(Engine.time_scale > 0.99, "Hit-stop restores the global time scale")
	game.player.cancel_pointer_command()
	for i in 24:
		await physics_frame
	var pointer_enemy := game.enemies[1] as CovenantEnemy
	pointer_enemy.global_position = game.player.global_position + Vector2(145, 0)
	var pointer_health_before := pointer_enemy.health
	_check(game.issue_pointer_command(pointer_enemy.global_position), "Clicking an enemy accepts a contextual attack command")
	for i in 70:
		await physics_frame
	_check(pointer_enemy.health < pointer_health_before, "Enemy click chases into range and attacks automatically")
	game.player.cancel_pointer_command()

	await _tap_action(&"toggle_sheet")
	_check(game.phase == AshenCovenantGame.GamePhase.SHEET, "Character sheet enters its own frozen phase")
	var sheet_position := game.player.global_position
	var sheet_health := game.player.health
	var sheet_time := game.run_time
	Input.action_press(&"move_right")
	for i in 8:
		await physics_frame
	Input.action_release(&"move_right")
	_check(game.player.global_position.distance_to(sheet_position) < 0.5, "Character sheet freezes player movement")
	_check(is_equal_approx(game.player.health, sheet_health) and is_equal_approx(game.run_time, sheet_time), "Character sheet freezes combat and run time")
	await _tap_action(&"toggle_sheet")
	_check(game.phase == AshenCovenantGame.GamePhase.PLAYING, "Character sheet returns to gameplay")

	game.player.global_position = Vector2(1100, 1200)
	game.player.last_move_direction = Vector2.UP
	var dash_start := game.player.global_position
	await _tap_action(&"dash")
	for i in 15:
		await physics_frame
	_check(game.player.global_position.distance_to(dash_start) > 35.0, "Shadow Step covers burst distance")
	_check(game.player.dash_cooldown > 0.0, "Shadow Step starts its cooldown")

	for i in mini(2, game.enemies.size()):
		game.enemies[i].global_position = game.player.global_position + Vector2(45 + i * 24, 0)
	var mana_before := game.player.mana
	var enemy_health_before := game.enemies[0].health
	await _tap_action(&"skill_nova")
	_check(game.player.mana < mana_before, "Ash Nova consumes essence")
	_check(game.enemies[0].health < enemy_health_before, "Ash Nova damages clustered enemies")

	game.playtest_break_all_anchors()
	await process_frame
	_check(game.anchors_destroyed == 3, "All three soul anchors can be broken")
	_check(is_instance_valid(game.boss), "Breaking anchors awakens the boss")
	_check(save_manager.has_save(), "Anchor progress writes a checkpoint")
	var saved: Dictionary = save_manager.load_game()
	_check(int(saved.get("anchors_destroyed", 0)) == 3, "Checkpoint restores objective progress")

	game.playtest_damage_boss(99999.0)
	await process_frame
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.VICTORY, "Defeating the boss reaches victory")
	_check(not save_manager.has_save(), "Victory clears the completed run checkpoint")

	var state := game.get_playtest_state()
	print("[TEST STATE] ", JSON.stringify(state))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[TEST RESULT] PASS — full gameplay loop verified")
		quit(0)
	else:
		print("[TEST RESULT] FAIL count=%d" % failures.size())
		quit(1)
