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

# Plots: road-square rectangles that hold grounds and lots (see HANDOFF-plots.md).
# Their parts are [kind, x, z, w, d, rot, variant] in the plot frame (x along
# the road, -z towards it); kits/grounds_kit.gd draws them. A rect part spans
# w across and d along its own z, turned by rot like a lot's yaw; a line part
# (wall, hedge, fence, trees) runs w along its own x.
PLOT_TYPES = ["estate", "cluster", "farmyard", "field"]
PART_KINDS = ["lawn", "yard", "gravel", "drive", "track", "wall", "hedge", "fence", "gate", "trees",
              "court", "parterre", "tennis", "orchard", "crop", "vines", "boat", "woodpile", "garden"]
# Tree kinds for "trees" and "orchard" parts.
TREE_KINDS = ["oak", "palm", "cypress", "fruit"]
# Dwellings that go into clusters rather than lots of their own.
DWELLINGS = ("house", "shack", "stilt_house", "trailer_home")
# Turn of cluster dwellings off the plot's axis (degrees) by style: small
# towns a little, the bayou edge of the city more, bayou camps most.
CLUSTER_JITTER = {"village": 8.0, "bayou_town": 16.0, "bayou_village": 26.0, "camp": 28.0, "trailers": 4.0}
# Homes in a cluster share its yard, so their lots are tighter than a street lot.
CLUSTER_LOT = {"house": (11, 12), "stilt_house": (10, 10), "shack": (8, 9)}
# Estate house lot (the mansion kit draws house, forecourt and pool in it).
ESTATE_HOUSE = 40.0
TENNIS_BACK = 21.0      # depth behind an estate house for a tennis court across the plot
# Field cells: 44 m wide on a 50 m pitch (the gaps are the field edges).
FIELD_CELL = 44.0
FIELD_PITCH = 50.0
# Line parts: their w runs along their own x.
LINE_PARTS = ("wall", "hedge", "fence", "gate", "trees")
# Dwellings of the styles whose homes stand in clusters.
CLUSTER_HOMES = {"village": ["house", "house", "shack"], "bayou_village": ["stilt_house", "shack"],
                 "bayou_town": ["stilt_house", "shack", "house"]}

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
    gen.report()


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


def frame_point(c, yaw, lx, lz):
    """A point of a lot or plot frame in local metres."""
    cs, sn = math.cos(yaw), math.sin(yaw)
    return (c[0] + lx * cs + lz * sn, c[1] - lx * sn + lz * cs)


def part(kind, x, z, w, d, rot=0.0, variant=0):
    return [kind, x, z, w, d, rot, variant]


