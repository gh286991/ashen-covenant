"""Build an editable, low-profile rubble court in the south exterior gap.

The set occupies only the narrow visual apron between the playable south wall
and the existing outer ruin line.  Every root object is exported as its own
GLB so level artists can move, hide or replace it in Godot without separating
meshes first.  It deliberately has no collision, navigation or gameplay role.
"""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector


COLLECTION_NAME = "CODEX_ExteriorCourtyardDressingV1"
REPO_ROOT = Path(__file__).resolve().parents[1]
MASTER_OUTPUT = REPO_ROOT / "assets" / "exterior_courtyard_dressing_v1.glb"
PIECES_DIR = REPO_ROOT / "assets" / "exterior_courtyard_pieces"
SCENE_OUTPUT = REPO_ROOT / "levels" / "exterior_courtyard_editable_pieces.tscn"


def make_material(name: str, color):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.9
    return material


def to_blender(position):
    """Convert Godot x/y/z world coordinates to Blender x/y/z coordinates."""
    return Vector((position[0], -position[2], position[1]))


def to_godot(position):
    return (position.x, position.z, -position.y)


def number(value: float) -> str:
    return f"{value:.5f}".rstrip("0").rstrip(".") or "0"


def reset_owned_collection():
    previous = bpy.data.collections.get(COLLECTION_NAME)
    if previous is not None:
        for obj in list(previous.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(previous)
    result = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(result)
    return result


COL = reset_owned_collection()
STONE = make_material("EXT_StoneCharcoal", (0.105, 0.125, 0.165, 1.0))
EDGE = make_material("EXT_StoneColdEdge", (0.17, 0.205, 0.27, 1.0))
ASH = make_material("EXT_AshRock", (0.075, 0.075, 0.09, 1.0))
BARK = make_material("EXT_DeadBark", (0.09, 0.055, 0.045, 1.0))


def own(obj, role: str):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj["courtyard_role"] = role
    if obj.data is not None and obj.data.users > 1:
        obj.data = obj.data.copy()
    return obj


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def add_box(name, position, dimensions, material, role, yaw: float = 0.0):
    bpy.ops.mesh.primitive_cube_add(location=to_blender(position), rotation=(0.0, 0.0, yaw))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply_transform(obj)
    obj.data.materials.append(material)
    return own(obj, role)


def add_rock(name, position, scale, material, role, yaw: float = 0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=to_blender(position))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = (0.12, -0.15, yaw)
    apply_transform(obj)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return own(obj, role)


def join(parts, name: str, role: str):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result["courtyard_role"] = role
    return result


def collapsed_plinth(name, x: float, z: float, yaw: float):
    """A 2.0 m low plinth with a seated broken cap and verified 0.03 m overlap."""
    base_top = 0.22
    cap_bottom = 0.19
    parts = [
        add_box(name + "_Base", (x, base_top * 0.5, z), (1.95, base_top, 1.18), STONE, "collapsed_plinth", yaw),
        add_box(name + "_Cap", (x + 0.10, cap_bottom + 0.16, z - 0.08), (1.20, 0.32, 0.58), EDGE, "collapsed_plinth", yaw - 0.20),
        add_rock(name + "_RubbleA", (x - 0.82, 0.19, z + 0.42), (0.34, 0.25, 0.20), STONE, "collapsed_plinth", yaw + 0.30),
        add_rock(name + "_RubbleB", (x + 0.72, 0.15, z - 0.46), (0.28, 0.21, 0.16), EDGE, "collapsed_plinth", yaw - 0.36),
    ]
    overlap = base_top - cap_bottom
    assert overlap >= 0.03
    print(f"EXTC_CONTACT {name} cap_to_base overlap={overlap:.3f}m")
    return join(parts, name, "collapsed_plinth")


def fallen_column(name, x: float, z: float, yaw: float):
    """A deliberately horizontal column fragment, capped by physically seated stone."""
    shaft_top = 0.34
    cap_bottom = 0.30
    parts = [
        add_box(name + "_Shaft", (x, shaft_top * 0.5, z), (2.35, shaft_top, 0.38), STONE, "fallen_column", yaw),
        add_box(name + "_Cap", (x + 0.94, cap_bottom + 0.17, z + 0.08), (0.52, 0.34, 0.64), EDGE, "fallen_column", yaw + 0.08),
        add_rock(name + "_Chip", (x - 1.02, 0.13, z - 0.34), (0.25, 0.18, 0.14), EDGE, "fallen_column", yaw + 0.42),
    ]
    overlap = shaft_top - cap_bottom
    assert overlap >= 0.03
    print(f"EXTC_CONTACT {name} cap_to_shaft overlap={overlap:.3f}m")
    return join(parts, name, "fallen_column")


def thorn_cluster(name, x: float, z: float, height: float):
    parts = [add_box(name + "_Root", (x, 0.08, z), (0.42, 0.16, 0.36), ASH, "thorn_cluster", 0.18)]
    for index, (dx, dz, tilt) in enumerate([(-0.20, 0.06, -0.28), (0.16, -0.10, 0.24), (0.04, 0.20, 0.10)]):
        parts.append(add_box(name + f"_Stem{index}", (x + dx, height * 0.5, z + dz), (0.08, height, 0.08), BARK, "thorn_cluster", tilt))
    return join(parts, name, "thorn_cluster")


def placement_scene(placements):
    lines = [f"[gd_scene load_steps={len(placements) + 1} format=3]", ""]
    for index, (name, _position) in enumerate(placements, start=1):
        lines.append(f'[ext_resource type="PackedScene" path="res://assets/exterior_courtyard_pieces/{name}.glb" id="piece_{index:02d}"]')
    lines += [
        "",
        '[node name="ExteriorCourtyardDressing" type="Node3D"]',
        'editor_description = "南側外牆與外圍斷牆之間的低矮崩塌前庭。每個直接子節點都是獨立 GLB，可逐件調整；純視覺，無碰撞、無導航、無互動。"',
        "",
    ]
    for index, (name, position) in enumerate(placements, start=1):
        x, y, z = (number(value) for value in position)
        lines += [
            f'[node name="{name}" parent="." instance=ExtResource("piece_{index:02d}")]',
            f"position = Vector3({x}, {y}, {z})",
        ]
    return "\n".join(lines) + "\n"


def export_assets():
    for obj in COL.objects:
        if obj.type != "MESH":
            continue
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
        world_position = to_godot(obj.location.copy())
        apply_transform(obj)
        obj.location = (0.0, 0.0, 0.0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=str(PIECES_DIR / f"{obj.name}.glb"), export_format="GLB", use_selection=True, export_yup=True, export_apply=True)
        placements.append((obj.name, world_position))
    SCENE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SCENE_OUTPUT.write_text(placement_scene(placements), encoding="utf-8")
    return placements


def build():
    # Visible south-court band: the playable south boundary ends at z=5.6 and
    # the existing ruin line is at z=9.0.  Keep every silhouette low (<=0.55m)
    # so the camera still reads the dungeon wall and player clearly.
    collapsed_plinth("EXTC_CollapsedPlinth_00", -4.65, 7.55, 0.16)
    fallen_column("EXTC_FallenColumn_00", -0.55, 7.72, -0.18)
    collapsed_plinth("EXTC_CollapsedPlinth_01", 3.45, 7.48, -0.10)
    fallen_column("EXTC_FallenColumn_01", 8.12, 7.76, 0.24)
    thorn_cluster("EXTC_ThornCluster_00", -6.85, 8.05, 0.62)
    thorn_cluster("EXTC_ThornCluster_01", 5.82, 8.18, 0.58)

    for index, (x, z, sx, sz, yaw) in enumerate([
        (-8.2, 7.48, 0.72, 0.40, 0.16), (-2.55, 8.36, 0.56, 0.32, -0.24),
        (1.48, 7.30, 0.64, 0.36, 0.10), (6.72, 8.36, 0.58, 0.34, -0.18),
        (10.35, 7.44, 0.68, 0.38, 0.28),
    ]):
        add_rock(f"EXTC_Rubble_{index:02d}", (x, 0.12, z), (sx, sz, 0.20), STONE if index % 2 == 0 else EDGE, "courtyard_rubble", yaw)

    for index, (x, z, width, depth, yaw) in enumerate([
        (-7.05, 8.72, 1.00, 0.48, -0.12), (-3.0, 8.78, 0.92, 0.44, 0.20),
        (2.05, 8.75, 1.04, 0.46, -0.16), (9.45, 8.62, 0.98, 0.45, 0.12),
    ]):
        add_rock(f"EXTC_Paver_{index:02d}", (x, 0.028, z), (width, depth, 0.034), EDGE, "courtyard_paver", yaw)

    assert all(obj.type == "MESH" for obj in COL.objects)
    placements = export_assets()
    print(f"EXTC_BUILD_OK collection={COLLECTION_NAME} pieces={len(placements)} master_output={MASTER_OUTPUT} pieces_dir={PIECES_DIR} scene={SCENE_OUTPUT} collisions=0")


build()
