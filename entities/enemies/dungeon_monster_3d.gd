class_name DungeonMonster3D
extends CharacterBody3D

## Lightweight 3D dungeon enemy with body collision, hit reaction, and a
## timed melee attack. Damage is delivered through the take_damage() contract
## so the player and future enemy types can share the same combat flow.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died
signal attack_started(direction: Vector3)
signal attack_hit(target: Node, amount: float)

const PLAYER_LAYER := 2
const DEATH_DURATION := 0.72

@export_group("Identity")
@export var monster_id: StringName = &"CRYPT_WRAITH"
@export_range(1, 999, 1) var experience_reward := 55

@export_group("Movement / AI")
@export var move_speed: float = 0.8
@export var aggro_range: float = 3.8
@export var patrol_radius: float = 0.65
@export var bob_height: float = 0.05

@export_group("Combat")
@export var max_health: float = 40.0
@export var attack_damage: float = 8.0
@export var attack_range: float = 1.55
@export var attack_radius: float = 0.95
@export var attack_windup: float = 0.42
@export var attack_recovery: float = 0.34
@export var attack_cooldown: float = 1.05
@export var hit_stun_duration: float = 0.18
@export var hit_invincibility_duration: float = 0.12
@export var knockback_force: float = 2.4

@export var attack_jump_height: float = 0.18
@export var attack_squash_scale := Vector3(1.05, 0.94, 1.05)
@export var attack_stretch_scale := Vector3(0.94, 1.22, 0.94)
@export var attack_landing_scale := Vector3(1.04, 0.96, 1.04)

@export_group("Animation & Combat Style")
@export var is_ranged: bool = false
@export var attack_animation_name: StringName = &"Attack_Slash"
@export var attack_strike_duration: float = 0.0
@export var attack_hit_delay: float = 0.0
@export var attack_lunge_speed: float = 3.2
@export var projectile_scene: PackedScene = preload("res://entities/projectiles/skeleton_arrow_3d.tscn")
@export var projectile_spawn_offset: Vector3 = Vector3(0.0, 0.9, 0.4)

var _home_position := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _phase := 0.0
var _player: Node3D
var _health: float
var _hit_reaction_timer := 0.0
var _hit_stun_timer := 0.0
var _hit_invincibility_timer := 0.0
var _attack_cooldown_timer := 0.0
var _attack_elapsed := -1.0
var _attack_duration := 0.0
var _attack_hit_done := false
var _attack_direction := Vector3.FORWARD
var _attack_shape: SphereShape3D
var _knockback_velocity := Vector3.ZERO
var _death_elapsed := 0.0
var _death_geometry: Array[GeometryInstance3D] = []
var _dead := false
var _hovered := false
var _selected := false
var _anim_player: AnimationPlayer = null
var _active_animation: StringName = StringName()
var _telegraph: MeshInstance3D = null
var _hit_flash: OmniLight3D = null
var _hit_flash_tween: Tween = null
var _attack_variant := 1
var _active_lunge_speed := 0.0
var _base_visual_scale := Vector3.ONE
var _base_visual_position := Vector3.ZERO

@onready var _body_shape: CollisionShape3D = $BodyShape
@onready var _health_bar: Node3D = $HealthBar
@onready var _visual: Node3D = $Visual
@onready var _selection_indicator: Node3D = $SelectionIndicator
@onready var _hover_indicator: Node3D = $SelectionIndicator/HoverRing
@onready var _selected_indicator: Node3D = $SelectionIndicator/SelectedRing
@onready var _selected_diamond: Node3D = $SelectionIndicator/SelectedDiamond


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group("dungeon_monsters")
	collision_layer = 4
	collision_mask = 3 # World + Player: bodies block each other.
	_health = max_health
	_base_visual_scale = _visual.scale
	_base_visual_position = _visual.position
	_attack_shape = SphereShape3D.new()
	_attack_shape.radius = attack_radius
	_home_position = global_position
	_phase = absf(global_position.x * 0.71 + global_position.z * 1.13)
	for visual_node in _visual.find_children("*", "GeometryInstance3D", true, false):
		var geometry := visual_node as GeometryInstance3D
		if geometry != null:
			_death_geometry.append(geometry)
	_anim_player = _visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player == null:
		_anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player != null:
		_anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		for looping_clip in [&"Idle", &"Run"]:
			var resolved := _resolve_model_anim(looping_clip)
			if not resolved.is_empty():
				_anim_player.get_animation(resolved).loop_mode = Animation.LOOP_LINEAR
		_play_model_anim(&"Idle")
	_setup_combat_fx()
	_choose_patrol_target()
	health_changed.emit(_health, max_health)
	_refresh_selection_indicator()


