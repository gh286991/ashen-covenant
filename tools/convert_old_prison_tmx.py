#!/usr/bin/env python3
"""Convert the purchased Old Prison Tiled map into Godot TileMapLayer cell data.

The generated JSON deliberately keeps the Tiled layer structure and the original
32px grid. A small Godot build step then writes real TileMapLayer tile_map_data
into a .tscn, so the game does not depend on a baked map image.
"""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TMX_PATH = PROJECT_ROOT / "assets/old_prison/source/TiledMap Editor New/Old Prison example map.tmx"
OUTPUT_PATH = PROJECT_ROOT / "data/old_prison_tiled_layers.json"


def load_tileset_catalog(root: ET.Element) -> dict[int, dict[str, int | str]]:
    catalog: dict[int, dict[str, int | str]] = {}
    source_map = {
        "Tilesets/Tileset - wall 1.tsx": (0, "wall_1"),
        "Tilesets/Tileset - wall 2.tsx": (1, "wall_2"),
        "Tilesets/Tileset-Terrain-old prison.tsx": (2, "terrain"),
        "Tilesets/Blood pool - style2 - with spikes - transparency.tsx": (3, "blood"),
        "Tilesets/atlas-props.tsx": (4, "props_atlas"),
    }
    for tileset in root.findall("tileset"):
        firstgid = int(tileset.attrib["firstgid"])
        source = tileset.attrib.get("source", "")
        if source not in source_map:
            continue
        source_path = TMX_PATH.parent / source
        tsx_root = ET.parse(source_path).getroot()
        image = tsx_root.find("image")
        if image is None:
            continue
        catalog[firstgid] = {
            "source": source_map[source][0],
            "name": source_map[source][1],
            "tilecount": int(tsx_root.attrib["tilecount"]),
            "columns": int(tsx_root.attrib["columns"]),
            "tilewidth": int(tsx_root.attrib["tilewidth"]),
            "tileheight": int(tsx_root.attrib["tileheight"]),
        }
    return catalog


def resolve_gid(gid: int, catalog: dict[int, dict[str, int | str]]) -> tuple[int, int, int] | None:
    candidates = [firstgid for firstgid in catalog if firstgid <= gid]
    if not candidates:
        return None
    firstgid = max(candidates)
    entry = catalog[firstgid]
    local_id = gid - firstgid
    if local_id < 0 or local_id >= int(entry["tilecount"]):
        return None
    columns = int(entry["columns"])
    return int(entry["source"]), local_id % columns, local_id // columns


def convert() -> None:
    root = ET.parse(TMX_PATH).getroot()
    width = int(root.attrib["width"])
    height = int(root.attrib["height"])
    catalog = load_tileset_catalog(root)
    layers: list[dict[str, object]] = []
    skipped: dict[str, int] = {}

    for layer_index, layer in enumerate(root.findall("layer")):
        data = layer.find("data")
        if data is None:
            continue
        values = [int(value.strip()) for value in (data.text or "").replace("\n", "").split(",") if value.strip()]
        cells: list[dict[str, int]] = []
        for index, gid in enumerate(values):
            if gid == 0:
                continue
            resolved = resolve_gid(gid, catalog)
            if resolved is None:
                skipped[layer.attrib["name"]] = skipped.get(layer.attrib["name"], 0) + 1
                continue
            source_id, atlas_x, atlas_y = resolved
            cells.append({
                "x": index % width,
                "y": index // width,
                "source": source_id,
                "atlas_x": atlas_x,
                "atlas_y": atlas_y,
            })
        layers.append({
            "name": layer.attrib["name"],
            "order": layer_index,
            "cells": cells,
        })

    payload = {
        "source": "EPIC RPG World Pack - Old Prison V1.7.1 / Old Prison example map.tmx",
        "tile_size": 32,
        "width": width,
        "height": height,
        "layers": layers,
        "skipped_unavailable_tiles": skipped,
    }
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    total_cells = sum(len(layer["cells"]) for layer in layers)
    print(f"Wrote {OUTPUT_PATH.relative_to(PROJECT_ROOT)}: {len(layers)} layers, {total_cells} cells")
    if skipped:
        print(f"Skipped unavailable Tiled tiles: {skipped}")


if __name__ == "__main__":
    convert()
