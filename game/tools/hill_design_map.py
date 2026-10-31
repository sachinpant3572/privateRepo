#!/usr/bin/env python3
"""Draws the hill-country design map: the land as built (relief, roads,
tracks, trails, rails, peaks and viewpoints) with the content Sachin asked
for placed on it as PROPOSALS (nothing in PLACES or ZONES is built).

  python3 tools/hill_design_map.py [data/country.json] [--out ../docs/hill_country_design_map.png]

Coordinates are game metres (x east, y south; the hills lie at negative y).
The lists below are the design: change them here, rerun, commit the PNG.
"""
import base64
import json
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter

SCALE = 2                     # pixels per terrain cell (8 m), so 4 m a pixel
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Zones: (kind, label, polygon in game metres). Quiet zones keep events,
# races and raves out; busy zones hold them; the ring BUFFER m round each
# busy zone holds neither. Forest and closed zones are drawn first.
BUFFER = 250.0
ZONES = [
    ("forest", "Great back-range forest", [(-550, -4950), (1150, -4950), (1150, -4150),
                                           (850, -4100), (800, -3500), (-550, -3500)]),
    ("closed", "Lab valley (closed)", [(870, -4060), (1450, -4060), (1450, -3420), (870, -3420)]),
    ("quiet", "Fernmoor quiet country", [(1650, -4950), (2350, -4950), (2400, -4380), (1650, -4300)]),
    ("quiet", "Whistler-Tallow quiet ridge", [(2350, -4200), (2850, -4200), (2850, -3500), (2350, -3500)]),
    ("quiet", "High range", [(150, -3400), (1950, -3400), (1950, -2500), (150, -2500)]),
    ("busy", "East Hills Road strip", [(2150, -2500), (3000, -2500), (3000, -2050), (2150, -2050)]),
    ("busy", "Copperback race country", [(2350, -3250), (2950, -3250), (2950, -2650), (2350, -2650)]),
]

# Places: (kind, label, x, y[, "left"]). All proposals; main() prints each one's
# height and nearest road so the notes stay true when the land changes.
PLACES = [
    ("town", "Brackett village (diner, store, fuel)", 2300, -2180),
    ("truck", "East Hills truck stop", 2800, -2300),
    ("trailer", "Copperback trailer town", 2720, -2900),
    ("race", "Hill race start", 2780, -2520),
    ("jump", "Stunt jump", 2610, -3050),
    ("rave", "Rave clearing", 2480, -3120),
    ("rave", "Rave clearing", 2900, -2850),
    ("cult", "Cult compound (fictional faith)", 2140, -3960),
    ("lab", "Secret research lab", 1180, -3720),
    ("gate", "Lab gate (guarded road)", 1394, -4273),
    ("hot", "Raven hot spring", 560, -3330),
    ("cold", "Whistler cold spring", 2620, -3800),
    ("hot", "Fernmoor hot spring", 2050, -4600),
    ("cold", "Tallow cold spring", 2440, -4040),
    ("logging", "Illegal logging camp", -300, -3800),
    ("hotel", "5-star hotel by the summit restaurant", 905, -2800, "left"),
    ("hotel", "Whistler lodge hotel", 2560, -3610),
]

# Streams run downhill from these sources on the smoothed ground until the
# plain or a basin; a basin becomes a lake (radius in m).
STREAMS = [("Raven Creek", 560, -3330), ("Lab creek", 1180, -3720),
           ("Copperback brook", 2250, -3400), ("Whistler brook", 2620, -3800)]
LAKES = [("Tallow Lake", 2248, -4144, 110), ("Fernmoor Pond", 1752, -4512, 60)]

ROAD_COL = {0: (250, 220, 90), 1: (250, 200, 80), 2: (240, 240, 240), 3: (230, 230, 230),
            4: (220, 220, 220), 5: (210, 210, 210), 6: (196, 150, 96)}
ZONE_COL = {"quiet": (80, 170, 240), "busy": (240, 120, 60), "closed": (220, 40, 40),
            "forest": (40, 120, 50)}
PLACE_COL = {"town": (255, 255, 255), "truck": (255, 210, 60), "trailer": (230, 180, 120),
             "cult": (190, 80, 220), "lab": (230, 30, 30), "gate": (230, 30, 30),
             "hot": (255, 120, 80), "cold": (120, 200, 255), "rave": (255, 60, 200),
             "logging": (150, 100, 40), "hotel": (255, 230, 120), "eat": (255, 255, 160),
             "race": (255, 140, 0), "jump": (255, 140, 0)}
