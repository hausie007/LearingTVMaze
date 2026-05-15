#!/usr/bin/env python3
"""Generate the Cars raised-2D maze texture pack.

The cars theme needs a racing-barrier look where the horizontal top and the
south/front face are one coherent object. This script creates deterministic
transparent PNGs from a shared red/cream block rhythm, then exports the legacy
layer files plus the combined horizontal-wall files used by the improved
renderer path.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "themes" / "cars"
OUT = ROOT / "themes" / "cars" / "maze"
SCALE = 4

RED = (218, 30, 24, 255)
RED_LIGHT = (255, 83, 68, 255)
RED_DARK = (145, 22, 20, 255)
CREAM = (242, 220, 184, 255)
CREAM_LIGHT = (255, 242, 214, 255)
CREAM_DARK = (194, 164, 130, 255)
SEAM = (122, 54, 42, 92)
INK = (92, 34, 31, 96)


def sc(value: float) -> int:
    return int(round(value * SCALE))


def new_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def down(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def rect(draw: ImageDraw.ImageDraw, box, fill, radius=0):
    box_s = tuple(sc(v) for v in box)
    if radius > 0:
        draw.rounded_rectangle(box_s, radius=sc(radius), fill=fill)
    else:
        draw.rectangle(box_s, fill=fill)


def line(draw: ImageDraw.ImageDraw, xy, fill, width=1):
    draw.line(tuple((sc(x), sc(y)) for x, y in xy), fill=fill, width=max(1, sc(width)))


def add_noise(img: Image.Image, seed: int, alpha: int = 8) -> None:
    rng = random.Random(seed)
    px = img.load()
    w, h = img.size
    for _ in range((w * h) // 520):
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


def blocks_for_width(width: int, block: int = 128):
    x = 0
    idx = 0
    while x < width:
        yield x, min(width, x + block), idx
        x += block
        idx += 1


def block_colors(idx: int, dark=False):
    red = RED_DARK if dark else RED
    cream = CREAM_DARK if dark else CREAM
    return red if idx % 2 == 0 else cream


def block_light(idx: int):
    return RED_LIGHT if idx % 2 == 0 else CREAM_LIGHT


def draw_block_strip(
    layer: Image.Image,
    y: float,
    height: float,
    width: int,
    seed: int,
    radius: float,
    dark: bool = False,
    xpad: float = 0,
) -> None:
    draw = ImageDraw.Draw(layer)
    mask = Image.new("L", layer.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(
        (sc(xpad), sc(y), sc(width - xpad), sc(y + height)),
        radius=sc(radius),
        fill=255,
    )

    body = new_layer(width, layer.height // SCALE)
    bd = ImageDraw.Draw(body)
    for x0, x1, idx in blocks_for_width(width):
        fill = block_colors(idx + seed, dark=dark)
        bd.rectangle((sc(x0), sc(y), sc(x1), sc(y + height)), fill=fill)

        # Panel bevel and hand-painted vertical separators.
        edge = x0 if x0 > 0 else x1
        bd.line((sc(edge), sc(y + 4), sc(edge), sc(y + height - 3)), fill=SEAM, width=sc(1.0))
        if x1 - x0 > 18:
            hi = block_light(idx + seed)
            bd.rounded_rectangle(
                (sc(x0 + 4), sc(y + 4), sc(x1 - 4), sc(y + height * 0.42)),
                radius=sc(4),
                fill=(hi[0], hi[1], hi[2], 82),
            )
            bd.line((sc(x0 + 6), sc(y + height - 5), sc(x1 - 6), sc(y + height - 5)), fill=(60, 20, 20, 42), width=sc(1))

    body.putalpha(mask)
    layer.alpha_composite(body)
    add_strip_lighting(layer, mask, y, height, dark)
    line(draw, [(xpad + 2, y + 2), (width - xpad - 2, y + 2)], (255, 255, 255, 80), 1.2)
    line(draw, [(xpad + 2, y + height - 2), (width - xpad - 2, y + height - 2)], (86, 29, 25, 58), 1.0)


def add_strip_lighting(layer: Image.Image, mask: Image.Image, y: float, height: float, face: bool) -> None:
    w, h = layer.size
    top = sc(y)
    bottom = sc(y + height)
    span = max(1, bottom - top)

    light_alpha = Image.new("L", (w, h), 0)
    shade_alpha = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(light_alpha)
    sd = ImageDraw.Draw(shade_alpha)
    for yy in range(top, bottom):
        t = (yy - top) / span
        light = int((46 if face else 58) * max(0.0, 1.0 - t * 1.8))
        shade = int((58 if face else 28) * max(0.0, (t - 0.38) / 0.62))
        if light > 0:
            ld.line((0, yy, w, yy), fill=light)
        if shade > 0:
            sd.line((0, yy, w, yy), fill=shade)

    light_alpha = ImageChops.multiply(light_alpha, mask)
    shade_alpha = ImageChops.multiply(shade_alpha, mask)
    light_layer = Image.new("RGBA", layer.size, (255, 247, 224, 0))
    shade_layer = Image.new("RGBA", layer.size, (92, 28, 24, 0))
    light_layer.putalpha(light_alpha)
    shade_layer.putalpha(shade_alpha)
    layer.alpha_composite(light_layer)
    layer.alpha_composite(shade_layer)


def draw_combined_horizontal(seed: int) -> Image.Image:
    w, h = 256, 62
    img = new_layer(w, h)
    draw = ImageDraw.Draw(img)

    # Soft contact/depth shadow under the barrier face.
    shadow = new_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    rect(sd, (2, 47, w - 2, 61), (54, 20, 18, 42), 6)
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(2.7)))
    img.alpha_composite(shadow)

    # South/front face, drawn first so the rounded top overlaps it.
    draw_block_strip(img, 38, 21, w, seed, radius=3.5, dark=True, xpad=3)
    line(draw, [(4, 39), (w - 4, 39)], (255, 228, 190, 38), 1)
    line(draw, [(4, 58), (w - 4, 58)], (86, 29, 25, 78), 1.5)

    # Bright rounded top.
    draw_block_strip(img, 3, 35, w, seed, radius=11, dark=False, xpad=0)
    line(draw, [(5, 6), (w - 5, 6)], (255, 255, 255, 105), 1.4)
    line(draw, [(4, 34), (w - 4, 34)], (118, 43, 35, 68), 1.0)

    add_cracks(img, seed + 10, w, h)
    add_noise(img, seed + 20)
    return down(img, w, h)


def add_cracks(img: Image.Image, seed: int, w: int, h: int) -> None:
    rng = random.Random(seed)
    draw = ImageDraw.Draw(img)
    for _ in range(8):
        x = rng.randrange(10, w - 10)
        y = rng.choice([rng.randrange(9, 28), rng.randrange(44, 56)])
        length = rng.randrange(4, 11)
        angle = rng.uniform(-0.8, 0.8)
        xy = [(x, y), (x + math.cos(angle) * length, y + math.sin(angle) * length)]
        line(draw, xy, (72, 45, 45, rng.randrange(24, 48)), rng.choice([0.5, 0.7, 0.9]))


def crop_combined_parts(seed: int, combined: Image.Image):
    top = combined.crop((0, 0, 256, 44))
    face = Image.new("RGBA", (256, 18), (0, 0, 0, 0))
    face.alpha_composite(combined.crop((0, 40, 256, 58)))
    return top, face


def draw_vertical_top(seed: int) -> Image.Image:
    base = new_layer(44, 256)
    mask = Image.new("L", base.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((sc(3), 0, sc(41), sc(256)), radius=sc(11), fill=255)
    body = new_layer(44, 256)
    bd = ImageDraw.Draw(body)
    for y0, y1, idx in blocks_for_width(256):
        fill = block_colors(idx + seed)
        bd.rectangle((sc(3), sc(y0), sc(41), sc(y1)), fill=fill)
        bd.line((sc(8), sc(y0), sc(36), sc(y0)), fill=SEAM, width=sc(1.0))
        hi = block_light(idx + seed)
        bd.rounded_rectangle((sc(8), sc(y0 + 4), sc(23), sc(y1 - 4)), radius=sc(4), fill=(hi[0], hi[1], hi[2], 70))
    body.putalpha(mask)
    base.alpha_composite(body)
    d = ImageDraw.Draw(base)
    line(d, [(7, 2), (7, 254)], (255, 255, 255, 70), 1.1)
    line(d, [(38, 2), (38, 254)], (45, 16, 16, 62), 1.2)
    add_cracks(base, seed + 30, 44, 256)
    add_noise(base, seed + 31)
    return down(base, 44, 256)


def mask_from_dirs(mask: int, size=44, thickness=39, rounded=True) -> Image.Image:
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

    # Round the internal join/cap. L-bends get a slightly smaller center fill so
    # the outside reads as a molded curve instead of a square plug.
    join_half = half * 0.78 if len(active) == 2 and mask not in (5, 10) else half
    d.ellipse((sc(cx - join_half), sc(cy - join_half), sc(cx + join_half), sc(cy + join_half)), fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.55))).point(lambda p: 255 if p > 68 else 0)


def end_mask_from_dir(mask: int, size=44, thickness=32) -> Image.Image:
    cx = cy = size / 2
    half = thickness / 2
    cap = 2.0
    overshoot = 2.0
    m = Image.new("L", (size * SCALE, size * SCALE), 0)
    d = ImageDraw.Draw(m)
    radius = sc(half)

    if mask == 2:  # wall continues east, exposed rounded tip on the west/left
        box = (cx - cap, cy - half, size + overshoot, cy + half)
    elif mask == 8:  # wall continues west, exposed rounded tip on the east/right
        box = (-overshoot, cy - half, cx + cap, cy + half)
    elif mask == 4:  # wall continues south, exposed rounded tip on the north/top
        box = (cx - half, cy - cap, cx + half, size + overshoot)
    else:  # mask == 1, wall continues north, exposed rounded tip on the south/bottom
        box = (cx - half, -overshoot, cx + half, cy + cap)

    d.rounded_rectangle(tuple(sc(v) for v in box), radius=radius, fill=255)
    return m.filter(ImageFilter.GaussianBlur(sc(0.35))).point(lambda p: 255 if p > 70 else 0)


def draw_embossed_mask(img: Image.Image, alpha: Image.Image, light_strength: int = 74, dark_strength: int = 82) -> None:
    """Add a soft toy-like bevel to the visible alpha without creating a joint button."""
    edge = alpha.filter(ImageFilter.FIND_EDGES)

    shadow_mask = ImageChops.offset(edge, sc(1.2), sc(1.6)).filter(ImageFilter.GaussianBlur(sc(0.8)))
    shadow_mask = shadow_mask.point(lambda p: int(p * 0.34))
    shadow = Image.new("RGBA", img.size, (92, 20, 16, dark_strength))
    shadow.putalpha(shadow_mask)
    img.alpha_composite(shadow)

    light_mask = ImageChops.offset(edge, -sc(1.0), -sc(1.1)).filter(ImageFilter.GaussianBlur(sc(0.65)))
    light_mask = light_mask.point(lambda p: int(p * 0.30))
    highlight = Image.new("RGBA", img.size, (255, 244, 220, light_strength))
    highlight.putalpha(light_mask)
    img.alpha_composite(highlight)


def draw_joint(mask: int, seed: int, cream: bool = False) -> Image.Image:
    size = 44
    img = new_layer(size, size)
    alpha = mask_from_dirs(mask)

    body = new_layer(size, size)
    bd = ImageDraw.Draw(body)
    fill = CREAM if cream else RED
    light = CREAM_LIGHT if cream else RED_LIGHT
    dark = CREAM_DARK if cream else RED_DARK
    bd.rectangle((0, 0, sc(size), sc(size)), fill=fill)

    # A junction must look like the same molded barrier continuing through the
    # bend, not like a separate plug. Keep the center the same material color
    # and use only broad edge lighting.
    bd.rounded_rectangle((sc(6), sc(5), sc(38), sc(18)), radius=sc(8), fill=(*light[:3], 58 if cream else 54))
    bd.arc((sc(5), sc(5), sc(39), sc(39)), 190, 330, fill=(*light[:3], 72), width=sc(1.3))
    bd.line((sc(7), sc(35), sc(37), sc(35)), fill=(*dark[:3], 48), width=sc(0.85))

    body.putalpha(alpha)
    img.alpha_composite(body)

    draw_embossed_mask(img, alpha, light_strength=64 if cream else 74, dark_strength=64 if cream else 82)
    add_noise(img, seed + mask, alpha=6)
    return down(img, size, size)


def draw_top_end(mask: int, seed: int, cream: bool = False) -> Image.Image:
    size = 44
    img = new_layer(size, size)
    alpha = end_mask_from_dir(mask)

    body = new_layer(size, size)
    bd = ImageDraw.Draw(body)
    fill = CREAM if cream else RED
    light = RED_LIGHT if fill == RED else CREAM_LIGHT
    dark = RED_DARK if fill == RED else CREAM_DARK
    bd.rectangle((0, 0, sc(size), sc(size)), fill=fill)
    bd.rounded_rectangle((sc(8), sc(6), sc(36), sc(17)), radius=sc(8), fill=(*light[:3], 56))
    bd.arc((sc(6), sc(5), sc(38), sc(37)), 195, 326, fill=(*light[:3], 78), width=sc(1.2))
    bd.line((sc(9), sc(34), sc(35), sc(34)), fill=(*dark[:3], 48), width=sc(0.85))
    body.putalpha(alpha)
    img.alpha_composite(body)
    draw_embossed_mask(img, alpha, light_strength=68, dark_strength=76)
    add_noise(img, seed + 70, alpha=6)
    return down(img, size, size)


def draw_face_piece(left: bool, corner: bool, seed: int, cream: bool = False) -> Image.Image:
    w, h = 44, 18
    img = new_layer(w, h)
    draw = ImageDraw.Draw(img)
    radius = 7 if not corner else 5
    fill = CREAM_DARK if cream else RED_DARK
    light = CREAM if cream else RED
    if left:
        box = (5, 1, w - 7, h - 2)
    else:
        box = (7, 1, w - 5, h - 2)
    rect(draw, box, fill, radius)
    rect(draw, (box[0] + 4, 3, box[2] - 4, 8), (*light[:3], 72), 3)
    line(draw, [(box[0] + 5, h - 3), (box[2] - 5, h - 3)], (74, 29, 25, 72), 1.0)
    if corner:
        shade_x = box[0] if left else box[2] - 5
        rect(draw, (shade_x, 2, shade_x + 5, h - 2), (55, 19, 20, 70), 2)
    add_noise(img, seed + 90, alpha=5)
    return down(img, w, h)


def draw_shadow_h(end: str | None = None) -> Image.Image:
    w = 44 if end else 256
    h = 12
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    if end == "left":
        box = (8, 1, w - 3, h - 2)
    elif end == "right":
        box = (3, 1, w - 8, h - 2)
    else:
        box = (0, 1, w, h - 2)
    rect(d, box, (0, 0, 0, 88), 6)
    img = img.filter(ImageFilter.GaussianBlur(sc(2.2)))
    return down(img, w, h)


def draw_shadow_v() -> Image.Image:
    w, h = 12, 256
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    rect(d, (1, 0, w - 2, h), (0, 0, 0, 56), 5)
    img = img.filter(ImageFilter.GaussianBlur(sc(2)))
    return down(img, w, h)


def draw_floor(seed: int) -> Image.Image:
    w = h = 512
    rng = random.Random(seed)
    img = Image.new("RGBA", (w, h), (30, 35, 38, 255))
    px = img.load()
    for y in range(h):
        for x in range(w):
            delta = rng.randrange(-7, 8)
            base = 34 + delta
            px[x, y] = (base, base + 4, base + 6, 255)
    d = ImageDraw.Draw(img)

    # Keep the asphalt quiet. Directional marks here read like accidental
    # scratches once tiled; lane dashes are drawn by the renderer separately.
    haze = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    hd = ImageDraw.Draw(haze)
    for _ in range(18):
        x = rng.randrange(-80, w)
        y = rng.randrange(-80, h)
        radius = rng.randrange(60, 160)
        color = rng.choice([(45, 54, 56, 12), (14, 18, 19, 16), (45, 40, 34, 10)])
        hd.ellipse((x, y, x + radius, y + radius * rng.uniform(0.55, 1.0)), fill=color)
    haze = haze.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(haze)

    for _ in range(260):
        x = rng.randrange(0, w)
        y = rng.randrange(0, h)
        shade = rng.randrange(18, 62)
        alpha = rng.randrange(14, 34)
        d.point((x, y), fill=(shade, shade + 2, shade + 3, alpha))
    for _ in range(16):
        x = rng.randrange(0, w)
        y = rng.randrange(0, h)
        d.ellipse((x, y, x + rng.randrange(2, 5), y + rng.randrange(1, 4)), fill=(9, 12, 13, rng.randrange(18, 34)))
    return img


def icon_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def draw_racing_wheel_token(layer: Image.Image, cx: float, cy: float, rx: float, ry: float, seed: int) -> None:
    d = ImageDraw.Draw(layer)

    # Strong outer silhouette: black tire, warm rim, and a calm center reserved
    # for Godot's overlaid number/letter.
    d.ellipse((sc(cx - rx + 5), sc(cy + ry * 0.52), sc(cx + rx + 5), sc(cy + ry * 0.86)), fill=(0, 0, 0, 64))
    d.ellipse((sc(cx - rx - 10), sc(cy - ry - 10), sc(cx + rx + 10), sc(cy + ry + 10)), fill=(255, 215, 55, 78))
    d.ellipse((sc(cx - rx - 1), sc(cy - ry - 1), sc(cx + rx + 1), sc(cy + ry + 1)), fill=(251, 234, 185, 255))
    d.ellipse((sc(cx - rx + 8), sc(cy - ry + 8), sc(cx + rx - 8), sc(cy + ry - 8)), fill=(20, 22, 25, 255))
    d.ellipse((sc(cx - rx * 0.82), sc(cy - ry * 0.80), sc(cx + rx * 0.82), sc(cy + ry * 0.80)), fill=(45, 49, 52, 255))
    d.ellipse((sc(cx - rx * 0.70), sc(cy - ry * 0.68), sc(cx + rx * 0.70), sc(cy + ry * 0.68)), fill=(8, 9, 11, 255))

    # Edge-only racing accents. They suggest speed without entering the label zone.
    ring_box = (sc(cx - rx * 0.93), sc(cy - ry * 0.91), sc(cx + rx * 0.93), sc(cy + ry * 0.91))
    d.arc(ring_box, 206, 286, fill=(255, 255, 255, 210), width=sc(7.0))
    d.arc(ring_box, 296, 350, fill=RED_LIGHT, width=sc(7.0))
    d.arc(ring_box, 28, 86, fill=(255, 212, 42, 205), width=sc(7.0))

    # Large matte label well. Avoid white detail in the center because Godot's
    # white label with black outline sits here.
    d.ellipse((sc(cx - rx * 0.64), sc(cy - ry * 0.61), sc(cx + rx * 0.64), sc(cy + ry * 0.61)), fill=(9, 11, 15, 255))
    d.ellipse((sc(cx - rx * 0.56), sc(cy - ry * 0.53), sc(cx + rx * 0.56), sc(cy + ry * 0.53)), fill=(25, 31, 39, 255))
    d.arc((sc(cx - rx * 0.59), sc(cy - ry * 0.56), sc(cx + rx * 0.59), sc(cy + ry * 0.56)), 214, 305, fill=(255, 255, 255, 30), width=sc(2.2))
    d.arc((sc(cx - rx * 0.67), sc(cy - ry * 0.64), sc(cx + rx * 0.67), sc(cy + ry * 0.64)), 30, 72, fill=(255, 211, 44, 58), width=sc(2.4))


def draw_collectible_wheels() -> Image.Image:
    w = h = 512
    img = icon_layer(w, h)
    shadow = icon_layer(w, h)
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((sc(108), sc(350), sc(404), sc(422)), fill=(0, 0, 0, 76))
    shadow = shadow.filter(ImageFilter.GaussianBlur(sc(9)))
    img.alpha_composite(shadow)
    glow = icon_layer(w, h)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((sc(80), sc(78), sc(432), sc(434)), fill=(255, 205, 42, 38))
    gd.ellipse((sc(111), sc(108), sc(401), sc(404)), fill=(255, 255, 255, 14))
    glow = glow.filter(ImageFilter.GaussianBlur(sc(13)))
    img.alpha_composite(glow)
    draw_racing_wheel_token(img, 256, 256, 148, 136, 7)
    add_noise(img, 140, alpha=4)
    return down(img, w, h)


def clean_player_sprite() -> None:
    source = THEME / "player_1.png"
    path = THEME / "player_1_readable.png"
    if not source.exists() and not path.exists():
        return
    img = Image.open(source if source.exists() else path).convert("RGBA")
    w, h = img.size
    px = img.load()

    car_mask = Image.new("L", img.size, 0)
    cd = ImageDraw.Draw(car_mask)
    cd.polygon(
        [
            (w * 0.04, h * 0.75),
            (w * 0.05, h * 0.61),
            (w * 0.13, h * 0.50),
            (w * 0.25, h * 0.42),
            (w * 0.35, h * 0.31),
            (w * 0.61, h * 0.30),
            (w * 0.76, h * 0.34),
            (w * 0.96, h * 0.41),
            (w * 0.99, h * 0.66),
            (w * 0.92, h * 0.78),
            (w * 0.74, h * 0.82),
            (w * 0.24, h * 0.81),
        ],
        fill=255,
    )
    cd.ellipse((int(w * 0.07), int(h * 0.46), int(w * 0.55), int(h * 0.80)), fill=255)
    cd.ellipse((int(w * 0.52), int(h * 0.47), int(w * 0.98), int(h * 0.82)), fill=255)
    car_mask = car_mask.filter(ImageFilter.GaussianBlur(1.1))

    wheel_mask = Image.new("L", img.size, 0)
    wd = ImageDraw.Draw(wheel_mask)
    wd.ellipse((int(w * 0.62), int(h * 0.54), int(w * 0.82), int(h * 0.78)), fill=255)
    wd.ellipse((int(w * 0.84), int(h * 0.50), int(w * 1.03), int(h * 0.75)), fill=255)
    wheel_mask = wheel_mask.filter(ImageFilter.GaussianBlur(0.8))

    out = img.copy()
    opx = out.load()
    mpx = car_mask.load()
    wpx = wheel_mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = opx[x, y]
            if a == 0:
                continue
            mx = max(r, g, b)
            mn = min(r, g, b)
            sat = 0.0 if mx == 0 else float(mx - mn) / float(mx)
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            in_car = mpx[x, y] > 12
            in_wheel = wpx[x, y] > 18
            red_body = r > 115 and r > g * 1.25 and r > b * 1.25
            neutral_ground = sat < 0.22 and lum > 42 and y > h * 0.62 and not in_wheel
            bottom_smear = y > h * 0.77 and not in_wheel and (sat < 0.42 or lum < 70)
            side_smoke = sat < 0.24 and lum > 36 and y > h * 0.36 and (x < w * 0.16 or x > w * 0.84) and not in_wheel
            far_right_smoke = x > w * 0.93 and y > h * 0.36 and lum > 46 and sat < 0.36
            old_underbody_shadow = y > h * 0.74 and not in_wheel and not red_body
            left_speckles = x < w * 0.28 and y > h * 0.68 and not red_body and lum < 105
            if not in_car or neutral_ground or bottom_smear or side_smoke or far_right_smoke or old_underbody_shadow or left_speckles:
                opx[x, y] = (r, g, b, 0)

    # A small local shadow grounds the cutout without importing the gray road.
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse((int(w * 0.22), int(h * 0.74), int(w * 0.84), int(h * 0.86)), fill=(0, 0, 0, 62))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    shadow.alpha_composite(out)
    out = shadow
    out.save(path)


def save(img: Image.Image, name: str) -> None:
    path = OUT / name
    img.save(path)


def save_theme(img: Image.Image, name: str) -> None:
    path = THEME / name
    img.save(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    for i in range(4):
        combined = draw_combined_horizontal(i)
        top, face = crop_combined_parts(i, combined)
        save(combined, f"wall_h_combined_{i:02d}.png")
        save(top, f"wall_top_h_{i:02d}.png")
        save(face, f"wall_face_h_{i:02d}.png")
        save(draw_vertical_top(i), f"wall_top_v_{i:02d}.png")

    for mask in [3, 6, 7, 9, 11, 12, 13, 14, 15]:
        save(draw_joint(mask, 10, False), f"wall_joint_mask_{mask:02d}_red.png")
        save(draw_joint(mask, 11, True), f"wall_joint_mask_{mask:02d}_cream.png")

    save(draw_top_end(2, 1, False), "wall_top_end_left_red.png")
    save(draw_top_end(2, 2, True), "wall_top_end_left_cream.png")
    save(draw_top_end(8, 3, False), "wall_top_end_right_red.png")
    save(draw_top_end(8, 4, True), "wall_top_end_right_cream.png")
    save(draw_top_end(4, 5, False), "wall_top_end_north_red.png")
    save(draw_top_end(4, 6, True), "wall_top_end_north_cream.png")
    save(draw_top_end(1, 7, False), "wall_top_end_south_red.png")
    save(draw_top_end(1, 8, True), "wall_top_end_south_cream.png")

    save(draw_face_piece(True, False, 0, False), "wall_face_end_left_red.png")
    save(draw_face_piece(True, False, 1, True), "wall_face_end_left_cream.png")
    save(draw_face_piece(False, False, 2, False), "wall_face_end_right_red.png")
    save(draw_face_piece(False, False, 3, True), "wall_face_end_right_cream.png")
    save(draw_face_piece(True, True, 4, False), "wall_face_corner_left_red.png")
    save(draw_face_piece(True, True, 5, True), "wall_face_corner_left_cream.png")
    save(draw_face_piece(False, True, 6, False), "wall_face_corner_right_red.png")
    save(draw_face_piece(False, True, 7, True), "wall_face_corner_right_cream.png")

    save(draw_shadow_h(None), "wall_shadow_h.png")
    save(draw_shadow_h("left"), "wall_shadow_h_end_left.png")
    save(draw_shadow_h("right"), "wall_shadow_h_end_right.png")
    save(draw_shadow_v(), "wall_shadow_v.png")

    save(draw_floor(20), "floor_00.png")
    save(draw_floor(21), "floor_01.png")
    save_theme(draw_collectible_wheels(), "collectible_wheels.png")
    clean_player_sprite()


if __name__ == "__main__":
    main()
