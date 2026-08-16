class_name DungeonMonster3D
extends CharacterBody3D

## Lightweight 3D dungeon enemy placeholder.
## The scene is intentionally modular so its visual child can be replaced by
## a real monster GLB later without changing placement or movement logic.

@export_group("Identity")
@export var monster_id: StringName = &"CRYPT_WRAITH"

@export_group("Movement / AI")
@export var move_speed: float = 0.8
@export var aggro_range: float = 3.8
@export var patrol_radius: float = 0.65
@export var bob_height: float = 0.05

@export_group("Combat")
@export var max_health: float = 40.0

var _home_position := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _phase := 0.0
var _player: Node3D
var _health: float
var _hit_reaction_timer := 0.0
var _hovered := false
var _selected := false

@onready var _visual: Node3D = $Visual
@onready var _hover_indicator: Node3D = $SelectionIndicator/HoverRing
@onready var _selected_indicator: Node3D = $SelectionIndicator/SelectedRing
@onready var _selected_diamond: Node3D = $SelectionIndicator/SelectedDiamond


func _ready() -> void:
	add_to_group("dungeon_monsters")
	_health = max_health
	_home_position = global_position
	_phase = absf(global_position.x * 0.71 + global_position.z * 1.13)
	_choose_patrol_target()
	_refresh_selection_indicator()


func is_alive() -> bool:
	return _health > 0.0 and not is_queued_for_deletion()


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
	if is_node_ready():
		$SelectionIndicator.position.y = 0.04 + sin(Time.get_ticks_msec() * 0.005 + _phase) * 0.025
	if _hit_reaction_timer > 0.0:
		_hit_reaction_timer = maxf(0.0, _hit_reaction_timer - delta)
		_visual.scale = Vector3.ONE * (1.0 + _hit_reaction_timer * 0.8)
	else:
		_visual.scale = _visual.scale.lerp(Vector3.ONE, minf(1.0, delta * 12.0))

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var direction := Vector3.ZERO
	if is_instance_valid(_player):
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() <= aggro_range:
			direction = to_player.normalized()

	if direction == Vector3.ZERO and patrol_radius > 0.0:
		var to_patrol := _patrol_target - global_position
		to_patrol.y = 0.0
		if to_patrol.length() < 0.12:
			_choose_patrol_target()
		else:
			direction = to_patrol.normalized()

	var target_velocity := direction * move_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, move_speed * 5.0 * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, move_speed * 5.0 * delta)
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = -0.15
	move_and_slide()

	if direction.length_squared() > 0.01:
		_visual.look_at(global_position + direction, Vector3.UP)
	_visual.position.y = sin(Time.get_ticks_msec() * 0.004 + _phase) * bob_height


func _choose_patrol_target() -> void:
	if patrol_radius <= 0.0:
		_patrol_target = _home_position
		return
	var angle := _phase + Time.get_ticks_msec() * 0.0003
	_patrol_target = _home_position + Vector3(cos(angle), 0.0, sin(angle)) * patrol_radius


func take_damage(amount: float, _source: Node = null) -> bool:
	_health = maxf(0.0, _health - amount)
	_hit_reaction_timer = 0.18
	if _health <= 0.0:
		_hovered = false
		_selected = false
		_refresh_selection_indicator()
		collision_layer = 0
		set_physics_process(false)
		_visual.visible = false
		queue_free()
	return true
