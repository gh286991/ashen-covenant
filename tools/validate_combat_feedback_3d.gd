extends SceneTree


func _init() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var packed := load("res://levels/dungeon_3d.tscn") as PackedScene
	if packed == null:
		_fail("scene_missing")
		return
	var dungeon := packed.instantiate()
	root.add_child(dungeon)
	await process_frame
	# Combat is not available while the opening dialogue owns the pause state.
	# Remove it for this isolated combat test so SceneTree timers and Tweens share
	# the same gameplay pause mode they have after the player enters the dungeon.
	var prologue := dungeon.get_node_or_null("PrologueDialogue") as CanvasLayer
	if prologue != null:
		prologue.queue_free()
		await process_frame
	if paused:
		_fail("prologue_pause_not_released")
		return

	var player := dungeon.get_node("Player") as DungeonPlayer3D
	var monster := dungeon.get_node("Monsters/CryptWraith_A1") as DungeonMonster3D
	var feedback := dungeon.get_node("CombatFeedback3D") as CombatFeedback3D
	var audio := dungeon.get_node("AudioDirector") as AshenAudioDirector
	var health_bar := monster.get_node("HealthBar") as MonsterHealthBar3D
	if audio == null or not audio.is_music_playing():
		_fail("exploration_music_not_playing")
		return
	if audio.sword_hits.size() != 3 or audio.sword_hits.any(func(stream: AudioStream) -> bool: return stream == null):
		_fail("sword_hit_sfx_not_loaded")
		return
	if audio.sword_whooshes.size() != 9 or audio.sword_whooshes.any(func(stream: AudioStream) -> bool: return stream == null):
		_fail("sword_whoosh_sfx_not_loaded")
		return
	if health_bar == null or health_bar.get_child_count() != 1:
		_fail("monster_health_bar_not_built")
		return
	var health_fill := health_bar.get_child(0) as MeshInstance3D
	if health_fill == null or not is_equal_approx((health_fill.mesh as QuadMesh).size.x, MonsterHealthBar3D.BAR_WIDTH):
		_fail("monster_health_bar_not_full_at_spawn")
		return
	if health_bar.visible:
		_fail("monster_health_bar_visible_without_lock")
		return
	if health_bar.position.y >= 0.1:
		_fail("monster_health_bar_not_below_monster")
		return

	if not monster.take_damage(3.0, player):
		_fail("monster_damage_not_accepted")
		return
	await process_frame
	if not is_equal_approx((health_fill.mesh as QuadMesh).size.x, MonsterHealthBar3D.BAR_WIDTH * 0.925) or not health_fill.visible or health_bar.visible:
		_fail("monster_health_bar_not_updated_after_damage")
		return
	monster.set_selected(true)
	await process_frame
	if not health_bar.visible:
		_fail("monster_health_bar_not_visible_when_locked")
		return
	monster.set_selected(false)
	if health_bar.visible:
		_fail("monster_health_bar_not_hidden_after_unlock")
		return
	if feedback.get_child_count() < 1:
		_fail("monster_damage_number_missing")
		return
	if audio.active_effect_count() < 1:
		_fail("monster_hit_sfx_missing")
		return

	if not player.take_damage(4.0, monster):
		_fail("player_damage_not_accepted")
		return
	await process_frame
	if feedback.get_child_count() < 2:
		_fail("player_damage_number_missing")
		return

	await create_timer(CombatFeedback3D.FLOAT_DURATION + 0.2, false).timeout
	await process_frame
	if feedback.get_child_count() != 0:
		_fail("damage_numbers_not_cleaned_up")
		return

	var dying_monster := dungeon.get_node("Monsters/CryptWraith_A2") as DungeonMonster3D
	dying_monster.take_damage(999.0, player)
	await create_timer(0.18).timeout
	if (dying_monster.get_node("HealthBar") as Node3D).visible:
		_fail("monster_health_bar_not_hidden_on_death")
		return
	if not is_instance_valid(dying_monster) or (dying_monster.get_node("Visual/Body") as GeometryInstance3D).transparency <= 0.0:
		_fail("monster_death_fade_not_started")
		return
	await create_timer(0.7).timeout
	if is_instance_valid(dying_monster):
		_fail("monster_death_fade_not_finished")
		return

	print("COMBAT_FEEDBACK_3D_VALIDATE_OK health_bar=ok monster_damage=ok player_damage=ok fade_cleanup=ok death_animation=ok")
	quit(0)


func _fail(reason: String) -> void:
	push_error("COMBAT_FEEDBACK_3D_VALIDATE_FAIL " + reason)
	quit(1)