WATER = (70, 150, 240)


def load(path):
    d = json.load(open(path))
    t = d["terrain"]
    nx, ny = t["size"]
    h = np.frombuffer(base64.b64decode(t["dm"]), dtype="<u2").astype(float).reshape(ny, nx) / 10.0
    return d, h, t["origin"], t["cell"]


def relief(h, cell):
    """Hillshade from the north-west, tinted by height."""
    gy, gx = np.gradient(h, cell)
    lx, ly, lz = -0.6, -0.6, 0.53
    shade = np.clip((-gx * lx - gy * ly + lz) / np.sqrt(1 + gx * gx + gy * gy), 0, 1)
    t = np.clip(h / 1000.0, 0, 1)[..., None]
    low, high = np.array([96, 120, 80]), np.array([200, 190, 170])
    col = low * (1 - t) + high * t
    img = col * (0.35 + 0.75 * shade[..., None])
    img[h < 3.0] = [70, 72, 78]                       # the plain and the city
    return np.clip(img, 0, 255).astype(np.uint8)


def stream(hs, h, origin, cell, x, y):
    """Steepest descent on the smoothed ground from (x, y) until the plain
    (under 3 m) or a basin."""
    i, j = int((y - origin[1]) / cell), int((x - origin[0]) / cell)
    path = [(x, y)]
    for _ in range(3000):
        w = hs[max(i - 1, 0):i + 2, max(j - 1, 0):j + 2]
        a, b = np.unravel_index(np.argmin(w), w.shape)
        ni, nj = max(i - 1, 0) + a, max(j - 1, 0) + b
        if (ni, nj) == (i, j):
            break
        i, j = ni, nj
        path.append((origin[0] + j * cell, origin[1] + i * cell))
        if h[i, j] < 3.0:
            break
    return path


def nearest(d, x, y):
    """The closest named road, track or trail to (x, y) and its distance."""
    best = ("", 1e9)
    nodes = d["nodes"]
    lines = [(r["name"] or "unnamed road", [nodes[n] for n in r["nodes"]]) for r in d["roads"]]
    lines += [(t["name"], t["pts"]) for t in d["trails"]]
    for name, pts in lines:
        for q in pts:
            dd = np.hypot(q[0] - x, q[1] - y)
            if dd < best[1]:
                best = (name, dd)
    return best


