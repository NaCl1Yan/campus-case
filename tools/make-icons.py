"""生成应用图标（深蓝底 + 白色时钟，时针指向 7 点）。

用途：换图标时重跑即可，产物直接覆盖 harmony 的 media 资源。
用法：python tools/make-icons.py
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BG = (38, 50, 74, 255)
FG = (255, 255, 255, 255)
DOT = (255, 200, 120, 255)


def make(rel_path: str, size: int) -> None:
    path = ROOT / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)

    img = Image.new("RGBA", (size, size), BG)
    draw = ImageDraw.Draw(img)
    pad = size * 0.18
    stroke = max(2, int(size * 0.045))
    draw.ellipse([pad, pad, size - pad, size - pad], outline=FG, width=stroke)

    cx = cy = size / 2
    hour_len = size * 0.20
    min_len = size * 0.28
    draw.line([cx, cy, cx - hour_len * 0.62, cy + hour_len * 0.78], fill=FG, width=stroke)
    draw.line([cx, cy, cx, cy - min_len], fill=FG, width=stroke)
    r = max(3, int(size * 0.035))
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DOT)

    img.save(path, format="PNG")
    print(f"wrote {rel_path} ({size}x{size})")


def main() -> int:
    try:
        import PIL  # noqa: F401
    except ImportError:
        print("需要 Pillow：pip install pillow")
        return 1
    make("harmony/AppScope/resources/base/media/app_icon.png", 512)
    make("harmony/entry/src/main/resources/base/media/app_icon.png", 512)
    make("harmony/entry/src/main/resources/base/media/startIcon.png", 256)
    return 0


if __name__ == "__main__":
    sys.exit(main())
