"""Render the actual 3D player Walk action into high-resolution source frames.

Run this with Blender, not the system Python:

    /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
      --python tools/bake_warrior_walk_3d.py

The output stays unquantized under assets/raw/.  The ordinary Python post-process
then normalizes it to the game's 128px sprite format and applies one shared palette.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
MODEL_PATH = ROOT / "assets/models/animated/fantasy_warrior_gameplay_head_level.glb"
RAW_DIR = ROOT / "assets/raw/player_3d_walk_4dir_8f"
FRAME_DIR = RAW_DIR / "frames"

FRAME_SIZE = 512
FRAMES_PER_DIRECTION = 8
# Game direction order: south/down, west/left, east/right, north/up.
DIRECTIONS = (
    ("down", 0.0),
    ("left", math.radians(-90.0)),
    ("right", math.radians(90.0)),
    ("up", math.radians(180.0)),
)


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def add_area_light(location: tuple[float, float, float], color: tuple[float, float, float], energy: float, size: float) -> None:
    light_data = bpy.data.lights.new("SpriteBakeLight", "AREA")
    light_data.energy = energy
    light_data.color = color
    light_data.shape = "DISK"
    light_data.size = size
    light = bpy.data.objects.new("SpriteBakeLight", light_data)
    bpy.context.collection.objects.link(light)
    light.location = location
    look_at(light, Vector((0.0, 0.0, 0.75)))


def setup_rendering() -> bpy.types.Scene:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = FRAME_SIZE
    scene.render.resolution_y = FRAME_SIZE
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.film_transparent = True

    scene.world.color = (0.04, 0.05, 0.07)
    scene.view_settings.look = "AgX - Medium High Contrast"
    add_area_light((3.0, -4.0, 5.5), (1.0, 0.76, 0.62), 900.0, 4.0)
    add_area_light((-4.0, -1.0, 3.5), (0.52, 0.64, 1.0), 350.0, 3.5)

    camera_data = bpy.data.cameras.new("SpriteBakeCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.55
    camera = bpy.data.objects.new("SpriteBakeCamera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (2.45, -4.65, 3.2)
    look_at(camera, Vector((0.0, 0.0, 0.78)))
    scene.camera = camera
    return scene


def import_warrior() -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Action]:
    existing_objects = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(MODEL_PATH))
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one armature, found {len(armatures)}")
    armature = armatures[0]
    if armature.animation_data is None:
        armature.animation_data_create()
    walk = bpy.data.actions.get("Walk")
    if walk is None:
        raise RuntimeError("The 3D player model does not contain a Walk action")
    armature.animation_data.action = walk

    pivot = bpy.data.objects.new("SpriteBakePivot", None)
    bpy.context.collection.objects.link(pivot)
    imported_roots = [obj for obj in bpy.context.scene.objects if obj is not pivot and obj not in existing_objects and obj.parent is None]
    for obj in imported_roots:
        obj.parent = pivot
        obj.matrix_parent_inverse = pivot.matrix_world.inverted()
    return armature, pivot, walk


def render_frames(scene: bpy.types.Scene, pivot: bpy.types.Object, action: bpy.types.Action) -> None:
    FRAME_DIR.mkdir(parents=True, exist_ok=True)
    first, last = action.frame_range
    sampled_frames = [first + (last - first) * index / FRAMES_PER_DIRECTION for index in range(FRAMES_PER_DIRECTION)]
    for direction_index, (_, angle) in enumerate(DIRECTIONS):
        pivot.rotation_euler = (0.0, 0.0, angle)
        for animation_index, frame in enumerate(sampled_frames):
            scene.frame_set(math.floor(frame), subframe=frame % 1.0)
            bpy.context.view_layer.update()
            frame_index = direction_index * FRAMES_PER_DIRECTION + animation_index
            scene.render.filepath = str(FRAME_DIR / f"frame_{frame_index:03d}.png")
            bpy.ops.render.render(write_still=True)


def main() -> None:
    if not MODEL_PATH.is_file():
        raise FileNotFoundError(MODEL_PATH)
    clear_scene()
    scene = setup_rendering()
    _, pivot, action = import_warrior()
    render_frames(scene, pivot, action)
    metadata = {
        "source_model": str(MODEL_PATH.relative_to(ROOT)),
        "action": action.name,
        "source_frame_size": FRAME_SIZE,
        "frames_per_direction": FRAMES_PER_DIRECTION,
        "directions": [name for name, _ in DIRECTIONS],
        "camera": "orthographic three-quarter",
        "background": "transparent",
        "color_processing": "none; retained as source renders",
    }
    (RAW_DIR / "render-meta.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(RAW_DIR), "frames": len(DIRECTIONS) * FRAMES_PER_DIRECTION}))


if __name__ == "__main__":
    main()
