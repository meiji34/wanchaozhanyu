#!/usr/bin/env python3
"""将生成源图重排为精确的多视图建模参考表。"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


PROJECT_DIR = Path(__file__).resolve().parent
IMAGE_DIR = PROJECT_DIR / "images"
OUTPUT_DIR = PROJECT_DIR / "assets" / "backgrounds"
CELL_SIZE = 512
OUTLINE_COLORS = ["#17151A", "#211C20", "#2B2526", "#332D2B"]
ROCK_COLORS = [
    "#3A3A38",
    "#454640",
    "#51534B",
    "#5E6055",
    "#6B6D60",
    "#797A6C",
    "#888779",
    "#979487",
    "#A7A295",
    "#B7B0A1",
    "#C6BDAA",
    "#D5CBB7",
]
EARTH_COLORS = [
    "#3A2A24",
    "#4A3328",
    "#5B3D2E",
    "#6C4935",
    "#7D563D",
    "#906747",
    "#A57955",
    "#BA8E67",
]
WOOD_COLORS = [
    "#2D1E1B",
    "#3B261F",
    "#4A2F24",
    "#59382A",
    "#684431",
    "#795139",
    "#8B6043",
    "#A0714F",
]
VEGETATION_COLORS = [
    "#1F2B22",
    "#293729",
    "#344632",
    "#40553B",
    "#4D6545",
    "#5B7650",
    "#6A875D",
    "#7A986B",
    "#8CAA79",
    "#9DBC88",
    "#AFCB98",
    "#C2D7AA",
]
MOSS_COLORS = ["#38443A", "#536050", "#707A64", "#909879"]
TREE_PALETTE = OUTLINE_COLORS + WOOD_COLORS + VEGETATION_COLORS + MOSS_COLORS
MOUNTAIN_PALETTE = (
    OUTLINE_COLORS
    + ROCK_COLORS
    + EARTH_COLORS
    + VEGETATION_COLORS[:8]
    + MOSS_COLORS
)


def _grid_bounds(length: int, count: int) -> list[int]:
    """使用四舍五入边界，完整覆盖不能整除的生成图尺寸。"""
    return [round(index * length / count) for index in range(count + 1)]


def _split_grid(
    source_path: Path,
    columns: int,
    rows: int,
    names: list[str],
    palette: list[str],
) -> list[Image.Image]:
    source = Image.open(source_path).convert("RGBA")
    x_bounds = _grid_bounds(source.width, columns)
    y_bounds = _grid_bounds(source.height, rows)
    max_cell_width = max(
        x_bounds[index + 1] - x_bounds[index] for index in range(columns)
    )
    max_cell_height = max(
        y_bounds[index + 1] - y_bounds[index] for index in range(rows)
    )
    scale = min(CELL_SIZE / max_cell_width, CELL_SIZE / max_cell_height)

    cells: list[Image.Image] = []
    for row in range(rows):
        for column in range(columns):
            source_cell = source.crop(
                (
                    x_bounds[column],
                    y_bounds[row],
                    x_bounds[column + 1],
                    y_bounds[row + 1],
                )
            )
            resized_size = (
                max(1, round(source_cell.width * scale)),
                max(1, round(source_cell.height * scale)),
            )
            resized = source_cell.resize(resized_size, Image.Resampling.NEAREST)
            target = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
            target.alpha_composite(
                resized,
                (
                    (CELL_SIZE - resized.width) // 2,
                    (CELL_SIZE - resized.height) // 2,
                ),
            )
            target = _quantize_to_palette(target, palette)
            target.save(OUTPUT_DIR / f"{names[len(cells)]}.png")
            cells.append(target)
    return cells


def _quantize_to_palette(image: Image.Image, colors: list[str]) -> Image.Image:
    """无抖动映射到资产子调色板，并保留二值透明度。"""
    rgb_colors = [
        tuple(int(color[index : index + 2], 16) for index in (1, 3, 5))
        for color in colors
    ]
    padded_colors = rgb_colors + [rgb_colors[0]] * (256 - len(rgb_colors))
    palette_image = Image.new("P", (1, 1))
    palette_image.putpalette(
        [channel for color in padded_colors for channel in color]
    )
    alpha = image.getchannel("A")
    quantized = image.convert("RGB").quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    quantized.putalpha(alpha)
    return quantized


def _assemble_sheet(
    cells: list[Image.Image],
    columns: int,
    rows: int,
    output_name: str,
) -> None:
    sheet = Image.new(
        "RGBA",
        (columns * CELL_SIZE, rows * CELL_SIZE),
        (0, 0, 0, 0),
    )
    for index, cell in enumerate(cells):
        sheet.alpha_composite(
            cell,
            (
                (index % columns) * CELL_SIZE,
                (index // columns) * CELL_SIZE,
            ),
        )
    sheet.save(OUTPUT_DIR / output_name)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    tree_names = [
        "rts_ancient_pine_view_front",
        "rts_ancient_pine_view_right",
        "rts_ancient_pine_view_rear",
        "rts_ancient_pine_view_left",
        "rts_ancient_pine_view_top",
        "rts_ancient_pine_view_isometric",
    ]
    tree_cells = _split_grid(
        IMAGE_DIR / "rts_ancient_pine_alpha_source.png",
        columns=3,
        rows=2,
        names=tree_names,
        palette=TREE_PALETTE,
    )
    _assemble_sheet(
        tree_cells,
        columns=3,
        rows=2,
        output_name="rts_ancient_pine_multiview.png",
    )

    mountain_types = ["sharp_peak", "long_ridge", "rounded_cluster"]
    mountain_views = ["front", "side", "top", "isometric"]
    mountain_names = [
        f"rts_mountain_{mountain_type}_view_{view}"
        for view in mountain_views
        for mountain_type in mountain_types
    ]
    mountain_cells = _split_grid(
        IMAGE_DIR / "rts_mountains_alpha_source.png",
        columns=3,
        rows=4,
        names=mountain_names,
        palette=MOUNTAIN_PALETTE,
    )
    _assemble_sheet(
        mountain_cells,
        columns=3,
        rows=4,
        output_name="rts_mountains_multiview.png",
    )

    print(f"Built {len(tree_cells) + len(mountain_cells)} views and 2 master sheets.")


if __name__ == "__main__":
    main()
