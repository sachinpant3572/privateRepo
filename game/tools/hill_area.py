#!/usr/bin/env python3
"""Measures the hill country in data/country.json: rolling ground a player
can explore, not cliffs and not the flat city.

A cell counts as hill ground when its height is between LOW and HIGH, its
slope is at most MAX_SLOPE, and it lies within REACH of a drivable road or
track or a trail. The script prints the total, then the totals per height
band and per slope band, so the design map can see where the ground is.

  python3 tools/hill_area.py [data/country.json] [--png out.png]
"""
import base64
import json
import sys

import numpy as np

LOW, HIGH = 3.0, 450.0     # m: above the plain, below the high mountain
MAX_SLOPE = 0.45           # rise over run: a 4x4 or a walker manages it
REACH = 150.0              # m from a road, track or trail


def load(path):
    d = json.load(open(path))
    t = d["terrain"]
    nx, ny = t["size"]
    h = np.frombuffer(base64.b64decode(t["dm"]), dtype="<u2").astype(float).reshape(ny, nx) / 10.0
    return d, h, t["origin"], t["cell"]


def reach_mask(d, origin, cell, shape):
    """Cells within REACH of a drivable road or a trail (a distance
    transform of the rasterised lines)."""
    from scipy.ndimage import distance_transform_edt
    ny, nx = shape
    lines = np.zeros(shape, dtype=bool)
    nodes = d["nodes"]

    def draw(pts):
        for a, b in zip(pts, pts[1:]):
            n = max(2, int(np.hypot(b[0] - a[0], b[1] - a[1]) / (cell * 0.5)))
            for f in np.linspace(0.0, 1.0, n):
                x = (a[0] + (b[0] - a[0]) * f - origin[0]) / cell
                y = (a[1] + (b[1] - a[1]) * f - origin[1]) / cell
                i, j = int(round(y)), int(round(x))
                if 0 <= i < ny and 0 <= j < nx:
                    lines[i, j] = True

    for r in d["roads"]:
        draw([nodes[n] for n in r["nodes"]])
    for t in d["trails"]:
        draw(t["pts"])
    return distance_transform_edt(~lines) * cell <= REACH


def main():
    argv = sys.argv[1:]
    png = None
    if "--png" in argv:
        k = argv.index("--png")
        png = argv[k + 1]
        del argv[k:k + 2]
    args = argv
    path = args[0] if args else "data/country.json"
    d, h, origin, cell = load(path)
    gy, gx = np.gradient(h, cell)
    slope = np.hypot(gx, gy)
    band = (h >= LOW) & (h <= HIGH)
    gentle = slope <= MAX_SLOPE
    near = reach_mask(d, origin, cell, h.shape)
    km2 = cell * cell / 1e6
    hill = band & gentle & near
    print("hill ground: %.2f km2 (%.0f-%.0f m, slope <= %.2f, within %.0f m of a road or trail)"
          % (hill.sum() * km2, LOW, HIGH, MAX_SLOPE, REACH))
    print("  same, no reach limit: %.2f km2" % ((band & gentle).sum() * km2))
    print("  all ground over %.0f m: %.2f km2" % (LOW, (h >= LOW).sum() * km2))
    for lo, hi in [(3, 50), (50, 120), (120, 200), (200, 300), (300, 450), (450, 700), (700, 1100)]:
        m = (h >= lo) & (h < hi)
        print("  %4d-%4d m: %.2f km2 ground, %.2f gentle, %.2f gentle and reached"
              % (lo, hi, m.sum() * km2, (m & gentle).sum() * km2, (m & gentle & near).sum() * km2))
    if png:
        from PIL import Image
        out = png
        img = np.zeros(h.shape + (3,), dtype=np.uint8)
        shade = np.clip(h / 1000.0 * 200 + 40, 0, 255).astype(np.uint8)
        img[..., 0] = img[..., 1] = img[..., 2] = shade
        img[band & gentle] = [120, 170, 90]
        img[hill] = [60, 140, 50]
        img[h < LOW] = [30, 30, 40]
        Image.fromarray(img).save(out)
        print("saved", out)


if __name__ == "__main__":
    main()
