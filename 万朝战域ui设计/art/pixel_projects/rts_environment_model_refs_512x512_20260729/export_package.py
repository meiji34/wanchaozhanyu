#!/usr/bin/env python3
"""导出建模参考 PNG、调色板和清单压缩包。"""

from __future__ import annotations

import json
import re
import shutil
import struct
from pathlib import Path

from PIL import Image


PROJECT_DIR = Path(__file__).resolve().parent
ASSET_DIR = PROJECT_DIR / "assets" / "backgrounds"
EXPORT_NAME = "rts_environment_model_refs_20260729"
EXPORT_DIR = PROJECT_DIR / "exports" / EXPORT_NAME
ZIP_PATH = PROJECT_DIR / "exports" / f"{EXPORT_NAME}.zip"


def _read_palette() -> list[str]:
    spec = (PROJECT_DIR / "spec_lock.md").read_text(encoding="utf-8")
    return re.findall(r"^\s+-\s+(#[0-9A-Fa-f]{6})\s*$", spec, re.MULTILINE)


def _write_palettes(colors: list[str], output_dir: Path) -> None:
    rgb_colors = [
        tuple(int(color[index : index + 2], 16) for index in (1, 3, 5))
        for color in colors
    ]

    gpl_lines = [
        "GIMP Palette",
        "Name: Three Kingdoms Natural Terrain 48",
        "Columns: 8",
        "#",
    ]
    gpl_lines.extend(
        f"{red:3d} {green:3d} {blue:3d}\t{hex_color}"
        for (red, green, blue), hex_color in zip(rgb_colors, colors)
    )
    (output_dir / "three_kingdoms_natural_terrain_48.gpl").write_text(
        "\n".join(gpl_lines) + "\n",
        encoding="utf-8",
    )

    pal_lines = ["JASC-PAL", "0100", str(len(rgb_colors))]
    pal_lines.extend(
        f"{red} {green} {blue}" for red, green, blue in rgb_colors
    )
    (output_dir / "three_kingdoms_natural_terrain_48.pal").write_text(
        "\n".join(pal_lines) + "\n",
        encoding="ascii",
    )

    act_colors = rgb_colors + [(0, 0, 0)] * (256 - len(rgb_colors))
    act_data = bytes(channel for color in act_colors for channel in color)
    act_data += struct.pack(">HH", len(rgb_colors), 0xFFFF)
    (output_dir / "three_kingdoms_natural_terrain_48.act").write_bytes(
        act_data
    )


def main() -> None:
    if EXPORT_DIR.exists() or ZIP_PATH.exists():
        raise FileExistsError(
            f"Export already exists; refusing to overwrite: {EXPORT_DIR}"
        )

    sprite_dir = EXPORT_DIR / "sprites"
    sheet_dir = EXPORT_DIR / "sheets"
    palette_dir = EXPORT_DIR / "palettes"
    note_dir = EXPORT_DIR / "notes"
    for directory in (sprite_dir, sheet_dir, palette_dir, note_dir):
        directory.mkdir(parents=True, exist_ok=False)

    manifest_assets: list[dict[str, object]] = []
    for asset_path in sorted(ASSET_DIR.glob("*.png")):
        shutil.copy2(asset_path, sprite_dir / asset_path.name)
        image = Image.open(asset_path).convert("RGBA")
        opaque_colors = {
            pixel[:3] for pixel in image.getdata() if pixel[3] > 0
        }
        manifest_assets.append(
            {
                "name": asset_path.stem,
                "file": f"sprites/{asset_path.name}",
                "width": image.width,
                "height": image.height,
                "colors": len(opaque_colors),
                "alpha": "binary",
                "animation": "none",
                "kind": (
                    "master_sheet"
                    if asset_path.stem.endswith("_multiview")
                    else "modeling_view"
                ),
            }
        )

    for master_name in (
        "rts_ancient_pine_multiview.png",
        "rts_mountains_multiview.png",
    ):
        shutil.copy2(ASSET_DIR / master_name, sheet_dir / master_name)

    for note_path in sorted((PROJECT_DIR / "notes").glob("*.md")):
        shutil.copy2(note_path, note_dir / note_path.name)

    shutil.copy2(PROJECT_DIR / "design_spec.md", EXPORT_DIR / "design_spec.md")
    shutil.copy2(PROJECT_DIR / "spec_lock.md", EXPORT_DIR / "spec_lock.md")

    palette = _read_palette()
    _write_palettes(palette, palette_dir)

    manifest = {
        "project": "rts_environment_model_refs",
        "version": "2026-07-29",
        "target": ["Blender modeling reference", "Godot 4.7.1"],
        "palette": {
            "name": "Three Kingdoms Natural Terrain 48",
            "colors": palette,
        },
        "tree_sheet": {
            "layout": "3x2",
            "cell_size": [512, 512],
            "view_order": [
                "front",
                "right",
                "rear",
                "left",
                "top",
                "isometric",
            ],
        },
        "mountain_sheet": {
            "layout": "3x4",
            "cell_size": [512, 512],
            "columns": ["sharp_peak", "long_ridge", "rounded_cluster"],
            "rows": ["front", "side", "top", "isometric"],
        },
        "assets": manifest_assets,
    }
    (EXPORT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    shutil.make_archive(
        str(ZIP_PATH.with_suffix("")),
        "zip",
        root_dir=EXPORT_DIR,
    )
    print(f"Exported: {EXPORT_DIR}")
    print(f"Archive: {ZIP_PATH}")


if __name__ == "__main__":
    main()