def seg_part(kind, a, b, thick, variant=0):
    """A line part from a to b (plot frame)."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    # Its own x runs along a -> b: Basis(UP, rot) takes x to (cos, -sin).
    return part(kind, (a[0] + b[0]) * 0.5, (a[1] + b[1]) * 0.5, math.hypot(dx, dz), thick, math.atan2(-dz, dx), variant)


def rect_part_poly(p):
    """The footprint of a rect part in the plot frame."""
    return lot_poly(p[1], p[2], p[5], p[3], p[4])


class PolyGrid:
    """Polygons binned by every 50 m cell their bounds touch."""

    def __init__(self, cell=50.0):
        self.cell = cell
        self.cells = {}

    def _keys(self, poly):
        x0, y0, x1, y1 = poly.bounds
        c = self.cell
        return [(gx, gy) for gx in range(math.floor(x0 / c), math.floor(x1 / c) + 1)
                for gy in range(math.floor(y0 / c), math.floor(y1 / c) + 1)]

    def hits(self, poly):
        for k in self._keys(poly):
            for o in self.cells.get(k, ()):
                if o.intersects(poly):
                    return True
        return False

    def add(self, poly):
        for k in self._keys(poly):
            self.cells.setdefault(k, []).append(poly)


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
        self.lot_grid = PolyGrid()
        self.plot_grid = PolyGrid()
        self.plots = []
        # The road pieces lots and plots front onto.
        self.front_lines = [LineString(pc["pts"]) for pc in self.pieces]
        self.front_half = [CLASSES[pc["cls"]]["w"] * 0.5 for pc in self.pieces]
        self.front_tree = STRtree(self.front_lines)

    def _frontage(self, q):
        """The road piece nearest q: (point on its centreline, unit tangent,
        unit normal towards q, half width, piece index, distance along it)."""
        i = int(self.front_tree.nearest(Point(q)))
        line = self.front_lines[i]
        s = line.project(Point(q))
        p, t = _along(line, s)
        n = (-t[1], t[0])
        if (q[0] - p[0]) * n[0] + (q[1] - p[1]) * n[1] < 0:
            n = (-n[0], -n[1])
        return p, t, n, self.front_half[i], i, s

    def _front_spot(self, q, w, d, setback=3.5):
        """A w x d rect square to the road nearest q, its front edge `setback`
        metres off the road's edge: (centre, yaw, normal, polygon) or None
        when it would not run alongside that road (past a road's end, or
        on a bend too tight for its width)."""
        p, t, n, hw, i, s = self._frontage(q)
        line = self.front_lines[i]
        if s < 2.0 or s > line.length - 2.0:
            return None
        off = hw + setback + d * 0.5
        c = (p[0] + n[0] * off, p[1] + n[1] * off)
        yaw = yaw_facing(n[0], n[1])
        poly = lot_poly(c[0], c[1], yaw, w, d)
        a, b = poly.exterior.coords[0], poly.exterior.coords[1]
        if abs(line.distance(Point(a)) - line.distance(Point(b))) > 1.5:
            return None
        return c, yaw, n, poly

    def _free(self, poly, yaw):
        if not self.play_land_prep.contains(poly.buffer(1.0)):
            return False
        if self.road_prep.intersects(poly):
            return False
        if self.lot_grid.hits(poly) or self.plot_grid.hits(poly):
            return False
        return self._square_to_roads(poly, yaw)

    def _square_to_roads(self, poly, yaw):
        """Whether every road within 10 m of poly runs along or across it
        (within 6 degrees): no lot ends up askew beside a second road."""
        ax = (math.cos(yaw), -math.sin(yaw))
        cen = poly.centroid
        for j in self.front_tree.query(poly.buffer(20.0)):
            line = self.front_lines[int(j)]
            if line.distance(poly) > self.front_half[int(j)] + 10.0:
                continue
            _, t = _along(line, line.project(cen))
            ang = math.degrees(math.asin(min(1.0, abs(ax[0] * t[1] - ax[1] * t[0]))))
            if 6.0 < ang < 84.0:
                return False
        return True

    def try_lot(self, x, y, yaw, kind, landmark="", zone="", size=None, plot=-1):
        """Adds a lot when it is free; a lot inside a plot (plot >= 0) was
        laid out with the plot and goes in as it is."""
        w, d = size if size else LOT[kind]
        if plot < 0:
            poly = lot_poly(x, y, yaw, w, d)
            if not self._free(poly, yaw):
                return False
            self.lot_grid.add(poly.buffer(1.5))
        self.lots.append({"x": x, "y": y, "yaw": yaw, "w": w, "d": d, "kind": kind, "id": landmark, "zone": zone,
                          "plot": plot})
        return True

    def add_plot(self, c, yaw, w, d, ptype, parts):
        self.plot_grid.add(lot_poly(c[0], c[1], yaw, w, d).buffer(1.5))
        self.plots.append({"x": c[0], "y": c[1], "yaw": yaw, "w": w, "d": d, "type": ptype, "parts": parts})
        return len(self.plots) - 1

    def _drive_to_road(self, f, n, gap):
        """A gravel drive from f straight back to the road's edge."""
        r = (f[0] - n[0] * gap, f[1] - n[1] * gap)
        self.paths.append([[round(f[0], 2), round(f[1], 2)], [round(r[0], 2), round(r[1], 2)]])

    def _spiral(self, p, reach, step=6.0):
        for r in _steps(0.0, reach, step):
            m = max(1, int(r / 4))
            for k in range(m):
                ang = k / m * math.tau
                yield (p[0] + math.cos(ang) * r, p[1] + math.sin(ang) * r)

    def landmark_lots(self):
        for lm in self.world["landmarks"]:
            kind = LANDMARK_KIND.get(lm["id"])
            if not kind or lm.get("phase", 1) > 2:
                continue
            p = self.L([lm["pos"]])[0]
            if self.P.contains(Point(p)) or not self.A.contains(Point(p)):
                print("skip landmark", lm["id"], "at", p)
                continue
            if kind == "mansion" and self._estate_near(p, lm["id"]):
                continue
            if not self._place_near(p, kind, lm["id"]):
                print("WARNING: no room for landmark", lm["id"])

    def _place_near(self, p, kind, ident, zone="", reach=160.0):
        """A lot as near p as there is room for, square to the road it fronts."""
        w, d = LOT[kind]
        tried = set()
        for q in self._spiral(p, reach):
            spot = self._front_spot(q, w, d)
            if spot is None:
                continue
            c, yaw, n, poly = spot
            key = (round(c[0] / 2.0), round(c[1] / 2.0))
            if key in tried or dist(c, p) > reach + 40.0:
                continue
            tried.add(key)
            if self.try_lot(c[0], c[1], yaw, kind, ident, zone):
                self._drive_to_road(frame_point(c, yaw, 0.0, -d * 0.5), n, 3.5)
                return True
        return False

    # --- Plots ----------------------------------------------------------------------

    def _estate_near(self, p, ident):
        tried = set()
        for q in self._spiral(p, 220.0, 8.0):
            for size in ((100.0, 100.0), (90.0, 90.0), (84.0, 84.0)):
                key = (round(q[0] / 4.0), round(q[1] / 4.0), size)
                if key in tried:
                    continue
                tried.add(key)
                if self.estate_at(q, size, ident, "", 0, grand=True):
                    return True
        return False

    def estate_at(self, q, size, ident="", zone="", style=0, grand=False, sun=False):
        """Walled (style 0) or hedged (1) grounds round a mansion, on a plot
        square to the road nearest q."""
        W, D = size
        spot = self._front_spot(q, W, D)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        turn = self._view_turn(c, yaw, W, D, sun)
        parts, house, gate = estate_layout(W, D, turn, style, self.rng, grand)
        k = self.add_plot(c, yaw, W, D, "estate", parts)
        h = frame_point(c, yaw, house[0], house[1])
        self.try_lot(h[0], h[1], yaw + turn, "mansion", ident, zone, (house[2], house[2]), plot=k)
        self._drive_to_road(frame_point(c, yaw, gate[0], gate[1]), n, gate[1] + D * 0.5 + 3.5)
        return True

    def _view_turn(self, c, yaw, W, D, sun=False):
        """The turn of an estate's house off its plot: 0, or 45 degrees either
        way on a square plot whose view (the nearest water, or with `sun` the
        south and the west) lies off to the back or side, so the garden side
        turns to it. A view straight behind keeps the house on the axis."""
        if min(W, D) < 80.0 or abs(W - D) > 8.0:
            return 0.0
        views = []
        if self.water.distance(Point(c)) < 350.0:
            w = nearest_points(Point(c), self.water)[1].coords[0]
            views.append((w[0] - c[0], w[1] - c[1]))
        if sun:
            views += [(0.0, 1.0), (-1.0, 0.0)]  # the midday and the evening sun
        cs, sn = math.cos(yaw), math.sin(yaw)
        for dx, dy in views:
            lx, lz = dx * cs - dy * sn, dx * sn + dy * cs
            a = math.atan2(lx, lz)
            if abs(a) < math.pi / 8:
                return 0.0
            if abs(a) < math.pi * 5 / 8:
                return math.copysign(math.pi / 4, lx)
        return 0.0

    def cluster_at(self, q, W, D, kinds, style, zone):
        """Dwellings scattered over a fenced yard on a plot square to the road
        nearest q (small towns, the bayou, trailer parks)."""
        spot = self._front_spot(q, W, D)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        parts, homes, gx = cluster_layout(W, D, kinds, style, self.rng)
        if len(homes) < 2:
            return False
        k = self.add_plot(c, yaw, W, D, "cluster", parts)
        for kind, x, z, rot in homes:
            h = frame_point(c, yaw, x, z)
            self.try_lot(h[0], h[1], yaw + rot, kind, "", zone, CLUSTER_LOT.get(kind), plot=k)
        self._drive_to_road(frame_point(c, yaw, gx, -D * 0.5), n, 3.5)
        return True

    def farmyard_at(self, q, template, zone):
        """A farmstead on a fenced yard: house nearest the road, barn, silos
        and sheds behind, a windbreak on the north and west sides."""
        lots, parts, (W, D) = farmyard_layout(template, self.rng)
        spot = self._front_spot(q, W, D, 6.0)
        if spot is None:
            return False
        c, yaw, n, poly = spot
        if not self._free(poly, yaw):
            return False
        # Windbreak rows along the sides (not the front) that face north (-y) or west (-x).
        x0, z0, x1, z1 = -W * 0.5, -D * 0.5, W * 0.5, D * 0.5
        sides = []
        for lx, lz, a, b in ((0, 1, (x0 + 3, z1 - 3), (x1 - 3, z1 - 3)), (-1, 0, (x0 + 3, z0 + 8), (x0 + 3, z1 - 3)),
                             (1, 0, (x1 - 3, z0 + 8), (x1 - 3, z1 - 3))):
            cs, sn = math.cos(yaw), math.sin(yaw)
            wx, wy = lx * cs + lz * sn, -lx * sn + lz * cs
            sides.append((max(-wy, -wx), a, b))
        sides.sort(key=lambda s: -s[0])
        for score, a, b in sides[:2]:
            if score > 0.3:
                parts.append(seg_part("trees", a, b, 8.0, TREE_KINDS.index("oak")))
        k = self.add_plot(c, yaw, W, D, "farmyard", parts)
        for kind, x, z in lots:
            h = frame_point(c, yaw, x, z)
            self.try_lot(h[0], h[1], yaw, kind, "", zone, plot=k)
        gate = next(p for p in parts if p[0] == "drive")
        self._drive_to_road(frame_point(c, yaw, gate[1], -D * 0.5), n, 6.0)
        return True

    def street_lots(self):
        zone_of = {}
        for name, poly in self.zones:
            zone_of[name] = prep(poly)
        towns = [(t, prep(t["zone"])) for t in self.town_zones]
        for pi, pc in enumerate(self.pieces):
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
            homes = CLUSTER_HOMES.get(style)
            for sgn in (1.0, -1.0):
                s = 14.0
                while s < line.length - 14.0:
                    kind = self.rng.choices(kinds, weights)[0]
                    if style == "heights" and kind == "mansion":
                        width = float(round(self.rng.uniform(64.0, 84.0)))
                        if s + width > line.length - 14.0:
                            break
                        if any(self.estate_at(self._side_point(line, s + width * 0.5, sgn, w * 0.5 + 3.5 + depth * 0.5),
                                              (width, depth), "", zname, 0)
                               for depth in ((width,) if width >= 80.0 else ()) + (88.0, 76.0, 64.0)):
                            s += width + self.rng.uniform(2.0, 6.0)
                            continue
                        kind = "house"
                    elif homes and kind in DWELLINGS:
                        sub = "trailers" if kind == "trailer_home" else style
                        width = self.rng.uniform(62.0, 78.0) if sub == "trailers" else self.rng.uniform(48.0, 64.0)
                        depth = 46.0 if sub == "trailers" else self.rng.uniform(34.0, 44.0)
                        if s + width > line.length - 14.0:
                            break
                        q = self._side_point(line, s + width * 0.5, sgn, w * 0.5 + 3.5 + depth * 0.5)
                        if self.cluster_at(q, width, depth, ["trailer_home"] if sub == "trailers" else homes, sub, zname):
                            s += width + self.rng.uniform(3.0, 9.0)
                        else:
                            s += 4.0
                        continue
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

    @staticmethod
    def _side_point(line, s, sgn, off):
        """The point `off` metres to one side (sgn) of line at s."""
        p, t = _along(line, s)
        return (p[0] - t[1] * sgn * off, p[1] + t[0] * sgn * off)

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
        """Farmsteads along the country roads, camps along the bayou tracks,
        villas and farms among the vines."""
        regions = {r["id"]: prep(Polygon(self.L(r["polygon"]))) for r in self.world["regions"] if r.get("phase") == 2}
        town_prep = [prep(t["zone"].buffer(60)) for t in self.town_zones]
        suburb = prep(unary_union([z[1] for z in self.zones]).buffer(60))
        for i, pc in enumerate(self.pieces):
            if pc["cls"] not in ("road", "lane", "track", "highway"):
                continue
            line = self.front_lines[i]
            s = self.rng.uniform(60, 300)
            while s < line.length - 40:
                p = line.interpolate(s)
                if suburb.contains(p) or any(tp.contains(p) for tp in town_prep):
                    s += 200
                    continue
                reg = next((rid for rid, rp in regions.items() if rp.contains(p)), None)
                sgn = 1.0 if self.rng.random() < 0.5 else -1.0
                q = self._side_point(line, s, sgn, self.front_half[i] + 30.0)
                if reg == "golden_flats":
                    placed = self.farmyard_at(q, "flats", reg)
                    gap = self.rng.uniform(380, 700)
                elif reg == "saltgrass":
                    placed = self.cluster_at(q, self.rng.uniform(40.0, 56.0), self.rng.uniform(34.0, 42.0),
                                             ["shack", "stilt_house", "trailer_home"], "camp", reg)
                    gap = self.rng.uniform(220, 450)
                elif reg == "verdant_hills":
                    if self.rng.random() < 0.5:
                        placed = self.estate_at(q, (84.0, 84.0), "", reg, 1, sun=True) or \
                            self.estate_at(q, (72.0, 80.0), "", reg, 1)
                    else:
                        placed = self.farmyard_at(q, "hills", reg)
                    gap = self.rng.uniform(450, 800)
                else:
                    s += 200
                    continue
                s += gap if placed else 60

    def field_plots(self):
        """Crop fields on the flats and vineyard blocks and orchards in the
        hills: cells square to the road they front, several deep, one crop
        to a run of cells."""
        regions = {r["id"]: Polygon(self.L(r["polygon"])) for r in self.world["regions"] if r.get("phase") == 2}
        block = unary_union([z[1] for z in self.zones] + [t["zone"] for t in self.town_zones]).buffer(20.0)
        areas = []
        for rid in ("golden_flats", "verdant_hills"):
            if rid in regions:
                areas.append((rid, prep(regions[rid].intersection(self.play_land).difference(block))))
        choice = {}
        for i, line in enumerate(self.front_lines):
            hw = self.front_half[i]
            for sgn in (1.0, -1.0):
                for s0 in _steps(4.0, line.length - FIELD_PITCH + 4.0, FIELD_PITCH):
                    s = s0 + FIELD_PITCH * 0.5
                    p, t = _along(line, s)
                    nx, ny = -t[1] * sgn, t[0] * sgn
                    yaw = yaw_facing(nx, ny)
                    for k in range(7):
                        off = hw + 6.0 + FIELD_PITCH * k + FIELD_CELL * 0.5
                        c = (p[0] + nx * off, p[1] + ny * off)
                        poly = lot_poly(c[0], c[1], yaw, FIELD_CELL, FIELD_CELL)
                        rid = next((r for r, ap in areas if ap.contains(poly)), None)
                        if rid is None or not self._free(poly, yaw):
                            continue
                        key = (i, sgn, int(s0 // 150.0), k // 3)
                        if key not in choice:
                            roll = self.rng.random()
                            rot = 0.0 if self.rng.random() < 0.5 else math.pi / 2
                            if rid == "golden_flats":
                                pick = None if roll < 0.08 else ("crop", rot, self.rng.randrange(4))
                            else:
                                pick = ("vines", rot, 0) if roll < 0.6 else (
                                    ("orchard", 0.0, TREE_KINDS.index("fruit")) if roll < 0.75 else None)
                            choice[key] = pick
                        pick = choice[key]
                        if pick is None:
                            continue
                        self.add_plot(c, yaw, FIELD_CELL, FIELD_CELL, "field",
                                      [part(pick[0], 0.0, 0.0, FIELD_CELL - 2.0, FIELD_CELL - 2.0, pick[1], pick[2])])

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
                    tiles[(gx, gy)] = {"g": parts, "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": [], "q": []}

        def tile_of(p):
            return (math.floor(p[0] / TILE), math.floor(p[1] / TILE))

        def put(key, field, value):
            t = tiles.get(key)
            if t is None:
                t = tiles[key] = {"g": [], "r": [], "l": [], "w": [], "b": [], "p": [], "t": [], "x": [], "f": [], "q": []}
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
        for qi, pl in enumerate(self.plots):
            put(tile_of((pl["x"], pl["y"])), "q", qi)
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
        self.field_plots()
        self.ground_zones()
        self.polyline_outputs()
        self.tiles()

    def report(self):
        """Plot counts, and the worst turn of a lot or plot off the road it fronts."""
        counts = {}
        for p in self.plots:
            counts[p["type"]] = counts.get(p["type"], 0) + 1
        turned = sum(1 for l in self.lots if l["plot"] >= 0 and l["kind"] == "mansion"
                     and abs(l["yaw"] - self.plots[l["plot"]]["yaw"]) > 0.1)
        worst = (0.0, None)
        for item in [l for l in self.lots if l["plot"] < 0 and l["zone"] != "sand"] + self.plots:
            f = frame_point((item["x"], item["y"]), item["yaw"], 0.0, -item["d"] * 0.5)
            p, t, n, hw, i, sa = self._frontage(f)
            if dist(f, p) > hw + 8.0:
                continue  # a back field: it fronts the field before it
            yaw = item["yaw"]
            ax = (math.cos(yaw), -math.sin(yaw))
            off = math.degrees(math.asin(min(1.0, abs(ax[0] * t[1] - ax[1] * t[0]))))
            if off > worst[0]:
                worst = (off, item.get("kind", item.get("type")), round(item["x"]), round(item["y"]))
        print("plots:", counts, "turned estate houses:", turned, "worst turn off the fronting road (deg):", worst)

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
                 l["id"], l["zone"], l["plot"]] for l in self.lots]
        plots = [[round(p["x"], 2), round(p["y"], 2), round(p["yaw"], 4), round(p["w"], 2), round(p["d"], 2),
                  PLOT_TYPES.index(p["type"]),
                  [[PART_KINDS.index(q[0]), round(q[1], 2), round(q[2], 2), round(q[3], 2), round(q[4], 2),
                    round(q[5], 4), q[6]] for q in p["parts"]]] for p in self.plots]
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
            "plot_types": PLOT_TYPES,
            "part_kinds": PART_KINDS,
            "tree_kinds": TREE_KINDS,
            "plots": plots,
            "paths": self.paths,
            "trails": self.trail_out,
            "rails": self.rail_out,
            "far_roads": self.far_out,
            "tiles": tiles,
        }


