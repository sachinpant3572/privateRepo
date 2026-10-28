"""Golden Flats County: irrigated farmland west of the Bellerive Hills, like
the flats of San Andreas' countryside (HANDOFF-wide-roads.md F-1 to F-6).

build_country.py takes from here the Golden Flats Expressway, the section
grid (paved section roads, dirt half-section tracks, curving dirt
shortcuts), the irrigation canals, and the field layout: centre-pivot
circles with their sprinkler arms and rectangular fields in rows. Fields
are ground zones, so the tile cutter clips them to tiles and a big circle
never streams in half drawn; each sprinkler span is a plot of its own.

All in local metres (game x = local x, game z = local y; north is -y).
"""

import math
import random

from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union
from shapely.prepared import prep

# The section grid: lines every GRID metres through the map's county roads
# (County Road 12 at x -1550, Section Line Road at x -950, y -1750, -1050).
GRID = 600.0
GRID_X0 = -1550.0
GRID_Y0 = -1750.0
BRIDGE_Y = GRID_Y0 - GRID  # County Road 10, over the Cinder Lower
HALF_TRACK_ODDS = 0.4  # a half-section line's 600 m stretch is a dirt track
SHORTCUT_ODDS = 0.35  # a section gets a curving shortcut across it
MIN_PIECE = 120.0
# A grid road skips where it would run alongside an existing road this close.
PARALLEL_GAP = 40.0
PARALLEL_DEG = 15.0

# From the Beltway's north-west corner, across the Morrow and past Wheaton,
# out of the play area to the north (on toward the dam road).
EXPRESSWAY = [(-560, -370), (-760, -640), (-930, -950), (-1060, -1350), (-1150, -1900), (-1230, -2500),
              (-1300, -3100), (-1350, -3700)]
EXPRESSWAY_NAME = "Golden Flats Expressway"

# Canals beside these paved section roads (y), on their north side, from
# the Morrow west.
CANAL_YS = [-2350.0, -1150.0]
CANAL_OFF = 21.0  # canal centre off the road's centreline
CANAL_W = 5.0  # water
CANAL_LIP = 1.5  # concrete lip each side

# Pivots: radii tried in a 300 m quarter section, then in a 150 m sixteenth.
PIVOT_R = (132.0, 100.0)
PIVOT_R_SMALL = 64.0
PIVOT_ODDS = 0.7
SPAN = 45.0  # sprinkler span between wheel towers, at most
TRACK_W = 1.6  # wheel-track ring
CLEAR = 8.0  # fields keep this clear of roads, lots and plots
ROW_PITCH = 6.0
ROW_W = 2.6

PIVOT_CROPS = [("pivot_green", 0.5), ("pivot_gold", 0.3), ("pivot_bare", 0.2)]
FIELD_CROPS = [("field_green", 0.4), ("field_gold", 0.35), ("field_bare", 0.25)]
ROWS = {"field_green": "field_green_row", "field_bare": "field_bare_row"}
ZONES = ["pivot_track", "pivot_green", "pivot_gold", "pivot_bare", "field_green_row", "field_green",
         "field_gold", "field_bare_row", "field_bare", "canal", "canal_bank"]


def _pick(rng, table):
    roll = rng.random()
    for name, odds in table:
        if roll < odds:
            return name
        roll -= odds
    return table[-1][0]


def _lines_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "LineString":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(_lines_of(g))
        return out
    return []


