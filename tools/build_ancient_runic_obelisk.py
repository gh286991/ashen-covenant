"""Build Ancient Runic Obelisk 3D model with textured skin.

Run with:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_ancient_runic_obelisk.py
"""

import math
from pathlib import Path
import bpy
import bmesh
from mathutils import Matrix

PROJECT_ROOT = Path(__file__).resolve().parent.parent
TEXTURE_PATH = PROJECT_ROOT / "assets" / "models" / "arena" / "runic_obelisk_albedo.png"
OUTPUT_GLB = PROJECT_ROOT / "assets" / "models" / "arena" / "ancient_runic_obelisk.glb"


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in (
        bpy.data.objects,
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.textures,
        bpy.data.images,
    ):
        for item in list(block):
            block.remove(item)


def create_obelisk_mesh() -> bpy.types.Object:
    mesh = bpy.data.meshes.new("AncientRunicObelisk_Mesh")
    obj = bpy.data.objects.new("AncientRunicObelisk", mesh)
    bpy.context.collection.objects.link(obj)

    bm = bmesh.new()

    # Base Tier 1: Wide octagonal foundation
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.95,
        radius2=0.95,
        depth=0.3,
        matrix=Matrix.Translation((0, 0, 0.15)),
    )

    # Base Tier 2: Stepped pedestal
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.75,
        radius2=0.75,
        depth=0.35,
        matrix=Matrix.Translation((0, 0, 0.475)),
    )

    # Obelisk Shaft: Tapering octagonal pillar
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.55,
        radius2=0.32,
        depth=2.2,
        matrix=Matrix.Translation((0, 0, 1.75)),
    )

    # Capital ring: Decorative trim between shaft and tip
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=8,
        radius1=0.38,
        radius2=0.38,
        depth=0.15,
        matrix=Matrix.Translation((0, 0, 2.925)),
    )

    # Pyramidion Capstone / Crystal Spire
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=True,
        segments=8,
        radius1=0.34,
        radius2=0.0,
        depth=0.75,
        matrix=Matrix.Translation((0, 0, 3.375)),
    )

    # 4 Corner Guardian Plinths / Runestones around base
    corner_radius = 0.88
    for i in range(4):
        angle = i * (math.pi / 2.0) + (math.pi / 4.0)
        cx = corner_radius * math.cos(angle)
        cy = corner_radius * math.sin(angle)
        bmesh.ops.create_cube(
            bm,
            size=0.28,
            matrix=Matrix.Translation((cx, cy, 0.35)),
        )

    bm.to_mesh(mesh)
    bm.free()

    for poly in mesh.polygons:
        poly.use_smooth = True

    return obj


def setup_uv_and_material(obj: bpy.types.Object):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)

    # Smart UV project
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")

    # Create Material
    mat = bpy.data.materials.new("M_AncientRunicObelisk")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    bsdf = nodes.get("Principled BSDF")
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")

    # Load Texture
    if TEXTURE_PATH.exists():
        tex_image = bpy.data.images.load(str(TEXTURE_PATH))
        tex_node = nodes.new("ShaderNodeTexImage")
        tex_node.image = tex_image

        # Connect Base Color
        links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

        # Connect to Emission for glowing runes
        if "Emission Color" in bsdf.inputs:
            links.new(tex_node.outputs["Color"], bsdf.inputs["Emission Color"])
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 1.25
        elif "Emission" in bsdf.inputs:
            links.new(tex_node.outputs["Color"], bsdf.inputs["Emission"])

    # PBR Settings
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = 0.82
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.15

    obj.data.materials.append(mat)


def export_glb(output_path: Path):
    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path),
        export_format="GLB",
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_apply=True,
    )
    print(f"SUCCESS: Exported {output_path} (Size: {output_path.stat().st_size} bytes)")


def main():
    clear_scene()
    obj = create_obelisk_mesh()
    setup_uv_and_material(obj)
    export_glb(OUTPUT_GLB)


if __name__ == "__main__":
    main()