def _along(line, s):
    """The point of line at s and its unit tangent there."""
    a = line.interpolate(max(0.0, s - 2.0)).coords[0]
    b = line.interpolate(min(line.length, s + 2.0)).coords[0]
    tx, ty = b[0] - a[0], b[1] - a[1]
    tn = math.hypot(tx, ty) or 1.0
    return line.interpolate(s).coords[0], (tx / tn, ty / tn)


def _boundary(kind, W, D, gap_at=None, gap=7.0, splay=None):
    """The four sides of a W x D plot as line parts, 0.5 m in, with a gate
    gap in the front centred on x = gap_at, or a gate across the front-left
    corner when splay is given (mirror the result for the right)."""
    e = 0.5
    x0, z0, x1, z1 = -W * 0.5 + e, -D * 0.5 + e, W * 0.5 - e, D * 0.5 - e
    out = [seg_part(kind, (x1, z0), (x1, z1), 0.6), seg_part(kind, (x0, z1), (x1, z1), 0.6)]
    if splay:
        out += [seg_part(kind, (x0 + splay, z0), (x1, z0), 0.6), seg_part(kind, (x0, z0 + splay), (x0, z1), 0.6),
                seg_part("gate", (x0, z0 + splay), (x0 + splay, z0), 0.6)]
    else:
        out.append(seg_part(kind, (x0, z0), (x0, z1), 0.6))
        if gap_at is None:
            out.append(seg_part(kind, (x0, z0), (x1, z0), 0.6))
        else:
            out += [seg_part(kind, (x0, z0), (gap_at - gap * 0.5, z0), 0.6),
                    seg_part(kind, (gap_at + gap * 0.5, z0), (x1, z0), 0.6),
                    seg_part("gate", (gap_at - gap * 0.5, z0), (gap_at + gap * 0.5, z0), 0.6)]
    return out


