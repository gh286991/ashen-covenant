class_name CovenantEnemy
extends CharacterBody2D

signal died(enemy: CovenantEnemy, xp_reward: int, was_boss: bool)
signal attack_requested(enemy: CovenantEnemy, center: Vector2, radius: float, raw_damage: float, color: Color)
signal projectile_requested(origin: Vector2, direction: Vector2, speed: float, raw_damage: float, color: Color)
signal summon_requested(origin: Vector2, count: int)
signal damaged(position: Vector2, amount: int, critical: bool, impact_direction: Vector2)

enum AIState { CHASE, WINDUP, RECOVER, CHARGE, STAGGER, DEAD }
enum AttackStyle { MELEE, PROJECTILE, RADIAL, CHARGE }

const DEATH_DURATION := 0.26
const BOSS_DEATH_DURATION := 0.48

const GHOUL_TEXTURES := [
	preload("res://assets/sprites/ghoul_idle/idle-1.png"),
	preload("res://assets/sprites/ghoul_idle/idle-2.png"),
	preload("res://assets/sprites/ghoul_idle/idle-3.png"),
	preload("res://assets/sprites/ghoul_idle/idle-4.png"),
]
const WRAITH_TEXTURES := [
	preload("res://assets/sprites/wraith_idle/idle-1.png"),
	preload("res://assets/sprites/wraith_idle/idle-2.png"),
	preload("res://assets/sprites/wraith_idle/idle-3.png"),
	preload("res://assets/sprites/wraith_idle/idle-4.png"),
]
const BRUTE_TEXTURES := [
	preload("res://assets/sprites/brute_idle/idle-1.png"),
	preload("res://assets/sprites/brute_idle/idle-2.png"),
	preload("res://assets/sprites/brute_idle/idle-3.png"),
	preload("res://assets/sprites/brute_idle/idle-4.png"),
]
const BOSS_TEXTURES := [
	preload("res://assets/sprites/boss_idle/idle-1.png"),
	preload("res://assets/sprites/boss_idle/idle-2.png"),
	preload("res://assets/sprites/boss_idle/idle-3.png"),
	preload("res://assets/sprites/boss_idle/idle-4.png"),
]

var enemy_kind: StringName = &"ghoul"
var display_name := "Ash Ghoul"
var target: CovenantPlayer
var is_boss := false
var enemy_level := 1
var max_health := 60.0
var health := 60.0
var armor := 4.0
var move_speed := 100.0
var contact_damage := 13.0
var attack_range := 58.0
var attack_radius := 62.0
var attack_cooldown_duration := 1.25
var attack_cooldown := 0.25
var windup_duration := 0.34
var state := AIState.CHASE
var state_timer := 0.0
var state_duration := 0.0
var hurt_flash := 0.0
var invincible_timer := 0.0
var facing := Vector2.DOWN
var knockback_velocity := Vector2.ZERO
var locomotion_velocity := Vector2.ZERO
var charge_direction := Vector2.ZERO
var attack_direction := Vector2.DOWN
var attack_origin := Vector2.ZERO
var attack_center := Vector2.ZERO
var attack_style := AttackStyle.MELEE
var attack_pattern := 0
var boss_phase := 1
var xp_reward := 18
var spawn_time := 0.0
var rng := RandomNumberGenerator.new()
var visual_root: Node2D
var art_sprite: Sprite2D
var art_scale := 0.43
var art_base_y := -44.0
var movement_filter: Callable
var activation_radius := 520.0
var death_timer := 0.0

func setup(kind: StringName, level_value: int, player: CovenantPlayer, boss: bool = false) -> CovenantEnemy:
	enemy_kind = kind
	enemy_level = maxi(1, level_value)
	target = player
	is_boss = boss
	_apply_archetype()
	return self

