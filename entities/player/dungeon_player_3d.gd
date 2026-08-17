class_name DungeonPlayer3D
extends CharacterBody3D

signal attack_started(direction: Vector3)
signal attack_hit(target: Node, amount: float)
signal health_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died

@export_group("Movement")
@export var move_speed: float = 5.4
@export var acceleration: float = 24.0
@export var deceleration: float = 30.0
@export var gravity: float = 24.0
@export var mouse_move_enabled: bool = true
@export var click_stop_distance: float = 0.16

@export_group("Combat")
@export var attack_damage: float = 20.0
@export var attack_range: float = 2.4
@export var attack_radius: float = 1.35
@export var attack_cooldown: float = 0.3

@export_group("Defense")
@export var max_health: float = 100.0
@export var hit_invincibility_duration: float = 0.22
@export var hit_stun_duration: float = 0.18
@export var knockback_force: float = 4.5

var last_move_direction := Vector3.FORWARD
var health: float
var _mouse_target := Vector3.ZERO
var _mouse_target_active := false
var _attack_direction := Vector3.FORWARD
var _attack_elapsed := -1.0
var _attack_duration := 0.0
var _attack_hit_done := false
var _attack_cooldown_timer := 0.0
var _attack_shape: SphereShape3D
var _attack_target: DungeonMonster3D
var _hovered_target: DungeonMonster3D
var _hit_invincibility_timer := 0.0
var _hit_stun_timer := 0.0
var _hit_reaction_timer := 0.0
var _knockback_velocity := Vector3.ZERO
var _dead := false
var _base_visual_scale := Vector3.ONE

@onready var visual: DungeonWarrior3D = $Visual
@onready var _body_shape: CollisionShape3D = $BodyShape


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_attack_shape = SphereShape3D.new()
	_attack_shape.radius = attack_radius
	_base_visual_scale = visual.scale if visual != null else Vector3.ONE
	health_changed.emit(health, max_health)
	if visual != null and not visual.attack_finished.is_connected(_on_attack_animation_finished):
		visual.attack_finished.connect(_on_attack_animation_finished)


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	_set_hovered_target(_pick_monster(get_viewport().get_mouse_position()))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		start_attack(last_move_direction)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var ground_point: Variant = _screen_to_ground(event.position)
		var attack_direction := last_move_direction
		if ground_point is Vector3:
			var offset: Vector3 = (ground_point as Vector3) - global_position
			offset.y = 0.0
			if offset.length_squared() > 0.001:
				attack_direction = offset.normalized()
		start_attack(attack_direction)
		get_viewport().set_input_as_handled()
		return
	if not mouse_move_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_monster := _pick_monster(event.position)
		if clicked_monster != null:
			set_attack_target(clicked_monster)
			get_viewport().set_input_as_handled()
			return
		clear_attack_target()
		_set_mouse_target(event.position)
		get_viewport().set_input_as_handled()


func clear_move_target() -> void:
	_mouse_target_active = false


func set_attack_target(target: DungeonMonster3D) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.is_alive():
		clear_attack_target()
		return
	if _attack_target != target:
		if is_instance_valid(_attack_target):
			_attack_target.set_selected(false)
		_attack_target = target
	_attack_target.set_selected(true)
	_mouse_target_active = false


func clear_attack_target() -> void:
	if is_instance_valid(_attack_target):
		_attack_target.set_selected(false)
	_attack_target = null


func _set_hovered_target(target: DungeonMonster3D) -> void:
	if _hovered_target == target:
		return
	if is_instance_valid(_hovered_target):
		_hovered_target.set_hovered(false)
	_hovered_target = target
	if is_instance_valid(_hovered_target):
		_hovered_target.set_hovered(true)