func _setup_combat_fx() -> void:
	_telegraph = find_child("Telegraph", true, false) as MeshInstance3D
	if _telegraph == null:
		_telegraph = MeshInstance3D.new()
		_telegraph.name = "Telegraph"
		var torus := TorusMesh.new()
		var is_hound := monster_id.contains("HOUND")
		torus.inner_radius = 0.85 if is_hound else 0.58
		torus.outer_radius = 1.05 if is_hound else 0.76
		torus.rings = 24
		torus.ring_segments = 6
		_telegraph.mesh = torus
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.render_priority = 2
		var ring_color := Color("ff2b1a") if is_hound else (Color("26e0ff") if is_ranged else Color("3de0ff"))
		mat.albedo_color = Color(ring_color, 0.85)
		mat.emission_enabled = true
		mat.emission = ring_color
		mat.emission_energy_multiplier = 4.2
		_telegraph.material_override = mat
		_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_telegraph)
		_telegraph.position = Vector3(0.0, 0.08, 0.0)
	_telegraph.visible = false

	_hit_flash = find_child("HitFlash", true, false) as OmniLight3D
	if _hit_flash == null:
		_hit_flash = OmniLight3D.new()
		_hit_flash.name = "HitFlash"
		var is_hound := monster_id.contains("HOUND")
		_hit_flash.light_color = Color("ff6224") if is_hound else Color("4ee6ff")
		_hit_flash.light_energy = 0.0
		_hit_flash.omni_range = 3.0
		_hit_flash.shadow_enabled = false
		add_child(_hit_flash)
		_hit_flash.position = Vector3(0.0, 0.95, 0.0)


func is_alive() -> bool:
	return not _dead and _health > 0.0 and not is_queued_for_deletion()


func get_health() -> float:
	return _health


func set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_selection_indicator()


func set_selected(value: bool) -> void:
	_selected = value
	_refresh_selection_indicator()


func _refresh_selection_indicator() -> void:
	if not is_node_ready():
		return
	_hover_indicator.visible = _hovered and not _selected
	_selected_indicator.visible = _selected
	_selected_diamond.visible = _selected
	_health_bar.visible = _selected


func _physics_process(delta: float) -> void:
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_hit_invincibility_timer = maxf(0.0, _hit_invincibility_timer - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 12.0 * delta)

	if _dead:
		_tick_death_animation(delta)
		return

	_update_visual(delta)

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	if _hit_stun_timer > 0.0:
		_hit_stun_timer = maxf(0.0, _hit_stun_timer - delta)
		_move_body(Vector3.ZERO, delta)
		return

	if _attack_elapsed >= 0.0:
		_tick_attack(delta)
		return

	var direction := Vector3.ZERO
	var player_alive := is_instance_valid(_player) and _player.has_method(&"is_alive") and bool(_player.call(&"is_alive"))
	if player_alive:
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var distance_to_player := to_player.length()
		if distance_to_player <= attack_range:
			direction = to_player.normalized() if distance_to_player > 0.001 else _attack_direction
			_attack_direction = direction
			if _attack_cooldown_timer <= 0.0 and _can_start_attack():
				_start_attack(direction)
				return # Preserve the attack clip; locomotion must not replace it.
			if is_ranged:
				direction = -direction if distance_to_player < 6.5 * 0.68 else Vector3.ZERO
		elif distance_to_player <= aggro_range:
			direction = to_player.normalized()

	if direction == Vector3.ZERO and patrol_radius > 0.0 and not (player_alive and global_position.distance_to(_player.global_position) <= aggro_range):
		var to_patrol := _patrol_target - global_position
		to_patrol.y = 0.0
		if to_patrol.length() < 0.12:
			_choose_patrol_target()
		else:
			direction = to_patrol.normalized()

	if direction.length_squared() > 0.01:
		_play_model_anim(&"Run")
	elif _attack_elapsed < 0.0 and _hit_stun_timer <= 0.0 and not _dead:
		_play_model_anim(&"Idle")

	_move_body(direction, delta, _calculate_separation_velocity())


func _can_start_attack() -> bool:
	var active_attackers := 0
	for candidate in get_tree().get_nodes_in_group("dungeon_monsters"):
		var m := candidate as DungeonMonster3D
		if m == null or m == self or not m.is_alive():
			continue
		if float(m.get("_attack_elapsed")) >= 0.0:
			active_attackers += 1
	return active_attackers < 2


