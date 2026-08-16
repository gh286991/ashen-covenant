extends SceneTree

const GRID_SCENE := "res://levels/dungeon_grid_map.tscn"
const MIN_CUTE_FLOOR_EXTENT := 3.5
const USER_WALL_ID := 11
const TRIPO_FLOOR_ID := 12
const GRID_SIZE := 3.946
const EXPECTED_FLOOR_CELLS := 33
const EXPECTED_STRUCTURE_CELLS := 20
const EXPECTED_BOUNDARY_CELLS := 14


func _init() -> void:
	var failures: Array[String] = []
	var packed_grid := load(GRID_SCENE) as PackedScene
	if packed_grid == null:
		failures.append("could not load GridMap scene")
	else:
		var grid_root := packed_grid.instantiate()
		_check_grid(grid_root, "FloorGridMap", failures)
		_check_grid(grid_root, "StructureGridMap", failures)
		_check_grid(grid_root, "BoundaryGridMap", failures)
		_check_grid(grid_root, "PropGridMap", failures)
		var floor_grid := grid_root.get_node_or_null("FloorGridMap") as GridMap
		if floor_grid != null and floor_grid.mesh_library != null:
			if floor_grid.get_used_cells().size() != EXPECTED_FLOOR_CELLS:
				failures.append("FloorGridMap cells=%d expected=%d" % [floor_grid.get_used_cells().size(), EXPECTED_FLOOR_CELLS])
			var structure_grid := grid_root.get_node_or_null("StructureGridMap") as GridMap
			if structure_grid != null and structure_grid.get_used_cells().size() != EXPECTED_STRUCTURE_CELLS:
				failures.append("StructureGridMap cells=%d expected=%d" % [structure_grid.get_used_cells().size(), EXPECTED_STRUCTURE_CELLS])
			var boundary_grid := grid_root.get_node_or_null("BoundaryGridMap") as GridMap
			if boundary_grid != null and boundary_grid.get_used_cells().size() != EXPECTED_BOUNDARY_CELLS:
				failures.append("BoundaryGridMap cells=%d expected=%d" % [boundary_grid.get_used_cells().size(), EXPECTED_BOUNDARY_CELLS])
			if structure_grid != null and boundary_grid != null:
				_check_layout(floor_grid, structure_grid, boundary_grid, failures)
			var library := floor_grid.mesh_library
			if library.get_item_list().size() != 13:
				failures.append("MeshLibrary item count is not 13")
			for item_id in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, USER_WALL_ID, TRIPO_FLOOR_ID]:
				if library.get_item_shapes(item_id).is_empty():
					failures.append("MeshLibrary item %d is missing collision" % item_id)
			var tripo_floor_mesh := library.get_item_mesh(TRIPO_FLOOR_ID)
			if tripo_floor_mesh == null:
				failures.append("Tripo floor item has no mesh")
			else:
				var tripo_floor_size := tripo_floor_mesh.get_aabb().size
				if abs(tripo_floor_size.x - GRID_SIZE) > 0.01 or abs(tripo_floor_size.z - GRID_SIZE) > 0.01 or abs(tripo_floor_size.y - 0.13) > 0.01:
					failures.append("Tripo floor item has unexpected size: %s" % tripo_floor_size)
			for item_id in [7, 8, 9, 10]:
				var floor_mesh := library.get_item_mesh(item_id)
				if floor_mesh == null:
					failures.append("Cute floor item %d has no mesh" % item_id)
					continue
				var floor_size := floor_mesh.get_aabb().size
				if floor_size.x < MIN_CUTE_FLOOR_EXTENT or floor_size.z < MIN_CUTE_FLOOR_EXTENT:
					failures.append("Cute floor item %d is only a partial tile: %s" % [item_id, floor_size])
			var user_wall_mesh := library.get_item_mesh(USER_WALL_ID)
			if user_wall_mesh == null:
				failures.append("User wall item has no mesh")
			else:
				var user_wall_size := user_wall_mesh.get_aabb().size
				if user_wall_size.x < 3.5 or user_wall_size.y < 3.9 or user_wall_size.z < 0.5:
					failures.append("User wall item has unexpected size: %s" % user_wall_size)
				for surface_index in user_wall_mesh.get_surface_count():
					var wall_material := user_wall_mesh.surface_get_material(surface_index) as BaseMaterial3D
					if wall_material == null:
						continue
					if wall_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						failures.append("User wall surface %d is still transparent" % surface_index)
				var user_wall_aabb := user_wall_mesh.get_aabb()
				var user_wall_center := user_wall_aabb.position + user_wall_aabb.size * 0.5
				if abs(user_wall_center.x) > 0.05 or abs(user_wall_center.z + GRID_SIZE * 0.5) > 0.05:
					failures.append("User wall is not on the cell boundary: center=%s" % user_wall_center)
		else:
			failures.append("FloorGridMap has no MeshLibrary")
		grid_root.queue_free()

	var packed_main := load("res://levels/dungeon_3d.tscn") as PackedScene
	if packed_main == null:
		failures.append("could not load main dungeon")
	else:
		var main_dungeon := packed_main.instantiate()
		if main_dungeon.get_node_or_null("GridMapDungeon") == null:
			failures.append("main dungeon does not instance GridMapDungeon")
		main_dungeon.free()

	if failures.is_empty():
		var verified_grid_root := (load(GRID_SCENE) as PackedScene).instantiate()
		var verified_tripo_size: Vector3 = verified_grid_root.get_node("FloorGridMap").mesh_library.get_item_mesh(TRIPO_FLOOR_ID).get_aabb().size
		verified_grid_root.free()
		print("DUNGEON_GRIDMAP_VALIDATE_OK palette=13 floor_item=12 tripo_aabb=%s canonical_layout=3rooms_2corridors" % verified_tripo_size)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_grid(root: Node, path: String, failures: Array[String]) -> void:
	var grid := root.get_node_or_null(path) as GridMap
	if grid == null:
		failures.append("missing " + path)
		return
	if grid.get_used_cells().is_empty():
		failures.append(path + " has no painted cells")


