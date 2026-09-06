class_name ActionCombatEnemy3D
extends CharacterBody3D

signal damaged(world_position: Vector3, amount: float, finisher: bool)
signal died(enemy: ActionCombatEnemy3D)
signal strike_landed(world_position: Vector3)

enum State { CHASE, TELEGRAPH, STRIKE, RECOVER, STAGGER, DEAD }

@export var max_health := 75.0
@export var move_speed := 3.1
@export var attack_damage := 14.0
@export var attack_range := 2.0
@export var telegraph_duration := 0.62
@export var accent_color := Color("d94cff")
@export var brute := false
@export var hound := false
@export var skeleton := false
@export var skeleton_archer := false

const ArrowScene := preload("res://entities/projectiles/skeleton_arrow_3d.tscn")


@export_group("Crowd Movement")
@export var separation_strength := 5.8
@export var separation_radius := 1.2

var health := 75.0
var state := State.CHASE
var _state_elapsed := 0.0
var _state_duration := 0.0
var _strike_done := false
var _player: ActionCombatPlayer3D
var _knockback := Vector3.ZERO
var _invincible_timer := 0.0
var _attack_cooldown := 0.35
var _death_elapsed := 0.0
var _base_visual_scale := Vector3.ONE
var _base_visual_position := Vector3.ZERO
var _body_base_scale := Vector3.ONE
var _core_base_scale := Vector3.ONE
var _core_base_position := Vector3.ZERO
var _eye_left_base_position := Vector3.ZERO
var _eye_right_base_position := Vector3.ZERO
var _slime_motion_clock := 0.0
var _impact_hold_duration := 0.0
var _attack_variant := 1
var _active_animation := StringName()
var _hit_flash_tween: Tween

@onready var body_shape: CollisionShape3D = $BodyShape
@onready var visual: Node3D = $Visual
@onready var body_mesh: MeshInstance3D = get_node_or_null("Visual/Body") as MeshInstance3D
@onready var core_mesh: MeshInstance3D = get_node_or_null("Visual/Core") as MeshInstance3D
@onready var eye_left: MeshInstance3D = get_node_or_null("Visual/EyeLeft") as MeshInstance3D
@onready var eye_right: MeshInstance3D = get_node_or_null("Visual/EyeRight") as MeshInstance3D
@onready var telegraph: MeshInstance3D = $Telegraph
@onready var shadow: MeshInstance3D = $Shadow
@onready var animation_player: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var hit_flash: OmniLight3D = get_node_or_null("HitFlash") as OmniLight3D


func _ready() -> void:
	add_to_group(&"action_enemies")
	health = max_health
	_base_visual_scale = visual.scale
	_base_visual_position = visual.position
	if body_mesh != null:
		_body_base_scale = body_mesh.scale
	if core_mesh != null:
		_core_base_scale = core_mesh.scale
		_core_base_position = core_mesh.position
	if eye_left != null:
		_eye_left_base_position = eye_left.position
	if eye_right != null:
		_eye_right_base_position = eye_right.position
	_apply_color_materials()
	telegraph.visible = false
	_attack_cooldown = 0.42 + float(get_instance_id() % 5) * 0.09
	if hound:
		move_speed = 3.85
		attack_range = 2.35
		telegraph_duration = 0.46
		attack_damage = 12.0
		for looping_clip in [&"Idle", &"Run"]:
			var resolved := _resolve_animation(looping_clip)
			if not resolved.is_empty():
				animation_player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
		_play_animation(&"Idle", 1.0)
	elif skeleton:
		move_speed = 2.7
		attack_range = 1.85
		telegraph_duration = 0.62
		attack_damage = 9.0
		for looping_clip in [&"Idle", &"Run"]:
			var resolved := _resolve_animation(looping_clip)
			if not resolved.is_empty():
				animation_player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
		_play_animation(&"Idle", 1.0)
	elif skeleton_archer:
		move_speed = 3.0
		attack_range = 8.5
		telegraph_duration = 0.72
		attack_damage = 11.0
		separation_radius = 1.6
		for looping_clip in [&"Idle", &"Run"]:
			var resolved := _resolve_animation(looping_clip)
			if not resolved.is_empty():
				animation_player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
		_play_animation(&"Idle", 1.0)
	if brute:
		visual.scale *= 1.28
		_base_visual_scale = visual.scale
		move_speed *= 0.78
		attack_damage *= 1.4
		attack_range *= 1.18
		telegraph_duration *= 1.16
		var shape := body_shape.shape as CapsuleShape3D
		if shape != null:
			shape = shape.duplicate() as CapsuleShape3D
			shape.radius *= 1.22
			shape.height *= 1.18
			body_shape.shape = shape


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 18.0 * delta)
	if state == State.DEAD:
		_tick_death(delta)
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"action_player") as ActionCombatPlayer3D
	if not is_instance_valid(_player) or _player.state == ActionCombatPlayer3D.State.DEAD:
		_move(Vector3.ZERO, delta)
		return

	match state:
		State.CHASE:
			_tick_chase(delta)
		State.TELEGRAPH:
			_tick_telegraph(delta)
		State.STRIKE:
			_tick_strike(delta)
		State.RECOVER:
			_tick_recover(delta)
		State.STAGGER:
			_tick_stagger(delta)


