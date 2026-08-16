extends SceneTree

const TILESET_PATH := "res://assets/old_prison/tiles/old_prison_tileset.tres"
const LAYOUT_PATH := "res://data/old_prison_tiled_layers.json"
const OUTPUT_PATH := "res://levels/old_prison_tilemap.tscn"
const TILEMAP_SCRIPT_PATH := "res://levels/old_prison_tilemap.gd"
const WALL_SHADER_PATH := "res://levels/old_prison_wall_occlusion.gdshader"
const FOREGROUND_WALL_Z_INDEX := 80
const FOREGROUND_WALL_OPACITY := 0.48

func _init() -> void:
	var tile_set := load(TILESET_PATH) as TileSet
	var layout := JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH)) as Dictionary
	if tile_set == null or layout.is_empty():
		push_error("Old Prison TileMap build failed: missing TileSet or converted layout")
		quit(1)
		return

	var scene_root := Node2D.new()
	scene_root.name = "OldPrisonTileMap"
	scene_root.z_index = -30
	scene_root.set_script(load(TILEMAP_SCRIPT_PATH))
	scene_root.set_meta("display_name", "Old Prison")
	scene_root.set_meta("tile_size", 32)
	scene_root.set_meta("source_pack", "EPIC RPG World Pack - Old Prison V1.7.1")
	scene_root.set_meta("assembly", "Tiled layers converted to Godot TileMapLayer")

	var layers: Array = layout.get("layers", [])
	for layer_index in layers.size():
		var layer_data: Dictionary = layers[layer_index]
		var layer := TileMapLayer.new()
		layer.name = _safe_layer_name(str(layer_data.get("name", "Layer")))
		layer.tile_set = tile_set
		layer.z_index = layer_index * 2
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for cell_data in layer_data.get("cells", []):
			var cell: Dictionary = cell_data
			layer.set_cell(
				Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))),
				int(cell.get("source", -1)),
				Vector2i(int(cell.get("atlas_x", 0)), int(cell.get("atlas_y", 0)))
			)
		scene_root.add_child(layer)
		layer.owner = scene_root

		# Keep a copy of the two architectural wall layers in front of actors.
		# The shader uses the player's actual alpha mask, so only wall pixels that
		# cover the player become translucent; the rest stays fully opaque.
		if layer.name == "wall_1" or layer.name == "wall_2":
			var foreground_layer := TileMapLayer.new()
			foreground_layer.name = "Foreground_%s" % layer.name
			foreground_layer.tile_set = tile_set
			foreground_layer.z_index = FOREGROUND_WALL_Z_INDEX
			foreground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var wall_material := ShaderMaterial.new()
			wall_material.shader = load(WALL_SHADER_PATH) as Shader
			wall_material.set_shader_parameter("occluded_opacity", FOREGROUND_WALL_OPACITY)
			foreground_layer.material = wall_material
			for cell_data in layer_data.get("cells", []):
				var cell: Dictionary = cell_data
				foreground_layer.set_cell(
					Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0))),
					int(cell.get("source", -1)),
					Vector2i(int(cell.get("atlas_x", 0)), int(cell.get("atlas_y", 0)))
				)
			scene_root.add_child(foreground_layer)
			foreground_layer.owner = scene_root

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(scene_root)
	if pack_error != OK:
		push_error("Old Prison TileMap pack failed: %s" % pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed_scene, OUTPUT_PATH)
	if save_error != OK:
		push_error("Old Prison TileMap save failed: %s" % save_error)
		quit(1)
		return

	print("Wrote %s with %d base layers plus silhouette-masked foreground walls" % [OUTPUT_PATH, layers.size()])
	quit()

func _safe_layer_name(raw_name: String) -> String:
	var cleaned := raw_name.strip_edges().replace(" ", "_").replace("-", "_")
	return cleaned if not cleaned.is_empty() else "TileLayer"
