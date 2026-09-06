class_name ActionCombatPlayer3D
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal dash_changed(charges: int, maximum: int)
signal combo_changed(step: int)
signal damaged(amount: float, source: Node)
signal died
signal perfect_dodged(world_position: Vector3)
signal slash_requested(world_position: Vector3, direction: Vector3, combo_step: int, heavy: bool, sweep_duration: float)
signal hit_confirmed(world_position: Vector3, amount: float, heavy: bool, direction: Vector3, combo: int, defeated: bool)
signal dash_requested(world_position: Vector3, direction: Vector3)

enum State { FREE, LIGHT, HEAVY, DASH, STUN, DEAD }

const ENEMY_MASK := 4
const LIGHT_DURATIONS := [0.38, 0.4, 0.62]
const LIGHT_HIT_TIMES := [0.15, 0.24, 0.26]
const LIGHT_ANIMATION_SPEEDS := [2.45, 2.4, 2.7]
const LIGHT_DAMAGE := [14.0, 18.0, 30.0]
const LIGHT_LUNGE := [6.2, 7.0, 9.2]

@export_group("Movement")
@export var move_speed := 6.8
@export var acceleration := 42.0
@export var deceleration := 52.0
@export var gravity := 24.0

@export_group("Defense")
@export var max_health := 100.0
@export var hit_invincibility_duration := 0.42

var health := 100.0
var facing := Vector3.FORWARD
var state := State.FREE
var combo_step := 0

var _state_elapsed := 0.0
var _state_duration := 0.0
var _hit_done := false
var _queued_light := false
var _combo_grace := 0.0
var _dash_charges := 3
var _dash_recharge := 0.0
var _dash_direction := Vector3.FORWARD
var _invincible_timer := 0.0
var _knockback := Vector3.ZERO
var _attack_shape: SphereShape3D
var _mouse_light_requested := false
var _mouse_heavy_requested := false

@onready var visual: ActionWarriorVisual3D = $Visual
@onready var body_shape: CollisionShape3D = $BodyShape


func _ready() -> void:
	add_to_group(&"action_player")
	health = max_health
	_attack_shape = SphereShape3D.new()
	_attack_shape.radius = 1.45
	health_changed.emit(health, max_health)
	dash_changed.emit(_dash_charges, 3)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_light_requested = true
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_heavy_requested = true
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 24.0 * delta)
	_recharge_dash(delta)

	if state == State.DEAD:
		return

	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var move_direction := Vector3(move_input.x, 0.0, move_input.y)
	if move_direction.length_squared() > 1.0:
		move_direction = move_direction.normalized()

	var wants_light := Input.is_action_just_pressed(&"attack") or _mouse_light_requested
	var wants_heavy := Input.is_action_just_pressed(&"skill_nova") or _mouse_heavy_requested
	_mouse_light_requested = false
	_mouse_heavy_requested = false

	if Input.is_action_just_pressed(&"dash") and _dash_charges > 0 and state != State.STUN:
		_start_dash(move_direction)
	elif wants_heavy and state == State.FREE:
		_start_heavy()
	elif wants_light:
		if state == State.FREE:
			_start_light(_next_light_step())
		elif state == State.LIGHT:
			_queued_light = true

	match state:
		State.DASH:
			_tick_dash(delta)
		State.LIGHT:
			_tick_light(delta)
		State.HEAVY:
			_tick_heavy(delta)
		State.STUN:
			_tick_stun(delta)
		_:
			_tick_free_movement(delta, move_direction)

	_apply_gravity(delta)
	move_and_slide()


func _tick_free_movement(delta: float, direction: Vector3) -> void:
	if _combo_grace <= 0.0 and combo_step != 0:
		combo_step = 0
		combo_changed.emit(combo_step)
	if direction.length_squared() > 0.01:
		facing = direction
	var target := direction * move_speed + _knockback
	var response := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target.x, response * delta)
	velocity.z = move_toward(velocity.z, target.z, response * delta)
	visual.play_locomotion(&"Run" if direction != Vector3.ZERO else &"Idle", facing, 1.18)


func _start_light(step: int) -> void:
	state = State.LIGHT
	combo_step = step
	_state_elapsed = 0.0
	_state_duration = LIGHT_DURATIONS[step - 1]
	_hit_done = false
	_queued_light = false
	_combo_grace = 0.72
	face_toward_priority_target(6.0)
	visual.play_combo_attack(step, facing, LIGHT_ANIMATION_SPEEDS[step - 1])
	combo_changed.emit(combo_step)


func _next_light_step() -> int:
	if _combo_grace > 0.0 and combo_step >= 1 and combo_step < 3:
		return combo_step + 1
	return 1


func _tick_light(delta: float) -> void:
	_state_elapsed += delta
	var index := combo_step - 1
	var hit_time: float = LIGHT_HIT_TIMES[index]
	if not _hit_done and _state_elapsed >= hit_time:
		_hit_done = true
		velocity.x = facing.x * LIGHT_LUNGE[index]
		velocity.z = facing.z * LIGHT_LUNGE[index]
		var sweep_duration := maxf(0.14, _state_duration - _state_elapsed)
		slash_requested.emit(global_position + Vector3.UP * 0.15, facing, combo_step, false, sweep_duration)
		_perform_hit(LIGHT_DAMAGE[index], 2.2 + combo_step * 0.7, combo_step == 3)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 34.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 34.0 * delta)
	if _state_elapsed >= _state_duration:
		if _queued_light and combo_step < 3:
			_start_light(combo_step + 1)
		else:
			_finish_action()


