#!/usr/bin/env python3
"""Rough shaded-relief sketch of the whole state of Solvera (a planning picture, not game code).

Builds an invented height grid from game/data/world_map.json (region types, peaks, mesas,
lakes, rivers, the coast), hillshades it (light from the north-west) and draws water,
cities, towns, main roads, rail and labels on top. Deterministic (fixed seed).

Heights are made up for planning: listed peak elevations are scaled by PEAK_SCALE (0.2), so
Cinder Peak's 2,140 m becomes 428 m; region heights are guesses on the same scale.

Usage: python3 game/tools/state_relief.py <out.png> [--m-px N] [--cell M] [--grid] [--small PATH]
  --m-px  metres per output pixel (default 5: 2400 x 1800 map plus title and legend bands)
  --cell  height-grid cell in metres (default 10)
  --grid  also write the height grid (float32 metres, rows = y south) as <out>.npy
  --small also write a half-size copy to PATH
"""
import argparse
import json
from pathlib import Path

import numpy as np
import shapely
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union
from PIL import Image, ImageDraw, ImageFilter, ImageFont

DATA = Path(__file__).resolve().parent.parent / "data" / "world_map.json"
SEED = 1907
PEAK_SCALE = 0.2
# region type -> (base height m, noise amplitude m, ridged weight); None = land outside any region
TERRAIN = {"mountains": (170, 130, 1.0), "hills": (45, 30, 0.2), "desert": (70, 10, 0.0),
           "military": (60, 5, 0.0), "lakeside": (105, 35, 0.6), "forest": (75, 30, 0.3),
           "farmland": (14, 3, 0.0), "bayou": (2, 1, 0.0), "island": (3, 2, 0.0),
           "parkland": (30, 16, 0.1), "rustbelt": (22, 6, 0.0), None: (6, 2, 0.0)}
OVERRIDE = {"bellerive_hills": (10, 14, 1.0)}  # a low chaparral ridge: Calder Peak (114 m) x 0.2 = 23 m
# Palette copied from render_map.py REGION_FILL (plus "plain" for unzoned coastal land).
TINT = {"desert": "#e8d3a2", "military": "#b9b39a", "mountains": "#b7a99a", "forest": "#7fa66a",
        "lakeside": "#a9c98f", "hills": "#9cc488", "farmland": "#d9d79a", "bayou": "#7fa37a",
        "island": "#e9dca8", "rustbelt": "#b8b59a", "parkland": "#a6cf8f", None: "#d6d3b0"}
LAKE_LEVEL = {"lake_corran": 12, "miravel": 88, "bluegill_lake": 38}
# (centre x, y, radius m, level m): flat dry lake beds (Fort Granite range, the salt flats)
DRY_LAKES = [(650, 1000, 650, 55), (1600, 6250, 450, 42)]
ROUTE_STYLE = {  # type -> (colour, width px, casing colour or None, dash (on, off) or None)
    "highway": ("#fff4d6", 6, "#7a5a32", None), "road": ("#f7ecd2", 4, "#8a7a5a", None),
    "lane": ("#f3ead2", 2.5, None, None), "track": ("#7b4f26", 2, None, (9, 6)),
    "trail": ("#5a3418", 2, None, (3, 4)), "rail": ("#2b211d", 5, None, None),
    "ferry": ("#ffffff", 2, None, (10, 8)), "airship": ("#2e86c1", 2, None, (6, 6))}
FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")


def font(size, bold=False, serif=False):
    name = ("DejaVuSerif" if serif else "DejaVuSans") + ("-Bold" if bold else "") + ".ttf"
    try:
        return ImageFont.truetype(str(FONT_DIR / name), size)
    except OSError:
        return ImageFont.load_default()


def rgb(hexcol):
    return np.array([int(hexcol[i:i + 2], 16) for i in (1, 3, 5)], np.float32)


def smoothstep(x):
    t = np.clip(x, 0.0, 1.0)
    return t * t * (3 - 2 * t)