def _mirror(parts):
    """Parts mirrored across the plot's x = 0 axis."""
    out = []
    for p in parts:
        q = list(p)
        q[1] = -p[1]
        # A line keeps its run (pi - rot); a gate, symmetric along its run,
        # takes -rot instead so its leaves still swing inward.
        q[5] = math.pi - p[5] if p[0] in LINE_PARTS and p[0] != "gate" else -p[5]
        out.append(q)
    return out


def estate_layout(W, D, turn, style, rng, grand=False):
    """The grounds of an estate (research: HANDOFF-plots.md). Axial: gate,
    tree-lined drive and mirrored parterres in front, the house on the axis,
    a tennis court and an orchard of the same size either side behind, a
    parterre and a row of trees at the back. Turned (square plots, house at
    45 degrees): the gate across a front corner, the drive up the diagonal,
    square parterres either side of it and a round garden behind the house.
    Returns (parts, house (x, z, size), gate (x, z))."""
    m = 2.0
    bound = "wall" if style == 0 else "hedge"
    tree = TREE_KINDS.index("palm" if style == 0 and rng.random() < 0.6 else "oak")
    hs = ESTATE_HOUSE + (6.0 if grand else 0.0)
    x0, z0, x1, z1 = -W * 0.5, -D * 0.5, W * 0.5, D * 0.5
    parts = [part("lawn", 0.0, 0.0, W, D)]
    if turn == 0.0:
        hs = min(hs, D - m - 16.0)
        front = min(max((D - hs) * 0.45, 12.0), 30.0)
        side = W * 0.5 - m - hs * 0.5 - 2.0
        # No room for a tennis court beside the house: shorten the front
        # garden, down to 12 m, to fit one behind it (court 18.3 m + margin).
        court_back = side < 18.5 and D - m - hs - TENNIS_BACK >= 12.0
        if court_back:
            front = min(front, D - m - hs - TENNIS_BACK)
        zf = z0 + front
        parts += _boundary(bound, W, D, 0.0)
        parts.append(part("drive", 0.0, (z0 + zf) * 0.5, 6.0, front))
        for s in (-1.0, 1.0):
            parts.append(seg_part("trees", (s * 6.5, z0 + 5.0), (s * 6.5, zf - 3.0), 9.0, tree))
        pw, pd = W * 0.5 - 10.0 - m, front - m - 4.0
        if pw >= 10.0 and pd >= 8.0:
            for s in (-1.0, 1.0):
                parts.append(part("parterre", s * (9.5 + pw * 0.5), z0 + m + 2.0 + pd * 0.5, pw, pd))
        run = z1 - m - zf
        sx = hs * 0.5 + 2.0 + side * 0.5
        if side >= 18.5 and run >= 37.0:
            t = 1.0 if rng.random() < 0.5 else -1.0
            parts.append(part("tennis", t * sx, z1 - m - 18.5, 18.3, 36.6))
            parts.append(part("orchard", -t * sx, z1 - m - 18.5, 18.3, 36.6, 0.0, TREE_KINDS.index("fruit")))
        elif side >= 8.0:
            # Beside the house, in front of a rear tennis court if there is one.
            end = z1 - m - (TENNIS_BACK + 1.0 if court_back else 1.0)
            ol = min(end - zf - 1.0, 40.0)
            if ol >= 8.0:
                for s in (-1.0, 1.0):
                    parts.append(part("orchard", s * sx, end - ol * 0.5, side - 1.0, ol, 0.0, TREE_KINDS.index("fruit")))
        back = z1 - m - (zf + hs)
        if court_back:
            # Across the back of the plot: tennis in one rear corner and an
            # orchard of the same size in the other, or tennis on the axis.
            zc = z1 - m - 1.0 - 18.3 * 0.5
            cx = W * 0.5 - m - 2.0 - 36.6 * 0.5
            if cx >= 36.6 * 0.5 + 2.0:
                t = 1.0 if rng.random() < 0.5 else -1.0
                parts.append(part("tennis", t * cx, zc, 18.3, 36.6, math.pi * 0.5))
                parts.append(part("orchard", -t * cx, zc, 36.6, 18.3, 0.0, TREE_KINDS.index("fruit")))
            else:
                parts.append(part("tennis", 0.0, zc, 18.3, 36.6, math.pi * 0.5))
            return parts, (0.0, zf + hs * 0.5, hs), (0.0, z0 + 0.5)
        if back >= 16.0:
            parts.append(part("parterre", 0.0, zf + hs + back * 0.5, min(W - 2 * m - 12.0, 40.0), back - 6.0))
        if back >= 6.0:
            parts.append(seg_part("trees", (x0 + 5.0, z1 - 3.5), (x1 - 5.0, z1 - 3.5), 10.0, tree))
        return parts, (0.0, zf + hs * 0.5, hs), (0.0, z0 + 0.5)
    # Turned: laid out for +45 degrees (house front to the front-left corner),
    # mirrored for -45.
    S = min(W, D)
    h = hs / math.sqrt(2.0)
    splay = 12.0
    own = _boundary(bound, W, D, splay=splay)
    g = (x0 + 0.5 + splay * 0.5, z0 + 0.5 + splay * 0.5)
    f = (-hs * 0.5 / math.sqrt(2.0), -hs * 0.5 / math.sqrt(2.0))
    u = (f[0] - g[0], f[1] - g[1])
    ln = math.hypot(*u)
    u = (u[0] / ln, u[1] / ln)
    own.append(part("drive", (g[0] + f[0]) * 0.5, (g[1] + f[1]) * 0.5, 6.0, ln, math.atan2(u[0], u[1])))
    for s in (-1.0, 1.0):
        o = (u[1] * s * 6.5, -u[0] * s * 6.5)
        own.append(seg_part("trees", (g[0] + u[0] * 4 + o[0], g[1] + u[1] * 4 + o[1]),
                            (f[0] - u[0] * 3 + o[0], f[1] - u[1] * 3 + o[1]), 9.0, tree))
    a = min(24.0, (S - 2 * m - h - 3.0) * 0.5)
    if a >= 10.0:
        own.append(part("parterre", x1 - m - a * 0.5, z0 + m + a * 0.5, a, a))
        own.append(part("parterre", x0 + m + a * 0.5, z1 - m - a * 0.5, a, a))
    r = min(10.0, (S * 0.5 - m - (h + 2.0) * 0.7071) / 1.7071)
    if r >= 5.0:
        k = (h + 2.0 + r) * 0.7071
        own.append(part("court", k, k, r * 2.0, r * 2.0))
    # Tree rows along the two back walls, between the parterres and the round garden.
    ends = (m + max(a, 0.0) + 3.0, 2.0 * r + 8.0)
    own.append(seg_part("trees", (x0 + ends[0], z1 - 3.5), (x1 - ends[1], z1 - 3.5), 10.0, tree))
    own.append(seg_part("trees", (x1 - 3.5, z0 + ends[0]), (x1 - 3.5, z1 - ends[1]), 10.0, tree))
    if turn < 0:
        own = _mirror(own)
        g = (-g[0], g[1])
    return parts + own, (0.0, 0.0, hs), g


