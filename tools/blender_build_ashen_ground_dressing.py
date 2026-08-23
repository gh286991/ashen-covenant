"""Build a layered, editable ground-dressing pass around the dungeon exterior.

This pass intentionally owns only its collection.  It fills the broad empty
areas around the existing ruins, cliffs, graves and viaduct without touching
the playable dungeon, its collisions, navigation or combat entities.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


COLLECTION_NAME = "CODEX_AshenGroundDressingV1"
REPO_ROOT = Path(__file__).resolve().parents[1]
MASTER_OUTPUT = REPO_ROOT / "assets" / "ashen_ground_dressing_v1.glb"
PIECES_DIR = REPO_ROOT / "assets" / "exterior_ground_pieces"
SCENE_OUTPUT = REPO_ROOT / "levels" / "exterior_ground_editable_pieces.tscn"


def make_material(name: str, color, *, metallic: float = 0.0, roughness: float = 0.9):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    bsdf = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return material


def to_blender(position):
    """Convert authored x/z/y-up coordinates to Blender's x/y/z axes."""
    x, godot_z, godot_y = position
    return Vector((x, -godot_z, godot_y))


def to_godot(position):
    return (position.x, position.z, -position.y)


def number(value: float) -> str:
    value_text = f"{value:.5f}".rstrip("0").rstrip(".")
    return value_text if value_text else "0"