func _calculate_separation_velocity() -> Vector3:
	var push := Vector3.ZERO
	var desired_spacing := 1.25
	for candidate in get_tree().get_nodes_in_group("dungeon_monsters"):
		var other := candidate as DungeonMonster3D
		if other == null or other == self or not other.is_alive():
			continue
		var offset := global_position - other.global_position
		offset.y = 0.0
		var dist_sq := offset.length_squared()
		if dist_sq >= desired_spacing * desired_spacing:
			continue
		if dist_sq <= 0.0001:
			var side := 1.0 if get_instance_id() > other.get_instance_id() else -1.0
			offset = Vector3(side, 0.0, side * 0.35)
			dist_sq = offset.length_squared()
		var dist := sqrt(dist_sq)
		push += offset / dist * (1.0 - dist / desired_spacing)
	return push.limit_length(1.0) * 4.5


func _move_body(direction: Vector3, delta: float, separation: Vector3 = Vector3.ZERO) -> void:
	if direction.length_squared() > 0.01:
		_visual.look_at(global_position + direction, Vector3.UP)
	var target_velocity := direction * move_speed + separation + _knockback_velocity
	var response := move_speed * 5.0 if (direction != Vector3.ZERO or separation != Vector3.ZERO) else 24.0
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.15
	move_and_slide()


func _update_visual(delta: float) -> void:
	if not is_node_ready():
		return
	if _hit_reaction_timer > 0.0:
		_hit_reaction_timer = maxf(0.0, _hit_reaction_timer - delta)

	var desired_scale := Vector3.ONE
	var attack_height_offset := 0.0
	if _hit_reaction_timer > 0.0:
		desired_scale = Vector3.ONE * (1.0 + _hit_reaction_timer * 0.8)
	elif _attack_elapsed >= 0.0 and _anim_player == null:
		var attack_progress := clampf(_attack_elapsed / maxf(0.001, _attack_duration), 0.0, 1.0)
		if attack_progress < 0.26:
			var anticipation := _smooth_attack_curve(attack_progress / 0.26)
			desired_scale = Vector3.ONE.lerp(attack_squash_scale, anticipation)
			attack_height_offset = lerpf(0.0, -0.08, anticipation)
		elif attack_progress < 0.60:
			var launch := _smooth_attack_curve((attack_progress - 0.26) / 0.34)
			desired_scale = attack_squash_scale.lerp(attack_stretch_scale, launch)
			attack_height_offset = lerpf(-0.08, attack_jump_height, launch)
		elif attack_progress < 0.78:
			var landing := _smooth_attack_curve((attack_progress - 0.60) / 0.18)
			desired_scale = attack_stretch_scale.lerp(attack_landing_scale, landing)
			attack_height_offset = lerpf(attack_jump_height, 0.03, landing)
		else:
			var recovery := _smooth_attack_curve((attack_progress - 0.78) / 0.22)
			desired_scale = attack_landing_scale.lerp(Vector3.ONE, recovery)
			attack_height_offset = lerpf(0.03, 0.0, recovery)

	_visual.scale = _visual.scale.lerp(_base_visual_scale * desired_scale, minf(1.0, delta * 14.0))

	var bob_offset := sin(Time.get_ticks_msec() * 0.004 + _phase) * (bob_height if _anim_player == null else 0.0)
	_visual.position.y = lerpf(_visual.position.y, _base_visual_position.y + bob_offset + attack_height_offset, minf(1.0, delta * 18.0))

	_selection_indicator.position.y = 0.04 + sin(Time.get_ticks_msec() * 0.005 + _phase) * 0.025
	_health_bar.position = Vector3(
		MonsterHealthBar3D.BAR_OFFSET_XZ,
		MonsterHealthBar3D.BAR_OFFSET_Y + _visual.position.y,
		MonsterHealthBar3D.BAR_OFFSET_XZ
	)


