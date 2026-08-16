extends SceneTree

func _init() -> void:
	var packed := load("res://levels/dungeon_grid_map.tscn") as PackedScene
	if packed == null:
		push_error("Could not load dungeon_grid_map")
		quit(1)
		return
	var root := packed.instantiate()
	for grid_name in ["FloorGridMap", "StructureGridMap", "BoundaryGridMap", "PropGridMap"]:
		var grid := root.get_node(grid_name) as GridMap
		print(grid_name + " cells=" + str(grid.get_used_cells().size()))
		for cell in grid.get_used_cells():
			print("  cell=%s item=%d orientation=%d" % [cell, grid.get_cell_item(cell), grid.get_cell_item_orientation(cell)])
	root.free()
	quit(0)
