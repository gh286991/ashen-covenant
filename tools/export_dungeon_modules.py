import bpy
from pathlib import Path


SOURCE = Path("/Users/tomjhuang/Documents/actRPG/assets/dungeon_two_rooms.blend")
OUTPUT_DIR = Path("/Users/tomjhuang/Documents/actRPG/assets/3d_dungeon/modules")

MODULES = {
    "MODULE_RoomA_EntryCrypt": "room_a_entry_crypt.glb",
    "MODULE_RoomB_SoulSanctum": "room_b_soul_sanctum.glb",
    "MODULE_Corridor_3p6m": "corridor_3p6m.glb",
}


def collection_objects(collection):
    result = []

    def visit(current):
        result.extend(current.objects)
        for child in current.children:
            visit(child)

    visit(collection)
    return result


def export_module(collection_name: str, filename: str) -> None:
    collection = bpy.data.collections.get(collection_name)
    if collection is None:
        raise RuntimeError(f"Missing collection: {collection_name}")

    bpy.ops.object.select_all(action="DESELECT")
    selected = []
    for obj in collection_objects(collection):
        if obj.type != "MESH":
            continue
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
        selected.append(obj)

    if not selected:
        raise RuntimeError(f"No mesh objects in collection: {collection_name}")

    bpy.context.view_layer.objects.active = selected[0]
    output_path = OUTPUT_DIR / filename
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    print(f"EXPORTED {collection_name} objects={len(selected)} path={output_path}")


if bpy.data.filepath != str(SOURCE):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))

for module_name, filename in MODULES.items():
    export_module(module_name, filename)

print("DUNGEON_MODULE_EXPORT_COMPLETE")
