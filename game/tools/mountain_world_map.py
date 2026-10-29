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
from shapely.geometry import LineString

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
fr["line"] = W([o[0]] + rp[::-1] + o[5:])
changed.append("freight_line")

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
