#!/usr/bin/env python3
"""Generate the Bathroom raised-2D maze texture pack and icon polish.

The Bathroom theme keeps its funny poop/toilet subject matter, but the maze
itself should read as a clean cartoon bathroom obstacle course: pale tile
floor, glossy blue raised tub-rim/pipe walls, and a playful pink soap trap.
"""

from __future__ import annotations

import math
import random
from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes" / "poop"
OUT = THEME / "maze"
SCALE = 4

TOP = (16, 158, 222, 255)
TOP_LIGHT = (105, 225, 255, 255)
TOP_DARK = (0, 76, 153, 255)
FACE = (4, 68, 145, 255)
FACE_LIGHT = (38, 125, 205, 255)
FACE_DARK = (1, 34, 86, 255)
INK = (2, 34, 84, 165)
WHITE = (255, 255, 255, 255)
FOAM = (230, 252, 255, 255)
FLOOR = (235, 252, 255, 255)
GROUT = (166, 215, 226, 255)
PAPER = (255, 255, 250, 255)
SOAP = (255, 110, 178, 255)
SOAP_LIGHT = (255, 179, 218, 255)
SOAP_DARK = (196, 42, 119, 255)
FONT_PATH = ROOT / "assets" / "fonts" / "Fredoka-VariableFont_wdth,wght.ttf"


def sc(value: float) -> int:
    return int(round(value * SCALE))


def new_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def down(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def rect(draw: ImageDraw.ImageDraw, box, fill, radius: float = 0) -> None:
    box_s = tuple(sc(v) for v in box)
    if radius > 0:
        draw.rounded_rectangle(box_s, radius=sc(radius), fill=fill)
    else:
        draw.rectangle(box_s, fill=fill)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=None, width: float = 1.0) -> None:
    box_s = tuple(sc(v) for v in box)
    if outline is None:
        draw.ellipse(box_s, fill=fill)
    else:
        draw.ellipse(box_s, fill=fill, outline=outline, width=max(1, sc(width)))


def line(draw: ImageDraw.ImageDraw, xy, fill, width: float = 1.0) -> None:
    draw.line(tuple((sc(x), sc(y)) for x, y in xy), fill=fill, width=max(1, sc(width)))


def blend(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] * (1.0 - t) + b[i] * t)) for i in range(4))


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if FONT_PATH.exists():
        return ImageFont.truetype(str(FONT_PATH), sc(size))
    return ImageFont.load_default()