def cluster_layout(W, D, kinds, style, rng):
    """Dwellings scattered over a yard (trailers in loose rows either side
    of a track): (parts, [(kind, x, z, rot)], gate x)."""
    jit = math.radians(CLUSTER_JITTER[style])
    wet = style in ("bayou_village", "camp", "bayou_town")
    parts = [part("yard", 0.0, 0.0, W, D, 0.0, 1 if wet else 0)]
    homes = []
    taken = []
    inner = box(-W * 0.5 + 2.0, -D * 0.5 + 2.0, W * 0.5 - 2.0, D * 0.5 - 2.0)
    if style == "trailers":
        gx = 0.0
        parts.append(part("track", 0.0, 0.0, 5.0, D))
        taken.append(box(-3.5, -D * 0.5, 3.5, D * 0.5))
        for side in (-1.0, 1.0):
            z = -D * 0.5 + 8.0
            while z < D * 0.5 - 6.0:
                if rng.random() < 0.85:
                    homes.append(("trailer_home", side * (13.0 + rng.uniform(-1.0, 1.0)), z + rng.uniform(-0.8, 0.8),
                                  -side * math.pi * 0.5 + rng.uniform(-jit, jit)))
                    taken.append(lot_poly(homes[-1][1], homes[-1][2], homes[-1][3], *LOT["trailer_home"]))
                z += 12.0
    else:
        gx = rng.uniform(-W * 0.22, W * 0.22)
        tl = D * rng.uniform(0.45, 0.7)
        parts.append(part("track", gx, -D * 0.5 + tl * 0.5, 3.5, tl))
        taken.append(box(gx - 3.0, -D * 0.5, gx + 3.0, -D * 0.5 + tl + 1.0))
        gap = {"village": 4.0, "bayou_town": 2.5, "bayou_village": 4.0, "camp": 7.0}[style]
        want = rng.randint(2, 4) if style == "camp" else rng.randint(3, 6)
        # Spots on a loose grid, each nudged and turned, tried in random order.
        cols, rows = max(2, int(W / 17.0)), max(1, int(D / 17.0))
        spots = [(-W * 0.5 + (i + 0.5) * W / cols, -D * 0.5 + (k + 0.5) * D / rows) for i in range(cols) for k in range(rows)]
        rng.shuffle(spots)
        for n in range(len(spots) * 4):
            if len(homes) >= want:
                break
            kind = rng.choice(kinds)
            w, d = CLUSTER_LOT.get(kind, LOT[kind])
            rot = rng.uniform(-jit, jit)
            if kind == "trailer_home" and rng.random() < 0.4:
                rot += math.pi * 0.5
            sx, sz = spots[n % len(spots)]
            x, z = sx + rng.uniform(-4.0, 4.0), sz + rng.uniform(-3.0, 3.0)
            poly = lot_poly(x, z, rot, w, d)
            if not inner.contains(poly) or any(poly.distance(t) < gap for t in taken):
                continue
            taken.append(poly)
            homes.append((kind, x, z, rot))
    if style != "camp" or rng.random() < 0.5:
        parts += _boundary("fence", W, D, gx, 6.0)
    # Trees, boats, woodpiles and garden patches in the spaces left.
    extras = [("trees", 1.5, TREE_KINDS.index("cypress" if wet else "oak"))] * rng.randint(2, 5)
    if wet:
        extras += [("boat", 3.0, 0)] * rng.randint(1, 2)
    extras += [("woodpile", 2.0, 0)] * rng.randint(0, 1)
    if not wet and style != "trailers":
        extras += [("garden", 4.0, 0)]
    for kind, room, variant in extras:
        for _ in range(30):
            x, z = rng.uniform(-W * 0.5 + 4.0, W * 0.5 - 4.0), rng.uniform(-D * 0.5 + 4.0, D * 0.5 - 4.0)
            spot = Point(x, z).buffer(room)
            if any(spot.distance(t) < 1.0 for t in taken):
                continue
            taken.append(spot)
            if kind == "trees":
                parts.append(part("trees", x, z, 0.0, 8.0, 0.0, variant))
            elif kind == "garden":
                parts.append(part("garden", x, z, 6.0, 5.0, rng.uniform(-jit, jit)))
            else:
                parts.append(part(kind, x, z, 2.0 if kind == "boat" else 3.0, 5.0 if kind == "boat" else 1.6,
                                  rng.uniform(-math.pi, math.pi)))
            break
    return parts, homes, gx