def box_blur(a, r):
    """Three box passes per axis, close to a gaussian of sigma ~ r cells."""
    for _ in range(3 if r >= 1 else 0):
        for ax in (0, 1):
            pad = [(0, 0), (0, 0)]
            pad[ax] = (r + 1, r)
            c = np.cumsum(np.pad(a, pad, mode="edge"), axis=ax, dtype=np.float64)
            n = a.shape[ax]
            a = ((np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax)
                  - np.take(c, np.arange(n), axis=ax)) / (2 * r + 1)).astype(np.float32)
    return a


def fbm(shape, cell, rng, ridged):
    ny, nx = shape
    out = np.zeros(shape, np.float32)
    amp = 1.0
    for wl in (1600, 800, 400, 200, 100):
        g = rng.random((int(ny * cell / wl) + 3, int(nx * cell / wl) + 3)).astype(np.float32)
        n = np.asarray(Image.fromarray(g, "F").resize((nx, ny), Image.BICUBIC))
        if ridged:
            n = (1 - np.abs(2 * n - 1)) ** 2
        out += amp * n
        amp *= 0.6
    return np.clip((out - out.mean()) / out.std(), -2.5, 2.5)


class Grid:
    def __init__(self, w, h, cell):
        self.cell, self.nx, self.ny = cell, int(w / cell), int(h / cell)
        self.X, self.Y = np.meshgrid((np.arange(self.nx) + 0.5) * cell, (np.arange(self.ny) + 0.5) * cell)
        cc = 40.0  # coarse grid for distance fields, upsampled
        self.cnx, self.cny = int(w / cc), int(h / cc)
        cx, cy = np.meshgrid((np.arange(self.cnx) + 0.5) * cc, (np.arange(self.cny) + 0.5) * cc)
        self.cpts = shapely.points(cx.ravel(), cy.ravel())

    def inside(self, geom):
        return shapely.contains_xy(geom, self.X, self.Y)

    def up(self, coarse):
        img = Image.fromarray(coarse.reshape(self.cny, self.cnx).astype(np.float32), "F")
        return np.asarray(img.resize((self.nx, self.ny), Image.BILINEAR))

    def dist(self, geom):
        return self.up(shapely.distance(geom, self.cpts))

    def sample(self, a, x, y):
        i = min(self.ny - 1, max(0, int(y / self.cell)))
        return float(a[i, min(self.nx - 1, max(0, int(x / self.cell)))])


