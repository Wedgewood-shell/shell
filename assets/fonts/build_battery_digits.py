#!/usr/bin/env python3
"""Build the battery icon's digit font and its enclosed-region table.

Needs: pip install fonttools skia-pathops

1. BatteryDigits.ttf: SN Pro (OFL) at weight 600, subset to 0-9, overlaps
   removed, renamed so it can't clash with an installed SN Pro.
2. components/BatteryHoles.js: for every percentage 0..100, the regions the
   number's halo encloses (the figures' loops, and pockets sealed off where
   neighbouring halos touch). The icon fills them in the outline colour.

The layout constants must match components/BatteryIndicator.qml.
"""
import json
import pathlib
import urllib.request

import pathops
from fontTools.subset import Options, Subsetter
from fontTools.ttLib import TTFont
from fontTools.ttLib.removeOverlaps import removeOverlaps
from fontTools.varLib.instancer import instantiateVariableFont

HERE = pathlib.Path(__file__).resolve().parent
OUT_FONT = HERE / "BatteryDigits.ttf"
OUT_HOLES = HERE.parent.parent / "components" / "BatteryHoles.js"
SOURCE = "https://github.com/google/fonts/raw/main/ofl/snpro/SNPro%5Bwght%5D.ttf"

# Must match BatteryIndicator.qml: halo radius 5 and size 62 (canvas units), and
# tracking in font units.
HALO = 5 / (62 / 1000)
TRACKING = -45
# Ignore slivers smaller than this (font units squared).
MIN_AREA = 400
# Grow each region into the surrounding halo so its edge never leaves a seam.
TUCK = HALO * 0.4
# Curve flattening steps per segment.
STEPS = 6


def build_font():
    src = HERE / "SNPro-source.ttf"
    if not src.exists():
        urllib.request.urlretrieve(SOURCE, src)
    font = instantiateVariableFont(TTFont(src), {"wght": 600})
    opts = Options()
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    sub = Subsetter(opts)
    sub.populate(text="0123456789")
    sub.subset(font)
    removeOverlaps(font)
    for rec in font["name"].names:
        if rec.nameID in (1, 4, 16):
            rec.string = "Battery Digits"
        elif rec.nameID in (2, 17):
            rec.string = "Regular"
        elif rec.nameID == 6:
            rec.string = "BatteryDigits-Regular"
    font["OS/2"].usWeightClass = 400
    font.save(OUT_FONT)
    src.unlink()


def glyph_path(font, ch, dx):
    glyphs = font.getGlyphSet()
    name = font.getBestCmap()[ord(ch)]
    path = pathops.Path()
    glyphs[name].draw(path.getPen())
    return path.transform(1, 0, 0, 1, dx, 0)


def flatten(path):
    """Contours of `path` as flat [x0, y0, x1, y1, ...] polygons."""
    out = []
    for contour in path.contours:
        pts = []
        cur = None
        for verb, args in contour.segments:
            if verb == "moveTo":
                cur = args[0]
                pts.append(cur)
            elif verb == "lineTo":
                cur = args[0]
                pts.append(cur)
            elif verb == "qCurveTo":
                # TrueType-style implied on-curve points.
                ctrl = list(args)
                on = ctrl.pop()
                p0 = cur
                for i, c in enumerate(ctrl):
                    end = on if i == len(ctrl) - 1 else ((c[0] + ctrl[i + 1][0]) / 2, (c[1] + ctrl[i + 1][1]) / 2)
                    for k in range(1, STEPS + 1):
                        t = k / STEPS
                        pts.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * c[0] + t * t * end[0],
                                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * c[1] + t * t * end[1]))
                    p0 = end
                cur = on
            elif verb == "curveTo":
                c1, c2, end = args
                p0 = cur
                for k in range(1, STEPS + 1):
                    t = k / STEPS
                    mt = 1 - t
                    pts.append((mt ** 3 * p0[0] + 3 * mt * mt * t * c1[0] + 3 * mt * t * t * c2[0] + t ** 3 * end[0],
                                mt ** 3 * p0[1] + 3 * mt * mt * t * c1[1] + 3 * mt * t * t * c2[1] + t ** 3 * end[1]))
                cur = end
        out.append(pts)
    return out


def simplify(pts, tol=3.0):
    """Douglas-Peucker on a closed polygon."""
    def dp(seg):
        if len(seg) < 3:
            return seg
        (x0, y0), (x1, y1) = seg[0], seg[-1]
        dx, dy = x1 - x0, y1 - y0
        norm = (dx * dx + dy * dy) ** 0.5 or 1
        far, idx = 0, 0
        for i in range(1, len(seg) - 1):
            d = abs(dy * (seg[i][0] - x0) - dx * (seg[i][1] - y0)) / norm
            if d > far:
                far, idx = d, i
        if far <= tol:
            return [seg[0], seg[-1]]
        return dp(seg[: idx + 1])[:-1] + dp(seg[idx:])
    # Split at the point farthest from the first so both halves are open chains.
    far = max(range(len(pts)), key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
    return dp(pts[: far + 1])[:-1] + dp(pts[far:] + [pts[0]])[:-1]


def area(pts):
    return sum(pts[i][0] * pts[i - 1][1] - pts[i - 1][0] * pts[i][1] for i in range(len(pts))) / 2


def holes_for(font, label):
    hmtx = font["hmtx"]
    cmap = font.getBestCmap()
    shape = pathops.Path()
    x = 0
    for ch in label:
        glyph = glyph_path(font, ch, x)
        halo = pathops.Path()
        halo.addPath(glyph)
        halo.stroke(2 * HALO, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
        halo.convertConicsToQuads()
        shape = pathops.op(shape, glyph, pathops.PathOp.UNION)
        shape = pathops.op(shape, halo, pathops.PathOp.UNION)
        x += hmtx[cmap[ord(ch)]][0] + TRACKING
    contours = flatten(shape)
    areas = [area(c) for c in contours]
    outer = max(areas, key=abs)
    regions = []
    for pts, a in zip(contours, areas):
        # Holes wind opposite to the outer contour.
        if (a > 0) == (outer > 0) or abs(a) < MIN_AREA:
            continue
        hole = pathops.Path()
        pen = hole.getPen()
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
        grown = pathops.Path()
        grown.addPath(hole)
        grown.stroke(2 * TUCK, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4)
        grown.convertConicsToQuads()
        hole = pathops.op(hole, grown, pathops.PathOp.UNION)
        for poly in flatten(hole):
            if abs(area(poly)) >= MIN_AREA:
                regions.append([round(v) for p in simplify(poly) for v in p])
    return regions


def main():
    build_font()
    font = TTFont(OUT_FONT)
    table = {}
    for n in range(101):
        regions = holes_for(font, str(n))
        if regions:
            table[str(n)] = regions
    body = json.dumps(table, separators=(",", ":"))
    OUT_HOLES.write_text(
        ".pragma library\n"
        "// Generated by assets/fonts/build_battery_digits.py; do not edit.\n"
        "// For each percentage, polygons [x0, y0, x1, y1, ...] in font units (y up),\n"
        "// relative to the first figure's pen position on the baseline: the regions\n"
        "// the number's halo encloses, filled in the outline colour.\n"
        f"var holes = {body}\n"
    )
    print(f"{len(table)} labels with enclosed regions, {OUT_HOLES.stat().st_size} bytes")


if __name__ == "__main__":
    main()