func _smooth_attack_curve(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	return clamped_value * clamped_value * (3.0 - 2.0 * clamped_value)


func _tick_death_animation(delta: float) -> void:
	_death_elapsed += delta
	var progress := clampf(_death_elapsed / DEATH_DURATION, 0.0, 1.0)
	_visual.position.y = lerpf(_visual.position.y, -0.22, minf(1.0, delta * 7.0))
	if _anim_player == null:
		_visual.rotation.z = lerpf(0.0, 0.72, progress)
		_visual.scale = Vector3(
			1.0 + progress * 0.08,
			maxf(0.05, 1.0 - progress * 0.92),
			1.0 + progress * 0.08
		)
	for geometry in _death_geometry:
		if is_instance_valid(geometry):
			geometry.transparency = progress
	if progress >= 1.0:
		queue_free()


func _choose_patrol_target() -> void:
	if patrol_radius <= 0.0:
		_patrol_target = _home_position
		return
	var angle := _phase + Time.get_ticks_msec() * 0.0003
	_patrol_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * patrol_radius


func _start_attack(direction: Vector3) -> void:
	if _attack_elapsed >= 0.0 or _attack_cooldown_timer > 0.0 or not is_instance_valid(_player):
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.001:
		flat_direction = Vector3.FORWARD
	_attack_direction = flat_direction.normalized()
	_attack_duration = attack_windup + attack_strike_duration + attack_recovery
	_attack_elapsed = 0.0
	_attack_hit_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	_visual.look_at(global_position + _attack_direction, Vector3.UP)
	if _telegraph != null:
		_telegraph.visible = true
		_telegraph.scale = Vector3(0.18, 1.0, 0.18)

	var anim_name := attack_animation_name
	var animation_speed := 1.0
	_active_lunge_speed = attack_lunge_speed
	if is_ranged:
		anim_name = &"Attack_Shoot"
		_active_lunge_speed = 0.0
	elif monster_id.contains("HOUND"):
		_attack_variant = (_attack_variant + 1) % 2
		anim_name = &"Pounce_Bite" if _attack_variant == 0 else &"Claw_Swipe"
		animation_speed = 0.92 if _attack_variant == 0 else 0.75
		_active_lunge_speed = 13.5 if _attack_variant == 0 else 7.5
	_play_model_anim(anim_name, animation_speed, true)
	attack_started.emit(_attack_direction)


func _tick_attack(delta: float) -> void:
	_attack_elapsed += delta
	_visual.look_at(global_position + _attack_direction, Vector3.UP)

	if _telegraph != null and _telegraph.visible:
		if _attack_elapsed < attack_windup:
			var telegraph_progress := clampf(_attack_elapsed / maxf(0.001, attack_windup), 0.0, 1.0)
			var pulse := 1.0 + sin(telegraph_progress * TAU * 4.0) * 0.08
			_telegraph.scale = Vector3.ONE * lerpf(0.18, 1.28 if monster_id.contains("HOUND") else 1.08, telegraph_progress) * pulse
		else:
			_telegraph.visible = false

	# Melee forward thrust / pounce lunge during the active hit strike
	if not is_ranged:
		if _attack_elapsed < attack_windup:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		elif _attack_elapsed < attack_windup + (attack_strike_duration if attack_strike_duration > 0.0 else 0.24):
			var lunge_speed := _active_lunge_speed
			velocity.x = _attack_direction.x * lunge_speed
			velocity.z = _attack_direction.z * lunge_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)

	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.15
	move_and_slide()

	if not _attack_hit_done and _attack_elapsed >= attack_windup + attack_hit_delay:
		_attack_hit_done = true
		_perform_attack_hit()
	if _attack_elapsed >= _attack_duration:
		_attack_elapsed = -1.0
		_attack_cooldown_timer = attack_cooldown
		velocity.x = 0.0
		velocity.z = 0.0
		if _telegraph != null:
			_telegraph.visible = false
		if not _dead and _hit_stun_timer <= 0.0:
			_play_model_anim(&"Idle")


