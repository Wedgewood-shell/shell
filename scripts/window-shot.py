#!/usr/bin/env python3
"""Put a window screenshot's content over black, leaving its client-side shadow alone.

Usage: window-shot.py flatten <image.png> <niri-window-id>

`niri msg action screenshot-window` renders the window's whole bounding box, which
includes any client-side shadow. Only the window geometry rectangle is composited
over black. Rounded corners inside that rectangle stay transparent.
"""
import json
import os
import subprocess
import sys
import time

import numpy as np
from PIL import Image


def niri(*args):
    return json.loads(subprocess.run(["niri", "msg", "--json", *args], check=True,
                                     capture_output=True, text=True).stdout)


def geometry_size(window_id):
    """Window geometry size in screenshot (physical) pixels."""
    window = next(w for w in niri("windows") if w["id"] == window_id)
    workspace = next(w for w in niri("workspaces") if w["id"] == window["workspace_id"])
    output = niri("outputs")[workspace["output"]]
    scale = output["logical"]["scale"]
    w, h = window["layout"]["window_size"]
    return round(w * scale), round(h * scale)


def locate(alpha, w, h):
    """Place the geometry rectangle where it covers the most opacity.

    Shadows are faint compared to window content, so shifting the rectangle into
    the shadow always loses more alpha than it gains.
    """
    ih, iw = alpha.shape
    if w >= iw and h >= ih:
        return 0, 0, iw, ih
    w, h = min(w, iw), min(h, ih)
    table = np.pad(alpha.astype(np.int64).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    sums = table[h:, w:] - table[:-h, w:] - table[h:, :-w] + table[:-h, :-w]
    y, x = np.unravel_index(np.argmax(sums), sums.shape)
    return int(x), int(y), w, h


def corner_coverage(alpha):
    """Coverage of the window's own rounded corners inside the rectangle.

    Each corner is compared with the opacity of the window edge next to it (the
    edge may itself be translucent). Starting at the rectangle corner, flood
    through pixels clearly fainter than that edge: these are the corner cutout
    and its antialiasing, and keep a proportional opacity. The rest is content.
    """
    h, w = alpha.shape
    coverage = np.ones((h, w), dtype=np.float32)
    box = max(1, min(64, w // 4, h // 4))
    for right, bottom in ((0, 0), (1, 0), (0, 1), (1, 1)):
        ys = slice(h - box, h) if bottom else slice(0, box)
        xs = slice(w - box, w) if right else slice(0, box)
        region = alpha[ys, xs]
        row = alpha[-1 if bottom else 0, (w - 2 * box if right else box):(w - box if right else 2 * box)]
        col = alpha[(h - 2 * box if bottom else box):(h - box if bottom else 2 * box), -1 if right else 0]
        edge = max(float(np.median(row)) if row.size else 0, float(np.median(col)) if col.size else 0)
        if edge <= 0:
            continue
        faint = region < edge * 0.9
        start = (box - 1 if bottom else 0, box - 1 if right else 0)
        if not faint[start]:
            continue
        flooded = np.zeros_like(faint)
        flooded[start] = True
        stack = [start]
        while stack:
            cy, cx = stack.pop()
            for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                if 0 <= ny < box and 0 <= nx < box and faint[ny, nx] and not flooded[ny, nx]:
                    flooded[ny, nx] = True
                    stack.append((ny, nx))
        coverage[ys, xs][flooded] = region[flooded] / edge
    return coverage


def wait_for_png(path, timeout=2.0):
    """niri writes screenshots from a worker thread after the IPC call returns."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            with open(path, "rb") as f:
                f.seek(-8, os.SEEK_END)
                if f.read(4) == b"IEND":
                    return
        except OSError:
            pass
        time.sleep(0.01)
    sys.exit(f"screenshot was not written: {path}")


def flatten(path, window_id):
    wait_for_png(path)
    image = Image.open(path).convert("RGBA")
    pixels = np.array(image).astype(np.float32)
    x, y, w, h = locate(pixels[:, :, 3], *geometry_size(window_id))
    window = pixels[y:y + h, x:x + w]
    alpha = window[:, :, 3]
    if not np.any(alpha < 255):
        return
    coverage = corner_coverage(alpha)
    # Content over black, then cut the corners back out with their coverage.
    opaque = window[:, :, :3] * (alpha[..., None] / 255.0)
    covered = np.clip(coverage, 1e-6, 1)[..., None]
    window[:, :, :3] = np.clip(opaque / covered, 0, 255)
    window[:, :, 3] = coverage * 255
    Image.fromarray(np.round(pixels).astype(np.uint8)).save(path)


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] != "flatten":
        sys.exit(__doc__)
    flatten(sys.argv[2], int(sys.argv[3]))
