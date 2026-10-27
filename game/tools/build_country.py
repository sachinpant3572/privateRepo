#!/usr/bin/env python3
"""Builds the country around Bellerive (phase 2) into data/country.json.

Everything outside the street plan's bounds that the game streams in tiles
(scripts/country.gd): the play area, ground by zone, the road graph with its
polylines and bridges, walls along water and the play area's edge, storm
barricades where roads leave it, suburb and town lots, and links from the
country roads to the street plan's frame junctions.

Needs shapely (pip install shapely) and a plan dump of the current street
plan (the country's suburb streets carry on from its edge junctions):

    cd game
    godot --headless -s res://tests/plan_dump.gd -- /tmp/plan.json
    python3 tools/build_country.py /tmp/plan.json

All output is in local metres: world-map metres minus Bellerive's
demo_window origin (game x = local x, game z = local y), like the city.
"""

import json
import math
import random
import sys
from pathlib import Path

from shapely import constrained_delaunay_triangles
from shapely.geometry import LineString, MultiLineString, Point, Polygon, box
from shapely.ops import nearest_points, unary_union
from shapely.prepared import prep
from shapely.strtree import STRtree

ROOT = Path(__file__).resolve().parent.parent
WORLD = ROOT / "data" / "world_map.json"
OUT = ROOT / "data" / "country.json"

TILE = 100.0
# The street plan's bounds (city.gd: window grown by MARGIN) and its frame
# street, 4 m inside them.
MARGIN = 110.0
FRAME_IN = 4.0
# Ground beyond the play area, so the edge is a fence, not the end of the world.
BEYOND = 450.0

# Road classes: width (m), traffic cruise speed (m/s), drivable by traffic,
# corner radius for the world map's polylines, resample step.
CLASSES = {
    "highway": {"w": 16.0, "speed": 22.0, "graph": True, "r": 260.0, "step": 24.0, "prio": 6},
    "avenue": {"w": 14.0, "speed": 15.0, "graph": True, "r": 60.0, "step": 20.0, "prio": 5},
    "road": {"w": 10.0, "speed": 17.0, "graph": True, "r": 140.0, "step": 20.0, "prio": 4},
    "street": {"w": 10.0, "speed": 12.0, "graph": True, "r": 20.0, "step": 20.0, "prio": 3},
    "lane": {"w": 7.0, "speed": 12.0, "graph": True, "r": 60.0, "step": 14.0, "prio": 2},
    "track": {"w": 6.0, "speed": 9.0, "graph": True, "r": 40.0, "step": 14.0, "prio": 1},
    "trail": {"w": 3.5, "speed": 6.0, "graph": False, "r": 25.0, "step": 12.0, "prio": 0},
}
CLASS_NAMES = list(CLASSES)
RAIL_TYPES = {"rail": "rail", "metro": "metro", "mover": "metro", "streetcar": "streetcar"}

# Lot sizes (along the street, deep) by kind; country_kit.gd builds them.
LOT = {
    "farmhouse": (16, 14), "barn": (18, 24), "silos": (12, 12), "machine_shed": (20, 14),
    "trailer_home": (9, 18), "shack": (8, 9), "stilt_house": (11, 11), "water_tower": (10, 10),
    "windpump": (6, 6), "gas_station": (30, 26), "diner": (20, 16), "motel": (40, 26),
    "general_store": (16, 14), "truck_stop": (60, 45), "garage": (20, 18), "town_hall": (22, 18),
    "bar": (16, 14), "shopfront": (10, 14), "house": (14, 14), "mansion": (32, 28),
    "garden_apartments": (30, 18), "strip_mall": (50, 24), "deco_hotel": (30, 22),
    "condo_tower": (26, 26), "beach_bar": (12, 10), "lifeguard_tower": (4, 4),
    "grain_elevators": (40, 30), "hollis_farm": (60, 50), "larkspur_vineyard": (40, 34),
    "gator_farm": (46, 40), "moonshine_still": (16, 14), "bellerive_general": (70, 50),
    "bus_terminal": (60, 40), "seaplane_base": (34, 40), "cruise_terminal": (90, 40),
    "torque_tone": (34, 26), "aurum_hangar": (50, 40), "police_station": (22, 16),
    "county_hospital": (36, 26), "airboat_dock": (18, 24), "airstrip_hangar": (26, 22),
}
KINDS = list(LOT)

# Map landmarks built as country lots: landmark id -> kit kind.
LANDMARK_KIND = {
    "hollis_farm": "hollis_farm", "grain_elevators": "grain_elevators",
    "larkspur_vineyard": "larkspur_vineyard", "gator_farm": "gator_farm",
    "moonshine_still": "moonshine_still", "bellerive_general": "bellerive_general",
    "bellerive_bus_terminal": "bus_terminal", "seaplane_base": "seaplane_base",
    "cruise_terminal": "cruise_terminal", "torque_tone_bellerive": "torque_tone",
    "aurum_hangar": "aurum_hangar", "hale_estate": "mansion", "krewe_hall": "bar",
    "glades_airboats": "airboat_dock", "flats_airstrip": "airstrip_hangar",
    "ridley_diner": "diner", "county_hospital": "county_hospital",
    "state_police_flats": "police_station", "deco_row": "deco_hotel",
}

# Suburb zones round the street plan (local metres) and what they hold.
SUBURB_STYLE = {
    "heights": {"house": 2, "mansion": 3},
    "bayou_town": {"stilt_house": 4, "shack": 2, "house": 2, "bar": 1},
    "fringe": {"garden_apartments": 2, "strip_mall": 1, "gas_station": 1, "garage": 1, "house": 2},
    "eastside": {"house": 5, "garden_apartments": 2, "strip_mall": 1, "gas_station": 1, "diner": 1},
    "beach_town": {"deco_hotel": 5, "condo_tower": 2, "beach_bar": 1, "shopfront": 1},
    "shore": {"house": 5, "garden_apartments": 2, "beach_bar": 1, "diner": 1},
    "town": {"shopfront": 4, "house": 4, "diner": 1, "general_store": 1, "bar": 1, "gas_station": 1, "garage": 1},
    "village": {"house": 5, "general_store": 1, "bar": 1, "trailer_home": 2},
    "bayou_village": {"stilt_house": 4, "shack": 3, "bar": 1, "general_store": 1},
}

