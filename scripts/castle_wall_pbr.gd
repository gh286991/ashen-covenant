@tool
class_name CastleWallPbr
extends DungeonKitPiece3D

## Applies the shared Poly Haven castle-wall PBR to a modular wall wrapper.
## The wrapper keeps the original GLB and collision layout intact, while
## allowing the visible map to switch material sets without touching legacy
## wall scenes.

@export_group("Castle Wall PBR")
@export var wall_material: BaseMaterial3D
@export var preserved_mesh_names: Array[StringName] = []
@export var hidden_mesh_names: Array[StringName] = []


func _ready() -> void:
	_apply_wall_material()


func _apply_wall_material() -> void:
	if wall_material == null:
		return
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null:
			continue
		if hidden_mesh_names.has(StringName(mesh_instance.name)):
			mesh_instance.visible = false
			continue
		if preserved_mesh_names.has(StringName(mesh_instance.name)):
			continue
		mesh_instance.material_override = wall_material
