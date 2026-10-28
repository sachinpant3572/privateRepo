"""Land value and household tiers for the country's homes (HANDOFF-wealth.md).

Called by build_country.py once every lot is laid out. It moves nothing and
draws nothing from the generator's rng: each home lot gets a land value V in
0..1 and a tier, T0 (the poorest) to T5 (owners and CEOs), that the country
kit shows through upkeep, cars, fences and pools.
"""

import collections
import hashlib
import math

from shapely.geometry import LineString, Point, box
from shapely.ops import unary_union

TIER_NAMES = ["poorest", "low wage", "regular employees", "professionals", "business owners", "owners and CEOs"]

# Base value of the ground each zone stands on (W-1). Unknown zones take
# BASE_DEFAULT.
ZONE_BASE = {
    "": 0.85,  # the Hale Estate
    "heights": 0.74, "mountain": 0.66, "verdant_hills": 0.7, "beach_town": 0.58, "shore": 0.47,
    "eastside": 0.4, "wheaton": 0.36, "fringe": 0.34, "golden_flats": 0.32, "larkspur": 0.26,
    "bayou_town": 0.17, "cypress_bend": 0.14, "saltgrass": 0.12, "gator_point": 0.1,
}
BASE_DEFAULT = 0.3

# Each home kind's tiers (lowest, highest).
TIER_RANGE = {
    "shack": (0, 1), "trailer_home": (0, 1), "stilt_house": (0, 2),
    "garden_apartments": (1, 2), "rowhouse_row": (1, 3), "house": (1, 4), "cape_house": (2, 3),
    "farmhouse_small": (1, 2), "farmhouse": (2, 3), "ranch_house": (2, 3), "adobe_farmhouse": (2, 3),
    "farmhouse_big": (3, 4), "condo_tower": (3, 4), "mansion": (4, 5),
}
# Households a lot holds, for land per household.
UNITS = {"garden_apartments": 12, "rowhouse_row": 4, "condo_tower": 36}
TOWERS = ("condo_tower",)

# Pluses and minuses (value, reach in metres; linear to 0 at the reach).
COAST = (0.18, 400.0)
LAKE = (0.08, 250.0)
RIVER = (0.04, 200.0)
DOWNTOWN = (0.1, 3000.0)
HEIGHT = (0.12, 120.0)  # full bonus at 120 m up
FAST_ROAD = (-0.12, 150.0)
RAIL = (-0.1, 120.0)
INDUSTRY = (-0.12, 500.0)
WORKS = (-0.08, 200.0)  # the truck stop, the airstrip, grain elevators
FLOOD = (-0.1, 100.0)
WORKS_KINDS = ("truck_stop", "airstrip_hangar", "grain_elevators", "aurum_hangar")
# Pocket noise: whole streets lean richer or poorer together, then each lot a little.
POCKET = 160.0
POCKET_AMP = 0.55
LOT_AMP = 0.25


def _hash01(*key):
    h = hashlib.blake2b(repr(key).encode(), digest_size=8).digest()
    return int.from_bytes(h, "little") / 2.0 ** 64


def _pocket(x, y):
    """Smooth value noise in -1..1 on a POCKET grid."""
    u, v = x / POCKET, y / POCKET
    i, j = math.floor(u), math.floor(v)
    fu, fv = u - i, v - j
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    n = [[_hash01("pocket", i + a, j + b) for a in (0, 1)] for b in (0, 1)]
    top = n[0][0] * (1 - fu) + n[0][1] * fu
    bot = n[1][0] * (1 - fu) + n[1][1] * fu
    return (top * (1 - fv) + bot * fv) * 2.0 - 1.0


def _near(geom, p, term):
    if geom is None or geom.is_empty:
        return 0.0
    amount, reach = term
    d = geom.distance(p)
    return amount * max(0.0, 1.0 - d / reach)


def tier_of(v, kind, x, y):
    lo, hi = TIER_RANGE[kind]
    t = v * 6.0 - 0.5 + POCKET_AMP * _pocket(x, y) + LOT_AMP * (_hash01("lot", round(x, 1), round(y, 1)) * 2.0 - 1.0)
    return max(lo, min(hi, int(round(t))))