# Ground zones, in drawing order; the game colours them (country_tiles.gd).
ZONES = ["land", "farmland", "bayou", "hills", "heights", "bayou_town", "fringe", "eastside",
         "beach_town", "shore", "town", "sand", "far_desert", "far_mountains", "far_forest",
         "far_lakeside", "far_parkland", "far_military", "far_land"]


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    plan = json.loads(Path(sys.argv[1]).read_text())
    world = json.loads(WORLD.read_text())
    gen = Country(world, plan)
    gen.run()
    data = gen.export()
    OUT.write_text(json.dumps(data, separators=(",", ":")))
    print("country.json: %d KB, %d nodes, %d edges, %d roads, %d lots, %d tiles, %d walls, %d barricades, %d links"
          % (OUT.stat().st_size // 1024, len(data["nodes"]), len(data["edges"]), len(data["roads"]),
             len(data["lots"]), len(data["tiles"]), len(data["walls"]), len(data["barricades"]),
             len(data["links"])))


# --- Geometry helpers ------------------------------------------------------------

def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def densify(pts, step):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        n = max(1, math.ceil(dist(a, b) / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def fillet(pts, radius, step):
    """Rounds each corner of a polyline with a quadratic curve."""
    if len(pts) < 3:
        return densify(pts, step)
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = pts[i - 1], pts[i], pts[i + 1]
        la, lc = dist(a, b), dist(b, c)
        if la < 1e-6 or lc < 1e-6:
            continue
        d = min(radius, 0.45 * la, 0.45 * lc)
        p0 = (b[0] + (a[0] - b[0]) / la * d, b[1] + (a[1] - b[1]) / la * d)
        p1 = (b[0] + (c[0] - b[0]) / lc * d, b[1] + (c[1] - b[1]) / lc * d)
        n = max(2, int(d / 6))
        for k in range(n + 1):
            t = k / n
            out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * b[0] + t * t * p1[0],
                        (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * b[1] + t * t * p1[1]))
    out.append(pts[-1])
    return densify(out, step)


def resample(line: LineString, step: float):
    n = max(1, math.ceil(line.length / step))
    return [line.interpolate(line.length * k / n).coords[0] for k in range(n + 1)]


def lines_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "LineString":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(lines_of(g))
        return out
    return []


def polys_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(polys_of(g))
        return out
    return []


def bezier(p0, c0, c1, p1, step):
    pts = []
    n = max(4, int((dist(p0, c0) + dist(c0, c1) + dist(c1, p1)) / step))
    for k in range(n + 1):
        t = k / n
        u = 1 - t
        pts.append((u ** 3 * p0[0] + 3 * u * u * t * c0[0] + 3 * u * t * t * c1[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c0[1] + 3 * u * t * t * c1[1] + t ** 3 * p1[1]))
    return pts


def lot_poly(x, y, yaw, w, d):
    # Lot frame: x along the street, -z towards it. yaw as Godot's
    # Basis(UP, yaw): local x -> (cos, -sin), local z -> (sin, cos).
    c, s = math.cos(yaw), math.sin(yaw)
    pts = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        pts.append((x + lx * c + lz * s, y - lx * s + lz * c))
    return Polygon(pts)


def yaw_facing(nx, ny):
    """Yaw of a lot whose street lies in direction -(nx, ny) from it... i.e.
    whose front (-Z) points along (-nx, -ny)."""
    return math.atan2(nx, ny)


class Country:
    def __init__(self, world, plan):
        self.world = world
        self.plan = plan
        city = next(c for c in world["cities"] if c["id"] == "bellerive")
        win = city["demo_window"]
        self.origin = (win["origin"][0], win["origin"][1])
        size = (win["blocks"][0] * win["pitch"], win["blocks"][1] * win["pitch"])
        self.P = box(-MARGIN, -MARGIN, size[0] + MARGIN, size[1] + MARGIN)
        self.frame = (-MARGIN + FRAME_IN, -MARGIN + FRAME_IN, size[0] + MARGIN - FRAME_IN, size[1] + MARGIN - FRAME_IN)
        r = city["rect"]
        self.city_rect = box(r[0] - self.origin[0], r[1] - self.origin[1], r[0] + r[2] - self.origin[0], r[1] + r[3] - self.origin[1])
        self.rng = random.Random(1234)
        self.sources = []  # [LineString, cls, name, kind] drivable or trail
        self.render_only = []  # roads beyond the play area: [LineString, cls]
        self.rails = []  # [LineString, kind]
        self.lots = []  # dicts
        self.lot_polys = []
        self.barricades = []
        self.paths = []  # driveways (render only)
        self.zones = []  # (name, polygon)
        self.town_zones = []
        self.links = []

    def L(self, pts):
        return [(x - self.origin[0], y - self.origin[1]) for x, y in pts]

    # --- Areas ------------------------------------------------------------------

    def areas(self):
        w = self.world
        regs = [Polygon(self.L(r["polygon"])) for r in w["regions"] if r.get("phase") == 2]
        # The shore between the city rect and the Gulf belongs to the city.
        shore = box(self.city_rect.bounds[0] - 100, self.P.bounds[3] - 20, self.city_rect.bounds[2] + 200, self.P.bounds[3] + 700)
        a = unary_union(regs + [self.city_rect, self.P, shore]).buffer(300).buffer(-300)
        a = Polygon(a.exterior)
        world_box = box(-self.origin[0], -self.origin[1], w["size"][0] - self.origin[0], w["size"][1] - self.origin[1])
        water = []
        for wt in w["water"]:
            if "polygon" in wt:
                water.append(Polygon(self.L(wt["polygon"])))
            elif wt["type"] in ("river", "creek"):
                water.append(LineString(self.L(wt["line"])).buffer(wt["width"] * 0.5, cap_style="flat", join_style="round"))
        self.gulf = Polygon(self.L(w["water"][0]["polygon"]))
        self.water = unary_union(water)
        self.A = a.difference(self.gulf)
        self.outer = self.A.buffer(BEYOND).intersection(world_box)
        self.land = self.outer.difference(self.water).difference(self.P)
        self.play_land = self.A.difference(self.water).difference(self.P)
        self.play_land_prep = prep(self.play_land.buffer(-0.5))
        self.water_prep = prep(self.water)
        self.A_prep = prep(self.A)
        self.coast = LineString(self.L(w["water"][0]["polygon"]))

    # --- Roads ------------------------------------------------------------------

    def add(self, pts, cls, name, kind="route"):
        if len(pts) < 2:
            return
        line = LineString(pts)
        if line.length < 1.0:
            return
        self.sources.append([line, cls, name, kind])

    def routes(self):
        clip = self.A.difference(self.P)
        for rt in self.world["routes"]:
            t = rt["type"]
            pts = self.L(rt["line"])
            if t in RAIL_TYPES:
                line = LineString(fillet(pts, 300.0, 20.0))
                for piece in lines_of(line.intersection(self.outer.difference(self.P))):
                    self.rails.append([piece, RAIL_TYPES[t], rt["name"], rt.get("phase", 1)])
                continue
            if t not in CLASSES:
                continue
            c = CLASSES[t]
            line = LineString(fillet(pts, c["r"], 8.0))
            for piece in lines_of(line.intersection(clip)):
                piece = self._to_frame(piece, t)
                self.add(list(piece.coords), t, rt["name"])
            # Past the play area: drawn, not driven; a storm barricade where
            # the road leaves it.
            for piece in lines_of(line.intersection(self.outer.difference(self.A).difference(self.P))):
                if piece.length > 5.0:
                    self.render_only.append([piece, t])
            for hit in self._points(line.intersection(self.A.exterior)):
                if self.water_prep.contains(Point(hit).buffer(2.0)) or self.gulf.distance(Point(hit)) < 30.0:
                    continue
                self._barricade(line, hit, c["w"])

    @staticmethod
    def _points(geom):
        if geom.is_empty:
            return []
        if geom.geom_type == "Point":
            return [geom.coords[0]]
        out = []
        for g in getattr(geom, "geoms", []):
            if g.geom_type == "Point":
                out.append(g.coords[0])
        return out

    def _barricade(self, line, hit, width):
        s = line.project(Point(hit))
        a = line.interpolate(max(0.0, s - 2.0)).coords[0]
        b = line.interpolate(min(line.length, s + 2.0)).coords[0]
        d = (b[0] - a[0], b[1] - a[1])
        n = math.hypot(*d) or 1.0
        d = (d[0] / n, d[1] / n)
        # Step back inside the play area.
        for sgn in (1.0, -1.0):
            p = (hit[0] - d[0] * sgn * 8.0, hit[1] - d[1] * sgn * 8.0)
            if self.A_prep.contains(Point(p)):
                self.barricades.append([round(p[0], 2), round(p[1], 2), round(d[0], 4), round(d[1], 4), width])
                return

    def frame_junctions(self, side):
        """Plan junctions on one side of the frame street that a street
        reaches from inside: [(pos along the side, node id, best class)]."""
        nodes = self.plan["nodes"]
        x0, y0, x1, y1 = self.frame
        widths = {"boulevard": 24, "avenue": 15, "street": 11, "quarter": 9, "lane": 7}
        best = {}
        for a, b, cls, road in self.plan["edges"]:
            if road == "frame":
                continue
            for n in (a, b):
                x, y = nodes[n]
                on = {"w": abs(x - x0) < 0.5, "e": abs(x - x1) < 0.5, "n": abs(y - y0) < 0.5, "s": abs(y - y1) < 0.5}[side]
                corner = (abs(x - x0) < 0.5 or abs(x - x1) < 0.5) and (abs(y - y0) < 0.5 or abs(y - y1) < 0.5)
                if on and not corner:
                    best[n] = max(best.get(n, 0), widths.get(cls, 0))
        out = []
        for n, w in best.items():
            x, y = nodes[n]
            out.append((y if side in "we" else x, n, w))
        out.sort()
        return out

    def _edge_point(self, n, side):
        """Where junction n's street leaves the plan bounds."""
        x, y = self.plan["nodes"][n]
        bx0, by0, bx1, by1 = self.P.bounds
        return {"w": (bx0, y), "e": (bx1, y), "n": (x, by0), "s": (x, by1)}[side]

    @staticmethod
    def _outward(side):
        return {"w": (-1.0, 0.0), "e": (1.0, 0.0), "n": (0.0, -1.0), "s": (0.0, 1.0)}[side]

    def _side_of(self, p):
        bx0, by0, bx1, by1 = self.P.bounds
        d = {"w": abs(p[0] - bx0), "e": abs(p[0] - bx1), "n": abs(p[1] - by0), "s": abs(p[1] - by1)}
        return min(d, key=d.get)

    def _to_frame(self, piece: LineString, cls):
        """A route piece that ends on the plan bounds is bent in to meet the
        nearest big frame junction square on."""
        pts = list(piece.coords)
        for end in (0, -1):
            p = pts[end]
            if self.P.exterior.distance(Point(p)) > 1.0:
                continue
            side = self._side_of(p)
            along = p[1] if side in "we" else p[0]
            options = self.frame_junctions(side)
            if not options:
                continue
            n = min(options, key=lambda o: abs(o[0] - along) - o[2] * 3.0)[1]
            e = self._edge_point(n, side)
            o = self._outward(side)
            line = LineString(pts if end == -1 else pts[::-1])
            keep = max(0.0, line.length - 160.0)
            head = list(line.coords) if keep <= 0 else [line.interpolate(k).coords[0] for k in _steps(0.0, keep, 8.0)]
            q = head[-1]
            if len(head) > 1:
                t = (q[0] - head[-2][0], q[1] - head[-2][1])
                tl = math.hypot(*t) or 1.0
                t = (t[0] / tl, t[1] / tl)
            else:
                t = (-o[0], -o[1])
            span = max(30.0, dist(q, e) * 0.4)
            tail = bezier(q, (q[0] + t[0] * span, q[1] + t[1] * span), (e[0] + o[0] * span, e[1] + o[1] * span), e, 6.0)
            new = head[:-1] + tail
            pts = new if end == -1 else new[::-1]
            self.links.append({"pos": e, "plan_node": n})
        return LineString(pts)

    def suburbs(self):
        bx0, by0, bx1, by1 = self.P.bounds
        cx0, cy0, cx1, cy1 = self.city_rect.bounds
        ring = 220.0
        west = cx0  # -600
        north = by0 - ring
        east = cx1 + 50.0
        land = self.play_land
        # Brisa Beach: a band along the Gulf east of the river mouth.
        coast_e = LineString(self.L([[7600, 8650], [8400, 8000], [8900, 7300]]))
        brisa_band = coast_e.buffer(400.0, cap_style="flat").intersection(box(1450, -400, east, 2100))
        shore_band = box(west - 200, by1, 1500, 2100)
        zones = [
            ("beach_town", brisa_band),
            ("shore", shore_band.difference(brisa_band)),
            ("heights", box(west, north, bx0, 560)),
            ("bayou_town", box(west, 560, bx0, by1)),
            ("fringe", box(bx0, north, bx1, by0)),
            ("eastside", box(bx1, north, east, by1 + 600).difference(brisa_band)),
        ]
        taken = Polygon()
        for name, poly in zones:
            poly = poly.difference(taken).intersection(land)
            taken = taken.union(poly)
            self.zones.append((name, poly))
        zone = dict(self.zones)
        # Streets carrying on from the frame junctions, kept 70 m apart.
        for side, zname, depth in (("w", ["heights", "bayou_town"], bx0 - west), ("n", ["fringe"], ring),
                                   ("e", ["eastside"], east - bx1), ("s", ["shore"], 520.0)):
            area = unary_union([zone[z] for z in zname]).difference(self.coast.buffer(60.0))
            last = -1e9
            o = self._outward(side)
            for along, n, w in self.frame_junctions(side):
                if along - last < 70.0 and w < 15:
                    continue
                last = along
                e = self._edge_point(n, side)
                end = (e[0] + o[0] * depth, e[1] + o[1] * depth)
                cls = "avenue" if w >= 15 else "street"
                for piece in lines_of(LineString([e, end]).intersection(area.buffer(1.0))):
                    if piece.length < 30.0:
                        continue
                    starts_at_frame = dist(piece.coords[0], e) < 2.0
                    self.add(list(piece.coords), cls, "", "suburb")
                    if starts_at_frame:
                        self.links.append({"pos": e, "plan_node": n})
        # Cross streets parallel to the plan's sides.
        for name, poly in self.zones:
            if name == "beach_town":
                continue
            x0, y0, x1, y1 = poly.bounds
            if name in ("heights", "bayou_town"):
                for x in _steps(bx0 - 105.0, west - 1.0, -105.0):
                    self._clip_add([(x, y0 - 5), (x, y1 + 5)], poly, "street")
            elif name == "fringe":
                self._clip_add([(x0 - 5, by0 - 110.0), (x1 + 5, by0 - 110.0)], poly, "street")
            elif name == "shore":
                for y in (by1 + 120.0, by1 + 240.0):
                    self._clip_add([(x0 - 5, y), (x1 + 5, y)], poly.difference(self.coast.buffer(60.0)), "street")
            elif name == "eastside":
                for x in _steps(bx1 + 105.0, x1, 105.0):
                    self._clip_add([(x, y0 - 5), (x, y1 + 5)], poly, "street")
        # The Beltway round the suburbs.
        belt = [(west, by1 + 30.0), (west, north), (east, north), (east, 700.0)]
        for piece in lines_of(LineString(fillet(belt, 60.0, 8.0)).intersection(self.A.difference(self.P))):
            self.add(list(piece.coords), "avenue", "Bellerive Beltway", "suburb")
        # Gulf Shore Drive and Seabreeze Drive: the coast 90 m inland, from the
        # western edge of the city to Brisa Beach's north end, over the
        # river mouth.
        coast = LineString(self.L([[5000, 8590], [5600, 8650], [7600, 8650], [8400, 8000], [8780, 7470]]))
        # Whichever side of the coast is land.
        drive = coast.offset_curve(90.0, join_style="round")
        if self.gulf.contains(drive.interpolate(0.5, normalized=True)):
            drive = coast.offset_curve(-90.0, join_style="round")
        drive = LineString(fillet(list(drive.coords), 80.0, 8.0))
        drive = drive.intersection(box(west - 200, -1000, east + 300, 2100)).difference(self.P.buffer(60.0))
        for piece in lines_of(drive):
            if piece.length > 60:
                self.add(list(piece.coords), "avenue", "Seabreeze Drive", "suburb")
        self.ocean_drive = unary_union(lines_of(drive))
        # Brisa Beach cross streets: square to the coast, every 95 m.
        d = (800 / 1031.0, -650 / 1031.0)
        inland = (-d[1], d[0]) if (-d[1]) < 0 else (d[1], -d[0])
        start = self.L([[7600, 8650]])[0]
        for k in range(0, 12):
            base = (start[0] + d[0] * (40 + 95 * k), start[1] + d[1] * (40 + 95 * k))
            a = (base[0] + inland[0] * 40, base[1] + inland[1] * 40)
            b = (base[0] + inland[0] * 420, base[1] + inland[1] * 420)
            self._clip_add([a, b], zone["beach_town"].buffer(2.0), "street")
        back = [(start[0] + inland[0] * 300, start[1] + inland[1] * 300),
                (start[0] + inland[0] * 300 + d[0] * 1200, start[1] + inland[1] * 300 + d[1] * 1200)]
        self._clip_add(back, zone["beach_town"].buffer(2.0), "street", "Palmetto Row")
        # South shore streets: north-south from the frame to the drive.
        self.brisa_dirs = (d, inland)

    def _clip_add(self, pts, poly, cls, name=""):
        for piece in lines_of(LineString(pts).intersection(poly)):
            if piece.length >= 30.0:
                self.add(list(piece.coords), cls, name, "suburb")

    def towns(self):
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        tree = STRtree([s[0] for s in drivable])
        for t in self.world["towns"]:
            if t.get("phase", 1) > 2:
                continue
            c = self.L([t["pos"]])[0]
            i = tree.nearest(Point(c))
            main = drivable[i][0]
            s = main.project(Point(c))
            a = main.interpolate(max(0, s - 10)).coords[0]
            b = main.interpolate(min(main.length, s + 10)).coords[0]
            dx, dy = b[0] - a[0], b[1] - a[1]
            n = math.hypot(dx, dy) or 1.0
            u = (dx / n, dy / n)
            v = (-u[1], u[0])
            m = main.interpolate(s).coords[0]
            kind = t["kind"]
            region = t.get("region", "")
            if kind == "truck_stop":
                style = "truck_stop"
                streets, half, backs = [], 0, []
            elif kind == "town":
                style = "town"
                streets, half, backs = [-150, -75, 0, 75, 150], 160, [-110, 110]
            else:
                style = "bayou_village" if region == "saltgrass" else "village"
                streets, half, backs = [-70, 0, 70], 110, []
            for k in streets:
                p = (m[0] + u[0] * k, m[1] + u[1] * k)
                self._clip_add([(p[0] - v[0] * half, p[1] - v[1] * half), (p[0] + v[0] * half, p[1] + v[1] * half)],
                               self.play_land.buffer(1.0), "street", "")
            for k in backs:
                p = (m[0] + v[0] * k, m[1] + v[1] * k)
                self._clip_add([(p[0] - u[0] * 190, p[1] - u[1] * 190), (p[0] + u[0] * 190, p[1] + u[1] * 190)],
                               self.play_land.buffer(1.0), "street", "")
            r = 200 if kind == "town" else (130 if kind != "truck_stop" else 90)
            zone = Point(m).buffer(r).intersection(self.play_land)
            self.town_zones.append({"id": t["id"], "name": t["name"], "kind": kind, "style": style,
                                    "center": m, "u": u, "v": v, "zone": zone, "main": i})

    def join_ends(self):
        """Ends of roads that stop just short of another road are joined to it."""
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        lines = [s[0] for s in drivable]
        tree = STRtree(lines)
        link_pts = [Point(l["pos"]) for l in self.links]
        extra = []
        for i, (line, cls, name, kind) in enumerate(drivable):
            for end in (line.coords[0], line.coords[-1]):
                p = Point(end)
                if any(p.distance(q) < 3.0 for q in link_pts):
                    continue
                if self.P.distance(p) < 3.0 or self.A.exterior.distance(p) < 12.0:
                    continue
                touching = [j for j in tree.query(p.buffer(2.0)) if j != i and lines[j].distance(p) < 2.0]
                if touching:
                    continue
                best, best_d = None, 90.0
                for j in tree.query(p.buffer(90.0)):
                    if j == i:
                        continue
                    d = lines[j].distance(p)
                    if d < best_d:
                        best, best_d = j, d
                if best is None or best_d < 0.5:
                    continue
                q = nearest_points(p, lines[best])[1]
                seg = LineString([end, q.coords[0]])
                if seg.crosses(self.P) or self.water_prep.intersects(seg.buffer(1.0)):
                    continue
                extra.append([seg, cls if CLASSES[cls]["prio"] <= CLASSES[drivable[best][1]]["prio"] else drivable[best][1], name, kind])
        self.sources.extend(extra)

    # --- Graph --------------------------------------------------------------------

    def graph(self):
        drivable = [s for s in self.sources if CLASSES[s[1]]["graph"]]
        trails = [s for s in self.sources if not CLASSES[s[1]]["graph"]]
        noded = lines_of(unary_union([s[0] for s in drivable]))
        tree = STRtree([s[0] for s in drivable])
        pieces = []
        for g in noded:
            if g.length < 0.5:
                continue
            mid = g.interpolate(0.5, normalized=True)
            cands = [j for j in tree.query(mid.buffer(1.0)) if drivable[j][0].distance(mid) < 0.6]
            if not cands:
                cands = [int(tree.nearest(mid))]
            j = max(cands, key=lambda k: CLASSES[drivable[k][1]]["prio"])
            pieces.append({"pts": list(g.coords), "cls": drivable[j][1], "name": drivable[j][2]})
        # Junctions: snap ends together.
        node_pos = []
        grid = {}

        def node_at(p):
            key = (round(p[0] / 4.0), round(p[1] / 4.0))
            for kx in (key[0] - 1, key[0], key[0] + 1):
                for ky in (key[1] - 1, key[1], key[1] + 1):
                    for k in grid.get((kx, ky), []):
                        if dist(node_pos[k], p) < 3.0:
                            return k
            node_pos.append(p)
            grid.setdefault(key, []).append(len(node_pos) - 1)
            return len(node_pos) - 1

        for pc in pieces:
            pc["a"] = node_at(pc["pts"][0])
            pc["b"] = node_at(pc["pts"][-1])
        # Merge junctions joined by a very short piece.
        parent = list(range(len(node_pos)))

        def find(k):
            while parent[k] != k:
                parent[k] = parent[parent[k]]
                k = parent[k]
            return k

        for pc in pieces:
            if LineString(pc["pts"]).length < 12.0:
                ra, rb = find(pc["a"]), find(pc["b"])
                if ra != rb:
                    parent[rb] = ra
        groups = {}
        for k in range(len(node_pos)):
            groups.setdefault(find(k), []).append(k)
        new_pos = {}
        for root, members in groups.items():
            new_pos[root] = (sum(node_pos[m][0] for m in members) / len(members),
                             sum(node_pos[m][1] for m in members) / len(members))
        out = []
        seen = set()
        for pc in pieces:
            a, b = find(pc["a"]), find(pc["b"])
            if a == b:
                continue
            key = (min(a, b), max(a, b), round(LineString(pc["pts"]).length / 5.0))
            if key in seen:
                continue
            seen.add(key)
            pts = pc["pts"]
            pts[0] = new_pos[a]
            pts[-1] = new_pos[b]
            out.append({"pts": pts, "cls": pc["cls"], "name": pc["name"], "a": a, "b": b})
        pieces = out
        # Drop short spurs (overshoots past a junction), twice.
        link_pts = [l["pos"] for l in self.links]
        for _ in range(3):
            deg = {}
            for pc in pieces:
                deg[pc["a"]] = deg.get(pc["a"], 0) + 1
                deg[pc["b"]] = deg.get(pc["b"], 0) + 1
            keep = []
            for pc in pieces:
                length = LineString(pc["pts"]).length
                dead = [n for n in (pc["a"], pc["b"]) if deg[n] == 1 and not any(dist(new_pos[n], q) < 3.0 for q in link_pts)]
                if dead and length < 25.0 and (deg[pc["a"]] > 1 or deg[pc["b"]] > 1):
                    continue
                keep.append(pc)
            pieces = keep
        self.pieces = pieces
        self.trails = trails
        self.junction_pos = new_pos

    def build_graph_arrays(self):
        """Each piece is cut into straight graph edges a traffic car can
        follow; shape nodes in between, junctions at the ends."""
        nodes = []
        index = {}

        def nid(root):
            if root not in index:
                index[root] = len(nodes)
                p = self.junction_pos[root]
                nodes.append([round(p[0], 2), round(p[1], 2)])
            return index[root]

        edges = []
        roads = []
        for pc in self.pieces:
            c = CLASSES[pc["cls"]]
            line = LineString(pc["pts"])
            pts = resample(line, c["step"])
            ids = [nid(pc["a"])]
            for p in pts[1:-1]:
                nodes.append([round(p[0], 2), round(p[1], 2)])
                ids.append(len(nodes) - 1)
            ids.append(nid(pc["b"]))
            first = len(edges)
            for k in range(len(ids) - 1):
                p, q = nodes[ids[k]], nodes[ids[k + 1]]
                mid = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
                bridge = 1 if self.water_prep.contains(Point(mid)) else 0
                edges.append([ids[k], ids[k + 1], CLASS_NAMES.index(pc["cls"]), len(roads), bridge])
            roads.append({"cls": CLASS_NAMES.index(pc["cls"]), "name": pc["name"], "nodes": ids, "e0": first})
        self.nodes = nodes
        self.edges = edges
        self.roads = roads
        # Links to the plan: the country node at each link point.
        links = []
        for l in self.links:
            best, best_d = -1, 4.0
            for root, k in index.items():
                d = dist(self.junction_pos[root], l["pos"])
                if d < best_d:
                    best, best_d = k, d
            if best >= 0 and [best, l["plan_node"]] not in links:
                links.append([best, l["plan_node"]])
        self.link_pairs = links

    # --- Walls and bridges --------------------------------------------------------

    def walls(self):
        gaps = []
        for e in self.edges:
            if e[4]:
                p, q = self.nodes[e[0]], self.nodes[e[1]]
                w = CLASSES[CLASS_NAMES[e[2]]]["w"]
                gaps.append(LineString([p, q]).buffer(w * 0.5 + 0.6, cap_style="flat"))
        # Bridges reach a little onto the banks so the gap is clean.
        bridge_runs = self._bridge_runs()
        for run in bridge_runs:
            gaps.append(LineString(run["pts"]).buffer(run["w"] * 0.5 + 0.6, cap_style="flat"))
        edge = self.play_land.boundary.difference(self.P.buffer(0.5))
        if gaps:
            edge = edge.difference(unary_union(gaps))
        walls = []
        for ln in lines_of(edge):
            pts = list(ln.simplify(0.8).coords)
            for a, b in zip(pts, pts[1:]):
                if dist(a, b) < 0.3:
                    continue
                for piece in _split(a, b, 30.0):
                    walls.append([round(piece[0][0], 2), round(piece[0][1], 2), round(piece[1][0], 2), round(piece[1][1], 2),
                                  self._wall_kind(piece[0], piece[1])])
        self.wall_list = walls
        self.bridges = bridge_runs

    def _wall_kind(self, a, b):
        """0: a river or lake bank, 1: the Gulf coast, 2: the play area's
        edge on land."""
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1.0
        for sgn in (1.0, -1.0):
            q = Point(m[0] - dy / n * 4.0 * sgn, m[1] + dx / n * 4.0 * sgn)
            if self.gulf.contains(q):
                return 1
            if self.water_prep.contains(q):
                return 0
        return 2

    def _bridge_runs(self):
        runs = []
        for r, road in enumerate(self.roads):
            e0 = road["e0"]
            n = len(road["nodes"]) - 1
            k = 0
            while k < n:
                if not self.edges[e0 + k][4]:
                    k += 1
                    continue
                s = k
                while k < n and self.edges[e0 + k][4]:
                    k += 1
                # One more segment each side lands it on the bank.
                s0 = max(0, s - 1)
                s1 = min(n, k + 1)
                pts = [self.nodes[road["nodes"][i]] for i in range(s0, s1 + 1)]
                runs.append({"road": r, "from": s0, "to": s1, "pts": pts, "w": CLASSES[CLASS_NAMES[road["cls"]]]["w"]})
        return runs

    # --- Lots ---------------------------------------------------------------------

    def lot_setup(self):
        polys = []
        for pc in self.pieces:
            w = CLASSES[pc["cls"]]["w"]
            polys.append(LineString(pc["pts"]).buffer(w * 0.5 + 2.5, cap_style="round"))
        for t in self.trails:
            polys.append(t[0].buffer(CLASSES["trail"]["w"] * 0.5 + 1.0))
        for rl in self.rails:
            polys.append(rl[0].buffer(4.0))
        self.road_area = unary_union(polys)
        self.road_prep = prep(self.road_area)
        self.lot_grid = {}

    def try_lot(self, x, y, yaw, kind, landmark="", zone="", size=None):
        w, d = size if size else LOT[kind]
        poly = lot_poly(x, y, yaw, w, d)
        if not self.play_land_prep.contains(poly.buffer(1.0)):
            return False
        if self.road_prep.intersects(poly):
            return False
        x0, y0, x1, y1 = poly.bounds
        cells = [(gx, gy) for gx in range(int(x0 // 50) - 1, int(x1 // 50) + 2) for gy in range(int(y0 // 50) - 1, int(y1 // 50) + 2)]
        for c in cells:
            for other in self.lot_grid.get(c, []):
                if other.intersects(poly):
                    return False
        key = (int(x // 50), int(y // 50))
        self.lot_grid.setdefault(key, []).append(poly.buffer(1.5))
        self.lots.append({"x": x, "y": y, "yaw": yaw, "w": w, "d": d, "kind": kind, "id": landmark, "zone": zone})
        return True

    def landmark_lots(self):
        for lm in self.world["landmarks"]:
            kind = LANDMARK_KIND.get(lm["id"])
            if not kind or lm.get("phase", 1) > 2:
                continue
            p = self.L([lm["pos"]])[0]
            if self.P.contains(Point(p)) or not self.A.contains(Point(p)):
                print("skip landmark", lm["id"], "at", p)
                continue
            if not self._place_near(p, kind, lm["id"]):
                print("WARNING: no room for landmark", lm["id"])

    def _place_near(self, p, kind, ident, zone="", reach=160.0):
        w, d = LOT[kind]
        for r in _steps(0.0, reach, 6.0):
            for k in range(max(1, int(r / 4))):
                ang = k / max(1, int(r / 4)) * math.tau
                q = (p[0] + math.cos(ang) * r, p[1] + math.sin(ang) * r)
                # Face the nearest road.
                near = nearest_points(Point(q), self.road_area.boundary)[1].coords[0]
                nx, ny = q[0] - near[0], q[1] - near[1]
                n = math.hypot(nx, ny)
                if n < 1e-3:
                    continue
                yaw = yaw_facing(nx / n, ny / n)
                # Pull it up to the road.
                gap = n - d * 0.5 - 2.0
                if gap > 40.0:
                    continue
                if gap > 1.0:
                    q = (q[0] - nx / n * gap, q[1] - ny / n * gap)
                if self.try_lot(q[0], q[1], yaw, kind, ident, zone):
                    # A drive from the front door to the road.
                    f = (q[0] - nx / n * (d * 0.5), q[1] - ny / n * (d * 0.5))
                    r = nearest_points(Point(f), self.road_area.boundary)[1].coords[0]
                    if dist(f, r) > 2.0:
                        self.paths.append([[round(f[0], 2), round(f[1], 2)], [round(r[0], 2), round(r[1], 2)]])
                    return True
        return False

    def street_lots(self):
        zone_of = {}
        for name, poly in self.zones:
            zone_of[name] = prep(poly)
        towns = [(t, prep(t["zone"])) for t in self.town_zones]
        for pc in self.pieces:
            cls = pc["cls"]
            if cls not in ("street", "avenue", "road", "highway", "lane"):
                continue
            line = LineString(pc["pts"])
            w = CLASSES[cls]["w"]
            mid = line.interpolate(0.5, normalized=True)
            style = None
            zname = ""
            for t, tp in towns:
                if tp.contains(mid):
                    style = t["style"]
                    zname = t["id"]
            if style is None:
                for name, zp in zone_of.items():
                    if zp.contains(mid):
                        style = name
                        zname = name
            if style is None or style == "truck_stop":
                continue
            table = SUBURB_STYLE[style]
            kinds = list(table)
            weights = [table[k] for k in kinds]
            for sgn in (1.0, -1.0):
                s = 14.0
                while s < line.length - 14.0:
                    kind = self.rng.choices(kinds, weights)[0]
                    lw, ld = LOT[kind]
                    s += lw * 0.5
                    if s > line.length - 14.0:
                        break
                    p = line.interpolate(s).coords[0]
                    a = line.interpolate(max(0, s - 2)).coords[0]
                    b = line.interpolate(min(line.length, s + 2)).coords[0]
                    tx, ty = b[0] - a[0], b[1] - a[1]
                    tn = math.hypot(tx, ty) or 1.0
                    nx, ny = -ty / tn * sgn, tx / tn * sgn
                    off = w * 0.5 + 3.5 + ld * 0.5
                    q = (p[0] + nx * off, p[1] + ny * off)
                    if self.try_lot(q[0], q[1], yaw_facing(nx, ny), kind, "", zname):
                        s += lw * 0.5 + self.rng.uniform(2.0, 6.0)
                    else:
                        s += 4.0 - lw * 0.5 + lw * 0.5
        # Lifeguard towers along the sand at Brisa Beach and the shore.
        d, inland = self.brisa_dirs
        coast = LineString(self.L([[5100, 8600], [5600, 8650], [7600, 8650], [8400, 8000], [8780, 7470]]))
        for s in _steps(80.0, coast.length - 40.0, 160.0):
            p = coast.interpolate(s)
            for off in (30.0, 36.0):
                a = coast.interpolate(max(0, s - 2)).coords[0]
                b = coast.interpolate(min(coast.length, s + 2)).coords[0]
                tx, ty = b[0] - a[0], b[1] - a[1]
                tn = math.hypot(tx, ty)
                # The Gulf is to the right of this line (south-east): land on the left.
                nx, ny = ty / tn, -tx / tn
                q = (p.x + nx * off, p.y + ny * off)
                if self.try_lot(q[0], q[1], yaw_facing(-nx, -ny), "lifeguard_tower", "", "sand"):
                    break

    def town_lots(self):
        for t in self.town_zones:
            m, u, v = t["center"], t["u"], t["v"]
            if t["kind"] == "truck_stop":
                for kind, k in (("truck_stop", 0.0), ("motel", 80.0), ("gas_station", -70.0), ("diner", 140.0)):
                    p = (m[0] + u[0] * k, m[1] + u[1] * k)
                    self._place_near(p, kind, "", t["id"], reach=90.0)
                continue
            civic = ["town_hall", "gas_station"] if t["kind"] == "town" else ["general_store"]
            for kind in civic:
                self._place_near((m[0] + v[0] * 30, m[1] + v[1] * 30), kind, "", t["id"], reach=150.0)

    def farm_lots(self):
        """Farmsteads along the country roads, shacks along the bayou tracks,
        villas among the vines."""
        regions = {r["id"]: prep(Polygon(self.L(r["polygon"]))) for r in self.world["regions"] if r.get("phase") == 2}
        town_prep = [prep(t["zone"].buffer(60)) for t in self.town_zones]
        suburb = prep(unary_union([z[1] for z in self.zones]).buffer(60))
        for pc in self.pieces:
            if pc["cls"] not in ("road", "lane", "track", "highway"):
                continue
            line = LineString(pc["pts"])
            s = self.rng.uniform(60, 300)
            while s < line.length - 40:
                p = line.interpolate(s)
                if suburb.contains(p) or any(tp.contains(p) for tp in town_prep):
                    s += 200
                    continue
                reg = next((rid for rid, rp in regions.items() if rp.contains(p)), None)
                a = line.interpolate(max(0, s - 2)).coords[0]
                b = line.interpolate(min(line.length, s + 2)).coords[0]
                tx, ty = b[0] - a[0], b[1] - a[1]
                tn = math.hypot(tx, ty) or 1.0
                sgn = 1.0 if self.rng.random() < 0.5 else -1.0
                nx, ny = -ty / tn * sgn, tx / tn * sgn
                w = CLASSES[pc["cls"]]["w"]
                if reg == "golden_flats":
                    group = [("farmhouse", 0, 18), ("barn", 30, 34), ("silos", 52, 30)]
                    gap = self.rng.uniform(380, 700)
                elif reg == "saltgrass":
                    group = [(self.rng.choice(["shack", "stilt_house", "trailer_home"]), 0, 14)]
                    gap = self.rng.uniform(220, 450)
                elif reg == "verdant_hills":
                    group = [(self.rng.choice(["farmhouse", "mansion"]), 0, 22), ("machine_shed", 34, 26)]
                    gap = self.rng.uniform(450, 800)
                else:
                    s += 200
                    continue
                placed = False
                for kind, along, back in group:
                    lw, ld = LOT[kind]
                    off = w * 0.5 + back + ld * 0.5
                    q = (p.x + tx / tn * along + nx * off, p.y + ty / tn * along + ny * off)
                    if self.try_lot(q[0], q[1], yaw_facing(nx, ny), kind, "", reg):
                        placed = True
                        if kind == group[0][0]:
                            d0 = (p.x + nx * (w * 0.5), p.y + ny * (w * 0.5))
                            d1 = (p.x + nx * (w * 0.5 + back), p.y + ny * (w * 0.5 + back))
                            self.paths.append([[round(d0[0], 2), round(d0[1], 2)], [round(d1[0], 2), round(d1[1], 2)]])
                s += gap if placed else 60

    # --- Ground -------------------------------------------------------------------

    def ground_zones(self):
        zones = []
        taken = Polygon()
        for t in self.town_zones:
            z = t["zone"].difference(taken)
            zones.append(("town", z))
            taken = taken.union(z)
        # Sand along the Gulf, inside the play area.
        sand = self.coast.buffer(45.0).intersection(self.play_land).difference(taken)
        zones.append(("sand", sand))
        taken = taken.union(sand)
        for name, poly in self.zones:
            z = poly.difference(taken)
            zones.append((name, z))
            taken = taken.union(z)
        for r in self.world["regions"]:
            poly = Polygon(self.L(r["polygon"]))
            if r.get("phase") == 2:
                name = {"farmland": "farmland", "bayou": "bayou", "hills": "hills"}[r["type"]]
                z = poly.intersection(self.play_land).difference(taken)
            else:
                name = "far_" + r["type"]
                if name not in ZONES:
                    name = "far_land"
                z = poly.intersection(self.land).difference(self.A).difference(taken)
            zones.append((name, z))
            taken = taken.union(z)
        rest = self.land.difference(taken)
        zones.append(("land", rest.intersection(self.A)))
        zones.append(("far_land", rest.difference(self.A)))
        self.ground = [(ZONES.index(n), z) for n, z in zones if not z.is_empty]

    # --- Tiles --------------------------------------------------------------------

    def tiles(self):
        x0, y0, x1, y1 = self.outer.bounds
        tiles = {}
        ground_tree = STRtree([g[1] for g in self.ground])
        for gx in range(math.floor(x0 / TILE), math.ceil(x1 / TILE)):
            for gy in range(math.floor(y0 / TILE), math.ceil(y1 / TILE)):
                cell = box(gx * TILE, gy * TILE, (gx + 1) * TILE, (gy + 1) * TILE)
                if cell.within(self.P):
                    continue
                parts = []
                for i in ground_tree.query(cell):
                    zi, zpoly = self.ground[i]
                    piece = zpoly.intersection(cell)
                    for poly in polys_of(piece):
                        if poly.area < 0.5:
                            continue
                        tris = constrained_delaunay_triangles(poly.simplify(0.05))
                        flat = []
                        for tri in polys_of(tris):
                            for c in list(tri.exterior.coords)[:3]:
                                flat.extend([round(c[0], 2), round(c[1], 2)])
                        if flat:
                            parts.append([zi, flat])
                if parts:
                    tiles[(gx, gy)] = {"g": parts, "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": []}

        def tile_of(p):
            return (math.floor(p[0] / TILE), math.floor(p[1] / TILE))

        def put(key, field, value):
            t = tiles.get(key)
            if t is None:
                t = tiles[key] = {"g": [], "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": []}
            t[field].append(value)

        for ei, e in enumerate(self.edges):
            p, q = self.nodes[e[0]], self.nodes[e[1]]
            put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "r", ei)
        for li, lot in enumerate(self.lots):
            put(tile_of((lot["x"], lot["y"])), "l", li)
        for wi, w in enumerate(self.wall_list):
            put(tile_of(((w[0] + w[2]) / 2, (w[1] + w[3]) / 2)), "w", wi)
        for bi, b in enumerate(self.barricades):
            put(tile_of(b), "b", bi)
        for pi, path in enumerate(self.paths):
            put(tile_of(path[0]), "p", pi)
        for ti, tr in enumerate(self.trail_out):
            for k in range(len(tr["pts"]) - 1):
                p, q = tr["pts"][k], tr["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "t", [ti, k])
        for ri, rl in enumerate(self.rail_out):
            for k in range(len(rl["pts"]) - 1):
                p, q = rl["pts"][k], rl["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "x", [ri, k])
        for fi, fr in enumerate(self.far_out):
            for k in range(len(fr["pts"]) - 1):
                p, q = fr["pts"][k], fr["pts"][k + 1]
                put(tile_of(((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)), "f", [fi, k])
        self.tile_data = tiles

    def polyline_outputs(self):
        self.trail_out = []
        for t in self.trails:
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(t[0], 12.0)]
            self.trail_out.append({"name": t[2], "pts": pts})
        self.rail_out = []
        for line, kind, name, phase in self.rails:
            if line.length < 10:
                continue
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(line, 16.0)]
            self.rail_out.append({"kind": kind, "name": name, "pts": pts, "phase": phase})
        self.far_out = []
        for line, cls in self.render_only:
            pts = [[round(c[0], 2), round(c[1], 2)] for c in resample(line, 24.0)]
            self.far_out.append({"cls": CLASS_NAMES.index(cls), "pts": pts})

    # --- Run and export -------------------------------------------------------------

    def run(self):
        self.areas()
        self.routes()
        self.suburbs()
        self.towns()
        self.join_ends()
        self.graph()
        self.build_graph_arrays()
        self.walls()
        self.lot_setup()
        self.landmark_lots()
        self.town_lots()
        self.street_lots()
        self.farm_lots()
        self.ground_zones()
        self.polyline_outputs()
        self.tiles()

    def export(self):
        def ring(poly):
            return [[round(c[0], 1), round(c[1], 1)] for c in poly.exterior.coords]

        towns = []
        for t in self.town_zones:
            towns.append({"id": t["id"], "name": t["name"], "kind": t["kind"],
                          "pos": [round(t["center"][0], 1), round(t["center"][1], 1)]})
        zones = []
        for name, poly in self.zones:
            for p in polys_of(poly):
                zones.append({"zone": name, "poly": ring(p.simplify(2.0))})
        tiles = []
        for (gx, gy), t in sorted(self.tile_data.items()):
            t = dict(t)
            t["k"] = [gx, gy]
            tiles.append(t)
        lots = [[round(l["x"], 2), round(l["y"], 2), round(l["yaw"], 4), l["w"], l["d"], KINDS.index(l["kind"]),
                 l["id"], l["zone"]] for l in self.lots]
        return {
            "version": 1,
            "tile": TILE,
            "origin": list(self.origin),
            "plan_bounds": list(self.P.bounds),
            "classes": [{"id": k, "w": v["w"], "speed": v["speed"]} for k, v in CLASSES.items()],
            "zones": ZONES,
            "kinds": KINDS,
            "area": [ring(p.simplify(4.0)) for p in polys_of(self.A)],
            "suburbs": zones,
            "towns": towns,
            "nodes": self.nodes,
            "edges": self.edges,
            "roads": self.roads,
            "links": self.link_pairs,
            "bridges": [{"road": b["road"], "from": b["from"], "to": b["to"]} for b in self.bridges],
            "walls": self.wall_list,
            "barricades": self.barricades,
            "lots": lots,
            "paths": self.paths,
            "trails": self.trail_out,
            "rails": self.rail_out,
            "far_roads": self.far_out,
            "tiles": tiles,
        }


def _steps(a, b, step):
    out = []
    v = a
    if step > 0:
        while v <= b + 1e-9:
            out.append(v)
            v += step
    else:
        while v >= b - 1e-9:
            out.append(v)
            v += step
    return out


def _split(a, b, max_len):
    n = max(1, math.ceil(dist(a, b) / max_len))
    pts = [(a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n) for k in range(n + 1)]
    return list(zip(pts, pts[1:]))


if __name__ == "__main__":
    main()
