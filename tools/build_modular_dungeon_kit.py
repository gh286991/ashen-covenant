"""Extract reusable dungeon-kit pieces from the authored Blender room.

Run with:
  Blender --background assets/dungeon_two_rooms.blend --python tools/build_modular_dungeon_kit.py

The source room is never overwritten.  This script saves a separate Blender
file and emits one GLB per editor-facing kit piece.
"""

from __future__ import annotations

import json
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = PROJECT_ROOT / "assets" / "3d_dungeon" / "kit"
KIT_BLEND_PATH = PROJECT_ROOT / "assets" / "dungeon_modular_kit.blend"
MANIFEST_PATH = OUTPUT_DIR / "dungeon_kit_manifest.json"
KIT_COLLECTION_NAME = "DUNGEON_MODULAR_KIT"


def tile_names(prefix: str, row_range: range, column_range: range) -> list[str]:
	return [f"{prefix}_{row}_{column}" for row in row_range for column in column_range]


def wall_names(prefix: str, brick_columns: range) -> list[str]:
	return [f"{prefix}_R{row}_B{column}" for row in range(7) for column in brick_columns]


ASSETS: list[dict] = [
	{
		"id": "floor_block_3p9",
		"role": "Floor",
		"anchor": (-11.05, -4.05, 0.0),
		"note": "Five-by-five stone-floor tiles. Place on the 3.9 m floor grid.",
		"objects": tile_names("ROOM_A_EntryCrypt_Tile", range(5), range(5)),
	},
	{
		"id": "wall_straight_2p6",
		"role": "Straight Wall",
		"anchor": (-8.286, 6.0, 0.0),
		"note": "Three-brick-wide straight wall. Local +X is the wall length; rotate 90 degrees for side walls.",
		"objects": wall_names("A_BackWall", range(4, 7)) + ["A_BackCap_3", "A_BackCap_4", "A_BackCap_5"],
	},
	{
		"id": "wall_corner_2p6",
		"role": "Corner Wall",
		"anchor": (-1.0, 6.0, 0.0),
		"note": "Outer corner. The two wall arms meet at the local origin and extend toward local -X and -Y.",
		"objects": (
			wall_names("A_BackWall", range(11, 14))
			+ ["A_BackCap_7", "A_BackCap_8", "A_BackCap_9"]
			+ wall_names("A_RightWall_Upper", range(2, 5))
			+ ["A_RightCapUpper_1", "A_RightCapUpper_2", "A_RightCapUpper_3"]
		),
	},
	{
		"id": "doorway_3p6",
		"role": "Doorway",
		"anchor": (-1.0, 0.0, 0.0),
		"note": "3.6 m arched doorway. Put its origin at the centre of a wall opening.",
		"objects": [
			"A_DoorBase_0", "A_DoorBase_1", "A_DoorPillar_0", "A_DoorPillar_1",
			"A_DoorTrim_0", "A_DoorTrim_1",
		]
		+ [f"A_ArchStone_{index}" for index in range(9)],
	},
	{
		"id": "pillar_crypt",
		"role": "Pillar",
		"anchor": (-14.75, 6.85, 0.0),
		"note": "Standalone crypt pillar. The origin is on the floor at the centre of its base.",
		"objects": ["A_Pillar_NW_Base", "A_Pillar_NW_Shaft", "A_Pillar_NW_Cap"],
	},
	{
		"id": "altar_coffin",
		"role": "Set Dressing",
		"anchor": (-9.25, 0.0, 0.0),
		"note": "Altar and coffin decoration for a focal point inside a room.",
		"objects": ["A_Altar_Base", "A_Altar_Top", "A_Coffin_Lid", "A_Coffin_Band1", "A_Coffin_Band2", "A_Skull"],
	},
	{
		"id": "brazier_blue",
		"role": "Set Dressing",
		"anchor": (-3.4, 6.55, 0.0),
		"note": "Blue-flame brazier. Add a Godot OmniLight3D beside it if a local light is wanted.",
		"objects": ["A_Brazier_N_Stand", "A_Brazier_N_Bowl", "A_Brazier_N_Coal", "A_Brazier_N_Flame"],
	},
]


