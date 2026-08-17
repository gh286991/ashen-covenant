extends SceneTree

const GRID_SIZE := 3.946
const LIBRARY_PATH := "res://levels/kit/dungeon_kit_mesh_library.tres"
const GRID_SCENE_PATH := "res://levels/dungeon_grid_map.tscn"
const ORIGINAL_FLOOR := "res://levels/kit/floor_stone_tripo_3p9.tscn"
const ORIGINAL_WALL := "res://levels/kit/wall_castle_pbr_2p6.tscn"
const ORIGINAL_DOORWAY := "res://levels/modules/castle_wall_doorway_3p946.tscn"
const MODULAR_WALL_STRAIGHT := "res://levels/modules/castle_wall_straight_3p946.tscn"
const MODULAR_WALL_CORNER := "res://levels/modules/castle_wall_corner_3p946.tscn"
const MODULAR_WING := "res://levels/modules/corridor_flexible_wing.tscn"

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
	root.editor_description = "實際地圖在 ModularAssembly：房間四邊用牆封住，只在 Doorways 開入口；走道兩側也有碰撞牆。四組 GridMap 是隱藏筆刷參考層。"
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
	_add_modular_assembly(root)

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
	# Keep the four GridMaps as a paint/reference layer, but let the explicit
	# modular assembly below be the visible game geometry and collision source.
	grid.visible = false
	grid.collision_layer = 0
	grid.collision_mask = 0
	return grid


func _add_modular_assembly(root: Node3D) -> void:
	var assembly := Node3D.new()
	assembly.name = "ModularAssembly"
	assembly.editor_description = "混合組裝的實際遊戲幾何：三個房間由兩段兩格長走道串起。房間與主走道沿用原本石板地板和石牆，北側分支使用新的可拆式牆體與轉角。"
	root.add_child(assembly)
	assembly.owner = root

	var rooms := Node3D.new()
	rooms.name = "Rooms"
	rooms.editor_description = "3x3 房間模組：沿用原本石板地板與原本石牆完整封邊，只在門洞與北側支線留出入口；房間之間保留清楚的走道距離。"
	assembly.add_child(rooms)
	rooms.owner = root

	var corridors := Node3D.new()
	corridors.name = "Corridors"
	corridors.editor_description = "1 格寬、兩格長走道：連續原本地板列由原本石牆包住，兩端接到房間石拱門。"
	assembly.add_child(corridors)
	corridors.owner = root

	_build_room(rooms, "RoomA_EntryCrypt", -3, -1, -1, 1, false, true, false, root)
	_build_room(rooms, "RoomB_SoulSanctum", 2, 4, -1, 1, true, true, true, root)
	_build_room(rooms, "RoomC_Bloodworks", 7, 9, -1, 1, true, false, false, root)
	_build_corridor(corridors, "Corridor_AB", 0, 1, root)
	_build_corridor(corridors, "Corridor_BC", 5, 6, root)

	var wing_scene := load(MODULAR_WING) as PackedScene
	if wing_scene != null:
		var wing := wing_scene.instantiate()
		wing.name = "CorridorFlexibleWing"
		assembly.add_child(wing)
		wing.position = Vector3(GRID_SIZE, 0, 0)
		wing.owner = root
	else:
		push_error("Missing modular wing scene: " + MODULAR_WING)


func _build_room(parent: Node3D, room_name: String, x0: int, x1: int, z0: int, z1: int, door_west: bool, door_east: bool, branch_north: bool, root: Node3D) -> void:
	var room := Node3D.new()
	room.name = room_name
	room.editor_description = "房間 %s：%dx%d 格，原本地板、連續石牆、門洞與裝飾分組。" % [room_name, x1 - x0 + 1, z1 - z0 + 1]
	parent.add_child(room)
	room.owner = root

	var floors := _new_piece_group(room, "Floors", "房間地板；可替換 Plain、Cracked、Rune 三種地板。", root)
	var walls := _new_piece_group(room, "Walls", "封閉房間外框的阻擋牆；只有 Doorways 位置留出可通行入口。每個牆片都帶 StaticBody3D 碰撞。", root)
	var corners := _new_piece_group(room, "Corners", "主房間以原本石牆連續封邊；L 型角牆零件集中用在北側支線轉彎，避免不同牆體散落在房間內。", root)
	var doorways := _new_piece_group(room, "Doorways", "房間邊界中央的門洞；門洞不封死可走路空間。", root)
	var props := _new_piece_group(room, "Props", "房間內的原本地下城裝飾；保持中央動線，讓房間不只是空地板。", root)

	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			# Keep the original cleaned Tripo floor in every room. The new
			# cracked/rune floors are reserved for corridors and the north wing.
			_add_piece(floors, ORIGINAL_FLOOR, "OriginalFloor_%d_%d" % [x, z], _cell_position(x, z), 0.0, root)

	# The original stone wall is a full grid-cell segment. Use it for every
	# room edge so the room reads as a deliberately enclosed dungeon chamber;
	# only the centre segment is omitted where a doorway or branch connects.
	for x in range(x0, x1 + 1):
		if not (branch_north and x == int((x0 + x1) / 2.0)):
			_add_piece(walls, ORIGINAL_WALL, "OriginalNorth_%d" % x, Vector3(x * GRID_SIZE, 0, z0 * GRID_SIZE), 0.0, root)
		_add_piece(walls, ORIGINAL_WALL, "OriginalSouth_%d" % x, Vector3(x * GRID_SIZE, 0, z1 * GRID_SIZE), 180.0, root)

	for z in range(z0, z1 + 1):
		if not (door_west and z == 0):
			_add_piece(walls, ORIGINAL_WALL, "OriginalWest_%d" % z, Vector3(x0 * GRID_SIZE, 0, z * GRID_SIZE), 90.0, root)
		if not (door_east and z == 0):
			_add_piece(walls, ORIGINAL_WALL, "OriginalEast_%d" % z, Vector3(x1 * GRID_SIZE, 0, z * GRID_SIZE), 270.0, root)

	if door_west:
		_add_piece(doorways, ORIGINAL_DOORWAY, "WestDoorway", Vector3((x0 - 0.5) * GRID_SIZE, 0, 0), 90.0, root)
	if door_east:
		_add_piece(doorways, ORIGINAL_DOORWAY, "EastDoorway", Vector3((x1 + 0.5) * GRID_SIZE, 0, 0), 270.0, root)

	# Reuse the original kit props inside the actual modular assembly. They
	# stay off the main travel axis except for the optional room focal altar.
	if branch_north:
		_add_piece(props, "res://levels/kit/brazier_blue.tscn", "Brazier_NW", _cell_position(x0, z0), 0.0, root)
		_add_piece(props, "res://levels/kit/brazier_blue.tscn", "Brazier_SE", _cell_position(x1, z1), 0.0, root)
	else:
		_add_piece(props, "res://levels/kit/brazier_blue.tscn", "Brazier_N", _cell_position(x0 + 1, z0), 0.0, root)
		_add_piece(props, "res://levels/kit/brazier_blue.tscn", "Brazier_S", _cell_position(x1 - 1, z1), 0.0, root)
	if room_name != "RoomA_EntryCrypt":
		_add_piece(props, "res://levels/kit/altar_coffin.tscn", "RoomAltar", _cell_position(int((x0 + x1) / 2.0), 0), 90.0, root)


