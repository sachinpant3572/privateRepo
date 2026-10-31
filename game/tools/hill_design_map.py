#!/usr/bin/env python3
"""Draws the hill-country design map: the land as built (relief, the Morrow,
roads, tracks, trails, rails, peaks and viewpoints) with the content Sachin
asked for placed on it as PROPOSALS (nothing in ZONES, PLACES, LINES, RAIL,
STREAMS or LAKES is built).

  python3 tools/hill_design_map.py [data/country.json] [--out ../docs/hill_country_design_map.png]

Coordinates are game metres (x east, y south; the hills lie at negative y).
The lists below are the design: change them here, rerun, commit the PNG.
main() prints each place's height, slope and nearest way, the length of each
line, and where the proposed rail would need tunnels and bridges, so the notes
stay true when the land changes.

LINES are proposed ways that are not roads yet (the lab road, the timber haul,
the sky bridge). RAIL is a proposed branch from the Morrow Freight Line at the
north foot east to the Corran Commuter; building it needs #110 (tunnels and
bridges) and #111 (trains).
"""
import base64
import json
import sys
import textwrap

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.ndimage import gaussian_filter, maximum_filter

SCALE = 2                     # pixels per terrain cell (8 m), so 4 m a pixel
PANEL = 430                   # key panel width on the right, pixels
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Zones: (kind, label, polygon in game metres). Quiet zones keep events,
# races and raves out; busy zones hold them; the ring BUFFER m round each
# busy zone holds neither. Forest and closed zones are drawn first.
BUFFER = 250.0
ZONES = [
    ("forest", "Great back-range forest and hunting ground",
     [(-550, -4950), (1250, -4950), (1250, -4600), (1150, -4150), (850, -3500), (-550, -3500)]),
    ("closed", "Lab valley (closed)", [(360, -4250), (740, -4250), (740, -3860), (360, -3860)]),
    ("quiet", "Fernmoor quiet country", [(1730, -4950), (2350, -4950), (2400, -4380), (1730, -4300)]),
    ("quiet", "Whistler-Tallow quiet ridge", [(2350, -4200), (2850, -4200), (2850, -3500), (2350, -3500)]),
    ("quiet", "High range", [(150, -3400), (1880, -3400), (1880, -2500), (150, -2500)]),
    ("busy", "Hollin Crossing", [(1300, -4560), (1470, -4560), (1470, -4300), (1300, -4300)]),
    ("busy", "East Hills Road strip", [(2150, -2500), (3000, -2500), (3000, -2050), (2150, -2050)]),
    ("busy", "Copperback race country", [(2350, -3250), (2950, -3250), (2950, -2650), (2350, -2650)]),
]

# Places: (kind, label, x, y), numbered on the map in this order.
PLACES = [
    ("town", "Brackett village: diner, store, petrol pump", 2412, -2116),
    ("town", "Hollin Crossing: sawmill, fuel, cafe, hunting store, fairground", 1448, -4408),
    ("truck", "East Hills truck stop", 2790, -2310),
    ("shady", "Roadside motel (shady)", 2944, -2448),
    ("trailer", "Copperback trailer town", 2720, -2900),
    ("race", "Hill race start (loop in orange)", 2780, -2520),
    ("jump", "Stunt jump on Copperback Cut", 2610, -3050),
    ("rave", "Rave clearing", 2664, -3104),
    ("rave", "Rave clearing", 2704, -2920),
    ("cult", "Cult compound (fictional faith)", 2316, -4024),
    ("lab", "Secret research lab (hidden hollow)", 528, -4048),
    ("gate", "Lab gate on Route 9", 472, -4288),
    ("hot", "Raven hot spring", 256, -3256),
    ("cold", "Whistler cold spring", 2620, -3800),
    ("hot", "Fernmoor hot spring", 2050, -4600),
    ("cold", "Tallow cold spring", 2440, -4040),
    ("logging", "Illegal logging camp (north bank)", -332, -4300),
    ("ranger", "Ranger post", 584, -4200),
    ("hotel", "5-star hotel by the summit restaurant", 905, -2800),
    ("hotel", "Whistler lodge hotel", 2472, -3538),
    ("creepy", "Abandoned mine (creepy)", 1573, -2917),
    ("mystery", "Stone ring (mystery)", 1936, -4520),
    ("sport", "Bungee platform (129 m drop)", 732, -2723),
    ("sport", "Parachute jumps from the summit helipad", 1035, -2740),
    ("sport", "Downhill bike route: Calder Trail", 990, -1502),
]

