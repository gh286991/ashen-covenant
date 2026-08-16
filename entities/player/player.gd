class_name CovenantPlayer
extends CharacterBody2D

const Warrior3DVisualScript = preload("res://entities/player/warrior_3d_visual.gd")

signal attack_requested(origin: Vector2, facing: Vector2, radius: float, packet: DamagePacket, combo_step: int)
signal nova_requested(origin: Vector2, radius: float, packet: DamagePacket)
signal dash_requested(origin: Vector2, direction: Vector2)
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal experience_changed(current: int, required: int, level: int)
signal skill_points_changed(available: int)
signal potions_changed(count: int)
signal equipment_changed
signal level_up_requested(new_level: int)
signal died
signal action_feedback(message: String, color: Color)
signal damaged(position: Vector2, amount: int, direction: Vector2)
signal potion_used

enum AttackPhase { NONE, WINDUP, ACTIVE, RECOVERY }

const MOVE_SPEED := 235.0
const ACCELERATION := 1500.0
const FRICTION := 1900.0
const DASH_SPEED := 720.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 0.78
const ATTACK_COOLDOWN := 0.34
const ATTACK_WINDUP := 0.06
const ATTACK_ACTIVE := 0.055
const ATTACK_RECOVERY := 0.18
const ATTACK_INPUT_BUFFER := 0.12
const HURT_LOCK_DURATION := 0.16
const NOVA_BASE_COOLDOWN := 3.4
const NOVA_MANA_COST := 28.0
const POINTER_STOP_DISTANCE := 10.0
const POINTER_ATTACK_DISTANCE := 68.0
const POINTER_WAYPOINT_DISTANCE := 14.0
const PLAYER_BODY_RADIUS := 14.0
const CRIMSON_FRAME_SIZE := Vector2(80.0, 80.0)
const CRIMSON_ART_SCALE := 1.6
const CRIMSON_PAINTED_FOOT_OFFSET := 16.0
const CRIMSON_FOOT_OFFSET := CRIMSON_PAINTED_FOOT_OFFSET * CRIMSON_ART_SCALE
const CRIMSON_FRAME_COUNTS := {
	&"idle": 6,
	&"walk": 8,
	&"run": 6,
	&"sword_attack": 5,
	&"axe_attack": 7,
	&"hurt": 4,
	&"death": 6,
}
const CRIMSON_SHEETS := {
	&"idle": [
		preload("res://assets/sprites/player_crimson/idle_down.png"),
		preload("res://assets/sprites/player_crimson/idle_left.png"),
		preload("res://assets/sprites/player_crimson/idle_right.png"),
		preload("res://assets/sprites/player_crimson/idle_up.png"),
	],
	&"walk": [
		preload("res://assets/sprites/player_crimson/walk_down.png"),
		preload("res://assets/sprites/player_crimson/walk_left.png"),
		preload("res://assets/sprites/player_crimson/walk_right.png"),
		preload("res://assets/sprites/player_crimson/walk_up.png"),
	],
	&"run": [
		preload("res://assets/sprites/player_crimson/run_down.png"),
		preload("res://assets/sprites/player_crimson/run_left.png"),
		preload("res://assets/sprites/player_crimson/run_right.png"),
		preload("res://assets/sprites/player_crimson/run_up.png"),
	],
	&"sword_attack": [
		preload("res://assets/sprites/player_crimson/sword_attack_down.png"),
		preload("res://assets/sprites/player_crimson/sword_attack_left.png"),
		preload("res://assets/sprites/player_crimson/sword_attack_right.png"),
		preload("res://assets/sprites/player_crimson/sword_attack_up.png"),
	],
	&"axe_attack": [
		preload("res://assets/sprites/player_crimson/axe_attack_down.png"),
		preload("res://assets/sprites/player_crimson/axe_attack_left.png"),
		preload("res://assets/sprites/player_crimson/axe_attack_right.png"),
		preload("res://assets/sprites/player_crimson/axe_attack_up.png"),
	],
	&"hurt": [
		preload("res://assets/sprites/player_crimson/hurt_down.png"),
		preload("res://assets/sprites/player_crimson/hurt_left.png"),
		preload("res://assets/sprites/player_crimson/hurt_right.png"),
		preload("res://assets/sprites/player_crimson/hurt_up.png"),
	],
	&"death": [
		preload("res://assets/sprites/player_crimson/death_down.png"),
		preload("res://assets/sprites/player_crimson/death_left.png"),
		preload("res://assets/sprites/player_crimson/death_right.png"),
		preload("res://assets/sprites/player_crimson/death_up.png"),
	],
}
const SKILL_ORDER: Array[StringName] = [&"iron_oath", &"executioner", &"blood_rush"]
const SKILL_DEFINITIONS := {
	&"iron_oath": {
		"title": "IRON OATH",
		"summary": "+20 Life  •  +3 Armor",
		"max_rank": 3,
	},
	&"executioner": {
		"title": "EXECUTIONER",
		"summary": "+3 Damage  •  +2.5% Critical",
		"max_rank": 3,
	},
	&"blood_rush": {
		"title": "BLOOD RUSH",
		"summary": "+10 Essence  •  Faster Ash Nova",
		"max_rank": 3,
	},
}

