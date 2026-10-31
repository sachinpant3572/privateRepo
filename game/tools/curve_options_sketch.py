"""Rough top-down sketches of the curved-road options (Now, A, B, C) from a plan dump.
Usage: python3 game/tools/curve_options_sketch.py /tmp/plan.json out.png"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union
from shapely.prepared import prep

P = json.load(open(sys.argv[1]))
OUT = sys.argv[2]
NODES = np.array(P["nodes"], float)
EDGES = P["edges"]
OUTLINE = Polygon(P["outline"])
X0, Y0, X1, Y1 = -380, -720, 2320, 2060
S = 0.36  # px per metre
W, H = int((X1 - X0) * S), int((Y1 - Y0) * S)
HEAD = 64
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_title = ImageFont.truetype(FONTB, 22)
f_sub = ImageFont.truetype(FONT, 15)
f_lab = ImageFont.truetype(FONTB, 13)

SEA = (118, 170, 196); LAND = (243, 238, 226); PARK = (178, 210, 160)
ROAD = (92, 92, 98); NEW = (222, 84, 30); BENT = (226, 140, 40)
WIDTH = {"boulevard": 3.2, "avenue": 2.2, "bridge": 3.2, "river": 2.0, "quay": 1.6,
         "street": 1.1, "quarter": 1.0, "lane": 0.8}


def px(q):
    return ((q[0] - X0) * S, (q[1] - Y0) * S + HEAD)


# --- the river: between the north bank roads (River Road, quay) and the levee
def bank(names, pad):
    pts = sorted({tuple(NODES[i]) for e in EDGES if e[3] in names for i in e[:2]},
                 key=lambda q: q[0] + q[1])
    return pts
north = [(-380, 1150)] + bank(("river_road", "quay"), 0) + [(1640, 2060)]
south = [(-380, 1395)] + bank(("levee",), 0) + [(1420, 2060)]
RIVER = Polygon(north + south[::-1]).buffer(-13)
LAND_POLY = OUTLINE.difference(RIVER)
LAND_PREP = prep(LAND_POLY)
RIVER_LINE = LineString([((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(
    [north[min(int(i * len(north) / 40), len(north) - 1)] for i in range(40)],
    [south[min(int(i * len(south) / 40), len(south) - 1)] for i in range(40)])])

PARK_FACES = [P["faces"][f]["poly"] for _, kind, f in P["pieces"]
              if kind in ("park", "grounds", "esplanade", "green", "plaza", "square")]


def catmull(ctrl, step=6.0):
    pts = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = map(np.array, pts[i - 1:i + 3])
        n = max(2, int(np.linalg.norm(p2 - p1) / step))
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(np.array(ctrl[-1]))
    return [tuple(q) for q in out]


def edge_lines(nodes, skip=None):
    out = []
    for a, b, cls, road in EDGES:
        if skip and skip(nodes[a], nodes[b]):
            continue
        out.append(([tuple(nodes[a]), tuple(nodes[b])], cls, road))
    return out


def off_grid_share(lines):
    tot = off = 0.0
    for pts, cls, _ in lines:
        if cls in ("lane",):
            continue
        for a, b in zip(pts, pts[1:]):
            d = np.subtract(b, a); L = float(np.hypot(*d))
            if L < 1e-6:
                continue
            ang = math.degrees(math.atan2(d[1], d[0])) % 90
            tot += L
            if min(ang, 90 - ang) > 2.5:
                off += L
    return 100 * off / tot


def base(img_draw, parks):
    d = img_draw
    d.rectangle([0, HEAD, W, H + HEAD], fill=SEA)
    d.polygon([px(q) for q in OUTLINE.exterior.coords], fill=LAND)
    d.polygon([px(q) for q in RIVER.exterior.coords], fill=SEA)
    for poly in parks:
        d.polygon([px(q) for q in poly], fill=PARK)


def draw_lines(d, lines, color=ROAD, scale=1.0):
    for pts, cls, _ in lines:
        w = max(1, round(WIDTH.get(cls, 1.0) * scale * 1.15))
        d.line([px(q) for q in pts], fill=color, width=w, joint="curve")


def finish(img, title, sub, lines, labels=()):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, HEAD], fill=(250, 250, 248))
    d.text((12, 6), title, font=f_title, fill=(30, 30, 30))
    d.text((12, 38), sub + f"   |   off the city grid: {off_grid_share(lines):.0f}% of street length",
           font=f_sub, fill=(70, 70, 70))
    for text, q in labels:
        x, y = px(q)
        d.text((x, y), text, font=f_lab, fill=(150, 40, 10), stroke_width=3, stroke_fill=(255, 255, 255))
    # scale bar and north arrow
    x, y = 20, H + HEAD - 26
    d.line([(x, y), (x + 500 * S, y)], fill=(20, 20, 20), width=3)
    d.text((x, y - 18), "500 m", font=f_sub, fill=(20, 20, 20))
    d.text((W - 40, HEAD + 10), "N", font=f_title, fill=(20, 20, 20))
    d.line([(W - 32, HEAD + 60), (W - 32, HEAD + 36)], fill=(20, 20, 20), width=3)
    d.rectangle([0, 0, W - 1, H + HEAD - 1], outline=(120, 120, 120), width=1)
    return img


def new_panel(parks):
    img = Image.new("RGB", (W, H + HEAD), LAND)
    base(ImageDraw.Draw(img), parks)
    return img


# ------------------------------------------------------------------ Now
def panel_now():
    lines = edge_lines(NODES)
    img = new_panel(PARK_FACES)
    draw_lines(ImageDraw.Draw(img), lines)
    return finish(img, "NOW", "today's street plan (grid, two turned grids, river roads)", lines)


# ------------------------------------------------------------------ A
SEAGRAPE_AT = np.array([1242.0, 1744.0]); SEAWARD = np.array([0.630, 0.776])
FIXED_ROADS = {"levee", "river_road", "quay", "bridge", "seagrape", "ocean", "liberty", "crescent",
               "hibiscus", "basin"}
levee_pts = sorted(bank(("levee",), 0))


def levee_y(x):
    xs = [q[0] for q in levee_pts]; ys = [q[1] for q in levee_pts]
    return float(np.interp(x, xs, ys))


def bow(q):
    x, y = q
    # Morrow Point: rows bulge north towards the river, fading in from the levee.
    if -80 < x < 690 and y > levee_y(x) + 5:
        t = (x + 80) / 770
        w = min(1.0, (y - levee_y(x)) / 220)
        return (x, y - 70 * math.sin(math.pi * t) * w)
    # Calle Luna: rows bulge towards the sea, fading in from Crescent and out at Seagrape.
    s = float(np.dot(np.array(q) - SEAGRAPE_AT, SEAWARD))
    if 1460 < x < 2230 and y > 500 and s < 0:
        t = (x - 1460) / 770
        w = min(1.0, (y - 500) / 150, -s / 150)
        return (x, y + 60 * math.sin(math.pi * t) * w)
    return (x, y)


MIRADOR = catmull([(330, -280), (240, -300), (160, -350), (110, -420), (60, -500), (-30, -560), (-120, -640)])
CANYON = catmull([(1460, 100), (1540, 60), (1600, 0), (1640, -90), (1660, -180), (1665, -280)])


def curved_A():
    fixed = set()
    for a, b, cls, road in EDGES:
        if road in FIXED_ROADS:
            fixed.update((a, b))
    nodes = NODES.copy()
    moved = set()
    for i, q in enumerate(NODES):
        if i in fixed:
            continue
        nq = bow(tuple(q))
        if abs(nq[1] - q[1]) > 0.5:
            moved.add(i)
        nodes[i] = nq
    lines = []
    for a, b, cls, road in EDGES:
        pa, pb = nodes[a], nodes[b]
        if (a in moved or b in moved) and np.hypot(*(NODES[b] - NODES[a])) > 1:
            # resample the moved edge so a long straight edge bends too
            seg = [bow(tuple(NODES[a] + (NODES[b] - NODES[a]) * k / 8)) if not (k == 0 and a in fixed or k == 8 and b in fixed)
                   else tuple(NODES[a] + (NODES[b] - NODES[a]) * k / 8) for k in range(9)]
            lines.append((seg, cls, road + "*"))
        else:
            lines.append(([tuple(pa), tuple(pb)], cls, road))
    shore = LineString([q for q in levee_pts if q[0] <= 612]).offset_curve(-75)
    shore = shore.intersection(LAND_POLY)
    new = []
    for c, cls in ((MIRADOR, "boulevard"), (CANYON, "avenue")):
        new.append((c, cls, "new"))
    for g in getattr(shore, "geoms", [shore]):
        if g.length > 50:
            new.append((list(g.coords), "avenue", "new"))
    return lines, new


def draw_A_like(img, lines, new, mask=None):
    d = ImageDraw.Draw(img)
    old = [l for l in lines if not l[2].endswith("*")]
    bent = [l for l in lines if l[2].endswith("*")]
    draw_lines(d, old)
    draw_lines(d, bent, BENT)
    for pts, cls, _ in new:
        inside = LineString(pts).intersection(OUTLINE)
        outside = LineString(pts).difference(OUTLINE)
        for g in getattr(inside, "geoms", [inside]):
            if g.length > 1:
                d.line([px(q) for q in g.coords], fill=NEW, width=max(2, round(WIDTH[cls] * 1.6)), joint="curve")
        for g in getattr(outside, "geoms", [outside]):  # carried on by the country
            cs = list(g.coords)
            for k in range(0, len(cs) - 1, 2):
                d.line([px(cs[k]), px(cs[k + 1])], fill=NEW, width=2)


def panel_A():
    lines, new = curved_A()
    parks = [[bow(tuple(q)) for q in poly] for poly in PARK_FACES]
    img = new_panel(parks)
    draw_A_like(img, lines, new)
    labels = [("Mirador Blvd", (120, -470)), ("Canyon Dr", (1560, -120)),
              ("Morrow Point rows", (60, 1520)), ("Shore Pkwy", (-60, 1360)), ("Calle Luna rows", (1640, 900))]
    return finish(img, "A  ·  curved roads + bent street groups  (8-12 h)",
                  "orange = new curved roads, amber = existing rows bent; downtown grid unchanged",
                  lines + new, labels)


# ------------------------------------------------------------------ B
HILL = OUTLINE.intersection(box(-400, -800, 330, -222))
CREST = (10, -430)


def hill_streets():
    out = []
    rng = np.random.default_rng(7)
    for R in (65, 130, 200, 270):
        ring = []
        for k in range(181):
            th = 2 * math.pi * k / 180
            r = R * (1 + 0.10 * math.sin(3 * th + R / 40) + 0.05 * math.sin(5 * th))
            ring.append((CREST[0] + r * math.cos(th), CREST[1] + 0.85 * r * math.sin(th)))
        g = LineString(ring).intersection(HILL)
        for part in getattr(g, "geoms", [g]):
            if part.length > 40:
                out.append((list(part.coords), "street", "hill"))
    for th in np.radians([10, 70, 135, 200, 255, 320]):
        seg = LineString([(CREST[0] + 65 * math.cos(th), CREST[1] + 55 * math.sin(th)),
                          (CREST[0] + 420 * math.cos(th), CREST[1] + 360 * math.sin(th))]).intersection(HILL)
        for part in getattr(seg, "geoms", [seg]):
            if part.length > 20:
                out.append((list(part.coords), "street", "hill"))
    for th in np.radians([40, 100, 165, 230, 290]):  # cul-de-sacs off the middle ring
        r0, r1 = 140, 172
        a = (CREST[0] + r0 * math.cos(th), CREST[1] + 0.85 * r0 * math.sin(th))
        b = (CREST[0] + r1 * math.cos(th + 0.12), CREST[1] + 0.85 * r1 * math.sin(th + 0.12))
        if HILL.contains(Point(b)):
            out.append(([a, b], "lane", "culdesac"))
    return out


def panel_B():
    lines, new = curved_A()
    hp = prep(HILL.buffer(4))
    lines = [l for l in lines if not (hp.contains(Point(l[0][0])) and hp.contains(Point(l[0][-1])))]
    trimmed = []
    for pts, cls, road in lines:
        ls = LineString(pts)
        if hp.intersects(ls) and road not in ("lantern", "presidio"):
            g = ls.difference(HILL)
            for part in getattr(g, "geoms", [g]):
                if part.length > 1:
                    trimmed.append((list(part.coords), cls, road))
        else:
            trimmed.append((pts, cls, road))
    hill = hill_streets()
    parks = [[bow(tuple(q)) for q in poly] for poly in PARK_FACES]
    parks.append([(CREST[0] + 40 * math.cos(t), CREST[1] + 34 * math.sin(t)) for t in np.linspace(0, 6.28, 30)])
    img = new_panel(parks)
    draw_A_like(img, trimmed, new + hill)
    d = ImageDraw.Draw(img)
    for pts, cls, road in hill:
        if road == "culdesac":
            x, y = px(pts[-1]); d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=NEW)
    labels = [("Cable Hill contour streets", (-280, -660)), ("Canyon Dr", (1560, -120)),
              ("Morrow Point rows", (60, 1520)), ("Calle Luna rows", (1640, 900))]
    return finish(img, "B  ·  A + contour hill district  (A + 6-10 h)",
                  "Cable Hill rebuilt as winding contour loops, spokes and cul-de-sacs (still flat ground)",
                  trimmed + new + hill, labels)


# ------------------------------------------------------------------ C
def field():
    gx = np.arange(X0, X1, 10.0); gy = np.arange(Y0, Y1, 10.0)
    X, Y = np.meshgrid(gx, gy)
    T = np.zeros(X.shape + (2,))
    def add(theta, w):
        T[..., 0] += w * np.cos(2 * theta); T[..., 1] += w * np.sin(2 * theta)
    gauss = lambda c, s: np.exp(-((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (2 * s * s))
    add(np.zeros_like(X), 1.0 * gauss((500, 250), 650))           # downtown grid
    add(np.full_like(X, math.radians(-39)), 1.6 * gauss((1950, 1350), 380))  # Brisa, on the coast
    add(np.full_like(X, math.radians(18)), 0.9 * gauss((350, 1700), 330))    # Morrow Point
    add(np.arctan2(Y - (-680), X - 40) + math.pi / 2, 1.3 * gauss((40, -680), 300))  # hill: rings
    # river: tangent to its centre line
    pts = np.array(RIVER_LINE.coords)
    best = np.full(X.shape, 1e9); ang = np.zeros(X.shape)
    for a, b in zip(pts, pts[1:]):
        d = b - a; L2 = float(d @ d)
        t = np.clip(((X - a[0]) * d[0] + (Y - a[1]) * d[1]) / L2, 0, 1)
        dist = np.hypot(X - a[0] - t * d[0], Y - a[1] - t * d[1])
        m = dist < best
        best[m] = dist[m]; ang[m] = math.atan2(d[1], d[0])
    add(ang, 1.4 * np.exp(-best ** 2 / (2 * 140 ** 2)))
    return gx, gy, T


def panel_C():
    gx, gy, T = field()
    def major(q):
        i = int((q[1] - Y0) / 10); j = int((q[0] - X0) / 10)
        i = min(max(i, 0), len(gy) - 1); j = min(max(j, 0), len(gx) - 1)
        th = 0.5 * math.atan2(T[i, j, 1], T[i, j, 0])
        return np.array([math.cos(th), math.sin(th)])
    def dirf(q, fam):
        v = major(q)
        return v if fam == 0 else np.array([-v[1], v[0]])
    grids = [{}, {}]
    def near(q, fam, dmin, own):
        k = (int(q[0] // dmin), int(q[1] // dmin))
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for (p, sid) in grids[fam].get((k[0] + dx, k[1] + dy), ()):
                    if sid != own and (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 < dmin * dmin:
                        return True
        return False
    def stamp(pts, fam, dmin, sid):
        for q in pts:
            grids[fam].setdefault((int(q[0] // dmin), int(q[1] // dmin)), []).append((q, sid))
    lines = []
    sid = 0
    for dsep, cls in ((230, "boulevard"), (78, "street")):
        for g in grids:  # re-key the hash for the new spacing
            old = [v for vs in g.values() for v in vs]; g.clear()
            for q, s in old:
                g.setdefault((int(q[0] // dsep), int(q[1] // dsep)), []).append((q, s))
        seeds = [(x, y) for y in np.arange(Y0, Y1, dsep * 0.5) for x in np.arange(X0, X1, dsep * 0.5)
                 if LAND_PREP.contains(Point(x, y))]
        rng = np.random.default_rng(3); rng.shuffle(seeds)
        for fam in (0, 1):
            for s in seeds:
                if near(s, fam, dsep, -1):
                    continue
                sid += 1
                halves = []
                for sign in (1, -1):
                    q = np.array(s, float); v = dirf(q, fam) * sign; out = []
                    for _ in range(600):
                        k1 = dirf(q, fam); k1 = k1 if k1 @ v >= 0 else -k1
                        mid = q + k1 * 4
                        k2 = dirf(mid, fam); k2 = k2 if k2 @ v >= 0 else -k2
                        q = q + k2 * 8; v = k2
                        if not LAND_PREP.contains(Point(*q)) or near(q, fam, dsep * 0.55, sid):
                            break
                        out.append(tuple(q))
                    halves.append(out)
                line = halves[1][::-1] + [tuple(s)] + halves[0]
                if len(line) * 8 < dsep * 0.6:
                    continue
                stamp(line, fam, dsep, sid)
                lines.append((line, cls, "tensor"))
    img = new_panel([])
    d = ImageDraw.Draw(img)
    draw_lines(d, [l for l in lines if l[1] == "street"])
    draw_lines(d, [l for l in lines if l[1] == "boulevard"], NEW, 0.9)
    return finish(img, "C  ·  tensor-field generator  (30-50 h)",
                  "whole street layout regenerated; set pieces, circles and plan-bound tests redone",
                  lines, [("arterials (orange) and streets follow one field", (-300, 2000))])


panels = [panel_now(), panel_A(), panel_B(), panel_C()]
gap = 12
sheet = Image.new("RGB", (2 * W + 3 * gap, 2 * (H + HEAD) + 3 * gap), (255, 255, 255))
for k, im in enumerate(panels):
    sheet.paste(im, (gap + (k % 2) * (W + gap), gap + (k // 2) * (H + HEAD + gap)))
sheet.save(OUT)
print("saved", OUT, sheet.size)