# Proposed ways that are not roads yet: (kind, label, points).
LINES = [
    ("guarded", "Lab road (guarded, one way in, switchbacks)",
     [(472, -4288), (520, -4240), (552, -4192), (568, -4096), (528, -4048)]),
    ("haul", "Timber haul (hidden log bridge over the Morrow, then Route 9 to the sawmill)",
     [(-332, -4300), (-230, -4200), (-127, -4103)]),
    ("bridge", "Sky bridge North Knob-Raven Peak (800 m, 170 m deep gap)",
     [(1090, -3580), (400, -3180)]),
]

# The hill race runs on these existing ways, only south of RACE_NORTH so it
# stays out of the Whistler-Tallow quiet ridge.
RACE_ROADS = ["East Hills Road", "Whistler Track", "Copperback Cut", "Copperback Track"]
RACE_NORTH = -3340

# Proposed rail: from the Morrow Freight Line east past Tallow Lake to the
# Corran Commuter. The rail level is the smoothed ground held to RAIL_GRADE;
# deeper than RAIL_CUT under the ground is a tunnel, higher than RAIL_FILL
# over it is a bridge.
RAIL = [(1420, -4880), (1720, -4640), (2000, -4330), (2248, -4290), (2600, -4100),
        (2850, -4100), (3056, -4025)]
RAIL_GRADE = 0.02
RAIL_CUT = 15.0
RAIL_FILL = 10.0

# Streams run downhill from these sources on the smoothed ground until the
# plain or a basin; a basin becomes a lake (radius in m).
STREAMS = [("Raven Creek", 560, -3330), ("Hollin creek", 1180, -3720),
           ("Copperback brook", 2250, -3400), ("Whistler brook", 2620, -3800)]
LAKES = [("Tallow Lake", 2248, -4144, 110), ("Fernmoor Pond", 1752, -4512, 60)]

ROAD_COL = {0: (250, 220, 90), 1: (250, 200, 80), 2: (240, 240, 240), 3: (230, 230, 230),
            4: (220, 220, 220), 5: (210, 210, 210), 6: (196, 150, 96)}
ZONE_COL = {"quiet": (80, 170, 240), "busy": (240, 120, 60), "closed": (220, 40, 40),
            "forest": (40, 120, 50)}
PLACE_COL = {"town": (255, 255, 255), "truck": (255, 210, 60), "trailer": (230, 180, 120),
             "shady": (200, 160, 255), "cult": (190, 80, 220), "lab": (230, 30, 30),
             "gate": (230, 30, 30), "hot": (255, 120, 80), "cold": (120, 200, 255),
             "rave": (255, 60, 200), "logging": (170, 120, 60), "ranger": (120, 220, 120),
             "hotel": (255, 230, 120), "race": (255, 140, 0), "jump": (255, 140, 0),
             "creepy": (160, 160, 160), "mystery": (180, 255, 200), "sport": (90, 255, 230)}
LINE_COL = {"guarded": (230, 30, 30), "haul": (170, 120, 60), "bridge": (90, 255, 230)}
WATER = (70, 150, 240)
# Label nudges in pixels for crowded spots: peaks by id, zones by label.
PEAK_NUDGE = {"mount_calder": (-60, -30)}
ZONE_BELOW = {"Lab valley (closed)", "Hollin Crossing"}
LAKE_BELOW = {"Fernmoor Pond"}
RAIL_COL = (255, 255, 255)
RACE_COL = (255, 140, 0)


def load(path):
    d = json.load(open(path))
    t = d["terrain"]
    nx, ny = t["size"]
    h = np.frombuffer(base64.b64decode(t["dm"]), dtype="<u2").astype(float).reshape(ny, nx) / 10.0
    return d, h, t["origin"], t["cell"]


def morrow(path):
    """The Morrow centreline in game metres and its width, from the world map
    (world coordinates less Bellerive's demo window origin)."""
    w = json.load(open(path))
    o = [c for c in w["cities"] if "demo_window" in c][0]["demo_window"]["origin"]
    r = [x for x in w["water"] if x["id"] == "morrow"][0]
    return [(p[0] - o[0], p[1] - o[1]) for p in r["line"]], float(r["width"])


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


def length(pts):
    return sum(np.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(pts, pts[1:]))