def add_noise(img: Image.Image, seed: int, alpha: int = 5, density: int = 620) -> None:
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size
    for _ in range(max(1, (w * h) // density)):
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


def alpha_mask_for_round_rect(size: tuple[int, int], box, radius: float) -> Image.Image:
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(tuple(sc(v) for v in box), radius=sc(radius), fill=255)
    return mask


def alpha_composite_masked(dst: Image.Image, src: Image.Image, mask: Image.Image) -> None:
    src = src.copy()
    src.putalpha(mask)
    dst.alpha_composite(src)


def draw_glossy_h_bar(layer: Image.Image, box, seed: int, face: bool = False, radius: float = 10) -> None:
    x0, y0, x1, y1 = box
    w, h = layer.size
    mask = alpha_mask_for_round_rect(layer.size, box, radius)
    body = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    bpx = body.load()
    top_color = FACE_LIGHT if face else TOP_LIGHT
    mid_color = FACE if face else TOP
    low_color = FACE_DARK if face else TOP_DARK
    for y in range(sc(y0), sc(y1)):
        t = (y - sc(y0)) / max(1, sc(y1 - y0))
        if t < 0.34:
            color = blend(top_color, mid_color, t / 0.34)
        else:
            color = blend(mid_color, low_color, (t - 0.34) / 0.66)
        for x in range(sc(x0), sc(x1)):
            bpx[x, y] = color
    body.putalpha(mask)
    layer.alpha_composite(body)

    d = ImageDraw.Draw(layer)
    panel = 64
    first = int(math.floor(x0 / panel) * panel)
    for i, x in enumerate(range(first, int(x1) + panel, panel)):
        if x <= x0 + 3 or x >= x1 - 3:
            continue
        seam = (3, 28, 80, 58 if face else 42)
        line(d, [(x, y0 + 4), (x, y1 - 4)], seam, 1.0)
        line(d, [(x + 1.4, y0 + 5), (x + 1.4, y1 - 5)], (255, 255, 255, 30), 0.65)

    if not face:
        line(d, [(x0 + 7, y0 + 5), (x1 - 7, y0 + 5)], (255, 255, 255, 125), 1.7)
        line(d, [(x0 + 8, y0 + 11), (x0 + 78, y0 + 11)], (255, 255, 255, 72), 2.4)
        line(d, [(x0 + 7, y1 - 5), (x1 - 7, y1 - 5)], (0, 39, 98, 88), 1.5)
        add_wall_bubbles(layer, seed, box, count=2)
    else:
        line(d, [(x0 + 6, y0 + 3), (x1 - 6, y0 + 3)], (130, 220, 255, 48), 1.0)
        line(d, [(x0 + 5, y1 - 3), (x1 - 5, y1 - 3)], (0, 20, 62, 115), 1.6)


def draw_glossy_v_bar(layer: Image.Image, box, seed: int, radius: float = 10) -> None:
    x0, y0, x1, y1 = box
    mask = alpha_mask_for_round_rect(layer.size, box, radius)
    body = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    bpx = body.load()
    for x in range(sc(x0), sc(x1)):
        t = (x - sc(x0)) / max(1, sc(x1 - x0))
        if t < 0.36:
            color = blend(TOP_LIGHT, TOP, t / 0.36)
        else:
            color = blend(TOP, TOP_DARK, (t - 0.36) / 0.64)
        for y in range(sc(y0), sc(y1)):
            bpx[x, y] = color
    body.putalpha(mask)
    layer.alpha_composite(body)

    d = ImageDraw.Draw(layer)
    panel = 64
    first = int(math.floor(y0 / panel) * panel)
    for y in range(first, int(y1) + panel, panel):
        if y <= y0 + 3 or y >= y1 - 3:
            continue
        line(d, [(x0 + 5, y), (x1 - 5, y)], (3, 28, 80, 48), 1.0)
        line(d, [(x0 + 6, y + 1.3), (x1 - 6, y + 1.3)], (255, 255, 255, 26), 0.65)
    line(d, [(x0 + 5, y0 + 6), (x0 + 5, y1 - 6)], (255, 255, 255, 112), 1.5)
    line(d, [(x1 - 5, y0 + 7), (x1 - 5, y1 - 7)], (0, 39, 98, 92), 1.6)
    add_wall_bubbles(layer, seed + 20, box, count=1, vertical=True)


def add_wall_bubbles(layer: Image.Image, seed: int, box, count: int, vertical: bool = False) -> None:
    rng = random.Random(seed)
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    for _ in range(count):
        r = rng.choice([3.2, 4.0, 4.8])
        x = rng.uniform(x0 + 18, x1 - 18) if not vertical else rng.uniform(x0 + 11, x1 - 11)
        y = rng.uniform(y0 + 9, y1 - 9) if vertical else rng.uniform(y0 + 12, y1 - 11)
        ellipse(d, (x - r, y - r, x + r, y + r), (255, 255, 255, 36), (235, 255, 255, 86), 0.8)
        ellipse(d, (x - r * 0.35, y - r * 0.42, x - r * 0.02, y - r * 0.09), (255, 255, 255, 90))


def draw_combined_horizontal(seed: int) -> Image.Image:
    w, h = 256, 68
    img = new_layer(w, h)
    shadow = new_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    rect(sd, (3, 49, w - 3, 65), (0, 19, 58, 44), 7)
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(2.3)))
    img.alpha_composite(shadow)
    draw_glossy_h_bar(img, (3, 40, w - 3, 63), seed + 2, face=True, radius=4.5)
    draw_glossy_h_bar(img, (0, 4, w, 47), seed + 1, face=False, radius=13)
    d = ImageDraw.Draw(img)
    line(d, [(6, 46), (w - 6, 46)], (0, 39, 96, 105), 1.2)
    add_noise(img, seed + 30, alpha=4)
    return down(img, w, h)


