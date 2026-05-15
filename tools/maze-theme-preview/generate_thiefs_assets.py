#!/usr/bin/env python3
"""Generate the Thieves raised-2D maze texture pack.

The thieves theme follows the Kids Robbers & Cops reference: glossy rounded
blue block walls, a darker south/front wall face, quiet city pavement, and a
bright loot collectible with a clean label area.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes" / "thiefs"
OUT = THEME / "maze"
SCALE = 4

BLUE = (33, 119, 235, 255)
BLUE_2 = (41, 139, 248, 255)
BLUE_LIGHT = (112, 190, 255, 255)
BLUE_HI = (177, 224, 255, 255)
BLUE_DARK = (12, 62, 164, 255)
FACE = (14, 70, 154, 255)
FACE_DARK = (7, 35, 96, 255)
SEAM = (8, 36, 102, 92)
INK = (4, 18, 56, 90)


def sc(value: float) -> int:
    return int(round(value * SCALE))


def layer(w: int, h: int) -> Image.Image:
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


def add_noise(img: Image.Image, seed: int, alpha: int = 6) -> None:
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size
    for _ in range((w * h) // 680):
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


def block_runs(width: int, seed: int):
    rng = random.Random(seed)
    x = 0
    idx = 0
    while x < width:
        block = rng.choice([44, 52, 60, 68])
        x1 = min(width, x + block)
        yield x, x1, idx
        x = x1
        idx += 1


def blue_for(idx: int, seed: int, dark=False):
    if dark:
        palette = [FACE, (17, 76, 170, 255), BLUE_DARK]
    else:
        palette = [BLUE, BLUE_2, (52, 149, 252, 255), (29, 107, 226, 255)]
    return palette[(idx + seed) % len(palette)]


def add_strip_lighting(img: Image.Image, mask: Image.Image, y: float, height: float, face: bool) -> None:
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
        light = int((52 if face else 70) * max(0.0, 1.0 - t * 1.65))
        shade = int((70 if face else 34) * max(0.0, (t - 0.42) / 0.58))
        if light:
            ld.line((0, yy, w, yy), fill=light)
        if shade:
            sd.line((0, yy, w, yy), fill=shade)
    light_alpha = ImageChops.multiply(light_alpha, mask)
    shade_alpha = ImageChops.multiply(shade_alpha, mask)
    light = Image.new("RGBA", img.size, (205, 235, 255, 0))
    shade = Image.new("RGBA", img.size, (1, 22, 82, 0))
    light.putalpha(light_alpha)
    shade.putalpha(shade_alpha)
    img.alpha_composite(light)
    img.alpha_composite(shade)


def draw_block_strip(img: Image.Image, y: float, height: float, width: int, seed: int, radius: float, dark=False, xpad=0) -> None:
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((sc(xpad), sc(y), sc(width - xpad), sc(y + height)), radius=sc(radius), fill=255)

    body = layer(width, img.height // SCALE)
    bd = ImageDraw.Draw(body)
    for x0, x1, idx in block_runs(width, seed):
        fill = blue_for(idx, seed, dark)
        bd.rectangle((sc(x0), sc(y), sc(x1), sc(y + height)), fill=fill)
        if x0 > 0:
            bd.line((sc(x0), sc(y + 5), sc(x0), sc(y + height - 4)), fill=SEAM, width=sc(1.0))
        if x1 - x0 > 26:
            bd.rounded_rectangle((sc(x0 + 5), sc(y + 5), sc(x1 - 5), sc(y + height * 0.42)), radius=sc(5), fill=(*BLUE_LIGHT[:3], 58 if not dark else 34))
            bd.line((sc(x0 + 8), sc(y + height - 5), sc(x1 - 8), sc(y + height - 5)), fill=(*INK[:3], 44), width=sc(1.0))
    body.putalpha(mask)
    img.alpha_composite(body)
    add_strip_lighting(img, mask, y, height, dark)

    d = ImageDraw.Draw(img)
    line(d, [(xpad + 6, y + 5), (width - xpad - 6, y + 5)], (*BLUE_HI[:3], 86), 1.4)
    line(d, [(xpad + 4, y + height - 3), (width - xpad - 4, y + height - 3)], (*FACE_DARK[:3], 54), 1.0)


def add_scuffs(img: Image.Image, seed: int, w: int, h: int) -> None:
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    for _ in range(7):
        x = rng.randrange(12, w - 12)
        y = rng.choice([rng.randrange(11, 28), rng.randrange(44, 56)])
        length = rng.randrange(5, 14)
        angle = rng.uniform(-0.6, 0.6)
        line(d, [(x, y), (x + math.cos(angle) * length, y + math.sin(angle) * length)], (3, 26, 78, rng.randrange(22, 44)), 0.75)


def draw_combined_horizontal(seed: int) -> Image.Image:
    w, h = 256, 62
    img = layer(w, h)
    shadow = layer(w, h)
    sd = ImageDraw.Draw(shadow)
    rect(sd, (2, 48, w - 2, 61), (0, 12, 55, 50), 7)
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(2.8)))
    img.alpha_composite(shadow)

    draw_block_strip(img, 38, 21, w, seed, radius=4.5, dark=True, xpad=3)
    d = ImageDraw.Draw(img)
    line(d, [(5, 39), (w - 5, 39)], (150, 205, 255, 28), 1)
    line(d, [(5, 58), (w - 5, 58)], (0, 16, 62, 46), 1.0)

    draw_block_strip(img, 3, 35, w, seed, radius=11, dark=False, xpad=0)
    line(d, [(6, 7), (w - 6, 7)], (220, 244, 255, 102), 1.5)
    line(d, [(5, 34), (w - 5, 34)], (0, 32, 106, 62), 1.0)
    add_scuffs(img, seed + 10, w, h)
    add_noise(img, seed + 20, 5)
    return down(img, w, h)


def crop_combined(combined: Image.Image):
    top = combined.crop((0, 0, 256, 44))
    face = Image.new("RGBA", (256, 18), (0, 0, 0, 0))
    face.alpha_composite(combined.crop((0, 40, 256, 58)))
    return top, face


def draw_vertical_top(seed: int) -> Image.Image:
    w, h = 44, 256
    img = layer(w, h)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((sc(3), 0, sc(41), sc(256)), radius=sc(11), fill=255)
    body = layer(w, h)
    bd = ImageDraw.Draw(body)
    for y0, y1, idx in block_runs(h, seed + 31):
        fill = blue_for(idx, seed, False)
        bd.rectangle((sc(3), sc(y0), sc(41), sc(y1)), fill=fill)
        if y0 > 0:
            bd.line((sc(8), sc(y0), sc(36), sc(y0)), fill=SEAM, width=sc(1.0))
        bd.rounded_rectangle((sc(8), sc(y0 + 5), sc(24), sc(y1 - 5)), radius=sc(5), fill=(*BLUE_LIGHT[:3], 58))
    body.putalpha(mask)
    img.alpha_composite(body)
    d = ImageDraw.Draw(img)
    line(d, [(7, 4), (7, 252)], (*BLUE_HI[:3], 78), 1.2)
    line(d, [(38, 4), (38, 252)], (*FACE_DARK[:3], 58), 1.1)
    add_scuffs(img, seed + 40, w, h)
    add_noise(img, seed + 41, 5)
    return down(img, w, h)


def mask_from_dirs(mask: int, size=44, thickness=38) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    endpoints = {
        1: (cx, -7),
        2: (size + 7, cy),
        4: (cx, size + 7),
        8: (-7, cy),
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
        join_half = half * 0.66
    else:
        for bit in active:
            d.line((sc(cx), sc(cy), sc(endpoints[bit][0]), sc(endpoints[bit][1])), fill=255, width=sc(thickness))
        join_half = half * 0.88 if len(active) >= 3 else half
    d.ellipse((sc(cx - join_half), sc(cy - join_half), sc(cx + join_half), sc(cy + join_half)), fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.55))).point(lambda p: 255 if p > 68 else 0)


def end_mask_from_dir(mask: int, size=44, thickness=32) -> Image.Image:
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
    return m.filter(ImageFilter.GaussianBlur(sc(0.35))).point(lambda p: 255 if p > 70 else 0)


def draw_emboss(img: Image.Image, alpha: Image.Image) -> None:
    edge = alpha.filter(ImageFilter.FIND_EDGES)
    shadow_mask = ImageChops.offset(edge, sc(1.1), sc(1.5)).filter(ImageFilter.GaussianBlur(sc(0.8))).point(lambda p: int(p * 0.33))
    light_mask = ImageChops.offset(edge, -sc(1.0), -sc(1.0)).filter(ImageFilter.GaussianBlur(sc(0.65))).point(lambda p: int(p * 0.30))
    shadow = Image.new("RGBA", img.size, (*FACE_DARK[:3], 78))
    light = Image.new("RGBA", img.size, (*BLUE_HI[:3], 82))
    shadow.putalpha(shadow_mask)
    light.putalpha(light_mask)
    img.alpha_composite(shadow)
    img.alpha_composite(light)


def draw_joint(mask: int, seed: int, alt=False) -> Image.Image:
    size = 44
    img = layer(size, size)
    alpha = mask_from_dirs(mask)
    body = layer(size, size)
    bd = ImageDraw.Draw(body)
    fill = BLUE_2 if alt else BLUE
    bd.rectangle((0, 0, sc(size), sc(size)), fill=fill)
    bd.rounded_rectangle((sc(8), sc(6), sc(36), sc(16)), radius=sc(6), fill=(*BLUE_LIGHT[:3], 36))
    bd.arc((sc(7), sc(7), sc(37), sc(37)), 200, 320, fill=(*BLUE_HI[:3], 38), width=sc(1.0))
    bd.line((sc(8), sc(35), sc(36), sc(35)), fill=(*FACE_DARK[:3], 34), width=sc(0.8))
    body.putalpha(alpha)
    img.alpha_composite(body)
    draw_emboss(img, alpha)
    add_noise(img, seed + mask, 5)
    return down(img, size, size)


def draw_top_end(mask: int, seed: int, alt=False) -> Image.Image:
    size = 44
    img = layer(size, size)
    alpha = end_mask_from_dir(mask)
    body = layer(size, size)
    bd = ImageDraw.Draw(body)
    bd.rectangle((0, 0, sc(size), sc(size)), fill=BLUE_2 if alt else BLUE)
    bd.rounded_rectangle((sc(8), sc(6), sc(36), sc(17)), radius=sc(8), fill=(*BLUE_LIGHT[:3], 58))
    bd.arc((sc(6), sc(5), sc(38), sc(37)), 195, 326, fill=(*BLUE_HI[:3], 76), width=sc(1.2))
    bd.line((sc(9), sc(34), sc(35), sc(34)), fill=(*FACE_DARK[:3], 46), width=sc(0.85))
    body.putalpha(alpha)
    img.alpha_composite(body)
    draw_emboss(img, alpha)
    add_noise(img, seed + 70, 5)
    return down(img, size, size)


def draw_face_piece(left: bool, corner: bool, seed: int, alt=False) -> Image.Image:
    w, h = 44, 18
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    fill = (17, 76, 170, 255) if alt else FACE
    if left:
        box = (5, 1, w - 7, h - 2)
    else:
        box = (7, 1, w - 5, h - 2)
    rect(d, box, fill, 6 if not corner else 5)
    rect(d, (box[0] + 4, 3, box[2] - 4, 8), (*BLUE_LIGHT[:3], 48), 3)
    line(d, [(box[0] + 5, h - 3), (box[2] - 5, h - 3)], (*FACE_DARK[:3], 68), 1.0)
    if corner:
        shade_x = box[0] if left else box[2] - 5
        rect(d, (shade_x, 2, shade_x + 5, h - 2), (*FACE_DARK[:3], 58), 2)
    add_noise(img, seed + 90, 4)
    return down(img, w, h)


def draw_shadow_h(end: str | None = None) -> Image.Image:
    w = 44 if end else 256
    h = 12
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    if end == "left":
        box = (8, 1, w - 3, h - 2)
    elif end == "right":
        box = (3, 1, w - 8, h - 2)
    else:
        box = (0, 1, w, h - 2)
    rect(d, box, (0, 9, 46, 72), 6)
    img = img.filter(ImageFilter.GaussianBlur(sc(2.2)))
    return down(img, w, h)


def draw_shadow_v() -> Image.Image:
    w, h = 12, 256
    img = layer(w, h)
    d = ImageDraw.Draw(img)
    rect(d, (1, 0, w - 2, h), (0, 9, 46, 42), 5)
    img = img.filter(ImageFilter.GaussianBlur(sc(2)))
    return down(img, w, h)


def draw_floor(seed: int) -> Image.Image:
    w = h = 512
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), (176, 184, 184, 255))
    d = ImageDraw.Draw(img)
    slab_h = 86
    y = -20
    row = 0
    while y < h:
        offset = -55 if row % 2 else -8
        x = offset
        while x < w:
            slab_w = rng.choice([96, 116, 132, 148])
            shade = rng.randrange(-10, 11)
            fill = (176 + shade, 184 + shade, 184 + shade, 255)
            d.rectangle((x, y, x + slab_w, y + slab_h), fill=fill)
            d.line((x, y, x + slab_w, y), fill=(113, 126, 130, 25), width=1)
            d.line((x, y, x, y + slab_h), fill=(113, 126, 130, 16), width=1)
            if rng.random() < 0.09:
                cx = x + rng.randrange(16, max(17, slab_w - 16))
                cy = y + rng.randrange(18, slab_h - 12)
                d.arc((cx - 9, cy - 6, cx + 10, cy + 7), rng.randrange(0, 160), rng.randrange(190, 350), fill=(91, 101, 104, 24), width=1)
            x += slab_w
        y += slab_h
        row += 1
    haze = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for _ in range(14):
        x = rng.randrange(-60, w)
        y = rng.randrange(-60, h)
        r = rng.randrange(80, 160)
        hd.ellipse((x, y, x + r, y + r * rng.uniform(0.5, 0.9)), fill=(116, 137, 137, rng.randrange(8, 18)))
    haze = haze.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(haze)
    for _ in range(190):
        x = rng.randrange(w)
        y = rng.randrange(h)
        dot = rng.randrange(130, 205)
        d.point((x, y), fill=(dot, dot + 2, dot + 2, rng.randrange(16, 40)))
    return img


def draw_background_tile(seed: int) -> Image.Image:
    rng = random.Random(seed)
    img = Image.new("RGBA", (512, 512), (78, 145, 70, 255))
    d = ImageDraw.Draw(img)
    for _ in range(75):
        x = rng.randrange(-30, 512)
        y = rng.randrange(-30, 512)
        r = rng.randrange(18, 58)
        color = rng.choice([(88, 164, 78, 54), (55, 117, 62, 42), (120, 174, 74, 34)])
        d.ellipse((x, y, x + r, y + r * rng.uniform(0.6, 1.2)), fill=color)
    for _ in range(38):
        x = rng.randrange(512)
        y = rng.randrange(512)
        if rng.random() < 0.45:
            d.ellipse((x, y, x + 5, y + 5), fill=(245, 210, 84, 95))
    return img.filter(ImageFilter.GaussianBlur(0.4))


def draw_money_bag() -> Image.Image:
    w = h = 512
    img = layer(w, h)
    shadow = layer(w, h)
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((sc(122), sc(360), sc(390), sc(432)), fill=(0, 0, 0, 68))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(8)))
    img.alpha_composite(shadow)
    glow = layer(w, h)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((sc(118), sc(118), sc(394), sc(416)), fill=(255, 215, 55, 30))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(10)))
    img.alpha_composite(glow)

    d = ImageDraw.Draw(img)
    outline = (92, 55, 23, 255)
    body_dark = (201, 132, 31, 255)
    body = (246, 181, 48, 255)
    body_light = (255, 223, 114, 255)
    d.polygon(
        [
            (sc(178), sc(158)),
            (sc(334), sc(158)),
            (sc(383), sc(260)),
            (sc(358), sc(392)),
            (sc(256), sc(432)),
            (sc(154), sc(392)),
            (sc(129), sc(260)),
        ],
        fill=outline,
    )
    d.polygon(
        [
            (sc(184), sc(164)),
            (sc(328), sc(164)),
            (sc(366), sc(258)),
            (sc(344), sc(378)),
            (sc(256), sc(412)),
            (sc(168), sc(378)),
            (sc(146), sc(258)),
        ],
        fill=body_dark,
    )
    d.ellipse((sc(146), sc(172), sc(366), sc(408)), fill=body)
    d.polygon([(sc(190), sc(166)), (sc(234), sc(78)), (sc(260), sc(166))], fill=(234, 158, 34, 255))
    d.polygon([(sc(234), sc(78)), (sc(322), sc(166)), (sc(260), sc(166))], fill=(185, 113, 28, 255))
    d.rounded_rectangle((sc(176), sc(144), sc(336), sc(178)), radius=sc(14), fill=outline)
    d.rounded_rectangle((sc(193), sc(149), sc(319), sc(167)), radius=sc(8), fill=(255, 212, 76, 190))
    d.ellipse((sc(188), sc(224), sc(324), sc(348)), fill=body_light)
    d.ellipse((sc(206), sc(242), sc(306), sc(330)), fill=(252, 226, 145, 165))
    d.arc((sc(152), sc(188), sc(360), sc(388)), 198, 318, fill=(255, 245, 178, 92), width=sc(7))
    d.arc((sc(140), sc(176), sc(372), sc(408)), 24, 104, fill=(103, 61, 24, 86), width=sc(7))
    d.line((sc(166), sc(358), sc(346), sc(358)), fill=(94, 54, 20, 78), width=sc(4))
    add_noise(img, 220, 5)
    return down(img, w, h)


def save(img: Image.Image, name: str) -> None:
    (OUT / name).parent.mkdir(parents=True, exist_ok=True)
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
        save(draw_joint(mask, 10, False), f"wall_joint_mask_{mask:02d}_blue.png")
        save(draw_joint(mask, 11, True), f"wall_joint_mask_{mask:02d}_blue_alt.png")

    save(draw_top_end(2, 1, False), "wall_top_end_left_blue.png")
    save(draw_top_end(2, 2, True), "wall_top_end_left_blue_alt.png")
    save(draw_top_end(8, 3, False), "wall_top_end_right_blue.png")
    save(draw_top_end(8, 4, True), "wall_top_end_right_blue_alt.png")
    save(draw_top_end(4, 5, False), "wall_top_end_north_blue.png")
    save(draw_top_end(4, 6, True), "wall_top_end_north_blue_alt.png")
    save(draw_top_end(1, 7, False), "wall_top_end_south_blue.png")
    save(draw_top_end(1, 8, True), "wall_top_end_south_blue_alt.png")

    save(draw_face_piece(True, False, 0, False), "wall_face_end_left_blue.png")
    save(draw_face_piece(True, False, 1, True), "wall_face_end_left_blue_alt.png")
    save(draw_face_piece(False, False, 2, False), "wall_face_end_right_blue.png")
    save(draw_face_piece(False, False, 3, True), "wall_face_end_right_blue_alt.png")
    save(draw_face_piece(True, True, 4, False), "wall_face_corner_left_blue.png")
    save(draw_face_piece(True, True, 5, True), "wall_face_corner_left_blue_alt.png")
    save(draw_face_piece(False, True, 6, False), "wall_face_corner_right_blue.png")
    save(draw_face_piece(False, True, 7, True), "wall_face_corner_right_blue_alt.png")

    save(draw_shadow_h(None), "wall_shadow_h.png")
    save(draw_shadow_h("left"), "wall_shadow_h_end_left.png")
    save(draw_shadow_h("right"), "wall_shadow_h_end_right.png")
    save(draw_shadow_v(), "wall_shadow_v.png")
    save(draw_floor(120), "floor_00.png")
    save(draw_floor(121), "floor_01.png")
    save_theme(draw_background_tile(130), "t_background_tile_city.png")
    save_theme(draw_money_bag(), "t_collectible_money_bag.png")


if __name__ == "__main__":
    main()
