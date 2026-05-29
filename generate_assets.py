#!/usr/bin/env python3
"""
Generate SafeZone PNG overlay assets.
All images are RGBA with transparent backgrounds.

Platform overlays: semi-transparent dark fills over the unsafe UI chrome zones,
magenta border around the safe content area.

Ratio-only overlays: cyan border marking the crop boundary, rest transparent.

Run from repo root: python3 generate_assets.py
"""

from PIL import Image, ImageDraw
import os

ASSETS_DIR = os.path.join(os.path.dirname(__file__), "SafeZone", "assets")

# Colors
UNSAFE_FILL   = (0, 0, 0, 100)       # 40%-opacity black for unsafe zones
SAFE_BORDER   = (255, 20, 200, 255)  # magenta — safe zone boundary
OUTER_BORDER  = (255, 255, 255, 140) # faint white — canvas edge
RATIO_BORDER  = (0, 220, 220, 255)   # cyan — crop frame


def make_dirs():
    os.makedirs(os.path.join(ASSETS_DIR, "platform"), exist_ok=True)
    os.makedirs(os.path.join(ASSETS_DIR, "ratio"), exist_ok=True)


def paste_rect(img, x0, y0, x1, y1, color):
    """Paste a solid colored rectangle onto img using alpha compositing."""
    w = max(1, x1 - x0)
    h = max(1, y1 - y0)
    layer = Image.new("RGBA", (w, h), color)
    img.paste(layer, (x0, y0), layer)


def make_platform_overlay(filename, w, h, top, bottom, left, right):
    """
    Draw a platform safe-zone overlay.
    top/bottom/left/right are the pixel widths of the unsafe zones on each edge.
    The safe content rectangle is everything inside those margins.
    """
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    # Fill unsafe zones
    if top > 0:
        paste_rect(img, 0, 0, w, top, UNSAFE_FILL)
    if bottom > 0:
        paste_rect(img, 0, h - bottom, w, h, UNSAFE_FILL)
    if left > 0:
        paste_rect(img, 0, top, left, h - bottom, UNSAFE_FILL)
    if right > 0:
        paste_rect(img, w - right, top, w, h - bottom, UNSAFE_FILL)

    # Safe zone border
    draw = ImageDraw.Draw(img)
    sx0, sy0 = left, top
    sx1, sy1 = w - right - 1, h - bottom - 1
    draw.rectangle([sx0, sy0, sx1, sy1], outline=SAFE_BORDER, width=3)

    # Faint outer canvas border
    draw.rectangle([0, 0, w - 1, h - 1], outline=OUTER_BORDER, width=1)

    path = os.path.join(ASSETS_DIR, "platform", filename)
    img.save(path)
    print(f"  {path}")


def make_ratio_frame(filename, w, h):
    """Draw a simple crop-frame border on a transparent background."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, w - 1, h - 1], outline=RATIO_BORDER, width=3)
    path = os.path.join(ASSETS_DIR, "ratio", filename)
    img.save(path)
    print(f"  {path}")


def main():
    make_dirs()

    print("Generating platform overlays...")

    # TikTok 9:16 — largest chrome: thick bottom bar + right action strip
    make_platform_overlay("tiktok_9x16.png",    1080, 1920, top=100, bottom=320, left=0, right=80)

    # IG Reels 9:16 — slightly less bottom chrome than TikTok
    make_platform_overlay("ig_reels_9x16.png",  1080, 1920, top=80,  bottom=260, left=0, right=80)

    # YT Shorts 9:16 — bottom title/subscribe bar + right actions
    make_platform_overlay("yt_shorts_9x16.png", 1080, 1920, top=80,  bottom=200, left=0, right=80)

    # IG Feed 4:5 — feed post, minimal chrome
    make_platform_overlay("ig_feed_4x5.png",    1080, 1350, top=60,  bottom=140, left=0, right=0)

    # IG Post 1:1 — square post, minimal chrome
    make_platform_overlay("ig_post_1x1.png",    1080, 1080, top=60,  bottom=120, left=0, right=0)

    # YT 16:9 — landscape; chrome on all four sides
    make_platform_overlay("yt_16x9.png",        1920, 1080, top=80,  bottom=100, left=80, right=80)

    # X / Twitter 16:9 — minimal chrome
    make_platform_overlay("x_twitter_16x9.png", 1920, 1080, top=60,  bottom=80,  left=60, right=60)

    print("\nGenerating ratio frames...")

    make_ratio_frame("frame_9x16.png", 1080, 1920)
    make_ratio_frame("frame_4x5.png",  1080, 1350)
    make_ratio_frame("frame_1x1.png",  1080, 1080)
    make_ratio_frame("frame_4x3.png",  1440, 1080)
    make_ratio_frame("frame_16x9.png", 1920, 1080)

    print("\nDone. 12 assets written to SafeZone/assets/")


if __name__ == "__main__":
    main()
