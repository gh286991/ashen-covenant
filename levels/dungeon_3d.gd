class_name AshenDungeon3D
extends Node3D

const CAMERA_OFFSET := Vector3(6.0, 10.0, 6.0)
const CAMERA_PITCH := -47.0
const CAMERA_YAW := 45.0
const CAMERA_FOLLOW_SPEED := 12.0
const CAMERA_SNAP_DISTANCE := 6.0

@onready var player: DungeonPlayer3D = %Player
@onready var camera: Camera3D = %Camera3D
@onready var door_prompt: Label = %DoorPrompt

var _prompt_owner: Node
var _camera_anchor := Vector3.ZERO


func _ready() -> void:
	door_prompt.visible = false
	camera.current = true
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + CAMERA_OFFSET
	# The dungeon is a fixed top-down view. Keeping the pitch fixed prevents
	# tiny physics-floor corrections from becoming visible camera shake.
	camera.rotation_degrees = Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var desired_anchor := _get_player_horizontal_position()
	if _camera_anchor.distance_to(desired_anchor) > CAMERA_SNAP_DISTANCE:
		_camera_anchor = desired_anchor
	else:
		var follow_weight := 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta)
		_camera_anchor = _camera_anchor.lerp(desired_anchor, follow_weight)
	camera.global_position = _camera_anchor + CAMERA_OFFSET


func _get_player_horizontal_position() -> Vector3:
	return Vector3(player.global_position.x, 0.0, player.global_position.z)


func show_door_prompt(text: String, source_door: Node) -> void:
	_prompt_owner = source_door
	door_prompt.text = text
	door_prompt.visible = true


func hide_door_prompt(source_door: Node) -> void:
	if source_door != _prompt_owner:
		return
	_prompt_owner = null
	door_prompt.visible = false


func transition_player(spawn: Node3D, _door: Node) -> void:
	player.global_position = spawn.global_position
	player.velocity = Vector3.ZERO
	player.clear_move_target()
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + CAMERA_OFFSET