func _perform_attack_hit() -> void:
	if not is_instance_valid(_player):
		return

	if is_ranged:
		if projectile_scene != null:
			var arrow: SkeletonArrow3D = projectile_scene.instantiate() as SkeletonArrow3D
			if arrow != null:
				get_parent().add_child(arrow)
				var spawn_pos := global_position + _attack_direction * projectile_spawn_offset.z + Vector3.UP * projectile_spawn_offset.y
				var target_pos := _player.global_position + Vector3.UP * 0.88
				arrow.setup(spawn_pos, (target_pos - spawn_pos).normalized(), self, attack_damage)
		return

	if _attack_shape == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _attack_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + _attack_direction * 0.72 + Vector3.UP * 0.72)
	query.collision_mask = PLAYER_LAYER
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var results := get_world_3d().direct_space_state.intersect_shape(query, 8)
	for result in results:
		var target := result.get("collider") as Node
		while target != null and not target.has_method(&"take_damage") and not target.has_method(&"receive_enemy_attack"):
			target = target.get_parent()
		if target == null or target != _player:
			continue
		var offset: Vector3 = (target as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range:
			continue
		if offset.length_squared() > 0.001 and _attack_direction.dot(offset.normalized()) < -0.15:
			continue
		var accepted := false
		if target.has_method(&"receive_enemy_attack"):
			accepted = bool(target.call(&"receive_enemy_attack", attack_damage, self))
		elif target.has_method(&"take_damage"):
			accepted = bool(target.call(&"take_damage", attack_damage, self))
		if accepted:
			attack_hit.emit(target, attack_damage)
		break


func _play_hit_flash(finisher: bool = false) -> void:
	if _hit_flash == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash.light_energy = 7.5 if finisher else 4.8
	_hit_flash.omni_range = 3.4 if finisher else 2.7
	_hit_flash_tween = create_tween()
	_hit_flash_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_hit_flash_tween.tween_property(_hit_flash, ^"light_energy", 0.0, 0.14 if finisher else 0.1)


func take_action_damage(amount: float, source: Node, knockback_force_val: float, stagger_duration: float, finisher: bool) -> bool:
	if _dead or _hit_invincibility_timer > 0.0:
		return false
	var actual_damage := minf(maxf(amount, 0.0), _health)
	if actual_damage <= 0.0:
		return false
	_health = maxf(0.0, _health - actual_damage)
	_hit_invincibility_timer = 0.065
	if _telegraph != null:
		_telegraph.visible = false
	_hit_reaction_timer = 0.18
	_hit_stun_timer = maxf(stagger_duration, hit_stun_duration)
	_attack_elapsed = -1.0
	_attack_cooldown_timer = maxf(_attack_cooldown_timer, 0.24)
	_play_hit_flash(finisher)
	var source_3d := source as Node3D
	if source_3d != null and is_instance_valid(source_3d):
		var away := global_position - source_3d.global_position
		away.y = 0.0
		if away.length_squared() > 0.001:
			_knockback_velocity = away.normalized() * knockback_force_val
	_play_model_anim(&"Hit_Recoil", 1.2 if not finisher else 0.95, true)
	health_changed.emit(_health, max_health)
	damaged.emit(actual_damage, source)
	if _health <= 0.0:
		_die()
	return true


func take_damage(amount: float, source: Node = null) -> bool:
	if _dead or _hit_invincibility_timer > 0.0:
		return false
	# Never report more damage than the monster actually had left.
	var actual_damage := minf(maxf(amount, 0.0), _health)
	if actual_damage <= 0.0:
		return false
	_health = maxf(0.0, _health - actual_damage)
	_hit_invincibility_timer = hit_invincibility_duration
	if _telegraph != null:
		_telegraph.visible = false
	_hit_reaction_timer = 0.18
	_hit_stun_timer = hit_stun_duration
	_attack_elapsed = -1.0
	_attack_cooldown_timer = maxf(_attack_cooldown_timer, 0.24)
	_play_hit_flash(false)
	_apply_knockback(source)
	_play_model_anim(&"Hit_Recoil", 1.2, true)
	health_changed.emit(_health, max_health)
	damaged.emit(actual_damage, source)
	if _health <= 0.0:
		_die()
	return true


func _apply_knockback(source: Node) -> void:
	var source_3d := source as Node3D
	if source_3d == null or not is_instance_valid(source_3d):
		return
	var away := global_position - source_3d.global_position
	away.y = 0.0
	if away.length_squared() > 0.001:
		_knockback_velocity = away.normalized() * knockback_force


func _die() -> void:
	_dead = true
	_death_elapsed = 0.0
	_hovered = false
	_selected = false
	if _telegraph != null:
		_telegraph.visible = false
	if _hit_flash != null:
		_hit_flash.light_energy = 0.0
	_refresh_selection_indicator()
	collision_layer = 0
	collision_mask = 0
	_body_shape.set_deferred("disabled", true)
	_health_bar.visible = false
	_selection_indicator.visible = false
	died.emit()


func _play_model_anim(requested: StringName, speed_scale: float = 1.0, restart: bool = false) -> void:
	if _anim_player == null:
		return
	var resolved := _resolve_model_anim(requested)
	if resolved.is_empty():
		return
	if not restart and resolved == _active_animation and _anim_player.is_playing():
		return
	_active_animation = resolved
	_anim_player.play(resolved, 0.1, speed_scale)


func _resolve_model_anim(requested: StringName) -> StringName:
	if _anim_player == null:
		return StringName()
	if _anim_player.has_animation(requested):
		return requested
	var exp_str := String(requested).to_lower()
	for candidate in _anim_player.get_animation_list():
		var norm := String(candidate).to_lower()
		if norm == exp_str or norm.ends_with("/" + exp_str) or norm.contains(exp_str):
			return candidate
	return StringName()