def farmyard_layout(template, rng):
    """A farmstead square to its road: ([(kind, x, z)], parts, (W, D)).
    House nearest the road beside the drive, the yard and its sheds behind;
    farmyard_at adds the windbreak."""
    if template == "flats":
        W, D = 90.0, 76.0
        lots = [("farmhouse", -28.0, -24.0), ("barn", 4.0, 8.0), ("silos", 28.0, 4.0)]
        if rng.random() < 0.6:
            lots.append(("machine_shed", -24.0, 22.0))
        dx, yard = -10.0, (10.0, 6.0, 52.0, 44.0)
    else:
        W, D = 64.0, 56.0
        lots = [("farmhouse", -14.0, -12.0), ("machine_shed", 16.0, 12.0)]
        dx, yard = 0.0, (13.0, 9.0, 34.0, 30.0)
    z0 = -D * 0.5
    yf = yard[1] - yard[3] * 0.5
    parts = [part("gravel", *yard), part("drive", dx, (z0 + yf) * 0.5, 5.0, yf - z0)]
    e = 0.5
    parts += [seg_part("fence", (-W * 0.5 + e, z0 + e), (dx - 3.0, z0 + e), 0.2, 1),
              seg_part("fence", (dx + 3.0, z0 + e), (W * 0.5 - e, z0 + e), 0.2, 1),
              seg_part("fence", (-W * 0.5 + e, z0 + e), (-W * 0.5 + e, D * 0.5 - e), 0.2, 1),
              seg_part("fence", (W * 0.5 - e, z0 + e), (W * 0.5 - e, D * 0.5 - e), 0.2, 1)]
    if rng.random() < 0.5:
        lots = [(k, -x, z) for k, x, z in lots]
        parts = _mirror(parts)
    return lots, parts, (W, D)


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
