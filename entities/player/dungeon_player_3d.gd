class_name DungeonPlayer3D
extends CharacterBody3D

signal attack_started(direction: Vector3)
signal attack_hit(target: Node, amount: float)
signal health_changed(current: float, maximum: float)
signal mana_changed(current: float, maximum: float)
signal damaged(amount: float, source: Node)
signal died
signal dash_changed(charges: int, maximum: int)
signal combo_changed(step: int)
signal slash_requested(world_position: Vector3, direction: Vector3, combo_step: int, heavy: bool, sweep_duration: float)
signal dash_requested(world_position: Vector3, direction: Vector3)
signal hit_confirmed(world_position: Vector3, amount: float, heavy: bool, direction: Vector3, combo: int, defeated: bool)
signal perfect_dodged(world_position: Vector3)

enum State { FREE, LIGHT, HEAVY, DASH, STUN, DEAD }

const ENEMY_MASK := 4
const LIGHT_DURATIONS := [0.38, 0.40, 0.62]
const LIGHT_HIT_TIMES := [0.15, 0.22, 0.26]
const LIGHT_ANIMATION_SPEEDS := [2.45, 2.40, 2.70]
const LIGHT_DAMAGE_MULTIPLIERS := [1.0, 1.25, 1.85]
const LIGHT_LUNGE := [5.8, 6.6, 9.0]
const DASH_CHARGES_MAX := 3
const DASH_RECHARGE_TIME := 0.78

@export_group("Movement")
@export var move_speed: float = 6.2
@export var acceleration: float = 38.0
@export var deceleration: float = 48.0
@export var gravity: float = 24.0
@export var mouse_move_enabled: bool = true
@export var click_stop_distance: float = 0.16

@export_group("Combat")
@export var attack_damage: float = 20.0
@export var attack_range: float = 2.4
@export var attack_radius: float = 1.45
@export var attack_cooldown: float = 0.25

@export_group("Defense")
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var hit_invincibility_duration: float = 0.35
@export var hit_stun_duration: float = 0.22
@export var knockback_force: float = 4.5

var last_move_direction := Vector3.FORWARD
var facing := Vector3.FORWARD
var state := State.FREE
var combo_step := 0
var health: float
var mana: float

var _state_elapsed := 0.0
var _state_duration := 0.0
var _hit_done := false
var _queued_light := false
var _combo_grace := 0.0
var _dash_charges := 3
var _dash_recharge := 0.0
var _dash_direction := Vector3.FORWARD
var _invincible_timer := 0.0
var _mouse_target := Vector3.ZERO
var _mouse_target_active := false
var _attack_direction := Vector3.FORWARD
var _attack_elapsed := -1.0
var _attack_duration := 0.0
var _attack_cooldown_timer := 0.0
var _attack_shape: SphereShape3D
var _attack_target: DungeonMonster3D
var _mouse_aimed_attack := false
var _chest_target: TreasureChest3D
var _hovered_target: DungeonMonster3D
var _hit_stun_timer := 0.0
var _hit_reaction_timer := 0.0
var _knockback_velocity := Vector3.ZERO
var _dead := false
var _base_visual_scale := Vector3.ONE
var _base_attack_damage: float
var _base_max_health: float
var _base_move_speed: float
var _base_attack_cooldown: float
var _critical_chance := 0.05

@onready var visual: DungeonWarrior3D = $Visual
@onready var _body_shape: CollisionShape3D = $BodyShape
@onready var progression: DungeonProgression = %Progression


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group("player")
	_base_attack_damage = attack_damage
	_base_max_health = max_health
	_base_move_speed = move_speed
	_base_attack_cooldown = attack_cooldown
	if progression != null:
		if not progression.progression_changed.is_connected(_on_progression_changed):
			progression.progression_changed.connect(_on_progression_changed)
		_apply_progression_values(progression.get_snapshot(), false)
	health = max_health
	mana = max_mana
	_attack_shape = SphereShape3D.new()
	_attack_shape.radius = attack_radius
	_base_visual_scale = visual.scale if visual != null else Vector3.ONE
	health_changed.emit(health, max_health)
	mana_changed.emit(mana, max_mana)
	dash_changed.emit(_dash_charges, DASH_CHARGES_MAX)
	combo_changed.emit(0)
	if visual != null and not visual.attack_finished.is_connected(_on_attack_animation_finished):
		visual.attack_finished.connect(_on_attack_animation_finished)


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	_set_hovered_target(_pick_monster(get_viewport().get_mouse_position()))


