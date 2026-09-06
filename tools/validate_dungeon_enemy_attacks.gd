extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred(&"_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var dungeon := load("res://levels/dungeon_3d.tscn").instantiate() as Node3D
	root.add_child(dungeon)
	await process_frame
	var prologue := dungeon.get_node_or_null("PrologueDialogue")
	if prologue != null:
		prologue.free()
	paused = false
	var player := dungeon.get_node("Player") as DungeonPlayer3D
	player.set_physics_process(false)
	for candidate in get_nodes_in_group(&"dungeon_monsters"):
		candidate.set_physics_process(false)
		candidate.set("_attack_elapsed", -1.0)
	var cases := {
		"SkeletonWarrior_A1": &"Attack_Slash",
		"SkeletonWarrior_B1": &"Attack_Slash",
		"SkeletonChampion_Boss": &"Attack_Slash",
		"AshenHound_A2": &"Pounce_Bite",
		"SkeletonArcher_B2": &"Attack_Shoot",
		"SkeletonArcher_C1": &"Attack_Shoot",
	}
	for monster_name in cases:
		var monster := dungeon.get_node("Monsters/" + monster_name) as DungeonMonster3D
		var visual := monster.get_node("Visual") as Node3D
		var anim := visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
		monster.set("_player", player)
		monster.set("_attack_cooldown_timer", 0.0)
		monster.set("_attack_variant", 1)
		player.global_position = monster.global_position + Vector3.FORWARD * (5.0 if monster.is_ranged else 1.4)
		# Exercise the real AI entry, where Run used to overwrite the attack.
		monster.call(&"_physics_process", 0.0)
		var expected: StringName = monster.call(&"_resolve_model_anim", cases[monster_name])
		_check(not expected.is_empty(), monster_name + " missing attack animation")
		_check(anim != null and anim.current_animation == expected, monster_name + " AI overwrote attack with locomotion")
		var base_scale := visual.scale
		var base_y := visual.position.y
		var duration: float = monster.get("_attack_duration")
		var arrow_count := 0
		for frame in range(ceili(duration * 60.0) + 1):
			monster.call(&"_tick_attack", 1.0 / 60.0)
			monster.call(&"_update_visual", 1.0 / 60.0)
			_check(visual.scale.is_equal_approx(base_scale), monster_name + " inherited slime stretch")
			_check(is_equal_approx(visual.position.y, base_y), monster_name + " inherited slime jump")
			for child in monster.get_parent().get_children():
				if child is SkeletonArrow3D:
					arrow_count += 1
					_check(float(monster.get("_attack_elapsed")) >= monster.attack_windup + monster.attack_hit_delay, "Arrow released before shoot pose")
					child.free()
			if float(monster.get("_attack_elapsed")) < 0.0:
				break
		_check(float(monster.get("_attack_elapsed")) < 0.0, monster_name + " attack did not finish")
		_check(arrow_count == (1 if monster.is_ranged else 0), monster_name + " incorrect projectile count")
		if monster_name == "AshenHound_A2":
			monster.set("_attack_cooldown_timer", 0.0)
			monster.call(&"_start_attack", Vector3.FORWARD)
			_check(anim.current_animation == monster.call(&"_resolve_model_anim", &"Claw_Swipe"), "Hound must alternate claw swipe")
			monster.set("_attack_elapsed", -1.0)
		print("DUNGEON_ATTACK_CHECK ", monster_name, " clip=", expected, " arrows=", arrow_count)
	dungeon.free()
	await process_frame
	print("DUNGEON_ENEMY_ATTACKS_", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