func _apply_archetype() -> void:
	var scale_factor := pow(1.15, clampi(enemy_level - 1, 0, 20))
	match enemy_kind:
		&"wraith":
			display_name = "Void Wraith"
			max_health = 48.0 * scale_factor
			move_speed = 92.0
			contact_damage = 15.0 * scale_factor
			attack_range = 310.0
			attack_radius = 40.0
			attack_cooldown_duration = 1.8
			windup_duration = 0.5
			armor = 3.0 + enemy_level
			xp_reward = 22 + enemy_level * 3
		&"brute":
			display_name = "Grave Brute"
			max_health = 125.0 * scale_factor
			move_speed = 74.0
			contact_damage = 23.0 * scale_factor
			attack_range = 90.0
			attack_radius = 88.0
			attack_cooldown_duration = 2.35
			windup_duration = 0.72
			armor = 16.0 + enemy_level * 2.0
			xp_reward = 42 + enemy_level * 5
		&"boss":
			display_name = "THE ASHEN WARDEN"
			is_boss = true
			max_health = 880.0 * scale_factor
			move_speed = 84.0
			contact_damage = 30.0 * scale_factor
			attack_range = 125.0
			attack_radius = 135.0
			attack_cooldown_duration = 2.0
			windup_duration = 0.82
			armor = 24.0 + enemy_level * 2.0
			xp_reward = 350
		_:
			display_name = "Ash Ghoul"
			max_health = 62.0 * scale_factor
			move_speed = 112.0
			contact_damage = 13.0 * scale_factor
			attack_range = 62.0
			attack_radius = 66.0
			attack_cooldown_duration = 1.22
			windup_duration = 0.3
			armor = 5.0 + enemy_level
			xp_reward = 16 + enemy_level * 3
	health = max_health

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 0
	var shape_node := CollisionShape2D.new()
	shape_node.name = "BodyShape"
	var circle := CircleShape2D.new()
	circle.radius = 30.0 if is_boss else (23.0 if enemy_kind == &"brute" else 16.0)
	shape_node.shape = circle
	add_child(shape_node)
	visual_root = Node2D.new()
	visual_root.name = "VisualRoot"
	visual_root.z_index = 1
	add_child(visual_root)
	_configure_art_sprite()
	add_to_group(&"enemies")
	rng.seed = hash("%s_%s_%s" % [enemy_kind, global_position, Time.get_ticks_usec()])
	z_index = 0

func _configure_art_sprite() -> void:
	art_sprite = Sprite2D.new()
	art_sprite.name = "ArtSprite"
	match enemy_kind:
		&"wraith":
			art_sprite.texture = WRAITH_TEXTURES[0]
			art_scale = 0.42
			art_base_y = -44.0
		&"brute":
			art_sprite.texture = BRUTE_TEXTURES[0]
			art_scale = 0.54
			art_base_y = -56.0
		&"boss":
			art_sprite.texture = BOSS_TEXTURES[0]
			art_scale = 0.49
			art_base_y = -66.0
		_:
			art_sprite.texture = GHOUL_TEXTURES[0]
			art_scale = 0.41
			art_base_y = -43.0
	art_sprite.scale = Vector2.ONE * art_scale
	art_sprite.position = Vector2(0, art_base_y)
	art_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visual_root.add_child(art_sprite)

