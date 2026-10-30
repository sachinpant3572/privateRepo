"""world_map.json: the map routes re-laid over Mount Calder (mountain_lines.json,
tag "route") and the freight line's rail pass go back in; the bridge
landmarks of those routes are found again; the range's peaks and the cable
car are added. Idempotent. Run after mountain_plan.py re-plans a route:

    git show b6e2e21:game/data/world_map.json > /tmp/wm_orig.json
    cd game/tools && python3 mountain_world_map.py /tmp/wm_orig.json

(the map before the range, for each route's own direction and the freight
line's tail past the pass)."""
import json
import math
import sys
from pathlib import Path

import mountain as M
from shapely.geometry import LineString, Point
from shapely.ops import substring
import numpy as np

P = Path(__file__).resolve().parent.parent / "data" / "world_map.json"


def dumps(w, ascii_=False):
    out = ["{"]
    items = list(w.items())
    for k, (key, v) in enumerate(items):
        end = "," if k < len(items) - 1 else ""
        if isinstance(v, list) and v and isinstance(v[0], dict):
            out.append("  %s: [" % json.dumps(key))
            for j, it in enumerate(v):
                out.append("    " + json.dumps(it, ensure_ascii=ascii_) + ("," if j < len(v) - 1 else ""))
            out.append("  ]" + end)
        else:
            out.append("  %s: %s%s" % (json.dumps(key), json.dumps(v, ensure_ascii=ascii_), end))
    out.append("}")
    return "\n".join(out) + "\n"


ORIG = sys.argv[1]  # the world map at b6e2e21 (for the freight line's original tail)
OX, OY = 6150, 6650
w = json.load(open(P))
orig = json.load(open(ORIG))
lines = M.lines()
m = M.Mountain()


def W(pts):
    return [[round(x + OX, 1), round(y + OY, 1)] for x, y in pts]


def simp(pts, tol=0.6):
    return list(LineString(pts).simplify(tol).coords)


def round_corners(pts, radius, step=20.0):
    """Each corner of a polyline turned on a circular arc of `radius` (less
    where its legs are too short: a leg is shared between its two corners in
    proportion to what each wants), the line every `step` m or less."""
    p = [np.array(v, dtype=float) for v in pts]
    leg = [float(np.linalg.norm(b - a)) for a, b in zip(p, p[1:])]
    dirs = [(b - a) / n for a, b, n in zip(p, p[1:], leg)]
    turn = [math.acos(max(-1.0, min(1.0, float(u @ v)))) for u, v in zip(dirs, dirs[1:])]
    want = [radius * math.tan(t / 2.0) for t in turn]  # tangent length of corner i (at p[i + 1])
    tl = list(want)
    for i, n in enumerate(leg):
        lo = want[i - 1] if i > 0 else 0.0
        hi = want[i] if i < len(want) else 0.0
        if lo + hi > n:
            k = n / (lo + hi)
            if i > 0:
                tl[i - 1] = min(tl[i - 1], lo * k)
            if i < len(want):
                tl[i] = min(tl[i], hi * k)
    out = [p[0]]
    for i, t in enumerate(turn):
        b, u, v = p[i + 1], dirs[i], dirs[i + 1]
        if t < 1e-3:
            out.append(b)
            continue
        r = tl[i] / math.tan(t / 2.0)
        p0 = b - u * tl[i]
        side = 1.0 if u[0] * v[1] - u[1] * v[0] > 0.0 else -1.0
        nrm = side * np.array([-u[1], u[0]])
        k = max(2, int(math.ceil(r * t / step)))
        out += [p0 + r * (nrm * (1.0 - math.cos(f)) + u * math.sin(f)) for f in np.linspace(0.0, t, k + 1)]
    out.append(p[-1])
    line = LineString(out)
    n = max(1, int(math.ceil(line.length / step)))
    return [line.interpolate(line.length * q / n).coords[0] for q in range(n + 1)]


def min_radius(pts):
    """The tightest bend (m) by the circle through each three points in a row."""
    r = math.inf
    for a, b, c in zip(pts, pts[1:], pts[2:]):
        area = abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) / 2.0
        if area > 1e-6:
            r = min(r, math.dist(a, b) * math.dist(b, c) * math.dist(a, c) / (4.0 * area))
    return r


routes = {r["id"]: r for r in w["routes"]}
orig_routes = {r["id"]: r for r in orig["routes"]}
changed = []
for k, v in lines.items():
    if v["tag"] != "route":
        continue
    r = routes[k]
    full = [tuple(p) for p in v["keep_head"]] + [tuple(p) for p in v["pts"]]
    full = simp(full)
    o = [(x - OX, y - OY) for x, y in orig_routes[k]["line"]]
    # Keep the route's own direction.
    if abs(full[-1][0] - o[0][0]) + abs(full[-1][1] - o[0][1]) < abs(full[0][0] - o[0][0]) + abs(full[0][1] - o[0][1]):
        full = full[::-1]
    r["line"] = W(full)
    changed.append(k)

