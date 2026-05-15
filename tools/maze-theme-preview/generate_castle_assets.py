#!/usr/bin/env python3
"""Generate the Castle raised-2D maze texture pack.

The castle theme uses the same fake-2.5D contract as the cars/thiefs themes:
the maze remains a top-down grid, horizontal walls get one coherent top+south
face asset, vertical walls show only their top surface, and junctions are quiet
seam covers rather than posts.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes" / "castle"
OUT = THEME / "maze"
SCALE = 4

STONE = (147, 145, 158, 255)
STONE_WARM = (164, 158, 171, 255)
STONE_COOL = (133, 136, 152, 255)
STONE_LIGHT = (188, 184, 199, 255)
STONE_HI = (211, 207, 219, 255)
STONE_DARK = (96, 93, 112, 255)
FACE = (78, 73, 94, 255)
FACE_2 = (64, 61, 82, 255)
FACE_DARK = (33, 30, 49, 255)
MORTAR = (58, 56, 70, 118)
INK = (30, 29, 40, 96)
MOSS = (61, 91, 67, 255)
MOSS_LIGHT = (94, 123, 80, 255)
GOLD = (238, 177, 33, 255)
GOLD_DARK = (130, 74, 15, 255)
RUBY = (188, 31, 41, 255)
BLUE = (42, 95, 187, 255)


def sc(value: float) -> int:
    return int(round(value * SCALE))


def layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def icon_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def down(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def rect(draw: ImageDraw.ImageDraw, box, fill, radius=0) -> None:
    box_s = tuple(sc(v) for v in box)
    if radius:
        draw.rounded_rectangle(box_s, radius=sc(radius), fill=fill)
    else:
        draw.rectangle(box_s, fill=fill)


def line(draw: ImageDraw.ImageDraw, xy, fill, width=1) -> None:
    draw.line(tuple((sc(x), sc(y)) for x, y in xy), fill=fill, width=max(1, sc(width)))


def poly(draw: ImageDraw.ImageDraw, points, fill) -> None:
    draw.polygon([tuple(sc(v) for v in point) for point in points], fill=fill)


def ellipse(draw: ImageDraw.ImageDraw, box, fill) -> None:
    draw.ellipse(tuple(sc(v) for v in box), fill=fill)


def add_noise(img: Image.Image, seed: int, alpha: int = 6) -> None:
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size
    for _ in range((w * h) // 600):
        x = rng.randrange(w)
        y = rng.randrange(h)
        r, g, b, a = px[x, y]
        if a == 0:
            continue
        delta = rng.randrange(-alpha, alpha + 1)
        px[x, y] = (
            max(0, min(255, r + delta)),
            max(0, min(255, g + delta)),
            max(0, min(255, b + delta)),
            a,
        )


def add_cracks(img: Image.Image, seed: int, w: int, h: int, count: int = 10) -> None:
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        x = rng.randrange(14, w - 14)
        y = rng.choice([rng.randrange(10, 31), rng.randrange(45, 60)])
        length = rng.randrange(5, 15)
        angle = rng.uniform(-0.95, 0.95)
        x1 = x + math.cos(angle) * length
        y1 = y + math.sin(angle) * length
        line(d, [(x, y), (x1, y1)], (38, 37, 49, rng.randrange(32, 58)), rng.choice([0.55, 0.75, 0.9]))
        if rng.random() > 0.67:
            line(
                d,
                [(x1, y1), (x1 + math.cos(angle + 0.9) * length * 0.42, y1 + math.sin(angle + 0.9) * length * 0.42)],
                (38, 37, 49, rng.randrange(22, 42)),
                0.55,
            )


def stone_runs(width: int, seed: int, min_w: int = 30, max_w: int = 58):
    rng = random.Random(seed)
    x = 0
    idx = 0
    while x < width:
        block = rng.randrange(min_w, max_w + 1)
        if width - (x + block) < min_w * 0.62:
            block = width - x
        x1 = min(width, x + block)
        yield x, x1, idx
        x = x1
        idx += 1


def stone_color(idx: int, seed: int, face: bool = False):
    if face:
        palette = [FACE, FACE_2, (70, 66, 88, 255), (58, 55, 76, 255)]
    else:
        palette = [STONE, STONE_WARM, STONE_COOL, (172, 169, 183, 255), (158, 158, 173, 255)]
    return palette[(idx + seed) % len(palette)]


def draw_strip_lighting(img: Image.Image, mask: Image.Image, y: float, height: float, face: bool) -> None:
    w, h = img.size
    top = sc(y)
    bottom = sc(y + height)
    span = max(1, bottom - top)
    light_alpha = Image.new("L", (w, h), 0)
    shade_alpha = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(light_alpha)
    sd = ImageDraw.Draw(shade_alpha)
    for yy in range(top, bottom):
        t = (yy - top) / span
        light = int((34 if face else 54) * max(0.0, 1.0 - t * 1.55))
        shade = int((112 if face else 34) * max(0.0, (t - 0.34) / 0.66))
        if light:
            ld.line((0, yy, w, yy), fill=light)
        if shade:
            sd.line((0, yy, w, yy), fill=shade)
    light_alpha = ImageChops.multiply(light_alpha, mask)
    shade_alpha = ImageChops.multiply(shade_alpha, mask)
    light = Image.new("RGBA", img.size, (255, 252, 244, 0))
    shade = Image.new("RGBA", img.size, (31, 28, 43, 0))
    light.putalpha(light_alpha)
    shade.putalpha(shade_alpha)
    img.alpha_composite(light)
    img.alpha_composite(shade)


def chip_top_mask(mask: Image.Image, width: int, y: float, height: float, seed: int) -> None:
    rng = random.Random(2200 + seed)
    md = ImageDraw.Draw(mask)
    for _ in range(max(4, width // 70)):
        x = rng.randrange(8, max(9, width - 18))
        notch_w = rng.randrange(5, 15)
        if rng.random() > 0.55:
            md.rounded_rectangle((sc(x), sc(y - 1.0), sc(x + notch_w), sc(y + rng.uniform(1.0, 2.6))), radius=sc(1.5), fill=0)
        else:
            md.rounded_rectangle((sc(x), sc(y + height - rng.uniform(2.4, 4.4)), sc(x + notch_w), sc(y + height + 1.0)), radius=sc(1.5), fill=0)


def draw_stone_strip(
    img: Image.Image,
    y: float,
    height: float,
    width: int,
    seed: int,
    radius: float,
    face: bool,
    runs: list[tuple[int, int, int]] | None = None,
    xpad: float = 0.0,
) -> list[tuple[int, int, int]]:
    if runs is None:
        runs = list(stone_runs(width, seed))

    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((sc(xpad), sc(y), sc(width - xpad), sc(y + height)), radius=sc(radius), fill=255)
    if not face:
        chip_top_mask(mask, width, y, height, seed)

    body = layer(width, img.height // SCALE)
    bd = ImageDraw.Draw(body)
    base_fill = (*FACE_DARK[:3], 255) if face else (104, 101, 119, 255)
    bd.rounded_rectangle((sc(xpad), sc(y), sc(width - xpad), sc(y + height)), radius=sc(radius), fill=base_fill)
    for x0, x1, idx in runs:
        fill = stone_color(idx, seed, face=face)
        bx0 = max(x0 + (1.0 if not face else 0.0), xpad)
        bx1 = min(x1 - (1.0 if not face else 0.0), width - xpad)
        if bx1 <= bx0:
            continue
        if face:
            bd.rectangle((sc(bx0), sc(y), sc(bx1), sc(y + height)), fill=fill)
        else:
            jitter_top = 0.0 if idx % 3 else 0.8
            jitter_bottom = 0.0 if idx % 4 else -0.7
            bd.rounded_rectangle(
                (sc(bx0), sc(y + 1.0 + jitter_top), sc(bx1), sc(y + height - 1.0 + jitter_bottom)),
                radius=sc(3.4),
                fill=fill,
            )
        if x0 > 0:
            seam_alpha = 118 if face else 72
            bd.line((sc(x0), sc(y + 4), sc(x0), sc(y + height - 4)), fill=(*MORTAR[:3], seam_alpha), width=sc(1.0))
            if not face:
                bd.line((sc(x0 + 1.2), sc(y + 5), sc(x0 + 1.2), sc(y + height - 5)), fill=(255, 255, 255, 16), width=sc(0.55))
        if x1 - x0 > 26:
            inset = 5 if not face else 4
            hi = STONE_LIGHT if not face else STONE
            bd.rounded_rectangle(
                (sc(x0 + inset), sc(y + 4), sc(x1 - inset), sc(y + height * (0.40 if not face else 0.33))),
                radius=sc(4.5 if not face else 3.2),
                fill=(*hi[:3], 20 if not face else 28),
            )
            bd.line((sc(x0 + 7), sc(y + height - 4), sc(x1 - 7), sc(y + height - 4)), fill=(*INK[:3], 46), width=sc(0.8))

    body.putalpha(mask)
    img.alpha_composite(body)
    draw_strip_lighting(img, mask, y, height, face=face)

    d = ImageDraw.Draw(img)
    if face:
        line(d, [(xpad + 4, y + 2), (width - xpad - 4, y + 2)], (205, 198, 218, 28), 0.9)
        line(d, [(xpad + 4, y + height - 2), (width - xpad - 4, y + height - 2)], (17, 15, 28, 62), 1.0)
    else:
        line(d, [(xpad + 5, y + height - 3), (width - xpad - 5, y + height - 3)], (*FACE_DARK[:3], 42), 0.75)
    return runs


def draw_combined_horizontal(seed: int) -> Image.Image:
    w, h = 512, 82
    img = layer(w, h)

    shadow = layer(w, h)
    sd = ImageDraw.Draw(shadow)
    rect(sd, (4, 65, w - 4, 80), (0, 0, 0, 48), 7)
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(2.8)))
    img.alpha_composite(shadow)

    runs = list(stone_runs(w, 100 + seed, 56, 118))
    draw_stone_strip(img, 39, 32, w, seed + 20, radius=3.5, face=True, runs=runs, xpad=5)

    d = ImageDraw.Draw(img)
    line(d, [(7, 39), (w - 7, 39)], (237, 232, 244, 28), 1.0)
    line(d, [(8, 42), (w - 8, 42)], (17, 14, 28, 66), 0.9)
    line(d, [(8, 68), (w - 8, 68)], (12, 10, 24, 56), 0.85)

    draw_stone_strip(img, 4, 37, w, seed + 10, radius=10, face=False, runs=runs, xpad=0)
    line(d, [(6, 37), (w - 6, 37)], (*FACE_DARK[:3], 48), 0.85)

    add_cracks(img, 300 + seed, w, h, count=14)
    add_noise(img, 400 + seed, alpha=5)
    return down(img, w, h)


def crop_combined(combined: Image.Image):
    top = combined.crop((0, 0, 512, 48))
    face = Image.new("RGBA", (512, 32), (0, 0, 0, 0))
    face.alpha_composite(combined.crop((0, 39, 512, 71)))
    return top, face


def draw_vertical_top(seed: int) -> Image.Image:
    w, h = 48, 512
    img = layer(w, h)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((sc(4), 0, sc(44), sc(h)), radius=sc(10), fill=255)

    body = layer(w, h)
    bd = ImageDraw.Draw(body)
    runs = list(stone_runs(h, 500 + seed, 58, 110))
    for y0, y1, idx in runs:
        fill = stone_color(idx, seed + 30, face=False)
        bd.rectangle((sc(4), sc(y0), sc(44), sc(y1)), fill=fill)
        if y0 > 0:
            bd.line((sc(8), sc(y0), sc(40), sc(y0)), fill=MORTAR, width=sc(1.0))
            bd.line((sc(9), sc(y0 + 1), sc(39), sc(y0 + 1)), fill=(255, 255, 255, 24), width=sc(0.55))
        bd.rounded_rectangle((sc(8), sc(y0 + 5), sc(24), sc(y1 - 5)), radius=sc(4), fill=(*STONE_LIGHT[:3], 46))
    body.putalpha(mask)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    line(d, [(8, 4), (8, h - 4)], (*STONE_HI[:3], 52), 1.0)
    line(d, [(41, 4), (41, h - 4)], (*FACE_DARK[:3], 66), 1.05)
    add_cracks(img, 550 + seed, w, h, count=12)
    add_noise(img, 560 + seed, alpha=5)
    return down(img, w, h)


def mask_from_dirs(mask: int, size: int = 48, thickness: int = 40) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    overshoot = 8
    endpoints = {
        1: (cx, -overshoot),
        2: (size + overshoot, cy),
        4: (cx, size + overshoot),
        8: (-overshoot, cy),
    }
    active = [bit for bit in [1, 2, 4, 8] if mask & bit]
    if len(active) == 2 and mask not in (5, 10):
        order = {
            3: [endpoints[1], (cx, cy), endpoints[2]],
            6: [endpoints[2], (cx, cy), endpoints[4]],
            12: [endpoints[4], (cx, cy), endpoints[8]],
            9: [endpoints[8], (cx, cy), endpoints[1]],
        }[mask]
        d.line([tuple(sc(v) for v in point) for point in order], fill=255, width=sc(thickness), joint="curve")
        join_half = half * 0.72
    else:
        for bit in active:
            d.line((sc(cx), sc(cy), sc(endpoints[bit][0]), sc(endpoints[bit][1])), fill=255, width=sc(thickness))
        join_half = half * 0.84 if len(active) >= 3 else half
    d.ellipse((sc(cx - join_half), sc(cy - join_half), sc(cx + join_half), sc(cy + join_half)), fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.42))).point(lambda p: 255 if p > 70 else 0)


def end_mask_from_dir(mask: int, size: int = 48, thickness: int = 34) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    cap = 2.0
    overshoot = 2.0
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    if mask == 2:
        box = (cx - cap, cy - half, size + overshoot, cy + half)
    elif mask == 8:
        box = (-overshoot, cy - half, cx + cap, cy + half)
    elif mask == 4:
        box = (cx - half, cy - cap, cx + half, size + overshoot)
    else:
        box = (cx - half, -overshoot, cx + half, cy + cap)
    d.rounded_rectangle(tuple(sc(v) for v in box), radius=sc(half), fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.32))).point(lambda p: 255 if p > 72 else 0)


def draw_emboss(img: Image.Image, alpha: Image.Image, light: int = 76, dark: int = 84) -> None:
    edge = alpha.filter(ImageFilter.FIND_EDGES)
    shadow_mask = ImageChops.offset(edge, sc(1.15), sc(1.45)).filter(ImageFilter.GaussianBlur(sc(0.75))).point(lambda p: int(p * 0.35))
    light_mask = ImageChops.offset(edge, -sc(1.0), -sc(1.0)).filter(ImageFilter.GaussianBlur(sc(0.65))).point(lambda p: int(p * 0.31))
    shadow = Image.new("RGBA", img.size, (*FACE_DARK[:3], dark))
    highlight = Image.new("RGBA", img.size, (*STONE_HI[:3], light))
    shadow.putalpha(shadow_mask)
    highlight.putalpha(light_mask)
    img.alpha_composite(shadow)
    img.alpha_composite(highlight)


def draw_joint_detail(draw: ImageDraw.ImageDraw, mask: int, seed: int, size: int = 48) -> None:
    rng = random.Random(seed + mask * 13)
    active = [bit for bit in [1, 2, 4, 8] if mask & bit]
    cx = cy = size / 2
    for bit in active:
        if bit in (1, 4):
            for y in [rng.randrange(9, 17), rng.randrange(31, 39)]:
                if bit == 1 and y > cy:
                    continue
                if bit == 4 and y < cy:
                    continue
                line(draw, [(cx - 13, y), (cx + 13, y)], MORTAR, 0.8)
        else:
            for x in [rng.randrange(9, 17), rng.randrange(31, 39)]:
                if bit == 8 and x > cx:
                    continue
                if bit == 2 and x < cx:
                    continue
                line(draw, [(x, cy - 13), (x, cy + 13)], MORTAR, 0.8)
    if len(active) == 2 and mask not in (5, 10):
        draw.arc((sc(9), sc(9), sc(39), sc(39)), 205, 330, fill=(*STONE_HI[:3], 54), width=sc(1.15))
    if rng.random() > 0.42:
        x = rng.randrange(14, 34)
        y = rng.randrange(14, 34)
        line(draw, [(x, y), (x + rng.randrange(-5, 6), y + rng.randrange(4, 9))], (36, 35, 48, 42), 0.65)


def draw_joint(mask: int, seed: int, alt: bool = False) -> Image.Image:
    size = 48
    img = layer(size, size)
    alpha = mask_from_dirs(mask)
    body = layer(size, size)
    bd = ImageDraw.Draw(body)
    bd.rectangle((0, 0, sc(size), sc(size)), fill=STONE_WARM if alt else STONE)
    bd.line((sc(8), sc(8), sc(40), sc(8)), fill=(*STONE_HI[:3], 38), width=sc(1.0))
    bd.line((sc(8), sc(39), sc(40), sc(39)), fill=(*FACE_DARK[:3], 36), width=sc(0.8))
    draw_joint_detail(bd, mask, seed + (31 if alt else 0), size)
    body.putalpha(alpha)
    img.alpha_composite(body)
    draw_emboss(img, alpha)
    add_noise(img, seed + mask + 600, alpha=5)
    return down(img, size, size)


def draw_top_end(mask: int, seed: int, alt: bool = False) -> Image.Image:
    size = 48
    img = layer(size, size)
    alpha = end_mask_from_dir(mask)
    body = layer(size, size)
    bd = ImageDraw.Draw(body)
    bd.rectangle((0, 0, sc(size), sc(size)), fill=STONE_COOL if alt else STONE_WARM)
    bd.line((sc(9), sc(9), sc(39), sc(9)), fill=(*STONE_HI[:3], 38), width=sc(0.9))
    bd.line((sc(9), sc(38), sc(39), sc(38)), fill=(*FACE_DARK[:3], 36), width=sc(0.75))
    draw_joint_detail(bd, mask, seed, size)
    body.putalpha(alpha)
    img.alpha_composite(body)
    draw_emboss(img, alpha, light=72, dark=78)
    add_noise(img, seed + 700, alpha=5)
    return down(img, size, size)


def draw_face_piece(left: bool, corner: bool, seed: int, alt: bool = False) -> Image.Image:
    w, h = 48, 32
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    fill = FACE_2 if alt else FACE
    if left:
        box = (5, 1.5, w - (9 if not corner else 7), h - 2)
    else:
        box = ((9 if not corner else 7), 1.5, w - 5, h - 2)
    rect(d, box, fill, 5.5 if not corner else 4.2)
    rect(d, (box[0] + 3.8, 3.5, box[2] - 3.8, 8.2), (*STONE[:3], 36), 2.4)
    line(d, [(box[0] + 5, h - 3.2), (box[2] - 5, h - 3.2)], (10, 8, 22, 94), 1.0)
    if corner:
        shade_x = box[0] if left else box[2] - 5
        rect(d, (shade_x, 2.5, shade_x + 5, h - 2.5), (*FACE_DARK[:3], 58), 2.2)
    if alt:
        line(d, [(box[0] + 9, h - 6), (box[0] + 18, h - 4)], (34, 34, 47, 44), 0.6)
    add_noise(img, seed + 780, alpha=4)
    return down(img, w, h)


def draw_shadow_h(end: str | None = None) -> Image.Image:
    w = 48 if end else 512
    h = 16
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    if end == "left":
        box = (8, 1, w - 3, h - 2)
    elif end == "right":
        box = (3, 1, w - 8, h - 2)
    else:
        box = (0, 1, w, h - 2)
    rect(d, box, (0, 0, 0, 72), 6)
    img = img.filter(ImageFilter.GaussianBlur(sc(2.15)))
    return down(img, w, h)


def draw_shadow_v() -> Image.Image:
    w, h = 13, 512
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    rect(d, (1, 0, w - 2, h), (0, 0, 0, 45), 5)
    img = img.filter(ImageFilter.GaussianBlur(sc(2.0)))
    return down(img, w, h)


def draw_floor(seed: int) -> Image.Image:
    w = h = 1024
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), (39, 48, 56, 255))
    px = img.load()
    for y in range(h):
        for x in range(w):
            delta = rng.randrange(-6, 7)
            px[x, y] = (40 + delta, 49 + delta, 57 + delta, 255)

    haze = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for _ in range(18):
        x = rng.randrange(-90, w)
        y = rng.randrange(-90, h)
        rx = rng.randrange(60, 160)
        color = rng.choice([(50, 63, 72, 14), (14, 21, 28, 18), (45, 64, 48, 12)])
        hd.ellipse((x, y, x + rx, y + int(rx * rng.uniform(0.45, 0.92))), fill=color)
    haze = haze.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(haze)

    d = ImageDraw.Draw(img)
    row_y = -10
    row = 0
    while row_y < h + 24:
        row_h = rng.randrange(36, 54)
        shift = -rng.randrange(24, 90) if row % 2 else -rng.randrange(0, 32)
        x = shift
        col = 0
        while x < w + 60:
            stone_w = rng.randrange(70, 140)
            shade = rng.randrange(-7, 10)
            fill = (45 + shade, 55 + shade, 63 + shade, 255)
            d.rectangle((x, row_y, x + stone_w, row_y + row_h), fill=fill)
            d.rectangle((x, row_y, x + stone_w, row_y + row_h), outline=(15, 21, 28, 54), width=1)
            if rng.random() > 0.72:
                cx = x + rng.randrange(8, max(9, stone_w - 8))
                cy = row_y + rng.randrange(7, max(8, row_h - 7))
                d.line((cx, cy, cx + rng.randrange(-8, 10), cy + rng.randrange(5, 13)), fill=(9, 14, 20, rng.randrange(46, 76)), width=1)
            if rng.random() > 0.88:
                mx = x + rng.randrange(2, max(3, stone_w - 4))
                my = row_y + rng.randrange(2, max(3, row_h - 4))
                d.ellipse((mx, my, mx + rng.randrange(5, 14), my + rng.randrange(2, 7)), fill=(*MOSS[:3], rng.randrange(26, 48)))
            x += stone_w
            col += 1
        row_y += row_h
        row += 1

    img = img.filter(ImageFilter.GaussianBlur(0.12))
    d = ImageDraw.Draw(img)
    for _ in range(160):
        x = rng.randrange(w)
        y = rng.randrange(h)
        d.point((x, y), fill=(rng.randrange(18, 70), rng.randrange(24, 78), rng.randrange(28, 84), rng.randrange(14, 34)))
    return img


def draw_collectible_shield(glow_phase: int = 0) -> Image.Image:
    w = h = 512
    img = icon_layer(w, h)
    shadow = icon_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((sc(115), sc(355), sc(400), sc(430)), fill=(0, 0, 0, 76))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(10)))
    img.alpha_composite(shadow)

    glow = icon_layer(w, h)
    gd = ImageDraw.Draw(glow)
    glow_alpha = 44 + glow_phase * 16
    gd.ellipse((sc(70), sc(56), sc(442), sc(444)), fill=(255, 198, 54, glow_alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(18)))
    img.alpha_composite(glow)

    d = ImageDraw.Draw(img)
    outer = [(256, 65), (392, 115), (371, 296), (256, 438), (141, 296), (120, 115)]
    inner = [(256, 98), (354, 134), (338, 280), (256, 385), (174, 280), (158, 134)]
    poly(d, outer, GOLD_DARK)
    poly(d, [(256, 72), (381, 118), (361, 291), (256, 421), (151, 291), (131, 118)], GOLD)
    poly(d, inner, BLUE if glow_phase == 0 else RUBY)
    poly(d, [(256, 111), (340, 141), (326, 269), (256, 358), (186, 269), (172, 141)], (38, 65, 130, 255) if glow_phase == 0 else (134, 30, 45, 255))
    d.line([tuple(sc(v) for v in point) for point in outer + [outer[0]]], fill=(255, 235, 138, 210), width=sc(7), joint="curve")
    d.line([tuple(sc(v) for v in point) for point in inner + [inner[0]]], fill=(91, 48, 12, 156), width=sc(5), joint="curve")
    d.arc((sc(165), sc(102), sc(344), sc(246)), 204, 333, fill=(255, 255, 255, 135), width=sc(9))
    d.arc((sc(136), sc(102), sc(376), sc(362)), 28, 95, fill=(255, 232, 108, 120), width=sc(7))
    # A clean center is deliberate: Godot draws the letter/number label there.
    d.ellipse((sc(205), sc(193), sc(307), sc(295)), fill=(28, 32, 43, 190))
    d.ellipse((sc(214), sc(202), sc(298), sc(286)), fill=(248, 240, 215, 226))
    add_noise(img, 900 + glow_phase, alpha=4)
    return down(img, w, h)


def save(img: Image.Image, name: str) -> None:
    img.save(OUT / name)


def save_theme(img: Image.Image, name: str) -> None:
    img.save(THEME / name)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for i in range(4):
        combined = draw_combined_horizontal(i)
        top, face = crop_combined(combined)
        save(combined, f"wall_h_combined_{i:02d}.png")
        save(top, f"wall_top_h_{i:02d}.png")
        save(face, f"wall_face_h_{i:02d}.png")
        save(draw_vertical_top(i), f"wall_top_v_{i:02d}.png")

    for mask in [3, 6, 7, 9, 11, 12, 13, 14, 15]:
        save(draw_joint(mask, 30, False), f"wall_joint_mask_{mask:02d}_00.png")
        save(draw_joint(mask, 31, True), f"wall_joint_mask_{mask:02d}_01.png")

    for direction, mask in [
        ("left", 2),
        ("right", 8),
        ("north", 4),
        ("south", 1),
    ]:
        save(draw_top_end(mask, 40 + mask, False), f"wall_top_end_{direction}_00.png")
        save(draw_top_end(mask, 50 + mask, True), f"wall_top_end_{direction}_01.png")

    save(draw_face_piece(True, False, 60, False), "wall_face_end_left_00.png")
    save(draw_face_piece(True, False, 61, True), "wall_face_end_left_01.png")
    save(draw_face_piece(False, False, 62, False), "wall_face_end_right_00.png")
    save(draw_face_piece(False, False, 63, True), "wall_face_end_right_01.png")
    save(draw_face_piece(True, True, 64, False), "wall_face_corner_left_00.png")
    save(draw_face_piece(True, True, 65, True), "wall_face_corner_left_01.png")
    save(draw_face_piece(False, True, 66, False), "wall_face_corner_right_00.png")
    save(draw_face_piece(False, True, 67, True), "wall_face_corner_right_01.png")

    save(draw_shadow_h(None), "wall_shadow_h.png")
    save(draw_shadow_h("left"), "wall_shadow_h_end_left.png")
    save(draw_shadow_h("right"), "wall_shadow_h_end_right.png")
    save(draw_shadow_v(), "wall_shadow_v.png")
    save(draw_floor(80), "floor_00.png")
    save(draw_floor(81), "floor_01.png")
    save_theme(draw_collectible_shield(0), "c_collectible_shield_0.png")
    save_theme(draw_collectible_shield(1), "c_collectible_shield_1.png")


if __name__ == "__main__":
    main()
