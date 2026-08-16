@tool
class_name DungeonKitPiece3D
extends Node3D

## Editor-facing metadata for a reusable Blender-exported dungeon piece.
## This script does not create geometry at runtime: the GLB is a child scene
## and every piece is placed explicitly in dungeon_3d.tscn.

@export_group("Kit Identity")
@export var piece_id: StringName = &"DUNGEON_KIT_PIECE"
@export_enum("Floor", "Straight Wall", "Corner Wall", "Doorway", "Prop") var piece_role: String = "Prop"

@export_group("Placement")
@export var footprint: Vector3 = Vector3.ONE
@export_multiline var editor_note: String = "Duplicate and position this piece in the map scene."
