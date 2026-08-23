"""Build the non-playable Ashen Approach exterior dressing in Blender.

Run through Blender MCP so the asset remains reproducible.  The script only
owns objects in COLLECTION_NAME, leaves every other collection untouched, and
exports just its generated meshes to a Godot-ready GLB.
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


COLLECTION_NAME = "CODEX_AshenExteriorV1"
REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = REPO_ROOT / "assets" / "ashen_exterior_dressing_v1.glb"
PIECES_OUTPUT_DIR = REPO_ROOT / "assets" / "exterior_pieces"
PIECES_SCENE_OUTPUT = REPO_ROOT / "levels" / "exterior_editable_pieces.tscn"


def material(name: str, color: tuple[float, float, float, float], *, emission=None, strength=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    # Blender localizes node display names; node.type stays stable.
    bsdf = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = 0.88
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = strength
    return mat


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
STONE = material("EXT_StoneCharcoal", (0.105, 0.125, 0.165, 1.0))
STONE_EDGE = material("EXT_StoneColdEdge", (0.17, 0.205, 0.27, 1.0))
ASH = material("EXT_AshRock", (0.075, 0.075, 0.09, 1.0))
BARK = material("EXT_DeadBark", (0.09, 0.055, 0.045, 1.0))
RUNE = material(
    "EXT_SoulRune",
    (0.02, 0.24, 0.36, 1.0),
    emission=(0.015, 0.48, 0.82, 1.0),
    strength=3.8,
)


def to_blender(position):
    """Convert Godot-like authoring coordinates (x, z, y-up) to Blender."""
    x, godot_z, godot_y = position
    return (x, -godot_z, godot_y)


def own(obj, role: str):
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    COL.objects.link(obj)
    obj["exterior_role"] = role
    if obj.data is not None and getattr(obj.data, "users", 1) > 1:
        obj.data = obj.data.copy()
    return obj


def apply_transform(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def add_box(name, location, dimensions, mat, role, rotation=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(location=to_blender(location), rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    apply_transform(obj)
    obj.data.materials.append(mat)
    return own(obj, role)


def add_rock(name, location, scale, rotation, mat=ASH, role="cliff_rock"):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=to_blender(location), rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply_transform(obj)
    obj.data.materials.append(mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return own(obj, role)


def add_cylinder_between(name, start, end, radius_start, radius_end, mat, role, vertices=7):
    start_v = Vector(to_blender(start))
    end_v = Vector(to_blender(end))
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


def join_objects(objects, name, role):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    joined["exterior_role"] = role
    normalize_material_slots(joined)
    return joined


def normalize_material_slots(obj):
    if obj.type != "MESH":
        return
    old_materials = list(obj.data.materials)
    if not old_materials:
        return
    unique_materials = []
    old_to_new = {}
    for old_index, mat in enumerate(old_materials):
        if mat not in unique_materials:
            unique_materials.append(mat)
        old_to_new[old_index] = unique_materials.index(mat)
    old_indices = [polygon.material_index for polygon in obj.data.polygons]
    obj.data.materials.clear()
    for mat in unique_materials:
        obj.data.materials.append(mat)
    for polygon, old_index in zip(obj.data.polygons, old_indices):
        polygon.material_index = old_to_new[old_index]


def compact_static_modules():
    groups = [
        ("EXT_SouthCliffLine", "south_cliff_line", lambda o: o.name.startswith("EXT_SouthCliff")),
        ("EXT_GraveGroveWest", "grave_grove", lambda o: o.name.startswith("EXT_GraveMarker_0") and int(o.name.rsplit("_", 1)[1]) < 3),
        ("EXT_GraveGroveEast", "grave_grove", lambda o: o.name.startswith("EXT_GraveMarker_0") and int(o.name.rsplit("_", 1)[1]) >= 3),
        ("EXT_DeadTreesSouth", "dead_tree_grove", lambda o: o.name in {"EXT_DeadTree_00", "EXT_DeadTree_01"}),
        ("EXT_DeadTreesNorth", "dead_tree_grove", lambda o: o.name in {"EXT_DeadTree_02", "EXT_DeadTree_03"}),
        ("EXT_BrokenViaduct", "broken_viaduct", lambda o: o.name.startswith("EXT_Viaduct")),
        ("EXT_RuneObeliskField", "rune_obelisk_field", lambda o: o.name.startswith("EXT_Obelisk")),
        ("EXT_NorthCairns", "cairn_field", lambda o: o.name.startswith("EXT_Cairn")),
    ]
    for module_name, role, predicate in groups:
        matches = [obj for obj in list(COL.objects) if predicate(obj)]
        if matches:
            join_objects(matches, module_name, role)


def _godot_position(blender_location):
    """Convert the authored Blender location back to Godot X/Y/Z."""
    return (blender_location.x, blender_location.z, -blender_location.y)


def _godot_number(value: float) -> str:
    """Write deterministic, compact numeric values for a .tscn file."""
    text = f"{value:.6f}".rstrip("0").rstrip(".")
    return text if text else "0"


def write_editable_piece_scene(placements):
    """Generate the Godot wrapper with one directly transformable child per GLB."""
    PIECES_SCENE_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"[gd_scene load_steps={len(placements) + 1} format=3]", ""]
    for index, (name, _position) in enumerate(placements, start=1):
        lines.append(
            f'[ext_resource type="PackedScene" path="res://assets/exterior_pieces/{name}.glb" id="piece_{index:02d}"]'
        )
    lines.extend(
        [
            "",
            '[node name="AshenExteriorDressing" type="Node3D"]',
            'editor_description = "可逐件調整的灰燼前庭外圍。每個直接子節點各自實例化一個 GLB，原點已對齊物件本身；可在此場景或 dungeon_grid_map.tscn 直接選取、移動、旋轉、縮放、隱藏或替換。"',
            "",
        ]
    )
    for index, (name, position) in enumerate(placements, start=1):
        x, y, z = (_godot_number(value) for value in position)
        lines.append(f'[node name="{name}" parent="." instance=ExtResource("piece_{index:02d}")]')
        lines.append(f"position = Vector3({x}, {y}, {z})")
    PIECES_SCENE_OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")


def export_editable_piece_files():
    """Export every authored object as its own Godot-ready GLB scene.

    Godot treats each file as an independent PackedScene instance, so a level
    designer can select and transform one rock, gravestone, tree, bridge
    segment, obelisk, or cairn without entering an imported master GLB.
    """
    PIECES_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exported = []
    placements = []
    for obj in sorted(COL.objects, key=lambda item: item.name):
        # The shipping master GLB keeps its authored transforms.  Individual
        # editor pieces instead have a mesh-local origin, with their world
        # placement stored on the direct Godot child node.  This keeps the
        # transform gizmo and selection bounds tight around one prop.
        godot_position = _godot_position(obj.location.copy())
        apply_transform(obj)
        obj.location = (0.0, 0.0, 0.0)
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        output_path = PIECES_OUTPUT_DIR / f"{obj.name}.glb"
        bpy.ops.export_scene.gltf(
            filepath=str(output_path),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=True,
        )
        exported.append(output_path)
        placements.append((obj.name, godot_position))
    bpy.ops.object.select_all(action="DESELECT")
    write_editable_piece_scene(placements)
    return exported


def add_dead_tree(index, base, height, lean=0.0):
    x, y, z = base
    crown = (x + lean, y, z + height)
    pieces = [
        add_cylinder_between(f"EXT_Tree_{index:02d}_Trunk", (x, y, z), crown, 0.42, 0.18, BARK, "dead_tree"),
    ]
    branch_specs = [
        (0.50, (-1.35, 0.15, 1.25), 0.18, 0.07),
        (0.63, (1.25, -0.2, 1.35), 0.16, 0.055),
        (0.77, (-0.85, -0.18, 1.1), 0.13, 0.045),
    ]
    for branch_index, (fraction, offset, r0, r1) in enumerate(branch_specs):
        anchor = Vector((x + lean * fraction, y, z + height * fraction))
        end = anchor + Vector(offset)
        pieces.append(
            add_cylinder_between(
                f"EXT_Tree_{index:02d}_Branch_{branch_index}",
                anchor - (end - anchor).normalized() * 0.08,
                end,
                r0,
                r1,
                BARK,
                "dead_tree",
                6,
            )
        )
    return join_objects(pieces, f"EXT_DeadTree_{index:02d}", "dead_tree")


def prism_mesh(name, rings, mat, role):
    vertices = []
    for ring in rings:
        z, radius = ring
        for i in range(4):
            angle = math.radians(45.0 + i * 90.0)
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, z))
    faces = []
    faces.append((0, 3, 2, 1))
    for ring_index in range(len(rings) - 1):
        start = ring_index * 4
        nxt = (ring_index + 1) * 4
        for side in range(4):
            faces.append((start + side, start + (side + 1) % 4, nxt + (side + 1) % 4, nxt + side))
    top = (len(rings) - 1) * 4
    faces.append((top, top + 1, top + 2, top + 3))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    COL.objects.link(obj)
    obj.data.materials.append(mat)
    obj["exterior_role"] = role
    return obj


def add_obelisk(index, location, height, rotation=0.0):
    body = prism_mesh(
        f"EXT_Obelisk_{index:02d}_Body",
        [(0.0, 0.68), (height * 0.78, 0.54), (height, 0.08)],
        STONE,
        "rune_obelisk",
    )
    body.location = to_blender(location)
    body.rotation_euler[2] = rotation
    rune = add_box(
        f"EXT_Obelisk_{index:02d}_Rune",
        (location[0], location[1] - 0.49, location[2] + height * 0.53),
        (0.12, 0.08, height * 0.28),
        RUNE,
        "rune_inlay",
        rotation=(0.0, 0.0, rotation),
    )
    return body, rune


def add_arch_segment(name, center, r_inner, r_outer, angle_a, angle_b, depth, mat):
    cx, cy, cz = center
    verts = []
    for y_offset in (-depth * 0.5, depth * 0.5):
        for radius in (r_inner, r_outer):
            for angle in (angle_a, angle_b):
                world = to_blender((cx + math.cos(angle) * radius, cy + y_offset, cz + math.sin(angle) * radius))
                origin = Vector(to_blender(center))
                verts.append(Vector(world) - origin)
    faces = [
        (0, 1, 3, 2), (4, 6, 7, 5),
        (0, 4, 5, 1), (2, 3, 7, 6),
        (0, 2, 6, 4), (1, 5, 7, 3),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    COL.objects.link(obj)
    obj.location = to_blender(center)
    obj.data.materials.append(mat)
    obj["exterior_role"] = "broken_viaduct"
    return obj


def add_broken_viaduct():
    center = (8.0, -29.4, 5.6)
    left = add_box("EXT_Viaduct_LeftPier", (5.35, -29.4, 2.95), (1.05, 1.3, 5.9), STONE, "broken_viaduct")
    right = add_box("EXT_Viaduct_RightPier", (10.65, -29.4, 2.95), (1.05, 1.3, 5.9), STONE, "broken_viaduct")
    segments = [left, right]
    angles = [(0.0, 0.38), (0.42, 0.82), (0.88, 1.18), (1.55, 1.92), (2.02, 2.38), (2.46, math.pi)]
    for index, (a0, a1) in enumerate(angles):
        segments.append(add_arch_segment(f"EXT_Viaduct_Arch_{index:02d}", center, 2.15, 3.05, a0, a1, 1.3, STONE_EDGE))
    top_blocks = [
        add_box("EXT_Viaduct_TopLeft", (3.9, -29.4, 6.25), (3.0, 1.3, 0.75), STONE, "broken_viaduct", rotation=(0.0, -0.06, 0.0)),
        add_box("EXT_Viaduct_TopRight", (12.0, -29.4, 6.3), (2.9, 1.3, 0.75), STONE, "broken_viaduct", rotation=(0.0, 0.05, 0.0)),
    ]
    segments.extend(top_blocks)
    for obj in segments:
        obj.data = obj.data.copy()
    # Numerical contact proof: the pier tops intentionally overlap the arch spring by 0.3 m.
    pier_top = left.location.z + left.dimensions.z * 0.5
    spring_height = center[2]
    print(f"EXT_CONTACT viaduct_pier_to_arch overlap={pier_top - spring_height:.3f}m")


def add_grave_marker(index, location, scale=1.0, angle=0.0):
    body = add_box(
        f"EXT_Grave_{index:02d}_Body",
        (location[0], location[1], location[2] + 0.7 * scale),
        (0.68 * scale, 0.28 * scale, 1.35 * scale),
        STONE,
        "grave_marker",
        rotation=(0.0, 0.0, angle),
    )
    cap = prism_mesh(
        f"EXT_Grave_{index:02d}_Cap",
        [(0.0, 0.42 * scale), (0.42 * scale, 0.06 * scale)],
        STONE_EDGE,
        "grave_marker",
    )
    cap.location = to_blender((location[0], location[1], location[2] + 1.33 * scale))
    cap.rotation_euler[2] = angle
    return join_objects([body, cap], f"EXT_GraveMarker_{index:02d}", "grave_marker")


def build():
    # Exterior-edge anatomy, measured from the south playable wall at z=5.6:
    #   1. a clear 4 m service gap; 2. a low rubble apron at z≈11–15;
    #   3. a 14–18 m broken scarp; 4. graves and dead trees beyond z≈20.
    # The scarp alternates depth by roughly one boulder diameter, so it reads
    # as a collapsed natural edge rather than a perfectly parallel stone row.
    # Every formation remains beyond z=9 in Godot space, leaving combat clear.
    cliff_specs = [
        (-17.0, 17.0, 0.8, 4.8, 2.4, 1.6), (-10.5, 15.4, 0.6, 4.0, 2.2, 1.3),
        (-3.0, 18.1, 0.7, 4.6, 2.5, 1.5), (5.0, 14.8, 0.9, 5.2, 2.6, 1.8),
        (13.0, 17.6, 0.65, 4.4, 2.3, 1.4), (21.0, 15.0, 0.75, 5.0, 2.5, 1.7),
        (29.0, 18.0, 0.7, 4.5, 2.4, 1.45), (37.0, 14.5, 0.8, 5.1, 2.7, 1.75),
        (44.0, 16.8, 0.55, 3.8, 2.2, 1.2),
    ]
    for index, (x, y, z, sx, sy, sz) in enumerate(cliff_specs):
        add_rock(
            f"EXT_SouthCliff_{index:02d}",
            (x, y, z),
            (sx, sy, sz),
            (0.12 * ((index % 3) - 1), 0.08 * (index % 2), 0.16 * ((index % 4) - 1.5)),
        )
        shard_specs = [(-1.15, -2.9, 0.28, (1.18, 0.84, 0.52)), (1.38, -3.65, 0.22, (0.92, 0.72, 0.42))]
        for shard, (offset_x, offset_z, shard_height, shard_scale) in enumerate(shard_specs):
            add_rock(
                f"EXT_SouthCliff_{index:02d}_Shard_{shard}",
                (x + offset_x, y + offset_z, shard_height),
                shard_scale,
                (0.1, 0.2, shard * 0.6 + index * 0.17),
                STONE,
                "cliff_shard",
            )

    # Two small, angled scarps on each side turn the south apron into a
    # believable perimeter without enclosing or visually invading the rooms.
    side_scarp_specs = [
        ("EXT_SideScarp_West_00", (-20.6, 7.4, 0.62), (2.35, 1.48, 1.05), (0.08, 0.12, -0.24)),
        ("EXT_SideScarp_West_01", (-19.6, -11.2, 0.54), (1.85, 1.32, 0.88), (-0.05, 0.16, 0.34)),
        ("EXT_SideScarp_East_00", (44.8, 7.4, 0.68), (2.45, 1.55, 1.12), (0.04, -0.14, 0.28)),
        ("EXT_SideScarp_East_01", (43.6, -11.8, 0.52), (1.75, 1.24, 0.84), (-0.08, 0.10, -0.30)),
    ]
    for name, location, scale, rotation in side_scarp_specs:
        add_rock(name, location, scale, rotation, STONE_EDGE, "side_scarp")

    # Grave grove sits behind the scarp, breaking the silhouette only at the
    # two deliberate cemetery clearings instead of forming a second straight row.
    grave_positions = [
        (-11.8, 21.7, 0.0, -0.10), (-8.6, 20.1, 0.0, 0.08), (-5.4, 22.8, 0.0, -0.04),
        (25.3, 20.9, 0.0, 0.08), (28.8, 22.7, 0.0, -0.08), (31.8, 19.8, 0.0, 0.05),
        (35.4, 21.9, 0.0, -0.05),
    ]
    for index, (x, y, z, angle) in enumerate(grave_positions):
        add_grave_marker(index, (x, y, z), 0.9 + (index % 3) * 0.1, angle)

    add_dead_tree(0, (-14.0, 23.6, 0.0), 5.8, 0.65)
    add_dead_tree(1, (39.0, 23.2, 0.0), 6.3, -0.55)
    add_dead_tree(2, (-12.0, -28.0, 0.0), 5.4, 0.45)
    add_dead_tree(3, (38.0, -28.5, 0.0), 5.9, -0.55)

    add_broken_viaduct()

    obelisk_specs = [(-2.0, -28.0, 0.0, 4.7, -0.08), (18.0, -29.0, 0.0, 5.4, 0.06), (31.0, -28.0, 0.0, 4.4, -0.05)]
    for index, (x, y, z, height, angle) in enumerate(obelisk_specs):
        add_obelisk(index, (x, y, z), height, angle)

    # Cairns tie the new silhouette back to the existing rubble language.
    for cairn in range(6):
        cx = -6.0 + cairn * 8.4
        cy = -27.4 - (cairn % 2) * 1.4
        for layer in range(3):
            add_rock(
                f"EXT_Cairn_{cairn:02d}_{layer}",
                (cx + (layer - 1) * 0.12, cy, 0.28 + layer * 0.42),
                (0.7 - layer * 0.14, 0.52 - layer * 0.08, 0.32),
                (0.06 * layer, 0.12, layer * 0.5),
                STONE_EDGE if layer == 2 else STONE,
                "cairn",
            )

    # Keep authored props as individual export nodes so level designers can
    # move, rotate, scale, hide, or override each piece independently in the
    # Godot editor.  The optional compact_static_modules() helper remains
    # available for a later shipping-only export profile.

    # Final cleanup: all meshes single-user, flat shaded, named and owned once.
    for obj in COL.objects:
        if obj.type == "MESH":
            if obj.data.users > 1:
                obj.data = obj.data.copy()
            for polygon in obj.data.polygons:
                polygon.use_smooth = False
            assert len(obj.users_collection) == 1 and obj.users_collection[0] == COL
        assert obj.type not in {"CAMERA", "LIGHT"}

    bpy.ops.object.select_all(action="DESELECT")
    for obj in COL.objects:
        obj.select_set(True)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUTPUT_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
    )
    piece_files = export_editable_piece_files()
    print(
        f"EXT_BUILD_OK collection={COLLECTION_NAME} editable_objects={len(COL.objects)} "
        f"master_output={OUTPUT_PATH} piece_files={len(piece_files)} "
        f"pieces_dir={PIECES_OUTPUT_DIR} cameras=0 lights=0"
    )


build()