def build_heights(world, g):
    rng = np.random.default_rng(SEED)
    regions = world["regions"]
    idx = np.full((g.ny, g.nx), -1, np.int32)
    for k, r in enumerate(regions):
        idx[g.inside(Polygon(r["polygon"]))] = k
    terr = [OVERRIDE.get(r["id"], TERRAIN.get(r["type"], TERRAIN[None])) for r in regions] + [TERRAIN[None]]
    lut = np.array(terr, np.float32)  # index -1 picks the last row (no region)
    base, amp, ridge = (box_blur(lut[idx, j], int(300 / g.cell)) for j in range(3))
    n_plain, n_ridge = fbm(idx.shape, g.cell, rng, False), fbm(idx.shape, g.cell, rng, True)
    noise = (1 - ridge) * n_plain + ridge * n_ridge
    h = base + 0.45 * amp * noise
    # peaks: smooth massifs at their scaled heights, roughened away from the summit
    for lm in (lm for lm in world["landmarks"] if lm["type"] == "peak"):
        H = float(lm["elev"]) * PEAK_SCALE
        rad = 250 + 1.6 * H
        d2 = ((g.X - lm["pos"][0]) ** 2 + (g.Y - lm["pos"][1]) ** 2) / rad ** 2
        prof = H * np.exp(-d2) if lm["id"] != "sable_butte" else H * smoothstep((1.6 - np.sqrt(d2) * 2.2) / 0.5)
        h = np.maximum(h, prof + (0.06 * prof + 0.3 * amp) * noise * (1 - prof / H))
    # mesas: flat-topped tables scattered through the desert, plus one at Mesa Arch
    desert = unary_union([Polygon(r["polygon"]) for r in regions if r["type"] == "desert"])
    avoid = unary_union([shapely.box(c["rect"][0] - 300, c["rect"][1] - 300, c["rect"][0] + c["rect"][2] + 300,
                                     c["rect"][1] + c["rect"][3] + 300) for c in world["cities"]]
                        + [Polygon(r["polygon"]).buffer(200) for r in regions if r["type"] == "military"])
    mesas, mesa = [(1150, 4650, 240, 55, 0.4)], np.zeros(h.shape, np.float32)
    while len(mesas) < 18:
        x, y = rng.uniform(200, 3800), rng.uniform(300, 7000)
        if desert.buffer(-350).contains(shapely.Point(x, y)) and not avoid.contains(shapely.Point(x, y)) \
                and all((x - m[0]) ** 2 + (y - m[1]) ** 2 > 700 ** 2 for m in mesas):
            mesas.append((x, y, rng.uniform(110, 260), rng.uniform(30, 70), rng.uniform(0, np.pi)))
    for x, y, R, top, ang in mesas:
        dx, dy = g.X - x, g.Y - y
        u, v = dx * np.cos(ang) + dy * np.sin(ang), (-dx * np.sin(ang) + dy * np.cos(ang)) * 1.6
        s = smoothstep((1.35 * R - np.hypot(u, v)) / (0.35 * R))
        h = np.where(s > 0, np.maximum(h, 70 + top * s), h)
        mesa = np.maximum(mesa, s)
    for x, y, R, lvl in DRY_LAKES:
        w = smoothstep((R - np.hypot(g.X - x, g.Y - y)) / (0.4 * R))
        h = h * (1 - w) + lvl * w
    # water: land eases down to each water level; water gets a shallow bed
    islands = unary_union([Polygon(r["polygon"]) for r in regions if r["type"] == "island"])
    sea = unary_union([Polygon(w["polygon"]) for w in world["water"] if w["type"] in ("ocean", "bay")]).difference(islands)
    bodies = [("sea", sea, 0.0, 900.0)] + [(w["id"], Polygon(w["polygon"]), LAKE_LEVEL.get(w["id"], 30), 450.0)
                                          for w in world["water"] if w["type"] == "lake"]
    wet = np.zeros(h.shape, bool)
    for wid, geom, lvl, fall in bodies:
        d = g.dist(geom.boundary)
        ins = g.inside(geom)
        if wid == "bluegill_lake":
            lvl = g.sample(h, *geom.centroid.coords[0]) - 4
        h = np.where(ins, lvl - np.minimum(40, d * 0.03), lvl + (h - lvl) * smoothstep(d / fall))
        wet |= ins
    # rivers: carve a valley whose bed falls steadily from source to mouth
    rivers = [w for w in world["water"] if w["type"] in ("river", "creek")]
    rivers.sort(key=lambda w: -float(w["width"]))
    for w in rivers:
        line = LineString(w["line"])
        start = 12.0 if w["id"] == "morrow" else g.sample(h, *w["line"][0]) - 8
        end = min(start, g.sample(h, *w["line"][-1]) - 2)
        t = g.up(shapely.line_locate_point(line, g.cpts, normalized=True))
        bed = start + (end - start) * t
        k, half = (0.04, 250.0) if w["type"] == "river" else (0.08, 150.0)
        dd = np.maximum(0, g.dist(line) - float(w["width"]) / 2)
        cut = np.maximum(0, h - bed - k * dd - 60 * (dd / half) ** 2) * (1 - smoothstep(dd / half - 1))
        h = np.where(wet, h, h - cut)
    h = np.where(wet, h, np.maximum(h, 0.3))
    return h.astype(np.float32), idx, wet, sea, mesa


