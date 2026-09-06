extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://levels/action_combat_lab.tscn") as PackedScene
	assert(packed != null, "Action combat lab scene must load")
	var lab := packed.instantiate()
	root.add_child(lab)
	await process_frame
	await physics_frame
	var player := lab.get_node("Player") as ActionCombatPlayer3D
	assert(player != null, "Action player must exist")
	assert(player.state == ActionCombatPlayer3D.State.FREE, "Player must start ready")
	var hero_animation_player := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(hero_animation_player != null, "Hero animation player must import")
	assert(player.visual.get_weapon_visual_count() > 0, "Hero weapon visuals must be discoverable")
	assert(not player.visual.is_weapon_drawn(), "Hero must keep the sword hidden during idle and locomotion")
	var hero_meshes := player.find_children("*", "MeshInstance3D", true, false)
	assert(hero_meshes.size() >= 40, "Hero model must import its visible mesh parts")
	for hero_mesh_candidate in hero_meshes:
		var hero_mesh := hero_mesh_candidate as MeshInstance3D
		assert(hero_mesh != null, "Every imported hero mesh must instantiate")
		if not hero_mesh.is_visible_in_tree():
			assert(_has_named_ancestor(hero_mesh, "sword", player.visual), "Only the hero sword may be hidden during locomotion")
	var hero_clips := hero_animation_player.get_animation_list()
	assert(player.visual.call(&"_resolve_animation", &"Idle") != StringName(), "Hero idle clip resolver must accept imported suffixes")
	assert(player.visual.call(&"_resolve_animation", &"Run") != StringName(), "Hero run clip resolver must accept imported suffixes")
	for required_clip in [&"Attack_1_Horizontal", &"Attack_2_Return", &"Attack_3_Overhead"]:
		assert(_contains_clip(hero_clips, required_clip), "Hero combo clip must import: " + required_clip)
		var resolved_clip: StringName = player.visual.call(&"_resolve_animation", required_clip)
		assert(hero_animation_player.get_animation(resolved_clip).loop_mode == Animation.LOOP_NONE, "Hero combo clips must never loop")

	assert(InputMap.has_action(&"attack") and InputMap.has_action(&"dash"), "Combat input actions must exist")
	for combo_step in range(1, 4):
		player.call(&"_start_light", combo_step)
		assert(player.state == ActionCombatPlayer3D.State.LIGHT, "Attack input must begin the combo")
		assert(player.visual.is_weapon_drawn(), "Hero must draw the sword for every combo attack")
		assert(_contains_clip(PackedStringArray([hero_animation_player.current_animation]), [&"Attack_1_Horizontal", &"Attack_2_Return", &"Attack_3_Overhead"][combo_step - 1]), "Each combo step must play its own clip")
	player.combo_step = 1
	player.set("_combo_grace", 0.5)
	assert(player.call(&"_next_light_step") == 2, "A follow-up pressed during combo grace must advance to attack two")
	player.combo_step = 2
	assert(player.call(&"_next_light_step") == 3, "A follow-up pressed during combo grace must advance to attack three")
	player.combo_step = 3
	assert(player.call(&"_next_light_step") == 1, "A completed combo must restart at attack one")

	player.call(&"_start_dash", Vector3.RIGHT)
	assert(player.state == ActionCombatPlayer3D.State.DASH, "Dash must cancel an attack")
	assert(not player.visual.is_weapon_drawn(), "Hero must sheathe the sword when returning to movement")
	var combat_fx := lab.get_node("ActionCombatFX3D") as ActionCombatFX3D
	var impact_flash := lab.get_node("HUD/ImpactFlash") as ColorRect
	assert(impact_flash != null, "Combat HUD must include a full-screen impact flash layer")
	await create_timer(0.3).timeout
	var fx_child_count := combat_fx.get_child_count()
	combat_fx.show_slash(player.global_position, Vector3.FORWARD, 3, false, 0.36)
	await process_frame
	assert(combat_fx.get_child_count() == fx_child_count + 3, "A refined sword swing must create afterimage, ribbon, and blade-edge layers")
	for child_index in range(fx_child_count, combat_fx.get_child_count()):
		var slash_layer := combat_fx.get_child(child_index) as MeshInstance3D
		assert(slash_layer != null and slash_layer.material_override is ShaderMaterial, "Every sword-swing layer must use the gradient energy shader")
	await create_timer(0.25).timeout
	assert(combat_fx.get_child_count() > fx_child_count, "A slowed third swing must keep its sword trail visible through the follow-through")
	await create_timer(0.35).timeout
	await process_frame
	assert(combat_fx.get_child_count() == fx_child_count, "Sword-swing layers must clean themselves up after the trail fades")
	var impact_child_count := combat_fx.get_child_count()
	combat_fx.show_hit(player.global_position + Vector3.UP, Vector3.RIGHT, 2, false, false)
	await process_frame
	assert(combat_fx.get_child_count() >= impact_child_count + 10, "A confirmed hit must layer a contact core, directional ring, shards, and sparks")

	await create_timer(0.75).timeout
	var spawned := get_nodes_in_group(&"action_enemies")
	assert(spawned.size() >= 3, "The first combat wave must spawn")
	var hound: ActionCombatEnemy3D
	var skeleton: ActionCombatEnemy3D
	var archer: ActionCombatEnemy3D
	var standard_enemy: ActionCombatEnemy3D
	for candidate in spawned:
		var action_enemy := candidate as ActionCombatEnemy3D
		if action_enemy != null and action_enemy.hound:
			hound = action_enemy
		elif action_enemy != null and action_enemy.skeleton:
			skeleton = action_enemy
		elif action_enemy != null and action_enemy.skeleton_archer:
			archer = action_enemy
		elif action_enemy != null:
			standard_enemy = action_enemy
	assert(hound != null, "Every wave must include the new Ashen Hound")
	assert(skeleton != null, "Every wave must include the beginner Skeleton Warrior")
	assert(archer != null, "Wave must include the new ranged Skeleton Archer")
	assert(standard_enemy != null, "The original enemy type must still spawn beside the hound")
	var formation_targets: Array[Vector3] = []
	for formation_enemy in [hound, skeleton, standard_enemy]:
		formation_targets.append(formation_enemy.call(&"_engagement_slot_target") as Vector3)
		assert(formation_targets[-1].distance_to(player.global_position) > 1.35, "Enemies must aim for a surrounding engagement ring instead of the player's center")
	for first_target in range(formation_targets.size()):
		for second_target in range(first_target + 1, formation_targets.size()):
			assert(formation_targets[first_target].distance_to(formation_targets[second_target]) > 0.75, "Each melee enemy must receive a distinct formation slot")
	hound.state = ActionCombatEnemy3D.State.TELEGRAPH
	assert(not skeleton.call(&"_can_start_attack"), "A three-enemy wave must allow only one committed attacker at a time")
	hound.state = ActionCombatEnemy3D.State.CHASE
	var hound_animation_player := hound.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(hound_animation_player != null, "Ashen Hound animation player must import")
	var hound_clips := hound_animation_player.get_animation_list()
	assert(_contains_clip(hound_clips, &"Pounce_Bite"), "Hound pounce-bite animation must import")
	assert(_contains_clip(hound_clips, &"Claw_Swipe"), "Hound claw-swipe animation must import")
	assert(_contains_clip(hound_clips, &"Hit_Recoil"), "Hound hit-recoil animation must import")
	var hound_model := hound.get_node("Visual/AshenHound") as Node3D
	assert(hound_model != null and is_equal_approx(absf(hound_model.rotation.y), PI), "Hound model must face the gameplay forward direction")
	assert(hound_animation_player.get_animation(hound.call(&"_resolve_animation", &"Idle")).loop_mode == Animation.LOOP_LINEAR, "Hound idle animation must loop")
	assert(hound_animation_player.get_animation(hound.call(&"_resolve_animation", &"Run")).loop_mode == Animation.LOOP_LINEAR, "Hound run animation must loop")
	var slime_shell := standard_enemy.get_node_or_null("Visual/GelShell") as MeshInstance3D
	var slime_pupil := standard_enemy.get_node_or_null("Visual/EyeLeft/PupilLeft") as MeshInstance3D
	assert(slime_shell != null and slime_pupil != null, "Slime must include its refined gel shell and pupil details")
	var slime_base_scale := standard_enemy.visual.scale
	standard_enemy.call(&"_start_telegraph")
	standard_enemy.set("_state_elapsed", standard_enemy.telegraph_duration * 0.62)
	standard_enemy.call(&"_tick_telegraph", 0.0)
	assert(standard_enemy.visual.scale.x > slime_base_scale.x * 1.2, "Slime anticipation must visibly squash outward")
	assert(standard_enemy.visual.scale.y < slime_base_scale.y * 0.8, "Slime anticipation must visibly compress before launch")
	standard_enemy.state = ActionCombatEnemy3D.State.STRIKE
	standard_enemy.set("_state_duration", 0.3)
	standard_enemy.set("_state_elapsed", 0.18)
	standard_enemy.set("_strike_done", true)
	standard_enemy.call(&"_tick_strike", 0.0)
	assert(standard_enemy.visual.scale.x > slime_base_scale.x * 1.15, "Slime strike must include a separate landing squash")
	standard_enemy.call(&"_reset_visual_pose")
	standard_enemy.state = ActionCombatEnemy3D.State.CHASE
	var skeleton_animation_player := skeleton.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(skeleton_animation_player != null, "Skeleton Warrior animation player must import")
	var skeleton_meshes := skeleton.find_children("*", "MeshInstance3D", true, false)
	assert(skeleton_meshes.size() >= 55, "Skeleton Warrior must import all of its detailed visible bone parts")
	var skeleton_clips := skeleton_animation_player.get_animation_list()
	for required_clip in [&"Idle", &"Run", &"Attack_Slash", &"Hit_Recoil"]:
		assert(_contains_clip(skeleton_clips, required_clip), "Skeleton animation must import: " + required_clip)
	assert(skeleton_animation_player.get_animation(skeleton.call(&"_resolve_animation", &"Idle")).loop_mode == Animation.LOOP_LINEAR, "Skeleton idle animation must loop")
	assert(skeleton_animation_player.get_animation(skeleton.call(&"_resolve_animation", &"Run")).loop_mode == Animation.LOOP_LINEAR, "Skeleton run animation must loop")
	var archer_animation_player := archer.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(archer_animation_player != null, "Skeleton Archer animation player must import")
	var archer_meshes := archer.find_children("*", "MeshInstance3D", true, false)
	assert(archer_meshes.size() >= 50, "Skeleton Archer must import all detailed bone parts and crypt longbow")
	var archer_clips := archer_animation_player.get_animation_list()
	for required_clip in [&"Idle", &"Run", &"Attack_Shoot", &"Hit_Recoil"]:
		assert(_contains_clip(archer_clips, required_clip), "Skeleton Archer animation must import: " + required_clip)
	assert(archer_animation_player.get_animation(archer.call(&"_resolve_animation", &"Idle")).loop_mode == Animation.LOOP_LINEAR, "Archer idle animation must loop")
	assert(archer_animation_player.get_animation(archer.call(&"_resolve_animation", &"Run")).loop_mode == Animation.LOOP_LINEAR, "Archer run animation must loop")
	standard_enemy.global_position = hound.global_position + Vector3(0.35, 0.0, 0.0)
	var hound_separation: Vector3 = hound.call(&"_calculate_separation_velocity")
	var standard_separation: Vector3 = standard_enemy.call(&"_calculate_separation_velocity")
	assert(hound_separation.length() > 0.1 and standard_separation.length() > 0.1, "Crowded enemies must generate separation steering")
	assert(hound_separation.dot(standard_separation) < 0.0, "Nearby enemies must steer away from each other")
	player.global_position = Vector3(8.0, 0.95, 0.0)
	var crowd: Array[ActionCombatEnemy3D] = []
	for index in range(mini(3, spawned.size())):
		var crowd_enemy := spawned[index] as ActionCombatEnemy3D
		crowd.append(crowd_enemy)
		crowd_enemy.global_position = Vector3(0.0, 0.04, index * 0.08)
		crowd_enemy.state = ActionCombatEnemy3D.State.CHASE
		crowd_enemy.set("_attack_cooldown", 2.0)
	await create_timer(0.65).timeout
	var minimum_spacing := INF
	for first in range(crowd.size()):
		for second in range(first + 1, crowd.size()):
			minimum_spacing = minf(minimum_spacing, crowd[first].global_position.distance_to(crowd[second].global_position))
	assert(minimum_spacing > 0.62, "A moving enemy crowd must physically spread instead of overlapping")
	hound.set("_attack_variant", 1)
	hound.call(&"_start_telegraph")
	assert(_contains_clip(PackedStringArray([hound_animation_player.current_animation]), &"Pounce_Bite"), "Hound must start with its pounce animation")
	hound.call(&"_start_telegraph")
	assert(_contains_clip(PackedStringArray([hound_animation_player.current_animation]), &"Claw_Swipe"), "Hound must alternate to its claw animation")
	hound.state = ActionCombatEnemy3D.State.CHASE
	assert(hound.take_action_damage(5.0, player, 2.0, 0.3, false), "Hound must accept action damage")
	assert(_contains_clip(PackedStringArray([hound_animation_player.current_animation]), &"Hit_Recoil"), "Hound damage must play the hit-recoil clip")
	assert(hound.hit_flash.light_energy > 0.0, "Hound damage must trigger its impact flash")
	await create_timer(0.18).timeout
	assert(hound.state == ActionCombatEnemy3D.State.STAGGER, "Hound recoil must not be cut short by a brief player stagger")
	assert(_contains_clip(PackedStringArray([hound_animation_player.current_animation]), &"Hit_Recoil"), "Hound must hold its recoil through the visible impact pose")
	assert(hound.hit_flash.light_energy <= 0.01, "Hound impact flash must fade instead of remaining lit")
	skeleton.state = ActionCombatEnemy3D.State.CHASE
	skeleton.call(&"_start_telegraph")
	assert(_contains_clip(PackedStringArray([skeleton_animation_player.current_animation]), &"Attack_Slash"), "Skeleton telegraph must play its dedicated sword slash")
	skeleton.state = ActionCombatEnemy3D.State.CHASE
	assert(skeleton.take_action_damage(5.0, player, 2.0, 0.2, false), "Skeleton must accept action damage")
	assert(_contains_clip(PackedStringArray([skeleton_animation_player.current_animation]), &"Hit_Recoil"), "Skeleton damage must play the hit-recoil clip")
	assert(skeleton.hit_flash.light_energy > 0.0, "Skeleton damage must trigger its cyan soul flash")
	await create_timer(0.18).timeout
	assert(skeleton.state == ActionCombatEnemy3D.State.STAGGER, "Skeleton recoil must remain visible long enough to read")
	standard_enemy.global_position = Vector3(4.0, 0.04, 4.0)
	player.global_position = Vector3(4.0, 0.95, 0.0)
	standard_enemy.call(&"_face_player")
	standard_enemy.state = ActionCombatEnemy3D.State.STRIKE
	standard_enemy.set("_state_elapsed", 0.0)
	var strike_origin := standard_enemy.global_position
	await physics_frame
	await physics_frame
	assert(standard_enemy.global_position.distance_to(strike_origin) > 0.01, "Enemy strike state must physically advance")
	standard_enemy.state = ActionCombatEnemy3D.State.CHASE
	assert(standard_enemy.is_alive(), "Original enemy must remain combat-ready")
	assert(standard_enemy.take_action_damage(5.0, player, 2.0, 0.2, false), "Original enemy must accept normal action damage")
	assert(standard_enemy.is_alive(), "Normal damage must not incorrectly defeat the original enemy")
	standard_enemy.call(&"_tick_stagger", 0.01)
	assert(standard_enemy.visual.scale.x > slime_base_scale.x * 1.2, "Slime hit impact must hold a readable squash pose")
	assert(standard_enemy.visual.scale.y < slime_base_scale.y * 0.75, "Slime hit impact hold must not be skipped")
	assert(standard_enemy.state == ActionCombatEnemy3D.State.STAGGER, "Slime hit recovery must not immediately return to chase")
	await create_timer(0.08).timeout
	assert(standard_enemy.take_action_damage(999.0, player, 2.0, 0.2, true), "Original enemy must accept lethal action damage")
	assert(not standard_enemy.is_alive(), "Lethal action damage must defeat the original enemy")

	print("ACTION_COMBAT_LAB_VALIDATED")
	Engine.time_scale = 1.0
	lab.free()
	await process_frame
	call_deferred(&"quit")


func _contains_clip(clips: PackedStringArray, expected: StringName) -> bool:
	var needle := String(expected).to_lower()
	for clip in clips:
		var normalized := String(clip).to_lower()
		if normalized == needle or normalized.ends_with("/" + needle) or normalized.begins_with(needle + "."):
			return true
	return false


func _has_named_ancestor(node: Node, needle: String, stop_at: Node) -> bool:
	var current := node
	while current != null and current != stop_at:
		if String(current.name).to_lower().contains(needle):
			return true
		current = current.get_parent()
	return false