var gameplay_enabled := false
var rng := RandomNumberGenerator.new()
var facing := Vector2.UP
var model_facing := Vector2.UP
var last_move_direction := Vector2.UP
var dash_direction := Vector2.UP
var dash_timer := 0.0
var dash_cooldown := 0.0
var attack_cooldown := 0.0
var attack_phase := AttackPhase.NONE
var attack_phase_timer := 0.0
var buffered_attack_timer := 0.0
var attack_direction := Vector2.UP
var attack_origin := Vector2.ZERO
var pending_attack_radius := 0.0
var pending_attack_packet: DamagePacket
var pending_combo_step := 0
var nova_cooldown := 0.0
var hurt_timer := 0.0
var hurt_lock_timer := 0.0
var invulnerable_timer := 0.0
var combo_step := 0
var combo_reset_timer := 0.0
var knockback_velocity := Vector2.ZERO
var locomotion_velocity := Vector2.ZERO
var visual_root: Node2D
var art_sprite: Sprite2D
var model_visual
var art_time := 0.0
var death_pose_timer := 0.0
var movement_filter: Callable
var pointer_path := PackedVector2Array()
var pointer_path_index := 0
var pointer_command_active := false
var pointer_target: CovenantEnemy
var pointer_attack_point := Vector2.ZERO

# The foreground wall shader reads this sprite's alpha as the occlusion mask.
# The property is updated every frame because the animation frame and pose can
# change while the player is moving or attacking.
var occlusion_sprite: Sprite2D
var pointer_attack_point_active := false

var level := 1
var experience := 0
var skill_points := 0
var base_max_health := 150.0
var base_max_mana := 85.0
var base_damage := 17.0
var base_crit_chance := 0.08
var armor := 12.0
var health := 150.0
var mana := 85.0
var gold := 0
var potions := 3
var kills := 0
var total_damage := 0
var nova_cooldown_bonus := 0.0
var upgrades: Array[String] = []
var equipped: Dictionary = {&"weapon": null, &"armor": null, &"charm": null}
var loot_history: Array[LootItem] = []

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 0
	var shape_node := CollisionShape2D.new()
	shape_node.name = "BodyShape"
	var circle := CircleShape2D.new()
	circle.radius = PLAYER_BODY_RADIUS
	shape_node.shape = circle
	add_child(shape_node)
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	visual_root.z_index = 1
	add_child(visual_root)
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	art_sprite.texture = CRIMSON_SHEETS[&"idle"][3]
	art_sprite.region_enabled = true
	art_sprite.region_rect = Rect2(Vector2.ZERO, CRIMSON_FRAME_SIZE)
	art_sprite.scale = Vector2.ONE * CRIMSON_ART_SCALE
	art_sprite.position = Vector2(0, -CRIMSON_FOOT_OFFSET)
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_root.add_child(art_sprite)
	model_visual = Warrior3DVisualScript.new()
	model_visual.name = "Warrior3DVisual"
	visual_root.add_child(model_visual)
	if model_visual.is_available():
		art_sprite.visible = false
		occlusion_sprite = model_visual.get_display_sprite()
	else:
		model_visual.queue_free()
		model_visual = null
		occlusion_sprite = art_sprite
	rng.seed = 0xA55E_2026
	health = max_health()
	mana = max_mana()
	z_index = 0
	_emit_all_stats()

func _physics_process(delta: float) -> void:
	art_time += delta
	if not gameplay_enabled and health > 0.0:
		locomotion_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		_update_art_sprite()
		queue_redraw()
		return
	if health <= 0.0:
		death_pose_timer += delta
	_tick_timers(delta)
	if not gameplay_enabled:
		locomotion_velocity = locomotion_velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		velocity = locomotion_velocity + knockback_velocity
		move_and_slide()
		_update_art_sprite()
		queue_redraw()
		return
	_update_aim_from_input()
	_handle_actions()
	_handle_movement(delta)
	mana = minf(max_mana(), mana + (6.5 + level * 0.35) * delta)
	mana_changed.emit(mana, max_mana())
	_update_art_sprite()
	queue_redraw()

