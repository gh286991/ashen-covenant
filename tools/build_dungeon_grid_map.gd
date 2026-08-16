extends SceneTree

const GRID_SIZE := 3.946
const LIBRARY_PATH := "res://levels/kit/dungeon_kit_mesh_library.tres"
const GRID_SCENE_PATH := "res://levels/dungeon_grid_map.tscn"

const ITEM_FLOOR := 0
const ITEM_WALL := 1
const ITEM_CORNER := 2
const ITEM_DOORWAY := 3
const ITEM_PILLAR := 4
const ITEM_ALTAR := 5
const ITEM_BRAZIER := 6
const ITEM_FLOOR_CUTE_BASE := 7
const ITEM_FLOOR_CUTE_CRACKED := 8
const ITEM_FLOOR_CUTE_MOSS := 9
const ITEM_FLOOR_CUTE_DECORATED := 10
const ITEM_WALL_USER_STONE := 11
const ITEM_FLOOR_TRIPO := 12
const FLOOR_LAYOUT_ITEM := ITEM_FLOOR_TRIPO

const ITEM_SOURCES := [
	{"id": ITEM_FLOOR, "name": "Floor Block 3.9m", "scene": "res://levels/kit/floor_block_3p9.tscn"},
	{"id": ITEM_WALL, "name": "Straight Wall 3.9m", "scene": "res://levels/kit/wall_straight_2p6.tscn"},
	{"id": ITEM_CORNER, "name": "Corner Wall", "scene": "res://levels/kit/wall_corner_2p6.tscn"},
	{"id": ITEM_DOORWAY, "name": "Doorway 3.6m", "scene": "res://levels/kit/doorway_3p6.tscn"},
	{"id": ITEM_PILLAR, "name": "Crypt Pillar", "scene": "res://levels/kit/pillar_crypt.tscn"},
	{"id": ITEM_ALTAR, "name": "Coffin Altar", "scene": "res://levels/kit/altar_coffin.tscn"},
	{"id": ITEM_BRAZIER, "name": "Blue Brazier", "scene": "res://levels/kit/brazier_blue.tscn"},
	{"id": ITEM_FLOOR_CUTE_BASE, "name": "Cute Floor - Base", "scene": "res://levels/kit/floor_cute_base_3p9.tscn"},
	{"id": ITEM_FLOOR_CUTE_CRACKED, "name": "Cute Floor - Cracked", "scene": "res://levels/kit/floor_cute_cracked_3p9.tscn"},
	{"id": ITEM_FLOOR_CUTE_MOSS, "name": "Cute Floor - Moss", "scene": "res://levels/kit/floor_cute_moss_3p9.tscn"},
	{"id": ITEM_FLOOR_CUTE_DECORATED, "name": "Cute Floor - Decorated", "scene": "res://levels/kit/floor_cute_decorated_3p9.tscn"},
	{"id": ITEM_WALL_USER_STONE, "name": "Wall - User Stone", "scene": "res://levels/kit/wall_user_stone_2p6.tscn"},
	{"id": ITEM_FLOOR_TRIPO, "name": "Stone Floor - Tripo Cleaned", "scene": "res://levels/kit/floor_stone_tripo_3p9.tscn"},
]


func _init() -> void:
	var library := MeshLibrary.new()
	for item_source in ITEM_SOURCES:
		_add_library_item(library, item_source)
	var library_error := ResourceSaver.save(library, LIBRARY_PATH)
	if library_error != OK:
		push_error("Could not save MeshLibrary: %s" % error_string(library_error))
		quit(1)
		return
	# Reload from disk so the scene keeps a reusable external MeshLibrary reference.
	var saved_library := load(LIBRARY_PATH) as MeshLibrary
	if saved_library == null:
		push_error("Could not reload MeshLibrary after saving")
		quit(1)
		return

	var root := Node3D.new()
	root.name = "DungeonGridMap"
	root.editor_description = "快速筆刷地圖。選取 DungeonGridMap/GridMap 後，從下方 GridMap 面板挑選素材並直接在 3D 視窗繪製。"
	var floor_grid := _create_grid_map("FloorGridMap", saved_library, "只畫地板；所有房間與走廊的基底。")
	var structure_grid := _create_grid_map("StructureGridMap", saved_library, "畫直牆、轉角與門洞。要新增互動門，仍請在 dungeon_3d.tscn 的 Doors 複製 Area3D。")
	var boundary_grid := _create_grid_map("BoundaryGridMap", saved_library, "畫左右邊界牆；與 StructureGridMap 的上下牆分層，讓房間四角不會互相覆蓋。")
	var prop_grid := _create_grid_map("PropGridMap", saved_library, "畫柱子、祭壇、火盆等靜態裝飾。")
	root.add_child(floor_grid)
	root.add_child(structure_grid)
	root.add_child(boundary_grid)
	root.add_child(prop_grid)
	floor_grid.owner = root
	structure_grid.owner = root
	boundary_grid.owner = root
	prop_grid.owner = root
	_populate_layout(floor_grid, structure_grid, boundary_grid, prop_grid)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack GridMap scene: %s" % error_string(pack_error))
		quit(1)
		return
	var scene_error := ResourceSaver.save(packed_scene, GRID_SCENE_PATH)
	if scene_error != OK:
		push_error("Could not save GridMap scene: %s" % error_string(scene_error))
		quit(1)
		return
	print("DUNGEON_GRIDMAP_BUILD_OK items=13 floor_item=%d scene=%s library=%s" % [FLOOR_LAYOUT_ITEM, GRID_SCENE_PATH, LIBRARY_PATH])
	quit(0)


