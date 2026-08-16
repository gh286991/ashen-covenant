class_name DungeonWarrior3D
extends Node3D

signal attack_finished

## Drives the project's existing animated fantasy warrior GLB in the 3D scene.
## The imported model is a child instance so it remains replaceable in the
## Godot editor without changing the player controller.

@export var face_offset_degrees: float = 180.0

var _animation_player: AnimationPlayer
var _active_animation := StringName()
var _attack_animation := StringName()
var _attack_animation_active := false


func _ready() -> void:
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		push_warning("Dungeon warrior model has no AnimationPlayer")
		return
	_animation_player.animation_finished.connect(_on_animation_finished)
	for looping_animation in [&"Idle", &"Walk", &"Run"]:
		var resolved := _resolve_animation(looping_animation)
		if not resolved.is_empty():
			var clip := _animation_player.get_animation(resolved)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
	var attack_animation := _resolve_animation(&"Sword_Attack")
	if not attack_animation.is_empty():
		_animation_player.get_animation(attack_animation).loop_mode = Animation.LOOP_NONE
	set_animation_state(&"Idle", Vector3.FORWARD)


func set_animation_state(state: StringName, facing: Vector3) -> void:
	if _attack_animation_active and state != &"Sword_Attack":
		return
	if facing.length_squared() > 0.001:
		_apply_facing(facing)
	if _animation_player == null:
		return
	var animation_name := _resolve_animation(state)
	if animation_name.is_empty() or animation_name == _active_animation:
		return
	_animation_player.play(animation_name, 0.08)
	_active_animation = animation_name


func play_attack(facing: Vector3) -> float:
	if _animation_player == null:
		return 0.0
	var animation_name := _resolve_animation(&"Sword_Attack")
	if animation_name.is_empty():
		return 0.0
	_apply_facing(facing)
	var clip := _animation_player.get_animation(animation_name)
	if clip == null:
		return 0.0
	clip.loop_mode = Animation.LOOP_NONE
	_attack_animation = animation_name
	_attack_animation_active = true
	_active_animation = animation_name
	_animation_player.play(animation_name, 0.04)
	return clip.length


func is_attack_animation_active() -> bool:
	return _attack_animation_active


func _apply_facing(facing: Vector3) -> void:
	var flat_facing := Vector3(facing.x, 0.0, facing.z).normalized()
	look_at(global_position + flat_facing, Vector3.UP)
	rotation.y += deg_to_rad(face_offset_degrees)


func _on_animation_finished(animation_name: StringName) -> void:
	if not _attack_animation_active or animation_name != _attack_animation:
		return
	_attack_animation_active = false
	_attack_animation = StringName()
	attack_finished.emit()


func _resolve_animation(requested: StringName) -> StringName:
	if _animation_player == null:
		return StringName()
	if _animation_player.has_animation(requested):
		return requested
	var expected := String(requested).to_lower()
	for candidate in _animation_player.get_animation_list():
		var normalized := String(candidate).to_lower()
		if normalized == expected or normalized.begins_with(expected + "."):
			return candidate
	return StringName()