def crop_combined_parts(combined: Image.Image) -> tuple[Image.Image, Image.Image]:
    top = combined.crop((0, 0, 256, 49))
    face = Image.new("RGBA", (256, 23), (0, 0, 0, 0))
    face.alpha_composite(combined.crop((0, 40, 256, 63)))
    return top, face


def draw_vertical_top(seed: int) -> Image.Image:
    w, h = 48, 256
    img = new_layer(w, h)
    draw_glossy_v_bar(img, (3, 0, w - 3, h), seed, radius=13)
    add_noise(img, seed + 50, alpha=4)
    return down(img, w, h)


def mask_from_dirs(mask: int, size: int = 48, thickness: int = 42) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    line_w = sc(thickness)
    overshoot = 7
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
        d.line([tuple(sc(v) for v in point) for point in order], fill=255, width=line_w, joint="curve")
    else:
        for bit in active:
            d.line((sc(cx), sc(cy), sc(endpoints[bit][0]), sc(endpoints[bit][1])), fill=255, width=line_w)
    join_half = half * 0.80 if len(active) == 2 and mask not in (5, 10) else half
    d.ellipse((sc(cx - join_half), sc(cy - join_half), sc(cx + join_half), sc(cy + join_half)), fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.45))).point(lambda p: 255 if p > 68 else 0)


def end_mask_from_dir(mask: int, size: int = 48, thickness: int = 38) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    cap = 2.0
    overshoot = 2.0
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    radius = sc(half)
    if mask == 2:
        box = (cx - cap, cy - half, size + overshoot, cy + half)
    elif mask == 8:
        box = (-overshoot, cy - half, cx + cap, cy + half)
    elif mask == 4:
        box = (cx - half, cy - cap, cx + half, size + overshoot)
    else:
        box = (cx - half, -overshoot, cx + half, cy + cap)
    d.rounded_rectangle(tuple(sc(v) for v in box), radius=radius, fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.35))).point(lambda p: 255 if p > 70 else 0)


def draw_embossed_mask(img: Image.Image, alpha: Image.Image) -> None:
    edge = alpha.filter(ImageFilter.FIND_EDGES)
    shadow_mask = ImageChops.offset(edge, sc(1.1), sc(1.5)).filter(ImageFilter.GaussianBlur(sc(0.65)))
    shadow_mask = shadow_mask.point(lambda p: int(p * 0.32))
    shadow = Image.new("RGBA", img.size, (0, 23, 72, 84))
    shadow.putalpha(shadow_mask)
    img.alpha_composite(shadow)

    light_mask = ImageChops.offset(edge, -sc(1.0), -sc(1.0)).filter(ImageFilter.GaussianBlur(sc(0.55)))
    light_mask = light_mask.point(lambda p: int(p * 0.34))
    highlight = Image.new("RGBA", img.size, (255, 255, 255, 92))
    highlight.putalpha(light_mask)
    img.alpha_composite(highlight)


def draw_joint(mask: int, seed: int) -> Image.Image:
    size = 48
    img = new_layer(size, size)
    alpha = mask_from_dirs(mask, size=size)
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bpx = body.load()
    for y in range(body.height):
        ty = y / max(1, body.height - 1)
        color = blend(TOP_LIGHT, TOP, min(1.0, ty * 1.4))
        color = blend(color, TOP_DARK, max(0.0, ty - 0.55) / 0.45)
        for x in range(body.width):
            tx = x / max(1, body.width - 1)
            c = blend(color, TOP_DARK, max(0.0, tx - 0.65) * 0.25)
            bpx[x, y] = c
    body.putalpha(alpha)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    line(d, [(10, 9), (38, 9)], (255, 255, 255, 70), 1.2)
    line(d, [(8, 36), (40, 36)], (0, 37, 91, 55), 1.0)
    draw_embossed_mask(img, alpha)
    add_noise(img, seed + mask, alpha=4)
    return down(img, size, size)