func _physics_process(delta: float) -> void:
	spawn_time += delta
	if state == AIState.DEAD:
		hurt_flash = maxf(0.0, hurt_flash - delta)
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
		death_timer += delta
		locomotion_velocity = Vector2.ZERO
		velocity = knockback_velocity
		move_and_slide()
		_update_art_sprite()
		queue_redraw()
		if death_timer >= (BOSS_DEATH_DURATION if is_boss else DEATH_DURATION):
			queue_free()
		return
	if not is_instance_valid(target):
		return
	if not target.gameplay_enabled:
		velocity = Vector2.ZERO
		_update_art_sprite()
		queue_redraw()
		return
	hurt_flash = maxf(0.0, hurt_flash - delta)
	invincible_timer = maxf(0.0, invincible_timer - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	var distance_to_target := global_position.distance_to(target.global_position)
	if not is_boss and distance_to_target > activation_radius:
		locomotion_velocity = locomotion_velocity.move_toward(Vector2.ZERO, 760.0 * delta)
		velocity = locomotion_velocity + knockback_velocity
		_update_art_sprite()
		queue_redraw()
		return
	if is_boss and boss_phase == 1 and health <= max_health * 0.5:
		boss_phase = 2
		attack_cooldown_duration *= 0.72
		move_speed *= 1.15
		summon_requested.emit(global_position, 3)
		state = AIState.RECOVER
		state_timer = 1.0
		state_duration = state_timer
	var previous_position := global_position
	_process_state(delta)
	velocity = locomotion_velocity + knockback_velocity
	move_and_slide()
	global_position.x = clampf(global_position.x, 35.0, 2165.0)
	global_position.y = clampf(global_position.y, 30.0, 1370.0)
	if movement_filter.is_valid() and not bool(movement_filter.call(previous_position, global_position, 18.0 if not is_boss else 30.0)):
		global_position = previous_position
		velocity = Vector2.ZERO
		locomotion_velocity = Vector2.ZERO
		knockback_velocity = Vector2.ZERO
	_update_art_sprite()
	queue_redraw()

func _update_art_sprite() -> void:
	if not is_instance_valid(art_sprite):
		return
	var direction_index := 0
	if absf(facing.x) > absf(facing.y):
		direction_index = 1 if facing.x < 0.0 else 2
	elif facing.y < 0.0:
		direction_index = 3
	match enemy_kind:
		&"wraith": art_sprite.texture = WRAITH_TEXTURES[direction_index]
		&"brute": art_sprite.texture = BRUTE_TEXTURES[direction_index]
		&"boss": art_sprite.texture = BOSS_TEXTURES[direction_index]
		_: art_sprite.texture = GHOUL_TEXTURES[direction_index]
	var moving := locomotion_velocity.length_squared() > 225.0
	var bob_speed := 5.4 if enemy_kind == &"wraith" else (7.0 if moving else 2.5)
	var bob_amount := 3.8 if enemy_kind == &"wraith" else (1.8 if moving else 0.6)
	art_sprite.position.y = art_base_y + sin(spawn_time * bob_speed + global_position.x * 0.01) * bob_amount
	var pulse := 1.0 + sin(spawn_time * 2.8) * (0.02 if is_boss else 0.008)
	art_sprite.scale = Vector2(art_scale * pulse, art_scale / pulse)
	var pose_position := Vector2.ZERO
	var pose_rotation := 0.0
	var pose_scale := Vector2.ONE
	match state:
		AIState.WINDUP:
			var p := 1.0 - state_timer / maxf(0.001, state_duration)
			pose_position = -attack_direction * lerpf(0.0, 7.0 if is_boss else 4.5, p)
			pose_rotation = sin(p * PI * 2.0) * 0.025
			pose_scale = Vector2(1.0 + p * 0.07, 1.0 - p * 0.09)
		AIState.CHARGE:
			var p := 1.0 - state_timer / maxf(0.001, state_duration)
			pose_position = charge_direction * (5.0 + sin(p * PI) * 4.0)
			pose_rotation = sin(p * PI * 4.0) * 0.018
			pose_scale = Vector2(0.88, 1.16)
		AIState.RECOVER:
			var p := 1.0 - state_timer / maxf(0.001, state_duration)
			pose_position = -attack_direction * lerpf(5.0, 0.0, p)
			pose_rotation = lerpf(0.045, 0.0, p)
			pose_scale = Vector2(lerpf(1.08, 1.0, p), lerpf(0.93, 1.0, p))
		AIState.STAGGER:
			var p := 1.0 - state_timer / maxf(0.001, state_duration)
			var recoil := knockback_velocity.normalized()
			if recoil == Vector2.ZERO:
				recoil = -facing
			pose_position = recoil * (4.0 * (1.0 - p)) + facing.orthogonal() * sin(p * PI * 7.0) * 2.4 * (1.0 - p)
			pose_rotation = sin(p * PI * 5.0) * 0.065 * (1.0 - p)
			pose_scale = Vector2(1.07 - p * 0.07, 0.93 + p * 0.07)
		AIState.DEAD:
			var duration := BOSS_DEATH_DURATION if is_boss else DEATH_DURATION
			var p := clampf(death_timer / duration, 0.0, 1.0)
			pose_position = Vector2(0.0, p * (18.0 if is_boss else 11.0))
			pose_rotation = lerpf(0.0, 0.42 if facing.x >= 0.0 else -0.42, p)
			pose_scale = Vector2(1.0 + p * 0.14, 1.0 - p * 0.45)
		_:
			if moving:
				pose_rotation = sin(spawn_time * bob_speed) * 0.012
				pose_scale = Vector2(1.0 + sin(spawn_time * bob_speed) * 0.015, 1.0 - sin(spawn_time * bob_speed) * 0.01)
	visual_root.position = pose_position
	visual_root.rotation = pose_rotation
	visual_root.scale = pose_scale
	if hurt_flash > 0.0:
		art_sprite.modulate = Color.WHITE if int(hurt_flash * 90.0) % 2 == 0 else Color("ffd7c7")
	elif is_boss and boss_phase == 2:
		art_sprite.modulate = Color(1.0, 0.72, 0.58)
	elif state == AIState.WINDUP:
		art_sprite.modulate = Color(1.0, 0.78, 0.68)
	else:
		art_sprite.modulate = Color.WHITE
	if state == AIState.DEAD:
		var duration := BOSS_DEATH_DURATION if is_boss else DEATH_DURATION
		art_sprite.modulate.a = 1.0 - clampf(death_timer / duration, 0.0, 1.0)

func _process_state(delta: float) -> void:
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > 0.1 and state == AIState.CHASE:
		facing = to_target / distance
	match state:
		AIState.CHASE:
			_process_chase(delta, distance, to_target)
		AIState.WINDUP:
			state_timer -= delta
			locomotion_velocity = locomotion_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
			if state_timer <= 0.0:
				_execute_attack()
		AIState.RECOVER:
			state_timer -= delta
			locomotion_velocity = locomotion_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			if state_timer <= 0.0:
				state = AIState.CHASE
				state_duration = 0.0
		AIState.CHARGE:
			state_timer -= delta
			locomotion_velocity = charge_direction * (390.0 if enemy_kind == &"brute" else 465.0)
			if global_position.distance_to(target.global_position) < attack_radius * 0.62:
				attack_requested.emit(self, global_position + charge_direction * 24.0, attack_radius, contact_damage * 1.25, Color("ff6c4f"))
				state_timer = 0.0
			if state_timer <= 0.0:
				state = AIState.RECOVER
				state_timer = 0.5
				state_duration = state_timer
				attack_cooldown = attack_cooldown_duration
		AIState.STAGGER:
			state_timer -= delta
			locomotion_velocity = Vector2.ZERO
			if state_timer <= 0.0:
				state = AIState.CHASE
				state_duration = 0.0

func _process_chase(delta: float, distance: float, to_target: Vector2) -> void:
	if enemy_kind == &"wraith":
		if distance < 190.0:
			locomotion_velocity = locomotion_velocity.move_toward(-to_target.normalized() * move_speed, 600.0 * delta)
		elif distance > 300.0:
			locomotion_velocity = locomotion_velocity.move_toward(to_target.normalized() * move_speed, 520.0 * delta)
		else:
			locomotion_velocity = locomotion_velocity.move_toward(to_target.orthogonal().normalized() * move_speed * 0.65, 400.0 * delta)
	else:
		locomotion_velocity = locomotion_velocity.move_toward(to_target.normalized() * move_speed, 620.0 * delta)
	if attack_cooldown <= 0.0 and distance <= attack_range:
		_begin_windup()

func _begin_windup() -> void:
	state = AIState.WINDUP
	state_timer = windup_duration
	state_duration = state_timer
	locomotion_velocity = Vector2.ZERO
	attack_direction = facing.normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN
	facing = attack_direction
	attack_style = _next_attack_style()
	attack_origin = global_position
	match attack_style:
		AttackStyle.MELEE:
			attack_center = attack_origin + attack_direction * (32.0 if is_boss else 22.0)
		_:
			attack_center = attack_origin

func _next_attack_style() -> AttackStyle:
	if enemy_kind == &"wraith":
		return AttackStyle.PROJECTILE
	if enemy_kind == &"brute":
		return AttackStyle.CHARGE
	if is_boss:
		match (attack_pattern + 1) % 3:
			0: return AttackStyle.RADIAL
			1: return AttackStyle.MELEE
			_: return AttackStyle.CHARGE
	return AttackStyle.MELEE

func _execute_attack() -> void:
	attack_pattern += 1
	if attack_style == AttackStyle.PROJECTILE:
		var volley := 3 if enemy_level >= 3 else 1
		for i in volley:
			var offset := (float(i) - float(volley - 1) * 0.5) * 0.16
			projectile_requested.emit(attack_origin, attack_direction.rotated(offset), 265.0, contact_damage, Color("b05cff"))
	elif attack_style == AttackStyle.RADIAL:
		var count := 12 if boss_phase == 2 else 8
		for i in count:
			projectile_requested.emit(attack_origin, Vector2.from_angle(TAU * float(i) / float(count)), 225.0, contact_damage * 0.72, Color("f16464"))
	elif attack_style == AttackStyle.CHARGE:
		charge_direction = attack_direction
		state = AIState.CHARGE
		state_timer = 0.68 if is_boss else 0.58
		state_duration = state_timer
		return
	elif is_boss:
		attack_requested.emit(self, attack_center, attack_radius, contact_damage * 1.2, Color("ff5f45"))
	else:
		attack_requested.emit(self, attack_center, attack_radius, contact_damage, Color("d95959"))
	state = AIState.RECOVER
	state_timer = 0.38 if not is_boss else 0.62
	state_duration = state_timer
	attack_cooldown = attack_cooldown_duration

func take_damage(packet: DamagePacket) -> bool:
	if state == AIState.DEAD or invincible_timer > 0.0:
		return false
	var amount := DamageFormula.mitigate(packet.amount, armor)
	health = maxf(0.0, health - amount)
	invincible_timer = 0.07
	hurt_flash = 0.16
	knockback_velocity = (knockback_velocity + packet.knockback * (0.22 if is_boss else 0.62)).limit_length(430.0)
	var impact_direction := packet.knockback.normalized()
	if impact_direction == Vector2.ZERO:
		impact_direction = (global_position - packet.origin).normalized()
	if impact_direction == Vector2.ZERO:
		impact_direction = -facing
	damaged.emit(global_position, int(amount), packet.is_critical, impact_direction)
	if health <= 0.0:
		_die()
	elif amount > max_health * 0.17 and not is_boss:
		state = AIState.STAGGER
		state_timer = 0.22
		state_duration = state_timer
		attack_cooldown = maxf(attack_cooldown, 0.24)
	return true

func _die() -> void:
	state = AIState.DEAD
	state_timer = 0.0
	state_duration = BOSS_DEATH_DURATION if is_boss else DEATH_DURATION
	death_timer = 0.0
	locomotion_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred(&"disabled", true)
	died.emit(self, xp_reward, is_boss)

func health_ratio() -> float:
	return clampf(health / maxf(1.0, max_health), 0.0, 1.0)

func _draw() -> void:
	var c := _body_color()
	var death_fade := 1.0
	if state == AIState.DEAD:
		death_fade = 1.0 - clampf(death_timer / (BOSS_DEATH_DURATION if is_boss else DEATH_DURATION), 0.0, 1.0)
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.4, 0.48))
	var shadow_radius := 38.0 if is_boss else (29.0 if enemy_kind == &"brute" else 20.0)
	draw_circle(Vector2.ZERO, shadow_radius, Color(0.0, 0.0, 0.0, 0.42 * death_fade))
	draw_set_transform(Vector2.ZERO)
	if state != AIState.DEAD and (is_boss or health < max_health):
		var width := 112.0 if is_boss else (62.0 if enemy_kind == &"brute" else 48.0)
		var bar_y := -136.0 if is_boss else (-112.0 if enemy_kind == &"brute" else -94.0)
		draw_rect(Rect2(-width * 0.5, bar_y, width, 7.0), Color("241a24"))
		draw_rect(Rect2(-width * 0.5 + 1.0, bar_y + 1.0, (width - 2.0) * health_ratio(), 5.0), Color("cc3d52") if not is_boss else Color("f06a43"))

