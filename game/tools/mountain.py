"""The Bellerive Hills: a drivable mountain north of the city, like the Santa
Monica Mountains above Los Angeles (HANDOFF-roads-mountain.md M-6).

build_country.py takes from here the zone outline, the roads (a freeway
through the saddle, Crest Drive along the ridge, a canyon road, the
observatory road with its hairpins, a fire road to the masts), the
monument sites, and at the end the height grid the game reads
(scripts/terrain.gd): the ground's own shape, cut and filled to each road's
graded profile and to a flat pad under each lot.

All in local metres (game x = local x, game z = local y; north is -y).
"""

import base64
import math

import numpy as np
import shapely
from shapely.geometry import LineString, Point, Polygon

from road_classes import CLASSES

# The zone: from 90 m north of the Beltway (y -330) to the ridge's back.
OUTLINE = [(270, -430), (235, -800), (200, -1110), (165, -1260), (230, -1400), (400, -1580), (680, -1790), (1100, -1840),
           (1500, -1770), (1770, -1520), (1930, -1220), (2090, -950), (2210, -720), (2130, -600),
           (1900, -560), (1640, -430)]
FALLOFF = 220.0  # heights fade in over this far inside the outline
CELL = 8.0
MAX_H = 150.0

# Crests the ground falls away from: [(x, y, height)...], width (m).
RIDGES = [
    # The spine, west to east: Coyote Peak, the saddle the freeway takes,
    # Calder Peak (the masts), the eastern summit.
    ([(170, -1240, 0), (300, -1232, 14), (420, -1215, 32), (530, -1195, 48), (650, -1215, 50), (770, -1245, 40),
      (880, -1270, 58), (1010, -1270, 80), (1100, -1255, 112), (1230, -1230, 92), (1370, -1210, 84),
      (1520, -1190, 98), (1660, -1160, 72), (1800, -1060, 52), (1950, -880, 30), (2080, -720, 8)], 230.0),
    # Spurs toward the city: the observatory's, the west and east ones.
    ([(1100, -1255, 112), (1062, -1050, 88), (1050, -880, 70), (1040, -700, 32), (1030, -560, 8)], 140.0),
    ([(530, -1195, 48), (470, -1000, 40), (400, -760, 22), (380, -600, 8)], 130.0),
    ([(1520, -1190, 98), (1480, -950, 70), (1450, -700, 28)], 150.0),
    # Back spurs, falling north.
    ([(1010, -1270, 80), (1050, -1560, 40)], 150.0),
    ([(530, -1195, 48), (560, -1500, 26)], 150.0),
]

# Sites (x, y): the observatory's forecourt end, the letters' middle, the masts.
OBSERVATORY = (1050.0, -909.0)
OBSERVATORY_SIZE = (64.0, 44.0)
# Where Observatory Road ends, a road shoulder short of the lot (a drive
# carries on to the forecourt).
OBSERVATORY_ROAD_END = (OBSERVATORY[0] - 20.0, OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 + 8.5)
LETTERS = (1330.0, -1085.0)
LETTERS_SIZE = (150.0, 26.0)
MASTS = [(1106.0, -1250.0), (1132.0, -1232.0)]
MAST_SIZE = (18.0, 18.0)

GRADE = {"freeway": 0.06, "highway": 0.075, "road": 0.13, "street": 0.13, "lane": 0.14, "track": 0.25, "trail": 0.3}
BLEND = 22.0  # cut and fill fade out over this far beside a road's shoulder, or more:
MAX_BANK = 0.4  # no cut or fill bank steeper than this (the camera looks down at 60 degrees)
PAD_BLEND = 12.0


