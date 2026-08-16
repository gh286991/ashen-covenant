extends SceneTree


func _init() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var packed := load("res://levels/dungeon_3d.tscn") as PackedScene
	if packed == null:
		push_error("DUNGEON_3D_VALIDATE_FAIL scene_missing")
		quit(1)
		return
	var dungeon := packed.instantiate()
	root.add_child(dungeon)
	await process_frame

	var required_paths := [
		"GridMapDungeon",
		"GridMapDungeon/FloorGridMap",
		"GridMapDungeon/StructureGridMap",
		"GridMapDungeon/BoundaryGridMap",
		"GridMapDungeon/PropGridMap",
		"Player",
		"Doors/Door_A_to_B",
		"Doors/Door_B_to_A",
		"Doors/Door_B_to_C",
		"Doors/Door_C_to_B",
		"Spawn_Room_A_From_B",
		"Spawn_Room_B_From_A",
		"Spawn_Room_C_From_B",
		"Spawn_Room_B_From_C",
		"Monsters",
	]
	for path in required_paths:
		if dungeon.get_node_or_null(path) == null:
			push_error("DUNGEON_3D_VALIDATE_FAIL missing=%s" % path)
			quit(1)
			return
	if dungeon.get_node_or_null("Modules") != null:
		push_error("DUNGEON_3D_VALIDATE_FAIL legacy_modules_still_present")
		quit(1)
		return

	var player := dungeon.get_node("Player") as CharacterBody3D
	var visual := dungeon.get_node_or_null("Player/Visual")
	var warrior_model := dungeon.get_node_or_null("Player/Visual/FantasyWarrior")
	var animation_player := visual.find_child("AnimationPlayer", true, false) if visual else null
	if visual == null or warrior_model == null or animation_player == null:
		push_error("DUNGEON_3D_VALIDATE_FAIL warrior_model_or_animation_missing")
		quit(1)
		return
	if not animation_player.has_animation(&"Sword_Attack"):
		push_error("DUNGEON_3D_VALIDATE_FAIL warrior_attack_animation_missing")
		quit(1)
		return
	if visual.scale.x < 1.5 or visual.position.y > -0.5:
		push_error("DUNGEON_3D_VALIDATE_FAIL warrior_scale_or_grounding")
		quit(1)
		return
	var grid_map := dungeon.get_node("GridMapDungeon")
	if grid_map.get_node("FloorGridMap").get_used_cells().is_empty():
		push_error("DUNGEON_3D_VALIDATE_FAIL floor_grid_empty")
		quit(1)
		return
	var monsters := dungeon.get_node("Monsters").get_children()
	if monsters.size() != 6:
		push_error("DUNGEON_3D_VALIDATE_FAIL monsters=%d" % monsters.size())
		quit(1)
		return
	for monster in monsters:
		if monster.get_script() == null or monster.get_script().resource_path != "res://entities/enemies/dungeon_monster_3d.gd":
			push_error("DUNGEON_3D_VALIDATE_FAIL invalid_monster_instance=%s" % monster.name)
			quit(1)
			return
	var target_monster := monsters[0] as DungeonMonster3D
	player.set_attack_target(target_monster)
	var selected_ring := target_monster.get_node("SelectionIndicator/SelectedRing") as Node3D
	var selected_diamond := target_monster.get_node("SelectionIndicator/SelectedDiamond") as Node3D
	if not selected_ring.visible or not selected_diamond.visible:
		push_error("DUNGEON_3D_VALIDATE_FAIL monster_selection_indicator_missing")
		quit(1)
		return
	player.clear_attack_target()
	if selected_ring.visible:
		push_error("DUNGEON_3D_VALIDATE_FAIL monster_selection_clear_missing")
		quit(1)
		return
	if not player.get("mouse_move_enabled"):
		push_error("DUNGEON_3D_VALIDATE_FAIL mouse_move_disabled")
		quit(1)
		return
	if not InputMap.has_action(&"attack"):
		push_error("DUNGEON_3D_VALIDATE_FAIL attack_input_missing")
		quit(1)
		return
	player.start_attack(Vector3.FORWARD)
	await process_frame
	if not player.is_attacking():
		push_error("DUNGEON_3D_VALIDATE_FAIL attack_did_not_start")
		quit(1)
		return
	var spawn_b := dungeon.get_node("Spawn_Room_B_From_A") as Node3D
	dungeon.transition_player(spawn_b, dungeon.get_node("Doors/Door_A_to_B"))
	if not player.global_position.is_equal_approx(spawn_b.global_position):
		push_error("DUNGEON_3D_VALIDATE_FAIL door_transition")
		quit(1)
		return
	var spawn_c := dungeon.get_node("Spawn_Room_C_From_B") as Node3D
	dungeon.transition_player(spawn_c, dungeon.get_node("Doors/Door_B_to_C"))
	if not player.global_position.is_equal_approx(spawn_c.global_position):
		push_error("DUNGEON_3D_VALIDATE_FAIL east_room_transition")
		quit(1)
		return

	print("DUNGEON_3D_VALIDATE_OK gridmap=4 doors=4 monsters=6 warrior=ok mouse=ok attack=ok transitions=2way")
	quit(0)
