@tool
class_name ExteriorDressingStyle3D
extends Node3D

## Applies a restrained shared palette to imported non-playable backdrop GLBs.
## Blender materials keep semantic names, while Godot owns the final exposure-
## safe look for the Compatibility renderer.

var _material_cache: Dictionary[StringName, StandardMaterial3D] = {}

const ASHEN_CHARCOAL_STONE: StandardMaterial3D = preload("res://materials/exterior/ashen_charcoal_stone.tres")
const ASHEN_COLD_EDGE: StandardMaterial3D = preload("res://materials/exterior/ashen_cold_edge.tres")
const ASHEN_ROCK: StandardMaterial3D = preload("res://materials/exterior/ashen_rock.tres")
const ASHEN_DEAD_BARK: StandardMaterial3D = preload("res://materials/exterior/ashen_dead_bark.tres")
const ASHEN_SOUL_RUNE: StandardMaterial3D = preload("res://materials/exterior/ashen_soul_rune.tres")


func _enter_tree() -> void:
	# @tool scenes can be instantiated inside another edited scene before
	# _ready() is called.  Applying once on enter and once deferred keeps the
	# material preview visible in both dungeon_grid_map and dungeon_3d tabs.
	call_deferred(&"_apply_exterior_palette")


func _ready() -> void:
	call_deferred(&"_apply_exterior_palette")


func _apply_exterior_palette() -> void:
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
		var source_material := mesh_instance.get_active_material(surface_index)
		if source_material == null:
			continue
		var style_key := _style_key(String(source_material.resource_name))
		if style_key.is_empty():
			continue
		mesh_instance.set_surface_override_material(surface_index, _shared_material(style_key))


func _style_key(material_name: String) -> StringName:
	if material_name.contains("DarkSlate") or material_name.contains("Slate_Dark") or material_name.contains("StoneCharcoal") or material_name.contains("Stone_Charcoal"):
		return &"charcoal_stone"
	if material_name.contains("Slate_Mid") or material_name.contains("CapStone") or material_name.contains("StoneColdEdge") or material_name.contains("Stone_BlueGray") or material_name.contains("Stone_Weathered"):
		return &"cold_edge"
	if material_name.contains("Slate_Light"):
		return &"pale_edge"
	if material_name.contains("WarmStone"):
		return &"warm_stone"
	if material_name.contains("Stone_Moss"):
		return &"moss_stone"
	if material_name.contains("AshRock"):
		return &"ash_rock"
	if material_name.contains("DeadBark") or material_name.contains("Dark_Wood"):
		return &"dead_bark"
	if material_name.contains("BoneDust") or material_name.contains("MAT_Bone"):
		return &"bone_dust"
	if material_name.contains("TarnishedIron") or material_name.contains("Iron_Black"):
		return &"dark_iron"
	if material_name.contains("Aged_Brass"):
		return &"aged_brass"
	if material_name.contains("MAT_Void"):
		return &"void"
	if material_name.contains("MAT_Ember"):
		return &"blue_ember"
	if material_name.contains("VioletSeal"):
		return &"violet_seal"
	if material_name.contains("SoulRune"):
		return &"soul_rune"
	return &""


func _shared_material(style_key: StringName) -> StandardMaterial3D:
	match style_key:
		&"charcoal_stone":
			return ASHEN_CHARCOAL_STONE
		&"cold_edge":
			return ASHEN_COLD_EDGE
		&"ash_rock":
			return ASHEN_ROCK
		&"dead_bark":
			return ASHEN_DEAD_BARK
		&"soul_rune":
			return ASHEN_SOUL_RUNE
	if _material_cache.has(style_key):
		return _material_cache[style_key]
	var result := StandardMaterial3D.new()
	result.resource_name = "Exterior_%s" % style_key
	result.metallic = 0.0
	result.roughness = 0.9
	match style_key:
		&"charcoal_stone":
			result.albedo_color = Color(0.075, 0.095, 0.14, 1.0)
		&"cold_edge":
			result.albedo_color = Color(0.13, 0.17, 0.24, 1.0)
			result.roughness = 0.84
		&"pale_edge":
			result.albedo_color = Color(0.19, 0.23, 0.31, 1.0)
			result.roughness = 0.82
		&"warm_stone":
			result.albedo_color = Color(0.19, 0.13, 0.12, 1.0)
		&"moss_stone":
			result.albedo_color = Color(0.075, 0.12, 0.105, 1.0)
		&"ash_rock":
			result.albedo_color = Color(0.055, 0.062, 0.085, 1.0)
		&"dead_bark":
			result.albedo_color = Color(0.075, 0.04, 0.032, 1.0)
		&"bone_dust":
			result.albedo_color = Color(0.28, 0.3, 0.32, 1.0)
		&"dark_iron":
			result.albedo_color = Color(0.028, 0.035, 0.05, 1.0)
			result.metallic = 1.0
			result.roughness = 0.78
		&"aged_brass":
			result.albedo_color = Color(0.24, 0.16, 0.065, 1.0)
			result.metallic = 1.0
			result.roughness = 0.7
		&"void":
			result.albedo_color = Color(0.008, 0.012, 0.025, 1.0)
			result.roughness = 1.0
		&"blue_ember":
			result.albedo_color = Color(0.02, 0.18, 0.34, 1.0)
			result.emission_enabled = true
			result.emission = Color(0.03, 0.38, 0.92, 1.0)
			result.emission_energy_multiplier = 1.8
		&"violet_seal":
			result.albedo_color = Color(0.11, 0.035, 0.18, 1.0)
			result.emission_enabled = true
			result.emission = Color(0.34, 0.08, 0.68, 1.0)
			result.emission_energy_multiplier = 1.35
		&"soul_rune":
			result.albedo_color = Color(0.02, 0.17, 0.28, 1.0)
			result.emission_enabled = true
			result.emission = Color(0.04, 0.42, 0.86, 1.0)
			result.emission_energy_multiplier = 1.55
	_material_cache[style_key] = result
	return result
