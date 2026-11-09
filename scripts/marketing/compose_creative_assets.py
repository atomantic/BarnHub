#!/usr/bin/env python3
"""Compose App Store product page header and search results assets.

Builds the two creative assets App Store Connect's Asset Library accepts
from existing iPhone App Store screenshots:

  header_<lang>.png          21:9, 3840 x 1646  (product page header)
  search_results_<lang>.png  3:2,  3840 x 2560  (search results)

Usage:
  python3 scripts/marketing/compose_creative_assets.py \
      --screens screenshots/en --lang en --out marketing/creative

--screens is a folder of iPhone 6.9" screenshots (1320 x 2868) named like
take_screenshots.sh writes them; the files listed in SHOTS are used.
"""

import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_DIR = "/usr/share/fonts/opentype/inter"
BOLD = os.path.join(FONT_DIR, "InterDisplay-Bold.otf")
MEDIUM = os.path.join(FONT_DIR, "InterDisplay-Medium.otf")

# Brand colors from Color+Brand.swift (light variants).
GREEN = (74, 124, 63)
GREEN_DARK = (44, 82, 38)
OFF_WHITE = (245, 242, 237)
TAN = (196, 162, 101)

# Short phrases per locale. English is the source; translations get added
# once Adam approves the copy.
COPY = {
    "en": {
        "headline": "Your whole barn,\nin one place.",
        "sub": "Horses, schedules, clients, and accounting.",
        "search": "Run your barn\nfrom your pocket.",
    },
}

SHOTS = {
    "home": "01_home.png",
    "horses": "02_horses.png",
    "schedule": "06_schedule.png",
    "accounting": "07_accounting.png",
}


def vertical_gradient(size, top, bottom):
    w, h = size
    grad = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return grad.resize(size)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def phone(screen, height):
    """Return an RGBA phone mockup (dark bezel, rounded screen) at height px."""
    scale = height / (screen.height * 1.04)
    sw, sh = int(screen.width * scale), int(screen.height * scale)
    bezel = int(sw * 0.035)
    w, h = sw + 2 * bezel, sh + 2 * bezel
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    body = Image.new("RGBA", (w, h), (24, 24, 26, 255))
    out.paste(body, (0, 0), rounded_mask((w, h), int(w * 0.16)))
    scr = screen.convert("RGB").resize((sw, sh), Image.LANCZOS)
    out.paste(scr, (bezel, bezel), rounded_mask((sw, sh), int(sw * 0.13)))
    return out


def paste_with_shadow(canvas, img, pos, blur=40, offset=(0, 30), alpha=110):
    shadow = Image.new("RGBA", (img.width + blur * 4, img.height + blur * 4), (0, 0, 0, 0))
    a = img.split()[3].point(lambda v: alpha if v else 0)
    shadow.paste((0, 0, 0, 255), (blur * 2, blur * 2), a)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (pos[0] - blur * 2 + offset[0], pos[1] - blur * 2 + offset[1]))
    canvas.alpha_composite(img, pos)


def draw_text_block(draw, xy, headline, sub, size, color, sub_color, max_width=None):
    x, y = xy
    hf = ImageFont.truetype(BOLD, size)
    draw.multiline_text((x, y), headline, font=hf, fill=color, spacing=int(size * 0.12))
    bbox = draw.multiline_textbbox((x, y), headline, font=hf, spacing=int(size * 0.12))
    if sub:
        sf = ImageFont.truetype(MEDIUM, int(size * 0.42))
        draw.text((x, bbox[3] + int(size * 0.45)), sub, font=sf, fill=sub_color)


def header(screens, copy, logo):
    """21:9 header: brand gradient, headline left, fanned phones right.

    Apple's guidance: one clear idea, focal point centered, nothing key at
    the edges (it gets cropped on smaller layouts).
    """
    W, H = 3840, 1646
    canvas = vertical_gradient((W, H), GREEN, GREEN_DARK).convert("RGBA")
    # Soft tan glow behind the phones.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((2000, 150, 3500, 1650), fill=TAN + (90,))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(220)))

    d = ImageDraw.Draw(canvas)
    lg = logo.resize((210, 210), Image.LANCZOS)
    canvas.alpha_composite(lg, (560, 430))
    d.text((800, 470), "BarnHub", font=ImageFont.truetype(BOLD, 110), fill=OFF_WHITE)
    draw_text_block(d, (560, 720), copy["headline"], copy["sub"], 150, (255, 255, 255), (225, 235, 220))

    ph = 1380
    order = [("schedule", -330, 120), ("horses", 0, 40), ("accounting", 330, 120)]
    cx = 2780
    for key, dx, dy in order:
        p = phone(screens[key], ph if key == "horses" else int(ph * 0.9))
        paste_with_shadow(canvas, p, (cx + dx - p.width // 2, dy + (H - ph) // 2))
    return canvas.convert("RGB")


def search_results(screens, copy, logo):
    """3:2 search results: show the real interface, state the purpose."""
    W, H = 3840, 2560
    canvas = vertical_gradient((W, H), OFF_WHITE, (232, 226, 214)).convert("RGBA")
    d = ImageDraw.Draw(canvas)
    hf = ImageFont.truetype(BOLD, 190)
    lines = copy["search"]
    bbox = d.multiline_textbbox((0, 0), lines, font=hf, align="center", spacing=20)
    d.multiline_text(((W - bbox[2]) // 2, 170), lines, font=hf, fill=GREEN_DARK, align="center", spacing=20)

    ph = 2000
    keys = ["horses", "schedule", "accounting"]
    gap = 160
    p = [phone(screens[k], ph) for k in keys]
    total = sum(i.width for i in p) + gap * (len(p) - 1)
    x = (W - total) // 2
    for i, img in enumerate(p):
        y = H - ph + 300 + (0 if i == 1 else 90)
        paste_with_shadow(canvas, img, (x, y), alpha=80)
        x += img.width + gap
    return canvas.convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--screens", required=True)
    ap.add_argument("--lang", default="en")
    ap.add_argument("--logo", default="logo.png")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    screens = {k: Image.open(os.path.join(a.screens, f)) for k, f in SHOTS.items()}
    logo = Image.open(a.logo).convert("RGBA")
    copy = COPY.get(a.lang, COPY["en"])
    os.makedirs(a.out, exist_ok=True)
    header(screens, copy, logo).save(os.path.join(a.out, f"header_{a.lang}.png"))
    search_results(screens, copy, logo).save(os.path.join(a.out, f"search_results_{a.lang}.png"))
    print("wrote", a.out)


if __name__ == "__main__":
    main()
