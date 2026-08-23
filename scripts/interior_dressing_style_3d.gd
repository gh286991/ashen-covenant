@tool
class_name InteriorDressingStyle3D
extends Node3D

## Gives imported interior GLBs a restrained, rough material palette while
## keeping the source assets simple and individually editable in the editor.

const SOOT_STONE: StandardMaterial3D = preload("res://materials/interior/soot_stone.tres")
const STONE_EDGE: StandardMaterial3D = preload("res://materials/interior/stone_edge.tres")
const DECAYED_WOOD: StandardMaterial3D = preload("res://materials/interior/decayed_wood.tres")
const BONE_DUST: StandardMaterial3D = preload("res://materials/interior/bone_dust.tres")
const TARNISHED_IRON: StandardMaterial3D = preload("res://materials/interior/tarnished_iron.tres")
const OLD_BLOOD: StandardMaterial3D = preload("res://materials/interior/old_blood.tres")


func _enter_tree() -> void:
	call_deferred(&"_apply_palette")


func _ready() -> void:
	call_deferred(&"_apply_palette")


func _apply_palette() -> void:
	_apply_to_tree(self)


func _apply_to_tree(node: Node) -> void:
	if node is MeshInstance3D:
		_style_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_apply_to_tree(child)


func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface_index in mesh_instance.mesh.get_surface_count():
		var source := mesh_instance.get_active_material(surface_index)
		if source == null:
			continue
		var replacement := _material_for(String(source.resource_name))
		if replacement != null:
			mesh_instance.set_surface_override_material(surface_index, replacement)


func _material_for(material_name: String) -> StandardMaterial3D:
	if material_name.contains("INT_StoneSoot"):
		return SOOT_STONE
	if material_name.contains("INT_StoneEdge"):
		return STONE_EDGE
	if material_name.contains("INT_DecayedWood"):
		return DECAYED_WOOD
	if material_name.contains("INT_BoneDust"):
		return BONE_DUST
	if material_name.contains("INT_TarnishedIron"):
		return TARNISHED_IRON
	if material_name.contains("INT_OldBlood"):
		return OLD_BLOOD
	return null
