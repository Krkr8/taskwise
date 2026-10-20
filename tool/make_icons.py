#!/usr/bin/env python3
"""Generates Taskwise's placeholder app icon for every platform.

A white check inside a ring on the app's teal seed colour. Run from the repo
root after changing the design:

    python3 tool/make_icons.py

Needs Pillow (python3-pillow on Fedora) and ImageMagick's `magick` for the
Windows .ico. The generated files are committed, so building the app does
not need either tool.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
TEAL = (0, 137, 123, 255)  # AppTheme.seed (0xFF00897B)
WHITE = (255, 255, 255, 255)
SCALE = 4  # draw large, then downsample for smooth edges


def draw_icon(size: int, rounded: bool) -> Image.Image:
    """Draws the icon at [size] px. iOS wants a full square (it applies its
    own mask); desktop icons get rounded corners on a transparent canvas."""
    big = size * SCALE
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    if rounded:
        d.rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.22, fill=TEAL)
    else:
        d.rectangle((0, 0, big, big), fill=TEAL)

    # Ring.
    c = big / 2
    r = big * 0.30
    ring = big * 0.055
    d.ellipse((c - r, c - r, c + r, c + r), outline=WHITE, width=round(ring))

    # Check mark, with round caps and joint.
    points = [
        (c - r * 0.48, c + r * 0.02),
        (c - r * 0.12, c + r * 0.38),
        (c + r * 0.52, c - r * 0.34),
    ]
    stroke = big * 0.07
    d.line(points, fill=WHITE, width=round(stroke), joint="curve")
    for x, y in (points[0], points[-1]):
        h = stroke / 2
        d.ellipse((x - h, y - h, x + h, y + h), fill=WHITE)

    img = img.resize((size, size), Image.LANCZOS)
    return img if rounded else img.convert("RGB")  # iOS icons must be opaque


def write_ios() -> None:
    iconset = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for old in iconset.glob("*.png"):
        old.unlink()
    draw_icon(1024, rounded=False).save(iconset / "AppIcon-1024.png")
    # Single-size app icon (Xcode 14+ derives all other sizes from it).
    contents = {
        "images": [
            {
                "filename": "AppIcon-1024.png",
                "idiom": "universal",
                "platform": "ios",
                "size": "1024x1024",
            }
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (iconset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_linux() -> None:
    out = APP / "linux/packaging"
    out.mkdir(parents=True, exist_ok=True)
    draw_icon(256, rounded=True).save(out / "io.github.krkr8.taskwise.png")


def write_windows() -> None:
    magick = shutil.which("magick")
    if magick is None:
        sys.exit("ImageMagick `magick` not found (sudo dnf install ImageMagick)")
    tmp = APP / "windows/runner/resources/_icon-256.png"
    draw_icon(256, rounded=True).save(tmp)
    try:
        subprocess.run(
            [
                magick,
                str(tmp),
                "-define",
                "icon:auto-resize=256,128,64,48,32,24,16",
                str(APP / "windows/runner/resources/app_icon.ico"),
            ],
            check=True,
        )
    finally:
        tmp.unlink()


if __name__ == "__main__":
    write_ios()
    write_linux()
    write_windows()
    print("Icons written for iOS, Linux and Windows.")
