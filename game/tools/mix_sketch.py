"""Rough top-down sketches of the A + B + C street-plan mix, four variations.

Tensor-field streets (C) round the hand-placed set pieces, Cable Hill as a
contour district (B), the single curved roads Mirador and Canyon (A), and the
roundabouts. Drawn from a plan dump (tests/plan_dump.gd) for Sachin to choose
from before the build; nothing here runs in the game.
Usage: python3 game/tools/mix_sketch.py /tmp/plan.json out.png"""
import json, math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from shapely.geometry import Polygon, LineString, Point, MultiLineString, box
from shapely.ops import unary_union, nearest_points
from shapely.prepared import prep

P = json.load(open(sys.argv[1]))
OUT = sys.argv[2]
NODES = np.array(P["nodes"], float)
EDGES = P["edges"]
OUTLINE = Polygon(P["outline"])
X0, Y0, X1, Y1 = -380, -720, 2320, 2060
S = 0.36
W, H = int((X1 - X0) * S), int((Y1 - Y0) * S)
HEAD = 64
F = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_title, f_sub, f_lab = ImageFont.truetype(FB, 21), ImageFont.truetype(F, 14), ImageFont.truetype(FB, 12)

SEA = (118, 170, 196); PAPER = (243, 238, 226); PARK = (178, 210, 160)
HAND = (60, 60, 66); ART = (222, 84, 30); STREET = (120, 120, 126); HILL_C = (128, 70, 160); A_C = (200, 30, 60)
WIDTH = {"boulevard": 3.4, "avenue": 2.4, "bridge": 3.4, "river": 2.0, "quay": 1.6,
         "street": 1.1, "quarter": 1.0, "lane": 0.8}


def px(q):
    return ((q[0] - X0) * S, (q[1] - Y0) * S + HEAD)


def bank(names):
    return sorted({tuple(NODES[i]) for e in EDGES if e[3] in names for i in e[:2]}, key=lambda q: q[0] + q[1])


north = [(-380, 1150)] + bank(("river_road", "quay")) + [(1640, 2060)]
south = [(-380, 1395)] + bank(("levee",)) + [(1420, 2060)]
RIVER = Polygon(north + south[::-1]).buffer(-13)
LAND = OUTLINE.difference(RIVER)
LAND_PREP = prep(LAND)
k = 40
RIVER_LINE = [((north[min(int(i * len(north) / k), len(north) - 1)][0] + south[min(int(i * len(south) / k), len(south) - 1)][0]) / 2,
               (north[min(int(i * len(north) / k), len(north) - 1)][1] + south[min(int(i * len(south) / k), len(south) - 1)][1]) / 2)
              for i in range(k)]


def catmull(ctrl, step=6.0):
    pts = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = map(np.array, pts[i - 1:i + 3])
        n = max(2, int(np.linalg.norm(p2 - p1) / step))
        for j in range(n):
            t = j / n
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                    + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)))
    out.append(tuple(ctrl[-1]))
    return out


# ------------------------------------------------------------ hand-placed parts
def named(names, clip=None):
    out = []
    for a, b, cls, road in EDGES:
        if road in names:
            seg = LineString([NODES[a], NODES[b]])
            if clip is not None:
                seg = seg.intersection(clip)
            for g in getattr(seg, "geoms", [seg]):
                if g.length > 0.5:
                    out.append((list(g.coords), cls, road))
    return out


WATER_ROADS = {"river_road", "levee", "quay", "bridge"}
SET_ROADS = {"founders", "civic", "esplanade", "moreau", "liberty", "ocean", "presidio",
             "liberty_circle", "aurum_circle", "cypress_circle", "harbor_circle"}
FRAME = {"lantern", "crescent", "rampart", "palmetto", "cypress", "aurum", "basin", "harbor", "morrow",
         "hibiscus", "tamarind", "mangrove", "gulfview", "pelican", "seagrape", "wharf", "point_ave"}
CIRCLES = [(330, 257, 46), (690, 500, 30), (1010, 140, 26), (1010, 500, 26), (690, 1400, 26)]
GREEN = [P["faces"][f]["poly"] for _, kind, f in P["pieces"] if kind in ("grounds", "esplanade", "square")]
GREEN.append(P["faces"][P["park"]]["poly"])
# Lantern Quarter East: the old town's turned grid stays as it is.
QE = []
for a, b, cls, road in EDGES:
    if cls == "quarter":
        d = NODES[b] - NODES[a]
        ang = math.degrees(math.atan2(d[1], d[0])) % 90
        if 20 < ang < 70:
            QE.append(([tuple(NODES[a]), tuple(NODES[b])], cls, "quarter_e"))