func _update_art_sprite() -> void:
	if not is_instance_valid(art_sprite) or not is_instance_valid(visual_root):
		return
	var moving := locomotion_velocity.length_squared() > 625.0 or dash_timer > 0.0
	# The Old Prison TileSet is authored on a 32px grid. Keep the fallback
	# Keep the fallback player at the requested 128x128 footprint.
	art_sprite.position = Vector2(0, -CRIMSON_FOOT_OFFSET)
	art_sprite.scale = Vector2.ONE * CRIMSON_ART_SCALE
	var pose_position := Vector2.ZERO
	var pose_rotation := 0.0
	var pose_scale := Vector2.ONE
	var sprite_action: StringName = &"idle"
	var sprite_direction := facing
	var sprite_frame := 0
	if health <= 0.0:
		sprite_action = &"death"
		sprite_frame = mini(int(death_pose_timer * 14.0), CRIMSON_FRAME_COUNTS[sprite_action] - 1)
		var death_t := clampf(death_pose_timer / 0.42, 0.0, 1.0)
		pose_position = Vector2(0.0, death_t * 12.0)
		pose_rotation = lerpf(0.0, 0.34 if facing.x >= 0.0 else -0.34, death_t)
		pose_scale = Vector2(1.0 + death_t * 0.08, 1.0 - death_t * 0.2)
	elif hurt_lock_timer > 0.0:
		sprite_action = &"hurt"
		var hurt_progress := 1.0 - hurt_lock_timer / HURT_LOCK_DURATION
		sprite_frame = mini(int(hurt_progress * CRIMSON_FRAME_COUNTS[sprite_action]), CRIMSON_FRAME_COUNTS[sprite_action] - 1)
		var hurt_t := 1.0 - hurt_lock_timer / HURT_LOCK_DURATION
		var recoil_direction := -knockback_velocity.normalized()
		if recoil_direction == Vector2.ZERO:
			recoil_direction = -facing
		pose_position = recoil_direction * (5.0 * (1.0 - hurt_t))
		pose_position += facing.orthogonal() * sin(hurt_t * PI * 6.0) * 2.2 * (1.0 - hurt_t)
		pose_rotation = sin(hurt_t * PI * 5.0) * 0.055 * (1.0 - hurt_t)
		pose_scale = Vector2(1.06 - hurt_t * 0.06, 0.94 + hurt_t * 0.06)
	elif attack_phase != AttackPhase.NONE:
		sprite_action = &"axe_attack" if pending_combo_step == 2 else &"sword_attack"
		sprite_direction = attack_direction
		var attack_elapsed := ATTACK_WINDUP + ATTACK_ACTIVE + ATTACK_RECOVERY - attack_phase_timer
		var attack_progress := clampf(attack_elapsed / (ATTACK_WINDUP + ATTACK_ACTIVE + ATTACK_RECOVERY), 0.0, 0.999)
		sprite_frame = int(attack_progress * CRIMSON_FRAME_COUNTS[sprite_action])
		var side := -1.0 if pending_combo_step == 2 else 1.0
		match attack_phase:
			AttackPhase.WINDUP:
				var p := 1.0 - attack_phase_timer / ATTACK_WINDUP
				pose_position = -attack_direction * lerpf(0.0, 5.5, p)
				pose_rotation = side * lerpf(0.0, -0.055, p)
				pose_scale = Vector2(1.0 + p * 0.04, 1.0 - p * 0.05)
			AttackPhase.ACTIVE:
				var p := 1.0 - attack_phase_timer / ATTACK_ACTIVE
				pose_position = attack_direction * (9.0 + sin(p * PI) * (5.0 if pending_combo_step < 3 else 9.0))
				pose_rotation = side * lerpf(0.08, -0.075, p)
				pose_scale = Vector2(0.96, 1.06)
			AttackPhase.RECOVERY:
				var p := 1.0 - attack_phase_timer / ATTACK_RECOVERY
				pose_position = attack_direction * lerpf(8.0, 0.0, p)
				pose_rotation = side * lerpf(-0.06, 0.0, p)
				pose_scale = Vector2(lerpf(0.97, 1.0, p), lerpf(1.04, 1.0, p))
	elif dash_timer > 0.0:
		sprite_action = &"run"
		sprite_direction = dash_direction
		sprite_frame = int(art_time * 19.0) % CRIMSON_FRAME_COUNTS[sprite_action]
		pose_position = dash_direction * 7.0
		pose_scale = Vector2(0.9, 1.12)
	elif moving:
		# Keep travelling grounded and readable. Run frames are reserved for the
		# supernatural dash; this complete eight-frame walk cycle sells each step.
		sprite_action = &"walk"
		sprite_frame = int(art_time * 10.0) % CRIMSON_FRAME_COUNTS[sprite_action]
		pose_rotation = sin(art_time * 7.5) * 0.006
		pose_scale = Vector2(1.0 + sin(art_time * 7.5) * 0.008, 1.0 - sin(art_time * 7.5) * 0.005)
	else:
		sprite_frame = int(art_time * 6.0) % CRIMSON_FRAME_COUNTS[sprite_action]
		var breath := sin(art_time * 2.7)
		pose_scale = Vector2(1.0 + breath * 0.006, 1.0 - breath * 0.009)
	if is_instance_valid(model_visual):
		model_visual.set_animation_state(_model_animation_for(sprite_action), _model_facing_direction())
	else:
		_set_crimson_frame(sprite_action, sprite_direction, sprite_frame)
	visual_root.position = pose_position
	visual_root.rotation = pose_rotation
	visual_root.scale = pose_scale
	if hurt_timer > 0.0:
		art_sprite.modulate = Color.WHITE if int(hurt_timer * 70.0) % 2 == 0 else Color("ff6f72")
	elif dash_timer > 0.0:
		art_sprite.modulate = Color(0.78, 0.68, 1.0, 0.82)
	else:
		art_sprite.modulate = Color.WHITE
	if health <= 0.0:
		art_sprite.modulate.a = 1.0 - clampf(death_pose_timer / 0.42, 0.0, 0.72)
	if is_instance_valid(model_visual):
		model_visual.modulate = art_sprite.modulate

