extends SceneTree

const EXPECTED_PIECES := 84
const PLAYER_START := Vector3(-7.892, 0.0, 0.0)
const COMBAT_STARTS := [
	Vector3(-9.5, 0.0, 2.4), Vector3(-4.3, 0.0, -2.4),
	Vector3(10.146, 0.0, -3.0), Vector3(15.746, 0.0, 2.8),
	Vector3(29.692, 0.0, -2.0), Vector3(35.292, 0.0, 2.7),
]


func _init() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var packed := load("res://levels/dungeon_3d.tscn") as PackedScene
	if packed == null:
		_fail("scene_missing")
		return
	var dungeon := packed.instantiate()
	root.add_child(dungeon)
	await process_frame
	await process_frame

	var dressing := dungeon.get_node_or_null("GridMapDungeon/InteriorDressing") as Node3D
	if dressing == null:
		_fail("interior_dressing_missing")
		return
	if dressing.get_child_count() != EXPECTED_PIECES:
		_fail("piece_count=%d expected=%d" % [dressing.get_child_count(), EXPECTED_PIECES])
		return

	var visual_nodes := dressing.find_children("*", "MeshInstance3D", true, false)
	if visual_nodes.size() < EXPECTED_PIECES:
		_fail("visual_count=%d expected_at_least=%d" % [visual_nodes.size(), EXPECTED_PIECES])
		return
	var collisions := dressing.find_children("*", "CollisionObject3D", true, false)
	if not collisions.is_empty():
		_fail("collision_nodes=%d" % collisions.size())
		return
	for forbidden_type in ["NavigationRegion3D", "NavigationObstacle3D", "NavigationLink3D", "Area3D", "Marker3D", "Light3D"]:
		var forbidden := dressing.find_children("*", forbidden_type, true, false)
		if not forbidden.is_empty():
			_fail("forbidden_%s=%d" % [forbidden_type, forbidden.size()])
			return

	var interior_materials: Dictionary[String, bool] = {}
	for visual_node in visual_nodes:
		var mesh := visual_node as MeshInstance3D
		if mesh.mesh == null:
			_fail("mesh_missing=%s" % mesh.get_path())
			return
		for surface_index in mesh.mesh.get_surface_count():
			var active := mesh.get_active_material(surface_index)
			if active != null and active.resource_path.begins_with("res://materials/interior/"):
				interior_materials[active.resource_path] = true
	if interior_materials.size() != 6:
		_fail("interior_material_count=%d expected=6" % interior_materials.size())
		return

	for child in dressing.get_children():
		var prop := child as Node3D
		if prop == null:
			_fail("non_spatial_direct_child=%s" % child.name)
			return
		var position := prop.global_position
		if _horizontal_distance(position, PLAYER_START) < 0.9:
			_fail("player_start_too_close=%s pos=%s" % [prop.name, position])
			return
		for combat_start in COMBAT_STARTS:
			if _horizontal_distance(position, combat_start) < 0.82:
				_fail("combat_start_too_close=%s pos=%s" % [prop.name, position])
				return
		if prop.name.contains("Stain") or prop.name.contains("Dust") or prop.name.contains("Trace"):
			if position.y > 0.03:
				_fail("ground_decal_too_high=%s y=%f" % [prop.name, position.y])
				return

	# The two 3.946 m corridors need a readable central strip.  Only flat dust
	# marks may sit close to the centreline; all chunky dressing stays by a wall.
	for corridor_name in ["INT_AB", "INT_BC"]:
		for child in dressing.get_children():
			if not child.name.begins_with(corridor_name):
				continue
			var prop := child as Node3D
			if not (prop.name.contains("Dust") or prop.name.contains("Trace")) and absf(prop.global_position.z) < 0.9:
				_fail("corridor_lane_blocked=%s z=%f" % [prop.name, prop.global_position.z])
				return

	print("DUNGEON_INTERIOR_DRESSING_VALIDATE_OK pieces=%d visuals=%d materials=%d collisions=0 route_clear=true" % [dressing.get_child_count(), visual_nodes.size(), interior_materials.size()])
	quit(0)


func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _fail(reason: String) -> void:
	push_error("DUNGEON_INTERIOR_DRESSING_VALIDATE_FAIL %s" % reason)
	quit(1)