func _pick_monster(screen_position: Vector2) -> DungeonMonster3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null or get_world_3d() == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * 200.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 5)
	query.exclude = [get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	var collider := hit.get("collider") as Node
	while collider != null:
		if collider is DungeonMonster3D:
			var monster := collider as DungeonMonster3D
			return monster if monster.is_alive() else null
		collider = collider.get_parent()
	return null


func _physics_process(delta: float) -> void:
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_hit_invincibility_timer = maxf(0.0, _hit_invincibility_timer - delta)
	_hit_reaction_timer = maxf(0.0, _hit_reaction_timer - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	_update_hit_reaction(delta)
	if _dead:
		return
	if _hit_stun_timer > 0.0:
		_hit_stun_timer = maxf(0.0, _hit_stun_timer - delta)
		velocity.x = move_toward(velocity.x, _knockback_velocity.x, deceleration * delta)
		velocity.z = move_toward(velocity.z, _knockback_velocity.z, deceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if _attack_elapsed >= 0.0:
		_tick_attack(delta)
		velocity.x = move_toward(velocity.x, _knockback_velocity.x, deceleration * delta)
		velocity.z = move_toward(velocity.z, _knockback_velocity.z, deceleration * delta)
		_apply_gravity(delta)
		move_and_slide()
		return

	var direction := Vector3.ZERO
	if is_instance_valid(_attack_target) and not _attack_target.is_queued_for_deletion() and _attack_target.is_alive():
		var target_offset := _attack_target.global_position - global_position
		target_offset.y = 0.0
		var target_distance := target_offset.length()
		if target_distance > maxf(attack_range * 0.82, 0.7):
			direction = target_offset.normalized()
		else:
			_attack_direction = target_offset.normalized() if target_distance > 0.001 else last_move_direction
			last_move_direction = _attack_direction
			if _attack_elapsed < 0.0 and _attack_cooldown_timer <= 0.0:
				_start_attack(_attack_direction)
	else:
		if is_instance_valid(_attack_target):
			clear_attack_target()
		var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if input_2d.length_squared() > 0.001:
			# Keyboard input remains available as a precise fallback while the main
			# control scheme is click-to-move.
			_mouse_target_active = false
			direction = Vector3(input_2d.x, 0.0, input_2d.y)
		elif _mouse_target_active:
			var move_target_offset := _mouse_target - global_position
			move_target_offset.y = 0.0
			if move_target_offset.length() <= click_stop_distance:
				_mouse_target_active = false
			else:
				direction = move_target_offset.normalized()
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var target_velocity := direction * move_speed + _knockback_velocity
	var response := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, response * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, response * delta)

	_apply_gravity(delta)
	move_and_slide()

	if direction.length_squared() > 0.01:
		last_move_direction = direction

	var warrior_visual := get_node_or_null("Visual")
	if warrior_visual != null and warrior_visual.has_method("set_animation_state"):
		var animation := &"Walk" if direction.length_squared() > 0.01 else &"Idle"
		warrior_visual.call(&"set_animation_state", animation, last_move_direction)


func _set_mouse_target(screen_position: Vector2) -> void:
	var hit: Variant = _screen_to_ground(screen_position)
	if hit is Vector3:
		_mouse_target = hit
		_mouse_target.y = global_position.y
		_mouse_target_active = true


func _screen_to_ground(screen_position: Vector2) -> Variant:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	return Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)


func start_attack(direction: Vector3) -> void:
	_start_attack(direction)


func is_attacking() -> bool:
	return _attack_elapsed >= 0.0


func _start_attack(direction: Vector3) -> void:
	if _dead or _hit_stun_timer > 0.0 or _attack_elapsed >= 0.0 or _attack_cooldown_timer > 0.0:
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() <= 0.001:
		flat_direction = Vector3.FORWARD
	_attack_direction = flat_direction.normalized()
	last_move_direction = _attack_direction
	if visual == null:
		return
	var duration := visual.play_attack(_attack_direction)
	if duration <= 0.0:
		return
	_mouse_target_active = false
	velocity.x = 0.0
	velocity.z = 0.0
	_attack_duration = duration
	_attack_elapsed = 0.0
	_attack_hit_done = false
	attack_started.emit(_attack_direction)


func _tick_attack(delta: float) -> void:
	_attack_elapsed += delta
	var hit_time := minf(_attack_duration * 0.38, _attack_duration - 0.05)
	if not _attack_hit_done and _attack_elapsed >= hit_time:
		_attack_hit_done = true
		_perform_attack_hit()
	if _attack_elapsed >= _attack_duration:
		_attack_elapsed = -1.0
		_attack_cooldown_timer = attack_cooldown


func _perform_attack_hit() -> void:
	if _attack_shape == null:
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _attack_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + _attack_direction * 0.95 + Vector3.UP * 0.75)
	query.collision_mask = 4
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var results := get_world_3d().direct_space_state.intersect_shape(query, 16)
	for result in results:
		var target := result.get("collider") as Node3D
		if target == null or not target.has_method(&"take_damage"):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() > attack_range:
			continue
		if offset.length_squared() > 0.001 and _attack_direction.dot(offset.normalized()) < 0.0:
			continue
		var accepted := bool(target.call(&"take_damage", attack_damage, self))
		if accepted:
			attack_hit.emit(target, attack_damage)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2


func is_alive() -> bool:
	return not _dead and health > 0.0 and is_inside_tree()


func take_damage(amount: float, source: Node = null) -> bool:
	if _dead or _hit_invincibility_timer > 0.0:
		return false
	var actual_damage := maxf(amount, 0.0)
	if actual_damage <= 0.0:
		return false
	health = maxf(0.0, health - actual_damage)
	_hit_invincibility_timer = hit_invincibility_duration
	_hit_stun_timer = hit_stun_duration
	_hit_reaction_timer = 0.18
	_attack_elapsed = -1.0
	_mouse_target_active = false
	_apply_knockback(source)
	health_changed.emit(health, max_health)
	damaged.emit(actual_damage, source)
	if health <= 0.0:
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


func _update_hit_reaction(delta: float) -> void:
	if visual == null:
		return
	var desired_scale := _base_visual_scale
	if _hit_reaction_timer > 0.0:
		desired_scale = _base_visual_scale * (1.0 + _hit_reaction_timer * 0.55)
	visual.scale = visual.scale.lerp(desired_scale, minf(1.0, delta * 16.0))


func _die() -> void:
	_dead = true
	_attack_elapsed = -1.0
	velocity = Vector3.ZERO
	clear_attack_target()
	collision_layer = 0
	collision_mask = 0
	_body_shape.set_deferred("disabled", true)
	set_physics_process(false)
	if visual != null:
		visual.visible = false
	died.emit()


func _on_attack_animation_finished() -> void:
	if _attack_elapsed >= 0.0:
		_attack_elapsed = _attack_duration
