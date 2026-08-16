extends Node2D

const FOREGROUND_PREFIX := "Foreground_"

func _process(_delta: float) -> void:
	var player := get_node_or_null("../Actors/Player") as Node2D
	if player == null:
		return
	var visual_sprite := player.get("occlusion_sprite") as Sprite2D
	var visual_texture := visual_sprite.texture if visual_sprite != null else null
	var visual_ready := visual_sprite != null and visual_texture != null
	var inverse_transform := visual_sprite.get_global_transform().affine_inverse() if visual_ready else Transform2D.IDENTITY
	var texture_size := visual_texture.get_size() if visual_ready else Vector2.ONE
	var region_rect := visual_sprite.region_rect if visual_ready and visual_sprite.region_enabled else Rect2(Vector2.ZERO, texture_size)
	if region_rect.size.x <= 0.0 or region_rect.size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		visual_ready = false
	for child in get_children():
		if not child is TileMapLayer or not child.name.begins_with(FOREGROUND_PREFIX):
			continue
		var shader_material := (child as TileMapLayer).material as ShaderMaterial
		if shader_material != null:
			shader_material.set_shader_parameter("player_visual_texture", visual_texture)
			shader_material.set_shader_parameter("player_visual_ready", 1.0 if visual_ready else 0.0)
			shader_material.set_shader_parameter("player_world_to_local_x", Vector2(inverse_transform.x.x, inverse_transform.y.x))
			shader_material.set_shader_parameter("player_world_to_local_y", Vector2(inverse_transform.x.y, inverse_transform.y.y))
			shader_material.set_shader_parameter("player_world_to_local_origin", inverse_transform.origin)
			shader_material.set_shader_parameter("player_visual_texture_size", texture_size)
			shader_material.set_shader_parameter("player_visual_region_origin", region_rect.position)
			shader_material.set_shader_parameter("player_visual_region_size", region_rect.size)