func _model_animation_for(sprite_action: StringName) -> StringName:
	match sprite_action:
		&"walk":
			return &"Walk"
		&"run":
			return &"Run"
		&"sword_attack", &"axe_attack":
			return &"Sword_Attack"
		_:
			return &"Idle"

func _model_facing_direction() -> Vector2:
	return model_facing

func set_model_facing_at(target_position: Vector2) -> void:
	var click_direction := target_position - global_position
	if click_direction.length_squared() > 16.0:
		model_facing = click_direction.normalized()

func _set_crimson_frame(action: StringName, direction: Vector2, frame: int) -> void:
	var direction_index := 0 # down, left, right, up
	if absf(direction.x) > absf(direction.y):
		direction_index = 1 if direction.x < 0.0 else 2
	elif direction.y < 0.0:
		direction_index = 3
	var frame_count: int = CRIMSON_FRAME_COUNTS[action]
	art_sprite.texture = CRIMSON_SHEETS[action][direction_index]
	art_sprite.region_rect = Rect2(Vector2(frame % frame_count * CRIMSON_FRAME_SIZE.x, 0.0), CRIMSON_FRAME_SIZE)

func _tick_timers(delta: float) -> void:
	var was_dashing := dash_timer > 0.0
	dash_timer = maxf(0.0, dash_timer - delta)
	if was_dashing and dash_timer <= 0.0:
		locomotion_velocity = dash_direction * MOVE_SPEED * 0.7
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	buffered_attack_timer = maxf(0.0, buffered_attack_timer - delta)
	nova_cooldown = maxf(0.0, nova_cooldown - delta)
	hurt_timer = maxf(0.0, hurt_timer - delta)
	hurt_lock_timer = maxf(0.0, hurt_lock_timer - delta)
	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	combo_reset_timer = maxf(0.0, combo_reset_timer - delta)
	if combo_reset_timer <= 0.0:
		combo_step = 0
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 720.0 * delta)
	_tick_attack(delta)
	if buffered_attack_timer > 0.0 and _can_start_attack():
		buffered_attack_timer = 0.0
		_start_attack()

func _tick_attack(delta: float) -> void:
	if attack_phase == AttackPhase.NONE:
		return
	attack_phase_timer -= delta
	while attack_phase != AttackPhase.NONE and attack_phase_timer <= 0.0:
		var overflow := -attack_phase_timer
		match attack_phase:
			AttackPhase.WINDUP:
				attack_phase = AttackPhase.ACTIVE
				attack_phase_timer = maxf(0.001, ATTACK_ACTIVE - overflow)
				attack_origin = global_position
				if pending_attack_packet:
					pending_attack_packet.origin = attack_origin
				attack_requested.emit(attack_origin, attack_direction, pending_attack_radius, pending_attack_packet, pending_combo_step)
			AttackPhase.ACTIVE:
				attack_phase = AttackPhase.RECOVERY
				attack_phase_timer = maxf(0.001, ATTACK_RECOVERY - overflow)
			AttackPhase.RECOVERY:
				attack_phase = AttackPhase.NONE
				attack_phase_timer = 0.0
				pending_attack_packet = null

func _handle_actions() -> void:
	if Input.is_action_just_pressed(&"dash"):
		try_dash()
	if Input.is_action_just_pressed(&"attack"):
		try_attack()
	if Input.is_action_just_pressed(&"skill_nova"):
		try_cast_nova()
	if Input.is_action_just_pressed(&"use_potion"):
		use_potion()