def draw_top_end(mask: int, seed: int) -> Image.Image:
    size = 48
    img = new_layer(size, size)
    alpha = end_mask_from_dir(mask, size=size)
    body = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bpx = body.load()
    for y in range(body.height):
        t = y / max(1, body.height - 1)
        color = blend(TOP_LIGHT, TOP, min(1.0, t * 1.3))
        color = blend(color, TOP_DARK, max(0.0, t - 0.58) / 0.42)
        for x in range(body.width):
            bpx[x, y] = color
    body.putalpha(alpha)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    line(d, [(10, 9), (38, 9)], (255, 255, 255, 82), 1.3)
    draw_embossed_mask(img, alpha)
    add_noise(img, seed + 80, alpha=4)
    return down(img, size, size)


def draw_face_piece(left: bool, corner: bool, seed: int) -> Image.Image:
    w, h = 48, 23
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    if left:
        box = (5, 2, w - 6, h - 3)
    else:
        box = (6, 2, w - 5, h - 3)
    rect(d, box, FACE_DARK, 5.0 if corner else 7.0)
    rect(d, (box[0] + 4, box[1] + 2, box[2] - 4, box[1] + 8), (*FACE_LIGHT[:3], 94), 3.5)
    line(d, [(box[0] + 5, h - 4), (box[2] - 5, h - 4)], (0, 18, 58, 110), 1.1)
    if corner:
        shade_x = box[0] if left else box[2] - 5
        rect(d, (shade_x, 3, shade_x + 5, h - 3), (0, 18, 58, 82), 2.0)
    add_noise(img, seed + 90, alpha=3)
    return down(img, w, h)


def draw_shadow_h(end: str | None = None) -> Image.Image:
    w = 48 if end else 256
    h = 13
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    if end == "left":
        box = (8, 1, w - 3, h - 2)
    elif end == "right":
        box = (3, 1, w - 8, h - 2)
    else:
        box = (0, 1, w, h - 2)
    rect(d, box, (0, 14, 52, 82), 6)
    img = img.filter(ImageFilter.GaussianBlur(sc(2.1)))
    return down(img, w, h)


def draw_shadow_v() -> Image.Image:
    w, h = 13, 256
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    rect(d, (1, 0, w - 2, h), (0, 14, 52, 52), 5)
    img = img.filter(ImageFilter.GaussianBlur(sc(1.9)))
    return down(img, w, h)