def roads(route_at):
    """The mountain's roads, in build order (a later road's junctions take
    an earlier one's height): [(points, class, name, tag, fillet radius)].
    route_at(name, near) gives the point on a map route nearest `near`."""
    freeway = [(690, -338), (696, -560), (722, -850), (752, -1080), (770, -1262), (800, -1420), (900, -1580),
               (1100, -1740), (1450, -1930), (1900, -1980), (2350, -1820), route_at("Route 1 Gulf Highway", (2700, -1600))]
    crest = [route_at("Route 9 River Road", (132, -1250)), (270, -1265), (400, -1255), (530, -1240), (650, -1250),
             (770, -1262), (880, -1322), (1010, -1362), (1110, -1388), (1230, -1342), (1370, -1300), (1520, -1270),
             (1660, -1225), (1760, -1132), (1840, -1010), (1990, -800), route_at("Route 1 Gulf Highway", (2300, -560))]
    coyote = [(452, -338), (470, -500), (540, -650), (590, -820), (600, -980), (612, -1120), (650, -1250)]
    observatory = [(1010, -338), (1015, -470), (1100, -560), (1180, -640), (1190, -700), (1110, -712),
                   (990, -760), (965, -820), (1000, -870), OBSERVATORY_ROAD_END]
    fire = [(1110, -1388), (1150, -1335), (1122, -1295), (1090, -1276), (1086, -1250)]
    trail = [(OBSERVATORY[0] + OBSERVATORY_SIZE[0] * 0.5 + 5.0, OBSERVATORY[1] + OBSERVATORY_SIZE[1] * 0.5 - 4.0), (1150, -930),
             (1230, -1010), (LETTERS[0] - LETTERS_SIZE[0] * 0.5 + 10.0, LETTERS[1] + LETTERS_SIZE[1] * 0.5 + 5.0)]
    return [
        (freeway, "highway", "Canyon Freeway", "freeway", 200.0),
        (crest, "road", "Crest Drive", "crest", 45.0),
        (coyote, "road", "Coyote Canyon Road", "canyon", 50.0),
        (observatory, "road", "Observatory Road", "observatory", 26.0),
        (fire, "track", "Summit Fire Road", "fire_road", 12.0),
        (trail, "trail", "Letters Trail", "letters_trail", 15.0),
    ]


