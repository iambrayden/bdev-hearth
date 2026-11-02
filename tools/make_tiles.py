#!/usr/bin/env python3
"""
Cut a high-resolution map image into Leaflet tiles for Hearth.

    pip install pillow
    python tools/make_tiles.py path/to/big-map.png

Uses the bounds from config.lua (Config.Map.Bounds) unless --bounds is given, writes
html/map/tiles/{z}/{x}/{y}.webp, and prints the Config.Map.Tiles block to paste into
config.lua. Tile coordinates match Leaflet's CRS.Simple with world coords as lat/lng,
which is what html/app.js uses.

A different render of the map needs new bounds; a higher-resolution export of the
same render keeps the existing ones.
"""
import argparse
import math
import os
import re
import shutil

from PIL import Image

Image.MAX_IMAGE_PIXELS = None  # map renders are big on purpose

TILE = 256


def bounds_from_config(path):
    text = open(path, encoding='utf-8').read()
    m = re.search(r'Bounds\s*=\s*\{([^}]*)\}', text)
    if not m:
        raise SystemExit('Could not find Config.Map.Bounds in ' + path)
    vals = dict(re.findall(r'(minX|maxX|minY|maxY)\s*=\s*(-?[\d.]+)', m.group(1)))
    return {k: float(vals[k]) for k in ('minX', 'maxX', 'minY', 'maxY')}


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('image')
    ap.add_argument('--out', default=os.path.join(root, 'html', 'map', 'tiles'))
    ap.add_argument('--bounds', nargs=4, type=float, metavar=('MINX', 'MAXX', 'MINY', 'MAXY'))
    ap.add_argument('--min-zoom', type=int, default=-6)
    ap.add_argument('--quality', type=int, default=80)
    ap.add_argument('--background', default='#0a2250', help='colour for tile areas outside the image')
    args = ap.parse_args()

    b = (dict(zip(('minX', 'maxX', 'minY', 'maxY'), args.bounds)) if args.bounds
         else bounds_from_config(os.path.join(root, 'config.lua')))
    src = Image.open(args.image).convert('RGB')
    W, H = src.size
    world_w, world_h = b['maxX'] - b['minX'], b['maxY'] - b['minY']
    native = math.log2(W / world_w)
    aspect_err = abs((W / world_w) / (H / world_h) - 1)
    if aspect_err > 0.01:
        print(f'warning: image aspect differs from bounds by {aspect_err:.1%}; is this the same render?')
    max_zoom = math.ceil(native)
    print(f'{W}x{H}px, {W / world_w:.3f} px per metre, native zoom {native:.2f}; tiles z={args.min_zoom}..{max_zoom}')

    if os.path.isdir(args.out):
        shutil.rmtree(args.out)
    total = 0
    for z in range(args.min_zoom, max_zoom + 1):
        s = 2.0 ** z  # level pixels per world unit
        f = s / (W / world_w)
        lw, lh = max(1, round(W * f)), max(1, round(H * f))
        level = src.resize((lw, lh), Image.LANCZOS)
        # Level-pixel position of the image's top-left corner (CRS.Simple: px = x*s, py = -y*s).
        ox, oy = b['minX'] * s, -b['maxY'] * s
        tx0, tx1 = math.floor(ox / TILE), math.floor((ox + lw - 1) / TILE)
        ty0, ty1 = math.floor(oy / TILE), math.floor((oy + lh - 1) / TILE)
        for tx in range(tx0, tx1 + 1):
            d = os.path.join(args.out, str(z), str(tx))
            os.makedirs(d, exist_ok=True)
            for ty in range(ty0, ty1 + 1):
                left, top = tx * TILE - ox, ty * TILE - oy  # tile origin inside the level image
                tile = Image.new('RGB', (TILE, TILE), args.background)
                box = (max(0, round(left)), max(0, round(top)),
                       min(lw, round(left) + TILE), min(lh, round(top) + TILE))
                if box[2] > box[0] and box[3] > box[1]:
                    tile.paste(level.crop(box), (box[0] - round(left), box[1] - round(top)))
                tile.save(os.path.join(d, f'{ty}.webp'), 'WEBP', quality=args.quality, method=4)
                total += 1
        print(f'  z={z}: {(tx1 - tx0 + 1) * (ty1 - ty0 + 1)} tiles')

    size = sum(os.path.getsize(os.path.join(dp, fn)) for dp, _, fns in os.walk(args.out) for fn in fns)
    print(f'{total} tiles, {size / 1e6:.1f} MB in {args.out}\n')
    print('Paste into Config.Map in config.lua:\n')
    print(f"    Tiles = {{ Url = 'map/tiles/{{z}}/{{x}}/{{y}}.webp', MinZoom = {args.min_zoom}, MaxZoom = {max_zoom} }},")


if __name__ == '__main__':
    main()
