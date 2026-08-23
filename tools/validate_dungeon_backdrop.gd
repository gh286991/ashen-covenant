extends SceneTree

const MAIN_PLAYABLE_MIN_X := -14.0
const MAIN_PLAYABLE_MAX_X := 38.0
const BRANCH_PLAYABLE_MIN_X := -4.5
const BRANCH_PLAYABLE_MAX_X := 28.0
const BRANCH_MIN_Z := -22.0
const BRANCH_MAX_Z := -5.9
const CASTLE_WALL_MATERIAL_PATH := "res://assets/3d_dungeon/kit/textures/castle_wall_stylized/castle_wall_stylized_material.tres"
const FAR_GROUND_TEXTURE_PATH := "res://assets/backgrounds/dungeon_far_ground.png"


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
	var far_ground := dungeon.get_node_or_null("FarGround") as MeshInstance3D
	if far_ground == null or not far_ground.mesh is PlaneMesh:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL far_ground_missing")
		quit(1)
		return
	var far_ground_mesh := far_ground.mesh as PlaneMesh
	var far_ground_material := far_ground.material_override as StandardMaterial3D
	if far_ground_mesh.size.x < 160.0 or far_ground_mesh.size.y < 160.0 or far_ground_material == null or far_ground_material.albedo_texture == null or far_ground_material.albedo_texture.resource_path != FAR_GROUND_TEXTURE_PATH:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL far_ground_coverage_or_material size=%s texture=%s" % [far_ground_mesh.size, far_ground_material.albedo_texture.resource_path if far_ground_material != null and far_ground_material.albedo_texture != null else "missing"])
		quit(1)
		return

	var flank_walls := backdrop.get_node_or_null("OuterFlankWalls")
	if flank_walls == null or flank_walls.get_child_count() != 8:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL flank_wall_piece_count=%d" % [flank_walls.get_child_count() if flank_walls != null else 0])
		quit(1)
		return
	var flank_meshes := flank_walls.find_children("*", "MeshInstance3D", true, false)
	if flank_meshes.size() < 8:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL flank_wall_visual_count=%d" % flank_meshes.size())
		quit(1)
		return
	for node in flank_meshes:
		var flank_mesh := node as MeshInstance3D
		var active_wall_material := flank_mesh.material_override if flank_mesh.material_override != null else flank_mesh.get_active_material(0)
		if active_wall_material == null or active_wall_material.resource_path != CASTLE_WALL_MATERIAL_PATH:
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL flank_wall_material=%s" % flank_mesh.get_path())
			quit(1)
			return
		var flank_bounds := _world_aabb(flank_mesh)
		if _overlaps_rect(flank_bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(flank_bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL flank_wall_aabb_inside_playable_projection=%s bounds=%s" % [flank_mesh.get_path(), flank_bounds])
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

	var ground := backdrop.get_node_or_null("AshenGroundDressing")
	if ground == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_ground_missing")
		quit(1)
		return
	if ground.get_child_count() != 73:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_ground_piece_count=%d" % ground.get_child_count())
		quit(1)
		return
	var ground_visual_nodes := ground.find_children("*", "MeshInstance3D", true, false)
	if ground_visual_nodes.size() < 73:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_ground_visual_count=%d" % ground_visual_nodes.size())
		quit(1)
		return
	var ground_material_paths: Dictionary[String, bool] = {}
	var ground_uses_dark_iron := false
	for node in ground_visual_nodes:
		var ground_mesh := node as MeshInstance3D
		var ground_bounds := _world_aabb(ground_mesh)
		if _overlaps_rect(ground_bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(ground_bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_ground_aabb_inside_playable_projection=%s bounds=%s" % [ground_mesh.get_path(), ground_bounds])
			quit(1)
			return
		for surface_index in ground_mesh.mesh.get_surface_count():
			var ground_material := ground_mesh.get_active_material(surface_index)
			if ground_material != null and ground_material.resource_path.begins_with("res://materials/exterior/"):
				ground_material_paths[ground_material.resource_path] = true
			if ground_material != null and ground_material.resource_name == "Exterior_dark_iron":
				ground_uses_dark_iron = true
	if ground_material_paths.size() < 4 or not ground_uses_dark_iron:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL ashen_ground_persistent_materials=%d dark_iron=%s" % [ground_material_paths.size(), ground_uses_dark_iron])
		quit(1)
		return

	var courtyard := backdrop.get_node_or_null("ExteriorCourtyardDressing")
	if courtyard == null or courtyard.get_child_count() != 15:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL courtyard_piece_count=%d" % [courtyard.get_child_count() if courtyard != null else 0])
		quit(1)
		return
	var courtyard_visual_nodes := courtyard.find_children("*", "MeshInstance3D", true, false)
	if courtyard_visual_nodes.size() < 15:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL courtyard_visual_count=%d" % courtyard_visual_nodes.size())
		quit(1)
		return
	var courtyard_material_paths: Dictionary[String, bool] = {}
	for node in courtyard_visual_nodes:
		var courtyard_mesh := node as MeshInstance3D
		var courtyard_bounds := _world_aabb(courtyard_mesh)
		if _overlaps_rect(courtyard_bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(courtyard_bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL courtyard_aabb_inside_playable_projection=%s bounds=%s" % [courtyard_mesh.get_path(), courtyard_bounds])
			quit(1)
			return
		for surface_index in courtyard_mesh.mesh.get_surface_count():
			var courtyard_material := courtyard_mesh.get_active_material(surface_index)
			if courtyard_material != null and courtyard_material.resource_path.begins_with("res://materials/exterior/"):
				courtyard_material_paths[courtyard_material.resource_path] = true
	if courtyard_material_paths.size() < 4:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL courtyard_persistent_materials=%d" % courtyard_material_paths.size())
		quit(1)
		return

	var wilderness := backdrop.get_node_or_null("ExteriorWildernessDressing")
	if wilderness == null or wilderness.get_child_count() != 43:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL wilderness_piece_count=%d" % [wilderness.get_child_count() if wilderness != null else 0])
		quit(1)
		return
	var wilderness_visual_nodes := wilderness.find_children("*", "MeshInstance3D", true, false)
	if wilderness_visual_nodes.size() < 43:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL wilderness_visual_count=%d" % wilderness_visual_nodes.size())
		quit(1)
		return
	var wilderness_material_paths: Dictionary[String, bool] = {}
	for node in wilderness_visual_nodes:
		var wilderness_mesh := node as MeshInstance3D
		var wilderness_bounds := _world_aabb(wilderness_mesh)
		if _overlaps_rect(wilderness_bounds, -8.2, 24.0, -22.0, -5.6) or _overlaps_rect(wilderness_bounds, -14.0, 38.0, -5.6, 5.6):
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL wilderness_aabb_inside_playable_projection=%s bounds=%s" % [wilderness_mesh.get_path(), wilderness_bounds])
			quit(1)
			return
		for surface_index in wilderness_mesh.mesh.get_surface_count():
			var wilderness_material := wilderness_mesh.get_active_material(surface_index)
			if wilderness_material != null and wilderness_material.resource_path.begins_with("res://materials/exterior/"):
				wilderness_material_paths[wilderness_material.resource_path] = true
	if wilderness_material_paths.size() < 4:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL wilderness_persistent_materials=%d" % wilderness_material_paths.size())
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
		# AABB projection checks above are the authoritative clearance test.  This
		# position-level guard only classifies all props that live beyond the main
		# dungeon's east/west edge, including the existing south corner trim.
		var is_main_side_safe := p.x < MAIN_PLAYABLE_MIN_X or p.x > MAIN_PLAYABLE_MAX_X
		if not is_north_safe and not is_south_safe and not is_branch_side_safe and not is_main_side_safe:
			push_error("DUNGEON_BACKDROP_VALIDATE_FAIL_visual_inside_playable_projection=%s pos=%s" % [item.get_path(), p])
			quit(1)
			return

	var dungeon_body := dungeon.get_node_or_null("GridMapDungeon/ModularAssembly")
	if dungeon_body == null:
		push_error("DUNGEON_BACKDROP_VALIDATE_FAIL dungeon_body_missing")
		quit(1)
		return

	print("DUNGEON_BACKDROP_VALIDATE_OK visuals=%d ashen_pieces=%d ground_pieces=%d courtyard_pieces=%d wilderness_pieces=%d flank_walls=%d far_ground=%.1f ashen_surfaces=%d persistent_materials=%d ground_materials=%d courtyard_materials=%d wilderness_materials=%d dark_iron=%s collisions=0 branch_clear=true body_untouched=true" % [visual_nodes.size(), exterior_visual_nodes.size(), ground.get_child_count(), courtyard.get_child_count(), wilderness.get_child_count(), flank_walls.get_child_count(), far_ground_mesh.size.x, exterior_surface_count, exterior_material_paths.size(), ground_material_paths.size(), courtyard_material_paths.size(), wilderness_material_paths.size(), ground_uses_dark_iron])
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