def require_source_objects(names: list[str]) -> list[bpy.types.Object]:
	missing = [name for name in names if bpy.data.objects.get(name) is None]
	if missing:
		raise RuntimeError("Missing source objects: %s" % ", ".join(missing))
	return [bpy.data.objects[name] for name in names]


def remove_previous_kit() -> None:
	collection = bpy.data.collections.get(KIT_COLLECTION_NAME)
	if collection is None:
		return
	for obj in list(collection.all_objects):
		bpy.data.objects.remove(obj, do_unlink=True)
	bpy.data.collections.remove(collection)


def bounds_relative_to_origin(obj: bpy.types.Object) -> dict[str, list[float]]:
	points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
	minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
	maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
	return {
		"min": [round(component, 4) for component in minimum],
		"max": [round(component, 4) for component in maximum],
		"size": [round(component, 4) for component in (maximum - minimum)],
	}


def make_single_mesh_asset(spec: dict, kit_collection: bpy.types.Collection) -> dict:
	asset_id = spec["id"]
	anchor = Vector(spec["anchor"])
	source_objects = require_source_objects(spec["objects"])

	asset_collection = bpy.data.collections.new("KIT_" + asset_id)
	kit_collection.children.link(asset_collection)

	root = bpy.data.objects.new("KIT_" + asset_id, None)
	root.empty_display_type = "CUBE"
	root.empty_display_size = 0.5
	root["kit_id"] = asset_id
	root["kit_role"] = spec["role"]
	root["kit_note"] = spec["note"]
	asset_collection.objects.link(root)

	duplicates: list[bpy.types.Object] = []
	translation = Matrix.Translation(-anchor)
	for source in source_objects:
		copy = source.copy()
		if source.data is not None:
			copy.data = source.data.copy()
		copy.animation_data_clear()
		asset_collection.objects.link(copy)
		copy.matrix_world = translation @ source.matrix_world
		copy.parent = root
		duplicates.append(copy)

	bpy.ops.object.select_all(action="DESELECT")
	for duplicate in duplicates:
		duplicate.select_set(True)
	bpy.context.view_layer.objects.active = duplicates[0]
	bpy.ops.object.join()
	joined = bpy.context.view_layer.objects.active
	joined.name = "MESH_" + asset_id
	joined.data.name = "MESH_" + asset_id
	joined.parent = root

	bounds = bounds_relative_to_origin(joined)
	root["kit_bounds_size"] = bounds["size"]

	OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
	output_path = OUTPUT_DIR / (asset_id + ".glb")
	bpy.ops.object.select_all(action="DESELECT")
	root.select_set(True)
	joined.select_set(True)
	bpy.context.view_layer.objects.active = joined
	bpy.ops.export_scene.gltf(
		filepath=str(output_path),
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_materials="EXPORT",
	)
	print("KIT_ASSET_OK", asset_id, bounds)
	return {"id": asset_id, "role": spec["role"], "note": spec["note"], "bounds": bounds, "file": output_path.name}


def main() -> None:
	if bpy.context.mode != "OBJECT":
		bpy.ops.object.mode_set(mode="OBJECT")
	remove_previous_kit()
	kit_collection = bpy.data.collections.new(KIT_COLLECTION_NAME)
	bpy.context.scene.collection.children.link(kit_collection)

	manifest = [make_single_mesh_asset(spec, kit_collection) for spec in ASSETS]
	MANIFEST_PATH.write_text(json.dumps({"source": "dungeon_two_rooms.blend", "assets": manifest}, indent=2), encoding="utf-8")
	bpy.ops.wm.save_as_mainfile(filepath=str(KIT_BLEND_PATH))
	print("DUNGEON_KIT_BUILD_OK assets=%d blend=%s" % (len(manifest), KIT_BLEND_PATH))


main()
