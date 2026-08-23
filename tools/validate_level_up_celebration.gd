extends SceneTree

const CELEBRATION_SCENE := preload("res://ui/dungeon_level_up_celebration_3d.tscn")


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var celebration := CELEBRATION_SCENE.instantiate() as DungeonLevelUpCelebration3D
	root.add_child(celebration)
	celebration.play(12, 5, 1)
	_assert(celebration.visible, "celebration must become visible")
	_assert(celebration.is_playing(), "celebration tween must be running")
	_assert(celebration.get_node("LevelLabel").text == "LEVEL UP!  LV.12", "level label mismatch")
	_assert(celebration.get_node("RewardLabel").text == "能力點 +5　技能點 +1", "reward label mismatch")
	_assert(celebration.get_node("Sparkles").emitting, "sparkle burst must emit")
	_assert(celebration.get_node("LevelLabel").fixed_size, "level text must remain readable across camera zoom")
	_assert(celebration.get_node("RewardLabel").fixed_size, "reward text must remain readable across camera zoom")

	var progression := DungeonProgression.new()
	root.add_child(progression)
	var level_events: Array[Array] = []
	progression.leveled_up.connect(
		func(level: int, attribute_points: int, skill_points: int) -> void:
			level_events.append([level, attribute_points, skill_points])
	)
	_assert(progression.add_experience(250) == 2, "250 EXP must cross two early level thresholds")
	_assert(level_events.size() == 1, "multi-level gains must emit one aggregated celebration")
	_assert(level_events[0] == [3, 10, 2], "multi-level celebration must report the real total award")

	var fanfare := load("res://assets/audio/sfx/level_up_fanfare.wav") as AudioStreamWAV
	var victory := load("res://assets/audio/sfx/level_up.mp3") as AudioStreamMP3
	_assert(fanfare != null and fanfare.get_length() > 2.5, "level-up fanfare must load")
	_assert(victory != null and victory.get_length() > fanfare.get_length(), "victory stinger must remain separate")

	print("LEVEL_UP_CELEBRATION_VALIDATE_OK")
	celebration.queue_free()
	progression.queue_free()
	fanfare = null
	victory = null
	await process_frame
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
