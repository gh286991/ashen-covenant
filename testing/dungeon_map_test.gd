extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run_suite")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("[MAP TEST PASS] ", message)
	else:
		failures.append(message)
		push_error("[MAP TEST FAIL] " + message)


func _run_suite() -> void:
	var packed := load("res://levels/main.tscn") as PackedScene
	_check(packed != null, "Dungeon scene loads")
	if packed == null:
		quit(1)
		return

	var game := packed.instantiate() as AshenCovenantGame
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_game()
	await process_frame

	_check(game.dungeon_layout.get("rooms", []).size() >= 12, "Dungeon contains twelve named spaces")
	_check(game.dungeon_layout.get("hazards", []).size() >= 4, "Dungeon contains four trap zones")
	_check(game.chests.size() == 3, "Main path and two side caches are present")
	_check(game.breakables.size() >= 6, "Breakable dungeon dressing is populated")
	_check(game.enemies.size() >= 12, "Encounters are distributed across the dungeon")
	_check(game.player.get_collision_mask_value(1), "Player collision mask scans the World layer")
	if not game.enemies.is_empty():
		_check(game.enemies[0].get_collision_mask_value(1), "Enemy collision mask scans the World layer")

	# Keep the systems under test deterministic while checking navigation and props.
	for enemy: CovenantEnemy in game.enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	game.enemies.clear()
	await process_frame

	var world := game.world_renderer
	await process_frame
	var world_collision := world.get_node_or_null("WorldCollision") as StaticBody2D
	_check(world_collision != null, "World renderer builds a runtime StaticBody2D")
	if world_collision != null:
		_check(world_collision.collision_layer == 1, "Runtime world collider uses the World layer")
		_check(world_collision.collision_mask == 0, "Static world collider does not scan other layers")
		var boundary_count := 0
		for child in world_collision.get_children():
			if child is CollisionPolygon2D and child.build_mode == CollisionPolygon2D.BUILD_SEGMENTS:
				boundary_count += 1
		_check(boundary_count == 1, "Connected walkable layout merges into one segment boundary collider")
		_check(world_collision.get_node_or_null("BossGate") != null, "Sealed boss gate has a physical blocker")
		_check(world_collision.get_node_or_null("Decor_sarcophagus_w1") != null, "Authored decor blocker has a physical shape")
		_check(world_collision.get_node_or_null("Chest_nave_cache") != null, "Chest has a physical shape")
		_check(world_collision.get_node_or_null("Breakable_urn_1") != null, "Living breakable has a physical shape")
	game.player.global_position = Vector2(1100, 520)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	game.player.last_move_direction = Vector2.UP
	game.player.facing = Vector2.UP
	Input.action_press(&"dash")
	await physics_frame
	Input.action_release(&"dash")
	for _frame in 18:
		await physics_frame
	_check(game.player.global_position.y >= 479.0, "Physical boss gate stops the player's dash")
	game.player.dash_timer = 0.0
	game.player.cancel_pointer_command()
	game.player.global_position = Vector2(1100, 520)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	_check(game.issue_pointer_command(Vector2(1100, 350)), "Click navigation accepts a destination beyond the sealed gate")
	for _frame in 60:
		await physics_frame
	_check(game.player.global_position.y >= 390.0 and world.is_point_walkable(game.player.global_position, 17.0), "Click navigation stops on the reachable side of the sealed gate")
	game.player.cancel_pointer_command()
	game.player.global_position = Vector2(960, 1150)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	Input.action_press(&"move_left")
	Input.action_press(&"move_up")
	for _frame in 18:
		await physics_frame
	Input.action_release(&"move_left")
	Input.action_release(&"move_up")
	_check(game.player.global_position.x >= 946.0, "Physical nave wall blocks the player's collision radius")
	_check(game.player.global_position.y < 1125.0, "CharacterBody2D preserves wall-tangent movement")
	_check(world.is_point_walkable(Vector2(1100, 1250), 17.0), "Entry spawn is walkable")
	_check(world.is_point_walkable(Vector2(390, 680), 17.0), "West crypt is walkable")
	_check(world.is_point_walkable(Vector2(1810, 680), 17.0), "East ossuary is walkable")
	_check(world.is_point_walkable(Vector2(1100, 670), 17.0), "Ritual court is walkable")
	_check(world.is_point_walkable(Vector2(1100, 190), 17.0), "Boss sanctum is authored as playable space")
	_check(not world.is_point_walkable(Vector2(20, 20), 17.0), "Darkness outside the dungeon is blocked")
	_check(world.is_point_walkable(Vector2(950, 1100), 18.0), "Small enemy radius fits near the nave wall")
	_check(not world.is_point_walkable(Vector2(950, 1100), 23.0), "Brute radius cannot clip through the same nave wall")
	var slide_start := Vector2(950, 1150)
	var slide_result := world.resolve_motion(slide_start, Vector2(930, 1110), 17.0)
	_check(slide_result.x >= 946.9, "Diagonal movement remains outside the nave wall")
	_check(slide_result.y < 1115.0, "Diagonal wall contact preserves tangential movement")

	_check(not world.is_motion_walkable(Vector2(1100, 500), Vector2(1100, 350), 17.0), "Sealed soul gate blocks the boss route")
	_check(not world.is_point_walkable(Vector2(477, 830), 17.0), "West shortcut starts sealed")

	var chest_hits := game._hit_interactables(Vector2(1010, 1185), 12.0)
	_check(chest_hits >= 1 and bool(game.chests[2].get("opened", false)), "Entry cache opens and creates loot")
	_check(game.loot_layer.get_child_count() >= 2, "Opened cache drops tangible rewards")
	var prop_hits := game._hit_interactables(Vector2(1080, 1160), 12.0)
	_check(prop_hits >= 1 and not bool(game.breakables[0].get("alive", true)), "Funerary urn can be smashed")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("Breakable_urn_1") == null, "Destroyed breakable removes its physical shape")

	game.player.invulnerable_timer = 0.0
	game.player.health = game.player.max_health()
	game.player.global_position = Vector2(1100, 1045)
	var health_before := game.player.health
	game._update_hazards()
	_check(game.player.health < health_before, "Spike trap damages the player")

	game.player.global_position = Vector2(390, 680)
	game._update_exploration(0.1)
	_check(game.current_room == "west_crypt", "Room discovery identifies the west crypt")
	_check("west_crypt" in game.discovered_rooms, "Discovered rooms are recorded for the minimap")

	var west_anchor := game._anchor_by_id("west")
	game._damage_anchor(west_anchor, float(west_anchor.get("health", 0.0)) + 1.0)
	await process_frame
	_check(world.is_point_walkable(Vector2(477, 830), 17.0), "Breaking the west anchor unseals its shortcut")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("ShortcutGate_west_shortcut") == null, "Breaking the west anchor removes its physical shortcut gate")
	game.player.global_position = Vector2(460, 910)
	game.shortcut_cooldown = 0.0
	game._update_shortcuts()
	_check(game.player.global_position.distance_to(Vector2(985, 1045)) < 2.0, "West shortcut returns the player to the nave")

	game.playtest_break_all_anchors()
	await process_frame
	_check(game.anchors_destroyed == 3, "All anchors can be cleared from their branches")
	_check(is_instance_valid(game.boss), "Clearing the anchors awakens the boss")
	_check(world.is_motion_walkable(Vector2(1100, 500), Vector2(1100, 350), 17.0), "Soul gate opens after all anchors fall")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("BossGate") == null, "Opening the soul gate removes its physical blocker")

	game.playtest_damage_boss(99999.0)
	await process_frame
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.VICTORY, "Dungeon route ends in a winnable boss fight")

	print("[MAP TEST STATE] ", JSON.stringify(game.get_playtest_state()))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[MAP TEST RESULT] PASS — dungeon layout and interactions verified")
		quit(0)
	else:
		print("[MAP TEST RESULT] FAIL count=%d" % failures.size())
		quit(1)
