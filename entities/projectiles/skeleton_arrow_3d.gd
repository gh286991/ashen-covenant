class_name SkeletonArrow3D
extends Area3D

signal impacted(world_position: Vector3)

@export var speed := 16.5
@export var damage := 11.0
@export var lifetime := 3.5

var direction := Vector3.FORWARD
var source_enemy: Node3D
var _elapsed := 0.0
var _hit := false

@onready var light: OmniLight3D = $Light

func setup(start_pos: Vector3, shoot_dir: Vector3, shooter: Node3D, dmg: float = 11.0) -> void:
	global_position = start_pos
	direction = shoot_dir.normalized()
	source_enemy = shooter
	damage = dmg
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)
	reset_physics_interpolation()


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	monitoring = true
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _hit:
		return
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
		
	var step := direction * speed * delta
	global_position += step
	
	# Check proximity for player (supports both ActionCombat and Dungeon)
	var player_node := get_tree().get_first_node_in_group(&"action_player") as Node3D
	if player_node == null:
		player_node = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player_node):
		var is_alive: bool = true
		if player_node.has_method(&"is_alive"):
			is_alive = bool(player_node.call(&"is_alive"))
		if is_alive:
			var diff: Vector3 = (player_node.global_position + Vector3.UP * 0.9) - global_position
			if diff.length() <= 0.85:
				_hit_target(player_node)


func _on_body_entered(body: Node) -> void:
	if _hit:
		return
	if body is ActionCombatPlayer3D or body.is_in_group(&"player") or body.is_in_group(&"action_player"):
		_hit_target(body)
	elif body != source_enemy and not (body is ActionCombatEnemy3D) and not (body is DungeonMonster3D):
		# Hit wall or obstacle
		_explode_and_free()


func _hit_target(target: Node) -> void:
	if _hit:
		return
	_hit = true
	var attacker: Node = source_enemy if is_instance_valid(source_enemy) else self
	if target.has_method(&"receive_enemy_attack"):
		target.call(&"receive_enemy_attack", damage, attacker)
	elif target.has_method(&"take_damage"):
		target.call(&"take_damage", damage, attacker)
	if is_instance_valid(source_enemy) and source_enemy.has_signal(&"strike_landed"):
		var target_3d := target as Node3D
		var strike_pos := (target_3d.global_position if target_3d != null else global_position) + Vector3.UP * 0.7
		source_enemy.emit_signal(&"strike_landed", strike_pos)
	impacted.emit(global_position)
	_explode_and_free()


func _explode_and_free() -> void:
	_hit = true
	set_physics_process(false)
	set_deferred(&"monitoring", false)
	visible = false
	queue_free()