# The freight line: the rail pass from the city's north side over the range,
# then on as before.
fr = routes["freight_line"]
o = [(x - OX, y - OY) for x, y in orig_routes["freight_line"]["line"]]
rp = simp([tuple(p) for p in lines["rail_pass"]["pts"]], 1.0)
assert abs(rp[0][0] - o[4][0]) < 1 and abs(rp[0][1] - o[4][1]) < 1, (rp[0], o[4])
# The pass ends at its foot (-50, -850) heading east-southeast, toward the
# city; the line now goes west, so it leaves the pass FREIGHT_BRANCH m short
# of the foot, where the shelf starts its straight run south along x -340, and
# turns west on a FREIGHT_R arc over the Morrow, north of the Golden Flats
# Expressway (the river's crossing by the expressway is a bridge); it comes
# out heading west 70 m north of County Road 14 and runs on west between
# County Roads 14 and 12, square to the Golden Flats grid's range roads. At
# the north end the line leaves the pass's top straight on along its own
# heading (o[0] sat off it, a 50 degree kink on 16 m legs). The docks spur
# carries on straight south from the branch (a turnout), down to the Morrow's east bank
# FREIGHT_BANK m off the river's centreline, over the expressway on land, and
# along the bank into the city's freight strip on the north bank (street_plan.gd
# FREIGHT_STRIP: water's edge 80 m, River Road's kerb 96.8 m; the track runs
# down its middle) to Rampart Avenue; past
# Rampart the docks and Ironwharf take it in the quay street.
FREIGHT_BRANCH = 740.0
FREIGHT_R = 200.0
SPUR_BEND = (-340.0, -960.0)
SPUR_ON_BANK = (-545.0, -615.0)
FREIGHT_BANK = 88.0
FREIGHT_END_X = 680.0
SPUR_R = 200.0  # m: the bank's corners turn on arcs this wide (the offset has sharp corners)
SPUR_GENTLE = (-50.0, 1142.0)  # on the bank past the Morrow's sharp bend (river vertex (-50, 1234))
pl = LineString(rp[::-1])
head = [tuple(q) for q in substring(pl, 0.0, pl.length - FREIGHT_BRANCH).coords]
assert abs(head[-1][0] + 340.0) < 1.0, head[-1]
h = np.array(head[-1])
t = h - np.array(pl.interpolate(pl.length - FREIGHT_BRANCH - 20.0).coords[0])
t /= np.linalg.norm(t)
n = np.array([-t[1], t[0]])
assert n[0] < -0.99, n  # the shelf runs south here, so the arc turns west
# The arc turns until it heads straight at o[7], so the west leg leaves it
# without a corner.
def arc_at(f):
    return h + FREIGHT_R * (n * (1.0 - math.cos(f)) + t * math.sin(f))


def off_aim(f):
    d = np.array(o[7]) - arc_at(f)
    head_f = n * math.sin(f) + t * math.cos(f)
    return head_f[0] * d[1] - head_f[1] * d[0]


f_end = next(f for f in np.arange(0.01, math.pi, 0.001) if off_aim(f) * off_aim(0.0) <= 0.0)
arc = [tuple(arc_at(f)) for f in np.linspace(0.0, f_end, max(2, int(FREIGHT_R * f_end / 20.0)) + 1)[1:]]
top = np.array(pl.coords[0])
t0 = top - np.array(pl.interpolate(20.0).coords[0])
t0 /= np.linalg.norm(t0)
start = tuple(top + t0 * max(200.0, float(np.linalg.norm(top - np.array(o[0])))))
fr["line"] = W([start] + head + arc + o[7:])
changed.append("freight_line")
river = LineString([(x - OX, y - OY) for x, y in next(t for t in w["water"] if t["id"] == "morrow")["line"]])
bank = river.offset_curve(-FREIGHT_BANK, join_style=2)
if bank.distance(Point(450.0, 1125.0 - FREIGHT_BANK)) > 5.0:
    bank = river.offset_curve(FREIGHT_BANK, join_style=2)
a = bank.project(Point(SPUR_ON_BANK))
# The bank runs to where it reaches FREIGHT_END_X; up to the river's sharp
# bend at SPUR_GENTLE it is simplified coarsely (its short legs there leave
# no room for SPUR_R arcs), past it finely (a coarse chord there comes within
# the water's edge).
cut = bank.intersection(LineString([(FREIGHT_END_X, -100.0), (FREIGHT_END_X, 5000.0)]))
b = bank.project(cut if cut.geom_type == "Point" else min(cut.geoms, key=lambda q: q.y))
g = bank.project(Point(SPUR_GENTLE))
pts = list(substring(bank, a, g).simplify(15.0).coords) + list(substring(bank, g, b).simplify(1.0).coords)[1:]
pts = round_corners([tuple(h), SPUR_BEND] + pts, SPUR_R)
spur = next((r for r in w["routes"] if r["id"] == "freight_docks"), None)
if spur is None:
    spur = {"id": "freight_docks", "name": "Morrow Freight Line (docks spur)", "type": "rail", "phase": fr.get("phase", 3)}
    w["routes"].insert(w["routes"].index(fr) + 1, spur)