func _add_library_item(library: MeshLibrary, item_source: Dictionary) -> void:
	var item_id: int = item_source["id"]
	var source_scene := load(item_source["scene"]) as PackedScene
	if source_scene == null:
		push_error("Missing kit scene: " + item_source["scene"])
		return
	var source_instance := source_scene.instantiate()
	var mesh_infos: Array = []
	_collect_meshes(source_instance, Transform3D.IDENTITY, mesh_infos)
	if mesh_infos.is_empty():
		push_error("No mesh found in kit scene: " + item_source["scene"])
		source_instance.free()
		return
	library.create_item(item_id)
	library.set_item_name(item_id, item_source["name"])
	library.set_item_mesh(item_id, _create_styled_mesh(mesh_infos))
	library.set_item_mesh_transform(item_id, Transform3D.IDENTITY)
	library.set_item_shapes(item_id, _collision_shapes_for(item_id))
	source_instance.free()


func _collect_meshes(node: Node, parent_transform: Transform3D, mesh_infos: Array) -> void:
	var node_transform := parent_transform
	if node is Node3D:
		node_transform = parent_transform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		mesh_infos.append({"mesh": (node as MeshInstance3D).mesh, "transform": node_transform})
	for child in node.get_children():
		_collect_meshes(child, node_transform, mesh_infos)


func _create_styled_mesh(mesh_infos: Array) -> Mesh:
	var styled_mesh := ArrayMesh.new()
	for mesh_info in mesh_infos:
		var source_mesh := mesh_info["mesh"] as Mesh
		var mesh_transform := mesh_info["transform"] as Transform3D
		for surface_index in source_mesh.get_surface_count():
			var surface_tool := SurfaceTool.new()
			surface_tool.begin(source_mesh.surface_get_primitive_type(surface_index))
			surface_tool.append_from(source_mesh, surface_index, mesh_transform)
			var source_material := source_mesh.surface_get_material(surface_index) as BaseMaterial3D
			if source_material != null:
				var material := source_material.duplicate() as BaseMaterial3D
				_apply_stone_style(material)
				surface_tool.set_material(material)
			surface_tool.commit(styled_mesh)
	return styled_mesh


func _apply_stone_style(material: BaseMaterial3D) -> void:
	# Imported Tripo wall materials may carry hashed/dithered alpha flags even
	# when the texture alpha is fully opaque. Disable transparency at the
	# MeshLibrary boundary so wall backfill and stone faces never show through.
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var material_name := String(material.resource_name)
	if material_name.contains("Slate_Dark"):
		material.albedo_color = Color(0.13, 0.17, 0.24, 1)
	elif material_name.contains("Slate_Mid"):
		material.albedo_color = Color(0.2, 0.25, 0.33, 1)
	elif material_name.contains("Slate_Light"):
		material.albedo_color = Color(0.31, 0.36, 0.45, 1)
	elif material_name.contains("WarmStone"):
		material.albedo_color = Color(0.33, 0.26, 0.24, 1)
	elif material_name.contains("CrimsonPath"):
		material.albedo_color = Color(0.28, 0.045, 0.065, 1)
	elif material_name.contains("CapStone"):
		material.albedo_color = Color(0.29, 0.35, 0.44, 1)
	material.roughness = 0.82