func _start_heavy() -> void:
	state = State.HEAVY
	_state_elapsed = 0.0
	_state_duration = 0.98
	_hit_done = false
	face_toward_priority_target(7.0)
	visual.play_heavy_attack(facing, 1.65)


func _tick_heavy(delta: float) -> void:
	_state_elapsed += delta
	velocity.x = move_toward(velocity.x, 0.0, 44.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 44.0 * delta)
	if not _hit_done and _state_elapsed >= 0.38:
		_hit_done = true
		velocity.x = facing.x * 10.5
		velocity.z = facing.z * 10.5
		var sweep_duration := maxf(0.18, _state_duration - _state_elapsed)
		slash_requested.emit(global_position + Vector3.UP * 0.18, facing, 3, true, sweep_duration)
		_perform_hit(42.0, 9.0, true, 2.15)
	if _state_elapsed >= _state_duration:
		combo_step = 0
		combo_changed.emit(combo_step)
		_finish_action()


func _start_dash(input_direction: Vector3) -> void:
	state = State.DASH
	_state_elapsed = 0.0
	_state_duration = 0.23
	_dash_direction = input_direction.normalized() if input_direction.length_squared() > 0.01 else facing
	facing = _dash_direction
	_dash_charges -= 1
	_dash_recharge = 0.0
	_invincible_timer = 0.29
	_queued_light = false
	visual.cancel_action(facing, &"Run", 2.1)
	dash_changed.emit(_dash_charges, 3)
	dash_requested.emit(global_position + Vector3.UP * 0.25, _dash_direction)


func _tick_dash(delta: float) -> void:
	_state_elapsed += delta
	var speed := lerpf(17.5, 10.0, _state_elapsed / _state_duration)
	velocity.x = _dash_direction.x * speed
	velocity.z = _dash_direction.z * speed
	if _state_elapsed >= _state_duration:
		_finish_action()


func _tick_stun(delta: float) -> void:
	_state_elapsed += delta
	velocity.x = move_toward(velocity.x, _knockback.x, 25.0 * delta)
	velocity.z = move_toward(velocity.z, _knockback.z, 25.0 * delta)
	if _state_elapsed >= _state_duration:
		_finish_action()


func _finish_action() -> void:
	state = State.FREE
	_state_elapsed = 0.0
	visual.cancel_action(facing)


func _perform_hit(damage: float, knockback_force: float, finisher: bool, radius: float = 1.45) -> void:
	_attack_shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _attack_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + facing * 1.05 + Vector3.UP * 0.72)
	query.collision_mask = ENEMY_MASK
	query.collide_with_bodies = true
	query.exclude = [get_rid()]
	var hit_targets: Dictionary = {}
	var confirmed_hits := 0
	for result in get_world_3d().direct_space_state.intersect_shape(query, 24):
		var target := result.get("collider") as Node3D
		if target == null or hit_targets.has(target) or not target.has_method(&"take_action_damage"):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01 and facing.dot(offset.normalized()) < (-0.2 if finisher else 0.05):
			continue
		hit_targets[target] = true
		var accepted := bool(target.call(&"take_action_damage", damage, self, knockback_force, 0.32 if finisher else 0.15, finisher))
		if accepted:
			confirmed_hits += 1
			var defeated := target.has_method(&"is_alive") and not bool(target.call(&"is_alive"))
			hit_confirmed.emit(target.global_position + Vector3.UP * 0.85, damage, finisher, facing, combo_step if state == State.LIGHT else 3, defeated)
	if confirmed_hits > 0:
		# Losing a little forward momentum at contact makes the weapon feel like it met resistance.
		velocity.x *= 0.38 if finisher else 0.58
		velocity.z *= 0.38 if finisher else 0.58


func receive_enemy_attack(amount: float, source: Node) -> bool:
	if state == State.DASH or _invincible_timer > 0.0:
		if state == State.DASH and _state_elapsed <= 0.19:
			perfect_dodged.emit(global_position + Vector3.UP * 0.7)
		return false
	if state == State.DEAD:
		return false
	health = maxf(0.0, health - maxf(0.0, amount))
	_invincible_timer = hit_invincibility_duration
	state = State.STUN
	_state_elapsed = 0.0
	_state_duration = 0.24
	var source_3d := source as Node3D
	if source_3d != null:
		var away := global_position - source_3d.global_position
		away.y = 0.0
		if away.length_squared() > 0.01:
			_knockback = away.normalized() * 7.0
	visual.cancel_action(facing, &"Idle")
	health_changed.emit(health, max_health)
	damaged.emit(amount, source)
	if health <= 0.0:
		state = State.DEAD
		body_shape.set_deferred("disabled", true)
		visual.visible = false
		died.emit()
	return true


func face_toward_priority_target(max_distance: float) -> void:
	var best_distance := max_distance
	var best_direction := facing
	for node in get_tree().get_nodes_in_group(&"action_enemies"):
		var target := node as Node3D
		if target == null or not target.has_method(&"is_alive") or not bool(target.call(&"is_alive")):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance < best_distance:
			best_distance = distance
			best_direction = offset.normalized()
	facing = best_direction


func _recharge_dash(delta: float) -> void:
	if _dash_charges >= 3:
		return
	_dash_recharge += delta
	if _dash_recharge >= 0.78:
		_dash_recharge -= 0.78
		_dash_charges += 1
		dash_changed.emit(_dash_charges, 3)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2