def sample(pts, step):
    """Points every `step` m along a polyline, with their distance along it."""
    out = []
    s0 = 0.0
    for a, b in zip(pts, pts[1:]):
        seg = np.hypot(b[0] - a[0], b[1] - a[1])
        k = 0.0 if not out else step - (s0 % step if s0 % step else step)
        while k < seg:
            t = k / seg
            out.append((s0 + k, a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            k += step
        s0 += seg
    out.append((s0, pts[-1][0], pts[-1][1]))
    return out


def rail_profile(h, origin, cell):
    """Ground and rail level every 8 m along RAIL. The level is the ground
    smoothed over 40 m with both ends pinned to it, then lowered wherever it
    would climb or fall faster than RAIL_GRADE (so it never leaves the ends'
    levels and favours tunnels over bridges)."""
    step = 8.0
    sp = sample(RAIL, step)
    ny, nx = h.shape
    g = np.array([h[min(max(int((y - origin[1]) / cell), 0), ny - 1),
                    min(max(int((x - origin[0]) / cell), 0), nx - 1)] for _, x, y in sp])
    lv = gaussian_filter(g, 40.0 / step, mode="nearest")
    lv[0], lv[-1] = g[0], g[-1]
    dz = RAIL_GRADE * step
    for i in range(1, len(lv)):               # lower envelope: one pass each way
        lv[i] = min(lv[i], lv[i - 1] + dz)
    for i in range(len(lv) - 2, -1, -1):
        lv[i] = min(lv[i], lv[i + 1] + dz)
    return sp, g, lv


def runs(mask, sp, min_len=24.0):
    """Stretches where mask holds for min_len m or more: (start, end, x0, y0, x1, y1)."""
    out = []
    i = 0
    while i < len(mask):
        if mask[i]:
            j = i
            while j + 1 < len(mask) and mask[j + 1]:
                j += 1
            if sp[j][0] - sp[i][0] >= min_len:
                out.append((sp[i][0], sp[j][0], sp[i][1], sp[i][2], sp[j][1], sp[j][2]))
            i = j + 1
        else:
            i += 1
    return out


def dashed(dr, pts, fill, width, on=10, off=7):
    """A dashed polyline in pixels."""
    carry, draw = 0.0, True
    for a, b in zip(pts, pts[1:]):
        seg = np.hypot(b[0] - a[0], b[1] - a[1])
        if seg == 0:
            continue
        s = 0.0
        while s < seg:
            run = (on if draw else off) - carry
            e = min(s + run, seg)
            if draw:
                t0, t1 = s / seg, e / seg
                dr.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0),
                         (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)],
                        fill=fill, width=width)
            if e - s < run:
                carry += e - s
            else:
                carry, draw = 0.0, not draw
            s = e


