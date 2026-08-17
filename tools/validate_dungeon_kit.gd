extends SceneTree

const KIT_MAP := "res://levels/dungeon_kit_map.tscn"
const PIECES := [
	"res://levels/kit/floor_block_3p9.tscn",
	"res://levels/kit/wall_straight_2p6.tscn",
	"res://levels/kit/wall_corner_2p6.tscn",
	"res://levels/kit/doorway_3p6.tscn",
	"res://levels/kit/pillar_crypt.tscn",
	"res://levels/kit/altar_coffin.tscn",
	"res://levels/kit/brazier_blue.tscn",
	"res://levels/kit/floor_cute_base_3p9.tscn",
	"res://levels/kit/floor_cute_cracked_3p9.tscn",
	"res://levels/kit/floor_cute_moss_3p9.tscn",
	"res://levels/kit/floor_cute_decorated_3p9.tscn",
	"res://levels/kit/wall_user_stone_2p6.tscn",
	"res://levels/kit/wall_castle_pbr_2p6.tscn",
	"res://levels/kit/floor_stone_tripo_3p9.tscn",
]


func _init() -> void:
	var failures: Array[String] = []
	var packed_map := load(KIT_MAP) as PackedScene
	if packed_map == null:
		failures.append("could not load modular kit map")
	else:
		var map := packed_map.instantiate()
		_check_count(map, "FloorBlocks", 29, failures)
		_check_count(map, "Walls", 37, failures)
		_check_count(map, "Corners", 12, failures)
		_check_count(map, "Doorways", 2, failures)
		_check_count(map, "Props", 21, failures)
		map.queue_free()

	for scene_path in PIECES:
		var packed_piece := load(scene_path) as PackedScene
		if packed_piece == null:
			failures.append("could not load " + scene_path)
			continue
		var piece := packed_piece.instantiate()
		if not piece is DungeonKitPiece3D:
			failures.append(scene_path + " has no DungeonKitPiece3D root")
		if piece.get_node_or_null("Visual") == null:
			failures.append(scene_path + " has no visual child")
		piece.queue_free()

	if failures.is_empty():
		print("DUNGEON_KIT_VALIDATE_OK floor=29 walls=37 corners=12 doors=2 props=21 pieces=14")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_count(map: Node, path: String, expected: int, failures: Array[String]) -> void:
	var group := map.get_node_or_null(path)
	if group == null:
		failures.append("missing group " + path)
		return
	if group.get_child_count() != expected:
		failures.append("%s count=%d expected=%d" % [path, group.get_child_count(), expected])