QE_AREA = unary_union([LineString(l[0]) for l in QE]).convex_hull.buffer(4)
HILL = OUTLINE.intersection(box(-400, -800, 330, -222))
CREST = (10, -430)
MIRADOR = catmull([(330, -280), (240, -300), (160, -350), (110, -420), (60, -500), (-30, -560), (-120, -640)])
CANYON = catmull([(1460, 100), (1540, 60), (1600, 0), (1640, -90), (1660, -180), (1665, -280)])


def hill_streets():
    out = []
    for R in (65, 130, 200, 270):
        ring = []
        for j in range(181):
            th = 2 * math.pi * j / 180
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
    culs = []
    for th in np.radians([40, 100, 165, 230, 290]):
        a = (CREST[0] + 140 * math.cos(th), CREST[1] + 0.85 * 140 * math.sin(th))
        b = (CREST[0] + 172 * math.cos(th + 0.12), CREST[1] + 0.85 * 172 * math.sin(th + 0.12))
        if HILL.contains(Point(b)):
            out.append(([a, b], "lane", "hill")); culs.append(b)
    return out, culs


# ------------------------------------------------------------ the field
def build_field(v):
    gx = np.arange(X0, X1, 10.0); gy = np.arange(Y0, Y1, 10.0)
    X, Y = np.meshgrid(gx, gy)
    T = np.zeros(X.shape + (2,))
    def add(theta, w):
        T[..., 0] += w * np.cos(2 * theta); T[..., 1] += w * np.sin(2 * theta)
    gauss = lambda c, s: np.exp(-((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (2 * s * s))
    def along(line, sigma, w):
        pts = np.array(line, float)
        best = np.full(X.shape, 1e9); ang = np.zeros(X.shape)
        for a, b in zip(pts, pts[1:]):
            d = b - a; L2 = float(d @ d)
            if L2 < 1e-6:
                continue
            t = np.clip(((X - a[0]) * d[0] + (Y - a[1]) * d[1]) / L2, 0, 1)
            dist = np.hypot(X - a[0] - t * d[0], Y - a[1] - t * d[1])
            m = dist < best
            best[m] = dist[m]; ang[m] = math.atan2(d[1], d[0])
        add(ang, w * np.exp(-best ** 2 / (2 * sigma ** 2)))
    add(np.zeros_like(X), v["grid_w"] * gauss((450, 300), v["grid_s"]))       # downtown grid
    add(np.full_like(X, math.radians(-39)), 1.6 * gauss((1950, 1350), v["coast_s"]))  # Gulf coast
    along(RIVER_LINE, v["river_s"], v["river_w"])                               # the Morrow
    for line in v["align"]:                                                      # the curved roads
        along(line, 70, 1.2)
    for c, ang, s, w in v.get("extra", []):
        add(np.full_like(X, math.radians(ang)), w * gauss(c, s))
    return gx, gy, T


def trace_all(v, fixed, obstacles):
    gx, gy, T = build_field(v)
    obst = unary_union(obstacles)
    obst_p = prep(obst); obst_b = obst.boundary
    def dirf(q, fam):
        i = min(max(int((q[1] - Y0) / 10), 0), len(gy) - 1); j = min(max(int((q[0] - X0) / 10), 0), len(gx) - 1)
        th = 0.5 * math.atan2(T[i, j, 1], T[i, j, 0]) + (math.pi / 2 if fam else 0)
        return np.array([math.cos(th), math.sin(th)])
    CELL = 40.0
    grids = [{}, {}]
    def stamp(pts, fam, sid):
        for q in pts:
            grids[fam].setdefault((int(q[0] // CELL), int(q[1] // CELL)), []).append((q, sid))
    def nearest(q, fam, dmin, own):
        r = int(dmin // CELL) + 1; kx, ky = int(q[0] // CELL), int(q[1] // CELL)
        best, bd = None, dmin * dmin
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                for (p, sid) in grids[fam].get((kx + dx, ky + dy), ()):
                    if sid != own:
                        d2 = (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2
                        if d2 < bd:
                            best, bd = p, d2
        return best
    sid = 0
    for line in fixed:  # a hand-placed road keeps away the field roads that run along it
        pts = [tuple(q) for q in LineString(line).segmentize(8).coords]
        sid += 1
        for p0, p1 in zip(pts, pts[1:]):
            t = np.subtract(p1, p0); t = t / (np.hypot(*t) + 1e-9)
            fam = 0 if abs(t @ dirf(p0, 0)) >= abs(t @ dirf(p0, 1)) else 1
            stamp([p0], fam, sid)
    out = []
    for dsep, cls, seeds_extra in v["passes"]:
        seeds = list(seeds_extra) + sorted(
            [(x, y) for y in np.arange(Y0, Y1, dsep * 0.5) for x in np.arange(X0, X1, dsep * 0.5)],
            key=lambda q: (q[0] - 450) ** 2 + (q[1] - 300) ** 2)
        seeds = [s for s in seeds if LAND_PREP.contains(Point(s)) and not obst_p.contains(Point(s))]
        for fam in (0, 1):
            for s in seeds:
                if nearest(s, fam, dsep * (0.3 if s in seeds_extra else 0.9), -1) is not None:
                    continue
                sid += 1
                halves = []
                for sign in (1, -1):
                    q = np.array(s, float); vdir = dirf(q, fam) * sign; pts = []
                    for _ in range(700):
                        k1 = dirf(q, fam); k1 = k1 if k1 @ vdir >= 0 else -k1
                        k2 = dirf(q + k1 * 4, fam); k2 = k2 if k2 @ vdir >= 0 else -k2
                        nq = q + k2 * 8; vdir = k2
                        pt = Point(*nq)
                        if not LAND_PREP.contains(pt):
                            hit = LineString([q, nq]).intersection(LAND.boundary)
                            if not hit.is_empty:
                                pts.append(nearest_points(Point(*q), hit)[1].coords[0])
                            break
                        if obst_p.contains(pt):
                            hit = LineString([q, nq]).intersection(obst_b)
                            if not hit.is_empty:
                                pts.append(nearest_points(Point(*q), hit)[1].coords[0])
                            break
                        j = nearest(tuple(nq), fam, dsep * 0.5, sid)
                        if j is not None:
                            pts.append(j)  # join the street it ran into
                            break
                        pts.append(tuple(nq)); q = nq
                    halves.append(pts)
                line = halves[1][::-1] + [tuple(s)] + halves[0]
                if len(line) < 4 or LineString(line).length < dsep * 0.5:
                    continue
                stamp(line, fam, sid)
                out.append((line, cls, "field"))
    return out


def off_grid(lines):
    tot = off = 0.0
    for pts, cls, _ in lines:
        ls = LineString(pts)
        n = max(1, int(ls.length // 40))
        pts = [ls.interpolate(ls.length * i / n).coords[0] for i in range(n + 1)]
        for a, b in zip(pts, pts[1:]):
            d = np.subtract(b, a); L = float(np.hypot(*d))
            if L < 1e-6:
                continue
            ang = math.degrees(math.atan2(d[1], d[0])) % 90
            tot += L; off += L if min(ang, 90 - ang) > 2.5 else 0
    return 100 * off / tot


def panel(v):
    core = v.get("core")
    hand = named(WATER_ROADS | SET_ROADS) + QE
    frame = named(FRAME, core) if v["frame"] else named({"lantern"}, box(320, -800, 340, -200))
    a_roads = [(list(LineString(c).intersection(OUTLINE).coords), cls, "A") for c, cls in ((MIRADOR, "boulevard"), (CANYON, "avenue"))]
    hill, culs = hill_streets()
    obstacles = [RIVER, QE_AREA, HILL.buffer(1)] + [Polygon(g) for g in GREEN] + [Point(x, y).buffer(r + 4) for x, y, r in CIRCLES]
    fixed = [l[0] for l in hand + frame + a_roads if not l[2].endswith("circle")]
    field = trace_all(v, fixed, obstacles)
    img = Image.new("RGB", (W, H + HEAD), PAPER)
    d = ImageDraw.Draw(img)
    d.rectangle([0, HEAD, W, H + HEAD], fill=SEA)
    d.polygon([px(q) for q in OUTLINE.exterior.coords], fill=PAPER)
    d.polygon([px(q) for q in RIVER.exterior.coords], fill=SEA)
    for g in GREEN:
        d.polygon([px(q) for q in g], fill=PARK)
    hp = [(CREST[0] + 40 * math.cos(t), CREST[1] + 34 * math.sin(t)) for t in np.linspace(0, 6.28, 30)]
    d.polygon([px(q) for q in hp], fill=PARK)
    def lines(ls, color, scale=1.0):
        for pts, cls, _ in ls:
            d.line([px(q) for q in pts], fill=color, width=max(1, round(WIDTH.get(cls, 1) * scale * 1.15)), joint="curve")
    lines([l for l in field if l[1] == "street"], STREET)
    lines([l for l in field if l[1] != "street"], ART, 0.9)
    lines(hill, HILL_C, 1.6)
    for c in culs:
        x, y = px(c); d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=HILL_C)
    lines(frame + hand, HAND)
    lines(a_roads, A_C, 1.3)
    for x, y, r in CIRCLES:
        a, b = px((x - r, y - r)), px((x + r, y + r))
        d.ellipse([a, b], outline=HAND, width=3)
    d.rectangle([0, 0, W, HEAD], fill=(250, 250, 248))
    d.text((12, 6), v["title"], font=f_title, fill=(30, 30, 30))
    d.text((12, 37), v["sub"] + f"   |   off the city grid: {off_grid(field + frame + hand + a_roads + hill):.0f}%",
           font=f_sub, fill=(70, 70, 70))
    for text, q, col in (("Cable Hill (B)", (-300, -690), HILL_C), ("Mirador (A)", (150, -360), A_C),
                         ("Canyon (A)", (1560, -150), A_C), ("Liberty Ave", (820, 620), HAND),
                         ("Lantern Qtr old town", (430, 990), HAND)):
        x, y = px(q)
        d.text((x, y), text, font=f_lab, fill=col, stroke_width=3, stroke_fill=(255, 255, 255))
    x, y = 20, H + HEAD - 26
    d.line([(x, y), (x + 500 * S, y)], fill=(20, 20, 20), width=3)
    d.text((x, y - 18), "500 m", font=f_sub, fill=(20, 20, 20))
    d.text((W - 40, HEAD + 10), "N", font=f_title, fill=(20, 20, 20))
    d.line([(W - 32, HEAD + 60), (W - 32, HEAD + 36)], fill=(20, 20, 20), width=3)
    d.rectangle([0, 0, W - 1, H + HEAD - 1], outline=(120, 120, 120), width=1)
    return img


RING_SEEDS = [(x + (r + 9) * c, y + (r + 9) * s) for x, y, r in CIRCLES for c, s in ((1, 0), (-1, 0), (0, 1), (0, -1))]
LIB = sorted({tuple(NODES[i]) for e in EDGES if e[3] == "liberty" for i in e[:2]})
ALIGN = [MIRADOR, CANYON, LIB]
CORE = box(-110, -230, 1050, 1000)
VARIANTS = [
    {"title": "1 · Frame kept, field streets", "frame": True,
     "sub": "all arterials stay straight; streets inside each superblock follow the field",
     "grid_w": 1.0, "grid_s": 700, "coast_s": 380, "river_s": 140, "river_w": 1.4, "align": ALIGN,
     "passes": [(74, "street", [])]},
    {"title": "2 · Downtown frame, field outside", "frame": True, "core": CORE,
     "sub": "straight arterials in the core only; field arterials (orange) and streets elsewhere",
     "grid_w": 1.0, "grid_s": 650, "coast_s": 400, "river_s": 160, "river_w": 1.5, "align": ALIGN,
     "passes": [(270, "avenue", RING_SEEDS), (74, "street", [])]},
    {"title": "3 · Field everywhere, square centre", "frame": False,
     "sub": "every road from the field; a strong grid keeps downtown square",
     "grid_w": 1.0, "grid_s": 620, "coast_s": 420, "river_s": 170, "river_w": 1.5, "align": ALIGN,
     "passes": [(280, "avenue", RING_SEEDS), (74, "street", [])]},
    {"title": "4 · Field everywhere, organic", "frame": False,
     "sub": "weaker grid, stronger river and coast; Morrow Point on its own slant",
     "grid_w": 0.9, "grid_s": 400, "coast_s": 480, "river_s": 230, "river_w": 2.0, "align": ALIGN,
     "extra": [((380, 1720), 16, 280, 1.0)],
     "passes": [(300, "avenue", RING_SEEDS), (74, "street", [])]},
]

gap = 12
sheet = Image.new("RGB", (2 * W + 3 * gap, 2 * (H + HEAD) + 3 * gap), (255, 255, 255))
for i, v in enumerate(VARIANTS):
    sheet.paste(panel(v), (gap + (i % 2) * (W + gap), gap + (i // 2) * (H + HEAD + gap)))
sheet.save(OUT)
print("saved", OUT, sheet.size)