func _body_color() -> Color:
	match enemy_kind:
		&"wraith": return Color("7b4ca5")
		&"brute": return Color("82504a")
		&"boss": return Color("9c3d32") if boss_phase == 1 else Color("d44b2e")
		_: return Color("596d55")

func _draw_ghoul(c: Color, bob: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 18), Vector2(-10, -8 + bob), Vector2(0, -20 + bob), Vector2(11, -7 + bob), Vector2(15, 18)]), c)
	draw_circle(Vector2(0, -16 + bob), 8.0, Color("8d977b"))
	draw_circle(Vector2(-3, -18 + bob), 1.8, Color("f4e06d"))
	draw_circle(Vector2(3, -18 + bob), 1.8, Color("f4e06d"))

func _draw_wraith(c: Color, bob: float) -> void:
	var points := PackedVector2Array([Vector2(0, -27 + bob), Vector2(17, -3 + bob), Vector2(12, 25), Vector2(2, 17), Vector2(-7, 28), Vector2(-16, -3 + bob)])
	draw_colored_polygon(points, Color(c, 0.82))
	draw_circle(Vector2(0, -15 + bob), 8.0, Color("1e162b"))
	draw_circle(Vector2(-3, -16 + bob), 2.0, Color("d8a8ff"))
	draw_circle(Vector2(3, -16 + bob), 2.0, Color("d8a8ff"))