func _handle_movement(delta: float) -> void:
	var previous_position := global_position
	if dash_timer > 0.0:
		locomotion_velocity = dash_direction * DASH_SPEED
		velocity = locomotion_velocity + knockback_velocity
		move_and_slide()
		_constrain_to_world(previous_position)
		return
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input_vector != Vector2.ZERO:
		cancel_pointer_command()
	else:
		input_vector = _pointer_movement_direction()
	var movement_scale := 1.0
	if hurt_lock_timer > 0.0:
		movement_scale = 0.15
	elif attack_phase != AttackPhase.NONE:
		movement_scale = 0.5 if attack_phase != AttackPhase.RECOVERY else 0.68
	if input_vector != Vector2.ZERO:
		last_move_direction = input_vector.normalized()
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			facing = last_move_direction
		locomotion_velocity = locomotion_velocity.move_toward(input_vector * MOVE_SPEED * movement_scale, ACCELERATION * delta)
	else:
		locomotion_velocity = locomotion_velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	velocity = locomotion_velocity + knockback_velocity
	move_and_slide()
	_constrain_to_world(previous_position)

func command_move_path(path: PackedVector2Array) -> bool:
	if path.is_empty() or health <= 0.0:
		return false
	pointer_target = null
	pointer_attack_point_active = false
	pointer_path = path.duplicate()
	pointer_path_index = 0
	pointer_command_active = true
	return true

func command_attack_target(target_enemy: CovenantEnemy, path: PackedVector2Array) -> bool:
	if not is_instance_valid(target_enemy) or target_enemy.health <= 0.0 or health <= 0.0:
		return false
	pointer_target = target_enemy
	pointer_attack_point_active = false
	pointer_path = path.duplicate()
	pointer_path_index = 0
	pointer_command_active = true
	return true

func command_attack_point(target_position: Vector2, path: PackedVector2Array) -> bool:
	if health <= 0.0:
		return false
	pointer_target = null
	pointer_attack_point = target_position
	pointer_attack_point_active = true
	pointer_path = path.duplicate()
	pointer_path_index = 0
	pointer_command_active = true
	return true

func cancel_pointer_command() -> void:
	pointer_command_active = false
	pointer_target = null
	pointer_attack_point_active = false
	pointer_path = PackedVector2Array()
	pointer_path_index = 0

func is_attacking_pointer_point(target_position: Vector2) -> bool:
	return pointer_attack_point_active and pointer_attack_point.distance_to(target_position) <= 4.0

func _pointer_movement_direction() -> Vector2:
	if not pointer_command_active:
		return Vector2.ZERO
	var combat_position := Vector2.ZERO
	var has_combat_destination := false
	if is_instance_valid(pointer_target) and not pointer_target.is_queued_for_deletion() and pointer_target.health > 0.0:
		combat_position = pointer_target.global_position
		has_combat_destination = true
	elif pointer_target != null:
		cancel_pointer_command()
		return Vector2.ZERO
	elif pointer_attack_point_active:
		combat_position = pointer_attack_point
		has_combat_destination = true
	if has_combat_destination:
		var combat_delta := combat_position - global_position
		if combat_delta.length_squared() > 1.0:
			facing = combat_delta.normalized()
		if combat_delta.length() <= POINTER_ATTACK_DISTANCE:
			pointer_path = PackedVector2Array()
			pointer_path_index = 0
			if _can_start_attack():
				try_attack()
			return Vector2.ZERO
	while pointer_path_index < pointer_path.size() and global_position.distance_to(pointer_path[pointer_path_index]) <= POINTER_WAYPOINT_DISTANCE:
		pointer_path_index += 1
	if pointer_path_index < pointer_path.size():
		var waypoint_delta := pointer_path[pointer_path_index] - global_position
		if waypoint_delta.length_squared() > 1.0:
			return waypoint_delta.normalized()
	if has_combat_destination:
		var chase_delta := combat_position - global_position
		return chase_delta.normalized() if chase_delta.length() > POINTER_ATTACK_DISTANCE else Vector2.ZERO
	if pointer_path.is_empty():
		cancel_pointer_command()
		return Vector2.ZERO
	var destination := pointer_path[pointer_path.size() - 1]
	var destination_delta := destination - global_position
	if destination_delta.length() <= POINTER_STOP_DISTANCE:
		cancel_pointer_command()
		return Vector2.ZERO
	return destination_delta.normalized()

func _update_aim_from_input() -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var mouse_delta := get_global_mouse_position() - global_position
	if mouse_delta.length_squared() > 144.0:
		facing = mouse_delta.normalized()