func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed(&"dash"):
		if _dash_charges > 0 and state != State.STUN:
			_start_dash(_get_current_move_input())
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"skill_nova") and event is not InputEventMouseButton:
		if state == State.FREE:
			_start_heavy()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"attack"):
		if state == State.FREE:
			_start_light(_next_light_step())
		elif state == State.LIGHT:
			_queued_light = true
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if state == State.FREE:
				clear_attack_target()
				_aim_at_cursor(event.position)
				_start_heavy(true)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.shift_pressed:
				clear_attack_target()
				clear_move_target()
				if state == State.FREE:
					_aim_at_cursor(event.position)
					_start_light(_next_light_step(), true)
				elif state == State.LIGHT:
					_queued_light = true
				get_viewport().set_input_as_handled()
				return
			var clicked_monster := _pick_monster(event.position)
			var clicked_chest := _pick_chest(event.position)
			if clicked_chest != null:
				clear_attack_target()
				clear_move_target()
				_chest_target = clicked_chest
				get_viewport().set_input_as_handled()
				return
			if clicked_monster != null:
				set_attack_target(clicked_monster)
				var offset := clicked_monster.global_position - global_position
				offset.y = 0.0
				if offset.length() <= attack_range * 0.82:
					if offset.length_squared() > 0.001:
						facing = offset.normalized()
						last_move_direction = facing
					if state == State.FREE:
						_start_light(_next_light_step())
					elif state == State.LIGHT:
						_queued_light = true
				get_viewport().set_input_as_handled()
				return
			if mouse_move_enabled:
				clear_attack_target()
				_set_mouse_target(event.position)
				get_viewport().set_input_as_handled()
				return


func _get_current_move_input() -> Vector3:
	var input_2d := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input_2d.length_squared() > 0.01:
		return Vector3(input_2d.x, 0.0, input_2d.y).normalized()
	return facing


func _aim_at_cursor(screen_position: Vector2) -> void:
	var target := _pick_monster(screen_position)
	var point: Variant = target.global_position if target != null else _screen_to_ground(screen_position)
	if point is Vector3:
		var offset: Vector3 = point - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.001:
			facing = offset.normalized()
			last_move_direction = facing


func clear_move_target() -> void:
	_mouse_target_active = false
	_chest_target = null


func set_attack_target(target: DungeonMonster3D) -> void:
	_chest_target = null
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


func _pick_chest(screen_position: Vector2) -> TreasureChest3D:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var origin := camera.project_ray_origin(screen_position)
	# Dedicated interaction layer avoids decorative props swallowing chest clicks.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen_position) * 200.0, 256)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var node := hit.get("collider") as Node
	while node != null:
		if node is TreasureChest3D:
			return node as TreasureChest3D
		node = node.get_parent()
	return null


func _physics_process(delta: float) -> void:
	_invincible_timer = maxf(0.0, _invincible_timer - delta)
	_combo_grace = maxf(0.0, _combo_grace - delta)
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_hit_reaction_timer = maxf(0.0, _hit_reaction_timer - delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 22.0 * delta)
	_recharge_dash(delta)
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

	var move_input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var move_direction := Vector3.ZERO
	if move_input.length_squared() > 0.01:
		_chest_target = null
		_mouse_target_active = false
		move_direction = Vector3(move_input.x, 0.0, move_input.y).normalized()
	elif is_instance_valid(_chest_target):
		var to_chest := _chest_target.global_position - global_position
		to_chest.y = 0.0
		if _chest_target.is_opened():
			_chest_target = null
		elif to_chest.length() <= _chest_target.interaction_distance:
			if state == State.FREE:
				_chest_target.open_chest()
				_chest_target = null
				velocity.x = 0.0
				velocity.z = 0.0
		else:
			move_direction = to_chest.normalized()
	elif is_instance_valid(_attack_target) and _attack_target.is_alive():
		var to_target := _attack_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > maxf(attack_range * 0.82, 0.7):
			move_direction = to_target.normalized()
		else:
			facing = to_target.normalized() if to_target.length_squared() > 0.001 else facing
			last_move_direction = facing
			if state == State.FREE and _attack_cooldown_timer <= 0.0:
				_start_light(_next_light_step())
	elif _mouse_target_active:
		var to_mouse := _mouse_target - global_position
		to_mouse.y = 0.0
		if to_mouse.length() <= click_stop_distance:
			_mouse_target_active = false
		else:
			move_direction = to_mouse.normalized()

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
		last_move_direction = direction
	var target_vel := direction * move_speed + _knockback_velocity
	var response := acceleration if direction != Vector3.ZERO else deceleration
	velocity.x = move_toward(velocity.x, target_vel.x, response * delta)
	velocity.z = move_toward(velocity.z, target_vel.z, response * delta)
	if visual != null and visual.has_method(&"play_locomotion"):
		visual.play_locomotion(&"Run" if direction.length_squared() > 0.01 else &"Idle", facing, 1.18)