def reset_owned_collection():
    old = bpy.data.collections.get(COLLECTION_NAME)
    if old is not None:
        for obj in list(old.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(old)
    collection = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(collection)
    return collection


COL = reset_owned_collection()
STONE = make_material("EXT_StoneCharcoal", (0.105, 0.125, 0.165, 1.0))
EDGE = make_material("EXT_StoneColdEdge", (0.17, 0.205, 0.27, 1.0))
ASH = make_material("EXT_AshRock", (0.075, 0.075, 0.09, 1.0))
BARK = make_material("EXT_DeadBark", (0.09, 0.055, 0.045, 1.0))
IRON = make_material("EXT_TarnishedIron", (0.04, 0.055, 0.07, 1.0), metallic=0.72, roughness=0.62)


def own(obj, role: str):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj["ground_role"] = role
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
    # dimensions use game axes: width X, depth Z and height Y.
    obj.dimensions = dimensions
    apply_transform(obj)
    obj.data.materials.append(material)
    return own(obj, role)


def add_rock(name, position, scale, material, role, yaw: float = 0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=to_blender(position))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = (0.10, -0.16, yaw)
    apply_transform(obj)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return own(obj, role)


def add_cylinder_between(name, start, end, radius_start, radius_end, material, role, vertices: int = 7):
    start_v = to_blender(start)
    end_v = to_blender(end)
    delta = end_v - start_v
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_start,
        radius2=radius_end,
        depth=delta.length,
        location=(start_v + end_v) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(delta.normalized())
    apply_transform(obj)
    obj.data.materials.append(material)
    return own(obj, role)


def join(parts, name: str, role: str):
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    result = bpy.context.object
    result.name = name
    result["ground_role"] = role
    return result


def add_road_slab(name, position, width: float, depth: float, yaw: float):
    # Flattened faceted stones read as broken road remnants, not perfect tiles.
    return add_rock(name, (position[0], position[1], 0.028), (width, depth, 0.035), EDGE, "road_remnant", yaw)


def add_ash_patch(name, position, width: float, depth: float, yaw: float):
    return add_box(name, (position[0], position[1], 0.011), (width, depth, 0.022), ASH, "ash_patch", yaw)


def add_thorn_shrub(name, position, height: float, lean: float):
    x, z, _y = position
    top = (x + lean, z, height)
    parts = [add_cylinder_between(name + "_Stem", (x, z, 0.02), top, 0.13, 0.055, BARK, "thorn_shrub", 6)]
    for index, (fraction, dx, dz, dy) in enumerate([
        (0.46, -0.52, 0.18, 0.34), (0.63, 0.46, -0.15, 0.42), (0.78, -0.32, -0.26, 0.31),
    ]):
        anchor = (x + lean * fraction, z, height * fraction)
        parts.append(
            add_cylinder_between(
                name + "_Thorn_%d" % index,
                anchor,
                (anchor[0] + dx, anchor[1] + dz, anchor[2] + dy),
                0.055,
                0.018,
                BARK,
                "thorn_shrub",
                5,
            )
        )
    return join(parts, name, "thorn_shrub")


def add_cairn(name, position, scale: float, yaw: float):
    x, z, _y = position
    parts = []
    for index, (dx, dz, height, rock_scale, material) in enumerate([
        (-0.28, -0.08, 0.16, (0.38, 0.28, 0.18), STONE),
        (0.22, 0.02, 0.18, (0.34, 0.25, 0.20), EDGE),
        (-0.02, 0.22, 0.12, (0.26, 0.20, 0.14), STONE),
        (0.04, 0.04, 0.44, (0.28, 0.22, 0.16), EDGE),
    ]):
        parts.append(
            add_rock(
                name + "_Stone_%d" % index,
                (x + dx * scale, z + dz * scale, height * scale),
                tuple(value * scale for value in rock_scale),
                material,
                "trail_cairn",
                yaw + index * 0.32,
            )
        )
    return join(parts, name, "trail_cairn")


def add_broken_fence(name, start, end):
    """Build a short collapsed rail with numerically seated post connections."""
    start_v = Vector((start[0], start[1]))
    end_v = Vector((end[0], end[1]))
    direction = (end_v - start_v).normalized()
    post_height = 1.10
    post_radius = 0.105
    rail_height = 0.61
    # Rail deliberately overlaps each post by 0.035 m so there is no floating gap.
    rail_start = start_v - direction * 0.035
    rail_end = end_v + direction * 0.035
    parts = [
        add_cylinder_between(name + "_PostA", (start_v.x, start_v.y, 0.0), (start_v.x, start_v.y, post_height), post_radius, post_radius * 0.72, BARK, "broken_fence", 6),
        add_cylinder_between(name + "_PostB", (end_v.x, end_v.y, 0.0), (end_v.x, end_v.y, post_height * 0.78), post_radius, post_radius * 0.72, BARK, "broken_fence", 6),
        add_cylinder_between(name + "_Rail", (rail_start.x, rail_start.y, rail_height), (rail_end.x, rail_end.y, rail_height - 0.12), 0.065, 0.052, BARK, "broken_fence", 6),
    ]
    spike_anchor = start_v.lerp(end_v, 0.72)
    parts.append(add_cylinder_between(name + "_IronBrace", (spike_anchor.x, spike_anchor.y, 0.09), (spike_anchor.x + 0.23, spike_anchor.y - 0.10, 0.58), 0.035, 0.025, IRON, "broken_fence", 5))
    contact_overlap = 0.035
    print(f"EXTG_CONTACT {name} rail_to_posts overlap={contact_overlap:.3f}m")
    return join(parts, name, "broken_fence")


def placement_scene(placements):
    lines = [f"[gd_scene load_steps={len(placements) + 1} format=3]", ""]
    for index, (name, _position) in enumerate(placements, start=1):
        lines.append(f'[ext_resource type="PackedScene" path="res://assets/exterior_ground_pieces/{name}.glb" id="piece_{index:02d}"]')
    lines.extend([
        "",
        '[node name="AshenGroundDressing" type="Node3D"]',
        'editor_description = "可逐件調整的地下城外圍地表層：殘存石路、灰土、碎石、荊棘灌木、路標石塚與破欄。所有直接子節點都是獨立 GLB，無碰撞、無導航、無互動，且只放在主地下城投影外。"',
        "",
    ])
    for index, (name, position) in enumerate(placements, start=1):
        x, y, z = (number(value) for value in position)
        lines.append(f'[node name="{name}" parent="." instance=ExtResource("piece_{index:02d}")]')
        lines.append(f"position = Vector3({x}, {y}, {z})")
    return "\n".join(lines) + "\n"


def export_assets():
    for obj in COL.objects:
        if obj.type != "MESH":
            continue
        if obj.data.users > 1:
            obj.data = obj.data.copy()
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
        bpy.ops.export_scene.gltf(
            filepath=str(PIECES_DIR / f"{obj.name}.glb"),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=True,
        )
        placements.append((obj.name, world_position))
    SCENE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SCENE_OUTPUT.write_text(placement_scene(placements), encoding="utf-8")
    return placements


def build():
    # Four exterior layers, all in non-playable ground:
    # 1) south approach (z 7.4–12.6) just before the cliff apron;
    # 2) north shrine/viaduct approach (z < -22); 3) main-room west/east
    # shoulders; 4) narrow branch shoulders.  Paths are intentionally broken
    # and offset, while only low detail fills the spaces between larger ruins.
    south_slabs = [
        (-12.1, 7.55, 0.16), (-8.6, 8.18, -0.11), (-5.2, 7.72, 0.05), (-1.5, 8.55, -0.18),
        (2.0, 8.10, 0.12), (5.7, 8.72, -0.09), (9.1, 8.00, 0.18), (12.8, 8.52, -0.12),
        (16.2, 7.90, 0.06), (19.9, 8.50, -0.16), (23.5, 7.92, 0.14), (27.1, 8.48, -0.08),
        (30.8, 7.85, 0.11), (34.3, 8.42, -0.15),
    ]
    for index, (x, z, yaw) in enumerate(south_slabs):
        add_road_slab(f"EXTG_SouthRoad_{index:02d}", (x, z, 0), 1.02 + (index % 3) * 0.15, 0.58 + (index % 2) * 0.10, yaw)
    for index, (x, z, yaw) in enumerate([(-9.4, 10.8, 0.2), (-2.4, 11.2, -0.16), (6.4, 10.75, 0.12), (15.4, 11.05, -0.2), (24.0, 10.8, 0.18), (32.2, 11.25, -0.10)]):
        add_ash_patch(f"EXTG_SouthAsh_{index:02d}", (x, z, 0), 2.2, 0.52, yaw)
    for index, (x, z, size, yaw) in enumerate([(-13.5, 9.6, 0.60, 0.3), (-6.8, 10.1, 0.46, -0.2), (0.5, 9.8, 0.54, 0.1), (8.4, 10.3, 0.48, -0.4), (17.2, 9.65, 0.62, 0.24), (25.5, 10.15, 0.52, -0.1), (34.4, 9.55, 0.55, 0.38)]):
        add_rock(f"EXTG_SouthLooseStone_{index:02d}", (x, z, 0.15 * size), (size, size * 0.72, size * 0.35), STONE, "south_loose_stone", yaw)
    for index, (x, z, height, lean) in enumerate([(-15.0, 11.1, 1.10, 0.18), (3.4, 11.9, 0.95, -0.13), (21.3, 11.55, 1.22, 0.16), (37.0, 11.0, 1.08, -0.16)]):
        add_thorn_shrub(f"EXTG_SouthThorn_{index:02d}", (x, z, 0), height, lean)
    add_broken_fence("EXTG_SouthFence_00", (-11.4, 12.15), (-8.2, 12.32))
    add_broken_fence("EXTG_SouthFence_01", (27.4, 12.22), (30.6, 12.02))

    # North remains a distant shrine/viaduct silhouette, but the broken road
    # gives it a reason to exist rather than leaving isolated landmark props.
    north_slabs = [(0.6, -24.6, 0.18), (4.2, -25.2, -0.10), (7.7, -25.7, 0.06), (11.1, -26.2, -0.17), (14.7, -26.65, 0.12), (18.1, -26.1, -0.08), (21.7, -25.55, 0.15), (25.2, -24.9, -0.12)]
    for index, (x, z, yaw) in enumerate(north_slabs):
        add_road_slab(f"EXTG_NorthRoad_{index:02d}", (x, z, 0), 0.92 + (index % 2) * 0.17, 0.50 + (index % 3) * 0.06, yaw)
    for index, (x, z, size, yaw) in enumerate([(-8.2, -24.6, 0.62, -0.2), (-1.8, -25.6, 0.48, 0.14), (16.2, -27.1, 0.60, -0.12), (28.5, -25.3, 0.52, 0.25), (34.5, -26.8, 0.56, -0.28)]):
        add_rock(f"EXTG_NorthLooseStone_{index:02d}", (x, z, 0.14 * size), (size, size * 0.70, size * 0.33), EDGE, "north_loose_stone", yaw)
    add_cairn("EXTG_NorthCairn_00", (-4.1, -25.9, 0), 1.0, 0.2)
    add_cairn("EXTG_NorthCairn_01", (23.8, -26.4, 0), 0.92, -0.3)
    add_thorn_shrub("EXTG_NorthThorn_00", (34.0, -24.6, 0), 1.18, -0.18)

    # Main shoulder debris puts a believable collapsed perimeter on the two
    # sides without encroaching on the room projection.
    side_specs = [
        ("West", -16.3, -4.25), ("West", -17.15, -0.6), ("West", -16.55, 3.15),
        ("East", 40.4, -4.0), ("East", 41.25, -0.45), ("East", 40.65, 3.35),
    ]
    for index, (side, x, z) in enumerate(side_specs):
        add_rock(f"EXTG_Main{side}Stone_{index:02d}", (x, z, 0.20), (0.70, 0.50, 0.28), STONE if index % 2 == 0 else EDGE, "main_shoulder_stone", index * 0.34)
        add_ash_patch(f"EXTG_Main{side}Ash_{index:02d}", (x + (0.55 if side == "West" else -0.55), z + 0.55, 0), 1.55, 0.42, index * 0.16)
    add_thorn_shrub("EXTG_MainWestThorn_00", (-17.45, 1.85, 0), 0.94, 0.12)
    add_thorn_shrub("EXTG_MainEastThorn_00", (41.72, 1.55, 0), 1.02, -0.15)

    # Branch shoulders link the middle dungeon to the existing far ruins.
    branch_specs = [(-10.1, -18.7), (-10.7, -14.2), (-9.8, -9.2), (29.5, -18.4), (30.2, -13.9), (29.3, -9.5)]
    for index, (x, z) in enumerate(branch_specs):
        add_rock(f"EXTG_BranchStone_{index:02d}", (x, z, 0.18), (0.62, 0.44, 0.26), EDGE if index % 2 else STONE, "branch_shoulder_stone", index * 0.28)
    add_cairn("EXTG_BranchCairn_West", (-11.2, -16.2, 0), 0.86, -0.12)
    add_cairn("EXTG_BranchCairn_East", (30.7, -16.0, 0), 0.90, 0.16)
    add_broken_fence("EXTG_BranchFence_West", (-10.9, -11.9), (-10.5, -9.3))
    add_broken_fence("EXTG_BranchFence_East", (30.2, -12.4), (30.6, -9.8))

    assert all(obj.type == "MESH" for obj in COL.objects)
    placements = export_assets()
    print(
        f"EXTG_BUILD_OK collection={COLLECTION_NAME} pieces={len(placements)} "
        f"master_output={MASTER_OUTPUT} pieces_dir={PIECES_DIR} scene={SCENE_OUTPUT} collisions=0"
    )


build()