func _tick_chase(delta: float) -> void:
	var player_offset := _player.global_position - global_position
	player_offset.y = 0.0
	if player_offset.length() <= attack_range and _attack_cooldown <= 0.0 and _can_start_attack():
		_start_telegraph()
		return
	var engagement_target := _engagement_slot_target()
	var slot_offset := engagement_target - global_position
	slot_offset.y = 0.0
	var desired_radius := _engagement_radius()
	var direction := Vector3.ZERO
	if player_offset.length() < desired_radius * 0.68 and player_offset.length_squared() > 0.01:
		direction = -player_offset.normalized()
	elif slot_offset.length() > 0.22:
		direction = slot_offset.normalized()
	if hound or skeleton or skeleton_archer:
		_play_animation(&"Run" if direction != Vector3.ZERO else &"Idle", 1.15 if hound else 0.95)
	_move(direction, delta, _calculate_separation_velocity(), player_offset.normalized())
	if _is_slime():
		_animate_slime_idle(delta, direction.length_squared() > 0.01)


func _start_telegraph() -> void:
	state = State.TELEGRAPH
	_state_elapsed = 0.0
	_state_duration = telegraph_duration
	telegraph.visible = true
	telegraph.scale = Vector3(0.18, 1.0, 0.18)
	velocity.x = 0.0
	velocity.z = 0.0
	_face_player()
	if hound:
		_attack_variant = (_attack_variant + 1) % 2
		_play_animation(
			&"Pounce_Bite" if _attack_variant == 0 else &"Claw_Swipe",
			0.92 if _attack_variant == 0 else 0.75,
			true
		)
	elif skeleton:
		_play_animation(&"Attack_Slash", 1.0, true)
	elif skeleton_archer:
		_play_animation(&"Attack_Shoot", 1.0, true)
	else:
		_slime_motion_clock = 0.0
		_reset_slime_parts()


func _tick_telegraph(delta: float) -> void:
	_state_elapsed += delta
	var progress := clampf(_state_elapsed / _state_duration, 0.0, 1.0)
	var pulse := 1.0 + sin(progress * TAU * 4.0) * 0.08
	telegraph.scale = Vector3.ONE * lerpf(0.18, 1.35 if brute else 1.05, progress) * pulse
	if _is_slime():
		_animate_slime_telegraph(progress)
	_move(Vector3.ZERO, delta)
	if _state_elapsed >= _state_duration:
		state = State.STRIKE
		_state_elapsed = 0.0
		_state_duration = 0.27 if hound else (0.24 if skeleton else (0.35 if skeleton_archer else (0.34 if brute else 0.3)))
		_strike_done = false


func _tick_strike(delta: float) -> void:
	_state_elapsed += delta
	var direction := -visual.global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var strike_progress := clampf(_state_elapsed / _state_duration, 0.0, 1.0)
	if _is_slime():
		_animate_slime_strike(strike_progress)
	var strike_speed := 0.0 if skeleton_archer else ((13.5 if _attack_variant == 0 else 7.5) if hound else (6.8 if skeleton else (9.5 if brute else 8.5)))
	velocity.x = direction.x * strike_speed
	velocity.z = direction.z * strike_speed
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()
	if not _strike_done and _state_elapsed >= 0.075:
		var hit_moment := 0.12 if hound else (0.13 if skeleton else (0.10 if skeleton_archer else (0.17 if brute else 0.15)))
		if _state_elapsed < hit_moment:
			return
		_strike_done = true
		if skeleton_archer:
			_shoot_arrow()
		else:
			_try_strike_player()
	if _state_elapsed >= _state_duration:
		state = State.RECOVER
		_state_elapsed = 0.0
		_state_duration = 0.28 if hound else (0.5 if skeleton else (0.65 if skeleton_archer else (0.62 if brute else 0.52)))
		telegraph.visible = false


