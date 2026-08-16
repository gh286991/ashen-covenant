@tool
class_name DungeonRenderStyle3D
extends Node

var _material_cache: Dictionary = {}


func _ready() -> void:
	call_deferred("_apply_module_materials")


func _apply_module_materials() -> void:
	var owner_node := get_parent()
	if owner_node == null:
		return
	for container_name in [&"Modules", &"ModularKitMap"]:
		var container := owner_node.get_node_or_null(NodePath(container_name))
		if container != null:
			_apply_to_tree(container)


func _apply_to_tree(node: Node) -> void:
	if node is MeshInstance3D:
		_style_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_apply_to_tree(child)


func _style_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface_index in mesh_instance.mesh.get_surface_count():
		var source_material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
		if source_material == null:
			continue
		var style := _style_for_material(String(source_material.resource_name))
		if style.is_empty():
			continue
		var styled_material := _get_or_create_material(source_material, style)
		mesh_instance.set_surface_override_material(surface_index, styled_material)


func _style_for_material(material_name: String) -> Dictionary:
	if material_name.contains("Slate_Dark"):
		return {"key": "slate_dark", "color": Color(0.13, 0.17, 0.24, 1), "roughness": 0.86, "metallic": 0.02}
	if material_name.contains("Slate_Mid"):
		return {"key": "slate_mid", "color": Color(0.2, 0.25, 0.33, 1), "roughness": 0.82, "metallic": 0.02}
	if material_name.contains("Slate_Light"):
		return {"key": "slate_light", "color": Color(0.31, 0.36, 0.45, 1), "roughness": 0.78, "metallic": 0.03}
	if material_name.contains("WarmStone"):
		return {"key": "warm_stone", "color": Color(0.33, 0.26, 0.24, 1), "roughness": 0.88, "metallic": 0.01}
	if material_name.contains("CrimsonPath"):
		return {"key": "crimson_path", "color": Color(0.28, 0.045, 0.065, 1), "roughness": 0.74, "metallic": 0.04}
	if material_name.contains("CapStone"):
		return {"key": "cap_stone", "color": Color(0.29, 0.35, 0.44, 1), "roughness": 0.76, "metallic": 0.04}
	return {}


func _get_or_create_material(source: BaseMaterial3D, style: Dictionary) -> BaseMaterial3D:
	var cache_key: String = style["key"]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as BaseMaterial3D
	var styled_material := source.duplicate() as BaseMaterial3D
	styled_material.albedo_color = style["color"]
	styled_material.roughness = style["roughness"]
	styled_material.metallic = style["metallic"]
	_material_cache[cache_key] = styled_material
	return styled_material