func start_attack(direction: Vector3) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() > 0.001:
		facing = flat.normalized()
		last_move_direction = facing
	_start_light(_next_light_step())


func is_attacking() -> bool:
	return state in [State.LIGHT, State.HEAVY] or _attack_elapsed >= 0.0


func _start_light(step: int, mouse_aimed: bool = false) -> void:
	_chest_target = null
	_mouse_aimed_attack = mouse_aimed
	state = State.LIGHT
	combo_step = step
	_state_elapsed = 0.0
	_state_duration = LIGHT_DURATIONS[step - 1]
	_attack_elapsed = 0.0
	_attack_duration = _state_duration
	_hit_done = false
	_queued_light = false
	_combo_grace = 0.72
	_mouse_target_active = false
	if not mouse_aimed:
		_face_priority_target(5.5)
	_attack_direction = facing
	last_move_direction = facing
	if visual != null and visual.has_method(&"play_combo_attack"):
		visual.play_combo_attack(step, facing, LIGHT_ANIMATION_SPEEDS[step - 1])
	attack_started.emit(facing)
	combo_changed.emit(combo_step)


func _next_light_step() -> int:
	if _combo_grace > 0.0 and combo_step >= 1 and combo_step < 3:
		return combo_step + 1
	return 1


func _tick_light(delta: float) -> void:
	_state_elapsed += delta
	_attack_elapsed = _state_elapsed
	var index := combo_step - 1
	var hit_time: float = LIGHT_HIT_TIMES[index]
	if not _hit_done and _state_elapsed >= hit_time:
		_hit_done = true
		velocity.x = facing.x * LIGHT_LUNGE[index]
		velocity.z = facing.z * LIGHT_LUNGE[index]
		var sweep_duration := maxf(0.14, _state_duration - _state_elapsed)
		slash_requested.emit(global_position + Vector3.UP * 0.15, facing, combo_step, false, sweep_duration)
		var step_damage: float = attack_damage * float(LIGHT_DAMAGE_MULTIPLIERS[index])
		_perform_hit(step_damage, 2.4 + combo_step * 0.8, combo_step == 3)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 34.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 34.0 * delta)
	if _state_elapsed >= _state_duration:
		if _queued_light and combo_step < 3:
			_start_light(combo_step + 1, _mouse_aimed_attack)
		else:
			_finish_action()


func _start_heavy(mouse_aimed: bool = false) -> void:
	_chest_target = null
	_mouse_aimed_attack = mouse_aimed
	state = State.HEAVY
	_state_elapsed = 0.0
	_state_duration = 0.98
	_attack_elapsed = 0.0
	_attack_duration = _state_duration
	_hit_done = false
	_mouse_target_active = false
	if not mouse_aimed:
		_face_priority_target(6.5)
	_attack_direction = facing
	last_move_direction = facing
	if visual != null and visual.has_method(&"play_heavy_attack"):
		visual.play_heavy_attack(facing, 1.65)
	attack_started.emit(facing)


func _tick_heavy(delta: float) -> void:
	_state_elapsed += delta
	_attack_elapsed = _state_elapsed
	velocity.x = move_toward(velocity.x, 0.0, 44.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 44.0 * delta)
	if not _hit_done and _state_elapsed >= 0.38:
		_hit_done = true
		velocity.x = facing.x * 10.5
		velocity.z = facing.z * 10.5
		var sweep_duration := maxf(0.18, _state_duration - _state_elapsed)
		slash_requested.emit(global_position + Vector3.UP * 0.18, facing, 3, true, sweep_duration)
		_perform_hit(attack_damage * 2.2, 9.5, true, 2.2)
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
	last_move_direction = _dash_direction
	_dash_charges -= 1
	_dash_recharge = 0.0
	_invincible_timer = 0.29
	_queued_light = false
	_attack_elapsed = -1.0
	if visual != null and visual.has_method(&"cancel_action"):
		visual.cancel_action(facing, &"Run", 2.1)
	dash_changed.emit(_dash_charges, DASH_CHARGES_MAX)
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
	velocity.x = move_toward(velocity.x, _knockback_velocity.x, 25.0 * delta)
	velocity.z = move_toward(velocity.z, _knockback_velocity.z, 25.0 * delta)
	if _state_elapsed >= _state_duration:
		_finish_action()


func _finish_action() -> void:
	state = State.FREE
	_state_elapsed = 0.0
	_attack_elapsed = -1.0
	_attack_cooldown_timer = attack_cooldown
	if visual != null and visual.has_method(&"cancel_action"):
		visual.cancel_action(facing)


