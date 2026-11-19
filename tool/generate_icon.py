"""Draws the app icon: two stacked flashcards on a teal gradient.

Writes three 1024x1024 PNGs to assets/icon/:
  app_icon.png             full icon (iOS, older Android, desktop, web)
  app_icon_background.png  gradient layer for the Android adaptive icon
  app_icon_foreground.png  transparent card layer for the adaptive icon

Android crops adaptive icons to a circle, squircle or rounded square that can
be as small as the middle 61% of the layer, so the cards are kept inside that
circle. Then regenerate the platform icons with:

  pip install pillow
  python tool/generate_icon.py
  dart run flutter_launcher_icons
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 1024
SS = 4  # draw at 4x and downscale, for smooth edges
S = SIZE * SS

TEAL_LIGHT = (2, 191, 201)    # AppTheme.tealLight
TEAL = (0, 173, 181)          # AppTheme.teal
TEAL_DEEP = (1, 92, 110)      # darker end of the gradient
CARD_DARK = (34, 40, 49)      # AppTheme.darkCard
CARD_LIGHT = (250, 250, 250)

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def gradient():
    """Diagonal gradient, light teal top-left to deep teal bottom-right."""
    small = Image.new("RGB", (256, 256))
    px = small.load()
    for y in range(256):
        for x in range(256):
            t = (x + y) / 510
            # two-stop blend through the brand teal
            if t < 0.5:
                a, b, k = TEAL_LIGHT, TEAL, t / 0.5
            else:
                a, b, k = TEAL, TEAL_DEEP, (t - 0.5) / 0.5
            px[x, y] = tuple(round(a[i] + (b[i] - a[i]) * k) for i in range(3))
    return small.resize((SIZE, SIZE), Image.BICUBIC)


def card(w, h, radius, fill):
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle((0, 0, w - 1, h - 1), radius, fill=fill)
    return layer


def font(px):
    for name in ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, px)
        except OSError:
            pass
    return ImageFont.load_default(px)


def paste_centered(canvas, layer, cx, cy):
    canvas.alpha_composite(layer, (round(cx - layer.width / 2), round(cy - layer.height / 2)))


def foreground():
    canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cw, ch, r = int(S * 0.275), int(S * 0.365), int(S * 0.042)
    cx, cy = S / 2, S / 2

    # Back card: dark, tilted left, offset up-left.
    back = card(cw, ch, r, CARD_DARK + (255,)).rotate(12, Image.BICUBIC, expand=True)
    paste_centered(canvas, back, cx - S * 0.045, cy - S * 0.015)

    # Front card with a teal "?", tilted right, offset down-right.
    front = card(cw, ch, r, CARD_LIGHT + (255,))
    d = ImageDraw.Draw(front)
    f = font(int(ch * 0.62))
    d.text((cw / 2, ch / 2 + ch * 0.02), "?", font=f, fill=TEAL_DEEP + (255,), anchor="mm")
    # small "answer" line under the glyph
    lw, lh = cw * 0.42, ch * 0.045
    d.rounded_rectangle((cw / 2 - lw / 2, ch * 0.83, cw / 2 + lw / 2, ch * 0.83 + lh), lh / 2,
                        fill=TEAL + (255,))
    front = front.rotate(-8, Image.BICUBIC, expand=True)

    fx, fy = cx + S * 0.05, cy + S * 0.02
    shadow = Image.new("RGBA", front.size, (0, 0, 0, 0))
    shadow.putalpha(front.getchannel("A").point(lambda a: a * 0.35))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.018))
    paste_centered(canvas, shadow, fx + S * 0.012, fy + S * 0.025)
    paste_centered(canvas, front, fx, fy)

    return canvas.resize((SIZE, SIZE), Image.LANCZOS)


def check_safe_zone(fg):
    """Every visible pixel must sit inside the adaptive-icon safe circle."""
    safe_r = SIZE * 66 / 108 / 2
    a = fg.getchannel("A").load()
    worst = max(
        (math.hypot(x - SIZE / 2, y - SIZE / 2)
         for y in range(0, SIZE, 2) for x in range(0, SIZE, 2) if a[x, y] > 8),
        default=0,
    )
    print(f"furthest visible pixel: {worst:.0f}px from centre (safe radius {safe_r:.0f}px)")
    assert worst <= safe_r, "cards stick out of the adaptive icon safe zone"


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = gradient()
    fg = foreground()
    check_safe_zone(fg)

    bg.save(os.path.join(OUT, "app_icon_background.png"))
    fg.save(os.path.join(OUT, "app_icon_foreground.png"))

    # Full icon: the same layers, cards scaled up a little since iOS and
    # desktop crop less than Android.
    full = bg.convert("RGBA")
    big = fg.resize((int(SIZE * 1.4),) * 2, Image.LANCZOS)
    paste_centered(full, big, SIZE / 2, SIZE / 2)
    full.convert("RGB").save(os.path.join(OUT, "app_icon.png"))
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
