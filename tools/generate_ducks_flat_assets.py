#!/usr/bin/env python3
"""Polish the flat Ducks theme assets.

This intentionally keeps the Ducks maze on the simple flat renderer. It only
updates flat theme colors and generates a water-whirlpool trap icon that fits
the existing duck/pond illustration style.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
THEME = ROOT / "themes" / "ducks"
SCALE = 4

DEEP = (15, 103, 139, 255)
OUTLINE = (21, 86, 105, 255)
WATER = (55, 193, 232, 255)
WATER_LIGHT = (137, 235, 255, 255)
WATER_DARK = (23, 136, 190, 255)
FOAM = (230, 253, 255, 255)


def sc(value: float) -> int:
    return int(round(value * SCALE))


def new_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def down(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=None, width: float = 1.0) -> None:
    box_s = tuple(sc(v) for v in box)
    if outline is None:
        draw.ellipse(box_s, fill=fill)
    else:
        draw.ellipse(box_s, fill=fill, outline=outline, width=max(1, sc(width)))


def line(draw: ImageDraw.ImageDraw, xy, fill, width: float = 1.0) -> None:
    draw.line(tuple((sc(x), sc(y)) for x, y in xy), fill=fill, width=max(1, sc(width)))


def cubic_points(p0, p1, p2, p3, steps: int = 28):
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        yield (x, y)


def draw_bubble(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    ellipse(d, (cx - r, cy - r, cx + r, cy + r), (236, 253, 255, 84), (73, 175, 207, 210), 2.0)
    ellipse(d, (cx - r * 0.38, cy - r * 0.42, cx - r * 0.06, cy - r * 0.10), (255, 255, 255, 180))


def draw_whirlpool_trap() -> Image.Image:
    w = h = 256
    img = new_layer(w, h)

    shadow = new_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    ellipse(sd, (42, 164, 214, 218), (0, 42, 64, 56))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(6)))
    img.alpha_composite(shadow)

    d = ImageDraw.Draw(img)
    ellipse(d, (35, 55, 221, 206), (20, 126, 171, 255), OUTLINE, 4.0)
    ellipse(d, (47, 64, 209, 194), WATER, (47, 151, 190, 255), 2.0)
    ellipse(d, (62, 75, 194, 183), WATER_LIGHT)
    ellipse(d, (79, 92, 177, 171), WATER)
    ellipse(d, (93, 107, 162, 156), WATER_DARK)
    ellipse(d, (106, 119, 149, 145), (12, 95, 149, 255))

    # Strong flat spiral, in the same simplified illustration language as the
    # pond/start art.
    spiral = [
        (69, 126),
        (82, 96),
        (125, 82),
        (162, 98),
        (195, 116),
        (185, 157),
        (145, 174),
        (106, 163),
        (82, 154),
        (90, 127),
        (119, 115),
        (143, 122),
        (156, 133),
        (145, 149),
        (124, 150),
        (113, 142),
    ]
    line(d, spiral, (6, 91, 145, 240), 9.0)
    line(d, [(x, y - 3) for x, y in spiral[:12]], (197, 248, 255, 190), 3.4)

    # A few wide highlights, not a busy bubbly cloud.
    line(d, list(cubic_points((57, 93), (83, 70), (125, 66), (160, 78), 20)), (244, 255, 255, 190), 4.2)
    line(d, list(cubic_points((62, 158), (89, 185), (145, 188), (183, 162), 22)), (223, 252, 255, 140), 3.1)
    line(d, [(71, 116), (105, 105)], (255, 255, 255, 150), 2.6)

    for cx, cy, r in [(49, 68, 12), (211, 89, 13), (37, 151, 8), (204, 176, 10), (226, 139, 8)]:
        draw_bubble(d, cx, cy, r)

    return down(img, w, h)


def halo_passable(r: int, g: int, b: int, a: int) -> bool:
    if a <= 30:
        return True
    bright = max(r, g, b)
    dark = min(r, g, b)
    low_sat = bright - dark < 52
    pale = bright > 190 and low_sat and a < 245
    beige_shadow = r > 190 and g > 150 and b < 120 and a < 150
    return pale or beige_shadow


def clean_sprite_edges(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    outside = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= w or y >= h or outside[y][x]:
            return
        if halo_passable(*px[x, y]):
            outside[y][x] = True
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while q:
        x, y = q.popleft()
        push(x + 1, y)
        push(x - 1, y)
        push(x, y + 1)
        push(x, y - 1)

    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if outside[y][x]:
                continue
            r, g, b, a = px[x, y]
            # Drop isolated low-alpha sparkle/cut artifacts near the outside,
            # but preserve real painted highlights and contact shadows.
            if a < 82 and (x < w * 0.08 or x > w * 0.92 or y < h * 0.08):
                continue
            opx[x, y] = (r, g, b, a)
    out.save(path)


def main() -> None:
    draw_whirlpool_trap().save(THEME / "trap.png")
    for name in ["player.png", "chaser.png", "start.png", "finish.png"]:
        clean_sprite_edges(THEME / name)


if __name__ == "__main__":
    main()