def render(world, h, idx, wet, sea, mesa, g, m_px):
    regions = world["regions"]
    W, H = int(world["size"][0] / m_px), int(world["size"][1] / m_px)
    tints = np.stack([rgb(TINT.get(r["type"], TINT[None])) for r in regions] + [rgb(TINT[None])])
    col = np.stack([box_blur(tints[idx, c], int(60 / g.cell)) for c in range(3)], -1)
    for x, y, R, _ in DRY_LAKES:
        w = smoothstep((R - np.hypot(g.X - x, g.Y - y)) / (0.4 * R))[..., None]
        col = col * (1 - w) + rgb("#f2ead6") * w
    col = col + (rgb("#c4895c") - col) * mesa[..., None]
    col = col + (rgb("#c9beb0") - col) * smoothstep((h - 210) / 160)[..., None]
    col = col + (rgb("#f6f4f0") - col) * smoothstep((h - 385) / 40)[..., None]
    gy, gx = np.gradient(h * 3.0, g.cell)  # 3x vertical exaggeration for the shading only
    L = np.array([-np.cos(np.radians(45)) / np.sqrt(2), -np.cos(np.radians(45)) / np.sqrt(2), np.sin(np.radians(45))])
    shade = (-gx * L[0] - gy * L[1] + L[2]) / np.sqrt(gx ** 2 + gy ** 2 + 1)
    land = np.clip(col * (0.45 + 0.78 * np.clip(shade, 0, 1))[..., None], 0, 255)
    depth = smoothstep(g.dist(sea.boundary) / 1800)[..., None]
    water = rgb("#a9d1ec") * (1 - depth) + rgb("#4a80b4") * depth
    lake = (rgb("#7db4dd") * (0.9 + 0.1 * np.clip(shade, 0, 1)[..., None]))
    in_sea = g.inside(sea)[..., None]
    water = np.where(in_sea, water, lake)
    big = lambda a: Image.fromarray(a.astype(np.uint8), "RGB").resize((W, H), Image.BICUBIC)
    img_land, img_water = big(land), big(water)
    hz = np.asarray(Image.fromarray(h, "F").resize((W, H), Image.BILINEAR))
    band = np.floor(hz / 50)
    edge = (band != np.roll(band, 1, 0)) | (band != np.roll(band, 1, 1))
    arr = np.asarray(img_land).astype(np.float32)
    arr[edge & (hz > 20)] *= 0.86
    img_land = Image.fromarray(arr.astype(np.uint8))
    P = lambda pts: [(x / m_px, y / m_px) for x, y in pts]
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for wtr in world["water"]:
        if "polygon" in wtr:
            md.polygon(P(wtr["polygon"]), fill=255)
    for r in regions:
        if r["type"] == "island":
            md.polygon(P(r["polygon"]), fill=0)
    img = Image.composite(img_water, img_land, mask)
    img.paste((52, 98, 140), mask=mask.filter(ImageFilter.FIND_EDGES).point(lambda v: 255 if v > 60 else 0))
    d = ImageDraw.Draw(img, "RGBA")
    for r in regions:
        if r["type"] != "island":
            dashed(d, P(r["polygon"] + r["polygon"][:1]), (90, 80, 70, 110), 2, (4, 7))
    for wtr in world["water"]:
        if "line" in wtr:
            d.line(P(wtr["line"]), fill=(70, 130, 190, 255), width=max(3, int(float(wtr["width"]) / m_px * 0.5)), joint="curve")
    order = ["trail", "track", "lane", "ferry", "airship", "road", "rail", "highway"]
    for kind in order:
        colour, width, casing, dash = ROUTE_STYLE[kind]
        for r in world["routes"]:
            if r["type"] != kind:
                continue
            pts = P(r["line"])
            if casing:
                d.line(pts, fill=casing, width=int(width + 3), joint="curve")
            if dash:
                dashed(d, pts, colour, int(width), dash)
            else:
                d.line(pts, fill=colour, width=int(width), joint="curve")
            if kind == "rail":
                dashed(d, pts, "#f5f0e6", 2, (7, 7))
    for c in world["cities"]:
        x, y, cw, ch = (v / m_px for v in c["rect"])
        d.rectangle([x, y, x + cw, y + ch], fill=(255, 255, 255, 55), outline=(40, 30, 30, 255), width=4)
    return img, P


