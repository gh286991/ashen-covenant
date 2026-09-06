extends SceneTree

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var dungeon := load("res://levels/dungeon_3d.tscn").instantiate() as Node3D
	root.add_child(dungeon)
	await process_frame
	dungeon.get_node("PrologueDialogue").free()
	paused = false
	var player := dungeon.get_node("Player") as DungeonPlayer3D
	player.set_physics_process(false)
	for monster in get_nodes_in_group(&"dungeon_monsters"):
		monster.set_physics_process(false)
	var camera := dungeon.get_node("Camera3D") as Camera3D
	var point := player.global_position + Vector3(3.0, 0.0, 3.0)
	point.y = 0.0
	var click := InputEventMouseButton.new()
	click.position = camera.unproject_position(point)
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	player.state = DungeonPlayer3D.State.FREE
	player.call(&"_unhandled_input", click)
	assert(player.state == DungeonPlayer3D.State.HEAVY, "Right click must trigger heavy attack")
	assert(player.facing.dot(Vector3(1, 0, 1).normalized()) > 0.99, "Right click must preserve cursor aim instead of auto-targeting another enemy")
	player.call(&"_finish_action")
	click.button_index = MOUSE_BUTTON_LEFT
	click.shift_pressed = true
	player.call(&"_unhandled_input", click)
	assert(player.state == DungeonPlayer3D.State.LIGHT, "Shift left click must attack on empty ground")
	assert(not player.get("_mouse_target_active"), "Shift left click must not start click movement")
	assert(player.facing.dot(Vector3(1, 0, 1).normalized()) > 0.99, "Shift attack must preserve cursor aim")
	player.call(&"_finish_action")
	click.shift_pressed = false
	player.call(&"_unhandled_input", click)
	assert(player.get("_mouse_target_active"), "Left click on ground must still move")
	assert(player.state == DungeonPlayer3D.State.FREE, "Ground movement must not attack")
	var chest := dungeon.get_node("TreasureProps/TreasureChest_A1") as TreasureChest3D
	await physics_frame
	await process_frame
	click.position = camera.unproject_position(chest.get_node("Collision/Shape").global_position)
	assert(player.call(&"_pick_chest", click.position) == chest, "Chest collider must be pickable through the world ray")
	player.call(&"_unhandled_input", click)
	assert(player.get("_chest_target") == chest, "Left click must select chest before ground movement consumes input")
	assert(not chest.is_opened(), "Distant chest must wait until player approaches")
	player.global_position = chest.global_position + Vector3(0, 0, 1.2)
	player.call(&"_physics_process", 0.0)
	assert(chest.is_opened(), "Selected chest must open when the player reaches interaction range")
	var chest_animation := chest.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(chest_animation != null and chest_animation.is_playing(), "Opening must actually play the lid animation")
	print("DUNGEON_CHEST_CLICK_PASS pick=ok approach=ok opened=ok animation=ok")
	print("DUNGEON_MOUSE_COMBAT_PASS right=heavy cursor_aim=ok shift_left=light left_ground=move")
	dungeon.free()
	await process_frame
	quit()