func _check_layout(floor_grid: GridMap, structure_grid: GridMap, boundary_grid: GridMap, failures: Array[String]) -> void:
	var rooms := [Vector2i(-3, -1), Vector2i(1, 3), Vector2i(5, 7)]
	for room_index in rooms.size():
		var room: Vector2i = rooms[room_index]
		for x in range(room.x, room.y + 1):
			for z in range(-1, 2):
				_expect_item(floor_grid, Vector3i(x, 0, z), TRIPO_FLOOR_ID, failures)
			_expect_wall(structure_grid, Vector3i(x, 0, -1), 0, failures)
			_expect_wall(structure_grid, Vector3i(x, 0, 1), 180, failures)
		for z in [-1, 0, 1]:
			if room_index == 0 or z != 0:
				_expect_wall(boundary_grid, Vector3i(room.x, 0, z), 90, failures)
			if room_index == rooms.size() - 1 or z != 0:
				_expect_wall(boundary_grid, Vector3i(room.y, 0, z), 270, failures)

	for corridor_x in [0, 4]:
		for z in range(-1, 2):
			_expect_item(floor_grid, Vector3i(corridor_x, 0, z), TRIPO_FLOOR_ID, failures)
		_expect_item(structure_grid, Vector3i(corridor_x, 0, 0), 3, failures)


func _expect_wall(grid: GridMap, cell: Vector3i, rotation_degrees: float, failures: Array[String]) -> void:
	var expected_orientation := grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, deg_to_rad(rotation_degrees)))
	if grid.get_cell_item(cell) != USER_WALL_ID:
		failures.append("wall cell=%s item=%d expected=%d" % [cell, grid.get_cell_item(cell), USER_WALL_ID])
	elif grid.get_cell_item_orientation(cell) != expected_orientation:
		failures.append("wall cell=%s orientation=%d expected=%d" % [cell, grid.get_cell_item_orientation(cell), expected_orientation])


func _expect_item(grid: GridMap, cell: Vector3i, expected_item: int, failures: Array[String]) -> void:
	if grid.get_cell_item(cell) != expected_item:
		failures.append("cell=%s item=%d expected=%d" % [cell, grid.get_cell_item(cell), expected_item])
