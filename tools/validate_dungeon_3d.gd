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
	var castle_wall := dungeon.get_node("GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Walls/OriginalNorth_-2") as Node3D
	if castle_wall.get_script() == null or castle_wall.get_script().resource_path != "res://scripts/castle_wall_pbr.gd":
		push_error("DUNGEON_3D_VALIDATE_FAIL castle_wall_wrapper_not_active")
		quit(1)
		return
	var castle_meshes := castle_wall.find_children("*", "MeshInstance3D", true, false)
	var castle_mesh := castle_meshes[0] as MeshInstance3D if not castle_meshes.is_empty() else null
	if castle_mesh == null or castle_mesh.material_override == null:
		push_error("DUNGEON_3D_VALIDATE_FAIL cartoon_pbr_material_missing")
		quit(1)
		return
	var doorway := dungeon.get_node("GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Doorways/EastDoorway") as Node3D
	var glow_meshes := doorway.find_children("DoorGlow", "MeshInstance3D", true, false)
	if glow_meshes.is_empty() or (glow_meshes[0] as MeshInstance3D).material_override != null:
		push_error("DUNGEON_3D_VALIDATE_FAIL doorway_glow_not_preserved")
		quit(1)
		return
	var arch_visual := doorway.get_node_or_null("ArchVisual")
	if arch_visual == null:
		push_error("DUNGEON_3D_VALIDATE_FAIL doorway_arch_missing")
		quit(1)
		return
	var hidden_frame_names := [&"JambL", &"JambR", &"Lintel"]
	for frame_name in hidden_frame_names:
		for frame_node in doorway.find_children(String(frame_name), "MeshInstance3D", true, false):
			if (frame_node as MeshInstance3D).visible:
				push_error("DUNGEON_3D_VALIDATE_FAIL doorway_square_frame_visible_" + String(frame_name))
				quit(1)
				return
	var room_doorway_rotations := {
		"GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Doorways/EastDoorway": 270.0,
		"GridMapDungeon/ModularAssembly/Rooms/RoomB_SoulSanctum/Doorways/WestDoorway": 90.0,
		"GridMapDungeon/ModularAssembly/Rooms/RoomB_SoulSanctum/Doorways/EastDoorway": 270.0,
		"GridMapDungeon/ModularAssembly/Rooms/RoomC_Bloodworks/Doorways/WestDoorway": 90.0,
	}
	for doorway_path in room_doorway_rotations:
		var room_doorway := dungeon.get_node(doorway_path) as Node3D
		var actual_rotation := fposmod(room_doorway.rotation_degrees.y, 360.0)
		if not is_equal_approx(actual_rotation, room_doorway_rotations[doorway_path]):
			push_error("DUNGEON_3D_VALIDATE_FAIL doorway_rotation_" + doorway_path)
			quit(1)
			return
	var wing_doorway := dungeon.get_node("GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls/EntryDoorway") as Node3D
	if not is_equal_approx(fposmod(wing_doorway.rotation_degrees.y, 360.0), 0.0):
		push_error("DUNGEON_3D_VALIDATE_FAIL wing_entry_doorway_rotation")
		quit(1)
		return

	var required_paths := [
		"GridMapDungeon",
		"GridMapDungeon/FloorGridMap",
		"GridMapDungeon/StructureGridMap",
		"GridMapDungeon/BoundaryGridMap",
		"GridMapDungeon/PropGridMap",
		"GridMapDungeon/ModularAssembly",
		"GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt",
		"GridMapDungeon/ModularAssembly/Rooms/RoomB_SoulSanctum",
		"GridMapDungeon/ModularAssembly/Rooms/RoomC_Bloodworks",
		"GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Floors/OriginalFloor_-3_-1",
		"GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Walls/OriginalNorth_-2",
		"GridMapDungeon/ModularAssembly/Rooms/RoomA_EntryCrypt/Doorways/EastDoorway",
		"GridMapDungeon/ModularAssembly/Corridors/Corridor_AB",
		"GridMapDungeon/ModularAssembly/Corridors/Corridor_BC",
		"GridMapDungeon/ModularAssembly/Corridors/Corridor_AB/Floors/OriginalFloor_0_0",
		"GridMapDungeon/ModularAssembly/Corridors/Corridor_AB/Doorways",
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
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Floors",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Floors/MainFloor_North",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls/EntryDoorway",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls/WestBranchDoorway",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls/EastBranchDoorway",
		"GridMapDungeon/ModularAssembly/CorridorFlexibleWing/Walls/MainSouthEnd",
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
	var corridor_wing := dungeon.get_node("GridMapDungeon/ModularAssembly/CorridorFlexibleWing")
	if corridor_wing.get_node("Floors").get_child_count() != 26:
		push_error("DUNGEON_3D_VALIDATE_FAIL flexible_floor_count=%d" % corridor_wing.get_node("Floors").get_child_count())
		quit(1)
		return
	if corridor_wing.get_node("Walls").get_child_count() < 31:
		push_error("DUNGEON_3D_VALIDATE_FAIL flexible_wall_count=%d" % corridor_wing.get_node("Walls").get_child_count())
		quit(1)
		return
	if corridor_wing.get_node("Walls").get_child_count() != 31:
		push_error("DUNGEON_3D_VALIDATE_FAIL flexible_wall_count_expected_31=%d" % corridor_wing.get_node("Walls").get_child_count())
		quit(1)
		return
	for branch_name in [&"WestBranchDoorway", &"EastBranchDoorway"]:
		var branch_doorway := corridor_wing.get_node("Walls/" + String(branch_name)) as Node3D
		if not is_equal_approx(fposmod(branch_doorway.rotation_degrees.y, 360.0), 90.0):
			push_error("DUNGEON_3D_VALIDATE_FAIL branch_doorway_rotation_" + String(branch_name))
			quit(1)
			return
	if corridor_wing.get_node("Walls").get_node_or_null("North_02_02") != null or corridor_wing.get_node("Walls").get_node_or_null("North_02_03") != null:
		push_error("DUNGEON_3D_VALIDATE_FAIL flexible_path_blocked_by_cross_wall")
		quit(1)
		return
	if (dungeon.get_node("Doors") as Node3D).visible:
		push_error("DUNGEON_3D_VALIDATE_FAIL editor_door_markers_visible")
		quit(1)
		return
	for spawn_path in ["Spawn_Room_A_From_B", "Spawn_Room_B_From_A", "Spawn_Room_C_From_B", "Spawn_Room_B_From_C"]:
		if (dungeon.get_node(spawn_path) as Node3D).visible:
			push_error("DUNGEON_3D_VALIDATE_FAIL editor_spawn_marker_visible=%s" % spawn_path)
			quit(1)
			return
	var corridor_ab := dungeon.get_node("GridMapDungeon/ModularAssembly/Corridors/Corridor_AB")
	if corridor_ab.get_node("Doorways").get_child_count() != 0:
		push_error("DUNGEON_3D_VALIDATE_FAIL corridor_doorway_duplicate")
		quit(1)
		return
	var expected_door_positions := {
		"Doors/Door_A_to_B": Vector3(-1.973, 1.1, 0),
		"Doors/Door_B_to_A": Vector3(5.919, 1.1, 0),
		"Doors/Door_B_to_C": Vector3(17.757, 1.1, 0),
		"Doors/Door_C_to_B": Vector3(25.649, 1.1, 0),
	}
	for door_path in expected_door_positions:
		if not (dungeon.get_node(door_path) as Node3D).position.is_equal_approx(expected_door_positions[door_path]):
			push_error("DUNGEON_3D_VALIDATE_FAIL door_position=%s actual=%s" % [door_path, (dungeon.get_node(door_path) as Node3D).position])
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
	target_monster.set("_player", player)
	target_monster.set("_attack_cooldown_timer", 0.0)
	target_monster.call("_start_attack", Vector3.FORWARD)
	if float(target_monster.get("_attack_elapsed")) < 0.0:
		push_error("DUNGEON_3D_VALIDATE_FAIL monster_attack_did_not_start")
		quit(1)
		return
	await create_timer(0.62).timeout
	var monster_visual := target_monster.get_node("Visual") as Node3D
	if monster_visual.scale.y <= 1.15 or monster_visual.position.y <= 0.12:
		push_error("DUNGEON_3D_VALIDATE_FAIL monster_attack_animation_not_visible")
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
