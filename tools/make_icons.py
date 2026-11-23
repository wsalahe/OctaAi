#!/usr/bin/env python3
"""Generate OctaAi launcher icons from the official logo.

The logo is stored as base64 (assets/logo_mark.b64) because binary uploads
are not used in this repo; CI decodes it and writes the mipmap PNGs plus
the adaptive icon resources.
"""
import base64
import io
import os

from PIL import Image

RES = 'android/app/src/main/res'
BG_HEX = '#2C3240'  # dark slate from the official logo
LEGACY = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
FORE = {'mdpi': 108, 'hdpi': 162, 'xhdpi': 216, 'xxhdpi': 324, 'xxxhdpi': 432}


def load_icon():
    with open('assets/logo_mark.b64') as f:
        data = base64.b64decode(f.read())
    return Image.open(io.BytesIO(data)).convert('RGBA')


def main():
    src = load_icon()

    # Legacy launcher icons: full-bleed logo.
    for dpi, px in LEGACY.items():
        im = src.resize((px, px), Image.LANCZOS)
        out = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(out, exist_ok=True)
        im.save(os.path.join(out, 'ic_launcher.png'))
        im.save(os.path.join(out, 'ic_launcher_round.png'))

    # Adaptive foreground: logo at 66% inside the safe zone, transparent margin.
    for dpi, px in FORE.items():
        im = Image.new('RGBA', (px, px), (0, 0, 0, 0))
        inner = src.resize((int(px * 0.66), int(px * 0.66)), Image.LANCZOS)
        off = (px - inner.size[0]) // 2
        im.paste(inner, (off, off))
        out = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(out, exist_ok=True)
        im.save(os.path.join(out, 'ic_launcher_foreground.png'))

    # Adaptive background color + descriptor.
    values = os.path.join(RES, 'values')
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, 'ic_launcher_background.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<resources>\n'
                '    <color name="ic_launcher_background">' + BG_HEX + '</color>\n'
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
    print('icons written from official logo')


if __name__ == '__main__':
    main()