def main():
    argv = sys.argv[1:]
    out = "../docs/hill_country_design_map.png"
    if "--out" in argv:
        k = argv.index("--out")
        out = argv[k + 1]
        del argv[k:k + 2]
    d, h, origin, cell = load(argv[0] if argv else "data/country.json")
    ny, nx = h.shape
    base = Image.fromarray(relief(h, cell)).resize((nx * SCALE, ny * SCALE), Image.BILINEAR)
    img = base.convert("RGBA")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(over)
    f = ImageFont.truetype(FONT, 13)
    fs = ImageFont.truetype(FONT, 11)
    fb = ImageFont.truetype(FONT_B, 15)

    def px(p):
        return ((p[0] - origin[0]) / cell * SCALE, (p[1] - origin[1]) / cell * SCALE)

    m = BUFFER / cell * SCALE
    for kind, label, poly in ZONES:
        over = Image.new("RGBA", img.size, (0, 0, 0, 0))
        do = ImageDraw.Draw(over)
        pts = [px(p) for p in poly]
        c = ZONE_COL[kind]
        if kind == "busy":
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            do.rectangle([min(xs) - m, min(ys) - m, max(xs) + m, max(ys) + m],
                         outline=c + (200,), width=1)
        do.polygon(pts, fill=c + (55,), outline=c + (230,))
        img = Image.alpha_composite(img, over)
    dr = ImageDraw.Draw(img)

    hs = gaussian_filter(h, 3)
    for name, x, y in STREAMS:
        path = stream(hs, h, origin, cell, x, y)
        dr.line([px(p) for p in path], fill=WATER, width=3)
    for name, x, y, r in LAKES:
        p = px((x, y))
        rr = r / cell * SCALE
        dr.ellipse([p[0] - rr, p[1] - rr * 0.7, p[0] + rr, p[1] + rr * 0.7], fill=WATER,
                   outline=(20, 60, 140))
        dr.text((p[0] - rr, p[1] + rr * 0.7 + 2), name, fill=WATER, font=fs,
                stroke_width=2, stroke_fill=(0, 0, 0))

    nodes = d["nodes"]
    for r in d["roads"]:
        pts = [px(nodes[n]) for n in r["nodes"]]
        cls = r.get("cls", 3)
        dr.line(pts, fill=ROAD_COL.get(cls, (220, 220, 220)), width=4 if cls <= 2 else 2)
    for rl in d["rails"]:
        dr.line([px(p) for p in rl["pts"]], fill=(40, 40, 40), width=3)
    for t in d["trails"]:
        pts = [px(p) for p in t["pts"]]
        for a, b in zip(pts[::2], pts[1::2]):
            dr.line([a, b], fill=(255, 250, 230), width=1)

    for kind, label, poly in ZONES:
        xs = [px(p)[0] for p in poly]
        ys = [px(p)[1] for p in poly]
        dr.text((min(xs) + 6, min(ys) + 4), label, fill=ZONE_COL[kind] + (255,), font=fb,
                stroke_width=2, stroke_fill=(0, 0, 0))

    mt = d["mountain"]
    for name, (x, y, z) in mt["peaks"].items():
        p = px((x, y))
        dr.polygon([(p[0], p[1] - 7), (p[0] - 6, p[1] + 5), (p[0] + 6, p[1] + 5)],
                   fill=(255, 255, 255), outline=(0, 0, 0))
        dr.text((p[0] + 8, p[1] - 8), "%s %d m" % (name.replace("_", " ").title(), z),
                fill=(255, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
    for sid, s in mt["sites"].items():
        if sid.startswith("view_"):
            p = px((s["x"], s["y"]))
            dr.ellipse([p[0] - 4, p[1] + 6, p[0] + 4, p[1] + 14], outline=(80, 255, 255), width=2)

    print("%-40s %7s %6s  nearest road or trail" % ("place", "x,y", "h m"))
    for kind, label, x, y, *side in PLACES:
        p = px((x, y))
        c = PLACE_COL[kind]
        dr.rectangle([p[0] - 5, p[1] - 5, p[0] + 5, p[1] + 5], fill=c, outline=(0, 0, 0))
        tx = p[0] - 8 - dr.textlength(label, font=fs) if side else p[0] + 8
        dr.text((tx, p[1] + 2), label, fill=c, font=fs, stroke_width=2, stroke_fill=(0, 0, 0))
        name, dist = nearest(d, x, y)
        i, j = int((y - origin[1]) / cell), int((x - origin[0]) / cell)
        print("%-40s %4d,%-6d %4.0f  %s, %.0f m" % (label, x, y, h[i, j], name, dist))

    # Legend.
    lx, ly = 12, img.size[1] - 212
    dr.rectangle([lx - 6, ly - 6, lx + 560, img.size[1] - 8], fill=(0, 0, 0))
    rows = [("Hill country design map (2026-10-31)", (255, 255, 255)),
            ("Land as built: relief, roads, tracks (brown), trails (dotted), peaks, viewpoints (cyan ring)", (220, 220, 220)),
            ("PROPOSED, not built: zones, squares, streams and lakes (blue)", (255, 200, 120)),
            ("quiet: trails, springs, views, wildlife; no events, races or raves", ZONE_COL["quiet"]),
            ("busy: towns, truck stop, races, raves; thin ring = %d m buffer" % BUFFER, ZONE_COL["busy"]),
            ("closed: secret lab valley, one guarded road", ZONE_COL["closed"]),
            ("forest: the huge back-range forest, logging at its edge", ZONE_COL["forest"]),
            ("north is up; 1 px = 4 m; grid squares 500 m", (220, 220, 220))]
    for i, (text, c) in enumerate(rows):
        dr.text((lx, ly + i * 24), text, fill=c, font=fs if i else f)
    step = 500 / cell * SCALE
    gx0 = (np.ceil(origin[0] / 500) * 500 - origin[0]) / cell * SCALE
    gy0 = (np.ceil(origin[1] / 500) * 500 - origin[1]) / cell * SCALE
    for gx in np.arange(gx0, img.size[0], step):
        dr.line([(gx, 0), (gx, 6)], fill=(255, 255, 255))
    for gy in np.arange(gy0, img.size[1], step):
        dr.line([(0, gy), (6, gy)], fill=(255, 255, 255))
    img.convert("RGB").save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