func _constrain_to_world(previous_position: Vector2) -> void:
	global_position.x = clampf(global_position.x, 40.0, 2160.0)
	global_position.y = clampf(global_position.y, 35.0, 1365.0)
	if movement_filter.is_valid() and not bool(movement_filter.call(previous_position, global_position, PLAYER_BODY_RADIUS)):
		global_position = previous_position
		velocity = Vector2.ZERO
		locomotion_velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO

func try_dash() -> bool:
	if dash_cooldown > 0.0 or dash_timer > 0.0 or hurt_lock_timer > 0.0 or health <= 0.0:
		return false
	if attack_phase != AttackPhase.NONE:
		_cancel_attack()
	dash_direction = last_move_direction if last_move_direction != Vector2.ZERO else facing
	dash_timer = DASH_DURATION
	dash_cooldown = DASH_COOLDOWN
	invulnerable_timer = DASH_DURATION + 0.08
	dash_requested.emit(global_position, dash_direction)
	action_feedback.emit("SHADOW STEP", Color("9f7aea"))
	return true

func create_shadow_step_packet(origin: Vector2, direction: Vector2) -> DamagePacket:
	var roll := DamageFormula.roll_player_damage(base_damage, level, gear_damage(), crit_chance() * 0.5, 0.82, rng)
	return DamagePacket.new(roll.amount, self, origin, direction.normalized() * 255.0, DamagePacket.DamageKind.ASH, roll.critical)

func try_attack() -> bool:
	if not _can_start_attack():
		if health > 0.0:
			buffered_attack_timer = ATTACK_INPUT_BUFFER
		return false
	_start_attack()
	return true

func _can_start_attack() -> bool:
	return gameplay_enabled and health > 0.0 and attack_phase == AttackPhase.NONE and attack_cooldown <= 0.0 and dash_timer <= 0.0 and hurt_lock_timer <= 0.0

func _start_attack() -> void:
	combo_step = combo_step % 3 + 1
	combo_reset_timer = 0.7
	attack_cooldown = ATTACK_COOLDOWN * (0.82 if combo_step == 3 else 1.0)
	attack_phase = AttackPhase.WINDUP
	attack_phase_timer = ATTACK_WINDUP
	attack_direction = facing.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = last_move_direction if last_move_direction != Vector2.ZERO else Vector2.UP
	attack_origin = global_position
	pending_combo_step = combo_step
	var multipliers: Array[float] = [0.0, 1.0, 1.18, 1.55]
	var roll := DamageFormula.roll_player_damage(base_damage, level, gear_damage(), crit_chance(), multipliers[combo_step], rng)
	pending_attack_radius = 78.0 if combo_step < 3 else 96.0
	var push := attack_direction * (185.0 if combo_step < 3 else 310.0)
	pending_attack_packet = DamagePacket.new(roll.amount, self, attack_origin, push, DamagePacket.DamageKind.PHYSICAL, roll.critical)

func _cancel_attack(clear_buffer: bool = true) -> void:
	attack_phase = AttackPhase.NONE
	attack_phase_timer = 0.0
	pending_attack_packet = null
	if clear_buffer:
		buffered_attack_timer = 0.0

func try_cast_nova() -> bool:
	if nova_cooldown > 0.0 or mana < NOVA_MANA_COST or dash_timer > 0.0 or attack_phase != AttackPhase.NONE or hurt_lock_timer > 0.0 or health <= 0.0:
		if mana < NOVA_MANA_COST:
			action_feedback.emit("NOT ENOUGH ESSENCE", Color("729bd1"))
		return false
	mana -= NOVA_MANA_COST
	nova_cooldown = maxf(1.6, NOVA_BASE_COOLDOWN - nova_cooldown_bonus)
	var roll := DamageFormula.roll_player_damage(base_damage + 7.0, level, gear_damage() * 0.7, crit_chance(), 1.65, rng)
	var packet := DamagePacket.new(roll.amount, self, global_position, Vector2.ZERO, DamagePacket.DamageKind.ASH, roll.critical)
	nova_requested.emit(global_position, 185.0, packet)
	mana_changed.emit(mana, max_mana())
	return true

func take_damage(packet: DamagePacket) -> bool:
	if health <= 0.0 or invulnerable_timer > 0.0:
		return false
	var amount := DamageFormula.mitigate(packet.amount, armor_total())
	health = maxf(0.0, health - amount)
	knockback_velocity = (knockback_velocity + packet.knockback).limit_length(460.0)
	hurt_timer = 0.22
	hurt_lock_timer = HURT_LOCK_DURATION
	invulnerable_timer = 0.34
	_cancel_attack()
	health_changed.emit(health, max_health())
	var impact_direction := packet.knockback.normalized()
	if impact_direction == Vector2.ZERO:
		impact_direction = (global_position - packet.origin).normalized()
	if impact_direction == Vector2.ZERO:
		impact_direction = -facing
	damaged.emit(global_position, int(amount), impact_direction)
	if health <= 0.0:
		gameplay_enabled = false
		locomotion_velocity = Vector2.ZERO
		cancel_pointer_command()
		death_pose_timer = 0.0
		died.emit()
	return true

