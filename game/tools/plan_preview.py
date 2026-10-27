#!/usr/bin/env python3
"""Draws a street plan dump (tests/plan_dump.gd) as a PNG for a quick look.

    python3 tools/plan_preview.py plan.json out.png [--scale 0.6]
"""
import json
import sys

from PIL import Image, ImageDraw

WIDTH = {"boulevard": 24, "bridge": 16, "avenue": 15, "river": 14, "street": 11, "quarter": 9, "lane": 7, "quay": 3}
ROAD = {"boulevard": (70, 70, 78), "bridge": (90, 80, 70), "avenue": (60, 60, 66), "river": (60, 60, 66),
        "street": (55, 55, 60), "quarter": (95, 70, 60), "lane": (190, 170, 140), "quay": (230, 230, 225)}


def main():
    src, out = sys.argv[1], sys.argv[2]
    scale = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 0.6
    d = json.load(open(src))
    x0, y0 = -110, -110
    w = int((d["window"][2] + 220) * scale)
    h = int((d["window"][3] + 220) * scale)
    img = Image.new("RGB", (w, h), (40, 92, 107))
    dr = ImageDraw.Draw(img)

    def p(pt):
        return ((pt[0] - x0) * scale, (pt[1] - y0) * scale)

    for f in d["faces"]:
        if len(f["poly"]) < 3:
            continue
        col = {"land": (52, 52, 58), "sliver": (52, 52, 58), "water": (40, 92, 107)}[f["kind"]]
        dr.polygon([p(q) for q in f["poly"]], fill=col)
    for f in d["faces"]:
        if len(f["inner"]) >= 3:
            dr.polygon([p(q) for q in f["inner"]], fill=(150, 146, 136))
        if len(f["lot"]) >= 3:
            small = min(f["rect"]) < 14
            dr.polygon([p(q) for q in f["lot"]], fill=(200, 120, 110) if small else (214, 200, 168))
    for a, b, cls, road in d["edges"]:
        if cls in ("lane", "quay"):
            dr.line([p(d["nodes"][a]), p(d["nodes"][b])], fill=ROAD[cls], width=max(1, int(2 * scale)))
    for a, b, cls, road in d["edges"]:
        if cls == "bridge":
            dr.line([p(d["nodes"][a]), p(d["nodes"][b])], fill=ROAD[cls], width=max(1, int(WIDTH[cls] * scale)))
    win = d["window"]
    dr.rectangle([p((0, 0)), p((win[2], win[3]))], outline=(255, 60, 60), width=2)
    for name, x, y, f in d["landmarks"]:
        dr.ellipse([p((x - 6, y - 6)), p((x + 6, y + 6))], fill=(255, 220, 40))
        dr.text(p((x + 8, y - 8)), name, fill=(255, 255, 255))
    img.save(out)


main()