def _polys_of(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Polygon":
        return [geom]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out.extend(_polys_of(g))
        return out
    return []


def _grid_values(lo, hi, base, step):
    k0 = math.ceil((lo - base) / step)
    k1 = math.floor((hi - base) / step)
    return [base + k * step for k in range(k0, k1 + 1)]


def _alongside(existing, gap=PARALLEL_GAP, deg=PARALLEL_DEG):
    """Two buffers (for x lines and y lines) round the stretches of existing
    roads that run within `deg` of north-south or east-west."""
    ns, ew = [], []
    for line in existing:
        cs = list(line.coords)
        for a, b in zip(cs, cs[1:]):
            dx, dy = b[0] - a[0], b[1] - a[1]
            if math.hypot(dx, dy) < 1.0:
                continue
            ang = math.degrees(math.atan2(abs(dy), abs(dx)))
            seg = LineString([a, b]).buffer(gap, cap_style="flat")
            if ang > 90.0 - deg:
                ns.append(seg)
            elif ang < deg:
                ew.append(seg)
    return unary_union(ns), unary_union(ew)


def _bezier(p0, c0, c1, p1, n=24):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append((u ** 3 * p0[0] + 3 * u * u * t * c0[0] + 3 * u * t * t * c1[0] + t ** 3 * p1[0],
                    u ** 3 * p0[1] + 3 * u * u * t * c0[1] + 3 * u * t * t * c1[1] + t ** 3 * p1[1]))
    return out


def grid_roads(area, existing, bridges=None, seed=77):
    """The section grid inside `area` (a polygon clear of rivers, towns and
    suburbs): [(points, class, name, tag)]. `existing` are the roads already
    there, which the grid does not double; `bridges` maps a grid line's y to
    the water it bridges."""
    bridges = bridges or {}
    rng = random.Random(seed)
    x0, y0, x1, y1 = area.bounds
    xs = _grid_values(x0, x1, GRID_X0, GRID)
    ys = _grid_values(y0, y1, GRID_Y0, GRID)
    ns, ew = _alongside(existing)
    out = []

    def put(pts, cls, name, tag, skip, wet=None):
        line = LineString(pts).intersection(area if wet is None else area.union(wet))
        if not skip.is_empty:
            line = line.difference(skip)
        for piece in _lines_of(line):
            if piece.length >= MIN_PIECE:
                out.append((list(piece.coords), cls, name, tag))

    for k, x in enumerate(xs):
        put([(x, y0 - 10), (x, y1 + 10)], "road", "Range Road %d" % (k + 1), "farm_grid", ns)
    for k, y in enumerate(ys):
        put([(x0 - 10, y), (x1 + 10, y)], "road", "County Road %d" % (2 * k + 8), "farm_grid", ew, bridges.get(y))
    # Half-section dirt tracks: some 600 m stretches of the lines between.
    for x in _grid_values(x0, x1, GRID_X0 + GRID * 0.5, GRID):
        for y in _grid_values(y0 - GRID, y1, GRID_Y0, GRID):
            if rng.random() < HALF_TRACK_ODDS:
                put([(x, y), (x, y + GRID)], "track", "", "farm_track", ns)
    for y in _grid_values(y0, y1, GRID_Y0 + GRID * 0.5, GRID):
        for x in _grid_values(x0 - GRID, x1, GRID_X0, GRID):
            if rng.random() < HALF_TRACK_ODDS:
                put([(x, y), (x + GRID, y)], "track", "", "farm_track", ew)
    # Shortcuts: a road curving across a section from one side to the other,
    # the way a farmer cuts the corner; every other one is paved (an old
    # asphalt lane), the rest dirt.
    for sx in _grid_values(x0 - GRID, x1, GRID_X0, GRID):
        for sy in _grid_values(y0 - GRID, y1, GRID_Y0, GRID):
            if rng.random() >= SHORTCUT_ODDS:
                continue
            a = rng.uniform(110.0, 230.0)
            b = rng.uniform(110.0, 230.0)
            if rng.random() < 0.5:
                p0, p1 = (sx, sy + a), (sx + GRID, sy + GRID - b)
                c0, c1 = (sx + 260.0, p0[1]), (sx + GRID - 260.0, p1[1])
            else:
                p0, p1 = (sx + a, sy), (sx + GRID - b, sy + GRID)
                c0, c1 = (p0[0], sy + 260.0), (p1[0], sy + GRID - 260.0)
            put(_bezier(p0, c0, c1, p1), "track", "", "farm_cut", LineString())
    # Paved and dirt in turn among the pieces that made it into the area.
    k = 0
    for i, (pts, cls, name, tag) in enumerate(out):
        if tag == "farm_cut":
            if k % 2:
                out[i] = (pts, "lane", name, tag)
            k += 1
    return out


def canal_lines(area):
    """The canals' centrelines: beside each canal road from the Morrow west,
    the longest run that stays in `area`."""
    out = []
    x0, _, x1, _ = area.bounds
    for y in CANAL_YS:
        line = LineString([(x0 - 10, y - CANAL_OFF), (x1 + 10, y - CANAL_OFF)]).intersection(area)
        pieces = [p for p in _lines_of(line) if p.length >= 300.0]
        if pieces:
            # The run that reaches furthest east (the Morrow end).
            out.append(max(pieces, key=lambda p: max(c[0] for c in p.coords)))
    return out


def canal_zones(lines, roads):
    """(water, banks) polygons of the canals, cut where a road crosses."""
    water = unary_union([l.buffer(CANAL_W * 0.5, cap_style="flat") for l in lines]).difference(roads)
    whole = unary_union([l.buffer(CANAL_W * 0.5 + CANAL_LIP, cap_style="flat") for l in lines]).difference(roads)
    return water, whole.difference(water)


def lay_fields(free, seed=78):
    """Fields in `free` (farmland clear of roads, lots, plots, canals and
    water): ({zone: geometry}, arms, pivots) where arms are the sprinkler
    spans [(centre, angle, length, variant)] (variant 1 the span at the
    pivot, 2 the last one with the overhang, 3 both) and pivots the circles
    [(centre, radius, crop zone)] for the maps."""
    rng = random.Random(seed)
    fp = prep(free)
    x0, y0, x1, y1 = free.bounds
    zones = {}
    arms = []
    circles = []
    pivots = []

    def add(name, geom):
        zones.setdefault(name, []).append(geom)

    def pivot(c, r):
        circle = Point(c).buffer(r, 16)
        if not fp.contains(circle) or any(circle.intersects(o) for o in circles):
            return False
        circles.append(circle)
        crop = _pick(rng, PIVOT_CROPS)
        n = max(1, math.ceil((r - 3.0) / SPAN))
        span = (r - 3.0) / n
        rings = []
        for k in range(1, n + 1):
            rr = span * k
            rings.append(Point(c).buffer(rr + TRACK_W * 0.5, 16).difference(Point(c).buffer(rr - TRACK_W * 0.5, 16)))
        add("pivot_track", unary_union(rings))
        add(crop, circle)
        pivots.append((c, r, crop))
        a = rng.uniform(0.0, 2.0 * math.pi)
        u = (math.cos(a), math.sin(a))
        for k in range(n):
            mid = span * (k + 0.5)
            variant = (1 if k == 0 else 0) + (2 if k == n - 1 else 0)
            arms.append(((c[0] + u[0] * mid, c[1] + u[1] * mid), a, span, variant))
        return True

    def fields(rect):
        """Two strip fields across `rect`, cut to the free ground."""
        bx0, by0, bx1, by1 = rect.bounds
        along_x = rng.random() < 0.5
        halves = ([box(bx0, by0, bx1, (by0 + by1) * 0.5), box(bx0, (by0 + by1) * 0.5, bx1, by1)] if along_x else
                  [box(bx0, by0, (bx0 + bx1) * 0.5, by1), box((bx0 + bx1) * 0.5, by0, bx1, by1)])
        for h in halves:
            h = h.buffer(-2.5, join_style="mitre")
            for piece in _polys_of(h.intersection(free)):
                piece = piece.simplify(0.5)
                if piece.area < 2500.0 or any(piece.intersects(o) for o in circles):
                    continue
                crop = _pick(rng, FIELD_CROPS)
                add(crop, piece)
                if crop in ROWS:
                    # Rows run the long way of the strip.
                    px0, py0, px1, py1 = piece.bounds
                    rows = []
                    if (px1 - px0) >= (py1 - py0):
                        y = py0 + ROW_PITCH * 0.5
                        while y < py1:
                            rows.append(box(px0, y - ROW_W * 0.5, px1, y + ROW_W * 0.5))
                            y += ROW_PITCH
                    else:
                        x = px0 + ROW_PITCH * 0.5
                        while x < px1:
                            rows.append(box(x - ROW_W * 0.5, py0, x + ROW_W * 0.5, py1))
                            x += ROW_PITCH
                    add(ROWS[crop], unary_union(rows).intersection(piece))

    q = GRID * 0.5
    for qx in _grid_values(x0 - q, x1, GRID_X0, q):
        for qy in _grid_values(y0 - q, y1, GRID_Y0, q):
            quarter = box(qx, qy, qx + q, qy + q)
            if not quarter.intersects(free):
                continue
            c = (qx + q * 0.5, qy + q * 0.5)
            placed = False
            if rng.random() < PIVOT_ODDS:
                # Whole size first, nudged off a farmstead or a shortcut if need be.
                placed = any(pivot((c[0] + dx, c[1] + dy), r) for r in PIVOT_R
                             for dx, dy in ((0, 0), (12, 0), (-12, 0), (0, 12), (0, -12)))
                if not placed:
                    # Small pivots in the sixteenths that are clear.
                    s = q * 0.5
                    for ix in (0, 1):
                        for iy in (0, 1):
                            sc = (qx + s * (ix + 0.5), qy + s * (iy + 0.5))
                            if pivot(sc, PIVOT_R_SMALL):
                                placed = True
                            else:
                                fields(box(qx + s * ix, qy + s * iy, qx + s * (ix + 1), qy + s * (iy + 1)))
                    continue
            fields(quarter)
    # A later zone in the list keeps the ground it shares with an earlier one
    # out of it: tracks over crops, rows over their field.
    return {name: unary_union(geoms) for name, geoms in zones.items()}, arms, pivots