func use_potion() -> bool:
	if potions <= 0 or health >= max_health() - 1.0:
		return false
	potions -= 1
	var healed := max_health() * 0.45
	health = minf(max_health(), health + healed)
	health_changed.emit(health, max_health())
	potions_changed.emit(potions)
	potion_used.emit()
	action_feedback.emit("RESTORED %d LIFE" % int(healed), Color("77d991"))
	return true

func add_experience(amount: int) -> bool:
	experience += maxi(0, amount)
	var leveled := false
	while experience >= experience_required():
		experience -= experience_required()
		level += 1
		skill_points += 1
		base_max_health += 12.0
		base_damage += 1.5
		health = max_health()
		mana = max_mana()
		leveled = true
		level_up_requested.emit(level)
		skill_points_changed.emit(skill_points)
	experience_changed.emit(experience, experience_required(), level)
	return leveled

func experience_required() -> int:
	return mini(600, int(58.0 * pow(1.36, clampi(level - 1, 0, 20))))

func equip_loot(item: LootItem) -> bool:
	loot_history.push_front(item)
	if loot_history.size() > 12:
		loot_history.resize(12)
	var previous: LootItem = equipped.get(item.slot) as LootItem
	var equipped_new := previous == null or item.score() > previous.score()
	if equipped_new:
		equipped[item.slot] = item
		health = minf(health + float(item.bonus_health), max_health())
		mana = minf(mana + float(item.bonus_mana), max_mana())
		equipment_changed.emit()
		_emit_all_stats()
	return equipped_new

func get_skill_rank(skill_id: StringName) -> int:
	var definition: Dictionary = SKILL_DEFINITIONS.get(skill_id, {})
	if definition.is_empty():
		return 0
	return mini(upgrades.count(String(skill_id)), int(definition.get("max_rank", 1)))

func can_purchase_skill(skill_id: StringName) -> bool:
	var definition: Dictionary = SKILL_DEFINITIONS.get(skill_id, {})
	if definition.is_empty() or skill_points <= 0:
		return false
	return get_skill_rank(skill_id) < int(definition.get("max_rank", 1))

func purchase_skill(skill_id: StringName) -> bool:
	if not can_purchase_skill(skill_id):
		return false
	skill_points -= 1
	upgrades.append(String(skill_id))
	match skill_id:
		&"iron_oath":
			base_max_health += 20.0
			armor += 3.0
			health = max_health()
		&"executioner":
			base_damage += 3.0
			base_crit_chance += 0.025
		&"blood_rush":
			nova_cooldown_bonus += 0.18
			base_max_mana += 10.0
			mana = max_mana()
	skill_points_changed.emit(skill_points)
	_emit_all_stats()
	return true

func get_skill_tree_snapshot() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for skill_id in SKILL_ORDER:
		var definition: Dictionary = SKILL_DEFINITIONS[skill_id]
		skills.append({
			"id": skill_id,
			"title": String(definition.get("title", skill_id)),
			"summary": String(definition.get("summary", "")),
			"rank": get_skill_rank(skill_id),
			"max_rank": int(definition.get("max_rank", 1)),
			"available": can_purchase_skill(skill_id),
		})
	return skills

func max_health() -> float:
	var bonus := 0
	for value in equipped.values():
		var item := value as LootItem
		if item: bonus += item.bonus_health
	return maxf(1.0, base_max_health + bonus)

func max_mana() -> float:
	var bonus := 0
	for value in equipped.values():
		var item := value as LootItem
		if item: bonus += item.bonus_mana
	return maxf(1.0, base_max_mana + bonus)

func gear_damage() -> float:
	var bonus := 0.0
	for value in equipped.values():
		var item := value as LootItem
		if item: bonus += item.bonus_damage
	return bonus

func crit_chance() -> float:
	var total := base_crit_chance
	for value in equipped.values():
		var item := value as LootItem
		if item: total += item.bonus_crit
	return clampf(total, 0.0, 0.65)

func armor_total() -> float:
	var gear_armor := 0.0
	var armor_item := equipped.get(&"armor") as LootItem
	if armor_item:
		gear_armor += armor_item.power * 1.7
	return armor + gear_armor

func cooldown_ratio(ability: StringName) -> float:
	match ability:
		&"dash": return clampf(dash_cooldown / DASH_COOLDOWN, 0.0, 1.0)
		&"nova": return clampf(nova_cooldown / maxf(1.6, NOVA_BASE_COOLDOWN - nova_cooldown_bonus), 0.0, 1.0)
		_: return clampf(attack_cooldown / ATTACK_COOLDOWN, 0.0, 1.0)

