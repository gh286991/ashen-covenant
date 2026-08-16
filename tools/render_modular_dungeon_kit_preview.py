"""Render temporary multi-angle verification previews for the extracted kit.

This only changes the in-memory scene passed to Blender and does not save it.
"""

from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parent.parent
PREVIEW_DIR = PROJECT_ROOT / "assets" / "3d_dungeon" / "kit" / "previews"
KIT_COLLECTION = bpy.data.collections["DUNGEON_MODULAR_KIT"]


def look_at(node: bpy.types.Object, target: Vector) -> None:
	node.rotation_euler = (target - node.location).to_track_quat("-Z", "Y").to_euler()


def add_area_light(name: str, location: tuple[float, float, float], energy: float, size: float) -> None:
	light_data = bpy.data.lights.new(name, "AREA")
	light_data.energy = energy
	light_data.shape = "DISK"
	light_data.size = size
	light = bpy.data.objects.new(name, light_data)
	bpy.context.scene.collection.objects.link(light)
	light.location = location
	look_at(light, Vector((4.0, 2.0, 1.5)))


def main() -> None:
	PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
	kit_objects = set(KIT_COLLECTION.all_objects)
	for obj in bpy.context.scene.objects:
		obj.hide_render = obj not in kit_objects

	placements = {
		"KIT_floor_block_3p9": (0.0, 0.0, 0.0),
		"KIT_wall_straight_2p6": (5.0, 0.0, 0.0),
		"KIT_wall_corner_2p6": (0.0, 5.0, 0.0),
		"KIT_doorway_3p6": (5.2, 5.0, 0.0),
		"KIT_pillar_crypt": (9.5, 0.0, 0.0),
		"KIT_altar_coffin": (9.5, 5.5, 0.0),
		"KIT_brazier_blue": (12.5, 0.5, 0.0),
	}
	for name, position in placements.items():
		bpy.data.objects[name].location = position

	scene = bpy.context.scene
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x = 1000
	scene.render.resolution_y = 700
	scene.render.resolution_percentage = 100
	scene.render.image_settings.file_format = "PNG"
	scene.world.color = (0.025, 0.035, 0.06)

	bpy.ops.mesh.primitive_plane_add(size=28, location=(5.0, 2.5, -0.02))
	ground = bpy.context.object
	ground.name = "TEMP_PREVIEW_GROUND"
	ground.hide_render = False
	ground_material = bpy.data.materials.new("TEMP_PREVIEW_GROUND_MAT")
	ground_material.diffuse_color = (0.04, 0.055, 0.08, 1.0)
	ground.data.materials.append(ground_material)

	add_area_light("TEMP_PREVIEW_KEY", (6.0, -5.0, 12.0), 1700.0, 7.0)
	add_area_light("TEMP_PREVIEW_FILL", (-6.0, 8.0, 7.0), 900.0, 6.0)

	camera_data = bpy.data.cameras.new("TEMP_PREVIEW_CAMERA")
	camera = bpy.data.objects.new("TEMP_PREVIEW_CAMERA", camera_data)
	bpy.context.scene.collection.objects.link(camera)
	scene.camera = camera
	target = Vector((5.0, 2.5, 1.7))
	views = {
		"kit_reference": (15.0, -16.0, 15.0),
		"kit_side": (18.0, 2.5, 5.5),
		"kit_front_left": (-8.0, -13.0, 10.0),
		"kit_top": (5.0, 2.5, 24.0),
	}
	for name, location in views.items():
		camera.location = location
		look_at(camera, target)
		scene.render.filepath = str(PREVIEW_DIR / (name + ".png"))
		bpy.ops.render.render(write_still=True)
		print("KIT_PREVIEW_OK", name)


main()