def draw_floor(seed: int) -> Image.Image:
    w = h = 512
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), FLOOR)
    px = img.load()
    for y in range(h):
        for x in range(w):
            delta = rng.randrange(-3, 4)
            px[x, y] = (
                max(0, min(255, FLOOR[0] + delta)),
                max(0, min(255, FLOOR[1] + delta)),
                max(0, min(255, FLOOR[2] + delta)),
                255,
            )
    detail = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(detail)

    x_positions = [-22, 154, 334, 512]
    y_positions = [-18, 162, 342, 512]
    for pos in x_positions:
        d.line((pos, 0, pos, h), fill=(GROUT[0], GROUT[1], GROUT[2], 12), width=1)
        d.line((pos + 2, 0, pos + 2, h), fill=(255, 255, 255, 18), width=1)
    for pos in y_positions:
        d.line((0, pos, w, pos), fill=(GROUT[0], GROUT[1], GROUT[2], 12), width=1)
        d.line((0, pos + 2, w, pos + 2), fill=(255, 255, 255, 18), width=1)

    for row in range(4):
        for col in range(4):
            if rng.random() < 0.32:
                x = col * 128 + rng.randrange(26, 96)
                y = row * 128 + rng.randrange(24, 96)
                r = rng.randrange(8, 16)
                d.ellipse((x - r, y - r, x + r, y + r), outline=(114, 204, 222, 58), width=2)
                d.ellipse((x - r // 3, y - r // 3, x - 1, y - 1), fill=(255, 255, 255, 80))
            if rng.random() < 0.20:
                x = col * 128 + rng.randrange(22, 104)
                y = row * 128 + rng.randrange(24, 104)
                angle = rng.uniform(-0.45, 0.45)
                rw, rh = rng.randrange(10, 18), rng.randrange(7, 13)
                paper = Image.new("RGBA", (rw, rh), (*PAPER[:3], 75))
                pd = ImageDraw.Draw(paper)
                pd.rectangle((0, 0, rw - 1, rh - 1), outline=(172, 205, 214, 55), width=1)
                paper = paper.rotate(math.degrees(angle), expand=True, resample=Image.Resampling.BICUBIC)
                detail.alpha_composite(paper, (x, y))

    img.alpha_composite(detail)

    haze = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for _ in range(12):
        x = rng.randrange(-90, w)
        y = rng.randrange(-70, h)
        radius = rng.randrange(70, 160)
        hd.ellipse((x, y, x + radius, y + int(radius * rng.uniform(0.35, 0.70))), fill=(102, 213, 230, rng.randrange(7, 15)))
    haze = haze.filter(ImageFilter.GaussianBlur(22))
    img.alpha_composite(haze)
    return img


def draw_bubble(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    ellipse(d, (cx - r, cy - r, cx + r, cy + r), (245, 255, 255, 58), (190, 245, 255, 184), 2.2)
    ellipse(d, (cx - r * 0.42, cy - r * 0.45, cx - r * 0.10, cy - r * 0.13), (255, 255, 255, 150))


def draw_surface_bubble_cluster(layer: Image.Image, cx: float, cy: float, scale: float, seed: int) -> None:
    rng = random.Random(seed)
    d = ImageDraw.Draw(layer)
    for _ in range(10):
        ox = rng.uniform(-16, 18) * scale
        oy = rng.uniform(-9, 10) * scale
        r = rng.uniform(2.2, 5.8) * scale
        ellipse(
            d,
            (cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r),
            (255, 239, 249, rng.randrange(46, 78)),
            (255, 255, 255, rng.randrange(105, 155)),
            0.7,
        )


def draw_sparkle(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float, alpha: int = 190) -> None:
    line(d, [(cx - r, cy), (cx + r, cy)], (255, 255, 255, alpha), 1.2)
    line(d, [(cx, cy - r), (cx, cy + r)], (255, 255, 255, alpha), 1.2)
    line(d, [(cx - r * 0.55, cy - r * 0.55), (cx + r * 0.55, cy + r * 0.55)], (255, 255, 255, alpha // 2), 0.8)
    line(d, [(cx - r * 0.55, cy + r * 0.55), (cx + r * 0.55, cy - r * 0.55)], (255, 255, 255, alpha // 2), 0.8)


def draw_lm_text_mask(size: tuple[int, int]) -> Image.Image:
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    lm_font = font(66)
    text = "LM"
    box = d.textbbox((0, 0), text, font=lm_font)
    tw = box[2] - box[0]
    th = box[3] - box[1]
    x = (size[0] - tw) // 2 - sc(1)
    y = sc(36) - th // 2
    d.text((x, y), text, font=lm_font, fill=255)
    return mask.filter(ImageFilter.GaussianBlur(sc(0.25)))


def draw_trap() -> Image.Image:
    w = h = 256
    img = new_layer(w, h)

    shadow = new_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    ellipse(sd, (34, 165, 224, 218), (0, 20, 50, 58))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(7)))
    img.alpha_composite(shadow)

    puddle = new_layer(w, h)
    pd = ImageDraw.Draw(puddle)
    ellipse(pd, (55, 174, 203, 211), (84, 216, 238, 74), (13, 104, 161, 66), 1.4)
    line(pd, [(77, 187), (132, 176), (177, 187)], (12, 94, 150, 64), 2.4)
    img.alpha_composite(puddle)

    soap = new_layer(224, 144)
    d = ImageDraw.Draw(soap)

    # Soft block side, then glossy top. This mirrors the reference's chunky
    # soap volume while staying simple enough for a tiny trap icon.
    rect(d, (17, 41, 211, 128), (140, 29, 85, 112), 25)
    side_mask = alpha_mask_for_round_rect(soap.size, (16, 38, 212, 130), 25)
    side = Image.new("RGBA", soap.size, (0, 0, 0, 0))
    spx = side.load()
    for yy in range(sc(44), sc(130)):
        t = (yy - sc(44)) / max(1, sc(86))
        color = blend((255, 104, 172, 255), SOAP_DARK, t)
        color = blend(color, (130, 24, 80, 255), max(0.0, t - 0.62) / 0.38)
        for xx in range(sc(16), sc(212)):
            spx[xx, yy] = color
    side.putalpha(side_mask)
    soap.alpha_composite(side)

    top_mask = alpha_mask_for_round_rect(soap.size, (11, 9, 213, 101), 27)
    body = Image.new("RGBA", soap.size, (0, 0, 0, 0))
    bpx = body.load()
    for yy in range(sc(9), sc(102)):
        t = (yy - sc(9)) / max(1, sc(93))
        color = blend((255, 170, 208, 255), SOAP, min(1.0, t * 1.25))
        color = blend(color, SOAP_DARK, max(0.0, t - 0.72) / 0.28)
        for xx in range(sc(11), sc(213)):
            bpx[xx, yy] = color
    body.putalpha(top_mask)
    soap.alpha_composite(body)

    d = ImageDraw.Draw(soap)
    line(d, [(24, 24), (184, 13)], (255, 255, 255, 145), 3.2)
    line(d, [(23, 35), (199, 25)], (255, 230, 244, 64), 1.3)
    line(d, [(20, 93), (205, 91)], (255, 210, 232, 70), 1.1)
    line(d, [(23, 120), (198, 121)], (122, 20, 78, 88), 2.0)

    # Raised LM: same-pink letters with a darker lower edge and bright upper
    # glints, inspired by the supplied reference without copying a brand mark.
    text_mask = draw_lm_text_mask(soap.size)
    raised_shadow = Image.new("RGBA", soap.size, (128, 23, 83, 0))
    raised_shadow.putalpha(ImageChops.offset(text_mask, sc(3.0), sc(4.0)).filter(ImageFilter.GaussianBlur(sc(0.8))).point(lambda p: int(p * 0.58)))
    soap.alpha_composite(raised_shadow)
    raised = Image.new("RGBA", soap.size, (255, 150, 197, 0))
    raised.putalpha(text_mask.point(lambda p: int(p * 0.86)))
    soap.alpha_composite(raised)
    raised_hi = Image.new("RGBA", soap.size, (255, 238, 247, 0))
    raised_hi.putalpha(ImageChops.offset(text_mask, -sc(1.2), -sc(1.5)).filter(ImageFilter.FIND_EDGES).point(lambda p: int(p * 0.42)))
    soap.alpha_composite(raised_hi)
    raised_low = Image.new("RGBA", soap.size, (135, 25, 84, 0))
    raised_low.putalpha(ImageChops.offset(text_mask, sc(1.4), sc(1.8)).filter(ImageFilter.FIND_EDGES).point(lambda p: int(p * 0.42)))
    soap.alpha_composite(raised_low)

    d = ImageDraw.Draw(soap)
    for cx, cy, s, seed in [(37, 73, 0.95, 1), (169, 29, 0.72, 2), (192, 79, 0.75, 3), (109, 20, 0.42, 4)]:
        draw_surface_bubble_cluster(soap, cx, cy, s, seed)
    for cx, cy, r in [(61, 31, 2.6), (147, 76, 2.2), (186, 44, 1.7), (82, 85, 1.6), (127, 17, 1.5)]:
        ellipse(d, (cx - r, cy - r, cx + r, cy + r), (255, 255, 255, 74))
    draw_sparkle(d, 185, 25, 8.0, 190)
    draw_sparkle(d, 34, 100, 5.7, 150)

    add_noise(soap, 177, alpha=3, density=520)
    soap = soap.rotate(-12, expand=True, resample=Image.Resampling.BICUBIC)
    img.alpha_composite(soap, ((w * SCALE - soap.width) // 2, sc(48)))

    d = ImageDraw.Draw(img)
    for cx, cy, r in [(207, 68, 12), (42, 92, 8)]:
        draw_bubble(d, cx, cy, r)
    return down(img, w, h)


def halo_passable(r: int, g: int, b: int, a: int) -> bool:
    if a <= 36:
        return True
    bright = max(r, g, b)
    dark = min(r, g, b)
    low_sat = bright - dark < 58
    pale_blue = b >= r - 8 and b >= g - 8 and bright > 150 and a < 230
    pale_white = bright > 178 and low_sat
    return pale_white or pale_blue


def clean_sprite(path: Path) -> None:
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    px = img.load()
    outside = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        if x < 0 or y < 0 or x >= w or y >= h or outside[y][x]:
            return
        r, g, b, a = px[x, y]
        if halo_passable(r, g, b, a):
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

    cleaned = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cpx = cleaned.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if outside[y][x]:
                continue
            # Remove old light/gray contact smears; a fresh compact shadow is
            # added from the surviving character silhouette below.
            if y > h * 0.56 and a < 105 and max(r, g, b) < 170:
                continue
            if a > 0 and max(r, g, b) > 218 and min(r, g, b) > 180 and a < 230:
                continue
            cpx[x, y] = (r, g, b, a)

    alpha = cleaned.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        img.save(path)
        return

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    left, top, right, bottom = bbox
    cx = (left + right) / 2
    width = max(28, (right - left) * 0.58)
    sy = min(h - 11, bottom - 7)
    sd.ellipse((cx - width / 2, sy - 7, cx + width / 2, sy + 8), fill=(0, 25, 58, 46))
    shadow = shadow.filter(ImageFilter.GaussianBlur(4))
    shadow.alpha_composite(cleaned)
    shadow.save(path)


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name)


def save_theme(img: Image.Image, name: str) -> None:
    img.save(THEME / name)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for i in range(4):
        combined = draw_combined_horizontal(i)
        top, face = crop_combined_parts(combined)
        save(combined, f"wall_h_combined_{i:02d}.png")
        save(top, f"wall_top_h_{i:02d}.png")
        save(face, f"wall_face_h_{i:02d}.png")
        save(draw_vertical_top(i), f"wall_top_v_{i:02d}.png")

    for mask in [3, 6, 7, 9, 11, 12, 13, 14, 15]:
        save(draw_joint(mask, 20), f"wall_joint_mask_{mask:02d}.png")

    save(draw_top_end(2, 1), "wall_top_end_left_00.png")
    save(draw_top_end(8, 2), "wall_top_end_right_00.png")
    save(draw_top_end(4, 3), "wall_top_end_north_00.png")
    save(draw_top_end(1, 4), "wall_top_end_south_00.png")

    save(draw_face_piece(True, False, 0), "wall_face_end_left_00.png")
    save(draw_face_piece(False, False, 1), "wall_face_end_right_00.png")
    save(draw_face_piece(True, True, 2), "wall_face_corner_left_00.png")
    save(draw_face_piece(False, True, 3), "wall_face_corner_right_00.png")

    save(draw_shadow_h(None), "wall_shadow_h.png")
    save(draw_shadow_h("left"), "wall_shadow_h_end_left.png")
    save(draw_shadow_h("right"), "wall_shadow_h_end_right.png")
    save(draw_shadow_v(), "wall_shadow_v.png")

    save(draw_floor(40), "floor_00.png")
    save(draw_floor(41), "floor_01.png")
    # trap.png is intentionally artist-supplied, so maze regeneration must not
    # overwrite it.

    for name in ["player_0.png", "player_1.png", "chaser_0.png", "chaser_1.png"]:
        clean_sprite(THEME / name)


if __name__ == "__main__":
    main()
