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

@export_group("Attack Visual")
@export var attack_jump_height: float = 0.42
@export var attack_squash_scale := Vector3(1.16, 0.72, 1.16)
@export var attack_stretch_scale := Vector3(0.86, 1.52, 0.86)
@export var attack_landing_scale := Vector3(1.22, 0.76, 1.22)

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

@onready var _body_shape: CollisionShape3D = $BodyShape
@onready var _health_bar: Node3D = $HealthBar
@onready var _visual: Node3D = $Visual
@onready var _selection_indicator: Node3D = $SelectionIndicator
@onready var _hover_indicator: Node3D = $SelectionIndicator/HoverRing
@onready var _selected_indicator: Node3D = $SelectionIndicator/SelectedRing
@onready var _selected_diamond: Node3D = $SelectionIndicator/SelectedDiamond


func _ready() -> void:
	add_to_group("dungeon_monsters")
	collision_layer = 4
	collision_mask = 3 # World + Player: bodies block each other.
	_health = max_health
	_attack_shape = SphereShape3D.new()
	_attack_shape.radius = attack_radius
	_home_position = global_position
	_phase = absf(global_position.x * 0.71 + global_position.z * 1.13)
	for visual_node in _visual.find_children("*", "GeometryInstance3D", true, false):
		var geometry := visual_node as GeometryInstance3D
		if geometry != null:
			_death_geometry.append(geometry)
	_choose_patrol_target()
	health_changed.emit(_health, max_health)
	_refresh_selection_indicator()


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
		_move_body(Vector3.ZERO, delta)
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
			if _attack_cooldown_timer <= 0.0:
				_start_attack(direction)
		elif distance_to_player <= aggro_range:
			direction = to_player.normalized()

	if direction == Vector3.ZERO and patrol_radius > 0.0:
		var to_patrol := _patrol_target - global_position
		to_patrol.y = 0.0
		if to_patrol.length() < 0.12:
			_choose_patrol_target()
		else:
			direction = to_patrol.normalized()

	_move_body(direction, delta)


func _move_body(direction: Vector3, delta: float) -> void:
	if direction.length_squared() > 0.01:
		_visual.look_at(global_position + direction, Vector3.UP)
	var target_velocity := direction * move_speed + _knockback_velocity
	var response := move_speed * 5.0 if direction != Vector3.ZERO else 24.0
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
	elif _attack_elapsed >= 0.0:
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
	_visual.scale = _visual.scale.lerp(desired_scale, minf(1.0, delta * 14.0))
	_selection_indicator.position.y = 0.04 + sin(Time.get_ticks_msec() * 0.005 + _phase) * 0.025
	var bob_offset := sin(Time.get_ticks_msec() * 0.004 + _phase) * bob_height
	_visual.position.y = lerpf(_visual.position.y, bob_offset + attack_height_offset, minf(1.0, delta * 18.0))
	_health_bar.position.y = MonsterHealthBar3D.BAR_OFFSET_Y + _visual.position.y


func _smooth_attack_curve(value: float) -> float:
	var clamped_value := clampf(value, 0.0, 1.0)
	return clamped_value * clamped_value * (3.0 - 2.0 * clamped_value)


func _tick_death_animation(delta: float) -> void:
	_death_elapsed += delta
	var progress := clampf(_death_elapsed / DEATH_DURATION, 0.0, 1.0)
	_visual.position.y = lerpf(_visual.position.y, -0.18, minf(1.0, delta * 7.0))
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
	_attack_duration = attack_windup + attack_recovery
	_attack_elapsed = 0.0
	_attack_hit_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	_visual.look_at(global_position + _attack_direction, Vector3.UP)
	attack_started.emit(_attack_direction)


func _tick_attack(delta: float) -> void:
	_attack_elapsed += delta
	if not _attack_hit_done and _attack_elapsed >= attack_windup:
		_attack_hit_done = true
		_perform_attack_hit()
	if _attack_elapsed >= _attack_duration:
		_attack_elapsed = -1.0
		_attack_cooldown_timer = attack_cooldown


func _perform_attack_hit() -> void:
	if _attack_shape == null or not is_instance_valid(_player):
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
		while target != null and not target.has_method(&"take_damage"):
			target = target.get_parent()
		if target == null or target != _player:
			continue
		var offset: Vector3 = (target as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range:
			continue
		if offset.length_squared() > 0.001 and _attack_direction.dot(offset.normalized()) < -0.15:
			continue
		var accepted := bool(target.call(&"take_damage", attack_damage, self))
		if accepted:
			attack_hit.emit(target, attack_damage)
		break


func take_damage(amount: float, source: Node = null) -> bool:
	if _dead or _hit_invincibility_timer > 0.0:
		return false
	var actual_damage := maxf(amount, 0.0)
	if actual_damage <= 0.0:
		return false
	_health = maxf(0.0, _health - actual_damage)
	_hit_invincibility_timer = hit_invincibility_duration
	_hit_reaction_timer = 0.18
	_hit_stun_timer = hit_stun_duration
	_attack_elapsed = -1.0
	_attack_cooldown_timer = maxf(_attack_cooldown_timer, 0.24)
	_apply_knockback(source)
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
	_refresh_selection_indicator()
	collision_layer = 0
	collision_mask = 0
	_body_shape.set_deferred("disabled", true)
	_health_bar.visible = false
	_selection_indicator.visible = false
	died.emit()
