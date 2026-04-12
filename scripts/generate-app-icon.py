#!/usr/bin/env python3
"""Generate Resources/icon.png (1024×1024) using Pillow.
Run: uv run --with Pillow python3 scripts/generate-app-icon.py
"""
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    sys.exit("error: Pillow not installed — run via: uv run --with Pillow python3 scripts/generate-app-icon.py")

SIZE   = 1024
RADIUS = 220          # rounded-corner radius (~21 % of 1024)
OUT    = Path("Resources/icon.png")

# ── Canvas ────────────────────────────────────────────────────────────
img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── Gradient background (blue → indigo) ──────────────────────────────
def lerp(a, b, t): return int(a + (b - a) * t)

top_left     = (28,  51, 204)   # #1C33CC  vivid blue
bottom_right = (92,  41, 194)   # #5C29C2  indigo

for y in range(SIZE):
    for x in range(SIZE):
        t = (x + (SIZE - y)) / (2 * SIZE)   # diagonal blend
        r = lerp(top_left[0], bottom_right[0], t)
        g = lerp(top_left[1], bottom_right[1], t)
        b = lerp(top_left[2], bottom_right[2], t)
        draw.point((x, y), fill=(r, g, b, 255))

# ── Decorative translucent circles ───────────────────────────────────
overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
od      = ImageDraw.Draw(overlay)
od.ellipse((570, 460, 570 + 600, 460 + 600), fill=(255, 255, 255, 15))
od.ellipse((-90, -90, 310, 310),              fill=(255, 255, 255, 10))
img = Image.alpha_composite(img, overlay)
draw = ImageDraw.Draw(img)

# ── ">_" text ─────────────────────────────────────────────────────────
font_size = 330
font_paths = [
    "/System/Library/Fonts/SFMono-Regular.otf",
    "/System/Library/Fonts/Menlo.ttc",
    "/System/Library/Fonts/Courier.dfont",
    "/System/Library/Fonts/Monaco.dfont",
]
font = None
for p in font_paths:
    if Path(p).exists():
        try:
            font = ImageFont.truetype(p, font_size)
            break
        except Exception:
            continue
if font is None:
    font = ImageFont.load_default()

text = ">_"
# Measure text bounding box
bbox = draw.textbbox((0, 0), text, font=font)
tw   = bbox[2] - bbox[0]
th   = bbox[3] - bbox[1]
tx   = (SIZE - tw) / 2 - bbox[0]
ty   = (SIZE - th) / 2 - bbox[1] + 8   # +8px optical adjustment

# Soft shadow layer
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd     = ImageDraw.Draw(shadow)
sd.text((tx + 2, ty - 8), text, font=font, fill=(0, 0, 0, 80))
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
img    = Image.alpha_composite(img, shadow)
draw   = ImageDraw.Draw(img)

# White text
draw.text((tx, ty), text, font=font, fill=(255, 255, 255, 237))

# ── Rounded-corner mask ───────────────────────────────────────────────
mask = Image.new("L", (SIZE, SIZE), 0)
md   = ImageDraw.Draw(mask)
md.rounded_rectangle((0, 0, SIZE, SIZE), radius=RADIUS, fill=255)
img.putalpha(mask)

# ── Save ──────────────────────────────────────────────────────────────
OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT, "PNG")
print(f"✓  icon written → {OUT}  ({SIZE}×{SIZE})")