func _perform_hit(damage: float, knockback: float, finisher: bool, radius: float = 1.45) -> void:
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
		if target == null or hit_targets.has(target):
			continue
		while target != null and not target.has_method(&"take_damage") and not target.has_method(&"take_action_damage"):
			target = target.get_parent() as Node3D
		if target == null or hit_targets.has(target):
			continue
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01 and facing.dot(offset.normalized()) < (-0.2 if finisher else 0.05):
			continue
		hit_targets[target] = true
		var dealt_damage := damage
		if randf() < _critical_chance:
			dealt_damage *= 2.0
		var accepted := false
		if target.has_method(&"take_action_damage"):
			accepted = bool(target.call(&"take_action_damage", dealt_damage, self, knockback, 0.32 if finisher else 0.15, finisher))
		elif target.has_method(&"take_damage"):
			accepted = bool(target.call(&"take_damage", dealt_damage, self))
		if accepted:
			confirmed_hits += 1
			attack_hit.emit(target, dealt_damage)
			var defeated := target.has_method(&"is_alive") and not bool(target.call(&"is_alive"))
			hit_confirmed.emit(target.global_position + Vector3.UP * 0.85, dealt_damage, finisher, facing, combo_step if state == State.LIGHT else 3, defeated)
	if confirmed_hits > 0:
		velocity.x *= 0.38 if finisher else 0.58
		velocity.z *= 0.38 if finisher else 0.58


func receive_enemy_attack(amount: float, source: Node) -> bool:
	return take_damage(amount, source)


func take_damage(amount: float, source: Node = null) -> bool:
	if _dead or _invincible_timer > 0.0:
		if state == State.DASH and _state_elapsed <= 0.19:
			perfect_dodged.emit(global_position + Vector3.UP * 0.7)
		return false
	if state == State.DASH:
		perfect_dodged.emit(global_position + Vector3.UP * 0.7)
		return false
	var actual_damage := maxf(amount, 0.0)
	if actual_damage <= 0.0:
		return false
	health = maxf(0.0, health - actual_damage)
	_invincible_timer = hit_invincibility_duration
	_hit_stun_timer = hit_stun_duration
	_hit_reaction_timer = 0.18
	_attack_elapsed = -1.0
	_mouse_target_active = false
	state = State.STUN
	_state_elapsed = 0.0
	_state_duration = 0.24
	_apply_knockback(source)
	if visual != null and visual.has_method(&"cancel_action"):
		visual.cancel_action(facing, &"Idle")
	health_changed.emit(health, max_health)
	damaged.emit(actual_damage, source)
	if health <= 0.0:
		_die()
	return true


func _face_priority_target(max_dist: float) -> void:
	if is_instance_valid(_attack_target) and _attack_target.is_alive():
		var selected_offset := _attack_target.global_position - global_position
		selected_offset.y = 0.0
		if selected_offset.length_squared() > 0.001:
			facing = selected_offset.normalized()
			return
	var best_dist := max_dist
	var best_dir := facing
	for monster_node in get_tree().get_nodes_in_group("dungeon_monsters"):
		var m := monster_node as DungeonMonster3D
		if m == null or not m.is_alive():
			continue
		var offset := m.global_position - global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist < best_dist:
			best_dist = dist
			best_dir = offset.normalized()
	facing = best_dir


func _recharge_dash(delta: float) -> void:
	if _dash_charges >= DASH_CHARGES_MAX:
		return
	_dash_recharge += delta
	if _dash_recharge >= DASH_RECHARGE_TIME:
		_dash_recharge -= DASH_RECHARGE_TIME
		_dash_charges += 1
		dash_changed.emit(_dash_charges, DASH_CHARGES_MAX)


func _set_mouse_target(screen_position: Vector2) -> void:
	_chest_target = null
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


func _on_progression_changed(snapshot: Dictionary) -> void:
	_apply_progression_values(snapshot, true)


func _apply_progression_values(snapshot: Dictionary, adjust_current_health: bool) -> void:
	var old_max_health := max_health
	attack_damage = _base_attack_damage + float(snapshot.get("attack_damage_bonus", 0.0))
	max_health = maxf(1.0, _base_max_health + float(snapshot.get("max_health_bonus", 0.0)))
	move_speed = _base_move_speed + float(snapshot.get("move_speed_bonus", 0.0))
	attack_cooldown = _base_attack_cooldown * float(snapshot.get("attack_cooldown_multiplier", 1.0))
	_critical_chance = clampf(float(snapshot.get("critical_chance", 0.05)), 0.0, 0.5)
	if adjust_current_health:
		health = clampf(health + maxf(0.0, max_health - old_max_health), 0.0, max_health)
		health_changed.emit(health, max_health)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.2


func is_alive() -> bool:
	return not _dead and health > 0.0 and is_inside_tree()


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
	state = State.DEAD
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
	if _attack_elapsed >= 0.0 and state in [State.LIGHT, State.HEAVY]:
		_attack_elapsed = _attack_duration
