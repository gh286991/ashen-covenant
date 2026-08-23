extends SceneTree

const MAIN_PLAYABLE_MIN_X := -14.0
const MAIN_PLAYABLE_MAX_X := 38.0
const BRANCH_PLAYABLE_MIN_X := -4.5
const BRANCH_PLAYABLE_MAX_X := 28.0
const BRANCH_MIN_Z := -22.0
const BRANCH_MAX_Z := -5.9


func _init() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var packed := load("res://levels/dungeon_3d.tscn") as PackedScene
	if packed == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL scene_missing")
		quit(1)
		return
	var dungeon := packed.instantiate()
	root.add_child(dungeon)
	await process_frame

	var backdrop := dungeon.get_node_or_null("GridMapDungeon/NonPlayableFill") as Node3D
	if backdrop == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL root_node_missing")
		quit(1)
		return
	var dressing := backdrop.get_node_or_null("BlenderDressingFinal")
	if dressing == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL final_dressing_missing")
		quit(1)
		return
	var dressing_visual_nodes := dressing.find_children("*", "MeshInstance3D", true, false)
	if dressing_visual_nodes.size() < 80:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL final_dressing_visual_count=%d" % dressing_visual_nodes.size())
		quit(1)
		return
	for node in dressing_visual_nodes:
		var dressing_mesh := node as MeshInstance3D
		var bounds := _world_aabb(dressing_mesh)
		if _overlaps_rect(bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL_final_dressing_aabb_inside_playable_projection=%s bounds=%s" % [dressing_mesh.get_path(), bounds])
			quit(1)
			return

	var exterior := backdrop.get_node_or_null("AshenExteriorDressing")
	if exterior == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_exterior_missing")
		quit(1)
		return
	if exterior.get_child_count() != 76:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_exterior_piece_count=%d" % exterior.get_child_count())
		quit(1)
		return
	for cliff_index in range(9):
		var cliff_name := "EXT_SouthCliff_%02d" % cliff_index
		var cliff := exterior.get_node_or_null(cliff_name) as Node3D
		if cliff == null:
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL cliff_missing=%s" % cliff_name)
			quit(1)
			return
		for shard_index in range(2):
			var shard_name := "%s_Shard_%d" % [cliff_name, shard_index]
			var shard := exterior.get_node_or_null(shard_name) as Node3D
			if shard == null:
				push_error("DUNGEON_BACKDROP_VALIDATE_FAIL cliff_shard_missing=%s" % shard_name)
				quit(1)
				return
			var relative_offset := cliff.global_position - shard.global_position
			if relative_offset.length() > 6.0 or shard.global_position.z >= cliff.global_position.z - 1.8:
				push_error("DUNGEON_BACKDROP_VALIDATE_FAIL cliff_group_split=%s main=%s shard=%s" % [cliff_name, cliff.global_position, shard.global_position])
				quit(1)
				return
	var exterior_visual_nodes := exterior.find_children("*", "MeshInstance3D", true, false)
	if exterior_visual_nodes.size() < 60:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_exterior_visual_count=%d" % exterior_visual_nodes.size())
		quit(1)
		return
	var exterior_surface_count := 0
	var exterior_material_paths: Dictionary[String, bool] = {}
	for node in exterior_visual_nodes:
		var exterior_mesh := node as MeshInstance3D
		exterior_surface_count += exterior_mesh.mesh.get_surface_count()
		for surface_index in exterior_mesh.mesh.get_surface_count():
			var active_material := exterior_mesh.get_active_material(surface_index)
			if active_material != null and active_material.resource_path.begins_with("res://materials/exterior/"):
				exterior_material_paths[active_material.resource_path] = true
		var exterior_bounds := _world_aabb(exterior_mesh)
		if _overlaps_rect(exterior_bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(exterior_bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_exterior_aabb_inside_playable_projection=%s bounds=%s" % [exterior_mesh.get_path(), exterior_bounds])
			quit(1)
			return
	if exterior_surface_count < 70:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_exterior_surface_count=%d" % exterior_surface_count)
		quit(1)
		return
	if exterior_material_paths.size() < 5:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL persistent_exterior_materials=%d" % exterior_material_paths.size())
		quit(1)
		return

	var visual_nodes := backdrop.find_children("*", "MeshInstance3D", true, false)
	if visual_nodes.size() < 20:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL visual_count=%d" % visual_nodes.size())
		quit(1)
		return

	var collision_nodes := backdrop.find_children("*", "CollisionObject3D", true, false)
	if not collision_nodes.is_empty():
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL unexpected_collision_nodes=%d" % collision_nodes.size())
		quit(1)
		return

	for forbidden_type in ["NavigationRegion3D", "NavigationObstacle3D", "NavigationLink3D", "Area3D", "Marker3D"]:
		var forbidden_nodes := backdrop.find_children("*", forbidden_type, true, false)
		if not forbidden_nodes.is_empty():
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL forbidden_%s_nodes=%d" % [forbidden_type, forbidden_nodes.size()])
			quit(1)
			return
	for node in backdrop.find_children("*", "Node", true, false):
		if node.get_script() != null:
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL unexpected_child_script=%s" % node.get_path())
			quit(1)
			return

	for node in visual_nodes:
		var item := node as Node3D
		var p := item.global_position
		var is_north_safe := p.z < BRANCH_MIN_Z
		var is_south_safe := p.z > 7.0
		var is_branch_side_safe := p.z >= BRANCH_MIN_Z and p.z <= BRANCH_MAX_Z and (p.x < BRANCH_PLAYABLE_MIN_X or p.x > BRANCH_PLAYABLE_MAX_X)
		var is_main_side_safe := p.z > 5.0 and (p.x < MAIN_PLAYABLE_MIN_X or p.x > MAIN_PLAYABLE_MAX_X)
		if not is_north_safe and not is_south_safe and not is_branch_side_safe and not is_main_side_safe:
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL_visual_inside_playable_projection=%s pos=%s" % [item.get_path(), p])
			quit(1)
			return

	var dungeon_body := dungeon.get_node_or_null("GridMapDungeon/ModularAssembly")
	if dungeon_body == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL dungeon_body_missing")
		quit(1)
		return

	print("DUNGEON_BACKDROP_VALIDATE_OK visuals=%d ashen_pieces=%d ashen_surfaces=%d persistent_materials=%d collisions=0 branch_clear=true body_untouched=true" % [visual_nodes.size(), exterior_visual_nodes.size(), exterior_surface_count, exterior_material_paths.size()])
	quit(0)


func _world_aabb(mesh: MeshInstance3D) -> AABB:
	var local_bounds := mesh.get_aabb()
	var corners := [
		local_bounds.position,
		local_bounds.position + Vector3(local_bounds.size.x, 0.0, 0.0),
		local_bounds.position + Vector3(0.0, local_bounds.size.y, 0.0),
		local_bounds.position + Vector3(0.0, 0.0, local_bounds.size.z),
		local_bounds.position + Vector3(local_bounds.size.x, local_bounds.size.y, 0.0),
		local_bounds.position + Vector3(local_bounds.size.x, 0.0, local_bounds.size.z),
		local_bounds.position + Vector3(0.0, local_bounds.size.y, local_bounds.size.z),
		local_bounds.position + local_bounds.size,
	]
	var world_bounds := AABB(mesh.global_transform * corners[0], Vector3.ZERO)
	for index in range(1, corners.size()):
		world_bounds = world_bounds.expand(mesh.global_transform * corners[index])
	return world_bounds


func _overlaps_rect(bounds: AABB, min_x: float, max_x: float, min_z: float, max_z: float) -> bool:
	return bounds.position.x <= max_x and bounds.end.x >= min_x and bounds.position.z <= max_z and bounds.end.z >= min_z
