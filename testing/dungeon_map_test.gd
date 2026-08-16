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
	_check(packed != null, "Old Prison dungeon scene loads")
	if packed == null:
		quit(1)
		return

	var game := packed.instantiate() as AshenCovenantGame
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_new_game()
	await process_frame

	var tiled_map := game.get_node_or_null("OldPrisonTileMap") as Node2D
	var tiled_layer_count := 0
	var tiled_cell_count := 0
	var tiled_size_ok := true
	if tiled_map != null:
		for child in tiled_map.get_children():
			if child is TileMapLayer:
				tiled_layer_count += 1
				tiled_cell_count += (child as TileMapLayer).get_used_cells().size()
				if (child as TileMapLayer).tile_set == null or (child as TileMapLayer).tile_set.tile_size != Vector2i(32, 32):
					tiled_size_ok = false
	_check(tiled_map != null and tiled_layer_count == 10, "Old Prison is assembled from eight base layers plus two foreground wall layers")
	_check(tiled_cell_count >= 7900 and tiled_size_ok, "Old Prison TileMap uses the purchased 32px TileSet grid")
	var foreground_wall_1 := tiled_map.get_node_or_null("Foreground_wall_1") as TileMapLayer if tiled_map != null else null
	var foreground_wall_2 := tiled_map.get_node_or_null("Foreground_wall_2") as TileMapLayer if tiled_map != null else null
	var foreground_material := foreground_wall_1.material as ShaderMaterial if foreground_wall_1 != null else null
	var silhouette_mask_ready := foreground_material != null and float(foreground_material.get_shader_parameter("player_visual_ready")) > 0.5
	_check(foreground_wall_1 != null and foreground_wall_2 != null and foreground_wall_1.modulate.a > 0.99 and foreground_material != null and foreground_material.shader != null and foreground_wall_1.z_index > 50 and silhouette_mask_ready, "Foreground walls use the player's silhouette for exact occlusion")

	_check(game.dungeon_layout.get("rooms", []).size() >= 6, "Old Prison contains four exploration zones plus approach and boss sanctum")
	_check(game.dungeon_layout.get("hazards", []).size() >= 4, "Old Prison contains four trap zones")
	_check(game.chests.size() == 3, "Entry cache and two side caches are present")
	_check(game.breakables.size() >= 6, "Breakable barrels and bone piles are populated")
	_check(game.enemies.size() >= 12, "Encounters are distributed across the three anchor zones")
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
		_check(boundary_count == 1, "Connected Old Prison walkable layout merges into one boundary collider")
		_check(world_collision.get_node_or_null("BossGate") != null, "Sealed Warden gate has a physical blocker")
		_check(world_collision.get_node_or_null("Decor_cell_barrels") != null, "Authored barrel blocker has a physical shape")
		_check(world_collision.get_node_or_null("Chest_entry_cache") != null, "Entry chest has a physical shape")
		_check(world_collision.get_node_or_null("Breakable_barrel_1") != null, "Living barrel has a physical shape")

	game.player.global_position = Vector2(1280, 380)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	game.player.last_move_direction = Vector2.UP
	game.player.facing = Vector2.UP
	Input.action_press(&"dash")
	await physics_frame
	Input.action_release(&"dash")
	for _frame in 18:
		await physics_frame
	_check(game.player.global_position.y >= 360.0, "Physical Warden gate stops the player's dash with the smaller player radius")

	game.player.dash_timer = 0.0
	game.player.cancel_pointer_command()
	game.player.global_position = Vector2(1280, 380)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	_check(game.issue_pointer_command(Vector2(1280, 180)), "Click navigation accepts a destination beyond the sealed Warden gate")
	for _frame in 60:
		await physics_frame
	_check(game.player.global_position.y >= 363.0 and world.is_point_walkable(game.player.global_position, 14.0), "Click navigation stops on the reachable side of the sealed Warden gate")
	game.player.cancel_pointer_command()

	game.player.global_position = Vector2(280, 1040)
	game.player.velocity = Vector2.ZERO
	game.player.locomotion_velocity = Vector2.ZERO
	Input.action_press(&"move_left")
	for _frame in 18:
		await physics_frame
	Input.action_release(&"move_left")
	_check(game.player.global_position.x >= 270.0, "Outer prison wall blocks the smaller player's collision radius")

	_check(world.is_point_walkable(Vector2(820, 1100), 14.0), "Entry spawn is walkable")
	_check(world.is_point_walkable(Vector2(432, 760), 14.0), "Silent Cells are walkable")
	_check(world.is_point_walkable(Vector2(820, 420), 14.0), "Gearworks are walkable")
	_check(world.is_point_walkable(Vector2(1580, 760), 14.0), "Bloodworks are walkable")
	_check(world.is_point_walkable(Vector2(1280, 170), 14.0), "Warden sanctum is authored as playable space")
	_check(not world.is_point_walkable(Vector2(20, 20), 14.0), "Darkness outside the prison is blocked")
	_check(not world.is_motion_walkable(Vector2(1280, 380), Vector2(1280, 180), 14.0), "Sealed Warden gate blocks the boss route")
	_check(not world.is_point_walkable(Vector2(475, 830), 14.0), "Cell shortcut starts sealed")

	var chest_hits := game._hit_interactables(Vector2(960, 1110), 12.0)
	_check(chest_hits >= 1 and bool(game.chests[0].get("opened", false)), "Entry cache opens and creates loot")
	_check(game.loot_layer.get_child_count() >= 2, "Opened cache drops tangible rewards")
	var prop_hits := game._hit_interactables(Vector2(360, 900), 12.0)
	_check(prop_hits >= 1 and not bool(game.breakables[0].get("alive", true)), "Prison barrel can be smashed")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("Breakable_barrel_1") == null, "Destroyed breakable removes its physical shape")

	game.player.invulnerable_timer = 0.0
	game.player.health = game.player.max_health()
	game.player.global_position = Vector2(610, 900)
	var health_before := game.player.health
	game._update_hazards()
	_check(game.player.health < health_before, "Cell spike trap damages the player")

	game.player.global_position = Vector2(432, 760)
	game._update_exploration(0.1)
	_check(game.current_room == "cell_block", "Room discovery identifies the Silent Cells")
	_check("cell_block" in game.discovered_rooms, "Discovered rooms are recorded for the minimap")

	var cells_anchor := game._anchor_by_id("cells")
	game._damage_anchor(cells_anchor, float(cells_anchor.get("health", 0.0)) + 1.0)
	await process_frame
	_check(world.is_point_walkable(Vector2(475, 830), 14.0), "Breaking the Cells anchor unseals its shortcut")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("ShortcutGate_cell_shortcut") == null, "Breaking the Cells anchor removes its physical shortcut gate")
	game.player.global_position = Vector2(460, 900)
	game.shortcut_cooldown = 0.0
	game._update_shortcuts()
	_check(game.player.global_position.distance_to(Vector2(820, 1050)) < 2.0, "Cells shortcut returns the player to the entry hall")

	game.playtest_break_all_anchors()
	await process_frame
	_check(game.anchors_destroyed == 3, "All anchors can be cleared from their branches")
	_check(is_instance_valid(game.boss), "Clearing the anchors awakens the Warden")
	_check(world.is_motion_walkable(Vector2(1280, 380), Vector2(1280, 180), 14.0), "Warden gate opens after all anchors fall")
	await process_frame
	if world_collision != null:
		_check(world_collision.get_node_or_null("BossGate") == null, "Opening the Warden gate removes its physical blocker")

	game.playtest_damage_boss(99999.0)
	await process_frame
	await process_frame
	_check(game.phase == AshenCovenantGame.GamePhase.VICTORY, "Old Prison route ends in a winnable boss fight")

	print("[MAP TEST STATE] ", JSON.stringify(game.get_playtest_state()))
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[MAP TEST RESULT] PASS — Old Prison layout and interactions verified")
		quit(0)
	else:
		print("[MAP TEST RESULT] FAIL count=%d" % failures.size())
		quit(1)
