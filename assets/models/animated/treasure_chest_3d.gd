class_name TreasureChest3D
extends Node3D

signal opened

@export_category("Treasure Chest")
@export var interaction_distance: float = 2.35
@export var open_animation_hint: String = "lid_hinge"

var _opened := false
var _animation_player: AnimationPlayer
var _open_animation := StringName()
var _player: Node3D
var _click_collision: CollisionObject3D
var _hovered := false
var _selected := false

@onready var _prompt: Label3D = $Prompt
@onready var _selection_ring: MeshInstance3D = $SelectionRing


func _ready() -> void:
	add_to_group("treasure_chests")
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_open_animation = _resolve_open_animation()
	_click_collision = get_node_or_null("Collision") as CollisionObject3D
	if _click_collision != null:
		_click_collision.input_ray_pickable = true
		_click_collision.input_event.connect(_on_collision_input_event)
		_click_collision.mouse_entered.connect(_on_mouse_entered)
		_click_collision.mouse_exited.connect(_on_mouse_exited)
	if _animation_player != null and not _open_animation.is_empty():
		var clip := _animation_player.get_animation(_open_animation)
		if clip != null:
			clip.loop_mode = Animation.LOOP_NONE
	if _prompt != null:
		_prompt.visible = false
	_update_selection_ring()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	var in_range := is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= interaction_distance
	if _prompt != null:
		_prompt.visible = in_range and not _opened
	_update_selection_ring()
	if in_range and not _opened and Input.is_action_just_pressed("interact"):
		open_chest()


func open_chest() -> void:
	if _opened:
		return
	_opened = true
	if _prompt != null:
		_prompt.visible = false
	if _animation_player != null and not _open_animation.is_empty():
		_animation_player.play(_open_animation, 0.12)
	opened.emit()


func is_opened() -> bool:
	return _opened


func _on_collision_input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_selected = true
		open_chest()
		get_viewport().set_input_as_handled()


func _on_mouse_entered() -> void:
	_hovered = true
	_update_selection_ring()


func _on_mouse_exited() -> void:
	_hovered = false
	_update_selection_ring()


func _update_selection_ring() -> void:
	if _selection_ring != null:
		_selection_ring.visible = _hovered or _selected


func _resolve_open_animation() -> StringName:
	if _animation_player == null:
		return StringName()
	var hint := open_animation_hint.to_lower()
	for candidate in _animation_player.get_animation_list():
		var normalized := String(candidate).to_lower()
		if normalized.contains(hint) or (normalized.contains("lid") and normalized.contains("open")):
			return candidate
	return StringName()
