#!/usr/bin/env python3
"""Generate OctaAi launcher icons (mipmap PNGs + adaptive icon) in CI."""
import math
import os
from PIL import Image, ImageDraw

TEAL = (46, 196, 182, 255)  # #2EC4B6
RES = 'android/app/src/main/res'

LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
FORE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}


def octagon(cx, cy, radius, rot=math.pi / 8):
    return [(cx + radius * math.cos(rot + i * math.pi / 4),
             cy + radius * math.sin(rot + i * math.pi / 4)) for i in range(8)]


def draw_mark(d, cx, cy, r):
    outer = octagon(cx, cy, r)
    d.line(outer + [outer[0]], fill=TEAL, width=max(2, int(r * 0.11)), joint='curve')
    inner = octagon(cx, cy, r * 0.62)
    d.line(inner + [inner[0]], fill=TEAL, width=max(1, int(r * 0.045)), joint='curve')
    d.line([(cx - r * 1.18, cy), (cx + r * 1.18, cy)], fill=TEAL,
           width=max(1, int(r * 0.04)))


def gradient(size):
    im = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(im)
    top, bot = (14, 51, 56), (4, 10, 14)  # dark teal to near-black
    for y in range(size):
        t = y / size
        d.line([(0, y), (size, y)],
               fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return im


def main():
    # Legacy launcher icons: mark on gradient, full bleed.
    for dpi, px in LEGACY.items():
        im = gradient(px)
        d = ImageDraw.Draw(im)
        draw_mark(d, px / 2, px / 2, px * 0.36)
        out = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(out, exist_ok=True)
        im.save(os.path.join(out, 'ic_launcher.png'))
        im.save(os.path.join(out, 'ic_launcher_round.png'))

    # Adaptive foreground: transparent, mark inside safe zone.
    for dpi, px in FORE.items():
        im = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        draw_mark(d, px / 2, px / 2, px * 0.24)
        out = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(out, exist_ok=True)
        im.save(os.path.join(out, 'ic_launcher_foreground.png'))

    # Adaptive background color + descriptor.
    values = os.path.join(RES, 'values')
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                '    <color name="ic_launcher_background">#0E3338</color>\n'
                '</resources>\n')
    anydpi = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(anydpi, exist_ok=True)
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        with open(os.path.join(anydpi, name), 'w') as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                    '    <background android:drawable="@color/ic_launcher_background"/>\n'
                    '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
                    '</adaptive-icon>\n')
    print('icons written')


if __name__ == '__main__':
    main()
