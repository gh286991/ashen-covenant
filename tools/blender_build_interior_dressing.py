"""Build editable, gameplay-safe interior dressing for the dungeon.

The main dungeon geometry is intentionally left alone.  This generator owns a
single Blender collection, exports a master preview GLB plus one GLB per prop,
and writes the Godot wrapper scene with the placement transforms on its direct
children.  All props are visual only: the level keeps its existing collisions,
navigation and combat routes.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


COLLECTION_NAME = "CODEX_InteriorDressingV1"
REPO_ROOT = Path(__file__).resolve().parents[1]
MASTER_OUTPUT = REPO_ROOT / "assets" / "interior_dressing_v1.glb"
PIECES_DIR = REPO_ROOT / "assets" / "interior_pieces"
SCENE_OUTPUT = REPO_ROOT / "levels" / "interior_editable_dressing.tscn"


def material(name: str, color, *, metallic: float = 0.0, roughness: float = 0.88):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def godot_to_blender(position):
    """Convert authored (x, z, y-up) coordinates into Blender coordinates."""
    x, godot_z, godot_y = position
    return Vector((x, -godot_z, godot_y))


def blender_to_godot(position):
    return (position.x, position.z, -position.y)


def fmt(value: float) -> str:
    text = f"{value:.5f}".rstrip("0").rstrip(".")
    return text if text else "0"


def rotate_ground(offset, angle: float):
    """Rotate an X/Z ground-plane Vector without relying on Blender API sugar."""
    cosine = math.cos(angle)
    sine = math.sin(angle)
    return Vector((offset.x * cosine - offset.y * sine, offset.x * sine + offset.y * cosine))


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
STONE = material("INT_StoneSoot", (0.11, 0.13, 0.16, 1.0))
EDGE = material("INT_StoneEdge", (0.20, 0.25, 0.30, 1.0))
WOOD = material("INT_DecayedWood", (0.14, 0.075, 0.045, 1.0))
BONE = material("INT_BoneDust", (0.43, 0.42, 0.36, 1.0))
IRON = material("INT_TarnishedIron", (0.09, 0.11, 0.13, 1.0), metallic=0.72, roughness=0.58)
STAIN = material("INT_OldBlood", (0.18, 0.035, 0.04, 1.0), roughness=0.96)


def own(obj, role: str):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj["interior_role"] = role
    if obj.data is not None and obj.data.users > 1:
        obj.data = obj.data.copy()
    return obj


def apply_transform(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def add_box(name, position, dimensions, mat, role, angle: float = 0.0):
    bpy.ops.mesh.primitive_cube_add(location=godot_to_blender(position), rotation=(0.0, 0.0, angle))
    obj = bpy.context.object
    obj.name = name
    # dimensions use game axes: width X, depth Z, height Y.
    obj.dimensions = dimensions
    apply_transform(obj)
    obj.data.materials.append(mat)
    return own(obj, role)


def add_rock(name, position, scale, mat, role, angle: float = 0.0):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=godot_to_blender(position))
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = (0.13, -0.21, angle)
    apply_transform(obj)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return own(obj, role)


def add_cylinder_between(name, start, end, radius_start, radius_end, mat, role, vertices: int = 7):
    start_v = godot_to_blender(start)
    end_v = godot_to_blender(end)
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
    obj.data.materials.append(mat)
    return own(obj, role)


def join(objects, name, role):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj["interior_role"] = role
    return obj


def rubble_cluster(name, position, scale: float = 1.0, angle: float = 0.0):
    x, z, _y = position
    specs = [
        (-0.34, -0.12, 0.16, (0.40, 0.30, 0.17), STONE),
        (0.19, -0.06, 0.20, (0.34, 0.25, 0.20), EDGE),
        (-0.04, 0.28, 0.12, (0.28, 0.22, 0.13), STONE),
        (0.38, 0.22, 0.09, (0.19, 0.16, 0.10), EDGE),
    ]
    parts = []
    for index, (dx, dz, height, rock_scale, mat) in enumerate(specs):
        parts.append(
            add_rock(
                f"{name}_Stone_{index}",
                (x + dx * scale, z + dz * scale, height * scale),
                tuple(value * scale for value in rock_scale),
                mat,
                "rubble_cluster",
                angle + index * 0.41,
            )
        )
    # Keep each stone as its own imported GLB.  This is deliberately more
    # granular than a joined scatter mesh, so a level designer can move one
    # loose rock in Godot without disturbing the rest of the accumulation.
    return parts


def bone_scatter(name, position, angle: float = 0.0):
    x, z, _y = position
    specs = [
        ((-0.34, -0.10), (0.33, 0.08), 0.07),
        ((-0.18, 0.28), (0.22, -0.28), 0.06),
        ((0.10, -0.30), (0.40, -0.12), 0.055),
    ]
    parts = []
    for index, (start_offset, end_offset, radius) in enumerate(specs):
        start = Vector(start_offset)
        end = Vector(end_offset)
        # Rotate each bone in the ground plane around its scatter centre.
        start = rotate_ground(start, angle)
        end = rotate_ground(end, angle)
        parts.append(
            add_cylinder_between(
                f"{name}_Bone_{index}",
                (x + start.x, z + start.y, 0.075),
                (x + end.x, z + end.y, 0.075),
                radius,
                radius * 0.82,
                BONE,
                "bone_scatter",
                7,
            )
        )
    return parts


def fallen_beam(name, position, length: float, angle: float):
    x, z, _y = position
    beam = add_box(name + "_Timber", (x, z, 0.18), (length, 0.34, 0.28), WOOD, "fallen_beam", angle)
    cap = add_rock(name + "_Splinter", (x + length * 0.39, z + 0.08, 0.20), (0.25, 0.18, 0.16), EDGE, "fallen_beam", angle + 0.33)
    return join([beam, cap], name, "fallen_beam")


def crate(name, position, angle: float = 0.0):
    x, z, _y = position
    body = add_box(name + "_Body", (x, z, 0.38), (0.78, 0.66, 0.72), WOOD, "supply_crate", angle)
    band_a = add_box(name + "_BandA", (x, z - 0.22, 0.39), (0.82, 0.07, 0.76), IRON, "supply_crate", angle)
    band_b = add_box(name + "_BandB", (x, z + 0.22, 0.39), (0.82, 0.07, 0.76), IRON, "supply_crate", angle)
    return join([body, band_a, band_b], name, "supply_crate")


def broken_column(name, position, angle: float = 0.0):
    x, z, _y = position
    base = add_box(name + "_Base", (x, z, 0.12), (0.86, 0.72, 0.20), EDGE, "broken_column", angle)
    shaft = add_cylinder_between(name + "_Shaft", (x - 0.12, z - 0.15, 0.19), (x + 0.42, z + 0.23, 0.38), 0.24, 0.20, STONE, "broken_column", 8)
    cap = add_rock(name + "_Cap", (x + 0.56, z + 0.32, 0.30), (0.35, 0.26, 0.16), EDGE, "broken_column", angle + 0.45)
    return join([base, shaft, cap], name, "broken_column")


def chain_pile(name, position):
    x, z, _y = position
    parts = []
    for index, (dx, dz, rotation) in enumerate([(-0.26, -0.08, 0.1), (0.04, 0.11, -0.38), (0.31, -0.06, 0.28)]):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.18,
            minor_radius=0.045,
            major_segments=8,
            minor_segments=4,
            location=godot_to_blender((x + dx, z + dz, 0.065 + index * 0.012)),
            rotation=(0.0, 0.0, rotation),
        )
        ring = bpy.context.object
        ring.name = f"{name}_Link_{index}"
        ring.data.materials.append(IRON)
        parts.append(own(ring, "chain_pile"))
    return join(parts, name, "chain_pile")


def floor_stain(name, position, dimensions, mat=STAIN, angle: float = 0.0):
    x, z, _y = position
    return add_box(name, (x, z, 0.012), (dimensions[0], dimensions[1], 0.024), mat, "floor_stain", angle)


def placement_lines(placements):
    lines = [f"[gd_scene load_steps={len(placements) + 2} format=3]", ""]
    lines.append('[ext_resource type="Script" path="res://scripts/interior_dressing_style_3d.gd" id="1_style"]')
    for index, (name, _position) in enumerate(placements, start=1):
        lines.append(f'[ext_resource type="PackedScene" path="res://assets/interior_pieces/{name}.glb" id="piece_{index:02d}"]')
    lines.extend([
        "",
        '[node name="InteriorDressing" type="Node3D"]',
        'editor_description = "室內純視覺敘事層：牆根崩塌、供物殘骸、骨骸、斷柱、鏈條與地面痕跡。每個直接子節點都是獨立 GLB，可在此場景或 dungeon_grid_map.tscn 逐件移動、旋轉、縮放、隱藏或替換；無碰撞、無導航、無互動。"',
        'script = ExtResource("1_style")',
        "",
    ])
    for index, (name, position) in enumerate(placements, start=1):
        x, y, z = (fmt(value) for value in position)
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
    bpy.ops.export_scene.gltf(
        filepath=str(MASTER_OUTPUT),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
    )

    PIECES_DIR.mkdir(parents=True, exist_ok=True)
    placements = []
    for obj in sorted(COL.objects, key=lambda item: item.name):
        local_position = blender_to_godot(obj.location.copy())
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
        placements.append((obj.name, local_position))
    SCENE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    SCENE_OUTPUT.write_text(placement_lines(placements), encoding="utf-8")
    return placements


def build():
    # Layout rules:
    # - rooms remain readable and have a clean centre / door-to-door lane;
    # - visual density gathers in corners and against existing walls;
    # - only paper-thin stains enter the central floor, therefore no gameplay
    #   collision or path changes are introduced.
    # Room A – a recently looted entry crypt, with a broken supply corner.
    rubble_cluster("INT_A_WallRubble_00", (-11.05, -3.25, 0), 1.10)
    rubble_cluster("INT_A_WallRubble_01", (-10.95, 3.28, 0), 0.92, 0.6)
    rubble_cluster("INT_A_WallRubble_02", (-4.66, 3.26, 0), 0.86, 1.1)
    fallen_beam("INT_A_FallenBeam_00", (-10.55, 1.42, 0), 1.74, 0.38)
    crate("INT_A_SupplyCrate_00", (-10.85, -1.32, 0), 0.12)
    bone_scatter("INT_A_BoneScatter_00", (-10.12, -2.25, 0), 0.24)
    bone_scatter("INT_A_BoneScatter_01", (-5.10, 2.52, 0), -0.42)
    floor_stain("INT_A_DustTrail_00", (-7.45, -1.80, 0), (2.45, 0.40), STONE, 0.13)
    floor_stain("INT_A_DustTrail_01", (-8.62, 2.02, 0), (1.60, 0.34), STONE, -0.27)

    # Room B – a maintained ritual chamber: intentional clutter at the altar
    # perimeter, but never in the two opposing doorway lanes.
    rubble_cluster("INT_B_WallRubble_00", (8.45, -3.28, 0), 0.88, 0.2)
    rubble_cluster("INT_B_WallRubble_01", (15.13, -3.23, 0), 1.05, -0.35)
    rubble_cluster("INT_B_WallRubble_02", (8.60, 3.24, 0), 0.96, 0.7)
    broken_column("INT_B_BrokenColumn_00", (14.48, 3.18, 0), -0.55)
    chain_pile("INT_B_ChainPile_00", (8.92, -2.28, 0))
    chain_pile("INT_B_ChainPile_01", (14.68, 2.38, 0))
    bone_scatter("INT_B_BoneScatter_00", (10.02, 2.86, 0), 0.58)
    floor_stain("INT_B_AshRing_00", (11.84, -2.05, 0), (1.36, 0.42), STONE, 0.0)
    floor_stain("INT_B_AshRing_01", (11.84, 2.06, 0), (1.36, 0.42), STONE, 0.0)

    # Room C – the bloodworks gets darker, low lying evidence rather than
    # more tall props that would hide combat silhouettes.
    rubble_cluster("INT_C_WallRubble_00", (28.46, -3.26, 0), 1.10, 0.28)
    rubble_cluster("INT_C_WallRubble_01", (34.55, -3.28, 0), 0.92, -0.46)
    rubble_cluster("INT_C_WallRubble_02", (28.42, 3.24, 0), 0.86, 0.58)
    broken_column("INT_C_BrokenColumn_00", (33.82, 3.18, 0), 0.42)
    fallen_beam("INT_C_FallenBeam_00", (27.98, 1.58, 0), 1.42, -0.28)
    bone_scatter("INT_C_BoneScatter_00", (34.08, -2.08, 0), -0.48)
    chain_pile("INT_C_ChainPile_00", (28.92, 2.45, 0))
    floor_stain("INT_C_OldStain_00", (31.52, -2.28, 0), (2.38, 0.72), STAIN, 0.18)
    floor_stain("INT_C_OldStain_01", (32.62, 1.92, 0), (1.62, 0.48), STAIN, -0.22)

    # Corridors have narrow, believable accumulation at their walls but keep
    # the one-tile centreline visually legible for the player and enemies.
    rubble_cluster("INT_AB_RubbleNorth_00", (0.48, -1.34, 0), 0.54, 0.1)
    rubble_cluster("INT_AB_RubbleSouth_00", (3.36, 1.34, 0), 0.50, -0.6)
    bone_scatter("INT_AB_BoneScatter_00", (2.03, -1.10, 0), 0.10)
    floor_stain("INT_AB_DustTrace_00", (1.98, 0.54, 0), (2.46, 0.20), STONE, 0.0)
    rubble_cluster("INT_BC_RubbleNorth_00", (20.22, -1.34, 0), 0.52, -0.18)
    rubble_cluster("INT_BC_RubbleSouth_00", (23.08, 1.34, 0), 0.55, 0.40)
    chain_pile("INT_BC_ChainPile_00", (21.96, -1.10, 0))
    floor_stain("INT_BC_DustTrace_00", (21.72, 0.54, 0), (2.28, 0.20), STONE, 0.0)

    assert all(obj.type == "MESH" for obj in COL.objects)
    placements = export_assets()
    print(
        f"INTERIOR_BUILD_OK collection={COLLECTION_NAME} pieces={len(placements)} "
        f"master_output={MASTER_OUTPUT} pieces_dir={PIECES_DIR} scene={SCENE_OUTPUT} collisions=0"
    )


build()
