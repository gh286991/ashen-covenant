extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var progression := DungeonProgression.new()
	root.add_child(progression)
	assert(progression.level == 1, "Progression starts at level 1")
	assert(progression.attribute_points == 5, "New characters receive five initial allocation points")
	assert(progression.skill_points == 1, "New characters receive one initial skill point")
	assert(not progression.spend_attribute_point(&"unknown"), "Unknown attributes must be rejected")
	var points_before_cap_test := progression.attribute_points
	progression.strength = 99
	assert(not progression.spend_attribute_point(&"strength"), "Attributes at 99 must reject further points")
	assert(progression.attribute_points == points_before_cap_test, "Rejected capped attributes must not consume points")
	progression.strength = 10
	assert(not progression.unlock_skill(&"unknown_skill"), "Unknown skills must be rejected")
	assert(not progression.equip_skill(-1, &"ash_slash"), "Invalid loadout slots must be rejected")
	assert(progression.add_experience(99) == 0, "EXP below the threshold must not level up")
	assert(progression.add_experience(1) == 1, "Reaching the threshold must level up")
	assert(progression.level == 2, "Level must increase")
	assert(progression.attribute_points == 10, "A level-up awards exactly five attribute points")
	assert(progression.skill_points == 2, "A level-up awards exactly one skill point")

	var attack_bonus_before := float(progression.get_snapshot().attack_damage_bonus)
	assert(progression.spend_attribute_point(&"strength"), "Strength point can be spent")
	assert(float(progression.get_snapshot().attack_damage_bonus) > attack_bonus_before, "Strength changes derived attack")
	var health_bonus_before := float(progression.get_snapshot().max_health_bonus)
	assert(progression.spend_attribute_point(&"vitality"), "Vitality point can be spent")
	assert(float(progression.get_snapshot().max_health_bonus) > health_bonus_before, "Vitality changes derived health")
	var speed_bonus_before := float(progression.get_snapshot().move_speed_bonus)
	assert(progression.spend_attribute_point(&"agility"), "Agility point can be spent")
	assert(float(progression.get_snapshot().move_speed_bonus) > speed_bonus_before, "Agility changes derived speed")
	var critical_before := float(progression.get_snapshot().critical_chance)
	assert(progression.spend_attribute_point(&"luck"), "Luck point can be spent")
	assert(float(progression.get_snapshot().critical_chance) > critical_before, "Luck changes critical chance")

	assert(not progression.equip_skill(1, &"shadow_step"), "Locked skills cannot be equipped")
	assert(progression.unlock_skill(&"shadow_step"), "A skill point unlocks an available skill")
	assert(not progression.unlock_skill(&"shadow_step"), "Already unlocked skills cannot spend another point")
	assert(progression.equip_skill(1, &"shadow_step"), "Unlocked skills can be equipped")
	assert(progression.get_snapshot().skill_loadout[1] == "shadow_step", "Equipped skill is stored in progression data")
	progression.queue_free()
	await process_frame
	progression = null

	var dungeon_scene := load("res://levels/dungeon_3d.tscn") as PackedScene
	assert(dungeon_scene != null, "Dungeon scene must load")
	var dungeon := dungeon_scene.instantiate()
	root.add_child(dungeon)
	await process_frame
	var player := dungeon.get_node("%Player") as DungeonPlayer3D
	assert(player != null and player.progression != null, "Dungeon player owns the progression component")
	var base_damage := player.attack_damage
	var base_health := player.max_health
	var base_speed := player.move_speed
	player.progression.spend_attribute_point(&"strength")
	player.progression.spend_attribute_point(&"vitality")
	player.progression.spend_attribute_point(&"agility")
	assert(player.attack_damage > base_damage, "Strength is applied to real dungeon attack damage")
	assert(player.max_health > base_health, "Vitality is applied to real dungeon max health")
	assert(player.move_speed > base_speed, "Agility is applied to real dungeon movement speed")
	var xp_before := player.progression.experience
	var monster := get_first_node_in_group(&"dungeon_monsters") as DungeonMonster3D
	assert(monster != null, "Dungeon contains an XP-awarding monster")
	monster.died.emit()
	assert(player.progression.experience == xp_before + monster.experience_reward, "Monster death awards real EXP")

	monster = null
	player = null
	dungeon.queue_free()
	paused = false
	await process_frame
	dungeon = null
	dungeon_scene = null
	print("DUNGEON_PROGRESSION_VALIDATE_OK")
	quit()
