"""The street field: the direction field the curved districts' streets follow.

Variation 2 of the A + B + C mix (reference/world/mix_options_sketch.png,
tools/mix_sketch.py), with variation 4's stronger pull along the water: a
tensor field summed from the downtown grid, the Gulf coast, the Morrow and
the hand-placed curved roads (Mirador, Canyon, Liberty). StreetPlan traces
streets along it at build time (street_plan.gd, _field_lines); this only
precomputes the field, which numpy does in a blink and GDScript would not.

Usage: python3 game/tools/street_field.py plan.json [game/data/street_field.json]
(plan.json from tests/plan_dump.gd; it gives the curved roads. The river
line comes from data/world_map.json.)"""
import base64, json, math, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
P = json.load(open(sys.argv[1]))
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "data", "street_field.json")
NODES = np.array(P["nodes"], float)

# Grid of the field, local metres; past the city's outline on every side.
X0, Y0, X1, Y1, CELL = -600.0, -1000.0, 2600.0, 2300.0, 20.0
# Variation 2, with 4's water pull (Sachin 2026-10-29).
GRID_AT, GRID_W, GRID_S = (450.0, 300.0), 1.0, 650.0
COAST_AT, COAST_ANGLE, COAST_W, COAST_S = (1950.0, 1350.0), -39.0, 1.6, 480.0
RIVER_W, RIVER_S = 2.0, 230.0
ALIGN_W, ALIGN_S = 1.2, 70.0


def road(name):
    """The polyline of a named road in the dump, its edges chained in order."""
    segs = [(tuple(NODES[a]), tuple(NODES[b])) for a, b, _, r in P["edges"] if r == name]
    if not segs:
        sys.exit("no road %s in the dump" % name)
    nxt = {}
    for a, b in segs:
        nxt.setdefault(a, []).append(b); nxt.setdefault(b, []).append(a)
    ends = [q for q, n in nxt.items() if len(n) == 1] or [segs[0][0]]
    line, prev, q = [ends[0]], None, ends[0]
    while True:
        step = [n for n in nxt[q] if n != prev]
        if not step:
            break
        prev, q = q, step[0]
        line.append(q)
        if len(line) > len(segs) + 1:
            break
    return line


def river():
    world = json.load(open(os.path.join(HERE, "..", "data", "world_map.json")))
    city = next(c for c in world["cities"] if c["id"] == "bellerive")
    o = city["demo_window"]["origin"]
    w = next(w for w in world["water"] if w["id"] == "morrow")
    return [(p[0] - o[0], p[1] - o[1]) for p in w["line"]]


gx = np.arange(X0, X1 + 0.1, CELL)
gy = np.arange(Y0, Y1 + 0.1, CELL)
X, Y = np.meshgrid(gx, gy)
T = np.zeros(X.shape + (2,))


def add(theta, w):
    T[..., 0] += w * np.cos(2 * theta)
    T[..., 1] += w * np.sin(2 * theta)


def gauss(c, s):
    return np.exp(-((X - c[0]) ** 2 + (Y - c[1]) ** 2) / (2 * s * s))


def along(line, sigma, w):
    pts = np.array(line, float)
    best = np.full(X.shape, 1e9)
    ang = np.zeros(X.shape)
    for a, b in zip(pts, pts[1:]):
        d = b - a
        L2 = float(d @ d)
        if L2 < 1e-6:
            continue
        t = np.clip(((X - a[0]) * d[0] + (Y - a[1]) * d[1]) / L2, 0, 1)
        dist = np.hypot(X - a[0] - t * d[0], Y - a[1] - t * d[1])
        m = dist < best
        best[m] = dist[m]
        ang[m] = math.atan2(d[1], d[0])
    add(ang, w * np.exp(-best ** 2 / (2 * sigma ** 2)))


add(np.zeros_like(X), GRID_W * gauss(GRID_AT, GRID_S))
add(np.full_like(X, math.radians(COAST_ANGLE)), COAST_W * gauss(COAST_AT, COAST_S))
along(river(), RIVER_S, RIVER_W)
for name in ("mirador", "canyon", "liberty"):
    along(road(name), ALIGN_S, ALIGN_W)
theta = (0.5 * np.arctan2(T[..., 1], T[..., 0])) % math.pi
q = np.round(theta / math.pi * 256).astype(np.int64) % 256
data = {"origin": [X0, Y0], "cell": CELL, "size": [len(gx), len(gy)],
        "note": "angle of the major direction, 0..pi as 0..255, rows north to south (tools/street_field.py)",
        "angle": base64.b64encode(q.astype(np.uint8).tobytes()).decode()}
with open(OUT, "w") as f:
    json.dump(data, f)
print("saved", OUT, data["size"], os.path.getsize(OUT), "bytes")