func _draw_brute(c: Color, bob: float) -> void:
	draw_circle(Vector2.ZERO, 25.0, c)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -7), Vector2(-12, -29 + bob), Vector2(12, -29 + bob), Vector2(25, -7), Vector2(18, 20), Vector2(-18, 20)]), c)
	draw_circle(Vector2(0, -21 + bob), 11.0, Color("a78477"))
	draw_line(Vector2(-13, -7), Vector2(13, 7), Color("4a2528"), 5.0)

func _draw_boss(c: Color, bob: float) -> void:
	var side := facing.orthogonal()
	var body := PackedVector2Array([-facing * 34.0 + side * 23.0, facing * 34.0 + side * 29.0, facing * 38.0 - side * 29.0, -facing * 34.0 - side * 23.0])
	draw_colored_polygon(body, c)
	draw_polyline(body, Color("ff9a5c"), 3.0)
	draw_circle(-facing * 23.0 + Vector2(0, bob), 16.0, Color("2d2022"))
	for sign_value in [-1.0, 1.0]:
		draw_line(-facing * 28.0 + side * sign_value * 8.0, -facing * 46.0 + side * sign_value * 19.0, Color("e8d3aa"), 5.0)
	draw_circle(-facing * 26.0 + side * 6.0, 2.5, Color("ffcf5a"))
	draw_circle(-facing * 26.0 - side * 6.0, 2.5, Color("ffcf5a"))
	draw_arc(Vector2.ZERO, 43.0 + sin(spawn_time * 3.0) * 3.0, 0.0, TAU, 40, Color(c, 0.42), 3.0)