class Mountain:
    def __init__(self, seed=1234):
        self.poly = Polygon(OUTLINE)
        self.boundary = self.poly.exterior
        rng = np.random.default_rng(seed)
        self.lattice = [(rng.uniform(-1.0, 1.0, (64, 64)), 150.0, 7.0), (rng.uniform(-1.0, 1.0, (64, 64)), 55.0, 2.5)]
        self.profiles = []  # [LineString, s samples, z samples, half width]

    # --- The ground's own shape -------------------------------------------------

    def _noise(self, xs, ys):
        out = np.zeros_like(xs)
        for grid, wave, amp in self.lattice:
            u, v = xs / wave, ys / wave
            i0, j0 = np.floor(u).astype(int), np.floor(v).astype(int)
            fu, fv = u - i0, v - j0
            fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
            g = lambda i, j: grid[i % 64, j % 64]
            a = g(i0, j0) * (1 - fu) + g(i0 + 1, j0) * fu
            b = g(i0, j0 + 1) * (1 - fu) + g(i0 + 1, j0 + 1) * fu
            out += (a * (1 - fv) + b * fv) * amp
        return out

    def raw(self, xs, ys):
        """Height of the untouched ground at arrays of points (0 outside)."""
        xs = np.asarray(xs, dtype=float)
        ys = np.asarray(ys, dtype=float)
        best = np.zeros_like(xs)
        for pts, width in RIDGES:
            dmin = np.full_like(xs, np.inf)
            hmin = np.zeros_like(xs)
            for (x0, y0, h0), (x1, y1, h1) in zip(pts, pts[1:]):
                dx, dy = x1 - x0, y1 - y0
                t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / (dx * dx + dy * dy), 0.0, 1.0)
                d = np.hypot(xs - (x0 + dx * t), ys - (y0 + dy * t))
                closer = d < dmin
                dmin = np.where(closer, d, dmin)
                hmin = np.where(closer, h0 + (h1 - h0) * t, hmin)
            best = np.maximum(best, hmin * np.exp(-(dmin / width) ** 2))
        inside = shapely.contains_xy(self.poly, xs, ys)
        di = shapely.distance(shapely.points(xs, ys), self.boundary)
        f = np.where(inside, _smooth(np.clip(di / FALLOFF, 0.0, 1.0)), 0.0)
        return np.clip(best + self._noise(xs, ys) * np.clip(best / 40.0, 0.2, 1.0), 0.0, MAX_H) * f

    def raw_at(self, p):
        return float(self.raw(np.array([p[0]]), np.array([p[1]]))[0])

    # --- Road profiles -------------------------------------------------------------

    def profile_at(self, p):
        """The height of the nearest graded road at p, or None off them."""
        best = None
        for line, s, z, hw, _bank in self.profiles:
            d = line.distance(Point(p))
            if d < hw + 3.0 and (best is None or d < best[0]):
                best = (d, float(np.interp(line.project(Point(p)), s, z)))
        return None if best is None else best[1]

    def profile_near(self, p, reach):
        """The height of the nearest graded road within `reach` of p (the
        road a lot fronts), or None."""
        best = None
        for line, s, z, _hw, _bank in self.profiles:
            d = line.distance(Point(p))
            if d < reach and (best is None or d < best[0]):
                best = (d, float(np.interp(line.project(Point(p)), s, z)))
        return None if best is None else best[1]

    def grade(self, line, cls, ends=None):
        """Grades a road: its height follows the ground, smoothed, no steeper
        than its class allows; ends on the flat or on an earlier road keep
        that height. Returns the max grade it reached."""
        if self.poly.distance(line) > 1.0:
            return 0.0
        n = max(2, math.ceil(line.length / 4.0))
        s = np.linspace(0.0, line.length, n + 1)
        pts = [line.interpolate(v).coords[0] for v in s]
        z = self.raw(np.array([p[0] for p in pts]), np.array([p[1] for p in pts]))
        k = 15
        if len(z) > k:
            z = np.convolve(np.pad(z, k // 2, mode="edge"), np.ones(k) / k, mode="valid")
        pins = {}
        for i in (0, len(pts) - 1):
            h = self.profile_at(pts[i])
            pins[i] = h if h is not None else self.raw_at(pts[i])
        if ends:
            for i, h in ends.items():
                pins[i if i >= 0 else len(pts) + i] = h
        # Where it crosses an earlier road, both share that height.
        for other, os, oz, _hw, _bank in self.profiles:
            for q in _points(line.intersection(other)):
                i = int(round(line.project(Point(q)) / (line.length / n)))
                pins[i] = float(np.interp(other.project(Point(q)), os, oz))
        g = GRADE[cls]
        ds = line.length / n
        for i, h in pins.items():
            z[i] = h
        # Pinned heights stay; the rest is pulled within the grade of them.
        for _ in range(4):
            for i in range(1, len(z)):
                if i not in pins:
                    z[i] = min(max(z[i], z[i - 1] - g * ds), z[i - 1] + g * ds)
            for i in range(len(z) - 2, -1, -1):
                if i not in pins:
                    z[i] = min(max(z[i], z[i + 1] - g * ds), z[i + 1] + g * ds)
        # How far the cut or fill fades out: wide enough to keep its bank gentle.
        bank = np.maximum(BLEND, np.abs(self.raw(np.array([p[0] for p in pts]), np.array([p[1] for p in pts])) - z) / MAX_BANK)
        self.profiles.append([line, s, z, _HALF[cls], bank])
        return float(np.max(np.abs(np.diff(z))) / ds)

    # --- The height grid ------------------------------------------------------------

    def grid(self, pads):
        """The final heights: the ground, cut and filled to the roads and to
        each lot's pad ([polygon, height]). Returns the export dict."""
        x0, y0, x1, y1 = self.poly.bounds
        x0, y0 = math.floor(x0 / CELL) * CELL - CELL, math.floor(y0 / CELL) * CELL - CELL
        nx = int(math.ceil((x1 - x0) / CELL)) + 2
        ny = int(math.ceil((y1 - y0) / CELL)) + 2
        gx, gy = np.meshgrid(x0 + np.arange(nx) * CELL, y0 + np.arange(ny) * CELL)
        xs, ys = gx.ravel(), gy.ravel()
        h = self.raw(xs, ys)
        wsum = np.zeros_like(h)
        zsum = np.zeros_like(h)
        margin = np.zeros_like(h)
        reach = np.zeros_like(h)
        for line, s, z, hw, bank in self.profiles:
            coords = np.array(line.coords)
            seg_s = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(coords, axis=0).T))])
            dmin = np.full_like(h, np.inf)
            smin = np.zeros_like(h)
            for k in range(len(coords) - 1):
                (ax, ay), (bx, by) = coords[k], coords[k + 1]
                dx, dy = bx - ax, by - ay
                l2 = dx * dx + dy * dy
                if l2 < 1e-9:
                    continue
                t = np.clip(((xs - ax) * dx + (ys - ay) * dy) / l2, 0.0, 1.0)
                d = np.hypot(xs - (ax + dx * t), ys - (ay + dy * t))
                closer = d < dmin
                dmin = np.where(closer, d, dmin)
                smin = np.where(closer, seg_s[k] + t * math.sqrt(l2), smin)
            zr = np.interp(smin, s, z)
            blend = np.interp(smin, s, bank)
            edge = hw + 2.0
            w = 1.0 - _smooth(np.clip(dmin / (edge + blend), 0.0, 1.0))
            wsum += w * w
            zsum += w * w * zr
            margin = np.maximum(margin, 1.0 - _smooth(np.clip((dmin - hw - 1.0) / CELL, 0.0, 1.0)))
            reach = np.maximum(reach, 1.0 - _smooth(np.clip((dmin - edge) / blend, 0.0, 1.0)))
        zroad = np.where(wsum > 1e-9, zsum / np.maximum(wsum, 1e-9), h)
        h = h * (1.0 - reach) + zroad * reach
        pts = shapely.points(xs, ys)
        if pads:
            # Each node takes the height of the nearest pad, flat a cell past
            # the lot's edge (so the bilinear ground under the whole lot is
            # at its height) and fading out beyond; a road keeps its own
            # grading a cell past its edge.
            dbest = np.full_like(h, np.inf)
            hbest = np.zeros_like(h)
            for poly, ph in pads:
                d = shapely.distance(pts, poly)
                closer = d < dbest
                dbest = np.where(closer, d, dbest)
                hbest = np.where(closer, ph, hbest)
            w = (1.0 - _smooth(np.clip((dbest - CELL - 2.0) / PAD_BLEND, 0.0, 1.0))) * (1.0 - margin)
            w = np.where(dbest <= 0.0, 1.0, w)  # under the lot itself, the pad
            h = h * (1.0 - w) + hbest * w
        h = np.clip(h, 0.0, MAX_H)
        self.heights = h.reshape(ny, nx)
        self.origin = (x0, y0)
        raw = np.round(self.heights * 10.0).astype("<u2").tobytes()
        return {"origin": [x0, y0], "cell": CELL, "size": [nx, ny], "dm": base64.b64encode(raw).decode("ascii")}

    def height(self, p):
        """Bilinear height from the final grid (as the game reads it)."""
        x0, y0 = self.origin
        ny, nx = self.heights.shape
        u, v = (p[0] - x0) / CELL, (p[1] - y0) / CELL
        i, j = int(math.floor(u)), int(math.floor(v))
        if i < 0 or j < 0 or i >= nx - 1 or j >= ny - 1:
            return 0.0
        fu, fv = u - i, v - j
        hh = self.heights
        a = hh[j, i] * (1 - fu) + hh[j, i + 1] * fu
        b = hh[j + 1, i] * (1 - fu) + hh[j + 1, i + 1] * fu
        return float(a * (1 - fv) + b * fv)


_HALF = {k: c["w"] * 0.5 for k, c in CLASSES.items()}


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def _points(geom):
    if geom.is_empty:
        return []
    if geom.geom_type == "Point":
        return [geom.coords[0]]
    if hasattr(geom, "geoms"):
        out = []
        for g in geom.geoms:
            out += _points(g)
        return out
    return [geom.coords[0], geom.coords[-1]]
