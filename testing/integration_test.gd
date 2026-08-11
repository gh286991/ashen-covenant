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
	var audio := game.get_node_or_null("AudioDirector") as AshenAudioDirector
	_check(audio != null and audio.is_music_playing(), "CC0 title music begins playing")
	_check(audio != null and audio.explore_music != null and audio.boss_music != null and audio.level_up != null, "CC0 music and level-up sound load")
	await _tap_action(&"confirm")
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.PLAYING, "Confirm starts the hunt")
	_check(audio != null and audio.music_state == AshenAudioDirector.MusicState.EXPLORE, "Exploration music state starts with the hunt")
	_check(game.enemies.size() >= 9, "Enemy encounters populate all anchors")
	_check(ResourceLoader.exists("res://assets/ui/gothic_hud/gothic-hud-frame.png"), "Gothic angel and demon HUD art is available")
	var left_mouse_still_attacks := false
	for input_event in InputMap.action_get_events(&"attack"):
		if input_event is InputEventMouseButton and input_event.button_index == MOUSE_BUTTON_LEFT:
			left_mouse_still_attacks = true
	_check(not left_mouse_still_attacks, "Left click is reserved for contextual move and attack commands")
	_check(game.hud.blocks_world_pointer(Vector2(300, 650)), "Gothic HUD prevents accidental world commands")
	var hotbar_first := game.hud.surface.hotbar_slot_rect(0)
	var hotbar_last := game.hud.surface.hotbar_slot_rect(game.hud.surface.hotbar_slot_count() - 1)
	_check(game.hud.surface.hotbar_slot_count() == 4, "Bottom HUD keeps exactly four action slots")
	_check(is_equal_approx((hotbar_first.position.x + hotbar_last.end.x) * 0.5, 640.0), "Four action icons stay centered in the hotbar")

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
	_check(player_art != null and is_equal_approx(player_art.scale.x, 2.55) and is_equal_approx(player_art.position.y, -40.8), "Player art is reduced while keeping its feet on the ground")

	var target_enemy := game.enemies[0] as CovenantEnemy
	_check(target_enemy.active_art_animation() == &"stance", "Flare bestiary supplies a directional stance animation")
	target_enemy.flare_animator.set_animation(&"stance", Vector2.RIGHT, 0.0)
	_check(target_enemy.flare_animator.current_direction() == 5, "Flare east-facing frames match enemy movement")
	target_enemy.flare_animator.set_animation(&"stance", Vector2.DOWN, 0.0)
	_check(target_enemy.flare_animator.current_direction() == 7, "Flare south-facing frames match enemy movement")
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
	_check(target_enemy.active_art_animation() in [&"swing", &"hit", &"stance"], "Flare bestiary swaps enemy combat animation states")
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
	var points_before_level := game.player.skill_points
	var level_position := game.player.global_position
	var level_time := game.run_time
	audio.play_level_up()
	_check(audio.active_effect_count() > 0, "CC0 level-up sound queues for playback")
	var required_xp := maxi(1, game.player.experience_required() - game.player.experience)
	game.player.add_experience(required_xp)
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.PLAYING, "Leveling up no longer interrupts the hunt")
	_check(game.player.skill_points == points_before_level + 1, "Leveling awards an unspent skill point")
	_check(game.player.global_position.distance_to(level_position) < 0.5 and game.run_time >= level_time, "Level-up keeps the game running")
	_check(game.hud.surface.has_level_up_notice(), "Leveling plays a visible skill-point notice")
	var badge_click := InputEventMouseButton.new()
	badge_click.button_index = MOUSE_BUTTON_LEFT
	badge_click.pressed = true
	badge_click.position = game.hud.surface._skill_badge_rect().get_center()
	game.hud.surface._gui_input(badge_click)
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.SKILL_TREE, "Clicking the skill badge opens the separate skill tree")
	var tree_position := game.player.global_position
	var tree_time := game.run_time
	Input.action_press(&"move_right")
	for i in 8:
		await physics_frame
	Input.action_release(&"move_right")
	_check(game.player.global_position.distance_to(tree_position) < 0.5 and is_equal_approx(game.run_time, tree_time), "Skill tree freezes player movement and combat time")
	var damage_before_skill := game.player.base_damage
	game.purchase_skill("executioner")
	_check(game.player.get_skill_rank(&"executioner") == 1, "Skill tree purchases increase the selected branch rank")
	_check(game.player.skill_points == points_before_level, "Buying a skill spends exactly one point")
	_check(game.player.base_damage > damage_before_skill, "Executioner applies its rank benefit")
	await _tap_action(&"toggle_skills")
	_check(game.phase == AshenCovenantGame.GamePhase.PLAYING, "Skill tree returns to gameplay with K")

	game.player.global_position = Vector2(1100, 1200)
	game.player.last_move_direction = Vector2.UP
	var dash_target := game.enemies[2] as CovenantEnemy
	dash_target.global_position = game.player.global_position + Vector2(46, 0)
	var dash_health_before := dash_target.health
	var dash_start := game.player.global_position
	await _tap_action(&"dash")
	for i in 15:
		await physics_frame
	_check(game.player.global_position.distance_to(dash_start) > 35.0, "Shadow Step covers burst distance")
	_check(game.player.dash_cooldown > 0.0, "Shadow Step starts its cooldown")
	_check(dash_target.health < dash_health_before, "Shadow Step phase rend damages enemies at its departure point")

	var nearby_targets: Array[CovenantEnemy] = []
	for i in 2:
		var enemy := game.enemies[i + 3] as CovenantEnemy
		enemy.global_position = game.player.global_position + Vector2(45 + i * 24, 0)
		nearby_targets.append(enemy)
	var mana_before := game.player.mana
	var nearby_health_before: Array[float] = []
	for enemy in nearby_targets:
		nearby_health_before.append(enemy.health)
	await _tap_action(&"skill_nova")
	_check(game.player.mana < mana_before, "Ash Nova consumes essence")
	var nova_damaged_enemy := false
	var nova_ashbound_enemy := false
	for i in nearby_targets.size():
		if not is_instance_valid(nearby_targets[i]) or nearby_targets[i].health < nearby_health_before[i]:
			nova_damaged_enemy = true
		if is_instance_valid(nearby_targets[i]) and nearby_targets[i].ashbound_timer > 0.0:
			nova_ashbound_enemy = true
	_check(nova_damaged_enemy, "Ash Nova damages clustered enemies")
	_check(nova_ashbound_enemy, "Ash Nova leaves clustered enemies Ashbound and slowed")

	game.playtest_break_all_anchors()
	await process_frame
	_check(game.anchors_destroyed == 3, "All three soul anchors can be broken")
	_check(is_instance_valid(game.boss), "Breaking anchors awakens the boss")
	_check(audio.music_state == AshenAudioDirector.MusicState.BOSS, "Boss arrival crossfades to battle music")
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
