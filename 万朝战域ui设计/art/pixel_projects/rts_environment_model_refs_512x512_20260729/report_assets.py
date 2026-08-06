#!/usr/bin/env python3
"""输出最终素材的尺寸、实用色数和 Alpha 统计。"""

from pathlib import Path

from PIL import Image


ASSET_DIR = Path(__file__).resolve().parent / "assets" / "backgrounds"


for asset_path in sorted(ASSET_DIR.glob("*.png")):
    image = Image.open(asset_path).convert("RGBA")
    opaque_colors = {pixel[:3] for pixel in image.getdata() if pixel[3] > 0}
    alpha_values = {pixel[3] for pixel in image.getdata()}
    print(
        f"{asset_path.name}|{image.width}x{image.height}|"
        f"{len(opaque_colors)} colors|alpha={sorted(alpha_values)}"
    )
