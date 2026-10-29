"""world_map.json: the map routes re-laid over Mount Calder (mountain_lines.json,
tag "route") and the freight line's rail pass go back in; the bridge
landmarks of those routes are found again; the range's peaks and the cable
car are added. Idempotent. Run after mountain_plan.py re-plans a route:

    git show b6e2e21:game/data/world_map.json > /tmp/wm_orig.json
    cd game/tools && python3 mountain_world_map.py /tmp/wm_orig.json

(the map before the range, for each route's own direction and the freight
line's tail past the pass)."""
import json
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
# of the foot, where the shelf runs straight south along x -340, and turns
# west at FREIGHT_TURN over the Morrow, north of the Golden Flats Expressway
# (the river's crossing by the expressway is a bridge); from FREIGHT_WEST it
# runs west between County Roads 14 and 12, square to the Golden Flats grid's
# range roads (clear of Ridley Crossing and the airstrip). The docks spur carries on
# straight south from the branch (a turnout), down to the Morrow's east bank
# FREIGHT_BANK m off the river's centreline, over the expressway on land, and
# along the bank into the city's freight strip on the north bank (street_plan.gd
# FREIGHT_STRIP: water's edge 80 m, River Road 106 m) to Rampart Avenue; past
# Rampart the docks and Ironwharf take it in the quay street.
FREIGHT_BRANCH = 700.0
FREIGHT_TURN = (-340.0, -1000.0)
FREIGHT_WEST = (-1250.0, -1300.0)
SPUR_BEND = (-340.0, -960.0)
SPUR_ON_BANK = (-545.0, -615.0)
FREIGHT_BANK = 92.0
FREIGHT_END_X = 680.0
pl = LineString(rp[::-1])
head = [tuple(q) for q in substring(pl, 0.0, pl.length - FREIGHT_BRANCH + 50.0).coords]
assert abs(head[-1][0] - FREIGHT_TURN[0]) < 1.0, head[-1]
fr["line"] = W([o[0]] + head + [FREIGHT_TURN, FREIGHT_WEST] + o[7:])
changed.append("freight_line")
river = LineString([(x - OX, y - OY) for x, y in next(t for t in w["water"] if t["id"] == "morrow")["line"]])
bank = river.offset_curve(-FREIGHT_BANK, join_style=1)
if bank.distance(Point(450.0, 1125.0 - FREIGHT_BANK)) > 5.0:
    bank = river.offset_curve(FREIGHT_BANK, join_style=1)
a = bank.project(Point(SPUR_ON_BANK))
pts = [bank.interpolate(s).coords[0] for s in np.arange(a, bank.length, 20.0)]
pts = [p for p in pts if p[0] <= FREIGHT_END_X or p[1] < -100.0]
pts = [substring(pl, 0.0, pl.length - FREIGHT_BRANCH).coords[-1], SPUR_BEND] + pts
spur = next((r for r in w["routes"] if r["id"] == "freight_docks"), None)
if spur is None:
    spur = {"id": "freight_docks", "name": "Morrow Freight Line (docks spur)", "type": "rail", "phase": fr.get("phase", 3)}
    w["routes"].insert(w["routes"].index(fr) + 1, spur)
spur["line"] = W(simp(pts, 1.0))
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