def dashed(d, pts, fill, width, dash):
    on, off = dash
    phase, drawing = 0.0, True
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = float(np.hypot(x1 - x0, y1 - y0))
        pos = 0.0
        while pos < seg:
            run = min((on if drawing else off) - phase, seg - pos)
            if drawing:
                a, b = pos / seg, (pos + run) / seg
                d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)], fill=fill, width=width)
            pos += run
            phase += run
            if phase >= (on if drawing else off) - 1e-6:
                phase, drawing = 0.0, not drawing


class Labels:
    def __init__(self, draw, W, H):
        self.d, self.W, self.H, self.boxes = draw, W, H, []

    def block(self, x, y, r):
        self.boxes.append((x - r, y - r, x + r, y + r))

    def put(self, text, x, y, fnt, fill, anchor="mm", tries=((0, 0),), force=False):
        for k, (dx, dy) in enumerate(tries):
            box = self.d.textbbox((x + dx, y + dy), text, font=fnt, anchor=anchor, stroke_width=3)
            shift = max(0, -box[0] + 4) - max(0, box[2] - self.W + 4)
            inside = shift == 0 and box[1] >= 0 and box[3] <= self.H
            free = not any(box[0] < b[2] and box[2] > b[0] and box[1] < b[3] and box[3] > b[1] for b in self.boxes)
            last = force and k == len(tries) - 1
            if (inside and free) or last:
                self.d.text((x + dx + shift, y + dy), text, font=fnt, fill=fill, anchor=anchor, stroke_width=3, stroke_fill="white")
                self.boxes.append((box[0] + shift, box[1], box[2] + shift, box[3]))
                return True
        return False


