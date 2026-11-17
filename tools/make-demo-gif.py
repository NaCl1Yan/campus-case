#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把设备端抓到的连续帧合成演示动图（GIF）。

用法：
  python tools/make-demo-gif.py --src tools/__frames/frames --out docs/demo/demo.gif
      [--width 480] [--min-gap 60] [--duration 180] [--max-mb 9]

做的事：
  1. 丢掉全黑帧（重启应用/转场瞬间）与重复帧（相邻缩略图几乎一样）
  2. 等比缩放到指定宽度、转 256 色调色板
  3. 按 --duration（毫秒/帧）写成循环 GIF，超过 --max-mb 就自动降宽重试
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def is_black(img: Image.Image, threshold: float = 6.0) -> bool:
    gray = img.convert("L").resize((64, 64))
    return ImageStat.Stat(gray).mean[0] < threshold


def diff_score(a: Image.Image, b: Image.Image) -> float:
    la = a.convert("L").resize((96, 207))
    lb = b.convert("L").resize((96, 207))
    return ImageStat.Stat(ImageChops.difference(la, lb)).mean[0]


def build(src: Path, out: Path, width: int, min_gap: float, duration: int) -> tuple[int, int]:
    frames = sorted(src.glob("*.jpeg")) + sorted(src.glob("*.jpg")) + sorted(src.glob("*.png"))
    kept: list[Image.Image] = []
    last = None
    skipped_black = skipped_same = 0
    for path in frames:
        img = Image.open(path).convert("RGB")
        if is_black(img):
            skipped_black += 1
            continue
        if last is not None and diff_score(last, img) < min_gap:
            skipped_same += 1
            continue
        kept.append(img)
        last = img

    if not kept:
        raise SystemExit("没有可用帧（全黑或全部重复）")

    h = round(kept[0].height * width / kept[0].width)
    out.parent.mkdir(parents=True, exist_ok=True)
    paletted = [f.resize((width, h), Image.LANCZOS).convert("P", palette=Image.ADAPTIVE, colors=256) for f in kept]
    paletted[0].save(out, save_all=True, append_images=paletted[1:], duration=duration, loop=0, optimize=True)
    print(f"输入 {len(frames)} 帧 → 保留 {len(kept)} 帧（丢黑 {skipped_black}、丢重复 {skipped_same}）")
    return len(kept), out.stat().st_size


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="tools/__frames/frames")
    ap.add_argument("--out", default="docs/demo/demo.gif")
    ap.add_argument("--width", type=int, default=480)
    ap.add_argument("--min-gap", type=float, default=1.0)
    ap.add_argument("--duration", type=int, default=180)
    ap.add_argument("--max-mb", type=float, default=9.0)
    args = ap.parse_args()

    src, out = Path(args.src), Path(args.out)
    width = args.width
    for attempt in range(4):
        n, size = build(src, out, width, args.min_gap, args.duration)
        mb = size / 1024 / 1024
        print(f"宽度 {width}px · {n} 帧 · {mb:.1f} MB")
        if mb <= args.max_mb:
            print(f"OK -> {out}（{mb:.1f} MB）")
            return 0
        width = int(width * 0.85)
        print(f"超 {args.max_mb} MB，降到 {width}px 重试")
    print("仍然偏大，建议加大 --min-gap 或减小 --duration")
    return 1


if __name__ == "__main__":
    sys.exit(main())