func _shoot_arrow() -> void:
	if not is_instance_valid(_player):
		return
	var shoot_from := global_position + Vector3.UP * 1.1 + (-visual.global_basis.z) * 0.65
	var target_pos := _player.global_position + Vector3.UP * 0.85
	var shoot_dir := (target_pos - shoot_from).normalized()
	if ArrowScene == null:
		return
	var arrow := ArrowScene.instantiate() as SkeletonArrow3D
	if arrow == null:
		return
	var parent_node := get_parent()
	if parent_node != null:
		parent_node.add_child(arrow)
	else:
		get_tree().root.add_child(arrow)
	arrow.setup(shoot_from, shoot_dir, self, attack_damage)


func _tick_recover(delta: float) -> void:
	_state_elapsed += delta
	_move(Vector3.ZERO, delta)
	if _is_slime():
		_animate_slime_recover(clampf(_state_elapsed / _state_duration, 0.0, 1.0))
	else:
		visual.scale = visual.scale.lerp(_base_visual_scale, minf(1.0, delta * 12.0))
	if _state_elapsed >= _state_duration:
		_reset_visual_pose()
		state = State.CHASE
		_attack_cooldown = 0.72 if brute else 0.5
		if hound or skeleton or skeleton_archer:
			_play_animation(&"Idle", 1.0)


func _tick_stagger(delta: float) -> void:
	_state_elapsed += delta
	var holding_impact := _state_elapsed <= _impact_hold_duration
	var stagger_progress := clampf(_state_elapsed / maxf(_state_duration, 0.001), 0.0, 1.0)
	if holding_impact:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = move_toward(velocity.x, _knockback.x, 22.0 * delta)
		velocity.z = move_toward(velocity.z, _knockback.z, 22.0 * delta)
	move_and_slide()
	if _is_slime():
		_animate_slime_stagger(stagger_progress, holding_impact)
	else:
		var recoil_weight := 1.0 - stagger_progress
		visual.rotation.z = (-0.16 if holding_impact else sin(stagger_progress * PI * 2.5) * 0.11) * recoil_weight
		visual.scale = _base_visual_scale * Vector3(1.0 + recoil_weight * 0.06, 1.0 - recoil_weight * 0.035, 1.0 + recoil_weight * 0.04)
	if _state_elapsed >= _state_duration:
		_reset_visual_pose()
		state = State.CHASE
		_attack_cooldown = 0.32
		if hound or skeleton or skeleton_archer:
			_play_animation(&"Idle", 1.0, true)