def annotate(img, world, P, m_px):
    W, H = img.size
    d = ImageDraw.Draw(img, "RGBA")
    lab = Labels(d, W, H)
    for c in world["cities"]:
        x, y, cw, ch = c["rect"]
        lab.put(f'{c["name"].upper()}  (phase {c["phase"]})', (x + cw / 2) / m_px, y / m_px + 22, font(30, True), "#1d1414", force=True)
    peaks = [lm for lm in world["landmarks"] if lm["type"] == "peak"]
    for lm in peaks:  # symbols first, so labels avoid them
        x, y = P([lm["pos"]])[0]
        d.polygon([(x - 9, y + 7), (x, y - 9), (x + 9, y + 7)], fill="#4a3426", outline="white")
        lab.block(x, y, 10)
    for t in world["towns"]:
        x, y = P([t["pos"]])[0]
        if t["kind"] == "ghost":
            d.ellipse([x - 7, y - 7, x + 7, y + 7], fill="#efe9df", outline="#5a5048", width=3)
        elif t["kind"] == "truck_stop":
            d.rectangle([x - 7, y - 7, x + 7, y + 7], fill="#c27c0e", outline="white", width=2)
        else:
            rr = 8 if t["kind"] == "town" else 6
            d.ellipse([x - rr, y - rr, x + rr, y + rr], fill="#222", outline="white", width=2)
        lab.block(x, y, 9)
    for lm in world["landmarks"]:
        x, y = P([lm["pos"]])[0]
        if lm["type"] == "military":
            d.rectangle([x - 7, y - 7, x + 7, y + 7], fill="#b03a2e", outline="white", width=2)
        elif lm["type"] == "airport":
            d.text((x, y), "\u2708", font=font(24, True), fill="#1b2631", anchor="mm", stroke_width=2, stroke_fill="white")
        elif lm["type"] == "dam":
            d.line([(x - 12, y - 4), (x + 12, y + 4)], fill="#1b4f72", width=6)
        if lm["type"] in ("military", "airport", "dam"):
            lab.block(x, y, 9)
    vert = tuple((0, k * s) for k in (0, 1, 2, 3) for s in (1, -1))[1:]
    for r in world["regions"]:
        if r.get("label_pos"):
            x, y = P([r["label_pos"]])[0]
            for dx, dy in vert:
                if lab.put(r["name"].upper(), x + dx, y + dy * 22, font(24, True), "#3f3527", "mm", ((0, 0),), force=(dy == -3)):
                    lab.put(f'phase {r["phase"]}', x + dx, y + dy * 22 + 23, font(16), "#3f3527", force=True)
                    break
    water_names = {"lake_corran": (9000, 350), "miravel": (4500, 2650), "sovereign_bay": (10500, 2780),
                   "bluegill_lake": (8650, 4650), "gulf": (3000, 8780)}
    for wtr in world["water"]:
        if wtr["id"] in water_names:
            x, y = P([water_names[wtr["id"]]])[0]
            sz = 30 if wtr["id"] in ("gulf", "lake_corran") else 18
            lab.put(wtr["name"], x, y, font(sz, True, serif=True), "#1f4e79", force=True)
    for name, pos in (("Morrow River", (6750, 3050)), ("Cinder River", (3550, 5550))):
        x, y = P([pos])[0]
        lab.put(name, x, y, font(17, True, serif=True), "#1f4e79", "mm", ((0, 0), (0, 20), (0, -20)))
    side = ((13, 0, "lm"), (-13, 0, "rm"), (0, -18, "mm"), (0, 18, "mm"), (13, -16, "lm"), (13, 16, "lm"), (-13, 16, "rm"), (-13, -16, "rm"))
    items = [(f'{lm["name"]} {round(float(lm["elev"]) * PEAK_SCALE)} m', lm["pos"], 17, "#4a3426") for lm in peaks]
    items += [(t["name"] + (" (ghost)" if t["kind"] == "ghost" else ""), t["pos"], 19, "#1f1f1f") for t in world["towns"]]
    items += [(lm["name"], lm["pos"], 15, "#7b241c" if lm["type"] == "military" else "#1b4f72")
              for lm in world["landmarks"] if lm["type"] in ("military", "dam")]
    for text, pos, size, colour in items:
        x, y = P([pos])[0]
        for dx, dy, anc in side:
            if lab.put(text, x + dx, y + dy, font(size, True), colour, anc):
                break
    for r in world["regions"]:
        if r["type"] == "island":
            cx, cy = Polygon(r["polygon"]).centroid.coords[0]
            x, y = P([(cx, cy)])[0]
            lab.put(r["name"], x, y, font(16, True), "#3f3527", "mm", ((0, 28), (0, -28), (0, 48), (0, -48)))
    nx, ny = 11000 / m_px, 280 / m_px  # north arrow on Lake Corran
    d.polygon([(nx, ny - 34), (nx - 13, ny + 12), (nx, ny + 2), (nx + 13, ny + 12)], fill="#1d1d1d", outline="white")
    d.text((nx, ny + 28), "N", font=font(22, True), fill="#1d1d1d", anchor="mm", stroke_width=3, stroke_fill="white")


