@tool
class_name DungeonModule3D
extends Node3D

@export_group("Module Identity")
@export var module_id: StringName = &"DUNGEON_MODULE"

@export_group("Layout")
@export var footprint: Vector3 = Vector3(12.0, 4.8, 12.0)
@export var door_width: float = 3.6

@export_group("Top-down Preview")
@export var topdown_cutaway: bool = true
@export_enum("FrontWall", "BackWall", "Both") var topdown_cutaway_side: String = "FrontWall"

@export_group("Editor")
@export_multiline var editor_note: String = "Move or duplicate this scene instance in the dungeon scene."


func _ready() -> void:
	if topdown_cutaway:
		# Keep the editor preview readable as well as the game view. The
		# collision nodes remain untouched, so the module is still playable.
		call_deferred("_apply_topdown_cutaway")
	if not Engine.is_editor_hint():
		add_to_group("dungeon_modules")


func _apply_topdown_cutaway() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var should_hide := topdown_cutaway_side == "Both" or String(node.name).contains(topdown_cutaway_side)
		if should_hide:
			var mesh := node as GeometryInstance3D
			if mesh != null:
				# Keep collision active while opening the camera-facing side for play.
				mesh.visible = false