func _collision_shapes_for(item_id: int) -> Array:
	var shapes: Array = []
	match item_id:
		ITEM_FLOOR, ITEM_FLOOR_CUTE_BASE, ITEM_FLOOR_CUTE_CRACKED, ITEM_FLOOR_CUTE_MOSS, ITEM_FLOOR_CUTE_DECORATED, ITEM_FLOOR_TRIPO:
			_append_box_shape(shapes, Vector3(GRID_SIZE, 0.24, GRID_SIZE), Vector3(0, -0.12, 0))
		ITEM_WALL:
			_append_box_shape(shapes, Vector3(GRID_SIZE, 4.24, 0.62), Vector3(0, 2.12, 0))
		ITEM_WALL_USER_STONE:
			# The user wall is a boundary piece: the thickness straddles the cell edge.
			_append_box_shape(shapes, Vector3(GRID_SIZE, 4.24, 0.62), Vector3(0, 2.12, -GRID_SIZE * 0.5))
		ITEM_CORNER:
			_append_box_shape(shapes, Vector3(GRID_SIZE, 4.24, 0.62), Vector3(0, 2.12, -GRID_SIZE * 0.5))
			_append_box_shape(shapes, Vector3(0.62, 4.24, GRID_SIZE), Vector3(-GRID_SIZE * 0.5, 2.12, 0))
		ITEM_PILLAR:
			# Match the narrow column shaft instead of its decorative capital/base.
			var pillar := CylinderShape3D.new()
			pillar.radius = 0.42
			pillar.height = 4.0
			shapes.append(pillar)
			shapes.append(Transform3D(Basis(), Vector3(0, 2.0, 0)))
		ITEM_ALTAR:
			# Only the central coffin plinth blocks; the visual steps stay walkable.
			_append_box_shape(shapes, Vector3(2.45, 1.1, 1.15), Vector3(0, 0.55, 0))
		ITEM_BRAZIER:
			# Keep a small blocker at the stem/base, not the flame or wide top.
			var brazier := CylinderShape3D.new()
			brazier.radius = 0.25
			brazier.height = 1.25
			shapes.append(brazier)
			shapes.append(Transform3D(Basis(), Vector3(0, 0.625, 0)))
	return shapes


func _append_box_shape(shapes: Array, size: Vector3, origin: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	shapes.append(shape)
	shapes.append(Transform3D(Basis(), origin))


func _create_grid_map(grid_name: String, library: MeshLibrary, description: String) -> GridMap:
	var grid := GridMap.new()
	grid.name = grid_name
	grid.mesh_library = library
	grid.cell_size = Vector3(GRID_SIZE, GRID_SIZE, GRID_SIZE)
	grid.cell_center_y = false
	grid.cell_octant_size = 8
	grid.editor_description = description
	return grid


func _populate_layout(floor_grid: GridMap, structure_grid: GridMap, boundary_grid: GridMap, prop_grid: GridMap) -> void:
	var room_columns := [Vector2i(-3, -1), Vector2i(1, 3), Vector2i(5, 7)]
	for room_index in room_columns.size():
		var room: Vector2i = room_columns[room_index]
		for x in range(room.x, room.y + 1):
			for z in range(-1, 2):
				_place(floor_grid, Vector3i(x, 0, z), FLOOR_LAYOUT_ITEM)

		# Boundary walls sit in the outermost floor cells. The user-stone wall
		# mesh is authored with its centreline on the cell boundary, so it
		# closes the room without leaving a one-cell gap around the floor.
		for x in range(room.x, room.y + 1):
			_place(structure_grid, Vector3i(x, 0, -1), ITEM_WALL_USER_STONE)
			_place(structure_grid, Vector3i(x, 0, 1), ITEM_WALL_USER_STONE, 180)

		# Leave the centre of adjoining room edges open for the full-width
		# corridor and doorway. The outermost room edges remain sealed.
		var has_left_door := room_index > 0
		var has_right_door := room_index < room_columns.size() - 1
		for z in [-1, 0, 1]:
			if not has_left_door or z != 0:
				_place(boundary_grid, Vector3i(room.x, 0, z), ITEM_WALL_USER_STONE, 90)
			if not has_right_door or z != 0:
				_place(boundary_grid, Vector3i(room.y, 0, z), ITEM_WALL_USER_STONE, 270)

	# Two full-width playable passages. Doorway cells deliberately have no
	# collision; the floor cells on either side keep the passage continuous.
	for corridor_x in [0, 4]:
		for z in range(-1, 2):
			_place(floor_grid, Vector3i(corridor_x, 0, z), FLOOR_LAYOUT_ITEM)
		_place(structure_grid, Vector3i(corridor_x, 0, 0), ITEM_DOORWAY)
	# Static decoration remains paintable in the same palette.
	for center_x in [-2, 2, 6]:
		_place(prop_grid, Vector3i(center_x, 0, 0), ITEM_ALTAR, 90)
		_place(prop_grid, Vector3i(center_x, 0, -1), ITEM_BRAZIER)
		_place(prop_grid, Vector3i(center_x, 0, 1), ITEM_BRAZIER)
		_place(prop_grid, Vector3i(center_x - 1, 0, -1), ITEM_PILLAR)
		_place(prop_grid, Vector3i(center_x + 1, 0, -1), ITEM_PILLAR)
		_place(prop_grid, Vector3i(center_x - 1, 0, 1), ITEM_PILLAR)
		_place(prop_grid, Vector3i(center_x + 1, 0, 1), ITEM_PILLAR)


func _place(grid: GridMap, cell: Vector3i, item_id: int, y_rotation_degrees := 0.0) -> void:
	var orientation := grid.get_orthogonal_index_from_basis(Basis(Vector3.UP, deg_to_rad(y_rotation_degrees)))
	grid.set_cell_item(cell, item_id, orientation)
