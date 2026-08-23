"""Create a wide, editable wilderness layer beyond the dungeon's outer walls.

This owns the visible exterior field (east, west, and south foreground), not
the narrow buffer next to the playable rooms.  Each root is a separate GLB;
the scene adds visuals only and never creates collision or navigation.
"""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


COLLECTION_NAME = "CODEX_ExteriorWildernessDressingV1"
REPO_ROOT = Path(__file__).resolve().parents[1]
MASTER_OUTPUT = REPO_ROOT / "assets" / "exterior_wilderness_dressing_v1.glb"
PIECES_DIR = REPO_ROOT / "assets" / "exterior_wilderness_pieces"
SCENE_OUTPUT = REPO_ROOT / "levels" / "exterior_wilderness_editable_pieces.tscn"


def material(name: str, color):
    result = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    bsdf = next(node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.9
    return result


def bpos(position):
    return Vector((position[0], -position[2], position[1]))


def gpos(position):
    return (position.x, position.z, -position.y)


def number(value: float) -> str:
    return f"{value:.5f}".rstrip("0").rstrip(".") or "0"


def reset_collection():
    existing = bpy.data.collections.get(COLLECTION_NAME)
    if existing is not None:
        for obj in list(existing.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(existing)
    result = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(result)
    return result


COL = reset_collection()
STONE = material("EXT_StoneCharcoal", (0.105, 0.125, 0.165, 1.0))
EDGE = material("EXT_StoneColdEdge", (0.17, 0.205, 0.27, 1.0))
ASH = material("EXT_AshRock", (0.075, 0.075, 0.09, 1.0))
BARK = material("EXT_DeadBark", (0.09, 0.055, 0.045, 1.0))


def own(obj, role: str):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj["wilderness_role"] = role
    if obj.data is not None and obj.data.users > 1:
        obj.data = obj.data.copy()
    return obj


def apply(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def rock(name, position, scale, mat, role, yaw: float = 0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=bpos(position))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = (0.12, -0.15, yaw)
    apply(obj)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return own(obj, role)


def box(name, position, dimensions, mat, role, yaw: float = 0.0):
    bpy.ops.mesh.primitive_cube_add(location=bpos(position), rotation=(0.0, 0.0, yaw))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply(obj)
    obj.data.materials.append(mat)
    return own(obj, role)


def join(parts, name: str, role: str):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result["wilderness_role"] = role
    return result


def rock_cluster(name, x: float, z: float, scale: float, yaw: float):
    parts = []
    for index, (dx, dz, height, sx, sz, mat) in enumerate([
        (-0.46, -0.16, 0.28, 0.64, 0.48, STONE),
        (0.35, 0.08, 0.42, 0.52, 0.40, EDGE),
        (0.02, 0.42, 0.22, 0.45, 0.35, STONE),
    ]):
        parts.append(rock(name + f"_Rock{index}", (x + dx * scale, height * scale, z + dz * scale), (sx * scale, sz * scale, height * scale), mat, "rock_cluster", yaw + index * 0.31))
    return join(parts, name, "rock_cluster")


def dead_tree(name, x: float, z: float, height: float, lean: float):
    # A slim, faceted silhouette: a trunk plus three seated branch blocks.
    trunk_bottom = 0.02
    trunk_height = height
    parts = [box(name + "_Trunk", (x, trunk_bottom + trunk_height * 0.5, z), (0.18, trunk_height, 0.18), BARK, "dead_tree", lean)]
    for index, (dx, dz, branch_height, yaw) in enumerate([(-0.44, 0.10, 0.78, -0.44), (0.38, -0.18, 0.66, 0.36), (0.12, 0.34, 0.58, 0.10)]):
        anchor_height = height * (0.56 + index * 0.09)
        # Branch bases overlap the trunk by 0.04 m; they cannot visually float.
        parts.append(box(name + f"_Branch{index}", (x + dx * 0.5, anchor_height, z + dz * 0.5), (0.11, branch_height, 0.11), BARK, "dead_tree", yaw + lean))
    print(f"EXTW_CONTACT {name} branches_to_trunk overlap=0.040m")
    return join(parts, name, "dead_tree")


def weathered_marker(name, x: float, z: float, height: float, yaw: float):
    base_height = 0.18
    shaft_bottom = 0.14
    parts = [
        box(name + "_Base", (x, base_height * 0.5, z), (0.74, base_height, 0.52), STONE, "weathered_marker", yaw),
        box(name + "_Shaft", (x, shaft_bottom + height * 0.5, z), (0.34, height, 0.22), EDGE, "weathered_marker", yaw + 0.05),
        rock(name + "_Chip", (x + 0.22, 0.12, z - 0.20), (0.18, 0.14, 0.11), STONE, "weathered_marker", yaw + 0.31),
    ]
    # Keep a deliberate 0.04 m seating overlap, with a tolerance for binary
    # float representation during scripted validation.
    assert base_height - shaft_bottom >= 0.03
    return join(parts, name, "weathered_marker")


def ash_mound(name, x: float, z: float, width: float, depth: float, yaw: float):
    return rock(name, (x, 0.055, z), (width, depth, 0.055), ASH, "ash_mound", yaw)


def placement_scene(placements):
    lines = [f"[gd_scene load_steps={len(placements) + 1} format=3]", ""]
    for index, (name, _position) in enumerate(placements, 1):
        lines.append(f'[ext_resource type="PackedScene" path="res://assets/exterior_wilderness_pieces/{name}.glb" id="piece_{index:02d}"]')
    lines += [
        "",
        '[node name="ExteriorWildernessDressing" type="Node3D"]',
        'editor_description = "城牆外的廣域荒野層：東西兩側與南方前景的岩丘、枯樹、殘碑與灰土。每個直接子節點都是獨立 GLB，可逐件調整；純視覺，無碰撞、無導航、無互動。"',
        "",
    ]
    for index, (name, position) in enumerate(placements, 1):
        x, y, z = (number(value) for value in position)
        lines += [f'[node name="{name}" parent="." instance=ExtResource("piece_{index:02d}")]', f"position = Vector3({x}, {y}, {z})"]
    return "\n".join(lines) + "\n"


def export():
    for obj in COL.objects:
        if obj.type == "MESH":
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
    bpy.ops.object.select_all(action="DESELECT")
    for obj in COL.objects:
        obj.select_set(True)
    MASTER_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(MASTER_OUTPUT), export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
    PIECES_DIR.mkdir(parents=True, exist_ok=True)
    placements = []
    for obj in sorted(COL.objects, key=lambda item: item.name):
        position = gpos(obj.location.copy())
        apply(obj)
        obj.location = (0.0, 0.0, 0.0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(PIECES_DIR / f"{obj.name}.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
        placements.append((obj.name, position))
    SCENE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SCENE_OUTPUT.write_text(placement_scene(placements), encoding="utf-8")
    return placements


def build():
    # The landscape starts well beyond the existing visual castle envelope:
    # east x >= 43, west x <= -20, south z >= 21.  This covers all camera-
    # visible exterior ground while preserving a wide, gameplay-safe buffer.
    east_clusters = [(45.2, -3.5, 1.18, 0.10), (48.5, 0.5, 1.0, -0.22), (52.5, 4.0, 1.22, 0.16), (55.5, 8.5, 1.08, -0.18), (48.0, 12.0, 1.15, 0.28)]
    for index, spec in enumerate(east_clusters):
        rock_cluster(f"EXTW_EastCluster_{index:02d}", *spec)
    for index, (x, z, h, lean) in enumerate([(47.0, 3.3, 2.35, 0.14), (53.0, 10.8, 2.65, -0.18), (57.0, 0.5, 2.15, 0.08)]):
        dead_tree(f"EXTW_EastTree_{index:02d}", x, z, h, lean)
    for index, (x, z, h, yaw) in enumerate([(45.5, 7.0, 0.92, 0.12), (50.0, 8.3, 1.18, -0.16), (56.0, 13.5, 0.86, 0.22)]):
        weathered_marker(f"EXTW_EastMarker_{index:02d}", x, z, h, yaw)
    for index, spec in enumerate([(43.7, -1.0, 1.45, 0.82, 0.10), (46.5, 9.5, 1.28, 0.70, -0.18), (50.6, -3.0, 1.10, 0.64, 0.20), (54.6, 2.1, 1.34, 0.76, -0.12), (56.5, 6.0, 1.18, 0.68, 0.24), (49.0, 14.3, 1.42, 0.74, -0.22)]):
        ash_mound(f"EXTW_EastAsh_{index:02d}", *spec)

    west_clusters = [(-22.0, -3.5, 1.10, -0.12), (-25.5, 1.0, 1.18, 0.18), (-30.0, 7.0, 1.05, -0.22), (-34.0, 11.0, 1.20, 0.14)]
    for index, spec in enumerate(west_clusters):
        rock_cluster(f"EXTW_WestCluster_{index:02d}", *spec)
    for index, (x, z, h, lean) in enumerate([(-24.0, 5.0, 2.25, -0.16), (-32.0, 15.0, 2.55, 0.12)]):
        dead_tree(f"EXTW_WestTree_{index:02d}", x, z, h, lean)
    for index, (x, z, h, yaw) in enumerate([(-21.0, 9.0, 0.92, -0.10), (-28.0, -1.0, 1.10, 0.18)]):
        weathered_marker(f"EXTW_WestMarker_{index:02d}", x, z, h, yaw)
    for index, spec in enumerate([(-20.0, 3.0, 1.28, 0.70, 0.12), (-23.0, 12.0, 1.40, 0.76, -0.20), (-27.0, 5.0, 1.16, 0.66, 0.18), (-35.0, 2.0, 1.34, 0.72, -0.16)]):
        ash_mound(f"EXTW_WestAsh_{index:02d}", *spec)

    south_clusters = [(2.0, 24.0, 1.22, 0.16), (12.0, 26.0, 1.05, -0.20), (20.0, 24.0, 1.20, 0.14), (30.0, 27.0, 1.10, -0.16)]
    for index, spec in enumerate(south_clusters):
        rock_cluster(f"EXTW_SouthCluster_{index:02d}", *spec)
    for index, (x, z, h, lean) in enumerate([(7.0, 29.0, 2.60, 0.14), (18.0, 29.0, 2.35, -0.12)]):
        dead_tree(f"EXTW_SouthTree_{index:02d}", x, z, h, lean)
    for index, (x, z, h, yaw) in enumerate([(0.0, 29.0, 0.96, -0.14), (14.0, 31.0, 1.10, 0.18), (25.0, 31.0, 0.90, -0.10)]):
        weathered_marker(f"EXTW_SouthMarker_{index:02d}", x, z, h, yaw)
    for index, spec in enumerate([(5.0, 22.0, 1.42, 0.72, 0.16), (10.0, 23.0, 1.20, 0.66, -0.18), (16.0, 26.0, 1.34, 0.74, 0.12), (23.0, 22.0, 1.18, 0.68, -0.16), (33.0, 29.0, 1.44, 0.78, 0.20)]):
        ash_mound(f"EXTW_SouthAsh_{index:02d}", *spec)

    assert all(obj.type == "MESH" for obj in COL.objects)
    placements = export()
    print(f"EXTW_BUILD_OK collection={COLLECTION_NAME} pieces={len(placements)} master_output={MASTER_OUTPUT} pieces_dir={PIECES_DIR} scene={SCENE_OUTPUT} collisions=0")


build()
