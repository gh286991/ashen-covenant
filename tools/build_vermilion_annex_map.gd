extends Node

## One-shot authoring helper. Run this scene once to create the editable
## TileMap scene and its TileSet resource, then open the generated scene in
## Godot to make hand-authored changes.

const OUTPUT_TILESET_PATH := "res://assets/tiles/vermilion_annex_32x32.tres"
const OUTPUT_SCENE_PATH := "res://levels/vermilion_annex_tilemap.tscn"
const OUTPUT_PREVIEW_PATH := "res://assets/maps/vermilion_annex_tilemap_preview.png"
const SOURCE_TEXTURE_PATH := "res://assets/tiles/third_party/sbs_tiny_top_down/Tiny Top Down 32x32.png"
const LAYOUT_PATH := "res://data/ashen_catacombs_layout.json"
const TILE_SIZE := 32
const MAP_SIZE := Vector2i(69, 44)

const FLOOR_TILES := [Vector2i(0, 7), Vector2i(0, 8), Vector2i(4, 8)]
const WALL_TILE := Vector2i(1, 1)
const WALL_CAP_TILE := Vector2i(1, 0)
const DOOR_TILE := Vector2i(0, 9)


func _ready() -> void:
	call_deferred(&"_build")


func _build() -> void:
	var layout := _load_layout()
	if layout.is_empty():
		push_error("Vermilion Annex build failed: layout data is unavailable.")
		get_tree().quit(1)
		return

	var tile_set := _create_tileset()
	if tile_set == null:
		push_error("Vermilion Annex build failed: source tileset texture is unavailable.")
		get_tree().quit(1)
		return
	ResourceSaver.save(tile_set, OUTPUT_TILESET_PATH)

	var editable_tile_set := load(OUTPUT_TILESET_PATH) as TileSet
	if editable_tile_set == null:
		push_error("Vermilion Annex build failed: Godot could not save the TileSet resource.")
		get_tree().quit(1)
		return

	var root := Node2D.new()
	root.name = "VermilionAnnexTiles"
	root.z_index = -30
	root.set_meta("display_name", "Vermilion Annex")
	root.set_meta("tile_size", TILE_SIZE)
	root.set_meta("source_license", "CC0 / Public Domain — Screaming Brain Studios")

	var ground := _new_layer("Ground", editable_tile_set, 0)
	var walls := _new_layer("Walls", editable_tile_set, 1)
	var doors := _new_layer("Doors", editable_tile_set, 2)
	root.add_child(ground)
	ground.owner = root
	root.add_child(walls)
	walls.owner = root
	root.add_child(doors)
	doors.owner = root

	var walkable := _make_walkable_grid(layout)
	_paint_ground(ground, walkable)
	_paint_walls(walls, walkable)
	_paint_doors(doors)
	_save_preview([ground, walls, doors])

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("Vermilion Annex build failed: scene packing returned %s." % pack_error)
		get_tree().quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_SCENE_PATH)
	if save_error != OK:
		push_error("Vermilion Annex build failed: scene save returned %s." % save_error)
		get_tree().quit(1)
		return

	print("[VERMILION_ANNEX] GENERATED scene=%s tileset=%s" % [OUTPUT_SCENE_PATH, OUTPUT_TILESET_PATH])
	get_tree().quit()


func _load_layout() -> Dictionary:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _create_tileset() -> TileSet:
	var texture := load(SOURCE_TEXTURE_PATH) as Texture2D
	if texture == null:
		return null
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for y in 10:
		for x in 10:
			source.create_tile(Vector2i(x, y))
	tile_set.add_source(source, 0)
	return tile_set


func _new_layer(layer_name: String, tile_set: TileSet, layer_z_index: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.z_index = layer_z_index
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


func _make_walkable_grid(layout: Dictionary) -> Array[bool]:
	var grid: Array[bool] = []
	grid.resize(MAP_SIZE.x * MAP_SIZE.y)
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var world_point := Vector2(x * TILE_SIZE + TILE_SIZE * 0.5, y * TILE_SIZE + TILE_SIZE * 0.5)
			grid[_grid_index(Vector2i(x, y))] = _point_is_walkable(layout, world_point)
	return grid


func _point_is_walkable(layout: Dictionary, point: Vector2) -> bool:
	for shape: Dictionary in layout.get("walkables", []):
		if String(shape.get("shape", "rect")) == "ellipse":
			var radius_x := float(shape.get("rx", 1.0))
			var radius_y := float(shape.get("ry", 1.0))
			var delta := point - Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))
			if delta.x * delta.x / (radius_x * radius_x) + delta.y * delta.y / (radius_y * radius_y) <= 1.0:
				return true
		else:
			var rect := Rect2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)), float(shape.get("w", 0.0)), float(shape.get("h", 0.0)))
			if rect.has_point(point):
				return true
	return false


func _paint_ground(ground: TileMapLayer, walkable: Array[bool]) -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if not _is_walkable(walkable, cell):
				continue
			ground.set_cell(cell, 0, FLOOR_TILES[_floor_variant(cell)])


func _paint_walls(walls: TileMapLayer, walkable: Array[bool]) -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _is_walkable(walkable, cell):
				continue
			var touches_floor := false
			var cap := false
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if _is_walkable(walkable, cell + direction):
					touches_floor = true
					cap = cap or direction == Vector2i.DOWN
			if touches_floor:
				walls.set_cell(cell, 0, WALL_CAP_TILE if cap else WALL_TILE)


func _paint_doors(doors: TileMapLayer) -> void:
	for cell in [Vector2i(34, 40), Vector2i(34, 14), Vector2i(16, 21), Vector2i(52, 21)]:
		doors.set_cell(cell, 0, DOOR_TILE)


func _save_preview(layers: Array[TileMapLayer]) -> void:
	var texture := load(SOURCE_TEXTURE_PATH) as Texture2D
	if texture == null:
		return
	var source_image := texture.get_image()
	if source_image == null:
		return
	source_image.convert(Image.FORMAT_RGBA8)
	var preview := Image.create(MAP_SIZE.x * TILE_SIZE, MAP_SIZE.y * TILE_SIZE, false, Image.FORMAT_RGBA8)
	preview.fill(Color("101218"))
	for layer in layers:
		for cell in layer.get_used_cells():
			var atlas := layer.get_cell_atlas_coords(cell)
			var source_rect := Rect2i(atlas * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE))
			var destination := cell * TILE_SIZE
			preview.blit_rect(source_image, source_rect, destination)
	preview.save_png(OUTPUT_PREVIEW_PATH)


func _is_walkable(grid: Array[bool], cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= MAP_SIZE.x or cell.y >= MAP_SIZE.y:
		return false
	return grid[_grid_index(cell)]


func _grid_index(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE.x + cell.x


func _floor_variant(cell: Vector2i) -> int:
	var value: int = abs(cell.x * 17 + cell.y * 31 + cell.x * cell.y * 7)
	if value % 23 == 0:
		return 2
	return 1 if value % 7 == 0 else 0