func _build_corridor(parent: Node3D, corridor_name: String, cell_x0: int, cell_x1: int, root: Node3D) -> void:
	var corridor := Node3D.new()
	corridor.name = corridor_name
	corridor.editor_description = "1 格寬、兩格長東西向走道；兩側直牆連續排列，走道兩端由房間 Doorways 接入。"
	parent.add_child(corridor)
	corridor.owner = root

	var floors := _new_piece_group(corridor, "Floors", "走道地板列。", root)
	var walls := _new_piece_group(corridor, "Walls", "封住走道左右兩側的阻擋牆；地板只在走道軸線上保持通行。", root)
	var doorways := _new_piece_group(corridor, "Doorways", "走道接口門洞由相鄰房間的 Doorways 群組各放一個，避免兩個門框重疊。", root)
	for cell_x in range(cell_x0, cell_x1 + 1):
		_add_piece(floors, ORIGINAL_FLOOR, "OriginalFloor_%d_0" % cell_x, _cell_position(cell_x, 0), 0.0, root)
		_add_piece(walls, ORIGINAL_WALL, "OriginalNorthWall_%d" % cell_x, _cell_position(cell_x, 0), 0.0, root)
		_add_piece(walls, ORIGINAL_WALL, "OriginalSouthWall_%d" % cell_x, _cell_position(cell_x, 0), 180.0, root)


func _new_piece_group(parent: Node3D, group_name: String, description: String, root: Node3D) -> Node3D:
	var group := Node3D.new()
	group.name = group_name
	group.editor_description = description
	parent.add_child(group)
	group.owner = root
	return group


func _add_piece(parent: Node3D, scene_path: String, piece_name: String, position: Vector3, y_rotation_degrees: float, root: Node3D) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Missing modular piece scene: " + scene_path)
		return
	var piece := packed.instantiate()
	piece.name = piece_name
	parent.add_child(piece)
	piece.position = position
	piece.rotation_degrees.y = y_rotation_degrees
	piece.owner = root


func _cell_position(x: int, z: int) -> Vector3:
	return Vector3(x * GRID_SIZE, 0, z * GRID_SIZE)


func _populate_layout(floor_grid: GridMap, structure_grid: GridMap, boundary_grid: GridMap, prop_grid: GridMap) -> void:
	var room_columns := [Vector2i(-3, -1), Vector2i(2, 4), Vector2i(7, 9)]
	for room_index in room_columns.size():
		var room: Vector2i = room_columns[room_index]
		for x in range(room.x, room.y + 1):
			for z in range(-1, 2):
				_place(floor_grid, Vector3i(x, 0, z), FLOOR_LAYOUT_ITEM)

		# Boundary walls sit in the outermost floor cells. The user-stone wall
		# mesh is authored with its centreline on the cell boundary, so it
		# closes the room without leaving a one-cell gap around the floor.
		for x in range(room.x, room.y + 1):
			# Open the middle of the central room for the new modular north wing.
			if not (room_index == 1 and x == 3):
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

	# Two one-cell-wide playable passages. Each room owns one doorway at its
	# interface, so the corridor never duplicates a doorway at the same edge.
	for corridor_x in [0, 1, 5, 6]:
		_place(floor_grid, Vector3i(corridor_x, 0, 0), FLOOR_LAYOUT_ITEM)
	for doorway_x in [0, 5]:
		_place(structure_grid, Vector3i(doorway_x, 0, 0), ITEM_DOORWAY)
	# Static decoration remains paintable in the same palette.
	for center_x in [-2, 3, 8]:
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
