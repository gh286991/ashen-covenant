class_name DungeonWarrior3D
extends Node3D

signal attack_finished

## Drives the project's animated warrior GLB in the 3D scene.
## Supports both legacy single-attack calls and full multi-step action combo animation.

@export var face_offset_degrees: float = 180.0

var _animation_player: AnimationPlayer
var _active_animation := StringName()
var _attack_animation := StringName()
var _attack_animation_active := false
var _action_locked := false
var _weapon_visuals: Array[Node3D] = []


func _ready() -> void:
	_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_collect_weapon_visuals()
	_set_weapon_drawn(false)
	if _animation_player == null:
		push_warning("Dungeon warrior model has no AnimationPlayer")
		return
	_animation_player.animation_finished.connect(_on_animation_finished)
	_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	for looping_animation in [&"Idle", &"Walk", &"Run"]:
		var resolved := _resolve_animation(looping_animation)
		if not resolved.is_empty():
			var clip := _animation_player.get_animation(resolved)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
	for attack_animation in [&"Sword_Attack", &"Attack_1_Horizontal", &"Attack_2_Return", &"Attack_3_Overhead"]:
		var resolved := _resolve_animation(attack_animation)
		if not resolved.is_empty():
			var clip := _animation_player.get_animation(resolved)
			if clip:
				clip.loop_mode = Animation.LOOP_NONE
	play_locomotion(&"Idle", Vector3.FORWARD)

func play_locomotion(state: StringName, facing: Vector3, speed_scale: float = 1.0) -> void:
	if _action_locked or _animation_player == null:
		return
	_set_weapon_drawn(false)
	_apply_facing(facing)
	var animation_name := _resolve_animation(state)
	if animation_name.is_empty():
		return
	if animation_name != _active_animation:
		_animation_player.play(animation_name, 0.08, speed_scale)
		_active_animation = animation_name
	else:
		_animation_player.speed_scale = speed_scale


func set_animation_state(state: StringName, facing: Vector3) -> void:
	if _attack_animation_active or _action_locked:
		return
	play_locomotion(state, facing, 1.18 if state == &"Run" else 1.0)


func play_attack(facing: Vector3) -> float:
	return _play_attack_clip(&"Sword_Attack", facing, 2.2)


func play_combo_attack(combo_step: int, facing: Vector3, speed_scale: float = 1.0) -> float:
	var clips: Array[StringName] = [&"Attack_1_Horizontal", &"Attack_2_Return", &"Attack_3_Overhead"]
	var index := clampi(combo_step - 1, 0, clips.size() - 1)
	return _play_attack_clip(clips[index], facing, speed_scale)


func play_heavy_attack(facing: Vector3, speed_scale: float = 0.9) -> float:
	return _play_attack_clip(&"Attack_3_Overhead", facing, speed_scale)


func _play_attack_clip(requested: StringName, facing: Vector3, speed_scale: float) -> float:
	if _animation_player == null:
		return 0.0
	_apply_facing(facing)
	var animation_name := _resolve_animation(requested)
	if animation_name.is_empty():
		animation_name = _resolve_animation(&"Sword_Attack")
	if animation_name.is_empty():
		return 0.0
	_action_locked = true
	_attack_animation_active = true
	_set_weapon_drawn(true)
	_attack_animation = animation_name
	_active_animation = animation_name
	_animation_player.stop()
	_animation_player.play(animation_name, 0.025, speed_scale)
	var clip := _animation_player.get_animation(animation_name)
	return (clip.length / speed_scale) if clip != null else 0.4


func cancel_action(facing: Vector3, locomotion: StringName = &"Idle", speed_scale: float = 1.0) -> void:
	_action_locked = false
	_attack_animation_active = false
	_attack_animation = StringName()
	_active_animation = StringName()
	_set_weapon_drawn(false)
	play_locomotion(locomotion, facing, speed_scale)


func is_attack_animation_active() -> bool:
	return _attack_animation_active or _action_locked


func is_weapon_drawn() -> bool:
	if _weapon_visuals.is_empty():
		return true
	for weapon_visual in _weapon_visuals:
		if not weapon_visual.visible:
			return false
	return true


func get_weapon_visual_count() -> int:
	return _weapon_visuals.size()


func _collect_weapon_visuals() -> void:
	_weapon_visuals.clear()
	for candidate in find_children("*", "Node3D", true, false):
		var visual_node := candidate as Node3D
		if visual_node == null:
			continue
		var normalized_name := String(visual_node.name).to_lower().replace("_", "").replace("-", "")
		if not normalized_name.contains("sword"):
			continue
		var parent_visual := visual_node.get_parent() as Node3D
		if parent_visual != null:
			var parent_name := String(parent_visual.name).to_lower().replace("_", "").replace("-", "")
			if parent_name.contains("sword"):
				continue
		_weapon_visuals.append(visual_node)


func _set_weapon_drawn(drawn: bool) -> void:
	for weapon_visual in _weapon_visuals:
		weapon_visual.visible = drawn


func _apply_facing(facing: Vector3) -> void:
	var flat_facing := Vector3(facing.x, 0.0, facing.z)
	if flat_facing.length_squared() <= 0.001:
		return
	look_at(global_position + flat_facing.normalized(), Vector3.UP)
	rotation.y += deg_to_rad(face_offset_degrees)


func _on_animation_finished(animation_name: StringName) -> void:
	if not _attack_animation_active and not _action_locked:
		return
	_attack_animation_active = false
	_action_locked = false
	_attack_animation = StringName()
	_set_weapon_drawn(false)
	attack_finished.emit()


func _resolve_animation(requested: StringName) -> StringName:
	if _animation_player == null:
		return StringName()
	if _animation_player.has_animation(requested):
		return requested
	var expected := String(requested).to_lower()
	for candidate in _animation_player.get_animation_list():
		var normalized := String(candidate).to_lower()
		if normalized == expected or normalized.begins_with(expected + ".") or normalized.begins_with(expected + "_") or normalized.ends_with("/" + expected):
			return candidate
	return StringName()