def main():
    argv = sys.argv[1:]
    out = "../docs/hill_country_design_map.png"
    if "--out" in argv:
        k = argv.index("--out")
        out = argv[k + 1]
        del argv[k:k + 2]
    path = argv[0] if argv else "data/country.json"
    d, h, origin, cell = load(path)
    river, river_w = morrow(path.replace("country.json", "world_map.json"))
    ny, nx = h.shape
    W, H = nx * SCALE, ny * SCALE
    img = Image.new("RGBA", (W + PANEL, H), (0, 0, 0, 255))
    img.paste(Image.fromarray(relief(h, cell)).resize((W, H), Image.BILINEAR), (0, 0))
    dr = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, 13)
    fs = ImageFont.truetype(FONT, 11)
    fb = ImageFont.truetype(FONT_B, 15)
    fn = ImageFont.truetype(FONT_B, 10)

    def px(p):
        return ((p[0] - origin[0]) / cell * SCALE, (p[1] - origin[1]) / cell * SCALE)

    # The Morrow as built.
    dr.line([px(p) for p in river], fill=WATER, width=int(river_w / cell * SCALE), joint="curve")

    # Zones, one overlay each so fills do not overwrite one another; the
    # forest only tints the hills (ground at 3 m or more).
    hill = Image.fromarray(((h >= 3.0) * 255).astype(np.uint8)).resize((W, H), Image.NEAREST)
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
        do.polygon(pts, fill=c + (70 if kind == "forest" else 55,), outline=c + (230,))
        if kind == "forest":
            a = np.array(over.getchannel("A"))
            a[:, :W] = a[:, :W] * (np.array(hill) > 0)
            over.putalpha(Image.fromarray(a))
        img = Image.alpha_composite(img, over)

    # A 500 m grid of faint full lines.
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    do = ImageDraw.Draw(over)
    step = 500 / cell * SCALE
    gx0 = (np.ceil(origin[0] / 500) * 500 - origin[0]) / cell * SCALE
    gy0 = (np.ceil(origin[1] / 500) * 500 - origin[1]) / cell * SCALE
    for gx in np.arange(gx0, W, step):
        do.line([(gx, 0), (gx, H)], fill=(255, 255, 255, 50))
    for gy in np.arange(gy0, H, step):
        do.line([(0, gy), (W, gy)], fill=(255, 255, 255, 50))
    img = Image.alpha_composite(img, over)
    dr = ImageDraw.Draw(img)

    hs = gaussian_filter(h, 3)
    for name, x, y in STREAMS:
        dr.line([px(p) for p in stream(hs, h, origin, cell, x, y)], fill=WATER, width=3)
    for name, x, y, r in LAKES:
        p = px((x, y))
        rr = r / cell * SCALE
        dr.ellipse([p[0] - rr, p[1] - rr * 0.7, p[0] + rr, p[1] + rr * 0.7], fill=WATER,
                   outline=(20, 60, 140))

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

    # The race loop on existing ways, south of RACE_NORTH only.
    names = {r["name"] for r in d["roads"]}
    for rn in RACE_ROADS:
        if rn not in names:
            print("warning: race road %r not in the data" % rn)
    for r in d["roads"]:
        if r["name"] in RACE_ROADS:
            seg = []
            for n in r["nodes"] + [None]:
                if n is not None and nodes[n][1] > RACE_NORTH:
                    seg.append(px(nodes[n]))
                    continue
                if len(seg) > 1:
                    dr.line(seg, fill=RACE_COL, width=5)
                seg = []

    for kind, label, pts in LINES:
        dashed(dr, [px(p) for p in pts], LINE_COL[kind], 4)

    # The proposed rail: dashed, tunnels hollow, bridges white blocks.
    sp, g, lv = rail_profile(h, origin, cell)
    tunnels = runs(g - lv > RAIL_CUT, sp)
    bridges = runs(lv - g > RAIL_FILL, sp)
    dashed(dr, [px(p) for p in RAIL], RAIL_COL, 3, on=14, off=6)
    for s0, s1, x0, y0, x1, y1 in tunnels:
        dr.line([px((x0, y0)), px((x1, y1))], fill=(0, 0, 0), width=9)
        dr.line([px((x0, y0)), px((x1, y1))], fill=(150, 150, 150), width=3)
    for s0, s1, x0, y0, x1, y1 in bridges:
        dr.line([px((x0, y0)), px((x1, y1))], fill=(255, 255, 255), width=8)

    for kind, label, poly in ZONES:
        xs = [px(p)[0] for p in poly]
        ys = [px(p)[1] for p in poly]
        ty = max(ys) + 4 if label in ZONE_BELOW else min(ys) + 4
        dr.text((min(xs) + 6, ty), label, fill=ZONE_COL[kind] + (255,), font=fb,
                stroke_width=2, stroke_fill=(0, 0, 0))

    mt = d["mountain"]
    for name, (x, y, z) in mt["peaks"].items():
        p = px((x, y))
        dr.polygon([(p[0], p[1] - 7), (p[0] - 6, p[1] + 5), (p[0] + 6, p[1] + 5)],
                   fill=(255, 255, 255), outline=(0, 0, 0))
        nx_, ny_ = PEAK_NUDGE.get(name, (0, 0))
        dr.text((p[0] + 8 + nx_, p[1] - 8 + ny_), "%s %d m" % (name.replace("_", " ").title(), z),
                fill=(255, 255, 255), font=f, stroke_width=2, stroke_fill=(0, 0, 0))
    for sid, s in mt["sites"].items():
        if sid.startswith("view_"):
            p = px((s["x"], s["y"]))
            dr.ellipse([p[0] - 4, p[1] + 6, p[0] + 4, p[1] + 14], outline=(80, 255, 255), width=2)

    for name, x, y, r in LAKES:                # west of each lake, or below it
        p = px((x, y))
        tw = dr.textlength(name, font=fs)
        rr = r / cell * SCALE
        at = ((p[0] - tw / 2, p[1] + rr * 0.7 + 3) if name in LAKE_BELOW
              else (p[0] - rr - tw - 4, p[1] - 6))
        dr.text(at, name, fill=WATER, font=fs, stroke_width=2, stroke_fill=(0, 0, 0))
    for name, x, y in STREAMS[:1]:             # beside the middle of the stream
        path = stream(hs, h, origin, cell, x, y)
        p = px(path[len(path) // 2])
        dr.text((p[0] + 8, p[1] - 6), name, fill=WATER, font=fs, stroke_width=2,
                stroke_fill=(0, 0, 0))
    p = px((-300, -4560))
    dr.text(p, "Morrow (river, built)", fill=WATER, font=f, stroke_width=2, stroke_fill=(0, 0, 0))

    # Numbered places and the printed table.
    gy, gx = np.gradient(gaussian_filter(h, 1), cell)
    slope = maximum_filter(np.hypot(gx, gy), 5)
    print("%2s %-64s %11s %5s %5s  nearest road or trail" % ("#", "place", "x,y", "h m", "slope"))
    for n, (kind, label, x, y) in enumerate(PLACES, 1):
        p = px((x, y))
        c = PLACE_COL[kind]
        dr.ellipse([p[0] - 8, p[1] - 8, p[0] + 8, p[1] + 8], fill=c, outline=(0, 0, 0), width=2)
        tw = dr.textlength(str(n), font=fn)
        dr.text((p[0] - tw / 2, p[1] - 6), str(n), fill=(0, 0, 0), font=fn)
        name, dist = nearest(d, x, y)
        i, j = int((y - origin[1]) / cell), int((x - origin[0]) / cell)
        print("%2d %-64s %5d,%-5d %5.0f %5.2f  %s, %.0f m"
              % (n, label, x, y, h[i, j], slope[i, j], name, dist))
    for kind, label, pts in LINES:
        print("line: %s, %.0f m" % (label, length(pts)))
    print("rail: %.0f m, grade %.3f; tunnels (over %.0f m deep) and bridges (over %.0f m high):"
          % (sp[-1][0], RAIL_GRADE, RAIL_CUT, RAIL_FILL))
    for what, rr in (("tunnel", tunnels), ("bridge", bridges)):
        for s0, s1, x0, y0, x1, y1 in rr:
            print("  %s %.0f-%.0f m (%.0f m) from (%.0f,%.0f) to (%.0f,%.0f)"
                  % (what, s0, s1, s1 - s0, x0, y0, x1, y1))

    # Key panel.
    kx, ky = W + 14, 12
    dr.rectangle([W, 0, W + PANEL, H], fill=(18, 18, 22))
    dr.text((kx, ky), "Hill country design map (2026-10-31)", fill=(255, 255, 255), font=fb)
    ky += 26
    rows = [("Built: relief, the Morrow, roads, tracks (brown),", (220, 220, 220)),
            ("  trails (dotted), rails (dark), peaks, views (cyan ring)", (220, 220, 220)),
            ("PROPOSED, not built: everything below", (255, 200, 120)),
            ("quiet: trails, springs, views, wildlife; no events", ZONE_COL["quiet"]),
            ("busy: towns, races, raves; thin ring = %d m buffer" % BUFFER, ZONE_COL["busy"]),
            ("closed: secret lab hollow, one guarded road", ZONE_COL["closed"]),
            ("forest: back-range forest and hunting ground", ZONE_COL["forest"]),
            ("orange: hill race loop on existing ways", RACE_COL),
            ("dashed: new ways (lab road red, haul brown, sky bridge)", (220, 220, 220)),
            ("white dashed: rail branch; tunnels grey, bridges white", RAIL_COL),
            ("blue: streams and lakes found from the ground", WATER),
            ("north is up; 1 px = 4 m; grid 500 m", (220, 220, 220))]
    for text, c in rows:
        dr.text((kx, ky), text, fill=c, font=fs)
        ky += 16
    ky += 8
    dr.text((kx, ky), "Places", fill=(255, 255, 255), font=f)
    ky += 20
    for n, (kind, label, x, y) in enumerate(PLACES, 1):
        c = PLACE_COL[kind]
        dr.ellipse([kx, ky + 1, kx + 12, ky + 13], fill=c, outline=(0, 0, 0))
        for k, part in enumerate(textwrap.wrap(label, 56)):
            dr.text((kx + 18, ky), ("%d  " % n if k == 0 else "     ") + part, fill=c, font=fs)
            ky += 15
        ky += 1
    ky += 8
    dr.text((kx, ky), "Rail branch: %.1f km at %.0f%%" % (sp[-1][0] / 1000, RAIL_GRADE * 100),
            fill=RAIL_COL, font=f)
    ky += 18
    for what, rr in (("tunnel", tunnels), ("bridge", bridges)):
        for s0, s1, x0, y0, x1, y1 in rr:
            dr.text((kx, ky), "  %s %.0f m near (%.0f, %.0f)" % (what, s1 - s0, x0, y0),
                    fill=(200, 200, 200), font=fs)
            ky += 15
    if ky > H:
        print("warning: key panel overflows by %d px" % (ky - H))
    img.convert("RGB").save(out)
    print("saved", out)


if __name__ == "__main__":
    main()