spur["line"] = W(pts)
print("freight spur: min radius %.0f m" % min_radius(pts))
assert min_radius(pts) >= 170.0
routes["freight_docks"] = spur
changed.append("freight_docks")

# Bridge landmarks of the changed routes, found again where each crosses a river or creek.
water = [(wt["id"], wt["name"], LineString([(x - OX, y - OY) for x, y in wt["line"]]))
         for wt in w["water"] if "line" in wt]
w["landmarks"] = [l for l in w["landmarks"] if not (l.get("type") == "bridge" and l.get("route") in changed)]
for k in changed:
    r = routes[k]
    line = LineString([(x - OX, y - OY) for x, y in r["line"]])
    for wid, wname, wl in water:
        hit = line.intersection(wl)
        pts = [hit] if hit.geom_type == "Point" else [g for g in getattr(hit, "geoms", []) if g.geom_type == "Point"]
        for n, q in enumerate(pts):
            lid = "%s_%s_bridge" % (k, wid) + ("" if n == 0 else "_%d" % (n + 1))
            w["landmarks"].append({"id": lid, "name": "%s bridge" % wname, "type": "bridge",
                                   "pos": [round(q.x + OX), round(q.y + OY)], "phase": r.get("phase", 2), "route": k,
                                   "minor": True, "detail": True})

# Grade separation on the Solvera Line (high speed: no level crossings). It
# flies over the freight lines (the newer line on its own viaduct), and every
# road, track or trail goes over it. Not counted: where two rail lines share a
# vertex (Sable Junction's station: a junction), where a road ends on the line,
# and the rail pass on the range (mountain.py's own bridges and tunnels).
SEPARATE = {"highway": "overpass", "road": "overpass", "lane": "overpass", "track": "overpass",
            "trail": "footbridge", "rail": "flyover"}
w["landmarks"] = [l for l in w["landmarks"] if l.get("type") not in ("flyover", "overpass", "footbridge")]
sol = routes["solvera_line"]
sol_line = LineString(sol["line"])
rail_pass = LineString([(x + OX, y + OY) for x, y in lines["rail_pass"]["pts"]])
for o in w["routes"]:
    kind = SEPARATE.get(o["type"])
    if o["id"] == "solvera_line" or kind is None:
        continue
    ol = LineString(o["line"])
    hit = sol_line.intersection(ol)
    done_at = []
    for q in [hit] if hit.geom_type == "Point" else [g for g in getattr(hit, "geoms", []) if g.geom_type == "Point"]:
        if kind == "flyover" and any(math.dist(v, (q.x, q.y)) < 1.0 for v in sol["line"]):
            continue  # a junction
        if min(math.dist(o["line"][0], (q.x, q.y)), math.dist(o["line"][-1], (q.x, q.y))) < 1.0:
            continue  # the road ends on the line
        if rail_pass.distance(q) < 30.0 or any(math.dist(d, (q.x, q.y)) < 30.0 for d in done_at):
            continue
        done_at.append((q.x, q.y))
        over, under = ("solvera_line", o["id"]) if kind == "flyover" else (o["id"], "solvera_line")
        names = {rr["id"]: rr["name"] for rr in w["routes"]}
        w["landmarks"].append({"id": "%s_over_%s_%d" % (over, under, round(q.x)), "type": kind,
                               "name": "%s %s" % (names[over].split(" (")[0], kind),
                               "pos": [round(q.x), round(q.y)], "over": over, "under": under,
                               "phase": max(int(sol.get("phase", 2)), int(o.get("phase", 2))),
                               "minor": True, "detail": True})

# The range's peaks.
NAMES = {"mount_calder": "Mount Calder", "raven_peak": "Raven Peak", "east_peak": "Eastgate Peak",
         "north_knob": "North Knob", "hawk_peak": "Hawk Peak", "pine_knob": "Pine Knob", "calder_knob": "Calder Knob",
         "larkspur_knob": "Larkspur Knob"}
ids = set(NAMES)
w["landmarks"] = [l for l in w["landmarks"] if l["id"] not in ids and l["id"] != "calder_summit"]
for k, (x, y) in M.PEAKS.items():
    w["landmarks"].append({"id": k, "name": NAMES[k], "type": "peak", "pos": [round(x + OX), round(y + OY)],
                           "phase": 2, "elev": int(round(float(m.raw_at((x, y))))), "detail": True})
sx, sy = M.SUMMIT_SITES["deck"][:2]
w["landmarks"].append({"id": "calder_summit", "name": "Mount Calder summit (restaurant, helipad, viewing deck)",
                       "type": "viewpoint", "pos": [round(sx + OX), round(sy + OY)], "phase": 2})
# The cable car.
w["routes"] = [r for r in w["routes"] if r["id"] != "calder_cable"]
w["routes"].append({"id": "calder_cable", "name": "Calder Aerial Tramway", "type": "cable", "phase": 2,
                    "line": W([M.CABLE["bottom"], M.CABLE["mid"], M.CABLE["top"]])})
open(P, "w").write(dumps(w))
print("routes", changed, "landmarks", len(w["landmarks"]))
