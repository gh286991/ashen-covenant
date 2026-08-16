#!/usr/bin/env python3
"""Create a Godot 4 TileSet atlas resource from the Old Prison atlases."""

from __future__ import annotations

from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = PROJECT_ROOT / "assets/old_prison/tiles/old_prison_tileset.tres"

ATLAS_SOURCES = [
    ("wall_1", "wall_1.png", 16, 23),
    ("wall_2", "wall_2.png", 16, 15),
    ("terrain", "terrain.png", 65, 69),
    ("blood", "blood.png", 31, 10),
    ("props_atlas", "props_atlas.png", 59, 46),
]


def build() -> None:
    lines = [
        "[gd_resource type=\"TileSet\" load_steps=11 format=3]",
        "",
    ]
    for index, (name, filename, columns, rows) in enumerate(ATLAS_SOURCES):
        lines.append(f"[ext_resource type=\"Texture2D\" path=\"res://assets/old_prison/tiles/{filename}\" id=\"{index + 1}_{name}\"]")
    lines.append("")
    for index, (name, _filename, columns, rows) in enumerate(ATLAS_SOURCES):
        lines.extend([
            f"[sub_resource type=\"TileSetAtlasSource\" id=\"TileSetAtlasSource_{name}\"]",
            f"texture = ExtResource(\"{index + 1}_{name}\")",
            "texture_region_size = Vector2i(32, 32)",
        ])
        for y in range(rows):
            for x in range(columns):
                lines.append(f"{x}:{y}/0 = 0")
        lines.append("")
    lines.extend([
        "[resource]",
        "tile_size = Vector2i(32, 32)",
        "sources/0 = SubResource(\"TileSetAtlasSource_wall_1\")",
        "sources/1 = SubResource(\"TileSetAtlasSource_wall_2\")",
        "sources/2 = SubResource(\"TileSetAtlasSource_terrain\")",
        "sources/3 = SubResource(\"TileSetAtlasSource_blood\")",
        "sources/4 = SubResource(\"TileSetAtlasSource_props_atlas\")",
        "metadata/source_pack = \"EPIC RPG World Pack - Old Prison V1.7.1\"",
        "metadata/tile_size_px = 32",
        "",
    ])
    OUTPUT_PATH.write_text("\n".join(lines))
    print(f"Wrote {OUTPUT_PATH.relative_to(PROJECT_ROOT)} with {sum(c * r for _, _, c, r in ATLAS_SOURCES)} atlas cells")


if __name__ == "__main__":
    build()