class Wealth:
    def __init__(self, country):
        c = self.c = country
        w = c.world
        water = {"coast": [], "lake": [], "river": [], "flood": []}
        for wt in w["water"]:
            if "polygon" in wt:
                g = LineString(c.L(wt["polygon"] + wt["polygon"][:1]))
            else:
                g = LineString(c.L(wt["line"])).buffer(wt.get("width", 10.0) * 0.5)
            if wt["type"] in ("ocean", "bay"):
                water["coast"].append(g)
            elif wt["type"] == "lake":
                water["lake"].append(g)
            elif wt["type"] == "river":
                water["river"].append(g)
            elif wt["id"] in ("black_bayou", "turtle_slough"):
                water["flood"].append(g)
            else:
                water["lake"].append(g)  # a creek: a small view
        self.water = {k: unary_union(v) if v else None for k, v in water.items()}
        fast = [LineString(pc["pts"]) for pc in c.pieces if pc["cls"] in ("freeway", "highway")]
        self.fast = unary_union(fast) if fast else None
        self.rails = unary_union([r[0] for r in c.rails]) if c.rails else None
        city = next(x for x in w["cities"] if x["id"] == "bellerive")
        rects = {d["id"]: d["rect"] for d in city["districts"]}

        def local_box(r):
            return box(r[0] - c.origin[0], r[1] - c.origin[1], r[0] + r[2] - c.origin[0], r[1] + r[3] - c.origin[1])

        self.industry = local_box(rects["ironwharf"])
        self.downtown = local_box(rects["gilt_district"]).centroid
        works = [Point(l["x"], l["y"]) for l in c.lots if l["kind"] in WORKS_KINDS]
        self.works = unary_union(works) if works else None

    def value(self, l):
        p = Point(l["x"], l["y"])
        v = ZONE_BASE.get(l["zone"], BASE_DEFAULT)
        v += _near(self.water["coast"], p, COAST)
        v += max(_near(self.water["lake"], p, LAKE), _near(self.water["river"], p, RIVER))
        v += DOWNTOWN[0] * max(0.0, 1.0 - p.distance(self.downtown) / DOWNTOWN[1])
        v += HEIGHT[0] * min(1.0, self.c.mtn.height((l["x"], l["y"])) / HEIGHT[1])
        v += _near(self.fast, p, FAST_ROAD)
        v += _near(self.rails, p, RAIL)
        v += _near(self.industry, p, INDUSTRY)
        v += _near(self.works, p, WORKS)
        v += _near(self.water["flood"], p, FLOOD)
        return max(0.0, min(1.0, v))

    def assign(self):
        """Sets each lot's "value" and "tier" (-1 and 0 for lots no one lives in)."""
        c = self.c
        for l in c.lots:
            if l["kind"] not in TIER_RANGE:
                l["tier"], l["value"] = -1, 0.0
                continue
            v = self.value(l)
            t = tier_of(v, l["kind"], l["x"], l["y"])
            if l["plot"] >= 0 and c.plots[l["plot"]]["type"] == "estate":
                t = 5  # gated grounds: the top of the ladder
            l["tier"], l["value"] = t, round(v, 3)

    def land(self, l):
        """Private ground per household (m²): an estate's or a parcel's area
        shared by its homes, else the home's own lot shared by its units. A
        cluster's yard is common ground, so a cluster home counts its own lot."""
        c = self.c
        if l["plot"] >= 0:
            q = c.plots[l["plot"]]
            if q["type"] in ("estate", "parcel"):
                homes = sum(1 for m in c.lots if m["plot"] == l["plot"] and m["kind"] in TIER_RANGE) or 1
                return q["w"] * q["d"] / homes
        return l["w"] * l["d"] / UNITS.get(l["kind"], 1)

    def stats(self):
        """Per tier: homes, mean value, mean land per household; and homes per zone and tier."""
        by = collections.defaultdict(list)
        zones = collections.defaultdict(collections.Counter)
        for l in self.c.lots:
            if l.get("tier", -1) < 0:
                continue
            by[l["tier"]].append(l)
            zones[l["zone"] or "estate"][l["tier"]] += 1
        rows = {}
        for t in range(6):
            ls = by.get(t, [])
            # Towers are measured by their floors, not their ground.
            low = [l for l in ls if l["kind"] not in TOWERS]
            if ls:
                rows[t] = (len(ls), sum(l["value"] for l in ls) / len(ls),
                           sum(self.land(l) for l in low) / max(1, len(low)))
        return rows, zones

    def report(self):
        rows, zones = self.stats()
        print("homes by tier (homes, mean value, land per household m2):")
        for t, (n, v, a) in rows.items():
            print(f"  T{t} {TIER_NAMES[t]}: {n}, {v:.2f}, {a:.0f}")
        print("homes per zone and tier:", {z: [cnt.get(t, 0) for t in range(6)] for z, cnt in sorted(zones.items())})
        bad = []
        if len(rows) < 6:
            bad.append("missing tiers %s" % [t for t in range(6) if t not in rows])
        ts = sorted(rows)
        for a, b in zip(ts, ts[1:]):
            # Estates (T5) trade the dearest ground for the most of it: wine
            # country grounds stand on cheaper land than a Heights house, so
            # T5 need only beat T3 on value, and must beat everyone on land.
            if rows[b][1] <= rows[a if b < 5 else 3][1]:
                bad.append(f"value T{b} <= T{a if b < 5 else 3}")
            if rows[b][2] <= rows[a][2]:
                bad.append(f"land T{b} <= T{a}")
        print("wealth ladder problems:", len(bad), bad)
        return bad
