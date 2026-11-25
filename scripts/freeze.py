#!/usr/bin/env python3
"""Helpers for region screenshots of a frozen screen.

freeze.py grab FILE         grim the whole desktop to FILE; prints "ORIGIN_X ORIGIN_Y SCALE"
                            (layout position of the image's top-left, and pixels per logical px)
freeze.py crop FILE X Y W H write FILE cropped to the logical rectangle to stdout as PNG
"""
import json
import subprocess
import sys

from PIL import Image


def layout():
    out = json.loads(subprocess.check_output(["niri", "msg", "--json", "outputs"]))
    rects = [o["logical"] for o in out.values() if o.get("logical")]
    x0 = min(r["x"] for r in rects)
    y0 = min(r["y"] for r in rects)
    x1 = max(r["x"] + r["width"] for r in rects)
    return x0, y0, x1 - x0


def main():
    cmd = sys.argv[1]
    path = sys.argv[2]
    x0, y0, width = layout()
    if cmd == "grab":
        subprocess.check_call(["grim", path])
        with Image.open(path) as im:
            scale = im.width / width
        print(x0, y0, scale)
    elif cmd == "crop":
        x, y, w, h = (float(v) for v in sys.argv[3:7])
        with Image.open(path) as im:
            scale = im.width / width
            box = (round((x - x0) * scale), round((y - y0) * scale), round((x - x0 + w) * scale), round((y - y0 + h) * scale))
            im.crop(box).save(sys.stdout.buffer, "PNG")
    else:
        sys.exit(__doc__)


main()