def frame(map_img, world, m_px):
    W, H = map_img.size
    top, bottom = 64, 150
    out = Image.new("RGB", (W, H + top + bottom), "#f4f1ea")
    out.paste(map_img, (0, top))
    d = ImageDraw.Draw(out)
    d.text((18, top / 2), "Solvera — rough sketch (not to scale vertically; planning only)", font=font(34, True), fill="#1d1d1d", anchor="lm")
    d.text((W - 18, top / 2), f"12 x 9 km · 1 px = {m_px:g} m · generated from game/data/world_map.json by game/tools/state_relief.py",
           font=font(16), fill="#444", anchor="rm")
    y0, x = top + H + 14, 18
    for name, key in (("mountains", "mountains"), ("hills", "hills"), ("forest", "forest"), ("lakeside", "lakeside"),
                      ("desert", "desert"), ("military", "military"), ("farmland", "farmland"), ("swamp", "bayou"),
                      ("parkland", "parkland"), ("rust belt", "rustbelt"), ("island", "island"), ("coastal plain", None)):
        d.rectangle([x, y0, x + 26, y0 + 18], fill=TINT[key], outline="#555")
        d.text((x + 32, y0 + 9), name, font=font(15), fill="#222", anchor="lm")
        x += 40 + int(d.textlength(name, font=font(15)))
    y1, x = y0 + 36, 18
    for name, kind in (("highway", "highway"), ("road", "road"), ("lane", "lane"), ("rail", "rail"), ("dirt track", "track"),
                       ("trail / 4x4", "trail"), ("ferry", "ferry"), ("airship tour", "airship")):
        colour, width, casing, dash = ROUTE_STYLE[kind]
        if kind == "ferry":
            d.rectangle([x - 2, y1 + 1, x + 52, y1 + 17], fill="#7db4dd")
        if casing:
            d.line([(x, y1 + 9), (x + 50, y1 + 9)], fill=casing, width=int(width + 3))
        (dashed(d, [(x, y1 + 9), (x + 50, y1 + 9)], colour, int(width), dash) if dash
         else d.line([(x, y1 + 9), (x + 50, y1 + 9)], fill=colour, width=int(width)))
        d.text((x + 58, y1 + 9), name, font=font(15), fill="#222", anchor="lm")
        x += 70 + int(d.textlength(name, font=font(15)))
    d.line([(x, y1 + 9), (x + 50, y1 + 9)], fill=(70, 130, 190), width=6)
    d.text((x + 58, y1 + 9), "river (half width)", font=font(15), fill="#222", anchor="lm")
    y2, x = y1 + 36, 18
    syms = (("▲ peak (scaled height)", "#4a3426"), ("● town / village", "#222"), ("○ ghost town", "#5a5048"),
            ("■ truck stop", "#c27c0e"), ("■ military site", "#b03a2e"), ("✈ airport / airstrip", "#1b2631"),
            ("□ city (outlined)", "#1d1414"), ("- - county line", "#5a5046"), ("contours every 50 m", "#5a5046"))
    for text, colour in syms:
        d.text((x, y2 + 9), text, font=font(15, True), fill=colour, anchor="lm")
        x += 26 + int(d.textlength(text, font=font(15, True)))
    y3 = y2 + 34
    d.text((18, y3 + 9), f"Heights are invented: listed peak elevations x {PEAK_SCALE:g} (Cinder Peak 2,140 m -> 428 m); "
                         "relief shading uses 3x vertical exaggeration. Mesas and dry lakes are placed for the sketch only.",
           font=font(15), fill="#333", anchor="lm")
    sx = W - 18 - 3000 / m_px
    for k in range(3):
        d.rectangle([sx + k * 1000 / m_px, y2 + 4, sx + (k + 1) * 1000 / m_px, y2 + 14], fill="#222" if k % 2 == 0 else "white", outline="#222")
    for k in range(4):
        d.text((sx + k * 1000 / m_px, y2 + 28), f"{k} km", font=font(15, True), fill="#222", anchor="mm")
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("out")
    ap.add_argument("--m-px", type=float, default=5.0)
    ap.add_argument("--cell", type=float, default=10.0)
    ap.add_argument("--grid", action="store_true")
    ap.add_argument("--small")
    a = ap.parse_args()
    world = json.loads(DATA.read_text())
    g = Grid(world["size"][0], world["size"][1], a.cell)
    h, idx, wet, sea, mesa = build_heights(world, g)
    img, P = render(world, h, idx, wet, sea, mesa, g, a.m_px)
    annotate(img, world, P, a.m_px)
    out = frame(img, world, a.m_px)
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(a.out, optimize=True)
    print(f"saved {a.out} {out.size[0]}x{out.size[1]}; land height {h[~wet].min():.0f}..{h[~wet].max():.0f} m")
    if a.small:
        out.resize((out.size[0] // 2, out.size[1] // 2), Image.LANCZOS).save(a.small, optimize=True)
        print(f"saved {a.small}")
    if a.grid:
        np.save(Path(a.out).with_suffix(".npy"), h)
        print(f"saved {Path(a.out).with_suffix('.npy')} ({g.ny}x{g.nx}, {a.cell:g} m cells)")


if __name__ == "__main__":
    main()
