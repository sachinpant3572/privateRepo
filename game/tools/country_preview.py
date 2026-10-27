#!/usr/bin/env python3
"""Draws data/country.json (and a plan dump, if given) to a PNG for a quick
look at the generated country:

    python3 tools/country_preview.py out.png [plan.json] [--m-px 4] [--crop x0 y0 x1 y1]

Coordinates are local metres (see build_country.py). Ground by zone, roads
by class (bridges blue), lots by kind, walls red, barricades orange, links
to the plan magenta.
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ZONE_COLORS = {
    "land": (185, 195, 150), "farmland": (214, 200, 120), "bayou": (98, 128, 90), "hills": (140, 180, 110),
    "heights": (170, 200, 150), "bayou_town": (120, 150, 110), "fringe": (175, 170, 160), "eastside": (190, 190, 175),
    "beach_town": (235, 215, 190), "shore": (210, 205, 185), "town": (200, 190, 170), "sand": (240, 225, 170),
    "far_desert": (200, 180, 140), "far_mountains": (150, 140, 130), "far_forest": (90, 120, 80),
    "far_lakeside": (140, 170, 120), "far_parkland": (140, 175, 125), "far_military": (150, 150, 135),
    "far_land": (165, 170, 140),
}
ROAD_COLORS = {"highway": (250, 240, 200), "avenue": (240, 240, 240), "road": (235, 225, 200), "street": (225, 225, 225),
               "lane": (215, 205, 180), "track": (150, 110, 70), "trail": (120, 80, 50)}


def main() -> None:
    args = sys.argv[1:]
    out = args.pop(0)
    m_px = 4.0
    crop = None
    plan = None
    while args:
        a = args.pop(0)
        if a == "--m-px":
            m_px = float(args.pop(0))
        elif a == "--crop":
            crop = [float(args.pop(0)) for _ in range(4)]
        else:
            plan = json.loads(Path(a).read_text())
    c = json.loads((ROOT / "data" / "country.json").read_text())
    if crop is None:
        xs = [p[0] for ring in c["area"] for p in ring]
        ys = [p[1] for ring in c["area"] for p in ring]
        crop = [min(xs) - 500, min(ys) - 500, max(xs) + 500, max(ys) + 500]
    x0, y0, x1, y1 = crop
    img = Image.new("RGB", (int((x1 - x0) / m_px), int((y1 - y0) / m_px)), (60, 110, 140))
    d = ImageDraw.Draw(img)

    def P(p):
        return ((p[0] - x0) / m_px, (p[1] - y0) / m_px)

    zones = c["zones"]
    tile = c["tile"]
    for t in c["tiles"]:
        gx, gy = t["k"]
        if (gx + 1) * tile < x0 or gx * tile > x1 or (gy + 1) * tile < y0 or gy * tile > y1:
            continue
        for zi, flat in t["g"]:
            col = ZONE_COLORS.get(zones[zi], (255, 0, 255))
            for k in range(0, len(flat), 6):
                d.polygon([P(flat[k:k + 2]), P(flat[k + 2:k + 4]), P(flat[k + 4:k + 6])], fill=col)
    if plan:
        for a, b, cls, road in plan["edges"]:
            d.line([P(plan["nodes"][a]), P(plan["nodes"][b])], fill=(90, 90, 90), width=max(1, int(8 / m_px)))
    for f in c["far_roads"]:
        d.line([P(p) for p in f["pts"]], fill=(160, 150, 130), width=max(1, int(8 / m_px)))
    for t in c["trails"]:
        d.line([P(p) for p in t["pts"]], fill=ROAD_COLORS["trail"], width=max(1, int(3 / m_px)))
    for r in c["rails"]:
        d.line([P(p) for p in r["pts"]], fill=(80, 60, 50), width=max(1, int(4 / m_px)))
    classes = [k["id"] for k in c["classes"]]
    for e in c["edges"]:
        a, b, cls, road, bridge = e
        w = c["classes"][cls]["w"]
        col = (60, 120, 230) if bridge else ROAD_COLORS[classes[cls]]
        d.line([P(c["nodes"][a]), P(c["nodes"][b])], fill=col, width=max(1, int(w / m_px)))
    import math
    for lot in c["lots"]:
        x, y, yaw, w, dd, kind, ident, zone = lot
        cs, sn = math.cos(yaw), math.sin(yaw)
        pts = []
        for lx, lz in ((-w / 2, -dd / 2), (w / 2, -dd / 2), (w / 2, dd / 2), (-w / 2, dd / 2)):
            pts.append(P((x + lx * cs + lz * sn, y - lx * sn + lz * cs)))
        d.polygon(pts, fill=(200, 60, 60) if ident else (120, 100, 90), outline=(40, 30, 30))
        # Front edge (towards the street).
        d.line([pts[0], pts[1]], fill=(255, 255, 0), width=1)
    for w in c["walls"]:
        d.line([P(w[:2]), P(w[2:])], fill=(230, 30, 30), width=max(1, int(2 / m_px)))
    for b in c["barricades"]:
        p = P(b)
        d.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=(255, 140, 0))
    for n, pn in c["links"]:
        p = P(c["nodes"][n])
        d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=(255, 0, 255))
    img.save(out)
    print(out, img.size)


if __name__ == "__main__":
    main()
