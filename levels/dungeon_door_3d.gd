class_name DungeonDoor3D
extends Area3D

@export_group("Door Identity")
@export var door_id: StringName = &"DUNGEON_DOOR"

@export_group("Transition")
@export var target_spawn: NodePath
@export var prompt_text: String = "按 E 進入下一區"

@export_group("Editor")
@export_multiline var editor_note: String = "把 target_spawn 指向另一個 Marker3D，就能建立雙向門。"

var _nearby_player: DungeonPlayer3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is DungeonPlayer3D:
		_nearby_player = body
		var dungeon := get_tree().current_scene
		if dungeon.has_method("show_door_prompt"):
			dungeon.show_door_prompt(prompt_text, self)


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		var dungeon := get_tree().current_scene
		if dungeon.has_method("hide_door_prompt"):
			dungeon.hide_door_prompt(self)


func _unhandled_input(event: InputEvent) -> void:
	if _nearby_player == null or not event.is_action_pressed(&"interact"):
		return
	var spawn := get_node_or_null(target_spawn) as Node3D
	var dungeon := get_tree().current_scene
	if spawn != null and dungeon.has_method("transition_player"):
		dungeon.transition_player(spawn, self)
		get_viewport().set_input_as_handled()
