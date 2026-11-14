#!/usr/bin/env python3
"""Window screenshot preview helper for Quickshell capture menu.

Usage:
    window-preview.py <window_id>
    window-preview.py --all <id1> <id2> ...
    window-preview.py --apply-bg <image_path>
"""
import os
import sys
import time
import subprocess
from pathlib import Path

def get_runtime_dir():
    base = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
    p = Path(base) / "quickshell-previews"
    p.mkdir(parents=True, exist_ok=True)
    return p

def apply_black_background(image_path):
    """Composites semi-transparent window content over black, leaving outer corners transparent."""
    try:
        from PIL import Image, ImageDraw
        import numpy as np

        with Image.open(image_path) as im:
            if im.mode != "RGBA":
                return
            arr = np.array(im)
            if not np.any(arr[:, :, 3] < 255):
                return

            w, h = im.size
            corner_pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
            has_transparent_corners = any(arr[cy, cx, 3] == 0 for cx, cy in corner_pts)

            if not has_transparent_corners:
                # Rectangular window (e.g. Kitty terminal): all pixels inside window
                arr[:, :, 3] = 255
            else:
                # Window with transparent outer corners (e.g. rounded client corners)
                alpha = im.getchannel("A")
                mask = alpha.point(lambda p: 255 if p == 0 else 0, mode="L")
                for pt in corner_pts:
                    if mask.getpixel(pt) == 255:
                        ImageDraw.floodfill(mask, pt, 128)
                mask_arr = np.array(mask)
                is_inside = (mask_arr != 128) & (arr[:, :, 3] > 0)
                arr[is_inside, 3] = 255

            out = Image.fromarray(arr)
            out.save(image_path)
    except Exception:
        pass

def capture_window(window_id, runtime_dir):
    final_path = runtime_dir / f"preview-{window_id}.png"
    tmp_path = runtime_dir / f"tmp-{window_id}-{os.getpid()}.png"
    try:
        res = subprocess.run(
            ["niri", "msg", "action", "screenshot-window", "--id", str(window_id), "--path", str(tmp_path)],
            capture_output=True, text=True, timeout=2
        )
        if res.returncode != 0:
            return None
        # Wait up to 350ms for file to be completely written by checking PNG IEND chunk
        for _ in range(70):
            time.sleep(0.005)
            if tmp_path.exists() and tmp_path.stat().st_size > 100:
                try:
                    with open(tmp_path, "rb") as f:
                        f.seek(-8, os.SEEK_END)
                        if f.read(4) == b"IEND":
                            apply_black_background(tmp_path)
                            os.replace(tmp_path, final_path)
                            return final_path
                except Exception:
                    pass
    except Exception:
        pass
    finally:
        if tmp_path.exists():
            try:
                tmp_path.unlink()
            except OSError:
                pass
    return final_path if final_path.exists() else None

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    if sys.argv[1] == "--apply-bg":
        if len(sys.argv) >= 3:
            apply_black_background(sys.argv[2])
            sys.exit(0)
        sys.exit(1)

    runtime_dir = get_runtime_dir()

    if sys.argv[1] == "--all":
        for arg in sys.argv[2:]:
            try:
                win_id = int(arg)
                capture_window(win_id, runtime_dir)
            except ValueError:
                pass
        sys.exit(0)

    try:
        target_id = int(sys.argv[1])
    except ValueError:
        sys.exit(1)

    # Check if a fresh preview (< 5s old) already exists
    final_path = runtime_dir / f"preview-{target_id}.png"
    if final_path.exists():
        try:
            if (time.time() - final_path.stat().st_mtime) < 5.0:
                print(final_path)
                sys.exit(0)
        except OSError:
            pass

    out = capture_window(target_id, runtime_dir)
    if out:
        print(out)
        sys.exit(0)
    sys.exit(1)

if __name__ == "__main__":
    main()
