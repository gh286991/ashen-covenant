"""Make a shared-palette 128px four-direction walk sprite from baked PNG frames."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "assets/raw/player_3d_walk_4dir_8f"
FRAME_DIR = RAW_DIR / "frames"
RAW_SHEET_PATH = RAW_DIR / "raw-sheet.png"
OUT_DIR = ROOT / "assets/sprites/player_3d_walk"

CELL_SIZE = 128
ROWS = 4
COLS = 8
PALETTE_COLORS = 64
DIRECTIONS = ("down", "left", "right", "up")


def source_path(index: int) -> Path:
    return FRAME_DIR / f"frame_{index:03d}.png"


def assemble_raw_sheet() -> tuple[Image.Image, tuple[int, int]]:
    frames = [Image.open(source_path(index)).convert("RGBA") for index in range(ROWS * COLS)]
    if len({frame.size for frame in frames}) != 1:
        raise ValueError("All source renders must have the same dimensions")
    width, height = frames[0].size
    sheet = Image.new("RGBA", (width * COLS, height * ROWS))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((index % COLS) * width, (index // COLS) * height))
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(RAW_SHEET_PATH)
    return sheet, (width, height)


def extract_processed_frames() -> list[Image.Image]:
    sheet = Image.open(OUT_DIR / "sheet.png").convert("RGBA")
    if sheet.size != (CELL_SIZE * COLS, CELL_SIZE * ROWS):
        raise ValueError(f"Expected a {CELL_SIZE * COLS}x{CELL_SIZE * ROWS} processed sheet, found {sheet.size}")
    return [
        sheet.crop(((index % COLS) * CELL_SIZE, (index // COLS) * CELL_SIZE, (index % COLS + 1) * CELL_SIZE, (index // COLS + 1) * CELL_SIZE))
        for index in range(ROWS * COLS)
    ]


def quantize_shared_palette(frames: list[Image.Image]) -> tuple[list[Image.Image], list[tuple[int, int, int]]]:
    combined = Image.new("RGB", (CELL_SIZE * COLS, CELL_SIZE * ROWS), (12, 13, 18))
    for index, frame in enumerate(frames):
        combined.paste(frame.convert("RGB"), ((index % COLS) * CELL_SIZE, (index // COLS) * CELL_SIZE), frame.getchannel("A"))
    indexed = combined.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palette = indexed.getpalette()[: PALETTE_COLORS * 3]
    colors = [tuple(palette[offset:offset + 3]) for offset in range(0, len(palette), 3)]
    quantized_rgb = indexed.convert("RGB")
    output: list[Image.Image] = []
    for index, frame in enumerate(frames):
        left = (index % COLS) * CELL_SIZE
        top = (index // COLS) * CELL_SIZE
        color = quantized_rgb.crop((left, top, left + CELL_SIZE, top + CELL_SIZE))
        color.putalpha(frame.getchannel("A"))
        output.append(color)
    return output, colors


def edge_touch(frame: Image.Image, margin: int = 2) -> bool:
    alpha = frame.getchannel("A")
    width, height = frame.size
    edge_regions = (
        alpha.crop((0, 0, width, margin)),
        alpha.crop((0, height - margin, width, height)),
        alpha.crop((0, 0, margin, height)),
        alpha.crop((width - margin, 0, width, height)),
    )
    return any(region.getbbox() is not None for region in edge_regions)


def write_final_assets(frames: list[Image.Image], palette: list[tuple[int, int, int]], source_cell: tuple[int, int]) -> None:
    final_frames = OUT_DIR / "frames"
    final_frames.mkdir(parents=True, exist_ok=True)
    final_sheet = Image.new("RGBA", (CELL_SIZE * COLS, CELL_SIZE * ROWS))
    for index, frame in enumerate(frames):
        frame.save(final_frames / f"frame_{index:03d}.png")
        final_sheet.alpha_composite(frame, ((index % COLS) * CELL_SIZE, (index // COLS) * CELL_SIZE))
    final_sheet.save(OUT_DIR / "sheet.png")
    for row, direction in enumerate(DIRECTIONS):
        strip = final_sheet.crop((0, row * CELL_SIZE, final_sheet.width, (row + 1) * CELL_SIZE))
        strip.save(OUT_DIR / f"walk_{direction}.png")
    preview_frames: list[Image.Image] = []
    for column in range(COLS):
        preview = Image.new("RGBA", (CELL_SIZE * ROWS, CELL_SIZE))
        for row in range(ROWS):
            preview.alpha_composite(frames[row * COLS + column], (row * CELL_SIZE, 0))
        preview_frames.append(preview)
    preview_frames[0].save(
        OUT_DIR / "walk-preview.gif",
        save_all=True,
        append_images=preview_frames[1:],
        duration=100,
        loop=0,
        disposal=2,
    )

    metadata = {
        "input": str(RAW_SHEET_PATH.relative_to(ROOT)),
        "grid": {"rows": ROWS, "cols": COLS, "source_cell": list(source_cell), "output_cell": CELL_SIZE},
        "directions": list(DIRECTIONS),
        "frames_per_direction": COLS,
        "anchor": "feet",
        "palette": {"mode": "shared global median-cut", "colors_requested": PALETTE_COLORS, "colors": ["#%02X%02X%02X" % color for color in palette]},
        "frames": [
            {"index": index, "row": index // COLS, "col": index % COLS, "source_bbox": frame.getchannel("A").getbbox(), "edge_touch": edge_touch(frame)}
            for index, frame in enumerate(frames)
        ],
        "valid": not any(edge_touch(frame) for frame in frames),
        "edge_margin": 2,
    }
    (OUT_DIR / "pipeline-meta.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assemble-only", action="store_true", help="Write the 4x8 raw sheet, then stop before final processing.")
    args = parser.parse_args()
    missing = [path for path in (source_path(index) for index in range(ROWS * COLS)) if not path.is_file()]
    if missing:
        raise FileNotFoundError(f"Missing baked frame: {missing[0]}")
    _, source_cell = assemble_raw_sheet()
    if args.assemble_only:
        print(json.dumps({"output": str(RAW_SHEET_PATH), "source_cell": list(source_cell)}))
        return
    frames = extract_processed_frames()
    quantized, palette = quantize_shared_palette(frames)
    write_final_assets(quantized, palette, source_cell)
    print(json.dumps({"output": str(OUT_DIR), "frames": len(quantized), "palette_colors": len(palette)}))


if __name__ == "__main__":
    main()