func to_save_dict() -> Dictionary:
	var equipment_data := {}
	for key in equipped:
		var item := equipped[key] as LootItem
		if item:
			equipment_data[String(key)] = item.to_dict()
		else:
			equipment_data[String(key)] = null
	return {
		"level": level, "experience": experience, "base_health": base_max_health,
		"skill_points": skill_points,
		"base_mana": base_max_mana, "base_damage": base_damage, "crit": base_crit_chance,
		"armor": armor, "gold": gold, "potions": potions, "kills": kills,
		"nova_bonus": nova_cooldown_bonus, "upgrades": upgrades.duplicate(),
		"equipment": equipment_data
	}

func load_save_dict(data: Dictionary) -> void:
	level = clampi(int(data.get("level", 1)), 1, 30)
	experience = maxi(0, int(data.get("experience", 0)))
	skill_points = clampi(int(data.get("skill_points", 0)), 0, 99)
	base_max_health = clampf(float(data.get("base_health", 150.0)), 80.0, 2000.0)
	base_max_mana = clampf(float(data.get("base_mana", 85.0)), 20.0, 1000.0)
	base_damage = clampf(float(data.get("base_damage", 17.0)), 5.0, 500.0)
	base_crit_chance = clampf(float(data.get("crit", 0.08)), 0.0, 0.65)
	armor = clampf(float(data.get("armor", 12.0)), 0.0, 500.0)
	gold = maxi(0, int(data.get("gold", 0)))
	potions = clampi(int(data.get("potions", 3)), 0, 9)
	kills = maxi(0, int(data.get("kills", 0)))
	nova_cooldown_bonus = clampf(float(data.get("nova_bonus", 0.0)), 0.0, 1.8)
	upgrades.assign(data.get("upgrades", []))
	var equipment_data: Dictionary = data.get("equipment", {})
	for key in [&"weapon", &"armor", &"charm"]:
		var stored: Variant = equipment_data.get(String(key))
		equipped[key] = LootItem.from_dict(stored) if stored is Dictionary else null
	health = max_health()
	mana = max_mana()
	_reset_combat_pose()
	_emit_all_stats()

func reset_progress() -> void:
	level = 1
	experience = 0
	skill_points = 0
	base_max_health = 150.0
	base_max_mana = 85.0
	base_damage = 17.0
	base_crit_chance = 0.08
	armor = 12.0
	gold = 0
	potions = 3
	kills = 0
	nova_cooldown_bonus = 0.0
	upgrades.clear()
	equipped = {&"weapon": null, &"armor": null, &"charm": null}
	loot_history.clear()
	health = max_health()
	mana = max_mana()
	_reset_combat_pose()
	_emit_all_stats()

func _reset_combat_pose() -> void:
	dash_timer = 0.0
	attack_cooldown = 0.0
	buffered_attack_timer = 0.0
	hurt_timer = 0.0
	hurt_lock_timer = 0.0
	invulnerable_timer = 0.0
	death_pose_timer = 0.0
	locomotion_velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	cancel_pointer_command()
	_cancel_attack()
	if is_instance_valid(visual_root):
		visual_root.position = Vector2.ZERO
		visual_root.rotation = 0.0
		visual_root.scale = Vector2.ONE
	if is_instance_valid(art_sprite):
		art_sprite.modulate = Color.WHITE

func _emit_all_stats() -> void:
	health_changed.emit(health, max_health())
	mana_changed.emit(mana, max_mana())
	experience_changed.emit(experience, experience_required(), level)
	skill_points_changed.emit(skill_points)
	potions_changed.emit(potions)

func _draw() -> void:
	var speed_ratio := clampf(velocity.length() / DASH_SPEED, 0.0, 1.0)
	draw_set_transform(Vector2(0, 3), 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 22.0 + speed_ratio * 4.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2.ZERO, PLAYER_BODY_RADIUS + speed_ratio * 2.0, Color(0.0, 0.0, 0.0, 0.42))
	draw_set_transform(Vector2.ZERO)
	if dash_timer > 0.0:
		for i in 4:
			draw_circle(-dash_direction * (18.0 + i * 15.0), 18.0 - i * 3.2, Color(0.45, 0.25, 0.75, 0.24 - i * 0.04))
	if nova_cooldown <= 0.0 and mana >= NOVA_MANA_COST:
		draw_arc(Vector2.ZERO, 27.0 + sin(Time.get_ticks_msec() * 0.004) * 2.0, 0.0, TAU, 32, Color(0.55, 0.3, 0.8, 0.33), 2.0)