func _move(direction: Vector3, delta: float, steering: Vector3 = Vector3.ZERO, facing_direction: Vector3 = Vector3.ZERO) -> void:
	var look_direction := facing_direction if facing_direction.length_squared() > 0.01 else direction
	if look_direction.length_squared() > 0.01:
		visual.look_at(global_position + look_direction, Vector3.UP)
	var target := direction * move_speed + steering + _knockback
	velocity.x = move_toward(velocity.x, target.x, 22.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 22.0 * delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.2
	move_and_slide()


func _engagement_radius() -> float:
	if skeleton_archer:
		return 6.5
	var radius := clampf(attack_range * 0.84, 1.55, 2.05)
	if hound:
		radius += 0.22
	elif brute:
		radius += 0.28
	return radius


func _engagement_slot_target() -> Vector3:
	if not is_instance_valid(_player):
		return global_position
	var formation: Array[ActionCombatEnemy3D] = []
	for candidate in get_tree().get_nodes_in_group(&"action_enemies"):
		var enemy := candidate as ActionCombatEnemy3D
		if enemy != null and enemy.is_alive():
			formation.append(enemy)
	formation.sort_custom(func(first: ActionCombatEnemy3D, second: ActionCombatEnemy3D) -> bool: return first.get_instance_id() < second.get_instance_id())
	var slot_index := formation.find(self)
	if slot_index < 0:
		return _player.global_position
	var count := maxi(formation.size(), 1)
	var slow_rotation := float(Time.get_ticks_msec()) * 0.00011
	var angle := TAU * float(slot_index) / float(count) + slow_rotation
	var radius := _engagement_radius()
	var target := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	# Keep formation slots inside the combat floor so enemies do not stack against walls.
	target.x = clampf(target.x, -9.8, 9.8)
	target.z = clampf(target.z, -7.25, 7.25)
	target.y = global_position.y
	return target


func _can_start_attack() -> bool:
	var living_count := 0
	var active_attackers := 0
	for candidate in get_tree().get_nodes_in_group(&"action_enemies"):
		var enemy := candidate as ActionCombatEnemy3D
		if enemy == null or not enemy.is_alive():
			continue
		living_count += 1
		if enemy != self and enemy.state in [State.TELEGRAPH, State.STRIKE]:
			active_attackers += 1
	var attacker_limit := 2 if living_count >= 5 else 1
	return active_attackers < attacker_limit


func _calculate_separation_velocity() -> Vector3:
	var push := Vector3.ZERO
	var desired_spacing := separation_radius * (1.3 if hound else (1.12 if skeleton else (1.35 if skeleton_archer else (1.2 if brute else 1.0))))
	for candidate in get_tree().get_nodes_in_group(&"action_enemies"):
		var other := candidate as ActionCombatEnemy3D
		if other == null or other == self or not other.is_alive():
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared >= desired_spacing * desired_spacing:
			continue
		if distance_squared <= 0.0001:
			var side := 1.0 if get_instance_id() > other.get_instance_id() else -1.0
			offset = Vector3(side, 0.0, side * 0.37)
			distance_squared = offset.length_squared()
		var distance := sqrt(distance_squared)
		push += offset / distance * (1.0 - distance / desired_spacing)
	return push.limit_length(1.0) * separation_strength


func _try_strike_player() -> void:
	if not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length() > attack_range + 0.8:
		return
	var forward := -visual.global_basis.z
	forward.y = 0.0
	if offset.length_squared() > 0.01 and forward.normalized().dot(offset.normalized()) < 0.15:
		return
	if _player.receive_enemy_attack(attack_damage, self):
		strike_landed.emit(_player.global_position + Vector3.UP * 0.7)


func take_action_damage(amount: float, source: Node, knockback_force: float, stagger_duration: float, finisher: bool) -> bool:
	if state == State.DEAD or _invincible_timer > 0.0:
		return false
	health = maxf(0.0, health - maxf(0.0, amount))
	_invincible_timer = 0.065
	telegraph.visible = false
	if hound or skeleton or skeleton_archer:
		_play_animation(&"Hit_Recoil", (1.15 if not finisher else 0.92) if hound else (1.0 if not finisher else 0.82), true)
	_impact_hold_duration = 0.085 if finisher else 0.055
	_play_hit_flash(finisher)
	var source_3d := source as Node3D
	if source_3d != null:
		var away := global_position - source_3d.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			_knockback = away.normalized() * knockback_force
	damaged.emit(global_position + Vector3.UP * 0.9, amount, finisher)
	if health <= 0.0:
		_die()
	else:
		state = State.STAGGER
		_state_elapsed = 0.0
		var minimum_recoil_duration := (0.52 if finisher else 0.42) if hound else ((0.48 if finisher else 0.4) if skeleton else ((0.44 if finisher else 0.38) if skeleton_archer else (0.46 if finisher else 0.36)))
		_state_duration = maxf(stagger_duration, minimum_recoil_duration) * (0.72 if brute else 1.0)
	return true


func _play_hit_flash(finisher: bool) -> void:
	if hit_flash == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	hit_flash.light_energy = 7.5 if finisher else 4.8
	hit_flash.omni_range = 3.4 if finisher else 2.7
	_hit_flash_tween = create_tween()
	_hit_flash_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_hit_flash_tween.tween_property(hit_flash, ^"light_energy", 0.0, 0.14 if finisher else 0.1)


func is_alive() -> bool:
	return state != State.DEAD and health > 0.0


func _die() -> void:
	state = State.DEAD
	_death_elapsed = 0.0
	telegraph.visible = false
	collision_layer = 0
	collision_mask = 0
	body_shape.set_deferred("disabled", true)
	died.emit(self)


func _tick_death(delta: float) -> void:
	_death_elapsed += delta
	var progress := clampf(_death_elapsed / 0.58, 0.0, 1.0)
	visual.rotation.z = progress * 1.15
	visual.scale = _base_visual_scale * Vector3(1.0 + progress * 0.25, 1.0 - progress * 0.9, 1.0 + progress * 0.25)
	visual.position = _base_visual_position + Vector3.DOWN * progress * 0.25
	if progress >= 1.0:
		queue_free()


func _play_animation(requested: StringName, speed_scale: float = 1.0, restart: bool = false) -> void:
	if animation_player == null:
		return
	var animation_name := _resolve_animation(requested)
	if animation_name.is_empty() or (not restart and animation_name == _active_animation):
		return
	_active_animation = animation_name
	animation_player.play(animation_name, 0.08, speed_scale)


func _resolve_animation(requested: StringName) -> StringName:
	if animation_player == null:
		return StringName()
	if animation_player.has_animation(requested):
		return requested
	var expected := String(requested).to_lower()
	for candidate in animation_player.get_animation_list():
		var normalized := String(candidate).to_lower()
		if normalized == expected or normalized.ends_with("/" + expected) or normalized.begins_with(expected + "."):
			return candidate
	return StringName()


func _face_player() -> void:
	if not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.01:
		visual.look_at(global_position + offset.normalized(), Vector3.UP)


func _is_slime() -> bool:
	return not hound and not skeleton and not skeleton_archer and body_mesh != null


func _animate_slime_idle(delta: float, moving: bool) -> void:
	_slime_motion_clock += delta * (8.0 if moving else 3.4)
	var bounce := sin(_slime_motion_clock) * (0.055 if moving else 0.025)
	var side_wobble := sin(_slime_motion_clock * 0.53) * (0.045 if moving else 0.018)
	visual.scale = _base_visual_scale * Vector3(1.0 - bounce * 0.42, 1.0 + bounce, 1.0 - bounce * 0.42)
	visual.position = _base_visual_position + Vector3.UP * maxf(0.0, bounce) * 0.12
	visual.rotation.z = side_wobble
	if core_mesh != null:
		core_mesh.scale = _core_base_scale * (1.0 + sin(_slime_motion_clock * 1.35) * 0.06)


func _animate_slime_telegraph(progress: float) -> void:
	var scale_shape := Vector3.ONE
	if progress < 0.22:
		var settle := _ease_out_back(progress / 0.22)
		scale_shape = Vector3(1.0 + settle * 0.08, 1.0 - settle * 0.08, 1.0 + settle * 0.08)
	elif progress < 0.74:
		var squash := _smoothstep((progress - 0.22) / 0.52)
		scale_shape = Vector3(1.08 + squash * 0.34, 0.92 - squash * 0.38, 1.08 + squash * 0.34)
	else:
		var stretch := _ease_out_back((progress - 0.74) / 0.26)
		scale_shape = Vector3(1.42 - stretch * 0.62, 0.54 + stretch * 0.9, 1.42 - stretch * 0.62)
	visual.scale = _base_visual_scale * scale_shape
	visual.position = _base_visual_position
	visual.rotation.x = deg_to_rad(-9.0) * progress
	visual.rotation.z = sin(progress * PI * 3.0) * 0.045 * (1.0 - progress)
	if core_mesh != null:
		var charge_pulse := 1.0 + sin(progress * PI * 8.0) * 0.08 + progress * 0.18
		core_mesh.scale = _core_base_scale * charge_pulse
		core_mesh.position = _core_base_position + Vector3.DOWN * progress * 0.08
	_animate_slime_face(Vector3(1.18, 0.72, 1.12), 0.04 * progress)


func _animate_slime_strike(progress: float) -> void:
	var scale_shape := Vector3.ONE
	if progress < 0.38:
		var launch := _ease_out_back(progress / 0.38)
		scale_shape = Vector3(0.8 - launch * 0.12, 1.44 + launch * 0.16, 0.8 - launch * 0.12)
		visual.rotation.x = deg_to_rad(-9.0 - launch * 19.0)
	elif progress < 0.68:
		var impact := _ease_out_back((progress - 0.38) / 0.3)
		scale_shape = Vector3(0.68 + impact * 0.78, 1.6 - impact * 1.02, 0.68 + impact * 0.78)
		visual.rotation.x = deg_to_rad(-28.0 + impact * 24.0)
	else:
		var rebound := _smoothstep((progress - 0.68) / 0.32)
		var ring := sin(rebound * PI)
		scale_shape = Vector3(1.46 - rebound * 0.46 - ring * 0.1, 0.58 + rebound * 0.42 + ring * 0.2, 1.46 - rebound * 0.46 - ring * 0.1)
		visual.rotation.x = deg_to_rad(-4.0) * (1.0 - rebound)
	visual.scale = _base_visual_scale * scale_shape
	visual.position = _base_visual_position + Vector3.UP * sin(progress * PI) * 0.08
	if core_mesh != null:
		core_mesh.scale = _core_base_scale * (1.25 - progress * 0.18)
	_animate_slime_face(Vector3(1.28, 0.62, 1.12), 0.075 * sin(progress * PI))


func _animate_slime_recover(progress: float) -> void:
	var damping := 1.0 - progress
	var wobble := sin(progress * PI * 5.0) * damping
	visual.scale = _base_visual_scale * Vector3(1.0 + wobble * 0.18, 1.0 - wobble * 0.22, 1.0 + wobble * 0.18)
	visual.position = _base_visual_position
	visual.rotation.x = deg_to_rad(-4.0) * damping
	visual.rotation.z = wobble * 0.055
	if core_mesh != null:
		core_mesh.scale = _core_base_scale * (1.0 + wobble * 0.12)
		core_mesh.position = _core_base_position
	_animate_slime_face(Vector3.ONE, wobble * 0.02)


func _animate_slime_stagger(progress: float, holding_impact: bool) -> void:
	if holding_impact:
		visual.scale = _base_visual_scale * Vector3(1.32, 0.68, 1.08)
		visual.rotation.z = -0.14
		visual.position = _base_visual_position
		_animate_slime_face(Vector3(1.25, 0.58, 1.1), -0.045)
		return
	var damping := 1.0 - progress
	var wobble := sin(progress * PI * 4.5) * damping
	visual.scale = _base_visual_scale * Vector3(1.0 + wobble * 0.28, 1.0 - wobble * 0.3, 1.0 + wobble * 0.18)
	visual.rotation.z = (-0.14 * damping) + wobble * 0.09
	visual.position = _base_visual_position
	_animate_slime_face(Vector3.ONE, wobble * 0.035)


func _animate_slime_face(face_scale: Vector3, vertical_offset: float) -> void:
	for eye in [eye_left, eye_right]:
		if eye != null:
			eye.scale = face_scale
	if eye_left != null:
		eye_left.position = _eye_left_base_position + Vector3.UP * vertical_offset
	if eye_right != null:
		eye_right.position = _eye_right_base_position + Vector3.UP * vertical_offset


func _reset_slime_parts() -> void:
	if body_mesh != null:
		body_mesh.scale = _body_base_scale
	if core_mesh != null:
		core_mesh.scale = _core_base_scale
		core_mesh.position = _core_base_position
	_animate_slime_face(Vector3.ONE, 0.0)


func _reset_visual_pose() -> void:
	visual.scale = _base_visual_scale
	visual.position = _base_visual_position
	visual.rotation.x = 0.0
	visual.rotation.z = 0.0
	_reset_slime_parts()


func _smoothstep(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _ease_out_back(value: float) -> float:
	var t := clampf(value, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * t * t * t + 1.70158 * t * t


func _apply_color_materials() -> void:
	if body_mesh == null or core_mesh == null:
		return
	var body_material := body_mesh.material_override.duplicate() as StandardMaterial3D
	body_material.albedo_color = accent_color.darkened(0.66)
	body_mesh.material_override = body_material
	var core_material := core_mesh.material_override.duplicate() as StandardMaterial3D
	core_material.albedo_color = accent_color
	core_material.emission = accent_color
	core_mesh.material_override = core_material
	var telegraph_material := telegraph.material_override.duplicate() as StandardMaterial3D
	telegraph_material.albedo_color = Color(accent_color, 0.62)
	telegraph_material.emission = accent_color
	telegraph.material_override = telegraph_material
