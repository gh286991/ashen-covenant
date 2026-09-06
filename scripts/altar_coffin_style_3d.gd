@tool
class_name AltarCoffinStyle3D
extends Node3D

func _ready() -> void:
	_apply_materials()

func _apply_materials() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := node as MeshInstance3D
		if mesh_inst == null or mesh_inst.mesh == null:
			continue
		
		# 0: MAT_Stone_BlueGray
		var mat0 = StandardMaterial3D.new()
		mat0.resource_name = "MAT_Stone_BlueGray_Styled"
		mat0.albedo_color = Color(0.18, 0.20, 0.24, 1.0)
		mat0.roughness = 0.82
		mesh_inst.set_surface_override_material(0, mat0)
		
		# 1: MAT_Stone_Weathered
		var mat1 = StandardMaterial3D.new()
		mat1.resource_name = "MAT_Stone_Weathered_Styled"
		mat1.albedo_color = Color(0.12, 0.13, 0.15, 1.0)
		mat1.roughness = 0.90
		mesh_inst.set_surface_override_material(1, mat1)
		
		# 2: MAT_Dark_Wood
		var mat2 = StandardMaterial3D.new()
		mat2.resource_name = "MAT_Dark_Wood_Styled"
		mat2.albedo_color = Color(0.14, 0.10, 0.07, 1.0)
		mat2.roughness = 0.85
		mesh_inst.set_surface_override_material(2, mat2)
		
		# 3: MAT_Aged_Brass
		var mat3 = StandardMaterial3D.new()
		mat3.resource_name = "MAT_Aged_Brass_Styled"
		mat3.albedo_color = Color(0.55, 0.42, 0.18, 1.0)
		mat3.metallic = 0.85
		mat3.roughness = 0.45
		mesh_inst.set_surface_override_material(3, mat3)
		
		# 4: MAT_Bone
		var mat4 = StandardMaterial3D.new()
		mat4.resource_name = "MAT_Bone_Styled"
		mat4.albedo_color = Color(0.72, 0.68, 0.60, 1.0)
		mat4.roughness = 0.75
		mesh_inst.set_surface_override_material(4, mat4)
