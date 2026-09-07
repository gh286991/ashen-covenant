extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var dungeon := load("res://levels/dungeon_3d.tscn").instantiate() as AshenDungeon3D
	root.add_child(dungeon)
	await process_frame
	dungeon.get_node("PrologueDialogue").free()
	assert(ProjectSettings.get_setting("physics/common/physics_interpolation"))
	assert(dungeon.player.is_physics_interpolated_and_enabled())
	assert(not dungeon.camera.is_physics_interpolated())
	assert(not dungeon.combat_feedback.is_physics_interpolated())
	assert(not dungeon.level_up_celebration.is_physics_interpolated())
	for monster in get_nodes_in_group(&"dungeon_monsters"):
		assert(monster.is_physics_interpolated_and_enabled())
		monster.set_physics_process(false)
	dungeon.player.set_physics_process(false)
	# Exaggerate the physics/render-rate difference to expose camera stepping.
	Engine.physics_ticks_per_second = 10
	Engine.max_fps = 120
	var previous_raw := dungeon.player.global_position
	var previous_smooth := previous_raw
	var interpolated_frames := 0
	var start := Time.get_ticks_msec()
	var move_probe := func() -> void: dungeon.player.position.x += 0.1
	physics_frame.connect(move_probe)
	while Time.get_ticks_msec() - start < 1000:
		await process_frame
		var raw := dungeon.player.global_position
		var smooth := dungeon.player.get_global_transform_interpolated().origin
		if raw.is_equal_approx(previous_raw) and not smooth.is_equal_approx(previous_smooth):
			interpolated_frames += 1
		previous_raw = raw
		previous_smooth = smooth
	physics_frame.disconnect(move_probe)
	assert(interpolated_frames > 0, "Rendered actor must move between physics ticks")
	for spawn_name in ["Spawn_Room_B_From_A", "Spawn_Room_C_From_B"]:
		var spawn := dungeon.get_node(spawn_name) as Node3D
		dungeon.transition_player(spawn, null)
		assert(dungeon.player.global_position.is_equal_approx(spawn.global_position))
		var expected := Vector3(spawn.global_position.x, 0.0, spawn.global_position.z) + dungeon._get_camera_offset()
		assert(dungeon.camera.global_position.is_equal_approx(expected))
		await process_frame
		assert(dungeon.camera.global_position.is_equal_approx(expected), "Camera must not lerp back toward the old room")
		await physics_frame
		await physics_frame
		await process_frame
		assert(dungeon.player.get_global_transform_interpolated().origin.is_equal_approx(spawn.global_position), "Teleport must reset previous room's interpolation")
		assert(dungeon.camera.global_position.is_equal_approx(expected))
	print("DUNGEON_INTERPOLATION_PASS intermediate_frames=", interpolated_frames, " transitions=2 effects=render_frame")
	dungeon.free()
	await process_frame
	quit()
