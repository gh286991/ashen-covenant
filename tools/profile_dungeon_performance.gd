extends SceneTree

## Run with a visible window: --path . --script tools/profile_dungeon_performance.gd
## Compare the old backend with --rendering-method gl_compatibility --rendering-driver opengl3.
## Optional report: -- --output=/absolute/path/report.json
## Measures wall time, so combat slow motion does not distort frame measurements.

var _results: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use a visible window to measure rendering performance.")
		quit(1)
		return
	seed(42)
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.unresizable = true
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var dungeon := load("res://levels/dungeon_3d.tscn").instantiate() as AshenDungeon3D
	root.add_child(dungeon)
	await process_frame
	dungeon.get_node("PrologueDialogue").free()
	dungeon.player.set("_invincible_timer", 3600.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await create_timer(4.0).timeout
	await _measure("idle", false)
	var start_position := dungeon.player.global_position
	await _measure("walking", true)
	var moved := dungeon.player.global_position.distance_to(start_position)
	print("DUNGEON_PERF_MOVEMENT displacement=", moved)
	var spawn := dungeon.get_node("Spawn_Room_B_From_A") as Node3D
	dungeon.transition_player(spawn, null)
	await create_timer(1.0).timeout
	await _measure("room_b", false)
	var report := {
		"engine": Engine.get_version_info().string,
		"debug": OS.is_debug_build(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"vsync": false,
		"viewport": root.get_texture().get_size(),
		"samples": _results,
	}
	print("DUNGEON_PERF_REPORT ", JSON.stringify(report))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var file := FileAccess.open(argument.trim_prefix("--output="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(report, "\t"))
	dungeon.free()
	await process_frame
	quit()


func _measure(label: String, walking: bool) -> void:
	var samples: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 4000000:
		if walking:
			# Exercise movement and the follow camera in both directions.
			var right := (Time.get_ticks_usec() - start) < 2000000
			Input.action_release(&"move_left" if right else &"move_right")
			Input.action_press(&"move_right" if right else &"move_left")
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	Input.action_release(&"move_right")
	Input.action_release(&"move_left")
	samples.sort()
	var sum := 0.0
	var slow_frames := 0
	for value in samples:
		sum += value
		if value > 16.667:
			slow_frames += 1
	var result := {
		"phase": label,
		"frames": samples.size(),
		"average_ms": sum / samples.size(),
		"p95_ms": samples[int(samples.size() * 0.95)],
		"over_16_67_ms_percent": 100.0 * slow_frames / samples.size(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	}
	_results.append(result)
	print("DUNGEON_PERF ", JSON.stringify(result))
